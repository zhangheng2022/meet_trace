# Windows x64 MSIX 打包

本目录描述 MeetTrace Windows x64 的 MSIX 包身份和视觉资产。模型权重、录音、转录、凭据与可导出签名私钥不得进入本目录或 MSIX。

## 当前正式路线：Microsoft Store

Partner Center 身份固定在 `store_identity.json`：

- `Identity Name`：`zhangheng2026.MeetTrace`
- `Publisher`：`CN=E5BC0A60-65F7-46C4-9A30-653FFCF9619B`
- `PublisherDisplayName`：`zhangheng2026`
- `PFN`：`zhangheng2026.MeetTrace_vaaj3dqegb9y0`
- `Store ID`：`9PHHSJMWK06G`

Store 包版本是独立的传输版本，固定映射为 `1.0.<共享发布构建号>.0`，共享构建号不得超过 `65535`。应用营销版本仍取 `pubspec.yaml` 并在三平台候选清单中保持一致。这样既保留同一发布的共享构建号，又满足 Microsoft Store 对第一段大于 `0`、第四段保留为 `0` 的要求。

这些值必须逐字匹配 Partner Center，不得猜测、缩写或重排。正式工作流使用：

```powershell
flutter build windows --release `
  --build-name 1.0.0 `
  --build-number 2 `
  --dart-define SENTRY_ENABLED=false

pwsh tool/windows/package_msix.ps1 `
  -MicrosoftStore `
  -PackageVersion '1.0.2.0' `
  -OutputPath 'build/windows/msix/meettrace-v1.0.0-alpha.3-windows-store-x64.msix'

pwsh tool/benchmarks/inspect_msix.ps1 `
  -MsixPath 'build/windows/msix/meettrace-v1.0.0-alpha.3-windows-store-x64.msix' `
  -ExpectedIdentityName 'zhangheng2026.MeetTrace' `
  -ExpectedPublisher 'CN=E5BC0A60-65F7-46C4-9A30-653FFCF9619B' `
  -ExpectedPublisherDisplayName 'zhangheng2026' `
  -ExpectedVersion '1.0.2.0'
```

Store 候选由 `Alpha Release` 创建并上传 Actions Artifact。`Alpha Release Reconciler` 核对候选清单和 SHA-256 后，把同一字节提交到固定 Package Flight；Flight 认证、真实安装验证通过后，再提交 100% production。候选不得上传 GitHub Release、自签名或引导用户旁加载。正式用户安装和更新只使用 Store 产品 `9PHHSJMWK06G`。

## 专用机 Store 生命周期验证

`Alpha Release Reconciler` 在 Flight `Published` 和 production `Published/Public` 后，分别在带 `Windows`、`X64`、`meettrace-store` 标签的仓库级自托管运行器执行 `tool/windows/validate_store_distribution.ps1`。运行器必须是隔离的 Windows 10 22H2/11 x64 交互式账号，已安装 GitHub CLI、WinGet，且 `winget source list` 能看到 `msstore`。`windows-store-validation` Environment 只允许 `master`，不配置 required reviewer，也不保存 Partner Center、签名或 Store Secret。

- `InstallUninstall` 要求当前运行器账号没有安装 MeetTrace；脚本从 `msstore` 安装公开版本、逐字段核对 Name/Publisher/PFN/Version/x64、连续启动两次验证单实例，然后卸载当前用户包。
- `Update` 是脚本保留的非发布诊断模式：要求当前运行器账号已预装输入的确切旧版 Store 包，只允许目标版本高于旧版，再经 `winget upgrade --source msstore` 检查更新。当前统一发布门禁不调用此模式。
- 脚本同时要求 `MEETTRACE_DEDICATED_STORE_VALIDATION=1`、`repository_dispatch` 和 `master`。任一条件不满足时在首次包变更前失败；禁止 `-AllUsers`，也不删除不符合预期的既有安装。

普通 GitHub 托管 Windows Server、旁加载 Actions Artifact 或开发探针都不能替代真实 Store 生命周期结果。Flight 与 production 两次独立 `InstallUninstall` 均成功前，Windows 继续标记为“规划中/未就绪”。

## CI 开发探针

常规 CI 使用显式 `-DevelopmentProbe` 生成不可安装、不可公开的结构探针。探针只验证 manifest、文件清单和审计规则，上传证据前删除包体。

## 未来 SignPath 路线

SignPath 申请材料仍保留，但当前工作流不调用 SignPath。只有证书 Subject 与 Store 包身份兼容性、升级和本地数据连续性验证完成，PRD 更新并明确停止 Store 路线后，才可考虑 GitHub MSIX；两个 Windows 包身份不得并存。
