# Self-Mark App（自律 App）

一个帮助人养成自律习惯、克服拖延、提升内驱力的应用。本文档定义业务领域术语，前后端共享。

## 术语表

**Mobile**:
用户登录手机号。v1 的请求、响应、JWT 自定义 claim 和数据库列统一使用 `mobile`；`username` 仅表示展示名，不可用于登录。
_Avoid_: account, 把 username 称为账号, nickname

**Task**:
用户每天需要执行的具体活动，由名字、内容、Time Window 构成。前端在"插件市场"界面中将其呈现为"插件"，但后端只有 Task 这一个实体，无 Plugin 概念。
_Avoid_: 计划, 待办, 日程, 插件

**Time Window**:
Task 每日重复执行的时间区间，由 start_time 和 end_time 表示。v1 在起点和终点各触发一次定时提醒；未来迭代可能切换为用户行为触发（如打卡完成）。
_Avoid_: 时间段（口语）, 时段

**Subscription**:
用户对某个 Task 的"我会每天执行"承诺。订阅者只能修改自己这份承诺的 Time Window 与启用状态，不能修改 Task 本身的 name 和 content。
_Avoid_: 订阅记录, 订阅关系

**Shared Task**:
作者主动发布到插件市场供其他用户订阅的 Task。发布后完全冻结：作者不可修改 name/content、不可撤回共享、不可删除。`PRIVATE → SHARED` 是单向不可逆操作，作者发布前须自行确认内容。
_Avoid_: 公开任务, 共享插件

**Private Task**:
作者自建、未发布到市场的 Task。作者可任意修改 name/content/time 相关字段。PRIVATE Task 无订阅者。
_Avoid_: 个人任务, 私有插件

**System Task**:
系统预置的 Task（v1 有三条：喝水、考研、散步），无作者，不可被任何用户修改 name/content。所有用户可在市场订阅，订阅时自行定义 Time Window。
_Avoid_: 默认任务, 内置任务
