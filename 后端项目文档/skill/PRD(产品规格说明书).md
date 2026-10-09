# Self-Mark App 后端 demo 版 PRD

**项目名称**: Self-Mark App
**所属公司**: nortidart
**版本**: demo（后端）
**创建日期**: 2026-09-22（重写自 v1 PRD，v1 内容见 git 历史与 archive-v1 切片）

领域术语定义见 [CONTEXT(业务术语).md](CONTEXT(业务术语).md)：Plugin、Task、Plugin Market、Installed Plugin、主系统、实验、画板、番茄钟、Time Window。本 PRD 全程使用这些规范术语。本次转型（插件市场取代任务市场）的决策依据见 [ADR 0001](docs/adr/0001-plugin-market-replaces-task-market.md)。

---

## 问题陈述

每个人的自律方式不同：有人用四象限划分任务轻重缓急，有人用金字塔分层目标与行动，有人只需要一个计时器专注当下。固定的软件形态无法适配所有人——用户被迫适应软件，而不是软件适应用户。

demo 版要验证的核心命题：**APP 只作为平台提供工具，软件的具体形态由用户通过安装、配置插件自行设计**。

---

## 解决方案

构建 Self-Mark App demo 版：一个开放平台的最小闭环。APP 分三个模块：**主系统**、**实验**、**插件市场**。

- **插件市场**（本 PRD 唯一开发对象）：参照智搭Edu 的市场形态，提供平台预置的 Plugin。用户可浏览、安装、配置、启停、卸载。demo 阶段插件的配置与功能预览均在插件市场的插件详情页内完成。
- **主系统**：用户装配插件后最终生效的容器（任务按画板象限分类、番茄钟出现于此）。demo 版不开发，仅文档占位。
- **实验**：预留模块。demo 版不开发，仅文档占位。

首批预置两个 Plugin：

1. **画板（quadrant-board）**：多结构任务分类工具。菜单栏提供多种划分结构，demo 版含**二维坐标轴**（固定 2×2 四象限）与**金字塔**（固定 3 层）两种；任一时刻只有一种结构生效，各结构的区域命名配置独立保留、切换不丢。用户可命名轴标签与各区域名称。demo 阶段仅配置与预览，Task 分类待主系统开发时接入。
2. **番茄钟（pomodoro）**：计时工具。配置仅存 label（计时对象，如"学习"）；计时时长在启动时由前端临时选择，不落库；计时纯前端运行，倒计时结束本地通知，后端不参与计时、不记录专注历史。

**认证模块**（注册/登录/登出，JWT + Redis 黑名单）已在 v1 切片 01-03 中完成开发，本 PRD 不再重复规格，仅作为既有能力引用。

核心闭环：**注册 → 登录 → 进插件市场 → 安装画板/番茄钟 → 个性化配置 → 预览自己的工具**。

---

## 用户故事

### 认证模块（已完成，切片 01-03）

1. 作为访客，我想用用户名和密码注册账号，以便使用 Self-Mark App
2. 作为已注册用户，我想用用户名密码登录获得 JWT token，以便后续 API 调用鉴权
3. 作为已登录用户，我想登出时 token 加入 Redis 黑名单，以便该 token 立即失效
4. 作为已登录用户，我想未携带或携带无效 token 访问受保护接口被拒绝，以便资源不被越权访问

### 插件市场模块

5. 作为已登录用户，我想浏览插件市场，看到平台预置的全部 Plugin（demo 版：画板、番茄钟），以便挑选安装
6. 作为已登录用户，我想市场列表中每个插件都展示我的安装状态（未安装/已安装/已禁用），以便一眼看清哪些已属于我
7. 作为已登录用户，我想点击安装某个 Plugin，系统自动为我创建 Installed Plugin 实例并写入该插件的默认配置，以便开箱即用
8. 作为已登录用户，我想对同一个 Plugin 重复安装被拒绝，以便我的每款工具只有一份
9. 作为已登录用户，我想卸载已安装的 Plugin，其实例与配置数据一并删除，以便清理不再需要的工具
10. 作为已登录用户，我想禁用已安装的 Plugin 但保留配置，以便暂时不用又不丢个性化设置
11. 作为已登录用户，我想重新启用被禁用的 Plugin，以便恢复使用且配置原样回来
12. 作为已登录用户，我想服务器拒绝我操作别人的 Installed Plugin，以便实例归属清晰
13. 作为已登录用户，我想未登录状态下无法访问市场接口，以便平台资源受保护

### 画板插件

14. 作为已安装画板的用户，我想看到菜单栏中有多种划分结构（demo 版：二维坐标轴、金字塔），以便选择适合自己的任务划分法
15. 作为已安装画板的用户，我想任一时刻只有一种结构生效，以便任务分类维度唯一、不混乱
16. 作为已安装画板的用户，我想切换生效结构时另一种结构的命名配置被保留，以便随时切回不丢设置
17. 作为已安装画板的用户，我想修改二维坐标轴的 X/Y 轴标签，以便定义自己的划分维度（如紧急度×重要度）
18. 作为已安装画板的用户，我想修改四个象限的名称，以便形成自己的分类语言
19. 作为已安装画板的用户，我想修改金字塔各层的名称，以便匹配自己的目标分层（如顶层目标/中层计划/底层行动）
20. 作为已安装画板的用户，我想安装时各结构就有合理的默认命名，以便不配置也能直接使用
21. 作为已安装画板的用户，我想在插件详情页预览当前配置渲染出的坐标轴/金字塔，以便确认效果

### 番茄钟插件

22. 作为已安装番茄钟的用户，我想给计时器设置一个 label（计时对象，如"学习"），以便知道自己计时的是什么事情
23. 作为已安装番茄钟的用户，我想开始计时时临时选择一个时长，以便每次按当下需要灵活决定
24. 作为已安装番茄钟的用户，我想倒计时结束时收到本地通知，以便知道时间到
25. 作为已安装番茄钟的用户，我想计时过程完全在 APP 本地运行，以便断网也能正常使用

### 数据约束与边界

26. 作为系统，我想 plugin 表 code 字段唯一，以便前端按 code 稳定路由到对应插件界面
27. 作为系统，我想 user_plugin 表 (user_id, plugin_id) 唯一，以便从数据库层防止重复安装
28. 作为系统，我想画板与番茄钟两条 Plugin 通过启动时 seed 注入，以便所有用户看到相同的市场内容
29. 作为系统，我想 user_plugin.config 以 JSON 存储且后端不校验其内部结构，以便未来新增插件类型时后端零改动
30. 作为系统，我想安装时由后端按插件 code 写入对应的默认 config，以便默认值逻辑集中在一处

---

## 实现决策

### 技术栈

沿用 v1 已定栈，无变化：Java 21 + Spring Boot 3.x + Maven + MyBatis-Plus + MySQL 8 + Redis + JWT 单 token 鉴权。包根 `com.nortidart.selfmark`。

### 模块划分

- **认证模块（auth）**：已完成，不动
- **插件模块（plugin，本次新建）**：市场查询、安装、配置更新、启停、卸载
- **主系统 / 实验**：不建代码包，仅文档标注预留
- 代码中 v1 遗留的 task/subscription 空包：保留不动，未来主系统开发时再评审

### 数据模型 Schema

两张新表（user 表已存在，不动）：

```
plugin
- id              BIGINT PK AUTO_INCREMENT
- code            VARCHAR(50)  NOT NULL UNIQUE  -- 插件标识: quadrant-board / pomodoro；前端据此路由渲染
- name            VARCHAR(50)  NOT NULL         -- 显示名: 画板 / 番茄钟
- description     VARCHAR(500) NULL             -- 市场卡片展示文案
- sort            INT          NOT NULL DEFAULT 0  -- 市场展示排序，小的在前
- created_at      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP

user_plugin
- id              BIGINT PK AUTO_INCREMENT
- user_id         BIGINT       NOT NULL
- plugin_id       BIGINT       NOT NULL
- config          JSON         NOT NULL          -- 各插件结构自定义，后端不透明存取
- enabled         TINYINT(1)   NOT NULL DEFAULT 1
- created_at      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP
- UNIQUE KEY uk_user_plugin (user_id, plugin_id)
- INDEX idx_user (user_id)
```

seed 数据（启动时注入，两表各相关部分）：

- `plugin`: (code=quadrant-board, name=画板, sort=1)、(code=pomodoro, name=番茄钟, sort=2)
- 安装时后端按 code 写入默认 config：

画板默认 config：

```json
{
  "active": "quadrant",
  "quadrant": {
    "xAxisLabel": "紧急度",
    "yAxisLabel": "重要度",
    "regions": [
      {"key": "q1", "name": "重要且紧急"},
      {"key": "q2", "name": "重要不紧急"},
      {"key": "q3", "name": "紧急不重要"},
      {"key": "q4", "name": "不重要不紧急"}
    ]
  },
  "pyramid": {
    "regions": [
      {"key": "p1", "name": "顶层目标"},
      {"key": "p2", "name": "中层计划"},
      {"key": "p3", "name": "底层行动"}
    ]
  }
}
```

番茄钟默认 config：

```json
{"label": "专注"}
```

### API 契约

所有接口需 `Authorization: Bearer <jwt>` 头。统一响应体 `{code, msg, data}`（沿用 v1 约定）。

| 方法 | 路径 | 鉴权 | 说明 |
|---|---|---|---|
| GET | /api/plugins | 是 | 市场列表：全部 Plugin（按 sort asc），每个附带当前用户安装状态：installed、userPluginId、enabled、config（未安装则为 null） |
| POST | /api/plugins/{code}/install | 是 | 安装：创建 user_plugin（写入该插件默认 config、enabled=1），返回创建的实例；code 不存在 404；已安装过 409 |
| PUT | /api/user-plugins/{id}/config | 是 | 整体替换 config（body 为 JSON 对象，后端不透明存储）；仅本人实例可操作，否则 403；id 不存在 404 |
| PUT | /api/user-plugins/{id}/enabled | 是 | body: {enabled: bool}；启停实例；仅本人，否则 403；id 不存在 404 |
| DELETE | /api/user-plugins/{id} | 是 | 卸载：删除实例及其全部数据；仅本人，否则 403；id 不存在 404 |

### 关键架构决策

1. **Plugin 与 Task 双实体分离**：Plugin 是工具（无 Time Window、不产生提醒），Task 是日程项（暂缓开发）。市场只提供 Plugin。决策依据见 ADR 0001。
2. **平台预置，无 UGC**：Plugin 由平台 seed，用户只能浏览/安装/配置；无发布渠道、无作者体系、无审核流。
3. **单实例约束**：每用户对同一 Plugin 限一个 Installed Plugin，由 DB 唯一约束兜底，应用层先检查后插入并捕获约束冲突转 409。
4. **config JSON 不透明**：后端只负责存取整个 JSON 对象，不解析、不校验内部结构；各插件的配置语义由前端按插件 code 处理；默认值由后端在安装时按 code 写入（默认值逻辑集中在后端一处，前端不内置默认值）。
5. **卸载即物理删除**：demo 版无子表数据，删除 user_plugin 单行即完成卸载；不做软删除。
6. **市场单接口带状态**：`GET /api/plugins` 一次返回全部插件与安装状态，前端自由组织"全部/我的"等 UI 形态，后端不拆接口。
7. **番茄钟纯前端计时**：后端只持久化 label；计时时长运行时选择不落库；不做专注记录。
8. **画板结构单选生效**：config 中 active 字段标记当前生效结构，各结构配置并列存储、切换不丢；新增结构类型时后端零改动（config 不透明）。
9. **主系统/实验不开发**：demo 版不建代码包、不建前端目录，仅在文档中占位；画板的 Task 分类能力随主系统开发时接入。
10. **v1 任务市场/订阅体系废弃**：Shared Task、System Task 概念永久废弃；Task/Subscription 相关设计归档（issues/archive-v1/）暂缓，未来重启时重新评审（Subscription 可能简化为自订阅，Task 默认私有）。

### 不可逆操作的事务边界

- 安装：`insert user_plugin` 为单条 SQL，唯一约束 uk_user_plugin 防并发重复安装，冲突转 409
- 卸载：`delete user_plugin` 为单条 SQL，demo 版无关联子表
- 配置更新：`update user_plugin set config=?` 整体替换，无增量合并语义（前端总是提交完整 JSON）

### 错误码约定（沿用 v1）

- 200 / 0：成功
- 400：参数校验失败（缺字段、config 非合法 JSON、enabled 非布尔等）
- 401：未登录或 token 无效或 token 在黑名单
- 403：已登录但无权操作（操作别人的 Installed Plugin）
- 404：资源不存在（plugin code 或 user_plugin id 不存在）
- 409：冲突（对同一 Plugin 重复安装）
- 500：服务器内部错误

---

## 测试决策

### 测试原则

- 只测外部行为，不测实现细节
- 不测 MyBatis-Plus 自带 CRUD、JWT 库内部、Redis 连接本身
- 优先用最高的接缝（Controller 层 MockMvc），复杂业务规则下沉到 Service 层单元测试

### 测试接缝

1. **Controller 层 MockMvc 测试（主）**：
   - 市场列表：只含两条 seed 插件；未安装时状态字段为 null；已安装时带 config/enabled
   - 安装：成功（返回默认 config）/ 重复安装（409）/ code 不存在（404）/ 未登录（401）
   - 改配置：成功 / 改别人实例（403）/ id 不存在（404）/ config 非 JSON（400）
   - 启停：成功 / 操作别人实例（403）
   - 卸载：成功 / 操作别人实例（403）/ id 不存在（404）

2. **Service 层单元测试（辅）**：
   - 单实例约束：同用户同插件二次安装抛业务异常
   - config 不透明：存入任意 JSON 结构原样取回，后端不校验内部字段
   - 默认值写入：按不同 code 生成对应默认 config（画板含两结构、番茄钟含 label）
   - 卸载连带删除实例

3. **集成测试（关键路径，SpringBootTest + Testcontainers）**：
   - 端到端闭环：注册 → 登录 → 拉市场（见画板+番茄钟）→ 安装画板（返回默认四象限配置）→ 修改象限名称 → 再拉市场验证持久化 → 禁用 → 启用（配置原样）→ 卸载 → 市场恢复未安装状态
   - 番茄钟路径：安装 → 默认 label="专注" → 改 label → 验证持久化
   - 跨用户隔离：用户 A 安装后，用户 B 的市场列表不受影响；B 操作 A 的实例 403

### 测试数据

- Plugin seed 在集成测试启动时通过同一套 seed 机制注入
- 用户测试数据：每个测试用例自己注册，不依赖共享 fixture 用户

---

## 不在范围

demo 版明确不做：

- **主系统功能开发**：不含 Task CRUD、画板对 Task 的实际分类、番茄钟在主系统的呈现
- **实验模块**：纯文档占位
- **插件 UGC**：无用户发布插件、无配置模板分享、无审核流
- **多实例**：同一插件每用户限装一个
- **config 后端深度校验**：结构合法性由前端负责
- **专注记录/统计**：番茄钟不记录任何历史
- **插件图标资源管理**：icon 由前端按 code 内置，后端不存图
- **任务提醒闭环**（Time Window 双边界通知、schedule 下发）：随主系统一并暂缓
- **v1 已废弃概念的一切实现**：Shared Task、System Task、任务订阅
- **社交、搜索、分类、标签**
- **修改密码 / 找回密码 / 多端登录管控**（沿用 v1 决策）
- **前端 Flutter 实现**：本 PRD 仅描述后端 demo 版

---

## 其他说明

### 领域术语

所有术语定义见 [CONTEXT(业务术语).md](CONTEXT(业务术语).md)。本 PRD 全程使用规范术语。严禁混用：Plugin ≠ Task；Installed Plugin 不叫"订阅的插件"。

### 未来扩展点

- 主系统开发：Task CRUD、画板 Task 分类接入、番茄钟主系统入口
- 实验模块
- 更多划分结构（四列表、同心圆等）——config 不透明，后端零改动
- 更多预置插件
- 插件 UGC 与配置模板分享
- 专注记录与习惯可视化
- 金字塔层数可配置

### 未决细节（实现时定）

- plugin 表 name/description 的最终文案
- seed 注入方式（建议启动脚本，与 v1 思路一致）
- config JSON 大小上限（建议 ≤ 4KB，防滥用）
- 画板各结构的默认文案是否随地区/语言调整（demo 版中文写死）
- 接口文档工具（v1 建议 SpringDoc/Knife4j，继续沿用）

### 关于此 PRD

- 此 PRD 由 grill-with-docs + to-prd 流程产出，全部决策已经 11 轮盘问敲定
- 转型决策依据见 [ADR 0001](docs/adr/0001-plugin-market-replaces-task-market.md)
- v1 PRD 的用户故事与决策已被本文件取代；v1 任务/订阅切片归档于 issues/archive-v1/ 供未来主系统开发时参考
