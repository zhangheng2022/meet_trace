# 仓库指南

## 语言

优先使用中文与用户沟通，并优先使用中文输出文档、计划、说明和提交信息。代码标识符、API 名称、命令、文件路径及需要保持准确的技术术语保留英文。

## 产品边界

- 会迹（MeetTrace）是 Android + iOS 自适应 Alpha，不提供登录或跨设备同步；双平台排期以 PRD 门槛评估为准，不继承原 Android 两周假设。
- 本地音频是唯一事实源；推理变慢或失败时，录音必须继续。说话人分离属于可降级能力。
- 端侧 ASR 仅使用官方 `whisper.cpp` v1.9.1 双模型：内置标准模型 `whisper-cpp-base-q5_1-v1.9.1`，高级模型 `whisper-cpp-small-q5_1-v1.9.1` 按需下载。
- 官方 `ggml-silero-v6.2.0` VAD 随 Base 内置，只负责确定性语音分段，不是第三个 ASR 模型；VAD 失败时预览降级为仅录音，事实 PCM 不受影响。
- 设置保存全局默认模型，首页开始会议时直接使用且不提供本场覆盖；录音开始后模型锁定，同时负责会中和最终转录，不得自动切换或混合输出。
- 当前 iOS 只要求 macOS/Xcode arm64 无签名构建、产物审计和共享自动化测试，不执行 iPhone/iPad 真机测试；后台录音、中断、性能、温控和识别质量必须标记为 `not_tested`。
- 真实产品会议准确率、噪声幻觉下降、语音首尾召回和 Preview 延迟是非阻断观察项；缺少合格证据时标记为 `not_tested`，不得声称质量通过，也不得阻断阶段 0～4 合并或 Alpha 发布。事实 PCM、录音连续性、模型锁定、确定性静音零误检、chunk 一致性、故障降级、资源释放和最终快照原子性仍是硬门槛。
- 新会议使用“待生成标题”，最终转录完成后由 AI 总结生成标题。AI 总结只能基于最终转录；使用云端 AI 时仅上传最终文本，并为关键结论保留带时间戳的原文证据。
- 扩展 P0 前必须先更新 PRD。

## 架构与项目结构

遵循 `View → ViewModel → Use Case / Port → Repository / Service 实现`：

- `lib/ui/features/<feature>/{views,view_models}/`：精简页面和展示状态。
- `lib/ui/core/`：共享 Forui 组件和 UI 工具。
- `lib/domain/{models,ports,use_cases}/`：业务概念、纯 Dart 能力端口和可复用编排。
- `lib/data/{models,repositories,services}/`：端口实现，以及持久化、HTTP、音频、模型管理和 ASR 适配器。

Domain 不得反向导入 data；UI 只依赖 domain 的 Port、Use Case 和模型，不得直接调用 whisper.cpp、原生 FFI、存储或 HTTP。两个模型分别实现统一 `AsrEngine`，由 Factory 按会议锁定的模型创建；具体 Engine 不得泄漏到 UI 或 ViewModel。VAD 与 ASR context 只存在于 data/service 和隔离 Native Assets package。音频写入与 VAD/ASR 必须独立运行；有界队列可以丢弃实时预览任务，但不能丢失录音。`test/` 镜像源码路径，设备流程放在 `integration_test/`，需求和技术决策放在 `docs/`。

## Forui 优先

优先使用 Forui 的 `F*` 组件和 `context.theme` 令牌。实现或核对 Forui API 时，优先参考 [Forui LLM 文档](https://forui.dev/docs/reference/llms)。仅在应用外壳、平台集成或已记录的能力缺口中使用 Material。禁止在功能组件中硬编码颜色、字体、圆角和重复间距；统一扩展 `lib/theme/`。CLI 管理的文件应通过 `dart forui theme create --preset aabbbc` 等命令重新生成。组件测试必须使用真实的 `Application`/`FTheme` 外壳。

## 技能与实现流程

- 新增功能或重构使用 `flutter-apply-architecture-best-practices`；行为变更使用 `flutter-add-widget-test` 或 `dart-add-unit-test`；交付前使用 `dart-run-static-analysis`；代码审查使用 `$open-code-review-delegate`。
- `whisper.cpp` 只通过仓库内 `meettrace_whisper_native` package 接入：官方源码固定 commit，使用 Native Assets 构建、`ffigen` 生成绑定和最小 C ABI 包装。禁止自建 JNI、手工 `jniLibs`、散落的 `DynamicLibrary.open` 或在 UI/domain 暴露 FFI；两个模型仅在 data/service 层通过统一 `AsrEngine` 适配。
- 官方包缺少目标能力时，先调整依赖版本或模型并更新 PRD，不得以私有原生桥接绕过。
- 变更产品范围或 P0 验收标准前运行 `$grill-me`。
- 活动文档入口为 `docs/README.md`；旧方案不在 `docs/` 保留副本，历史由 Git 保存。

## 常用命令与质量门槛

- `flutter pub get`：解析依赖。
- `flutter run -d <device-id>`：在 Android 或 iOS 设备上运行。
- `dart format lib test integration_test`：格式化 Dart 源码。
- `flutter analyze`：执行 `flutter_lints` 静态检查。
- `flutter test`：运行单元测试和组件测试。
- `flutter test integration_test`：运行支持的设备流程。
- `flutter build apk --debug`：构建 Alpha 调试 APK。
- `flutter build ios --debug --no-codesign`：在 macOS/Xcode 环境构建 iOS Alpha 调试产物。

测试文件使用 `*_test.dart`。优先覆盖录音连续性、模型校验、会议模型锁定、积压恢复、转录排序、快照原子切换、证据映射，以及 Forui 的加载、空白和错误状态。性能与资源发布证据必须绑定设备和原始指标；双模型产品会议质量对比属于非阻断观察，未执行时保持 `not_tested`。

## OCR 代码审查

代码审查统一使用 `$open-code-review-delegate`。OCR 只负责确定范围、排除项和适用规则，缺陷判断与误报过滤由审查代理完成。

- 按目标使用 workspace、range 或 commit 模式；必须审查 preview 返回的全部 reviewable 文件，并按 `ocr delegate rule` 的规则检查真实 diff 或未跟踪文件。
- 使用 `--background` 或 `--background-file` 注入 PRD、技术方案和用户影响。涉及录音、模型锁定、最终快照、证据链或数据删除时，必须带上相应产品边界。
- 生成文件只能通过明确的 `--exclude` 模式排除并说明原因，不得让 `graphify-out/`、构建产物或依赖噪声掩盖源码改动。
- 按 Critical、High、Medium、Low 报告精确路径、行号、触发条件、用户影响和修复建议。始终报告 Critical/High；只报告有实际影响的 Medium 和明确有价值的 Low；疑似误报静默丢弃。
- 用户只要求审查时保持只读；要求审查并修复时直接修复 Critical/High、补充测试并重新审查。涉及 `lib/`、平台目录、数据库 schema/迁移、构建配置或 `integration_test/` 的变更，交付或创建 PR 前必须完成审查；未解决的 Critical/High 阻断交付，保留的 Medium 必须说明风险与后续动作。
- OCR 不能替代格式化、静态检查、测试和目标平台构建；修复后重新运行受影响验证并审查新 diff。

## 提交、PR 与安全

提交标题应简短并使用祈使语气，例如 `增加 ASR 积压恢复`。PR 必须引用对应 PRD 章节，说明用户影响，列出验证命令和 OCR 范围；保留 Medium 时说明原因与后续动作。UI 变更需附截图。禁止提交密钥、录音、下载的模型、`build/` 或 `coverage/`。

## graphify

项目知识图谱位于 `graphify-out/`。用户输入 `/graphify` 时，必须先使用已安装的 Graphify 技能。

- 代码库问题优先运行 `graphify query "<question>"`；关系和概念分别使用 `graphify path`、`graphify explain`。有 `graphify-out/wiki/index.md` 时优先用于宽泛导航，只有架构综述或查询信息不足时才读取 `GRAPH_REPORT.md`。
- `graphify-out/` 的脏文件通常来自 hook 或增量更新，不是跳过查询的理由；仅在图谱本身错误、过期或用户明确禁止时跳过。
- 修改代码后运行 `graphify update .`，保持图谱同步。
