---
type: "query"
date: "2026-08-05T07:50:17.187782+00:00"
question: "TestFlight 上传除 altool 外还有哪些方案"
contributor: "graphify"
outcome: "useful"
---

# Q: TestFlight 上传除 altool 外还有哪些方案

## Answer

可选 Apple Transporter/JWT、Fastlane pilot/upload_to_testflight、Apple Build Uploads API、Xcode/Xcode Cloud。对当前 GitHub Actions 项目推荐 Fastlane pilot：API Key 认证、无需 Apple ID/2FA，可等待处理、填写 What to Test 并分配测试组；其底层使用 iTMSTransporter 而非 altool。若坚持纯 Apple 工具，使用 Transporter；直接 Build Uploads API 最复杂。

## Outcome

- Signal: useful