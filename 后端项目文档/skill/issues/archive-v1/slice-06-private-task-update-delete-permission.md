# 切片 06：Private Task 修改/删除 + 权限校验

**类型**: AFK
**覆盖用户故事**: #12, #13, #19

## 构建内容

实现 Private Task 作者的修改/删除权限闭环：作者能改/删自己的 Private Task；SHARED/SYSTEM 一律 403；非作者一律 403。删除时连带删除该 task 的所有 subscription（同一事务）。

行为：

- `PUT /api/tasks/{id}`：body `{name?, content?}`。需要鉴权。
  - 查询 task 是否存在（不存在 404）。
  - 校验当前用户是作者（task.creator_id == 当前用户 id；非作者 403）。
  - 校验 task.type=PRIVATE（SHARED 或 SYSTEM 一律 403，"SHARED 完全冻结"决策）。
  - 更新 name/content（提供哪个字段就更新哪个，未提供的字段不修改）。
- `DELETE /api/tasks/{id}`：需要鉴权。
  - 查询 task 是否存在（不存在 404）。
  - 校验当前用户是作者（非作者 403）。
  - 校验 task.type=PRIVATE（SHARED 或 SYSTEM 一律 403）。
  - **同一事务**内：
    1. 删除该 task 的所有 subscription（`delete from subscription where task_id=X`）
    2. 删除 task 本身（`delete from task where id=X`）
  - 任一失败整个事务回滚。
- SYSTEM Task（creator_id=NULL）：任何用户都不能改/删，全部 403。

## 验收标准

- [ ] 作者能改自己 Private Task 的 name（content 不传则不变）
- [ ] 作者能改自己 Private Task 的 content（name 不传则不变）
- [ ] 作者能同时改 name + content
- [ ] 作者能删自己 Private Task
- [ ] 删除后 DB 中 task 和该 task 的所有 subscription 都不存在
- [ ] 删除是事务性的（subscription 删了但 task 没删不会发生）
- [ ] 非作者用户调 PUT/DELETE 返回 403
- [ ] 对 SHARED Task 调 PUT/DELETE 返回 403（即使是作者自己）
- [ ] 对 SYSTEM Task 调 PUT/DELETE 返回 403（任何用户）
- [ ] 对不存在的 task_id 调 PUT/DELETE 返回 404
- [ ] 未携带 token 返回 401
- [ ] PUT 时 task_id 不存在返回 404（不是 403）

## 前置依赖

- Slice 05（创建 Private Task + subscription 表 + 事务边界）

## 参考文档

- [PRD](../PRD.md) — 用户故事 #12, #13, #19，实现决策 #2, #3（SHARED 冻结、PRIVATE 可改可删），API 契约 `PUT/DELETE /api/tasks/{id}`
- [CONTEXT.md](../../CONTEXT.md) — 术语表（Private Task、Shared Task、System Task）
