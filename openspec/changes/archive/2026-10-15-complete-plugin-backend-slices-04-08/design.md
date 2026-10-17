# Design

## Context

动机与范围见 [proposal.md](proposal.md)。行为依据为 [目录规格](specs/plugin-market-catalog/spec.md) 和 [实例规格](specs/installed-plugin-lifecycle/spec.md)，来源为 `后端项目文档/skill/issues/slice-04` 到 `slice-08` 及现行 PRD。

已核对的实现现状：

- Java 21、Spring Boot 3.5.16、MyBatis-Plus 3.5.17；目录、安装和配置的生产代码尚未实现，plugin各子包只有 `package-info.java`。
- Flyway已有V1到V3；默认/prod只加载 `db/migration`。MySQL镜像为8.4、Redis为7.4-alpine。
- 现有鉴权覆盖 `/api/**`，仅注册、登录、健康检查等既有路径例外；上下文提供 `CurrentUser.userId()`。不从客户端接收可信用户ID。
- `ApiResponse.success` 固定 `{code:200,msg:"success",data:...}`。PRD写的“200 / 0”不构成把code改成0的依据。
- 注册登录实际使用 `mobile`，`username`只是展示名；切片08按当前DTO注册，不复用PRD旧用户名登录描述。
- OpenAPI维护源是3.0.3，已有Docker驱动的lint、bundle、breaking检查；已有Testcontainers依赖和真实认证集成测试。
- `backend-module-boundaries` 已要求移除旧task/subscription占位包，优先于PRD中“保留旧空包”的历史表述。

## Goals / Non-Goals

**Goals:**

- 让每个切片都有可单独验证、提交的实现范围，完成一个切片后即交付该切片的契约、测试结果和边界说明。
- 把数据库不变量、HTTP错误语义和并发结果固定下来，避免实施时从框架默认行为推导业务规则。
- 生产目录初始化、开发联调数据和自动化测试用户各有明确生命周期。

**Non-Goals:**

- 不增加分页、搜索、插件后台管理、配置版本字段、乐观锁协议或JSON部分合并。
- 不为两个预置插件引入插件引擎、运行时加载框架、缓存市场列表或新的计时服务。
- 不新增全局Jackson布尔宽松/严格策略以改变认证请求的行为。
- 本次规划不执行Git提交和PR操作；后续实施也由用户管理这些操作。

## Decisions

### 1. 切片和提交边界

采用一个总change、五个顺序实施的任务组，避免五份提案重复定义相同模型和返回结构。切片06和07业务上都只依赖05，但按用户要求交付04、05、06、07、08。

| 切片 | 实施范围 | 独立交付和验收 | 建议commit标题 |
| --- | --- | --- | --- |
| 04 | 建表、生产目录seed、实体/mapper、列表 | DDL与索引检查、初始化、当前用户状态、列表契约 | `feat(plugin): add catalog schema seed and market list` |
| 05 | 安装、默认值、重复冲突转换 | 默认JSON、单实例、并发冲突、安装契约 | `feat(slice-05): install plugins with default config` |
| 06 | 配置对象整体替换 | 原始body、权限、类型错误、禁用配置保留 | `feat(slice-06): replace installed plugin config` |
| 07 | 严格布尔启停、物理卸载 | 同状态PUT、配置保留、重装默认值、旧ID404 | `feat(slice-07): enable disable and uninstall plugins` |
| 08 | 真实集成闭环与必要缺陷修复 | 全量测试、隔离、seed重启、真实约束与并发证据 | `test(slice-08): cover lifecycle and user isolation` |

每个切片在 `后端项目文档/skill/solutions/` 新增对应 `slice-0N-...-solution.md`，沿用现有02、03完成方案模式，记录实际文件、边界、验收命令、结果和未运行项。本设计是计划，不预先标记任何实现或验收已完成。

完成一个切片并报告结果后，等待用户提交及指定下一切片；实施指令若明确授权连续执行，则遵循该指令。用户可把规划文件放在draft PR的初始commit，随后逐切片提交；不由代理创建PR、暂存、commit或push。

### 2. 切片04：数据库字段和可评审DDL

以下DDL为新增migration的目标，不是本次已执行的SQL。拟使用 `V4__create_plugin_tables.sql`，不修改V1到V3，实施前重新核对版本占用。

```sql
CREATE TABLE `plugin` (
    `id` BIGINT NOT NULL AUTO_INCREMENT,
    `code` VARCHAR(50) COLLATE utf8mb4_0900_bin NOT NULL,
    `name` VARCHAR(50) NOT NULL,
    `description` VARCHAR(500) NULL,
    `sort` INT NOT NULL DEFAULT 0,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_plugin_code` (`code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `user_plugin` (
    `id` BIGINT NOT NULL AUTO_INCREMENT,
    `user_id` BIGINT NOT NULL,
    `plugin_id` BIGINT NOT NULL,
    `config` JSON NOT NULL,
    `enabled` TINYINT(1) NOT NULL DEFAULT 1,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_user_plugin` (`user_id`, `plugin_id`),
    KEY `idx_user` (`user_id`),
    CONSTRAINT `chk_user_plugin_config_object`
        CHECK (JSON_TYPE(`config`) = 'OBJECT'),
    CONSTRAINT `chk_user_plugin_enabled`
        CHECK (`enabled` IN (0, 1))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

| 边界 | 决策及原因 | 如何验证 |
| --- | --- | --- |
| 两张表主键 | 有符号BIGINT自增，与既有User的Long一致；业务不依赖固定ID或连续ID | 安装从生成键获得ID；回滚、冲突可产生编号空洞 |
| code唯一 | 命名为 `uk_plugin_code`；使用8.4支持的 `utf8mb4_0900_bin`，精确且大小写敏感，避免继承表的大小写不敏感排序规则 | 同code第二次INSERT失败；大小写不同的path不会匹配小写seed |
| 单实例 | `uk_user_plugin(user_id,plugin_id)`；两个字段均NOT NULL；enabled不参与唯一键 | 相同用户/插件重复失败；不同用户或不同插件允许；禁用不能重装 |
| idx_user | 按切片04显式保留；其查询能力已被联合唯一索引的user_id左前缀覆盖，存在额外写入/存储成本 | `SHOW INDEX` 确认存在；后续优化需要明确修订schema验收要求 |
| 索引顺序 | user_id在前支持按用户查询和列表关联；不额外建立plugin_id单列索引 | `EXPLAIN` 检查关联使用联合键；不要求优化器必须选某个索引名 |
| sort | INT可重复，可为0或负数；目录只有两条，不另建sort索引 | 查询使用 `sort ASC,id ASC`，同sort稳定返回 |
| config | JSON且NOT NULL；SQL NULL、JSON null和根数组/标量不允许； `{}` 合法；CHECK只校验根类型 | 真实MySQL验证非法JSON、NULL、非对象被拒，嵌套数组/null可存 |
| enabled | TINYINT(1)本身不是布尔约束，因此追加0/1 CHECK；默认1 | 省略enabled得到1，写2或NULL被拒；HTTP序列化用boolean |
| description | 可为NULL，列表始终返回description键 | 未设置文案返回JSON null，不冒充空字符串 |
| 时间 | created_at由数据库生成，更新配置/状态不改创建时间；本次不增updated_at | 更新及重装检查各自创建时间；响应不新增时间字段 |
| 外键 | 沿用切片明示schema，不新增物理外键和级联删除；user_id/plugin_id是逻辑关联 | 正常写入只使用当前用户和已查到的plugin；运维直接写SQL需自己维护引用完整性 |
| 字符长度 | VARCHAR长度为字符数，utf8mb4允许中文；当前没有目录写接口 | metadata检查50/500字段定义；seed文案不超过上限 |

新增两个CHECK是对“对象配置”和“布尔状态”已有契约的数据库保护，不校验active、regions、label等内部字段。MySQL 8.0.16以前不会可靠执行CHECK，本项目按既有8.4环境验收。不把CHECK异常笼统转换成重复安装409。

没有物理外键是明确取舍：当前没有删除User或Plugin的业务接口；未来增加这些操作时必须同时定义实例清理策略，不能默认为已有级联行为。JWT认证沿用现有身份语义；不在此change新增用户删除/账号失效协议。

### 3. 切片04：seed使用生产Flyway版本数据

采用 `V5__seed_builtin_plugins.sql`，按code guarded insert插入 `(quadrant-board,画板,1)` 和 `(pomodoro,番茄钟,2)`，description先设NULL。初始化在正常启动Flyway阶段发生，所有profile共用；迁移失败则启动失败，不返回“成功但目录没建好”的API。

选择理由：目录是产品必需的字典，不是联调账号。已有 `environment-seeded-data` 明确要求生产字典版本化，因此不放进 `db/devdata`，也不引入与Flyway竞争的ApplicationRunner。Flyway迁移锁解决多个API同时首次启动的问题；guarded insert保证seed SQL重复执行不覆盖既有记录。禁止使用REPLACE、truncate或每次启动重置配置。

重启幂等指同一数据库第二次启动不重复应用V5、ID和状态不变；已执行V5后若人工删除目录记录，普通重启不会自动修复。没有目录删除接口；若后续需要修复或新增插件，新增migration处理，不能修改已执行V5。该行为区别于“每次启动巡检补齐”，在切片04完成方案中明确注明。

Plugin目录仅在干净数据库上恰好两行；实际列表不硬编码只返回这两个code。默认配置不放进plugin表或seed SQL，留给切片05的单一后端生成逻辑。

### 4. 切片04：市场列表查询及JSON映射

一条参数化LEFT JOIN：

```sql
SELECT p.id, p.code, p.name, p.description, p.sort,
       up.id AS user_plugin_id, up.enabled, up.config
FROM plugin p
LEFT JOIN user_plugin up
  ON up.plugin_id = p.id AND up.user_id = #{userId}
ORDER BY p.sort ASC, p.id ASC;
```

用户条件必须在ON中；放入WHERE会过滤未安装插件。`installed` 由 `user_plugin_id != null` 推导，不能由enabled推导，也不逐插件查询造成N+1。

实体 `UserPlugin.config` 和响应中的config使用Jackson `JsonNode`/对象节点，DTO中安装状态enabled用可空Boolean。写入使用参数化绑定与JSON type handler；MyBatis-Plus实体启用 `autoResultMap`，自定义JOIN也显式resultMap/type handler，不能以为实体注解会自动处理自定义结果。自定义更新必须使用相同JSON序列化处理，不拼接JSON到SQL。

不创建字符串型config响应：`config` 必须是JSON对象而不是带转义引号的字符串。语义保留允许MySQL改变对象键顺序、空白。2026-10-14实施时经真实数据库测试和用户确认，保留MySQL JSON的原生数值精度：小数可能按double舍入，需要精确保留的高精度值由客户端以JSON字符串表达。type handler以BigDecimal解析数据库返回的小数，避免再次人为截断；覆盖整数、普通小数、高精度字符串和中文往返测试。DTO负责输出所需字段，不直接暴露user_id等实体内部字段。

### 5. 全切片共享：接口契约和响应结构

全部接口使用既有Bearer JWT和统一响应。安装和卸载沿用HTTP200，避免引入201/204使 `ApiResponse` 语义分叉。

| 接口 | 请求 | 200 data | 主要错误 |
| --- | --- | --- | --- |
| `GET /api/plugins` | 无body | `MarketPluginResponse[]`，不分页 | 401、500 |
| `POST /api/plugins/{code}/install` | 无业务请求体 | `InstalledPluginResponse` | 401、404、409、500 |
| `PUT /api/user-plugins/{id}/config` | `application/json`，完整配置对象本身 | `InstalledPluginResponse` | 400、401、403、404、415、500 |
| `PUT /api/user-plugins/{id}/enabled` | `application/json`，`{"enabled":boolean}` | `InstalledPluginResponse` | 400、401、403、404、415、500 |
| `DELETE /api/user-plugins/{id}` | 无body | null | 400、401、403、404、500 |

市场元素示例，ID只作演示：

```json
{"id":1,"code":"quadrant-board","name":"画板","description":null,
 "sort":1,"installed":false,"userPluginId":null,"enabled":null,"config":null}
```

安装及两个PUT返回同一种实例结构：

```json
{"code":200,"msg":"success","data":{
  "id":11,"pluginId":1,"code":"quadrant-board","name":"画板",
  "config":{"foo":1},"enabled":true}}
```

该例用于展示响应字段，`{"foo":1}`代表后续更新后的配置；安装默认值必须使用下一节的完整JSON。列表中的 `id` 是目录ID，`userPluginId` 是实例ID；实例响应中的 `id` 是实例ID，`pluginId` 是目录ID，两者在契约和示例中不得混用。

### 6. 切片05：安装流程、默认配置与冲突

流程：精确查code，不存在404；按当前userId和pluginId查已安装状态，存在409；新建实例并写入默认对象、enabled=1；单条INSERT由 `uk_user_plugin` 兜底，捕获该INSERT的 `DuplicateKeyException` 转为409；生成键后查回实例并映射响应。

使用Service事务保证写入和响应构造失败时不留下“报失败却已经安装”的实例。重复冲突捕获范围只包含实例INSERT，不把其他数据库异常捕获为409。两个请求都通过预检查也必须只有一个成功；不使用进程锁、Redis锁或INSERT IGNORE掩盖安装冲突。

默认配置由 `plugin.service` 中单一 `DefaultPluginConfigFactory` 按code创建独立对象，不共享可变ObjectNode。每次安装均写全量默认对象；不同用户和重装之间没有共享引用。

```json
{
  "active":"quadrant",
  "quadrant":{
    "xAxisLabel":"紧急度",
    "yAxisLabel":"重要度",
    "regions":[
      {"key":"q1","name":"重要且紧急"},
      {"key":"q2","name":"重要不紧急"},
      {"key":"q3","name":"紧急不重要"},
      {"key":"q4","name":"不重要不紧急"}
    ]
  },
  "pyramid":{
    "regions":[
      {"key":"p1","name":"顶层目标"},
      {"key":"p2","name":"中层计划"},
      {"key":"p3","name":"底层行动"}
    ]
  }
}
```

番茄钟完整默认对象为 `{"label":"专注"}`。路径code不存在返回404；若运维加入了目录记录但没有定义默认配置，安装失败500并记录服务端原因，不静默写 `{}`。未来新增插件需补目录migration和默认值定义；已有画板增加内部结构不要求后端校验逻辑变更。

### 7. 切片06：配置替换及权限事务

JSON配置请求体直接绑定树节点并验证 `isObject()`。空body/语法错误由请求解析报400，JSON null/根数组/标量由plugin校验报400， `{}` 合法。不设计 `{config:...}` 请求包装：如果提交该键，它只是普通配置内容。后端不检查active取值、区域数量、label长度，也不为缺失字段补默认值。

PRD的“建议4KB”尚未成为验收要求，本次不新增业务层4KB限制；OpenAPI不宣称该限制。JSON解析器和MySQL的实际资源上限仍存在，不承诺无限大小。若要新增可观测的400/413大小契约，需要后续单独确定计量单位及状态语义。

校验顺序为JWT鉴权、path/body语法校验、实例存在/归属校验、数据库更新。因此测试403/404时提交合法body；对于同时坏body和他人ID的请求允许先400，不承诺错误优先级覆盖语法错误。

归属与更新放在一个Service事务：按主键 `SELECT ... FOR UPDATE` 读取实例；不存在404，owner不同403；执行只更新config的SQL，WHERE同时限定id与当前userId；事务内查回并返回实例及目录元数据。每个操作独立事务，不依赖跨请求事务。

行锁使检查到写入期间卸载不能插入，避免检查后被删除还返回虚构成功。启停、卸载复用同样的锁定查找及归属校验；不在common中引入plugin类型。选择行锁而非version字段，因为当前契约没有版本/409更新冲突协议。

相同字段按最后成功写入覆盖，不提供冲突检测；两个设备改config时后者可覆盖前者。config与enabled通过窄更新互不覆盖，禁止读取旧实体后 `updateById` 写回全部字段。已锁定确认存在后，同值UPDATE可能报告0条changed rows，这不等于资源不存在，仍返回200。

### 8. 切片07：严格启停和卸载

启停采用局部JsonNode解析或严格字段反序列化，检查根为对象、enabled字段存在且 `isBoolean()`。使用Boolean DTO加 `@NotNull` 只能拒绝缺失/null，不能保证拒绝Jackson自动转换的 `"true"` 或1，必须覆盖这种输入。额外请求字段忽略，仅enabled参与UPDATE。

禁用实例仍占用联合唯一键，可更新config；市场installed=true且enabled=false。重复设置相同状态200，config不发生变化。

卸载同样锁定读取、校验归属后 `DELETE WHERE id=? AND user_id=?`，物理删除单行，无软删除字段、恢复旧配置或子表级联。重复DELETE返回404。重装INSERT产生新ID、enabled=true及完整默认对象；旧ID的PUT/DELETE都404。

### 9. 错误码、类型边界及契约维护

| HTTP/code | 稳定msg | 场景 |
| --- | --- | --- |
| 400 | 请求体格式错误 | 空body、JSON语法错误，沿用现有全局解析错误 |
| 400 | config 必须是 JSON 对象 | 已解析的根值不是对象，包括JSON null |
| 400 | enabled 必须是布尔值 | 根非对象、字段缺失/null/字符串/数字/数组/对象 |
| 400 | id 必须是正整数 | path无法绑定Long、溢出、0或负数 |
| 401 | 未登录 / token 无效 / token 已登出 | 沿用既有认证，不创建新的插件鉴权分支 |
| 403 | 无权操作该插件实例 | 合法请求的实例属于其他用户 |
| 404 | 插件不存在 | 精确code查不到目录 |
| 404 | 插件实例不存在 | 合法正整数ID查不到实例 |
| 409 | 插件已安装 | 预检查或数据库唯一冲突 |
| 415 | 仅支持 application/json | 两个JSON更新接口收到非JSON Content-Type |
| 500 | 服务器内部错误 | 非预期故障，详细异常只在服务端日志 |

当前 `GlobalExceptionHandler` 未显式处理path类型转换异常，可能落入500。添加范围明确的参数类型异常400处理，并为受影响的既有接口做回归；不得把所有Exception映射成400。两个JSON接口声明consumes，非JSON Content-Type返回标准415，维持统一包络和OpenAPI描述；补对应媒体类型异常处理和稳定消息 `仅支持 application/json`，避免落到泛化500。

接口文档新增 `paths/plugin.yaml`、`components/plugin-schemas.yaml`，并在入口注册；为403/404/415补齐独立错误schema/response，避免共享错误code示例误导。配置schema为 `type: object, additionalProperties: true`，请求根非nullable；市场未安装config为nullable object。id使用 `integer/int64`，enabled布尔，列表空值字段保持显式null。

每个切片更新维护源和 `api/docs/error-codes.md`，执行根目录 `bash api/check-api.sh` 得到bundle。不得手写dist YAML；Apifox JSON由用户完成接口导入、Review和重新导出后提交，代理不能伪称已完成外部Apifox验证，也不通过脚本冒充用户导出。

### 10. 切片08及逐切片测试策略

三层验证分工：MockMvc验证HTTP契约、严格解析和鉴权；Service单元测试验证默认值和重复冲突转换；MySQL/Redis集成测试验证真实JOIN、JSON映射、索引/CHECK及事务并发。数据库不变量不能以mapper mock测试替代。

每个切片就加入自己的Controller测试；04加入真实schema/列表验证，05加入真实重复约束验证，06/07加入自己的数据回读。08整合注册登录到卸载的闭环和并发/重启验收，不等到08才发现建表SQL无法执行。

集成测试沿用MySQL8.4和Redis7.4容器，显式指定只用生产migration，不依赖local配置、devdata账号或backup；每个用例通过手机号注册/登录产生独立用户。按用例清理自身user_plugin再清理user，不truncate共享表或重置自增；生产seed不清理。

| 验收组 | 必要证据 |
| --- | --- |
| 04目录 | 干净启动两条seed、重复启动ID不变、prod无联调账号、LEFT JOIN未安装不丢行、显式null、排序、B状态不混入A |
| 04数据库 | INFORMATION_SCHEMA/SHOW INDEX确认PK和索引，真实重复INSERT失败，config根和enabled CHECK有效 |
| 05安装 | 两份完整默认对象、缺code404、已禁用409、unique冲突映射、实际并发一次200一次409且最终一行 |
| 06配置 | 中文/嵌套/未知字段/数值往返、空对象、整体替换删字段、完整切结构、根非法400、相同配置200、禁用不受影响 |
| 07生命周期 | 非布尔400、同状态200、配置保留、物理删除、旧ID404、重装新ID和默认配置 |
| 08闭环 | A/B独立注册登录；两种插件持久化；B三种实例操作403且A数据未变；所有插件接口缺token401；登出token失效 |
| 08并发 | 两个独立线程/连接发安装请求，不共享UserContext；锁定事务下config与enabled窄更新同时成功、卸载后更新不复活 |
| 08重启 | 同一容器数据库保持运行，关闭应用上下文后重新启动并重新查询，不只是重复调用被mock的seed方法 |

用屏障协调并发请求启动并收集所有结果，测试HTTP200/409以及最终SQL行数；先用Service测试稳定覆盖两个预检查均通过后发生DuplicateKeyException的分支。若要控制数据库锁获取次序，使用独立连接和明确屏障，不靠随意sleep制造时序。

当前认证Testcontainers使用 `disabledWithoutDocker=true`。无Docker时本地单测可继续运行，但最终验收必须确认Docker可用、插件集成测试实际执行且未跳过，不能仅凭Maven exit=0宣称闭环通过。04到07的容器验证和08的全量验证都记录执行/跳过情况。

## Risks / Trade-offs

- [唯一联合键与idx_user重复] -> 本次遵守明示schema，记录成本，后续基于查询证据再优化。
- [无物理外键允许运维写入孤儿引用] -> 应用写入使用可信身份和存在目录；新增User/Plugin删除能力时补清理决策。
- [JSON归一化不保证原始字节和键顺序] -> 对外约定语义一致，测试解析后比较对象，避免字符串顺序断言。
- [整体替换允许客户端遗漏配置或覆盖另一设备修改] -> 契约明确整对象和最后写入语义；不伪称后端自动保留未提交结构。
- [行锁增加同实例操作等待] -> 事务仅含读、归属检查、单行写和回读，不在锁内调用Redis或外部服务。
- [Flyway DDL在MySQL上不是完全可回滚事务] -> 先在空库及V3库验证迁移；故障保留数据并新增修复migration，不删表重建。
- [单次V5不会修复人工删除的目录] -> 明确初始化生命周期，修复通过新migration；正常业务不提供目录删除。
- [容器测试静默跳过及旧SpringBootTest无mapper bean] -> 验收核对实际测试报告；新增plugin服务后给现有隔离启动测试补必要MockitoBean，保持认证/健康回归。

## Migration Plan

1. 切片04新增V4建表和V5生产字典seed，先在空数据库跑V1到V5，再在V3数据库验证增量启动；记录V3包含历史用户清理，这是既有迁移，不新增清理行为。
2. 通过 `SHOW CREATE TABLE`、`SHOW INDEX`、真实约束失败和列表回读核对SQL结果；成功后用户提交04。后续切片依次增加接口、契约及测试，保持各次提交可启动。
3. 生产升级先备份、执行新增migration，再部署包含该阶段接口的API。回退应用可保留新增表和字典，旧认证代码不依赖它们；不要把DROP TABLE作为常规回退。
4. SQL执行失败时先诊断Flyway历史和实际表状态，通过向前修复恢复一致，不执行flyway clean、不改V1到V5已执行文件，不自动repair掩盖失败。
5. 切片08全量验证并记录实际执行数与跳过项，用户完成draft PR提交/Review；本change全部任务完成后另行选择归档工作流。
