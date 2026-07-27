---
type: "query"
date: "2026-07-27T11:56:03.941868+00:00"
question: "C:\\Users\\96227\\Desktop\\works\\meetily_ai\\windows\\flutter\\ephemeral\\.plugin_symlinks\\connectivity_plus\\windows\\connectivity_plus_plugin.cpp(1,1): error C2220: 以下警告被视为错误；warning C4819: 该文件包含不能在当前代码页(936)中表示的字符。"
contributor: "graphify"
outcome: "useful"
source_nodes: ["windows/flutter/generated_plugin_registrant.cc", "Connectivity", "ConnectivityDownloadNetworkStatusProvider"]
---

# Q: C:\Users\96227\Desktop\works\meetily_ai\windows\flutter\ephemeral\.plugin_symlinks\connectivity_plus\windows\connectivity_plus_plugin.cpp(1,1): error C2220: 以下警告被视为错误；warning C4819: 该文件包含不能在当前代码页(936)中表示的字符。

## Answer

根因是 connectivity_plus 原生插件通过 apply_standard_settings 继承了 /WX，但 MSVC 在中文 Windows 上默认使用 CP936 解码 UTF-8 源文件。已在 windows/CMakeLists.txt 的公共 APPLY_STANDARD_SETTINGS 中增加 /utf-8，使应用和插件统一按 UTF-8 编译；未修改 ephemeral 或 Pub 缓存。flutter build windows --debug 成功，生成 meettrace.exe；flutter analyze 无问题。

## Outcome

- Signal: useful

## Source Nodes

- windows/flutter/generated_plugin_registrant.cc
- Connectivity
- ConnectivityDownloadNetworkStatusProvider