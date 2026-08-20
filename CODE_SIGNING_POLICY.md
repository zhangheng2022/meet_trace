# MeetTrace Code signing policy

Free code signing provided by [SignPath.io](https://about.signpath.io/), certificate by [SignPath Foundation](https://signpath.org/).

> 状态：仅供仍在审核的未来 GitHub MSIX 路线使用，未接入当前发布工作流。Windows 当前只通过 Microsoft Store 分发；除非证书身份兼容性验证和 PRD 更新均完成，否则不得启用本政策或与 Store 包并存。

本政策适用于 MeetTrace 仓库生成并以 SignPath Foundation 名义签名的 Windows x64 MSIX。Android APK 使用独立的 Android 发布密钥，iOS 仅通过 TestFlight 分发；两者不使用 SignPath Foundation 证书。

## 团队角色

- Committers：[@zhangheng2022](https://github.com/zhangheng2022)，负责维护源码、构建脚本与依赖锁定。
- Reviewers：[@zhangheng2022](https://github.com/zhangheng2022)，负责审查外部贡献者提出的每项变更；发布工作流、依赖、原生代码和打包配置属于重点审查范围。
- Approvers：[@zhangheng2022](https://github.com/zhangheng2022)，负责逐次人工批准 SignPath 签名请求，并确认候选来自已审查的不可变提交。

所有承担上述角色的成员必须为 GitHub 和 SignPath 账户启用多因素认证。角色变更必须先更新本页，再应用到 GitHub 权限组与 SignPath 项目。

## 可签名内容

- 只签名 [zhangheng2022/meet_trace](https://github.com/zhangheng2022/meet_trace) 自有源码与构建脚本生成的正式 Windows x64 MSIX。
- 候选必须来自公开仓库中的 annotated tag、固定提交 SHA、锁定依赖和可复现的 GitHub Actions 构建；本地手工构建不得申请正式签名。
- MSIX 中允许包含应用自有二进制和未修改的开源上游运行库，但不得以本项目证书单独签名上游二进制。
- SenseVoice、Silero VAD、Pyannote 与 3D-Speaker 权重不得进入 MSIX；它们只在首次初始化时按固定 Manifest 下载并校验。
- 产品名必须为 `MeetTrace`，包内所有版本元数据必须与同一候选的共享版本和构建号一致。MSIX Identity、Publisher 和证书 Subject 必须完全匹配；Publisher 只在 SignPath 接受项目并返回正式证书身份后冻结。

## 构建、审查与批准

1. 所有代码和构建配置变更通过仓库质量门禁、目标平台构建与 OCR 审查；未解决的 Critical/High 缺陷阻断发布。
2. Android、iOS 与 Windows 候选必须来自同一提交 SHA、发布标识和构建号。Windows 候选先作为不可见候选接受包审计，不能被公开自动更新发现。
3. SignPath 每次签名均需要 Approver 人工批准。批准人核对来源提交、工作流运行、MSIX SHA-256、文件清单、许可证、产品元数据和候选清单。
4. 私钥由 SignPath HSM 保管，不导出、不写入 GitHub Secrets，也不允许用自签名包、未签名包或个人 PFX 进行公开分发。
5. 三平台候选通过构建、自动化和分发门禁并由 `github-release` Environment 人工批准后，才公开原 Draft 为 GitHub Pre-release，并原子更新公开更新指针。

提交 SignPath 的 Windows 候选必须使用 `SENTRY_ENABLED=false` 构建，因此该签名产物不启动 Sentry 远程诊断。模型下载、分享、TestFlight、Microsoft Store 及未来自动更新的网络边界见[隐私政策](PRIVACY.md)。

## 验证、撤回与密钥事件

- 发布前使用 Windows 签名验证工具检查完整信任链、SHA-256 摘要、可信时间戳、Publisher 和包身份，并记录 MSIX SHA-256。
- 发现来源不明、签名滥用、恶意代码、供应链污染或私钥事件时，立即停止签名与公开更新，保留原资产和标签，在发布说明标记撤回，并通知 SignPath 调查或吊销。
- 已公开资产不得覆盖，tag 不得移动；修复必须使用更高版本重新走完整构建、签名和批准流程。
- MSIX 通过 Windows 设置或开始菜单的标准卸载入口移除；卸载会删除应用私有目录中的本地会议、模型与设置。安装、升级和卸载证据按[发布流程](docs/project/GitHub_版本发布流程.md)留存。

公开版本与下载入口位于 [GitHub Releases](https://github.com/zhangheng2022/meet_trace/releases)。
