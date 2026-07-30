---
type: "diagnosis"
date: "2026-07-30T11:46:43.362107+00:00"
question: "start meeting readiness model installation whisper initialization failure"
contributor: "graphify"
outcome: "useful"
source_nodes: ["failure", "readiness", "start", "installation", "whisper"]
---

# Q: start meeting readiness model installation whisper initialization failure

## Answer

Android 无法开始会议的实际根因不在权限、模型安装或 16 KB 页面对齐，而是 packages/meettrace_whisper_native/lib/src/c_library.dart 构建 libmeettrace_whisper.so 时未链接系统数学库。真机异常为 dlopen failed: cannot locate symbol exp。修复是在 Android 目标的 CBuilder.library libraries 中加入 m。验证：ELF NEEDED 包含 libm.so；LOAD 段对齐为 0x4000；flutter analyze 通过；flutter test 327 项通过；Mi 10 真机 integration_test/whisper_base_standard_asr_engine_test.dart 完成真实 Base 模型初始化、窗口识别和最终处理。

## Outcome

- Signal: useful

## Source Nodes

- failure
- readiness
- start
- installation
- whisper