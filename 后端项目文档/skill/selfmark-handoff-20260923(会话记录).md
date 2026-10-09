# Self-Mark App 后端 demo 版 — 会话交接文档

**交接时间**: 2026-09-23
**文档工作目录**: `e:\SelfMarkProject\skill`
**代码工作目录**: `e:\SelfMarkProject\SelfMark-app\api`（后端）、`e:\SelfMarkProject\SelfMark-app\view`（前端 Flutter，本次未动）
**项目**: Self-Mark App（自律习惯养成 App）后端 demo 版

---

## 一、本次会话发生了什么（一句话）

产品方向转型：从 v1 的"任务市场 + 订阅提醒"转向**开放平台**——APP 只提供工具（Plugin），用户安装配置插件自行设计软件形态。本次只完成了**设计与文档**，未写任何业务代码。

---

## 二、当前状态

### 已完成

- **认证模块（slice 01-03）**：注册/登录/登出，JWT + Redis 黑名单，代码在 `SelfMark-app\api`，正常可用，本次未动
- **转型设计（grill-with-docs，11 轮盘问）**：所有决策已敲定，见 `docs/adr/0001` 与 PRD
- **文档全套产出**（都在 `e:\SelfMarkProject\skill\`）：

| 文件 | 内容 |
|---|---|
| `CONTEXT(业务术语).md` | 术语表：新增 Plugin / Plugin Market / Installed Plugin / 主系统 / 实验 / 画板 / 番茄钟；Shared Task、System Task 已废弃，Subscription、Private Task 暂缓 |
| `docs/adr/0001-plugin-market-replaces-task-market.md` | 转型 ADR：动机、弃选方案、后果 |
| `PRD(产品规格说明书).md` | demo 版 PRD（已重写覆盖 v1）：30 条用户故事、plugin + user_plugin 两张表 schema、5 个 API 契约、10 项架构决策、三层测试策略 |
| `issues/slice-01~03` | 认证切片（已完成，保留） |
| `issues/slice-04~08` | **新插件市场切片，待开发** |
| `issues/archive-v1/slice-04~10` | v1 任务/订阅切片归档，仅作未来主系统开发参考 |

### 关键决策速览（细节以 PRD 为准，勿凭此表实现）

- 双实体：Plugin（工具，无提醒）≠ Task（日程，暂缓开发）；严禁混用术语
- 插件平台预置 seed 两条：画板（quadrant-board）、番茄钟（pomodoro），无 UGC
- `user_plugin` 表：每用户每插件限一个实例（DB 唯一约束），config JSON 后端不透明存取，enabled 禁用不丢配置，卸载物理删除
- 画板 config：二维坐标轴(2×2) + 金字塔(3层) 两结构，active 单选生效，切换不丢配置；默认 config 由后端安装时按 code 生成
- 番茄钟 config：只存 `{"label":"专注"}`，计时纯前端，无记录
- API：`GET /api/plugins`（单接口带安装状态）+ install / config / enabled / uninstall 四个操作接口
- 主系统、实验：demo 版**不开发**，前后端都不建目录，仅文档占位

### 未做

- 切片 04-08 的全部代码实现
- 前端 Flutter 任何页面

---

## 三、下一步工作（按顺序）

1. **切片 04**：插件模块骨架——plugin/user_plugin 建表 + seed（幂等）+ `GET /api/plugins`。无前置依赖，可立即开工
2. **切片 05**：安装接口 + 默认 config 生成 + 单实例 409
3. **切片 06 / 07**：更新配置 ∥ 启停+卸载（都依赖 05，彼此可并行）
4. **切片 08**：Testcontainers 集成测试（依赖 06+07），跑通即 demo 验收

实现时注意：

- 代码库在 `e:\SelfMarkProject\SelfMark-app\api`，新模块包名 `com.nortidart.selfmark.plugin`，分层沿用 controller/service/mapper/entity/dto
- 代码中 v1 遗留的 `task`/`subscription` 空包（只有 package-info.java）：**用户明确要求保留不动**
- 错误码、统一响应体 `{code,msg,data}`、JWT 拦截器沿用 auth 模块既有设施
- 每个切片的验收标准在 issue 文件里，逐条自验

---

## 四、用户偏好与沟通注意

- **语言**：全程中文；文档标题中文，规范术语保留英文（Task/Plugin/config 等）
- 用户是前端开发者，后端概念要讲通俗，避免堆黑话
- 决策风格：喜欢先讨论清楚再动手；倾向简单方案；一次一个问题 + 推荐答案 + 反方观点
- 流程偏好：明确走 grill-with-docs → to-prd → to-issues → handoff 技能链
- 无 git 仓库、无 issue tracker，所有文档存本地 markdown
- 环境：JDK 21 + Spring Boot 3.x + Maven（Wrapper）+ MySQL 8 + Redis + MyBatis-Plus

---

## 五、建议技能

| 技能 | 使用时机 |
|---|---|
| 直接编码 | 按 `issues/slice-04` 开工，逐切片推进，按验收标准自验 |
| TRAE-code-review | 每个切片完成后可审查 |
| TRAE-debugger | 集成测试（slice 08）出现运行时疑难时 |
| grill-with-docs | 若用户再提新方向性变更（如主系统设计） |
| handoff | 下次会话结束时再次交接 |

---

## 六、相关文件路径清单

```
e:\SelfMarkProject\skill\
├── CONTEXT(业务术语).md                     # 术语表（权威词汇）
├── PRD(产品规格说明书).md                    # demo 版 PRD（权威规格）
├── docs\adr\0001-plugin-market-replaces-task-market.md
├── issues\
│   ├── slice-01~03（已完成，认证）
│   ├── slice-04-plugin-market-skeleton-seed-list.md      # ← 下一个开工
│   ├── slice-05-install-plugin-default-config.md
│   ├── slice-06-update-plugin-config.md
│   ├── slice-07-plugin-enable-disable-uninstall.md
│   ├── slice-08-plugin-market-integration-test.md
│   └── archive-v1\（v1 归档，参考用）
e:\SelfMarkProject\SelfMark-app\api\         # 后端代码（auth 已完成）
```
