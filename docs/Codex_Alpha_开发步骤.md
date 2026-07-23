# Meetily Android Alpha — Codex 开发步骤

> 版本：V1.0
> 状态：当前执行计划
> 更新日期：2026-07-23
> PRD：[研会 AI Android Alpha PRD V0.5](./研会_AI_Alpha_PRD_无登录版.md)
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

截至 2026-07-23：

- 已有 Flutter 工程、Forui 依赖和主题文件。
- `lib/main.dart` 只有应用壳。
- 只有 `test/widget_test.dart` 壳层测试。
- 尚无录音、存储、数据库、模型管理、ASR、官方 `sherpa_onnx` 包依赖、会议页面或总结实现。
- 双模型设计已经批准，但仍需 Day 1 真机 Spike 证明可行。

因此 Step 00 和 Step 01 是强制前置，不得把设计文档中的类名误写成“已经存在”。

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
4. 使用相同 5 分钟会议样本记录 RTF、峰值内存、首字/句后延迟和温控。
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

---

## Step 09：ParaformerStandardAsrEngine

**目标**

实现标准模型的统一 `AsrEngine` 适配器。

**任务**

1. 从 Registry 和 ModelManager 获取已验证路径。
2. 实现初始化、VAD 窗口识别、事件输出和完整音频处理。
3. 使用外部全局时间轴，不假设模型提供词级时间戳。
4. 记录 RTF、错误码和版本。
5. 支持 dispose、取消和最终处理进度。

**关键测试**

- descriptor 与实际 Registry 条目一致。
- 输入窗口产生带模型 ID/版本和全局区间的事件。
- 初始化失败可恢复，不影响录音服务。
- 处理同一窗口结果顺序确定。

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

---

## Step 12：Silero VAD 与有界预览队列

**目标**

用统一时间轴驱动两个模型的句后准实时转录。

**任务**

1. 集成 Silero VAD，固定采样率和窗口契约。
2. 实现前后文、最大段长和重叠切分。
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
| 00 工程基线 | 待开始 | — |
| 01 双模型 Spike | 待开始 | — |
| 02 领域模型 | 待开始 | — |
| 03 本地存储 | 待开始 | — |
| 04 Registry/Manifest | 待开始 | — |
| 05 内置标准模型 | 待开始 | — |
| 06 高级模型下载 | 待开始 | — |
| 07 可靠录音 | 待开始 | — |
| 08 官方 Flutter 包集成 | 待开始 | — |
| 09 Paraformer Engine | 待开始 | — |
| 10 Qwen Engine | 待开始 | — |
| 11 Factory/模型锁定 | 待开始 | — |
| 12 VAD/预览队列 | 待开始 | — |
| 13 会中 UI | 待开始 | — |
| 14 最终转录 | 待开始 | — |
| 15 说话人分离 | 待开始 | — |
| 16 总结/证据 | 待开始 | — |
| 17 结果/数据控制 | 待开始 | — |
| 18 评测/发布 | 待开始 | — |

状态只允许：`待开始`、`进行中`、`已完成`、`阻塞`。标记“已完成”时必须在证据列填写测试、报告或提交。
