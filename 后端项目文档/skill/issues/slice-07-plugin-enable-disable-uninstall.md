# 切片 07：实例生命周期——启停 + 卸载

**类型**: AFK
**覆盖用户故事**: #9, #10, #11, #12

## 构建内容

实现 Installed Plugin 的启停与卸载两个操作接口，完成实例生命周期的闭环。

行为：

- `PUT /api/user-plugins/{id}/enabled`：body `{enabled: bool}`。仅本人实例，否则 403；id 不存在 404；enabled 缺失或非布尔 400。禁用只翻 enabled 标志，config 原样保留。
- `DELETE /api/user-plugins/{id}`：卸载，**物理删除**该 user_plugin 行（demo 版无子表数据，单条 SQL 完成）。仅本人实例，否则 403；id 不存在 404。
- 卸载后重新安装同一插件，得到的是带默认 config 的全新实例（旧配置不残留——此行为由切片 05 的安装逻辑自然保证，本切片验证）。

## 验收标准

- [ ] 禁用后 `GET /api/plugins` 中该实例 enabled=false，且 config 完整保留
- [ ] 重新启用后 enabled=true，config 与禁用前完全一致
- [ ] 卸载后 `GET /api/plugins` 中该插件恢复 installed=false、状态字段为 null
- [ ] 卸载后重新安装，得到默认 config 的新实例（旧配置不残留）
- [ ] 禁用/卸载他人实例均返回 403；id 不存在返回 404；未携带 token 返回 401
- [ ] 卸载后 user_plugin 表无该行（物理删除验证）
- [ ] Controller 层 MockMvc 测试覆盖上述路径

## 前置依赖

- 切片 05（有 Installed Plugin 可操作；与切片 06 无相互依赖，可并行）

## 参考文档

- [PRD](../PRD(产品规格说明书).md) — 用户故事 #9-#12，API 契约、架构决策 #5（卸载即物理删除）
- [CONTEXT(业务术语)](../CONTEXT(业务术语).md) — Installed Plugin 术语（禁用保留配置、卸载删除数据）
