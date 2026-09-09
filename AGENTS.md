# 会迹（MeetTrace）仓库协作指南

## 基线

- 沟通、文档、计划和提交信息优先中文；标识符、API、命令与路径保留原文。
- [Alpha PRD](docs/product/Alpha_PRD_无登录版.md) 是产品唯一事实源，[文档入口](docs/README.md) 定义权威关系。范围或 P0 验收变化时，先执行 `$grill-me`、更新 PRD 并同步本文件；冲突未消除前停工。

## 不可破坏的产品边界

- Android、iOS、Windows 自适应 Alpha；无登录、同步或 AI 总结。本地 SenseVoice 与用户自配在线 ASR 共存；Windows 在 AT-21～AT-26 闭环前标记为规划中。
- 事实 PCM 优先；推理不得中断录音。封存后最终 ASR 与分离并行，分离失败降级为单一说话人。
- 本地 ASR 仅用官方 `sherpa_onnx` 和固定 SenseVoice。权重不得进入 APK、IPA 或 MSIX；资源按所选本地能力准备，不阻断首页、历史或在线配置。
- 设置保存默认转录来源，会议开始前允许选择本地或在线；开始后锁定端点、模型、参数及分离配置，不自动切换或混合输出。会后手动换来源必须生成新任务和完整新快照，失败保留旧稿。
- 在线模型名和厂商不设白名单；首批支持 Audio Transcriptions、Chat 音频输入与 Realtime Transcription 协议，私有协议经适配器或用户自有网关。文件接口不宣称实时。每场在线上传和会后完整音频再次识别需明确告知并确认，费用由用户服务账户承担。
- API Key 与认证头仅存系统安全存储；会议/任务保存非秘密配置副本，编辑配置不得改变旧任务上传目标。事实 PCM 不改写，在线转换仅作用于发送副本。无服务端精确时间信息必须标记粗粒度；不得伪造模型版本或说话人。
- 主题默认跟随系统，可切换浅色/深色并仅本机保存；异常回退系统主题，不阻断核心流程。
- 应用语言支持简体中文/英文，默认跟随系统；任意 `zh-*` 使用简体中文，其他未支持语言回退英文。设置可即时切换并仅本机保存，且不得中断录音、ASR 或最终处理。
- Android、iOS、Windows Release 默认开启可退出的 Sentry，首页不展示告知，设置页披露采集边界：错误 100%、进程级性能抽样 20%、录音期每 60 秒匿名窗口；禁用 PII、Replay、日志、截图、View Hierarchy、用户交互与 Production Profiling。Sentry 失败不得影响事实录音；三平台生产配置与符号化失败阻断统一发布。
- 新会议按本地开始时间确定性命名。文本分享只含最终转录；音频分享独立二次确认并生成临时 WAV，不改写 PCM。
- Android 同时发布签名的 `armeabi-v7a`、`arm64-v8a`、`x86_64` split APK 与包含三者的 universal APK；README 默认 arm64，universal 仅作手动兼容下载，自动更新只选择本机 ABI 的 split APK。iOS 只经 TestFlight；Windows 只经 Microsoft Store 发布 Windows 10 22H2/11 x64 MSIX。GitHub 不上传 IPA 或 MSIX。
- 发布链仅含 `Alpha Release` 与 `Alpha Release Reconciler`。三平台同 SHA：Android 四包逐一验证签名、ABI、摘要、安装启动及 sherpa/ONNX 原生库加载，iOS 固定组 `Testing`，同一 MSIX 依次取得 Flight `Published` 与 production `Published/Public`；随后公开原 Draft、重验四个 APK、前移指针。无最终人工审批或专用 Windows runner，且 Store 回执不证明客户端生命周期。
- 发布资产、tag 和撤回记录不可覆盖、移动或删除。SignPath 未接入；启用前更新 PRD、验证包身份并停止 Store 路线。
- 共享构建号从 `2001` 连续递增；四个 Android APK 的实测 `versionCode` 必须与 iOS/Windows 共享构建号完全相同并写入清单，不得使用 ABI 偏移，客户端不得推导。
- Alpha 仅支持当前公开版本，不承诺升级、降级、迁移或数据兼容。本次引入在线来源后经用户重新确认仍沿用全清策略；破坏性清理须安装前确认，并清理本应用凭据，录音或最终处理期间不得安装、退出或清理。

## 架构与 UI

遵循 `View → ViewModel → Use Case / Port → Repository / Service`：UI 在 `lib/ui/features/`，共享组件在 `lib/ui/core/`，Domain 在 `lib/domain/`，实现在 `lib/data/`；`test/` 镜像源码。

Domain 不导入 data；UI 不直连 ONNX、存储或 HTTP。ASR 统一走 `AsrEngine`。录音写入与 ASR 独立；有界队列可丢预览，不能丢录音。

优先使用 Forui `F*`、`context.theme` 和 [Forui LLM 文档](https://forui.dev/docs/reference/llms)；Material 仅限外壳、平台集成或已记录缺口。样式令牌放在 `lib/theme/`；CLI 管理文件用 `dart forui theme create --preset aabbbc` 重生成，组件测试使用真实 `Application`/`FTheme`。

## 实现与验证

- 新功能或重构：`flutter-apply-architecture-best-practices`；行为变化：`flutter-add-widget-test` 或 `dart-add-unit-test`；交付前：`dart-run-static-analysis`；审查：`$open-code-review-delegate`。
- 用户可见行为变化同步写入 `CHANGELOG.md` 的 `Unreleased`；发布前移入与 `release_id` 完全匹配的定版区段。
- sherpa-onnx 只能在 data/service 层通过官方包适配 `AsrEngine`；禁止自建 JNI、FFI、C/C++ 链或 `jniLibs`。
- Actions YAML 只留触发、权限、Environment、依赖与短胶水；可测试逻辑下沉 `tool/`。`CI Gate` 必须依赖 Actions 静态检查。
- 纯文档运行 `git diff --check` 并核对链接、命令和 Markdown。Dart/Flutter 变更至少格式化、分析和受影响测试；跨模块/高风险跑全量测试；平台、依赖、构建、发布或路径分类变更增加相应构建与守卫。未运行项必须说明原因、风险和补偿。
- 测试使用 `*_test.dart`，优先覆盖录音连续性、资源校验、模型锁定、积压、最终快照、分离映射、分享清理、Windows 生命周期、更新 deferred 和 Forui 状态。性能与准确率指标均非阻断观测。

常用命令：`dart format lib test`、`flutter analyze`、`flutter test`、`flutter build apk --debug`、`flutter build windows --debug|--release`、`flutter build ios --debug --no-codesign`。本地构建不替代发布门禁。

## 审查、Git 与安全

- 所有 PR 默认使用官方 [`$open-code-review-delegate`](.agents/skills/open-code-review-delegate/SKILL.md)，通过 `npx skills add alibaba/open-code-review --skill open-code-review-delegate` 安装，不自行创建或改写技能。按技能执行同一 workspace/range/commit 的 `ocr delegate preview` 和 `ocr delegate rule`，由宿主代理实际审查。背景须包含需求、方案、用户影响及涉及的录音、模型锁定、快照、分离、音频分享或删除边界。仅用户明确指定时使用传统 `$open-code-review`；不得因委托失败自动切换外部模型或要求配置 API Key。
- 以 Git 完整清单为基线；覆盖全部 reviewable 文件，人工逐项补审排除文件，遵守根目录及局部项目规则。委托模式按适用规则分组，每组至多一个只读审查代理，宿主默认最多并行 3 个审查任务；无子代理能力时宿主顺序完成同等审查并披露。主代理逐条核验、去重并核对覆盖，输出普通 Markdown；有效问题标明级别、路径、行号、触发、影响和修复建议，规则支持的发现附最小适用规则引用。Critical/High 未清零不得验收阶段、Ready 或合并；OCR 不替代格式、分析、测试或构建。
- 先集中完成实现、必要验证和自检，再固定提交或工作区内容摘要进行审查；仅请求未提交审查时不得为冻结范围而擅自提交。Critical/High/Medium 集中修复后复审受影响范围；有效 Low 留档，不因每个小改动或 Low 重跑全量。不得抽样或降低覆盖标准；失败、中断及变更使结论失效的范围标记未完成，保留未变化的有效证据，直至完成或明确阻断并报告。
- 审查记录保存在不提交的 `build/ocr-delegate/`，包含模式、基准、规则、文件覆盖和裁定，不保存密钥或模型思考。CLI preview/rule 成功只表示准备完成，Token、轮数、退出码或缓存不能替代实际审查证据。切换模式时建立新批次，按文件、内容和适用规则复用有效旧证据，并对未完成及已修改范围合并去重；不得把旧版本审查或传统模式的失败请求标成委托通过。
- 使用独立分支和 Draft PR；Codex 分支默认 `codex/`。只暂存本次路径，禁止 `git add .`/`-A`，不得覆盖用户改动。
- 仅经用户明确授权后 squash 合并；禁止 merge commit。合并后删分支、同步默认分支并确认工作区干净。
- PR 引用 PRD、说明用户影响、验证和 OCR 范围；PRD/UI 不适用时明示，UI 变更附截图。
- 不提交密钥、`.env`、证书、keystore、provisioning profile、录音、模型、`build/` 或 `coverage/`；未经授权不得强推、重写共享历史或移动发布 tag。

## graphify

处理代码库导航、调用链、依赖关系或架构问题时，优先使用 Graphify。若 `graphify-out/graph.json` 存在，代码库问题优先 `graphify query`，关系用 `graphify path`，概念用 `graphify explain`；广泛导航读 `graphify-out/wiki/index.md`。用户输入 `/graphify` 时强制使用。图输出脏文件正常，仅在图过时、错误或用户明确禁用时跳过；修改代码后运行 `graphify update .`。
