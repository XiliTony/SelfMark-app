# Tasks

按切片04、05、06、07、08顺序实施。每组完成即报告可提交范围、测试结果和边界说明；由用户自行commit和管理draft PR。未获得连续实施指令时，一次实施一个切片，不自动展开下一切片。以下checkbox仅追踪代码、测试与文档交付，不包含替用户执行Git操作。

## 1. 切片04：建表、生产seed和市场列表

- [x] 1.1 新增 `V4__create_plugin_tables.sql`（若版本已占用则使用下一可用版本），按design实现两表、主键、 `uk_plugin_code`、 `uk_user_plugin`、 `idx_user` 和两个CHECK；用MySQL8.4验证空库完整迁移及V3库增量迁移，确认V1到V3未修改。
- [x] 1.2 新增生产 `V5__seed_builtin_plugins.sql`（版本跟随建表migration），按code guarded insert两条目录；真实数据库断言code/name/sort、仅两条预置数据、重复初始化不改ID，且生产路径不加载devdata账号。
- [x] 1.3 实现Plugin/UserPlugin实体、mapper、config JSON type handler和目录状态投影；验证真实插入及JOIN查询将config序列化为对象，支持中文/嵌套值/数值，未安装enabled/config保持null而非false/字符串。
- [x] 1.4 实现带认证上下文的单次LEFT JOIN市场查询及Controller；MockMvc覆盖两条目录、显式null、已安装/禁用状态、sort同值ID排序、空列表、他人状态隔离、无token401，真实SQL用例确认ON中的user_id条件不会丢未安装行。
- [x] 1.5 用真实MySQL用例验证code重复、同用户同插件重复、不同用户合法、NOT NULL、JSON根对象CHECK及enabled的0/1 CHECK；检查 `SHOW CREATE TABLE` / `SHOW INDEX`，记录idx_user左前缀冗余和无物理外键取舍，不用mapper mock代替数据库约束证据。
- [x] 1.6 增加列表OpenAPI源和对应schema，更新入口及错误码；执行 `bash api/check-api.sh` 确认lint/bundle/breaking检查通过并生成dist YAML，检查未安装三个字段为nullable且installed必为boolean。
- [x] 1.7 对新增plugin bean所影响的现有隔离启动/认证/健康测试补必要mock配置，运行本切片测试及认证/启动回归；交付切片04完成方案，列出DDL、索引/约束、seed重启边界、测试结果和Apifox待用户导入导出事项，确认本组文件可单独提交。

## 2. 切片05：安装、默认配置和单实例约束

- [x] 2.1 在plugin服务层实现集中默认配置生成，按design完整生成画板和番茄钟对象；Service测试断言全部默认字段、每次对象独立以及修改A对象不影响B默认值。
- [x] 2.2 实现事务安装和 `POST /api/plugins/{code}/install`，仅使用当前身份、精确code及服务端默认值；Controller与真实回读覆盖两种安装200、市场状态一致、未知code404、大小写不同code404、无token401及目录存在但缺默认值时无残留实例。
- [x] 2.3 实现已安装预检查及实例INSERT的DuplicateKeyException到409转换；Service测试稳定覆盖预检查通过后发生唯一冲突，Controller覆盖已启用/已禁用重复安装均409且不改原数据，真实SQL验证最终单实例约束。
- [x] 2.4 为安装增加OpenAPI请求/实例响应和404/409独立示例，更新稳定错误消息；执行契约检查及本切片测试，交付切片05完成方案中的默认JSON、事务/并发边界、测试结果和可提交文件清单。

## 3. 切片06：配置整体替换和归属校验

- [x] 3.1 实现原始JsonNode配置body的根对象校验及正整数Long path校验，补类型转换异常的400处理和JSON媒体类型415统一响应；MockMvc覆盖空body、坏JSON、null/数组/标量400、非JSON Content-Type415及abc/溢出/0/负数ID400，验证既有认证回归。
- [x] 3.2 实现事务内按ID锁定读取、存在与owner校验、仅写config且WHERE含当前userId的更新及回读；验证本人200、合法他人请求403、不存在404、无token401、同值重复PUT200、禁用实例enabled不变。
- [x] 3.3 加入完整对象替换和真实JSON往返用例：修改轴/区域名称、active切换且显式提交两结构、未知字段/嵌套数组/null、 `{}` 清空、遗漏字段被移除、 `{"config":...}` 按字面存储；再次GET与数据库回读均按JSON语义断言，确认没有隐含合并、补默认值或4KB业务限制。
- [x] 3.4 更新配置接口OpenAPI和错误码，使用自由对象schema及明确的原始请求示例，增加403/404/415共享错误定义；运行契约检查及本切片测试，交付切片06完成方案的body语义、权限/校验顺序、最后写入覆盖和同值更新边界。

## 4. 切片07：启停和物理卸载

- [x] 4.1 实现严格enabled布尔解析及事务内窄更新；MockMvc与真实回读覆盖false/true成功、同状态200、缺失/null/字符串/0/1/数组/对象400、额外字段不修改归属或config，并断言禁用/启用全程保留配置。
- [x] 4.2 实现锁定读取及归属校验后的物理DELETE；验证成功200且data=null、数据库旧行不存在、目录仍在、市场恢复未安装且字段为null、重复DELETE/旧ID更新404。
- [x] 4.3 加入生命周期权限与重装用例：启停/卸载他人实例403、不存在404、无token401；修改配置并禁用后卸载重装，断言新ID、完整默认config、enabled=true且旧自定义数据未恢复。
- [x] 4.4 更新两个接口OpenAPI、严格boolean必填定义、卸载响应和错误码；运行契约检查及本切片测试，交付切片07完成方案的同状态语义、无软删除/无级联假设、重装与旧ID边界及可提交文件清单。

## 5. 切片08：真实集成闭环和最终验收

- [x] 5.1 建立PluginIntegrationTests，沿用MySQL8.4/Redis7.4 Testcontainers与生产Flyway seed，每个用例注册/登录独立手机号用户并按自身ID清理；确认测试不依赖local配置、备份、devdata共享账号或测试执行顺序。
- [x] 5.2 实现画板端到端用例：注册、登录、市场未安装、安装默认配置、改名称/切结构、列表回读、禁用/启用配置不变、卸载市场复原、重装默认值；全程核对HTTP/code及关键数据库状态。
- [x] 5.3 实现番茄钟默认label及更新持久化、A/B市场隔离、B改配置/启停/卸载A实例全部403且A不变；遍历五个插件接口的缺token401并验证登出token访问插件接口401。
- [x] 5.4 用两个独立请求线程/连接和屏障验证实际并发安装一次200一次409且最终一行，验证config与enabled并发更新都保留；验证卸载先完成后旧ID更新404、不复活，不用任意sleep代替时序控制。
- [x] 5.5 保持同一数据库容器运行，关闭并重建应用上下文，确认目录code数和ID不变、既有实例配置/状态不重置；保留首次空库及V3升级、真实唯一/CHECK约束测试证据，确认测试不是只复测mock seed。
- [x] 5.6 在Docker可用环境从 `api/` 执行 `.\mvnw.cmd test` 并从仓库根执行 `bash api/check-api.sh`；检查Surefire报告确保插件集成测试实际运行且没有因无Docker跳过，全部认证/健康/Service/Controller/集成测试通过，记录失败修复和实际结果。
- [x] 5.7 交付切片08完成方案和04到08验收对照，核对五个接口维护源、bundle与实际响应一致，逐项注明用户Apifox导入/重新导出尚未完成的外部动作；确认本change任务状态与已交付证据一致，供用户完成最终commit和draft PR Review。
