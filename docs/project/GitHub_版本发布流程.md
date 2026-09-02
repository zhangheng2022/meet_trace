# 会迹（MeetTrace）Alpha 发布运行手册

> 适用于 Android arm64 APK、iOS TestFlight 和 Windows x64 Microsoft Store 的统一候选。机器合同见 [Alpha Release 规格](../../spec/spec-process-cicd-alpha-release.md)。

## 正常发布

在 Actions 手动运行一次 `Alpha Release`：

- 必填 `release_id`，例如 `v1.0.0-alpha.13`。
- 候选提交的 `CHANGELOG.md` 必须包含与 `release_id` 匹配的已定版区段；发布链自动同步到 GitHub Release 与 TestFlight。
- `release_notes` 仅用于紧急补充，正常发布留空。
- 不填写内部的 `resume_run_id`、`orchestration_run_id`，也不选择修复或撤回模式。

其余步骤自动完成：

1. 从 `master` 固定同一 SHA、tag 和共享构建号，创建 Draft。
2. 构建并审计 Android 签名 arm64 APK、iOS TestFlight 候选和 Windows Store x64 MSIX。
3. Android 原包在 Firebase ARM 验证一次；iOS 进入固定外测组并提交 Beta App Review；Windows 包只进入 Actions Artifact。
4. Reconciler 立即运行，之后每小时第 7、22、37、52 分钟查询商店状态，依次推进固定 Flight 与 100% production。
5. TestFlight 为 `Testing`、Flight 为 `Published`、production 为 `Published/Public` 且身份完全匹配后，生成 schema 3 门禁。
6. 自动公开原 Draft，重新下载 Android APK 核对 SHA-256，再原子更新签名指针。

等待商店处理时不要重跑。正常路径没有逐版本人工审批，也不要求 Windows 专用机；Store API 回执不证明客户端安装、启动、更新或卸载。

`CHANGELOG.md` 规则从 `v1.0.0-alpha.13` 起生效；此前已创建的活动 Draft 只允许由 Reconciler 以 `resume` 模式完成，不得据此创建缺少日志的新候选。

## 一次性 bootstrap

先创建 `microsoft-store` Environment，并逐项录入现有 Partner Center Secret：

```powershell
gh api 'repos/<owner>/<repo>/environments/microsoft-store' --method PUT `
  -F 'deployment_branch_policy[protected_branches]=true' `
  -F 'deployment_branch_policy[custom_branch_policies]=false'
gh secret set PARTNER_CENTER_TENANT_ID --repo '<owner>/<repo>' --env microsoft-store
gh secret set PARTNER_CENTER_SELLER_ID --repo '<owner>/<repo>' --env microsoft-store
gh secret set PARTNER_CENTER_CLIENT_ID --repo '<owner>/<repo>' --env microsoft-store
gh secret set PARTNER_CENTER_CLIENT_SECRET --repo '<owner>/<repo>' --env microsoft-store
```

再 dry-run，确认输出后追加 `-Apply`：

```powershell
./tool/release/bootstrap_release_automation.ps1 `
  -TestFlightExternalGroup '<固定外测组名>' `
  -TestFlightPublicLink 'https://testflight.apple.com/join/<固定代码>' `
  -PartnerCenterFlightId '<固定 Package Flight ID>'
```

脚本只校验和设置配置，不读取或复制 Secret。Partner Center 的产品、listing、年龄分级、定价、固定 Flight 和自动发布，以及 TestFlight 固定外测组、公测链接与 App Manager API Key，仍需预先完成一次。

| Environment | 内容 |
| --- | --- |
| `android-alpha` | Android 签名、Firebase、Sentry |
| `testflight` | App Store Connect、iOS 签名、固定 group/link、Sentry |
| `windows-alpha` | 只构建 Store 候选；含最小权限 Sentry 符号上传 Token，无 Store 发布 Secret |
| `microsoft-store` | Partner Center 凭据与固定 Flight ID |
| `github-release` | 更新指针私钥及最终重验所需固定值；无 reviewer |
| Repository Variables | Firebase OIDC 配置 |

## 阻断与恢复

Reconciler 对正常 processing/review/certification/publishing 状态只等待；拒审、未知状态、查询失败或候选身份不一致会维护 `release-blocked` Issue，并保持 Draft、tag 和旧指针不变。外部状态恢复后自动关闭 Issue 并复用原候选。

- 构建失败：修复后以同一 Draft `release_id` 重跑；只复用身份匹配的成功产物和 Android 回执。
- 外部审核等待：不操作。
- 外部拒审：修复商店元数据；若二进制或代码改变，使用新 release ID 和更高构建号。
- 最终公开失败：等待协调器用原门禁恢复。
- 已公开但指针失败：同一 `release_id` 选择 `repair_update_pointer`。
- 严重问题撤回：同一 `release_id` 选择 `withdraw_update`；保留 Release、tag、APK 和 Store submission，新版本向前修复。

不得手工公开 Draft、移动 tag、覆盖资产、重复提交已批准候选或手工前移更新指针。

## 发布前检查

- [ ] `CHANGELOG.md` 的 `Unreleased` 内容已移入 `## [<release-id 去掉 v>] - YYYY-MM-DD`，并重新保留空的 `Unreleased` 区段。
- [ ] 自动化变更已合并到 `master`，bootstrap 已完成。
- [ ] required checks 正常，发布 Environment 无 reviewer 或 wait timer。
- [ ] TestFlight 固定组、公测链接、审核联系与出口合规已配置。
- [ ] Partner Center 固定 Flight、自动认证后发布和 100% production 已配置。
- [ ] Firebase OIDC 与 ARM 设备可用。
- [ ] 三平台 Sentry 生产配置、统一 `release/dist`、最小权限 Token 与符号化验证已配置。
- [ ] 本次只填写新的 `release_id`；仅在无法通过候选提交表达时填写紧急补充说明。
