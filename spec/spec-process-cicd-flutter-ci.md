# Flutter CI/CD 工作流规格

> 当前状态：常规 CI 通过稳定 `CI Gate` 汇总 Actions 静态检查与按路径选择的平台检查；发布链只保留 `Alpha Release` 和 `Alpha Release Reconciler`。新统一门禁首次成功运行前，Windows 继续标记为规划中。

## 1. 目标与边界

本规格描述会迹仓库的常规 CI、Alpha 候选构建和公开发布工作流。工作流必须保证：

- 分支保护始终可以依赖名称稳定的 `CI Gate`，不因路径过滤而缺失。
- Flutter 格式化、静态分析和测试只定义一次，由常规 CI 与正式发布复用。
- Android、iOS、Windows 原生变更仅触发对应平台检查；未知路径保守执行完整 CI。
- iOS 无签名构建只做 Release `Runner.app` 检查，不上传未签名包或 IPA。
- 正式 Android 候选进入 GitHub Draft Release；正式 iOS 只进入 TestFlight。
- 正式三平台构建均注入同一营销版本和共享构建号；客户端只由正式发布工作流显式启用生产更新入口。
- GitHub Release 只保留 Android APK 与单一候选清单，详细签名和包检查证据进入短期 Actions Artifact。
- 最终批准先公开 Pre-release，再以 Ed25519 签名并原子前移 `updates/alpha/alpha.json`；撤回不删除或覆盖资产。
- Sentry 符号上传仅在受保护的发布 Environment 中运行，并与应用内 release/dist 完全一致。

## 2. 工作流清单

| 文件 | 触发方式 | 职责 |
|---|---|---|
| `.github/workflows/quality.yml` | PR、手动 | Actions Lint、路径分类、所需平台检查、稳定 `CI Gate` |
| `.github/workflows/_flutter-core.yml` | `workflow_call` | 锁定依赖、格式化、分析、测试及可选 Android APK 审计 |
| `.github/workflows/alpha-release.yml` | 手动一次 + 协调器内部恢复 | 同一 SHA 三平台候选、一次 Android ARM 验证、最终公开 APK 复核与签名指针更新 |
| `.github/workflows/alpha-release-reconcile.yml` | 即时调度 + 每小时第 7/22/37/52 分钟 | Flight 提交/恢复、TestFlight/Store 轮询、两阶段精确 Store 回执、production 提交与最终门禁 |
| `.github/workflows/firebase-test-lab.yml` | 手动/被调用 | Android 设备实验室自动化回归，不作为发布证据门禁 |
| `.github/workflows/codeql.yml` | PR、每周、手动 | 使用高级配置扫描 Actions、C/C++、Python 与 Ruby，并汇总稳定 `CodeQL Gate` |

## 3. 常规 CI 流程

```mermaid
flowchart LR
  A["PR / 手动"] --> L["Actions Lint"]
  A --> B["Classify changed paths"]
  B -->|"core=true"| C["Reusable Flutter Core"]
  B -->|"android=true"| C
  B -->|"ios=true"| D["Unsigned iOS app audit"]
  B -->|"windows=true"| W["Unsigned Windows MSIX probe"]
  B -->|"文档或 Graphify 输出"| E["CI Gate"]
  L --> E
  C --> E
  D --> E
  W --> E
```

### 3.1 路径分类契约

`tool/ci/classify_changes.py` 输出字符串布尔值 `core`、`android`、`ios`、`windows`：

- `lib/`、`assets/`、依赖文件、工具脚本和工作流：四个输出均为 `true`。
- `android/`：`core=true`、`android=true`。
- `ios/`、`Gemfile`、`Gemfile.lock`：`core=true`、`ios=true`。
- `windows/`：`core=true`、`windows=true`。
- `test/`：只设置 `core=true`。
- 文档、Graphify 输出、`.agents/**` 与 `.claude/**`：四个输出均为 `false`；代理技能目录不属于项目质量检测范围。
- 未识别路径：四个输出均为 `true`，不得静默漏检。
- 手动执行、缺失基准 SHA 或全零基准 SHA：等同完整 CI。

### 3.2 稳定 Gate 契约

`CI Gate` 必须使用 `if: always()` 并依赖 `Actions Lint`、分类、Flutter Core、iOS 和 Windows 检查。Actions YAML 静态检查和分类必须成功；按条件执行的任务必须为 `success`，未选中的任务只能为 `skipped`。工作流触发器不得使用顶层 `paths` 或 `paths-ignore`，以免 required check 消失。

### 3.3 Windows MSIX 开发探针

常规 Windows job 固定使用 `windows-2025`、Java 17 与仓库锁定的 Flutter。它以 `SENTRY_ENABLED=false` 构建 x64 Release，使用 `CN=MeetTrace Development` 生成未签名探针，只验证 manifest、运行资产、模型权重/用户数据/凭据禁入和 SHA-256；上传证据前删除包体。

正式 `Alpha Release` 的 Windows job 使用 Partner Center 固定 Name、Publisher、PublisherDisplayName、PFN 和 Store ID 构建 Store MSIX，生成候选清单与 provenance，并把 MSIX 只上传 Actions Artifact。Reconciler 幂等提交或恢复固定 Package Flight，并通过官方 Store CLI/API 轮询同一包；Flight `Published` 且精确包身份匹配后，才将同一 MSIX 以 100% rollout 提交 production。production 达到 `Published/Public` 且精确包身份匹配后，才生成 schema 3 最终门禁。Windows 门禁不依赖专用机，也不证明 Store 客户端生命周期。Android 签名 APK 只在来源运行执行一次 Firebase ARM 原包验证；TestFlight 同一 build 必须已通过 Beta App Review、位于固定外测组并进入 Testing。GitHub Release 明确拒绝 IPA 与 MSIX，正常路径不使用人工审批或人工状态证明。

## 4. 可复用 Flutter Core

输入：

| 输入 | 类型 | 要求 |
|---|---|---|
| `checkout_ref` | string | 必填，待验证的不可变提交或引用 |
| `build_android` | boolean | 是否构建并检查 Debug APK |

执行顺序固定为：检出 → Java/Flutter 工具链 → `flutter pub get --enforce-lockfile` → format → analyze → test → 可选 Android 构建与审计。任一步失败即失败关闭。常规 CI 不上传可从日志或后续构建重复得到的工具链与 Debug 包证据。

## 5. iOS 无签名审计

常规 CI 在 macOS/Xcode 固定版本上只构建并检查 Release `Runner.app`，检查结果留在 job 日志中，不上传可重复生成的未签名包或证据 Artifact。

禁止创建 `Payload`、压缩 `.ipa`、上传 `.ipa` 或把无签名产物描述为可安装发行包。

## 6. Alpha 发布与 Sentry

完整 Alpha 发布编排、商店 API 门禁、两阶段精确 Store 回执、输入输出与故障策略以 [Alpha Release 端到端规格](spec-process-cicd-alpha-release.md)为准。本节只描述与常规 CI 共用的构建和 Sentry 契约。

`alpha-release.yml` 对选定 SHA 先调用 Flutter Core，再向三平台传递统一构建号。运行时通过 `--dart-define` 注入：

- `SENTRY_RELEASE=com.meettrace.app@<version>+<build>`
- `SENTRY_DIST=<build>`

Android 符号上传在 `android-alpha` Environment 中执行；iOS dSYM 上传在 `testflight` Environment 中执行。两者只读取对应 Environment 的 `SENTRY_AUTH_TOKEN`，失败最多重试三次，最终失败阻断该平台候选。

Android APK 与 `candidate-manifest.json` 是 Release 中仅有的自定义资产；APK 检查、签名输出、证书摘要和 iOS/Windows 候选清单保存在 Actions Artifact，不上传 IPA 或 MSIX。若最终公开失败，协调器使用内部 `resume_run_id` 和门禁 Artifact 恢复，不得再次构建或重复上传同一 TestFlight/Store build。

`github-release` Environment 只保存 `APP_UPDATE_SIGNING_PRIVATE_KEY_BASE64`，以及最终重验所需的固定 TestFlight group/link 和 Store Flight ID，且不设 required reviewer；Store 凭据只保存在 `microsoft-store`，Apple 查询凭据只保存在 `testflight`。协调器删除含短期 URL 的原始响应，只上传脱敏回执。状态、可见性、文件名、包版本、x64 架构、上传状态、TestFlight 审核/Testing 或真实分发合同任一不匹配时，不得公开 Release 或生成新指针。元数据修复、指针修复和撤回复用原发布时的核验结果，不重新提交商店候选。

通过 Store 门禁后，工作流从 Android 候选证据、固定 TestFlight/Store 入口、当前数据代和候选 SHA 生成紧凑 payload，校验私钥导出的公钥与客户端内置公钥一致，并验证上一 envelope 的签名与状态迁移。Contents API 写入携带上一 blob SHA，避免并发覆盖；新公开版本构建号必须递增，同版本仅允许指针修复或从 `publicApproved` 撤回，撤回后不得重新公开同一构建。

## 7. 安全与依赖维护

- 第三方 Actions 必须固定到完整提交 SHA。
- Dependabot 常规 Gradle 更新仅允许既定补丁线；安全更新不使用 `ignore` 排除。
- Dependabot Security Updates 在仓库设置中启用后，仍需通过相同的 `CI Gate`。
- Secrets 不得进入 PR 工作流、日志、仓库文件或非发布 Artifact。
- 历史 Artifact 默认等待保留期到期，不执行批量删除。

Codacy 托管的 Dart Analyzer 不负责 `test/**`，因为它不解析 Flutter 的
`flutter_test` package graph；测试代码仍由仓库内锁定 Flutter 版本执行的
`flutter analyze` 和 `flutter test` 强制检查。Codacy 继续分析 `lib/**` 与其他
受支持源码，不得把整个 Dart 语言关闭。

`.agents/**` 与 `.claude/**` 同时从 Codacy 全局分析和 CodeQL 高级配置中排除；
这两个目录保持主分支原状，不属于项目质量检测与审查范围。

## 8. 验证与变更管理

修改这些工作流时至少运行：

```text
dart format --output=none --set-exit-if-changed lib test tool
flutter analyze
flutter test
```

同时执行 YAML/Actions 静态检查、`test/architecture/release_workflow_guard_test.dart` 和 `test/tool/ci/classify_changes_test.dart`。OCR 审查排除 `.agents/**` 与 `.claude/**`；发布相关改动合并前必须完成其余差异审查，未解决的 Critical/High 阻断交付。
