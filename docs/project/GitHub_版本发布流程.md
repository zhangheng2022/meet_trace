# 会迹（MeetTrace）GitHub Alpha 版本发布流程

> 状态：活动；仓库自动化与三个 Environment 已配置，等待 Android Secrets、Ruleset 和首次候选运行

> 上游需求：[Android + iOS Alpha PRD V1.0](../product/Alpha_PRD_无登录版.md)

## 1. 发布边界

GitHub 是源码治理、质量门禁、审批、构建来源和版本记录的控制面，不改变产品分发边界：

- Android Alpha 使用 `com.meettrace.app` 的正式签名、仅含 `arm64-v8a` 的 APK。候选先进入当前仓库不可见的 Draft Release，双平台最终验收后公开为 GitHub Pre-release 附件。
- iOS Alpha 只通过 TestFlight 分发，不把 IPA 上传到 Actions Artifact 或 GitHub Release；外部测试链接可在最终发布时填写，未就绪时明确标记待提供。
- Android 候选创建 Draft 前会预留指向候选 SHA 的 annotated tag；Android 与 iOS 任一平台未通过时 Draft 不得公开，该 tag 也不得移动或复用。
- 最终发布不重建、不覆盖 APK，不移动或复用 tag。严重问题版本保留资产和审计记录，只标记“已撤回，不建议安装”并用新版本向前修复。

## 2. 版本规则

| 标识 | 规则 | 示例 |
|---|---|---|
| PRD 版本 | 产品范围与验收标准修订号 | `V1.0` |
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
| `Android Alpha Candidate` | 人工 | 产品门禁、正式签名、审计、来源证明、当前仓库 Draft Release 暂存 | Draft 阶段无 |
| `iOS TestFlight Release` | 人工 | 产品门禁、签名、审计、来源证明、TestFlight 上传 | 无 |
| `Finalize Alpha Release` | 人工 | 校验双平台同 SHA、annotated tag 和 Draft APK，并公开原 Draft | Android arm64 APK |

行为规格位于 `spec/spec-process-cicd-*.md`；行为变化必须先更新对应规格。

## 4. GitHub 远端配置

### 4.1 `master` Ruleset

- 要求 Pull Request、线性历史并阻止 force push/deletion。
- Required checks：`Flutter quality and Android package audit`、`Build and inspect unsigned iOS app`。
- 管理员不默认绕过；紧急绕过必须在 Issue 中记录原因和补偿验证。

### 4.2 Tag Ruleset

- 目标模式：`v*`。
- 禁止更新和删除已有 tag。
- 只允许 `Android Alpha Candidate` 使用的 GitHub Actions 身份创建；最终发布流程只验证，不修改。

### 4.3 Environments

| Environment | Branch | 审批 | Secrets / Variables |
|---|---|---|---|
| `android-alpha` | 仅 `master` | Required reviewer | Android keystore 与证书摘要 |
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

无需额外分发 Token 或 Repository Variable。工作流只使用当前运行的 `GITHUB_TOKEN` 写入当前公开源码仓库；候选 Release 必须保持 draft/prerelease，只有有仓库管理权限的验收人员能在公开前下载 APK。

## 5. 候选发布步骤

1. 在 `docs/quality/alpha_release_input.json` 填入去敏设备标识、AT-01～AT-18 引用、SenseVoice 和说话人指标；未完成字段保持 `null` 时门禁会返回 `blocked`。
2. 将代码、活动文档和固定门禁证据合并到 `master`，确认 `Flutter Quality` 与 `iOS Unsigned Build` 对目标 SHA 成功。
3. 从 `master` 人工运行 `Android Alpha Candidate`，只输入 release ID 和可选说明。工作流自动锁定 dispatch 时的 `master` SHA 并读取固定门禁文件；成功后得到不可移动的 annotated tag 与不可见 Draft Release。
4. 从 `master` 人工运行 `iOS TestFlight Release`，只输入相同 release ID 和可选说明。工作流通过 Android annotated tag 自动检出完全相同的候选 SHA 和门禁文件。
   TestFlight 上传成功后，工作流会把不含 IPA 的 iOS 候选清单和门禁报告写入同一 Draft，供最终流程自动发现。
5. Android 验收人员从当前仓库 Draft Release 安装确切的 `meettrace-<release-id>-android-arm64.apk`；iOS 验收人员从 TestFlight 安装同一候选。
6. 在目标真机完成安装、初始化、30 分钟录音、最终处理、分享与清理验收；测试对象必须是候选工作流生成的确切构建号。

门禁 CLI 的退出码：`0=go`、`1=noGo`、`2=blocked`。`blocked` 和 `noGo` 都不能继续签名或最终发布。

## 6. 最终发布步骤

真机验收完成后人工运行 `Finalize Alpha Release`，输入：

- release ID；
- 可选的、已获准使用的 `https://testflight.apple.com/join/<code>` 外部测试链接；
- 可选公开说明。

候选 SHA 从既有 annotated tag 自动推导，Android 和 iOS run ID 从 Draft 中的候选指针自动解析；操作者不再复制这些技术字段。工作流仍会从 Actions 下载原始候选证据，并验证 run 类型、状态、SHA、release ID、marketing version、候选清单、两份 `go` 报告，以及 Draft 中 APK 的唯一文件名、大小和 SHA-256。全部一致后才将原 Draft 发布为 GitHub Pre-release；没有外部 TestFlight 链接时发布说明显示“待提供”。

TestFlight 外部链接获批后可以用相同输入重跑最终流程补充说明；已公开 Release 的 tag、APK、候选清单和门禁报告必须逐字节保持不变。

公开 Release 必须包含 Android 7.0+/arm64、未知来源安装、本地数据无同步、卸载删除、Alpha 升级可能全清、首次启动约下载 286.3 MB 和撤回策略提示。IPA 始终只留在 TestFlight。

## 7. 撤回与修复

- 不移动、不覆盖、不复用已创建 tag。
- TestFlight 停止测试问题构建；公开 Release、tag 和 Android APK 均保留。
- 在公开 Release 标题或说明顶部标记“已撤回，不建议安装”，不得删除或覆盖原 APK。
- 从问题版本创建 `codex/hotfix-<topic>`，经 PR 合并后使用新的 Alpha 序号和构建号重新发布。
- Alpha 数据代采用全清策略，回滚不得假定历史数据或已下载模型可继续使用。

## 8. 首次启用清单

- [x] 创建 `android-alpha` Environment，并限制为 `master` 和维护者审批。
- [ ] 配置 Android 正式签名 Secrets 与证书 SHA-256。
- [x] `testflight` Environment 已存在且只允许 `master`。
- [x] 创建 `github-release` Environment，并限制为 `master` 和维护者审批。
- [ ] 启用 `master` 与 `v*` Ruleset。
- [ ] 将新 workflow 推送后完成一次无发布副作用的 PR 检查。
- [ ] 准备首份完整 schema 4 发布证据并得到 `go`。
- [ ] 执行双平台候选和首个 `v1.0.0-alpha.1` Pre-release。
