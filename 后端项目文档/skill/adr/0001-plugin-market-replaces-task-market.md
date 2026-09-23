# 插件市场取代任务市场，Plugin 成为独立实体

**Status**: accepted（2026-09-22）

v1 曾明确决策"后端只有 Task 一个实体，无 Plugin 概念，'插件'只是前端显示词"，并围绕此完成了 10 个切片的设计（仅切片 01-03 认证已编码）。2026-09-22 用户决定转向开放平台愿景：APP 只作为平台提供工具，软件形态由用户装配插件自行设计。因此我们废弃 Shared Task 市场与订阅体系（切片 04-10 归档至 issues/archive-v1/），市场改为提供平台预置的 Plugin（首批：画板、番茄钟）；Plugin 成为独立后端实体，用户安装形成 Installed Plugin（user_plugin 表，每用户每插件限一个实例），各插件的个性化配置统一存 user_plugin.config JSON 列、后端不透明处理。

**Considered Options**：
- 保留单实体、把画板/番茄钟做成特殊 Task —— 语义扭曲，象限配置/计时器塞进 Task 模型无法自洽。
- Plugin 纯前端、后端只存配置 JSON —— 市场无后端注册表，"开放平台"名不副实。
- 用户可发布插件/配置模板（UGC）—— 本质是社交，demo 版明确不做。

**Consequences**：画板 demo 阶段只做结构配置与预览（二维坐标轴 2×2 + 金字塔 3 层，单选生效），Task 分类待主系统开发时接入；番茄钟 config 仅存 label，计时纯前端运行；Task/Subscription 的既有设计暂缓而非删除，未来主系统开发时重新评审（Shared Task 概念已永久废弃）。
