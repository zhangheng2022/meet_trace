# 会迹（MeetTrace）iOS Alpha 设备矩阵

> 状态：阻塞；无签名云端构建流水线已配置，等待首次运行、签名与真机证据
> 更新日期：2026-08-05
> 上游需求：[Android + iOS Alpha PRD V0.9](../product/Alpha_PRD_无登录版.md)

## 平台基线

| 项目 | 当前基线 |
|---|---|
| Flutter | GitHub Actions 跟随最新 stable；每次运行记录实际版本 |
| iOS 最低版本 | 13.0 |
| 必验架构 | arm64 真机 |
| Bundle ID / 签名 | Runner Debug/Release/Profile 已固定为 `com.meettrace.app`；Apple Team 未配置 |
| 录音实现 | `record` 7.1.1 / AVFoundation |
| 端侧推理 | `sherpa_onnx` 1.13.4 官方 Flutter 包；SenseVoice + Pyannote INT8 + 3D-Speaker |
| 内部分发 | TestFlight；不公开上架 |
| 后台能力 | `UIBackgroundModes: audio`；不承诺用户强制结束后继续录音 |

## 云端无签名构建

- [工作流规格](../../spec/spec-process-cicd-ios-unsigned.md)定义触发条件、质量门禁、产物合同和失败策略。
- `.github/workflows/ios-unsigned.yml` 使用 GitHub 托管的 `macos-latest`、Runner 默认稳定 Xcode 和 Flutter 最新 stable，不静默回退旧工具链。
- 流水线依次执行依赖解析、`flutter analyze`、`flutter test`、Debug/Release `--no-codesign` 构建和 Release App bundle 审计。
- `tool/benchmarks/inspect_ios_app.sh` 检查 Bundle ID、iOS 13.0、麦克风用途、后台音频、arm64、Flutter NOTICE、固定 Manifest/许可，并阻断模型权重、用户数据、签名材料或 provisioning profile。
- 成功运行上传 unsigned IPA、SHA-256、审计 JSON、工具链快照和构建元数据，保留 7 天。实际运行链接与结果尚未留证，因此本项当前仅代表仓库自动化已就绪。
- unsigned IPA 没有 Apple 签名和 provisioning profile，不能直接安装、不能进入 TestFlight，也不能替代 iPhone/iPad 真机验收。

## 必验设备

| 设备层级 | 目标 | 状态 | 必验内容 |
|---|---|---|---|
| 最低 iPhone | 待指定真实型号与系统版本 | 阻塞 | 30 分钟后台录音、SenseVoice、说话人分离、内存/温控、系统中断 |
| 当前 iPhone | 待指定真实型号与系统版本 | 阻塞 | 286.3 MB 初始化、锁屏、切后台、联合最终结果、文本/WAV 分享、删除、VoiceOver |
| iPad | 待指定真实型号与系统版本 | 阻塞 | 横竖屏、Split View、Dynamic Type、主从布局 |

## 发布门槛

- `flutter build ios --debug --no-codesign` 在 macOS/Xcode 环境通过。
- 云端 Release App bundle 审计通过，unsigned IPA 的 SHA-256、实际工具链和运行链接完成留证。
- 将 Bundle ID 改为 `com.meettrace.app`，并使用 Apple Team 完成签名与 TestFlight 内部测试配置。
- SenseVoice、Silero VAD、Pyannote 和 3D-Speaker 权重均不得进入 iOS 构建产物，首次初始化时下载。
- SenseVoice 与 `OfflineSpeakerDiarization` 在 iOS arm64 真机完成初始化、推理、释放和重复创建。
- 30 分钟前台、锁屏和切后台录音完整率均为 100%。
- 系统音频中断可恢复；用户强制结束后不显示“仍在录音”，重启可恢复已落盘事实音频。
- Dynamic Type 2.0、VoiceOver、浅/深色、边缘返回和 iPad 多任务窗口通过。
- 普通话 2/3/4 人固定语料达到 DER、人数误差和 RTF 门槛；失败时联合结果以单一说话人降级并一次发布。
- WAV 分享二次确认、时长一致性、临时文件清理和空间不足提示通过。
- 权限用途、官方原生库、NOTICE/隐私清单、密钥和用户数据完成构建产物审计。

在以上证据闭环前，双平台 Alpha 发布门禁必须保持 `blocked`。
