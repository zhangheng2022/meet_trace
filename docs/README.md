# 会迹（MeetTrace）文档索引

> 状态：当前文档入口
> 更新日期：2026-07-30

## 活动文档

1. [Android + iOS Alpha PRD V0.7](./会迹_MeetTrace_Alpha_PRD_无登录版.md)：产品范围、用户流程、质量门槛和 AT-01～AT-20 的事实源。
2. [端侧双模型转录技术方案](./端侧双模型转录技术方案.md)：`whisper.cpp` 双模型、Native Assets、录音解耦、模型生命周期和降级设计。
3. [Codex Alpha 开发步骤](./Codex_Alpha_开发步骤.md)：当前实现顺序与交付门槛。
4. [Git 分支与 Worktree 约定](./Git_分支与_Worktree_约定.md)：隔离开发、合并和安全清理规则。
5. [交互与视觉系统](../DESIGN.md)：页面、响应式布局和交互契约。

## 当前实现状态

截至 2026-07-30，应用当前 ASR 主链已从 sherpa-onnx 正式替换为官方
`whisper.cpp` v1.9.1。Rust + `whisper-rs` 候选方案已在阶段 1 判定 No-Go：

- 标准模型 `Whisper Base Q5_1` 随包内置。
- 高级模型 `Whisper Small Q5_1` 按需下载，下载前要求至少 512 MiB 可用空间。
- 官方源码固定 commit，通过仓库内 `meettrace_whisper_native` package、Native Assets、
  最小 C ABI 和 `ffigen` 接入；应用层不维护 JNI 或手工 `jniLibs`。
- 两个模型继续实现统一 `AsrEngine`。开始录音后模型锁定，会中与最终转录使用同一模型，
  不自动切换或混合输出。
- 事实 PCM 写入独立于推理。连续切窗和有界预览队列可丢弃临时预览任务，但不得丢失录音。
- 历史默认模型设置会迁移到对应的 Whisper 层级；历史会议的原模型 ID 与版本保持不变。

`whisper-rs-sys 0.15.0` 在 Windows → Android 交叉编译时错误注入宿主参数；
修复需要 fork 或补丁三方 crate，命中预设硬停止条件。因此不进入阶段 2，不切换 backend，
`meettrace_whisper_native` 继续作为当前正式后端。后续转录质量工作优先校准音频输入、
VAD 分段、解码参数、语言设置和模型层级。

Android Debug APK 已能产出 `arm64-v8a`、`armeabi-v7a`、`x86_64` 三个
`libmeettrace_whisper.so`，并只包含内置 Base 权重。iOS 仍需在 macOS/Xcode 和真机上完成
等价构建、后台录音、内存、温控和模型验收，因此双平台 Alpha 发布仍为 `blocked`。

## 仍需保留的实施证据

- [Step 07 可靠录音与崩溃恢复](./quality/Step_07_可靠录音与崩溃恢复.md)
- [Step 20 whisper.cpp 正式替换](./quality/Step_20_whisper.cpp_正式替换.md)
- [Rust ASR 迁移基线](./quality/Rust_ASR_迁移基线.md)
- [Rust ASR 阶段 1 No-Go 审查](./quality/Rust_ASR_阶段1审查.md)
- [Rust ASR 分阶段实施方案](./superpowers/plans/2026-07-30-rust-whisper-streaming-asr-migration.md)
- [Android Alpha 设备矩阵](./quality/Android_Alpha_设备矩阵.md)
- [iOS Alpha 设备矩阵](./quality/iOS_Alpha_设备矩阵.md)

旧 sherpa-onnx、Paraformer、Qwen3-ASR 和旧 sherpa Silero VAD 方案不在 `docs/` 保留并列副本；
需要追溯时使用 Git 历史。

## 维护规则

- 改变 P0、验收标准或产品边界：先更新 PRD。
- 改变模型、接口、数据链或降级策略：同步更新技术方案。
- 改变实施顺序或质量门槛：同步更新开发步骤。
- 标准模型之外的权重、真实录音、评测语料、密钥、`build/` 和 `coverage/` 不得提交。
