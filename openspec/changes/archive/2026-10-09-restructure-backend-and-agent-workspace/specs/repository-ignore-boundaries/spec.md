# Spec Delta

## Purpose

让仓库根目录、Java API 和未来 Python Agent 各自负责自己的忽略规则，防止构建产物、秘密配置、备份和本地工具文件进入版本库或误伤其他项目。

## ADDED Requirements

### Requirement: Backend-local files are ignored by api/.gitignore
只由 Java API 产生或使用的构建输出、IDE 元数据、Maven wrapper 缓存、运行日志、本地 profile 配置、OpenAPI 临时文件和本地生成的 devdata MUST 在 `api/.gitignore` 中声明；受版本控制的 `src/main/resources/db/devdata` 联调数据不得被该规则误忽略。

#### Scenario: A developer builds and runs the API locally
- **WHEN** Maven、IDE 或 local profile 生成文件
- **THEN** `git status` 不会把这些 backend-local files 暴露为待提交文件

### Requirement: Root ignore rules remain repository-wide
根 `.gitignore` MUST 只承担跨项目或仓库级文件的忽略职责，例如环境文件、操作系统文件、backups 和明确的根级工具目录；迁移后不得使用会误伤 `agent/` source 或 test resources 的过宽后端规则。

#### Scenario: The Agent project adds normal source files
- **WHEN** Python source、tests、prompts 或 lock files 在 `agent/` 下创建
- **THEN** 除非它们被明确分类为 generated 或 secret local data，否则仍然对 Git 可见

### Requirement: Secrets and snapshots never become commit candidates
本地数据库连接配置、JWT secret、模型 API key、带业务数据的 SQL 快照和运行时凭据 MUST 被忽略，并且仓库中只保留脱敏的 example/template 文件。

#### Scenario: A dated database dump is created
- **WHEN** backup 写入 repository 的 backup location
- **THEN** 它被忽略，且不会被复制到 `api` resources 或 Agent project
