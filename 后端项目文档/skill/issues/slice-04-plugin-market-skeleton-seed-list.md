# 切片 04：插件市场骨架——建表 + seed + 市场列表

**类型**: AFK
**覆盖用户故事**: #5, #6, #26, #28

## 构建内容

新建插件模块（包 `com.nortidart.selfmark.plugin`，分层沿用 controller/service/mapper/entity/dto），引入两张新表，并实现唯一的市场查询接口。本切片是后续所有插件切片的地基。

数据模型（schema 决策精确表达）：

```
plugin
- id              BIGINT PK AUTO_INCREMENT
- code            VARCHAR(50)  NOT NULL UNIQUE  -- 插件标识: quadrant-board / pomodoro；前端据此路由渲染
- name            VARCHAR(50)  NOT NULL
- description     VARCHAR(500) NULL
- sort            INT          NOT NULL DEFAULT 0
- created_at      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP

user_plugin
- id              BIGINT PK AUTO_INCREMENT
- user_id         BIGINT       NOT NULL
- plugin_id       BIGINT       NOT NULL
- config          JSON         NOT NULL
- enabled         TINYINT(1)   NOT NULL DEFAULT 1
- created_at      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP
- UNIQUE KEY uk_user_plugin (user_id, plugin_id)
- INDEX idx_user (user_id)
```

行为：

- 应用启动时 seed 两条 Plugin：(code=quadrant-board, name=画板, sort=1)、(code=pomodoro, name=番茄钟, sort=2)。seed 必须**幂等**（重复启动不产生重复行，建议按 code 判存）。
- `GET /api/plugins`（需鉴权）：返回全部 Plugin（按 sort asc），每个附带当前用户安装状态：`installed`、`userPluginId`、`enabled`、`config`。未安装的字段为 null。通过 plugin LEFT JOIN user_plugin（限定 user_id=当前用户）一次查出。
- 本切片不实现安装/配置/启停/卸载（后续切片），测试数据可直接 SQL 插入 user_plugin 验证列表状态。

## 验收标准

- [ ] 启动后 plugin 表恰好有 quadrant-board、pomodoro 两条记录
- [ ] 重复启动应用，plugin 表不产生重复 seed（幂等）
- [ ] `GET /api/plugins` 带合法 token 返回 2 条插件，按 sort asc（画板在前）
- [ ] 当前用户未安装任何插件时，每条返回 installed=false，userPluginId/enabled/config 为 null
- [ ] 预置 user_plugin 数据后再拉列表，对应插件返回 installed=true 及 config/enabled 原值
- [ ] 其他用户的 user_plugin 数据不影响当前用户的列表状态
- [ ] 未携带 token 访问返回 401
- [ ] user_plugin 表存在 uk_user_plugin 唯一约束（DB 层验证）
- [ ] 以上均有 Controller 层 MockMvc 测试覆盖

## 前置依赖

- 无（认证模块切片 01-03 已完成，可直接使用 JWT 拦截器与统一响应体）

## 参考文档

- [PRD](../PRD(产品规格说明书).md) — 用户故事 #5-#6、#26、#28，Schema、API 契约
- [CONTEXT(业务术语)](../CONTEXT(业务术语).md) — Plugin、Plugin Market、Installed Plugin 术语
- [ADR 0001](../docs/adr/0001-plugin-market-replaces-task-market.md) — 双实体与 JSON config 决策
