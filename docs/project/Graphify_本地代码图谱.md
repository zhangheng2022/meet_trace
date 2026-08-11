# 会迹（MeetTrace）Graphify 本地代码图谱

> 状态：活动
>
> 更新日期：2026-08-11
>
> 文档级别：A2；本地代码导航与维护 Runbook，不定义产品、技术或质量事实

## 1. 定位与事实边界

Graphify 为仓库生成本地知识图谱，并通过项目级 `.codex/config.toml` 暴露 MCP 查询工具。图谱用于定位代码、追踪依赖和评估改动影响，不能替代 PRD、技术方案、当前源码、Git diff 或目标平台证据。

- 生成物统一位于 `graphify-out/`，由 `.gitignore` 排除，不得提交。
- `.graphifyignore` 定义 Graphify 额外排除范围；活动文档与历史证据即使同时进入图谱，仍必须服从 `docs/README.md` 的权威级别。
- 仓库不依赖自动 Git Hook 保持图谱最新，修改者必须按本文的刷新矩阵执行更新。
- 使用图谱结论前先调用 MCP `graph_stats`，再用 Git、`rg` 和源码核对未提交修改与新文件。

## 2. 安装与连接

首次使用前安装包含 Gemini 与 MCP 支持的 Graphify：

```powershell
uv tool install "graphifyy[gemini,mcp]"
graphify --version
```

项目级 `.codex/config.toml` 负责启动本地 `graphify-mcp` 并指向当前仓库的 `graphify-out/graph.json`。配置必须满足：

- `graphify-mcp` 命令在当前机器可执行；图谱路径指向当前工作树，不复用其他 Worktree 的输出。
- 可共享配置不得包含用户名、机器绝对路径或静态凭据；机器专属值应留在本机配置或环境变量中。
- 修改 MCP 配置后重启 Codex，再调用 `graph_stats` 验证连接。

Codex 支持项目级 MCP 配置、STDIO `command`、`args`、`cwd` 与环境变量转发，具体字段以 [OpenAI MCP 文档](https://developers.openai.com/codex/mcp) 和 [Codex 配置参考](https://developers.openai.com/codex/config-reference) 为准。

## 3. 数据与凭据边界

`graphify update .` 和 `graphify extract . --code-only` 使用本地代码提取，不需要外部 LLM。`graphify extract . --backend gemini` 会把未被 `.gitignore` 和 `.graphifyignore` 排除的文档、图片等语义输入发送给 Gemini。

- `GEMINI_API_KEY` 只允许保存在本机用户环境变量中，不得写入仓库、命令示例、构建日志或图谱记忆。
- 扩大语义索引范围前必须获得用户明确授权；运行前先检查 `.graphifyignore` 和待发送文件清单。
- 不需要文档或图片语义索引、凭据不可用或数据边界不允许外发时，使用 `--code-only`。
- `graphify-out/`、`.codex/`、代理配置和其他本地生成目录必须保持排除。

## 4. 刷新矩阵

| 变化类型 | 命令 | 说明 |
|---|---|---|
| 首次建立完整语义图谱 | `graphify extract . --backend gemini` | 本地 AST + 已授权文档/图片语义提取 |
| 首次建立纯本地图谱 | `graphify extract . --code-only` | 仅代码，不发送文档或图片 |
| 普通代码增量 | `graphify update .` | 无 LLM；更新代码节点、边和聚类 |
| 删除或大规模重构 | `graphify update . --force` | 先确认节点减少符合预期，再允许覆盖较小图谱 |
| 文档或图片变化 | `graphify extract . --backend gemini` | 重新执行语义提取；仍须服从既有授权范围 |
| 检查是否待更新 | `graphify check-update .` | 用于发现语义重提取提示，不代替 `graph_stats` |

不要因为命令执行成功就认定图谱有效。删除或重构后若节点显著下降，应先用 Git diff 和源码确认范围，再使用 `--force`。

## 5. 查询流程

1. 调用 `graph_stats`，记录节点、边、社区数和生成状态。
2. 使用 `query_graph` 查找相关概念；需要精确关系时使用 `get_node`、`get_neighbors` 或 `shortest_path`。
3. 评估 Pull Request 时使用 `list_prs`、`get_pr_impact` 或 `triage_prs`。
4. 对结果涉及的文件运行 `rg`、查看 Git diff 并直接阅读源码。
5. 图谱缺少目标、MCP 不可用或结果与源码冲突时，以源码和权威文档为准，不得阻塞开发。

## 6. 交付检查

- [ ] `graphify --version` 可用，项目 MCP `graph_stats` 调用成功。
- [ ] 图谱刷新方式与本轮代码、删除、文档或图片变化匹配。
- [ ] Gemini 提取前已检查外发范围，没有凭据、用户数据、录音或模型权重。
- [ ] `graphify-out/` 仍被 Git 忽略，`git status` 不包含生成物。
- [ ] 实时统计来自本轮 `graph_stats`；带日期的历史统计没有被改写成当前状态。
- [ ] 图谱结论已通过 Git、`rg` 和源码直接复核。

## 7. 常见问题

- MCP 无法启动：确认 `graphify-mcp` 可执行、图谱路径属于当前工作树，并在修改配置后重启 Codex。
- Gemini 凭据不可用：改用 `graphify extract . --code-only`，不要把凭据写进配置文件。
- `update` 拒绝覆盖节点更少的图谱：先确认删除符合预期，再运行 `graphify update . --force`。
- 查询结果过期或缺少新文档：按刷新矩阵重建图谱，再调用 `graph_stats`；未提交内容始终直接检查工作树。
