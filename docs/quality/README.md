# 会迹（MeetTrace）质量与验收

> 状态：活动；Android 已有公开 Alpha，iOS 已具备 TestFlight 上传链路，Windows 已有固定 Store 身份候选与正式 submission 公开状态机器门禁；Partner Center 凭据、限定受众/Flight、首次认证及三平台统一发布运行尚未闭环
>
> 更新日期：2026-08-20
>
> 上游：[Alpha PRD V1.2](../product/Alpha_PRD_无登录版.md)

本文只保留当前自动化、构建和分发门槛。旧 Step 报告、旧测试数量、旧 APK 体积和旧工作流运行结果均从 Git 历史追溯，不能替代当前候选检查。

## 当前结论

- 仓库已具备格式、静态分析、测试、Android 包审计、iOS 无签名构建审计和统一 Alpha 候选流程；真实行为以 `.github/workflows/` 及守卫测试为准。
- SenseVoice、Silero VAD、Pyannote 和 3D-Speaker 运行时下载、严格校验、联合最终快照及文本/WAV 分享主链已实现。
- Patrol/Firebase Test Lab、Widget、Domain、Data 与平台守卫继续承担自动化回归，但不要求提交目标设备人工证据，也不将性能或准确率记录作为发布阻断条件。
- 官方 `sherpa_onnx 1.13.6` 继承了完整波形输入缓冲区释放修复。重复长会议内存、RTF、DER、能耗和温控可作为非阻断工程观测；运行失败时继续降级为单一说话人。
- Windows x64 Debug/Release 工程、SQLite FFI、输入设备锁定/一次回退、连续性事件、单实例激活、录音 close 转托盘、“停止并退出”安全封存及睡眠/恢复缺口记录链已实现并有自动化/本机构建冒烟。常规 CI 保留不可分发开发探针；正式 `Alpha Release` 已生成固定 Partner Center 身份的 Store MSIX，审计 Windows 10 22H2/x64、运行资产以及模型权重/用户数据/凭据禁入，并只上传 Actions Artifact。最终公开 job 在唯一人工批准后、公开 Draft 和更新指针前，机器校验 Store 正式 submission 为 Published/Public、同版本且唯一 x64 包已上传，并保留脱敏回执。自动更新解析器只接受 Store ID `9PHHSJMWK06G` 和包身份 `zhangheng2026.MeetTrace`。Partner Center 凭据配置、首次 Private audience（后续 Package Flight）、正式 Store 认证、安装更新端到端和统一公开运行仍未闭环，Windows 当前不得标记为受支持。
- PRD V1.2 要求 Android/iOS/Windows 同 SHA 的构建、自动化、分发与统一公开门禁；不再要求目标设备人工验收记录。

## 自动化门禁

| 范围 | 当前入口 | 必须证明 |
|---|---|---|
| 跨平台 CI | `.github/workflows/quality.yml` | 按变更路径执行格式、分析、测试、Android Debug APK 与 iOS 无签名构建审计，并始终汇总 `CI Gate` |
| 可复用质量核心 | `.github/workflows/_flutter-core.yml` | 为 PR CI 与 Alpha Release 提供同一套格式、分析和测试门禁 |
| 正式候选 | `.github/workflows/alpha-release.yml` | 同一 SHA、Android 签名 arm64 APK、iOS TestFlight、Windows Store MSIX Artifact、三平台候选清单及一次公开批准 |
| Windows 发布门禁 | `quality.yml` 开发探针；`alpha-release.yml` Store 候选与公开状态核验 | 固定 Store 身份、三平台同 SHA/版本、正式 submission Published/Public、同版本唯一 x64 包与脱敏回执；待首次真实运行限定受众/Flight、认证和 Store 内置更新 |
| 本地交付 | `dart format lib test`、`flutter analyze`、`flutter test` | 当前工作树通过；代码变更按 AGENTS 完成 OCR 和目标平台构建 |

自动化失败时不得发布。性能、准确率、能耗、温控和设备实验室结果均为非阻断工程观测，不要求形成候选证据。

## 运行时资源门槛

| 资源 | 固定下载大小 |
|---|---:|
| SenseVoice 模型与 tokens | 239,549,735 B |
| Silero VAD | 212,860 B |
| Pyannote 分段模型归档 | 6,958,444 B |
| 3D-Speaker 嵌入模型 | 39,593,761 B |
| **总计** | **286,314,800 B** |

- 总下载不得超过十进制 300 MB，初始化可用空间门槛固定为 1 GiB。
- 权重不得进入 APK、IPA 构建产物或 MSIX；构建产物必须包含 Manifest、许可和 NOTICE，并阻断权重、录音、转录、凭据及分享临时文件。
- URL、哈希、安装文件集、原子激活和降级规则以[技术方案](../technical/端侧_SenseVoice_转录技术方案.md)为准。

## 平台构建与分发矩阵

| 平台 | 构建约束 | 发布门禁 |
|---|---|---|
| Android | API 24+、仅 `arm64-v8a` 签名 APK | 构建与包审计通过；Draft APK 与公开 APK 逐字节一致 |
| iOS | iOS 15+、arm64、只经 TestFlight | 签名上传成功；GitHub 不创建或上传 IPA |
| Windows | Windows 10 22H2/11 x64、固定 Store 身份 | MSIX 审计、Private audience/Flight、正式认证、安装与 Store 更新通过 |

Android、iOS 与 Windows 必须来自同一 SHA、发布标识和共用构建号。目标设备人工记录、固定设备矩阵、性能指标表和人工验收模板不进入发布流程。Firebase Test Lab 与本地设备运行可以继续用于自动化回归和问题诊断，但其结果不是公开批准的必填输入。

最终公开决策由 `github-release` 批准人承担，操作见[发布流程](../project/GitHub_版本发布流程.md)。批准人核对构建、自动化、候选身份、不可变资产和分发状态，不核对目标设备人工证据；批准后工作流仍须通过 Store 正式 submission 机器门禁，任一不匹配都会阻断公开。

## 维护规则

- 本文维护门槛和未闭环事项，不累积逐日开发日志。
- 完成一次候选后，构建、签名、包审计和分发记录应放在对应 Release、Actions Artifact、TestFlight 或 Partner Center；仓库只更新仍有效的状态摘要。
- 平台、模型、指标或 P0 变化必须先更新 PRD，再同步技术方案和本文。
- Sentry 的采样、隐私与符号化按 [Sentry 配置](../project/Sentry_配置.md)单独验证，SDK 故障不得阻断事实录音。
