# Self-Mark App（自律 App）

一个帮助人养成自律习惯、克服拖延、提升内驱力的应用。本文档定义业务领域术语，前后端共享。

## 术语表

**Plugin（插件）**:
平台提供的工具/模板（如画板、番茄钟），用户在插件市场浏览、安装到自己的主系统并进行个性化配置。Plugin 是工具，不是日程：本身没有 Time Window，不产生提醒。插件通过增强 Task（如象限分类）或提供独立功能（如计时器）来定制主系统。
_Avoid_: 模板（口语可接受，代码用 Plugin）, 任务（严禁混用：Plugin 不是 Task）

**Task**:
用户每天需要执行的具体活动，由名字、内容、Time Window 构成，属于主系统内的日程项。Plugin 可以对 Task 进行分类或增强，但 Plugin 本身不是 Task。
_Avoid_: 计划, 待办, 日程

**Plugin Market（插件市场）**:
展示平台预置 Plugin 的场所，参照智搭Edu 的市场形态。用户对市场中 Plugin 的操作仅有：浏览、安装、配置。demo 版插件由平台预置（seed），无用户发布渠道。demo 阶段插件的配置与功能预览均在插件市场的插件详情页内完成。
_Avoid_: 应用商店, 模板中心

**主系统（Main System）**:
用户装配插件后形成的个性化工作区，是 Installed Plugin 最终生效的容器（如任务按画板象限分类、番茄钟计时器出现于此）。demo 版为空壳占位，仅有目录结构，不做功能开发。
_Avoid_: 主页（口语）, 工作台

**实验（Lab）**:
demo 版三模块之一，预留用于未来实验性功能。demo 版为空壳占位，仅有目录结构，不做功能开发。
_Avoid_: 实验室, 试验区

**画板（Quadrant Board）**:
预置 Plugin 之一，多结构任务分类工具。菜单栏提供多种划分结构（demo 版含：二维坐标轴 quadrant，固定 2×2；金字塔 pyramid，固定 3 层），任一时刻只有一种结构生效（active），各结构的区域命名配置独立保留、切换不丢。用户可命名轴标签与各区域名称。demo 阶段仅配置与预览，Task 分类待主系统开发时接入。
_Avoid_: 白板, 象限图

**番茄钟（Pomodoro）**:
预置 Plugin 之一，计时工具。config 仅存 label（计时对象，如"学习"）；计时时长在启动时由前端临时选择，不落库；计时纯前端运行，倒计时结束本地通知，后端不参与计时、不记录专注历史。
_Avoid_: 计时器（口语可接受，代码用 Pomodoro）, 专注钟

**Installed Plugin（已安装插件）**:
用户把某个 Plugin 安装到自己主系统后形成的实例，记录该用户的个性化配置（config，JSON 结构由各插件自定义）与启用状态（enabled）。每用户对同一 Plugin 限一个实例；卸载即删除实例及其数据，禁用（enabled=false）保留配置但功能不生效。
_Avoid_: 插件实例, 订阅的插件（严禁混用：Subscription 只属于 Task）

**Time Window**:
Task 每日重复执行的时间区间，由 start_time 和 end_time 表示。v1 在起点和终点各触发一次定时提醒；未来迭代可能切换为用户行为触发（如打卡完成）。
_Avoid_: 时间段（口语）, 时段

**Subscription（暂缓）**:
用户对某个 Task 的"我会每天执行"承诺。订阅者只能修改自己这份承诺的 Time Window 与启用状态，不能修改 Task 本身的 name 和 content。demo 版随主系统一并暂缓开发；由于 Shared Task 已废弃，未来重启时其语义可能简化为"自订阅"。
_Avoid_: 订阅记录, 订阅关系

**~~Shared Task~~（已废弃）**:
v1 旧概念：作者发布到市场供他人订阅的 Task。自 demo 版起，市场改为提供 Plugin（工具）而非 Task，任务共享/发布机制整体移除，此术语不再使用。
_Avoid_: 公开任务, 共享插件

**Private Task（暂缓）**:
作者自建、未发布到市场的 Task。作者可任意修改 name/content/time 相关字段。demo 版随主系统一并暂缓开发；由于共享机制废弃，未来重启时"Private"前缀可能不再需要，Task 默认即私有。
_Avoid_: 个人任务, 私有插件

**~~System Task~~（已废弃）**:
v1 旧概念：系统预置的三条 Task（喝水/考研/散步），作为任务市场的 seed 内容。自 demo 版起市场改为提供 Plugin，seed 对象变为画板与番茄钟两条 Plugin，此术语不再使用。
_Avoid_: 默认任务, 内置任务
