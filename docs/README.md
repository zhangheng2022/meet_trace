# 会迹（MeetTrace）文档索引

> 状态：当前文档入口
> 更新日期：2026-07-31

## 活动文档

1. [Android + iOS Alpha PRD](./会迹_MeetTrace_Alpha_PRD_无登录版.md)：产品范围、用户流程、质量门槛和 AT-01～AT-24 的事实源。
2. [端侧双模型转录技术方案 V0.8](./端侧双模型转录技术方案.md)：`whisper.cpp` 双模型、官方 Silero VAD、Native Assets、录音解耦、模型生命周期和降级设计。
3. [Codex Alpha 开发步骤](./Codex_Alpha_开发步骤.md)：当前实现顺序与交付门槛。
4. [whisper.cpp 质量强化与双平台交付计划](./plans/2026-07-30-whisper-cpp-quality-delivery.md)：Codex 可直接执行的文件级任务、测试、审查、硬门槛和提交点。
5. [Git 分支与 Worktree 约定](./Git_分支与_Worktree_约定.md)：隔离开发、合并和安全清理规则。
6. [交互与视觉系统](../DESIGN.md)：页面、响应式布局和交互契约。

## 当前实现状态

截至 2026-07-30，应用 ASR 主链已从 sherpa-onnx 正式替换为官方
`whisper.cpp` v1.9.1：

- 标准模型 `Whisper Base Q5_1` 随包内置。
- 高级模型 `Whisper Small Q5_1` 按需下载，下载前要求至少 512 MiB 可用空间。
- 官方源码固定 commit，通过仓库内 `meettrace_whisper_native` package、Native Assets、
  最小 C ABI 和 `ffigen` 接入；应用层不维护 JNI 或手工 `jniLibs`。
- 两个模型继续实现统一 `AsrEngine`。开始录音后模型锁定，会中与最终转录使用同一模型，
  不自动切换或混合输出。
- 官方 Silero VAD 在独立 isolate 中驱动会中预览；最终转录从完整 PCM 创建全新 VAD
  状态重跑，不依赖会中预览。
- Android 质量执行链可在相同设备、模型、Profile 和语料上比较固定窗口与生产 VAD
  分段；正式门槛只接受带来源证明的 `product-meeting` 语料，公开/合成语料只做回归
  或烟测。
- 私有候选语料必须先生成默认未批准的人工复核模板；只有逐段确认分类、去敏、关键事实
  和语音首尾后，晋升器才会生成 `product-meeting` manifest。正式 provenance 强制
  绑定复核证明 SHA-256 与 UTC 时间；VAD、ASR 草稿或未经晋升器校验的手工 manifest
  不属于可接受的正式证据。
- 当前本地审阅包提供每类 30 段冗余候选；人工可剔除敏感或误分类片段，但晋升后的
  正式集合仍必须满足每类至少 20 段和语音首尾覆盖。
- Base/Small × Baseline/Preview/Final × 三条 Pipeline 的模拟器矩阵可按组合断点续跑；
  批次复用会复算 transcript 哈希，合并时校验完整样本集合、语料证明和设备指纹。
- 当前 API 36 x86_64 模拟器的合成噪声矩阵中，Base 9 个组合完成，Small Baseline
  固定窗口在 4/20 段后推理失败；该结果按 No-Go 保留，不代表 Android 真机结论，
  也禁止激活 Small 候选 Profile。
- 可复现公开回归入口固定使用 ASCEND revision
  `737e9800ae31be9932ba8464c80366559bd28424`。API 36 x86_64 模拟器 A/B 已定位到
  生产默认 VAD 对短语音存在明显漏检，`vad-recall-035-v1` 仅作为评测候选保留；
  在真实会议噪声、远场和语音首尾门槛通过前不切换生产参数。
- 事实 PCM 写入独立于推理。有界预览队列可丢弃临时预览任务，但不得丢失录音。
- 历史默认模型设置会迁移到对应的 Whisper 层级；历史会议的原模型 ID 与版本保持不变。

Android Debug APK 已能产出 `arm64-v8a`、`armeabi-v7a`、`x86_64` 三个
`libmeettrace_whisper.so`，并只包含内置 Base 权重和批准的官方 VAD。当前实施范围只要求 iOS 在
macOS/Xcode 完成 arm64 无签名构建、产物审计和自动化验证，不执行 iOS 真机测试；
后台录音、系统中断、内存、温控和模型质量必须标记为 `not_tested`，不得推定通过。

## 仍需保留的实施证据

- [Step 07 可靠录音与崩溃恢复](./quality/Step_07_可靠录音与崩溃恢复.md)
- [Step 20 whisper.cpp 正式替换](./quality/Step_20_whisper.cpp_正式替换.md)
- [Step 21 C++ Whisper 质量交付基线](./quality/Step_21_C++_质量交付基线.md)
- [Step 22 Whisper 解码参数评测](./quality/Step_22_Whisper_解码参数评测.md)
- [Step 23～24 官方 VAD、预览与最终转录](./quality/Step_23_24_VAD_与最终转录.md)
- [Android Alpha 设备矩阵](./quality/Android_Alpha_设备矩阵.md)
- [iOS Alpha 设备矩阵](./quality/iOS_Alpha_设备矩阵.md)

旧 sherpa-onnx、Paraformer、Qwen3-ASR 和旧 sherpa Silero VAD 方案不在 `docs/` 保留并列副本；
需要追溯时使用 Git 历史。

## 维护规则

- 改变 P0、验收标准或产品边界：先更新 PRD。
- 改变模型、接口、数据链或降级策略：同步更新技术方案。
- 改变实施顺序或质量门槛：同步更新开发步骤。
- 标准模型之外的权重、真实录音、评测语料、密钥、`build/` 和 `coverage/` 不得提交。
