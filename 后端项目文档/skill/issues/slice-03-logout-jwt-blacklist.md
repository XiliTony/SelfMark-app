# 切片 03：登出 + JWT 黑名单

**类型**: AFK
**覆盖用户故事**: #5, #6

## 构建内容

在 Slice 01 的 JWT 拦截器基础上接入 Redis 黑名单，实现"登出后 token 立即失效"。本切片用 Redis 存黑名单，拦截器每次请求查一次。

行为：

- `POST /api/auth/logout`：需要鉴权。把当前 token 的 jti 加入 Redis 黑名单，key=`blacklist:{jti}`，value 任意（如 `1`），**TTL = token 剩余有效期**（即 `exp - now`，过期后自然消失）。返回成功即可。
- 修改 Slice 01 的 JWT 拦截器：在签名/有效期校验通过后，**额外查 Redis 黑名单**——如果 `blacklist:{jti}` 存在，返回 401。
- 黑名单只存 jti，不存整个 token（节省 Redis 内存）。
- 测试：登出后用旧 token 访问受保护接口返回 401；登出前 token 正常可用。

## 验收标准

- [ ] `POST /api/auth/logout` 携带合法 token 返回成功
- [ ] 登出后 Redis 里 `blacklist:{jti}` 存在
- [ ] 登出后用旧 token 访问 `/api/**` 返回 401
- [ ] 登出前同一 token 能正常访问
- [ ] TTL 设置正确：等于 token 剩余有效期（过期后 key 自动消失，不留垃圾）
- [ ] 黑名单查询走 Redis（不能用 DB 兜底，性能要求）
- [ ] 黑名单 key 命中率合理：登出的 token 黑名单 TTL 到期自动清理
- [ ] 未登出的 token 即使过期也是过期 401，不会因为黑名单逻辑出错
- [ ] 拦截器顺序：先查黑名单还是先查过期？应先查签名+过期（过期直接 401，不必查 Redis），再查黑名单（减少 Redis 调用）

## 前置依赖

- Slice 02（注册/登录 + JWT 签发 + user 上下文）

## 参考文档

- [PRD](../PRD.md) — 用户故事 #5、#6，实现决策 #9（JWT 单 token + Redis 黑名单）
- [CONTEXT.md](../../CONTEXT.md) — 术语表
