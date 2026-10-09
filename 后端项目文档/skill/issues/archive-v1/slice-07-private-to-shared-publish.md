# 切片 07：PRIVATE → SHARED 单向发布 + SHARED 完全冻结

**类型**: AFK
**覆盖用户故事**: #14, #15, #16, #17, #18

## 构建内容

实现 Private Task 发布到市场的单向不可逆流程，并强化 SHARED Task 完全冻结的语义（不可改 name/content、不可撤回、不可删）。本切片的"完全冻结"在 Slice 06 的 PUT/DELETE 已经覆盖了改/删部分，本切片补充 share 接口本身和反向转换拒绝。

行为：

- `POST /api/tasks/{id}/share`：需要鉴权。
  - 查询 task 是否存在（不存在 404）。
  - 校验当前用户是作者（非作者 403）。
  - 校验 task.type=PRIVATE（已经是 SHARED 返回 409"已发布，不能重复发布"；SYSTEM 返回 403"系统任务不能发布"）。
  - 在**同一事务**内：
    1. 更新 task：type=SHARED, shared=1（**双向更新**，type 与 shared 必须一致）
    2. 不影响已存在的 subscription（如果有，PRIVATE 自动订阅的那条仍保留——现在变成"作者订阅了自己的 SHARED Task"，合法）
  - 返回更新后的 task 信息。
- 反向转换拒绝：本切片**不提供** SHARED → PRIVATE 接口（根本没有这个端点）；如果未来加也必须返回 403 或 409。
- SHARED 完全冻结的强化（部分已在 Slice 06 实现，本切片补充边界）：
  - PUT SHARED Task → 403（Slice 06 已实现）
  - DELETE SHARED Task → 403（Slice 06 已实现）
  - 重复 share 已 SHARED 的 Task → 409（本切片实现）
  - share SYSTEM Task → 403（本切片实现）
  - 没有撤回共享接口（端点不存在，本切片确保不提供）

## 验收标准

- [ ] 作者对自己 Private Task 调 share 成功，task 变 SHARED（type=SHARED, shared=1）
- [ ] share 后 task 在 market 接口里可见（Slice 04 market 查 shared=1）
- [ ] 对已经是 SHARED 的 Task 调 share 返回 409
- [ ] 对 SYSTEM Task 调 share 返回 403
- [ ] 非作者调 share 返回 403
- [ ] 对不存在的 task_id 调 share 返回 404
- [ ] share 是单向不可逆：DB 层 task.type 一旦变成 SHARED 不能用任何接口转回 PRIVATE
- [ ] share 后该 task 的现有 subscription 仍保留（作者自动订阅的那条不被删除）
- [ ] share 事务内 type 和 shared 双向更新（type=SHARED 时 shared 必为 1，反之亦然）
- [ ] 不存在 `/api/tasks/{id}/unshare` 接口（撤回共享动作不存在）
- [ ] 未携带 token 返回 401

## 前置依赖

- Slice 05（创建 Private Task + subscription 表）

注：Slice 06 与 Slice 07 都只依赖 Slice 05，可并行认领。但建议先做 Slice 06（PUT/DELETE 基础）再做 Slice 07（share + SHARED 冻结强化），因为 Slice 07 的"PUT SHARED → 403"复用 Slice 06 的权限校验逻辑。

## 参考文档

- [PRD](../PRD.md) — 用户故事 #14-#18，实现决策 #2, #3, #5（SHARED 完全冻结、PRIVATE → SHARED 单向不可逆），API 契约 `POST /api/tasks/{id}/share`
- [CONTEXT.md](../../CONTEXT.md) — 术语表（Shared Task、Private Task）
