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
- 仓库外不少于 20 段的去敏音频，通过 `pathEnv` 引用；
- raw observations 必须带 model/version/profile、推理耗时、句后延迟、关键事实、
  静音/噪声输出、RSS、能耗和温控信息。

执行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass `
  -File tool/benchmarks/run_whisper_quality_matrix.ps1 `
  -CorpusManifest <仓库外语料清单> `
  -RawObservations <原始观测 JSON>
```

输出位于 `.spike/results/whisper-quality/`，不提交原始音频或转录正文。

## 4. Hard Gate 2

| 条件 | 状态 |
|---|---|
| 版本化 ABI、边界校验、生成绑定 | 通过 |
| Base/Small/Preview/Final 可用精确 Profile ID 评测 | 通过 |
| Base 关键事实召回不低于阶段 0 | `blocked`：缺少真实语料 |
| Small 关键事实召回不低于 Base | `blocked`：缺少真实语料和本机 Small 权重 |
| Preview 句后延迟 P95 ≤ 3 秒 | `blocked`：缺少真实语料 |
| 100 次 context 生命周期无持续增长 | 通过：第 10→100 次 RSS +6,242,304 bytes，小于 32 MiB 上限 |

在全部阻断项有原始报告前，候选 Profile 不得切换为默认。
