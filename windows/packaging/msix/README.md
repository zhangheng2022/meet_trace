# Windows x64 MSIX 打包

正式路线只有 Microsoft Store；候选不得上传 GitHub Release、自签名或引导旁加载。模型权重、会议数据、凭据和私钥不得进入 MSIX。

## 固定身份

| 字段 | 值 |
| --- | --- |
| Identity Name | `zhangheng2026.MeetTrace` |
| Publisher | `CN=E5BC0A60-65F7-46C4-9A30-653FFCF9619B` |
| PublisherDisplayName | `zhangheng2026` |
| PFN | `zhangheng2026.MeetTrace_vaaj3dqegb9y0` |
| Store ID | `9PHHSJMWK06G` |

这些值以 `store_identity.json` 为工程事实。Store 传输版本固定为 `1.0.<共享构建号>.0`，共享构建号不得超过 `65535`；营销版本来自 `pubspec.yaml`。

正式候选由 `Alpha Release` 构建、审计并上传 Actions Artifact；Reconciler 核对摘要后，将同一 MSIX 依次提交固定 Flight 和 100% non-flighted production。两阶段必须取得精确包身份与 `Published`、`Published/Public` 回执。该门禁不证明 Store 客户端生命周期。

本地只运行不可分发探针，因此可显式关闭 Sentry；正式 Store 候选必须按 PRD 使用生产 Sentry 配置和统一 `release/dist`：

```powershell
flutter build windows --release --dart-define SENTRY_ENABLED=false
pwsh tool/windows/package_msix.ps1 -Publisher 'CN=MeetTrace Development' -DevelopmentProbe -PackageVersion 1.0.0.0 -OutputPath build/windows/msix/meettrace-probe.msix
pwsh tool/benchmarks/inspect_msix.ps1 -MsixPath build/windows/msix/meettrace-probe.msix -ExpectedPublisher 'CN=MeetTrace Development' -ExpectedVersion 1.0.0.0
```

SignPath 仅是待审核替代路线；启用前必须验证包身份与数据连续性、更新 PRD 并停止 Store 路线，两个 Windows 包身份不得并存。
