---
type: "query"
date: "2026-08-06T11:00:43.587147+00:00"
question: "MeetTrace 应在哪里配置 Sentry，并如何在录音期间降载？"
contributor: "graphify"
outcome: "useful"
source_nodes: ["main()", "Application", "MeetTraceBootstrap", "RecordingSessionViewModel"]
---

# Q: MeetTrace 应在哪里配置 Sentry，并如何在录音期间降载？

## Answer

入口由 main 通过 SentryBootstrap 初始化并向 Application 注入 SentryNavigatorObserver；生产 RecordingSessionViewModel 通过 domain RecordingTelemetryGate 驱动 data/service 层 Sentry 采样回调，在录音前暂停新 tracing/profiling、交互 breadcrumb、截图和视图层级，录音结束后恢复。

## Outcome

- Signal: useful

## Source Nodes

- main()
- Application
- MeetTraceBootstrap
- RecordingSessionViewModel