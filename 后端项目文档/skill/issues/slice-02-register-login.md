# 切片 02：用户注册 + 登录闭环

**类型**: AFK
**覆盖用户故事**: #1, #2, #3, #4

## 构建内容

实现用户注册和登录的端到端闭环：前端调用 → DB 写入/查询 → 返回 JWT。本切片引入第一张业务表 `user`，并接入 Slice 01 的 JWT 工具实际签发 token。

数据模型（user 表，schema 决策精确表达）：

```
user
- id              BIGINT PK AUTO_INCREMENT
- username        VARCHAR(50)  NOT NULL UNIQUE
- password        VARCHAR(100) NOT NULL  -- bcrypt 加密后
- nickname        VARCHAR(50)  NULL
- created_at      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP
```

行为：

- `POST /api/auth/register`：body `{username, password, nickname?}`。校验 username 不为空、不重复（重复返回 409）；password 用 bcrypt 加密存入；nickname 可选。注册成功后**直接返回 token + user 信息**（注册即登录，无需再调一次 login）。
- `POST /api/auth/login`：body `{username, password}`。校验用户存在（不存在 401）；用 bcrypt 校验密码（错 401）；通过后签发 JWT（含 jti、userId、username、TTL 7 天）返回 token + user 信息。
- user 信息返回时**不包含 password 字段**（DTO 层屏蔽）。
- JWT 签发：HS256 + 服务端密钥（application.yml 配置），claim 包含 `sub=userId`、`jti=UUID`、`exp=7天后`。
- 测试用例可以创建用户、登录拿 token、用 token 访问受保护接口。

## 验收标准

- [ ] `POST /api/auth/register` 带合法 username+password 成功，返回 `{code:0, data:{token, user:{id, username, nickname}}}`
- [ ] 注册时 username 重复返回 `{code:409, msg:"用户名已存在"}`
- [ ] 注册时 username 或 password 缺失返回 400
- [ ] DB 中 password 字段是 bcrypt 哈希（明文不可见、不可还原）
- [ ] 返回的 user DTO 不含 password 字段
- [ ] `POST /api/auth/login` 带正确 username+password 成功，返回 token + user
- [ ] 登录时 username 不存在返回 401
- [ ] 登录时密码错误返回 401
- [ ] 注册拿到的 token 能用于访问 `/api/**` 受保护接口（拦截器解析出 userId）
- [ ] 登录拿到的 token 能用于访问 `/api/**` 受保护接口
- [ ] token 过期后访问受保护接口返回 401

## 前置依赖

- Slice 01（骨架 + JWT 工具 + 拦截器 + 全局异常 + 统一响应体）

## 参考文档

- [PRD](../PRD.md) — 用户故事 #1-#4、API 契约、数据模型 schema
- [CONTEXT.md](../../CONTEXT.md) — 术语表
