# 会迹（MeetTrace）端侧 SenseVoice 与说话人分离技术方案

> 日期：2026-08-04
> 对应 PRD：V0.9
> 状态：活动；说话人模型初始化、公开 API 适配器与联合最终快照已完成，官方 Dart 绑定内存缺陷导致生产自动分离保持阻断

## 1. 目标

以官方 `sherpa_onnx` Flutter/Dart 包接入固定 SenseVoice INT8、Pyannote INT8 和 3D-Speaker 模型，在不牺牲可靠录音的前提下提供会中预览，以及带说话人标签的联合最终结果。全部 ASR、VAD 和说话人权重不随 APK/IPA 分发，而在首次初始化时安全下载；第二次启动可完全离线快速通过。

## 2. 固定资源

SenseVoice Manifest 位于 `assets/models/manifest.json`：

| 文件 | 字节数 | SHA-256 |
| --- | ---: | --- |
| `model.int8.onnx` | 239,233,841 | `c71f0ce00bec95b07744e116345e33d8cbbe08cef896382cf907bf4b51a2cd51` |
| `tokens.txt` | 315,894 | `f449eb28dc567533d7fa59be34e2abca8784f771850c78a47fb731a31429a1dc` |

SenseVoice 与 Silero VAD 的运行时下载 URL 固定到 `https://mt.zhangheng.eu.org/models/SenseVoice/`，镜像文件与官方 SenseVoice revision `2365baeacb507f821a0c8120fcee3d484dba7a07` 及官方 Silero VAD 发布文件保持内容一致。

说话人分离使用独立 `assets/models/speaker-diarization-manifest.json`，并按下表固定：

| 下载产物 | 下载字节数 | SHA-256 | 安装结果 |
| --- | ---: | --- | --- |
| `sherpa-onnx-pyannote-segmentation-3-0.tar.bz2` | 6,958,444 | `24615ee884c897d9d2ba09bb4d30da6bb1b15e685065962db5b02e76e4996488` | 只保留 `model.int8.onnx`（1,540,506 B；`d582f4b4c6b48205de7e0643c57df0df5615a3c176189be3fc461e9d18827b5d`）与许可文件 |
| `3dspeaker_speech_eres2net_base_sv_zh-cn_3dspeaker_16k.onnx` | 39,593,761 | `1a331345f04805badbb495c775a6ddffcdd1a732567d5ec8b3d5749e3c7a5e4b` | 原文件校验后激活 |

Pyannote 与 3D-Speaker 的运行时下载 URL 固定到 `https://mt.zhangheng.eu.org/models/SpeakerDiarization/`。镜像内容必须分别与官方 sherpa-onnx `speaker-segmentation-models`、`speaker-recongition-models` 发布资产保持字节一致。Pyannote 归档内含 MIT 许可；3D-Speaker 按该精确模型的 ModelScope 元数据采用 Apache-2.0；两项许可与 NOTICE 均已入库。

同一 Manifest 固定 Engine 输入与聚类配置：16 kHz 单声道、CPU provider、2 threads、`numClusters=-1`、`minDurationOn=0.2`、`minDurationOff=0.5`。工程接入暂用 threshold `0.5`；该值不是发布质量结论，必须经过普通话 2/3/4 人标注语料校准后才能关闭阶段 3 门禁。

SenseVoice 合计 `239,549,735` 字节；Silero VAD 固定 `212,860` 字节；说话人资产下载 `46,552,205` 字节；全部运行时下载合计 `286,314,800` 字节。所有 URL 必须为 HTTPS，许可文本随安装包分发，权重不分发。

## 3. 分层和依赖

```text
Startup View
  → RuntimeInitializationViewModel
    → InitializeRuntimeAssetsUseCase
      → RuntimeAssetPreparationPort
        → LocalRuntimeAssetPreparationService
          ├─ DownloadableModelService
          ├─ DownloadableSileroVadModelService
          ├─ DownloadableSpeakerDiarizationModelService
          ├─ RuntimeDownloadConsentRepository
          ├─ ModelStorageCapacityProvider
          └─ DownloadNetworkStatusProvider

Meeting ViewModel
  → StartMeetingUseCase / FinalResultCoordinator
    → AsrEngineFactory Port
      → SherpaOnnxAsrEngineFactory
        → SenseVoiceAsrEngine
          → SherpaOnnxAsrEngine
            → 官方 sherpa_onnx isolate adapter
    → SpeakerDiarizationService Port
      → SherpaOnnxSpeakerDiarizationService
        → 官方 OfflineSpeakerDiarization isolate adapter
```

UI 只依赖 domain Port/Use Case/Model。下载、文件、网络、SQLite 和官方模型配置全部位于 data 层。录音服务不依赖 ASR Engine，预览协调器仅消费音频副本。

## 4. 初始化状态机

状态包括：检查本地资源、等待网络、等待移动网络同意、下载 ASR、下载 VAD、下载说话人分段/嵌入资产、解包、校验、暂停、失败和就绪。

快速路径只检查：安装记录为 `installed`、活动版本匹配、目录只包含固定文件、每个文件大小匹配。它不联网、不做远端版本查询，也不在每次启动计算大文件 SHA。首次下载、显式修复以及快速路径失败时执行完整 SHA-256。

准备流程：

1. 校验全部 Manifest 的固定总量不超过 `300,000,000`。
2. 尝试 ASR、VAD 和说话人资源的本地快速检查；完整集合同时就绪才返回。
3. 检查应用卷可用空间至少 `1,073,741,824` 字节；错误携带精确缺口。
4. 根据网络状态决定自动下载、等待网络或请求移动网络同意。
5. 顺序准备 SenseVoice、VAD、Pyannote 归档与 3D-Speaker，并把分项进度映射到全局字节进度。
6. Pyannote 归档先验证下载文件 SHA-256，再在受限临时目录解包；拒绝绝对路径、路径穿越、符号链接和非白名单文件，只激活固定的 INT8 模型与许可文件。
7. 严格校验每项临时目录后分别原子改名，只有完整资源集合都就绪才开放首页。

移动网络同意存入 `app_settings`，值是按 ASR、VAD 与说话人资源 ID、版本、文件大小和哈希排序生成的资源集合标识。任一资源变化都会使旧同意失效。

## 5. 下载一致性

- 最终目录、临时目录和 `.partial` 文件均位于 App 私有支持目录。
- HTTP 客户端使用 Range 从现有分片长度继续；服务器不支持预期 Range 时必须安全重启该文件，不得拼接错误内容。
- “暂停”通过 cancellation token 停止活动请求，保留分片和 paused 安装状态。
- 校验固定文件集合、逐文件大小和 SHA-256；多余文件也视为失败。
- 最终目录只在完整校验成功后原子切换；失败不会破坏已激活版本。
- 归档下载、解包目录与活动目录必须分离；激活成功后删除下载归档和未使用的浮点模型，失败或取消时不得留下可被快速路径误认的半成品。

## 6. SenseVoice Engine

`AsrModelRegistry.alpha` 只有一个 descriptor。Factory 拒绝未知 ID、非 `auto` 语言或关闭 ITN 的请求。`SenseVoiceAsrEngine` 只接受与 Registry 完全匹配、已安装、已验证且字节数正确的安装记录，并生成官方 `OfflineSenseVoiceModelConfig`。

识别器在独立 isolate 中持有。会中和最终转录复用统一 `SherpaOnnxAsrEngine`：16 kHz 单声道 PCM16、15 秒窗口、全局时间轴事件、确定性排队、诊断、RTF、取消与释放。

麦克风采集固定通过官方 `record` 插件请求平台自动增益、回声消除和噪声抑制。增强后的 16 kHz 单声道 PCM16 先写入事实音频，再分发给 VAD/ASR，保证最终录音、会中预览和最终转录使用同一音频事实。平台效果属于设备能力：Android 仅启用系统报告可用的 AGC/AEC/NS；iOS 流式录音通过系统 Voice Processing 启用回声消除和自动增益，不引入自建 DSP 或私有原生桥接。如增强录音启动失败，会以同样的 PCM16 规格关闭增强后重试一次，优先保证录音连续可用。

## 7. 说话人分离与联合最终快照

`SherpaOnnxSpeakerDiarizationService` 只通过官方 `OfflineSpeakerDiarization` Dart API 接入，不自建 JNI、FFI/C API 或原生桥接。固定输入为 16 kHz 单声道事实 PCM；分段使用 Pyannote INT8，嵌入使用 3D-Speaker，`numClusters=-1`。模型在独立 isolate 中按任务创建和释放；worker 在模型初始化尚未完成时也可被 Domain 超时直接终止，不能让已降级任务继续占用 CPU/内存。聚类 threshold 必须在不少于 60 分钟的普通话 2/3/4 人标注语料上校准并固定到 Manifest/配置，UI 不暴露该参数。

供应链审查确认官方 [`sherpa_onnx 1.13.4` Dart 实现](https://github.com/k2-fsa/sherpa-onnx/blob/v1.13.4/flutter/sherpa_onnx/lib/src/offline_speaker_diarization.dart#L258-L325)及上游 `master` 的 `process`/`processWithCallback` 都会 `calloc<Float>(samples.length)`，销毁结果后却没有释放输入指针。该内存属于进程原生堆，终止 Dart isolate 不能替代 `calloc.free`；30 分钟 16 kHz 波形对应 `115,200,000` B。项目规则又禁止导入包私有绑定或自建 FFI，因此生产组合根当前装配 `OfficialBindingBlockedSpeakerDiarizationService`，以 `speaker_diarization.official_binding_memory_leak` 明确降级。只有官方新版本修复、依赖升级、自动化通过并取得 Android/iOS 30 分钟重复任务内存证据后，才能切回真实服务。

录音封存后，`FinalResultCoordinator` 从同一事实音频并行启动最终 ASR 与离线分离，两者运行在独立 worker/isolate，不能占用录音写入队列。ASR 成功且分离成功时，按时间重叠把 `SpeakerTurn` 映射到最终转录片段；分离超时、空结果、内存或推理失败时生成明确的单一说话人降级结果。只有两条任务都结束后才以一次事务写入并激活最终快照；ASR 失败时保留事实音频和旧活动快照，不发布半成品。

用户修改说话人显示标签时，以当前活动快照为基线创建修订并通过 CAS 原子替换；不得改变片段时间、文本、模型配置或事实音频。普通话是 Alpha 分离质量承诺范围，其他语言只允许尽力运行并明确不承诺准确率。

## 8. 会议锁定与数据库

`Meeting` 保存 `recording_model_id`、`recording_model_version`、`recording_model_language` 和 `recording_model_use_itn`，并锁定说话人分段/嵌入模型版本与聚类配置。开始会议时一次写入；后续预览、最终转录和分离从会议读取，不从设置或远端重新解析。单模型基线已删除请求模型与回退原因字段，架构守卫禁止对应列名重新进入 `lib/`。

当前代码已建立 schema 7 与数据代 3 的干净安装基线，并删除总结结构；阶段 4 已通过 `FinalResultCoordinator` 补齐联合结果契约。`LocalDataGenerationGate` 在打开数据库与初始化运行资源之前校验数据代标记（`data_generation.json`），缺失或内容不一致时清空整个 `meettrace/` 数据根目录（数据库、会议音频与快照、模型、检查点、偏好和分享临时文件）并重走首次初始化；文件系统读取异常通过 `LocalDataGenerationMarkerReadException` 阻断启动，绝不继续清理。数据库层继续拒绝所有旧 schema 作为兜底防线。

## 9. 结果标题、分享与数据外发

会议创建时按当时本地时间生成确定性标题 `yyyy-MM-dd HH:mm 会议` 并立即持久化；后续时区变化不改写标题。代码中删除 AI 总结的 Port、Use Case、Service、Repository、表、任务状态、UI 与测试，不保留隐藏入口或不可用生产适配器。

文本分享只读取当前活动最终快照，输出会议标题、时间和带说话人/时间戳的转录，不附带音频。音频分享由 `ShareMeetingAudioUseCase` 独立编排：先计算目标 WAV 大小和可用空间，展示名称、时长、大小与敏感信息确认；确认后再次校验空间，从事实 PCM 只读分块生成每次分享独占的临时 WAV，通过 `share_plus` 调用系统分享面板，并在完成、取消、结果不可判定、异常或下次启动恢复时清理应用自有临时文件。源 PCM 不移动、不重命名，也不被转码覆盖。Android 额外清理 `share_plus` 创建的精确缓存子目录：取消、不可用和异常立即清理；成功路径等待应用离开前台并重新恢复后再清理，避免接收端尚未读取时提前删除；冷启动还会恢复清理旧残留。该清理不遍历临时目录的其他内容，也不跟随符号链接越界。

App 不接入远程埋点、远程崩溃上报或总结网关。诊断导出只包含白名单状态、错误码和设备指标，不包含音频或完整转录。

## 10. 故障和降级

| 故障 | 行为 |
| --- | --- |
| 无网络/未同意移动流量 | 停留初始化页 |
| 空间不足 | 显示精确缺口并允许重试 |
| 暂停 | 保留分片，状态为 paused |
| SHA/文件集失败 | 不激活，进入修复 |
| 第二次启动文件缺失/大小异常 | 进入修复并完整校验 |
| Engine 初始化或推理失败 | 不自动切换；录音继续，显示修复/重试 |
| 官方 Dart 分离绑定未释放完整波形缓冲区 | 生产自动分离保持关闭并写入明确降级；等待官方版本修复，不使用私有 API 绕过 |
| 预览积压 | 丢最旧预览任务，绝不丢录音 |
| 最终转录失败 | 保留事实音频和旧活动快照 |
| 说话人分离失败/超时/空结果 | 生成单一说话人降级结果，与成功的最终文本一起原子发布 |
| 联合处理仍在运行 | 不发布半成品；保留事实音频并显示真实处理状态 |
| WAV 临时空间不足 | 不生成文件，显示精确缺口 |
| 音频分享取消或失败 | 清理临时 WAV，不影响事实 PCM |

## 11. 安装包与供应链门禁

- `pubspec.yaml` 只能声明 Manifest 和许可证，不声明 `.onnx` 或模型 tokens。
- APK/IPA 必须审计：没有 SenseVoice、Paraformer、Qwen、Silero VAD、Pyannote 或 3D-Speaker 权重；官方 sherpa-onnx 运行库可存在。
- Manifest 与归档解析拒绝 HTTP、路径穿越、绝对路径、符号链接、重复文件、空哈希、错误总量和不兼容 schema。
- Pyannote MIT 许可与 3D-Speaker 精确模型许可/NOTICE 均须进入安装包；精确权重许可未确认时不得发布。
- 依赖只允许官方 `sherpa_onnx` 包，不新增 JNI、FFI/C API、自建 C/C++ 链或手工 `jniLibs`。

## 12. 验证

自动化至少覆盖：Registry 单模型、全部固定 Manifest/hash/revision、300 MB 上限、1 GiB 空间差额、移动网络同意绑定、暂停续传、受限归档解包、所有资源原子准备、快速离线启动、SenseVoice/分离配置、会议锁定、联合任务竞态、单次快照发布、分离降级、手工标签 CAS、确定性标题、WAV 封装与临时清理、旧库阻断和录音连续性。ASR 与分离均通过 fake worker 验证错误、取消、释放和时序；自动化不加载真实模型权重，真机性能和准确率仍由外部门禁负责。

交付运行：

```powershell
dart format lib test integration_test
flutter analyze
flutter test
flutter build apk --debug
```

目标真机还必须完成 PRD 的 SenseVoice RTF P95、结果延迟 P95、关键事实召回率、说话人 DER/人数误差/RTF、30 分钟电量/温控/内存、后台录音和音频分享验证。Windows 不能替代 iOS arm64 构建与真机证据。
