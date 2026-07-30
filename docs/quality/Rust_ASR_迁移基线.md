# Rust ASR 迁移基线

> 基线日期：2026-07-30
> 基线分支：`codex/rust-whisper-streaming-asr`
> 基线起点：`719158b`（当前 C++ whisper.cpp 后端）
> 当前状态：Android 工程基线已采集；Android 真机安装受设备策略阻止；Small、iOS 和同语料质量指标待补

## 1. 基线目的

本报告冻结 Rust 迁移前的 C++ whisper.cpp 行为和可获得证据。迁移是否成功只根据同一设备、
同一权重、同一事实 PCM 和同一指标的前后对照判断，不能根据语言或实现方式推断。

本报告不保存真实会议录音。当前仓库没有满足去敏、许可和标注要求的 20 段评测语料，因此
关键事实召回率、CER、静音幻觉、句后延迟和真实会议 RTF 仍是缺失证据，不填写猜测值。

## 2. 环境

| 项目 | 基线 |
|---|---|
| Flutter | 3.44.8 stable |
| Dart | 3.12.2 |
| 主机 | Windows 10.0.26100.8875 |
| Android SDK | `D:\AndroidSdk` |
| Android NDK | 28.2.13676358 |
| Android 真机 | Xiaomi Mi 10 |
| Android 系统/ABI | Android 11 / API 30 / arm64-v8a |
| iOS/macOS | 当前环境不可用 |
| 标准权重 | `ggml-base-q5_1.bin`，59,707,625 bytes |
| 标准权重 SHA-256 | `422f1ae452ade6f30a004d7e5c6a43195e4433bc370bf23fac9cc591f01a8898` |
| 高级权重 | 当前工作区未下载 |

## 3. 自动化基线

### 3.1 Dart/Flutter 测试

命令：

```powershell
flutter pub get
flutter test
```

结果：327 项测试通过，0 失败。已有测试覆盖：

- 每个 PCM 块完成文件 flush 和 checkpoint 后才投递预览；
- preview sink 阻塞或抛错不阻塞后续事实音频写入；
- 合成 30 分钟 PCM 的事实文件完整率 100%；
- 预览积压丢弃最旧任务并恢复；
- Engine 失败进入仅录音；
- 会议模型锁定且不自动回退；
- 最终转录失败保留事实音频和旧活动快照；
- 新最终快照完整写入后原子激活。

这些测试证明当前代码契约，不替代真机 30 分钟录音、功耗、温控或识别质量证据。

### 3.2 Android Debug APK

命令：

```powershell
& ./tool/benchmarks/run_android_whisper_validation.ps1 `
  -DeviceId '3f842cd0' `
  -AndroidSdkRoot 'D:\AndroidSdk' `
  -ModelFilter base
```

构建结果：

| 项目 | 结果 |
|---|---|
| `flutter build apk --debug` | 通过 |
| APK 大小 | 237,340,974 bytes |
| `arm64-v8a/libmeettrace_whisper.so` | 存在 |
| `armeabi-v7a/libmeettrace_whisper.so` | 存在 |
| `x86_64/libmeettrace_whisper.so` | 存在 |
| Base 权重大小/SHA | 匹配 |
| Small 权重 | 未混入 |
| sherpa/ONNX/Silero 旧资产 | 未混入 |
| Flutter notices | 存在 |
| 疑似密钥/用户数据 | 未发现 |

APK 安装结果：失败，ADB 返回
`INSTALL_FAILED_USER_RESTRICTED: Install canceled by user`。因此不能据此声称 Base 真机初始化、
识别、取消或释放已经通过。需要在 Mi 10 开启/确认“通过 USB 安装”后重跑。

### 3.3 已复现的构建诊断

- C/C++ `clang -c` 阶段重复输出
  `-Wl,-z,max-page-size=16384: 'linker' input unused`。这是 linker 参数进入仅编译阶段的
  告警，不等同于最终 ELF 未对齐；16 KB 兼容性必须由 APK 中每个 `.so` 的 program header
  和目标设备安装结果证明。
- Windows PowerShell 5.1 会把当前 UTF-8 无 BOM 的
  `run_android_whisper_validation.ps1` 误解码并产生 ParserError；PowerShell 7.6.4 可正常执行。
- whisper.cpp Android 构建有一处 `%ld` 与 32-bit `size_t` 的上游格式告警；当前未造成构建失败。
- `flutter_foreground_task` 仍应用 Kotlin Gradle Plugin；Flutter 提示未来版本需要迁移到
  Built-in Kotlin。该项不属于本轮 Rust ASR 迁移，但需进入后续依赖维护。

## 4. 尚缺证据

| 证据 | Android | iOS |
|---|---|---|
| Base 真机初始化/识别/释放 | 设备安装策略阻止 | 无 macOS/真机 |
| Small 真机初始化/识别/释放 | 权重未下载 | 无 macOS/真机 |
| 20 段同语料 Base/Small | 缺语料与标注 | 缺语料、标注和设备 |
| 30 分钟前台/后台事实录音 | 只有合成单测 | 无真机 |
| 句后延迟 P50/P95 | 缺 | 缺 |
| 最终转录 RTF | 缺 | 缺 |
| 峰值 RSS/CPU/耗电/温控 | 缺 | 缺 |
| 100 次 initialize/cancel/dispose | 缺 | 缺 |
| Android 16 KB ELF alignment | 待专用脚本 | 不适用 |

以上任何空缺都不能写成 0，也不能用 Android 工程构建替代 iOS 证据。

## 5. Rust cutover 门槛

只有全部满足时才能把默认后端切换为 Rust：

1. 事实 PCM 字节数、SHA-256 和 checkpoint 连续性与旧后端一致，双平台 30 分钟录音完整率
   100%。
2. Base/Small 在同一 20 段语料上的总体关键事实召回率不得低于旧后端。
3. 静音/背景噪音幻觉片段数相对旧后端至少降低 80%，纯静音为 0。
4. 正常设备句后出字 P95 不超过 3 秒。
5. 最终转录 RTF 相对旧后端不得恶化超过 10%。
6. 峰值 RSS 与耗电相对旧后端不得恶化超过 15%。
7. Android 与 iOS 都完成 100 次 initialize → recognize → cancel/dispose，无崩溃且 RSS
   不单调增长。
8. Android Release APK 中全部 `.so` 通过 16 KB alignment 检查。
9. 未解决的 OCR Critical/High 为 0。

## 6. 阶段 0 结论

当前 C++ 基线的自动化契约和 Android APK 构建可复现，但真机识别与质量矩阵不完整。
这不阻止继续更新产品/技术边界，也不允许提前通过 Rust Hard Gate 1 或删除旧 C++ 后端。
