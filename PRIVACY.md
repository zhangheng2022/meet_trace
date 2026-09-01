# 会迹（MeetTrace）隐私政策

> 生效日期：2026-08-31

MeetTrace 是无登录、无跨设备同步的本地优先会议记录应用。本政策适用于公开 Alpha 的 Android、iOS 和 Windows 版本。

## 本机数据

应用私有目录保存事实 PCM、会议元数据、转录、说话人标签、处理状态、检查点、设置和模型。MeetTrace 不提供业务云端 ASR 或同步，也不会上传事实 PCM、临时 WAV、完整转录或说话人结果到 MeetTrace 业务服务器。

用户主动分享文本，或二次确认音频分享后，选定内容会进入系统分享面板；之后由接收应用及其隐私政策负责。

## 网络访问

- 初始化和修复从 `mt.zhangheng.eu.org` 下载固定模型。托管服务会收到 IP、时间、User-Agent 和 Range 等常规连接信息，不会收到会议内容。
- Android、iOS 和 Windows Release 默认启用 Sentry 远程诊断。Sentry 接收未处理错误与必要堆栈、匿名 Release Health、抽样性能 Span、录音期间每 60 秒聚合的写入/队列/中断性能窗口，以及最多 100 条脱敏 Breadcrumb。平台支持时还会接收原生崩溃、ANR、App Hang、Watchdog 或 Tombstone。处理受 [Sentry 隐私政策](https://sentry.io/privacy/)约束。
- 应用使用 Sentry 官方 HTTP 客户端自动观测 Dart HTTP 请求，但只保留域名、HTTP 方法、状态码和耗时；不保留完整路径、查询参数、请求头、请求体、响应体或下载文件名，也不向目标服务传播 Sentry 追踪标识。
- Sentry 只允许记录 App 版本/构建号、平台、OS 版本、设备型号、CPU 架构、内存压力、前后台状态和语言区域代码，以及符号化所需的应用源码文件名、函数名和行号。不会上传事实 PCM、WAV、完整转录、说话人结果、会议/文件标识、运行时数据路径、用户标识、广告/安装 ID、设备名称、运营商、精确时区、截图、View Hierarchy、Replay、结构化日志、用户交互内容或附件。
- 候选经 Microsoft Partner Center 认证、签名和分发；SignPath 仅为未接入的申请路线，当前不接收候选。
- TestFlight 和 Microsoft Store 的账户、商店及平台诊断受 Apple、Microsoft 的设置与政策约束。

首次安装会在 Sentry 最早初始化的同一首屏展示一次非阻断告知；设置中的“远程诊断”开关默认开启并可随时关闭。关闭会停止应用侧后续采集，但已交给 SDK、已进入原生缓存或已上传的数据不能保证撤回；Windows 原生崩溃采集最迟在下次启动时完全关闭。MeetTrace 不接入广告、业务分析、用户画像或 AI 总结服务。

Android/iOS 最多离线缓存 10 个 Sentry Envelope；Windows 的 Dart 错误和性能数据在线发送，失败即丢，只有 Crashpad 原生崩溃数据可能在下次启动补传。

## 删除与保留

- 删除会议会删除该会议的音频、转录、说话人标签、处理记录和应用自有临时分享文件。
- 破坏性 Alpha 可在安装前确认后清除全部应用数据并重新初始化；卸载也会删除应用私有目录。已分享副本不受 MeetTrace 控制。
- Sentry 项目关闭 IP 存储和基于 IP 的地理推断，并启用敏感字段清洗；网络连接仍会使 Sentry 的接收端在传输过程中接触源 IP。远程事件使用账户支持的最短保留期且不超过 30 天，仓库不保存这些事件。
- 删除会议、破坏性清理、卸载或关闭远程诊断不会追溯删除已经发送的匿名 Sentry 事件；它们会按上述保留期到期删除。

隐私问题可提交至 [GitHub Issues](https://github.com/zhangheng2022/meet_trace/issues)，但不要附加录音、完整转录、令牌或其他敏感信息。实质变更会更新生效日期；历史由 Git 保留。
