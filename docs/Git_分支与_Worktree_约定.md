# Git 分支与 Worktree 约定

> 状态：当前执行约定
> 更新日期：2026-07-24

## 分支职责

- `master`：稳定集成线。只接收已经完成质量门槛的步骤，不直接承载开发。
- `codex/alpha-step-<NN>-<topic>`：单个 Alpha 步骤的功能分支，从最新稳定基线创建。
- `codex/alpha-step-03-baseline`：Step 01～03 已完成代码的当前本地基线；Step 04 从该提交开始。

分支名使用小写英文和连字符；一个功能分支只对应一个开发步骤。提交信息优先使用中文祈使语气。

## Worktree 布局

项目内的 linked worktree 统一放在：

```text
.worktrees/<branch-topic>/
```

`.worktrees/` 必须由仓库根目录的 `.gitignore` 忽略。一个分支同一时间只能被一个 worktree 检出，不在主检出目录和 linked worktree 之间来回切换同一分支。

当前规划：

```text
仓库根目录
  └─ codex/alpha-step-03-baseline

.worktrees/alpha-step-04-model-registry
  └─ codex/alpha-step-04-model-registry

.worktrees/alpha-step-05-bundled-paraformer
  └─ codex/alpha-step-05-bundled-paraformer

.worktrees/alpha-step-06-qwen-download
  └─ codex/alpha-step-06-qwen-download
```

## 标准流程

1. 在最新稳定基线上确认 `git status --short` 无业务改动。
2. 创建功能分支及 linked worktree。
3. 在新 worktree 中运行 `flutter pub get`。
4. 运行 `flutter test` 和 `flutter analyze`，确认基线可用。
5. 只在功能 worktree 中实现、测试和提交该步骤。
6. 合并前重新运行项目质量门槛，并记录对应 PRD/开发步骤章节。
7. 合并完成且确认无未提交内容后，才移除 worktree 和本地功能分支。

示例：

```powershell
git worktree add ".worktrees/alpha-step-04-model-registry" `
  -b "codex/alpha-step-04-model-registry" `
  "codex/alpha-step-03-baseline"
```

查看当前关系：

```powershell
git worktree list
git branch -vv
git status --short --branch
```

## 安全规则

- 不使用 `git reset --hard`、`git checkout --` 清理用户改动。
- 未提交的工具产物先放入带说明的 stash，不与业务提交混合。
- 不强制推送，不未经确认删除远端分支。
- worktree 有未提交内容时禁止执行 `git worktree remove --force`。
- `.spike/`、下载模型、真实录音和构建产物不进入任何分支。
