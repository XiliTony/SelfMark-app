# Slice 07 完成方案：严格布尔启停和物理卸载

完成日期：2026-10-14。对应OpenSpec `complete-plugin-backend-slices-04-08` 任务4.1到4.4，4项全部完成；总change进度19/26。

## 交付范围

实现 `PUT /api/user-plugins/{id}/enabled` 和 `DELETE /api/user-plugins/{id}`。复用认证上下文、统一响应、切片06行锁及JSON/路径错误处理。三个实例操作集中复用Service中的正整数校验、锁定归属检查和更新响应回读。

继续使用MySQL8.4及V4/V5，无新migration、索引、软删除字段或依赖。切片08的完整生命周期、跨操作并发及最终验收仍待后续实施。

## 启停接口

```http
PUT /api/user-plugins/11/enabled
Authorization: Bearer <jwt>
Content-Type: application/json

{"enabled":false}
```

实例ID必须是Java Long范围内的正整数，不是目录ID。归属取自JWT后的 `UserContext`；请求参数或body中的userId不参与归属判定。

enabled按JsonNode的 `isBoolean()` 严格检查，不使用会自动转换字符串/数字的Boolean DTO。true启用，false禁用。其他字段忽略，例如以下请求只修改状态：

```json
{"enabled":false,"id":999,"userId":999,"pluginId":999,"config":{"foo":999}}
```

成功返回完整实例，config、ID、目录关联、归属及createdAt均保持原值：

```json
{
  "code": 200,
  "msg": "success",
  "data": {
    "id": 11,
    "pluginId": 1,
    "code": "quadrant-board",
    "name": "画板",
    "config": {"label":"保留名称","nested":[null,true,{"foo":1}]},
    "enabled": false
  }
}
```

| 输入 | 结果 |
| --- | --- |
| `{"enabled":false}` / `{"enabled":true}` | HTTP200，config不变 |
| 重复提交当前状态 | HTTP200，不按changed rows=0判断不存在 |
| `{}` / `{"enabled":null}` | HTTP400，enabled 必须是布尔值 |
| `"true"` / `"false"` / 0 / 1 / 数组 / 对象作为字段值 | HTTP400，不自动转换 |
| 根为null、数组、字符串、数字或布尔值 | HTTP400，enabled 必须是布尔值 |
| 空body或坏JSON | HTTP400，请求体格式错误 |
| 非JSON Content-Type | HTTP415，仅支持 application/json |

禁用不是卸载：市场installed仍为true、enabled=false、config继续返回；仍占用 `(user_id,plugin_id)` 唯一安装名额，重复安装409。禁用后配置接口仍可更新，启用恢复原配置，不重置默认值。

## 卸载接口

```http
DELETE /api/user-plugins/11
Authorization: Bearer <jwt>
```

无需body或Content-Type。Service锁定读取、确认归属后物理删除当前用户的实例单行，成功返回HTTP200：

```json
{"code":200,"msg":"success","data":null}
```

不使用204。数据库旧行不存在，平台plugin目录仍在，市场恢复installed=false，并显式返回userPluginId=null、enabled=null、config=null。

重复DELETE返回404。卸载后对旧ID的config PUT、enabled PUT均404；即使已经重装，也不修改新实例或复活旧实例。

卸载释放联合唯一安装名额，随后POST安装生成新实例ID、enabled=true及完整默认配置。画板重新获得quadrant/pyramid两结构的全部默认字段，番茄钟重新获得 `{"label":"专注"}`；自定义配置和原禁用状态均不恢复。ID不保证固定或连续，不通过重置自增生成新实例。

## 错误与校验顺序

| HTTP/code | 稳定msg | 条件 |
| --- | --- | --- |
| 400 | 请求体格式错误 | 启停空/坏JSON |
| 400 | enabled 必须是布尔值 | 启停根非对象、enabled缺失或非布尔 |
| 400 | id 必须是正整数 | 两接口的abc、溢出、0或负数ID |
| 401 | 未登录 / token 无效 / token 已登出 | 沿用JWT和Redis黑名单 |
| 403 | 无权操作该插件实例 | 语法有效，但实例属于其他用户 |
| 404 | 插件实例不存在 | 正整数实例ID不存在，包括卸载后的旧ID |
| 415 | 仅支持 application/json | 启停收到非JSON Content-Type |
| 500 | 服务器内部错误 | 数据库异常、启停回读/DTO构造失败，或锁定后DELETE异常未删除一行 |

失败包络统一为 `{"code":状态码,"msg":"稳定消息","data":null}`。启停在可匹配JSON路由后先鉴权，再解析path/body，校验正整数和严格布尔，最后锁定实例并判断存在/归属。卸载在鉴权及路径校验后检查实例归属。测试403/404时使用合法path/body；多种错误同时存在时不假定资源错误优先于语法错误。

沿用06的高优先级 `RequestFormatExceptionHandler`，媒体类型路由匹配失败统一415，路径类型错误400。未改认证或通用异常处理器；缺失、无效、已登出token的启停/卸载测试均401且不调用mapper。

## 数据库与事务边界

```sql
SELECT * FROM user_plugin WHERE id = ? FOR UPDATE;
UPDATE user_plugin SET enabled = ? WHERE id = ? AND user_id = ?;
DELETE FROM user_plugin WHERE id = ? AND user_id = ?;
```

| 约束/索引 | 本切片作用 |
| --- | --- |
| user_plugin.PRIMARY(id) | 主键定位并锁定实例，无需新增索引 |
| uk_user_plugin(user_id,plugin_id) | 禁用仍占安装名额，物理DELETE后释放；重装走原安装唯一冲突规则 |
| idx_user(user_id) | 沿用04，与联合唯一键左前缀冗余，本轮不调整 |
| enabled NOT NULL、0/1 CHECK | HTTP提前严格验证，数据库继续限制直接SQL写入 |
| config JSON NOT NULL及根对象CHECK | 启停不写config，保留既有合法对象与MySQL JSON精度语义 |
| 无物理外键 | 卸载只删除实例，不删除目录/用户，不假定子表级联 |

两个Service方法均有独立 `@Transactional`。启停事务覆盖锁定检查、窄UPDATE、实例及目录回读和DTO构造；数据库或事务内回读异常会回滚状态修改。真实回读故障注入已确认HTTP500且旧状态和配置全部保留。

卸载事务覆盖锁定检查及单行DELETE。已锁定本人实例后，DELETE正常应返回1；异常返回0不报告成功，而抛服务端异常。与UPDATE不同，DELETE没有“同值但零变化”的成功场景，重复卸载在前置读取处404。

config更新、启停和卸载复用同一行锁策略，避免归属检查到写入期间出现删除竞态。启停只写enabled、配置只写config，不将旧实体整体写回。锁持有到提交/回滚，不在业务事务内调用Redis或外部服务；JWT黑名单检查在进入业务前完成。

同一字段采用最后成功写入覆盖，未增加version/ETag协议。跨操作并发、卸载先完成后的并发更新和应用重启综合验收属于切片08，本轮不将其任务预先勾选。

卸载是物理删除，无软删除标记、撤销、历史配置恢复或备份恢复接口。当前领域没有实例子表，不增加级联清理；未来引入依赖实例的数据时需同时设计卸载清理规则。

Service提交后的网络故障或HTTP序列化错误不能通过已结束的事务回滚。客户端可GET市场确认结果；卸载提交后重试可能404，启停同状态重试仍200。

## 验收结果

Docker Desktop实际运行MySQL8.4和Redis7.4-alpine，沿用生产Flyway迁移、独立注册用户和按自身ID清理；未使用local/devdata账号，容器测试未跳过。

| 验收 | 结果 |
| --- | --- |
| `api/` 下 `mvn -o test` | 115项，失败0、错误0、跳过0；本轮新增32项 |
| UserPluginControllerTests | 41项，新增23项；严格布尔13类输入、空/坏body、两接口非法ID、415及缺失/无效/已登出token |
| PluginLifecycleServiceTests | 新增4项；同状态零变化成功、他人卸载不DELETE、不存在404、异常零删除不报成功 |
| PluginCatalogIntegrationTests | 19项全部真实执行，新增07的5项执行案例 |
| 真实启停 | 两种插件false/false/true/true均200，逐列核对config/owner/id/pluginId/createdAt不变，GET一致 |
| 同状态UPDATE | 集成连接 `useAffectedRows=true`，同值SQL确实返回0；重复PUT仍200 |
| 真实卸载/重装 | 画板、番茄钟分别完成改配置、禁用、DELETE、市场复原、重装新ID和完整默认值；旧ID三种操作均404 |
| 权限与失败 | 他人启停/卸载403、不存在404、无token401、非法布尔400均保持原行；启停回读故障500回滚 |
| 既有回归 | 04数据库约束/迁移/seed、05安装并发、06配置及回滚、认证/健康/启动全部通过 |
| `bash api/check-api.sh` | Redocly lint/bundle及oasdiff breaking检查通过，生成dist YAML |
| `openspec validate complete-plugin-backend-slices-04-08 --strict` | 通过 |
| `git diff --check` | 通过 |

本机使用已安装Maven3.9.11和离线依赖缓存执行同一pom。Surefire报告位于 `api/target/surefire-reports/`，不提交构建产物。预期失败测试的异常日志不代表测试失败，以报告中的实际执行数和零失败/跳过核对。

## 可提交文件

生产代码：

- `api/src/main/java/com/nortidart/selfmark/plugin/controller/UserPluginController.java`
- `api/src/main/java/com/nortidart/selfmark/plugin/service/PluginService.java`
- `api/src/main/java/com/nortidart/selfmark/plugin/mapper/UserPluginMapper.java`

测试：

- `api/src/test/java/com/nortidart/selfmark/plugin/controller/UserPluginControllerTests.java`
- `api/src/test/java/com/nortidart/selfmark/plugin/PluginCatalogIntegrationTests.java`
- `api/src/test/java/com/nortidart/selfmark/plugin/service/PluginLifecycleServiceTests.java`（新增）

契约与交付：

- `api/docs/openapi/openapi.yaml`
- `api/docs/openapi/paths/plugin.yaml`
- `api/docs/openapi/components/plugin-schemas.yaml`
- `api/docs/openapi/dist/selfmark.openapi.yaml`（脚本生成）
- `api/docs/error-codes.md`
- `openspec/changes/complete-plugin-backend-slices-04-08/tasks.md`
- 本完成方案。

建议commit标题：`feat(slice-07): enable disable and uninstall plugins`。commit、push及draft PR由你自行操作。

## Apifox待用户操作

导入最新 `api/docs/openapi/dist/selfmark.openapi.yaml`，对已有安装实例验证false/true、同状态200、非法布尔400、额外字段无效、他人403和DELETE200/data:null；随后GET确认未安装、重装新ID及默认配置，验证旧ID404。

本轮工具只生成YAML；工作过程中检测到 `api/docs/openapi/dist/selfmark.openapi.json` 的其他更新并保留。检查时该JSON已包含到配置接口，尚无启停/卸载路径，需导入本轮YAML后在Apifox完成Review并重新导出JSON。现有JSON改动不作为本轮已完成外部验收的证据。

目前实现与自动化验收无需你补充其他资料。
