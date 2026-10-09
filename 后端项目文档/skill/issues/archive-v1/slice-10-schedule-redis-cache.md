# 切片 10：当日 schedule 下发 + Redis 当日缓存

**类型**: AFK
**覆盖用户故事**: #29, #30, #31, #32

## 构建内容

实现"当日 schedule"下发接口，给 APP 注册本地通知用。这是 v1 后端核心接口——APP 每天首次打开调这个接口拉当日 schedule，注册本地通知实现双边界提醒。Redis 缓存到当天 23:59 保证同一天多次拉取结果一致。

行为：

- `GET /api/subscriptions/schedule`：需要鉴权。
  - 查询当前用户所有 `enabled=1` 的 subscription，INNER JOIN task 表取 task.name + task.content（不取已删除/孤儿 task）。
  - 返回字段：每个 subscription 一条，含 `{subscription_id, task_id, task_name, task_content, start_time, end_time}`。
  - 排序：按 start_time asc（按时段从早到晚）。
  - Redis 缓存逻辑：
    - key = `schedule:{user_id}:{date}`，date 格式 `yyyy-MM-dd`
    - TTL = 到当天 23:59:59 的秒数（用 Redis 自带 EXPIRE 计算）
    - 缓存命中：直接返回缓存的 JSON
    - 缓存未命中：查 DB → 序列化为 JSON → 写入 Redis（带 TTL）→ 返回
  - 缓存语义：同一天多次拉取返回**完全相同**的结果——即使作者当天创建新 SHARED Task 或修改了 task 内容，当天用户拉到的 schedule 仍是当天凌晨第一次拉的快照。第二天缓存自然失效后重新查 DB。
  - 缓存不做主动 invalidate：作者改/删/发布 Task 都不主动清缓存（清了等于退回"实时跟随"语义，违背日级冻结设计）。让缓存自然过期。
- 缓存失败兜底：如果 Redis 不可用（连接失败），schedule 接口应该降级直接查 DB 返回（不能因为 Redis 挂了导致 APP 拉不到 schedule）。日志告警但不抛 500。

## 验收标准

- [ ] `GET /api/subscriptions/schedule` 携带合法 token 返回当日 schedule
- [ ] schedule 返回字段含 subscription_id, task_id, task_name, task_content, start_time, end_time
- [ ] schedule 按 start_time asc 排序
- [ ] schedule 只返回 enabled=1 的 subscription（enabled=0 不出现）
- [ ] schedule 不返回孤儿 subscription（对应 task 不存在的行不出现）
- [ ] 同一用户同一天多次调 schedule 返回**完全相同**的 JSON（包括字段顺序）
- [ ] 首次调 schedule 后 Redis 里有 `schedule:{user_id}:{date}` key
- [ ] 该 key 的 TTL 到当天 23:59:59 失效
- [ ] 模拟作者当天创建新 SHARED Task 后用户再拉 schedule，仍返回旧版（缓存命中）
- [ ] 模拟作者当天改自己 PRIVATE Task 的 name 后用户再拉 schedule，仍返回旧 name（缓存命中）
- [ ] 跨天后（或手动删 Redis key 后）再拉 schedule，返回新版（重新查 DB）
- [ ] Redis 不可用时 schedule 接口降级直查 DB 返回 200，不返回 500
- [ ] schedule 返回空列表（用户没有任何 enabled subscription 的情况）
- [ ] schedule 不返回其他用户的 subscription
- [ ] 未携带 token 返回 401

## 前置依赖

- Slice 09（改 subscription + mine 列表，subscription 数据完整）

## 参考文档

- [PRD](../PRD.md) — 用户故事 #29-#32，实现决策 #7（APP 每日单次拉取+下拉刷新）、#12（后端只下发 schedule，APP 本地通知），API 契约 `GET /api/subscriptions/schedule`
- [CONTEXT.md](../../CONTEXT.md) — 术语表（Time Window、Subscription）
