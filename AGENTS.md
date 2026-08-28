# 会迹（MeetTrace）仓库协作指南

## 语言

沟通、文档、计划、说明和提交信息优先使用中文；代码标识符、API、命令、路径和需保持准确的术语保留英文。

## 产品边界

`docs/product/Alpha_PRD_无登录版.md` 是产品唯一事实源，`docs/README.md` 是文档入口。产品范围或 P0 验收变化时，先执行 `$grill-me`、更新 PRD 并在同一 PR 同步本文件，再实现；冲突时停工并先消除冲突。

- Android、iOS、Windows 自适应 Alpha；无登录、跨设备同步或 AI 总结。Windows 在 PRD AT-21～AT-26 闭环前标记为规划中。
- 本地音频是唯一事实源；推理失败或变慢不得中断录音。说话人分离是首次初始化阻断能力，封存后与最终 ASR 并行，失败降级为单一说话人。
- ASR 仅允许官方 sherpa-onnx `sherpa-onnx-sense-voice-zh-en-ja-ko-yue-int8-2024-07-17`。SenseVoice、Silero VAD、Pyannote、3D-Speaker 权重不得进入 APK、IPA 或 MSIX；首次初始化按固定 Manifest 下载、校验，资源未齐时阻断首页。
- 设置只保存全局默认模型；会议开始后锁定同一模型用于会中和最终转录，不得本场覆盖、自动切换或混合输出。
- 主题默认跟随系统，可切换浅色/深色并仅本机持久化；选择即时全局生效，异常回退跟随系统且不阻断核心流程。
- 新会议按本地开始时间生成确定性标题。文本分享只含最终转录；音频分享使用独立入口、二次确认和临时 WAV，不改写事实 PCM。
- Android 只发布 `arm64-v8a` 签名 APK；iOS 只经 TestFlight 分发且 GitHub 不上传 IPA；Windows 只发布 Windows 10 22H2/11 x64 MSIX，经 Microsoft Store 分发且 GitHub 不上传 MSIX。
- 发布链仅含 `Alpha Release` 与 `Alpha Release Reconciler`：维护者手动提供一次 `release_id`，其余步骤幂等自动推进，不设 `github-release` 人工审批。三平台必须同 SHA 且门禁全过：Android Firebase ARM 原包验证一次、iOS 固定外测组为 `Testing`、同一 Windows MSIX 依次取得 Flight `Published` 与正式 `Published/Public` 精确回执；随后公开原 Draft、重下 APK 验摘要，再前移更新指针。Windows 门禁不证明 Store 客户端生命周期，也不依赖专用机或自托管 runner。
- 发布资产、tag 和撤回版本不可覆盖、移动或删除；自动更新不得暴露未批准候选。SignPath 仍是待审核路线，启用前须更新 PRD 并验证包身份兼容性，禁止双 Windows 包身份。
- 共享构建号从 `2001` 连续递增。Android 保留 `--split-per-abi`，基础构建号为共享号减 `2000`；实测 ARM64 `versionCode` 必须等于 iOS/Windows 构建号并写入候选清单和签名更新 Manifest，客户端不得自行推导。
- Alpha 仅支持当前公开版本，不承诺升级、降级、迁移或数据兼容。破坏性版本可在安装前确认后清除本地数据并重新初始化，但录音或最终处理期间不得强制安装、退出或清理；版本递增、包身份和签名门禁仍适用。

## 架构与项目结构

遵循 `View → ViewModel → Use Case / Port → Repository / Service`：UI 位于 `lib/ui/features/`，共享组件位于 `lib/ui/core/`，业务模型/端口/编排位于 `lib/domain/`，实现位于 `lib/data/`；`test/` 镜像源码路径。

Domain 不导入 data；UI 只依赖 domain，不直连 ONNX、存储或 HTTP。ASR 统一走 `AsrEngine`，具体实现不得泄漏到 UI/ViewModel。录音写入与 ASR 独立运行；有界队列可丢实时预览，不能丢录音。

## Forui 优先

优先使用 Forui `F*` 组件、`context.theme` 和 [Forui LLM 文档](https://forui.dev/docs/reference/llms)；Material 仅限应用外壳、平台集成或已记录的能力缺口。功能组件不得硬编码样式，主题令牌统一放在 `lib/theme/`；CLI 管理文件通过 `dart forui theme create --preset aabbbc` 重生成，组件测试使用真实 `Application`/`FTheme` 外壳。

## 技能与实现流程

- 新增功能或重构使用 `flutter-apply-architecture-best-practices`；行为变更使用 `flutter-add-widget-test` 或 `dart-add-unit-test`；交付前使用 `dart-run-static-analysis`；代码审查使用 `$open-code-review`。
- sherpa-onnx 仅通过官方 `sherpa_onnx` 包在 data/service 层适配 `AsrEngine`；禁止自建 JNI、FFI/C API、C/C++ 构建链或 `jniLibs`。能力不足时调整官方包版本或更新 PRD，不得私接原生桥。
- GitHub Actions YAML 只保留触发器、权限、Environment、job 依赖和短胶水步骤；可独立测试的状态分类、合同解析、Artifact 选择与回执生成必须下沉到 `tool/`。常规 CI 的稳定 `CI Gate` 必须依赖 Actions 静态检查。

## 质量门槛

- 常用命令：`dart format lib test`、`flutter analyze`、`flutter test`、`flutter build apk --debug`、`flutter build windows --debug`、`flutter build windows --release`、`flutter build ios --debug --no-codesign`。
- 纯文档运行 `git diff --check` 并人工核对链接、命令和 Markdown；Dart/Flutter 变更至少格式化、分析和运行受影响测试，跨模块或高风险变更运行全量测试；平台、依赖、构建或发布变更运行对应构建与守卫测试，CI 路径分类变更须验证代表路径。无法执行时在 PR 写明原因、风险和补偿验证，不得声称通过。
- 测试使用 `*_test.dart`，优先覆盖录音连续性、资源下载/校验、模型锁定、积压恢复、转录/说话人映射、最终快照、音频分享清理、Windows 生命周期、更新 deferred 和 Forui 状态。性能、能耗、温控、召回率、DER、人数误差与 RTF 仅为非阻断观测。
- 本地构建不替代发布工作流和 PRD 门禁。

## OCR 代码审查

所有 PR 使用 `$open-code-review`。执行 Agent 核对结果、补审排除文件并过滤误报。

- 全程复用 workspace（无范围参数）、range（`--from <ref> --to <ref>`）或 commit（`--commit <ref>`）范围；先加 `--preview`，再以 `--audience agent` 正式审查，并用 `--background` 或 `--background-file` 注入需求、方案和用户影响。涉及录音、模型锁定、最终快照、说话人分离、音频分享或数据删除时必须包含对应产品边界。
- 以 Git 完整变更清单为基线：OCR 覆盖全部 reviewable 文件，人工补审 Markdown、生成文件和不支持文件。总结报告变更总数、OCR/人工审查数、跳过数和原因，覆盖率必须为 100%。
- 报告 Critical/High、有实际影响的 Medium 和明确有价值的 Low，包含路径、行号、触发条件、用户影响与修复建议；过滤疑似误报，无发现也须说明。仅审查时只读；要求修复时修复 Critical/High、补测试并按原范围复审。未解决 Critical/High 阻断 Ready/合并；保留 Medium 须说明风险和后续动作。
- OCR 不替代格式化、静态检查、测试或平台构建；修复后重跑受影响验证。

## 提交、PR 与安全

- 所有变更在独立分支通过 PR 合并；不得直推默认分支。Codex 分支默认 `codex/` 前缀。修改前检查状态并保留用户变更；仅暂存本次路径，禁止 `git add .`、`git add -A`。
- PR 默认 Draft 且单一目的；完成适用验证和 OCR 后才转 Ready。必需 CI 全过且 Critical/High 清零才可合并；非必需失败/pending 和保留 Medium 也须在 PR 说明。
- 仅经用户明确授权后合并，默认 squash；禁止 merge commit。合并后删分支、同步默认分支并确认工作区干净。
- 提交信息优先中文、简短祈使。PR 引用 PRD 章节、说明用户影响并列出验证和 OCR 范围；PRD/UI 不适用时明确标注，UI 变更附截图。
- 禁止提交密钥、令牌、`.env`、证书、keystore、provisioning profile、录音、模型、`build/` 或 `coverage/`。未经授权不得强推、重写共享历史、移动已发布 tag 或用破坏性 Git 命令覆盖未确认修改。

## graphify

- 用户输入 `/graphify` 时，先使用已安装的 graphify 技能或说明。
- `graphify-out/graph.json` 存在时，代码库问题先运行 `graphify query "<question>"`；关系用 `graphify path "<A>" "<B>"`，概念用 `graphify explain "<concept>"`。广泛导航优先 `graphify-out/wiki/index.md`，仅在架构审查或查询不足时读 `GRAPH_REPORT.md`。
- graphify 输出脏文件属正常；仅当任务针对陈旧/错误图或用户明确禁用时跳过。
- 修改代码后运行 `graphify update .`。
