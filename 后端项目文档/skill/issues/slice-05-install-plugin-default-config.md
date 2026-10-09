# 切片 05：安装插件——install 接口 + 默认 config 生成 + 单实例约束

**类型**: AFK
**覆盖用户故事**: #7, #8, #20, #22（部分）, #27, #29, #30

## 构建内容

实现 `POST /api/plugins/{code}/install`：为当前用户创建 Installed Plugin 实例，写入该插件的默认配置。默认值逻辑集中在后端一处（按 code 生成），前端不内置默认值。

行为：

- path 中 code 不存在 → 404
- 当前用户已安装该插件（无论 enabled 状态）→ 409
- 安装成功：insert user_plugin（user_id=当前用户, plugin_id=该插件, enabled=1, config=默认 config），返回创建的实例（含 id、plugin code/name、config、enabled）
- 并发重复安装由 DB 唯一约束 uk_user_plugin 兜底，捕获冲突异常转 409（不得暴露 500）
- config 由后端按 code 生成，写入后前端原样使用：

画板（quadrant-board）默认 config：

```json
{
  "active": "quadrant",
  "quadrant": {
    "xAxisLabel": "紧急度",
    "yAxisLabel": "重要度",
    "regions": [
      {"key": "q1", "name": "重要且紧急"},
      {"key": "q2", "name": "重要不紧急"},
      {"key": "q3", "name": "紧急不重要"},
      {"key": "q4", "name": "不重要不紧急"}
    ]
  },
  "pyramid": {
    "regions": [
      {"key": "p1", "name": "顶层目标"},
      {"key": "p2", "name": "中层计划"},
      {"key": "p3", "name": "底层行动"}
    ]
  }
}
```

番茄钟（pomodoro）默认 config：

```json
{"label": "专注"}
```

## 验收标准

- [ ] 安装画板成功，返回实例的 config 含 active=quadrant、4 个象限区域、3 层金字塔，与上述默认 JSON 一致
- [ ] 安装番茄钟成功，返回 config 为 `{"label":"专注"}`
- [ ] 安装后 `GET /api/plugins` 中该插件 installed=true 且 config/enabled 与创建时一致
- [ ] 重复安装同一插件返回 409（enabled=false 的实例也算已安装）
- [ ] 并发/绕过应用层检查的重复 insert 被唯一约束拦截并转为 409，不出现 500
- [ ] code 不存在返回 404；未携带 token 返回 401
- [ ] Service 层单元测试：按 code 生成默认 config（两个 code 各自断言结构）；单实例约束抛业务异常
- [ ] Controller 层 MockMvc 测试覆盖成功/409/404/401 路径

## 前置依赖

- 切片 04（plugin 表、seed、市场列表）

## 参考文档

- [PRD](../PRD(产品规格说明书).md) — 用户故事 #7-#8、#20、#22、#27、#29-#30，API 契约、默认 config、事务边界
- [CONTEXT(业务术语)](../CONTEXT(业务术语).md) — Installed Plugin、画板、番茄钟术语
