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
  非空的 `provenance.sourceId`、`provenance.licenseId`，并强制绑定
  `reviewAttestationSha256` 与 `reviewedAtUtc`；
- 仓库外或 `.spike/` 中的正式去敏矩阵，通过 `pathEnv` 引用：至少 20 段
  `silence`、20 段 `noise-only` 和 20 段带关键事实的 `speech`；语音必须同时包含
  `speech-boundary-start` 与 `speech-boundary-end` 样本；
- raw observations 必须带 model/version/profile、推理耗时、句后延迟、关键事实、
  静音/噪声输出、RSS、能耗、温控、`pipelineId` 和 ASR 调用次数；VAD 管线还必须
  带检测语音段数与时长。无法从模拟器取得的能耗/温控必须为 `null`。
- 无语音噪声样本使用 `noise-only`；“语音 + 背景噪声”不得使用该标签。

Android x86_64 模拟器完整执行：

```powershell
& .\tool\benchmarks\run_android_whisper_quality_batches.ps1 `
  -CorpusManifest <私有正式语料清单> `
  -EnvironmentFile <私有 pathEnv 映射> `
  -DeviceId emulator-5554 `
  -SmallModelPath <ggml-small-q5_1.bin> `
  -Pipelines fixed-window,vad-segmented,vad-recall
```

默认比较 Base/Small × Baseline/Preview/Final。可用
`-Profiles baseline,preview,final` 明确选择 Profile，并默认对每个组合执行
`fixed-window-v1`、`vad-segmented-v1` 和 `vad-recall-035-v1`；每个组合必须完整
覆盖同一批语料。批处理入口将每个模型/Profile/Pipeline 组合独立落盘；重新执行时，
只有 manifest SHA-256、模型、Profile、Pipeline、设备指纹、API、线程数、样本数、
原始观测和通过报告全部一致的批次才会复用。全部批次完成后，合并器拒绝重复观测、
缺样本、设备口径漂移和语料证明不一致，复算每条私有 transcript SHA-256、重写并
校验引用，再生成完整矩阵报告。即使直接聚合单批，聚合器也要求原始观测和 transcript
位于 `.spike/`，逐条复算内容哈希，并拒绝重复引用。单批内部仍由
`run_android_whisper_quality_benchmark.ps1` 执行。
无效或参数不匹配的旧批次不会被原地清空：新运行先写入独立 attempt 目录，完整校验
通过后才切换；被替换批次保留在私有 `superseded/` 目录，便于失败恢复和人工审计。
设备证明同时包含 API/ABI 类别和 adb serial 的 12 位 SHA-256 指纹，避免把两个不同
的同版本模拟器误合并为“同一设备”，又不会把原始 serial 写入可提交报告；Android
物理设备仍会被底层 qemu 与 x86_64 检查拒绝。

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

对新语料先执行不加载 ASR 模型的 VAD 预检：

```powershell
& .\tool\benchmarks\run_android_whisper_quality_benchmark.ps1 `
  -CorpusManifest <仓库外语料清单> `
  -DeviceId emulator-5554 `
  -Pipelines @("vad-segmented", "vad-recall") `
  -VadPreflight `
  -RequiredEvidenceClass <语料证据类别> `
  -OutputDirectory .spike/results/whisper-quality/vad-preflight
```

`-VadPreflight` 禁止固定窗口和 ASR 模型，只输出 VAD 段数、相对时间边界、耗时与
峰值 RSS，不生成转录正文，也不调用质量聚合或发布证据推广。它用于发现切分和标签
问题，不能把 VAD 自身判定当作语料真值；`silence`、`noise-only`、关键事实和去敏状态
仍必须由独立人工复核确认。

### 3.1 私有候选语料的人工复核与晋升

候选切片必须保持 `evidenceClass=synthetic-smoke`、`deidentified=false`。先生成
默认全部未批准的复核证明模板：

```powershell
dart run tool/benchmarks/create_whisper_review_attestation_template.dart `
  --candidate-manifest <候选 manifest.private.json> `
  --environment <environment.private.json> `
  --repository-root . `
  --output <.spike/.../review-attestation.template.private.json>
```

模板中的 `candidateSuggestion` 只用于定位，不是标签真值。人工逐段试听后必须：

- 为每段明确填写布尔值 `approved` 和 `containsSensitiveData`，不能保留模板中的
  `null`；
- 只对确认可用且不含敏感信息的片段设置 `approved=true`，填写
  `reviewedClass`；为每段获批 `speech` 写入至少一个可在原文中匹配的
  `expectedKeyFacts`；
- 对敏感、误分类或质量不足的片段设置 `approved=false`；该片段不会写入正式
  manifest，且不得填写关键事实或语音首尾边界；
- 至少各确认一段 `boundaryStart=true` 和 `boundaryEnd=true`；
- 使用不含姓名的 `reviewedByRole`，填写 UTC 复核时间，并只在全部样本完成去敏确认后
  设置 `deidentificationAttested=true`。

把完成的模板另存为私有复核证明后执行：

```powershell
dart run tool/benchmarks/promote_reviewed_whisper_corpus.dart `
  --candidate-manifest <候选 manifest.private.json> `
  --review-attestation <review-attestation.private.json> `
  --environment <environment.private.json> `
  --repository-root . `
  --output <.spike/.../product-meeting-manifest.private.json>
```

晋升器默认拒绝覆盖文件，并要求候选 manifest SHA-256、样本 ID 集合以及每段人工结论
全部完整；未批准片段会被剔除，获批片段仍须满足分类、去敏、事实和边界约束。过滤后的
正式集合必须继续满足每类至少 20 段和语音首尾覆盖。输出只保留人工结论，固定为
`evidenceClass=product-meeting`、`deidentified=true`，并在 provenance 中绑定复核证明
SHA-256 和复核 UTC 时间；复核人姓名、音频、转录草稿和逐条私有证明不得提交。
ASR 草稿、VAD 结果或文件名都不能自动填充 `approved`、去敏状态或正式标签。

当前本地审阅包位于 `.spike/review/product-meeting-07-29-vad-informed-surplus/`，
共 90 段（每类 30 段），并已在同一 API 36 x86_64 模拟器上完成生产 VAD 与召回候选
VAD 的 180 条预检观测。模板保持 0/90 批准；人工完成前不得生成正式产品证据。

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

同日执行 20 段、每段 3 秒的 `synthetic-smoke` 完整矩阵时，Base 的 9 个
Profile/Pipeline 组合全部完成；Small Baseline 固定窗口在第 5 段高强度白噪声前返回
`asr.whisper.inference_failed`，因此矩阵保持 No-Go，未生成伪完整报告。失败前 4 段
各执行 2 次 ASR，单段推理耗时 161.1～305.9 秒、句后延迟 84.9～231.6 秒，观测峰值
RSS 达 988,631,040 bytes。该结果只证明当前 x86_64 模拟器上的 Small 固定窗口性能与
稳定性不达标，不外推为 Android 真机结论，也不通过删样本、提高模拟器内存或混合线程
数规避。原生日志现保留 `whisper.cpp` 非零返回码；批处理失败时会把 failed batch、
attempt 引用和私有日志 SHA-256 写入 `batch-progress.json`。

另以 20 段 1 秒合成非语音完成失败恢复与发布切换烟测：证据类别故意不匹配时，
`batch-progress.json` 正确记录 `failed`；有效 Base VAD 批次在线程数从 2 变为 3 时，
新 attempt 完整校验后才切换，线程数 2 的旧结果保留在 `superseded/`，最终合并
20 条观测并写出 `passed` 的 `batch-run.json`。

正式 `product-meeting` 执行完成后，编排脚本会调用
`build_phase_0_4_quality_input.dart`，按字段白名单把不含音频、绝对路径、正文、
transcript 引用或逐条私有观测的聚合报告推广到
`docs/quality/evidence/product-meeting/quality-report.json`，绑定 SHA-256 并更新
阶段 0～4 输入和报告。任何质量失败或矩阵缺项都会以非零退出码结束。
批次状态保存在 `batch-progress.json`，最终证明保存在 `batch-run.json`；二者及
`batches/`、合并前后的原始观测都属于 `.spike/` 私有产物，不得提交。

## 4. Hard Gate 2

| 条件 | 状态 |
|---|---|
| 版本化 ABI、边界校验、生成绑定 | 通过 |
| Base/Small/Preview/Final 可用精确 Profile ID 端到端评测 | 通过 |
| 固定窗口与 VAD 分段按同设备/模型/Profile 对照 | 通过：聚合器输出噪声幻觉下降率及关键事实召回变化 |
| Base 关键事实召回不低于阶段 0 | `blocked`：缺少真实语料 |
| Small 关键事实召回不低于 Base | `blocked`：缺少真实语料矩阵；当前模拟器的合成噪声固定窗口另有推理失败，候选不得激活 |
| Small 固定窗口模拟器稳定性 | `No-Go`：20 段合成噪声只完成 4 段，第 5 段前推理失败；保留私有日志与部分观测 |
| Preview 句后延迟 P95 ≤ 3 秒 | `blocked`：缺少真实语料 |
| 100 次 context 生命周期无持续增长 | 通过：第 10→100 次 RSS +6,242,304 bytes，小于 32 MiB 上限 |

在全部阻断项有原始报告前，候选 Profile 不得切换为默认。
