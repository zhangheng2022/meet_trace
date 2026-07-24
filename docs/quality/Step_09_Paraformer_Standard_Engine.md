# Step 09 Paraformer Standard Engine

> 状态：已完成
>
> 日期：2026-07-24
>
> 分支：`codex/alpha-step-09-paraformer-engine`

## 结论

Step 09 已实现标准 `ParaformerStandardAsrEngine`。它只通过 Step 08 的官方 `sherpa_onnx` Dart adapter 调用模型，不包含自建 JNI、FFI/C API、C/C++ 构建链或手工 `jniLibs`，且不与可靠录音写入链耦合。

## 关键设计

- Engine 从 `AsrModelRegistry` 固定获取标准模型 descriptor，只接受模型 ID、版本、安装类型和 `installed + verifiedAt + installedPath` 完全匹配的安装记录。
- 识别输入固定为 16 kHz、单声道 Float32；单窗口最多 15 秒，过长输入在进入 adapter 前以 `asr.paraformer.window_too_long` 拒绝。
- `TranscriptSegmentEvent` 使用调用方提供的全局 `startMs` 计算区间，记录实际模型 ID/版本，不假设官方结果包含词级时间戳。
- 完整转录从本地事实 PCM16 little-endian 文件按最多 15 秒读取，不一次性加载整场音频；所有成功片段归属于同一最终快照和同一模型版本。
- 任一最终处理窗口失败时抛出结构化错误并发出失败进度，不生成伪完成快照；事实音频保持不变，可由上层重新创建 Engine 后重试。
- 每个窗口记录 recognized、empty 或 failed 诊断，并累计音频时长、推理耗时、RTF、错误码、模型 ID 和版本。
- `AsrEngine` 统一暴露最终处理进度、指标、诊断、取消和带 `meetingId` 的最终快照协议，为 Step 10 高级 Engine 提供相同契约。
- 应用级取消立即拒绝后续窗口并丢弃活动结果；官方离线 `decode` 仍在独立 isolate 内完成当前窗口后释放。

## 测试先行证据

生产 Engine 创建前，专项测试因 `ParaformerStandardAsrEngine` 和 `AsrEngineException` 不存在而失败。随后实现以下 9 项行为：

1. descriptor 与 Registry 标准模型为同一条目，并从已验证目录生成官方配置。
2. 未验证或字节数不匹配的安装记录不能创建 Engine。
3. 窗口事件保留模型身份和外部全局时间区间。
4. 超过 15 秒的输入不会进入 adapter。
5. 初始化失败为可重试结构化错误，原 Engine 可再次初始化。
6. 并发提交窗口仍按提交顺序输出。
7. 空结果、错误、RTF 和版本逐窗记录。
8. 16 秒事实 PCM16 被切为 15 秒与 1 秒窗口，并生成最终快照和进度。
9. 取消丢弃活动结果并拒绝后续识别。

新增 9 项单元测试，全量自动化测试由 115 项增加到 124 项。

## Mi 10 真机结果

设备：Mi 10，Android 11（API 30），`arm64-v8a`。

集成测试从 APK 复制真实内置 Paraformer INT8 模型与 tokens，完成：

```text
已验证安装记录
  → ParaformerStandardAsrEngine.initialize
  → 识别 1 秒、16 kHz Float32 静音窗口
  → 从 1 秒 PCM16 事实文件执行最终处理
  → 最终快照 complete
  → 进度 completed、窗口 2/2、失败 0
  → dispose
```

测试逻辑阶段约 2 秒，全部通过。

## 已运行验证

```text
dart format lib test integration_test
flutter analyze
flutter test --no-pub
flutter test --no-pub integration_test/paraformer_standard_asr_engine_test.dart -d 3f842cd0
```

- 静态分析：0 issue。
- Step 09 单元测试：9/9 通过。
- 全量自动化测试：124/124 通过。
- Mi 10 真实模型集成测试：通过。

## 已知风险

- 当前正式 VAD 和重叠窗口合并属于 Step 12；Step 09 只执行 15 秒硬上限并处理已切分窗口。
- 官方离线 `decode` 不支持窗口内抢占；取消不会中止已进入 native decode 的当前窗口，因此 15 秒上限仍是延迟保护边界。
- 最终处理目前读取录音服务定义的 16 kHz、单声道、little-endian PCM16 事实文件；将来若事实音频容器格式变化，必须在 data/service 层增加显式解码器并同步技术方案。
- 真实会议语料、低端设备、温控和公开分发许可仍属于 Step 01/18 的发布门槛。
