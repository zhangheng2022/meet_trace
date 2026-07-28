# 会迹（MeetTrace）文档索引

> 状态：当前文档入口
> 更新日期：2026-07-27

## 活动文档

按优先级阅读：

1. [会迹（MeetTrace）Android + iOS Alpha PRD V0.6](./会迹_MeetTrace_Alpha_PRD_无登录版.md)
   双平台产品范围、用户流程、功能需求、质量门槛和 AT-01～AT-20 的唯一事实源。
2. [端侧双模型转录技术方案](./端侧双模型转录技术方案.md)
   将 PRD 约束落实为录音、模型管理、官方 sherpa-onnx Flutter 包、双 ASR Engine、存储和降级架构。
3. [会迹（MeetTrace）交互与视觉系统](../DESIGN.md)
   锁定多页面 UI 的结构、色彩、排版、间距、响应式、交互状态和页面契约。
4. [Git 分支与 Worktree 约定](./Git_分支与_Worktree_约定.md)
   Alpha 步骤分支、隔离 worktree、合并和安全清理规则。
5. [双模型设计规格](./superpowers/specs/2026-07-23-dual-asr-model-design.md)
   2026-07-23 已批准决策的审计记录；若与当前 PRD 冲突，以 PRD 为准并同步修订规格。
6. [官方 sherpa-onnx Flutter 包集成规格](./superpowers/specs/2026-07-23-official-sherpa-onnx-flutter-integration-design.md)
   2026-07-23 已批准的依赖边界：只使用官方 Flutter/Dart 包，不自建原生桥接。

实施证据：

- [Codex Alpha 开发步骤](./Codex_Alpha_开发步骤.md)：Step 00～19 的历史执行记录，不定义当前会议入口和模型选择行为。
- [Android Alpha 设备矩阵](./quality/Android_Alpha_设备矩阵.md)：最低 SDK、目标 ABI、开发设备和待补齐的验收设备。
- [iOS Alpha 设备矩阵](./quality/iOS_Alpha_设备矩阵.md)：最低系统、arm64、iPhone/iPad、
  后台录音、双模型和无障碍待验门槛；未闭环前双平台发布保持 `blocked`。
- [Step 01 双模型真机 Spike](./quality/Step_01_双模型真机_Spike.md)：官方包、模型文件、APK、录音解耦和真机复测状态。
- [Step 07 可靠录音与崩溃恢复](./quality/Step_07_可靠录音与崩溃恢复.md)：事实 PCM、检查点、原子封存、异常恢复和 Mi 10 后台录音证据。
- [Step 08 官方 sherpa-onnx Flutter 包集成](./quality/Step_08_官方_sherpa-onnx_Flutter_包集成.md)：一次性 bindings、isolate worker、结构化错误、重复创建和 APK 审计证据。
- [Step 09 Paraformer Standard Engine](./quality/Step_09_Paraformer_Standard_Engine.md)：15 秒窗口、全局时间轴、完整 PCM16 处理、诊断/RTF、取消和 Mi 10 真实模型证据。
- [Step 10 Qwen Advanced Engine](./quality/Step_10_Qwen_Advanced_Engine.md)：活动版本、使用租约、设备风险、统一输出协议、录音解耦和 Android x86_64 模拟器真实模型证据。
- [Step 11 Factory 与会议模型锁定](./quality/Step_11_Factory与会议模型锁定.md)：旧入口下的模型覆盖与锁定历史证据；当前入口只使用全局默认模型。
- [Step 12 Silero VAD 与预览队列](./quality/Step_12_Silero_VAD与预览队列.md)：统一时间轴、15 秒重叠切窗、音频时长水位、积压丢弃、确定性文本修订和仅录音降级证据。
- [Step 13 会议主链与会中 UI](./quality/Step_13_会议主链与会中_UI.md)：生产依赖装配、会议列表、开始会议、事实录音、会中降级状态、响应式布局和 Android 端到端证据。
- [Step 14 最终转录快照](./quality/Step_14_最终转录快照.md)：完整事实音频重处理、稳定快照 ID、原子激活、失败重试、独立重转录和 Android 端到端证据。
- [Step 15 说话人分离降级](./quality/Step_15_说话人分离降级.md)：能力开关、时间区间映射、单一说话人回退、任务恢复、人工标签和 Android 降级路径证据。
- [Step 16 AI 总结与证据链](./quality/Step_16_AI总结与证据链.md)：最终快照资格、最小上传 schema、本地证据校验、原子激活、过期处理和安全网关关闭证据。
- [Step 17 结果页与数据控制](./quality/Step_17_结果页与数据控制.md)：可审计转录修订、证据音频、无音频分享、可回滚删除、存储隐私和诊断白名单证据。
- [Step 18 双模型评测与发布门槛](./quality/Step_18_双模型评测与发布门槛.md)：可执行发布门禁、Android 集成复测、APK 审计和未完成发布证据。

## 文档关系

```text
PRD（做什么、为什么、如何验收）
  → 技术方案（怎样设计）
    → Codex 开发步骤（按什么顺序实现）
      → 代码、测试、真机报告（实现证据）
```

`AGENTS.md` 是仓库级执行约束，必须与以上活动文档一致。

## 当前实现状态

截至 2026-07-27，Android 侧 Step 00、Step 02～17 已完成，Step 01 的外部语料、低端设备和公开分发许可闭环仍在执行。仓库已固定官方 `sherpa_onnx` 1.13.4；标准 Paraformer、按需下载 Qwen3-ASR、可靠事实录音、双 Engine、模型锁定、Silero VAD、有界预览队列、会议主链、完整音频最终转录、说话人降级、AI 总结证据链和会后数据控制均已落地。iOS 已纳入 P0 并完成工程权限、音频后台模式、平台装配与原生返回导航基线，但尚未形成等价的真机、模型、后台生命周期和安装包审计证据。处理详情会自动使用本场锁定模型生成最终快照，失败时保留事实音频和旧活动结果；用户也可选择当前已安装模型生成独立重转录快照。

当前共有 304 项测试并通过静态分析；历史报告中的测试数量和 APK 字节数只代表当时构建证据。UI-00～UI-04 已建立 shadcn/ui Neutral 黑白语义令牌、共享页面组件、首页一键会议入口、录音工作台以及处理/结果三视图；结果页已覆盖诚实处理阶段、转录默认只读、显式编辑、总结证据定位播放、Widget Preview 源码、320～1024 px 与 2.0 字体缩放。Step 18 的三态门禁仍保持：证据缺失为 `blocked`，明确不达标为 `noGo`，只有两端适用门槛全部通过才为 `go`。Android 16 x86_64 模拟器和 Mi 10 历史证据不能替代 iOS arm64 真机验证；iOS 设备矩阵、30 分钟后台录音、双模型、系统中断、Dynamic Type/VoiceOver 和安装包审计均未闭环，因此双平台 Alpha 发布为阻塞状态。

## 维护规则

- 改变 P0、验收标准或产品边界：先更新 PRD。
- 改变模型、接口、数据链或降级策略：同步更新技术方案。
- 改变开发顺序、文件落点或质量门槛：同步更新 Codex 开发步骤。
- 每次文档变更检查相对链接、模型 ID、日期和术语。
- 活动文档不保留“旧版”“备选版”并列副本；历史内容从 Git 查看。
- DOCX/PDF 如需交付，必须从当前 Markdown 基线生成，不作为独立事实源。
- 除 PRD 指定随平台安装包内置并带完整 Manifest/NOTICE 的标准模型外，下载模型、真实录音、评测语料、密钥、`build/` 和 `coverage/` 不得提交。

## 已清理的旧基线

以下内容不再作为仓库活动文档：

- 云端实时 ASR 方案：Alpha 不使用云端 ASR。
- Qwen3-ASR 单模型方案：由标准 Paraformer + 高级 Qwen3-ASR 双模型方案替代。
- 旧版 PRD DOCX：内容与 Markdown 基线分叉，已移除。

需要追溯时使用 Git 历史，不要重新引用旧文件路径。
