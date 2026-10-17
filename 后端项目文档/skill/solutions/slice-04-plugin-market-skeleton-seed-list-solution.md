# Slice 04 完成方案：插件目录、数据库约束和市场列表

完成日期：2026-10-14。对应OpenSpec：`complete-plugin-backend-slices-04-08` 的任务1.1到1.7，7项全部完成；总change进度7/26。

## 交付范围

- 新增V4建表和V5平台目录seed；V1、V2、V3保持不变。
- 新增Plugin/UserPlugin实体、MyBatis mapper、JSON type handler、PluginService和PluginController。
- 实现 `GET /api/plugins`；安装、配置、启停、卸载接口留给切片05到07。
- 新增Controller测试4项、真实目录数据库测试4项、V3升级/生产重启测试1项；补齐既有启动测试的PluginMapper mock。
- 更新模块化OpenAPI维护源、生成YAML bundle和错误码。Apifox JSON仍由用户完成导入、测试及重新导出。

## 数据库设计

权威SQL：

- `api/src/main/resources/db/migration/V4__create_plugin_tables.sql`
- `api/src/main/resources/db/migration/V5__seed_builtin_plugins.sql`

### plugin

| 字段 | 类型与约束 | 边界 |
| --- | --- | --- |
| id | BIGINT、自增、主键 | 有符号Long；不依赖固定值或连续编号 |
| code | VARCHAR(50)、NOT NULL、uk_plugin_code唯一 | `utf8mb4_0900_bin`，区分大小写；不自动trim或转小写 |
| name | VARCHAR(50)、NOT NULL | 中文显示名，当前没有目录写接口 |
| description | VARCHAR(500)、可NULL | 两条seed先使用NULL，响应显式保留该字段 |
| sort | INT、NOT NULL、默认0 | 允许重复/负数，按sort再按id升序 |
| created_at | DATETIME、NOT NULL、默认CURRENT_TIMESTAMP | 数据库生成，本切片响应不暴露时间字段 |

### user_plugin

| 字段/约束 | 定义 | 边界 |
| --- | --- | --- |
| id | BIGINT、自增、主键 | 与目录ID分离；未来卸载重装生成新ID |
| user_id、plugin_id | BIGINT、NOT NULL | 逻辑关联，没有物理外键或级联删除 |
| config | JSON、NOT NULL | 根必须为对象，允许 `{}`、任意未知字段及内部数组/null |
| enabled | TINYINT(1)、NOT NULL、默认1 | CHECK限制为0或1，不依赖显示宽度来保证布尔语义 |
| created_at | DATETIME、默认CURRENT_TIMESTAMP | 数据库生成 |
| uk_user_plugin | UNIQUE(user_id,plugin_id) | 每用户每插件限一个实例；enabled不参与唯一键，禁用也占安装名额 |
| idx_user | INDEX(user_id) | 与联合唯一键左前缀重复，按现有切片要求保留；有额外写入/存储成本 |
| chk_user_plugin_config_object | CHECK(JSON_TYPE(config)='OBJECT') | SQL NULL、JSON null、根数组/标量被拒；不检查active、label等内部语义 |
| chk_user_plugin_enabled | CHECK(enabled IN (0,1)) | 直接SQL写2等值也失败 |

不新增sort或plugin_id索引：当前目录只有两条，列表按可信user_id关联，联合唯一键已支持这类查询。不新增物理外键是现行schema的明确取舍；未来增加用户或目录删除能力时必须一并设计实例清理，不能假定已有级联删除。MySQL按现有8.4环境验证，CHECK要求MySQL8.0.16或更新版本。

原生JSON会归一化空白和对象键顺序，比较配置时应解析后比较。经本轮用户确认，数值采用MySQL JSON原生精度：超出double精度的小数可能舍入；需要精确保留的高精度值应作为对象内的字符串提交，例如 `{"amount":"0.123456789012345678"}`。config本身仍为JSON对象，不是字符串。

### Navicat核对SQL

在已由应用/Flyway升级的目标库中只读检查：

```sql
SHOW CREATE TABLE plugin;
SHOW INDEX FROM plugin;
SHOW CREATE TABLE user_plugin;
SHOW INDEX FROM user_plugin;
SELECT id, code, name, description, sort FROM plugin ORDER BY sort, id;
SELECT version, description, success FROM flyway_schema_history ORDER BY installed_rank;
```

约束异常已经在独立测试容器中验证，不需要对自己的联调库执行违规INSERT来验收。

## seed生命周期

V5在所有环境的正常Flyway启动阶段创建画板 `(quadrant-board,画板,1)` 和番茄钟 `(pomodoro,番茄钟,2)`，不创建用户安装记录。

目录是生产必需数据，放在 `db/migration`，不在 `db/devdata` 或Java启动runner重复维护。SQL按code使用guarded insert；测试直接重复执行两次也保持原ID和配置。

同库重启时Flyway确认V5已执行，不重置目录或用户配置。已执行V5后如果人工删除某个目录行，普通重启不会重新补齐；修复或新增目录应新增migration，不修改已执行V5。干净数据库初始化后恰好两条，列表查询本身没有硬编码“两条”的限制。

## 接口契约

`GET /api/plugins`，需要 `Authorization: Bearer <jwt>`。无请求体、不分页；客户端附加userId不改变查询身份。

```json
{
  "code": 200,
  "msg": "success",
  "data": [
    {
      "id": 1,
      "code": "quadrant-board",
      "name": "画板",
      "description": null,
      "sort": 1,
      "installed": false,
      "userPluginId": null,
      "enabled": null,
      "config": null
    }
  ]
}
```

示例仅截取一条，正常干净目录还返回番茄钟；ID以实际数据库为准。id是目录ID，userPluginId是实例ID。未安装时三个状态字段显式null；已禁用实例仍installed=true、enabled=false，config按完整对象返回。空目录返回200和 `data:[]`。

列表一条参数化LEFT JOIN完成，用户条件位于ON中，保留未安装的目录条目；安装状态由实例ID是否存在推导，不由enabled推导。排序为 `sort ASC,id ASC`，不逐插件查询。自定义JOIN显式使用JSON type handler；UserPlugin实体的CRUD也启用autoResultMap，防止config回读成字符串。

失败沿用认证和统一包络：

| HTTP/code | msg | 场景 |
| --- | --- | --- |
| 401 | 未登录 | 缺少Bearer token |
| 401 | token 无效 | token无效或过期 |
| 401 | token 已登出 | Redis黑名单命中 |
| 500 | 服务器内部错误 | 数据库或Redis黑名单查询失败 |

错误data为null；当前响应code等于HTTP状态，成功不是0。A的实例不会出现在B的列表状态中。

## 自动化验收

在Docker Desktop已启动的环境从 `api/` 执行：

```powershell
mvn -o test
```

本次实际结果：45项测试，0失败、0错误、0跳过。Docker Engine29.8.0，测试容器MySQL8.4和Redis7.4-alpine。

| 测试类 | 数量 | 核心证据 |
| --- | ---: | --- |
| PluginControllerTests | 4 | 显式null、对象响应、空列表、token及身份上下文 |
| PluginCatalogIntegrationTests | 4 | 空库迁移、真实JOIN/JSON往返、A/B隔离、同sort排序、空目录、唯一/非空/CHECK约束 |
| PluginMigrationTests | 1 | V3增量升级、两次生产上下文启动保持ID/config/enabled、重复seed、未加载联调用户 |
| 既有认证、健康、基础设施及配置测试 | 36 | 全部回归通过，包含MySQL/Redis认证集成用例 |

MySQL CHECK违反返回vendor code3819，非法JSON为3140，NOT NULL违反为1048；测试断言底层错误码，避免误把Spring异常类名当成数据库约束是否执行的证据。

本终端的Maven Wrapper在沙箱环境报home解析错误，因此使用已安装的Maven3.9.11完成测试，没有修改wrapper。Docker命名管道在沙箱中拒绝访问，真实容器测试在经授权的沙箱外执行。

契约检查从仓库根执行 `bash api/check-api.sh`，最终退出码0：lint、bundle、相对origin/main的breaking检查全部通过。维护源位于 `api/docs/openapi/paths/plugin.yaml`、 `components/plugin-schemas.yaml`，bundle为 `api/docs/openapi/dist/selfmark.openapi.yaml`。

镜像加速服务无法拉取 `tufin/oasdiff:1.11.7`，Docker官方registry亦不可达。本次从oasdiff官方GitHub发布下载同版本Linux二进制，核对SHA-256为 `97f1052365f74e6fd6f4d8fa108606e09391aebb8ecbf3b5e7a4059d54327224` 后，在已忽略的 `.tmp/oasdiff-1.11.7` 中构建scratch临时镜像；版本输出为1.11.7，供原检查脚本使用。没有修改检查脚本或Docker daemon配置，临时发布包及Dockerfile不提交。

## 用户联调与提交

1. 在IDE使用既有local profile启动API，Flyway自动升级到V5；本轮只迁移了测试容器，未更改个人联调库。
2. 将生成的YAML bundle导入Apifox，登录取得token。Bearer Auth仅填原始token，不重复添加Authorization头。
3. 请求 `GET /api/plugins`，应见画板、番茄钟及当前账号未安装状态。安装接口尚未交付；预置实例回读已由真实数据库测试验证。
4. 完成Apifox Review和测试后重新导出JSON到 `api/docs/openapi/dist/selfmark.openapi.json`。现有JSON快照本轮没有冒充Apifox重新导出。
5. 用户自行查看变更并commit。建议标题：`feat(plugin): add catalog schema seed and market list`。切片04交付后再指定实施05。

本轮不修改真实连接配置、Docker daemon配置或历史migration，不执行Git暂存、commit、push或创建PR。
