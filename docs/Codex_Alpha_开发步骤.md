# 会迹 Codex Alpha 开发步骤

> 状态：当前实施顺序
> 更新日期：2026-07-30

## 已完成基线

- Flutter/Forui 自适应 UI、SQLite 数据层、可靠 PCM 录音、checkpoint 与启动恢复。
- 统一 `AsrEngine`、会议模型锁定、有界预览队列、最终转录快照与失败重试。
- 说话人可降级、AI 总结证据链、分享与本地删除。
- 官方 `whisper.cpp` v1.9.1 Native Assets 接入、Base 内置、Small 下载管理和旧偏好迁移。

## 当前交付顺序

1. 固定官方源码 commit、模型 revision、大小、SHA-256 和 NOTICE。
2. 以本地 `meettrace_whisper_native` package 隔离 Native Assets、C ABI 和 `ffigen` 产物。
3. 用 `WhisperAdapter` isolate 封装推理、真实取消、错误映射和资源释放。
4. 用 Base/Small 两个 Engine 实现统一 `AsrEngine`，由 Factory 按会议锁定模型创建。
5. 用连续重叠切窗替换旧 VAD 依赖，保持预览可丢弃、录音不可丢失。
6. 更新 Registry、Manifest、设置文案、下载空间门槛和旧默认模型迁移。
7. 删除 sherpa-onnx、ONNX、Silero 代码、依赖、资产与旧活动文档。
8. 运行格式化、静态分析、全量测试、Android Debug APK、APK 内容审计和 OCR 代码审查。
9. 在 macOS 完成 iOS Debug 构建和 arm64 真机验证。
10. 在相同语料与设备档位上补齐双模型 RTF、延迟、内存、能耗、温控和召回率门禁。

Rust + `whisper-rs` 候选迁移已在阶段 1 判定 No-Go，后续阶段停止；原因和证据见
[Rust ASR 阶段 1 No-Go 审查](./quality/Rust_ASR_阶段1审查.md)。

## 阻断门槛

- 事实录音不完整、推理阻塞写盘、会议中自动切换模型或最终快照非原子：阻断交付。
- Android/iOS 任一目标 ABI 缺失原生库，或包内混入 Small 权重/旧 ONNX 权重：阻断对应平台。
- 未解决的 OCR Critical/High：阻断交付。
- iOS 构建、后台录音与真机模型证据未闭环：双平台 Alpha 发布保持 `blocked`。
历史 sherpa-onnx 实施步骤从 Git 查看，不在活动文档中继续维护。
