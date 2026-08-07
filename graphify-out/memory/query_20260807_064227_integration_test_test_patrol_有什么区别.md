---
type: "query"
date: "2026-08-07T06:42:27.489117+00:00"
question: "integration_test test Patrol 有什么区别"
contributor: "graphify"
outcome: "useful"
source_nodes: ["Formatting Analysis Testing and OCR Quality Gate", "recording", "audio", "recording_session_view_test.dart"]
---

# Q: integration_test test Patrol 有什么区别

## Answer

Expanded from original query via vocab: [test, testing, integration, flutter, recording, audio, device]. 当前test/有102个测试文件，通过flutter test在Dart/Flutter测试环境执行，覆盖单元、仓储、服务、架构守卫、ViewModel和Widget，速度快且大量使用Fake，不安装真实App，也不操作系统UI。integration_test/有2个文件，使用IntegrationTestWidgetsFlutterBinding安装到设备执行真实插件/原生库：可靠录音与真实PCM模型回放；它们当前是设备内服务级集成测试，不是完整UI E2E，且难以自动处理系统权限/Home/分享面板。Patrol当前未安装且无patrol_test目录；它建立在integration_test上并增加Android instrumentation/iOS XCTest原生控制，可在Dart中同时操作Flutter Widget与系统权限、Home、通知和原生分享。三者应共存：test验证业务规则，integration_test验证PCM/模型/hash/RTF内部指标，Patrol验证用户跨Flutter与OS的关键主链。

## Outcome

- Signal: useful

## Source Nodes

- Formatting Analysis Testing and OCR Quality Gate
- recording
- audio
- recording_session_view_test.dart