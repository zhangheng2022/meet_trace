# 会迹（MeetTrace）仓库协作指南

## 语言

优先使用中文与用户沟通，并优先使用中文输出文档、计划、说明和提交信息。代码标识符、API 名称、命令、文件路径及需要保持准确的技术术语保留英文。

## 产品边界

活动需求以 `docs/product/Alpha_PRD_无登录版.md` 为产品事实源，并由 `docs/README.md` 统一导航；本节只保留实现时必须高频核对的不变量。产品范围或 P0 验收标准发生变化时，必须依次执行 `$grill-me`、更新 PRD、在同一 PR 中同步本文件，再开始实现。PRD 与本文件冲突时必须停止实施并先消除冲突，不得自行选择其一。

- 会迹（MeetTrace）是 Android + iOS + Windows 自适应 Alpha，不提供登录或跨设备同步；三平台排期以 PRD 门槛评估为准，不继承原 Android 两周假设。Windows 在 PRD AT-21～AT-26 的自动化、分发与统一发布门禁闭环前仍须标记为规划中。
- 本地音频是唯一事实源；推理变慢或失败时，录音必须继续。说话人分离是首次初始化阻断的真实能力，会议结束后与最终 ASR 并行运行；运行失败时降级为单一说话人。
- 端侧 ASR 当前仅使用官方 sherpa-onnx `sherpa-onnx-sense-voice-zh-en-ja-ko-yue-int8-2024-07-17`；其他模型待定，不得以占位项或隐藏入口提前暴露。
- SenseVoice、Silero VAD、Pyannote 与 3D-Speaker 权重均不得进入 APK、IPA 构建产物或 MSIX；首次初始化时按固定 Manifest 下载并严格校验，完整资源集合未就绪前首页保持阻断。
- 设置保存全局默认模型，首页开始会议时直接使用且不提供本场覆盖；录音开始后模型锁定，同时负责会中和最终转录，不得自动切换或混合输出。
- 新会议按本地开始时间生成确定性标题。Alpha 不提供 AI 总结或总结网关；文本分享只包含最终转录，音频分享必须使用独立入口、二次确认和临时 WAV，且不得改写事实 PCM。
- 扩展 P0 前必须先更新 PRD。
- Android Alpha 只构建 `arm64-v8a` 签名 APK，Windows 只构建 Windows 10 22H2/11 x64 MSIX；Android、iOS、Windows 同一 SHA 的构建、自动化和分发门禁通过后才公开原 Draft 为 GitHub Pre-release。iOS 只通过 TestFlight 分发，GitHub 不上传 IPA；Windows 当前只通过 Microsoft Store 分发和更新，Store 包不得上传 GitHub Release。SignPath 申请仅作为未来可能替换 Store 的待审核路线，不接入当前发布工作流；启用前必须验证包身份兼容性并更新 PRD，禁止两个 Windows 包身份并存。禁止覆盖 APK/MSIX、移动 tag、删除撤回版本或让自动更新发现未批准候选。
- 新统一版本序列从共享构建号 `2001` 开始连续递增。Android 必须保留 `--split-per-abi`，传入的包基础构建号为共享构建号减 `2000`，Flutter 默认 ARM64 ABI 偏移后的实测 `versionCode` 必须与 iOS、Windows 构建号一致并写入候选清单和签名更新 Manifest；客户端按实测值验包，不自行推导。
- Alpha 仅支持当前公开版本，不承诺任意 Alpha 版本之间的安装升级、本地数据格式、数据库、会议音频与转录、模型缓存、检查点或设置兼容性，也不提供降级或数据迁移。自动更新和统一发布只保证已批准候选的安全分发，不构成兼容性承诺；破坏性版本允许在用户安装前明确确认后清除全部本地数据并重新初始化，但录音或最终处理期间不得强制安装、退出或清理。发布资产不可覆盖、版本必须向前递增、包身份和签名校验等安全门禁不受影响。

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
- 活动文档入口为 `docs/README.md`；旧方案不在 `docs/` 保留副本，历史由 Git 保存。

## 常用命令与质量门槛

- `flutter pub get`：解析依赖。
- `flutter run -d <device-id>`：在 Android 或 iOS 设备上调试，优先使用真机，真机不可用时使用模拟器。
- `dart format lib test`：格式化 Dart 源码。
- `flutter analyze`：执行 `flutter_lints` 静态检查。
- `flutter test`：运行单元测试和组件测试。
- `flutter build apk --debug`：构建 Alpha 调试 APK。
- `flutter build windows --debug`：构建 Windows x64 Alpha 调试产物。
- `flutter build windows --release`：构建待 MSIX 打包的 Windows x64 Release 产物。
- `flutter build ios --debug --no-codesign`：在 macOS/Xcode 环境构建 iOS Alpha 调试产物。

最低验证按变更范围确定：

- 纯文档变更运行 `git diff --check`，并人工核对链接、命令和 Markdown 结构；由 CI 路径分类决定是否跳过 Flutter 与平台构建。
- Dart 或 Flutter 变更至少运行格式化、`flutter analyze` 和受影响测试；跨模块、公共行为或回归风险较高的变更运行完整 `flutter test`。
- 平台目录、构建配置、依赖或发布工作流变更运行对应平台构建及相关守卫测试；修改 CI 路径分类时必须验证各类代表路径。
- 本地调试构建不能替代发布工作流和 PRD 规定的发布门禁。无法运行适用验证时，必须在 PR 中说明原因、风险和补偿验证，不得写成已通过。

测试文件使用 `*_test.dart`。优先覆盖录音连续性、模型校验、初始化下载与续传、会议模型锁定、积压恢复、转录排序、说话人时间段映射、快照原子切换、音频分享临时文件清理、Windows 单实例/托盘/输入设备中断/睡眠恢复、全平台更新 deferred，以及 Forui 的加载、空白和错误状态。SenseVoice 的 RTF、延迟、内存、能耗、温控和关键事实召回率，以及说话人分离的 DER、人数误差和 RTF，均为可选的非阻断工程观测，不要求形成候选设备证据，也不进入发布结论。

## OCR 代码审查

所有 PR 都必须使用 `$open-code-review-delegate` 完成审查。OCR 只负责确定范围、排除项和适用规则，缺陷判断、人工补充审查与误报过滤由审查代理完成。

- 按目标使用 workspace、range 或 commit 模式；先运行 preview，再按 `ocr delegate rule` 的规则检查全部 reviewable 文件及其真实 diff 或未跟踪文件。
- 使用 `--background` 或 `--background-file` 注入 PRD、技术方案和用户影响。涉及录音、模型锁定、联合最终快照、说话人分离、音频分享或数据删除时，必须带上相应产品边界。
- preview 排除的 Markdown、生成文件或不支持文件仍须人工检查真实 diff，并逐项记录排除原因；不得让构建产物或依赖噪声掩盖源码改动。
- 审查总结必须覆盖 preview 返回的每个文件，报告总数、已审查数、跳过数和原因，覆盖率必须为 100%。
- 按 Critical、High、Medium、Low 报告精确路径、行号、触发条件、用户影响和修复建议。始终报告 Critical/High；只报告有实际影响的 Medium 和明确有价值的 Low；疑似误报静默丢弃。
- 用户只要求审查时保持只读；要求审查并修复时直接修复 Critical/High、补充测试并重新审查。PR 转为 Ready 或合并前必须完成审查；未解决的 Critical/High 阻断交付，保留的 Medium 必须说明风险与后续动作。
- OCR 不能替代格式化、静态检查、测试和目标平台构建；修复后重新运行受影响验证并审查新 diff。

## 提交、PR 与安全

- 所有仓库变更，包括代码、测试、配置和文档，都必须在独立分支提交并通过 PR 合并；禁止直接向默认分支提交或推送。Codex 创建的分支默认使用 `codex/` 前缀，除非用户明确指定其他命名。
- 开始修改前检查工作区和分支状态，保留用户已有变更；只暂存本次确认的路径，禁止使用 `git add .`、`git add -A` 或同类全量暂存命令，不得将无关修改混入提交。
- PR 默认创建为 Draft，且保持单一目的和可审查范围。适用的格式化、静态检查、测试、构建和 OCR 审查完成后才能转为 Ready。
- 必需 CI 检查以默认分支保护规则为准；全部通过且 Critical/High 问题清零后方可合并。非必需检查失败或长期 pending 时也必须评估并在 PR 中说明，不能静默忽略；保留 Medium 时必须说明风险、理由和后续动作。
- 只有用户明确授权后才能合并 PR。默认使用 squash merge 以保持线性历史；合并后删除功能分支、同步本地默认分支并确认工作区干净。禁止使用 merge commit 合并默认分支。
- 提交信息优先使用中文。提交标题应简短并使用祈使语气，例如 `增加 ASR 积压恢复`。
- PR 必须引用对应 PRD 章节，说明用户影响，并列出验证命令和 OCR 范围；UI 变更需附截图。不涉及 PRD 或 UI 时须在 PR 中明确标注不适用。
- 禁止提交密钥、令牌、`.env`、签名证书、keystore、provisioning profile、录音、下载的模型、`build/` 或 `coverage/`。未经用户明确授权，禁止强制推送、重写共享历史、移动已发布 tag，或使用破坏性 Git 命令覆盖未确认修改。

## graphify

This project has a knowledge graph at graphify-out/ with god nodes, community structure, and cross-file relationships.

When the user types `/graphify`, use the installed graphify skill or instructions before doing anything else.

Rules:
- For codebase questions, first run `graphify query "<question>"` when graphify-out/graph.json exists. Use `graphify path "<A>" "<B>"` for relationships and `graphify explain "<concept>"` for focused concepts. These return a scoped subgraph, usually much smaller than GRAPH_REPORT.md or raw grep output.
- Dirty graphify-out/ files are expected after hooks or incremental updates; dirty graph files are not a reason to skip graphify. Only skip graphify if the task is about stale or incorrect graph output, or the user explicitly says not to use it.
- If graphify-out/wiki/index.md exists, use it for broad navigation instead of raw source browsing.
- Read graphify-out/GRAPH_REPORT.md only for broad architecture review or when query/path/explain do not surface enough context.
- After modifying code, run `graphify update .` to keep the graph current (AST-only, no API cost).
