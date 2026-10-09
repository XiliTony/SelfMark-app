# 切片 01：项目骨架 + 基础设施

**类型**: AFK
**覆盖用户故事**: —（基础设施，不直接对应用户故事，是后续所有切片的地基）

## 构建内容

搭建 Spring Boot 3 后端工程骨架，技术栈：Java 21 + Maven + MyBatis-Plus + MySQL 8 + Redis。本切片不含业务逻辑，只产出可启动、可连接数据库/Redis、可统一响应/异常的空骨架。

骨架需要：
- Maven `pom.xml` 声明 Spring Boot 3.x、MyBatis-Plus、MySQL 驱动、Redis 客户端（Spring Data Redis）、JWT 库（如 jjwt）、Lombok、SpringDoc OpenAPI/Knife4j、测试库（Spring Boot Test + Testcontainers + MockMvc）
- Spring Boot 启动类（包根 `com.nortidart.selfmark`）
- `application.yml` 配置：MySQL 连接、Redis 连接、MyBatis-Plus 配置、JWT 密钥与 TTL、服务端口
- 统一响应体封装 `{code: int, msg: string, data: object}`，提供成功/失败静态工厂方法
- 全局异常处理器：捕获参数校验失败（400）、业务异常（自定义 BusinessException 带 code+msg）、未登录/无权限（401/403）、资源不存在（404）、冲突（409）、其他未捕获异常（500），统一走响应体封装
- JWT 工具类骨架：签发与解析方法（HS256 + 服务端密钥 + 7 天 TTL + 带 jti），本切片只产出工具类，不接入业务（业务接入在 Slice 2/3）
- JWT 拦截器骨架：解析 Authorization Bearer 头，校验签名、有效期、解析出 userId，放入请求上下文；本切片只产出拦截器，**不**含 Redis 黑名单逻辑（黑名单在 Slice 3 接入）
- 拦截器注册：所有 `/api/**` 受保护，`/api/auth/register`、`/api/auth/login`、Swagger/Knife4j 路径放行
- CORS 配置：允许前端域名（v1 demo 可放开允许所有 origin，但注释说明生产环境需收紧）
- MyBatis-Plus 配置：分页插件、自动填充（created_at）、驼峰映射
- 项目分层包结构（空目录即可，文件按需建）：`controller/`、`service/`、`service/impl/`、`mapper/`、`entity/`、`dto/`、`config/`、`common/`、`common/exception/`、`common/response/`、`util/`

启动后访问健康检查端点（如 `/actuator/health` 或自定义 `/api/health`）返回 200，证明骨架可启动。

## 验收标准

- [ ] `mvn spring-boot:run` 能成功启动应用，日志无报错
- [ ] 应用启动时能成功连接 MySQL 和 Redis（连接失败应启动失败并报清晰错误）
- [ ] 未携带 token 访问 `/api/**`（非放行路径）返回 `{code:401, msg:"未登录", data:null}`
- [ ] 携带格式错误的 token 返回 `{code:401, msg:"token 无效", data:null}`
- [ ] 携带过期 token 返回 401
- [ ] 携带合法 token（用 JWT 工具手动签发一个测试 token）能访问 `/api/**`，请求上下文里能取出 userId
- [ ] 参数校验失败（如 POST body 缺字段、@NotBlank 触发）返回 `{code:400, msg:"...", data:null}` 而非 Spring 默认错误格式
- [ ] 手动抛 BusinessException(409, "冲突") 返回 `{code:409, msg:"冲突", data:null}`
- [ ] 未捕获的 NullPointerException 等返回 500 而非 Spring 默认错误页
- [ ] 访问 Swagger/Knife4j 文档路径能打开（无需 token）
- [ ] 访问 `/api/health` 返回 200
- [ ] CORS 预检 OPTIONS 请求能正常返回（前端联调不卡）

## 前置依赖

None — can start immediately.

## 参考文档

- [PRD](../PRD.md) — 实现决策章节（技术栈、统一响应体、错误码约定）
- [CONTEXT.md](../../CONTEXT.md) — 术语表
