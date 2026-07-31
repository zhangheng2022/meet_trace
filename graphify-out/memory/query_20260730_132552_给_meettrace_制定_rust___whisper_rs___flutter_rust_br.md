---
type: "architecture"
date: "2026-07-30T13:25:52.601669+00:00"
question: "给 MeetTrace 制定 Rust + whisper-rs + flutter_rust_bridge 分阶段 ASR 迁移方案，保证 VAD、录音连续性、模型锁定和最终快照语义"
contributor: "graphify"
outcome: "useful"
source_nodes: ["AsrEngine", "WhisperAsrEngineFactory", "AsrPreviewCoordinator", "FinalTranscriptionService", "ReliableRecordingService", "WhisperAdapter"]
---

# Q: 给 MeetTrace 制定 Rust + whisper-rs + flutter_rust_bridge 分阶段 ASR 迁移方案，保证 VAD、录音连续性、模型锁定和最终快照语义

## Answer

# Rust + whisper-rs 流式 ASR 迁移 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan.

**Goal:** 在不改变 `AsrEngine` 领域契约、不影响事实录音连续性、不改变会议模型锁定语义的前提下，用 Rust + `whisper-rs` + `flutter_rust_bridge` 替换当前 Dart isolate + 自建 C ABI/FFI 的 whisper.cpp 接入，并引入官方 Silero VAD 改善静音幻觉、短窗断句和实时转录质量。

**Architecture:** UI、ViewModel、Use Case 和 Domain 保持不变；Data 层继续由 `WhisperAsrEngineFactory` 创建 Base/Small 两个 `AsrEngine`。Rust 原生库在专用工作线程持有 `WhisperContext`、`WhisperState` 和 `WhisperVadContext`，Dart 通过生成的 FRB 桥接调用。可靠录音服务仍先落盘事实 PCM，再把副本投递给预览链；VAD 或 ASR 变慢时只降级/丢弃预览，不阻塞录音。迁移期间旧 C++ 后端保留为可切换对照组，通过双平台门槛后再删除。

**Tech Stack:** Flutter 3.44.8、Dart 3.12、Rust 1.88.0、`flutter_rust_bridge`/codegen 2.12.0、Cargokit、`whisper-rs` 0.16.0、`whisper-rs-sys` 0.15.0、whisper.cpp GGML Base/Small Q5_1、官方 `ggml-silero-v6.2.0.bin`。

## Global Constraints

- Android + iOS Alpha 同步推进；任一平台缺少真机构建、加载、转录、取消或释放证据时不得删除旧后端。
- `lib/domain/ports/asr_engine.dart` 的 `AsrEngine` 接口保持不变；Domain 不导入 FRB、Rust 或 data。
- 会议开始后模型 ID/版本锁定；Rust 后端失败只能降级为“仅录音”，不得自动换 Base/Small 或混合输出。
- 不复用带旧 runtime 含义的 `whisper-cpp-*-v1.9.1` 身份。新 runtime 使用 `meettrace-whisper-base-q5_1-rust-v1` / `meettrace-whisper-small-q5_1-rust-v1`，版本固定为 `rust-v1-whisper-rs-0.16.0-q5_1`；历史会议身份不改写，旧偏好只迁移一次。
- 本地事实 PCM 是唯一事实源。`ReliableRecordingService` 的写盘和 checkpoint 顺序不得改变；VAD/ASR 不得运行在录音写入路径上。
- 会中预览允许丢弃；最终转录必须重新读取完整事实 PCM，完整写入并校验后才原子激活快照。
- AI 总结仍只读取激活的最终转录；云端总结只上传最终文本。
- 标准 Base 随包内置，高级 Small 按需下载；两个层级共用内置 Silero VAD。
- 不手写 JNI、不放置手工 `jniLibs`、不手写 FRB 生成文件。Cargokit/FRB 生成目录通过命令维护。
- 初始版本关闭 GPU/Metal/Vulkan；先建立 CPU 可移植基线，后续优化必须单独评测。
- Rust 与 FRB 只能改善边界管理、并发和可维护性，不能天然提高同一 Whisper 权重的准确率；质量提升主要来自 VAD、窗口策略和参数。
- 所有行为变更先写失败测试，再写最小实现；每一阶段单独提交且可回退。

## 固定版本与外部依据

- `flutter_rust_bridge` 稳定版固定 `2.12.0`，使用其默认且稳定的 Cargokit 集成；不在本轮采用 `2.13.0-beta` Native Assets 后端。参考：[pub.dev](https://pub.dev/packages/flutter_rust_bridge)、[集成后端文档](https://cjycode.com/flutter_rust_bridge/manual/integrate/builtin)。
- `whisper-rs` 固定 `0.16.0`。其高层 API 提供 `WhisperContext`、`WhisperState`、`WhisperVadContext` 和 `WhisperVadParams`，但项目 README 明确表示维护者无法协助 Windows/macOS/Linux 以外平台，因此 Android/iOS 是硬性 Spike，不作纸面假设。参考：[whisper-rs API](https://docs.rs/whisper-rs/0.16.0/whisper_rs/)、[仓库说明](https://codeberg.org/tazz4843/whisper-rs)。
- VAD 使用 whisper.cpp 官方支持的 `ggml-silero-v6.2.0.bin`：885,098 bytes，SHA-256 `2aa269b785eeb53a82983a20501ddf7c1d9c48e33ab63a41391ac6c9f7fb6987`，固定 Hugging Face revision `9ffd54a1e1ee413ddf265af9913beaf518d1639b`。参考：[whisper.cpp VAD 文档](https://github.com/ggml-org/whisper.cpp#voice-activity-detection-vad)。

---

## 阶段 0：冻结基线并先更新产品边界

### Task 0.1：记录当前 C++ 后端的可复现实验基线

**Files:**

- Create: `docs/quality/Rust_ASR_迁移基线.md`
- Modify: `docs/README.md`
- Test data: `integration_test/fixtures/asr/`（只提交去敏、短小、许可明确的 PCM/WAV；真实会议录音不得入库）

**Step 1: 建立基线表格**

在 `docs/quality/Rust_ASR_迁移基线.md` 记录每台 Android/iOS 设备、ABI、系统版本、模型层级和以下指标：

- 20 段中/英/中英混合去敏语料的关键事实召回率、字符错误率、静音幻觉次数；
- 首个稳定片段延迟、句后出字 P50/P95、最终转录 RTF；
- 30 分钟会议的峰值 RSS、平均 CPU、温控和耗电；
- `cancel()` 延迟、连续创建/销毁 100 次后的内存变化；
- APK/IPA 原生库大小及 Android 16 KB page-size 检查结果。

**Step 2: 运行旧后端基线**

Run:

```powershell
$meettraceAndroidDeviceId = Read-Host '请输入 Android 真机 device id'
flutter test
flutter build apk --debug
flutter test integration_test/whisper_base_standard_asr_engine_test.dart -d $meettraceAndroidDeviceId
flutter test integration_test/whisper_small_advanced_asr_engine_test.dart -d $meettraceAndroidDeviceId
```

在 macOS 上运行：

```bash
read -r -p "请输入 iOS 真机 device id: " MEETTRACE_IOS_DEVICE_ID
flutter build ios --debug --no-codesign
flutter test integration_test/whisper_base_standard_asr_engine_test.dart -d "$MEETTRACE_IOS_DEVICE_ID"
flutter test integration_test/whisper_small_advanced_asr_engine_test.dart -d "$MEETTRACE_IOS_DEVICE_ID"
```

Expected: 所有结果带设备、commit `719158b` 或实际基线 commit、模型 SHA 和原始命令，不写“主观感觉更好/更差”。

**Step 3: 写死迁移验收门槛**

在基线文档中写入以下 cutover 门槛：

- 事实 PCM 字节数、SHA 和 checkpoint 连续性与旧后端一致，30 分钟录音成功率 100%；
- 两个模型的总体关键事实召回率不得低于旧后端；
- 静音/背景噪音测试的幻觉片段数至少降低 80%，纯静音测试为 0；
- 正常设备句后出字 P95 ≤ 3 秒；
- 最终转录 RTF 与旧后端相比不得恶化超过 10%；
- 峰值 RSS 与耗电不得恶化超过 15%；
- Android 与 iOS 均完成 100 次 initialize → recognize → cancel/dispose，不崩溃且 RSS 无单调增长。

**Step 4: Commit**

```powershell
git add docs/quality/Rust_ASR_迁移基线.md docs/README.md integration_test/fixtures/asr
git commit -m "记录 Rust ASR 迁移基线"
```

### Task 0.2：在代码前更新 PRD 和技术方案

**Files:**

- Modify: `docs/会迹_MeetTrace_Alpha_PRD_无登录版.md`
- Modify: `docs/端侧双模型转录技术方案.md`
- Modify: `docs/Codex_Alpha_开发步骤.md`
- Modify: `docs/README.md`

**Step 1: 更新 PRD**

将 FR-011 的“本阶段不额外加载 VAD 模型”改为：

- 随包内置官方 Silero VAD；
- VAD 只控制预览/最终识别区间，不控制录音；
- VAD 失败时会中降级为仅录音，最终转录可重试；
- 两个 Whisper 模型使用同一份 VAD 参数和同一批语音区间；
- 增加静音幻觉、边界不截字、VAD 积压不影响录音的验收项。
- 把两个新 runtime 模型 ID/版本写入模型矩阵；旧 `whisper-cpp-*-v1.9.1` 只作为历史身份，不用于新会议。

**Step 2: 更新技术方案**

把原 `WhisperAdapter → isolate → C ABI` 图更新为：

```text
AsrEngine
  └─ WhisperWorkerFactory
       ├─ CppWhisperWorkerFactory（迁移期对照）
       └─ RustWhisperWorkerFactory
            └─ flutter_rust_bridge
                 └─ Rust worker thread
                      ├─ WhisperVadContext
                      ├─ WhisperContext / WhisperState
                      └─ bounded preview queue
```

明确 FRB/Rust 只位于 data/native 层，迁移期间允许 debug 对照开关，正式构建只保留 Rust。

**Step 3: 审阅文档一致性**

Run:

```powershell
rg -n "不额外加载 VAD|不包含.*Silero|连续切窗器|C ABI|Native Assets" docs
```

Expected: 活动文档中不再把“无 VAD”和“旧 C ABI”描述为目标状态；历史质量报告可保留事实描述。

**Step 4: Commit**

```powershell
git add docs/会迹_MeetTrace_Alpha_PRD_无登录版.md docs/端侧双模型转录技术方案.md docs/Codex_Alpha_开发步骤.md docs/README.md
git commit -m "批准 Rust ASR 与 VAD 产品边界"
```

---

## 阶段 1：Rust/FRB 双平台可行性 Spike（硬门槛）

### Task 1.1：固定工具链并生成最小桥接

**Files:**

- Create: `rust-toolchain.toml`
- Create: `rust/Cargo.toml`
- Create: `rust/src/lib.rs`
- Create: `rust/src/api/mod.rs`
- Create: `rust/src/api/health.rs`
- Create: `flutter_rust_bridge.yaml`
- Generated: `rust/src/frb_generated.rs`
- Generated: `lib/data/services/asr/rust_bridge/generated/`
- Generated: `rust_builder/`
- Modify: `pubspec.yaml`
- Modify: `.gitignore`

**Step 1: 安装并固定工具版本**

Run:

```powershell
winget install --exact --id Rustlang.Rustup
rustup toolchain install 1.88.0
rustup target add aarch64-linux-android armv7-linux-androideabi x86_64-linux-android --toolchain 1.88.0
cargo install flutter_rust_bridge_codegen --version 2.12.0 --locked
```

在 macOS 构建机额外运行：

```bash
rustup toolchain install 1.88.0
rustup target add aarch64-apple-ios aarch64-apple-ios-sim x86_64-apple-ios --toolchain 1.88.0
cargo install flutter_rust_bridge_codegen --version 2.12.0 --locked
```

Expected: `rustc --version` 为 1.88.0，`flutter_rust_bridge_codegen --version` 为 2.12.0。

**Step 2: 生成 Cargokit 集成**

Run:

```powershell
flutter_rust_bridge_codegen integrate --rust-crate-name meettrace_asr_native --rust-crate-dir rust --integration-backend cargokit --platforms android,ios --no-integration-test
```

随后配置 `flutter_rust_bridge.yaml`：

```yaml
rust_input: crate::api
rust_root: rust/
dart_output: lib/data/services/asr/rust_bridge/generated
```

Run:

```powershell
flutter_rust_bridge_codegen generate
```

Expected: 生成 Rust/Dart glue，`pubspec.yaml` 固定 `flutter_rust_bridge: 2.12.0`，没有手工 JNI 或 `jniLibs`。

**Step 3: 先写失败的桥接测试**

Create `test/data/services/asr/rust_bridge/rust_runtime_test.dart`：

```dart
test('Rust runtime exposes pinned component versions', () async {
  final info = await rustRuntimeInfo();

  expect(info.bridgeVersion, '2.12.0');
  expect(info.whisperRsVersion, '0.16.0');
  expect(info.rustVersion, startsWith('1.88.0'));
});
```

Run:

```powershell
flutter test test/data/services/asr/rust_bridge/rust_runtime_test.dart
```

Expected: FAIL because `rustRuntimeInfo` is not implemented.

**Step 4: 实现最小运行时 API**

在 `rust/src/api/health.rs` 定义可由 FRB 生成的 `RustRuntimeInfo` 和 `rust_runtime_info()`，值由编译期常量返回，不读取网络或环境变量。

Run:

```powershell
flutter_rust_bridge_codegen generate
cargo fmt --manifest-path rust/Cargo.toml --check
cargo test --manifest-path rust/Cargo.toml
flutter test test/data/services/asr/rust_bridge/rust_runtime_test.dart
```

Expected: PASS。

### Task 1.2：验证 whisper-rs 在 Android/iOS 的模型加载、推理和释放

**Files:**

- Modify: `rust/Cargo.toml`
- Create: `rust/src/api/probe.rs`
- Create: `rust/tests/model_probe_test.rs`
- Create: `integration_test/rust_whisper_mobile_probe_test.dart`
- Modify: `rust/src/api/mod.rs`

**Step 1: 固定依赖**

在 `rust/Cargo.toml` 精确固定：

```toml
[dependencies]
flutter_rust_bridge = "=2.12.0"
whisper-rs = "=0.16.0"

[profile.release]
lto = "thin"
codegen-units = 1
panic = "abort"
strip = "symbols"
```

生成并提交 `rust/Cargo.lock`，禁止使用宽松 `^` 版本。

**Step 2: 先写失败的真机 Probe**

`integration_test/rust_whisper_mobile_probe_test.dart` 必须完成：

1. 复制内置 Base 到应用私有模型目录；
2. `probeWhisperModel(path)` 创建 context/state；
3. 对 2 秒 16 kHz Float32 测试 PCM 执行一次推理；
4. 取消并释放；
5. 循环 100 次。

Run:

```powershell
flutter test integration_test/rust_whisper_mobile_probe_test.dart -d $meettraceAndroidDeviceId
```

Expected: FAIL because probe API is absent.

**Step 3: 实现最小 Probe**

在 `rust/src/api/probe.rs` 仅通过 `whisper-rs` 高层 API 创建 `WhisperContext`/`WhisperState`、运行一次 `full` 并释放。不得启用 `raw-api` 或新增私有 C 绑定来绕过构建问题。

**Step 4: 构建目标平台**

Run:

```powershell
cargo test --manifest-path rust/Cargo.toml
flutter build apk --debug
flutter test integration_test/rust_whisper_mobile_probe_test.dart -d $meettraceAndroidDeviceId
```

在 macOS：

```bash
cargo test --manifest-path rust/Cargo.toml
flutter build ios --debug --no-codesign
flutter test integration_test/rust_whisper_mobile_probe_test.dart -d "$MEETTRACE_IOS_DEVICE_ID"
```

Expected: 两个平台均可加载 Base、完成推理、取消和 100 次释放。

**Step 5: 检查 Android 16 KB page size**

Run:

```powershell
flutter build apk --release --target-platform android-arm64
$apk = Resolve-Path build/app/outputs/flutter-apk/app-release.apk
powershell -ExecutionPolicy Bypass -File tool/check_android_16kb.ps1 $apk
```

`tool/check_android_16kb.ps1` 必须先把 APK 解压到 `New-Item` 创建的临时目录，再对其中每个 `.so` 执行 NDK `llvm-readelf -lW`；所有 LOAD segment 的 alignment 必须满足 16 KB。脚本测试对象包括 Rust 库和所有三方 `.so`，结束后只删除它自己创建且已校验位于系统临时目录下的目录。

**Hard Gate 1：**

- Android arm64 真机、iOS arm64 真机均通过；
- 100 次生命周期无崩溃/明显泄漏；
- Release APK 通过 16 KB 检查；
- 不需要 `whisper-rs` raw API、仓库 fork、手工 JNI 或手工复制 `.so`。

任何一项失败：停止 Rust 正式迁移，保留当前 C++ 后端；把失败证据写入 `docs/quality/Rust_ASR_迁移基线.md`。不得继续把实验桥接接入生产 Factory。

**Step 6: Commit**

```powershell
git add rust rust-toolchain.toml rust_builder flutter_rust_bridge.yaml lib/data/services/asr/rust_bridge/generated pubspec.yaml pubspec.lock .gitignore integration_test/rust_whisper_mobile_probe_test.dart test/data/services/asr/rust_bridge tool/check_android_16kb.ps1
git commit -m "验证 Rust Whisper 双平台可行性"
```

---

## 阶段 2：实现 Rust ASR 核心与批式流 VAD

### Task 2.1：定义稳定的 Rust 错误、配置和识别结果

**Files:**

- Create: `rust/src/asr/mod.rs`
- Create: `rust/src/asr/config.rs`
- Create: `rust/src/asr/error.rs`
- Create: `rust/src/asr/events.rs`
- Create: `rust/src/asr/transcriber.rs`
- Create: `rust/tests/transcriber_test.rs`
- Modify: `rust/src/lib.rs`

**Step 1: 写失败的配置与错误测试**

覆盖：

- 非 16 kHz、空 PCM、空模型路径、线程数 ≤ 0 被拒绝；
- Whisper 初始化/推理/取消错误映射为稳定 code；
- 输出 segment 的 `start_ms/end_ms` 单调、不越过输入时长；
- 中英自动语言沿用当前 `language = auto`。

Run:

```powershell
cargo test --manifest-path rust/Cargo.toml transcriber
```

Expected: FAIL because modules do not exist.

**Step 2: 实现最小类型**

```rust
pub struct RustRecognizerConfig {
    pub model_id: String,
    pub model_version: String,
    pub model_path: String,
    pub thread_count: u32,
    pub language: String,
}

pub struct RustRecognitionSegment {
    pub text: String,
    pub start_ms: i64,
    pub end_ms: i64,
}

pub struct RustRecognition {
    pub text: String,
    pub sample_count: u64,
    pub elapsed_ms: u64,
    pub segments: Vec<RustRecognitionSegment>,
}
```

`RustTranscriber` 独占 `WhisperContext` 和 `WhisperState`，不在多个线程共享可变 state；调用方只通过 worker 消息使用。

**Step 3: 实现一次识别**

使用 `SamplingStrategy::Greedy { best_of: 1 }`，保持当前线程数、自动语言、时间戳和取消语义。先追求与旧后端等价，不在本任务调 beam search、temperature fallback 或 prompt。

Run:

```powershell
cargo fmt --manifest-path rust/Cargo.toml --check
cargo clippy --manifest-path rust/Cargo.toml --all-targets -- -D warnings
cargo test --manifest-path rust/Cargo.toml
```

Expected: PASS。

### Task 2.2：实现 Silero VAD 的滚动未决尾段算法

**Files:**

- Create: `rust/src/asr/vad.rs`
- Create: `rust/tests/vad_test.rs`
- Create: `rust/tests/fixtures/vad/README.md`
- Modify: `rust/src/asr/mod.rs`

**Step 1: 写失败的 VAD 测试**

至少覆盖：

- 纯静音返回空；
- 短于 250 ms 的噪音不成为语音；
- 语音跨两个任意 Dart chunk 时不截断首尾；
- 100 ms 短停顿不拆段，≥ 500 ms 停顿拆段；
- 超过 15 秒连续语音被切分且带 100 ms overlap；
- `flush()` 提交最后一个未决语音段；
- `reset(next_start_sample)` 后全局 sample 时间轴正确；
- 同一 PCM 用 20 ms、100 ms、500 ms chunk 输入，最终区间完全一致。

Run:

```powershell
cargo test --manifest-path rust/Cargo.toml vad
```

Expected: FAIL。

**Step 2: 实现固定 VAD 参数**

初始参数固定为：

- threshold `0.50`
- min speech `250 ms`
- min silence `500 ms`
- max speech `15 s`
- speech pad `100 ms`
- samples overlap `0.10 s`

参数集中在 `RustVadConfig::meettrace_default()`，不得散落魔法数字。

**Step 3: 实现高层 API 可支持的滚动算法**

`whisper-rs 0.16.0` 高层 API 暴露 `segments_from_samples`，没有在计划中依赖未公开的增量 LSTM state API。因此：

1. Rust 保存尚未提交的 PCM tail；
2. 新 chunk 到达时追加 tail；
3. 每累计 500 ms 调用 `WhisperVadContext::segments_from_samples` 重跑未决 tail；
4. 只提交末尾已有 ≥ 500 ms 静音确认的 segment；
5. 从最后已提交端点前 100 ms 保留 overlap，其余丢弃；
6. tail 达到 15 秒时按 max-speech 规则强制提交；
7. `flush()` 对完整 tail 做最后一次检测并提交。

这避免假定 `detect_speech_no_reset` 已被 `whisper-rs` 稳定绑定，同时保证不同 Dart chunk 大小不改变最终区间。

**Step 4: 验证并写清停止条件**

Run:

```powershell
cargo test --manifest-path rust/Cargo.toml vad -- --nocapture
```

Expected: 所有 chunk-boundary 测试一致。

若高层 `whisper-rs` 无法保证边界一致、VAD 模型在任一移动平台崩溃、或重跑 tail 使预览 P95 超过 3 秒，则停止 Rust 迁移；本轮不启用 `raw-api` 补洞。

**Step 5: Commit**

```powershell
git add rust/src/asr rust/tests
git commit -m "实现 Rust Whisper 与滚动 VAD 核心"
```

---

## 阶段 3：通过现有 Worker seam 接入 Dart

### Task 3.1：实现 RustWhisperWorkerFactory

**Files:**

- Create: `lib/data/services/asr/whisper/rust_whisper_worker.dart`
- Create: `test/data/services/asr/whisper/rust_whisper_worker_test.dart`
- Modify: `lib/data/services/asr/whisper/whisper_adapter.dart`
- Modify: `lib/data/services/asr/whisper_asr_engine_factory.dart`
- Modify: `lib/data/services/asr/whisper_base_standard_asr_engine.dart`
- Modify: `lib/data/services/asr/whisper_small_advanced_asr_engine.dart`

**Step 1: 先写失败的契约测试**

用 fake Rust API 验证：

- `WhisperRecognizerConfig` 精确映射；
- `Float32List` 输入和 16 kHz 校验不变；
- Rust segment 映射到 `WhisperRecognitionSegment`；
- Rust structured error 映射为现有 `AppFailure.code/stage/modelId/modelVersion`；
- `cancel()` 幂等；
- `dispose()` 等待在途识别并只释放一次；
- Base/Small 使用各自锁定的模型路径，不发生自动切换。

Run:

```powershell
flutter test test/data/services/asr/whisper/rust_whisper_worker_test.dart
```

Expected: FAIL。

**Step 2: 实现 Worker**

`RustWhisperWorkerFactory implements WhisperWorkerFactory`。继续复用 `WhisperAdapter` 的串行 `_tail`，首轮不删除旧 `_IsolateWhisperWorker`。Rust 内部执行 CPU 工作，Dart main isolate 不执行推理。

`nativeContextAddress` 是旧 C++ 诊断字段。先把 `WhisperWorker` 改为返回后端无关的：

```dart
String get runtimeInstanceId;
```

同步更新只依赖该诊断字段的测试；不得把 Rust 指针地址暴露给业务层。

**Step 3: 增加显式迁移期开关**

在 data 层定义：

```dart
enum WhisperNativeBackend { cpp, rust }
```

`WhisperAsrEngineFactory` 构造参数显式接收 backend，默认暂为 `cpp`。开关只用于 debug/integration test，不进入设置 UI，不允许会议中途切换。

**Step 4: 运行等价测试**

Run:

```powershell
dart format lib test
flutter test test/data/services/asr/whisper/rust_whisper_worker_test.dart
flutter test test/data/services/asr/whisper_base_standard_asr_engine_test.dart
flutter test test/data/services/asr/whisper_small_advanced_asr_engine_test.dart
flutter test test/data/services/asr/whisper_asr_engine_factory_test.dart
```

Expected: PASS。

**Step 5: Commit**

```powershell
git add lib/data/services/asr test/data/services/asr
git commit -m "接入 Rust Whisper Worker"
```

---

## 阶段 4：把 VAD 接入预览，保持录音路径非阻塞

### Task 4.1：将同步 VAD Port 改为异步并增加独立 VAD ingress

**Files:**

- Modify: `lib/data/services/vad/voice_activity_segmenter.dart`
- Create: `lib/data/services/vad/rust_voice_activity_segmenter.dart`
- Create: `test/data/services/vad/rust_voice_activity_segmenter_test.dart`
- Modify: `lib/data/services/asr/asr_preview_coordinator.dart`
- Modify: `lib/app/meettrace_dependency_factories.dart`
- Modify: `test/data/services/asr/asr_preview_coordinator_test.dart`
- Delete after cutover only: `lib/data/services/vad/streaming_window_segmenter.dart`
- Delete after cutover only: `test/data/services/vad/streaming_window_segmenter_test.dart`

**Step 1: 写录音隔离失败测试**

在 `asr_preview_coordinator_test.dart` 增加：

- fake VAD 永不完成时，连续 `add()` 录音块仍立即完成；
- VAD ingress 达到 10 秒上限时进入 `recordingOnly`，不向上抛错、不影响后续事实 PCM；
- VAD 结果乱序完成时仍按串行输入顺序处理；
- `flush()` 等待 VAD 和 ASR 队列，但 `dispose()` 可取消；
- 时间轴断点调用 `reset(nextStartSample)` 并丢弃未决预览；
- 已落盘的录音 chunk 数与启用/禁用 VAD 时完全一致。

Run:

```powershell
flutter test test/data/services/asr/asr_preview_coordinator_test.dart
```

Expected: FAIL。

**Step 2: 修改内部 Port**

将 data 层接口改为：

```dart
abstract interface class VoiceActivitySegmenter {
  int get sampleRate;
  Future<List<VadSpeechSegment>> accept(Float32List samples);
  Future<List<VadSpeechSegment>> flush();
  Future<void> reset({required int nextStartSample});
  Future<void> dispose();
}
```

这是 data 内部协议，不修改 Domain。

**Step 3: 增加预览专用 ingress**

`AsrPreviewCoordinator.add()` 只做 PCM16 → Float32 解码、时间轴追加和有界入队，然后立即返回。新增串行 `_drainVadIngress()` 在后台等待 Rust VAD：

- ingress 最大 10 秒音频；
- 超限或 VAD 异常后调用 `_enterRecordingOnly('asr.preview.vad_backlogged')`；
- 不阻塞 `RecordingPreviewSink.add()`；
- 原 ASR 窗口队列 30 秒、高/低水位和丢弃规则保持不变。

**Step 4: 实现 RustVoiceActivitySegmenter**

仅负责把 Float32 chunk、全局起点、flush/reset/dispose 映射到 Rust VAD session；Dart 不复制模型逻辑和参数。

**Step 5: 运行测试**

Run:

```powershell
dart format lib test
flutter test test/data/services/vad/rust_voice_activity_segmenter_test.dart
flutter test test/data/services/asr/asr_preview_coordinator_test.dart
flutter test test/data/services/audio
```

Expected: PASS，尤其“VAD 卡死不阻塞录音”测试。

### Task 4.2：安装并校验 VAD 模型

**Files:**

- Modify: `assets/models/manifest.json`
- Create: `assets/models/whisper-vad-silero-v6.2.0/ggml-silero-v6.2.0.bin`
- Create: `assets/licenses/whisper-vad-NOTICE.txt`
- Modify: `pubspec.yaml`
- Modify: `lib/data/services/models/asr_model_registry.dart`
- Modify: relevant tests under `test/data/services/models/`

**Step 1: 下载固定 revision 并校验**

Run:

```powershell
New-Item -ItemType Directory -Force -Path assets/models/whisper-vad-silero-v6.2.0 | Out-Null
Invoke-WebRequest -Uri 'https://huggingface.co/ggml-org/whisper-vad/resolve/9ffd54a1e1ee413ddf265af9913beaf518d1639b/ggml-silero-v6.2.0.bin?download=true' -OutFile 'assets/models/whisper-vad-silero-v6.2.0/ggml-silero-v6.2.0.bin'
Get-Item 'assets/models/whisper-vad-silero-v6.2.0/ggml-silero-v6.2.0.bin' | Select-Object Length
Get-FileHash 'assets/models/whisper-vad-silero-v6.2.0/ggml-silero-v6.2.0.bin' -Algorithm SHA256
```

Expected: 885098 bytes；SHA-256 `2AA269B785EEB53A82983A20501DDF7C1D9C48E33AB63A41391AC6C9F7FB6987`。

**Step 2: 先写失败的资产测试**

验证 manifest、实际资产、pubspec、许可 notice 的路径、大小和 SHA 一致；Base/Small 都引用同一个 VAD descriptor。

**Step 3: 更新注册表**

VAD 是 ASR runtime dependency，不作为第三个用户可选模型；开始会议前模型准备必须同时验证 Whisper 权重和 VAD。VAD 损坏时允许仅录音并给出修复入口。注册表增加 `meettrace-whisper-base-q5_1-rust-v1` / `meettrace-whisper-small-q5_1-rust-v1`，并增加一次性旧偏好迁移；历史会议与快照中的旧 ID/版本原样保留。

**Step 4: 运行测试**

Run:

```powershell
flutter pub get
flutter test test/data/services/models
flutter build apk --debug
```

Expected: APK 包含 Base + Silero，不包含 Small；资产 hash 测试 PASS。

**Step 5: Commit**

```powershell
git add lib/data/services/vad lib/data/services/asr/asr_preview_coordinator.dart lib/app/meettrace_dependency_factories.dart lib/data/services/models test/data/services/vad test/data/services/asr/asr_preview_coordinator_test.dart test/data/services/models assets/models/manifest.json assets/models/whisper-vad-silero-v6.2.0 assets/licenses/whisper-vad-NOTICE.txt pubspec.yaml pubspec.lock
git commit -m "接入 Rust Silero VAD 预览分段"
```

---

## 阶段 5：最终转录、快照与取消恢复

### Task 5.1：让 Rust 后端覆盖最终转录

**Files:**

- Modify: `lib/data/services/asr/whisper/whisper_asr_engine.dart`
- Modify: `lib/data/services/asr/whisper_base_standard_asr_engine.dart`
- Modify: `lib/data/services/asr/whisper_small_advanced_asr_engine.dart`
- Modify: `lib/domain/use_cases/run_final_transcription.dart`
- Modify: `test/data/services/asr/whisper_base_standard_asr_engine_test.dart`
- Modify: `test/data/services/asr/whisper_small_advanced_asr_engine_test.dart`
- Modify: `test/data/services/asr/final_transcription_service_test.dart`

**Step 1: 写失败测试**

覆盖：

- 最终转录重新读取 `AudioSource.path` 的完整 PCM，不复用会中临时文本；
- 以同一 VAD 参数生成确定性区间；
- VAD/Whisper 局部失败不会激活半成品快照；
- 旧快照在失败时仍为 active；
- 重试生成新 snapshotId；
- segment 全局时间戳单调且不超出 `AudioSource.durationMs`；
- `cancel()` 能中断 VAD 和 Whisper，`dispose()` 等待 worker 退出；
- 模型 ID/版本仍为会议锁定值。

Run:

```powershell
flutter test test/data/services/asr/final_transcription_service_test.dart
flutter test test/data/services/asr/whisper_base_standard_asr_engine_test.dart
flutter test test/data/services/asr/whisper_small_advanced_asr_engine_test.dart
```

Expected: 新 Rust 路径测试 FAIL。

**Step 2: 实现最终路径**

继续由 Dart `FinalTranscriptionService` 负责编排租约、快照和原子激活；Rust 只负责 VAD + 识别，不直接写数据库。音频文件读取可在 Dart 现有路径中完成并以有界窗口送入 Rust，避免把数据库/文件生命周期下沉到 native。

**Step 3: 验证取消和失败恢复**

Run:

```powershell
flutter test test/data/services/asr
flutter test test/domain/use_cases
```

Expected: PASS。

**Step 4: Commit**

```powershell
git add lib/data/services/asr lib/domain/use_cases/run_final_transcription.dart test/data/services/asr test/domain/use_cases
git commit -m "完成 Rust Whisper 最终转录"
```

---

## 阶段 6：双后端同语料对照与正式切换

### Task 6.1：建立 debug 对照工具和真机报告

**Files:**

- Create: `tool/run_asr_backend_matrix.dart`
- Create: `docs/quality/Rust_ASR_Android_设备矩阵.md`
- Create: `docs/quality/Rust_ASR_iOS_设备矩阵.md`
- Modify: `integration_test/whisper_base_standard_asr_engine_test.dart`
- Modify: `integration_test/whisper_small_advanced_asr_engine_test.dart`

**Step 1: 同一事实 PCM 依次跑 cpp/rust**

工具输入相同语料目录、模型和设备，只输出 JSON/Markdown 指标，不上传音频。对比：

- transcript、segment 时间戳、关键事实召回、CER；
- 静音幻觉；
- VAD 区间；
- P50/P95 latency、RTF、RSS、CPU、耗电和温控；
- 初始化、取消、释放。

**Step 2: 跑 Android/iOS 矩阵**

Run:

```powershell
dart run tool/run_asr_backend_matrix.dart --backend cpp --model base --corpus integration_test/fixtures/asr
dart run tool/run_asr_backend_matrix.dart --backend rust --model base --corpus integration_test/fixtures/asr
dart run tool/run_asr_backend_matrix.dart --backend cpp --model small --corpus integration_test/fixtures/asr
dart run tool/run_asr_backend_matrix.dart --backend rust --model small --corpus integration_test/fixtures/asr
```

在两平台真机分别运行相同矩阵并写入对应质量报告。

**Hard Gate 2：**

- 满足 Task 0.1 的全部 cutover 门槛；
- AT-03/04/07/14/15/16/17/18 通过；
- iOS arm64 与 Android arm64 至少各两档设备有证据；
- 无未解决 Critical/High OCR 问题。

### Task 6.2：把默认 backend 切到 Rust

**Files:**

- Modify: `lib/data/services/asr/whisper_asr_engine_factory.dart`
- Modify: `lib/app/meettrace_dependencies.dart`
- Modify: `lib/app/meettrace_dependency_factories.dart`
- Modify: `test/data/services/asr/whisper_asr_engine_factory_test.dart`
- Modify: relevant dependency wiring tests

**Step 1: 写失败测试**

验证默认 Factory 创建 `RustWhisperWorkerFactory`，debug 显式传 `cpp` 时才使用旧后端；Release 构建不从用户设置读取 backend。

**Step 2: 切默认值**

默认改为 Rust，保留 cpp 仅供一个迁移观察周期的集成测试和紧急回退分支。

**Step 3: 全量验证**

Run:

```powershell
dart format lib test integration_test tool
flutter analyze
flutter test
flutter build apk --debug
```

在 macOS：

```bash
flutter analyze
flutter test
flutter build ios --debug --no-codesign
```

Expected: PASS。

**Step 4: Commit**

```powershell
git add lib test integration_test tool docs/quality
git commit -m "默认启用 Rust Whisper 后端"
```

---

## 阶段 7：删除旧 C++/FFI 链并收口依赖

### Task 7.1：移除旧后端

**Files:**

- Delete: `packages/meettrace_whisper_native/`
- Delete old isolate/C++ worker code from: `lib/data/services/asr/whisper/whisper_adapter.dart`
- Delete: `lib/data/services/vad/streaming_window_segmenter.dart`
- Delete: `test/data/services/vad/streaming_window_segmenter_test.dart`
- Modify: `pubspec.yaml`
- Modify: `pubspec.lock`
- Modify: `.gitignore`
- Modify: `docs/端侧双模型转录技术方案.md`
- Modify: `docs/Codex_Alpha_开发步骤.md`
- Modify: `docs/README.md`

**Step 1: 先证明旧路径没有引用**

Run:

```powershell
rg -n "meettrace_whisper_native|OfficialWhisperWorkerFactory|_IsolateWhisperWorker|StreamingWindowSegmenter|WhisperNativeBackend.cpp|ffigen|native_toolchain_c" lib test integration_test pubspec.yaml
```

Expected: 只命中待删除代码或迁移测试。

**Step 2: 删除旧链**

删除自建 C ABI、FFI 绑定、vendored whisper.cpp、Native Assets C++ hook、旧 isolate worker 和 cpp backend enum 分支。`WhisperWorkerFactory` seam 与 Rust 实现保留，便于测试 fake。

**Step 3: 验证包内容**

Run:

```powershell
flutter pub get
flutter build apk --release
powershell -ExecutionPolicy Bypass -File tool/check_android_16kb.ps1 build/app/outputs/flutter-apk/app-release.apk
rg -n "sherpa|onnx|meettrace_whisper_native|third_party/whisper.cpp" lib android ios pubspec.yaml
```

Expected:

- 不再包含 `packages/meettrace_whisper_native`；
- 不包含 sherpa/ONNX；
- Rust 库和模型资产存在；
- 无旧 C/C++ `clang -c` 阶段的 linker flag warning；
- 16 KB 检查 PASS。

**Step 4: 更新活动文档**

技术方案版本升级，明确 `whisper-rs` 实际 vendored 的 whisper.cpp revision/版本（从 `Cargo.lock` 和 runtime API 读取并写死），不再声称使用已删除的 v1.9.1 C ABI 实现。历史由 Git 保存，不在 `docs/` 留并列旧方案。

**Step 5: Commit**

```powershell
git add -A packages/meettrace_whisper_native lib/data/services/asr/whisper lib/data/services/vad test/data/services/vad pubspec.yaml pubspec.lock .gitignore docs
git commit -m "移除旧 Whisper C++ 接入"
```

---

## 阶段 8：交付验证、OCR 审查与 dev 合并

### Task 8.1：运行全部质量门槛

**Files:**

- Modify as evidence: `docs/quality/Rust_ASR_迁移基线.md`
- Modify as evidence: `docs/quality/Rust_ASR_Android_设备矩阵.md`
- Modify as evidence: `docs/quality/Rust_ASR_iOS_设备矩阵.md`

Run:

```powershell
cargo fmt --manifest-path rust/Cargo.toml --check
cargo clippy --manifest-path rust/Cargo.toml --all-targets -- -D warnings
cargo test --manifest-path rust/Cargo.toml
flutter_rust_bridge_codegen generate
git diff --exit-code -- rust/src/frb_generated.rs lib/data/services/asr/rust_bridge/generated
dart format --output=none --set-exit-if-changed lib test integration_test tool
flutter analyze
flutter test
flutter build apk --debug
flutter build apk --release
powershell -ExecutionPolicy Bypass -File tool/check_android_16kb.ps1 build/app/outputs/flutter-apk/app-release.apk
```

在 macOS：

```bash
cargo fmt --manifest-path rust/Cargo.toml --check
cargo clippy --manifest-path rust/Cargo.toml --all-targets -- -D warnings
cargo test --manifest-path rust/Cargo.toml
flutter analyze
flutter test
flutter build ios --debug --no-codesign
```

Expected: 全部 PASS，生成文件无未提交差异。

### Task 8.2：运行 OCR 代码审查

使用 `$open-code-review-delegate` 的 workspace 或 range 模式审查从阶段 0 基线 commit 到当前 HEAD 的全部 reviewable 文件。Background 必须写入：

- 事实 PCM 是唯一事实源，录音不可因 VAD/ASR 失败或积压中断；
- 预览可丢弃，最终转录必须完整重跑并原子激活；
- 会议模型锁定，不允许自动切换/混合输出；
- Android+iOS 双平台、16 KB page size、Rust 生命周期和模型/VAD 资产校验；
- 生成的 FRB/Cargokit 文件只按明确模式 exclude，并说明原因。

发现 Critical/High：直接修复、补测试、重跑受影响验证并重新审查。保留 Medium 必须写入质量报告，说明风险、责任人和后续动作。

### Task 8.3：同步 Graphify 并合并 dev

Run:

```powershell
graphify update .
graphify query "Rust Whisper VAD 如何保证录音连续性、会议模型锁定和最终快照原子切换" --budget 5000
git status --short
```

确认只有本计划相关变更后：

```powershell
git add graphify-out docs/quality
git commit -m "同步 Rust ASR 架构图谱"
git switch dev
git merge --no-ff codex/rust-whisper-streaming-asr -m "合并 Rust Whisper 流式转录"
flutter analyze
flutter test
```

不得在 Hard Gate 1、Hard Gate 2、OCR 或 iOS 证据未完成时合并 `dev`。

---

## 阶段退出与回退策略

| 阶段 | 可发布状态 | 失败时动作 |
|---|---|---|
| 0 | 旧 C++ 可继续使用 | 补齐基线/PRD，不写 Rust 生产代码 |
| 1 | 旧 C++ 可继续使用 | 删除/隔离 Spike，不接 Factory |
| 2–5 | 默认仍为 C++ | 回退 Rust backend 选择，不影响会议数据 |
| 6 | Rust 默认、C++ 暂留 | 切回 data 层 backend，会议内不热切换 |
| 7 | 仅 Rust | 用阶段 6 前 tag/commit 回退整次 cutover |
| 8 | 可合并 dev | 任一 Critical/High 或平台门槛失败即阻断 |

## 预估排期

按 1 名熟悉 Flutter、1 名可使用 Android/iOS 真机与 macOS 构建机的工程师估算：

- 阶段 0：1–2 天；
- 阶段 1：2–4 天（最大不确定性）；
- 阶段 2：3–5 天；
- 阶段 3：2–3 天；
- 阶段 4：3–5 天；
- 阶段 5：2–4 天；
- 阶段 6：3–5 天，另加 30 分钟/多设备跑测时间；
- 阶段 7–8：2–4 天。

总计约 18–32 个工程日。若阶段 1 需要 fork `whisper-rs`、手写移动平台构建补丁或 raw API，本计划按硬门槛停止，不把该不确定性悄悄扩进 Alpha。

## 最终自检

- 类型链一致：Rust `RustRecognitionSegment` → Dart `WhisperRecognitionSegment` → Domain `TranscriptSegment`。
- 时间链一致：全局 sample index → VAD segment → preview window → `start_ms/end_ms`，所有重置和 overlap 有测试。
- 生命周期一致：会议锁定模型 → context/state/VAD 创建 → cancel → dispose，均幂等且不泄漏。
- 数据链一致：PCM 先落盘 → preview 副本 → VAD/ASR；最终始终从事实 PCM 重跑。
- 资产链一致：manifest → pubspec asset → 私有目录复制 → bytes/SHA 校验 → Rust model path。
- 交付链一致：格式化、Rust lint/test、Flutter analyze/test、双平台构建、16 KB、真机矩阵、OCR、Graphify 全部完成后才合并 dev。

## Outcome

- Signal: useful

## Source Nodes

- AsrEngine
- WhisperAsrEngineFactory
- AsrPreviewCoordinator
- FinalTranscriptionService
- ReliableRecordingService
- WhisperAdapter