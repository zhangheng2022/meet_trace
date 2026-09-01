# MeetTrace Code signing policy

Free code signing provided by [SignPath.io](https://about.signpath.io/), certificate by [SignPath Foundation](https://signpath.org/).

> 状态：SignPath 申请材料，未接入当前发布工作流。Windows 当前只由 Microsoft Store 分发；包身份兼容性验证和 PRD 更新完成前，不得启用本政策或与 Store 包并存。

本政策仅适用于 [zhangheng2022/meet_trace](https://github.com/zhangheng2022/meet_trace) 未来可能生成的 Windows x64 MSIX。Android 使用独立发布密钥，iOS 只经 TestFlight 分发。

## 角色与范围

- Committer、Reviewer、Approver：[@zhangheng2022](https://github.com/zhangheng2022)；相关 GitHub 与 SignPath 账户必须启用多因素认证。
- 只签名公开仓库固定提交、锁定依赖和 GitHub Actions 生成的正式 MSIX；本地构建不得申请正式签名。
- 包可包含项目二进制和未修改的开源运行库，但不得用本项目证书单独签名上游二进制。
- 模型权重、录音、转录、凭据和私钥不得进入 MSIX；产品名、版本、Identity、Publisher 与证书 Subject 必须一致。

## 审查与签名

1. 候选先通过 CI、包审计和代码审查，并与 Android/iOS 使用同一 SHA、版本和构建号。
2. Approver 逐次核对提交、工作流、MSIX SHA-256、文件清单、许可、元数据和候选清单。
3. 私钥由 SignPath HSM 保管，不导出或写入 GitHub Secrets；不允许用自签名包、未签名包或个人 PFX 进行公开分发。
4. 候选与当前三平台合同一致使用 `SENTRY_ENABLED=true`、统一 `release/dist` 并在公开前完成符号上传；Sentry Token 不得进入 MSIX。网络和数据边界见[隐私政策](PRIVACY.md)。

发现来源不明、签名滥用、供应链污染或密钥事件时立即停止签名与更新，保留原资产和标签并通知 SignPath。撤回不覆盖资产；修复使用更高版本重新完成门禁。
