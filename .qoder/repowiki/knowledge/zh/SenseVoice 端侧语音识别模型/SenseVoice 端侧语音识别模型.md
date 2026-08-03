---
kind: external_dependency
name: SenseVoice 端侧语音识别模型
slug: sensevoice-sherpa-onnx
category: external_dependency
category_hints:
    - vendor_identity
    - sdk_real_api
scope:
    - '**'
---

### SenseVoice 端侧语音识别模型
- 基于 sherpa-onnx 的 SenseVoice 多语言（中/英/日/韩/粤语）INT8 量化模型，用于本地实时转录
- 通过 assets/models/manifest.json 固定资源表管理：SHA-256 校验、字节数验证、下载 URL 锁定
- 首次初始化时按 Manifest 下载并校验，资源未就绪前不进入首页
- 与 Silero VAD 配合使用，实现说话人检测与录音增强策略
- 当前为唯一 ASR 模型，后续新增模型必须复用统一 AsrEngine 端口
- 验证命令包含完整性检查与性能基准测试
- verify exact API/params against official docs: sherpa-onnx 官方文档确认模型加载与推理接口