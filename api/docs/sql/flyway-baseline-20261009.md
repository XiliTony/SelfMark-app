# Flyway 基线记录（2026-10-09）

本记录对应 change `restructure-backend-and-agent-workspace` 实施前的 Git 基线：

- Git commit：`39596862ca63be88dafa4085e02aa967e390793a`
- 已存在 migration：`V1`、`V2`、`V3`
- 本记录不修改既有 migration 文件；插件表和插件目录 seed 留待后续切片完成设计后再新增 migration。

实施前工作树审查记录：用户已有的根 `.gitignore` 和 `docs/` 改动被保留；本 change 仅在其上新增后端结构、资源、测试、Agent 和 OpenSpec 文件。实施期间使用 `git status --short` 与 `git diff --name-status 39596862ca63be88dafa4085e02aa967e390793a` 复核范围，未对无关文件执行回滚。

| 文件 | SHA-256 |
| --- | --- |
| `V1__create_user_table.sql` | `4E039B69E64F64446173F26E2ED2A26AD3E89E0D09DD2B4197986C7D5C8F69B4` |
| `V2__use_mobile_as_login_account.sql` | `5EC678BF4618463B7867C840BCE9995C65C96C2756CD57BDC9044C27DEE9C308` |
| `V3__clean_legacy_accounts_and_narrow_mobile.sql` | `0CA517CBD073BD45612629A20D0199BC71A46AB8A6D0BCB74FC10198B0B10852` |

执行 baseline 或接管已有数据库前，必须先只读检查目标库的 `flyway_schema_history`。日常开发不使用 `baseline-on-migrate` 自动接管数据库。

本 change 的 Testcontainers 认证回归在空数据库上验证了 `flyway_schema_history` 依次记录 V1、V2、V3；该容器数据库为临时验证实例，不作为开发或生产 baseline。现有数据库接管仍必须先执行 `SELECT * FROM flyway_schema_history ORDER BY installed_rank` 并人工审查结果。
