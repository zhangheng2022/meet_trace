# Official sherpa-onnx Flutter Integration Documentation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make every active Meetily document require the official `sherpa_onnx` Flutter/Dart package and prohibit a project-owned native bridge.

**Architecture:** Meetily keeps its Dart `AsrEngine` abstraction and two model-specific Dart adapters. The official Flutter package owns FFI and Android native runtime integration; Meetily owns model lifecycle, recording isolation, transcript events, snapshots, and application error handling.

**Tech Stack:** Markdown, Flutter, official `sherpa_onnx` package, PowerShell validation commands.

## Global Constraints

- Preserve the `AGENTS.md` rule that user communication, documents, plans, explanations, and commit messages prefer Chinese while code identifiers, APIs, commands, paths, and exact technical terms remain in English.
- Do not add or maintain sherpa-onnx JNI code.
- Do not write or generate sherpa-onnx C API bindings with ffigen.
- Do not maintain sherpa-onnx C/C++ sources, CMake builds, private ABI declarations, or manually copied `jniLibs`.
- Pin the official Flutter package to a version proven by the Day 1 device spike.
- If the official package cannot support a target model, revise the package/model decision; do not build a private bridge.
- Keep `ParaformerStandardAsrEngine` and `QwenAdvancedAsrEngine` as Dart business adapters.
- Do not change the dual-model, recording-first, meeting-lock, final-transcript, or privacy product requirements.

---

### Task 1: Update repository and product constraints

**Files:**
- Modify: `AGENTS.md`
- Modify: `docs/研会_AI_Alpha_PRD_无登录版.md`
- Modify: `docs/README.md`

**Interfaces:**
- Consumes: `docs/superpowers/specs/2026-07-23-official-sherpa-onnx-flutter-integration-design.md`
- Produces: Repository-wide integration rule and Day 1 product gate.

- [ ] **Step 1: Replace the repository integration rule**

In `AGENTS.md`, replace the self-built bridge and ffigen requirements with:

```text
sherpa-onnx 只通过官方 `sherpa_onnx` Flutter/Dart 包接入。项目不得自建 JNI、FFI/C API 绑定、C/C++ 构建链或手工 `jniLibs`；两个模型只在 data/service 层通过 Dart `AsrEngine` 适配官方 API。若官方包缺少目标能力，先调整依赖版本或模型并更新 PRD，不得以私有原生桥接绕过。
```

- [ ] **Step 2: Replace the PRD Day 1 bridge gate**

In `docs/研会_AI_Alpha_PRD_无登录版.md`, make Day 1 require:

```text
- 确认官方 `sherpa_onnx` Flutter 包能运行两个目标模型、正确释放资源，并由依赖包完成 Android 原生运行库打包。
```

- [ ] **Step 3: Update the documentation index**

In `docs/README.md`, describe the technical baseline as:

```text
将 PRD 约束落实为录音、模型管理、官方 sherpa-onnx Flutter 包、双 ASR Engine、存储和降级架构。
```

Add the approved integration spec to the supporting-document list.

- [ ] **Step 4: Validate Task 1**

Run:

```powershell
rg -n "官方.*sherpa_onnx|不得自建|Day 1" AGENTS.md docs/README.md docs/研会_AI_Alpha_PRD_无登录版.md
```

Expected: all three files describe the official-package boundary; the PRD no longer requires ffigen.

- [ ] **Step 5: Commit Task 1**

```powershell
git add -- AGENTS.md docs/README.md docs/研会_AI_Alpha_PRD_无登录版.md
git commit -m "更新官方 ASR 包约束"
```

---

### Task 2: Replace the technical bridge design

**Files:**
- Modify: `docs/端侧双模型转录技术方案.md`

**Interfaces:**
- Consumes: Official `sherpa_onnx` Dart API, model paths from ModelManager.
- Produces: Dart-only `ParaformerStandardAsrEngine` and `QwenAdvancedAsrEngine` adapters.

- [ ] **Step 1: Remove project-owned native directories**

Remove `android/src/main/cpp/` and project-owned `android/src/main/jniLibs/` from the target directory tree. Keep `android/` only for ordinary Flutter platform configuration generated or required by the official package.

- [ ] **Step 2: Replace the native bridge section**

The replacement section must state:

```text
## 7. 官方 sherpa_onnx Flutter 包集成

- `pubspec.yaml` 直接依赖官方 `sherpa_onnx` Flutter 包。
- 版本固定为 Day 1 真机 Spike 验证通过的版本。
- 官方包负责 Dart FFI、Android 原生运行库和 ABI 集成。
- Meetily 不维护 JNI、ffigen、C API 绑定、C/C++ 构建或手工 jniLibs。
- 两个 AsrEngine 是 Dart 业务适配器，不包含 DynamicLibrary.open、指针或 ABI 声明。
- 官方包能力不足时停止实现并调整依赖/模型决策，不自建桥接。
```

- [ ] **Step 3: Preserve packaging verification**

Keep APK checks for:

- target ABI availability;
- duplicate native libraries;
- APK size;
- package/model licenses;
- absence of the downloadable advanced model.

Clarify that these are verification duties, not ownership of the native build.

- [ ] **Step 4: Update implementation and release wording**

Change the implementation order from “ffigen integration” to “official Flutter package integration.” Change release checks from project-owned native libraries to official-package ABI and dependency verification.

- [ ] **Step 5: Validate Task 2**

Run:

```powershell
$text = Get-Content -LiteralPath '.\docs\端侧双模型转录技术方案.md' -Raw
if ($text -notmatch '官方 `sherpa_onnx` Flutter') { throw 'official package rule missing' }
if ($text -match '通过 `ffigen` 生成|src/main/cpp|手工.*jniLibs') { throw 'self-built bridge rule remains' }
```

Expected: command exits successfully.

- [ ] **Step 6: Commit Task 2**

```powershell
git add -- docs/端侧双模型转录技术方案.md
git commit -m "改用官方 sherpa-onnx Flutter 包"
```

---

### Task 3: Rewrite Codex execution steps

**Files:**
- Modify: `docs/Codex_Alpha_开发步骤.md`

**Interfaces:**
- Consumes: `docs/端侧双模型转录技术方案.md`
- Produces: Day 1 and Step 08 tasks that can be executed without private native integration.

- [ ] **Step 1: Replace global engineering rules**

State that sherpa-onnx is consumed only through the official Flutter package. Remove the global requirement to generate bindings from headers.

- [ ] **Step 2: Rewrite Day 1 Spike**

The Spike must:

- select and pin a candidate official package version;
- initialize both target models through the public Dart API;
- verify audio input, result reading, resource release, isolation from recording, ABI contents, RTF, memory, and temperature;
- return No-Go or require a model/dependency decision when the public API is insufficient;
- prohibit private FFI/JNI fallback.

Remove `dart-use-ffigen` and `dart-setup-ffi-assets` from this step.

- [ ] **Step 3: Rewrite Step 08**

Rename it:

```text
## Step 08：官方 sherpa_onnx Flutter 包集成
```

Required tasks:

1. Add and pin the verified official package.
2. Initialize the package once according to its public API.
3. Create a small Dart adapter around recognizer configuration and lifecycle.
4. Run inference outside the UI/recording critical path.
5. Convert package errors into structured application errors.
6. Inspect the Debug APK for ABI, duplicate libraries, advanced model absence, size, and licenses.

Explicitly prohibit `ffigen`, JNI, C/C++, private ABI declarations, `DynamicLibrary.open`, and manual `jniLibs`.

- [ ] **Step 4: Update dependencies, schedule, and board**

Rename every “FFI/Android asset” reference to “official Flutter package integration.” Remove `android/cpp` and `jniLibs` from the target tree.

- [ ] **Step 5: Validate Task 3**

Run:

```powershell
$path = '.\docs\Codex_Alpha_开发步骤.md'
$text = Get-Content -LiteralPath $path -Raw
foreach ($required in @('Step 08：官方 sherpa_onnx Flutter 包集成', '不得自建', 'ParaformerStandardAsrEngine', 'QwenAdvancedAsrEngine')) {
  if (-not $text.Contains($required)) { throw "missing: $required" }
}
foreach ($forbidden in @('dart-use-ffigen', 'dart-setup-ffi-assets', '从头文件通过 ffigen 生成', 'android/src/main/cpp')) {
  if ($text.Contains($forbidden)) { throw "forbidden: $forbidden" }
}
```

Expected: command exits successfully.

- [ ] **Step 6: Commit Task 3**

```powershell
git add -- docs/Codex_Alpha_开发步骤.md
git commit -m "更新官方包开发步骤"
```

---

### Task 4: Cross-document verification

**Files:**
- Verify: `AGENTS.md`
- Verify: `docs/README.md`
- Verify: `docs/研会_AI_Alpha_PRD_无登录版.md`
- Verify: `docs/端侧双模型转录技术方案.md`
- Verify: `docs/Codex_Alpha_开发步骤.md`
- Verify: `docs/superpowers/specs/2026-07-23-official-sherpa-onnx-flutter-integration-design.md`

**Interfaces:**
- Consumes: Tasks 1–3.
- Produces: One consistent active documentation baseline.

- [ ] **Step 1: Run the prohibited-positive-requirement scan**

```powershell
rg -n "必须.*ffigen|通过.*ffigen.*生成|自建.*JNI|自建.*FFI|src/main/cpp|手工.*jniLibs" AGENTS.md docs/README.md docs/研会_AI_Alpha_PRD_无登录版.md docs/端侧双模型转录技术方案.md docs/Codex_Alpha_开发步骤.md
```

Expected: no matches. Prohibitions such as “不得自建 FFI/JNI” are allowed only when they do not describe an implementation task.

- [ ] **Step 2: Verify required decisions**

```powershell
rg -n "官方.*sherpa_onnx.*Flutter|不得自建|官方包.*能力不足" AGENTS.md docs
```

Expected: the repository rule, technical baseline, execution plan, and approved spec all contain the decision.

- [ ] **Step 3: Verify Markdown links and whitespace**

Run the repository Markdown relative-link check and:

```powershell
git diff --check
```

Expected: no broken local links and no whitespace errors.

- [ ] **Step 4: Run project checks**

```powershell
flutter analyze
flutter test
```

Expected: analyzer reports no issues and all tests pass.

- [ ] **Step 5: Remove this completed execution plan**

After all checks pass, delete:

```text
docs/superpowers/plans/2026-07-23-official-sherpa-onnx-flutter-documentation.md
```

Git history remains the audit trail; `docs/` keeps only current active guidance and approved design specifications.

- [ ] **Step 6: Commit final cleanup**

```powershell
git add -- docs/superpowers/plans/2026-07-23-official-sherpa-onnx-flutter-documentation.md
git commit -m "完成官方包文档同步"
```
