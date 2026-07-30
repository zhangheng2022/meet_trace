# Step 23～24：官方 VAD、预览与最终转录

> 状态：阶段 3～4 工程实现完成；真实语料质量门槛 `blocked`
> 日期：2026-07-30

## 1. 固定资产与原生边界

- VAD：官方 `ggml-org/whisper-vad` 的 `ggml-silero-v6.2.0.bin`。
- revision：`9ffd54a1e1ee413ddf265af9913beaf518d1639b`。
- bytes：`885098`。
- SHA-256：`2aa269b785eeb53a82983a20501ddf7c1d9c48e33ab63a41391ac6c9f7fb6987`。
- VAD 与 Base 一起准备到已校验安装目录；Small 不进入 APK。
- ASR 与 VAD 使用两个独立原生 context。VAD C ABI 同样校验 ABI、结构大小和参数，
  只返回 sample index，不把上游结构或指针泄漏到应用层。

APK 审计确认三个 ABI 均含 `libmeettrace_whisper.so`，Base 和批准的 VAD 文件字节数、
SHA-256 均匹配；未包含 Small、sherpa、ONNX、用户音频或数据库。

## 2. 会中预览

- `WhisperVadSegmenter` 在专用 isolate 中持有原生 VAD context。
- 输入按全局采样点对齐分析，保留 1 秒未决尾段，输出全局、单调的语音区间。
- 滚动缓冲有上限；超过 15 秒的语音区间仍由预览规划器分窗。
- 事实 PCM 先写盘，再把副本投递给有界预览 dispatcher；VAD/ASR 慢、失败或 worker
  退出时，只让预览进入 `recordingOnly`。

## 3. 最终转录

- 重新打开完整 PCM，从 sample 0 创建全新 VAD worker，不读取会中 VAD 状态或预览文本。
- 第一遍按 1 秒 PCM 块计算 VAD；第二遍只读取已归一化的语音区间，并按最多 15 秒调用
  本场锁定模型。
- 重叠 VAD 区间在识别前确定性合并；输出时间戳始终使用会议全局时间轴。
- 纯静音生成 `complete` 的零片段最终快照，不调用 ASR。
- 只有完整快照通过身份、时间戳、排序校验后才原子激活；失败继续保留旧活动快照。

## 4. 自动化与模拟器证据

| 场景 | 结果 |
|---|---|
| 不同 chunk 边界 | 单元测试得到相同最终 VAD 区间 |
| 纯静音 | 单元测试及 API 36 x86_64 原生 VAD 均为 0 片段 |
| VAD isolate | API 36 x86_64 成功加载、检测、幂等释放 |
| VAD 生命周期 | 100 次 create/detect/cancel-reset/destroy 通过，预热后 RSS -5,836,800 bytes |
| 预览故障 | 事实 PCM 继续增长，最终快照仍 `complete` |
| 最终重新分段 | 只识别从完整 PCM 得到的脚本化语音区间 |
| 快照原子性 | 数据库冲突/推理失败测试保留旧活动快照 |
| 总结事实源 | 现有测试只允许读取已激活的完整最终快照 |

入口：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass `
  -File tool/benchmarks/run_android_emulator_smoke.ps1
```

机器可读证据位于 `docs/quality/evidence/android-emulator/`。

## 5. Hard Gate 3～4

| 条件 | 状态 |
|---|---|
| 官方 VAD 资产、C ABI、isolate、chunk 一致性、静音零片段 | 通过 |
| 会中预览和最终转录使用同一 VAD 参数语义 | 通过 |
| 预览丢弃不改变最终完整 PCM 重跑 | 通过 |
| 时间戳、排序、旧快照原子保留、总结事实源 | 通过 |
| 噪声幻觉相对阶段 0 下降至少 80% | `blocked`：缺少真实语料 |
| 语音首尾关键事实不丢失 | `blocked`：缺少真实语料 |
| VAD 100 次生命周期无持续泄漏 | 通过 |

工程实现可以进入代码审查，但在阻断项关闭前不能声明质量 Gate 或 Alpha 发布通过。
