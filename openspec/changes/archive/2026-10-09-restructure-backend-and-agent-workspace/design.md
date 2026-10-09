# Design

## Context

See `proposal.md` for the motivation and scope. 当前 `api` 是 Java 21/Spring Boot 单体，认证代码已经稳定在 `auth`，横向能力在 `common` 与 `config`，Flyway 只有 `V1` 到 `V3`，而 `task`/`subscription` 只有旧产品占位文件。根目录已有被忽略的数据库备份，`api` 尚未有清晰的生产迁移、联调数据和测试 fixture 分层；仓库也没有 Python Agent 工程。

当前 `application.yml` 通过 `spring.config.import: optional:classpath:application-local.yml` 无条件导入本地配置，文件存在时即被加载，与 local profile 是否启用无关。`optional` 只允许文件缺失，不提供环境隔离。现有认证集成测试通过 Testcontainers 和 `@DynamicPropertySource` 注入连接信息，并通过注册接口创建用户；修订配置时必须保留这条独立的测试路径。

## Goals / Non-Goals

**Goals:**

- 为后续插件市场切片提供明确的 `plugin` 领域包和测试镜像结构。
- 让生产迁移、联调 devdata、测试 fixture、备份恢复各自拥有清晰的加载边界。
- 建立可以逐步增加 LangChain 依赖的 Python `agent/` 工程骨架，同时让 API 仍可独立构建和部署。
- 把后端本地文件的忽略责任收回 `api/.gitignore`，保留根规则的仓库级职责。

**Non-Goals:**

- 本 change 不实现插件市场接口、`plugin` 表业务、配置校验或前端页面；这些仍由切片 04-08 完成。
- 本 change 不引入 LangChain、模型供应商、Milvus、FastAPI、RabbitMQ 或 Python 运行时依赖到可运行产品；只建立边界和最小脚手架约定。
- 本 change 不删除或重命名认证包，不修改手机号 API、Redis key、OpenAPI 契约或已完成切片的行为。
- 本 change 不把现有 SQL 备份转换成 migration，也不通过 `clean` 或重建数据库解决历史迁移问题。

## Decisions

### 1. Keep a domain-oriented Java monolith

保留以下根包职责：

```text
api/src/main/java/com/nortidart/selfmark/
├── auth/                  # 手机号认证、JWT、Redis 黑名单
├── common/                # 响应、异常、用户上下文、健康检查等横向能力
├── config/                # Spring/MyBatis/JWT 等全局配置
├── plugin/                # 插件市场与 Installed Plugin
│   ├── controller/
│   ├── dto/
│   ├── entity/
│   ├── mapper/
│   ├── service/
│   └── seed/              # 为后续切片预留的领域初始化协作边界
```

选择领域包而不是按全局 `controller/service/mapper` 分组，是为了让切片 04-08 的代码、测试和后续删除/替换都能在单一边界内完成。`plugin` 可以依赖 `auth` 提供的用户上下文和 `common` 的统一响应，但 `common`/`config` 不反向依赖业务领域。旧 `task`/`subscription` Java 包直接删除，历史切片文档继续保留在 `issues/archive-v1/`，不再形成代码层面的预留。

测试目录镜像业务包，例如 `api/src/test/java/com/nortidart/selfmark/plugin/{service,controller}`；认证测试路径保持不变。

### 2. Separate production migrations, devdata, test fixtures, and backups

目标资源布局：

```text
api/
├── src/main/resources/db/migration/      # V*.sql；所有环境；不可原地修改
├── src/main/resources/db/devdata/        # 联调/本地数据；只由 local/test 显式加载
├── src/test/resources/db/fixture/        # 自动化测试 fixture；不进入生产 jar
└── src/main/resources/application*.yml
```

所有环境都需要的 schema 和已经明确的生产字典数据使用版本化 migration。本 change 只固定 migration 目录职责，不定义 Plugin 表、Installed Plugin 表、目录字段或平台 seed；这些设计留待切片 04-08 的产品规格完成后再新增 migration。以后新增生产数据也只能新增 migration，不能编辑旧版本。

确认采用方案 A：`src/main/resources/db/devdata` 的共享 SQL 和 README 纳入 GitHub，不整体忽略该目录，也不创建外置 `api/devdata/`。数据必须虚构、轻量、可重复生成；联调账号在 SQL 中存放公开测试密码对应的 BCrypt hash，账号和公开测试密码登记在 README，便于 Apifox 登录。禁止放真实用户数据、真实凭据、JWT secret 或数据库快照。该目录默认进入 API jar，资源存在不等于生产启动时执行。

自动化测试专用数据仍放在 `src/test/resources/db/fixture`，按用例显式加载，例如在 Flyway 完成 schema 初始化后使用 `@Sql`；不把 fixture 加进生产 Flyway locations，也不进入生产 jar。共享 devdata 与用例 fixture 不重复维护同一份账号，现有认证测试继续通过注册接口自行创建用户。Flyway locations 必须精确列出目录，禁止使用会递归扫描 `classpath:db` 的宽泛配置。

#### Profile-controlled configuration

实施时删除公共 `application.yml` 中无条件导入 `application-local.yml` 的 `spring.config.import`。由 Spring Boot 的 profile 文件规则负责加载本地连接信息：只有显式启用 `local` 时，才自动读取被 Git 忽略的 `application-local.yml`。不设置默认 local profile，不通过 profile group 或 include 间接激活 local。prod 使用生产环境的外部配置或环境变量，测试使用测试资源配置及 Testcontainers 提供的连接信息。

共享的 Flyway 加载规则写在受版本控制的 `application.yml` 中，使用独立 YAML 文档和 `spring.config.activate.on-profile`，不依赖每个开发者复制的私有本地文件来声明 devdata。目标配置片段如下（其余既有配置保留）：

```yaml
spring:
  flyway:
    locations:
      - classpath:db/migration

---
spring:
  config:
    activate:
      on-profile: "(local | test) & !prod"
  flyway:
    locations:
      - classpath:db/migration
      - classpath:db/devdata
```

该表达式让开发 profile 在显式启用且 prod 未启用时加载 devdata；即使误把 prod 与 local/test 一起激活，devdata 文档也不会生效。正常生产部署只启用 prod，不能依赖开发连接信息；环境变量或外部配置同样不得覆盖生产 Flyway locations 为开发目录。

| 激活的 profile | 本地配置 | Flyway locations | 测试 fixture |
| --- | --- | --- | --- |
| 无 | 不自动读取 `application-local.yml` | 仅 migration | 不加载 |
| local | 读取本地连接信息 | migration + devdata | 不加载 |
| test | 测试配置或 Testcontainers 注入，不自动读取 local | migration + devdata | 用例显式加载 |
| prod | 生产外部配置，不自动读取 local | 仅 migration | 不加载 |
| prod 与 local/test 混合 | 不作为支持的部署方式；种子隔离单独验证 | 仅 migration | 生产不加载 |

README、devdata README 和 IDEA 运行说明同步改为显式激活 profile。例如，从 `api/` 运行以下 Windows 命令即可启动联调环境：

```powershell
.\mvnw.cmd spring-boot:run "-Dspring-boot.run.profiles=local"
```

IDEA 运行配置使用 active profiles=`local` 或程序参数 `--spring.profiles.active=local`；生产启动使用 `java -jar <api-jar> --spring.profiles.active=prod`，真实凭据由外部配置提供。应用在开发 profile 下先执行 schema migration，再执行选中的 devdata SQL，前端同事无需手工导入 backup。删除全局本地配置导入后，不带 profile 的旧启动命令可能因缺少连接信息而失败，这是预期变化，必须更新文档和验收命令。

devdata 采用 Flyway repeatable SQL（例如 `R__dev_demo_data.sql`），在版本化 schema migration 完成后执行；文件未变化时普通重启不重复执行，新增或修改种子内容会触发再次执行。SQL 使用稳定业务 key 和仅补齐缺失数据的 guarded insert，不覆盖联调过程中修改的密码或插件配置。测试 fixture 按用例隔离并可幂等初始化。各环境使用各自的数据库及 `flyway_schema_history`，不把已经执行过 devdata 的开发库切换为生产库。Flyway 目标配置显式开启 `validate-on-migrate`、`clean-disabled` 和 `out-of-order=false`，关闭日常使用的 `baseline-on-migrate`。现有 `V1`-`V3` 不改；调整 baseline 配置前先读取目标数据库的 `flyway_schema_history`，仅在接管没有历史记录的既有库时执行一次经过审查的 baseline。

`backups/selfmark-data-*.sql` 继续保持在应用资源之外，仅作为本地/运维恢复输入。恢复顺序是先启动当前 schema 的 Flyway，再由开发者显式导入与当前 schema 匹配的纯数据备份；备份不加入任何 Flyway location，也不参与 API 启动。开发联调不依赖备份文件，直接使用 migration 提供的生产目录数据和 local/test profile 提供的 devdata。

### 3. Use a separate Python Agent project

Agent 初始目录约定：

```text
agent/
├── pyproject.toml
├── README.md
├── .env.example
├── src/selfmark_agent/
│   ├── api/             # 未来需要 HTTP 入口时使用；当前可为空
│   ├── application/    # 用例编排
│   ├── domain/         # Agent 领域对象和端口
│   ├── agents/         # LangChain/LangGraph workflow 实现
│   ├── prompts/        # 版本化 prompt 模板
│   ├── tools/          # 工具定义与参数模型
│   ├── infrastructure/
│   │   ├── llm/        # 模型供应商适配
│   │   ├── retrieval/  # 向量/全文检索适配
│   │   └── persistence/
│   └── settings.py
├── tests/{unit,integration}/
├── evals/              # 评测集和跑分脚本
└── scripts/
```

先提交可导入的最小包和依赖/配置约定，不提前选定 LangChain 版本或模型供应商。未来 Agent 作为独立进程运行；Java API 只能通过版本化 HTTP 或消息契约调用它，并在契约中定义认证、超时和不可用错误。这样 Python 依赖升级不会改变 API 的 Maven 构建，也不会把 Agent 的 prompt/eval 资产藏进 Java resources。

### 4. Split ignore rules by ownership

`api/.gitignore` 负责 `target/`、IDE/Maven 元数据、API 本地 profile、OpenAPI 临时输出、日志和本地生成的 devdata。根 `.gitignore` 只保留 `.env*`、`backups/`、操作系统文件、仓库级工具目录等跨项目规则；Agent 自己的缓存、虚拟环境和本地配置写入 `agent/.gitignore`。忽略规则调整时先使用 `git check-ignore -v` 验证，避免把 `agent/src`、测试、prompt、锁文件或 API 文档误忽略。

## Risks / Trade-offs

- [Risk] 现有开发数据库可能没有完整的 `flyway_schema_history`，直接关闭 baseline 选项会阻止启动 → [Mitigation] 迁移前只读检查历史表；对确需接管的库单独执行一次审查过的 baseline，并把结果记录在本地验收文档。
- [Risk] Plugin 表和目录 seed 在产品规格完成前过早固化 → [Mitigation] 本 change 只保留 `plugin` 包和 `seed` 边界，不创建插件 schema 或平台数据；后续切片完成评审后再新增 migration。
- [Risk] `src/main/resources/db/devdata` 会进入 API jar，误放敏感或大体量数据会造成泄露和包膨胀 → [Mitigation] 只允许虚构、轻量、可重复生成的联调数据；生产 profile 不加载该目录，并在构建检查中确认没有敏感字段。
- [Risk] Flyway location 写成 `classpath:db` 会意外执行 devdata → [Mitigation] 所有 profile 显式列出 `classpath:db/migration`，local/test 再按需增加 `classpath:db/devdata`，自动化 fixture 使用测试专用加载路径。
- [Risk] 保留全局本地配置导入会让 prod 或默认启动读到开发配置 → [Mitigation] 删除无条件 import，显式激活 local/test，验证本地文件存在但只激活 prod 或未指定 profile 时不会读取它；额外验证 prod 与开发 profile 混用时不执行 devdata。
- [Risk] 删除隐式本地配置导入后，现有启动命令缺少 profile → [Mitigation] 同步更新 README、IDEA 运行说明和前端同事的联调指引，保留 Testcontainers 动态配置的回归测试。
- [Risk] Python Agent 的目录过早稳定可能限制后续框架选择 → [Mitigation] 只固定端口（应用、基础设施、prompt、tools、eval）和进程边界，不锁定 LangChain/LangGraph、Web 框架或模型供应商。
- [Risk] 根 `.gitignore` 收窄后可能暴露旧本地文件 → [Mitigation] 迁移后分别运行 API、Agent 和根目录的 `git status`/`git check-ignore`，确认敏感配置、备份和构建产物仍被忽略。

## Migration Plan

1. 只读记录当前工作树、`flyway_schema_history`、已执行的 `V1`-`V3` 和现有备份类型，不修改用户未提交的 `.gitignore`/`docs` 内容。
2. 创建 `plugin` 包及其测试镜像，删除 `task`/`subscription` Java 占位包；认证包仅做编译和测试回归。
3. 先移除公共配置中的无条件 local import，再加入按 profile 激活的 Flyway locations；新增生产 migration、`src/main/resources/db/devdata` 和 `src/test/resources/db/fixture` 资源配置并提交共享种子说明。在独立数据库/测试容器上验证 local、test、prod、无 profile 及混合 profile 的加载边界，验证重启和种子内容更新不会重复插入或重置联调数据。
4. 创建 `agent/` 最小 Python 工程和本地忽略规则，运行包导入/静态检查，不启动任何模型服务。
5. 迁移后端专属忽略项到 `api/.gitignore`，收窄根规则，运行 `git check-ignore -v` 并检查 jar 内容确认没有 backup 和 test fixture；确认 devdata 仅按 local/test 显式 profile 使用。
6. 通过 Maven 全量测试、Flyway 验证、Agent 最小检查和 OpenAPI 现有检查后，才开始切片 04；若迁移失败，回滚新增结构和配置文件，不回滚已执行的 Flyway 历史或改写现有认证代码。

## Open Questions

- 未来 Agent 首个业务切片开始时，再决定使用 LangChain、LangGraph 或其他编排库，以及是否需要 FastAPI 入口；这些选择不影响本 change 的目录和进程边界。
- Java 与 Agent 的第一条真实调用链出现时，再决定使用同步 HTTP 还是 RabbitMQ；在此之前不添加对应依赖。
