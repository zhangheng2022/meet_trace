# 会迹（MeetTrace）仓库协作指南

## 基线

- 沟通、文档、计划和提交信息优先中文；标识符、API、命令与路径保留原文。
- [Alpha PRD](docs/product/Alpha_PRD_无登录版.md) 是产品唯一事实源，[文档入口](docs/README.md) 定义权威关系。范围或 P0 验收变化时，先执行 `$grill-me`、更新 PRD 并同步本文件；冲突未消除前停工。

## 不可破坏的产品边界

- Android、iOS、Windows 自适应 Alpha；无登录、同步、云端 ASR 或 AI 总结。Windows 在 AT-21～AT-26 闭环前标记为规划中。
- 事实 PCM 优先；推理不得中断录音。封存后最终 ASR 与分离并行，分离失败降级为单一说话人。
- ASR 仅用官方 `sherpa_onnx` 和固定 SenseVoice。SenseVoice、Silero VAD、Pyannote、3D-Speaker 权重不得进入 APK、IPA 或 MSIX；资源未齐阻断首页。
- 设置只保存全局默认模型；会议开始后锁定同一 ASR 与分离配置，不得本场覆盖、自动切换或混合输出。
- 主题默认跟随系统，可切换浅色/深色并仅本机保存；异常回退系统主题，不阻断核心流程。
- 应用语言支持简体中文/英文，默认跟随系统；任意 `zh-*` 使用简体中文，其他未支持语言回退英文。设置可即时切换并仅本机保存，且不得中断录音、ASR 或最终处理。
- Android、iOS、Windows Release 默认开启可退出的 Sentry：错误 100%、进程级性能抽样 20%、录音期每 60 秒匿名窗口；禁用 PII、Replay、日志、截图、View Hierarchy、用户交互与 Production Profiling。Sentry 失败不得影响事实录音；三平台生产配置与符号化失败阻断统一发布。
- 新会议按本地开始时间确定性命名。文本分享只含最终转录；音频分享独立二次确认并生成临时 WAV，不改写 PCM。
- Android 只发布签名 arm64 APK；iOS 只经 TestFlight；Windows 只经 Microsoft Store 发布 Windows 10 22H2/11 x64 MSIX。GitHub 不上传 IPA 或 MSIX。
- 发布链仅含 `Alpha Release` 与 `Alpha Release Reconciler`。三平台同 SHA：Android Firebase 原包一次、iOS 固定组 `Testing`、同一 MSIX 依次取得 Flight `Published` 与 production `Published/Public`；随后公开原 Draft、重验 APK、前移指针。无最终人工审批或专用 Windows runner，且 Store 回执不证明客户端生命周期。
- 发布资产、tag 和撤回记录不可覆盖、移动或删除。SignPath 未接入；启用前更新 PRD、验证包身份并停止 Store 路线。
- 共享构建号从 `2001` 连续递增；Android 基础号为共享号减 `2000`，实测 arm64 `versionCode` 必须等于 iOS/Windows 构建号并写入清单，客户端不得推导。
- Alpha 仅支持当前公开版本，不承诺升级、降级、迁移或数据兼容。破坏性清理须安装前确认，录音或最终处理期间不得安装、退出或清理。

## 架构与 UI

遵循 `View → ViewModel → Use Case / Port → Repository / Service`：UI 在 `lib/ui/features/`，共享组件在 `lib/ui/core/`，Domain 在 `lib/domain/`，实现在 `lib/data/`；`test/` 镜像源码。

Domain 不导入 data；UI 不直连 ONNX、存储或 HTTP。ASR 统一走 `AsrEngine`。录音写入与 ASR 独立；有界队列可丢预览，不能丢录音。

优先使用 Forui `F*`、`context.theme` 和 [Forui LLM 文档](https://forui.dev/docs/reference/llms)；Material 仅限外壳、平台集成或已记录缺口。样式令牌放在 `lib/theme/`；CLI 管理文件用 `dart forui theme create --preset aabbbc` 重生成，组件测试使用真实 `Application`/`FTheme`。

## 实现与验证

- 新功能或重构：`flutter-apply-architecture-best-practices`；行为变化：`flutter-add-widget-test` 或 `dart-add-unit-test`；交付前：`dart-run-static-analysis`；审查：`$open-code-review`。
- sherpa-onnx 只能在 data/service 层通过官方包适配 `AsrEngine`；禁止自建 JNI、FFI、C/C++ 链或 `jniLibs`。
- Actions YAML 只留触发、权限、Environment、依赖与短胶水；可测试逻辑下沉 `tool/`。`CI Gate` 必须依赖 Actions 静态检查。
- 纯文档运行 `git diff --check` 并核对链接、命令和 Markdown。Dart/Flutter 变更至少格式化、分析和受影响测试；跨模块/高风险跑全量测试；平台、依赖、构建、发布或路径分类变更增加相应构建与守卫。未运行项必须说明原因、风险和补偿。
- 测试使用 `*_test.dart`，优先覆盖录音连续性、资源校验、模型锁定、积压、最终快照、分离映射、分享清理、Windows 生命周期、更新 deferred 和 Forui 状态。性能与准确率指标均非阻断观测。

常用命令：`dart format lib test`、`flutter analyze`、`flutter test`、`flutter build apk --debug`、`flutter build windows --debug|--release`、`flutter build ios --debug --no-codesign`。本地构建不替代发布门禁。

## 审查、Git 与安全

- 所有 PR 使用 `$open-code-review`：同一 workspace/range/commit 先完整执行 `--preview`，再执行 `--audience agent`，并注入需求、方案和用户影响。录音、模型锁定、快照、分离、音频分享或删除变更必须附相应产品边界。
- 以 Git 完整清单为基线；OCR 覆盖全部 reviewable 文件，人工逐项补审其余文件，尊重 OCR 规则。不得因耗时、文件数、超时、供应商故障或 Token 成本改用抽样、低强度、部分文件或仅 preview 结果；失败文件必须按同一范围和规则逐一重试，直到全部完成或明确阻断并报告。报告有效 Critical/High/Medium/Low、路径、行号、触发、影响和修复；Critical/High 未清零不得提交阶段、Ready 或合并。OCR 不替代格式、分析、测试或构建。
- 为减少 OCR 调用且不降低完整度，阶段内先集中完成实现、格式化、分析、测试与人工自检，再冻结 commit 执行完整 OCR；禁止每个小改动或每个 Low 后重跑全量。一次审查产生的 Critical/High/Medium 必须批量修复后再复审；有效 Low 统一记录，除非用户要求或其风险升级，否则不触发全量重跑。完整审查出现失败请求后，可在保留同一 commit、背景、模型、规则与强度的前提下只精确复审失败文件；这不视为抽样，已成功文件不得无故重复调用。`--background` 保持简短、稳定且仅含必要产品边界；并发默认 `3`、通常不得超过 `4`，除非已证明供应商可稳定承载。`--resume` 只有在确实重新发出失败请求时才算复审；仅返回缓存结果或零 Token 不算完成。
- 使用独立分支和 Draft PR；Codex 分支默认 `codex/`。只暂存本次路径，禁止 `git add .`/`-A`，不得覆盖用户改动。
- 仅经用户明确授权后 squash 合并；禁止 merge commit。合并后删分支、同步默认分支并确认工作区干净。
- PR 引用 PRD、说明用户影响、验证和 OCR 范围；PRD/UI 不适用时明示，UI 变更附截图。
- 不提交密钥、`.env`、证书、keystore、provisioning profile、录音、模型、`build/` 或 `coverage/`；未经授权不得强推、重写共享历史或移动发布 tag。

## graphify

用户输入 `/graphify` 时使用已安装技能。若 `graphify-out/graph.json` 存在，代码库问题优先 `graphify query`，关系用 `graphify path`，概念用 `graphify explain`；广泛导航读 `graphify-out/wiki/index.md`。图输出脏文件正常，仅在图过时/错误或用户禁用时跳过；修改代码后运行 `graphify update .`。
