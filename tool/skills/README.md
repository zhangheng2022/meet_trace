# 第三方仓库技能

`.agents/skills` 与 `.claude/skills` 只保存上游发行内容。`skills-lock.json` 由官方 `skills` CLI 管理；`sources.json` 补充不可变来源 revision、CLI 版本和全部文件 SHA-256，包含支持文件与两个宿主副本。运行 `python3 tool/skills/check_skills.py` 检查漏锁、缺失入口和内容漂移。

更新时使用 `npx --yes skills@1.7.0 add <source> --skill <names> --agent codex claude-code --copy --yes`，从官方源检查变更后更新来源 revision 和文件摘要。不要只改摘要以绕过未审查的内容变化。复现指定 revision 时使用 `https://github.com/<owner>/<repo>/tree/<revision>` 作为来源，并核对全部摘要。CLI 的 computedHash 算法由 CLI 自身管理，不当作提交 SHA 使用。

Graphify 例外：它不是 `skills add` 所支持的标准上游目录；以前安装了整个 Python 包且入口大小写错误。使用官方 `graphifyy==0.9.72` 的 `graphify install --project --platform agents` 和 `--platform claude` 在临时空目录生成技能，再复制两个 `skills/graphify` 目录到仓库。这样保留官方生成的 `SKILL.md`、对应宿主 references 与 `.graphify_version`，不覆盖项目已有 AGENTS、CLAUDE 或 hook 设置。其来源及全部摘要独立锁在 `sources.json`，不能重新用 `skills add graphify-labs/graphify` 覆盖。

代码变化后使用同版本 Graphify 执行 `graphify update .`；图输出在忽略的 `graphify-out/` 中。技能与 CLI 是开发工具，不能代替产品测试、隐私授权或正式审查。
