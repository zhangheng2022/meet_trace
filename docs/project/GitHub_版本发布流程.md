# 会迹（MeetTrace）GitHub Alpha 版本发布流程

> 状态：活动；仓库自动化与三个 Environment 已配置，等待 Android Secrets、私有分发仓库、Ruleset 和首次候选运行

> 上游需求：[Android + iOS Alpha PRD V0.9](../product/Alpha_PRD_无登录版.md)

## 1. 发布边界

GitHub 是源码治理、质量门禁、审批、构建来源和版本记录的控制面，不改变产品分发边界：

- Android Alpha 使用 `com.meettrace.app` 的正式签名 APK，仅向受控内部测试者分发。
- iOS Alpha 只通过 TestFlight 内部测试分发。
- 公开源码仓库的 Actions Artifact 和 GitHub Release 不保存签名 APK 或 IPA。
- GitHub Pre-release 只公开候选清单、门禁报告、摘要和运行链接。
- Android 与 iOS 必须基于同一 `master` commit；任一平台未通过时不得创建版本 tag。

## 2. 版本规则

| 标识 | 规则 | 示例 |
|---|---|---|
| PRD 版本 | 产品范围与验收标准修订号 | `V0.9` |
| App marketing version | `pubspec.yaml` 中不含 build number 的版本 | `1.0.0` |
| Alpha release ID/tag | `v<marketing-version>-alpha.<正整数>` | `v1.0.0-alpha.1` |
| Android versionCode | `workflow run number * 100 + attempt` | `401` |
| iOS CFBundleVersion | `workflow run number * 100 + attempt` | `501` |

tag、Android versionCode 和 iOS build number 均不得复用或回退。PRD 版本与 App marketing version 是不同维度，不自动相互改写。

## 3. 自动化入口

| Workflow | 触发 | 作用 | 公开二进制 |
|---|---|---|---|
| `Flutter Quality` | PR、`master` push、人工 | 格式、分析、测试、Debug APK 构建与内容审计 | 无 |
| `iOS Unsigned Build` | PR、`master` push、人工 | Debug/Release 无签名编译、App bundle 审计 | 仅不可安装 unsigned IPA，保留 7 天 |
| `Android Alpha Candidate` | 人工 | 产品门禁、正式签名、审计、来源证明、私有 Draft Release | 无 |
| `iOS TestFlight Release` | 人工 | 产品门禁、签名、审计、来源证明、TestFlight 上传 | 无 |
| `Finalize Alpha Release` | 人工 | 校验双平台同 SHA，创建 annotated tag 与 Pre-release | 无 |

行为规格位于 `spec/spec-process-cicd-*.md`；行为变化必须先更新对应规格。

## 4. GitHub 远端配置

### 4.1 `master` Ruleset

- 要求 Pull Request、线性历史并阻止 force push/deletion。
- Required checks：`Flutter quality and Android package audit`、`Build and inspect unsigned iOS app`。
- 管理员不默认绕过；紧急绕过必须在 Issue 中记录原因和补偿验证。

### 4.2 Tag Ruleset

- 目标模式：`v*`。
- 禁止更新和删除已有 tag。
- 只允许 `Finalize Alpha Release` 使用的 GitHub Actions 身份创建。

### 4.3 Environments

| Environment | Branch | 审批 | Secrets / Variables |
|---|---|---|---|
| `android-alpha` | 仅 `master` | Required reviewer | Android keystore、证书摘要、私有分发 token/repo |
| `testflight` | 仅 `master` | Required reviewer | Apple distribution、profile、Team 和 API Key |
| `github-release` | 仅 `master` | Required reviewer | 只使用最小权限 `GITHUB_TOKEN` |

有第二名维护者后启用 prevent self review。单维护者阶段保留人工 Environment 审批和完整运行审计，不把同一审批伪装成双人复核。

### 4.4 Android Environment 配置

Secrets：

- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`
- `ANDROID_SIGNING_CERT_SHA256`
- `ANDROID_DISTRIBUTION_TOKEN`

Variable：

- `ANDROID_DISTRIBUTION_REPOSITORY`：格式为 `owner/repo`，目标仓库必须为 private。

分发 token 使用 fine-grained 权限，只授予目标私有仓库 `contents: write`。私有分发仓库的 Release 必须保持 draft/prerelease；测试者通过仓库访问控制获取 APK。

## 5. 候选发布步骤

1. 在功能 PR 中更新代码、活动文档和去敏发布证据，合并到 `master`。
2. 确认 `Flutter Quality` 与 `iOS Unsigned Build` 对目标 SHA 成功。
3. 复制 `tool/benchmarks/alpha_release_input.example.json` 形成受版本控制的候选输入；填入去敏设备标识、AT-01～AT-18 引用、SenseVoice 和说话人指标。
4. 人工运行 `Android Alpha Candidate`，输入 release ID、完整 SHA、门禁输入路径和说明。
5. 人工运行 `iOS TestFlight Release`，使用完全相同的 release ID、SHA 和门禁输入路径。
6. Android 测试者从私有 Draft Release 安装；iOS 测试者从 TestFlight 安装。
7. 在目标真机完成安装、初始化、30 分钟录音、最终处理、分享与清理验收；测试对象必须是候选工作流生成的确切构建号。

门禁 CLI 的退出码：`0=go`、`1=noGo`、`2=blocked`。`blocked` 和 `noGo` 都不能继续签名或最终发布。

## 6. 最终发布步骤

真机验收完成后人工运行 `Finalize Alpha Release`，输入：

- release ID；
- 候选完整 SHA；
- 成功的 Android run ID；
- 成功的 iOS run ID；
- 可选公开说明。

工作流会验证 run 类型、状态、SHA、release ID、marketing version、候选清单与两份 `go` 报告。全部一致后才创建 annotated tag 和 GitHub Pre-release。

## 7. 撤回与修复

- 不移动、不覆盖、不复用已创建 tag。
- TestFlight 停止测试问题构建；Android 从私有分发仓库撤下对应 Draft asset。
- 公开 Release 保留审计记录并标记为已撤回。
- 从问题版本创建 `codex/hotfix-<topic>`，经 PR 合并后使用新的 Alpha 序号和构建号重新发布。
- Alpha 数据代采用全清策略，回滚不得假定历史数据或已下载模型可继续使用。

## 8. 首次启用清单

- [x] 创建 `android-alpha` Environment，并限制为 `master` 和维护者审批。
- [ ] 创建私有 Android 分发仓库并授权内部测试者。
- [ ] 配置 Android 正式签名 Secrets、证书 SHA-256 和分发变量。
- [x] `testflight` Environment 已存在且只允许 `master`。
- [x] 创建 `github-release` Environment，并限制为 `master` 和维护者审批。
- [ ] 启用 `master` 与 `v*` Ruleset。
- [ ] 将新 workflow 推送后完成一次无发布副作用的 PR 检查。
- [ ] 准备首份完整 schema 4 发布证据并得到 `go`。
- [ ] 执行双平台候选和首个 `v1.0.0-alpha.1` Pre-release。
