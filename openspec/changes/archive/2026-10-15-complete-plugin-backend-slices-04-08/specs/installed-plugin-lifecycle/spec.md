# Spec Delta

## Purpose

定义用户安装平台插件后形成的独立实例及其完整生命周期，保证每用户每插件只有一份配置、操作归属明确、禁用保留数据、卸载删除数据，并让前端能够可靠地存取不受插件内部结构限制的配置对象。

## ADDED Requirements

### Requirement: Installation creates one enabled instance with defaults

`POST /api/plugins/{code}/install` MUST 为当前用户创建唯一实例，写入服务端默认对象配置并设 `enabled=true`。成功 MUST 返回HTTP200和实例 `id`、`pluginId`、`code`、`name`、`config`、`enabled`。不存在的code MUST 返回404。调用方 MUST NOT 决定归属、初始配置或初始启用状态。

#### Scenario: Board installation includes both structures
- **WHEN** 当前用户首次安装 `quadrant-board`
- **THEN** 返回 `active=quadrant`，轴标签为紧急度和重要度，q1到q4名称依次为重要且紧急、重要不紧急、紧急不重要、不重要不紧急，p1到p3名称依次为顶层目标、中层计划、底层行动

#### Scenario: Pomodoro installation provides its label
- **WHEN** 当前用户首次安装 `pomodoro`
- **THEN** 返回配置 `{"label":"专注"}` 及 `enabled=true`，市场随后返回相同实例和配置

#### Scenario: Unknown plugin cannot be installed
- **WHEN** 客户端安装目录中不存在的code
- **THEN** 返回404和 `msg="插件不存在"`，不创建实例

#### Scenario: Different users receive independent defaults
- **WHEN** A安装并修改画板配置，B随后安装画板
- **THEN** B获得全新的默认配置对象，A的修改不传播给B

### Requirement: Duplicate installation is a conflict even under concurrency

同一 `(user_id, plugin_id)` MUST 由数据库唯一约束保护。已安装实例无论启用或禁用，再次安装 MUST 返回409和 `msg="插件已安装"`，原实例ID、配置和enabled MUST 保持不变。应用检查后的数据库重复冲突 MUST NOT 转为500。

#### Scenario: Disabled instance prevents reinstallation
- **WHEN** 用户再次安装已禁用的插件
- **THEN** 返回409，不重新启用或重置旧实例

#### Scenario: Concurrent installation has exactly one winner
- **WHEN** 同一用户同时提交两次首次安装同一插件的请求
- **THEN** 一次成功200、一次冲突409，数据库只有一条实例记录

#### Scenario: Constraint is enforced outside the API
- **WHEN** 直接向数据库写入第二条相同用户与插件的实例
- **THEN** 唯一约束拒绝重复记录

### Requirement: Configuration is an opaque object replaced as a whole

`PUT /api/user-plugins/{id}/config` MUST 以请求体本身作为新config并整体替换旧对象；不进行合并、内部字段校验或补默认值。成功 MUST 返回HTTP200及更新后的实例。对象内允许未知字段、嵌套数组、布尔值和null；JSON语义 MUST 在MySQL JSON原生数值精度范围内保留，原始空白和对象键顺序无需保留。需要精确保留的高精度数值 MUST 由调用方使用JSON字符串表达。

#### Scenario: Arbitrary object is stored without plugin schema validation
- **WHEN** 本人实例的配置被替换为 `{"foo":1,"nested":{"items":[true,null,"中文"]}}`
- **THEN** 更新响应和再次查询的config与提交对象语义相同，不补入active或label

#### Scenario: Empty object is accepted
- **WHEN** 本人实例提交 `{}`
- **THEN** config变为 `{}`，原对象的所有字段均被删除

#### Scenario: Precise numeric text remains unchanged
- **WHEN** 提交 `{"preciseDecimal":"0.123456789012345678"}`
- **THEN** 更新响应和再次查询均保留该字符串原值，不自动转为数值

#### Scenario: Body is not an envelope
- **WHEN** 本人实例提交 `{"config":{"foo":1}}`
- **THEN** 完整对象连同顶层config键被存储，不自动提取内层对象

#### Scenario: Structure switching retains only explicitly submitted structures
- **WHEN** 用户提交含 `active=pyramid`、旧quadrant命名和pyramid命名的完整对象
- **THEN** 两种结构均被保留；若提交时遗漏quadrant，则旧quadrant不会被后端合并回来

#### Scenario: Root is required to be an object
- **WHEN** 请求体缺失、JSON格式错误或根为null、数组、字符串、数字、布尔值
- **THEN** 返回400，原config和enabled均不改变

#### Scenario: Disabled instance can still be configured
- **WHEN** 本人禁用实例接受合法对象配置更新
- **THEN** 新配置被持久化，enabled仍为false

### Requirement: State changes accept only a JSON boolean

`PUT /api/user-plugins/{id}/enabled` MUST 接收对象中的布尔 `enabled`，只改变启用状态并原样保留config。成功 MUST 返回HTTP200及更新后的实例。字段缺失、null或非布尔值 MUST 返回400；重复设置当前状态 MUST 成功。

#### Scenario: Disable and reenable preserve configuration
- **WHEN** 本人实例先提交 `{"enabled":false}` 再提交 `{"enabled":true}`
- **THEN** enabled依次为false和true，两次操作均保留完整原配置

#### Scenario: Coercible values are rejected
- **WHEN** enabled为 `"true"`、`"false"`、0、1、null、数组或对象
- **THEN** 返回400，不将这些值自动转换成布尔值

#### Scenario: Repeating the current state succeeds
- **WHEN** 已禁用实例再次收到 `{"enabled":false}`
- **THEN** 返回200和该实例，不误判为404

#### Scenario: Extra fields cannot change another part of the instance
- **WHEN** 本人实例提交 `{"enabled":false,"config":{"foo":1},"userId":999}`
- **THEN** 只更新enabled，config和实例归属保持不变

### Requirement: Uninstall physically removes the instance

`DELETE /api/user-plugins/{id}` MUST 物理删除本人实例，成功返回HTTP200及 `{code:200,msg:"success",data:null}`。后续市场 MUST 显示未安装；重新安装 MUST 生成新实例ID和默认配置。重复删除旧ID MUST 返回404。

#### Scenario: Uninstall resets market status
- **WHEN** 本人已安装插件被卸载
- **THEN** 数据库不再存在旧实例，目录插件仍存在，市场 `installed=false` 且三个状态字段均为null

#### Scenario: Reinstall does not restore deleted customization
- **WHEN** 用户修改配置、卸载后重新安装同一插件
- **THEN** 返回与旧ID不同的新实例、默认配置及 `enabled=true`

#### Scenario: Old identifier remains absent
- **WHEN** 对已删除的旧ID再次删除、改配置或启停
- **THEN** 返回404，不重新创建旧实例或影响重装的新实例

### Requirement: Instance operations enforce authentication and ownership

安装及实例操作 MUST 受既有JWT鉴权保护，缺失或无效身份返回401。对语法有效的实例请求，合法正整数ID不存在 MUST 返回404，存在但属于他人 MUST 返回403。非整数、溢出、零或负数ID MUST 返回400。实例所有者 MUST 取自认证身份，不接受调用方覆盖。

#### Scenario: Other user cannot mutate an instance
- **WHEN** B对A实例发送合法的配置更新、启停或卸载请求
- **THEN** 每个操作均返回403和 `msg="无权操作该插件实例"`，A的实例保持不变

#### Scenario: Missing instance is distinct from forbidden instance
- **WHEN** 对不存在的合法正整数ID发送语法有效的实例操作
- **THEN** 返回404和 `msg="插件实例不存在"`

#### Scenario: Invalid identifier is a client error
- **WHEN** 实例操作ID为 `abc`、0、-1或超过Java Long上限
- **THEN** 返回400，不落入通用500响应

#### Scenario: Every plugin operation rejects an unauthenticated request
- **WHEN** 未携带token调用安装、配置、启停或卸载
- **THEN** 返回401，数据库保持不变

### Requirement: Concurrent mutations preserve independently owned fields

配置更新 MUST 只写config，启停 MUST 只写enabled，不得互相覆盖。相同字段的并发更新 MUST 按写入顺序采用最后成功提交的值；卸载之后的更新 MUST NOT 复活实例，已删除实例在更新前被发现时 MUST 返回404。

#### Scenario: Config and enabled updates do not lose each other's result
- **WHEN** 同一实例同时接受合法的新配置和禁用请求
- **THEN** 两次成功操作完成后，新config及 `enabled=false` 均保留

#### Scenario: Unchanged config is a successful replacement
- **WHEN** 用户再次提交语义相同的完整对象
- **THEN** 返回200，不因数据库报告没有变化而返回404

#### Scenario: Deletion precedes an update
- **WHEN** 卸载先完成，随后配置更新尝试操作旧ID
- **THEN** 更新返回404，数据库无旧实例，也不产生替代实例

### Requirement: API envelopes and error semantics remain consistent

插件接口成功 MUST 使用HTTP200、`code=200`、`msg="success"`；失败 MUST 使用对应HTTP状态作为code和 `data:null`。非预期服务器错误 MUST 为500及通用消息，不暴露SQL或异常堆栈。

#### Scenario: Database connection failure is not reported as duplicate installation
- **WHEN** 安装时发生非唯一冲突的数据库错误
- **THEN** 返回500和 `msg="服务器内部错误"`，不错误地报告409

#### Scenario: Unsupported update content type remains a client error
- **WHEN** 已鉴权用户向配置或启停更新接口发送非JSON Content-Type的请求
- **THEN** 返回HTTP415及 `code=415`、`msg="仅支持 application/json"`、`data=null`，不执行更新或返回500
