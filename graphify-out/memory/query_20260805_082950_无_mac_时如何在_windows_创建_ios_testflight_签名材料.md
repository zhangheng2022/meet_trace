---
type: "query"
date: "2026-08-05T08:29:50.790654+00:00"
question: "无 Mac 时如何在 Windows 创建 iOS TestFlight 签名材料"
contributor: "graphify"
outcome: "useful"
---

# Q: 无 Mac 时如何在 Windows 创建 iOS TestFlight 签名材料

## Answer

签名材料分为 Apple Distribution 证书私钥/p12、App Store Connect provisioning profile、App Store Connect API Key 和 Team ID。Windows PowerShell 可用 OpenSSL 生成加密 RSA-2048 私钥与 PKCS#10 CSR，Apple Developer Portal 选择 Apple Distribution 上传 CSR并下载 DER cer，转换 PEM后校验公私钥并导出带强密码 p12；注册 com.meettrace.app 显式 App ID并生成 App Store Connect profile；App Store Connect Users and Access/Integrations 生成 App Manager Team API Key并一次性下载 p8；把 p12/profile/p8的Base64及密码、Key ID、Issuer ID、Team ID放入GitHub testflight Environment Secrets。三类私钥不得提交仓库，Base64不是加密。

## Outcome

- Signal: useful