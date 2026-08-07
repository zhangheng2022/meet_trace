---
type: "query"
date: "2026-08-07T06:59:57.036978+00:00"
question: "是否可以删除integration_test"
contributor: "graphify"
outcome: "useful"
source_nodes: ["recording", "audio", "device", "Formatting Analysis Testing and OCR Quality Gate"]
---

# Q: 是否可以删除integration_test

## Answer

Expanded from original query via vocab: [integration, test, recording, audio, device, model, replay, testing]. 当前不应删除integration_test。reliable_recording_test在设备上使用真实麦克风、前台生命周期与文件系统，断言文件字节、完整率>=0.98、checkpoint finalized；live_preview_replay_test在设备上校验SenseVoice/VAD固定大小和SHA-256并测量RTF、延迟、积压与转录事件。Patrol只能增加权限、Home、恢复和系统分享等OS流程控制，不会自动替代这些内部设备指标；将它们强行迁入Patrol只会增加原生Runner和UI流程开销。仓库AGENTS还明确要求真机流程放integration_test，README、质量文档、Gradle回放测试包名逻辑和格式门禁均引用该目录。推荐三层共存：test用于业务规则，integration_test用于设备内部与指标，patrol_test用于用户跨App/OS的E2E。只有在Patrol或其他目录已逐项等价覆盖所有断言、双平台重复通过且同步更新全部契约后，才可讨论迁移，当前没有替代实现。

## Outcome

- Signal: useful

## Source Nodes

- recording
- audio
- device
- Formatting Analysis Testing and OCR Quality Gate