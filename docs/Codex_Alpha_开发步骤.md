# 会迹 Codex Alpha 开发步骤

> 状态：阶段 0～4 工程实现完成；阶段 1 Android 模拟器门槛通过，真实语料质量门槛阻断
> 更新日期：2026-07-31

## 已完成基线

- Flutter/Forui 自适应 UI、SQLite 数据层、可靠 PCM 录音、checkpoint 与启动恢复。
- 统一 `AsrEngine`、会议模型锁定、有界预览队列、最终转录快照与失败重试。
- 说话人可降级、AI 总结证据链、分享与本地删除。
- 官方 `whisper.cpp` v1.9.1 Native Assets 接入、Base 内置、Small 下载管理和旧偏好迁移。
- Android 模拟器已完成 Base/Small 的固定版本 ASCEND 回归，以及 fixed-window、
  生产默认 VAD、候选 VAD 的 20 段确定性非语音回归；两者分别属于
  `public-regression` 和 `synthetic-smoke`，不替代真实产品会议证据。
- 自动发布评估输入已升级为 schema 6，显式检查产品会议证据类别、Base/Small
  召回不回退、Preview 延迟和阶段 0～4 工程不变量；当前机器可读结论为
  `blocked`（22 passed、0 failed、24 missing）。新增质量报告 SHA-256 和完整
  Profile/Pipeline 矩阵门禁，质量指标只能由脱敏聚合报告自动写入。该报告显式使用
  `evaluationScope=phase-0-4`，不会让阶段 5 以后的 Android 真机、iOS 和 Release
  门槛污染本阶段结论；Android 模拟器证据由完整日志自动推导，并以 SHA-256 绑定。

## 当前交付顺序

完整文件级任务、测试命令、硬门槛、审查和提交点见
[whisper.cpp 质量强化与双平台交付计划](./plans/2026-07-30-whisper-cpp-quality-delivery.md)。

1. 阶段 0：统一 `AGENTS.md`、PRD 和当前 C++ 实现，冻结正式去敏矩阵：20 段静音、
   20 段噪声和 20 段带关键事实的会议语音。
2. 阶段 1：首先打通 Android x86_64 模拟器，完成 Base 初始化、会议开始/停止、
   30 秒事实 PCM、故障降级和最终快照闭环。
3. 阶段 2：增加版本化 C ABI，基于同语料选择 Preview/Final 解码 Profile。
4. 阶段 3：接入官方 Silero VAD，并在异步 worker 中实现确定性流式分段。
5. 阶段 4：用 VAD 驱动会中预览和完整 PCM 最终转录，保持模型锁定与快照原子激活。
6. 阶段 5：完成 Android 三档真机、Release APK、16 KB、质量与资源门禁。
7. 阶段 6：完成 iOS arm64 无签名构建、产物审计和自动化门禁；不执行 iOS 真机测试。
8. 阶段 7：运行全量验证、OCR、Graphify 和自动发布评估；全部为 Go 后才合并 `dev`。

## 阻断门槛

- 事实录音不完整、推理阻塞写盘、会议中自动切换模型或最终快照非原子：阻断交付。
- Android/iOS 任一目标 ABI 缺失原生库，或包内混入 Small 权重/旧 ONNX 权重：阻断对应平台。
- 未解决的 OCR Critical/High：阻断交付。
- iOS arm64 构建或产物审计失败：阻断合并；后台录音、系统中断、性能和模型质量
  明确记为 `not_tested`，不得表述为已通过。
- Android Release 任一 `.so` 未通过 16 KB LOAD alignment：阻断 Android 交付。
- 静音产生文本、VAD chunk 边界不一致或 VAD/ASR 阻塞写盘：阻断质量交付。
- Android 模拟器 x86_64 原生库、会议流或最终快照未闭环：不进入 VAD、真机和 iOS 阶段。

历史 sherpa-onnx 实施步骤从 Git 查看，不在活动文档中继续维护。
