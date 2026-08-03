# 会迹（MeetTrace）

本地优先的 Android + iOS 会议录音、端侧转录与证据化总结应用。

- 本地事实音频优先，实时转录变慢或失败时录音继续。
- 首次初始化按固定 Manifest 下载并校验 SenseVoice 与 Silero VAD；资源未就绪前不进入首页。
- AI 总结只基于最终转录，关键结论保留时间戳证据。
- Android + iOS Alpha 不提供登录或跨设备同步，并分别遵循两端原生交互与后台生命周期。

项目资料从[活动文档索引](docs/README.md)进入；[产品上下文](PRODUCT.md)与[交互视觉规范](DESIGN.md)分别服务于产品、设计和实现协作，冲突时以活动 PRD 为准。
