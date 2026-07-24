# Step 10 Qwen Advanced Engine

> 状态：代码、自动化测试及 Android x86_64 模拟器正式 Engine 复测通过；Mi 10 正式 Engine 复测仍待设备允许 USB 安装
>
> 日期：2026-07-24
>
> 分支：`codex/alpha-step-10-qwen-engine`

## 结论

Step 10 已实现 `QwenAdvancedAsrEngine`。高级 Engine 只通过 Step 08 的官方 `sherpa_onnx` Dart adapter 调用 Qwen3-ASR，不包含自建 JNI、FFI/C API、C/C++ 构建链或手工 `jniLibs`。初始化或推理失败只返回高级模型结构化错误，不会自动创建或切换到 Paraformer。正式 Engine 已在 Android 16 x86_64 模拟器使用真实固定 Qwen 权重连续通过两轮集成测试。

## 关键设计

- `create` 从 `ActiveModelInstallationRepository` 读取 Qwen 当前活动版本，并要求 Registry ID/版本、downloadable 类型、`installed` 状态、已验证路径和 `987,015,347` 字节完全匹配。
- Engine 创建时为会议/任务 owner 获取版本使用租约；同 owner 已有有效租约时返回 `asr.qwen.lease_conflict`，接近到期时在识别前续租，`dispose` 释放租约。
- Paraformer 与 Qwen 改为薄封装，共用 `SherpaOnnxAsrEngine`：16 kHz 单声道、15 秒硬上限、确定性队列、全局时间轴事件、完整 PCM16 切窗、最终快照、诊断、RTF、进度、取消和释放逻辑只有一份。
- `AsrDeviceRiskState` 表达设备支持级别、内存压力、温控状态、进程 RSS 和估算可用内存；风险数据由 `AsrDeviceRiskMonitor` 注入。
- unsupported、critical memory 和 critical thermal 阻止高级模型初始化/后续推理；constrained、memory warning 和 thermal serious 保留为可观察警告但允许运行。
- 风险或模型故障不会修改 `descriptor`、实际模型 ID/版本或会议锁定状态，也不会触发自动回退。
- Qwen 推理失败的同时，独立 `ReliableRecordingService` 仍能继续写入并封存 100% 的测试 PCM 字节。

## 测试先行证据

生产 Engine 创建前，专项测试因 `QwenAdvancedAsrEngine`、设备风险协议和共享核心不存在而失败。随后实现 10 项行为：

1. 只从活动且已验证的高级版本生成 Qwen 官方配置并获取租约。
2. 未安装、校验失败或非活动版本不能创建 Engine。
3. 同 owner 的有效租约冲突时拒绝重复创建。
4. 不支持设备、临界内存和临界温控分别阻止初始化。
5. 风险警告允许初始化，后续临界风险只阻止高级模型。
6. 事件和最终快照可通过统一 `AsrEngine` 协议消费。
7. 超过 15 秒的窗口不会进入 Qwen adapter。
8. 推理失败保持高级模型身份且不自动切换。
9. 推理失败期间可靠录音继续写入完整事实音频。
10. 识别前续租，`dispose` 同时释放 worker 和租约。

新增 10 项单元测试，全量自动化测试由 124 项增加到 134 项；Step 09 的 9 项 Paraformer 测试在共享核心重构后全部通过。

## 真实模型与设备状态

Step 01 已在 Mi 10（Android 11、`arm64-v8a`）使用相同官方 Qwen3-ASR 配置完成两轮真实初始化、15/30 秒窗口推理、结果读取和释放：RTF 为 0.688/0.707，峰值 RSS 约 2.92 GiB。

本步骤新增 `integration_test/qwen_advanced_asr_engine_test.dart`，会用真实 Qwen active version、SQLite 安装/租约仓库和正式 Engine 完成 1 秒窗口识别后释放。2026-07-24 本轮已重新下载并校验官方固定归档。Mi 10 的普通 Debug APK 曾成功安装，但 Flutter 集成测试运行器再次安装测试应用时仍返回：

```text
INSTALL_FAILED_USER_RESTRICTED: Install canceled by user
```

用户随后切换到 `sdk_gphone64_x86_64` 模拟器（Android 16、API 36、`x86_64`）。APK 包含 x86_64 的官方 sherpa-onnx 和 ONNX Runtime 原生库；设备准备了 Registry 要求的六个运行文件，共 `987,015,347` 字节。正式 Engine 连续两轮通过：

- 首轮包含 120 秒模型准备窗口，总耗时 2 分 15 秒。
- 无等待复跑的设备内测试耗时 9 秒；包含构建、安装和测试的主机总耗时 35.289 秒。

两轮均完成活动版本读取、SQLite 安装记录、使用租约、官方 worker 初始化、1 秒窗口识别、指标断言、worker 释放和租约释放。因此可以确认正式 Engine 的 Android 集成测试已在模拟器通过，但不能把它表述为 Mi 10 真机正式 Engine 已通过。Mi 10 与模拟器的 `/data/local/tmp` 中转目录及应用私有测试模型均已清理；主机 `.spike/step10-qwen` 模型被 Git 忽略，可在 Mi 10 允许测试应用安装后继续复测。

## 已运行验证

```text
dart format lib test integration_test
flutter analyze
flutter test --no-pub
flutter build apk --debug --no-pub
flutter test --no-pub integration_test/qwen_advanced_asr_engine_test.dart -d 3f842cd0 ...
flutter test --no-pub integration_test/qwen_advanced_asr_engine_test.dart -d emulator-5554 --no-uninstall ...
```

- 静态分析：0 issue。
- Step 10 单元测试：10/10 通过。
- Paraformer 回归：9/9 通过。
- 全量自动化测试：134/134 通过。
- Debug APK：构建通过。
- Android 16 x86_64 模拟器正式 Engine 复测：2/2 通过。
- Mi 10 正式 Engine 复测：测试应用安装策略仍阻塞，未通过也未伪报通过。

## 已知风险

- `AsrDeviceRiskMonitor` 的 Android 平台装配与 UI 风险提示属于 Step 11/13；在提供风险监视器前，Factory 不应创建高级 Engine。
- Qwen 在 Mi 10 上约占 2.92 GiB RSS 且首结果约 18～20 秒，只适合作为明确风险提示下的高级离线能力，不满足会中准实时。
- 官方离线 `decode` 不支持窗口内抢占；取消会丢弃活动结果并拒绝后续窗口，但当前 native decode 仍会完成。
- 同 owner 冲突检查与租约保存目前通过 Repository 顺序执行；若未来支持多进程并发，需要在 SQLite 增加 owner 级唯一约束或原子获取事务。
