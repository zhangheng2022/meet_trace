---
type: "query"
date: "2026-08-05T07:39:43.911060+00:00"
question: "iOS 通过 GitHub 发布到 TestFlight 需要什么"
contributor: "graphify"
outcome: "useful"
---

# Q: iOS 通过 GitHub 发布到 TestFlight 需要什么

## Answer

当前项目已有 com.meettrace.app、iOS 配置和无签名构建审计；仍需 Apple Developer Program、显式 App ID 和 App Store Connect 应用记录、Apple Distribution 证书私钥、App Store Connect provisioning profile、App Store Connect API Key、GitHub Environment Secrets、唯一递增 build number，以及独立的受保护签名构建与上传流水线。API Key 用于上传，不替代签名证书和 profile。

## Outcome

- Signal: useful