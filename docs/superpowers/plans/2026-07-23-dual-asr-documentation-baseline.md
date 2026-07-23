# Dual ASR Documentation Baseline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Meetily's single-Qwen product baseline with an approved standard Paraformer + advanced Qwen3-ASR dual-model baseline across the PRD, technical design, repository instructions, and Codex roadmap.

**Architecture:** Documentation remains the source of truth before code changes. The PRD defines user-visible behavior and acceptance; the renamed dual-model technical design defines engine, lifecycle, and performance contracts; `AGENTS.md` enforces those contracts; the Codex roadmap sequences later implementation. This phase changes no Dart, Kotlin, Gradle, model binary, or dependency.

**Tech Stack:** Markdown, PowerShell validation, Git, Flutter baseline verification.

## Global Constraints

- Local audio remains the only source of truth.
- Recording writes and ASR inference remain decoupled.
- Standard model: `sherpa-onnx-paraformer-zh-small-2024-03-09` INT8, bundled with the APK.
- Advanced model: `sherpa-onnx-qwen3-asr-0.6B-int8-2026-03-25`, downloaded on demand.
- Standard-model language commitment is Mandarin and English.
- Settings store the global default; meeting creation may override it.
- One selected model handles both live temporary and post-meeting final transcription.
- The model is locked after recording starts.
- Runtime fallback never mixes models silently; reprocessing uses the complete local audio and produces a new attributed snapshot.
- No Qwen3-ASR 1.7B, cloud ASR, automatic model switching, login, sync, team, or iOS scope.
- Do not add downloaded models, recordings, `build/`, `coverage/`, or secrets to Git.

---

## Scope Decomposition

This plan covers only the approved documentation baseline. It deliberately precedes four follow-on implementation plans:

1. Dual-model domain contracts and registry.
2. Bundled Paraformer standard engine.
3. Downloadable Qwen3-ASR advanced engine and model lifecycle.
4. Model-selection UI, persistence, reprocessing, and device qualification.

Those plans must be written against the synchronized documents produced here. They must not be combined into this documentation-only change.

## Target File Map

| File | Responsibility after this phase |
|---|---|
| `docs/superpowers/specs/2026-07-23-dual-asr-model-design.md` | Approved design and immutable decision rationale |
| `docs/研会_AI_Alpha_PRD_无登录版.md` | User-visible dual-model product requirements and acceptance |
| `docs/端侧双模型转录技术方案.md` | Active Paraformer/Qwen engine, lifecycle, degradation, and benchmark design |
| `docs/Qwen3-ASR离线转录技术方案.md` | Removed by Git rename; no stale active technical baseline remains |
| `AGENTS.md` | Repository-wide constraints for agents and contributors |
| `docs/Codex_Alpha_开发步骤.md` | Sequenced delivery roadmap and Codex task template |

### Task 1: Promote the approved design into the PRD

**Files:**

- Modify: `docs/superpowers/specs/2026-07-23-dual-asr-model-design.md:3`
- Modify: `docs/研会_AI_Alpha_PRD_无登录版.md:1`
- Test: inline PowerShell contract checks

**Interfaces:**

- Consumes: approved decisions in `docs/superpowers/specs/2026-07-23-dual-asr-model-design.md`.
- Produces: PRD V0.5 user behavior, requirements, acceptance scenarios, metrics, and scope gates used by every later task.

- [ ] **Step 1: Run the PRD contract check and verify that it fails**

Run:

```powershell
$prd = Get-Content -LiteralPath '.\docs\研会_AI_Alpha_PRD_无登录版.md' -Raw
$required = @(
  'V0.5（无登录、双模型端侧转录版）',
  'Paraformer 中文/英文 Small INT8',
  'Qwen3-ASR 0.6B INT8',
  '标准模型',
  '高级模型',
  '会议开始后不得切换模型'
)
$missing = @($required | Where-Object {
  $prd -notmatch [regex]::Escape($_)
})
if ($missing.Count -gt 0) {
  throw "PRD missing dual-model decisions: $($missing -join ', ')"
}
```

Expected: FAIL with `PRD missing dual-model decisions`.

- [ ] **Step 2: Mark the written design as approved**

Change the design header to:

```markdown
> 状态：已批准
> 日期：2026-07-23
```

- [ ] **Step 3: Update the PRD identity and product decision**

Set the PRD version row and Section 0 to this contract:

```markdown
| 版本 | V0.5（无登录、双模型端侧转录版） |

**本地录音是唯一事实源；标准模型在支持的 Android 设备上提供低功耗句级近实时转录，Qwen3-ASR 作为用户按需下载的高级模型。用户为每场会议选择一个模型；该模型同时负责会中临时转录和会后最终转录。**

标准模型固定为 `sherpa-onnx-paraformer-zh-small-2024-03-09` INT8，随 APK 内置，语言承诺为普通话和英语。高级模型固定为 `sherpa-onnx-qwen3-asr-0.6B-int8-2026-03-25`，按需下载。设置保存全局默认模型，开始会议时允许本场覆盖；会议开始后不得切换模型。
```

Replace the active link to the old Qwen-only technical plan with:

```markdown
[端侧双模型转录技术方案](./端侧双模型转录技术方案.md)
```

- [ ] **Step 4: Update product principles, scope, and core flow**

Make the following requirements explicit in Sections 1–5:

```markdown
- 标准模型开箱即用，不要求首次下载约 1 GB 的高级模型。
- 高级模型是准确率优先选项，不是完成第一场会议的前置条件。
- 模型切换只影响未来会议，不修改历史会议。
- 开始录音前可以显式回退标准模型；录音中不得静默混用模型。
- 会后原模型失败时，用户可以基于完整本地音频选择标准模型重新生成一个独立最终快照。
```

Change the explicit non-goal from only excluding Qwen 1.7B to:

```markdown
- 不做 Qwen3-ASR 1.7B、云端 ASR、会议中自动模型切换或混合模型转录。
```

- [ ] **Step 5: Update functional requirements**

Add these clauses to the existing FR sections:

```markdown
FR-002:
- 开始会议页显示本场转录模型，默认继承设置，允许本场覆盖。
- 高级模型未安装时，用户可以下载或明确改用标准模型。

FR-011:
- 标准模型使用 Paraformer Small INT8；高级模型使用 Qwen3-ASR 0.6B INT8。
- 临时片段记录实际模型 ID 和版本。

FR-012:
- 推理失败不触发会议中自动换模；录音继续并显示转录降级。

FR-020:
- 会后最终转录默认使用该场会议锁定的模型。
- 原模型重试失败后，用户可以选择标准模型重新处理完整音频。
- 新快照成功写入前保留旧快照。
```

Add a new requirement:

```markdown
### FR-013 双模型安装与选择

**产品行为**

- 标准模型随 APK 内置，首次使用无需联网下载。
- 高级模型按需下载，支持空间检查、进度、取消、校验、更新和删除。
- 设置保存全局默认模型，初始值为标准模型。
- 开始会议页允许本场覆盖；录音开始后锁定模型。
- 模型回退必须由用户确认并记录实际模型。

**通过条件**

- 全新安装在离线状态下可以使用标准模型开始会议。
- 删除高级模型不影响历史会议及其结果。
- 任何最终快照都能追溯到实际模型 ID 和版本。
- 同一个最终快照不混合两个模型的转录片段。
```

- [ ] **Step 6: Update pages, local data, metrics, risks, and acceptance**

Add model selection/install states to the settings and start-meeting pages.

Add these local fields:

```text
default_model_id
requested_model_id
recording_model_id
model_version
snapshot_model_id
snapshot_model_version
```

Add standard-model metrics:

```text
model_prepare_latency_ms
model_init_latency_ms{model_id}
asr_rtf{model_id}
asr_peak_memory_bytes{model_id}
asr_energy_ratio{model_id}
asr_thermal_status{model_id}
key_fact_recall{model_id}
```

Add acceptance scenarios:

```markdown
| AT-13 | 全新安装且完全离线 | 标准模型无需网络即可准备并开始句级转录 |
| AT-14 | 选择未安装的高级模型 | 可以下载高级模型或明确改用标准模型，不静默切换 |
| AT-15 | 录音中高级模型推理失败 | 本地录音继续，不混用标准模型，页面显示转录降级 |
| AT-16 | 会后高级模型重试失败 | 可用标准模型重新处理完整音频，新快照标记实际模型 |
```

Add explicit risks for APK growth, standard-model accuracy, advanced-model storage, and cross-model result confusion.

- [ ] **Step 7: Update delivery plan and completion definition**

The two-week plan must now include:

```markdown
- Day 1 对同一批音频同时评测 Paraformer Small INT8 与 Qwen3-ASR 0.6B INT8。
- Day 2 完成内置标准模型准备和高级模型 Manifest/下载流程。
- Day 3 建立统一 AsrEngine 和模型 Factory。
- Day 4 验证模型锁定、显式回退和录音连续性。
- Day 5 验证两个模型分别生成独立最终快照。
```

The Alpha completion definition must say that a new install can use the bundled standard model immediately, while the advanced model is optional.

- [ ] **Step 8: Re-run the PRD contract check**

Run the Step 1 command.

Expected: PASS with no output.

- [ ] **Step 9: Check the Task 1 diff**

Run:

```powershell
git diff --check
git diff -- `
  'docs/superpowers/specs/2026-07-23-dual-asr-model-design.md' `
  'docs/研会_AI_Alpha_PRD_无登录版.md'
```

Expected: no whitespace errors; diff contains only the approved design status and PRD dual-model changes.

- [ ] **Step 10: Commit Task 1**

```powershell
git add -- `
  'docs/superpowers/specs/2026-07-23-dual-asr-model-design.md' `
  'docs/研会_AI_Alpha_PRD_无登录版.md'
git commit -m '更新双模型产品需求'
```

Expected: one commit containing exactly two files.

### Task 2: Replace the Qwen-only technical baseline

**Files:**

- Rename: `docs/Qwen3-ASR离线转录技术方案.md` → `docs/端侧双模型转录技术方案.md`
- Modify: `docs/端侧双模型转录技术方案.md`
- Test: inline PowerShell contract checks

**Interfaces:**

- Consumes: PRD V0.5 and the approved dual-model design.
- Produces: active engine, model lifecycle, failure, benchmark, and integration contracts used by implementation plans.

- [ ] **Step 1: Run the technical-plan contract check and verify that it fails**

```powershell
if (-not (Test-Path -LiteralPath '.\docs\端侧双模型转录技术方案.md')) {
  throw 'Dual-model technical plan does not exist'
}
$tech = Get-Content -LiteralPath '.\docs\端侧双模型转录技术方案.md' -Raw
$required = @(
  'ParaformerStandardAsrEngine',
  'QwenAdvancedAsrEngine',
  'AsrEngineFactory',
  'requestedModelId',
  'recordingModelId',
  'snapshotModelId'
)
$missing = @($required | Where-Object {
  $tech -notmatch [regex]::Escape($_)
})
if ($missing.Count -gt 0) {
  throw "Technical plan missing contracts: $($missing -join ', ')"
}
```

Expected: FAIL with `Dual-model technical plan does not exist`.

- [ ] **Step 2: Rename the active technical document**

```powershell
git mv -- `
  'docs/Qwen3-ASR离线转录技术方案.md' `
  'docs/端侧双模型转录技术方案.md'
```

Expected: Git reports one rename after content is edited.

- [ ] **Step 3: Replace the title and decision table**

Use:

```markdown
# 研会 AI：端侧双模型转录技术方案

> Android 无登录 Alpha｜标准 Paraformer + 高级 Qwen3-ASR｜2026-07-23
```

The decision table must contain:

```markdown
| 标准模型 | `sherpa-onnx-paraformer-zh-small-2024-03-09` INT8，随 APK 内置 |
| 高级模型 | `sherpa-onnx-qwen3-asr-0.6B-int8-2026-03-25`，按需下载 |
| 模型选择 | 设置保存默认，开始会议允许覆盖，录音开始后锁定 |
| 时间戳 | 两个模型统一使用 Silero VAD 片段起止时间 |
| 会后精转 | 使用会议锁定模型；显式回退时从完整音频生成新快照 |
```

- [ ] **Step 4: Define the common engine and model-specific adapters**

Document these exact implementation names:

```text
AsrEngine
AsrEngineFactory
ParaformerStandardAsrEngine
QwenAdvancedAsrEngine
AsrModelRegistry
ModelManager
```

Document that both adapters emit the same immutable `TranscriptEvent` and `TranscriptSnapshot`, including `modelId` and `modelVersion`.

Document these meeting/snapshot fields:

```text
requestedModelId
recordingModelId
modelVersion
snapshotModelId
snapshotModelVersion
```

- [ ] **Step 5: Split the model lifecycle section**

The standard-model subsection must specify:

- APK-bundled resource.
- First-run private-directory preparation.
- SHA-256 verification.
- Atomic install.
- Cannot be deleted.
- Failure permits recording-only mode.

The advanced-model subsection must specify:

- 2 GB free-space preflight.
- Versioned Manifest.
- Progress, cancel, retry, validation, atomic install, rollback, update, delete.
- No replacement while an active task uses the installed version.

- [ ] **Step 6: Update live/final processing and failure semantics**

Document:

- Both engines share 16 kHz mono PCM16 input and Silero VAD intervals.
- The selected engine handles both live and final transcription.
- No mid-meeting model switch.
- A failed live engine never blocks audio writes.
- Reprocessing with standard model rereads complete local audio and creates a separately attributed snapshot.
- AI summary reads only the activated final snapshot.

- [ ] **Step 7: Add the two-model benchmark matrix**

Use the approved standard-model gates:

```markdown
| 模型资源 | ≤ 100 MB，不含公共运行库 |
| 最低设备 RTF P95 | `< 0.5` |
| 句后出字 P95 | `≤ 3 s` |
| 30 分钟最终转录 | `≤ 5 min` |
| 录音完整率 | 100% |
| 温控 | 不持续进入 Severe/Critical |
| 相对能耗 | 不高于同设备 Qwen3-ASR 的 70% |
| 关键事实召回率 | `≥ 85%` |
```

Retain the existing advanced-model gates, but qualify them by the advanced-model device matrix.

- [ ] **Step 8: Update modules, two-week sequence, exit gates, and references**

The module tree must include:

```text
lib/data/services/asr/asr_engine.dart
lib/data/services/asr/asr_engine_factory.dart
lib/data/services/asr/paraformer_standard_asr_engine.dart
lib/data/services/asr/qwen_advanced_asr_engine.dart
lib/data/services/model_manager/model_manager.dart
lib/domain/models/asr_model_descriptor.dart
lib/domain/models/asr_model_selection.dart
```

Day 1 exits if the standard model fails its low-device gate or cannot support key-fact extraction. Qwen failure on a low device removes that device from advanced-model support; it does not remove standard-model support.

- [ ] **Step 9: Re-run the technical-plan contract check**

Run the Step 1 command.

Expected: PASS with no output.

- [ ] **Step 10: Commit Task 2**

```powershell
git add -A -- `
  'docs/Qwen3-ASR离线转录技术方案.md' `
  'docs/端侧双模型转录技术方案.md'
git diff --cached --check
git commit -m '改为端侧双模型技术方案'
```

Expected: one rename/edit commit.

### Task 3: Update repository-wide agent constraints

**Files:**

- Modify: `AGENTS.md:3-36`
- Test: inline PowerShell contract check

**Interfaces:**

- Consumes: PRD V0.5 and dual-model technical plan.
- Produces: mandatory rules for all future Codex and contributor changes.

- [ ] **Step 1: Run the AGENTS contract check and verify that it fails**

```powershell
$agents = Get-Content -LiteralPath '.\AGENTS.md' -Raw
$required = @(
  'Paraformer 中文/英文 Small INT8',
  'Qwen3-ASR 0.6B INT8',
  '标准模型随 APK 内置',
  '会议开始后不得切换模型',
  '最终快照必须记录实际模型'
)
$missing = @($required | Where-Object {
  $agents -notmatch [regex]::Escape($_)
})
if ($missing.Count -gt 0) {
  throw "AGENTS missing dual-model rules: $($missing -join ', ')"
}
```

Expected: FAIL with `AGENTS missing dual-model rules`.

- [ ] **Step 2: Replace the product-boundary paragraph**

Use this content:

```markdown
Meetily 是两周交付的 Android Alpha，不提供登录或跨设备同步。本地音频是唯一事实源；推理变慢或失败时，录音必须继续。标准模型使用 sherpa-onnx 运行 Paraformer 中文/英文 Small INT8，随 APK 内置；高级模型使用 Qwen3-ASR 0.6B INT8，按需下载。设置保存默认模型，开始会议允许本场覆盖，会议开始后不得切换模型。所选模型同时负责会中临时转录和会后最终转录；显式回退必须重读完整音频并生成独立快照。AI 总结只能基于最终转录，最终快照必须记录实际模型。说话人分离属于可降级能力。扩展 P0 前必须先更新 PRD。
```

- [ ] **Step 3: Add model implementation constraints**

Add these rules to architecture/workflow sections:

```markdown
- UI 和 ViewModel 只能依赖统一 `AsrEngine`/Repository，不得判断具体模型类型。
- 模型选择由 `AsrEngineFactory` 完成。
- 内置与下载模型都必须校验版本、字节数和 SHA-256。
- 不得静默混合两个模型的转录片段。
- 模型集成继续遵循 `dart-use-ffigen` 和 `dart-setup-ffi-assets`。
```

- [ ] **Step 4: Re-run the AGENTS contract check**

Run the Step 1 command.

Expected: PASS with no output.

- [ ] **Step 5: Commit Task 3**

```powershell
git add -- 'AGENTS.md'
git diff --cached --check
git commit -m '更新双模型仓库约束'
```

Expected: one-file commit.

### Task 4: Update the Codex delivery roadmap

**Files:**

- Modify: `docs/Codex_Alpha_开发步骤.md`
- Test: inline PowerShell contract checks

**Interfaces:**

- Consumes: synchronized PRD, technical plan, and `AGENTS.md`.
- Produces: dependency-ordered execution steps for later code work.

- [ ] **Step 1: Run the roadmap contract check and verify that it fails**

```powershell
$plan = Get-Content -LiteralPath '.\docs\Codex_Alpha_开发步骤.md' -Raw
$required = @(
  'ParaformerStandardAsrEngine',
  'QwenAdvancedAsrEngine',
  '双模型对比评测',
  '内置标准模型',
  '高级模型按需下载',
  '会议模型锁定',
  'AT-16'
)
$missing = @($required | Where-Object {
  $plan -notmatch [regex]::Escape($_)
})
if ($missing.Count -gt 0) {
  throw "Codex roadmap missing dual-model steps: $($missing -join ', ')"
}
```

Expected: FAIL with `Codex roadmap missing dual-model steps`.

- [ ] **Step 2: Update the roadmap header, baseline, and grill conclusions**

Replace single-Qwen scope language with:

```markdown
标准 Paraformer Small INT8 + 高级 Qwen3-ASR 0.6B INT8 的端侧双模型 Alpha
```

Update the active technical link to `./端侧双模型转录技术方案.md`.

Record the approved decisions:

- Low-power standard model.
- Mandarin/English commitment.
- Bundled standard and downloadable advanced model.
- Global default plus per-meeting override.
- No mid-meeting switch.
- Explicit full-audio reprocessing fallback.

- [ ] **Step 3: Update Step 01 and Step 04**

Step 01 becomes a same-device dual-model benchmark with the approved RTF, energy, thermal, accuracy, and recording-continuity gates.

Step 04 splits lifecycle behavior:

```text
standard: bundled → prepare → hash verify → atomic install → non-deletable
advanced: manifest → preflight → download → hash verify → atomic install → rollback/update/delete
```

- [ ] **Step 4: Update Step 06 through Step 09**

Use the exact implementation names:

```text
AsrEngineFactory
ParaformerStandardAsrEngine
QwenAdvancedAsrEngine
```

Step 07 must require `modelId/modelVersion` on events.

Step 08 must include settings default, start-meeting override, download states, and locked-recording UI.

Step 09 must require same-model final transcription and explicit full-audio fallback snapshots.

- [ ] **Step 5: Update testing, acceptance mapping, and the reusable prompt**

Add AT-13 through AT-16 and model-specific unit/widget/integration coverage.

The reusable Codex prompt must state:

```text
- 不得把具体模型判断放进 View/ViewModel。
- 不得在录音中静默切换模型。
- 每个事件和最终快照必须记录实际模型。
- 标准模型与高级模型必须分别跑真机验证。
```

- [ ] **Step 6: Re-run the roadmap contract check**

Run the Step 1 command.

Expected: PASS with no output.

- [ ] **Step 7: Commit Task 4**

```powershell
git add -- 'docs/Codex_Alpha_开发步骤.md'
git diff --cached --check
git commit -m '更新双模型开发步骤'
```

Expected: one-file commit.

### Task 5: Verify the synchronized documentation baseline

**Files:**

- Verify: `docs/superpowers/specs/2026-07-23-dual-asr-model-design.md`
- Verify: `docs/研会_AI_Alpha_PRD_无登录版.md`
- Verify: `docs/端侧双模型转录技术方案.md`
- Verify: `AGENTS.md`
- Verify: `docs/Codex_Alpha_开发步骤.md`

**Interfaces:**

- Consumes: Tasks 1–4.
- Produces: a clean, internally consistent source-of-truth baseline for later implementation plans.

- [ ] **Step 1: Check for stale single-model wording**

```powershell
$hits = rg -n `
  '技术选型固定为 `Qwen3-ASR|模型固定为 `Qwen3-ASR|必须使用 `Qwen3-ASR-0.6B' `
  AGENTS.md docs
if ($LASTEXITCODE -eq 0) {
  $hits
  throw 'Stale single-model baseline remains'
}
```

Expected: PASS; `rg` returns no active single-model baseline.

- [ ] **Step 2: Check for stale technical-document links**

```powershell
$hits = rg -n 'Qwen3-ASR离线转录技术方案\.md' AGENTS.md docs
if ($LASTEXITCODE -eq 0) {
  $hits
  throw 'Stale Qwen-only technical-plan link remains'
}
```

Expected: PASS with no matches.

- [ ] **Step 3: Check required decisions across all active documents**

```powershell
$files = @(
  '.\AGENTS.md',
  '.\docs\研会_AI_Alpha_PRD_无登录版.md',
  '.\docs\端侧双模型转录技术方案.md',
  '.\docs\Codex_Alpha_开发步骤.md'
)
$required = @(
  'Paraformer',
  'Qwen3-ASR',
  '标准模型',
  '高级模型'
)
foreach ($file in $files) {
  $text = Get-Content -LiteralPath $file -Raw
  foreach ($term in $required) {
    if ($text -notmatch [regex]::Escape($term)) {
      throw "$file missing $term"
    }
  }
}
```

Expected: PASS with no output.

- [ ] **Step 4: Validate local Markdown links**

```powershell
$files = Get-ChildItem -LiteralPath '.\docs' -Recurse -Filter '*.md'
$missing = @()
foreach ($file in $files) {
  $text = Get-Content -LiteralPath $file.FullName -Raw
  $links = [regex]::Matches($text, '\[[^\]]+\]\((\./[^)#]+)\)')
  foreach ($link in $links) {
    $target = Join-Path $file.DirectoryName $link.Groups[1].Value.Substring(2)
    if (-not (Test-Path -LiteralPath $target)) {
      $missing += "$($file.FullName) -> $target"
    }
  }
}
if ($missing.Count -gt 0) {
  $missing
  throw 'Broken local Markdown links'
}
```

Expected: PASS with no output.

- [ ] **Step 5: Run repository verification**

```powershell
git diff --check
flutter analyze
flutter test
git status --short
```

Expected:

- `git diff --check`: no output.
- `flutter analyze`: `No issues found!`
- `flutter test`: all tests pass.
- `git status --short`: clean.

- [ ] **Step 6: Review the commit sequence**

```powershell
git log -5 --oneline
```

Expected: four documentation commits after the approved design commit:

```text
更新双模型产品需求
改为端侧双模型技术方案
更新双模型仓库约束
更新双模型开发步骤
```

Order may appear newest-first in `git log`; each commit must retain the file scope defined by its task.

## Plan Completion Criteria

- PRD version is V0.5 and contains FR-013 plus AT-13 through AT-16.
- The active technical document is `docs/端侧双模型转录技术方案.md`.
- No active document links to the removed Qwen-only technical filename.
- `AGENTS.md` enforces the standard/advanced model split.
- The Codex roadmap contains both engines, lifecycle branches, UI selection, explicit fallback, and device qualification.
- All local Markdown links resolve.
- Flutter analysis and tests remain green.
- Git working tree is clean.

## Follow-on Planning Order

After this plan is executed and reviewed:

1. Write `dual-asr-domain-foundation` implementation plan.
2. Execute and verify the pure-Dart model registry, selection lock, event attribution, and engine factory contracts.
3. Write and execute the bundled Paraformer engine plan.
4. Write and execute the Qwen model-manager and advanced engine plan.
5. Write and execute model-selection UI and persistence plan.
6. Run the two-model device qualification plan before Alpha feature expansion.
