# 切片 02：用户注册 + 登录闭环

**类型**: AFK
**覆盖用户故事**: #1, #2, #3, #4

## 构建内容

实现用户注册和登录的端到端闭环：前端调用 → DB 写入/查询 → 返回 JWT。本切片引入第一张业务表 `user`，并接入 Slice 01 的 JWT 工具实际签发 token。

数据模型（user 表，schema 决策精确表达）：

```
user
- id              BIGINT PK AUTO_INCREMENT
- mobile          VARCHAR(20)  NOT NULL UNIQUE -- 登录账号
- password        VARCHAR(100) NOT NULL  -- bcrypt 加密后
- username        VARCHAR(50)  NOT NULL -- 用户展示名
- created_at      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP
```

行为：

- `POST /api/auth/register`：body `{mobile, password, username}`。mobile 是登录手机号，校验为中国大陆手机号且不可重复（重复返回 409）；password 用 bcrypt 加密存入；username 是必填展示名。注册成功后直接返回 `{id, mobile, username, token}`（注册即登录）。
- `POST /api/auth/login`：body `{mobile, password}`。按 mobile 查询用户（不存在 401）；用 bcrypt 校验密码（错 401）；通过后签发 JWT（含 jti、userId、mobile、TTL 7 天），返回 `{id, mobile, username, token}`。
- 认证响应使用白名单 DTO，**不包含 password 字段**。
- JWT 签发：HS256 + 服务端密钥（application.yml 配置），claim 包含 `sub=userId`、`jti=UUID`、`exp=7天后`。
- 测试用例可以创建用户、登录拿 token、用 token 访问受保护接口。

## 验收标准

- [x] `POST /api/auth/register` 带合法 mobile+password+username 成功，返回 `{code:200, data:{id, mobile, username, token}}`
- [x] 注册时 mobile 重复返回 `{code:409, msg:"手机号已注册"}`
- [x] 注册时 mobile/password/username 缺失或手机号格式错误返回 400
- [x] DB 中 password 字段是 bcrypt 哈希（明文不可见、不可还原）
- [x] 返回的 user DTO 不含 password 字段
- [x] `POST /api/auth/login` 带正确 mobile+password 成功，返回 `{id, mobile, username, token}`
- [x] 登录时 mobile 不存在返回 401
- [x] 登录时密码错误返回 401
- [x] 注册拿到的 token 能用于访问 `/api/**` 受保护接口（拦截器解析出 userId）
- [x] 登录拿到的 token 能用于访问 `/api/**` 受保护接口
- [x] token 过期后访问受保护接口返回 401

## 后续演进边界

- v1 只实现手机号+密码，不发送或校验短信验证码。
- 后续短信验证码可使用 Redis 保存短期验证码和频控状态，RabbitMQ 异步发送短信；认证接口仍以 mobile 作为稳定账号标识。

## 前置依赖

- Slice 01（骨架 + JWT 工具 + 拦截器 + 全局异常 + 统一响应体）

## 参考文档

- [PRD](../PRD.md) — 用户故事 #1-#4、API 契约、数据模型 schema
- [CONTEXT.md](../../CONTEXT.md) — 术语表
- [完成方案](../solutions/slice-02-register-login-solution.md) — 前端契约、安全设计、迁移与测试结论
