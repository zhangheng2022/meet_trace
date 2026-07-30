# Step 20：whisper.cpp 正式替换

> 日期：2026-07-29
> 状态：Android 工程验证通过，iOS 真机验证待补

## 变更

- 移除 `sherpa_onnx` 依赖、Paraformer/Qwen Engine、Silero VAD 和旧 Spike。
- 固定官方 `whisper.cpp` v1.9.1 commit
  `f049fff95a089aa9969deb009cdd4892b3e74916`。
- 新增本地 `meettrace_whisper_native` package，以 Native Assets 构建 C/C++，以 `ffigen`
  生成最小 C ABI 绑定。
- 标准模型改为内置 Base Q5_1，高级模型改为按需下载 Small Q5_1。
- 保持统一 `AsrEngine`、会议模型锁定、事实录音优先和最终快照原子激活。
- 旧全局默认模型设置迁移到相同层级的 Whisper 模型，历史会议身份不改写。

## 已验证

- `flutter analyze`
- `flutter test`
- `flutter build apk --debug`
- `tool/benchmarks/inspect_debug_apk.ps1`
- APK 包含 `arm64-v8a`、`armeabi-v7a`、`x86_64` 的
  `libmeettrace_whisper.so`。
- APK 包含 Base 权重，不包含 Small 权重、sherpa 原生库、ONNX 或 Silero 资产。

## 未完成

- iOS 只能在 macOS/Xcode 环境完成构建和真机验收。
- Base/Small 的双平台相同语料指标需重新采集；旧模型数据不能沿用。
- `$grill-me` 技能在本次环境不可用，已以 PRD、AGENTS、技术方案、测试和发布门禁的逐项
  一致性检查替代，合并前仍应在具备该技能的环境补跑。

## 真机复验入口

- `tool/benchmarks/download_whisper_models.ps1`：按固定 revision、字节数和 SHA-256
  准备 Base/Small 权重。
- `tool/benchmarks/run_android_whisper_validation.ps1`：构建并审计 APK，再在指定 Android
  设备运行 Base/Small 原生集成测试。
