# 会迹（MeetTrace）Sentry 配置

> 目标合同以 [Alpha PRD](../product/Alpha_PRD_无登录版.md) FR-004 与 AT-19 为准。Android、iOS、Windows 可分发 Release 默认启用；Debug/Profile 默认关闭。

## 运行边界

- 三平台共用一个 Sentry 项目。候选显式设置 `release=com.meettrace.app@<version>+<共享构建号>`、`dist=<共享构建号>` 和 `environment=production`。
- 错误事件、Flutter `silent` 错误与后台 Isolate 未处理异常采集率为 100%；启用匿名 Release Health，不设置用户、安装、设备或会议持久标识。
- 性能会话按进程抽样一次，生产抽样率为 20%；应用保存本进程结果，公开 `tracesSampler` 只返回 `1.0` 或 `0.0`。覆盖启动、命名路由、模型下载/初始化、录音开始/安全封存、最终 ASR 和说话人分离。
- 被抽样的录音会话每 60 秒生成一次匿名窗口：PCM 写入延迟、写入积压、预览积压/丢弃、录音中断/恢复次数和窗口时长。应用交给 SDK 后不等待上传。
- Android/iOS 使用 SDK 原生离线缓存并设置 `maxCacheItems=10`；Windows 的 Dart 错误、Span 和 Metrics 在线发送、失败即丢，Crashpad 只持久化原生崩溃。不增加自定义传输层。初始化、缓存或上传失败不得阻断 App、事实录音或最终处理。
- Android 采集原生崩溃、ANR、Android 12+ Tombstone 和卡帧；iOS 采集原生崩溃、App Hang、Watchdog 和卡帧；Windows x64 使用 Crashpad 原生崩溃/minidump。三平台启动阶段统一使用 Dart Span；为先读取退出开关，不承诺需要在 Flutter Binding 前初始化的自动原生 App Start。
- Production 禁用 Profiling；仅 iOS 受控 `development` 诊断构建可显式启用。所有平台禁用 Replay、结构化日志、业务分析指标、截图、View Hierarchy、用户交互追踪、用户反馈和附件。

## 告知与开关

- 首次安装在 Sentry 最早初始化的同一首屏展示一次可关闭的非阻断告知；设置页开关默认开启并仅保存在本机。
- 后续启动先读取开关。关闭或读取异常时本次进程不初始化，读取异常不得覆盖已有退出选择或阻断本地启动；运行中关闭立即停止应用侧新事件、Tracing、Metrics 和当前窗口，且不回填。
- 已交给 SDK、进入原生缓存或上传的数据不能保证撤回。Windows 原生 Crashpad 最迟在下次启动时完全关闭；文案必须披露该边界。
- 重新开启后立即恢复错误监控，并从下一个 60 秒边界重新抽样性能会话。

## Tracing、Metrics 与 Breadcrumb

| 项目 | 合同 |
| --- | --- |
| 错误采样 | `1.0` |
| 性能会话采样 | 应用侧 `0.2` 决定一次；`tracesSampler` 在该进程返回 `1.0` 或 `0.0` |
| Profiling | Production `0`；仅 iOS 受控诊断构建可开启 |
| Replay / Logs | `0` / 关闭 |
| 路由 | 会议列表、录音、会议详情、设置均命名并采集 TTID |
| TTFD | 会议列表就绪、录音就绪、会议详情加载完成 |
| 用户交互 | Tracing 与 Breadcrumb 均关闭 |
| Breadcrumb | 最多 100 条；生命周期、网络、内存、静态路由、资源、录音及最终处理阶段 |
| Metrics | 仅录音性能窗口，不采集业务指标 |
| Client Reports | 开启，仅含丢弃类型、原因与数量 |
| 依赖清单 | `reportPackages=false` |

## HTTP 自动采集

- 应用全部 Dart HTTP 客户端统一使用官方 `SentryHttpClient` 自动采集请求与失败；关闭原生全局失败请求采集。
- 只保留域名、方法、状态码和耗时。发送前通过公开 Hook 删除完整路径、查询参数、请求头、请求体、响应体和下载文件名。
- `maxRequestBodySize=never`；`tracePropagationTargets` 为空，不发送 `sentry-trace`、`baggage` 或 `traceparent`。
- 网络 Breadcrumb 使用同一脱敏规则；网络请求失败不得影响模型下载、更新检查或录音。

## 隐私配置

- `sendDefaultPii=false`，不设置 `SentryUser`，不附加 PCM、WAV、转录、说话人结果、截图、View Hierarchy、日志或诊断文件。
- 只允许 App 版本/构建、平台、OS 版本、设备型号、CPU 架构、内存压力、前后台状态和 locale code。源码包内路径、函数名和行号可用于符号化。
- 禁止设备名、广告/安装 ID、运营商、精确时区、IP 推断位置、会议/文件标识、运行时数据路径和内容。
- Sentry 项目关闭 IP 存储与地理推断，启用敏感字段清洗，保留期使用账户支持的最短值且不超过 30 天。

## 构建参数

| 名称 | 候选值 |
| --- | --- |
| `SENTRY_ENABLED` | Android/iOS/Windows Release 为 `true` |
| `SENTRY_DSN` | 单一 Sentry 项目的公开 DSN；缺失时阻断候选 |
| `SENTRY_ENVIRONMENT` | `production` |
| `SENTRY_RELEASE` | `com.meettrace.app@<version>+<共享构建号>` |
| `SENTRY_DIST` | 共享构建号 |
| `SENTRY_PERFORMANCE_SESSION_SAMPLE_RATE` | `0.2`，应用侧进程级一次抽样 |
| `SENTRY_PROFILES_SAMPLE_RATE` | `0` |

不可分发的本地受控验证使用 `development`，不得复用生产 `release/dist`：

```powershell
flutter run -d '<device-id>' `
  --dart-define=SENTRY_ENABLED=true `
  --dart-define=SENTRY_ENVIRONMENT=development
```

## 符号、服务端与告警

- `SENTRY_AUTH_TOKEN` 只存在于被忽略的本地配置或 `android-alpha`、`testflight`、`windows-alpha` Environment，不得进入仓库、构建参数、应用包或日志。
- 三平台候选上传 Dart `split-debug-info`、混淆映射及所需 Android 原生符号、iOS dSYM、Windows PDB/minidump 符号；禁止上传完整源码和 Web source maps。
- 任一平台生产配置缺失、符号上传失败、测试事件无法符号化或最终入库字段越界，均阻断统一发布，不允许公开后补传符号。
- 新出现或回归的 Fatal、原生崩溃、ANR、App Hang/Watchdog 按 Issue 聚合通知维护者；性能只进入 Dashboard。

```powershell
dart run sentry_dart_plugin
```

## AT-19 验证

1. 验证三平台候选默认开启、Debug/Profile 默认关闭，以及缺失生产配置会阻断。
2. 分别注入 Dart 未处理异常和平台支持的原生故障，核对统一 `release/dist` 与符号栈。
3. 验证 20% 进程级一次抽样、主流程 Span、录音 60 秒窗口、`SentryHttpClient` HTTP 脱敏和最多 100 条 Breadcrumb。
4. 验证首次告知、默认开启开关、运行中关闭/重开、不回填及 Windows 下次启动完全关闭。
5. 审计 Android/iOS 最多 10 个离线 Envelope、Windows 在线失败即丢与 Crashpad 补传、最终入库字段、IP/PII 清洗、保留期和故障不影响录音。受控验证完成后删除人工测试 Issue。
