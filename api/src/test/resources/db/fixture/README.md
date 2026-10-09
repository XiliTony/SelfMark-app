# 自动化测试 fixture

这里存放只供自动化测试使用的 SQL fixture，不进入生产 jar。测试用例在 Flyway 完成 schema migration 后，通过 `@Sql` 或等价的测试初始化方式显式加载指定 fixture。

fixture 必须使用稳定业务 key 或 guarded insert，不能依赖 `backups/`，也不能复用联调 devdata 中的账号。
