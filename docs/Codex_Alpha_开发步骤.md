# 会迹（MeetTrace）Android Alpha — Codex 开发步骤

> 版本：V1.0
> 状态：当前执行计划
> 更新日期：2026-07-25
> PRD：[会迹（MeetTrace）Android Alpha PRD V0.5](./会迹_MeetTrace_Alpha_PRD_无登录版.md)
> 技术基线：[端侧双模型转录技术方案](./端侧双模型转录技术方案.md)

## 1. 使用方式

本文把两周 Alpha 拆成可独立验收的 Codex 任务。每次只执行一个步骤；开始前读取 PRD、技术方案、`AGENTS.md` 和该步骤，结束时运行该步骤的验证命令并更新状态。

推荐指令：

```text
请执行 docs/Codex_Alpha_开发步骤.md 的 Step XX。
先核对前置条件，再按测试驱动实现；不要扩展 P0。
完成后报告修改文件、验证命令、剩余风险和下一步。
```

若步骤会修改 P0、验收标准、模型决策或数据上传边界，先停止并更新 PRD；不得通过代码悄悄改变产品范围。

## 2. 当前仓库基线

截至 2026-07-25：

- 已有独立 `Application`、Forui 主题和会议列表空页面。
- 已有通用 `ViewState`，并启用严格类型分析。
- 已有 228 个应用壳、组件、Step 01、领域层、本地存储、模型生命周期、可靠录音、官方 ASR adapter、双 Engine、Factory、VAD、会议主链、最终转录、说话人降级和 AI 总结证据链自动化测试。
- 已固定 Android API 24 最低版本，并记录 `arm64-v8a` 必验设备矩阵。
- 已固定官方 `sherpa_onnx` 1.13.4，并建立只用于 Step 01 的双模型真机 Spike、录音连续性探针和可重复执行脚本；Spike 不是正式 `AsrEngine`。
- 已完成 Step 02 的纯 Dart 领域模型、会议/录音/处理/模型安装状态机、结构化错误、统一 `AsrEngine`/Factory 和 Repository 抽象端口。
- 已完成 Step 03 的 SQLite v1 Schema/迁移、App 私有文件布局、耐久文件提交、五类 Sqflite Repository 和幂等启动恢复器。
- 已完成 Step 04 的双模型 `AsrModelRegistry`、Manifest v1 解析与兼容校验、严格文件集/SHA-256 校验、SQLite v2 默认模型设置和显式本场覆盖解析。
- 已完成 Step 05：`81,904,027` 字节 Paraformer INT8 运行文件、发布 Manifest 和来源 NOTICE 已进入 APK；Flutter asset 读取、临时目录复制、严格校验、原子目录切换、安装状态持久化、进度、失败重试和孤儿目录收养均已实现。
- 已完成 Step 06：Qwen3-ASR 六文件发布 Manifest、2 GiB 空间预检、网络确认、HTTPS Range 续传、取消/重试、临时目录、严格校验、SQLite v3 原子活动版本、持久化使用租约和高级模型安全删除均已实现；高级权重不进入 APK。
- 已完成 Step 07：官方 `record` 采集 16 kHz 单声道 PCM16，公开 `flutter_foreground_task` 维持 Android 麦克风前台生命周期；事实文件逐块 flush 并持久化双代 checkpoint 后才投递有界预览，支持暂停/恢复、原子封存和启动恢复。
- 已完成 Step 08：应用启动时一次性初始化官方 bindings；data/service 层以独立 isolate 持有官方识别器，封装双模型纯 Dart 配置、串行推理、资源释放、应用级取消和结构化错误。
- 已完成 Step 09：标准 Paraformer Engine 只接受 Registry 标准模型与已验证安装记录，支持不超过 15 秒的窗口、外部全局时间轴事件、完整事实 PCM16 切窗、最终快照、逐窗诊断、RTF、进度和取消。
- 已完成 Step 10：高级 Qwen Engine 只从活动已验证版本创建，持有可续期模型租约，复用统一窗口/事件/快照协议，暴露设备支持、内存和温控风险，失败不自动切换模型。
- 已完成 Step 11：Factory 只按确认的 Registry ID/版本创建具体 Engine；设置页、开始会议页和录音态锁定组件覆盖全局默认、本场覆盖、显式回退记录和开始后不可切换。
- 已完成 Step 12：官方 Silero VAD、统一预览时间轴、有界积压队列、确定性文本修订和仅录音降级已接入可靠录音的预览端口。
- 已完成 Step 13：生产入口装配 SQLite、内置模型、Factory、VAD、可靠录音和会中预览；会议列表、开始会议、录音、暂停/恢复、结束、响应式会中状态和处理详情主链可运行。
- 已完成 Step 14：完整事实 PCM 最终转录、稳定 processing 快照、片段边界/模型校验、CAS 原子激活、失败保留、幂等重试、已安装模型独立重转录和处理详情已接通。
- 已完成 Step 15：说话人 service 端口、能力开关、最大重叠区间映射、超时/异常单一说话人降级、任务状态恢复和人工标签已接通；当前未批准独立分离权重，生产能力显式不可用。
- 已完成 Step 16：总结 service 端口、最终活动快照资格校验、最小请求 schema、本地证据映射、SQLite 原子激活、转录变更过期、失败重试和 Forui 状态已接通；当前没有安全网关，生产能力显式不可用。
- 双模型设计已经批准；APK 静态检查、录音并发断言和双模型各两次真机识别已有证据。最终合并复跑通过，录音完整率 99.54%；Qwen3-ASR 峰值 RSS 约 2.92 GiB、首结果约 18～20 秒，当前为预备 Conditional Go。Paraformer 的 30 秒窗口空结果已通过 15 秒窗口复测关闭，两轮均为 20/20 可读；仍待会议样本、低端设备和许可闭环。

Step 00、Step 02～16 已完成；Step 01 的代码与 Mi 10 技术验证已完成，但外部语料、低端设备和公开分发许可闭环仍在进行中。会议结束后会从完整事实音频生成并激活最终转录快照；说话人增强失败不会改变快照完成态。AI 总结只接受当前活动的已完成最终快照，服务请求不含音频、会中临时文本、会议 ID、快照 ID 或本地时间戳。

## 3. 不可破坏的工程规则

- 架构固定为 `View → ViewModel → Repository → Service`。
- UI 不直接依赖 ONNX、HTTP、数据库或文件系统。
- 本地完整音频是唯一事实源。
- 每个音频块先持久化，再投递 ASR。
- 预览队列可以丢任务，录音链不能丢音频。
- 会议开始后锁定模型；会中不得切换或混合两个模型。
- 最终转录来自完整音频，AI 总结只读取激活最终快照。
- Forui 优先，颜色、字体、圆角和间距来自主题令牌。
- sherpa-onnx 只通过官方 `sherpa_onnx` Flutter/Dart 包接入；不得自建 JNI、FFI/C API 绑定、C/C++ 构建链或手工维护原生库。
- 官方包缺少目标能力时，调整依赖版本或模型并更新 PRD，不得以私有原生桥接绕过。
- 行为变更先写测试；交付前运行静态分析和对应测试。

## 4. 目标依赖关系

```text
Step 00 工程基线
  → Step 01 双模型真机 Spike（Go/No-Go）
    → Step 02 领域模型与接口
      → Step 03 本地存储与恢复
      → Step 04 模型 Registry / Manifest
        ├─ Step 05 内置标准模型
        └─ Step 06 高级模型下载
      → Step 07 可靠录音
      → Step 08 官方 sherpa_onnx Flutter 包
        ├─ Step 09 Paraformer Engine
        └─ Step 10 Qwen Engine
          → Step 11 Factory / 会议模型锁定
            → Step 12 VAD / 有界预览队列
              → Step 13 会中转录 UI
              → Step 14 最终转录快照
                → Step 15 说话人分离
                → Step 16 AI 总结与证据
                  → Step 17 结果、分享与删除
                    → Step 18 双模型对比评测与发布门槛
```

Step 03、04、07 可在 Step 02 后并行准备，但同一工作区内提交时必须保持可构建。

## 5. 建议目标结构

```text
lib/
  ui/
    core/
    features/
      meetings/{views,view_models}/
      recording/{views,view_models}/
      results/{views,view_models}/
      settings/{views,view_models}/
  domain/
    models/
    use_cases/
  data/
    models/
    repositories/
    services/
      audio/
      asr/
      models/
      storage/
      summary/
android/               # 常规 Flutter 平台配置，不放自建 sherpa-onnx 桥接
assets/models/
test/                  # 镜像 lib/
integration_test/
tool/
  benchmarks/
```

目录在首次需要时创建，不提前生成空文件。

---

## Step 00：建立可验证的工程基线

**目标**

让后续功能有稳定的应用壳、分层目录、测试外壳和 CI 命令。

**技能**

- `flutter-apply-architecture-best-practices`
- `flutter-add-widget-test`
- `dart-run-static-analysis`

**任务**

1. 将应用壳收敛为 `Application`，配置真实 `FTheme`。
2. 建立根导航和最小会议列表空白页。
3. 创建 UI、domain、data 的目录边界和导入约束。
4. 为 ViewModel 定义统一的 loading/data/error 表达，但不引入全局复杂状态框架。
5. 更新壳层组件测试，使用真实 `Application/FTheme`。
6. 记录最低 Android SDK、目标 ABI 和开发设备矩阵。

**验证**

```powershell
dart format lib test
flutter analyze
flutter test
flutter build apk --debug
```

**完成标准**

- 空白会议列表可启动。
- 层间没有反向依赖。
- 应用壳测试不再依赖默认计数器示例。

---

## Step 01：双模型真机 Spike（Day 1 Go/No-Go）

**目标**

用官方 `sherpa_onnx` Flutter 包的公开 Dart API 验证两个模型、资源占用和录音解耦，不做正式 UI。

**任务**

1. 选择并固定一个候选的官方 `sherpa_onnx` Flutter 包版本。
2. 只通过公开 Dart API 在 `arm64-v8a` 真机分别加载：
   - `sherpa-onnx-paraformer-zh-small-2024-03-09` INT8。
   - `sherpa-onnx-qwen3-asr-0.6B-int8-2026-03-25`。
3. 验证公开 API 能完成模型配置、音频输入、结果读取、资源释放和重复创建。
4. 使用相同 5 分钟会议样本和统一的不超过 15 秒窗口记录 RTF、峰值内存、首字/句后延迟和温控。
5. 并行运行持续录音写入与故意减速的 ASR，验证推理不阻塞或终止录音。
6. 检查 Debug APK 的目标 ABI、重复原生库、体积、许可证和高级模型缺失状态。
7. 记录模型真实文件、字节数、SHA-256、许可、来源以及官方包/平台包版本。
8. 将原始数据保存到不含真实会议内容的基准结果文件。
9. 在技术方案记录任何公开 API、ABI、调度或模型兼容性修正。

**禁止**

- 不提交下载的模型或真实录音。
- 不以模拟器结果代替真机 Go/No-Go。
- 不在 Spike 中承诺未验证能力。
- 不得自建 FFI/JNI/C++ 桥接，也不得把它作为官方包能力不足时的回退。

**验证**

```text
两模型均能初始化和转录同一 5 分钟样本
公开 Dart API 能输入音频、读取结果并正确释放资源
录音样本数/时长与预期一致
ASR 故障不终止录音
Debug APK 的 ABI、原生库和模型内容符合预期
原始指标和设备信息可追溯
```

**完成标准**

- Go：两个模型可运行，录音解耦成立，性能风险可量化。
- Conditional Go：高级模型仅在部分设备可用，但标准模型和仅录音主链成立。
- No-Go：官方包公开 API 无法支持目标模型，或音频事实链不可行；停止后续 ASR 实现，调整依赖/模型决策并更新 PRD。

---

## Step 02：领域模型、状态机与接口

**目标**

先固定不依赖 Flutter/ONNX 的业务语言。

**技能**

- `flutter-apply-architecture-best-practices`
- `dart-add-unit-test`

**任务**

1. 实现 `Meeting`、`TranscriptSegment`、`TranscriptSnapshot`、`Summary`。
2. 实现 `AsrModelDescriptor`、层级、安装类型和能力集合。
3. 定义 `AsrEngine`、`AsrEngineFactory`、Repository 接口。
4. 定义会议、录音、处理、模型安装和下载状态机。
5. 定义结构化错误和 `recoverability/userAction`。
6. 用纯 Dart 测试覆盖合法/非法迁移、模型锁定和快照激活。

**关键测试**

- 录音开始后不能修改 `recordingModelId`。
- `requestedModelId` 与实际模型可以不同，但必须有显式回退原因。
- 临时快照不能作为总结输入。
- 新最终快照失败时旧激活快照不变。

**验证**

```powershell
dart format lib test
flutter analyze
flutter test test/domain
```

---

## Step 03：本地数据库、文件布局与恢复器

**目标**

建立音频、快照和任务的可恢复事实存储。

**任务**

1. 选定 SQLite 方案并建立 schema/migration。
2. 实现会议、快照、片段、摘要、模型安装和任务表。
3. 定义 App 私有目录布局和文件命名规则。
4. 实现临时文件 → 校验/flush → 原子重命名 → 数据库引用的提交顺序。
5. 实现启动恢复器，处理未完成录音、过期处理租约、模型临时目录和孤儿快照。
6. 提供 Repository，不向 UI 暴露数据库对象。

**关键测试**

- 任一步骤失败都不会让数据库引用不存在的最终文件。
- 恢复器重复运行结果一致。
- 失败的新快照不会覆盖旧激活快照。
- 删除会议只删除目标会议的数据。

**验证**

```powershell
flutter test test/data
flutter analyze
```

---

## Step 04：模型 Registry、Manifest 与选择规则

**目标**

让模型元数据、发布文件和产品选择规则只有一个实现入口。

**任务**

1. 建立 `AsrModelRegistry`，注册标准和高级模型。
2. 定义本地/远端 Manifest schema 和兼容版本。
3. 实现逐文件大小、SHA-256 和许可字段校验。
4. 实现全局默认模型设置，初始值为标准模型。
5. 实现本场覆盖解析和开始前可用性检查。
6. 禁止业务层通过文件名推断模型。

**关键测试**

- Registry 中恰有一个标准默认模型。
- Manifest 重复 ID、非法哈希、缺文件和不兼容 schema 被拒绝。
- 本场覆盖不修改全局默认值。
- 会议创建后模型选择不可变。

**实现状态（2026-07-24）**

- `AsrModelRegistry.alpha` 是标准/高级模型 ID、版本、层级、安装类型、运行必需字节数和能力的单一入口；标准 Paraformer 是唯一初始默认模型。
- Manifest v1 要求 `schemaVersion`、`minAppVersion`、逐模型文件、64 位 SHA-256、来源 URL 和许可/NOTICE 字段；拒绝重复 ID、占位符、路径穿越、非 HTTPS 下载源以及与 Registry 不一致的元数据。
- `ModelFileVerifier` 严格核对文件集、字节数和 SHA-256，并返回缺失、大小错误、哈希错误和多余文件四类结构化结果。
- SQLite v2 增加 `app_settings`，全局默认模型可持久化；本场覆盖由纯领域用例解析，不修改全局值，也不允许未确认的自动回退。
- Step 04 新增 19 项测试；69 项全量测试和 `flutter analyze` 通过。最终双模型发布 Manifest 已分别在 Step 05/06 使用真实资产和固定版本下载源补齐，不含占位条目。

**验证**

```powershell
flutter test test/domain test/data/services/models
flutter analyze
```

---

## Step 05：内置标准模型

**目标**

实现无需联网、不可删除的内置标准模型。

**任务**

1. 仅把发布所需 Paraformer INT8 文件加入 `assets/models/`。
2. 首次运行复制到私有临时目录。
3. 校验大小、SHA-256 和文件集。
4. 原子切换为可用版本并持久化安装状态。
5. 实现准备进度、失败重试和仅录音降级。
6. 确认 APK 中不包含多余模型变体。

**关键测试**

- 已正确安装时不重复复制。
- 中途退出留下的临时目录可安全恢复/清理。
- 哈希不符不会标记 installed。
- 用户删除接口拒绝标准模型。

**验收映射**

- FR-020
- AT-01
- AT-12

**实现状态（2026-07-24）**

- 已实现 `FlutterModelAssetSource` 和 `BundledModelPreparationService`：只接受 `bundled + asset://`，按版本写入私有临时目录，逐文件 flush，严格校验后原子重命名，最后保存 `installed`。
- 已实现检查、复制、校验、提交和就绪进度；正确安装时不重复读取 asset；数据库提交失败时保留已校验目录，下次重试可直接收养。
- 已安装文件损坏可转为 `failed` 并重新校验；哈希不符、文件集错误或复制失败不会形成最终安装记录。内置模型禁止删除的领域约束继续生效。
- `model.int8.onnx` 与 `tokens.txt` 合计 `81,904,027` 字节，已按精确大小和 SHA-256 写入 `assets/models/manifest.json`；APK 同时包含来源与许可状态 NOTICE，且不包含 Qwen3-ASR 或其他模型变体。
- 新增真实资产一致性测试；共新增 9 项测试，78 项全量测试和 `flutter analyze` 通过。
- Debug APK 已构建并通过资产检查。精确转换来源的 ModelScope `License`、`LicenseName` 和 `LicenseLink` 仍为空；产品负责人已明确批准用于 Android Alpha APK，公开分发前仍须确认权重再分发许可。

---

## Step 06：高级模型按需下载

**目标**

实现 Qwen3-ASR 的安全下载、校验、更新和删除。

**任务**

1. 实现空间预检（至少 2 GB）和网络提示。
2. 实现下载进度、取消、重试和临时文件。
3. 下载后逐文件校验 Manifest。
4. 使用版本目录和原子 active-version 切换。
5. 新版本失败时保留旧版本。
6. 用租约阻止删除活动会议正在使用的版本。
7. 删除高级模型时保留历史会议、转录和摘要。

**关键测试**

- 下载取消/断网不产生已安装状态。
- 校验失败不覆盖旧版本。
- 活动租约存在时删除失败并给出可操作原因。
- 删除成功只移除模型文件和安装记录。

**验收映射**

- FR-021
- AT-13

**实现状态（2026-07-24）**

- `DownloadableModelService` 只接受 Registry/Manifest 一致的 downloadable 模型；下载前检查至少 2 GiB 空间，无网络直接失败，移动或未知网络必须由调用方显式确认。
- `HttpModelFileDownloader` 只允许 HTTPS，支持 HTTP Range 续传、进度、应用级取消和响应大小上限；取消保留版本化临时文件，重试按已有字节继续。
- 六个 Qwen3-ASR 运行文件固定到 Hugging Face revision `68818b2313fe77bd06f6a7c5068ff3ef59d02b8a`，总计 `987,015,347` 字节，大小和 SHA-256 写入发布 Manifest；APK 只包含 Manifest/NOTICE，不包含高级权重。
- 全部文件严格校验后才把临时目录原子重命名为版本目录，并在 SQLite v3 事务中写入安装记录和 `active_model_versions`；新版本失败不会切换旧活动版本。
- `model_usage_leases` 持久化活动占用者与过期时间；有效租约阻止删除并返回 owner，删除成功仅移除对应版本目录、安装记录和活动指针。
- Step 06 新增 17 项测试；95 项全量测试、`flutter analyze`、Debug APK 构建和高级权重缺失检查通过。

---

## Step 07：可靠录音与崩溃恢复

**目标**

先完成独立于 ASR 的可靠录音主链。

**任务**

1. 实现麦克风权限、音频采集和前台录音生命周期。
2. 以 16 kHz、单声道 PCM16 写入事实音频。
3. 每个块先持久化并更新 checkpoint，再发送预览副本。
4. 实现暂停、恢复、结束、flush 和原子封存。
5. 实现空间不足、来电/音频焦点、后台和进程终止处理。
6. 提供可替换的 preview sink，录音层不依赖 ASR Engine。

**关键测试**

- preview sink 抛错/阻塞不影响文件写入。
- 暂停和恢复后的时间轴连续。
- 异常退出后音频可识别、可播放、可继续处理。
- 30 分钟音频完整率 100%。

**验收映射**

- FR-003
- FR-010
- AT-02 至 AT-06

**完成证据**

- 官方 `record` 7.1.1 适配器固定请求 16 kHz、单声道、PCM16，并使用 `AudioInterruptionMode.pauseResume` 响应来电/音频焦点中断。
- `ReliableRecordingService` 按“写入并 flush → 双代 checkpoint → 非阻塞 preview”顺序处理每个块；preview 阻塞、失败或满载不回滚事实音频。
- `StartupRecoveryService` 对异常退出遗留 PCM16 截断不完整尾样本，原子封存后写入真实时长并转入处理态。
- 30 分钟合成事实 PCM 共 `57,600,000` 字节，文件完整率 100%；105 项全量自动化测试通过。
- Mi 10（Android 11）切到后台后持续录制 30 秒，写入 `960,000` 字节，持久化率 100%，采集完整率约 99.96%。
- 详见 [Step 07 质量报告](./quality/Step_07_可靠录音与崩溃恢复.md)。

---

## Step 08：官方 sherpa_onnx Flutter 包集成

**目标**

把 Spike 验证过的官方包收敛为可维护、可测试的 Dart 应用层适配。

**任务**

1. 在 `pubspec.yaml` 增加并固定 Spike 验证通过的官方 `sherpa_onnx` Flutter 包版本。
2. 按官方公开 API 在应用启动流程中完成一次性 bindings 初始化。
3. 在 data/service 层建立小型 Dart adapter，封装识别器配置、初始化、调用、释放和应用级取消。
4. 把推理调度到不阻塞 UI 和录音写入关键路径的执行链。
5. 将官方包异常转换为结构化应用错误，不向 UI 暴露第三方类型。
6. 实现初始化、释放、重复创建和 fake adapter 单元测试。
7. 在 Debug APK 中检查目标 ABI、重复原生库、高级模型缺失状态、体积和许可证。
8. 明确禁止在本步骤增加 ffigen、JNI、C/C++、私有 ABI 声明、`DynamicLibrary.open` 或手工 `jniLibs`。

**关键测试**

- 官方 bindings 只初始化一次。
- Engine dispose 后官方识别器资源可以重复创建。
- 官方包错误转换为结构化错误，不穿透到 UI。
- fake adapter 测试不加载原生运行库。
- APK 包含目标 ABI、无重复原生库且不包含高级模型文件。

**完成证据**

- `SherpaOnnxRuntimeInitializer` 在应用入口执行，单个 isolate 只调用一次官方 `initBindings()`；初始化失败转换为可重试 `AppFailure`，不阻止可靠录音应用壳启动。
- `SherpaOnnxAdapter` 只接受可跨 isolate 传输的 Paraformer/Qwen3-ASR 应用配置；官方类型与异常均停留在 data/service 层。
- 独立长生命周期 isolate 持有一个官方 `OfflineRecognizer`，PCM 通过 `TransferableTypedData` 传递，请求串行执行且不占用 UI/录音写入执行链。
- 应用级取消立即拒绝排队任务并丢弃活动结果；官方 `decode` 无抢占 API，活动窗口在后台完成后释放。
- 10 项新增单元测试和 115 项全量测试通过；fake worker 测试不调用原生运行库。
- Mi 10 使用真实内置 Paraformer 完成两轮 bindings、初始化、1 秒 PCM 推理、释放和重复创建。
- APK 检查确认 `arm64-v8a`、聚合许可证 `NOTICES.Z`、标准模型资产，无重复原生库和高级模型权重；详见 [Step 08 报告](./quality/Step_08_官方_sherpa-onnx_Flutter_包集成.md)。

---

## Step 09：ParaformerStandardAsrEngine

**目标**

实现标准模型的统一 `AsrEngine` 适配器。

**任务**

1. 从 Registry 和 ModelManager 获取已验证路径。
2. 实现初始化、VAD 窗口识别、事件输出和完整音频处理。
3. 拒绝超过 15 秒的未切分输入，逐窗口记录空结果和错误。
4. 使用外部全局时间轴，不假设模型提供词级时间戳。
5. 记录 RTF、错误码和版本。
6. 支持 dispose、取消和最终处理进度。

**关键测试**

- descriptor 与实际 Registry 条目一致。
- 输入窗口产生带模型 ID/版本和全局区间的事件。
- 超过 15 秒的输入不会直接送入 Paraformer。
- 初始化失败可恢复，不影响录音服务。
- 处理同一窗口结果顺序确定。

**完成证据**

- `ParaformerStandardAsrEngine` 从 Registry 固定取得标准模型，仅接受模型 ID、版本、安装类型和已验证状态完全匹配的 `ModelInstallation`。
- 预览与最终处理均通过 Step 08 官方 adapter；单窗口硬上限为 15 秒，事件保留外部全局区间、模型 ID 和版本，不假设词级时间戳。
- 完整事实 PCM16 文件按最多 15 秒流式读取，成功后生成同一模型版本的最终快照；任一窗口失败时不会返回伪完成快照。
- `AsrEngine` 统一暴露最终处理进度、逐窗空结果/错误诊断、RTF、取消和结构化异常；初始化失败可在原 Engine 上重试。
- 9 项新增单元测试和 124 项全量自动化测试通过；Mi 10 使用真实内置 Paraformer 完成 1 秒窗口识别和事实 PCM16 最终处理。
- 详见 [Step 09 报告](./quality/Step_09_Paraformer_Standard_Engine.md)。

---

## Step 10：QwenAdvancedAsrEngine

**目标**

实现高级模型的统一 `AsrEngine` 适配器。

**任务**

1. 只从已校验的高级模型 active version 初始化。
2. 实现与标准模型相同的事件、最终快照和取消协议。
3. 增加内存、温控和不支持设备的风险状态。
4. 初始化和推理失败不触发自动模型切换。
5. 复用公共 adapter，模型特有配置留在 Engine 内。

**关键测试**

- 未安装/校验失败/租约冲突时不能初始化。
- 输出协议与 Paraformer Engine 可互换。
- 故障后录音链仍活动。
- dispose 释放大模型资源。

**完成证据**

- `QwenAdvancedAsrEngine.create` 只读取 Qwen Registry 条目对应的 SQLite 活动版本，要求安装记录处于 `installed`、路径/校验时间/字节数完整且版本精确匹配。
- Engine 创建时获取 owner 级使用租约，拒绝同 owner 冲突；识别前按阈值续租，`dispose` 同时释放官方 worker 和租约。
- 双 Engine 复用 `SherpaOnnxAsrEngine` 公共 Dart 核心，使用相同 15 秒窗口、全局时间轴事件、最终快照、诊断、RTF、进度和取消协议；模型特有文件配置留在各自薄封装内。
- `AsrDeviceRiskState`/`AsrDeviceRiskMonitor` 表达 supported/constrained/unsupported、内存压力和温控状态；临界风险只阻止高级模型推理并返回结构化错误，不触发自动模型切换。
- Qwen 推理失败期间可靠录音继续写入并封存完整事实 PCM16；10 项新增单元测试和 134 项全量自动化测试通过。
- Step 01 已在 Mi 10 使用相同官方 Qwen 配置完成两轮真实初始化、推理和释放；本步骤正式 Engine 已在 Android 16 x86_64 模拟器使用真实固定权重连续通过两轮集成测试，Mi 10 正式 Engine 复测仍因测试应用安装被拒而待补，详见 [Step 10 报告](./quality/Step_10_Qwen_Advanced_Engine.md)。

---

## Step 11：Factory、会议模型锁定与设置 UI

**目标**

串起全局默认、本场覆盖、显式回退和 Engine 创建。

**技能**

- `flutter-add-widget-test`

**任务**

1. 实现 `AsrEngineFactory`，只按已确认模型 ID/版本创建 Engine。
2. 实现设置页“转录模型”区域。
3. 实现开始会议页的折叠模型选择。
4. 高级模型不可用时提供下载、改用标准模型或取消。
5. 用户确认后创建会议并锁定模型。
6. 录音页不显示切换入口。

**组件测试**

- 默认标准模型已安装。
- 高级模型未下载、下载中、校验中、已安装、失败和空间不足。
- 本场覆盖不修改默认。
- 回退必须用户确认且被记录。
- 开始后无法更改模型。

**验收映射**

- FR-002
- AT-14
- AT-15

**实施结果（2026-07-24）**

- `SherpaOnnxAsrEngineFactory` 精确校验 Registry ID/版本，仅创建已确认的标准或高级 Engine，不读取默认值、不自动回退。
- 设置页覆盖标准已安装，以及高级未下载、下载中、校验中、已安装、失败和空间不足状态；只有已安装模型能成为后续会议默认值。
- 开始会议页继承全局默认并允许本场覆盖；高级模型不可用时提供下载、改用标准模型或取消，只有显式确认才记录回退原因并创建会议。
- 会议进入 `recording` 后，领域模型、ViewModel 和录音态组件均不再提供模型切换入口；主导航与真实录音服务装配留在 Step 13。
- 新增 20 项测试，全量 154 项测试、静态分析和 Debug APK 构建通过。详见 [Step 11 报告](./quality/Step_11_Factory与会议模型锁定.md)。

---

## Step 12：Silero VAD 与有界预览队列

**目标**

用统一时间轴驱动两个模型的句后准实时转录。

**任务**

1. 集成 Silero VAD，固定采样率和窗口契约。
2. 实现前后文、15 秒最大段长和重叠切分。
3. 实现以排队音频时长计量的有界队列。
4. 实现高水位、丢弃可重建预览和恢复策略。
5. 输出队列深度、预览延迟和丢弃指标。
6. 在 Engine 故障时切换到仅录音状态，不停止录音。

**关键测试**

- 全局时间区间单调且不越过音频时长。
- 积压时只丢预览任务。
- 重叠窗口合并结果确定。
- 两模型使用相同 VAD 区间。

**验收映射**

- FR-011
- AT-04
- AT-15

**实施结果（2026-07-24）**

- 已通过官方 `sherpa_onnx` Dart API 实现 `SileroVadSegmenter`，固定 16 kHz、512 样本窗口和 15 秒最大语音段，不新增原生桥接。
- 已将官方 `silero_vad.int8.onnx`（`212,860` 字节）纳入 APK，以独立 Manifest 固定 SHA-256、GitHub release asset ID、来源时间戳、NOTICE 和 MIT 许可文本。
- 已实现内置 VAD 权重的应用私有目录准备：临时复制、严格文件校验、原子切换和已验证版本复用。
- 已实现默认前后各 200 ms、15 秒最大窗口和 500 ms 重叠切分；重叠文本使用稳定片段 ID 确定性修订。
- 已实现按排队音频时长计量的 Coordinator：30 秒容量、15 秒高水位、5 秒低水位、丢最旧待处理预览、恢复和完整指标。
- VAD/Engine 失败进入 `recordingOnly`，不向可靠录音写入链传播异常；两个模型使用同一 Coordinator 生成的区间。
- 新增 16 项单元测试，全量 173 项测试、静态分析、Debug APK/包内哈希检查通过；Android 16 x86_64 模拟器使用真实内置权重完成两轮初始化、连续输入、flush、释放和复用。详见 [Step 12 报告](./quality/Step_12_Silero_VAD与预览队列.md)。

---

## Step 13：会议列表、开始会议和录音 UI

**目标**

完成用户可运行的前半段主链。

**技能**

- `flutter-build-responsive-layout`
- `flutter-add-widget-test`

**任务**

1. 实现会议列表加载、空白、正常、处理中和失败状态。
2. 实现开始会议预检、标题和模型选择。
3. 实现录音时长、暂停/恢复、结束和持续可见状态。
4. 显示正常转录、积压、转录暂停和仅录音。
5. 遵循 Forui 和 `context.theme`，不硬编码视觉令牌。
6. 保证返回键、锁屏和后台流程有明确行为。

**验证**

```powershell
flutter test test/ui
flutter analyze
flutter run -d <device-id>
```

**实现结果**

- `MeetTraceBootstrap/MeetTraceFlow` 将启动恢复、SQLite、内置 Paraformer/VAD 准备、精确 Engine Factory、可靠录音和预览协调器装配为可运行主链。
- 会议列表覆盖加载、空白、正常、处理中和失败；宽屏使用主题断点切换网格，窄屏保持列表。
- 录音页覆盖时长、暂停/恢复、结束、正常转录、积压、转录暂停和仅录音，并在活动录音期间阻止返回。
- 设备风险监视器只读取 Android 公开 procfs/sysfs；低于 4 GiB、可用内存不足 512 MiB 或温度达到 80°C 时阻止高级推理，不引入 JNI、FFI 或原生桥接。
- 新增 11 项行为/组件测试，全量 184 项测试、静态分析和 Debug APK 构建通过；Android 16 x86_64 模拟器走通权限、真实录音、暂停/恢复、21 秒音频封存、处理详情和列表刷新。详见 [Step 13 报告](./quality/Step_13_会议主链与会中_UI.md)。

---

## Step 14：最终转录快照与完整音频重处理

**目标**

在录音结束后建立可重试、可追溯的最终事实文本。

**任务**

1. 封存音频后创建 processing 快照。
2. 默认用本场锁定模型处理完整音频。
3. 合并并校验片段排序、边界和模型归属。
4. 原子保存快照并切换 active ID。
5. 失败时保留旧快照、音频和重试入口。
6. 重新转录允许选择当前已安装模型，但生成独立快照。
7. 新激活快照使旧摘要过期。

**关键测试**

- 不读取临时转录拼接成最终结果。
- 不混合两个模型片段。
- 事务失败不改变 active ID。
- 重试幂等且保留来源模型。

**验收映射**

- FR-012
- FR-032
- AT-07

**实现状态（2026-07-25）**

- `FinalTranscriptionService` 先持久化稳定 ID 的 `processing` 快照，再按本场锁定模型从完整事实 PCM 运行 Engine；重新转录只接受显式模型 ID/版本并生成独立快照。
- Engine 可接收编排层提供的 snapshot ID；快照构造与编排层共同拒绝跨快照、跨模型、越界和重叠片段，不读取会中预览文本。
- `saveFinalAndActivate` 在一个 SQLite 事务中保存完整快照、CAS 切换 active ID、完成会议并清除旧摘要；事务失败完整回滚。启动恢复可补激活已完成快照并恢复 `completed`。
- 失败尝试保留同一 snapshot ID、来源模型、旧活动快照、旧摘要和事实音频；重试复用失败 ID，已经激活的完成尝试直接返回，不重复推理。
- 处理详情显示完整音频进度、来源模型、带时间戳最终文本和可操作失败提示；完成后只列出当前已安装模型供独立重转录。
- 新增 13 项领域、Repository、编排、ViewModel 和组件测试；全量 197 项测试、静态分析和 Debug APK 构建通过。Android 16 x86_64 模拟器走通 `563,200` 字节事实 PCM 封存、Paraformer 最终转录和同模型重转录，详见 [Step 14 报告](./quality/Step_14_最终转录快照.md)。

---

## Step 15：说话人分离降级

**目标**

提供可关闭、可失败、不阻断主链的说话人增强。

**任务**

1. 定义 diarization service 接口和能力开关。
2. 只对已完成最终转录运行。
3. 把说话人结果映射到时间区间，保留原文。
4. 超时、内存不足或失败时回退单一说话人。
5. 支持用户修改说话人标签。

**关键测试**

- 服务失败后最终转录仍是 complete。
- 映射不能改变片段时间轴或模型归属。
- 人工修改可保存。

**验收映射**

- FR-013
- AT-08

**实现状态（2026-07-25）**

- 新增 `SpeakerDiarizationService` 能力端口和 `SpeakerDiarizationCoordinator`；只接受当前活动的 `final + complete` 快照与事实音频，按时间区间最大重叠映射说话人。
- Repository 受限事务只更新既有片段 `speaker_id`，拒绝未知片段、未完成快照和非法标签；原文、时间轴、片段 ID、置信度及 ASR 模型归属保持不变。
- 全局能力开关保存到 `app_settings`，稳定 `speaker-diarization-<snapshotId>` 任务保存完成/失败和错误码；重开页面可恢复降级提示且不会重复处理。
- 超时、空结果、资源不足、服务异常或能力不可用统一回退 `speaker-1`，最终转录继续保持 `complete`；Forui 详情页明确展示降级状态并允许批量修改同一说话人标签。
- 当前 PRD、Registry 和 Manifest 没有批准独立说话人权重，生产装配使用显式不可用适配器；未来实现必须继续走纯 Dart 端口，不得自建 JNI/FFI 原生桥接。
- 新增 15 项 Repository、编排、ViewModel 和组件测试；全量 212 项测试、静态分析和 `334,376,185` 字节 Debug APK 通过。Android 16 x86_64 模拟器走通冷启动、录音、最终转录、能力不可用提示、单一说话人展示和人工标签保存；桌面名称、应用标题、启动页和录音通知统一显示“会迹”，英文工程标识统一使用 `MeetTrace`，详见 [Step 15 报告](./quality/Step_15_说话人分离降级.md)。

---

## Step 16：AI 总结与证据链

**目标**

只基于最终转录生成可追溯结果。

**任务**

1. 实现 `GenerateSummaryUseCase` 的最终快照前置校验。
2. 定义结构化输出 schema：概览、关键结论、行动项和 evidence IDs。
3. 若使用云端，只发送最终文本和最小元数据。
4. 未配置安全网关时关闭云端总结。
5. 校验 evidence ID、时间区间和引用文本。
6. 无证据内容标记“待核对”。
7. 转录版本变化后将摘要标记过期。

**关键测试**

- 临时或 processing 快照不能触发总结。
- 无效 evidence ID 不会伪造时间戳。
- 云端请求不含音频路径、音频字节或临时转录。
- 总结失败不影响最终转录。

**验收映射**

- FR-030
- FR-031
- AT-09
- AT-10

**实施结果（2026-07-25）**

- `SummaryGenerationService` 只接收 schema 版本、片段 ID、最终文本和可选说话人标签；类型层不提供会议 ID、快照 ID、音频路径、音频字节或时间戳。
- `GenerateSummaryUseCase` 只允许当前活动的 `final + complete` 快照；服务只返回 evidence segment IDs，时间区间和原文引用由本地最终快照派生，未知 ID 被丢弃并标记“待核对”。
- SQLite 在同一事务内校验当前最终快照、逐条核对本地证据、保存摘要并激活 `active_summary_id`；新最终转录激活后旧摘要标记 `stale`。
- 生产装配使用 `UnavailableSummaryGenerationService`。未配置安全网关时页面明确关闭云端总结且不显示生成按钮；生成失败与最终转录状态隔离，可重试。
- 新增 16 项 UseCase、Repository、ViewModel 和组件测试；全量 228 项测试、静态分析和 `310,828,706` 字节 Debug APK 通过。Android 16 x86_64 模拟器覆盖安装后确认最终转录继续可见，并显示“安全总结网关未配置”和最小上传边界，详见 [Step 16 报告](./quality/Step_16_AI总结与证据链.md)。

---

## Step 17：结果页、编辑、分享、删除与诊断

**目标**

闭合可交付的会后用户体验和隐私控制。

**技能**

- `flutter-add-widget-test`

**任务**

1. 实现播放器、最终转录、摘要和证据跳转。
2. 实现文本/说话人编辑和摘要过期提示。
3. 实现纯文本/Markdown 分享，默认不分享音频。
4. 实现会议二次确认删除和模型独立删除。
5. 实现存储占用、隐私说明和诊断导出。
6. 诊断只包含元数据、指标和错误码。

**关键测试**

- 证据定位到正确片段和音频区间。
- 分享不意外包含本地路径或音频。
- 删除会议清理全部派生数据。
- 删除高级模型不影响历史会议。

**验收映射**

- FR-040 至 FR-042
- AT-10
- AT-11

**实施结果（2026-07-25）**

- 结果页通过官方 `audioplayers` 读取本地 PCM16 事实音频，按本地证据的 `startMs/endMs` 流式生成临时 WAV；证据必须同时匹配当前活动最终快照的片段 ID、时间范围和引文，拒绝越界或过期映射。
- 文本和说话人编辑生成新的 `final + complete` 快照及新片段 ID，旧快照继续保留；SQLite 原子激活新版本并将旧 AI 总结标记 `stale`，不在原记录上静默改写。
- 纯文本/Markdown 由当前最终快照和本地总结派生，通过官方 `share_plus` 调起系统分享；导出内容明确标注 AI、待核对项和“不包含原始音频”，类型层不读取音频字节或本地路径。
- 会议删除采用“目录暂存 → SQLite 外键级联删除 → 提交清理”，数据库失败时自动回滚目录；设置中的高级模型删除继续使用模型租约和安全根目录校验，不改变历史会议保存的模型 ID/版本。
- 会议首页新增中文设置入口；设置页装配双模型管理、存储用量、卸载风险和诊断字段披露。诊断由用户主动触发，白名单只包含容量、状态计数、模型 ID/版本/字节和错误码。
- 新增 13 项用例、服务与组件测试；全量 241 项测试、`flutter analyze --no-pub` 和 315,775,985 字节 Debug APK 通过。Android 16 x86_64 模拟器完成安装、中文冷启动、设置页和诊断系统分享复测；证据音频字节区间与点击路由、高级模型下载取消由自动化测试覆盖，实体设备实录播放留到 Step 18。
- 详见 [Step 17 报告](./quality/Step_17_结果页与数据控制.md)。

---

## Step 18：双模型对比评测、真机回归与 Alpha 发布

**目标**

用证据证明质量门槛，而不是只证明“能运行”。

**技能**

- `dart-run-static-analysis`
- `flutter-add-integration-test`
- `superpowers:verification-before-completion`

**任务**

1. 准备 20 段去敏会议评测清单，不提交原音频。
2. 两模型使用相同音频、VAD 配置、设备和环境。
3. 记录 RTF P50/P95、句后延迟、内存、耗电、温控、错误和最终耗时。
4. 人工标注人名、数字、产品名、结论和行动项，计算关键事实召回。
5. 执行 30 分钟录音、断网、积压、崩溃恢复和完整重转。
6. 检查标准模型门槛：
   - 模型资源 ≤ 100 MB。
   - 最低目标设备 RTF P95 `< 0.5`。
   - 句后出字 P95 `≤ 3 秒`。
   - 30 分钟最终转录 `≤ 5 分钟`。
   - 录音完整率 100%。
   - 不持续进入 Severe/Critical。
   - 能耗不高于高级模型 70%。
   - 关键事实召回率 `≥ 85%`。
7. 完成 AT-01 至 AT-16 证据表。
8. 检查 APK 的 ABI、模型文件、密钥、许可和体积。

**验证**

```powershell
dart format lib test integration_test
flutter analyze
flutter test
flutter test integration_test -d <device-id>
flutter build apk --debug
```

**完成标准**

- AT-16 双模型对比评测保留原始数据和设备信息。
- 录音连续性、模型失败降级和最终快照全通过。
- 任一未达门槛项明确标记，不以“Alpha”名义隐藏。
- PRD、技术方案、实施步骤和实现一致。

**当前进度**

- 已实现三态发布门禁和 JSON CLI：明确失败输出 `noGo`，缺失证据输出 `blocked`，全部通过才输出 `go`；P50/P95 少于 20 个样本不计算。
- 全量 246 项测试和静态分析通过；Android 16 x86_64 模拟器上的 Paraformer、官方 adapter、Silero VAD 和 30 秒可靠录音集成通过。
- 315,775,937 字节 Debug APK 构建与审计通过，包含 arm64-v8a，不包含高级模型权重、用户事实数据或疑似永久密钥。
- 相同 20 段去敏语料、最低目标 arm64 真机、30 分钟实体设备回归、AT-01～AT-16 完整证据和 Paraformer 再分发许可尚未闭环；当前发布结论为 `blocked`。
- 详见 [Step 18 报告](./quality/Step_18_双模型评测与发布门槛.md)。

---

## 6. 两周排期建议

| 时间 | 主线 | 必须输出 |
|---|---|---|
| Day 1 | Step 00–01 | 双模型 Go/No-Go 和录音解耦证据 |
| Day 2 | Step 02–04 | 领域接口、状态机、存储和 Manifest |
| Day 3 | Step 05–07 | 两类模型生命周期、可靠录音 |
| Day 4 | Step 08–10 | 官方 Flutter 包集成和两个 Engine |
| Day 5 | Step 11–13 | 模型选择、VAD、会中 UI |
| Day 6–7 | Step 14–15 | 最终快照和说话人降级 |
| Day 8 | Step 16 | 总结和证据 |
| Day 9 | Step 17 | 结果、分享、删除和诊断 |
| Day 10 | Step 18 | 双模型评测、30 分钟回归、APK |

如果 Day 1 Spike 或可靠录音晚于 Day 3，优先砍掉说话人分离和云端总结，不得压缩录音连续性、最终转录和双模型评测。

## 7. 每步统一交付模板

Codex 完成每一步后必须报告：

```text
步骤：
需求映射：
修改文件：
关键设计：
测试先行证据：
已运行验证：
未运行验证及原因：
已知风险：
下一步：
```

提交前检查：

- 只包含当前步骤相关改动。
- 没有下载模型、真实录音、密钥、`build/` 或 `coverage/`。
- 新行为有单元/组件/集成测试之一。
- 生成文件有来源和可重复生成方式。
- 文档与实现状态一致。

## 8. 完成看板

| Step | 状态 | 证据 |
|---|---|---|
| 00 工程基线 | 已完成 | `flutter analyze`、3 个测试、Debug APK、Mi 10 安装启动、[设备矩阵](./quality/Android_Alpha_设备矩阵.md) |
| 01 双模型 Spike | 进行中 | [Step 01 报告](./quality/Step_01_双模型真机_Spike.md)：静态检查、13 个测试、Debug APK/ABI、录音并发及双模型各两轮合并复跑通过；Paraformer 15 秒窗口两轮 20/20 可读，预备 Conditional Go，待会议样本、低端设备和许可闭环 |
| 02 领域模型 | 已完成 | 26 项 `test/domain` 测试：模型锁定、显式回退、合法/非法迁移、快照激活、总结输入、模型安装及抽象端口；`flutter analyze` 通过 |
| 03 本地存储 | 已完成 | 11 项存储测试：SQLite v1/迁移、外键、文件提交故障、事务快照激活、级联删除、Repository 往返和四类幂等启动恢复；50 项全量测试及 `flutter analyze` 通过 |
| 04 Registry/Manifest | 已完成 | 双模型 Registry、Manifest v1/兼容性、严格文件集/大小/SHA-256 校验、SQLite v2 默认模型设置、显式本场覆盖；19 项新增测试、69 项全量测试及 `flutter analyze` 通过 |
| 05 内置标准模型 | 已完成 | `81,904,027` 字节运行资产、发布 Manifest、来源 NOTICE、asset 读取、原子准备、状态持久化、失败重试和孤儿目录收养已完成；9 项新增测试、78 项全量测试、`flutter analyze`、Debug APK 构建及资产检查通过；公开分发许可仍属 Step 01/18 发布门槛 |
| 06 高级模型下载 | 已完成 | 2 GiB 空间预检、网络确认、HTTPS Range 续传、取消/重试、六文件严格校验、SQLite v3 原子活动版本、持久化租约和安全删除；17 项新增测试、95 项全量测试、`flutter analyze`、Debug APK 构建和高级权重缺失检查通过 |
| 07 可靠录音 | 已完成 | 官方 `record` PCM16、公开 Android 麦克风前台服务、逐块 durable checkpoint、非阻塞预览、暂停/恢复、原子封存和异常启动恢复；10 项新增测试、105 项全量测试、`flutter analyze`、Debug APK 及 Mi 10 后台真机测试通过，详见 [Step 07 报告](./quality/Step_07_可靠录音与崩溃恢复.md) |
| 08 官方 Flutter 包集成 | 已完成 | 官方 `sherpa_onnx` 1.13.4 一次性 bindings、独立 isolate worker、纯 Dart 双模型配置、串行推理、释放/重复创建、应用级取消和结构化错误；10 项新增测试、115 项全量测试、静态分析、Debug APK/许可证检查及 Mi 10 两轮真实 Paraformer worker 测试通过，详见 [Step 08 报告](./quality/Step_08_官方_sherpa-onnx_Flutter_包集成.md) |
| 09 Paraformer Engine | 已完成 | Registry/已验证安装约束、15 秒窗口、全局时间轴事件、完整 PCM16 切窗、最终快照、逐窗诊断、RTF、进度和取消；9 项新增测试、124 项全量测试、静态分析及 Mi 10 真实模型集成测试通过，详见 [Step 09 报告](./quality/Step_09_Paraformer_Standard_Engine.md) |
| 10 Qwen Engine | 已完成 | 活动已验证版本、owner 租约冲突/续租/释放、统一双 Engine 核心、设备支持/内存/温控风险、禁止自动切换及录音解耦；10 项新增测试、134 项全量测试和静态分析通过，正式 Engine 在 Android 16 x86_64 模拟器使用真实固定权重 2/2 通过；Step 01 Mi 10 真实模型证据有效，但 Mi 10 正式 Engine 复测仍受测试应用安装策略阻塞，详见 [Step 10 报告](./quality/Step_10_Qwen_Advanced_Engine.md) |
| 11 Factory/模型锁定 | 已完成 | 精确 ID/版本 Factory、设置默认、本场覆盖、显式回退、录音态锁定与 Forui 状态组件；20 项新增测试、154 项全量测试、静态分析和 Debug APK 构建通过，详见 [Step 11 报告](./quality/Step_11_Factory与会议模型锁定.md) |
| 12 VAD/预览队列 | 已完成 | 官方 Silero Dart API、内置 INT8 权重及独立 Manifest/NOTICE、私有目录原子准备、统一时间轴、200 ms 前后文、15 秒/500 ms 重叠切窗、30/15/5 秒容量与水位、确定性文本修订、指标及仅录音降级；16 项新增单元测试、173 项全量测试、静态分析、Debug APK/包内哈希和 Android 模拟器真实权重测试通过，详见 [Step 12 报告](./quality/Step_12_Silero_VAD与预览队列.md) |
| 13 会中 UI | 已完成 | 生产依赖装配、加载/空白/正常/处理中/失败列表、开始会议、真实录音、暂停/恢复/结束、四类会中转录状态、响应式 Forui 页面和 procfs/sysfs 设备风险；11 项新增测试、184 项全量测试、静态分析、Debug APK 和 Android 16 x86_64 模拟器真实录音主链通过，详见 [Step 13 报告](./quality/Step_13_会议主链与会中_UI.md) |
| 14 最终转录 | 已完成 | 完整音频编排、稳定 processing/failed 快照、片段与模型校验、CAS 原子激活、摘要失效、幂等重试和已安装模型独立重转录；13 项新增测试、197 项全量测试、静态分析、Debug APK 和 Android 16 x86_64 模拟器端到端通过，详见 [Step 14 报告](./quality/Step_14_最终转录快照.md) |
| 15 说话人分离 | 已完成 | 能力开关、纯 Dart service 端口、最大重叠映射、单一说话人降级、任务恢复和人工标签；15 项新增测试、212 项全量测试、静态分析、Debug APK 和 Android 16 模拟器降级主链通过，详见 [Step 15 报告](./quality/Step_15_说话人分离降级.md) |
| 16 总结/证据 | 已完成 | 最终活动快照资格、最小请求 schema、本地证据校验、SQLite 原子激活、摘要过期、失败重试和安全网关关闭；16 项新增测试、228 项全量测试、静态分析、Debug APK 和 Android 16 模拟器验证通过，详见 [Step 16 报告](./quality/Step_16_AI总结与证据链.md) |
| 17 结果/数据控制 | 已完成 | 新版本修订、证据区间 WAV、无音频分享、可回滚会议删除、独立模型删除、存储/隐私和诊断白名单；13 项新增测试、241 项全量测试、静态分析、Debug APK 和 Android 16 模拟器系统分享通过，详见 [Step 17 报告](./quality/Step_17_结果页与数据控制.md) |
| 18 评测/发布 | 阻塞 | 三态发布门禁、5 项新增测试、246 项全量测试、静态分析、Android 16 x86_64 模拟器 Paraformer/adapter/VAD/30 秒录音和 APK 审计通过；缺相同 20 段语料、最低目标 arm64 真机、30 分钟回归、AT-01～AT-16 完整证据及 Paraformer 再分发许可，详见 [Step 18 报告](./quality/Step_18_双模型评测与发布门槛.md) |

状态只允许：`待开始`、`进行中`、`已完成`、`阻塞`。标记“已完成”时必须在证据列填写测试、报告或提交。
