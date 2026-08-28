# 会迹（MeetTrace）Sentry 配置

> Android/iOS Release 默认启用；Windows Store、Debug 和 Profile 默认关闭。

## 运行边界

- 错误事件 100%；Tracing 20%；Profiling 10%；普通 Replay 10%；错误 Replay 100%。
- 启用默认 PII、日志、指标、截图、View Hierarchy、交互、HTTP 上下文、原生崩溃、ANR、Tracing、Profiling 和 Replay。
- Replay、截图和 View Hierarchy 遮罩全部文本、普通图片与 Asset 图片。
- 不主动上传事实 PCM、WAV、转录快照或说话人结果，也不增加首次启动遥测同意。
- 录音期间停止新 Tracing/Profiling、交互 Breadcrumb、错误截图和 View Hierarchy；崩溃与 ANR 保留。`sentry_flutter 9.26.0` 无公开 Replay 暂停 API，因此 Replay 继续运行并保持全量遮罩，不增加私有桥接。
- Sentry 初始化、离线或上传失败不得阻断启动或事实录音。

## 构建参数

| 名称 | 默认值 |
| --- | --- |
| `SENTRY_ENABLED` | Android/iOS Release 为 `true`；其他为 `false`；DSN 为空时关闭 |
| `SENTRY_DSN` | 项目公开 DSN |
| `SENTRY_ENVIRONMENT` | Release 为 `production`，其他为 `development` |
| `SENTRY_RELEASE` | SDK 自动识别；候选显式传 `com.meettrace.app@<version>+<build>` |
| `SENTRY_DIST` | SDK 自动识别；候选显式传共享构建号 |
| `SENTRY_TRACES_SAMPLE_RATE` | `0.2` |
| `SENTRY_PROFILES_SAMPLE_RATE` | `0.1` |
| `SENTRY_REPLAY_SESSION_SAMPLE_RATE` | `0.1` |
| `SENTRY_REPLAY_ON_ERROR_SAMPLE_RATE` | `1` |

本地受控验证：

```powershell
flutter run -d '<device-id>' `
  --dart-define=SENTRY_ENABLED=true `
  --dart-define=SENTRY_ENVIRONMENT=development
```

## 符号上传

`sentry_dart_plugin` 的组织和项目已在 `pubspec.yaml` 配置。Token 只放在被忽略的本地 `sentry.properties`，或 `android-alpha`、`testflight` Environment 的最小权限 `SENTRY_AUTH_TOKEN`；不得进入仓库、构建参数或日志。

```powershell
dart run sentry_dart_plugin
```

验证只需确认事件到达、Release/Dist 正确、Dart 与原生栈可符号化、画面保持遮罩、录音期暂停项生效且 SDK 故障不影响录音。完成后删除受控异常。
