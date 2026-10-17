# Proposal

## Why

认证切片01到03已完成，插件模块目前只有包骨架，尚不能完成市场浏览、安装和个性化配置的产品闭环。依据现行插件市场 PRD 和切片04到08，补齐后端能力，并将数据库边界、接口契约和验收条件明确到每个切片，支持用户逐个 commit 和自行管理 draft PR。

## What Changes

- 切片04：通过新增 Flyway migration 建立 `plugin`、`user_plugin`，初始化画板和番茄钟，提供带当前用户安装状态的市场列表；明确主键、唯一约束、索引、空值、JSON 和排序边界。
- 切片05：提供安装接口、集中生成默认配置，并用联合唯一约束和409响应处理串行及并发重复安装。
- 切片06：提供完整 JSON 对象替换接口，明确请求体、配置不透明性、权限与并发更新边界。
- 切片07：提供严格布尔启停和物理卸载，验证禁用保留配置、卸载后重装恢复默认配置。
- 切片08：用现有 SpringBootTest、MockMvc 和 MySQL/Redis Testcontainers 验证闭环、隔离、幂等和数据库约束。
- 每个新增接口同时维护模块化 OpenAPI 源文件、错误码和验收记录；任务按04、05、06、07、08顺序分组，提交和 draft PR 操作由用户完成。

## Capabilities

### New Capabilities

- `plugin-market-catalog`：平台插件目录、生产初始化、稳定排序及当前用户安装状态查询。
- `installed-plugin-lifecycle`：单实例安装、默认配置、对象配置替换、归属权限、启停和物理卸载。

### Modified Capabilities

无。沿用 `backend-module-boundaries` 的领域归属和 `environment-seeded-data` 的 Flyway、profile、fixture 规则，本次新增产品能力不改变其要求。

## Impact

- 后端实现位于 `api/src/main/java/com/nortidart/selfmark/plugin/`，复用现有 JWT 拦截器、`UserContext`、`BusinessException` 和 `ApiResponse`。
- 数据库新增两个版本 migration；当前最新版本为V3，拟使用V4建表、V5生产插件字典初始化，实施前确认版本未被占用。V1到V3保持不变。
- 新增五个受保护接口：`GET /api/plugins`、`POST /api/plugins/{code}/install`、两个 `PUT /api/user-plugins/{id}/...` 和 `DELETE /api/user-plugins/{id}`。
- 契约维护沿用 `api/docs/openapi/` 和 `api/check-api.sh`，测试沿用已安装的 JUnit、Mockito、MockMvc、Testcontainers；不增加业务框架依赖。
- 面向当前 MySQL 8.4 和 Redis 7.4 环境。涉及配置更新和启停的请求解析，以及通用参数类型异常的400处理，需要保持认证回归通过。
- 本提案只生成规划产物。实施不包含前端、Task/Subscription、插件发布、后端计时、用户提交的配置模板或主系统功能，也不代用户执行 commit、push 或创建 PR。
