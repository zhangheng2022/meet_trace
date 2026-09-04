# 会迹（MeetTrace）质量与验收

> 上游：[Alpha PRD V1.5](../product/Alpha_PRD_无登录版.md)。Windows 在 AT-21～AT-26 和首次 schema 3 生产门禁闭环前保持“规划中/未就绪”。

本文只记录当前门禁和缺口；历史运行、测试数量、包体积与阶段报告由 Git、Actions 和商店追溯。

## 自动化门禁

| 范围 | 入口 | 合同 |
| --- | --- | --- |
| 常规 CI | `.github/workflows/quality.yml` | Actions 静态检查、按路径运行平台检查，并始终汇总 `CI Gate` |
| Flutter 核心 | `.github/workflows/_flutter-core.yml` | 格式、分析、测试及可选 Android Debug 包审计 |
| 正式候选 | `.github/workflows/alpha-release.yml` | 同一 SHA 构建三平台；Android 签名 arm64 APK 原包验证一次 |
| 候选协调 | `.github/workflows/alpha-release-reconcile.yml` | TestFlight、Store Flight/production 状态与精确包回执；生成 schema 3 门禁 |
| 安全 | `.github/workflows/codeql.yml` | CodeQL 分析并汇总 `CodeQL Gate` |

任一必需门禁失败均不得发布。性能、准确率、内存、能耗、温控和设备实验室结果是非阻断观测，不是候选证据。

## 平台结论

| 平台 | 构建与分发门禁 |
| --- | --- |
| Android | API 24+；正式签名的三个 ABI split 与 universal APK；Draft 与公开四包摘要一致 |
| iOS | iOS 15+；只经固定 TestFlight 外测组，GitHub 不上传 IPA |
| Windows | Windows 10 22H2/11 x64；固定 Store 身份；Flight `Published` 与 production `Published/Public` 精确回执；GitHub 不上传 MSIX |

三平台必须共享候选 SHA、发布标识和构建号。Windows 的静态审计与 Store API 回执不证明客户端安装、启动、更新或卸载。

## 运行时资源

资源总量、URL、哈希和安装文件集以 `assets/models/*.json` 为准。硬门槛是十进制 300 MB 下载上限和 1 GiB 初始化可用空间；权重不得进入 APK、IPA 或 MSIX，许可与 NOTICE 必须进入安装包。准备、校验与降级合同见[技术方案](../technical/端侧_SenseVoice_转录技术方案.md)。

## 本地验证

```text
dart format lib test
flutter analyze
flutter test
```

代码变更再按 [AGENTS](../../AGENTS.md) 增加受影响测试、目标平台构建和 OCR；发布操作见[发布 Runbook](../project/GitHub_版本发布流程.md)，Sentry 见[配置说明](../project/Sentry_配置.md)。
