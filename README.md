# PixivTool

PixivTool 是面向 Windows 与 macOS 的 Flutter 桌面下载器。当前版本支持 PID、搜索、排行榜、当前账户公开/非公开收藏夹，以及统一、可暂停和可恢复的下载队列。

## 支持范围

- Windows x64：Windows 10 1809 或更高版本
- macOS arm64：Apple Silicon，macOS 12 或更高版本
- 简体中文与英文，默认跟随系统

首版不包含 CLI、OCR、翻译、ugoira 下载或自动更新。ugoira 会在收藏列表中显示，但加入下载时会被明确标记为不支持并计入跳过数量。

## 开发环境

项目通过 [FVM](https://fvm.app/) 的 `.fvmrc` 固定 Flutter 3.47.2 stable。也可以直接使用完全相同版本的 Flutter SDK。

```powershell
fvm install
fvm flutter pub get
fvm dart run build_runner build --delete-conflicting-outputs
fvm flutter gen-l10n
fvm flutter run -d windows
```

macOS 上使用 `fvm flutter run -d macos`。Windows 构建 Flutter 插件时需要启用 Windows Developer Mode，以允许创建符号链接；内嵌登录还依赖 Microsoft Edge WebView2 Runtime。WebView2 不可用时仍可在设置页粘贴 Cookie 登录。

## 登录与隐私

默认登录方式会打开 Pixiv 内嵌登录页。登录成功后，应用读取 `.pixiv.net` Cookie，并通过当前用户接口验证账户；也可以在设置页手动粘贴 Cookie。Cookie 和代理密码只存入系统安全凭据存储，不写入 SQLite、普通设置或日志。

退出会清除安全 Cookie 与内嵌浏览器 Cookie。收藏缓存按用户 ID 隔离，退出后不会展示，可在设置页单独清除。

## 下载

- PID：`{pidRoot}/{pid}/{originalFileName}`
- 搜索：`{pidRoot}/{pid}/{originalFileName}`
- 排行榜：`{rankRoot}/{mode[_r18]}/{content}/{pid}/{originalFileName}`
- 收藏夹：`{bookmarkRoot}/{safeAuthorName}_{authorId}/{pid}/{originalFileName}`

收藏页可在公开/非公开、标签和内容类型间筛选，支持无限滚动、同步全部、选择已加载、跨页选择、下载所选，以及下载服务端全部筛选结果。

下载以响应流直接写入 `.part` 文件。应用重启后，中断中的任务会恢复为暂停状态；继续时使用 `Range` 与 `If-Range`，服务端不支持续传或实体变化时会从头下载。默认并发为 4，可在设置页调整为 1～8。

## 搜索

搜索页支持标签部分匹配、标签完全匹配以及标题/说明关键字三种模式。可以填写最低点赞数和最低收藏数；留空或填 0 表示不限，两个条件同时填写时必须同时满足。未设置门槛时每次加载一页；启用筛选时每次最多检查 5 页，找到匹配结果后处理完当前页即停止，点击“继续查找”可从下一页继续，也可随时停止扫描。应用会按需读取作品详情补齐计数；详情读取失败的作品不会被当作 0，并可在页面重试。搜索结果可跨页选择并加入统一下载队列。

## 代理

- System：使用进程/系统环境提供的代理配置
- Manual：为 Pixiv API 和图片下载指定 HTTP/HTTPS 代理，可使用用户名和密码
- Direct：直连

内嵌登录窗口始终使用系统代理。修改代理会重建网络客户端并暂停当前队列，用户确认后可从下载页继续。

## 质量检查与构建

```powershell
fvm dart format --output=none --set-exit-if-changed lib test
fvm flutter analyze
fvm flutter test
fvm flutter build windows --release
```

macOS arm64 构建使用：

```bash
fvm flutter build macos --release
```

CI 在 push/PR 上运行格式、分析和测试；推送 `v*` tag 会生成 Windows x64 便携 ZIP、MSIX，以及 macOS arm64 DMG。未配置签名凭据时，Release 仍会发布便携 ZIP、带 `-unsigned` 后缀的测试 MSIX 和 macOS DMG；Windows 可能阻止直接安装未签名 MSIX，此时请使用便携 ZIP，macOS 则需要用户手动允许打开未签名且未公证的应用。配置 Windows 代码签名证书和 Apple Developer 签名/notarization 凭据后，工作流会自动改为正式签名发行。

架构与数据流见 [docs/architecture.md](docs/architecture.md)。Pixiv AJAX 并非稳定公共 API，相关请求与响应映射集中在基础设施适配层，并有脱敏 fixture 测试保护。
