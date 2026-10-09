# Spec Delta

## Purpose

区分生产数据库演进、联调 devdata、自动化测试 fixture 和数据库备份，避免本地数据或恢复快照在生产 API 启动时被误执行。

## ADDED Requirements

### Requirement: Production migrations are the schema source of truth
所有环境必须执行的表、索引、约束和已经明确的生产字典数据 MUST 使用不可变的、按版本递增的 Flyway migration；已执行的版本文件 MUST NOT 被原地修改。本 change 不定义 Plugin 或 Installed Plugin schema，后续切片完成产品规格后再新增对应 migration。

#### Scenario: A later slice introduces a plugin table
- **WHEN** 后续切片完成 Plugin schema 评审并需要新增表
- **THEN** 它通过生产 migration 目录中的新版本 migration 表达，并可以在空数据库上执行；本 change 不提前创建该 schema

#### Scenario: An existing schema needs correction
- **WHEN** 已执行的 schema 需要修正
- **THEN** 新增一个 migration，旧版本文件保持字节级不变

### Requirement: Development data and test fixtures are opt-in and isolated
联调 devdata MUST 位于 `api/src/main/resources/db/devdata`，自动化测试 fixture MUST 位于 `api/src/test/resources/db/fixture`；local/test profile 或测试启动配置可以显式加载它们，生产 profile MUST NOT 加载这些目录。

#### Scenario: Production starts with an empty application database
- **WHEN** 生产 profile 执行 Flyway
- **THEN** 只发现并执行生产 migration，联调 devdata 和测试 fixture 都不会被加载

#### Scenario: Apifox integration needs deterministic data
- **WHEN** 开发者使用 local/test profile 进行 Apifox 或前后端联调
- **THEN** 可以加载虚构、轻量、幂等的 `db/devdata`（其中的测试账号可以正常登录，凭据公开登记），不需要导入数据库备份

#### Scenario: Integration tests need deterministic fixtures
- **WHEN** 创建测试容器或测试上下文
- **THEN** 测试可以加载 `db/fixture` 中的稳定 fixture，且不读取 `backups/`

### Requirement: Local configuration requires explicit profile activation
公共配置 MUST NOT 无条件导入本地配置或默认激活 local；本地连接信息只能在显式启用 local 时加载。生产配置与自动化测试配置 MUST 不依赖开发者的 `application-local.yml`。默认和 prod 的 Flyway locations MUST 只包含生产 migration；只要 prod 被激活，就 MUST NOT 执行 devdata。

#### Scenario: A local file exists during production startup
- **WHEN** 本地配置文件存在，应用仅以 prod profile 启动
- **THEN** 不加载该本地文件，只使用生产配置，且不执行 devdata 或测试 fixture

#### Scenario: No development profile is selected
- **WHEN** 应用未显式启用 local 或 test profile
- **THEN** 不自动读取本地连接信息，不执行 devdata；需要的连接信息由外部配置提供

#### Scenario: A developer starts the local integration environment
- **WHEN** 开发者显式激活 local profile 并提供本地连接配置
- **THEN** 应用在 schema migration 完成后加载联调 devdata，Apifox 和前端可以使用公开的虚构测试账号登录

#### Scenario: Production is combined with a development profile
- **WHEN** prod 与 local 或 test 被同时激活
- **THEN** 开发种子的加载条件不成立，Flyway 不执行 devdata

#### Scenario: Authentication tests remain independent of local setup
- **WHEN** 现有认证集成测试使用 Testcontainers 注入配置，且不存在开发者的本地配置文件
- **THEN** 测试仍可通过注册接口创建自己的用户，并完成既有认证流程

### Requirement: Shared development data is version-controlled
用于前端联调的虚构 SQL 和 README MUST 提交 GitHub；README MUST 写明公开测试账号、测试密码、profile 激活方式和数据更新规则。共享 devdata MUST NOT 被当作个人临时数据忽略，且开发启动 MUST 不依赖恢复 backup 或手工造数。

#### Scenario: A frontend developer clones the repository
- **WHEN** 前端同事拉取仓库、准备本地数据库和连接配置并按说明启用 local profile
- **THEN** 应用自动初始化共享联调数据，前端同事可以按 README 登录并进行 API 联调

### Requirement: Main-resource devdata stays safe to package
`db/devdata` 会进入 API jar，因此其中的 SQL MUST 只包含**虚构**、轻量、可重复生成的联调数据：手机号等字段使用测试号段，账号密码使用**公开已知的统一测试明文**所对应的 hash，并把账号/明文登记在 `db/devdata/README.md`，以便 Apifox 直接登录。MUST NOT 包含真实用户的个人信息、生产环境凭据、任何 secret 或数据库快照。Flyway locations MUST 显式列出目录，禁止使用宽泛的 `classpath:db`。

> 「虚构」与「脱敏」的区别：脱敏是对真实数据打码，会破坏登录可用性；虚构是凭空编造测试数据，本来就不含真实信息，因此既能满足安全要求又能正常登录。

#### Scenario: The API artifact is built
- **WHEN** 生产 jar 被构建
- **THEN** `db/devdata` 可以作为资源存在，但生产 profile 不会加载它，`db/fixture` 和 `backups/` 不会进入生产 jar

#### Scenario: A profile is configured
- **WHEN** 配置 Flyway locations
- **THEN** 默认和生产 profile 使用 `classpath:db/migration`，显式激活 local/test 且 prod 未激活时额外加入 `classpath:db/devdata`

### Requirement: Database backups are not application seeds
`backups/` 中的 `selfmark-data-*.sql` 或完整快照 MUST 被视为人工恢复输入，不得被打包进 API 运行资源、自动加入 Flyway locations 或在应用启动时执行。

#### Scenario: A local database is restored
- **WHEN** 开发者导入带日期的 backup
- **THEN** 这是 API 启动之外的显式数据库操作，之后再按当前 schema 验证 Flyway

#### Scenario: The API artifact is built
- **WHEN** 生产 jar 被构建
- **THEN** backup 文件和测试 fixture 不在 artifact 中，devdata 只有在显式 local/test profile 下才会加载

### Requirement: Seed loading is repeatable
任何 devdata 或测试 fixture MUST 使用稳定 key 或 guarded insert，重复执行时不得产生重复的逻辑数据。

#### Scenario: A test context is rebuilt
- **WHEN** 相同的 devdata 或 fixture setup 执行两次
- **THEN** 数据库中每份数据只保留一份逻辑数据，Flyway 状态保持有效

#### Scenario: Seed content changes after integration data is edited
- **WHEN** 开发者已修改联调数据，后续更新共享 devdata 并再次启动开发环境
- **THEN** 只补齐缺失的种子数据，不重置已有账号密码或插件配置，也不产生重复的逻辑数据
