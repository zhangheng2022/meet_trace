# Step 18 双模型评测与发布门槛

> 2026-07-27 双平台范围说明：本报告只记录既有 Android 证据。当前 PRD 已扩展为
> Android + iOS V0.6；本报告不能单独关闭 AT-17～AT-20 或 Step 19，双平台发布继续
> 保持 `blocked`。iOS 门槛见 [iOS Alpha 设备矩阵](./iOS_Alpha_设备矩阵.md)。

> 状态：进行中，Alpha 发布阻塞
> 更新日期：2026-07-25

## 1. 本轮结论

本轮完成了可执行发布门禁、Android 模拟器真实运行链复测和 APK 审计，但不满足 Alpha 完成定义，当前结论为 `blocked`，不得宣布 Alpha 已完成或公开发布。

将本轮已确认的模型体积和 APK 审计结果输入门禁后，报告为 `2 passed / 0 failed / 20 missing`，CLI 退出码为 `2`。

已确认：

- 标准模型运行资源为 `81,904,027` 字节，满足不超过 100 MiB 的门槛。
- `flutter analyze --no-pub` 无问题，246 项单元/组件测试全部通过。
- Android 16 x86_64 模拟器上的包内 Paraformer Engine、官方 sherpa-onnx adapter 和 Silero VAD 集成测试通过。
- 模拟器 30 秒录音集成测试写入并持久化 `960,512` 字节，持久化比率 `1.0`、采集完整率约 `1.0004`、丢弃预览块为 `0`。
- Debug APK 为 `315,775,937` 字节，包含 `arm64-v8a`、`armeabi-v7a`、`x86_64`；模型、VAD、NOTICE 和 Flutter notices 齐全，没有高级模型权重、录音/数据库文件、重复原生库或疑似永久密钥。

仍缺失：

- 相同 20 段去敏会议语料及原始指标引用。
- 最低目标 4 GB RAM arm64 实体设备。
- 两模型在同一语料、设备和环境下的 RTF、句后延迟、内存、能耗、温控、错误和最终耗时。
- 30 分钟实体设备录音、最终转录、断网、积压、崩溃恢复和证据播放结果。
- 关键事实人工标注与召回率。
- AT-01～AT-16 完整证据表。
- Paraformer 转换权重的公开再分发许可确认。

历史 Mi 10 Spike 和本轮模拟器结果只能作为前置工程证据，不能替代上述同语料发布评测。

## 2. 可执行发布门禁

新增 `EvaluateAlphaReleaseUseCase`，将 PRD 门槛转换为 `passed`、`failed`、`missing` 三态结果：

- 任一明确不达标项产生 `noGo`。
- 没有失败但证据缺失产生 `blocked`。
- 只有全部门禁通过才产生 `go`。

RTF 和句后延迟使用最近秩算法计算 P50/P95，少于 20 个样本不计算 P95。报告同时保留语料 ID、设备 ID、原始指标引用、双模型对比统计和每个门禁的实际值；不会把缺失值当作 `0`。

输入模板：

```text
tool/benchmarks/alpha_release_input.example.json
```

执行：

```powershell
dart run tool/benchmarks/evaluate_alpha_release.dart `
  <评测输入.json> `
  .spike/results/alpha-release-evaluation.json
```

退出码：

- `0`：`go`
- `1`：`noGo`
- `2`：`blocked`
- `64`～`66`：参数、JSON 或文件错误

评测输入和输出只保存匿名标识、数值和证据引用，不保存原音频、完整转录或摘要正文；真实评测产物继续放在已忽略的 `.spike/`，不得提交。

## 3. 自动化验证

### 3.1 静态分析与测试

```powershell
dart format lib test integration_test tool/benchmarks/evaluate_alpha_release.dart
flutter analyze --no-pub
flutter test --no-pub
```

结果：

- 格式化无额外变化。
- 静态分析无问题。
- 246 项测试全部通过，其中发布门禁新增 5 项测试，覆盖 Go、严格 RTF 边界、样本不足、证据缺失和 JSON 可追溯性。

### 3.2 Android 集成

设备：

- Android 16 / API 36
- x86_64 模拟器 `emulator-5554`

通过：

```powershell
flutter test integration_test/paraformer_standard_asr_engine_test.dart `
  --no-pub -d emulator-5554
flutter test integration_test/sherpa_onnx_adapter_test.dart `
  --no-pub -d emulator-5554
flutter test integration_test/silero_vad_test.dart `
  --no-pub -d emulator-5554
flutter test integration_test/reliable_recording_test.dart `
  --no-pub -d emulator-5554 --no-enable-impeller
```

录音测试首次运行等待 Android 13+ 通知权限；预授权后，模拟器 Impeller 又在 0×0 surface 上触发 `libflutter.so` raster SIGSEGV。关闭 Impeller 后同一业务用例通过。该异常属于本模拟器图形环境，不标记录音链失败，但保留为模拟器测试条件。

Qwen 集成测试需要约 987 MB 固定权重目录，本模拟器当前没有准备该目录，因此本轮没有产生新的 Qwen Engine 指标。

### 3.3 APK

```powershell
flutter build apk --debug --no-pub
.\tool\benchmarks\inspect_debug_apk.ps1
```

审计脚本现同时检查：

- 必需 ABI 和重复原生库。
- 标准模型、VAD、Manifest、NOTICE 和哈希。
- 高级模型权重或额外 ONNX 文件。
- APK 内录音、数据库等用户事实数据。
- DEX、Flutter 应用资产和 `libapp.so` 中常见永久密钥特征。

构建仍只有 `flutter_foreground_task` 应用 Kotlin Gradle Plugin 的 Built-in Kotlin 迁移警告；本轮不影响构建，但必须继续跟踪上游兼容性。

## 4. 下一轮执行清单

1. 准备不含原音频路径的 20 段去敏语料清单、人工关键事实标注和匿名语料 ID。
2. 准备最低目标 4 GB RAM arm64 真机，并记录型号、系统、ABI、内存和环境。
3. 在同一设备、同一语料和同一 VAD 配置下分别运行标准模型与高级模型。
4. 将原始 RTF、句后延迟、内存、能耗、温控、错误和最终耗时写入 `.spike/`，把匿名引用填入门禁输入。
5. 执行 30 分钟实体设备录音、最终转录、断网、积压、崩溃恢复和证据播放。
6. 补齐 AT-01～AT-16 证据引用，并确认 Paraformer 公开再分发许可。
7. 重新运行门禁；只有输出 `go` 才能把 Step 18 和 Alpha 状态改为已完成。
