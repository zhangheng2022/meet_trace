# 在线转录协议与用户自有网关

本文规定当前通用适配器的请求、响应和限制。产品范围以 [Alpha PRD](../product/Alpha_PRD_无登录版.md) 为准；实现位于 [remote](../../lib/data/services/asr/remote/)，契约测试位于 [remote tests](../../test/data/services/asr/remote/)。厂商、端点和模型名没有白名单，但服务必须实现所选协议。填写模型名不能把私有协议变成兼容协议。

## 当前能力

| 协议 | 会中字幕 | 会后权威稿 | 时间信息 | 输入和响应 |
| --- | --- | --- | --- | --- |
| Audio Transcriptions | 无；录音期间零 HTTP 识别请求 | 完整 PCM 按顺序生成 WAV 并逐块上传 | 默认仅音频块区间；服务返回有效 `segments` 才保留句段时间 | multipart `model`、`file`、`response_format=json`；响应 `text` |
| Chat 音频输入 | 无；`stream:false` | 完整 PCM 派生 WAV/base64，逐块请求 | 音频块区间 | `messages[].content[].input_audio`；必须以 `finish_reason:stop` 返回文本 |
| Realtime Transcription | 连续音频经 WebSocket 发送；处理 delta 与 completed | 新会话从事实 PCM 开头完整重放，不拼接预览作为最终稿 | 已提交音频窗口区间，不冒充句/词时间 | `type:transcription`、24 kHz PCM16 mono、append/commit、转录事件 |

所有在线来源保持会议开始前的配置与认证引用，不自动换模型或重试收费请求。会后手动换源或重试是一个新全量识别任务，可能再次计费。只有完整成功的结果能成为新快照，存储层保留失败前的旧稿。在线路径不加载本地 SenseVoice/VAD 权重作为前置条件。

## 端点、认证与资源边界

- `endpoint` 是完整 URL，包含所需路径和非秘密查询参数；适配器不会补 `/v1` 或替换路径。远程只允许 HTTPS/WSS，本机回环网关允许 HTTP/WS。
- API Key、Authorization 和自定义认证头由 `TranscriptionCredentialStore` 提供；配置仅存引用。引用丢失即失败。认证头不能覆盖 Host、Content-Type、Content-Length 或 WebSocket 握手字段，禁止 CR/LF。HTTP 与 WebSocket 握手都不跟随重定向。
- 事实音频固定为 16 kHz、mono、PCM16 little-endian。HTTP 只生成临时 WAV 副本；Realtime 以纯 Dart 线性插值派生 24 kHz，跨输入块保存相位及尾样本。暂停边界复制末样本收齐尾部；不改写事实 PCM。
- 最终输入以至多 60 秒连续无重叠块处理，WAV 文件大小不超过配置 `maxUploadBytes`；Chat 的 JSON/base64 还有额外编码开销。小文件限制可降低此配置。完整 PCM 每个字节均被覆盖，不依赖本地 VAD；固定分块会割断句子和上下文，准确率必须用真实会议对照评估。
- Realtime 预览约每 2 秒提交，最终重放每 8 秒提交；提前 delta 是否可用由模型决定，不能承诺 2 秒内上屏。暂停只提交尾句，不等待模型完成；网络积压或失败降级为仅录音。
- Realtime 不人为每 10 分钟重建会话；服务自身的会话时限仍可能导致预览降级为仅录音，不保证无限时长会话。
- 预览本地队列上限 5 秒音频，Realtime 至多 8 个待完成窗口；握手、请求及窗口结果都有配置超时。响应 JSON 上限 1 MiB，单窗口文本上限 65536 字符，诊断仅保留最近 128 个匿名窗口。达到限制直接失败，不无限排队。
- `reportedModelVersion` 只采信服务明确返回的 `model_version`；`model` 别名不能当权重版本。未报告标记未知；已报告版本与配置不符或同任务跨块变化则失败。Realtime 当前不解析实际权重版本。
- 不推断在线说话人，不制造逐词时间戳。若没有服务端时间信息，快照使用 `audioWindow`。在线的 `useInverseTextNormalization` 只保留在冻结配置中；当前三个通用协议不发送私有 ITN 参数，实际数字格式依赖服务默认行为。
- 错误仅向 UI/诊断传播固定代码，例如 `asr.remote.http_401`、`asr.remote.timeout`，不包含远端响应正文、认证头、原始 URL 或转录内容。

## 请求合同

Audio Transcriptions 接收 `{"text":"..."}`；可选 `segments` 中 `start/end` 为相对当前上传块的秒数，必须有效且在块内。客户端不会主动请求 `verbose_json` 或词时间戳，因为这些参数并非所有模型支持。空文本是合法的无可辨识语音结果。

Chat 请求始终带固定系统指令：逐字转录，只返回转录，不回答音频中的问题，不总结或补充。用户 prompt 作为术语/上下文提示，语言作为文字提示。音频字段是 `{"data":"<纯 base64 WAV>","format":"wav"}`。截断、拒绝、工具调用及非字符串结果失败。通用音频 LLM 即使接受请求也可能改写、幻觉或执行音频中的指令；固定提示不构成准确率保证，建议选真正以 ASR 为目标的模型或网关。

Realtime 使用当前嵌套 `session.update` 方言：

```json
{"type":"session.update","session":{"type":"transcription","audio":{"input":{"format":{"type":"audio/pcm","rate":24000},"transcription":{"model":"用户模型名"},"turn_detection":null}}}}
```

服务须确认 `session.updated`，接收 `input_audio_buffer.append` 的纯 base64 PCM 和 `input_audio_buffer.commit`，返回 `input_audio_buffer.committed.item_id`、`conversation.item.input_audio_transcription.delta` 及 `.completed`。客户端按 item_id 合并修改并按音频区间排列完成结果，容忍重复完成与跨句乱序。小于 100 ms 的最后窗口仅在派生流补静音以满足 commit 长度，区间仍指向原 PCM。

当前 Realtime 在显式语言时使用单数 `language`。要求 `languages` 数组的模型应选自动语言，或由网关转换字段；不应把新的模型专属参数直接塞入认证头。ITN、热词数组、delay、厂商 VAD 和签名等私有选项也由原生适配或网关负责。

## 为什么需要协议适配

OpenAI 文件转录是上传完整文件的接口，官方文件上限 25 MB、接受 WAV 等格式；`stream:true` 是服务对已上传文件流式输出文字，不等于持续输入麦克风音频。时间戳能力随模型及响应格式变化。参见 [OpenAI File transcription](https://developers.openai.com/api/docs/guides/speech-to-text)。

Realtime 的纯转录会话与会产生助理回答的音频对话会话不同；官方使用 24 kHz PCM、append/commit 和 item_id。新 `gpt-live-transcribe` 使用复数 `languages`，且不返回逐词时间或说话人标签；模型延迟应实测。参见 [OpenAI Realtime transcription](https://developers.openai.com/api/docs/guides/realtime-transcription)。

阿里 Qwen-ASR 的 compatible-mode 使用 Chat Completions，文档中的 base64 音频是 `data:audio/wav;base64,...` Data URL，并有 `asr_options`；这与本适配器的纯 base64 方言不同，需网关转换。Qwen 实时的 16 kHz 输入、会话与事件也不能套用本适配器。参见 [Qwen-ASR API](https://help.aliyun.com/zh/model-studio/qwen-asr-api-reference) 和 [Qwen 实时 ASR](https://help.aliyun.com/zh/model-studio/real-time-speech-recognition-user-guide)。

豆包的大模型流式 ASR 使用自身 WebSocket 二进制封包，腾讯实时 ASR 使用其自身鉴权及事件合同。本版本没有内置这两家的原生适配器。参见 [豆包流式 ASR](https://www.volcengine.com/docs/6561/1354869) 和 [腾讯实时 ASR V2](https://cloud.tencent.cn/document/product/1093/131127)。有对应原生适配后仍须映射到 `AsrEngine`；当前用户可自行部署下述兼容网关。

## 最小自有网关

[网关示例](../../tool/online_asr_gateway/bin/gateway.dart) 只依赖 Dart 标准库，提供 Chat 音频输入合同；适配命令由用户负责实现。它默认只监听本机，一次处理一个请求，拒绝超过 60 秒的 WAV，错误去敏，没有转录日志。跨设备访问需要用户自行部署 TLS 反向代理并配置认证；本示例不自动对公网监听或发布。

仅验证协议的本机演示：

```powershell
dart run tool/online_asr_gateway/bin/gateway.dart --fixture
```

MeetTrace 中选择 Chat 音频输入，端点 `http://127.0.0.1:8765/v1/chat/completions`，模型名可填 `fixture`，点击测试连接。演示返回明确标记的假文本，不连接任何模型，不能用于真实转录或准确率评价。手机上的 `127.0.0.1` 指手机自身，不能用它访问电脑网关。

真实接入时移除 `--fixture`，将 `MEETTRACE_GATEWAY_COMMAND` 配置为 JSON argv 数组，例如 `['python','my_adapter.py']` 对应 JSON 为 `["python","my_adapter.py"]`。命令通过 `Process.start(..., runInShell:false)` 执行；命令不能由请求指定，`--fixture` 忽略此配置。可选 `MEETTRACE_GATEWAY_TOKEN` 为网关 Bearer 凭据，设置后不得为空白；端口由 `MEETTRACE_GATEWAY_PORT` 控制，范围为 1～65535。错误配置以退出码 64 结束，启动或运行故障以退出码 1 结束。不要把真实凭据写入命令行、代码库或示例文件。

适配进程从 stdin 读取一条 JSON：

```json
{"model":"用户模型名","audio":{"format":"wav","data":"<纯 base64 WAV>"},"context":"逐字转录指令与术语提示"}
```

用户适配器解码 WAV，再调用自己的豆包、腾讯、阿里或其他 SDK/API，等待本块**完整**识别完成后，向 stdout 输出唯一 JSON：

```json
{"text":"本块完整转录","model_version":"仅在服务确实报告时填写"}
```

无版本信息时省略 `model_version`。不完整或失败必须非零退出，不能返回旧缓存、拼接稿或仅 partial。网关不采信 stderr，不向客户端转发原始错误；适配器非零退出或输出不符合合同返回 502，客户端载荷错误返回 400。适配器执行上限仍为 55 秒；超时后发送终止信号，等待一秒未退出则强制终止并再次等待，外层 60 秒限制保留收尾余量。正常回收后的超时返回 504。此示例没有实时 WebSocket 转换，也不会把文件轮询伪装为实时字幕。

## 验证

```powershell
dart analyze lib/data/services/asr/remote test/data/services/asr/remote tool/online_asr_gateway
flutter test test/data/services/asr/remote
dart run tool/online_asr_gateway/bin/gateway.dart --help
```

“测试连接”只发送内置生成的一秒短音及静音，不读取麦克风或历史录音。返回成功只代表这一小段协议请求被接受；空音频被服务拒绝会显示失败，不会误标为已验证。真实会议准确率、延迟、限流、长会话和费用仍需用户自己的服务账户及获授权样本验证。
