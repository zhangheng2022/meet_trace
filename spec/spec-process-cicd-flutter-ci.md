# Flutter CI 工作流规格

> 工作流实现及守卫测试是工程事实；本文只记录稳定合同。

## 1. 工作流

| 文件 | 触发 | 职责 |
| --- | --- | --- |
| `quality.yml` | PR、手动 | Actions Lint、路径分类、平台检查、`CI Gate` |
| `_flutter-core.yml` | `workflow_call` | 依赖、格式、分析、测试、可选 Android Debug 审计 |
| `alpha-release.yml` | 手动、内部恢复 | 同一 SHA 三平台候选、一次 Android 验证、最终公开与指针 |
| `alpha-release-reconcile.yml` | 即时、定时 | TestFlight/Store 协调与 schema 3 门禁 |
| `firebase-test-lab.yml` | 手动 | Android 设备回归；不是发布批准输入 |
| `codeql.yml` | PR、每周、手动 | CodeQL 与稳定 `CodeQL Gate` |

## 2. 常规 CI

`tool/ci/classify_changes.py` 输出字符串布尔值 `core`、`android`、`ios`、`windows`：

| 路径 | 输出 |
| --- | --- |
| `lib/`、`assets/`、依赖、工具、工作流 | 全部 `true` |
| `android/` | `core`、`android` |
| `ios/`、Gemfile | `core`、`ios` |
| `windows/` | `core`、`windows` |
| `test/` | 仅 `core` |
| 文档、Graphify、`.agents/**`、`.claude/**` | 全部 `false` |
| 未识别路径或无可靠基准 SHA | 全部 `true` |

`CI Gate` 必须使用 `if: always()` 并依赖 Actions Lint、分类和所有条件平台 job。必需 job 只能为 `success`，未选中 job 只能为 `skipped`。触发器不得用顶层 `paths` 或 `paths-ignore`。

可复用 Flutter Core 的顺序固定为：检出 → Java/Flutter → `flutter pub get --enforce-lockfile` → format → analyze → test → 可选 Android Debug 构建与审计。任一步失败即关闭。

## 3. 平台审计

- iOS：只构建 Release `Runner.app` 并检查；不创建、上传或描述为可安装 IPA。
- Windows：在 `windows-2025` 以 `SENTRY_ENABLED=false` 构建 Release，生成 `CN=MeetTrace Development` 的不可分发探针，检查 manifest、运行资产和禁入内容，上传证据前删除 MSIX。
- Android：正式候选只构建签名 arm64 APK，并在来源运行的 Firebase ARM 设备以 `--no-resign` 验证一次。

## 4. 发布共享合同

完整状态机见 [Alpha Release 规格](spec-process-cicd-alpha-release.md)。CI 与发布只共享以下规则：

- 三平台使用同一营销版本和共享构建号。
- GitHub Release 只含 Android APK 与公开候选清单；IPA、MSIX 和详细证据留在平台或短期 Artifact。
- Android/iOS 候选的 `SENTRY_RELEASE` 为 `com.meettrace.app@<version>+<build>`，`SENTRY_DIST` 为共享构建号；符号上传只读对应受保护 Environment 的 Token。
- Windows Store 候选固定关闭 Sentry。
- 完整门禁前不得公开 Draft 或修改 `updates/alpha/alpha.json`；撤回不删除或覆盖资产。
- Store、Apple、签名与更新私钥不得进入 PR 工作流、日志、仓库或非发布 Artifact。

第三方 Actions 固定完整提交 SHA。Dependabot 安全更新仍需通过 `CI Gate`；历史 Artifact 按保留期到期，不做批量删除。Codacy 不分析 `test/**` 的 Flutter package graph，测试仍由仓库锁定 Flutter 的 `analyze` 和 `test` 覆盖；`.agents/**` 与 `.claude/**` 排除于项目质量扫描。

## 5. 变更验证

```text
dart format --output=none --set-exit-if-changed lib test tool
flutter analyze
flutter test
```

同时运行 Actions/YAML 静态检查、`test/architecture/release_workflow_guard_test.dart` 和 `test/tool/ci/classify_changes_test.dart`，并按 AGENTS 完成 OCR。
