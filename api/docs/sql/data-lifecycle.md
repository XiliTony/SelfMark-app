# 数据库资源生命周期

## 目录职责

| 目录 | 用途 | 是否进入 API jar | 是否生产启动加载 |
| --- | --- | --- | --- |
| `src/main/resources/db/migration` | 生产 schema、索引和约束；后续明确为生产必需的数据也在此版本化 | 是 | 是 |
| `src/main/resources/db/devdata` | Apifox/前后端联调的虚构数据与公开测试账号 | 是 | 否，只有 local/test 且未启用 prod 时加载 |
| `src/test/resources/db/fixture` | 自动化测试用例的独立 fixture | 否 | 否，测试通过 `@Sql` 等方式显式加载 |
| 根目录 `backups/` | 本地或运维恢复输入 | 否 | 否，不能加入 Flyway locations |

旧 v1 切片的历史文档保留在 `后端项目文档/skill/issues/archive-v1/`，只用于查阅，不构成当前 Java 包。

## Profile 规则

公共 `application.yml` 不导入 `application-local.yml`。本地配置只有在显式激活 `local` 时才会由 Spring Boot profile 文件规则加载：

```powershell
.\mvnw.cmd spring-boot:run "-Dspring-boot.run.profiles=local"
```

生产启动使用 `prod` profile，连接凭据从外部配置或环境变量提供。默认和 `prod` 只使用 `classpath:db/migration`；`local`/`test` 且未启用 `prod` 时才增加 `classpath:db/devdata`。

## 数据规则

- 生产 migration 使用 `V<版本>__<描述>.sql`，已执行文件不得修改。
- 联调数据使用 Flyway repeatable SQL，例如 `R__dev_demo_data.sql`，并使用 guarded insert，不覆盖开发者已经修改的密码或未来插件配置。
- 自动化测试 fixture 不依赖备份，不复用联调账号；测试用例负责显式加载并清理自己的数据。
- 备份文件只用于人工恢复。恢复前先让当前 API/Flyway 建立并验证 schema，再显式导入与当前 schema 匹配的备份。
