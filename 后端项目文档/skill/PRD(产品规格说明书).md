# Self-Mark App 后端 v1 PRD

**项目名称**: Self-Mark App
**所属公司**: nortidart
**版本**: v1 (后端)
**创建日期**: 2026-09-04

领域术语定义见 [CONTEXT.md](../CONTEXT.md)：Task、Time Window、Subscription、Shared Task、Private Task、System Task。本 PRD 全程使用这些规范术语。

---

## 问题陈述

人普遍存在自律不足、拖延严重、内驱力缺乏的问题。即便用户主观上"想养成好习惯"（如每天喝水、考研复习、傍晚散步），也常常因为缺少**到点的明确提醒**和**对承诺的可视化承接**而中断。

现有的解决方案各有缺陷：

- 系统闹钟：到点提醒一次就完，没有"开始 + 结束"双重边界，没有承诺承接，容易关掉就忘
- 待办清单 App：以"完成单次任务"为核心，不是"每天重复执行"的承诺模型
- 习惯打卡 App：侧重"记录完成"，但缺少"插件式订阅 + 时间段双提醒"的轻量承诺模型

用户需要一个**轻量、可订阅、到点双边界提醒、可自建可共享**的自律辅助 App，把"想做的事"变成"每天到点被提醒去做的事"。

---

## 解决方案

构建 **Self-Mark App**：一个以"插件市场 + 订阅承诺 + 每日定时双边界提醒"为核心的自律辅助应用。后端 v1 提供：

1. **用户认证**：手机号作为账号 + 密码注册登录，JWT 单 token 鉴权
2. **插件市场**：展示 System Task（系统预置 3 条）+ 别人发布的 Shared Task
3. **任务订阅**：用户在市场订阅 Task，**订阅时自行定义 Time Window**
4. **任务自建**：用户可创建自己的 Private Task；可把 Private Task 单向发布为 Shared Task 进入市场
5. **每日 schedule 下发**：后端下发当日 schedule，APP 拉取后注册本地通知实现双边界提醒（起点弹窗"该开始了"、终点弹窗"时间到"）

核心闭环：**注册 → 进市场 → 订阅/创建 → 每天到点提醒 → 形成习惯**

---

## 用户故事

### 认证模块

1. 作为访客，我想用手机号、密码和用户名注册账号，以便使用 Self-Mark App
2. 作为访客，我想注册时密码被 bcrypt 加密存储，以便即使数据库泄露密码也不会被还原
3. 作为访客，我想注册时手机号重复被拒绝，以便一个手机号只对应一个账号
4. 作为已注册用户，我想用手机号和密码登录获得 JWT token，以便后续 API 调用鉴权
5. 作为已登录用户，我想登出时 token 加入 Redis 黑名单，以便该 token 立即失效
6. 作为已登录用户，我想未携带或携带无效 token 访问受保护接口被拒绝，以便资源不被越权访问

### 任务模块（task）

7. 作为已登录用户，我想浏览插件市场，看到所有 System Task 和别人发布的 Shared Task，以便挑选订阅
8. 作为已登录用户，我想市场列表不展示 Private Task，以便私有任务不被他人看到
9. 作为已登录用户，我想市场列表不展示已撤回或已冻结的 Task，以便列表干净
10. 作为已登录用户，我想创建 Private Task（带 name、content），以便定义自己每天要做的活动
11. 作为已登录用户，我想创建 Private Task 后自动生成一条自己订阅自己的 Subscription，以便无需再手动订阅
12. 作为 Private Task 的作者，我想修改自己 Private Task 的 name 和 content，以便调整任务定义
13. 作为 Private Task 的作者，我想删除自己 Private Task（连带删除自己的 Subscription），以便清理不再需要的任务
14. 作为 Private Task 的作者，我想把自己的 Private Task 发布到市场变成 Shared Task，以便让其他用户订阅
15. 作为作者，我想 `PRIVATE → SHARED` 是单向不可逆操作，被服务器拒绝反向转换，以便发布后状态稳定
16. 作为已发布 Shared Task 的作者，我想服务器拒绝我对该 Task 的 name/content 修改请求，以便已订阅者的体验不被打断
17. 作为已发布 Shared Task 的作者，我想服务器拒绝我撤回 Shared Task 共享的请求，以便已订阅者的承诺不被剥夺
18. 作为已发布 Shared Task 的作者，我想服务器拒绝我删除 Shared Task 的请求，以便已订阅者的订阅引用不变成孤儿
19. 作为访客或非作者，我想服务器拒绝我修改/删除别人创建的 Task，以便任务归属清晰
20. 作为任何用户，我想 System Task（喝水/考研/散步）的 name/content 永远不可被任何用户修改，以便系统任务保持稳定

### 订阅模块（subscription）

21. 作为已登录用户，我想订阅市场上的 System Task 或 Shared Task，body 带 start_time 和 end_time，以便定义自己的执行 Time Window
22. 作为已登录用户，我想订阅时服务器校验 `end_time > start_time`，拒绝跨天或同时段，以便 v1 不处理跨天逻辑
23. 作为已登录用户，我想对同一个 Task 重复订阅被拒绝，以便一个用户对一个 Task 只有一份承诺
24. 作为已登录用户，我想取消自己的 Subscription，以便不再被该 Task 提醒
25. 作为已登录用户，我想修改自己 Subscription 的 start_time 和 end_time，以便调整执行时段
26. 作为已登录用户，我想修改自己 Subscription 的 enabled 字段（暂停/启用），以便临时关闭某个 Task 的提醒而不删除订阅
27. 作为已登录用户，我想服务器拒绝我修改别人 Subscription，以便订阅归属清晰
28. 作为已登录用户，我想查询"我的任务"列表（自己创建的 Private + 自己订阅的 System/Shared），以便统一查看所有承诺
29. 作为已登录用户，我想拉取当日 schedule（含我所有 enabled=true 的 Subscription 对应 Task 的 name/content + Time Window），以便 APP 注册本地通知
30. 作为已登录用户，我想当日 schedule 中 enabled=false 的 Subscription 不出现在 schedule 里，以便暂停的任务不打扰我
31. 作为已登录用户，我想当日 schedule 接口对同一用户同一天返回相同结果（Redis 缓存到当天 23:59），以便同一天多次拉取不被作者可能的内容变化打断
32. 作为已登录用户，我想第二天 schedule 缓存自然失效后重新查 DB 拉取，以便看到作者发布的新 Shared Task 或新创建的 System Task

### 数据约束与边界

33. 作为系统，我想 user 表 mobile 唯一，以便登录账号冲突可避免
34. 作为系统，我想 task 表 type 字段为枚举（SYSTEM/SHARED/PRIVATE），shared 字段为 bool，以便类型与共享状态清晰
35. 作为系统，我想 subscription 表 (user_id, task_id) 唯一，以便防止重复订阅
36. 作为系统，我想 System Task 通过启动时 seed 注入（喝水、考研、散步三条），无 creator_id，以便所有用户共享引用
37. 作为系统，我想 Private Task 的 creator_id = 创建者 user_id，shared=false，以便区分归属
38. 作为系统，我想 Shared Task 的 creator_id = 作者 user_id，shared=true，以便市场筛选

---

## 实现决策

### 技术栈

- **语言/运行时**: Java 21
- **框架**: Spring Boot 3.x
- **构建工具**: Maven
- **ORM**: MyBatis-Plus
- **数据库**: MySQL 8
- **缓存**: Redis（用于 JWT 黑名单 + schedule 当日缓存）
- **认证**: JWT 单 token + Redis 黑名单登出
- **不引入 MQ**：v1 用不到，未来转服务端推送时再考虑
- **包根**: `com.nortidart.selfmark`（公司名 nortidart + 项目名 selfmark）

### 模块划分（按领域而非按技术分层组织 controller/service）

后端 v1 分三个领域模块 + 基础设施：

- **基础设施（common + config）**：统一响应体、全局异常处理、JWT 工具与拦截器、Redis 工具、参数校验
- **认证模块（auth）**：注册、登录、登出
- **任务模块（task）**：market 查询、Private Task CRUD、PRIVATE → SHARED 发布
- **订阅模块（subscription）**：订阅、取消、改 Time Window/enabled、schedule 下发

### 数据模型 Schema

三张主表（schema 决策的关键部分，inline 表达更精确）：

```
user
- id              BIGINT PK AUTO_INCREMENT
- mobile          VARCHAR(20)  NOT NULL UNIQUE -- 登录账号，中国大陆手机号
- password        VARCHAR(100) NOT NULL  -- bcrypt 加密后
- username        VARCHAR(50)  NOT NULL -- 用户展示名，不用于登录
- created_at      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP

task
- id              BIGINT PK AUTO_INCREMENT
- name            VARCHAR(100)  NOT NULL
- content         VARCHAR(500)  NULL
- type            VARCHAR(20)   NOT NULL  -- 枚举: SYSTEM / SHARED / PRIVATE
- creator_id      BIGINT        NULL      -- SYSTEM 任务为 NULL，其他为创建者 user.id
- shared          TINYINT(1)    NOT NULL DEFAULT 0  -- 是否发布到市场；SYSTEM=1, SHARED=1, PRIVATE=0
- created_at      DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP
- INDEX idx_creator (creator_id)
- INDEX idx_shared_type (shared, type)

subscription
- id              BIGINT PK AUTO_INCREMENT
- user_id         BIGINT       NOT NULL
- task_id         BIGINT       NOT NULL
- start_time      TIME         NOT NULL  -- HH:mm:ss
- end_time        TIME         NOT NULL  -- HH:mm:ss, 必须 > start_time
- enabled         TINYINT(1)   NOT NULL DEFAULT 1
- created_at      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP
- UNIQUE KEY uk_user_task (user_id, task_id)
- INDEX idx_user_enabled (user_id, enabled)
```

约束（DB 层 + 应用层）：
- task.type 与 task.shared 的对应关系由应用层保证：SYSTEM → shared=1；SHARED → shared=1；PRIVATE → shared=0
- System Task seed 三条：name='喝水' / '考研' / '散步'，type=SYSTEM，creator_id=NULL，shared=1
- subscription.start_time < subscription.end_time 由应用层校验（v1 不支持跨天）

### API 契约

所有受保护接口需 `Authorization: Bearer <jwt>` 头。统一响应体 `{code, msg, data}`。

| 方法 | 路径 | 鉴权 | 说明 |
|---|---|---|---|
| POST | /api/auth/register | 否 | body: {mobile, password, username}；返回 {id, mobile, username, token} |
| POST | /api/auth/login | 否 | body: {mobile, password}；返回 {id, mobile, username, token} |
| POST | /api/auth/logout | 是 | 把当前 token jti 加入 Redis 黑名单（TTL=token 剩余有效期）|
| GET | /api/tasks/market | 是 | 返回 market 列表：所有 SYSTEM + 所有 SHARED（shared=1）；按 created_at desc |
| POST | /api/tasks | 是 | body: {name, content}；创建 PRIVATE Task（type=PRIVATE, shared=0, creator_id=me）；同时自动生成一条 Subscription（自己订阅自己，Time Window 由 body 提供）|
| PUT | /api/tasks/{id} | 是 | 修改 name/content；仅当 type=PRIVATE 且 creator_id=me 通过；SHARED/SYSTEM 一律 403 |
| DELETE | /api/tasks/{id} | 是 | 删除 Task + 连带删除该 task 所有 Subscription；仅当 type=PRIVATE 且 creator_id=me 通过；SHARED/SYSTEM 一律 403 |
| POST | /api/tasks/{id}/share | 是 | 把 PRIVATE Task 发布为 SHARED：type 改为 SHARED，shared=1；仅当 type=PRIVATE 且 creator_id=me 通过；SHARED/SYSTEM 一律 403（单向不可逆）|
| GET | /api/tasks/mine | 是 | 返回我创建的 Task 列表（creator_id=me）|
| POST | /api/subscriptions | 是 | body: {task_id, start_time, end_time}；订阅市场上的 Task（仅可订阅 SYSTEM 或 SHARED）；(user_id, task_id) 唯一约束；Private Task 不可被非作者订阅 |
| DELETE | /api/subscriptions/{id} | 是 | 取消订阅；仅当 user_id=me 通过 |
| PUT | /api/subscriptions/{id} | 是 | body: {start_time?, end_time?, enabled?}；修改自己的订阅；仅当 user_id=me 通过 |
| GET | /api/subscriptions/schedule | 是 | 返回当日 schedule：该用户所有 enabled=1 的 Subscription，JOIN task 表取 name/content，按 start_time asc 排序；Redis 缓存 key=`selfmark:schedule:{user_id}:{date}` TTL 到当天 23:59:59 |

### 关键架构决策

1. **Subscription 是引用不是快照**：subscription 只存 task_id，不冗余 task 的 name/content。作者撤回/修改（虽然 SHARED 已禁止）等变化通过 JOIN 自然反映。
2. **SHARED Task 完全冻结**：发布后不可改 name/content、不可撤回共享、不可删除。`PRIVATE → SHARED` 单向不可逆。这避免了"作者改了影响订阅者"的所有边界问题。
3. **PRIVATE Task 可改可删**：作者对自己的 Private Task 有完全控制权。PRIVATE 无外部订阅者（只有自己自动生成的那条 Subscription），改/删只影响自己。
4. **System Task 永久不可变**：3 条 seed 数据，任何用户都不可改/删/订阅状态改变。所有用户都可订阅 System Task。
5. **完成记录 v1 不做**：v1 只做提醒闭环，不记录用户每天是否完成。完成打卡 + 习惯可视化放 v2。
6. **跨天任务 v1 不支持**：subscription.start_time < end_time 由应用层校验。睡眠任务等跨天场景留给 v2 专门设计。
7. **APP 每日 schedule 单次拉取 + 用户主动下拉刷新**：APP 当天首次打开拉一次 schedule 存本地（SharedPreferences/SQLite），注册本地通知后当天不再拉；用户可下拉刷新强制重新拉。后端 Redis 缓存 schedule 接口到当天 23:59，保证同一天多次拉取结果一致（避免作者当天创建新 SHARED Task 导致当天 schedule 抖动）。
8. **订阅级别暂停，无全局暂停**：subscription.enabled 字段控制单条订阅是否进 schedule；v1 不在 user 表加 pause_all 之类字段。全局"今日勿扰"由 APP 端实现（不调 schedule/不注册本地通知）。
9. **JWT 单 token + Redis 黑名单**：登录返回单个 JWT，TTL 较长（如 7 天）；登出时把 token 的 jti 加入 Redis 黑名单（key=`selfmark:auth:jwt:blacklist:{jti}`，TTL=token 剩余有效期），JWT 拦截器每次请求查黑名单。不引入 refresh token，简化 v1。
10. **不引入 MQ**：APP 本地通知方案下后端不需要到点调度推送，MQ 无角色。未来转服务端推送时再引入。
11. **不引入版本化**：作者不能改 SHARED Task，所以不需要 task 表 version 字段；订阅是引用自然跟随（但 SHARED 冻结意味着实际上不会跟随）。
12. **APP 本地通知 + 后端只下发 schedule**：后端不做定时调度推送，只下发当日 schedule 给 APP，APP 用 Flutter 本地通知插件注册当天 Time Window 起点+终点的本地通知。

### 不可逆操作的事务边界

- 创建 Private Task：`insert task` + `insert subscription(user_id=me, task_id=new, start_time, end_time)` 必须在**同一事务**内，避免出现"task 创建了但没有自动订阅"的中间态
- 删除 Private Task：`delete subscription where task_id=X` + `delete task where id=X` 必须在**同一事务**内
- 发布 PRIVATE → SHARED：`update task set type=SHARED, shared=1` 是单条 SQL，但状态校验（type 必须当前是 PRIVATE）必须在事务内带条件检查

### 错误码约定（统一响应体）

- 200 / 0：成功
- 400：参数校验失败（缺字段、格式错、end_time <= start_time 等）
- 401：未登录或 token 无效或 token 在黑名单
- 403：已登录但无权操作（改别人 Task、改别人 Subscription、对 SHARED Task 改/删/撤回等）
- 404：资源不存在（task_id 或 subscription_id 不存在）
- 409：冲突（手机号已注册、对同一 task 重复订阅、PRIVATE → SHARED 反向转换）
- 500：服务器内部错误

---

## 测试决策

### 测试原则

- 只测外部行为，不测实现细节
- 不测 MyBatis-Plus 自带 CRUD、JWT 库内部、Redis 连接本身
- 优先用最高的接缝（Controller 层 MockMvc），复杂业务规则下沉到 Service 层单元测试

### 测试接缝

1. **Controller 层 MockMvc 测试（主）**：每个 API 端点的成功 + 错误响应。覆盖：
   - 认证：register 成功 / 用户名重复（409）/ 缺字段（400）；login 成功 / 密码错（401）/ 用户不存在（401）；logout 后 token 进黑名单、再次用该 token 访问受保护接口（401）
   - 任务：market 列表只含 SYSTEM+SHARED；创建 PRIVATE 成功；改 PRIVATE 成功 / 改 SHARED（403）/ 改别人 Task（403）；删 PRIVATE 成功 / 删 SHARED（403）；share PRIVATE 成功 / share 已 SHARED（409）/ share 别人 Task（403）
   - 订阅：订阅市场 Task 成功 / 重复订阅（409）/ 订阅 PRIVATE Task（403 或 404）/ end_time <= start_time（400）；取消自己订阅成功 / 取消别人订阅（403）；改自己订阅时间段成功 / 改别人订阅（403）；schedule 下发正确字段、enabled=false 的不出现

2. **Service 层单元测试（辅）**：纯业务规则，Mockito mock 掉 Mapper。重点：
   - SHARED Task 完全冻结逻辑：update/delete/share 反向转换全部抛业务异常
   - PRIVATE → SHARED 单向：从 SHARED 退回 PRIVATE 抛异常
   - Time Window 校验：end_time <= start_time 抛异常
   - Subscription 跨用户改：user_id != me 抛异常
   - 创建 Private Task 时自动 Subscription 在同一事务

3. **集成测试（关键路径）**：SpringBootTest + Testcontainers（MySQL 8 + Redis）
   - 端到端用户闭环：注册 → 登录 → 拉市场（看到 3 条 System Task）→ 订阅"喝水"（07:00-07:30）→ 拉 schedule（含喝水的 name/content + Time Window）→ 改自己 subscription 时间段为 08:00-08:30 → 再次拉 schedule 验证时间段变化
   - 跨用户共享流程：用户 A 创建 Private Task "夜读" → share → 用户 B 拉市场看到"夜读" → B 订阅 → B 拉 schedule 含"夜读"内容（来自 task 表 JOIN）→ A 尝试改"夜读" name（403 拒绝）→ A 尝试撤回（403 拒绝）→ A 尝试删除（403 拒绝）
   - schedule 当日缓存验证：同一用户同一天两次拉 schedule，返回完全相同；模拟作者当天创建新 SHARED Task 后用户再拉 schedule，仍返回旧版（缓存命中）；跨天后缓存失效重新查 DB

### 测试数据

- System Task seed 在集成测试启动时通过 SQL 脚本注入（与生产同一份 seed 脚本）
- 用户测试数据：每个测试用例自己注册，不依赖共享 fixture 用户

---

## 不在范围

v1 明确不做：

- **完成记录 / 打卡**：不记录用户每天是否完成 Task；连续天数、本月完成率等不放 v1
- **跨天任务**：subscription.start_time 必须小于 end_time；睡眠任务等场景留 v2
- **全局暂停**：不在 user 表加 pause_all 字段；今日勿扰由 APP 端实现
- **社交**：无好友、团队、互相监督、关注等
- **任务搜索 / 分类 / 标签**：market 列表只按 created_at desc 排序，不支持搜索/分类
- **修改密码 / 找回密码**：v1 不做，密码忘了只能重新注册
- **短信验证码登录/注册**：v1 已以手机号作为账号，但只支持密码；验证码生成、校验和发送留后续版本
- **refresh token**：v1 单 token，不做双 token
- **MQ**：v1 不引入消息队列；后续短信验证码场景可用 RabbitMQ 异步解耦短信发送，但验证码校验不能只依赖 MQ
- **服务端推送（FCM/极光）**：v1 仅 APP 本地通知，不接推送服务
- **管理员后台 / System Task 管理**：v1 System Task 写死在 seed，没有管理员修改入口
- **任务版本化**：SHARED 冻结，无 version 字段
- **撤回共享**：发布即终态，无撤回动作
- **作者对 SHARED Task 的任何操作**：完全无操作权
- **前端 Flutter 实现**：本 PRD 仅描述后端 v1，前端 Flutter 工程后续另起 PRD
- **多端登录管控**：v1 同一账号多端登录不做限制，token 各自独立

---

## 其他说明

### 领域术语

所有术语定义见 [CONTEXT.md](../CONTEXT.md)。本 PRD 全程使用规范术语，前后端共享。前端在 UI 文案上可叫"插件"，但后端代码与文档统一用 Task。

### 未来扩展点（v2+）

- 完成记录 + 习惯可视化（连续天数、本月完成率）
- 跨天任务支持（睡眠任务）
- 全局暂停（后端 user 表加字段）
- 社交（好友、团队、互相监督）
- 任务搜索 / 分类 / 标签
- refresh token 双 token 鉴权
- 服务端推送（FCM/极光）替代/补充本地通知
- 任务版本化（作者发布新版 + 订阅者自主升级）
- 管理员后台（管理 System Task、用户管理）
- 修改密码 / 找回密码（短信验证码验证）
- 短信验证码注册/登录（Redis 保存短期验证码，RabbitMQ 异步投递短信发送任务）
- 多端登录管控

### 未决细节（实现时定）

- task.name / content 长度上限（建议 name ≤ 50，content ≤ 500）
- JWT 算法（HS256 + 服务端密钥）与 TTL（建议 7 天）
- 接口文档工具（建议 SpringDoc OpenAPI / Knife4j，便于前端联调）
- 系统任务 seed 注入方式（建议 SQL 脚本 + Spring Boot 启动时执行，或 Flyway 管理）
- CORS 配置（前后端分离必须，允许前端域名）
- 统一响应体具体字段名（建议 `{code: int, msg: string, data: object}`）

### 关于此 PRD

- 此 PRD 由 grill-with-docs + to-prd 流程产出，所有决策已在对话中盘清
- 决策依据、术语演化、被否决的备选方案见对话历史
- CONTEXT.md 与本 PRD 配套使用：CONTEXT.md 是术语 glossary，本 PRD 是规格说明
