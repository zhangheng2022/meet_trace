# Step 07 可靠录音与崩溃恢复

> 状态：已完成
>
> 日期：2026-07-24
>
> 分支：`codex/alpha-step-07-reliable-recording`

## 结论

Step 07 已建立独立于 ASR 的事实录音主链，覆盖 FR-003、FR-010 和 AT-02～AT-06。实现只使用官方 `record` Flutter/Dart API 与公开 Android 前台服务插件，没有自建 JNI、FFI/C API、C/C++ 构建链或 sherpa-onnx 原生桥接。

## 实现证据

- `RecordPcmAudioCapture` 固定请求 16 kHz、单声道、PCM16；来电和音频焦点采用 `AudioInterruptionMode.pauseResume`。
- 每个 PCM 块按“文件写入并 flush → 双代 checkpoint → preview”提交。
- preview sink 有界且非阻塞；阻塞、抛错或满载不影响事实文件。
- 支持权限与 128 MiB 空间预检、暂停、恢复、显式 flush、停止和临时文件原子封存。
- 启动恢复会对齐 PCM16 样本边界，封存异常退出的可恢复音频，按真实字节数写入时长并进入处理态。
- Android Manifest 声明麦克风、前台服务、通知和 wake lock 权限，前台服务类型为 `microphone`。

## 测试先行证据

先建立以下失败测试，再实现生产代码：

- 每块必须在文件与 checkpoint 可见后才到达 preview。
- preview 阻塞或抛错不阻塞事实写入。
- 暂停/恢复时间轴连续。
- 权限拒绝与空间不足不创建临时音频。
- 30 分钟 PCM 文件完整率 100%。
- checkpoint 双代恢复、PCM16 对齐、官方录音参数和 Android Manifest 边界。
- 异常退出残留尾字节可恢复，会议得到正确音频时长。

Step 07 新增或扩展 10 项自动化测试；全量共 105 项。

## 真机结果

设备：Mi 10，Android 11（API 30），`arm64-v8a`。

录音启动后通过 ADB HOME 键将应用切到桌面，保持后台至测试结束：

```json
{
  "recordingSeconds": 30,
  "fileBytes": 960000,
  "persistedBytes": 960000,
  "persistenceRatio": 1.0,
  "captureCompletenessRatio": 0.9995814252781647,
  "droppedPreviewChunks": 0
}
```

同一测试还确认最终 checkpoint 为 `finalized`，记录字节数与封存文件一致。

## 已运行验证

```text
dart format lib test integration_test
flutter analyze --no-pub
flutter test --no-pub
flutter build apk --debug --no-pub
flutter test --no-pub integration_test/reliable_recording_test.dart -d 3f842cd0 --dart-define=MEETILY_RECORDING_SECONDS=30
```

- 格式化：通过。
- 静态分析：通过，0 issue。
- 自动化测试：105/105 通过。
- 30 分钟合成 PCM：`57,600,000` 字节，文件完整率 100%。
- Debug APK：构建通过。
- Mi 10 后台真机测试：通过。

## 兼容性与剩余风险

- `path_provider_android` 2.3.x 的 JNI 路径在当前 Android 11 Mi 10 上触发过 `libdartjni.so` SIGSEGV，当前固定 2.2.23；升级必须复跑真机测试。
- `flutter_foreground_task` 10.0.0 与 `storage_space` 1.2.0 在 Flutter 3.44.7 构建时仍有旧式 Kotlin Gradle Plugin 警告；当前构建成功，但 Flutter 后续版本升级前需要先验证插件兼容性。
- 本步骤真机覆盖 30 秒后台录音；30 分钟完整率由实际文件写入的合成 PCM 测试验证。30 分钟锁屏、来电和强制终止的端到端真机矩阵继续在 Step 18 发布门槛执行。
