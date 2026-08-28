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

这些值必须逐字匹配 Partner Center，不得猜测、缩写或重排。以下以首个统一构建号 `2001` 为例；正式工作流从发布标识和候选清单注入这些值：

```powershell
$env:MARKETING_VERSION = '1.0.0'
$env:RELEASE_BUILD_NUMBER = '2001'
$env:MEETTRACE_MSIX_VERSION = "1.0.$($env:RELEASE_BUILD_NUMBER).0"
$env:WINDOWS_MSIX_PATH = 'build/windows/msix/meettrace-v1.0.0-alpha.6-windows-store-x64.msix'

flutter build windows --release `
  --build-name $env:MARKETING_VERSION `
  --build-number $env:RELEASE_BUILD_NUMBER `
  --dart-define SENTRY_ENABLED=false

pwsh tool/windows/package_msix.ps1 `
  -MicrosoftStore `
  -PackageVersion $env:MEETTRACE_MSIX_VERSION `
  -OutputPath $env:WINDOWS_MSIX_PATH

pwsh tool/benchmarks/inspect_msix.ps1 `
  -MsixPath $env:WINDOWS_MSIX_PATH `
  -ExpectedIdentityName 'zhangheng2026.MeetTrace' `
  -ExpectedPublisher 'CN=E5BC0A60-65F7-46C4-9A30-653FFCF9619B' `
  -ExpectedPublisherDisplayName 'zhangheng2026' `
  -ExpectedVersion $env:MEETTRACE_MSIX_VERSION
```

Store 候选由 `Alpha Release` 创建并上传 Actions Artifact。`Alpha Release Reconciler` 核对候选清单和 SHA-256 后，把同一字节提交到固定 Package Flight；Flight 达到 `Published` 且精确包身份匹配后，再提交 100% non-flighted production。候选不得上传 GitHub Release、自签名或引导用户旁加载。正式用户安装和更新只使用 Store 产品 `9PHHSJMWK06G`。

## Store 发布门禁

Reconciler 通过 Partner Center API 取得脱敏 Flight 与 production 回执。两份回执都绑定 release ID、candidate SHA、source run、product ID、submission ID、文件名、`1.0.<build>.0`、x64 和上传状态；Flight 还绑定固定 Flight ID，production 还必须为 `Published/Public`。提交 production 前重新下载来源运行的不可变 MSIX 并核对 SHA-256，只以 100% non-flighted 方式提交该文件。

此门禁不依赖专用机或自托管 runner。GitHub 托管 Windows Server 的静态包审计、Store 认证与 API 状态不能证明 Store 客户端安装、启动、更新或卸载，因此发布说明和验收结论不得声称已验证这些行为。Windows 在 schema 3 统一门禁首次成功运行前继续标记为“规划中/未就绪”。

## CI 开发探针

常规 CI 使用显式 `-DevelopmentProbe` 生成不可安装、不可公开的结构探针。探针只验证 manifest、文件清单和审计规则，上传证据前删除包体。

## 未来 SignPath 路线

SignPath 申请材料仍保留，但当前工作流不调用 SignPath。只有证书 Subject 与 Store 包身份兼容性、升级和本地数据连续性验证完成，PRD 更新并明确停止 Store 路线后，才可考虑 GitHub MSIX；两个 Windows 包身份不得并存。
