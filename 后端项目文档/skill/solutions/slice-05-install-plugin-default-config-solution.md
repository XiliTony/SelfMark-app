# Slice 05 完成方案：插件安装、默认配置和重复冲突

完成日期：2026-10-14。对应OpenSpec `complete-plugin-backend-slices-04-08` 任务2.1到2.4，4项全部完成；总change进度11/26。

## 交付范围

实现 `POST /api/plugins/{code}/install`、集中默认配置工厂、安装实例响应、事务回读及重复安装409。数据库继续使用MySQL和切片04的V4/V5，无新migration或依赖。

切片06的配置更新、切片07的启停/卸载及切片08的完整生命周期验收仍待后续实施。本切片不提供这些接口。

## 接口设计

```http
POST /api/plugins/quadrant-board/install
Authorization: Bearer <jwt>
```

无需请求体或Content-Type。code精确匹配目录，不trim、不转小写；`Quadrant-Board`、`POMODORO`、`pomodoro ` 均不能命中预置code。

归属取自JWT认证后的 `UserContext`。附加userId参数或包含userId/config/enabled的请求体不参与安装；后端始终使用当前身份、全新默认配置及 `enabled=true`。

成功响应示例（ID仅为示例，不保证固定值）：

```json
{
  "code": 200,
  "msg": "success",
  "data": {
    "id": 12,
    "pluginId": 2,
    "code": "pomodoro",
    "name": "番茄钟",
    "config": {"label": "专注"},
    "enabled": true
  }
}
```

`id` 是当前用户实例主键；`pluginId` 是平台目录主键。响应不暴露userId或createdAt，config为对象而非JSON字符串。成功后 `GET /api/plugins` 返回相同实例ID、配置及启用状态。

| HTTP/code | 稳定msg | 条件与结果 |
| --- | --- | --- |
| 200 | success | 安装成功，返回6字段实例对象，不使用201 |
| 401 | 未登录 / token 无效 / token 已登出 | 沿用JWT拦截器和Redis黑名单，进入业务前拒绝 |
| 404 | 插件不存在 | 目录code不存在或大小写/空白不匹配，无实例写入 |
| 409 | 插件已安装 | 已启用或禁用实例，或INSERT唯一冲突；保留原实例 |
| 500 | 服务器内部错误 | 缺少默认配置、非重复数据库故障或事务内回读/构造失败 |

错误包络统一为 `{"code":状态码,"msg":"稳定消息","data":null}`，SQL及异常详情仅在服务端日志中记录。

## 完整默认JSON

画板：

```json
{
  "active": "quadrant",
  "quadrant": {
    "xAxisLabel": "紧急度",
    "yAxisLabel": "重要度",
    "regions": [
      {"key": "q1", "name": "重要且紧急"},
      {"key": "q2", "name": "重要不紧急"},
      {"key": "q3", "name": "紧急不重要"},
      {"key": "q4", "name": "不重要不紧急"}
    ]
  },
  "pyramid": {
    "regions": [
      {"key": "p1", "name": "顶层目标"},
      {"key": "p2", "name": "中层计划"},
      {"key": "p3", "name": "底层行动"}
    ]
  }
}
```

番茄钟：`{"label":"专注"}`。

`DefaultPluginConfigFactory` 每次创建独立ObjectNode及嵌套节点，不缓存共享可变对象。单元测试完整比较字段及数组顺序，并修改第一份对象的嵌套区域名称，确认第二份和后续默认值不受影响。

目录中有code但工厂未定义时抛服务端异常，返回通用500；不会降级写入 `{}`。未来新增插件需同时提供目录migration和默认配置定义。

## 数据库、事务与并发边界

| 约束/索引 | 本切片用途与边界 |
| --- | --- |
| plugin.uk_plugin_code | 精确查询唯一目录；V4的 `utf8mb4_0900_bin` 区分大小写、采用NO PAD语义 |
| user_plugin.uk_user_plugin(user_id,plugin_id) | 每用户每插件最多一行；enabled不参与，禁用仍占安装名额；不同用户可分别安装 |
| user_plugin.PRIMARY(id) | 自增生成实例ID并按ID回读；回滚或冲突可产生自增空洞，不保证连续 |
| user_plugin.idx_user(user_id) | 沿用V4；与联合唯一键左前缀冗余，本次不调整 |
| config NOT NULL及根对象CHECK | 完整默认JSON满足对象约束；MySQL继续负责JSON存储 |
| enabled NOT NULL及0/1 CHECK | 安装显式写true，数据库同时限制直接SQL写入 |

安装方法使用Spring `@Transactional`，顺序为：查询目录、预检查 `(user_id,plugin_id)`、生成默认对象、INSERT、按生成ID回读、构造DTO。默认配置失败发生在INSERT前；INSERT或事务内回读/DTO构造发生运行时异常会回滚。测试对真实插入后的回读注入异常，确认HTTP500且数据库无残留行。

预检查改善正常重复请求的处理，但不能单独保证并发安全。两个请求都通过预检查时，由InnoDB联合唯一键决定一个成功；仅在实例INSERT周围捕获 `DuplicateKeyException` 并转换409。其他数据库错误继续按500处理，不使用Redis锁、进程锁或INSERT IGNORE。

重复请求不会执行UPDATE，不改变旧ID、config、enabled或createdAt。该接口不提供重复安装返回200的幂等协议；客户端遇到409可重新GET市场确认当前实例。

事务在Service返回前提交。提交之后发生网络中断或HTTP序列化故障不能靠该事务回滚，客户端重试可能收到409；不要把所有客户端未收到成功响应的情况视为“未安装”。安装事务内不调用Redis或外部服务，鉴权在进入业务前完成。

沿用无物理外键的逻辑关联设计，当前没有用户/目录删除接口；不假定存在级联删除。JSON按语义比较，不保证键顺序/空白；数值继续采用MySQL JSON原生精度，需要精确保留的高精度数值应以JSON字符串保存。

## 验收结果

2026-10-14本机Docker Desktop实际运行MySQL8.4和Redis7.4-alpine容器，生产Flyway迁移初始化目录；独立注册用户并按自身ID清理，不使用local/devdata账号。

| 验收 | 证据与结果 |
| --- | --- |
| 全量回归 | `api/` 下 `mvn -o test`：59项，失败0、错误0、跳过0 |
| 默认配置 | DefaultPluginConfigFactoryTests：3项，完整默认值、嵌套对象独立、未定义code失败 |
| Service异常分支 | PluginServiceTests：4项，预检查重复、INSERT竞态409、其他DB错误不误报409、回读失败传播 |
| Controller鉴权 | PluginControllerTests：5项，保留04的4项并新增无token安装401且不调用mapper |
| 真实数据库及HTTP | PluginCatalogIntegrationTests：10项，04的4项加05的6项全部实际执行 |
| 05真实安装 | 两种插件200、默认值和GET/DB一致、客户端字段不能覆盖身份/默认配置；他人市场仍未安装 |
| 05真实失败 | 未知/大小写/尾空格404；目录缺默认值500且无残留；回读异常500回滚真实INSERT |
| 重复及并发 | 启用/禁用重复409并逐列核对原数据；两个独立请求线程用屏障同时开始，一次200一次409、最终一行，无sleep |
| 既有约束与迁移 | V4唯一/CHECK测试、空库迁移、V3升级及生产重启回归全部通过 |
| OpenAPI | 根目录 `bash api/check-api.sh`：Redocly lint/bundle和oasdiff breaking检查通过，生成dist YAML |
| OpenSpec | `openspec validate complete-plugin-backend-slices-04-08 --strict` 通过 |

本机使用已安装Maven3.9.11的离线模式及依赖缓存执行同一pom。测试报告位于 `api/target/surefire-reports/`，不提交构建产物。预期故障用例会产生500异常日志；容器关闭后缓存上下文的Redis重连日志不代表测试失败，以Surefire结果核对实际执行数。

## 可提交文件

新增生产文件：

- `api/src/main/java/com/nortidart/selfmark/plugin/service/DefaultPluginConfigFactory.java`
- `api/src/main/java/com/nortidart/selfmark/plugin/dto/InstalledPluginResponse.java`

修改生产文件：

- `api/src/main/java/com/nortidart/selfmark/plugin/service/PluginService.java`
- `api/src/main/java/com/nortidart/selfmark/plugin/controller/PluginController.java`

新增/修改测试：

- `api/src/test/java/com/nortidart/selfmark/plugin/service/DefaultPluginConfigFactoryTests.java`
- `api/src/test/java/com/nortidart/selfmark/plugin/service/PluginServiceTests.java`
- `api/src/test/java/com/nortidart/selfmark/plugin/controller/PluginControllerTests.java`
- `api/src/test/java/com/nortidart/selfmark/plugin/PluginCatalogIntegrationTests.java`
- `api/src/test/java/com/nortidart/selfmark/ApiApplicationTests.java`
- `api/src/test/java/com/nortidart/selfmark/HealthEndpointTests.java`
- `api/src/test/java/com/nortidart/selfmark/InfrastructureTests.java`

契约与交付文档：

- `api/docs/openapi/openapi.yaml`
- `api/docs/openapi/paths/plugin.yaml`
- `api/docs/openapi/components/plugin-schemas.yaml`
- `api/docs/openapi/components/common-schemas.yaml`
- `api/docs/openapi/dist/selfmark.openapi.yaml`（脚本生成）
- `api/docs/error-codes.md`
- `openspec/changes/complete-plugin-backend-slices-04-08/tasks.md`
- 本完成方案。

`design.md` 中已有你对05到08提交标题的修改，本轮保留；是否一并提交由你按原意选择。

建议commit标题：`feat(slice-05): install plugins with default config`。commit、push和draft PR由你自行操作。

## Apifox待用户操作

导入生成的 `api/docs/openapi/dist/selfmark.openapi.yaml`，用自己的JWT确认两种安装200、重复409、未知/大小写code404、无token401，以及GET市场回读。完成Review后从Apifox重新导出 `api/docs/openapi/dist/selfmark.openapi.json`。

本轮没有修改Apifox JSON，也未声明已完成外部Apifox验收。目前实施和容器验证无需你补充其他资料。
