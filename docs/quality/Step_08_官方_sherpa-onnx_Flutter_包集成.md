# Step 08 官方 sherpa-onnx Flutter 包集成

> 状态：已完成
>
> 日期：2026-07-24
>
> 分支：`codex/alpha-step-08-sherpa-adapter`

## 结论

Step 08 已将 Spike 验证过的官方 `sherpa_onnx` 1.13.4 收敛为 data/service 层公共 adapter。应用没有新增 JNI、ffigen、C/C++、`DynamicLibrary.open`、私有 ABI 声明或手工 `jniLibs`。

## 关键设计

- 应用入口执行一次性 bindings 初始化；失败转换为可重试结构化错误，不阻止应用壳与可靠录音启动。
- Paraformer 与 Qwen3-ASR 使用纯 Dart、可跨 isolate 传输的配置对象。
- 每个 adapter 在独立长生命周期 isolate 中初始化并持有一个官方 `OfflineRecognizer`。
- PCM 通过 `TransferableTypedData` 传输，识别请求串行执行，不阻塞 UI 或录音写入。
- 官方识别器和 stream 均显式 `free`；worker 异常退出会结束等待任务。
- 应用级取消拒绝排队任务并丢弃活动结果。官方离线 `decode` 没有抢占 API，正在执行的窗口完成后再释放，因此后续 Engine 仍须执行 15 秒窗口上限。
- fake worker 单元测试不调用官方 bindings 或加载原生运行库。

## 测试先行证据

生产文件创建前，以下测试因目标类型和应用启动调用不存在而失败：

- 单 isolate bindings 只初始化一次，失败不阻止启动。
- fake worker 初始化、识别、释放与 adapter 重复创建。
- 并发请求确定性串行。
- 初始化/推理异常不暴露第三方类型。
- 应用级取消丢弃活动结果并拒绝后续推理。
- 双模型配置可跨 isolate 传输并拒绝非法值。
- 官方版本固定、入口初始化且仓库不存在自建原生桥接。

新增 10 项单元测试，全量自动化测试为 115 项。

## Mi 10 真机结果

设备：Mi 10，Android 11（API 30），`arm64-v8a`。

集成测试从 APK 复制真实内置 Paraformer INT8 模型与 tokens，连续执行两轮：

```text
主 isolate initBindings
  → 创建独立 worker isolate
  → worker initBindings
  → OfflineRecognizer 初始化
  → 识别 1 秒、16 kHz Float32 PCM
  → stream.free
  → recognizer.free
  → 销毁 worker
```

两轮均通过，包含释放后的重新创建；测试逻辑阶段约 4 秒。

## APK 检查

- 必需 ABI：`arm64-v8a`，存在。
- 同时包含：`armeabi-v7a`、`x86_64`。
- sherpa/onnxruntime 原生库按 ABI 各一份，无可疑重复。
- 标准 Paraformer 模型与许可证声明存在。
- Qwen3-ASR 高级权重不存在。
- Flutter 聚合许可证：`assets/flutter_assets/NOTICES.Z`，存在。
- 本次生产入口 Debug APK：`321,851,678` 字节；检查脚本每次构建后把实时大小写入本地报告，不提交构建产物。

## 已运行验证

```text
dart format lib test integration_test
flutter analyze --no-pub
flutter test --no-pub
flutter build apk --debug --no-pub
tool/benchmarks/inspect_debug_apk.ps1
flutter test --no-pub integration_test/sherpa_onnx_adapter_test.dart -d 3f842cd0
```

- 静态分析：0 issue。
- Step 08 单元测试：10/10 通过。
- 全量自动化测试：115/115 通过。
- Debug APK：构建通过。
- APK ABI、资产、许可证和重复库检查：通过。
- Mi 10 官方 worker 重复创建集成测试：通过。
- Mi 10 生产入口启动：进程存活，应用完整绘制，日志无 native/Dart fatal。

## 已知风险

- 官方离线 `decode` 不支持窗口内抢占；取消不会停止已进入 native decode 的当前窗口，只会阻止业务消费结果并拒绝后续任务。
- `flutter_foreground_task` 与 `storage_space` 的旧式 Kotlin Gradle Plugin 警告延续自 Step 07，不影响当前构建，但 Flutter 升级前必须复核。
- 本步骤只验证公共 adapter 与真实 Paraformer；完整 Paraformer/Qwen Engine、15 秒窗口、事件输出和最终转录分别属于 Step 09/10/14。
