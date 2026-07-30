# Step 22：Whisper 解码参数评测

> 状态：工程能力完成，真实语料评测 `blocked`
> 日期：2026-07-30

## 1. 已实现能力

- C ABI 版本固定为 `1`，配置结构携带 `struct_size` 和 `abi_version`。
- 原生边界校验 thread、Greedy/Beam、best-of、beam-size、上下文、空白抑制、
  temperature fallback、language 和 initial prompt。
- 非法 ABI、结构大小、策略、参数和模型加载分别返回稳定状态码。
- Dart 绑定由 `dart run tool/ffigen.dart` 生成；生成文件不手工编辑。
- 每个识别窗口记录 `profileId`，便于把原始结果追溯到精确配置。

## 2. 候选 Profile

| ID | 用途 | 策略 | 关键参数 | 当前是否启用 |
|---|---|---|---|---|
| `baseline-fixed-greedy-v1` | 阶段 0 基线 | Greedy | best-of 5，temperature increment 0.2 | 是 |
| `preview-greedy-low-latency-v1` | 预览候选 | Greedy | best-of 1，不做 temperature fallback | 否 |
| `final-beam-quality-v1` | 最终候选 | Beam | beam-size 5，temperature increment 0.2 | 否 |

真实 20 段去敏语料尚未注入，因此 Preview 和 Final 候选只作为可评测配置存在。
生产 Factory 对会中和最终转录都继续选择 `baseline-fixed-greedy-v1`，避免把未经指标
验证的候选配置默认为质量提升。

## 3. 可复现评测

输入契约：

- `tool/benchmarks/whisper_corpus_manifest.example.json`
- corpus manifest schema `2`；正式执行要求 `evidenceClass=product-meeting` 以及
  非空的 `provenance.sourceId`、`provenance.licenseId`；
- 仓库外或 `.spike/` 中的正式去敏矩阵，通过 `pathEnv` 引用：至少 20 段
  `silence`、20 段 `noise-only` 和 20 段带关键事实的 `speech`；语音必须同时包含
  `speech-boundary-start` 与 `speech-boundary-end` 样本；
- raw observations 必须带 model/version/profile、推理耗时、句后延迟、关键事实、
  静音/噪声输出、RSS、能耗、温控、`pipelineId` 和 ASR 调用次数；VAD 管线还必须
  带检测语音段数与时长。无法从模拟器取得的能耗/温控必须为 `null`。
- 无语音噪声样本使用 `noise-only`；“语音 + 背景噪声”不得使用该标签。

Android x86_64 模拟器完整执行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass `
  -File tool/benchmarks/run_android_whisper_quality_benchmark.ps1 `
  -CorpusManifest <仓库外语料清单> `
  -DeviceId emulator-5554 `
  -SmallModelPath <ggml-small-q5_1.bin> `
  -Pipelines fixed-window,vad-segmented,vad-recall
```

默认比较 Base/Small × Baseline/Preview/Final。可用
`-Profiles baseline,preview,final` 明确选择 Profile，并默认对每个组合执行
`fixed-window-v1`、`vad-segmented-v1` 和 `vad-recall-035-v1`；每个组合必须完整
覆盖同一批语料。
脚本验证语料和 Small 权重，推送临时设备副本，静默捕获包含正文的私有日志，写出
transcript 引用，再调用 schema `4` 聚合器生成 JSON/CSV。schema 4 会拒绝旧 v3
观测以及缺少 VAD 可观测字段的输入。固定窗口句后延迟按每段中
最慢的端到端识别往返加 2 秒窗口等待统计；VAD 分段句后延迟包含 1 秒生产稳定裕量、
分段和最慢语音区间的识别往返。两者都包含 isolate 投递和结果返回；RSS 在分段和推理
期间每 50 ms 采样。该口径是设备离线评测的保守估算，阶段 5 仍需以真实时间录音验证
用户感知延迟。

`-RequiredEvidenceClass` 默认为 `product-meeting`。公开语料和合成音频只能在明确传入
`public-regression` 或 `synthetic-smoke` 时运行，其报告保留证据类别，不能用于关闭
产品质量门槛。

固定版本 ASCEND 公开回归可直接执行：

```powershell
& .\tool\benchmarks\run_ascend_android_regression.ps1 `
  -DeviceId emulator-5554 `
  -Models @("base") `
  -Profiles @("baseline") `
  -Pipelines @("vad-segmented", "vad-recall")
```

下载器默认从固定 revision 的 validation 前 100 行选择 20 段 1～3 秒语音，并把
全部私有产物限制在 `.spike/`。`vad-recall` 映射到
`vad-recall-035-v1`（threshold 0.35、min speech 100 ms、pad 100 ms），仅是评测
候选；生产 `WhisperVadConfig` 默认值没有改变。

确定性非语音三管线回归可直接执行：

```powershell
& .\tool\benchmarks\run_synthetic_noise_android_regression.ps1 `
  -DeviceId emulator-5554 `
  -Models @("base") `
  -Profiles @("baseline")
```

脚本默认生成 20 段 3 秒非语音噪声，并比较 `fixed-window-v1`、
`vad-segmented-v1` 和 `vad-recall-035-v1`。其证据类别固定为 `synthetic-smoke`；
即使 VAD 完全拦截合成噪声，也不能用于关闭产品会议的噪声幻觉门槛。

已有合规原始观测时仍可直接执行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass `
  -File tool/benchmarks/run_whisper_quality_matrix.ps1 `
  -CorpusManifest <仓库外语料清单> `
  -RawObservations <原始观测 JSON>
```

输出位于 `.spike/results/whisper-quality/`，不提交原始音频、私有设备清单、日志或转录
正文。2026-07-31 已在 API 36 x86_64 模拟器完成新 integration test 的编译、安装和
缺参跳过检查，并完成 Base/Small 的 20 段 ASCEND 双 VAD schema 4 回归；公开回归
不替代真实产品会议质量评测。

正式 `product-meeting` 执行完成后，编排脚本会调用
`build_phase_0_4_quality_input.dart`，按字段白名单把不含音频、绝对路径、正文、
transcript 引用或逐条私有观测的聚合报告推广到
`docs/quality/evidence/product-meeting/quality-report.json`，绑定 SHA-256 并更新
阶段 0～4 输入和报告。任何质量失败或矩阵缺项都会以非零退出码结束。

## 4. Hard Gate 2

| 条件 | 状态 |
|---|---|
| 版本化 ABI、边界校验、生成绑定 | 通过 |
| Base/Small/Preview/Final 可用精确 Profile ID 端到端评测 | 通过 |
| 固定窗口与 VAD 分段按同设备/模型/Profile 对照 | 通过：聚合器输出噪声幻觉下降率及关键事实召回变化 |
| Base 关键事实召回不低于阶段 0 | `blocked`：缺少真实语料 |
| Small 关键事实召回不低于 Base | `blocked`：Small 模拟器原生冒烟已通过，但缺少真实语料矩阵 |
| Preview 句后延迟 P95 ≤ 3 秒 | `blocked`：缺少真实语料 |
| 100 次 context 生命周期无持续增长 | 通过：第 10→100 次 RSS +6,242,304 bytes，小于 32 MiB 上限 |

在全部阻断项有原始报告前，候选 Profile 不得切换为默认。
