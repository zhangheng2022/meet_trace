# Codex 实施计划：whisper.cpp 质量强化与双平台交付

> 状态：执行中（阶段 0～4 工程实现完成；真实语料质量门槛阻断）
> 基线分支：`dev`
> 计划日期：2026-07-30
> 预计工作量：13～18 个工程日，另需 Android 真机和 macOS/Xcode 可用时间
> 首个可运行交付点：Android x86_64 模拟器会议闭环

## 1. 交付目标

在不更换当前官方 C++ `whisper.cpp` 后端的前提下，完成：

1. 会议启动和 16 kHz 单声道 PCM16 事实音频可靠性闭环。
2. Base/Small 两个模型的可复现解码 Profile。
3. 官方 Silero VAD 的 Native Assets、C ABI 和 Dart 异步适配。
4. VAD 驱动的会中预览，以及从完整事实 PCM 重跑的最终转录。
5. Android Release 16 KB、最低系统、低端性能和主力设备验收。
6. iOS arm64 编译、产物审计和自动化验证；本阶段不执行 iOS 真机测试。
7. 自动发布评估、OCR 审查、Graphify 更新和 `dev` 合并门禁。

除阶段 0 的边界与基线准备外，所有应用实现首先以 Android x86_64 模拟器为目标。
模拟器闭环未通过前，不进入 VAD 调优、Android 真机或 iOS 构建。

完成后仍保持：

- 本地事实 PCM 是唯一事实源。
- 录音写入先于预览投递，VAD/ASR 不得运行在写盘路径。
- 预览任务可以丢弃，事实录音不能丢失。
- 会议开始后模型锁定；不自动切换模型，不混合 Base/Small 输出。
- 最终转录只读取完整事实 PCM，不读取会中预览文本。
- 最终快照完整写入并校验后才原子激活。
- AI 总结只读取已激活的最终快照。

## 2. 明确不做

- 不引入 Rust、`whisper-rs`、`flutter_rust_bridge` 或 `whisper_ggml`。
- 不恢复 sherpa-onnx、Paraformer、Qwen3-ASR 或旧 ONNX/Silero 链。
- 不在 UI、ViewModel 或 Domain 中暴露 C++、FFI、Native Assets 或模型文件细节。
- 不把内部解码参数开放为用户设置。
- 不提交录音、评测音频、下载的 Small/VAD 临时文件、构建产物或原始设备序列号。
- 不在 Android 结果通过后推定 iOS 已通过。
- 不执行 iPhone/iPad 真机测试，不把 iOS 构建通过表述为后台录音、系统中断、
  性能、温控或端侧识别质量已通过。

## 3. Codex 执行协议

### 3.1 隔离工作区

执行阶段 0 前：

```powershell
git status --short
git worktree list --porcelain
```

使用 `using-git-worktrees` 技能创建隔离分支，建议：

```text
分支：codex/whisper-cpp-quality-delivery
目录：.worktrees/codex-whisper-cpp-quality-delivery
```

若分支或目录已存在，先检查并复用，不删除、不覆盖。主 `dev` 工作区的既有脏文件属于用户，
不得移动、暂存或清理。

### 3.2 每个任务的固定循环

每个行为变更都按以下顺序执行：

1. 写失败的单元测试、组件测试或集成测试。
2. 运行目标测试，确认失败原因与需求一致。
3. 实现最小完整行为。
4. 运行目标测试、相关回归测试和 `flutter analyze`。
5. 使用 `$open-code-review-delegate` 审查本任务全部可审查文件。
6. 修复全部 Critical/High 和有实际影响的 Medium。
7. 在 `docs/quality/` 写阶段证据，包含命令、设备、指标和未完成项。
8. 运行 `graphify update .`，但不得把无关 Graphify 噪声混入源码提交。
9. 提交一个中文祈使语气 commit。

### 3.3 每个阶段的统一验证

```powershell
dart format lib test integration_test
flutter analyze
flutter test
git diff --check
```

修改 `packages/meettrace_whisper_native/`、Android/iOS、构建配置或
`integration_test/` 时，必须额外完成对应原生构建和 OCR 审查。

### 3.4 停止条件

出现任一情况，停止进入下一阶段：

- 事实录音不完整，或 VAD/ASR 阻塞事实 PCM 写盘。
- 会议中模型发生自动切换或混合输出。
- 最终快照不是原子激活，或最终结果依赖预览文本。
- 需要私有 fork、手写 JNI、手工复制 `.so` 才能继续。
- 已覆盖平台的原生生命周期存在崩溃或持续泄漏。
- 阶段 OCR 仍有 Critical/High。
- 目标阶段规定的真机、质量或构建门槛未通过。

### 3.5 首个交付点的验证边界

Android 模拟器用于尽早打通功能链：

- x86_64 Native Assets 能构建、加载和释放；
- 内置 Base 模型能初始化；
- 应用能创建会议、开始/停止录音并生成事实 PCM；
- 预览失败时录音继续，停止后能创建最终快照；
- 启动失败能显示稳定错误码，而不是笼统的“无法开始会议”。

模拟器不用于验收麦克风音质、RTF、句后延迟、RSS、能耗、温控、锁屏/后台可靠性
或 16 KB arm64 产物；这些仍在 Android 真机阶段验证。

---

## 阶段 0：边界、基线和评测工具

### Task 0.1：冻结工作树和现有证据

**读取：**

- `AGENTS.md`
- `docs/会迹_MeetTrace_Alpha_PRD_无登录版.md`
- `docs/端侧双模型转录技术方案.md`
- `docs/quality/Step_20_whisper.cpp_正式替换.md`
- `lib/domain/use_cases/evaluate_alpha_release.dart`
- `tool/benchmarks/alpha_release_input.example.json`

**步骤：**

1. 记录 `git rev-parse HEAD`、Flutter/Dart、Android SDK/NDK、Java 和连接设备。
2. 运行现有基线：

   ```powershell
   flutter pub get
   flutter analyze
   flutter test
   flutter build apk --debug
   powershell -ExecutionPolicy Bypass -File tool/benchmarks/inspect_debug_apk.ps1
   ```

3. 将结果写入 `docs/quality/Step_21_C++_质量交付基线.md`。
4. 不修改源码，不用旧 sherpa 或 Rust 证据替代当前 C++ 证据。

**通过条件：**

- 静态分析、全量测试和 Android Debug APK 基线可重复。
- APK 中存在三 ABI `libmeettrace_whisper.so` 和 Base，且没有 Small、sherpa、ONNX。
- 任何失败都已记录真实日志，不以缓存 APK 代替本次构建。

### Task 0.2：统一产品和仓库约束

**修改：**

- `AGENTS.md`
- `docs/会迹_MeetTrace_Alpha_PRD_无登录版.md`
- `docs/端侧双模型转录技术方案.md`
- `docs/README.md`

**步骤：**

1. 在变更 P0 和验收标准前运行 `$grill-me`。
2. 若技能不可用，停止产品边界修改，向用户报告并取得明确替代授权。
3. 明确正式 ASR 后端为官方 `whisper.cpp`，Base 内置、Small 按需下载。
4. 明确官方 Silero VAD 是可失败的分段能力，不是第三个 ASR 模型。
5. 新增验收项：
   - 纯静音不产生转录；
   - 噪声幻觉相对固定窗口基线至少下降 80%；
   - 不同 PCM chunk 边界产生相同最终 VAD 区间；
   - VAD 失败只降级预览，事实录音完整率仍为 100%。
6. 保持“默认模型文件不可用时阻止开始”和“录音开始后 ASR 失败继续录音”的边界，
   不在本计划中静默改变 AT-14/AT-15。

**通过条件：**

- `AGENTS.md`、PRD、技术方案和当前 `dev` 实现不再互相冲突。
- 新增 VAD 范围、降级语义和质量门槛获得明确批准。

### Task 0.3：扩展自动发布评估

**修改：**

- `lib/domain/use_cases/evaluate_alpha_release.dart`
- `test/domain/use_cases/evaluate_alpha_release_test.dart`
- `tool/benchmarks/alpha_release_input.example.json`
- `tool/benchmarks/evaluate_alpha_release.dart`

**步骤：**

1. 先写失败测试，覆盖缺失、失败和通过三种结果：
   - 静音样本数和静音误识别数；
   - 噪声样本数和噪声幻觉率；
   - VAD chunk-boundary 一致性；
   - Android 16 KB 检查；
   - Android/iOS 分平台证据引用。
2. 运行：

   ```powershell
   flutter test test/domain/use_cases/evaluate_alpha_release_test.dart
   ```

3. 扩展输入 schema，旧 schema 缺少新字段时返回 `blocked`，不得默认通过。
4. 更新示例输入和 CLI JSON 输出。
5. 再运行目标测试和全量测试。

**通过条件：**

- 所有发布门槛都能明确输出 `passed`、`failed` 或 `missing`。
- `missing` 不被折算成 `passed`。

### Task 0.4：建立去敏语料和质量矩阵

**新增/修改：**

- `tool/benchmarks/run_whisper_quality_matrix.ps1`
- `tool/benchmarks/whisper_quality_metrics.dart`
- `test/tool/benchmarks/whisper_quality_metrics_test.dart`
- `docs/quality/Step_21_C++_质量交付基线.md`

**步骤：**

1. 定义不少于 20 段语料的 manifest，只保存：
   - corpus ID；
   - 去敏状态；
   - SHA-256；
   - 时长；
   - 语言/噪声/远场标签；
   - 关键事实标注；
   - 本地路径环境变量名。
2. 音频文件存放在仓库外或已忽略的 `.spike/`，不得提交。
3. 质量脚本必须输出 JSON/CSV：
   - 原始文本和时间戳的本地引用；
   - RTF；
   - 句后延迟；
   - 关键事实召回率；
   - 空文本率；
   - 静音/噪声幻觉；
   - 峰值 RSS、能耗和温控引用。
4. 用现有固定 2 秒窗口分别跑 Base/Small，作为后续唯一对照组。

**阶段 0 审查：**

- 范围：阶段 0 全部文档、发布评估代码和 benchmark 工具。
- 报告：`docs/quality/Step_21_C++_质量交付基线.md`。
- 建议提交：

  ```text
  批准 C++ Whisper 质量交付边界
  建立 Whisper 质量评测基线
  ```

**Hard Gate 0：**

- 产品边界已批准。
- 20 段语料可运行且未提交音频。
- 当前固定窗口 Base/Small 指标已生成。
- 发布评估器能阻断缺失证据。

---

## 阶段 1：Android 模拟器会议闭环与事实 PCM

### Task 1.0：启动 x86_64 模拟器并打通最小闭环

**验证/新增：**

- `packages/meettrace_whisper_native/hook/build.dart`
- `integration_test/whisper_base_standard_asr_engine_test.dart`
- `integration_test/reliable_recording_test.dart`
- `integration_test/android_emulator_meeting_flow_test.dart`
- `tool/benchmarks/run_android_emulator_smoke.ps1`

**环境：**

- Android x86_64 模拟器，API 24 或更高；
- 至少 4 GB 模拟器 RAM、8 GB 可用宿主磁盘；
- 模拟器已授予麦克风权限；
- 首轮只使用随包内置的 Whisper Base，不下载 Small。

**步骤：**

1. 枚举并启动模拟器，不在脚本中写死设备 ID：

   ```powershell
   flutter emulators
   flutter emulators --launch <emulator-id>
   flutter devices
   ```

2. 构建并启动 x86_64 Debug 应用：

   ```powershell
   flutter build apk --debug --target-platform android-x64
   flutter run -d <emulator-device-id>
   ```

3. 运行现有原生 Base 和事实录音测试：

   ```powershell
   flutter test integration_test/whisper_base_standard_asr_engine_test.dart `
     -d <emulator-device-id>
   flutter test integration_test/reliable_recording_test.dart `
     -d <emulator-device-id> `
     --dart-define=MEETTRACE_RECORDING_SECONDS=30
   ```

4. 先新增失败的 `android_emulator_meeting_flow_test.dart`，再实现到通过。测试必须：
   - 使用真实 `Application`/`FTheme` 外壳；
   - 选择内置 Base；
   - 创建会议并开始录音；
   - 验证事实 PCM 字节持续增长；
   - 注入预览失败并确认录音继续；
   - 停止会议并等待最终快照进入终态；
   - 校验所有 Native context、stream subscription 和数据库句柄释放。
5. 新增 `run_android_emulator_smoke.ps1`，按顺序执行设备预检、x86_64 构建、
   两个现有集成测试和会议流测试，并把机器可读结果写入
   `docs/quality/evidence/android-emulator/`。
6. 连续执行 10 次开始/停止。宿主麦克风只做冒烟；确定性转录测试读取阶段 0
   仓库外去敏 PCM，通过测试依赖注入进入 `PcmAudioCapture`，不得增加生产环境开关。

**通过条件：**

- APK 中存在 x86_64 `libmeettrace_whisper.so`，Base 可初始化并正常释放。
- 模拟器上可以开始/停止会议，不再出现无法定位原因的“无法开始会议”。
- 30 秒事实 PCM 完整率 `≥ 98%`，预览故障不影响写盘。
- 连续 10 次开始/停止无残留会议、租约、context 或 stream。
- 最终快照来自事实 PCM，且模型 ID/版本与会议锁定值一致。

失败时停在本任务，不进入解码 Profile、VAD、Android 真机或 iOS。

### Task 1.1：增加 PCM 输入诊断

**修改/新增：**

- `lib/data/services/audio/record_pcm_audio_capture.dart`
- `lib/data/services/audio/recording_ports.dart`
- `lib/data/services/audio/recording_pcm_diagnostics.dart`
- `test/data/services/audio/record_pcm_audio_capture_test.dart`
- `test/data/services/audio/recording_pcm_diagnostics_test.dart`
- `integration_test/reliable_recording_test.dart`

**步骤：**

1. 先写失败测试，覆盖：
   - 16 kHz、单声道、PCM16、小端序；
   - 奇数字节和空块；
   - chunk 起始 offset 连续；
   - 削波率、RMS、峰值、DC 偏移；
   - 实际字节数与录音持续时间一致。
2. 诊断只保存统计值，不保存或上传音频内容。
3. 保持 `ReliableRecordingService` 的顺序：
   `write → flush → checkpoint → preview.offer`。
4. 不在 `RecordPcmAudioCapture` 中调用 VAD 或 Whisper。

**目标验证：**

```powershell
flutter test test/data/services/audio/record_pcm_audio_capture_test.dart
flutter test test/data/services/audio/recording_pcm_diagnostics_test.dart
   flutter test integration_test/reliable_recording_test.dart -d <emulator-device-id>
```

### Task 1.2：修复会议启动失败链

**修改/验证：**

- `lib/domain/use_cases/check_meeting_readiness.dart`
- `lib/domain/use_cases/start_meeting.dart`
- `lib/ui/features/meetings/view_models/start/start_meeting_view_model.dart`
- `lib/app/meettrace_dependencies.dart`
- `packages/meettrace_whisper_native/lib/src/c_library.dart`
- 对应的 Domain、ViewModel 和 Native boundary 测试

**步骤：**

1. 为以下失败分别写测试和错误码：
   - 麦克风权限；
   - 存储空间；
   - 默认模型缺失/校验失败；
   - Native Assets 动态库不可用；
   - Base context 创建失败；
   - 会议持久化失败。
2. 禁止把所有异常折叠为一个不可诊断的“无法开始会议”。
3. Engine 初始化失败时不得留下半创建会议、租约或未释放 context。
4. 会议和录音已经开始后，ASR 失败必须进入仅录音状态，不得结束录音。
5. Android 模拟器连续执行 10 次开始/停止；真机 20 次留到阶段 5。

**Hard Gate 1：**

- Android 模拟器连续开始/停止 10 次无失败或资源残留。
- 30 秒 PCM 完整率 `≥ 98%`，并保留 30 分钟真机验收项。
- 注入 ASR 初始化后故障、推理崩溃和预览积压，事实 PCM 仍完整。
- 失败状态有稳定错误码和用户可执行动作。

**阶段 1 审查与提交：**

```text
打通 Android 模拟器 Whisper 会议闭环
增加事实 PCM 输入诊断
修复 Whisper 会议启动失败链
完成 C++ 质量阶段一审查
```

---

## 阶段 2：版本化 C ABI 与解码 Profile

### Task 2.1：定义稳定配置

**修改：**

- `packages/meettrace_whisper_native/src/meettrace_whisper.h`
- `packages/meettrace_whisper_native/src/meettrace_whisper.cpp`
- `packages/meettrace_whisper_native/lib/src/whisper_native_context.dart`
- `packages/meettrace_whisper_native/lib/src/third_party/meettrace_whisper.g.dart`
- `lib/data/services/asr/whisper/whisper_adapter.dart`
- `test/data/services/asr/whisper/whisper_cpp_boundary_test.dart`
- `test/data/services/asr/whisper/whisper_adapter_test.dart`

**步骤：**

1. 先写 boundary 测试，要求 C API 暴露：
   - ABI 版本；
   - `struct_size`；
   - versioned config；
   - 无效枚举/范围返回稳定错误；
   - 旧缓存原生库的 ABI 不匹配可诊断。
2. 增加 `mt_whisper_config_v1`，包含内部可评测参数：
   - thread count；
   - language；
   - Greedy/Beam；
   - best-of/beam-size；
   - no-context；
   - suppress-blank；
   - temperature fallback；
   - initial prompt。
3. 应用层只暴露不可变 `WhisperRecognizerConfig`，不把 `whisper_full_params`
   或 FFI 指针泄漏到 Domain/UI。
4. 重新生成绑定：

   ```powershell
   Push-Location packages/meettrace_whisper_native
   dart pub get
   dart run tool/ffigen.dart
   Pop-Location
   ```

5. 生成文件只由 codegen 修改，不手工编辑。

### Task 2.2：选择 Preview/Final Profile

**修改/新增：**

- `lib/data/services/asr/whisper/whisper_recognizer_profiles.dart`
- `test/data/services/asr/whisper/whisper_recognizer_profiles_test.dart`
- `tool/benchmarks/run_whisper_quality_matrix.ps1`
- `docs/quality/Step_22_Whisper_解码参数评测.md`

**步骤：**

1. 定义内部 `preview` 和 `final` Profile；用户设置仍只选择 Base/Small。
2. 在相同设备、相同模型、相同语料上比较参数矩阵。
3. 只接受有原始指标支撑的配置。
4. 将 Profile ID 和配置摘要写入诊断与质量报告。

**Hard Gate 2：**

- Base 关键事实召回率不低于固定窗口基线。
- Small 关键事实召回率不低于 Base。
- Preview 句后延迟 P95 `≤ 3 秒`。
- 取消和 dispose 幂等；100 次 context 生命周期无崩溃，且第 10→100 次 RSS
  增长小于 32 MiB。

**阶段 2 审查与提交：**

```text
增加版本化 Whisper 原生配置
确定 Whisper 预览与最终解码配置
完成 C++ 质量阶段二审查
```

---

## 阶段 3：官方 Silero VAD

### Task 3.1：固定 VAD 资产

**修改：**

- `assets/models/manifest.json`
- `assets/licenses/`
- `pubspec.yaml`
- `tool/benchmarks/download_whisper_models.ps1`
- `tool/benchmarks/inspect_debug_apk.ps1`
- 资产、manifest 和 APK 审计测试

**步骤：**

1. 固定官方 VAD 仓库 revision、文件名、字节数、SHA-256 和许可。
2. VAD 随 Base 一起内置；Small 仍不得进入安装包。
3. 更新 APK 审计：
   - 允许且要求批准的 VAD 文件；
   - 继续禁止旧 sherpa Silero、ONNX、Small 和用户数据；
   - 不使用宽泛 `silero` 正则误杀批准资产。
4. VAD 校验失败时标记 ASR 不可用，但不得破坏录音准备。

### Task 3.2：新增原生 VAD C ABI

**修改：**

- `packages/meettrace_whisper_native/src/meettrace_whisper.h`
- `packages/meettrace_whisper_native/src/meettrace_whisper.cpp`
- `packages/meettrace_whisper_native/lib/src/whisper_vad_native_context.dart`
- 生成绑定和 boundary 测试

**C ABI 最小能力：**

- create；
- accept/detect；
- segment count/start/end；
- flush；
- reset；
- cancel；
- last error；
- destroy。

**步骤：**

1. 先写 ABI、无效输入、取消和释放测试。
2. 使用当前固定 `whisper.cpp` 已包含的官方 VAD API，不复制或修改上游实现。
3. 所有时间先以 sample index 表达，在 Dart 边界转换为全局毫秒。
4. context/state 所有权只留在 package 内。
5. 重新运行 `ffigen` 并检查生成 diff。

### Task 3.3：实现异步 VAD Adapter

**修改/新增：**

- `lib/data/services/vad/voice_activity_segmenter.dart`
- `lib/data/services/vad/whisper/whisper_vad_adapter.dart`
- `lib/data/services/vad/whisper/whisper_vad_segmenter.dart`
- `test/data/services/vad/whisper_vad_segmenter_test.dart`
- `integration_test/whisper_vad_mobile_test.dart`

**步骤：**

1. 将 `accept/flush/dispose` 改为异步契约。
2. VAD context 在专用 worker isolate 中运行，不在 UI isolate 或事实写盘链执行。
3. 保留滚动未决尾段，只提交已有足够尾随静音确认的区间。
4. `reset(nextStartSample)` 后所有区间仍使用会议全局 sample index。
5. VAD 失败、队列超限或 worker 崩溃时返回结构化错误，由预览链进入仅录音状态。

**Hard Gate 3：**

- 纯静音不产生语音区间或文本。
- 噪声幻觉相对阶段 0 至少下降 80%。
- 不同输入 chunk 大小产生相同最终 VAD 区间。
- 语音首尾不丢失已标注关键事实。
- 100 次 create/detect/cancel/destroy 无崩溃和持续泄漏。

**阶段 3 审查与提交：**

```text
接入官方 Whisper Silero VAD
增加异步 Whisper VAD 分段器
完成 C++ 质量阶段三审查
```

---

## 阶段 4：预览、最终转录与快照

### Task 4.1：接入会中预览

**修改：**

- `lib/data/services/asr/asr_preview_coordinator.dart`
- `lib/data/services/audio/recording_ports.dart`
- `lib/app/meettrace_dependency_factories.dart`
- `test/data/services/asr/asr_preview_coordinator_test.dart`
- `test/data/services/audio/reliable_recording_service_test.dart`

**步骤：**

1. 先把现有同步 VAD 测试改为异步，并确认失败。
2. 将固定 `StreamingWindowSegmenter` 替换为 `WhisperVadSegmenter`。
3. 保持独立水位：
   - 事实写盘队列不可丢；
   - preview dispatcher 可丢 PCM 副本；
   - ASR 窗口队列可丢最旧预览任务。
4. 超过 15 秒的语音区间继续通过 `AsrPreviewWindowPlanner` 重叠切分。
5. 保持全局时间戳、确定性修订和去重语义。

### Task 4.2：最终转录使用相同 VAD 语义

**修改：**

- `lib/data/services/asr/whisper/whisper_asr_engine.dart`
- `lib/data/services/asr/whisper_asr_engine_factory.dart`
- `lib/domain/use_cases/run_final_transcription.dart`
- `test/data/services/asr/final_transcription_service_test.dart`
- Base/Small Engine 测试

**步骤：**

1. 最终转录重新打开完整事实 PCM，从 sample 0 创建全新 VAD 状态。
2. 不复用会中 VAD 状态、预览文本或已丢弃窗口。
3. 使用本场锁定模型和 `final` Profile。
4. 静音会议生成零片段的完整快照。
5. 新快照保存和校验完成后调用 `saveFinalAndActivate`。
6. 失败、取消、崩溃和显式重试均保留旧活动快照。

**Hard Gate 4：**

- 相同 PCM 不同 chunk 方式得到相同最终片段和排序。
- 预览丢弃不改变最终结果。
- 时间戳无负值、越界、交叉或倒退。
- 注入数据库失败时旧快照仍激活。
- AI 总结测试证明只读取最终激活快照。

**阶段 4 审查与提交：**

```text
接入 VAD 驱动的 Whisper 实时预览
统一 Whisper 最终转录分段语义
完成 C++ 质量阶段四审查
```

---

## 阶段 5：Android 交付门禁

进入本阶段前必须重新运行阶段 1 的 Android 模拟器脚本；模拟器回归失败时不得开始
真机性能和质量验收。

### Task 5.1：构建和 APK 审计

**修改/新增：**

- `packages/meettrace_whisper_native/hook/build.dart`
- `tool/benchmarks/inspect_debug_apk.ps1`
- `tool/benchmarks/check_android_16kb.ps1`
- 对应脚本和构建边界测试

**步骤：**

1. 将 `-Wl,-z,max-page-size=16384` 只传给链接阶段，不传给 `clang -c`。
2. 构建 Debug 和 Release：

   ```powershell
   flutter build apk --debug
   flutter build apk --release
   ```

3. `check_android_16kb.ps1` 使用 NDK `llvm-readelf -lW` 检查 APK 内每个 `.so`
   的 LOAD segment alignment。
4. 临时解压目录必须由脚本创建、验证位于系统临时目录后再清理。
5. 审计 Base、VAD、Small、旧原生库、许可证、密钥和用户数据。

### Task 5.2：三档 Android 真机

**设备：**

- Mi 10 主力开发机；
- API 24 arm64 最低系统设备；
- 4 GB RAM 低端 arm64 设备。

**命令入口：**

```powershell
powershell -ExecutionPolicy Bypass -File `
  tool/benchmarks/run_android_whisper_validation.ps1 `
  -DeviceId <device-id>
```

扩展脚本以执行：

- Base/Small/VAD 初始化和识别；
- 连续 20 次开始/停止；
- 30 分钟前台、锁屏、后台录音；
- VAD/ASR 积压；
- 取消、释放和重复创建；
- 20 段相同语料质量矩阵；
- RTF、延迟、RSS、能耗和温控采集。

**Hard Gate 5：**

- Release APK 全部 `.so` 通过 16 KB。
- 标准模型 RTF P95 `< 0.5`。
- 句后出字 P95 `≤ 3000 ms`。
- 30 分钟最终转录 `≤ 5 分钟`。
- 关键事实召回率 `≥ 85%`。
- 录音完整率 100%。
- 无持续 Severe/Critical 温控。
- OCR 无 Critical/High。

**阶段 5 报告：**

- `docs/quality/Step_25_Android_Whisper_质量验收.md`
- 更新 `docs/quality/Android_Alpha_设备矩阵.md`

---

## 阶段 6：iOS 构建门禁（无真机）

### Task 6.1：arm64 构建与产物审计

**前置：**

- macOS/Xcode；
- 可解析的 iOS 工程依赖；
- 无签名构建不要求 Apple Team 或连接设备。

**步骤：**

```bash
flutter pub get
flutter build ios --debug --no-codesign
flutter analyze
flutter test
```

检查：

- Base 和批准的 VAD 进入安装包；
- Small、sherpa、ONNX、录音和数据库不进入安装包；
- Native Assets 为 arm64；
- NOTICE、隐私清单和权限用途完整。

### Task 6.2：自动化与可选模拟器冒烟

**自动化验证：**

- C ABI 配置、取消、释放和错误映射由 host/unit test 覆盖；
- Flutter 层模型锁定、队列背压、最终快照和 VAD 降级测试通过；
- 检查 `Info.plist`、后台音频模式、隐私清单、最低系统版本和目标架构；
- 可运行模拟器时，仅验证应用启动、页面流转和非麦克风依赖的状态机。

**限制：**

- 不执行 iPhone/iPad 真机测试。
- 不验证或声称 iOS 后台/锁屏录音、来电/Siri/耳机中断、真机内存、
  能耗、温控、RTF、出字延迟或识别质量已通过。
- 模拟器结果不能替代真机结果；在报告和发布说明中将这些项目标为
  `not_tested`，不得填充推测值。

**Hard Gate 6：**

- iOS arm64 无签名构建通过。
- 产物只包含批准的模型、VAD 和原生库，隐私与权限配置完整。
- 共享 Dart/FFI 自动化测试通过。
- 所有未执行的 iOS 真机项目明确记录为 `not_tested`。
- OCR 无 Critical/High。

**阶段 6 报告：**

- `docs/quality/Step_26_iOS_Whisper_构建验收.md`
- 更新 `docs/quality/iOS_Alpha_设备矩阵.md`，将真机列标记为 `not_tested`

---

## 阶段 7：最终发布审查与合并

### Task 7.1：全量验证

```powershell
dart format lib test integration_test
flutter analyze
flutter test
flutter build apk --debug
flutter build apk --release
powershell -ExecutionPolicy Bypass -File tool/benchmarks/inspect_debug_apk.ps1
powershell -ExecutionPolicy Bypass -File tool/benchmarks/check_android_16kb.ps1
dart run tool/benchmarks/evaluate_alpha_release.dart `
  --input <release-input.json> `
  --output <release-report.json>
git diff --check
```

在 macOS 追加：

```bash
flutter build ios --debug --no-codesign
```

### Task 7.2：最终 OCR

使用 `$open-code-review-delegate`：

- 模式：从分支起点到 HEAD 的 range/commit 审查；
- 背景：PRD、事实 PCM、模型锁定、VAD 降级、最终快照、Android 真机门禁和
  iOS 无真机构建边界；
- 只排除明确生成的 FFI glue、构建产物和 Graphify 产物；
- 手工补审 OCR 默认排除但属于自有逻辑的脚本、C/C++ header 和平台配置；
- Critical/High 必须清零；
- 保留 Medium 必须记录风险、理由和后续动作。

### Task 7.3：交付材料

必须具备：

- Android Debug/Release 构建和 APK/AAB；
- Android 16 KB 报告；
- iOS Debug 无签名构建与产物审计报告；
- Base/Small/VAD 资产清单；
- Android 同语料原始指标引用；
- iOS 真机能力与质量项的 `not_tested` 清单；
- AT-01～新增 VAD 验收项的证据；
- 自动发布评估结果为 `go`；
- 最终 OCR 报告；
- 更新后的 PRD、技术方案、设备矩阵和 `docs/README.md`。

### Task 7.4：合并门槛

只有以下条件全部成立才可合并 `dev`：

- Hard Gate 0～6 全部通过。
- 自动发布评估为 `go`。
- Android 有完整真机证据。
- iOS arm64 构建和产物审计通过，且未把未测项表述为已验证。
- OCR 无 Critical/High。
- 当前分支没有录音、模型临时文件、构建产物、密钥或无关脏文件。

建议最终提交：

```text
完成 Whisper C++ 双平台质量交付
```

若任一条件不满足：

- 不合并 `dev`；
- 不删除当前稳定 C++ 固定窗口实现；
- 不在运行中自动回退到另一模型或混合输出；
- 记录 No-Go 证据并停在最近通过审查的阶段提交。

## 4. 阶段状态表

| 阶段 | 状态 | 进入条件 | 退出证据 |
|---|---|---|---|
| 0 边界与基线 | 工程完成 / 质量阻断 | 隔离 worktree | Step 21、发布评估测试已完成；真实语料缺失 |
| 1 Android 模拟器与 PCM | 通过 | 阶段 0 工程基线 | x86_64、10 次启动、30 秒 PCM、最终快照 |
| 2 解码 Profile | 工程完成 / 候选未激活 | 阶段 1 | ABI/Profile 与 100 次生命周期已完成；真实参数矩阵缺失 |
| 3 官方 VAD | 工程完成 / 质量阻断 | 阶段 2 工程能力 | 静音/chunk/模拟器 100 次生命周期通过；真实噪声证据缺失 |
| 4 预览与最终 | 工程完成 / 质量阻断 | 阶段 3 工程能力 | 确定性最终快照和故障注入通过；真实关键事实证据缺失 |
| 5 Android | 待执行 | Hard Gate 4 | 三档设备、16 KB、质量报告 |
| 6 iOS | 待执行 | Hard Gate 5 | arm64 构建、产物审计、未测项清单 |
| 7 发布合并 | 待执行 | Hard Gate 6 | release `go`、OCR、交付物 |
