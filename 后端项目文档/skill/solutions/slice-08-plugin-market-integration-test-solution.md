# Slice 08 完成方案：真实集成闭环和最终验收

完成日期：2026-10-15。对应 OpenSpec `complete-plugin-backend-slices-04-08` 任务5.1到5.7。切片08的7项交付完成，总change进度26/26；用户commit、push、draft PR及Apifox操作独立于任务checkbox。

## 交付范围

新增独立 `PluginIntegrationTests`，通过真实 MySQL 8.4、Redis 7.4-alpine 和生产 Flyway V1到V5验证全部插件生命周期。HTTP层使用完整 SpringBootTest + MockMvc，调用真实JWT拦截器、Controller、Service、mapper和数据库，没有替换或mock插件bean。

本切片新增7个用例，既有切片04到07的19项真实数据库用例及1项迁移/seed测试继续执行。插件业务代码、五个接口、MySQL字段及索引/约束没有新增变更。

为执行任务指定的Windows Maven Wrapper命令，修复 `api/mvnw.cmd` 对普通 `.m2` 目录的空 `Target` 直接索引问题：先判空，再决定使用目录路径或链接目标。保留wrapper指定的Maven3.9.16、pom和依赖版本。

## 独立测试数据

测试显式启用prod，限定 `classpath:db/migration`，为测试指定独立JWT secret和容器连接参数；不依赖local配置、devdata联调账号、备份或开发数据库。

每个用例使用自己的手机号注册，再调用登录获取token；A/B用例分别注册两个用户。记录创建的user ID，`@AfterEach` 按这些ID先删除user_plugin，再删除user。没有truncate、重置自增或清理生产plugin seed，也不依赖测试执行顺序。Redis只使用该测试类的临时容器，测试结束后由Testcontainers回收。

所有响应读取均断言HTTP状态与body code一致，成功msg为success、data键存在，失败data显式null。配置在HTTP与数据库回读时解析成JsonNode比较，避免用JSON键顺序或原始字符串作验收依据。

## 新增用例与边界

| 用例 | 实际验收内容 |
| --- | --- |
| `boardLifecycleRunsFromRegistrationThroughReinstall` | 注册/登录；市场恰好两条且均未安装；画板完整默认quadrant/pyramid；改轴和区域名称后回读；显式提交两结构并切pyramid；禁用/启用保留配置；物理卸载及市场null状态；重装新ID及完整默认值 |
| `pomodoroPersistsItsLabelAndOwnershipIsIsolated` | 默认对象 `{"label":"专注"}`；更新label及未知字段后GET/数据库一致；B市场仍未安装，附加A的userId也无效；B配置/启停/卸载A实例全部403，每次失败后A整行不变 |
| `allFiveRoutesRejectMissingAndLoggedOutTokensWithoutChangingData` | 五个插件接口逐一缺token401；真实登出写Redis黑名单后同一token再次访问五接口均401/token已登出；实例整行及用户实例数不变 |
| `concurrentInstallationsHaveOneWinnerAndOneConflict` | 两个独立MockMvc请求线程，CyclicBarrier同时放行；真实事务安装，一次200、一次409/插件已安装，最终只有一行且保留默认配置/enabled=true |
| `concurrentConfigAndEnabledUpdatesKeepBothCommittedFields` | 两线程经屏障同时发config PUT和禁用PUT；两个HTTP200，完成后SQL和GET均有完整新配置及enabled=false |
| `deletionCommittedBeforeUpdatesDoesNotResurrectTheInstance` | 两个请求线程；CountDownLatch在卸载请求完成后放行更新线程；config/enabled旧ID均404，旧行不存在且没有替代实例，市场恢复未安装 |
| `rebuildingApplicationContextPreservesSeedIdsAndUserState` | 同一MySQL/Redis容器持续运行；独立应用上下文中注册/登录、安装、修改配置及禁用，实际关闭并确认inactive；启动第二上下文后用其连接池和HTTP层核对code/ID、目录数量、完整config、enabled及原实例ID，未导入devdata账号 |

并发测试通过不同工作线程进入JWT上下文及Service事务，连接由Spring事务/Hikari管理；测试方法没有外层事务，也没有共享或手动设置UserContext。屏障只协调请求开始，不固定两个请求获取数据库锁的先后顺序。安装唯一冲突分支仍由既有Service测试稳定覆盖，HTTP竞争用例断言最终200/409及单行不变量。

卸载先完成的测试用明确完成信号控制时序，不用sleep。先完成的卸载事务已经提交，之后对旧ID的两种更新返回404；如果更新先获取行锁，则可先成功、随后被卸载，这属于现有事务序列化语义，测试不承诺所有竞争都返回404。

应用重建使用两个可关闭的完整Servlet上下文，临时服务端口为0，退出try-with-resources即关闭服务和连接池；数据库容器在两次启动之间不停止。既有 `PluginMigrationTests` 继续覆盖空库迁移到V3、V3增量升级V5、生产上下文重建及重复执行seed SQL，真实约束证据继续由 `PluginCatalogIntegrationTests` 保留。

## 切片04到08验收对照

| 切片 | 核心边界 | 本轮回归证据 | 完成方案 |
| --- | --- | --- | --- |
| 04 | plugin/user_plugin DDL、唯一键、CHECK、生产seed、当前用户LEFT JOIN、显式null及排序 | `actualDatabaseEnforcesIndexesNullabilityAndChecks`、目录/JSON/JOIN/排序用例、`PluginMigrationTests` | [04方案](slice-04-plugin-market-skeleton-seed-list-solution.md) |
| 05 | 两插件完整默认值、每用户每插件单实例、未知精确code404、禁用/并发重复409、失败回滚 | 默认值与Service测试、安装/重复/回滚数据库用例、新增安装竞争及两种插件闭环 | [05方案](slice-05-install-plugin-default-config-solution.md) |
| 06 | 原始对象body整体替换、对象根400、JSON媒体415、归属403、只写config、同值200 | UserPluginControllerTests、PluginConfigServiceTests、整体替换/嵌套/未知字段/JSON往返/回滚、新增切结构及并发窄更新 | [06方案](slice-06-replace-plugin-config-solution.md) |
| 07 | 严格布尔、同状态200、配置保留、物理DELETE、旧ID404、重装新ID和默认值 | Controller/Lifecycle Service测试、真实启停/卸载/重装/回滚、新增端到端及卸载先完成用例 | [07方案](slice-07-plugin-enable-disable-uninstall-solution.md) |
| 08 | 注册登录闭环、A/B隔离、五接口认证与登出、并发、关闭重建、最终全量检查 | 新增PluginIntegrationTests的7项及本轮122项全量测试 | 本方案 |

### 数据库最终边界

| 定义 | 保证与取舍 |
| --- | --- |
| 两表 `PRIMARY(id)` | BIGINT自增/Java Long；ID可能有空洞，不依赖固定或连续编号 |
| `uk_plugin_code(code)` | code唯一、`utf8mb4_0900_bin`精确区分大小写；大小写不匹配安装404 |
| `uk_user_plugin(user_id,plugin_id)` | 每用户每插件单实例；禁用仍占唯一名额，卸载后释放；并发INSERT冲突映射409 |
| `idx_user(user_id)` | 保留04明示索引，与联合唯一键左前缀冗余；本轮不调整schema |
| `config JSON NOT NULL`、根对象CHECK | `{}`合法；SQL NULL、JSON null、根数组/标量被数据库拒绝；内部对象不验证插件schema |
| `enabled NOT NULL DEFAULT 1`、0/1 CHECK | TINYINT(1)配合CHECK限制直接SQL；HTTP严格接受true/false |
| 逻辑关联，无物理外键 | 正常写入使用可信user及存在的plugin；无目录/user删除或子表级联协议，未来需显式设计清理 |
| MySQL JSON数值 | 保持原生数值精度及归一化；高精度值以JSON字符串提交；不承诺键顺序/空白保留 |
| V5生产seed | 初次生产迁移插入两条字典，重启不新增或改ID/实例配置；人工删除目录不会被普通重启修复，须新migration |

### 五接口契约核对

已核对 `api/docs/openapi/openapi.yaml`、`paths/plugin.yaml`、`components/plugin-schemas.yaml`、脚本生成的 `dist/selfmark.openapi.yaml` 和真实测试响应。成功均HTTP200/code200/msg=success，失败code与HTTP一致且data:null。

| 接口 | 输入及输出边界 | 错误状态 |
| --- | --- | --- |
| `GET /api/plugins` | JWT身份；全目录数组，sort/id升序；未安装三个状态字段显式null，禁用仍installed=true | 401、500 |
| `POST /api/plugins/{code}/install` | 无业务body；服务端完整默认config、enabled=true；返回实例id/pluginId/code/name/config/enabled | 401、404、409、500 |
| `PUT /api/user-plugins/{id}/config` | body本身为JSON对象；整体替换，不合并/补默认；`{}`清空；返回实例，enabled保留 | 400、401、403、404、415、500 |
| `PUT /api/user-plugins/{id}/enabled` | `{"enabled":boolean}`必填；额外字段忽略，只写enabled；同状态200，返回实例 | 400、401、403、404、415、500 |
| `DELETE /api/user-plugins/{id}` | 无body，物理删除本人实例；200/data:null；重装新ID/默认值，旧ID仍404 | 400、401、403、404、500 |

市场条目的id是目录ID、userPluginId是实例ID；实例响应的id是实例ID、pluginId是目录ID。实例path要求Java Long范围内正整数，语法有效的请求先判断实例存在404，再判断owner403；身份始终取JWT。config/enabled/卸载均使用同一事务行锁策略，更新各自字段，未增加version/ETag或JSON局部合并协议。

## 实际执行结果

| 检查 | 本轮结果 |
| --- | --- |
| 新增类定向 `mvn -o -Dtest=PluginIntegrationTests test` | 7项通过，失败0、错误0、跳过0；真实MySQL/Redis |
| `api/` 下 `.\mvnw.cmd test` | Maven3.9.16、Java21；122项，失败0、错误0、跳过0，BUILD SUCCESS；2026-10-15 08:28:30完成 |
| Surefire XML | 18份报告均为此次全量执行生成；实际求和122/0/0/0，排除旧报告和Docker缺失跳过 |
| PluginIntegrationTests | 7项，失败0、错误0、跳过0 |
| PluginCatalogIntegrationTests | 19项，失败0、错误0、跳过0；真实约束/JSON/回滚/生命周期全部执行 |
| PluginMigrationTests | 1项，失败0、错误0、跳过0；V3增量升级及生产seed重启证据仍有效 |
| AuthIntegrationTests | 2项，失败0、错误0、跳过0；认证回归执行 |
| 根目录 `bash api/check-api.sh` | Redocly lint/bundle通过，oasdiff breaking通过；生成YAML与已提交内容无语义差异 |
| `openspec validate complete-plugin-backend-slices-04-08 --strict` | 通过 |
| `git diff --check` | 通过 |

Surefire报告在 `api/target/surefire-reports/`，不提交构建产物。最初沙箱内运行因Docker命名管道拒绝访问而跳过测试，该次结果不作为验收；获得执行授权后在可访问Docker Engine的环境完成定向及全量测试，最后报告无跳过。普通目录Target为空的wrapper启动错误已修复，再按任务指定的wrapper命令实际执行全量验收。

预期故障注入会输出服务器异常日志，部分测试容器关闭后Spring缓存上下文会输出Redis重连日志；本轮最终结果以18份本轮Surefire报告的零失败/错误/跳过核对。

## 可提交文件

- `api/src/test/java/com/nortidart/selfmark/plugin/PluginIntegrationTests.java`（新增）
- `api/mvnw.cmd`（Windows启动空值防护）
- `openspec/changes/complete-plugin-backend-slices-04-08/tasks.md`（5.1到5.7完成状态）
- 本完成方案。

建议commit标题：`test(slice-08): cover lifecycle and user isolation`。OpenAPI YAML由现有脚本重新生成并检查，没有需要纳入本切片的内容差异；本轮未编辑Apifox JSON。commit、push和draft PR由用户自行操作，change保留未归档。

## Apifox待用户确认

当前仓库的 `api/docs/openapi/dist/selfmark.openapi.json` 已有五个插件接口，响应状态范围与维护源一致。文件存在不证明本轮已在外部Apifox完成导入或Review；以下动作本轮没有操作或验证，需用户确认当前工作区确实使用最终契约：

1. 导入/核对最终 `dist/selfmark.openapi.yaml`，检查五接口、认证以及market/instance两种ID含义。
2. 在Apifox完成注册登录、两插件默认值、配置整体替换、禁用/启用、卸载重装的实际请求Review；核对401、403、404、409、400/415及显式null。
3. Review完成后重新导出JSON，若与现有导出有差异则纳入最终commit；不以代理生成JSON代替用户导出。
4. 用户完成切片08commit和draft PR最终Review。所有OpenSpec任务完成后，可另行调用归档工作流。

后端自动化实现与验收目前无需补充其他资料。Apifox和用户Git操作不计作已完成的自动化测试。
