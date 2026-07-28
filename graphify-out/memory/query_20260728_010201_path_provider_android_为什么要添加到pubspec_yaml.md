---
type: "query"
date: "2026-07-28T01:02:01.575934+00:00"
question: "path_provider_android 为什么要添加到pubspec.yaml"
contributor: "graphify"
outcome: "useful"
source_nodes: ["path_provider", "path_provider_android", "pubspec.yaml"]
---

# Q: path_provider_android 为什么要添加到pubspec.yaml

## Answer

Expanded from original query via graph vocab: [android, dependencies, dependency, path, plugin, provider, startup, version]. path_provider_android 通常由 path_provider 传递引入，项目没有直接 import；这里把 2.2.23 写为 direct main dependency，是为了把 Android 实现精确锁在 Mi 10/Android 11 真机验证过的版本。path_provider 2.1.6 对它的约束是 ^2.2.5，会允许解析到 2.3.x，而 2.3.x 曾在该设备触发 libdartjni.so SIGSEGV。直接精确约束可在 pub upgrade 或重建 lock 时继续阻止升级。升级或移除此行前需复跑 Mi 10 启动、私有目录和后台录音回归。

## Outcome

- Signal: useful

## Source Nodes

- path_provider
- path_provider_android
- pubspec.yaml