# 切片 05：创建 Private Task + 自动订阅闭环

**类型**: AFK
**覆盖用户故事**: #10, #11, #23

## 构建内容

引入 `subscription` 表 schema，实现创建 Private Task 的端到端闭环：用户调用 `POST /api/tasks` 创建 Private Task，**同一事务**内自动生成一条自己订阅自己的 Subscription（user_id=me，task_id=新 task，Time Window 来自请求 body）。

数据模型（subscription 表，schema 决策精确表达）：

```
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

行为：

- `POST /api/tasks`：body `{name, content, start_time, end_time}`。需要鉴权。
  - 校验 name 不为空、start_time/end_time 格式合法（HH:mm:ss）、`end_time > start_time`（不满足 400，跨天 v1 不支持）。
  - 在**同一事务**内：
    1. 插入 task：type=PRIVATE，creator_id=当前用户 id，shared=0，name/content 来自 body
    2. 插入 subscription：user_id=当前用户 id，task_id=上一步生成的 task id，start_time/end_time 来自 body，enabled=1
  - 任一失败整个事务回滚（不能出现"task 创建了但没自动订阅"的中间态）。
  - 返回 `{task: {...}, subscription: {...}}`，让前端直接显示"我的任务"列表。
- 创建 Private Task 不允许指定 type=SYSTEM 或 SHARED（这些类型由系统或 share 接口设置，不能在创建时直接指定）。
- 创建 Private Task 不允许指定 shared=true（不能直接创建为 SHARED，必须先创建 PRIVATE 再调 share 接口，这是单向流程）。

## 验收标准

- [ ] `subscription` 表 schema 与 PRD 一致（字段、类型、唯一约束、索引）
- [ ] `POST /api/tasks` 带合法 body 成功，返回 task + subscription
- [ ] DB 中 task.type=PRIVATE，task.creator_id=当前用户，task.shared=0
- [ ] DB 中 subscription.user_id=当前用户，subscription.task_id=新建 task，subscription.enabled=1
- [ ] task 和 subscription 在同一事务内创建（任一失败另一个也不存在）
- [ ] name 为空返回 400
- [ ] start_time/end_time 格式不合法返回 400
- [ ] end_time <= start_time 返回 400（跨天 v1 不支持）
- [ ] body 里指定 type=SYSTEM 或 SHARED 返回 400（只允许 PRIVATE）
- [ ] body 里指定 shared=true 返回 400（必须先创建 PRIVATE 再调 share）
- [ ] 未携带 token 返回 401

## 前置依赖

- Slice 04（task 表 schema + System Task seed + market 接口）

## 参考文档

- [PRD](../PRD.md) — 用户故事 #10, #11, #23，数据模型 schema，API 契约 `POST /api/tasks`，事务边界决策
- [CONTEXT.md](../../CONTEXT.md) — 术语表（Private Task、Subscription、Time Window）
