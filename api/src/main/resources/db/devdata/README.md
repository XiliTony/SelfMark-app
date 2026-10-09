# 联调开发数据

本目录存放可提交到 GitHub 的虚构联调数据，供 Apifox 和前端本地联调使用。它会随 API jar 打包，但只有显式启用 `local` 或 `test` profile 且未启用 `prod` 时才由 Flyway 加载。

## 测试账号

- 手机号：`13800138001`
- 密码：`Password123`
- 用户名：`联调用户`

账号和密码是公开的开发凭据，只能用于本地联调，不能用于任何真实环境。SQL 中只保存密码的 BCrypt hash。

## 启动

从 `api/` 目录执行：

```powershell
.\mvnw.cmd spring-boot:run "-Dspring-boot.run.profiles=local"
```

本地 MySQL、Redis 和连接配置仍由 `application-local.yml` 提供。该文件不应提交 GitHub。

## 数据规则

- `R__dev_demo_data.sql` 使用稳定手机号和 guarded insert，重复启动不会重复创建账号；Plugin 安装和配置数据留待后续切片定义。
- 只允许提交虚构、轻量、无敏感信息的数据。
- 不把数据库 backup、JWT secret、生产密码或真实用户信息放入本目录。
- 修改联调数据时，不能覆盖开发者已经修改的密码或插件配置。
