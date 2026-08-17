# 会迹（MeetTrace）隐私政策

> 生效日期：2026-08-17

MeetTrace 是无登录、无跨设备同步的本地优先会议记录应用。本政策说明公开 Alpha 在 Android、iOS 与 Windows 上处理的数据和网络访问。项目源代码与问题跟踪位于 [zhangheng2022/meet_trace](https://github.com/zhangheng2022/meet_trace)。

## 本机数据

MeetTrace 在应用私有目录保存事实 PCM、会议标题与时间、转录、说话人标签、处理状态、检查点、设置和下载的模型。应用不会把事实 PCM、临时 WAV、完整转录或说话人结果上传到 MeetTrace 业务服务器，也不提供云端 ASR、登录或同步。

用户主动执行文本分享，或在查看名称、时长、大小和敏感提醒后二次确认音频分享时，选定内容会进入操作系统分享面板。接收应用之后如何处理内容由用户选择的接收方及其隐私政策决定。

## 网络访问

- 首次初始化或资源修复会从 `mt.zhangheng.eu.org` 下载固定的 SenseVoice、Silero VAD、Pyannote 与 3D-Speaker 文件。请求会向托管服务暴露常规连接信息，例如 IP 地址、时间、User-Agent 和下载字节范围；不会随请求上传事实 PCM 或转录。
- 当前 Android/iOS Release 可按构建配置启用 Sentry 远程诊断。启用时可能发送错误、设备与运行环境、默认 PII、日志、指标、性能、交互、失败请求上下文，以及全部文本和图片均被遮罩的 Replay、截图和 View Hierarchy；不会上传事实 PCM、临时 WAV、完整转录或说话人结果作为 Attachment 或自定义 Payload。处理受 [Sentry 隐私政策](https://sentry.io/privacy/)约束。
- 由 SignPath Foundation 签名的 Windows 候选固定使用 `SENTRY_ENABLED=false`，不启动 Sentry 远程诊断。Windows MSIX 签名由 [SignPath.io](https://about.signpath.io/) 与 [SignPath Foundation](https://signpath.org/)处理；签名服务处理的是构建产物、来源和发布元数据，不接收会议内容。
- iOS TestFlight 和 Microsoft Store 分发分别受 Apple 与 Microsoft 的账户、商店和诊断设置约束。未来自动更新正式接线后，只能访问公开批准的签名更新清单和平台安装入口；在接线与隐私选项验收完成前不得扩大公开分发。

## 诊断控制

公开 Windows SignPath 候选不启用 Sentry。Android/iOS Alpha 的 Sentry 开关是构建期配置，目前没有应用内遥测开关；因此这些平台的安装说明和发布说明必须明确披露远程诊断。需要完全关闭 Sentry 的测试构建必须使用 `SENTRY_ENABLED=false`，且不得伪装成同一正式候选。

MeetTrace 不接入广告、业务分析、用户画像或 AI 总结服务。

## 保留、删除与卸载

- 删除会议会删除该会议的音频、转录、说话人标签、处理记录和应用自有分享临时文件。
- 设置中的本地数据控制用于查看和清理应用管理的数据；Alpha 数据代变化可能在启动时清理全部本地数据并重新下载模型。
- 卸载应用会删除应用私有目录中的会议、模型与设置。已经分享给其他应用的副本不受 MeetTrace 控制。
- Sentry 已接收的诊断数据按 Sentry 项目配置和其隐私政策保留；仓库不保存这些远程事件的副本。

## 联系与变更

隐私问题可通过 [GitHub Issues](https://github.com/zhangheng2022/meet_trace/issues) 提交，但请勿在公开 Issue 中附加录音、完整转录、访问令牌或其他敏感信息。政策发生实质变化时会在仓库和对应发布说明中更新生效日期；历史版本由 Git 记录。
