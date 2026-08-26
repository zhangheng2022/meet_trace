# 会迹（MeetTrace）质量与验收

> 状态：活动；固定 TestFlight 外测审核、Windows Package Flight/production 提交、两阶段真实分发验证和统一自动公开门禁已实现；新门禁首次成功运行前，Windows 继续标记为“规划中/未就绪”
>
> 更新日期：2026-08-26
>
> 上游：[Alpha PRD V1.4](../product/Alpha_PRD_无登录版.md)

本文只保留当前自动化、构建和分发门槛。旧 Step 报告、旧测试数量、旧 APK 体积和旧工作流运行结果均从 Git 历史追溯，不能替代当前候选检查。

## 当前结论

- 仓库已具备格式、静态分析、测试、Android 包审计、iOS 无签名构建审计和统一 Alpha 候选流程；真实行为以 `.github/workflows/` 及守卫测试为准。
- SenseVoice、Silero VAD、Pyannote 和 3D-Speaker 运行时下载、严格校验、联合最终快照及文本/WAV 分享主链已实现。
- Patrol/Firebase Test Lab、Widget、Domain、Data 与平台守卫继续承担自动化回归，但不要求提交目标设备人工证据，也不将性能或准确率记录作为发布阻断条件。
- 官方 `sherpa_onnx 1.13.6` 继承了完整波形输入缓冲区释放修复。重复长会议内存、RTF、DER、能耗和温控可作为非阻断工程观测；运行失败时继续降级为单一说话人。
- Windows x64 Debug/Release 工程、SQLite FFI、输入设备锁定/一次回退、连续性事件、单实例激活、录音 close 转托盘、“停止并退出”安全封存及睡眠/恢复缺口记录链已实现并有自动化/本机构建冒烟。常规 CI 保留不可分发开发探针；正式 `Alpha Release` 生成固定 Partner Center 身份的 Store MSIX，只把包体上传 Actions Artifact 和 Partner Center。协调器以 Store CLI/API 核验 Flight 与 production，同一 MSIX 必须分别通过专用 Windows 机安装、启动、卸载；自动更新解析器只接受 Store ID `9PHHSJMWK06G` 和包身份 `zhangheng2026.MeetTrace`。新门禁尚无成功生产运行，因此 Windows 当前必须继续标记为“规划中/未就绪”。
- PRD V1.4 要求 Android/iOS/Windows 同 SHA 的构建、自动化、分发与统一公开门禁；发布链只保留两个工作流，不再要求目标设备人工验收记录。

## 自动化门禁

| 范围 | 当前入口 | 当前证据与缺口 |
|---|---|---|
| 跨平台 CI | `.github/workflows/quality.yml` | Actions Lint 与按路径执行的格式、分析、测试、Android Debug APK、iOS/Windows 构建审计，并始终汇总 `CI Gate` |
| 可复用质量核心 | `.github/workflows/_flutter-core.yml` | 为 PR CI 与 Alpha Release 提供同一套格式、分析和测试门禁 |
| 正式候选 | `.github/workflows/alpha-release.yml` | 同一 SHA 三平台候选；Android 签名 arm64 APK 在 Firebase ARM 原样验证一次；最终公开后重下 APK 并复核摘要 |
| 候选协调 | `.github/workflows/alpha-release-reconcile.yml` | Flight 提交/恢复、TestFlight/Store 轮询、Windows Flight/production 两阶段专用机验证、100% production 与最终门禁 |
| Windows 发布门禁 | `quality.yml` 开发探针；两个发布工作流的 Store 生命周期 | 固定 Store 身份、三平台同 SHA/版本、Published/Public 回执和两次独立专用机验证形成机器合同；首次完整生产运行前不得宣称闭环 |
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
| Windows | Windows 10 22H2/11 x64、固定 Store 身份 | 规划中/未就绪；MSIX 审计、Private audience/Flight、正式认证与统一公开已通过，生命周期工作流已实现，仍待专用机完成真实 Store 安装、卸载和更新运行 |

Android、iOS 与 Windows 必须来自同一 SHA、发布标识和共用构建号。目标设备人工记录、固定设备矩阵、性能指标表和人工验收模板不进入发布流程。Firebase Test Lab 与本地设备运行可以继续用于自动化回归和问题诊断，但其结果不是公开批准的必填输入。

最终公开由协调器生成的不可变门禁决定，操作见[发布流程](../project/GitHub_版本发布流程.md)。门禁逐项核对同一候选身份、TestFlight `APPROVED/Testing`、Store Flight `Published`、production `Published/Public` 以及两阶段真实分发回执；任一不匹配都会阻断公开并维护 `release-blocked` Issue，不依赖 `github-release` 或 `windows-store-validation` 人工审批。

## 维护规则

- 本文维护门槛和未闭环事项，不累积逐日开发日志。
- 完成一次候选后，构建、签名、包审计和分发记录应放在对应 Release、Actions Artifact、TestFlight 或 Partner Center；仓库只更新仍有效的状态摘要。
- 平台、模型、指标或 P0 变化必须先更新 PRD，再同步技术方案和本文。
- Sentry 的采样、隐私与符号化按 [Sentry 配置](../project/Sentry_配置.md)单独验证，SDK 故障不得阻断事实录音。
