# Windows x64 MSIX 打包

本目录只描述 MeetTrace Windows x64 的 MSIX 包身份和视觉资产。模型权重、录音、转录、凭据与可导出签名私钥不得进入本目录或 MSIX。

## 正式候选

正式候选必须先获得 SignPath 返回的完整证书 Subject，并把它逐字作为 `Publisher` 注入。不得猜测、缩写、重排或提交该值；MSIX manifest 的 `Publisher` 必须与签名证书 Subject 完全一致。

```powershell
flutter build windows --release `
  --build-name 1.0.0 `
  --build-number 2 `
  --dart-define SENTRY_ENABLED=false

pwsh tool/windows/package_msix.ps1 `
  -Publisher '<SignPath certificate Subject>' `
  -PackageVersion '1.0.0.2' `
  -OutputPath 'build/windows/msix/meettrace-v1.0.0-alpha.3-windows-x64.msix'

pwsh tool/benchmarks/inspect_msix.ps1 `
  -MsixPath 'build/windows/msix/meettrace-v1.0.0-alpha.3-windows-x64.msix' `
  -ExpectedPublisher '<SignPath certificate Subject>' `
  -ExpectedVersion '1.0.0.2' `
  -RequireSignature
```

`package_msix.ps1` 只创建未签名 MSIX；正式候选必须由可验证 CI 提交 SignPath，并由 SignPath HSM 签名。`-RequireSignature` 会验证 Authenticode 状态为 `Valid`，并要求签名证书 Subject 与 manifest Publisher 完全一致。仓库、GitHub Secrets 和开发设备都不得保存 PFX 或私钥。

## CI 开发探针

SignPath 尚未返回正式 Subject 时，只允许使用显式 `-DevelopmentProbe` 生成不可安装、不可公开的 CI 探针。探针只用于验证 manifest、文件清单和审计规则；不得上传 GitHub Release、不得生成自签名证书、不得引导用户绕过 Windows 安全警告。
