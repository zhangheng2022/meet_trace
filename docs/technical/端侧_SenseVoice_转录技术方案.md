# 会迹（MeetTrace）端侧 SenseVoice 转录技术方案

> 日期：2026-08-01  
> 对应 PRD：V0.7  
> 状态：活动；当前端侧转录实现基线

## 1. 目标

以官方 `sherpa_onnx` Flutter/Dart 包接入固定 SenseVoice INT8 模型，在不牺牲可靠录音的前提下提供会中预览和最终转录。ASR/VAD 权重不随 APK/IPA 分发，而在首次初始化时安全下载；第二次启动可完全离线快速通过。

## 2. 固定资源

SenseVoice Manifest 位于 `assets/models/manifest.json`：

| 文件 | 字节数 | SHA-256 |
| --- | ---: | --- |
| `model.int8.onnx` | 239,233,841 | `c71f0ce00bec95b07744e116345e33d8cbbe08cef896382cf907bf4b51a2cd51` |
| `tokens.txt` | 315,894 | `f449eb28dc567533d7fa59be34e2abca8784f771850c78a47fb731a31429a1dc` |

运行时下载 URL 固定到 `https://mt.zhangheng.eu.org/models/SenseVoice/`，镜像文件与官方 SenseVoice revision `2365baeacb507f821a0c8120fcee3d484dba7a07` 及官方 Silero VAD 发布文件保持内容一致。SenseVoice 合计 `239,549,735` 字节；Silero VAD 固定 `212,860` 字节；总计 `239,762,595` 字节。所有 URL 必须为 HTTPS，许可文本随安装包分发，权重不分发。

## 3. 分层和依赖

```text
Startup View
  → RuntimeInitializationViewModel
    → InitializeRuntimeAssetsUseCase
      → RuntimeAssetPreparationPort
        → LocalRuntimeAssetPreparationService
          ├─ DownloadableModelService
          ├─ DownloadableSileroVadModelService
          ├─ RuntimeDownloadConsentRepository
          ├─ ModelStorageCapacityProvider
          └─ DownloadNetworkStatusProvider

Meeting ViewModel
  → StartMeetingUseCase / RunFinalTranscriptionUseCase
    → AsrEngineFactory Port
      → SherpaOnnxAsrEngineFactory
        → SenseVoiceAsrEngine
          → SherpaOnnxAsrEngine
            → 官方 sherpa_onnx isolate adapter
```

UI 只依赖 domain Port/Use Case/Model。下载、文件、网络、SQLite 和官方模型配置全部位于 data 层。录音服务不依赖 ASR Engine，预览协调器仅消费音频副本。

## 4. 初始化状态机

状态包括：检查本地资源、等待网络、等待移动网络同意、下载 ASR、下载 VAD、校验、暂停、失败和就绪。

快速路径只检查：安装记录为 `installed`、活动版本匹配、目录只包含固定文件、每个文件大小匹配。它不联网、不做远端版本查询，也不在每次启动计算大文件 SHA。首次下载、显式修复以及快速路径失败时执行完整 SHA-256。

准备流程：

1. 校验两个 Manifest 的固定总量不超过 `300,000,000`。
2. 尝试两项本地快速检查；同时就绪则返回。
3. 检查应用卷可用空间至少 `805,306,368` 字节；错误携带精确缺口。
4. 根据网络状态决定自动下载、等待网络或请求移动网络同意。
5. 顺序准备 SenseVoice 和 VAD，并把分项进度映射到全局字节进度。
6. 严格校验临时目录后原子改名，只有两项都就绪才开放首页。

移动网络同意存入 `app_settings`，值是按模型/VAD ID、版本、文件大小和哈希排序生成的资源集合标识。任一资源变化都会使旧同意失效。

## 5. 下载一致性

- 最终目录、临时目录和 `.partial` 文件均位于 App 私有支持目录。
- HTTP 客户端使用 Range 从现有分片长度继续；服务器不支持预期 Range 时必须安全重启该文件，不得拼接错误内容。
- “暂停”通过 cancellation token 停止活动请求，保留分片和 paused 安装状态。
- 校验固定文件集合、逐文件大小和 SHA-256；多余文件也视为失败。
- 最终目录只在完整校验成功后原子切换；失败不会破坏已激活版本。

## 6. SenseVoice Engine

`AsrModelRegistry.alpha` 只有一个 descriptor。Factory 拒绝未知 ID、非 `auto` 语言或关闭 ITN 的请求。`SenseVoiceAsrEngine` 只接受与 Registry 完全匹配、已安装、已验证且字节数正确的安装记录，并生成官方 `OfflineSenseVoiceModelConfig`。

识别器在独立 isolate 中持有。会中和最终转录复用统一 `SherpaOnnxAsrEngine`：16 kHz 单声道 PCM16、15 秒窗口、全局时间轴事件、确定性排队、诊断、RTF、取消与释放。

麦克风采集固定通过官方 `record` 插件请求平台自动增益、回声消除和噪声抑制。增强后的 16 kHz 单声道 PCM16 先写入事实音频，再分发给 VAD/ASR，保证最终录音、会中预览和最终转录使用同一音频事实。平台效果属于设备能力：Android 仅启用系统报告可用的 AGC/AEC/NS；iOS 流式录音通过系统 Voice Processing 启用回声消除和自动增益，不引入自建 DSP 或私有原生桥接。如增强录音启动失败，会以同样的 PCM16 规格关闭增强后重试一次，优先保证录音连续可用。

## 7. 会议锁定与数据库

`Meeting` 保存 `requested_model_id`、`recording_model_id`、`recording_model_version`、`recording_model_language` 和 `recording_model_use_itn`。开始会议时一次写入 `auto/true`；后续预览和最终转录从会议读取，不从设置重新解析。

schema v5 为干净安装基线。检测到 v1～v4 时抛出 `UnsupportedAlphaInstallationException`，提示用户先导出录音再卸载或清除数据。升级事务不会修改旧数据库，也不会删除录音。

## 8. 故障和降级

| 故障 | 行为 |
| --- | --- |
| 无网络/未同意移动流量 | 停留初始化页 |
| 空间不足 | 显示精确缺口并允许重试 |
| 暂停 | 保留分片，状态为 paused |
| SHA/文件集失败 | 不激活，进入修复 |
| 第二次启动文件缺失/大小异常 | 进入修复并完整校验 |
| Engine 初始化或推理失败 | 不自动切换；录音继续，显示修复/重试 |
| 预览积压 | 丢最旧预览任务，绝不丢录音 |
| 最终转录失败 | 保留事实音频和旧活动快照 |

## 9. 安装包与供应链门禁

- `pubspec.yaml` 只能声明 Manifest 和许可证，不声明 `.onnx` 或模型 tokens。
- APK/IPA 必须审计：没有 SenseVoice、Paraformer、Qwen 或 Silero VAD 权重；官方 sherpa-onnx 运行库可存在。
- Manifest 解析拒绝 HTTP、路径穿越、重复文件、空哈希、错误总量和不兼容 schema。
- 依赖只允许官方 `sherpa_onnx` 包，不新增 JNI、FFI/C API、自建 C/C++ 链或手工 `jniLibs`。

## 10. 验证

自动化至少覆盖：Registry 单模型、固定 Manifest/hash/revision、300 MB 上限、768 MiB 空间差额、移动网络同意绑定、暂停续传、VAD 原子准备、快速离线启动、SenseVoice 配置、会议锁定、旧库阻断、录音连续性与最终快照。`SherpaOnnxAsrEngine` 通过 fake worker 直接验证预览片段时间轴、空结果、无效窗口、推理错误诊断、PCM16 解码、15 秒最终转录分窗、设备风险阻断、取消终态及幂等释放；这些测试不加载真实模型权重，真机性能和识别准确率仍由外部门禁负责。

交付运行：

```powershell
dart format lib test integration_test
flutter analyze
flutter test
flutter build apk --debug
```

目标真机还必须完成 PRD 的 RTF P95、结果延迟 P95、关键事实召回率、30 分钟电量/温控/内存和后台录音验证。Windows 不能替代 iOS arm64 构建与真机证据。
