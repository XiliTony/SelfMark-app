# Slice 06 完成方案：配置整体替换、归属校验和事务保护

完成日期：2026-10-14。对应OpenSpec `complete-plugin-backend-slices-04-08` 的任务3.1到3.4，4项全部完成；总change进度15/26。

## 交付范围

实现 `PUT /api/user-plugins/{id}/config`，复用切片05的实例响应。请求体直接绑定JsonNode，验证根对象及正整数Long实例ID，在事务内锁定读取、检查归属、仅更新config并回读。

数据库继续使用MySQL8.4和既有V4/V5，无新表、索引、migration或依赖。启停/卸载接口留给切片07，完整生命周期及跨操作并发验收留给切片08。

## 接口设计

```http
PUT /api/user-plugins/11/config
Authorization: Bearer <jwt>
Content-Type: application/json

{"foo":1,"nested":{"items":[true,null,"中文"]}}
```

路径 `id` 是用户实例ID，不是目录ID。归属取自JWT后的 `UserContext`，附加userId参数不改变身份。body中的userId、enabled等键仅为配置内容，不修改实例归属或启用状态。

成功响应示例：

```json
{
  "code": 200,
  "msg": "success",
  "data": {
    "id": 11,
    "pluginId": 1,
    "code": "quadrant-board",
    "name": "画板",
    "config": {"foo":1,"nested":{"items":[true,null,"中文"]}},
    "enabled": false
  }
}
```

响应包含 `id/pluginId/code/name/config/enabled` 六字段，配置更新保留原enabled。再次GET市场时，其userPluginId、config和enabled与更新结果一致。

| HTTP/code | 稳定msg | 条件 |
| --- | --- | --- |
| 200 | success | 本人合法对象替换成功；相同配置再次提交也成功 |
| 400 | 请求体格式错误 | 空body或坏JSON |
| 400 | config 必须是 JSON 对象 | 根为JSON null、数组、字符串、数字或布尔值 |
| 400 | id 必须是正整数 | abc、Long溢出、0或负数 |
| 401 | 未登录 / token 无效 / token 已登出 | 沿用JWT和Redis黑名单 |
| 403 | 无权操作该插件实例 | 请求语法有效，但实例属于其他用户 |
| 404 | 插件实例不存在 | 请求语法有效、正整数ID未对应实例 |
| 415 | 仅支持 application/json | 非JSON Content-Type |
| 500 | 服务器内部错误 | 数据库错误、事务内回读/DTO构造失败、目录逻辑关联缺失 |

失败响应统一为 `{"code":状态码,"msg":"稳定消息","data":null}`，不向客户端暴露SQL或异常详情。

## body语义与配置边界

| 提交内容 | 实际结果 |
| --- | --- |
| `{"foo":1}` | config整体变为该对象，旧active/label等字段被删除 |
| `{}` | config清空为对象，不代表删除实例 |
| `{"config":{"foo":1}}` | 顶层config键也被保存，不自动解包 |
| 未知字段、嵌套对象/数组、内部null | 原样按JSON语义存储，不使用插件内部schema校验 |
| active切换为pyramid，同时提交quadrant/pyramid | 两种结构均保留各自提交的名称 |
| 切换时遗漏quadrant | 旧quadrant被删除，不隐式合并回来 |
| `{"enabled":true}` | 仅成为config里的键，不修改实例的enabled |

完整替换时，客户端负责提交需要保留的全部字段。后端不校验active枚举、区域数量或label长度，不补默认值。5000个中文字的配置字段已实际通过，约15KB，证明没有额外4KB业务限制；JSON解析器和MySQL自身仍存在资源上限。

继续采用MySQL JSON原生数值精度；整数、普通小数及高精度字符串已覆盖。需要精确保留高精度值时使用 `{"preciseDecimal":"0.123456789012345678"}`。对象键顺序和空白不保证保持，验收解析后按JSON语义比较。

## 校验与权限顺序

对可匹配的JSON路由，JWT拦截器先于body解析和业务执行；因此无token且body为坏JSON的请求仍401。随后进行Long路径绑定及JSON解析，Service检查正整数ID和根对象，最后查询实例及归属。

403/404验收必须提交语法有效的请求；坏body或非法ID可先返回400，不依赖资源错误覆盖语法错误。不存在实例404，存在但owner不同403；归属判断前不执行UPDATE。

媒体类型匹配在控制器选定之前发生，非JSON类型返回统一415。新增 `RequestFormatExceptionHandler` 无包选择器，只处理 `MethodArgumentTypeMismatchException` 和 `HttpMediaTypeNotSupportedException`，以最高优先级避免被既有通用Exception处理器抢先映射为500。其他异常继续由原处理器处理；认证/健康及预期500回归均通过。

## 数据库与事务设计

SQL通过参数绑定和已有JSON type handler处理配置：

```sql
SELECT * FROM user_plugin WHERE id = ? FOR UPDATE;
UPDATE user_plugin SET config = ? WHERE id = ? AND user_id = ?;
```

| 数据库边界 | 实现与取舍 |
| --- | --- |
| PRIMARY(id) | 实例读取和行锁按主键定位，无需新增索引 |
| uk_user_plugin(user_id,plugin_id) | 安装单实例约束继续有效，配置更新不改变这两个字段 |
| idx_user(user_id) | 沿用04的索引及其左前缀冗余，不在本切片调整 |
| config NOT NULL、根对象CHECK | Service提前验证，数据库仍约束直接SQL写入 |
| enabled及0/1 CHECK | 更新SQL不写enabled，禁用状态保持false |
| 无物理外键 | 逻辑关联沿用04；目录关联意外缺失时500并回滚，不假定有级联清理 |

事务包含：校验、锁定读取、存在/归属检查、窄UPDATE、实例回读、目录查询及DTO构造。锁持续到事务提交或回滚；在检查到更新之间，同一行的删除/修改需要等待。后续启停/卸载须沿用同一锁定策略，相关跨接口测试在07/08补齐。

只更新config，不把整个旧实体写回数据库，避免覆盖enabled、owner或目录关联。参数绑定复用 `JsonNodeTypeHandler`，不把客户端JSON拼接到SQL。

同一字段按最后成功写入覆盖，未引入version、ETag或冲突检测。两台设备分别提交完整配置时，后一次可覆盖前一次的字段；客户端应读取和提交需要保留的完整对象。

已经锁定并确认存在后，MySQL对同值UPDATE可能返回0 changed rows，这不等于不存在。Service不按该数字返回404，而是回读真实状态并返回200。集成测试启用Connector/J `useAffectedRows=true`，确认同值SQL实际返回0，重复PUT仍200；单元测试也稳定覆盖该分支。

事务内回读故障会回滚此前真实UPDATE，数据库旧配置及enabled均保留。Service提交之后的网络中断或HTTP序列化故障不能靠已结束的事务回滚；客户端可重新GET市场确认当前配置。

## 验收结果

Docker Desktop实际运行MySQL8.4和Redis7.4-alpine，使用生产Flyway迁移及独立注册用户，按自身实例/用户ID清理。未使用local/devdata账号，也未因Docker不可用跳过。

| 验收 | 结果 |
| --- | --- |
| `api/` 下 `mvn -o test` | 83项，失败0、错误0、跳过0；本轮新增24项 |
| UserPluginControllerTests | 18项：空/坏body、7种非对象根、非法/溢出ID、3种非JSON类型、JWT先于body解析 |
| PluginConfigServiceTests | 2项：zero changed rows仍成功且禁用状态保留、其他owner不写入 |
| PluginCatalogIntegrationTests | 14项全部实际执行，保留04/05的10项，新增06的4项 |
| 06真实配置 | 改轴/区域名、保留两结构切换、遗漏字段删除、空对象清空、字面config包装、任意嵌套/内部null/中文/数值、高精度字符串、超过4KB |
| 06权限与失败 | 他人403、不存在404、无token401、非法输入400/415均保持旧数据；回读故障500回滚真实UPDATE |
| 既有回归 | 安装并发及唯一/CHECK约束、V3升级/生产重启、认证与黑名单、启动/健康全部通过 |
| `bash api/check-api.sh` | Redocly lint/bundle及oasdiff breaking检查通过，生成dist YAML |
| `openspec validate complete-plugin-backend-slices-04-08 --strict` | 通过 |

本机使用已安装Maven3.9.11及离线依赖缓存执行同一pom；Surefire报告位于 `api/target/surefire-reports/`，构建产物不提交。

实施中先发现按包限定的advice无法处理控制器选定前的415，随后发现新advice缺少优先级时路径转换异常仍被旧泛化处理器映射为500。通过无包选择器且限定两类异常的高优先级advice修复，18项请求校验和最终83项回归已全部通过。

## 可提交文件

新增生产文件：

- `api/src/main/java/com/nortidart/selfmark/plugin/controller/UserPluginController.java`
- `api/src/main/java/com/nortidart/selfmark/common/exception/RequestFormatExceptionHandler.java`

修改生产文件：

- `api/src/main/java/com/nortidart/selfmark/plugin/service/PluginService.java`
- `api/src/main/java/com/nortidart/selfmark/plugin/mapper/UserPluginMapper.java`

测试：

- `api/src/test/java/com/nortidart/selfmark/plugin/controller/UserPluginControllerTests.java`
- `api/src/test/java/com/nortidart/selfmark/plugin/service/PluginConfigServiceTests.java`
- `api/src/test/java/com/nortidart/selfmark/plugin/PluginCatalogIntegrationTests.java`

契约与交付文档：

- `api/docs/openapi/openapi.yaml`
- `api/docs/openapi/paths/plugin.yaml`
- `api/docs/openapi/components/plugin-schemas.yaml`
- `api/docs/openapi/components/common-schemas.yaml`
- `api/docs/openapi/dist/selfmark.openapi.yaml`（脚本生成）
- `api/docs/error-codes.md`
- `openspec/changes/complete-plugin-backend-slices-04-08/tasks.md`
- 本完成方案。

建议commit标题：`feat(slice-06): replace installed plugin config`。commit、push及draft PR由你自行操作。

## Apifox待用户操作

导入 `api/docs/openapi/dist/selfmark.openapi.yaml`，使用已有安装实例ID验证完整对象PUT、GET回读、重复PUT200、空对象清空、字面config包装及400/401/403/404/415响应。禁用实例验收可使用已有联调数据；本轮尚未提供启停API。

完成接口Review后从Apifox重新导出 `api/docs/openapi/dist/selfmark.openapi.json`。本轮没有修改该JSON，也不声明已完成外部Apifox验收。目前实施与自动化验证无需你补充其他资料。
