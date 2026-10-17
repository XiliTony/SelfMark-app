# 错误码表

## 通用错误码

| code | 含义 | 使用场景 |
| ---: | --- | --- |
| 400 | 请求参数错误 | DTO 校验失败、请求体格式错误 |
| 401 | 未登录或 token 无效 | 缺少、错误或过期的 JWT |
| 403 | 无权操作 | 当前用户没有资源权限 |
| 404 | 资源不存在 | 请求的资源不存在 |
| 409 | 业务冲突 | 手机号重复注册等状态冲突 |
| 415 | 媒体类型不支持 | JSON接口收到非JSON Content-Type |
| 500 | 服务器内部错误 | 未预期的服务端异常 |

## 认证模块

| HTTP/code | msg | 使用场景 |
| ---: | --- | --- |
| 400 | mobile 不能为空 / 手机号格式错误 | 注册或登录手机号缺失、不是中国大陆 11 位手机号 |
| 400 | password 不能为空 / password 不能超过 72 个 UTF-8 字节 | 密码缺失或超过 bcrypt 输入上限 |
| 400 | username 不能为空 / username 最长 50 个字符 | 注册展示名缺失或超长 |
| 401 | 手机号或密码错误 | 登录账号不存在或密码不匹配，统一提示避免账号枚举 |
| 401 | 未登录 | 受保护接口缺少 Bearer token |
| 401 | token 无效 | JWT 格式错误、签名错误、缺少必要声明或已过期 |
| 401 | token 已登出 | JWT 尚未过期，但 jti 已命中 Redis 黑名单 |
| 500 | 服务器内部错误 | Redis 黑名单写入或查询失败；鉴权保持 fail-closed，不降级到本地内存 |
| 409 | 手机号已注册 | 注册手机号已存在，包括并发唯一索引冲突 |

## 插件模块（切片04到07）

| HTTP/code | msg | 使用场景 |
| ---: | --- | --- |
| 400 | 请求体格式错误 | 配置或启停请求体为空或JSON语法错误 |
| 400 | config 必须是 JSON 对象 | 配置根为null、数组、字符串、数字或布尔值 |
| 400 | enabled 必须是布尔值 | 启停根非对象、字段缺失/null/字符串/数字/数组/对象；不自动转换 |
| 400 | id 必须是正整数 | 实例路径ID不能绑定Long、溢出、0或负数 |
| 401 | 未登录 | 五个插件接口缺少Bearer token |
| 401 | token 无效 | token签名、格式、声明或有效期不合法 |
| 401 | token 已登出 | token命中Redis黑名单 |
| 404 | 插件不存在 | 安装code不存在，或大小写/空白不匹配 |
| 403 | 无权操作该插件实例 | 合法配置、启停或卸载请求对应的实例属于其他用户 |
| 404 | 插件实例不存在 | 合法正整数实例ID不存在 |
| 409 | 插件已安装 | 同用户同插件已安装（包括禁用状态），或实例INSERT发生唯一冲突 |
| 415 | 仅支持 application/json | 配置或启停更新收到非JSON Content-Type |
| 500 | 服务器内部错误 | 数据库或Redis故障，缺默认配置/目录关联，事务内回读或响应构造失败 |

市场查询成功使用HTTP200和 `code:200`，空目录返回 `data:[]`。未安装的条目仍返回，且 `userPluginId`、`enabled`、`config` 显式为null；已禁用实例的 `installed` 仍为true。

`POST /api/plugins/{code}/install` 无需请求体，身份及完整默认配置由服务端决定；成功使用HTTP200（不是201），返回实例的 `id/pluginId/code/name/config/enabled`。重复安装不会重置原配置、状态或ID。非唯一冲突的数据库错误不转换为409；失败响应均保持 `data:null`。

`PUT /api/user-plugins/{id}/config` 仅接受application/json，body本身是完整配置对象。`{}` 清空旧字段，`{"config":...}` 按字面存储，未提交字段不会合并或补默认值；禁用状态可更新且enabled不变。有效路径和JSON语法通过后才查询实例及归属；同值更新返回200，不根据UPDATE changed rows=0判断404。

`PUT /api/user-plugins/{id}/enabled` 仅接受application/json及真实布尔enabled，只改变enabled；额外字段忽略，相同状态返回200，config和归属不变。

`DELETE /api/user-plugins/{id}` 成功返回HTTP200及data:null，物理删除单实例，不删除目录。重复DELETE和旧ID的两种PUT返回404；重装创建新ID、完整默认config和enabled=true，不恢复旧配置。

当前项目使用 HTTP 状态码同时作为响应体 `code`，即 HTTP 401 的响应体也必须是 `code: 401`。这里的 `code` 不是独立业务码；后续新增业务模块时继续补充稳定的 `msg`，避免同一场景出现多个消息文本。若未来引入 10xxx 等独立业务码，应新增 `errorCode` 字段或统一迁移 `code` 的语义，不能让同一字段有时表示 HTTP 状态、有时表示业务码。
