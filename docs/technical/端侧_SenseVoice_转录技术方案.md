# 会迹（MeetTrace）端侧 SenseVoice 与说话人分离技术方案

> 日期：2026-08-18
> 对应 PRD：V1.2
> 状态：活动；Android/iOS 主链已实现，Windows 输入、桌面生命周期与睡眠恢复首轮已落地；自动更新的签名 Manifest、三平台 adapter、延后状态和原子发布链已实现，Store 限定受众/Flight、正式认证及首次三平台统一发布仍待按第 13 节验收

## 1. 目标

以官方 `sherpa_onnx` Flutter/Dart 包接入固定 SenseVoice INT8、Pyannote INT8 和 3D-Speaker 模型，在不牺牲可靠录音的前提下为 Android、iOS 与 Windows 提供会中预览，以及带说话人标签的联合最终结果。全部 ASR、VAD 和说话人权重不随 APK、IPA 构建产物或 MSIX 分发，而在首次初始化时安全下载；第二次启动可完全离线快速通过。

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

同一 Manifest 固定 Engine 输入与聚类配置：16 kHz 单声道、CPU provider、2 threads、`numClusters=-1`、`minDurationOn=0.2`、`minDurationOff=0.5`。工程接入暂用 threshold `0.5`；该值不是质量达标结论，应经过普通话 2/3/4 人标注语料校准并记录，结果由团队评估。

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

Windows 与自动更新扩展沿用同一边界：

```text
Settings / Recording ViewModel
  → SelectRecordingInputUseCase / HandleRecordingInterruptionUseCase
    → RecordingInputDevicePort / RecordingContinuityPort
      → data/services/audio/windows/*
        → record Windows 公开插件 API 与平台事件适配器

Application shell / Recording ViewModel
  → DesktopLifecycle Port
    → data/services/platform/* + Windows runner
      → MethodChannel 与 Win32 窗口、托盘、命名互斥/激活事件

Startup / Settings ViewModel
  → CheckForAppUpdateUseCase
    → AppUpdatePort
      → data/services/update/{manifest,android,ios,windows}
```

Domain 模型只表达输入设备身份、设备中断、音频缺口、更新候选与更新安全状态，不导入 Windows、MSIX、PackageInstaller、TestFlight 或 `.appinstaller` 类型。Windows 插件、进程互斥、托盘和签名细节不得进入 ViewModel；View 只呈现 ViewModel 暴露的不可变状态。现有会议列表/预览和详情宽屏布局继续复用，不创建 Windows 专用业务页面。

## 4. 初始化状态机

状态包括：检查本地资源、等待网络、等待移动网络同意、下载 ASR、下载 VAD、下载说话人分段/嵌入资产、解包、校验、暂停、失败和就绪。

快速路径只检查：安装记录为 `installed`、活动版本匹配、目录只包含固定文件、每个文件大小匹配。它不联网、不做远端版本查询，也不在每次启动计算大文件 SHA。首次下载、显式修复以及快速路径失败时执行完整 SHA-256。

准备流程：

1. 校验全部 Manifest 的固定总量不超过 `300,000,000`。
2. 尝试 ASR、VAD 和说话人资源的本地快速检查；完整集合同时就绪才返回。
3. 检查应用卷可用空间至少 `1,073,741,824` 字节；错误携带精确缺口。
4. Android/iOS 根据网络状态决定自动下载、等待网络或请求移动网络同意；Windows 在网络可用时自动下载，并保留暂停、续传和重试。
5. 顺序准备 SenseVoice、VAD、Pyannote 归档与 3D-Speaker，并把分项进度映射到全局字节进度。
6. Pyannote 归档先验证下载文件 SHA-256，再在受限临时目录解包；拒绝绝对路径、路径穿越、符号链接和非白名单文件，只激活固定的 INT8 模型与许可文件。
7. 严格校验每项临时目录后分别原子改名，只有完整资源集合都就绪才开放首页。

移动网络同意只用于 Android/iOS，存入 `app_settings`，值是按 ASR、VAD 与说话人资源 ID、版本、文件大小和哈希排序生成的资源集合标识。任一资源变化都会使旧同意失效。Windows 不写入伪造的移动网络同意记录。

## 5. 下载一致性

- 最终目录、临时目录和 `.partial` 文件均位于 App 私有支持目录。
- HTTP 客户端使用 Range 从现有分片长度继续；服务器不支持预期 Range 时必须安全重启该文件，不得拼接错误内容。
- “暂停”通过 cancellation token 停止活动请求，保留分片和 paused 安装状态。
- 校验固定文件集合、逐文件大小和 SHA-256；多余文件也视为失败。
- 最终目录只在完整校验成功后原子切换；失败不会破坏已激活版本。
- 归档下载、解包目录与活动目录必须分离；激活成功后删除下载归档和未使用的浮点模型，失败或取消时不得留下可被快速路径误认的半成品。

## 6. SenseVoice Engine

`AsrModelRegistry.alpha` 只有一个 descriptor。Factory 拒绝未知 ID、非 `auto` 语言或关闭 ITN 的请求。`SenseVoiceAsrEngine` 只接受与 Registry 完全匹配、已安装、已验证且字节数正确的安装记录，并生成官方 `OfflineSenseVoiceModelConfig`。

识别器在独立 isolate 中持有。会中和最终转录复用统一 `SherpaOnnxAsrEngine` 端口与实现，但每次预览和最终任务使用独立 Engine 实例，不跨阶段复用原生识别器。录音先启动，预览 Engine 随后异步初始化；结束会议丢弃可丢弃的预览积压，不等待其全部推理完成。

最终 ASR 先以有界 PCM 块流式扫描完整事实音频，并使用同一份已校验 Silero VAD 生成全局语音区间；每个原始 VAD 区间独立识别，不再合并相邻区间。语音本身不超过 15 秒时按需缩减前后各 200 ms 上下文并保持单窗口，只有语音本身超过 15 秒时才按 500 ms 重叠切分；重叠文本合并忽略常见边界标点，并要求至少 4 个规范化字符的可信重叠。SenseVoice 延迟到首个语音窗口才初始化；全静音输入生成无片段的 `complete` 快照。VAD 创建、扫描、flush 或区间校验失败时以可重试错误结束最终转录，保留事实音频与旧活动快照，禁止按固定时间硬切后发布低质量结果；已成功生成片段后的 VAD 释放异常不推翻有效结果。

麦克风采集固定通过官方 `record` 插件请求平台自动增益、回声消除和噪声抑制。增强后的 16 kHz 单声道 PCM16 先写入事实音频，再分发给 VAD/ASR，保证最终录音、会中预览和最终转录使用同一音频事实。平台效果属于设备能力：Android 仅启用系统报告可用的 AGC/AEC/NS；iOS 流式录音通过系统 Voice Processing 启用回声消除和自动增益；Windows 只使用 `record_windows` 的公开输入设备和流式 PCM API，不采集 WASAPI loopback、不混合系统音频，也不自建 DSP。如增强录音启动失败，会以同样的 PCM16 规格关闭增强后重试一次，优先保证录音连续可用。

Windows 的全局输入偏好保存稳定设备标识和可读名称，“系统默认麦克风”不提前解析为具体设备；`StartMeetingUseCase` 在创建会议时解析并锁定实际设备。录音协调器监听设备流错误与平台会话事件：设备断开先刷新检查点，仅尝试一次当前系统默认输入；成功后向会议追加中断区间和设备变化事实，失败则进入可恢复的 interrupted 状态。中断开始、回退成功或最终中断按同一 `incidentId` 追加到会议目录的 `continuity.json`，使用 current/next/previous 三代原子替换，记录 UTC 时间、已落盘 PCM 字节位置与输入设备名称。任何设备切换均不能重写已落盘 PCM，也不能让 UI 在没有新字节时继续显示为正常录音。

## 7. 说话人分离与联合最终快照

`SherpaOnnxSpeakerDiarizationService` 只通过官方 `OfflineSpeakerDiarization` Dart API 接入，不自建 JNI、FFI/C API 或原生桥接。固定输入为 16 kHz 单声道事实 PCM；分段使用 Pyannote INT8，嵌入使用 3D-Speaker，`numClusters=-1`。模型在独立 isolate 中按任务创建和释放；worker 在模型初始化尚未完成时也可被 Domain 超时直接终止，不能让已降级任务继续占用 CPU/内存。聚类 threshold 必须在不少于 60 分钟的普通话 2/3/4 人标注语料上校准并固定到 Manifest/配置，UI 不暴露该参数。

供应链审查确认官方 [`sherpa_onnx 1.13.6` Dart 实现](https://github.com/k2-fsa/sherpa-onnx/blob/v1.13.6/flutter/sherpa_onnx/lib/src/offline_speaker_diarization.dart)继承了 1.13.5 为 `process` 与 `processWithCallback` 的 `calloc<Float>(samples.length)` 输入缓冲区增加 `finally` 释放的修复，替代存在完整波形原生堆遗留风险的 1.13.4。生产组合根在 Debug/Release 均装配 `SherpaOnnxSpeakerDiarizationService`，从已校验 Manifest 读取模型路径与推理参数。全局偏好无记录时按开启处理；用户关闭后，`FinalResultCoordinator` 在创建任务前直接跳过分离。实现仍只调用官方公开 API，不导入私有绑定、不自建 FFI；重复长会议内存仅作为非阻断工程观测，不要求形成候选设备证据。

录音封存后，`FinalResultCoordinator` 从同一事实音频并行启动最终 ASR 与离线分离，两者运行在独立 worker/isolate，不能占用录音写入队列。跨会议的联合最终推理由应用级 FIFO 调度器限制为单并发，同一会议内部 ASR 与分离仍并行。ASR 成功且分离成功时，按时间重叠把 `SpeakerTurn` 映射到最终转录片段；分离超时、空结果、内存或推理失败时生成明确的单一说话人降级结果。只有两条任务都结束后才以一次事务写入并激活最终快照；ASR 失败时保留事实音频和旧活动快照，不发布半成品。

用户修改说话人显示标签时，以当前活动快照为基线创建修订并通过 CAS 原子替换；不得改变片段时间、文本、模型配置或事实音频。普通话是 Alpha 分离质量承诺范围，其他语言只允许尽力运行并明确不承诺准确率。

## 8. 会议锁定与数据库

`Meeting` 保存 `recording_model_id`、`recording_model_version`、`recording_model_language` 和 `recording_model_use_itn`，并锁定说话人分段/嵌入模型版本与聚类配置。开始会议时一次写入；后续预览、最终转录和分离从会议读取，不从设置或远端重新解析。单模型基线已删除请求模型与回退原因字段，架构守卫禁止对应列名重新进入 `lib/`。

当前代码已建立 schema 7 与数据代 3 的干净安装基线，并删除总结结构；阶段 4 已通过 `FinalResultCoordinator` 补齐联合结果契约。`LocalDataGenerationGate` 在打开数据库与初始化运行资源之前校验数据代标记（`data_generation.json`），缺失或内容不一致时清空整个 `meettrace/` 数据根目录（数据库、会议音频与快照、模型、检查点、偏好和分享临时文件）并重走首次初始化；文件系统读取异常通过 `LocalDataGenerationMarkerReadException` 阻断启动，绝不继续清理。数据库层继续拒绝所有旧 schema 作为兜底防线。

Windows 使用 `path_provider_windows` 返回的应用本地支持目录作为数据根，并通过 `sqflite_common_ffi` 提供 SQLite factory。安装目录保持只读，数据库、模型、事实 PCM、检查点与更新临时文件不得写入 MSIX 包目录、漫游目录或用户自选路径。单实例协调必须先于数据库和 `LocalDataGenerationGate` 初始化，第二实例只能激活已有窗口，不能并发打开数据库或执行数据代清理。

## 9. 结果标题、分享与数据外发

会议创建时按当时本地时间生成确定性标题 `yyyy-MM-dd HH:mm 会议` 并立即持久化；后续时区变化不改写标题。用户可从会议列表重命名任意未删除会议，输入经 Domain 规范化为去除首尾空格的单行 1～60 字符标题并允许重名。Repository 使用字段级事务只更新 `meetings.title` 并通知会议流，避免后台转录或状态切换以旧会议对象覆盖新标题；该能力复用现有 `title` 列，不提升 schema 或数据代。重命名不移动或改写事实 PCM、会议时间、转录和快照。代码中删除 AI 总结的 Port、Use Case、Service、Repository、表、任务状态、UI 与测试，不保留隐藏入口或不可用生产适配器。

文本分享只读取当前活动最终快照，输出会议标题、时间和带说话人/时间戳的转录，不附带音频。音频分享由 `ShareMeetingAudioUseCase` 独立编排：先计算目标 WAV 大小和可用空间，展示名称、时长、大小与敏感信息确认；确认后再次校验空间，从事实 PCM 只读分块生成每次分享独占的临时 WAV，通过 `share_plus` 调用系统分享面板，并在完成、取消、结果不可判定、异常或下次启动恢复时清理应用自有临时文件。源 PCM 不移动、不重命名，也不被转码覆盖。Android 额外清理 `share_plus` 创建的精确缓存子目录：取消、不可用和异常立即清理；成功路径等待应用离开前台并重新恢复后再清理，避免接收端尚未读取时提前删除；冷启动还会恢复清理旧残留。该清理不遍历临时目录的其他内容，也不跟随符号链接越界。

Windows runner 在数据库初始化前使用同一用户会话内的命名互斥体和激活事件阻止第二实例；第二次启动只唤醒现有窗口。录音 ViewModel 通过 `DesktopLifecycle` Port 和 MethodChannel 同步保护状态：窗口外壳在录音中拦截 close 请求并隐藏到托盘，托盘菜单只发送“打开会迹”或“停止并退出”领域命令，不直接停止插件或删除文件；只有事实 PCM 封存且会议状态保存成功后 Dart 才确认原生退出，失败则恢复窗口并保持保护。空闲 close 正常退出。系统锁屏、最小化和失焦不改变录音状态；runner 将 `WM_POWERBROADCAST` 的挂起/恢复与 `WM_QUERYENDSESSION` 映射为有序领域事件。挂起前先排空已进入 Dart 的 PCM、刷新文件与检查点并记录字节偏移；恢复时先重开会议锁定输入，失败后仅允许一次系统默认输入降级，同一 `incidentId` 记录缺口起止或真实恢复失败。注销/关机属于尽力刷新，冷启动恢复仍以检查点和已落盘 PCM 为准，不等待 OS、也不把未收到的音频补零伪装为事实。

自动更新由 `AppUpdatePort` 消费 `updates/alpha/alpha.json` 的单一 Alpha 频道签名 Manifest，Domain 校验候选构建号必须高于当前版本，并要求状态为公开批准。签名 envelope 直接覆盖 Base64 解码后的原始 payload 字节，避免 JSON 重排歧义；parser 先用内置 Ed25519 公钥验签，再限定 `alpha` 频道、公开批准/撤回状态、同 SHA 候选和各平台固定入口。Android adapter 把不超过 512 MiB 的 APK 下载到应用私有目录，下载前必须在包体之外保留 128 MiB 录音空间，并验证长度、SHA-256、包名、版本/构建号和签名证书，交接系统安装器前再次复核；iOS 只打开受限 TestFlight URL；Windows 只接受 `ms-windows-store://pdp/?productid=9PHHSJMWK06G` 和包身份 `zhangheng2026.MeetTrace`，拒绝 `.appinstaller` 与其他 Store 产品。录音或最终处理运行时更新状态只能是 deferred，回到空闲后自动续检；提高数据代必须在平台安装交接前取得清理确认。检查、下载或交接失败均不阻断启动、事实写入或历史访问。

发布工作流仅从不设 reviewer 的 `github-release` Environment 读取 Ed25519 私钥 seed。协调器先验证 TestFlight、Store Flight/production 和两阶段真实分发门禁，再恢复最终 job；最终 job 验证协调器不可变回执、公开原 Draft，并用 Contents API 的旧 blob SHA 原子更新 `updates/alpha`。修复允许同 release/build 重签，撤回只允许当前 `publicApproved` 变为 `withdrawn`，已撤回版本不能重新公开。密钥不进入命令行、日志、Artifact、Release 或生成分支。

App 不接入业务分析埋点或总结网关。Release 组合根通过 data/service 层初始化 Sentry，启用 PII、日志、指标、截图、View Hierarchy、交互、失败请求、原生崩溃、ANR、Tracing、Profiling 和 Replay；画面内容保持全量文本与图片遮罩。录音 ViewModel 通过 domain Port 驱动遥测 Gate，录音期间停止新 Tracing/Profiling、交互 Breadcrumb、错误截图和 View Hierarchy，崩溃与 ANR 保持开启。官方 SDK 9.26 无公开 Replay 暂停 API，录音期间继续遮罩采集，不增加私有原生桥接。Sentry 初始化失败时组合根降级为无监控启动；不得阻断事实录音。诊断导出仍只包含白名单状态、错误码和设备指标，不包含音频或完整转录。

## 10. 故障和降级

| 故障 | 行为 |
| --- | --- |
| 无网络/未同意移动流量 | 停留初始化页 |
| 空间不足 | 显示精确缺口并允许重试 |
| 暂停 | 保留分片，状态为 paused |
| SHA/文件集失败 | 不激活，进入修复 |
| 第二次启动文件缺失/大小异常 | 进入修复并完整校验 |
| Engine 初始化或推理失败 | 不自动切换；录音继续，显示修复/重试 |
| 官方 Dart 分离绑定未释放完整波形缓冲区 | 按已接受 Alpha 风险继续启用；可选观测长会议内存，运行失败或资源不足时单一说话人降级，等待官方修复且不使用私有 API 绕过 |
| 预览积压 | 丢最旧预览任务，绝不丢录音 |
| 最终转录失败 | 保留事实音频和旧活动快照 |
| 说话人分离失败/超时/空结果 | 生成单一说话人降级结果，与成功的最终文本一起原子发布 |
| 联合处理仍在运行 | 不发布半成品；保留事实音频并显示真实处理状态 |
| WAV 临时空间不足 | 不生成文件，显示精确缺口 |
| 音频分享取消或失败 | 清理临时 WAV，不影响事实 PCM |
| Windows 输入设备断开 | 刷新检查点并仅尝试一次系统默认设备；失败则显示真实中断并等待恢复 |
| Windows 睡眠/休眠 | 不宣称睡眠期间连续录音；恢复后记录缺口并继续同一会议 |
| Windows 第二实例 | 激活已有窗口，不打开数据库、不启动新录音 |
| 更新 Manifest 不可用或签名/哈希失败 | 忽略候选并保留当前版本；不阻断启动、录音或历史访问 |
| 录音/最终处理期间发现更新 | 标记 deferred，任务结束且应用空闲后再交给平台更新器 |
| SignPath 审核结果到达 | 当前 Store 路线不变；只记录结果。启用 GitHub MSIX 前必须验证包身份兼容性、更新 PRD 并停止 Store 路线 |

## 11. 安装包与供应链门禁

- `pubspec.yaml` 只能声明 Manifest 和许可证，不声明 `.onnx` 或模型 tokens。
- APK、IPA 构建产物和 MSIX 必须审计：没有 SenseVoice、Paraformer、Qwen、Silero VAD、Pyannote 或 3D-Speaker 权重；官方 sherpa-onnx 平台运行库可存在。
- Manifest 与归档解析拒绝 HTTP、路径穿越、绝对路径、符号链接、重复文件、空哈希、错误总量和不兼容 schema。
- Pyannote MIT 许可与 3D-Speaker 精确模型许可/NOTICE 均须进入安装包；精确权重许可未确认时不得发布。
- 依赖只允许官方 `sherpa_onnx` 包，不新增 JNI、FFI/C API、自建 C/C++ 链或手工 `jniLibs`。
- Windows 只构建 x64 MSIX，当前唯一正式路线为 Microsoft Store。Manifest 固定 Store 的 Name、Publisher、PublisherDisplayName，Store 包版本使用 `1.0.<共享发布构建号>.0` 传输映射并另行记录营销版本；候选从可验证 CI 进入 Actions Artifact。一次性 bootstrap 完成 Partner Center 产品、固定 Flight 与自动认证后发布配置；每个候选自动进入 Package Flight，通过专用机验证后将同一包提交 100% production，等待 `Published/Public` 并再次验证。Store 签名前的候选不得放入 GitHub Release 或引导用户旁加载。
- SignPath Code signing policy 仅作为仍在审核的未来直发方案保留，当前工作流不得引用 SignPath 凭据或生成第二个 Windows 包身份。若未来考虑启用，必须先验证证书 Subject、升级和数据连续性，更新 PRD，并停止 Store 路线。
- APK、Store submission、三平台候选清单和公开更新 Manifest 都是不可变发布证据；iOS IPA 只进入 TestFlight，Windows MSIX 只进入 Actions Artifact/Partner Center。公开更新指针只能在三平台批准后改变，不得指向 Draft 或 Package Flight。

## 12. 验证

自动化至少覆盖：Registry 单模型、全部固定 Manifest/hash/revision、300 MB 上限、1 GiB 空间差额、移动网络同意绑定、Windows 自动下载、暂停续传、受限归档解包、所有资源原子准备、快速离线启动、SenseVoice/分离配置、会议锁定、联合任务竞态、全局推理 FIFO、最终静音跳过、VAD 故障阻断发布与可重试错误、VAD 释放异常保留有效片段、单次快照发布、分离降级、手工标签 CAS、确定性标题、WAV 封装与临时清理、旧库阻断、Windows 输入设备锁定/断开、单实例、托盘 close、睡眠缺口、更新延迟和录音连续性。ASR 与分离均通过 fake worker 验证错误、取消、释放和时序；自动化不加载真实模型权重。性能与准确率可按需要观测，但不要求目标设备人工证据，也不进入公开批准条件。

交付运行：

```powershell
dart format lib test
flutter analyze
flutter test
flutter build apk --debug
flutter build windows --debug
flutter build windows --release
```

SenseVoice RTF、结果延迟、关键事实召回率、说话人 DER/人数误差/RTF、长会议内存、能耗和温控属于非阻断工程观测。候选发布不要求提交设备记录；后台、托盘、音频分享和系统中断继续由自动化契约覆盖，MSIX 安装与升级继续按分发门禁验证。

## 13. Windows 与统一更新实施顺序

每阶段必须独立满足退出条件；不得因工程壳可以构建就提前把 Windows 标为受支持。

| 阶段 | 交付内容 | 退出条件 |
| --- | --- | --- |
| 0. 范围基线 | PRD V1.2、技术方案、质量矩阵和发布合同 | Windows 仍标记“规划中”；产品决策和不支持项无冲突 |
| 1. 构建与依赖探针 | Windows x64 Debug/Release 构建；验证 `record_windows`、`sherpa_onnx_windows`、SQLite FFI、播放和分享 | 不加载权重的构建/启动冒烟通过；记录插件能力缺口，不用私有 sherpa 绑定绕过 |
| 2. Domain 与 data 能力 | 输入设备、连续性事件、桌面生命周期、单实例和更新 Port/Use Case；Windows adapter | Domain 不导入平台包；单元测试覆盖锁定、断开、睡眠、第二实例和更新 deferred |
| 3. 桌面体验 | 托盘与 close 语义、窗口最小尺寸、现有双栏复用、键鼠焦点和屏幕阅读器 | Widget/integration 测试通过；录音中关闭窗口不丢 PCM；空闲关闭正常退出 |
| 4. 更新与打包 | Android 更新 adapter、iOS TestFlight 状态、Windows Store MSIX、Store-only 更新入口和公开 Manifest | 更新只消费批准候选；录音/处理期不安装；固定 Store 身份、首次 Private audience/后续 Flight 与正式 submission 已验证 |
| 5. CI/CD | Windows runner、MSIX 审计、三平台候选清单、同 SHA/版本门禁和原子公开更新指针 | 任一平台失败阻断；Draft/Flight 不可被自动更新发现；公开资产不可覆盖 |
| 6. 自动化与分发闭环 | 三平台行为自动化、Windows Store Private audience/Flight、正式认证、安装与更新 | PRD AT-01～AT-26 的自动化、构建和分发门禁通过，OCR Critical/High 为零；不要求目标设备人工证据 |
| 7. 首次统一发布 | 同一 SHA 的 Android APK、iOS TestFlight 与 Windows Store submission | 确认 Store submission 已公开可安装，再批准 GitHub Pre-release；此时才把 README 的 Windows 状态改为“受支持” |

实施代码时按 `Domain Model → Port/Use Case → data adapter → ViewModel → View → 组合根` 顺序推进。每个行为阶段先补 `dart-add-unit-test` 或 `flutter-add-widget-test`，交付前运行格式化、静态分析、全量测试、Android/Windows 构建、分发门禁验证和 `$open-code-review-delegate`；代码改动完成后运行 `graphify update .`。
