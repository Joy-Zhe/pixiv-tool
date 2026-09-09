# PixivTool Flutter 架构

## 分层

`lib/app` 负责启动、主题、路由、国际化与依赖组装；`lib/domain` 只包含纯 Dart 模型和接口；`lib/infrastructure` 实现 Pixiv AJAX、会话、Drift 数据库、安全凭据、连接池和下载器；`lib/features` 包含各桌面页面。

UI 只创建领域请求。PID、排行榜和收藏夹不会自行传输文件，所有任务统一进入 `PersistentDownloadQueue`。

## 会话与请求

1. WebView 登录或手动 Cookie 输入取得原始 Cookie。
2. `PixivSessionImpl` 调用当前用户接口验证 Cookie，验证成功后才写入系统安全存储。
3. `PixivHttpClient` 维护一个长期存活的 `dart:io HttpClient`，统一注入 Cookie、Referer、代理与 API 重试策略。
4. `PixivApiClient` 是 AJAX 字段映射的唯一边界；UI 和领域层不依赖 Pixiv JSON 结构。
5. 401 会使需要元数据的任务进入 `waitingForAuth`。已经取得 URL 的流式传输可以完成，重新登录后等待中的任务恢复。

## 收藏同步

收藏缓存以账户 ID、公开状态和 PID 隔离。页面先订阅 Drift 缓存，再刷新服务器首批数据。完整同步按 48 条一页遍历，只有全部分页成功后才删除服务器已经不存在的缓存；失败不会误删。选择集合保存 `PID -> BookmarkItem` 快照，因此切换筛选或分页不会丢失选择。

“下载所选”冻结当前选择；“下载全部筛选结果”重新遍历服务器全部分页并冻结固定任务快照，不依赖当前可见列表。ugoira 创建 `skipped/unsupportedType` 结果。

## 下载生命周期

`pending -> resolving -> downloading -> completed`

异常分支包括 `paused`、`waitingForAuth`、`failed`、`cancelled`、`skipped`。数据库保存任务、文件 URL、目标/临时路径、字节数、ETag、Last-Modified、状态与错误。启动时将中断的 `resolving/downloading` 恢复为 `paused`。

文件流写入 `.part`，续传发送 `Range` 和 `If-Range`；200 响应或实体改变会清空临时文件后重下。完成时校验 Content-Length/记录长度，再原子改名。队列限制文件并发，UI 快照最多每 200ms 发布一次。

## 本地数据

- SQLite：账户元数据、收藏缓存、下载任务、下载文件、普通偏好
- 系统安全存储：Pixiv Cookie、代理密码
- 文件系统：完整下载和 `.part` 临时文件

下载路径在任务创建时冻结，修改设置只影响新任务。删除收藏缓存不会删除下载历史。

## 后续扩展

OCR、翻译和 ugoira 转换应作为独立 Provider/Worker 接入领域接口。CPU 密集工作放入 isolate 或 FFI worker，不应阻塞 Flutter UI isolate；现有下载与 Pixiv API 接口无需改变。
