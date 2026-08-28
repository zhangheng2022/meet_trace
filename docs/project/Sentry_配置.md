# 会迹（MeetTrace）Sentry 配置

> 状态：活动
>
> 更新日期：2026-08-28；Android/iOS 已接入，Windows Store 候选固定关闭

## 1. 产品决策

- Android/iOS Release 构建默认启用 Sentry；Windows Store 候选固定关闭；Debug/Profile 默认关闭，可用编译期参数手动启用。
- 不增加首次启动遥测同意。
- 错误事件 100% 采集；Tracing 20%、Profiling 10%、普通 Session Replay 10%、错误 Replay 100%。
- 启用默认 PII、日志、指标、截图、View Hierarchy、用户交互、HTTP Breadcrumb/失败请求、原生崩溃、ANR、App Hang、Watchdog、Tombstone、Session、Tracing、Profiling、Replay、Frame 和路由监控。
- Replay、错误截图和 View Hierarchy 保留全量文本、普通图片与 Asset 图片遮罩。
- 不把事实 PCM、WAV、转录快照或说话人结果作为 Sentry Attachment 或自定义 Event Payload 主动上传。

录音开始后，动态停止新 Tracing，因此 Profiling 同时停止；交互 Breadcrumb、错误截图和 View Hierarchy 也停止。崩溃、ANR、App Hang 和系统 Breadcrumb 始终保留。`sentry_flutter 9.26.0` 没有公开的 Replay `pause/resume` API，因此 Replay 在录音期间继续运行，但保持全量遮罩；禁止为此增加私有原生桥接。

## 2. 运行时参数

| 名称 | 默认值 | 说明 |
|---|---:|---|
| `SENTRY_ENABLED` | Android/iOS Release 为 `true`，其他模式为 `false` | 总开关；Windows Store 工作流显式设为 `false`，DSN 为空时强制关闭 |
| `SENTRY_DSN` | 当前 MeetTrace Sentry 项目的公开 DSN | 可切换项目；不是上传权限凭据 |
| `SENTRY_ENVIRONMENT` | Release 为 `production`，其他模式为 `development` | Sentry 环境名 |
| `SENTRY_RELEASE` | 空，由 SDK 自动识别 | 正式候选显式使用 `com.meettrace.app@<version>+<build>` |
| `SENTRY_DIST` | 空，由 SDK 自动识别 | 正式候选显式使用共享构建号 |
| `SENTRY_TRACES_SAMPLE_RATE` | `0.2` | 性能事务采样率，限制在 `0..1` |
| `SENTRY_PROFILES_SAMPLE_RATE` | `0.1` | Profiling 相对采样率，限制在 `0..1` |
| `SENTRY_REPLAY_SESSION_SAMPLE_RATE` | `0.1` | 普通 Session Replay 采样率 |
| `SENTRY_REPLAY_ON_ERROR_SAMPLE_RATE` | `1` | 错误 Session Replay 采样率 |

Debug 真机验证示例：

```powershell
flutter run -d <device-id> `
  --dart-define=SENTRY_ENABLED=true `
  --dart-define=SENTRY_ENVIRONMENT=development
```

如需临时关闭 Release 上报：

```powershell
flutter build apk --release --dart-define=SENTRY_ENABLED=false
```

## 3. Debug Symbols 与 Source Maps

`pubspec.yaml` 已配置 `sentry_dart_plugin`、组织 `zhangheng-bc` 和项目 `meettrace`。上传凭据只能使用以下任一方式：

1. 本地被 `.gitignore` 排除的 `sentry.properties`：

   ```properties
   auth_token=<Sentry Auth Token>
   ```

2. `android-alpha` 与 `testflight` Environment 中的 CI Secret
   `SENTRY_AUTH_TOKEN`。两处均使用同一枚最小权限 Token，禁止放到仓库级
   Secret 或 PR 工作流。

构建完成后按实际产物运行；正式发布工作流会在 Android APK 和 iOS Archive
生成后自动执行，并等待 Sentry 服务端完成处理：

```powershell
dart run sentry_dart_plugin
```

Auth Token 具备上传权限，严禁写入 `pubspec.yaml`、Dart 源码、构建参数日志或提交到 Git。

## 4. 验证

首次验证在 `development` 环境手动触发受控异常，确认：

- Sentry 收到错误、性能、日志、指标和遮罩后的 Replay/截图/View Hierarchy；
- Release/Dist 与安装包版本一致，Dart 与 Android/iOS 原生栈可符号化；
- 遮罩画面不显示会议转录、说话人标签或普通图片；
- 录音期间不产生新 Tracing/Profiling、交互 Breadcrumb、错误截图或 View Hierarchy；
- Sentry 初始化失败、离线或上传超时时，应用仍启动且事实录音连续写入。

验证完成后删除受控异常，不在启动链保留样例事件。
