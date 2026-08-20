# 会迹（MeetTrace）仓库协作指南

## 语言

优先使用中文与用户沟通，并优先使用中文输出文档、计划、说明和提交信息。代码标识符、API 名称、命令、文件路径及需要保持准确的技术术语保留英文。

## 产品边界

- 会迹（MeetTrace）是 Android + iOS + Windows 自适应 Alpha，不提供登录或跨设备同步；三平台排期以 PRD 门槛评估为准，不继承原 Android 两周假设。Windows 在 PRD AT-21～AT-26 的自动化、分发与统一发布门禁闭环前仍须标记为规划中。
- 本地音频是唯一事实源；推理变慢或失败时，录音必须继续。说话人分离是首次初始化阻断的真实能力，会议结束后与最终 ASR 并行运行；运行失败时降级为单一说话人。
- 端侧 ASR 当前仅使用官方 sherpa-onnx `sherpa-onnx-sense-voice-zh-en-ja-ko-yue-int8-2024-07-17`；其他模型待定，不得以占位项或隐藏入口提前暴露。
- SenseVoice、Silero VAD、Pyannote 与 3D-Speaker 权重均不得进入 APK、IPA 构建产物或 MSIX；首次初始化时按固定 Manifest 下载并严格校验，完整资源集合未就绪前首页保持阻断。
- 设置保存全局默认模型，首页开始会议时直接使用且不提供本场覆盖；录音开始后模型锁定，同时负责会中和最终转录，不得自动切换或混合输出。
- 新会议按本地开始时间生成确定性标题。Alpha 不提供 AI 总结或总结网关；文本分享只包含最终转录，音频分享必须使用独立入口、二次确认和临时 WAV，且不得改写事实 PCM。
- 扩展 P0 前必须先更新 PRD。
- Android Alpha 只构建 `arm64-v8a` 签名 APK，Windows 只构建 Windows 10 22H2/11 x64 MSIX；Android、iOS、Windows 同一 SHA 的构建、自动化和分发门禁通过后才公开原 Draft 为 GitHub Pre-release。iOS 只通过 TestFlight 分发，GitHub 不上传 IPA；Windows 当前只通过 Microsoft Store 分发和更新，Store 包不得上传 GitHub Release。SignPath 申请仅作为未来可能替换 Store 的待审核路线，不接入当前发布工作流；启用前必须验证包身份兼容性并更新 PRD，禁止两个 Windows 包身份并存。禁止覆盖 APK/MSIX、移动 tag、删除撤回版本或让自动更新发现未批准候选。

## 架构与项目结构

遵循 `View → ViewModel → Use Case / Port → Repository / Service 实现`：

- `lib/ui/features/<feature>/{views,view_models}/`：精简页面和展示状态。
- `lib/ui/core/`：共享 Forui 组件和 UI 工具。
- `lib/domain/{models,ports,use_cases}/`：业务概念、纯 Dart 能力端口和可复用编排。
- `lib/data/{models,repositories,services}/`：端口实现，以及持久化、HTTP、音频、模型管理和 ASR 适配器。

Domain 不得反向导入 data；UI 只依赖 domain 的 Port、Use Case 和模型，不得直接调用 ONNX、存储或 HTTP。ASR 实现统一 `AsrEngine` 端口，由 Factory 按会议锁定的模型创建；当前仅 SenseVoice 一个模型，后续新增模型必须复用同一端口，具体 Engine 不得泄漏到 UI 或 ViewModel。音频写入与 ASR 必须独立运行；有界队列可以丢弃实时预览任务，但不能丢失录音。`test/` 镜像源码路径，需求和技术决策放在 `docs/`。

## Forui 优先

优先使用 Forui 的 `F*` 组件和 `context.theme` 令牌。实现或核对 Forui API 时，优先参考 [Forui LLM 文档](https://forui.dev/docs/reference/llms)。仅在应用外壳、平台集成或已记录的能力缺口中使用 Material。禁止在功能组件中硬编码颜色、字体、圆角和重复间距；统一扩展 `lib/theme/`。CLI 管理的文件应通过 `dart forui theme create --preset aabbbc` 等命令重新生成。组件测试必须使用真实的 `Application`/`FTheme` 外壳。

## 技能与实现流程

- 新增功能或重构使用 `flutter-apply-architecture-best-practices`；行为变更使用 `flutter-add-widget-test` 或 `dart-add-unit-test`；交付前使用 `dart-run-static-analysis`；代码审查使用 `$open-code-review-delegate`。
- sherpa-onnx 只通过官方 `sherpa_onnx` Flutter/Dart 包接入。禁止自建 JNI、FFI/C API 绑定、C/C++ 构建链或手工 `jniLibs`；ASR 模型仅在 data/service 层通过统一 `AsrEngine` 适配。
- 官方包缺少目标能力时，先调整依赖版本或模型并更新 PRD，不得以私有原生桥接绕过。
- 变更产品范围或 P0 验收标准前运行 `$grill-me`。
- 活动文档入口为 `docs/README.md`；旧方案不在 `docs/` 保留副本，历史由 Git 保存。

## 常用命令与质量门槛
- 优先使用`flutter run -d <device-id>`：在 Android 或 iOS 设备上调试运行
- 优先使用真机，真机不可用时使用模拟器
- `flutter pub get`：解析依赖。
- `flutter run -d <device-id>`：在 Android 或 iOS 设备上运行。
- `dart format lib test`：格式化 Dart 源码。
- `flutter analyze`：执行 `flutter_lints` 静态检查。
- `flutter test`：运行单元测试和组件测试。
- `flutter build apk --debug`：构建 Alpha 调试 APK。
- `flutter build windows --debug`：构建 Windows x64 Alpha 调试产物。
- `flutter build windows --release`：构建待 MSIX 打包的 Windows x64 Release 产物。
- `flutter build ios --debug --no-codesign`：在 macOS/Xcode 环境构建 iOS Alpha 调试产物。

测试文件使用 `*_test.dart`。优先覆盖录音连续性、模型校验、初始化下载与续传、会议模型锁定、积压恢复、转录排序、说话人时间段映射、快照原子切换、音频分享临时文件清理、Windows 单实例/托盘/输入设备中断/睡眠恢复、全平台更新 deferred，以及 Forui 的加载、空白和错误状态。SenseVoice 的 RTF、延迟、内存、能耗、温控和关键事实召回率，以及说话人分离的 DER、人数误差和 RTF，均为可选的非阻断工程观测，不要求形成候选设备证据，也不进入发布结论。

## OCR 代码审查

代码审查统一使用 `$open-code-review-delegate`。OCR 只负责确定范围、排除项和适用规则，缺陷判断与误报过滤由审查代理完成。

- 按目标使用 workspace、range 或 commit 模式；必须审查 preview 返回的全部 reviewable 文件，并按 `ocr delegate rule` 的规则检查真实 diff 或未跟踪文件。
- 使用 `--background` 或 `--background-file` 注入 PRD、技术方案和用户影响。涉及录音、模型锁定、联合最终快照、说话人分离、音频分享或数据删除时，必须带上相应产品边界。
- 生成文件只能通过明确的 `--exclude` 模式排除并说明原因，不得让构建产物或依赖噪声掩盖源码改动。
- 按 Critical、High、Medium、Low 报告精确路径、行号、触发条件、用户影响和修复建议。始终报告 Critical/High；只报告有实际影响的 Medium 和明确有价值的 Low；疑似误报静默丢弃。
- 用户只要求审查时保持只读；要求审查并修复时直接修复 Critical/High、补充测试并重新审查。涉及 `lib/`、平台目录、数据库 schema/迁移或构建配置的变更，交付或创建 PR 前必须完成审查；未解决的 Critical/High 阻断交付，保留的 Medium 必须说明风险与后续动作。
- OCR 不能替代格式化、静态检查、测试和目标平台构建；修复后重新运行受影响验证并审查新 diff。

## 提交、PR 与安全

- 所有仓库变更，包括代码、测试、配置和文档，都必须在独立分支提交并通过 PR 合并；禁止直接向默认分支提交或推送。分支默认使用 `codex/` 前缀，除非用户明确指定其他命名。
- PR 必须完成适用的格式化、静态检查、测试、构建和 OCR 审查。所有必需 CI 检查通过、Critical/High 问题清零后方可合并；保留 Medium 时必须在 PR 中说明风险、理由和后续动作。
- 提交信息优先使用中文。提交标题应简短并使用祈使语气，例如 `增加 ASR 积压恢复`。
- PR 必须引用对应 PRD 章节，说明用户影响，并列出验证命令和 OCR 范围；UI 变更需附截图。不涉及 PRD 或 UI 时须在 PR 中明确标注不适用。
- 禁止提交密钥、录音、下载的模型、`build/` 或 `coverage/`。

## graphify

This project has a knowledge graph at graphify-out/ with god nodes, community structure, and cross-file relationships.

When the user types `/graphify`, use the installed graphify skill or instructions before doing anything else.

Rules:
- For codebase questions, first run `graphify query "<question>"` when graphify-out/graph.json exists. Use `graphify path "<A>" "<B>"` for relationships and `graphify explain "<concept>"` for focused concepts. These return a scoped subgraph, usually much smaller than GRAPH_REPORT.md or raw grep output.
- Dirty graphify-out/ files are expected after hooks or incremental updates; dirty graph files are not a reason to skip graphify. Only skip graphify if the task is about stale or incorrect graph output, or the user explicitly says not to use it.
- If graphify-out/wiki/index.md exists, use it for broad navigation instead of raw source browsing.
- Read graphify-out/GRAPH_REPORT.md only for broad architecture review or when query/path/explain do not surface enough context.
- After modifying code, run `graphify update .` to keep the graph current (AST-only, no API cost).
