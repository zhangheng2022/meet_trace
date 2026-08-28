# 会迹（MeetTrace）端侧转录技术方案

> 上游：[Alpha PRD V1.5](../product/Alpha_PRD_无登录版.md)。本文只定义实现契约，不重复产品验收或可直接读取的 Manifest 字段。

## 1. 不变量

- 事实 PCM 是唯一事实源；先落盘，再把副本送给 VAD、ASR、波形和说话人分离。
- 录音不依赖推理。预览队列可丢最旧任务，录音字节不可丢。
- ASR 只通过官方 `sherpa_onnx` 包接入固定 SenseVoice；说话人分离只通过官方 `OfflineSpeakerDiarization` API。
- 权重不进入 APK、IPA 或 MSIX；完整资源集合未就绪时阻断首页。
- 会议创建时锁定 ASR、语言、ITN、分段模型、嵌入模型和聚类配置；会中、最终和重试不得静默换配置。
- 最终 ASR 与分离在封存后并行，完成后只原子发布一次快照；分离失败降级为单一说话人，ASR 失败保留旧快照。

## 2. 工程事实源

| 内容 | 事实源 |
| --- | --- |
| SenseVoice URL、大小、哈希、许可 | `assets/models/manifest.json` |
| Silero VAD | `assets/models/silero-vad-manifest.json` |
| Pyannote、3D-Speaker 与推理参数 | `assets/models/speaker-diarization-manifest.json` |
| 固定模型注册 | `lib/domain/models/asr_model_registry.dart` |
| 依赖版本 | `pubspec.yaml`、`pubspec.lock` |
| 数据 schema 与 generation | 当前迁移、`LocalDataGenerationGate` 及守卫测试 |
| 更新入口与公钥 | `updates/alpha/` 和 update adapter |

全部运行时下载不得超过十进制 300 MB，初始化要求应用卷至少 1 GiB 可用空间。URL 必须为 HTTPS；许可与 NOTICE 随安装包分发。

## 3. 分层

```text
View → ViewModel → Use Case / Port → Repository / Service
```

UI 只依赖 Domain 状态。下载、文件、SQLite、HTTP、`sherpa_onnx`、`record`、MSIX、TestFlight、Store 与平台通道都留在 data 或 runner 层。

- 初始化：`InitializeRuntimeAssetsUseCase → RuntimeAssetPreparationPort`。
- 录音/转录：`StartMeetingUseCase / FinalResultCoordinator → AsrEngine / SpeakerDiarizationService`。
- Windows：输入设备、连续性和桌面生命周期通过 Port；ViewModel 不导入 Win32。
- 更新：`CheckForAppUpdateUseCase → AppUpdatePort → Android/iOS/Windows adapter`。

## 4. 资源初始化

快速路径只检查安装状态、活动版本、固定文件集和字节数，不联网、不重算大文件哈希。首次下载、显式修复或快速检查失败时执行完整 SHA-256。

1. 校验所有 Manifest 与 300 MB 上限。
2. 完整资源集合未就绪时检查 1 GiB 可用空间。
3. Android/iOS 在移动或未知网络上要求与资源集合绑定的同意；Windows 网络可用即下载。
4. 使用 `.partial` 和 HTTP Range 续传；服务器不满足 Range 合同时安全重下该文件。
5. 归档在受限临时目录解包，拒绝绝对路径、路径穿越、符号链接和白名单外安装文件。
6. 校验固定文件集、大小和 SHA-256 后原子激活；失败不覆盖已激活版本。

暂停保留分片。任一资源变化都会使旧移动网络同意失效。空间不足返回精确差额；安装记录损坏或 Engine 初始化失败进入同一修复流程。

## 5. 录音、VAD 与 ASR

采集为 16 kHz 单声道 PCM16。平台支持时请求 AGC/AEC/NS；增强启动失败后以同规格关闭增强重试一次。音频先写事实文件，再驱动其他消费者。

会中预览与最终转录使用独立 Engine 实例。录音先启动，预览异步初始化；结束会议时丢弃预览积压，不等待其清空。

最终转录流式扫描完整 PCM，并用已校验 Silero VAD 生成全局语音区间：

- 每个 VAD 区间独立识别；语音不超过 15 秒时保持单窗口，只收窄最多 200 ms 上下文。
- 语音超过 15 秒时使用 500 ms 重叠窗口，并以至少 4 个规范化字符的可信重叠确定性合并。
- 全静音直接生成空的完成快照，不初始化 SenseVoice。
- VAD 创建、扫描、flush 或区间校验失败返回可重试错误，不回退为固定切片；释放异常不能推翻已经生成的有效区间。

## 6. 说话人分离与最终快照

分离固定读取同一 16 kHz 单声道事实 PCM，在独立 isolate 中创建和释放模型。Domain 超时可直接终止 worker；不允许私有绑定、自建 JNI/FFI 或原生桥。

`FinalResultCoordinator` 并行运行最终 ASR 与分离；跨会议使用应用级 FIFO 单并发，同一会议内仍并行。按时间重叠把 `SpeakerTurn` 映射到转录片段。分离超时、空结果或失败时生成单一说话人结果；只有 ASR 成功后才事务写入并激活新快照。

说话人显示标签修订以活动快照为基线，用 CAS 原子替换；不得改变文本、时间轴、模型配置或事实音频。

## 7. 数据、分享与平台

- 会议标题在创建时按本地时间确定性生成；重命名只更新标题字段，后台状态写入不得覆盖新值。
- 数据 generation 在数据库和运行资源初始化前检查。缺失或不匹配时清理应用数据根并重走初始化；标记读取异常必须阻断，不能继续清理。
- 文本分享只读活动最终快照。音频分享先确认，再只读封装临时 WAV；完成、取消、失败和冷启动恢复都清理应用自有临时文件，不遍历无关目录或跟随符号链接。
- Windows 先建立单实例，再打开数据库。录音中 close 转托盘；“停止并退出”必须在 PCM 封存和状态保存后才允许原生退出。
- Windows 输入设备在会议开始时锁定；断开后刷新检查点，仅尝试一次系统默认输入。睡眠期间不承诺采集，恢复后记录缺口。
- 更新 Manifest 先验 Ed25519 签名，再校验频道、状态、版本和平台身份。Android 还校验长度、哈希、包名、`versionCode` 与签名；iOS 只打开固定 TestFlight；Windows 只接受 Store 产品 `9PHHSJMWK06G`。录音或最终处理期间只标记 deferred。
- Sentry 按[配置说明](../project/Sentry_配置.md)接入；故障降级为无监控启动。

## 8. 故障语义

| 故障 | 结果 |
| --- | --- |
| 网络、空间、下载或校验失败 | 留在初始化/修复流程，不激活半成品 |
| Engine 或预览失败 | 继续录音，提供修复或重试 |
| 最终 ASR 失败 | 保留事实音频和旧快照 |
| 分离失败 | 单一说话人降级并发布成功文本 |
| Windows 输入中断或睡眠 | 记录真实中断/缺口，不伪造连续音频 |
| 更新签名、哈希或身份失败 | 忽略候选，不影响启动、录音或历史 |
| 分享失败或取消 | 清理临时 WAV，不改写 PCM |

## 9. 验证

自动化至少覆盖资源上限与哈希、续传和原子激活、单模型锁定、录音连续性、最终 VAD/ASR、分离竞态和降级、快照 CAS、分享清理、数据 generation、Windows 输入/单实例/托盘/睡眠，以及更新验签与 deferred。测试使用 fake worker，不加载真实权重。

```text
dart format lib test
flutter analyze
flutter test
flutter build apk --debug
flutter build windows --debug
flutter build windows --release
```

性能、准确率、DER、人数误差、内存、能耗和温控只作非阻断观测。发布门禁见[质量与验收](../quality/README.md)和[发布规格](../../spec/spec-process-cicd-alpha-release.md)。
