---
kind: external_dependency
name: Silero 语音活动检测模型
slug: silero-vad
category: external_dependency
category_hints:
    - vendor_identity
    - sdk_real_api
scope:
    - '**'
---

### Silero 语音活动检测模型
- INT8 量化的 VAD（Voice Activity Detection）模型，用于实时语音活动检测
- 通过独立的 silero-vad-manifest.json 管理：采样率 16kHz、窗口大小 512、文件大小 212KB
- 与 SenseVoice 协作，在录音主链中实现有界预览队列和录音隔离
- 支持 Range 续传和原子激活，确保下载一致性
- 作为录音增强策略的一部分，提升转录质量
- verify exact API/params against official docs: k2-fsa/sherpa-onnx 官方 VAD 文档确认集成方式