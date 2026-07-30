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
| `flutter test` | 通过，新增评测链后共 389 tests |
| `flutter build apk --debug` | 通过，145.3 秒 |
| `tool/benchmarks/inspect_debug_apk.ps1` | 通过，报告写入忽略目录 `.spike/results/apk-inspection.json` |
| Base 模拟器集成测试 | 通过，真实 Native Assets 初始化/推理/释放 |
| 30 秒模拟器录音测试 | 通过，960,512 bytes，完整率 1.00042，0 个预览丢弃 |
| 端到端会议流 | 通过，真实 `Application`/`FTheme`、临时数据库、Base 最终快照 |
| Native context 生命周期 | 通过，连续 100 次创建/推理/幂等释放；首尾 RSS +15,822,848 bytes，预热后 RSS +6,242,304 bytes |
| Small 模拟器原生冒烟 | 通过，固定 SHA-256 权重完成初始化、窗口推理和释放，67 秒 |

首次 `flutter test` 因 Dart 下载 `sqlite3.x64.windows.dll` 时 TLS 握手中断而失败；
使用 PowerShell 系统证书访问相同官方 URL 后重试通过。该问题属于本机依赖缓存，不是源码
回归。

## 4. 已确认缺口

1. Native Assets 的 `clang -c` 已不再接收 linker-only 参数，原有
   `linker input unused` 警告已消除；Release 16 KB LOAD alignment 仍属于阶段 5
   独立产物门槛，不能由“无警告”代替。
2. 模拟器首次录音会出现通知和麦克风权限弹窗；自动脚本必须在测试前显式授权 Debug 包，
   避免把交互等待误判为录音挂死。
3. 仓库外尚未配置不少于 20 段的真实去敏产品会议语料，因此 Base/Small 固定窗口质量
   基线、VAD 噪声幻觉下降和关键事实召回率暂时没有可声明的产品结果。
4. 阶段 0 无 VAD 基线中，Base 对 1 秒纯静音连续 10 次推理均产生片段；阶段 3
   已接入官方 Silero VAD，API 36 x86_64 的 3 秒纯静音返回 0 片段。

## 5. 评测输入契约

- 示例：`tool/benchmarks/whisper_corpus_manifest.example.json`
- 主机校验器：`tool/benchmarks/prepare_whisper_quality_corpus.dart`
- Android 执行器：`integration_test/android_whisper_quality_benchmark_test.dart`
- Android 编排入口：`tool/benchmarks/run_android_whisper_quality_benchmark.ps1`
- 聚合器：`tool/benchmarks/whisper_quality_metrics.dart`
- 已有原始观测的聚合入口：`tool/benchmarks/run_whisper_quality_matrix.ps1`
- 音频固定为无文件头的 16 kHz、单声道、PCM16LE，只通过每段 `pathEnv`
  指向仓库外或 `.spike/` 文件。
- corpus manifest schema 为 `2`，除 corpus/sample ID、去敏状态、SHA-256、时长、
  标签和关键事实外，还必须保存证据类别与来源/许可标识：
  - `product-meeting`：唯一可用于关闭正式产品质量门槛；
  - `public-regression`：公开数据集回归，不替代产品会议证据；
  - `synthetic-smoke`：合成链路烟测，不用于识别质量结论。
- 主机在推送前重新校验不少于 20 段、SHA-256、PCM 字节数和时长；设备临时目录在
  `finally` 中按受限路径清理。
- 原始观测携带 corpus ID、证据类别和 manifest SHA-256；聚合前必须与输入 manifest
  完全匹配。重用输出目录时先清除旧私有 transcript，避免残留正文混入新一轮证据。
- Base/Small 和选择的 Profile 默认同时执行 `fixed-window-v1` 与
  `vad-segmented-v1`。前者保留阶段 0 的固定 2 秒窗口对照，后者先以生产
  `WhisperVadSegmenter` 从完整 PCM 生成全局区间，再只识别语音区间。
- 原始观测和聚合报告 schema 为 `4`，每条观测必须携带 `pipelineId` 和实际 ASR
  调用次数；VAD 管线还必须携带检测语音段数与检测语音时长。聚合器只在
  相同设备、模型、版本和 Profile 内计算 VAD 相对固定窗口的噪声幻觉下降率与关键事实
  召回变化。固定窗口噪声幻觉为零时下降率保持 `null`，不得伪造 100% 改善。
- 设备端逐条输出原始观测，主机再把正文保存为 `.spike/` 下 transcript 引用。
- JSON/CSV 报告不得包含录音路径或录音内容。能耗、温控未采集时保持 `null` 并记录
  sample count 为 0，不得伪装成 `0 Wh` 或 `false`。
- `noise-only` 专用于没有语音的噪声样本；带背景噪声的正常语音使用其他标签，不能计入
  噪声幻觉分母。

### 5.1 公开回归轨道

- `tool/benchmarks/fetch_ascend_public_regression.dart` 只从 Hugging Face
  datasets-server 的 HTTPS 主机取得
  [ASCEND](https://huggingface.co/datasets/CAiRE/ASCEND/blob/main/README.md)
  元数据和音频，固定 revision
  `737e9800ae31be9932ba8464c80366559bd28424` 与 `CC-BY-SA-4.0`。
- 下载器拒绝非 16 kHz、单声道、16-bit PCM WAV；转换后的 PCM、manifest 和环境变量
  文件只写入被忽略的 `.spike/`。公开数据明确标记 `deidentified=false` 和
  `public-regression`，不得伪装成去敏产品会议。
- 2026-07-31 在 API 36 x86_64 模拟器以 Base、Baseline 和同一份 20 段
  中英自然短语音完成 schema 4 A/B。默认 `vad-segmented-v1` 有 12/20 段零语音
  检测、语音覆盖率 34.65%、空文本率 60%、完整参考句召回 0；评测候选
  `vad-recall-035-v1` 为 0/20 段零检测、覆盖率 97.71%、空文本率 0、完整参考句
  召回 15.79%。
- 同一语料、Profile 和 VAD 参数下完成 Small A/B：默认 VAD 仍有 12/20 段零检测，
  候选为 0/20 段零检测；候选的完整参考句召回由 Base 的 15.79% 增至 Small 的
  26.32%，但 Small 候选的模拟器 RTF P50 为 28.390、峰值 RSS 为
  1,010,302,976 bytes，Base 对应为 8.070 和 713,633,792 bytes。因此 Small
  继续只按需下载，不自动切换、不与 Base 混合输出。
- 该参考句召回采用归一化后的整句匹配，属于严格回归信号，不等同于产品会议关键事实
  召回。模拟器绝对 RTF 与延迟也不得用于真机发布承诺。

### 5.2 确定性非语音烟测轨道

- `tool/benchmarks/generate_synthetic_noise_corpus.dart` 确定性生成 20 段、每段默认
  3 秒的 PCM16LE：white noise、fan-like noise、50/60 Hz hum 和 impulsive
  clicks 各 5 档电平（-45、-35、-25、-18、-12 dBFS）。
- 生成器只允许写入仓库 `.spike/` 子目录；manifest 固定标记为
  `synthetic-smoke`、`deidentified=true` 和
  `generated:deterministic-nonspeech-v1`，每段保存 SHA-256。
- `tool/benchmarks/run_synthetic_noise_android_regression.ps1` 会生成语料、受控注入
  私有路径环境变量并执行 fixed-window、生产默认 VAD 和候选 VAD。该轨道验证非语音
  防线和报告口径，不能代替真实会议环境噪声。

### 5.3 阶段 0～4 自动发布评估

- `AlphaReleaseEvaluationInput` schema 已升级为 `4`，输出报告 schema 为 `2`；旧输入
  schema 或缺少新增字段时返回 `blocked`，不会沿用旧默认值。
- 正式质量门槛要求 `corpus.evidenceClass=product-meeting`，并校验 manifest
  SHA-256、来源和授权标识。`public-regression` 与 `synthetic-smoke` 会明确失败，
  不能拼装成 `go`。
- 评估器显式比较 Base VAD 相对固定窗口、Small 相对 Base 的关键事实召回，并要求
  20 个 Preview 延迟样本、语音首尾事实全部保留，以及 ASR/VAD 百次生命周期、事实
  PCM、模型锁定、预览丢弃、最终时间戳、快照原子性和总结事实源等阶段 0～4 不变量。
- 当前机器可读输入和报告位于
  `docs/quality/evidence/android-emulator/phase-0-4-release-input.json` 与
  `phase-0-4-release-report.json`。结果为 `blocked`：21 项通过、0 项失败、35 项
  缺失；缺失项保留真实产品语料、产品质量指标和后续平台门禁，不以代理数据填充。

## 6. Hard Gate 0

| 条件 | 状态 |
|---|---|
| 产品边界批准并统一 | 通过 |
| 工程基线可重复 | 通过 |
| 发布评估可阻断缺失 VAD/16 KB/证据项 | 通过：schema 4 另显式阻断代理语料和阶段 0～4 不变量缺失 |
| Android 外部语料执行链 | 通过：x86_64 编译、安装与缺参跳过检查已完成 |
| 20 段真实去敏产品会议语料可运行 | `blocked`：未提供语料环境变量 |
| 固定窗口 Base/Small 原始指标已生成 | `blocked`：未提供真实语料 |
| 固定窗口与 VAD 分段可同条件比较 | 通过：多管线 Android 执行、schema 4 可观测性及聚合链已实现 |

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
| Small Native Assets 初始化、推理、释放 | 通过；本机忽略目录权重，未进入 APK |
| 30 秒真实麦克风 PCM | 960,512 bytes，完整率 1.00042，持久化比 1.0 |
| 预览故障注入 | `asr.preview.vad_failed`，事实 PCM 继续增长 |
| 最终快照 | `complete`，实际模型/版本与会议锁定 Base 一致 |
| Native context 100 次生命周期 | 通过；第 10→100 次 RSS +6,242,304 bytes，小于 32 MiB 上限 |
| 事实 PCM 100 次开始/停止 | 通过，所有采集流关闭、checkpoint 均 finalized |

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
| 不少于 10 次 Native context 无持续增长 | 通过，实际 100 次 |
| 不少于 10 次事实 PCM 开始/停止无采集流残留 | 通过，实际 100 次 |
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

2026-07-31 对新增 Android 外部语料执行链再次按 workspace 模式审查 9 个 reviewable
文件，并手工覆盖 PowerShell、integration test 和指标语义。审查中已修正：

- 能耗/温控缺测被错误折算为 `0`/`false`；
- transcript/evidence 引用可写入绝对路径，以及私有输出目录可越出 `.spike/`；
- `emittedText` 非布尔输入被静默折算为 `false`；
- 句后延迟只统计原生解码、漏掉 isolate 往返；
- RSS 只读取推理前后瞬时值，可能漏掉推理期间峰值；
- 仅由标点组成的关键事实会因归一化为空串而被误报为召回。

修复后目标测试、静态分析与 API 36 x86_64 编译/安装检查通过；本轮未发现或保留
Critical/High。

随后使用 Windows PowerShell 5.1 执行 Small 模拟器验证时又发现并修复两项脚本缺陷：

- UTF-8 无 BOM 的中文 `.ps1` 在 Windows PowerShell 5.1 下可能被本地代码页破坏；
  benchmark PowerShell 脚本现保持 ASCII 兼容并逐个通过 PS5 parser。
- 旧脚本把 Small 复制进应用私有目录，但 `flutter test` 重装应用会删除它，且
  `run-as` 清理会掩盖原始结果；现改为受限 `/data/local/tmp` 只读临时目录，
  校验路径后清理，清理错误不覆盖测试退出码。

修复后的 `run_android_whisper_validation.ps1 -ModelFilter small` 已在 API 36 x86_64
模拟器通过。

2026-07-31 对固定窗口/VAD 双管线与证据分级再次审查全部 9 个 reviewable 文件。首轮
发现并修复：

- raw observations 未绑定 corpus manifest，可能把同名 sample 错接到另一份语料；
- 重用输出目录时保留旧私有 transcript，可能造成正文残留；
- Android 评测预加载全部 PCM，长语料矩阵会不必要地抬高内存；
- 普通 `noise` 标签可能把“语音 + 背景噪声”误算为幻觉；
- 固定窗口与 VAD 句后延迟漏算窗口等待或稳定裕量。

修复后 raw observations 和 run evidence 均携带 corpus ID、证据类别与 manifest
SHA-256；旧 transcript 在受限 `.spike` 输出目录内清除，噪声幻觉只统计
`noise-only`。第二轮规则审查未发现或保留 Critical/High 或有实际影响的 Medium。

确定性非语音轨道完成后，再按 workspace 模式审查生成器、单测和 Android wrapper
三个 reviewable 文件；OCR 不支持的四个 Markdown 变更由主审手工核对。审查补强了
`.spike/` 写入边界、私有输入契约和实际 PCM 峰值的自动化覆盖，复审未发现或保留
Critical/High 或有实际影响的 Medium。

自动发布评估 schema 4 完成后，按 workspace 模式审查 6 个 reviewable 文件并手工
核对三份 Markdown。审查发现直接 Domain 调用传入非有限召回值时，No-Go 报告可能因
JSON 不支持 `NaN/Infinity` 而无法输出；现已净化报告值并新增回归测试。复审未发现
或保留 Critical/High 或有实际影响的 Medium。
