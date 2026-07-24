# Step 01 双模型真机 Spike

> 状态：进行中
> 更新日期：2026-07-24
> 对应步骤：[Codex Alpha 开发步骤 — Step 01](../Codex_Alpha_开发步骤.md#step-01双模型真机-spikeday-1-gono-go)

## 1. 当前结论

当前结论为**预备 Conditional Go**，Step 01 仍保持“进行中”。

- 官方 `sherpa_onnx` 1.13.4 已通过公开 Dart API 接入，仓库没有新增 JNI、FFI/C API 绑定、C/C++ 构建链、`jniLibs` 或 `DynamicLibrary.open`。
- Debug APK 已成功构建并完成 ABI/内容检查。
- Mi 10 首轮真机测试中，ASR 在独立 Isolate 工作时 30 秒麦克风 PCM16 录音连续性断言通过。
- 首轮将 5 分钟音频作为单个离线 utterance 输入，Paraformer 返回空文本；改为固定窗口后，两个模型均完成两次创建、识别、读取结果和释放。
- 最终合并复跑按“录音并发 → Paraformer → Qwen3-ASR”执行，2 个真机测试全部通过，用时 8 分 03 秒。
- 30.138 秒录音写入 960,000 字节，完整率 99.54%。
- Paraformer 30 秒窗口基线每轮有 3/10 空结果；同一 300 秒音频改为 15 秒窗口后，两轮均为 20/20 可读、0 空结果。上游模型说明建议单段输入短于 20 秒，正式实现据此采用 15 秒硬上限并保留逐窗口诊断。
- Paraformer 15 秒窗口两次 RTF 约 0.0214，首个窗口结果为 317～324 ms，峰值 RSS 约 455 MiB。
- Qwen3-ASR 两次 RTF 为 0.688/0.707，首个窗口结果为 18.5/20.4 秒，峰值 RSS 约 2.92 GiB。前一轮在同一进程先加载 Qwen、后录音时曾触发系统低内存回收；高级模型必须增加设备能力门槛和明确的性能提示。
- Spike 已记录每个窗口的起止时间、耗时、字符数和可读状态，不保存转录正文；不得用汇总文本可读掩盖局部失败。
- 当前 5 分钟样本由官方公开测试语音循环生成，只能作为技术冒烟，不能替代 PRD 要求的去敏会议样本和低端设备评测。

## 2. 固定版本与输入

| 项目 | 值 |
|---|---|
| Flutter / Dart | Flutter 3.44.7 / Dart 3.12.2 |
| 官方包 | `sherpa_onnx` 1.13.4 |
| 录音包 | `record` 7.1.1 |
| 主开发设备 | Xiaomi Mi 10，Android 11 / API 30，`arm64-v8a`，约 8 GB RAM |
| 标准模型 | `sherpa-onnx-paraformer-zh-small-2024-03-09` |
| 高级模型 | `sherpa-onnx-qwen3-asr-0.6B-int8-2026-03-25` |
| 技术冒烟音频 | 300 秒、16 kHz、单声道 PCM16 WAV，9,600,044 字节 |
| 离线识别窗口 | 当前统一 15 秒；保留 30 秒全模型基线 |
| 重复次数 | 每个模型 2 次 |

模型、样本和原始运行结果只存放在被 Git 忽略的 `.spike/`，不提交音频或下载模型。

## 3. 模型文件证据

模型由 `tool/benchmarks/download_step01_models.ps1` 从 sherpa-onnx 官方 Release 下载。脚本校验归档字节数，解压后生成逐文件 SHA-256 清单 `.spike/model-files.json`。

| 模型 | 归档字节数 | Spike 运行必需文件字节数 | 必需文件 |
|---|---:|---:|---|
| Paraformer INT8 | 77,920,048 | 81,904,027 | `model.int8.onnx`、`tokens.txt` |
| Qwen3-ASR 0.6B INT8 | 878,702,423 | 987,015,347 | `conv_frontend.onnx`、`encoder.int8.onnx`、`decoder.int8.onnx`、tokenizer 三文件 |

许可状态：

- `sherpa_onnx` 包及 sherpa-onnx 项目为 Apache-2.0。
- Qwen3-ASR 上游仓库声明 Apache-2.0。
- Paraformer 原始上游模型的 ModelScope 元数据标记为 Apache-2.0；sherpa-onnx 下载归档指向的转换模型上传页未填写 License 字段，归档也没有独立 LICENSE。
- FunASR 当前仓库代码采用 MIT，同时另有独立 `MODEL_LICENSE`。发布前必须确认转换归档适用的模型条款，随 APK 保存来源、许可证和 NOTICE；本项仍未关闭。
- 2026-07-24 再次通过 ModelScope API 复核精确转换来源：`License`、`LicenseName`、`LicenseLink` 均为空。sherpa-onnx 文档确认转换来源和下载归档，但不能替代权重许可，因此 Step 05 不提交真实资产。

证据链接：[sherpa-onnx LICENSE](https://github.com/k2-fsa/sherpa-onnx/blob/master/LICENSE)、[Paraformer 原始上游模型](https://www.modelscope.cn/models/iic/speech_paraformer_asr_nat-zh-cn-16k-common-vocab8358-tensorflow1/summary)、[转换模型上传页](https://www.modelscope.cn/models/crazyant/speech_paraformer_asr_nat-zh-cn-16k-common-vocab8358-onnx/summary)、[FunASR MODEL_LICENSE](https://github.com/modelscope/FunASR/blob/main/MODEL_LICENSE)。

## 4. APK 检查

`tool/benchmarks/inspect_debug_apk.ps1` 对当前 Debug APK 的检查结果：

| 项目 | 结果 |
|---|---|
| APK 字节数 | 236,352,699 |
| ABI | `arm64-v8a`、`armeabi-v7a`、`x86_64` |
| sherpa-onnx / ONNX Runtime | 每个 ABI 各一份对应库，未发现可疑重复 |
| 模型文件 | 未包含 Paraformer 或 Qwen3-ASR 模型，符合 Step 01/Step 05 尚未内置模型的当前阶段 |
| 高级模型 | APK 中不存在 |

通用 Debug APK 体积不是 Alpha 发布体积；Step 05 内置标准模型、Step 18 确定 ABI 拆分后必须重测。

## 5. 双模型真机指标

原始全模型基线使用相同 300 秒技术冒烟音频、30 秒固定窗口、CPU 两线程：

| 模型/轮次 | 初始化 | 总推理 | RTF | 首个窗口结果 | 可读窗口 | 结果字符数 | 峰值 RSS |
|---|---:|---:|---:|---:|---:|---:|---:|
| Paraformer #1 | 1.300 s | 7.245 s | 0.0242 | 0.785 s | 7/10 | 413 | 505,032,704 B |
| Paraformer #2 | 1.257 s | 7.232 s | 0.0241 | 0.779 s | 7/10 | 413 | 505,032,704 B |
| Qwen3-ASR #1 | 4.987 s | 206.367 s | 0.6879 | 18.508 s | 10/10 | 1,723 | 3,132,452,864 B |
| Qwen3-ASR #2 | 5.475 s | 211.957 s | 0.7065 | 20.388 s | 10/10 | 1,723 | 3,132,452,864 B |

Paraformer 修复复测使用同一音频、15 秒固定窗口、CPU 两线程：

| 模型/轮次 | 初始化 | 总推理 | RTF | 首个窗口结果 | 可读窗口 | 结果字符数 | 峰值 RSS |
|---|---:|---:|---:|---:|---:|---:|---:|
| Paraformer #1 | 1.283 s | 6.413 s | 0.02138 | 0.324 s | 20/20 | 1,536 | 477,331,456 B |
| Paraformer #2 | 1.251 s | 6.420 s | 0.02140 | 0.317 s | 20/20 | 1,536 | 477,331,456 B |

运行结束电池温度读数为 36.5°C。单次短测不能代替持续温控与能耗评测。

这些结果只证明：

- 官方公开 Dart API 可配置并运行两个目标模型；
- 两个识别器都能释放后重新创建；
- Qwen3-ASR 在 Mi 10 上可完成离线处理，但不满足“句后准实时”，且内存风险显著；
- 当前样本不是会议语料，字符数不能用于比较准确率。
- Paraformer 的 30 秒窗口超出[上游建议的单段长度](https://www.modelscope.cn/models/iic/speech_paraformer_asr_nat-zh-cn-16k-common-vocab8358-tensorflow1/summary)；缩短到 15 秒后空结果稳定消失。正式 VAD 仍须在会议语料验证切分和重叠合并。

## 6. 录音解耦证据

真机集成测试使用 `record` 以 16 kHz、单声道 PCM16 采集 30 秒；同时在独立 Isolate 运行 Paraformer 识别。测试要求：

- 写入字节数大于 0；
- `bytesWritten / expectedBytes >= 0.98`；
- ASR 工作异常通过独立 Future 汇报，不直接终止录音采集与文件关闭。

最终合并复跑写入 960,000 字节，按实际 30.138 秒计算的期望值为 964,434 字节，完整率 99.54%，两个断言均通过。该证据证明当前 Spike 调度没有阻断 30 秒录音，但不等于 Step 07 的 30 分钟、后台、来电、空间不足和崩溃恢复验收。

## 7. 自动化与可重复执行

```powershell
flutter pub get
dart format lib test integration_test
flutter analyze
flutter test
flutter build apk --debug
.\tool\benchmarks\inspect_debug_apk.ps1
.\tool\benchmarks\download_step01_models.ps1
dart run tool/benchmarks/build_spike_sample.dart <输出.wav> 300 <源.wav...>
.\tool\benchmarks\run_android_step01_spike.ps1 -DeviceId <device-id>
```

当前已通过：

- `flutter analyze`
- `flutter test`：13 个测试
- `flutter build apk --debug`
- APK ABI、重复原生库和模型内容检查
- 首轮 Mi 10 录音连续性断言
- 两个模型各两次 300 秒窗口识别、结果读取和资源释放
- 先录音并发、后双模型的最终合并复跑（2 个测试全部通过）
- Paraformer 15 秒窗口修复复测（两轮各 20/20 可读）

当前未完成：

- 去敏会议样本和低端设备的 RTF、首结果延迟、峰值 RSS、温控原始指标；
- 去敏 5 分钟会议样本复测；
- 4 GB RAM 低端 `arm64-v8a` 设备 Go/No-Go；
- Paraformer 分发许可/NOTICE 闭环。

技术冒烟样本的原始指标已为 Mi 10 保存；仍需在去敏会议样本和低端设备生成对应数据。

## 8. 恢复复测步骤

1. 在 Mi 10 保持屏幕解锁，开启“开发者选项 → USB 调试（安全设置）/USB 安装”，并接受安装确认。
2. 运行 `tool/benchmarks/run_android_step01_spike.ps1`；只复测标准模型时传入 `-ModelFilter paraformer`。
3. 检查被 Git 忽略的 `.spike/results/`：
   - `asr-results.json`
   - `recording-continuity.json`
   - `device-metrics.json`
   - `apk-inspection.json`
4. 确认录音报告先输出，两个模型各有两次 `resultWasReadable: true`，并检查每轮 `emptyWindowCount == 0` 和逐窗口诊断。
5. 换用去敏 5 分钟会议样本重复执行，再补低端设备。
6. 关闭 Paraformer 许可项后，更新本报告与完成看板并签署 Go/Conditional Go/No-Go。
