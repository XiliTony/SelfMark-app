# 切片 09：改 subscription + 我的任务列表

**类型**: AFK
**覆盖用户故事**: #25, #26, #27, #28

## 构建内容

实现用户修改自己 subscription 的 Time Window / enabled 字段，以及查询"我的任务"列表（统一查看自己创建的 Private Task + 自己订阅的 System/Shared Task）。

行为：

- `PUT /api/subscriptions/{id}`：body `{start_time?, end_time?, enabled?}`。需要鉴权。
  - 查询 subscription 是否存在（不存在 404）。
  - 校验当前用户是订阅者（subscription.user_id == 当前用户；非订阅者 403）。
  - 如果传了 start_time/end_time，校验 `end_time > start_time`（如果两个都传，整体校验；如果只传一个，跟 DB 现有值组合校验）。
  - 提供哪个字段就更新哪个，未提供的字段不修改。
  - enabled 字段可单独修改（暂停/启用订阅）。
  - 返回更新后的 subscription。
- `GET /api/tasks/mine`：需要鉴权。返回"我的任务"列表：
  - 查询当前用户的所有 subscription（无论 enabled=true/false），JOIN task 表取 task.name/content/type/creator_id。
  - 返回每条 subscription + 对应 task 信息。
  - 排序：按 subscription.created_at desc（最早订阅的在前）或按 task.start_time asc（按时段排序）—— v1 选 subscription.created_at desc 简单实现。
  - 不返回不存在的 task（理论上不应该有孤儿，但 JOIN 不到的 subscription 行为：要么不返回，要么返回 task 字段为 null；v1 选 INNER JOIN 不返回孤儿行）。

## 验收标准

- [ ] 改自己 subscription 的 start_time 成功（end_time 不变）
- [ ] 改自己 subscription 的 end_time 成功（start_time 不变）
- [ ] 同时改 start_time + end_time 成功
- [ ] 改 enabled=false 成功（暂停订阅）
- [ ] 改 enabled=true 成功（恢复订阅）
- [ ] 改时 `end_time <= start_time`（两个都传的情况）返回 400
- [ ] 改时只传 start_time 但跟现有 end_time 矛盾（start_time >= 现有 end_time）返回 400
- [ ] 改时只传 end_time 但跟现有 start_time 矛盾（end_time <= 现有 start_time）返回 400
- [ ] 非订阅者调 PUT 返回 403
- [ ] 改不存在的 subscription_id 返回 404
- [ ] `GET /api/tasks/mine` 返回当前用户所有 subscription + 对应 task 信息
- [ ] mine 返回按 subscription.created_at desc 排序
- [ ] mine 不返回其他用户的 subscription
- [ ] mine 返回的 task 信息含 name/content/type/creator_id
- [ ] 如果某 subscription 对应的 task 不存在（孤儿，理论上不该有），该行不返回（INNER JOIN 行为）
- [ ] 未携带 token 返回 401

## 前置依赖

- Slice 08（订阅/取消闭环）

## 参考文档

- [PRD](../PRD.md) — 用户故事 #25-#28，API 契约 `PUT /api/subscriptions/{id}`、`GET /api/tasks/mine`
- [CONTEXT.md](../../CONTEXT.md) — 术语表（Subscription、Time Window）
