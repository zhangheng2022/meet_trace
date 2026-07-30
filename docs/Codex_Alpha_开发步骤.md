# 会迹 Codex Alpha 开发步骤

> 状态：Rust ASR 分阶段迁移实施顺序
> 更新日期：2026-07-30

## 已完成基线

- Flutter/Forui 自适应 UI、SQLite 数据层、可靠 PCM 录音、checkpoint 与启动恢复。
- 统一 `AsrEngine`、会议模型锁定、有界预览队列、最终转录快照与失败重试。
- 说话人可降级、AI 总结证据链、分享与本地删除。
- 官方 `whisper.cpp` v1.9.1 Native Assets 接入、Base 内置、Small 下载管理和旧偏好迁移。

## 当前交付顺序

详细任务、命令和回退点见
[Rust + whisper-rs 流式 ASR 迁移计划](./superpowers/plans/2026-07-30-rust-whisper-streaming-asr-migration.md)。

1. 冻结旧 C++ 后端自动化、Android/iOS 真机和同语料质量基线，先更新 PRD。
2. 固定 Rust 1.88.0、FRB 2.12.0/Cargokit、`whisper-rs` 0.16.0，完成双平台最小 Spike。
3. 只有 Android+iOS 模型加载、推理、取消、释放和 Android 16 KB 检查全部通过，才进入
   Rust 生产接入。
4. 在 Rust 实现 Whisper 识别与滚动未决尾段 VAD；不同 PCM chunk 切分必须得到相同区间。
5. 通过现有 `WhisperWorkerFactory` seam 接入，保持 `AsrEngine` 和 Domain 不变。
6. VAD ingress 与 ASR 队列独立于事实写入；阻塞/超限只降级临时预览。
7. 最终转录从完整事实 PCM 重跑，保持模型锁定、租约、失败恢复和快照原子激活。
8. 同设备、同权重、同语料对比 C++/Rust；通过质量、延迟、内存、功耗和温控门槛后，
   默认切换 Rust。
9. 再删除旧 C++/FFI/Native Assets 链，完成全量测试、Android/iOS 构建、OCR 和 Graphify。

## 阻断门槛

- 事实录音不完整、推理阻塞写盘、会议中自动切换模型或最终快照非原子：阻断交付。
- Android/iOS 任一目标 ABI 缺失原生库，或包内混入 Small 权重/旧 ONNX 权重：阻断对应平台。
- 未解决的 OCR Critical/High：阻断交付。
- iOS 构建、后台录音与真机模型证据未闭环：双平台 Alpha 发布保持 `blocked`。
- `whisper-rs` 需要 raw API、私有 fork、手写 JNI 或手工 `.so` 才能支持移动端：停止迁移，
  保留当前 C++ 后端。
- Rust/VAD 未达到同语料 cutover 门槛：不得切默认 backend 或删除旧后端。

历史 sherpa-onnx 实施步骤从 Git 查看，不在活动文档中继续维护。
