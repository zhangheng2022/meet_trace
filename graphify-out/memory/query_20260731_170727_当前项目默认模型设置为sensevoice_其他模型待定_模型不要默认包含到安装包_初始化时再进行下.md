---
type: "query"
date: "2026-07-31T17:07:27.674082+00:00"
question: "当前项目默认模型设置为SenseVoice，其他模型待定，模型不要默认包含到安装包，初始化时再进行下载，给我实施方案"
contributor: "graphify"
outcome: "useful"
source_nodes: ["MeetTraceDependencies", "DownloadableModelService", "AsrModelRegistry", "MeetTraceBootstrap", "MeetTraceStartupView", "BundledSileroVadModelService"]
---

# Q: 当前项目默认模型设置为SenseVoice，其他模型待定，模型不要默认包含到安装包，初始化时再进行下载，给我实施方案

## Answer

Expanded from original query via vocab: [asr, model, default, download, downloadable, startup, bootstrap, initialize, manifest, registry, readiness, vad]. 方案：先更新 PRD，将 Alpha 基线改为唯一默认 SenseVoice（固定 sherpa-onnx-sense-voice-zh-en-ja-ko-yue-int8-2024-07-17）、首启硬阻塞下载 SenseVoice 与 Silero VAD、安装包模型权重 0 字节、下载总资源不超过 300,000,000 字节。Domain 移除 standard/advanced tier 约束，Registry 只登记真实模型，新增运行资源初始化状态与用例；Data 复用 DownloadableModelService 的 HTTPS、Range 续传、校验和原子激活能力，并将 VAD 改为同类可下载资源，增加 768 MiB 空间门槛和版本级移动网络同意；启动装配拆成核心依赖创建与运行资源初始化，UI 展示下载、同意、暂停、空间不足、修复状态，未就绪不进入首页；ASR adapter/factory 新增 SenseVoice 配置，固定 language=auto 和 ITN=true，会议锁定模型 ID/版本/配置供预览与最终转录；设置保留单选项但不显示占位或删除入口。测试覆盖首装、蜂窝确认/拒绝、断点续传、离线二次启动、损坏修复、包体零权重、300 MB 上限、录音连续性与性能门槛。完成后运行 format、analyze、test、双平台构建/真机集成、OCR 审查和 graphify update。

## Outcome

- Signal: useful

## Source Nodes

- MeetTraceDependencies
- DownloadableModelService
- AsrModelRegistry
- MeetTraceBootstrap
- MeetTraceStartupView
- BundledSileroVadModelService