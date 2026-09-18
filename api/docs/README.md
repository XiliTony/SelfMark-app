# API 契约与前端交付物

此目录集中保存 SelfMark 的 OpenAPI 维护源、生成结果、Apifox 导出文件和错误码表：

- `openapi/openapi.yaml`：模块化 OpenAPI 维护源入口。
- `openapi/paths/`、`openapi/components/`：按业务模块拆分的契约源文件。
- `openapi/dist/selfmark.openapi.yaml`：由 `api/check-api.sh` 生成的 bundle，供校验和导入 Apifox 使用，禁止手工修改。
- `openapi/dist/selfmark.openapi.json`：从 Apifox 重新导出的前端联调快照。
- `error-codes.md`：按业务模块维护的错误码和稳定错误消息。

认证模块字段约定：请求、响应和 JWT 自定义 claim 统一使用 `mobile` 表示登录手机号；`username` 仅表示用户展示名，不可用于登录。

Apifox 的受保护接口统一使用 Bearer Auth，Token 值为环境变量 `{{bearerToken}}`。变量本地值只填写 JWT 本身，不含 `Bearer ` 前缀；Auth 面板会自动生成 `Authorization` 请求头，Headers 面板不得重复维护该请求头。

每次接口变更后，先更新模块源文件和 `error-codes.md`，执行 `api/check-api.sh`，再将 YAML bundle 导入 Apifox。完成 Review 和接口测试后，从 Apifox 重新导出 JSON 覆盖 `openapi/dist/selfmark.openapi.json`。

维护源和当前 Apifox 导出文件均使用 OpenAPI 3.0.3。即使后续 Apifox 导出版本发生变化，也不得用导出 JSON 反向覆盖维护源；YAML 与 JSON 的接口字段、必填项和响应语义必须一致。

错误响应不能让所有 HTTP 状态共用一个带固定 `code` 示例的 schema。共享的 `ApiResponseError` 只定义基础结构，各 HTTP response 引用按状态拆分的 schema（例如 `ApiResponseBadRequest`、`ApiResponseUnauthorized`、`ApiResponseConflict`），并在接口响应处提供与业务场景匹配的完整示例。这样 Apifox 展示和契约校验都不会把 400、401、409 混淆。
