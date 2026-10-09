# 切片 08：订阅市场 Task 闭环

**类型**: AFK
**覆盖用户故事**: #21, #22, #23, #24

## 构建内容

实现用户在市场订阅 System Task 或 Shared Task 的端到端闭环，以及取消订阅。订阅时由用户自行定义 Time Window（系统任务无默认时间段）。重复订阅被唯一约束拦截。不能订阅 Private Task（只有作者自己的自动订阅那一条）。

行为：

- `POST /api/subscriptions`：body `{task_id, start_time, end_time}`。需要鉴权。
  - 校验 task_id 存在（不存在 404）。
  - 校验 task 是可订阅的：type=SYSTEM 或 type=SHARED（即 shared=1）；如果是 PRIVATE 或 shared=0 返回 403"该任务不可订阅"。
  - 校验 `end_time > start_time`（不满足 400，跨天 v1 不支持）。
  - 校验 (user_id, task_id) 唯一性：用户对同一 task 已存在 subscription 返回 409"已订阅该任务"。
  - 插入 subscription：user_id=当前用户，task_id 来自 body，start_time/end_time 来自 body，enabled=1。
  - 返回 subscription 信息（含 JOIN 出的 task name/content，方便前端直接显示）。
- `DELETE /api/subscriptions/{id}`：需要鉴权。
  - 查询 subscription 是否存在（不存在 404）。
  - 校验当前用户是订阅者（subscription.user_id == 当前用户；非订阅者 403）。
  - 物理删除该 subscription（v1 不做软删除/历史记录，删除即彻底）。
  - 不影响 task 本身（task 还在市场，其他订阅者不受影响）。
- System Task 订阅：用户可订阅喝水/考研/散步，每个订阅时自行定义 Time Window。
- Shared Task 订阅：用户可订阅别人发布的 SHARED Task，订阅时定义自己的 Time Window。

## 验收标准

- [ ] 订阅 System Task（如"喝水"，带 start_time=10:00:00, end_time=10:30:00）成功，返回 subscription + JOIN 出的 task 信息
- [ ] 订阅 SHARED Task 成功（需要先有 Slice 07 创建并 share 的 SHARED Task）
- [ ] 订阅时 task_id 不存在返回 404
- [ ] 订阅 Private Task 返回 403"该任务不可订阅"
- [ ] 订阅时 `end_time <= start_time` 返回 400
- [ ] 订阅时 start_time/end_time 格式不合法返回 400
- [ ] 重复订阅同一 task 返回 409"已订阅该任务"
- [ ] 取消订阅成功，DB 里 subscription 不存在
- [ ] 取消订阅不影响 task 本身（task 还在）
- [ ] 取消订阅不影响其他用户的订阅
- [ ] 非订阅者调 DELETE 返回 403
- [ ] 取消不存在的 subscription_id 返回 404
- [ ] 未携带 token 返回 401

## 前置依赖

- Slice 07（SHARED 概念 + market 已有 SHARED Task 可订阅）
  - 实际上 SUBSCRIPTION 表在 Slice 05 已经建好，本切片只新增订阅/取消接口
  - 依赖 Slice 07 是因为需要测试订阅 SHARED Task 的场景

## 参考文档

- [PRD](../PRD.md) — 用户故事 #21-#24，实现决策 #6（跨天 v1 不支持）、唯一约束，API 契约 `POST/DELETE /api/subscriptions`
- [CONTEXT.md](../../CONTEXT.md) — 术语表（Subscription、Time Window、System Task、Shared Task）
