# Step 21：C++ Whisper 质量交付基线

> 状态：进行中（工程基线通过，真实去敏语料待注入）
> 日期：2026-07-30
> 基线提交：`719158bb80786af853093759180e146ad6dd6daf`
> 分支：`codex/whisper-cpp-quality-phases-0-4`

## 1. 产品与架构边界

- ASR 后端固定为官方 `whisper.cpp` v1.9.1。
- Base 随包内置，Small 按需下载；会议开始后模型锁定。
- 官方 `ggml-silero-v6.2.0` VAD 是内置分段能力，不是第三个 ASR 模型。
- 事实 PCM 是唯一事实源，写盘先于预览；VAD/ASR 失败不得停止录音。
- 最终转录从完整 PCM 和全新 VAD 状态重跑，不读取预览文本。
- 当前 iOS 只做 arm64 无签名构建、产物审计和共享自动化测试，不执行真机测试。

仓库 `$grill-me` 入口仅转发到未提供的 `/grilling` 命令；本次以用户明确要求“完成阶段
0～4”作为范围批准，并把上述边界同步写入 PRD、技术方案和 `AGENTS.md`。

## 2. 工具链

| 项目 | 结果 |
|---|---|
| Flutter | 3.44.8 stable，revision `058e0af2c2` |
| Dart | 3.12.2 |
| Android SDK | 36.0.0，路径 `D:\AndroidSdk` |
| Android NDK | 28.2.13676358 |
| Java | Android Studio JBR 21.0.10 |
| Android 模拟器 | `emulator-5554`，x86_64，API 36 |
| Android 真机 | Mi 10，arm64，API 30（已发现，未纳入本轮模拟器验收） |

`flutter doctor -v` 另报告 Flutter/FVM PATH 指向提示和 Chrome 缺失；两者不影响当前
Android/Flutter 交付。系统 PATH 未直接暴露 `java`/`adb`，设备脚本应从 Flutter doctor
确认的 Android SDK 路径解析工具，不能假设全局命令可用。

## 3. 可复现基线

| 命令 | 结果 |
|---|---|
| `flutter pub get` | 通过 |
| `flutter analyze` | 通过，0 diagnostics |
| `flutter test` | 通过，356 tests |
| `flutter build apk --debug` | 通过，145.3 秒 |
| `tool/benchmarks/inspect_debug_apk.ps1` | 通过，报告写入忽略目录 `.spike/results/apk-inspection.json` |
| Base 模拟器集成测试 | 通过，真实 Native Assets 初始化/推理/释放 |
| 30 秒模拟器录音测试 | 通过，960,512 bytes，完整率 1.00036，0 个预览丢弃 |
| 端到端会议流 | 通过，真实 `Application`/`FTheme`、临时数据库、Base 最终快照 |
| Native context 生命周期 | 通过，连续 10 次创建/推理/幂等释放；首尾 RSS +11,051,008 bytes，后段趋于平台 |

首次 `flutter test` 因 Dart 下载 `sqlite3.x64.windows.dll` 时 TLS 握手中断而失败；
使用 PowerShell 系统证书访问相同官方 URL 后重试通过。该问题属于本机依赖缓存，不是源码
回归。

## 4. 已确认缺口

1. Native Assets 工具链把 `-Wl,-z,max-page-size=16384` 同时传入 `clang -c`，
   因而产生 `linker input unused` 警告；最终链接成功，但阶段 5 前必须把编译/链接参数
   分层并用 `llvm-readelf` 验证实际 LOAD alignment。
2. 模拟器首次录音会出现通知和麦克风权限弹窗；自动脚本必须在测试前显式授权 Debug 包，
   避免把交互等待误判为录音挂死。
3. 仓库外尚未配置不少于 20 段的真实去敏会议语料，因此 Base/Small 固定窗口质量基线、
   噪声幻觉下降和关键事实召回率暂时没有可声明的结果。
4. 阶段 0 无 VAD 基线中，Base 对 1 秒纯静音连续 10 次推理均产生片段；阶段 3
   已接入官方 Silero VAD，API 36 x86_64 的 3 秒纯静音返回 0 片段。

## 5. 评测输入契约

- 示例：`tool/benchmarks/whisper_corpus_manifest.example.json`
- 聚合器：`tool/benchmarks/whisper_quality_metrics.dart`
- 入口：`tool/benchmarks/run_whisper_quality_matrix.ps1`
- 音频只通过每段 `pathEnv` 指向仓库外文件。
- manifest 只保存 corpus/sample ID、去敏状态、SHA-256、时长、标签和关键事实。
- JSON/CSV 报告不得包含录音路径或录音内容。

## 6. Hard Gate 0

| 条件 | 状态 |
|---|---|
| 产品边界批准并统一 | 通过 |
| 工程基线可重复 | 通过 |
| 发布评估可阻断缺失 VAD/16 KB/证据项 | 通过 |
| 20 段真实去敏语料可运行 | `blocked` |
| 固定窗口 Base/Small 原始指标已生成 | `blocked` |

在真实语料注入前，不得把 Hard Gate 0 或质量指标标记为通过；后续实现可以继续，但发布
结论必须保持 `blocked`。

## 7. Android x86_64 模拟器交付

入口：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass `
  -File tool/benchmarks/run_android_emulator_smoke.ps1
```

脚本自动选择唯一的 x86_64 模拟器，也允许显式传入 `-DeviceId`；从 Flutter SDK 配置解析
`adb`，不依赖系统 PATH。每次真实录音测试安装前重新授予 `RECORD_AUDIO` 和 Android 13+
通知权限，避免 Flutter 集成测试卸载应用后丢失授权。

机器可读证据：

- `docs/quality/evidence/android-emulator/android-emulator-smoke.json`
- `docs/quality/evidence/android-emulator/logs/`

本次 API 36 x86_64 结果：

| 门槛 | 结果 |
|---|---|
| x86_64 Debug 构建 | 通过 |
| Base Native Assets 初始化、推理、释放 | 通过 |
| 30 秒真实麦克风 PCM | 960,512 bytes，完整率 1.00036，持久化比 1.0 |
| 预览故障注入 | `asr.preview.vad_failed`，事实 PCM 继续增长 |
| 最终快照 | `complete`，实际模型/版本与会议锁定 Base 一致 |
| Native context 10 次生命周期 | 通过；最后三次增量为 188,416 / 45,056 / 61,440 bytes，增长已收敛 |
| 事实 PCM 10 次开始/停止 | 通过，所有采集流关闭、checkpoint 均 finalized |

端到端会议测试通过 `PcmAudioCapture` 注入确定性 PCM，同时使用真实写盘、真实 SQLite、
真实 Base 推理与最终快照原子激活；真实麦克风完整率由独立 30 秒测试负责。两类证据分开，
避免把宿主麦克风的非确定输入当成转录正确性语料。

## 8. 会议启动失败诊断

`StartMeetingViewModel` 现在保留并显示稳定错误码与用户动作：

| 场景 | 错误码 | 动作 |
|---|---|---|
| 麦克风权限 | `meeting.start.microphone_permission` | 授权 |
| 空间不足 | `meeting.start.storage_insufficient` | 释放空间 |
| 标准模型不可用 | `meeting.start.standard_model_unavailable` | 重新安装 |
| 高级模型不可用 | `meeting.start.advanced_model_unavailable` | 下载/切换模型 |
| Native Assets 动态库不可用 | `asr.whisper.native_library_unavailable` | 重新安装 |
| Base context 创建失败 | `asr.whisper.context_create_failed` | 重试 |
| Engine 组装/初始化失败 | `meeting.start.asr_factory_failed` / `meeting.start.asr_initialization_failed` | 重试 |
| 会议持久化失败 | `meeting.start.persistence_failed` | 重试 |

Engine 初始化或会议持久化失败时会 best-effort 释放已创建 Engine，且不会留下半创建会议。
录音已开始后的预览故障仍只进入 `recordingOnly`，不会反向终止事实录音。

## 9. Hard Gate 1

| 条件 | 状态 |
|---|---|
| Android x86_64 会议闭环 | 通过 |
| 30 秒 PCM 完整率 `≥ 98%` | 通过 |
| 预览故障后 PCM 继续增长 | 通过 |
| 10 次 Native context 无持续增长 | 通过 |
| 10 次事实 PCM 开始/停止无采集流残留 | 通过 |
| 启动失败有稳定错误码和动作 | 通过 |
| 30 分钟 Android 真机录音 | 留待阶段 5，不属于本模拟器 Gate |

阶段 1 工程门槛通过；全局 Alpha 仍因 Hard Gate 0 的真实语料缺失保持 `blocked`。

阶段 2～4 的实施与门槛状态分别见 Step 22 和 Step 23～24；真实语料缺失仍会阻断候选
Profile 激活、噪声幻觉下降率和关键事实召回结论。

## 10. OCR 代码审查

按 workspace 模式审查全部 52 个 reviewable 文件；仅明确排除 Graphify 生成物、ffigen
生成绑定、官方 VAD 二进制和模拟器生成证据。审查发现并已修复：

- 连续语音在同一全局采样点重复运行 VAD；
- VAD isolate 在 ready 后极早退出时可能留下永久等待请求；
- 高级模型可能复用状态失败或完整性不匹配的 Base/VAD 安装记录；
- 固定窗口基线为零时错误声称噪声幻觉下降 100%；
- 单个解码 Profile 未完整覆盖语料时仍生成质量汇总；
- 模拟器详细指标只存在于不提交的日志，缺少机器可读证据。

修复后重新执行规则审查，未保留 Critical/High；有实际影响的 Medium 也已关闭。
