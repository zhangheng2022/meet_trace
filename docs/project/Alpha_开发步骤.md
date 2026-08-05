# 会迹（MeetTrace）Alpha 开发步骤

> 状态：活动；V0.9 单人收尾执行清单
> 最终目标：Android + iOS 受控内部 Alpha；Android 先闭环
> 更新日期：2026-08-05

## 1. 当前结论

- 阶段 1、阶段 2、阶段 4、阶段 5 的仓库实现与应用标识统一已完成，固定镜像也已在 `mt.zhangheng.eu.org` 通过状态码、大小、ETag 与 Range 验收。阶段 3 的官方 Dart `OfflineSpeakerDiarization` worker、取消/释放和 Debug/Release 生产装配已落地；2026-08-05 产品决策接受当前官方绑定的已知内存风险，所有会议默认开启且保留全局关闭开关。剩余门槛包括目标真机阈值校准与性能证据、上游缺陷跟踪，以及双平台真机分享接收与播放证据。
- 旧的格式化、测试、APK 与 OCR 结果只作为历史证据；V0.9 代码完成后必须重建当前基线。
- 普通重构、视觉微调和非阻断技术债不进入 Alpha 主线，统一记入 Alpha 后 backlog。
- Web、Windows、Linux 与 macOS 工程壳暂时保留，但不属于产品支持面，也不进入发布结论。

## 2. 串行交付顺序

### 阶段 0：产品与文档基线

- [x] 通过 `$grill-me` 确认 V0.9 产品范围与取舍。
- [x] PRD 移除 AI 总结，固定确定性标题、真实说话人分离、音频分享和内部发布边界。
- [x] 固定 Pyannote INT8、3D-Speaker、300 MB 下载上限、1 GiB 空间门槛和普通话分离质量指标。
- [x] 完成全仓活动文档冲突检查、链接检查和 Graphify 更新。

完成证据：活动文档不再把 AI 总结或“待生成标题”写成当前 P0；历史 Step 文档明确只作为旧实现证据。

### 阶段 1：删除旧总结链与提升数据代

- [x] 删除 summary 专属 domain/data/UI/app 代码、数据库表、处理任务、测试与预览夹具，不保留隐藏入口或 `UnavailableSummaryGenerationService`。
- [x] 会议创建时按本地开始时间生成 `yyyy-MM-dd HH:mm 会议`，删除“待生成标题”状态与总结回写标题路径。
- [x] 建立 schema 7 干净安装基线并把 `LocalDataGenerationGate` 提升至数据代 3；旧安装由数据代门全清后重走初始化，数据库层继续拒绝原地升级。
- [x] 更新删除会议、文本分享、详情页和数据控制，只覆盖录音、转录、说话人标签、处理记录和后续临时分享文件。

完成证据：全仓不存在生产 summary 入口；数据代门与确定性标题测试通过；旧 schema 继续被兜底拒绝。

### 阶段 2：说话人运行时资产

- [x] 新增 `speaker-diarization-manifest.json`，固定官方 Pyannote 归档与 3D-Speaker 权重的 URL、大小、SHA-256、安装文件集和 NOTICE。
- [x] 扩展通用安装事务以支持受限 `tar.bz2` 解包，拒绝绝对路径、路径穿越、符号链接和白名单外文件。
- [x] 把全部运行时下载总量锁定为 `286,314,800` B，空间预检改为 `1,073,741,824` B；任一资源变化使移动网络同意失效。
- [x] 初始化 UI 展示全部资源的真实进度；完整集合未就绪前保持阻断，第二次启动仍走纯本地快速检查。
- [x] 依据精确模型元数据确认 3D-Speaker 权重为 Apache-2.0，并将许可与 NOTICE 加入安装包。

完成证据：Manifest、解包攻击面、续传、暂停、校验、原子激活、快速启动和 300 MB/1 GiB 门槛自动化全部通过；仓库与构建产物无权重。

外部前置已解除：`mt.zhangheng.eu.org/models/SpeakerDiarization/` 下两份固定镜像已于 2026-08-03 上传；公网检查返回 200，大小与本地原件一致，ETag 与本地 MD5 一致，Range 请求返回 206。

### 阶段 3：真实离线说话人分离

- [x] 已通过官方 `sherpa_onnx` Dart `OfflineSpeakerDiarization` 完成 `SpeakerDiarizationService` 适配，并在 Debug/Release 生产组合根启用；所有会议默认开启、不设会议时长上限、不显示前置风险提示，设置中保留全局关闭开关。`1.13.4` 的完整波形原生缓冲区未释放风险已由 2026-08-05 产品决策接受并继续跟踪。
- [ ] 固定 16 kHz 单声道输入、Pyannote INT8、3D-Speaker、`numClusters=-1`；当前 Manifest 暂定 threshold `0.5`，仍需用普通话 2/3/4 人语料校准后锁定发布值。
- [x] 在独立 worker/isolate 中运行，自动化覆盖初始化失败、初始化期间取消、超时终止、空结果、释放和重复创建；该隔离不能释放官方 Dart 绑定遗漏的原生波形缓冲区。
- [x] 保留手工说话人显示标签修订，不改变文本、时间轴或事实音频。

完成证据：不少于 60 分钟标注语料总体 DER `≤25%`、人数绝对误差 `≤1`、30 分钟 RTF `≤0.5`；Android/iOS 分别留证。

### 阶段 4：联合最终结果

- [x] 录音封存后由 `FinalResultCoordinator` 从同一事实音频并行启动最终 ASR 与说话人分离。
- [x] 两条任务结束后在内存中合并，并只通过一次 CAS 事务发布最终快照；处理中不展示半成品。
- [x] 分离失败、超时、空结果、能力关闭或缺少可取消生命周期时写入单一说话人降级结果；ASR 失败时终止分离并保留事实音频和旧快照。
- [x] 自动化覆盖并行启动、等待屏障、同会议串行、恢复快照 ID、任务状态、CAS 冲突、重试幂等和资源释放；详情页处理状态已改为真实并行语义。

完成证据：联合状态机单元测试、组件测试和设备流程通过；所有失败路径都不影响事实音频。

### 阶段 5：文本与音频分享

- [x] 文本分享只输出标题、会议时间和带说话人/时间戳的最终转录。
- [x] 音频分享使用独立入口，每次显示会议名、时长、大小和敏感信息提醒并二次确认。
- [x] 只读封装事实 PCM 为临时 WAV；应用自有临时目录和 Android `share_plus` 插件缓存均覆盖完成、取消、失败与启动恢复清理；空间不足显示精确差额。
- [x] 分享不改变源 PCM，不默认把文本和音频捆绑发送。

当前证据：共享 PCM16/WAV 写入器、独立 Domain Use Case、`share_plus` 文件分享、二次空间校验、并发应用临时目录和启动恢复已落地；WAV 头、RIFF 上限、源 PCM 不变、空间精确差额及组件确认测试通过。2026-08-04 Pixel 10 模拟器复验确认：系统面板打开期间插件副本可读，取消并回到应用后 `cache/share_plus` 与应用自有临时目录均无残留，冷启动也会清理旧插件缓存，事实 PCM 不变。Android/iOS 真机各一次接收端播放与清理仍属外部门禁，AT-18 整项尚不能判定通过。

### 阶段 6：应用标识与内部发布

- [x] Android `applicationId`/namespace 与 iOS Bundle ID 统一为 `com.meettrace.app`，更新 Android 原生入口并增加双端配置守卫。
- Android 生成签名 APK，直接分发给受控内部测试者；不做公开商店发布或应用内更新。
- iOS 配置 Apple Team，通过 TestFlight 内部测试；不公开上架。
- 不接入远程埋点或崩溃上报；诊断仅由用户主动导出且不含音频或完整转录。

完成证据：两端包标识、覆盖安装/数据代行为、签名、权限用途、隐私清单和构建产物审计通过。

### 阶段 7：重建仓库质量基线

```powershell
flutter pub get
dart format lib test integration_test
flutter analyze
flutter test
flutter build apk --debug
```

- 解包 Android 产物，确认不存在 `.onnx`、模型 token、ASR/VAD/说话人权重、会议音频、转录或分享临时文件。
- 使用 `$open-code-review-delegate` 审查全部 reviewable 源码与配置；修复 Critical/High，保留 Medium 时写明风险和后续动作。
- 复验受影响测试与构建，并运行 `graphify update .`。

完成证据：命令、日期、环境、产物和 OCR 范围写入活动质量文档；未解决 Critical/High 为零。

### 阶段 8：Android 阶段里程碑

1. Mi 10 完成主链冒烟与 30 分钟预检。
2. API 24 arm64 真机完成最低系统安装、权限、恢复和模型生命周期。
3. 约 4 GB RAM arm64 真机完成 SenseVoice 与说话人分离性能、准确率、内存、电量和温控。
4. `com.meettrace.app` 签名 APK 交付受控测试者。

只有三类设备证据和 AT-01～AT-18 的 Android 适用项均完成，Android 阶段才可判定 `go`；Mi 10 单机不能替代完整矩阵。

### 阶段 9：iOS 与双平台里程碑

1. macOS/Xcode 完成无签名构建与 App bundle 审计。
2. 配置 Apple Team、`com.meettrace.app` 和 TestFlight。
3. iPhone/iPad 完成后台录音、系统中断、联合最终结果、分享、Dynamic Type、VoiceOver、性能和温控。
4. iOS 适用 AT-01～AT-18 全部留证后再做双平台 Go/No-Go。

缺少 macOS/Xcode、Apple Team、iPhone 或 iPad 时，只记录外部前置条件，不用模拟器或 Android 证据替代。

## 3. 当前阻塞清单

| 优先级 | 阻塞项 | 解除条件 |
| --- | --- | --- |
| P0 | 官方 `sherpa_onnx` Dart 分离接口泄漏完整波形原生缓冲区 | 升级到已释放缓冲区的官方版本，并完成 30 分钟重复任务内存复验；不得用私有 API/自建 FFI 绕过 |
| P0 | 说话人阈值与性能尚无目标真机证据 | 完成普通话标注语料校准及 Android/iOS DER、人数误差、RTF、内存证据 |
| 外部 | 音频分享缺少双平台真机证据 | Android/iOS 各完成一次系统分享并确认接收端可播放、临时目录无残留 |
| 外部 | Android 正式签名与 iOS Apple Team 未配置 | 配置受控签名密钥与 Apple Team；不得把 Debug 签名产物当作内部发布包 |
| 外部 | Android 最低/低端设备缺失 | 获取目标真机并完成矩阵 |
| 外部 | iOS 工具链、签名与设备缺失 | macOS/Xcode、Apple Team、iPhone/iPad 就绪 |

## 4. 发布状态

当前 V0.9 的仓库门禁、Android 完整设备矩阵和 iOS 证据都未闭环，整体发布状态为 `blocked`。Android 可以先形成独立阶段里程碑，但不得被描述为双平台 Alpha 已完成。
