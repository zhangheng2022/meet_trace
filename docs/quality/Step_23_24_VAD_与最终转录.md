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
| Android 双管线评测 | 固定窗口与生产 VAD 分段可在同设备、模型、Profile、语料上直接比较 |
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

质量执行器不再用固定窗口结果推断 VAD 效果。`vad-segmented-v1` 为每段完整 PCM 创建
全新 `WhisperVadSegmenter` 状态，只识别其全局语音区间；`fixed-window-v1` 保留为阶段
0 对照。聚合器仅对匹配的设备、模型、版本和 Profile 计算：

- 噪声幻觉下降率；
- 关键事实召回率变化；
- 两条管线各自的 RTF、句后延迟和峰值 RSS。
- VAD 检测语音样本数、零检测样本数、语音段数、语音覆盖率和实际 ASR 调用次数。

正式门槛只接受 `product-meeting` 证据。合成静音可验证设备执行、零片段和报告结构，
但不得替代真实噪声、远场和语音首尾样本。

质量编排支持 `-VadPreflight`：复用同一语料校验、Android 上传、官方 VAD 和临时目录
清理流程，但不加载 Base/Small、不运行 ASR，也不输出转录正文。预检可输出每个 VAD
区间的相对时间边界，帮助准备人工审核包；由于独立片段的 flush 上下文会改变 VAD
判定，预检结果不得自动升级为 `product-meeting` 标签或关键事实真值。

2026-07-31 在 API 36 x86_64 模拟器执行 20 段数字静音烟测：

- Base/Small × Baseline × 固定窗口/VAD 共生成 80 条原始观测；
- 固定窗口 Base 和 Small 均在 20/20 段静音上输出文本；
- VAD 分段 Base 和 Small 均为 0/20 静音误输出；
- 报告保留 `synthetic-smoke`、`generated-digital-silence` 来源，噪声下降率和关键事实
  召回保持 `null`。

该结果证明 Android 原生双管线与证据隔离可执行，不是噪声幻觉下降 80% 或产品识别质量
通过的证据。

同日用固定 revision 的 ASCEND 20 段自然短语音执行 schema 4 Base A/B：

| 指标 | 生产默认 `vad-segmented-v1` | 候选 `vad-recall-035-v1` |
|---|---:|---:|
| 零语音检测样本 | 12/20 | 0/20 |
| 检测语音覆盖率 | 34.65% | 97.71% |
| ASR 调用次数 | 8 | 20 |
| 空文本率 | 60% | 0% |
| 完整参考句召回 | 0% | 15.79% |
| RTF P50（模拟器） | 0.020 | 8.070 |
| 句后延迟 P95（模拟器） | 24.17 秒 | 20.37 秒 |

同版本候选再跑 20 段数字静音，结果为 20/20 零语音检测、0 次 ASR、0 次静音误报。
这证明候选解决了本组短语音漏检且保住数字静音基础防线，但没有覆盖真实背景噪声、
远场和语音首尾，因此生产仍使用官方默认参数。产品会议语料补齐后，必须把固定窗口、
生产默认 VAD 和候选 VAD 放在同一报告中比较，只有噪声幻觉下降至少 80% 且关键事实
不回退才允许切换。

同一 ASCEND 样本和候选 VAD 的 Base/Small 对照：

| 指标 | Base | Small |
|---|---:|---:|
| 零语音检测样本 | 0/20 | 0/20 |
| 检测语音覆盖率 | 97.71% | 97.71% |
| 空文本率 | 0% | 0% |
| 完整参考句召回 | 15.79% | 26.32% |
| RTF P50（模拟器） | 8.070 | 28.390 |
| RTF P95（模拟器） | 15.925 | 59.885 |
| 峰值 RSS | 713,633,792 bytes | 1,010,302,976 bytes |

Small 在严格整句回归上提高 10.53 个百分点，但模拟器 P50 RTF 约为 Base 的 3.5 倍，
峰值 RSS 多约 283 MiB。该数据支持保留“Base 内置、Small 按需下载”的模型组合，不支持
会中自动换模或混合转录。

同日执行 20 段、共 60 秒的确定性非语音三管线回归：

| 指标 | 固定窗口 | 生产默认 VAD | 候选 VAD |
|---|---:|---:|---:|
| 噪声幻觉样本 | 18/20 | 0/20 | 0/20 |
| 零语音检测样本 | 不适用 | 20/20 | 20/20 |
| ASR 调用次数 | 40 | 0 | 0 |
| 空文本率 | 10% | 100% | 100% |
| 相对固定窗口幻觉下降 | 基线 | 100% | 100% |
| RTF P50（模拟器） | 11.880 | 0.022 | 0.023 |
| 峰值 RSS | 706,105,344 bytes | 509,595,648 bytes | 400,277,504 bytes |

固定窗口在 white noise、fan-like noise 和 impulsive clicks 上均为 5/5 误输出，
在 electrical hum 上为 3/5；两套 VAD 对全部 20 段均未创建 ASR 任务。报告共
60 条 schema 4 观测和 60 个 transcript 引用，manifest SHA-256 为
`dd0029cd90ef0361c7337c6daf6dd609e8f0bdb975cdfc7034e42ef102be330d`。
该结果证明 VAD 对这组确定性非语音的工程防线有效；由于证据类别是
`synthetic-smoke`，仍不能关闭“真实噪声幻觉下降至少 80%”的产品门槛。

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
