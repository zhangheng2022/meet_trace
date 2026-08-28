# 会迹（MeetTrace）隐私政策

> 生效日期：2026-08-28

MeetTrace 是无登录、无跨设备同步的本地优先会议记录应用。本政策适用于公开 Alpha 的 Android、iOS 和 Windows 版本。

## 本机数据

应用私有目录保存事实 PCM、会议元数据、转录、说话人标签、处理状态、检查点、设置和模型。MeetTrace 不提供业务云端 ASR 或同步，也不会上传事实 PCM、临时 WAV、完整转录或说话人结果到 MeetTrace 业务服务器。

用户主动分享文本，或二次确认音频分享后，选定内容会进入系统分享面板；之后由接收应用及其隐私政策负责。

## 网络访问

- 初始化和修复从 `mt.zhangheng.eu.org` 下载固定模型。托管服务会收到 IP、时间、User-Agent 和 Range 等常规连接信息，不会收到会议内容。
- Android/iOS Release 可启用 Sentry，发送错误、设备和运行环境、默认 PII、日志、指标、性能、交互、失败请求上下文，以及全量遮罩的 Replay、截图和 View Hierarchy；不会把事实 PCM、WAV、完整转录或说话人结果作为 Attachment 或自定义 Payload。处理受 [Sentry 隐私政策](https://sentry.io/privacy/)约束。
- Windows Store 候选固定关闭 Sentry。候选经 Microsoft Partner Center 认证、签名和分发；SignPath 仅为未接入的申请路线，当前不接收候选。
- TestFlight 和 Microsoft Store 的账户、商店及平台诊断受 Apple、Microsoft 的设置与政策约束。

Android/iOS 的 Sentry 是构建期开关，当前无应用内遥测开关；安装说明和发布说明必须披露。MeetTrace 不接入广告、业务分析、用户画像或 AI 总结服务。

## 删除与保留

- 删除会议会删除该会议的音频、转录、说话人标签、处理记录和应用自有临时分享文件。
- 破坏性 Alpha 可在安装前确认后清除全部应用数据并重新初始化；卸载也会删除应用私有目录。已分享副本不受 MeetTrace 控制。
- Sentry 事件按 Sentry 项目配置和其政策保留，仓库不保存这些远程事件。

隐私问题可提交至 [GitHub Issues](https://github.com/zhangheng2022/meet_trace/issues)，但不要附加录音、完整转录、令牌或其他敏感信息。实质变更会更新生效日期；历史由 Git 保留。
