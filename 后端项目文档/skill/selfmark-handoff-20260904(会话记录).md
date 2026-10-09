# Self-Mark App 后端 v1 — 会话交接文档

**交接时间**: 2026-09-04
**工作目录**: `e:\SelfMarkProject\skill`
**项目**: Self-Mark App（自律习惯养成 App）后端 v1

---

## 一、项目背景速览

用户要开发一个帮助人养成自律习惯、解决拖延症的 App。前后端分离：前端 Flutter（后续开发），后端 Spring Boot（当前阶段），MySQL + Redis + JWT，Restful API。

产品核心：插件市场 → 订阅任务 → 每日到点双边界提醒（开始+结束各弹一次本地通知）。

**关键环境信息**：
- 用户已装 JDK 21（另有 Java 8 共存），选 Java 21 + Spring Boot 3.x + Maven
- 本机未装 Maven/Gradle（用 IDE 内置或 Wrapper）
- 用户主要负责前端开发，后端概念需讲得通俗（讨论中多次需要消解后端黑话）
- 项目名 Self-Mark App，公司名 nortidart
- 无 git 仓库、无 issue tracker，所有文档存本地 markdown

---

## 二、已完成的工作

### 2.1 设计盘问（grill-with-docs 流程）

通过 16 轮逐题盘问敲定所有领域决策。**重要决策演进路径**（避免新会话重走弯路）：

1. **插件 vs 任务**：最初想保留 Plugin 作为上位词，用户最终决定"都叫 Task，插件只是前端 UI 文字"，无 Plugin 实体
2. **触发语义**：v1 = Time Window 起点+终点各定时弹一次（本地通知），未来可能改
3. **订阅模型**：引用而非快照；但后来演进出 **SHARED 发布即完全冻结**（不可改 name/content、不可撤回、不可删除，PRIVATE→SHARED 单向不可逆），因此"作者改内容影响订阅者"的场景根本不存在
4. **用户删任务**：曾提"撤回共享"方案，最终废弃，SHARED 无任何删除/修改路径
5. **日级冻结**：APP 每天首次打开拉一次 schedule 存本地，用户可选下拉刷新（决策 C）；后端 Redis 缓存到当天 23:59
6. **v1 明确不做**：完成记录/打卡、跨天任务（end>start 校验）、全局暂停、社交、MQ、服务端推送、refresh token（单 token + Redis 黑名单）、任务版本化
7. **登录**：用户名 + 密码（bcrypt），JWT 单 token 7 天 TTL，登出 token jti 入 Redis 黑名单

### 2.2 已产出文档（都在 `e:\SelfMarkProject\skill\`）

| 文件 | 内容 |
|---|---|
| `CONTEXT.md` | 术语表（Task/Time Window/Subscription/Shared Task/Private Task/System Task），主标题已汉化为"Self-Mark App（自律 App）" |
| `docs/PRD.md` | 完整 PRD：问题陈述/解决方案/38 条用户故事/实现决策（技术栈、3 张表 schema、14 个 API 契约、12 项架构决策、事务边界、错误码）/测试决策（3 类接缝）/不在范围 |
| `docs/issues/slice-01-skeleton-infrastructure.md` ~ `slice-10-schedule-redis-cache.md` | 10 个垂直切片（tracer-bullet），每个含构建内容/验收标准/前置依赖/参考文档 |

**切片依赖链**: 01 骨架 → 02 注册登录 → 03 登出黑名单 → 04 System Task seed+市场 → 05 创建 Private Task+自动订阅（引 subscription 表）→ 06 改删+权限 ∥ 07 share 发布（可并行）→ 08 订阅/取消 → 09 改订阅+mine 列表 → 10 schedule 下发+Redis 缓存

**注意**：所有文档标题已按用户要求汉化（## 问题陈述、## 构建内容、## 验收标准等），正文中的规范术语（Task/Subscription/SHARED 等）保留英文。用户对此最后一轮 review 尚未明确确认，接手后可再问一句。

---

## 三、下一步工作（按优先级）

1. **确认文档终稿**：向用户确认汉化后的 PRD 和切片文件是否符合预期
2. **搭后端骨架（切片 01）**：用户说"先不要搭骨架"是为了先写 PRD，现在文档已齐，可开始。技术栈 Java 21 + Spring Boot 3.x + Maven + MyBatis-Plus + MySQL 8 + Redis，包根 `com.nortidart.selfmark`，放在 `e:\SelfMarkProject\skill\backend\`
3. **按切片依赖链推进**：每个切片是独立可认领单元，AI 可逐个实现并按验收标准自验
4. **建议补一个 ADR**：SHARED 发布即完全冻结（不可逆+违反直觉+真实权衡）满足 ADR 三条件，可考虑 `docs/adr/0001-shared-task-frozen.md`

---

## 四、用户偏好与沟通注意

- **语言**：全程中文
- **沟通方式**：用户是前端开发者，后端概念（如"缓存""日级冻结"）需要用通俗语言解释，避免堆黑话；一次问一个问题，给推荐答案+理由+反方观点
- **决策风格**：倾向简单方案，遇到复杂边界问题常简化需求（如"发布即冻结"替代版本化）；喜欢先讨论清楚再动手
- **工具偏好**：用户明确要求用 grill-with-docs、to-prd、to-issues 技能走流程；标题必须中文
- **未决细节**（PRD 里已列，实现时定）：接口文档工具（建议 SpringDoc/Knife4j）、seed 注入方式（建议 Flyway 或启动脚本）、CORS 配置、JWT 密钥管理

---

## 五、建议技能

| 技能 | 使用时机 |
|---|---|
| 无需再调用 grill-with-docs | 设计已盘清，文档已产出 |
| 开始写代码时 | 直接按 `docs/issues/slice-01-skeleton-infrastructure.md` 实现，逐切片推进 |
| TRAE-code-review | 每个切片完成后可做代码审查 |
| handoff | 下次会话结束时再次交接进度 |

---

## 六、相关文件路径清单

```
e:\SelfMarkProject\skill\
├── CONTEXT.md                                          # 术语表
├── docs\
│   ├── PRD.md                                          # 完整 PRD
│   ├── issues\
│   │   ├── slice-01-skeleton-infrastructure.md         # 骨架+基础设施
│   │   ├── slice-02-register-login.md                  # 注册登录
│   │   ├── slice-03-logout-jwt-blacklist.md            # 登出+黑名单
│   │   ├── slice-04-system-task-seed-market.md         # seed+市场
│   │   ├── slice-05-create-private-task-auto-subscribe.md
│   │   ├── slice-06-private-task-update-delete-permission.md
│   │   ├── slice-07-private-to-shared-publish.md
│   │   ├── slice-08-subscribe-market-task.md
│   │   ├── slice-09-update-subscription-my-tasks.md
│   │   └── slice-10-schedule-redis-cache.md
│   └── (未来: adr\0001-shared-task-frozen.md 建议)
├── backend\                                            # 待创建
└── frontend\                                           # 未来 Flutter
```
