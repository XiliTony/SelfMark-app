# Spec Delta

## Purpose

为插件市场和后续主系统演进提供稳定、可检查的 Java 模块边界，使认证横向能力保持兼容，旧任务概念不会意外渗入当前插件产品。

## ADDED Requirements

### Requirement: Java domain ownership is explicit
每个业务能力 MUST 由一个领域包负责；当前插件市场及 Installed Plugin 行为 MUST 归属 `plugin` 领域，认证行为 MUST 继续归属 `auth`，跨领域通用响应、异常、用户上下文 MUST 归属 `common`。

#### Scenario: Plugin work is placed in the plugin domain
- **WHEN** 后续切片新增市场、安装、配置、启停或卸载行为
- **THEN** 其 API 契约、持久化模型和业务逻辑都能在 `plugin` 领域边界内找到

#### Scenario: Existing authentication remains owned by auth
- **WHEN** Java 包结构被重新整理
- **THEN** 手机号注册、登录、JWT 校验、登出黑名单和现有 API 路径仍归属 `auth`，并保持既有契约

### Requirement: Legacy domains are removed from the active codebase
旧产品的 `task` 和 `subscription` Java 占位包 MUST 删除；当前插件市场切片 MUST NOT 重新创建它们，也 MUST NOT 把它们作为 Plugin 或 Installed Plugin 的别名。

#### Scenario: Plugin implementation references no legacy market model
- **WHEN** 插件市场切片被编译和测试
- **THEN** 任何插件 endpoint 或持久化操作都不依赖 task 或 subscription 的 entity、mapper 或 service

#### Scenario: Historical v1 documentation remains available
- **WHEN** 开发者需要查看旧任务市场设计
- **THEN** `issues/archive-v1/` 中的历史文档仍可阅读，但不会形成当前 Java 代码包

### Requirement: Cross-cutting dependencies remain one-way
领域代码 MUST 通过稳定契约使用横向基础设施，而 `common` 和 `config` MUST NOT 依赖具体的 plugin、task 或 subscription 实现。

#### Scenario: Shared infrastructure stays reusable
- **WHEN** 新领域被加入
- **THEN** 它可以复用现有 response、exception、user-context、authentication 和 configuration 基础设施，而无需把这些类移动到业务领域包
