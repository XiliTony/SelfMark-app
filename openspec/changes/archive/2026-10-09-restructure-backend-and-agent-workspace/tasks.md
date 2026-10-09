# Tasks

## 1. Confirm the current baseline and Java package boundaries

- [x] 1.1 记录当前工作树变更、Flyway 历史和现有 `V1`-`V3` 的校验和，保留用户已有的 `.gitignore` 或 `docs/` 改动；确认记录可用于迁移审查。
- [x] 1.2 新增 `plugin` 领域包，包含 `controller`、`dto`、`entity`、`mapper`、`service` 和 `seed` 边界及对应的测试包目录；确认目录结构符合设计，且 `api` 仍可编译。
- [x] 1.3 删除 `task` 和 `subscription` Java 占位包并更新包引用；确认 `后端项目文档/skill/issues/archive-v1/` 历史文档仍保留，当前代码不再引用已删除的领域包。
- [x] 1.4 完成包结构调整后，运行现有认证、健康检查和基础设施测试；确认手机号登录、JWT 黑名单、Redis key 和响应契约的测试仍通过。

## 2. Separate Flyway migration and environment data

- [x] 2.1 保持 `V1`-`V3` 不变并固定生产 migration 边界；确认全新 MySQL 数据库仅通过 Flyway 生成当前已定义 schema，Plugin 表和目录 seed 留待后续产品规格完成后新增 migration。
- [x] 2.2 创建 `api/src/test/resources/db/fixture` 存放自动化测试 fixture，并配置测试加载方式；确认 Testcontainers 或项目集成测试加载稳定的 fixture，且不读取 `backups/`。
- [x] 2.3 创建 `api/src/main/resources/db/devdata` 存放轻量、虚构的 Apifox/本地联调数据，将共享 SQL 和 README 纳入 GitHub；确认测试密码对应的 BCrypt hash 可用于登录，共享种子没有真实用户数据或生产凭据，生产配置只列出 `classpath:db/migration`。
- [x] 2.4 devdata 使用 Flyway repeatable SQL 和仅补齐缺失行的 guarded insert，测试 fixture 按用例幂等初始化；确认重启不产生重复数据，种子内容更新后也不重置已修改的联调账号密码或插件配置。
- [x] 2.5 按设计统一 Flyway 校验配置（`validate-on-migrate`、`clean-disabled`、`out-of-order=false` 和经过审查的 baseline 策略）；确认在决定是否 baseline 前，已检查现有数据库的 `flyway_schema_history`。
- [x] 2.6 更新后端数据生命周期文档，区分 migration、`db/devdata`、测试 fixture 和带日期的 backup；确认 `backups/selfmark-data-*.sql` 被明确描述为人工恢复输入，不作为应用启动 seed。
- [x] 2.7 删除 `application.yml` 中无条件导入 `application-local.yml` 的配置，不默认激活 local；公共配置明确只加载 migration，通过 `spring.config.activate.on-profile: "(local | test) & !prod"` 为开发环境增加 devdata；确认共享种子规则受版本控制，只有显式启用 local 时才自动读取本地连接文件。
- [x] 2.8 增加 profile 配置与种子加载的正向、负向测试，覆盖 local、test、prod、无 profile 及 prod 与开发 profile 混用；使用临时本地配置标记确认 prod/默认/test 不读取 local，使用独立数据库确认 prod 不插入开发账号、混用时不执行 devdata，并确认现有 Testcontainers 认证测试不依赖本地配置。
- [x] 2.9 更新 README、devdata README 和 IDEA 运行说明，给出从 `api/` 执行 `.\mvnw.cmd spring-boot:run "-Dspring-boot.run.profiles=local"` 的启动方式、生产 profile 用法及公开测试账号；确认前端同事按文档即可复现联调数据，不需要手工导入 backup。

## 3. Add the Python Agent workspace boundary

- [x] 3.1 按约定的包边界创建最小 `agent/` 工程，包含 `pyproject.toml`、`.env.example`、README、`src/selfmark_agent`、tests、evals 和 scripts；确认无需启动模型服务即可导入 Python 包。
- [x] 3.2 为 Agent 增加配置和 secret 加载约定，提交的示例仅使用占位值；通过仓库扫描确认 `agent/` 中不存在真实模型 key 或数据库凭据。
- [x] 3.3 在文档中明确，LangChain/LangGraph、模型供应商、向量存储和 HTTP 框架依赖由后续 Agent 切片按需引入；确认 Agent 骨架不改变 `api/pom.xml` 和 API 构建流程。
- [x] 3.4 记录未来 Java 到 Agent 的集成边界，包括版本化 HTTP/消息契约、认证、超时和服务不可用时的行为；确认文档没有隐含的进程内 Python 依赖。

## 4. Reassign ignore-rule ownership

- [x] 4.1 将后端专属的生成文件、本地配置、IDE 元数据、日志、OpenAPI 临时文件和个人临时数据的忽略规则迁移到 `api/.gitignore`；从仓库根运行 `git check-ignore -v`，确认目标文件被正确忽略，而受版本控制的 `src/main/resources/db/devdata` SQL 和 README 不被忽略。
- [x] 4.2 将根 `.gitignore` 收窄为仓库级规则，继续忽略环境文件和数据库 backup；确认正常的 `agent/src`、tests、prompts、docs 和 lock 文件仍对 Git 可见。
- [x] 4.3 为 Agent 增加虚拟环境、缓存、日志和本地 secret 的忽略规则；确认 `.env.example`、源码、tests、prompts 和依赖 lock 文件不会被忽略。
- [x] 4.4 将最终忽略规则变更与用户现有未提交的 `.gitignore` 和 `docs/` 改动进行核对；确认没有删除或覆盖无关的用户改动。

## 5. Integrated verification and handoff

- [x] 5.1 构建 API，运行完整 Maven 测试套件和 OpenAPI 检查；确认认证回归测试与新增 migration/资源测试全部通过。
- [x] 5.2 检查生成的 API jar 和测试资源；确认生产产物包含 migration，不包含测试 fixture 和 backup，且只有显式启用 local/test profile 时才加载 `db/devdata`。
- [x] 5.3 使用项目选定的 Python runtime 运行最小 Agent 包导入和静态检查；确认检查不需要模型凭据或运行中的外部服务。
- [x] 5.4 最后运行 `git status`、`git diff --check` 和 OpenSpec 校验；确认 change 已准备好衔接切片 04-08 的实现流程，当前未实现 Plugin 业务接口或提前固化 Plugin 表设计。
