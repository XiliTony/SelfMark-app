# Spec Delta

## Purpose

为未来使用 Python LangChain 构建 Agent、工具调用、检索和评测提供独立且可扩展的工作区，同时保持当前 Java API 可单独构建、测试和部署。

## ADDED Requirements

### Requirement: The Python Agent is a separate runtime boundary
Agent 代码 MUST 位于独立的 Python 项目边界中，拥有自己的依赖声明、配置入口、源码包和测试；Java API 构建 MUST 不需要 Python、LangChain 或其虚拟环境。

#### Scenario: The API is built without the Agent environment
- **WHEN** 开发者运行 API Maven build 和现有认证测试
- **THEN** build 在不安装 Python package、不启动 Agent service 的情况下成功

#### Scenario: The Agent dependency set changes
- **WHEN** LangChain 或 model provider dependency 被新增或升级
- **THEN** 只有 Agent project 的 dependency lock/configuration 改变，除非另有明确的 API integration contract

### Requirement: Agent responsibilities have stable package seams
Agent project MUST 为 application entrypoints、domain use cases、model/retrieval infrastructure、prompts/tools 和 tests/evaluations 保留独立边界；prompt 文本和 evaluation fixture MUST NOT 隐藏在 Java resources 中。

#### Scenario: A new tool-using agent is added
- **WHEN** 未来功能新增 Agent workflow
- **THEN** orchestration、tools、prompts、provider adapters 和 evaluation cases 可以在 Python project 的对应边界内独立修改

### Requirement: Java-Agent integration is explicit
任何 Java 到 Agent 的调用 MUST 使用写明 authentication、timeout 和 failure behavior 的版本化 HTTP 或 messaging contract；任何 source package 都不得 import Python file 或假设进程内 Python runtime。

#### Scenario: The API delegates an AI request
- **WHEN** 后续产品切片引入 Agent delegation
- **THEN** API 调用一个 versioned external boundary，并把 Agent 不可用作为明确的 integration failure 处理

### Requirement: Agent secrets stay environment-bound
Model key、database credential、vector-store credential 和 runtime endpoint MUST 来自 environment 或 ignored local configuration；纳入 source control 的 example MUST 只包含 placeholder。

#### Scenario: A developer configures a local model provider
- **WHEN** 开发者在本地启动 Agent
- **THEN** Agent 从 local environment/configuration 读取 provider key，repository 中不存在真实 secret
