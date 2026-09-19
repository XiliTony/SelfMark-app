# Slice 03 完成方案：登出与 JWT 黑名单

## 完成状态

- 完成日期：2026-09-12
- 接口：`POST /api/auth/logout`
- 存储：Redis DB 0，key=`selfmark:auth:jwt:blacklist:{jti}`，value=`1`
- 失效规则：TTL 等于 JWT 的 `exp - 登出时间`
- 验收：已使用 Apifox、Navicat 和 Another Redis Desktop Manager 手动验证

## 2026-09-17 前后端联调变更审查与决策

- `JwtAuthenticationInterceptor` 使用 `CorsUtils.isPreFlightRequest` 放行浏览器 CORS 预检请求，与现有 Spring MVC CORS 配置兼容；仍需补一个受保护路径的 OPTIONS 自动化测试。
- Redis 内存降级已移除。Redis 是 JWT 黑名单的运行依赖，写入或查询失败时直接失败并由统一异常处理返回 500，不能用进程内 Map 代替共享黑名单。
- 这是安全边界而不是可选性能优化：本地 Map 无法覆盖 Redis 中已有的 jti，也无法在多实例间同步；fail-open 会让已登出的 token 重新有效。
- 前端本地联调需要先启动 Redis；不为“未安装 Redis”增加生产代码分支。可通过 Docker Compose 启动标准 Redis 服务。
- 现已补充 Redis 失败时 fail-closed 的单元测试；Docker 可用后仍需执行 Redis + MySQL 集成测试。

## 接口与 Apifox 认证配置

登出和其他受保护接口使用标准请求头 `Authorization: Bearer <jwt>`。在 Apifox 中统一使用接口的 Auth 面板：类型选 Bearer Token，值设为 `{{bearerToken}}`；环境变量 `bearerToken` 的本地值只填写登录响应中的原始 token，不包含 `Bearer ` 前缀。

Auth 面板会自动生成请求头，因此 Headers 面板不要再手工添加 `Authorization`。若两处同时配置，可能产生重复 Header 或因两份 token 不一致导致难以定位的 401。模块化 OpenAPI 中的 `bearerAuth` 是标准安全定义，bundle 导入 Apifox 后应由 Auth 面板接管。

成功响应：

```json
{
  "code": 200,
  "msg": "success",
  "data": null
}
```

## 实现方案

- JWT 签发时包含唯一 `jti` 和过期时间 `exp`。
- 拦截器先调用 JWT verifier 校验签名和有效期；过期或非法 token 直接返回 401，不访问 Redis。
- JWT 有效后，拦截器只按 jti 查询 Redis；命中黑名单返回 401，否则建立当前用户上下文。
- 登出接口从当前用户上下文取得 jti 和原始 token，将 `selfmark:auth:jwt:blacklist:{jti}=1` 写入 Redis。
- Redis TTL 使用登出时计算的 token 剩余有效秒数。TTL 到期后 key 自动消失，不保存完整 token，也不使用数据库兜底。
- Redis 不可用时认证链路不能放行无法确认状态的 token；当前实现保持 fail-closed。

## 验收结论

- 登出前使用 token 访问 `/api/users/me` 返回 200。
- 携带有效 token 调用 `/api/auth/logout` 返回 200。
- Another Redis Desktop Manager 可看到 `selfmark:auth:jwt:blacklist:{jti}`、value=`1` 和正数 TTL。
- 登出后使用同一 token 访问受保护接口返回 401，重复登出也返回 401。
- 使用短 TTL token 验证：未登出的过期 token 由 JWT 校验返回 401；登出 key 在 TTL 到期后由 Redis 自动删除。

## 数据库与配置

- Slice 03 不新增业务表，黑名单只存 Redis。
- V2 将登录账号迁移为 mobile；V3 在开发早期清理旧账号数据并将 `mobile` 收窄为 `VARCHAR(20)`。
- 正式 JWT TTL 保持 `7d`。`20s` 或 `30s` 只用于临时手测，不提交到正式配置。

## 自动化验证

- 单元测试验证黑名单 key、value 和剩余 TTL 写入规则，以及查询只访问 Redis。
- HTTP 实测覆盖登出前 200、登出 200、旧 token 再访问 401。
- Testcontainers 集成测试依赖 Docker Engine；提交或 CI 验收时应在 Docker 可用环境运行完整测试。

## 简历技术描述（Slice 03）

实现 JWT 登出闭环：拦截器先校验签名与 exp，再以 jti 查询 Redis 黑名单；登出仅写入 `selfmark:auth:jwt:blacklist:{jti}`，并将 TTL 设置为 token 剩余有效期，使旧 token 立即返回 401、黑名单到期自动清理，避免数据库存储和垃圾 key。
