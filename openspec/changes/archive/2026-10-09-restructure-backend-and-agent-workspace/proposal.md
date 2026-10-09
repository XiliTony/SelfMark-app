# Proposal

## Why

切片 01-03 已经把认证、Redis key 约定、手机号契约和 OpenAPI 基础落地，但产品在切片 03 之后从“任务市场”转为“插件市场”，原先为任务/订阅预留的结构不能继续作为下一批实现的默认落点。切片 04-08 开始前需要先固定 Java 后端的领域边界、Flyway 数据分层和未来 Python Agent 的独立工作区，否则插件业务、测试种子和 Agent 依赖会混入已有认证模块或生产包。

## What Changes

- 建立与当前 PRD 一致的 Java 后端结构：保留 `auth`、`common`、`config` 横向边界，新增 `plugin` 领域包，删除已经废弃的 `task`/`subscription` Java 占位包。
- 明确数据库资源分层：`api/src/main/resources/db/migration` 只放所有环境必须执行的、不可修改的 Flyway 版本迁移；自动化测试 fixture 放在 `api/src/test/resources/db/fixture`；需要随 API 工程提供、但不属于生产必需数据的联调数据放在 `api/src/main/resources/db/devdata`，只由 local/test profile 显式加载。
- 确认采用方案 A：共享联调 SQL 和 `db/devdata/README.md` 提交 GitHub，记录虚构账号、公开测试密码和启动方式，前端同事拉取项目后即可复现开发数据；不创建外置的 `api/devdata/`。
- 移除 `application.yml` 无条件导入 `application-local.yml` 的配置，依靠显式激活的 Spring profile 加载本地连接信息；默认和 prod 只加载生产 migration，local/test 才加载 devdata，并覆盖 prod 与开发 profile 混合启用时的隔离验收。
- 将 `backups/selfmark-data-*.sql` 保留为本地/运维恢复输入，不作为 Flyway migration 或应用启动 seed；它继续位于应用资源之外并受忽略规则保护，不纳入本 change 的应用包结构。
- 在仓库根新增独立的 Python Agent 工作区约定，为未来 LangChain Agent 预留 `agent/` 项目边界、配置、提示词、工具、评测和测试目录；Java API 不引入 Python 运行时或依赖。
- 整理忽略规则职责：后端生成物、IDE 元数据、本地配置和后端临时数据归 `api/.gitignore`；根 `.gitignore` 只保留仓库级别或跨项目规则，并避免误伤未来 Agent 源码。
- 记录迁移与验收顺序，使后续切片 04-08 可以在新结构中实现，并保证切片 01-03 的认证行为和手机号契约不变。

## Capabilities

### New Capabilities

- `backend-module-boundaries`: 定义 Java 单体后端的领域包、横向基础设施包、旧占位包删除和插件模块的职责边界。
- `environment-seeded-data`: 定义 Flyway 迁移、开发/测试种子和数据库备份的生命周期、加载范围与隔离规则。
- `python-agent-workspace`: 定义未来 Python LangChain Agent 的独立项目边界、可扩展目录约定和 Java API 的集成边界。
- `repository-ignore-boundaries`: 定义根目录与 `api/.gitignore` 的职责划分，避免敏感配置和构建产物进入版本库或污染其他项目。

### Modified Capabilities

无。当前 `openspec/specs/` 没有已存在的能力规范；认证模块的既有行为不在本 change 中修改。

## Impact

- Java 源码包：`api/src/main/java/com/nortidart/selfmark`，尤其是新增的 `plugin` 边界和删除旧 `task`/`subscription` 占位包。
- Spring/Flyway 资源：`api/src/main/resources/db`、profile 配置和测试资源配置。
- 新增独立 Python 工程目录 `agent/`，包含其自己的依赖清单、源码、测试和运行配置；不改变 `api/pom.xml` 的依赖模型。
- Git 忽略规则、README/后端团队文档和后续切片的实现路径。
- 后续切片 04-08 的实现与测试布局；切片 01-03 的 API、Redis key、手机号字段和认证测试应保持兼容。
