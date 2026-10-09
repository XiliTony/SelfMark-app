# 切片 04：System Task seed + 市场查询闭环

**类型**: AFK
**覆盖用户故事**: #7, #8, #9, #20, #36, #37, #38

## 构建内容

引入 `task` 表 schema，预置 3 条 System Task（喝水、考研、散步），实现插件市场查询接口。本切片只读不写（不创建任务，创建在 Slice 5）。

数据模型（task 表，schema 决策精确表达）：

```
task
- id              BIGINT PK AUTO_INCREMENT
- name            VARCHAR(100)  NOT NULL
- content         VARCHAR(500)  NULL
- type            VARCHAR(20)   NOT NULL  -- 枚举: SYSTEM / SHARED / PRIVATE
- creator_id      BIGINT        NULL      -- SYSTEM 任务为 NULL，其他为创建者 user.id
- shared          TINYINT(1)    NOT NULL DEFAULT 0  -- 是否发布到市场；SYSTEM=1, SHARED=1, PRIVATE=0
- created_at      DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP
- INDEX idx_creator (creator_id)
- INDEX idx_shared_type (shared, type)
```

行为：

- System Task seed：应用启动时通过 SQL 脚本（或 Flyway）注入 3 条：name='喝水'/'考研'/'散步'，type=SYSTEM，creator_id=NULL，shared=1，content 可为空或简单描述。
- seed 脚本需幂等：重复启动不会插入重复数据（用 `INSERT ... ON DUPLICATE KEY` 或先查后插，或 Flyway 管理版本）。
- `GET /api/tasks/market`：需要鉴权。返回 market 列表 = 所有 `shared=1` 的 task（即 SYSTEM + SHARED），按 `created_at desc` 排序。
- market 接口**不返回** Private Task（shared=0）。
- market 接口返回字段：id、name、content、type、creator_id（前端可用来判断是否是自己创建的）。**不返回**已订阅状态（订阅状态由前端调 `/api/subscriptions` 单独查或 Slice 9 的 mine 接口隐含）—— v1 简化，前端不需要在 market 知道订阅状态。

## 验收标准

- [ ] `task` 表 schema 与 PRD 一致（字段、类型、索引）
- [ ] 应用启动后 DB 里有 3 条 System Task：喝水/考研/散步，type=SYSTEM, creator_id=NULL, shared=1
- [ ] 重复启动应用不会产生重复 seed 数据
- [ ] `GET /api/tasks/market` 携带合法 token 返回 3 条 System Task（v1 还没有 SHARED，所以只有 SYSTEM）
- [ ] market 返回按 created_at desc 排序
- [ ] market 返回字段含 id/name/content/type/creator_id
- [ ] market 不返回 Private Task（v1 还没创建功能，但 schema 已支持；后续切片验证）
- [ ] 未携带 token 调 market 返回 401
- [ ] 携带过期 token 调 market 返回 401
- [ ] 携带黑名单 token（已登出）调 market 返回 401

## 前置依赖

- Slice 03（鉴权 + 黑名单完整闭环）

## 参考文档

- [PRD](../PRD.md) — 用户故事 #7-#9, #20, #36-#38，数据模型 schema，API 契约 `/api/tasks/market`
- [CONTEXT.md](../../CONTEXT.md) — 术语表（Task、System Task、Shared Task、Private Task）
