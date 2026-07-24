# Step 12：Silero VAD 与预览队列

> 状态：已完成
> 日期：2026-07-24

## 本轮结果

- `SileroVadSegmenter` 只通过官方 `sherpa_onnx` Dart API 使用 `VoiceActivityDetector`，没有新增 JNI、FFI 或手工原生库。
- 已将官方 `silero_vad.int8.onnx` 作为 APK 内置资产：`212,860` 字节，SHA-256 为 `c36d490aff5ab924ca6c7aeec4d8f6bd3d22db6fa17611b9c5b17eae58ac3a20`。
- 独立 VAD Manifest 固定模型版本 `2025-07-11`、GitHub release asset ID `271935990`、来源时间戳、16 kHz/512 样本契约、许可路径和完整性信息。
- `BundledSileroVadModelService` 从 Flutter asset 复制到应用私有临时目录，严格校验文件集、大小和 SHA-256 后原子切换；已正确准备时直接复用。
- 官方配置固定为 16 kHz、单线程 CPU、512 样本窗口、15 秒最大语音段；模型路径由上层装配，文件不存在时拒绝创建。
- `AsrPreviewWindowPlanner` 默认加入前后各 200 ms 上下文；超过 15 秒时按 500 ms 重叠确定性切分。
- `AsrPreviewCoordinator` 实现 PCM16 解码、统一全局样本时间轴、20 秒滚动缓冲、VAD 分段和双模型无关的 Engine 投递。
- 预览队列按排队音频时长计量：默认最大 30 秒、高水位 15 秒、低水位 5 秒；超限时丢弃最旧待处理窗口，回落到低水位后恢复。
- 指标暴露 `vadSegmentCount`、`queuedAudioMs`、`processedPreviewWindows`、`droppedPreviewWindows`、`previewLagMs` 和最后错误码。
- Engine 或 VAD 失败后进入 `recordingOnly`，停止后续预览推理，但 `RecordingPreviewSink.add` 不向可靠录音链传播异常。
- 重叠窗口使用最长“前一文本后缀 / 后一文本前缀”规则合并，并以同一稳定片段 ID 发出修订。

## 关键测试

- 前后文扩展不越过事实音频范围。
- 16 秒语音确定性切为 `0–15 s` 与 `14.5–16 s`。
- 两个不同模型收到完全相同的 VAD 全局区间。
- 高水位时只丢最旧待处理预览窗口，事实音频接口不受影响；低水位时恢复 `ready`。
- Engine 失败后进入 `recordingOnly`，后续 PCM 不再进入 VAD/ASR。
- 官方 VAD 局部样本位置在 reset 后正确映射到全局时间轴。
- VAD 权重损坏时不形成最终目录，Manifest 偏离 16 kHz 固定契约时拒绝解析。
- Android 使用真实内置权重连续两轮完成初始化、512 样本连续输入、尾段 `flush`、释放和资产复用。

## 验证

```powershell
dart format lib test
flutter analyze --no-pub
flutter test --no-pub
flutter build apk --debug --no-pub
```

- Step 12 单元测试：16/16 通过。
- 全量自动化测试：173/173 通过。
- 静态分析：0 issue。
- Debug APK：构建通过。
- APK 检查：VAD Manifest、NOTICE、MIT 文本和 ONNX 权重均存在；包内权重为 `212,860` 字节且 SHA-256 匹配。
- Android 16 x86_64 模拟器集成测试：1/1 通过，官方 VAD 两轮初始化和释放成功。
- 构建只保留 `flutter_foreground_task` 的上游 Built-in Kotlin 迁移警告。

## 后续边界

- Step 13 负责把 Coordinator 装配到真实录音流程，并在会中 UI 呈现 `ready`、`backlogged` 和 `recordingOnly`。
- 实体 Android 设备上的真实麦克风阈值、噪声环境、温控和功耗校准属于 Step 13 端到端验收，不改变本步骤固定的模型和队列契约。

官方模型与配置参考：[sherpa-onnx Silero VAD 文档](https://k2-fsa.github.io/sherpa/onnx/vad/silero-vad.html)。
