# 2026-09-30 第三方依赖升级清单

基线为 `e5b7911fb9e2bb252746265b39ecfbaebf761c92`。本次覆盖 Flutter/Dart、全部 pub 锁定包、平台构建链、GitHub Actions、仓库技能及实际存在的工具依赖。不发布应用；事实 PCM、用户音频上传授权、凭据存储和发布门禁保持原有边界。本文记录候选升级与核验结果，远程平台构建与 PR 必需检查仍须完成后才能合并。

## Flutter 与直接依赖

Flutter **3.47.2 → 3.47.5**，捆绑 Dart **3.13.2 → 3.13.4**，不独立替换 Dart。依据 [Flutter 官方稳定版清单](https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json)。以下版本均来自升级前后锁文件，包含未变化项；SDK 包随 Flutter 升级。

| 依赖 | 类别 | 基线 | 目标 | 处理 |
| --- | --- | --- | --- | --- |
| `archive` | 直接 | 4.3.0 | 4.3.0 | 保留，当前最新稳定 |
| `audioplayers` | 直接 | 6.8.1 | 6.8.1 | 保留，当前最新稳定 |
| `characters` | 直接 | 1.4.1 | 1.4.1 | 保留，当前最新稳定 |
| `connectivity_plus` | 直接 | 7.3.1 | 7.3.1 | 保留，当前最新稳定 |
| `crypto` | 直接 | 3.0.7 | 3.0.7 | 保留，当前最新稳定 |
| `cryptography` | 直接 | 2.9.0 | 2.9.0 | 保留，当前最新稳定 |
| `disk_space_2` | 直接 | 1.0.13 | 1.0.13 | 保留，当前最新稳定 |
| `flutter` | 直接 | 0.0.0 | 0.0.0 | 随 Flutter SDK |
| `flutter_foreground_task` | 直接 | 11.0.3 | 11.0.3 | 保留，当前最新稳定 |
| `flutter_launcher_icons` | 开发 | 0.14.4 | 0.14.4 | 保留，当前最新稳定 |
| `flutter_lints` | 开发 | 6.0.0 | 6.0.0 | 保留，当前最新稳定 |
| `flutter_localizations` | 直接 | 0.0.0 | 0.0.0 | 随 Flutter SDK |
| `flutter_native_splash` | 开发 | 2.4.8 | 2.4.8 | 保留，当前最新稳定 |
| `flutter_secure_storage` | 直接 | 11.0.0 | 11.2.0 | 升级 |
| `flutter_test` | 开发 | 0.0.0 | 0.0.0 | 随 Flutter SDK |
| `forui` | 直接 | 0.26.0 | 0.27.3 | 升级 |
| `forui_cli` | 开发 | 0.26.1 | 0.27.0 | 升级 |
| `http` | 直接 | 1.6.0 | 1.6.0 | 保留，当前最新稳定 |
| `intl` | 直接 | 0.20.3 | 0.20.3 | 保留，当前最新稳定 |
| `material_ui` | 直接 | 1.1.1 | 1.5.0 | 升级 |
| `meta` | 开发 | 1.19.0 | 1.19.0 | 保留，当前最新稳定 |
| `path` | 直接 | 1.9.1 | 1.9.1 | 保留，当前最新稳定 |
| `path_provider` | 直接 | 2.1.6 | 2.1.6 | 保留，当前最新稳定 |
| `patrol` | 开发 | 4.10.0 | 4.10.0 | 保留，当前最新稳定 |
| `record` | 直接 | 7.1.1 | 7.1.1 | 保留，当前最新稳定 |
| `sentry_dart_plugin` | 开发 | 3.4.0 | 3.4.0 | 保留，当前最新稳定 |
| `sentry_flutter` | 直接 | 9.30.1 | 9.30.1 | 保留，当前最新稳定 |
| `share_plus` | 直接 | 13.3.0 | 13.3.0 | 保留，当前最新稳定 |
| `shared_preferences` | 直接 | 2.5.5 | 2.5.5 | 保留，当前最新稳定 |
| `shared_preferences_platform_interface` | 开发 | 2.4.2 | 2.4.2 | 保留，当前最新稳定 |
| `sherpa_onnx` | 直接 | 1.13.8 | 1.13.8 | 保留，当前最新稳定 |
| `sqflite` | 直接 | 2.4.4 | 2.4.4 | 保留，当前最新稳定 |
| `sqflite_common_ffi` | 直接 | 2.4.3 | 2.4.3 | 保留，当前最新稳定 |
| `url_launcher` | 直接 | 6.3.2 | 6.3.2 | 保留，当前最新稳定 |

Forui 用新 CLI 在临时目录重生成模板并比对；现有自定义主题/API 无需迁移，保留原主题定制；安全存储保持平台保护边界。Material UI 选择 1.5.0，官方已撤回的 1.3.0 不进入锁文件。参见 [Forui](https://pub.dev/packages/forui/changelog)、[Forui CLI](https://pub.dev/packages/forui_cli/changelog)、[安全存储](https://pub.dev/packages/flutter_secure_storage/changelog)、[Material UI](https://pub.dev/packages/material_ui/changelog) 官方变更记录。

## 主项目传递依赖

主锁共 **28 项版本变化＝4 项直接/开发依赖＋24 项传递依赖**；上表包含四项直接变化，下表完整列出24项传递变化，避免把28项全部误称传递依赖。

| 依赖 | 基线 | 目标 |
| --- | --- | --- |
| `_fe_analyzer_shared` | 107.0.0 | 108.0.0 |
| `analyzer` | 14.3.0 | 14.4.0 |
| `code_assets` | 2.0.0 | 2.1.0 |
| `cupertino_ui` | 1.0.2 | 1.1.1 |
| `flutter_secure_storage_darwin` | 0.4.1 | 0.4.3 |
| `flutter_secure_storage_linux` | 3.0.2 | 3.0.3 |
| `flutter_secure_storage_platform_interface` | 2.0.3 | 2.1.1 |
| `forui_lucide` | 0.26.1 | 0.27.0 |
| `image` | 4.9.2 | 4.10.1 |
| `native_toolchain_c` | 0.19.4 | 0.19.5 |
| `petitparser` | 7.0.2 | 7.1.0 |
| `platform` | 3.1.6 | 3.2.0 |
| `record_android` | 2.1.2 | 2.2.0 |
| `record_linux` | 2.1.1 | 2.1.2 |
| `record_web` | 2.1.2 | 2.1.3 |
| `record_windows` | 2.2.3 | 2.3.0 |
| `sqflite_android` | 2.4.3 | 2.4.4 |
| `sqflite_common` | 2.5.11 | 2.5.13 |
| `sqflite_darwin` | 2.4.3+1 | 2.4.4 |
| `sqflite_platform_interface` | 2.4.1 | 2.4.2 |
| `sqlite3` | 3.5.2 | 3.6.0 |
| `synchronized` | 3.4.1+2 | 3.4.2 |
| `vector_math` | 2.4.2 | 2.4.3 |
| `xml` | 7.0.1 | 7.1.0 |

录音插件平台实现、SQLite 和原生构建依赖发生变化，因此需要录音连续性、存储和平台构建回归，不能只依靠解析成功。官方记录：[record_android](https://pub.dev/packages/record_android/changelog)、[record_windows](https://pub.dev/packages/record_windows/changelog)、[sqlite3](https://pub.dev/packages/sqlite3/changelog)。

## Patrol MCP 工具

独立 `tool/patrol_mcp` 锁中49项全部核验。`patrol_mcp 0.2.1` 与 `patrol_cli 4.8.0` 保留官方最新稳定，与主项目 `patrol 4.10.0` 版本守卫保持同步。变化共9项（包含新增1项）：

| 依赖 | 基线 | 目标 |
| --- | --- | --- |
| `archive` | 4.2.0 | 4.3.0 |
| `cli_completion` | 0.5.1 | 0.6.0 |
| `ffi_leak_tracker` | 新增 | 0.1.2 |
| `image` | 4.9.2 | 4.10.1 |
| `mason_logger` | 0.3.5 | 0.3.6 |
| `mcp_dart` | 2.4.1 | 2.4.2 |
| `package_config` | 2.2.0 | 3.0.0 |
| `pub_updater` | 0.5.0 | 0.6.0 |
| `win32` | 5.15.0 | 6.4.0 |

## 上游约束导致的保留

未通过 dependency_overrides 强行越过包约束。下列最新版本来自同次 pub outdated，依赖边由 pub deps 的 dependencyConstraints 核对。主项目11项、MCP2项未采用最新版本：

### 主项目

| 依赖 | 保留 | 最新 | 约束原因 |
| --- | --- | --- | --- |
| `cli_util` | 0.4.2 | 0.6.0 | `flutter_launcher_icons ^0.4.1` |
| `cross_file` | 0.3.5+5 | 0.4.0 | `share_plus ^0.3.5+2`；`share_plus_platform_interface ^0.3.5+2` |
| `dbus` | 0.7.15 | 0.8.0 | `nm ^0.7.0` |
| `equatable` | 2.1.0 | 3.0.0 | `patrol ^2.1.0`；`patrol_log ^2.1.0` |
| `injector` | 3.0.0 | 4.0.0 | `sentry_dart_plugin ^3.0.0` |
| `jni` | 0.14.2 | 1.0.3 | `sentry_flutter 0.14.2` |
| `material_color_utilities` | 0.13.0 | 0.13.1 | Flutter SDK 精确固定 `0.13.0` |
| `nm` | 0.5.0 | 0.6.0 | `connectivity_plus ^0.5.0` |
| `package_config` | 2.2.0 | 3.0.0 | `jni ^2.1.0` 限制其小于3.0.0（analyzer/dart_style 本身允许3.x） |
| `path_provider_android` | 2.2.23 | 2.3.1 | 新版要求 `jni ^1.0.0`，与 `sentry_flutter → jni 0.14.2` 冲突 |
| `test_api` | 0.7.12 | 0.7.14 | flutter_test SDK 精确固定 `0.7.12` |

### Patrol MCP

| 依赖 | 保留 | 最新 | 约束原因 |
| --- | --- | --- | --- |
| `equatable` | 2.1.0 | 3.0.0 | `patrol_cli ^2.1.0`；`patrol_log ^2.1.0`；`cli_completion ^2.0.5` |
| `platform` | 3.1.6 | 3.2.0 | `patrol_cli >=3.1.3 <3.2.0`；`process ^3.0.0` |

约束来源：[Sentry Flutter](https://pub.dev/packages/sentry_flutter)、[path_provider_android](https://pub.dev/packages/path_provider_android)、[Patrol CLI](https://pub.dev/packages/patrol_cli) 官方 pubspec，以及当前 Flutter SDK 的 `flutter`/`flutter_test` pubspec。升级上游依赖或 Flutter SDK 后重新解析，不将受约束版本虚报为全局最新。

## 撤回、停用与安全公告核验

对主项目 **169** 个锁条目和 MCP **49** 个锁条目逐一比对 `pub outdated --show-all --json` 的 current 与锁定目标版本，检查 `isDiscontinued`、`isCurrentRetracted`、`isCurrentAffectedByAdvisory`；撤回与安全公告命中均为 false；主项目 `globbing 1.0.0` 标记 discontinued，来源链为开发依赖 `sentry_dart_plugin 3.4.0 → system_info2 4.1.0 → globbing ^1.0.0`，官方无替代包声明或更新版本。保留此上游依赖并记录停用风险，不通过override或擅自移除功能规避。SDK 条目没有独立 pub 版本，随 Flutter 发行核验。完整逐项证据保存于本地 `build/dependency-upgrade/pub-lock-safety-audit.json`，原始输入为 `pub-all-after.json` 与 `patrol-all-after.json`。这是查询时 pub 已知公告状态，不代表不存在未知漏洞。

## Actions 与 CI 工具

| 依赖 | 基线 → 目标 | 依据/说明 |
| --- | --- | --- |
| Ubuntu runner | 24.04 → 26.04 | [官方 GA 公告](https://github.com/actions/runner-images/issues/14747)，镜像 20260920.143.1 提供 Android SDK/NDK、Java17/21/25、Go1.26.8、ShellCheck0.11.0 |
| macOS runner | macos-26 → 保留 | 官方最新稳定；Xcode27标签仍preview |
| Windows runner | windows-2025 → 保留 | 官方最新稳定，Visual Studio2026镜像 |
| ruby/setup-ruby | 1.324.0 → 1.327.0 | 14594264cd68ce8a2345dd349bc3d138a4ef85c8 |
| github/codeql-action | 4.38.1 → 4.38.2 | 2892aa5e19bbd11bc0cff5427e3b750a04d9e3c2；不能用releases/latest返回的CodeQL bundle tag代替Action版本 |
| Google Cloud CLI | 580.0.0 → 587.0.0 | [9/29 release notes](https://docs.cloud.google.com/sdk/docs/release-notes)，580至587无已使用firebase test/storage命令破坏变更 |
| Microsoft Store CLI | 0.4.1 → 0.4.3 | [官方release](https://github.com/microsoft/msstore-cli/releases/tag/v0.4.3)，价格保留修复与stdout输出支持；未执行发布 |
| actionlint | 1.7.12 → 保留 | 官方latest；新增精确ubuntu-26.04 label声明补其内置列表滞后，无规则禁用 |
| actions/checkout | 7.0.1 → 保留 | 官方latest，3d3c42e5aac5ba805825da76410c181273ba90b1 |
| actions/upload-artifact | 7.0.1 → 保留 | 官方latest，043fb46d1a93c77aae656e7c1c64a875d1fc6a0a |
| actions/download-artifact | 8.0.1 → 保留 | 官方latest，3e5f45b2cfb9172054b4087a40e8e0b5a5461e7c |
| actions/setup-java | 6.0.1 → 保留 | 官方latest，de7274f081f381c8f8158605e0321c36c376e2e6 |
| actions/attest | 4.2.2 → 保留 | 官方latest，1e69f48acb82d1966a394da916b4c1698aa569d6 |
| google-github-actions/auth | 3 → 保留 | 官方latest，7c6bc770dae815cd3e89ee6cdf493a5fab2cc093 |
| google-github-actions/setup-gcloud | 3.0.1 → 保留 | SHA已对应latest，仅完善注释，aa5489c8933f4cc7a4f7d45035b3b1440c9c10db |
| ReactiveCircus/android-emulator-runner | 2.38.0 → 保留 | 官方latest，a421e43855164a8197daf9d8d40fe71c6996bb0d |
| microsoft/microsoft-store-apppublisher | 1.4 → 保留 | 官方latest，cc9910a8d59f2eb55cbb83df0a3800cf3b5300e0 |
| axi92/flutter-action | 2.23.0+SHA固定分支 → 保留 | feature/pin-action-sha头仍36d2c2625bac6ea011cd7808d2a01bd8a7e5c766；普通tag失去内部SHA固定 |
| 传递actions/cache | 5.0.4 → 保留（最新6.1.0） | 由上述fork固定668228422ae6a00e4ad889ee87cd7109ec5666a7，上游尚无更新的固定版本；等待fork更新并核验后升级，不用浮动tag替代 |
| Patrol CLI | 4.8.0 → 保留 | 与Patrol4.10.0/MCP0.2.1同步，pub核验由主代理负责 |

所有13个外部 Action 路径均固定完整40位提交 SHA，并通过官方仓库 commits API 验证。GitHub Release 来源分别为工作流 `uses` 指定的官方仓库；完整核验记录保存在 `build/dependency-upgrade/actions-sha-verification.json`。Actions 静态检查使用官方 actionlint 1.7.12 和 ShellCheck 0.11.0 真实执行成功；新增Ubuntu标签仅补充工具内置列表，未关闭检查规则。CI Gate继续依赖Actions Lint。

## 仓库第三方技能与工具

采用官方 skills CLI 1.7.0 同步来源；35项技能均在 `.agents/skills` 和 `.claude/skills` 核对完整文件摘要。精确源码 revision、安装来源和内容SHA-256见已提交的 [`tool/skills/sources.json`](../../tool/skills/sources.json) 与 [`skills-lock.json`](../../skills-lock.json)。

| 技能 | 固定官方来源 | 处理 |
| --- | --- | --- |
| `create-github-action-workflow-specification` | [github/awesome-copilot](https://github.com/github/awesome-copilot/tree/e62be9667aff87958ed94bee2b396433897d1529) | 官方主文档保持最新，刷新完整来源锁 |
| `dart-add-unit-test` | [flutter/agent-plugins](https://github.com/flutter/agent-plugins/tree/8da8c54ecd740fded70f908ad9c46b72a1f21fb5) | 官方主文档保持最新，刷新完整来源锁 |
| `dart-build-cli-app` | [flutter/agent-plugins](https://github.com/flutter/agent-plugins/tree/8da8c54ecd740fded70f908ad9c46b72a1f21fb5) | 更新官方主文档与附属文件 |
| `dart-collect-coverage` | [flutter/agent-plugins](https://github.com/flutter/agent-plugins/tree/8da8c54ecd740fded70f908ad9c46b72a1f21fb5) | 官方主文档保持最新，刷新完整来源锁 |
| `dart-fix-runtime-errors` | [flutter/agent-plugins](https://github.com/flutter/agent-plugins/tree/8da8c54ecd740fded70f908ad9c46b72a1f21fb5) | 官方主文档保持最新，刷新完整来源锁 |
| `dart-generate-test-mocks` | [flutter/agent-plugins](https://github.com/flutter/agent-plugins/tree/8da8c54ecd740fded70f908ad9c46b72a1f21fb5) | 官方主文档保持最新，刷新完整来源锁 |
| `dart-migrate-to-checks-package` | [flutter/agent-plugins](https://github.com/flutter/agent-plugins/tree/8da8c54ecd740fded70f908ad9c46b72a1f21fb5) | 官方主文档保持最新，刷新完整来源锁 |
| `dart-resolve-package-conflicts` | [flutter/agent-plugins](https://github.com/flutter/agent-plugins/tree/8da8c54ecd740fded70f908ad9c46b72a1f21fb5) | 官方主文档保持最新，刷新完整来源锁 |
| `dart-run-static-analysis` | [flutter/agent-plugins](https://github.com/flutter/agent-plugins/tree/8da8c54ecd740fded70f908ad9c46b72a1f21fb5) | 官方主文档保持最新，刷新完整来源锁 |
| `dart-setup-ffi-assets` | [flutter/agent-plugins](https://github.com/flutter/agent-plugins/tree/8da8c54ecd740fded70f908ad9c46b72a1f21fb5) | 官方主文档保持最新，刷新完整来源锁 |
| `dart-use-ffigen` | [flutter/agent-plugins](https://github.com/flutter/agent-plugins/tree/8da8c54ecd740fded70f908ad9c46b72a1f21fb5) | 官方主文档保持最新，刷新完整来源锁 |
| `dart-use-pattern-matching` | [flutter/agent-plugins](https://github.com/flutter/agent-plugins/tree/8da8c54ecd740fded70f908ad9c46b72a1f21fb5) | 更新官方主文档与附属文件 |
| `dart-use-primary-constructors` | [flutter/agent-plugins](https://github.com/flutter/agent-plugins/tree/8da8c54ecd740fded70f908ad9c46b72a1f21fb5) | 官方主文档保持最新，刷新完整来源锁 |
| `flutter-add-integration-test` | [flutter/agent-plugins](https://github.com/flutter/agent-plugins/tree/8da8c54ecd740fded70f908ad9c46b72a1f21fb5) | 官方主文档保持最新，刷新完整来源锁 |
| `flutter-add-widget-preview` | [flutter/agent-plugins](https://github.com/flutter/agent-plugins/tree/8da8c54ecd740fded70f908ad9c46b72a1f21fb5) | 官方主文档保持最新，刷新完整来源锁 |
| `flutter-add-widget-test` | [flutter/agent-plugins](https://github.com/flutter/agent-plugins/tree/8da8c54ecd740fded70f908ad9c46b72a1f21fb5) | 官方主文档保持最新，刷新完整来源锁 |
| `flutter-apply-architecture-best-practices` | [flutter/agent-plugins](https://github.com/flutter/agent-plugins/tree/8da8c54ecd740fded70f908ad9c46b72a1f21fb5) | 官方主文档保持最新，刷新完整来源锁 |
| `flutter-build-responsive-layout` | [flutter/agent-plugins](https://github.com/flutter/agent-plugins/tree/8da8c54ecd740fded70f908ad9c46b72a1f21fb5) | 官方主文档保持最新，刷新完整来源锁 |
| `flutter-fix-layout-issues` | [flutter/agent-plugins](https://github.com/flutter/agent-plugins/tree/8da8c54ecd740fded70f908ad9c46b72a1f21fb5) | 官方主文档保持最新，刷新完整来源锁 |
| `flutter-implement-json-serialization` | [flutter/agent-plugins](https://github.com/flutter/agent-plugins/tree/8da8c54ecd740fded70f908ad9c46b72a1f21fb5) | 官方主文档保持最新，刷新完整来源锁 |
| `flutter-setup-declarative-routing` | [flutter/agent-plugins](https://github.com/flutter/agent-plugins/tree/8da8c54ecd740fded70f908ad9c46b72a1f21fb5) | 官方主文档保持最新，刷新完整来源锁 |
| `flutter-setup-localization` | [flutter/agent-plugins](https://github.com/flutter/agent-plugins/tree/8da8c54ecd740fded70f908ad9c46b72a1f21fb5) | 官方主文档保持最新，刷新完整来源锁 |
| `flutter-use-http-package` | [flutter/agent-plugins](https://github.com/flutter/agent-plugins/tree/8da8c54ecd740fded70f908ad9c46b72a1f21fb5) | 官方主文档保持最新，刷新完整来源锁 |
| `graphify` | [graphifyy 0.9.72](https://pypi.org/project/graphifyy/0.9.72/) | 修复包源码误装；官方graphifyy0.9.72安装器生成标准技能结构 |
| `grill-me` | [mattpocock/skills](https://github.com/mattpocock/skills/tree/d81f3a183412e71a5b1e84ca21bc1a35eea03a60) | 官方主文档保持最新，刷新完整来源锁 |
| `grilling` | [mattpocock/skills](https://github.com/mattpocock/skills/tree/d81f3a183412e71a5b1e84ca21bc1a35eea03a60) | 补齐漏锁；更新官方内容 |
| `impeccable` | [pbakaus/impeccable](https://github.com/pbakaus/impeccable/tree/0d6b47ea19b63afe15e3f93a44d5d9fbbc6fd275) | 补齐漏锁；4.1.3 → 4.4.0 |
| `msstore-cli` | [github/awesome-copilot](https://github.com/github/awesome-copilot/tree/e62be9667aff87958ed94bee2b396433897d1529) | 官方主文档保持最新，刷新完整来源锁 |
| `open-code-review` | [alibaba/open-code-review](https://github.com/alibaba/open-code-review/tree/a758d9cbfb689937c7857ad64b2dd66adb58c0c2) | 更新官方主文档与附属文件 |
| `open-code-review-delegate` | [alibaba/open-code-review](https://github.com/alibaba/open-code-review/tree/a758d9cbfb689937c7857ad64b2dd66adb58c0c2) | 官方主文档保持最新，刷新完整来源锁 |
| `patrol-setup` | [leancodepl/patrol](https://github.com/leancodepl/patrol/tree/c52c837957811addd36d8dd2efe337d895657ff3) | 官方主文档保持最新，刷新完整来源锁 |
| `patrol-test-architecture` | [leancodepl/patrol](https://github.com/leancodepl/patrol/tree/c52c837957811addd36d8dd2efe337d895657ff3) | 官方主文档保持最新，刷新完整来源锁 |
| `patrol-write-test` | [leancodepl/patrol](https://github.com/leancodepl/patrol/tree/c52c837957811addd36d8dd2efe337d895657ff3) | 官方主文档保持最新，刷新完整来源锁 |
| `sentry-flutter-sdk` | [getsentry/sentry-for-ai](https://github.com/getsentry/sentry-for-ai/tree/1adb9ee6deb9a708b9bd09da536194cdd03ff71c) | 官方主文档保持最新，刷新完整来源锁 |
| `using-git-worktrees` | [obra/superpowers](https://github.com/obra/superpowers/tree/8ca22dba9a94f28898bbce59f2537ff4d87c747d) | 官方主文档保持最新，刷新完整来源锁 |

Graphify 使用官方安装器生成 `SKILL.md`、references与版本文件，不再把Python运行库复制进技能目录。Impeccable4.4.0使用官方固定引擎启动器。既有computedHash变化也可能来自官方CLI完整目录摘要算法刷新，不能据此宣称所有主文档发生变化。新增来源/库存/摘要守卫 `python3 tool/skills/check_skills.py` 接入始终执行的 Actions Lint；正向及临时副本篡改、漏锁负向检查通过。更新入口与使用说明见 [`tool/skills/README.md`](../../tool/skills/README.md)。

仓库没有Node package.json/package-lock.json；gateway仅使用Dart标准库 `dart:async/convert/io/typed_data`，没有独立第三方包，随捆绑Dart升级。未为并不存在的Node应用引入依赖或生成锁文件。

## 平台链与验收状态

### 平台版本选择

| 依赖 | 当前 | 目标 | 依据 |
|---|---|---|---|
| Android Gradle Plugin | 9.1.1 | 9.3.1 | Kotlin 2.4.20 官方完整支持上限；最新 9.4.1 暂不越过兼容矩阵 |
| Gradle | 9.3.1 | 9.7.0 | Kotlin 2.4.20 官方完整支持上限；最新 9.8.0 暂不越过兼容矩阵；添加官方发行包 SHA-256 |
| Kotlin Gradle plugin | 2.4.20 | 保留 | Maven 官方元数据中最新 stable，2.4.21-RC/2.5.0-Beta1 不采用 |
| JDK runtime | CI Temurin 17 | Temurin 25 (本地25.0.4.1，CI固定LTS主版本) | 最新 LTS；JDK27 需 Gradle9.8，超 KGP 支持边界；源码字节码继续17 |
| Android compile SDK | 37 | 保留37 | 原应用锁定；AGP9.3支持最高API37；不为工具升级擅改 min/target 行为 |
| Android NDK | Flutter default 28.2.13676358 | 保留Flutter default | 与Flutter引擎和官方AGP默认一致，无应用自建JNI/FFI链 |
| SDK Build Tools | AGP default36.0.0 | 保留 AGP default | AGP9.3官方默认，无独立应用版本锁 |
| Ruby | 3.4.10 | 4.0.7 | ruby-lang.org最新stable；Fastlane2.240.1官方CI覆盖Ruby4.0/Xcode26.6 |
| Bundler | 2.6.9 | 4.0.22 | RubyGems最新stable；Fastlane约束 >=2.4,<5 |
| Fastlane | 2.240.1 | 保留 | RubyGems最新stable |
| xcodeproj | 1.28.1 | 保留 | RubyGems最新stable |
| CocoaPods | 不存在 | 不引入 | 仓库无Podfile/Podfile.lock，iOS使用Flutter生成本地SwiftPM包 |
| SwiftPM | Xcode26.6集成 | 保留随Xcode | 无独立第三方Package.resolved；远端依赖由pub插件官方Package.swift声明，iOS CI解析 |
| Swift language | 5.0 | 保留 | 这是源码语言模式而非工具发行版本，升级会触发并发语义迁移，无此需求 |
| Windows CMake最低版本 | 3.14 | 保留 | cmake_minimum_required声明兼容下限而非工具版本；实际工具由windows-2025镜像提供 |
| Windows SDK/VS | windows-2025 runner | 保留runner托管 | 包装脚本自动发现MakeAppx，未锁旧工具；CI代理核验最新runner |

### 平台官方来源

- https://kotlinlang.org/docs/gradle-configure-project.html — 2.4.20 支持 Gradle7.6.3–9.7.0、AGP8.5.2–9.3.1。
- https://developer.android.com/build/releases/agp-9-3-0-release-notes — 最低Gradle9.5.0/JDK17，默认NDK28.2.13676358/Build Tools36.0.0。
- https://dl.google.com/dl/android/maven2/com/android/tools/build/gradle/maven-metadata.xml — 最新stable9.4.1。
- https://repo.maven.apache.org/maven2/org/jetbrains/kotlin/kotlin-gradle-plugin/maven-metadata.xml — 最新stable2.4.20。
- https://services.gradle.org/versions/current — 最新stable9.8.0。
- https://services.gradle.org/distributions/gradle-9.7.0-all.zip.sha256 — a9ecb5ac5c2ca40691e6527724d11d0b43b8c0a52825b77c09899f2a72d2d2bf。
- https://docs.gradle.org/current/userguide/compatibility.html — JDK25从9.1支持，JDK27从9.8支持。
- https://raw.githubusercontent.com/flutter/flutter/3.47.5/packages/flutter_tools/lib/src/android/gradle_utils.dart — Flutter已知矩阵较保守，Android升级必须以实际构建补充验证。
- https://www.ruby-lang.org/en/downloads/ — Ruby4.0.7 SHA256 911ace20f90d068ca0e4dda6d0e4f0f81e52e52f2dd4f4004c721e253412e82d。
- https://raw.githubusercontent.com/fastlane/fastlane/2.240.1/.github/workflows/ci.yml — 官方 Ruby4.0 测试。
- https://raw.githubusercontent.com/fastlane/fastlane/2.240.1/fastlane.gemspec — Bundler约束及Ruby4移除默认库显式依赖。
- https://rubygems.org/api/v1/gems/fastlane.json
- https://rubygems.org/api/v1/gems/xcodeproj.json
- https://rubygems.org/api/v1/gems/bundler.json


### RubyGems 全量求解结果

| gem | 基线 | 目标 |
| --- | --- | --- |
| `aws-partitions` | 1.1287.0 | 1.1290.0 |
| `aws-sdk-s3` | 1.232.1 | 1.232.3 |
| `domain_name` | 0.6.20260907 | 0.6.20260921 |
| `excon` | 1.7.1 | 1.7.2 |
| `google-apis-androidpublisher_v3` | 0.108.0 | 0.109.0 |
| `google-apis-storage_v1` | 0.67.0 | 0.68.0 |
| `rdoc` | 8.0.0 | 8.1.0 |
| `representable` | 3.2.0 | 3.3.1 |

Fastlane 2.240.1、xcodeproj 1.28.1 保留最新稳定版本。Ruby 4.0.7 下 `bundle update --all`、`bundle check`、`bundle exec fastlane --version` 和 xcodeproj 加载 Runner/RunnerTests 均成功；无应用发布。未越过上游 gem 依赖约束。

### 本地验收

- Flutter 3.47.5 官方发行包 SHA-256 验证通过。
- `flutter test`：946 项通过；`flutter analyze`：无问题；格式检查412文件无变更。
- 主项目与 Patrol MCP `pub get --enforce-lockfile` 成功；MCP静态分析成功。
- Actions + ShellCheck、35技能双目录校验、Python发布清单测试通过。
- Android Debug APK 实际构建成功（AGP9.3.1/Gradle9.7.0/Kotlin2.4.20/Temurin25.0.4.1），三种ABI均包含Flutter/ONNX/sherpa原生库；iOS/Windows仍须在对应PR runner验证。
- Android/Windows record 平台实现包含后台线程重构；自动测试覆盖事实PCM与生命周期契约，但本次没有真实设备麦克风、蓝牙切换与长录音实测，不能据此宣称真机行为已验证。
- 正式 OCR 宿主全量审查完成，无 Critical/High/Medium 遗留；逐文件证据保存在不提交的 build/ocr-delegate。


本地已完成的Actions静态检查和技能锁验证不能替代应用格式、分析、全量测试、三平台构建、正式OCR宿主审查以及PR必需CI Gate/CodeQL。证据目录 `build/dependency-upgrade/` 与 `build/ocr-delegate/` 按仓库规则不提交；合并结论以最终代码提交和对应远程检查为准。
