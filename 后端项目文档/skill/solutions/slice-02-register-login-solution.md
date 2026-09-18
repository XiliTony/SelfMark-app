# Slice 02 完成方案：手机号注册登录

## 完成状态

- 完成日期：2026-09-12
- 接口：`POST /api/auth/register`、`POST /api/auth/login`、`GET /api/users/me`
- 账号规则：`mobile` 是唯一登录手机号，请求、响应、JWT claim 和数据库列统一使用该名称；`username` 是展示名
- 认证方式：手机号 + 密码，注册成功即登录并签发 JWT

## 前端接口契约

注册请求：

```json
{
  "mobile": "13800138000",
  "password": "Password123",
  "username": "小明"
}
```

登录请求：

```json
{
  "mobile": "13800138000",
  "password": "Password123"
}
```

注册和登录成功响应的 `data` 相同：

```json
{
  "id": 1,
  "mobile": "13800138000",
  "username": "小明",
  "token": "eyJ..."
}
```

前端保存 token，后续受保护请求携带 `Authorization: Bearer <token>`。`mobile` 用于显示登录手机号，`username` 用于显示用户名称；前端不可把 username 当作登录凭证。

## 数据与安全方案

- `user.mobile VARCHAR(20) NOT NULL UNIQUE`：数据库唯一索引是并发注册的最终防线。
- `user.username VARCHAR(50) NOT NULL`：只承载展示名称，不要求唯一。
- password 使用 BCrypt 盐化哈希，数据库不保存明文；请求最多 72 个 UTF-8 字节。
- 登录账号不存在和密码错误统一返回 `手机号或密码错误`，降低账号枚举风险。
- 认证响应使用白名单 DTO，只暴露 `id/mobile/username/token`，实体 password 不参与序列化。
- JWT 使用 HS256，包含 `sub=userId`、`userId`、`mobile`、`jti`、`iat`、`exp`，TTL 为 7 天。

## 数据库迁移

- V1 创建初始 user 表。
- V2 将旧登录字段 `username` 改为 `mobile`，旧 `nickname` 改为展示字段 `username`，并将唯一索引迁移为 `uk_user_mobile`。
- 已有展示名为空时，V2 使用原登录账号回填，保证升级为 `username NOT NULL`。
- Flyway 在应用启动时按版本执行，避免依赖 Navicat 手工同步生产结构。

## 自动化验证

- 单元测试覆盖 BCrypt 哈希、正确密码登录、重复手机号、并发唯一键冲突、账号不存在和密码错误。
- 参数测试覆盖 bcrypt UTF-8 字节上限。
- Testcontainers + MySQL 覆盖 HTTP 注册/登录、Flyway、真实落库、DTO 脱敏和 token 经过拦截器访问 `/api/users/me`。
- Docker 不可用时集成测试会跳过；提交或 CI 验收应在 Docker 可用环境运行一次完整测试。

## 短信验证码演进

当前切片不实现验证码。后续可以保持 mobile 账号模型不变，并增加：

1. Redis 保存验证码、发送频控、错误次数和短 TTL。
2. RabbitMQ 接收短信发送任务，异步调用短信供应商并支持有限重试与死信处理。
3. 验证成功后原子删除验证码，防止重复使用。

RabbitMQ 只解耦短信发送，验证码校验的真值和过期控制仍由 Redis/认证服务负责。

## 简历技术描述（Slice 02）

基于 Spring Boot、MyBatis-Plus 和 MySQL 实现手机号注册登录闭环，使用 BCrypt 盐化哈希、白名单 DTO 与统一认证错误提示保护凭证安全，基于 HS256 JWT/MVC 拦截器实现无状态鉴权，并通过 Flyway、数据库唯一约束及 Testcontainers 保障并发注册和端到端认证链路一致性。
