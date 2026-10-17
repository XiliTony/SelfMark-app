# Spec Delta

## Purpose

定义平台插件目录的唯一标识、初始化及市场查询行为，使用户始终能够浏览画板和番茄钟，并在同一次响应中获得只属于自己的安装状态和配置，为后续安装与配置操作提供稳定的入口。

## ADDED Requirements

### Requirement: Platform catalog has unique stable plugin codes

平台插件 MUST 具有唯一且区分大小写的 `code`，以及名称、可空描述、排序值和创建时间。相同 code MUST NOT 对应多个目录记录；数据库 MUST 拒绝重复 code。

#### Scenario: Duplicate code cannot create a second catalog entry
- **WHEN** 向数据库再次写入 `code=quadrant-board` 的目录记录
- **THEN** 唯一约束拒绝重复写入，原记录保持不变

#### Scenario: Code lookup uses the exact identifier
- **WHEN** 客户端安装 `Quadrant-Board` 而目录仅有 `quadrant-board`
- **THEN** 返回404，不自动转为小写或视为同一标识

### Requirement: Required catalog data is initialized in every environment

系统 MUST 在首次成功启动前初始化 `quadrant-board`（名称画板、sort=1）和 `pomodoro`（名称番茄钟、sort=2）。默认、local、test、prod 均 MUST 获得同一份平台目录；重复启动 MUST NOT 新增重复记录或修改已有 Installed Plugin 配置。

#### Scenario: Empty database receives the demo catalog
- **WHEN** 应用连接空数据库并成功完成初始化
- **THEN** 平台目录恰好包含画板和番茄钟，且没有自动安装任何用户实例

#### Scenario: Restart preserves catalog identity and user configuration
- **WHEN** 在同一数据库上关闭并重建应用上下文
- **THEN** 两个预置 code 各只有一行，其原有ID和用户的配置、enabled保持不变

#### Scenario: Production receives catalog without development users
- **WHEN** 仅使用生产数据库初始化路径启动应用
- **THEN** 两个插件均可查询，且没有因插件初始化而导入联调账号或测试实例

### Requirement: Market returns catalog with the current user's state

`GET /api/plugins` MUST 返回全部平台插件及当前用户的 `installed`、`userPluginId`、`enabled`、`config`。目录字段 MUST 包含 `id`、`code`、`name`、`description`、`sort`；排序 MUST 为 `sort ASC, id ASC`。响应 MUST 为HTTP200及 `{code:200,msg:"success",data:[...]}`。

#### Scenario: Uninstalled plugin uses explicit null state
- **WHEN** 当前用户未安装目录中的插件
- **THEN** 对应条目 `installed=false`，`userPluginId`、`enabled`、`config` 均显式为JSON null，目录条目仍存在

#### Scenario: Disabled plugin is still installed
- **WHEN** 当前用户的插件实例 `enabled=false`
- **THEN** 对应条目 `installed=true`、`enabled=false`，并返回该实例ID及完整对象配置

#### Scenario: Other users' installations do not affect the list
- **WHEN** 用户A安装画板，尚未安装的用户B查询市场
- **THEN** B的画板仍为 `installed=false`，B无法从响应获得A的实例ID、配置或状态

#### Scenario: Equal sort values produce a stable order
- **WHEN** 多个目录插件的sort相同
- **THEN** 这些插件按目录ID升序返回，所有用户的目录顺序一致

#### Scenario: Empty catalog is a successful empty list
- **WHEN** 查询时目录没有任何记录
- **THEN** 返回HTTP200和 `data=[]`，不返回null或404

### Requirement: Market requires the existing authentication contract

市场查询 MUST 使用既有 Bearer JWT 鉴权。缺失、无效、过期或已登出的token MUST 返回401；错误响应 MUST 包含与HTTP状态一致的code及 `data:null`。用户身份 MUST 取自认证上下文。

#### Scenario: Missing token rejects market access
- **WHEN** 未携带token访问 `GET /api/plugins`
- **THEN** 返回HTTP401及 `code=401`，不返回目录或任何实例状态

#### Scenario: Logout invalidates plugin access
- **WHEN** 使用已登出且尚未过期的token访问市场
- **THEN** 返回401，沿用既有Redis黑名单规则

#### Scenario: Client supplied user identifier does not select another user's state
- **WHEN** 用户B在市场请求附加用户A的 `userId` 参数
- **THEN** 查询仍使用B的认证身份，不返回A的安装状态
