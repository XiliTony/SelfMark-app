# 切片 06：更新插件配置——config 整体替换 + 权限校验

**类型**: AFK
**覆盖用户故事**: #14, #15, #16, #17, #18, #19, #21, #22

## 构建内容

实现 `PUT /api/user-plugins/{id}/config`：整体替换 Installed Plugin 的 config。后端对 config 做**不透明存储**——只校验 body 是合法 JSON 对象，不解析、不校验内部结构；无增量合并语义，前端总是提交完整 JSON。

行为：

- id 不存在 → 404
- 实例属于其他用户 → 403
- body 缺失或非合法 JSON 对象 → 400
- 成功：`update user_plugin set config=?`，返回更新后的实例

支撑的前端场景（仅作行为验证参考，前端实现不在本切片）：

- 画板：修改轴标签、重命名象限/金字塔区域、切换 active 结构（切换时另一结构配置由前端整体提交自然保留）
- 番茄钟：修改 label

## 验收标准

- [ ] 修改画板某个象限名称后，`GET /api/plugins` 返回更新后的完整 config
- [ ] 将 active 从 quadrant 切换为 pyramid 提交后，quadrant 下既有命名配置原样保留（整体替换语义）
- [ ] 修改番茄钟 label 后持久化生效
- [ ] config 替换为任意合法 JSON 结构（如 `{"foo":1}`）也能原样存取（不透明性验证）
- [ ] 操作他人实例返回 403；id 不存在返回 404；body 非 JSON 对象返回 400；未携带 token 返回 401
- [ ] enabled 字段不受 config 更新影响（禁用状态下改配置，enabled 保持 false）
- [ ] Controller 层 MockMvc 测试覆盖上述路径

## 前置依赖

- 切片 05（有 Installed Plugin 可操作）

## 参考文档

- [PRD](../PRD(产品规格说明书).md) — 用户故事 #14-#22，API 契约、架构决策 #4（config 不透明）、#8（结构单选生效）
- [CONTEXT(业务术语)](../CONTEXT(业务术语).md) — 画板、番茄钟、Installed Plugin 术语
