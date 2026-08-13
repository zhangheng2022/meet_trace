# 会迹（MeetTrace）质量与验收

> 状态：活动；Android 已有公开 Alpha，iOS 与双平台目标真机证据仍需按新候选闭环
>
> 更新日期：2026-08-13
>
> 上游：[Alpha PRD V1.0](../product/Alpha_PRD_无登录版.md)

本文只保留当前门槛和证据格式。旧 Step 报告、旧测试数量、旧 APK 体积和旧工作流运行结果均从 Git 历史追溯，不能替代当前候选复验。

## 当前结论

- 仓库已具备格式、静态分析、测试、Android 包审计、iOS 无签名构建审计和统一 Alpha 候选流程；真实行为以 `.github/workflows/` 及守卫测试为准。
- SenseVoice、Silero VAD、Pyannote 和 3D-Speaker 运行时下载、严格校验、联合最终快照及文本/WAV 分享主链已实现。
- Android/iOS 的目标 arm64 真机仍须完成录音连续性、ASR、说话人分离、分享、资源、温控和无障碍验收；任何旧候选的结果不能沿用到新 SHA。
- 官方 `sherpa_onnx 1.13.5` 已补充完整波形输入缓冲区释放。当前候选仍需完成 Android/iOS 重复长会议内存验证；证据闭环前不得据此扩大分发，运行失败时继续降级为单一说话人。

## 自动化门禁

| 范围 | 当前入口 | 必须证明 |
|---|---|---|
| 日常质量 | `.github/workflows/quality.yml` | 依赖锁、格式、分析、测试、Debug APK 构建与包审计 |
| iOS 无签名 | `.github/workflows/ios-unsigned.yml` | Debug/Release 无签名构建、App bundle 审计、工具链和产物摘要 |
| 正式候选 | `.github/workflows/alpha-release.yml` | 同一 SHA、Android 签名 arm64 APK、iOS TestFlight、候选清单及一次公开批准 |
| 本地交付 | `dart format lib test`、`flutter analyze`、`flutter test` | 当前工作树通过；代码变更按 AGENTS 完成 OCR 和目标平台构建 |

自动化失败时不得发布。自动化通过只证明技术检查，不代表目标设备、准确率、能耗或用户验收通过。

## 运行时资源门槛

| 资源 | 固定下载大小 |
|---|---:|
| SenseVoice 模型与 tokens | 239,549,735 B |
| Silero VAD | 212,860 B |
| Pyannote 分段模型归档 | 6,958,444 B |
| 3D-Speaker 嵌入模型 | 39,593,761 B |
| **总计** | **286,314,800 B** |

- 总下载不得超过十进制 300 MB，初始化可用空间门槛固定为 1 GiB。
- 权重不得进入 APK/IPA；构建产物必须包含 Manifest、许可和 NOTICE，并阻断权重、录音、转录、凭据及分享临时文件。
- URL、哈希、安装文件集、原子激活和降级规则以[技术方案](../technical/端侧_SenseVoice_转录技术方案.md)为准。

## 设备矩阵

| 平台角色 | 最低要求 | 主要验收 |
|---|---|---|
| Android 最低系统 | API 24、arm64-v8a 真机 | 安装、权限、前后台录音、检查点恢复、初始化与推理 |
| Android 低端性能 | 约 4 GB RAM、arm64-v8a 真机 | 30 分钟录音、RTF、延迟、DER、人数误差、内存、电量和温控 |
| Android 当前设备 | 当前支持的 arm64-v8a 真机 | 全主链、系统中断、文本/WAV 分享、删除和可访问性 |
| iPhone 分发基线 | iOS 15、arm64 | 工程配置、无签名构建产物审计、签名和 TestFlight 分发 |
| iPhone 当前设备 | 当前受支持 iPhone | 全主链、TestFlight、分享、内存/温控和 VoiceOver |
| iPad | 当前受支持 iPad | 横竖屏、Split View、Dynamic Type、导航和完整主链 |

模拟器只能做功能冒烟，不能替代 arm64 推理、录音连续性、能耗、温控或说话人质量证据。iOS 15 是编译与分发最低版本，但 Alpha 不要求 iOS 15 真机覆盖；当前设备真机证据必须记录实际系统版本，并明确最低版本只完成构建门禁。iOS 13/14 不再支持，已安装的旧 TestFlight 构建不提供专门迁移版。iOS 只通过 TestFlight 分发，GitHub 不上传 IPA；Android 公开候选只能是签名的 `arm64-v8a` APK。

## 每个候选的验收记录

记录至少包含：

- release ID、提交 SHA、构建号、工作流链接和产物 SHA-256；
- 设备型号、系统版本、ABI/架构、内存、测试日期和测试人；
- PRD AT-01～AT-18 中适用项的通过、失败或不适用结论；
- 30 分钟录音完整率、SenseVoice RTF P95/延迟 P95/关键事实召回率；
- 说话人 DER、人数绝对误差、RTF，以及重复任务峰值内存；
- 电量变化、起止/峰值温度、热降频、系统中断和后台行为；
- 文本分享、WAV 二次确认、接收端播放、临时文件清理和源 PCM 未变化；
- 失败项的复现步骤、用户影响、风险接受人和后续动作。

可使用 [alpha_release_input.json](./alpha_release_input.json) 记录结构化指标，但发布工作流不读取它。最终公开决策由 `github-release` 批准人承担，操作见[发布流程](../project/GitHub_版本发布流程.md)。

## 维护规则

- 本文维护门槛和未闭环事项，不累积逐日开发日志。
- 完成一次候选后，证据应放在对应 Release、Actions Artifact 或外部测试记录；仓库只更新仍有效的状态摘要。
- 平台、模型、指标或 P0 变化必须先更新 PRD，再同步技术方案和本文。
- Sentry 的采样、隐私与符号化按 [Sentry 配置](../project/Sentry_配置.md)单独验证，SDK 故障不得阻断事实录音。
