# SelfMark Agent

这是未来 Python LangChain Agent 的独立工作区。当前只提供包边界和配置约定，不安装 LangChain、模型供应商、向量数据库或 HTTP 框架依赖。

## 目录边界

- `src/selfmark_agent/api/`：未来对外 HTTP 入口
- `src/selfmark_agent/application/`：用例编排
- `src/selfmark_agent/domain/`：领域对象和端口
- `src/selfmark_agent/agents/`：Agent workflow
- `src/selfmark_agent/prompts/`：版本化 prompt
- `src/selfmark_agent/tools/`：工具与参数模型
- `src/selfmark_agent/infrastructure/`：模型、检索和持久化适配
- `tests/`：单元测试和集成测试
- `evals/`：评测集与跑分脚本

## 当前验证

项目约定使用 Anaconda 的 `Agent_python` 环境和 Python `3.13.3`。验证时先在已有环境中选择解释器，不在本 change 中创建环境、安装包或下载依赖：

```powershell
conda activate Agent_python
$env:PYTHONPATH = (Resolve-Path src).Path
python -c "import selfmark_agent; from selfmark_agent.settings import settings; print(selfmark_agent.__version__); print(settings.api_base_url)"
python -m compileall -q src tests
```

如果本地已经安装 `pytest`，也可以运行：

```powershell
python -m pytest
```

当前检查不需要模型 key、外部服务或安装 Agent 依赖。真实配置只放在未跟踪的 `.env` 中，`.env.example` 只提供占位值。LangChain、LangGraph、模型供应商、Milvus/FAISS、BGE、Rerank、Langfuse、FastAPI 和 MCP 依赖由后续 Agent 切片在 `Agent_python` 环境中按需评审和安装。

## Java 集成边界

Java API 与 Agent 未来通过版本化 HTTP 或消息契约集成，不在 Java 进程内导入 Python。每个契约必须明确认证方式、请求超时和 Agent 不可用时返回的可观测错误；API 只能把 Agent 当作独立进程调用，不能假设共享内存、Python runtime 或同步可用。
