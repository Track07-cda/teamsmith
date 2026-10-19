# P315 · 发布门禁剩余红的**归因**：是本次引入还是既有（决定 0.3.0 能不能发）

task: P315
agent: dev
phase: apply
category: verify
change: -
anchor: none (infra) — 发布前的红归属判定
deltas: -
branch: task/P315-release-reds-attribution
deps: 无（PM 已修两条：§0e 的声明、slash spec 的悬空路径）

## 要回答的问题（只做归因，不修）

FAST 门禁在发布提交上有这些红：**`36⑧`（产品面检出探针 15 条）**、**`38-a panel-choices ✗2`**（§36 另有 `36①` 与 `18c`——**这两条 PM 已修**，不用管）。

**判据（D192/D198 口径）**：同一命令、同一选段、**改动前的树**上跑一遍。
- 基线树：`git clone --branch v0.2.0`（上一个发布版，自带它自己的夹具）**与** `git worktree` 上的 `main~20`（今天的合并之前，若你判断更合适就说明理由）；
- 对每个红给出：**受检树读数 / 基线读数**（段 + ✓✗ 数 + 失败断言原文），并判定 **本次引入** 或 **既有**。

## 边界

- **只做归因**：不改产品、不改夹具、不修红（发现是本次引入的，说清**是哪一个提交**引入的即可，我另派修）；
- 基线克隆放 `/var/tmp/p315-base*`，用 `TEAM_SMOKE_FAST=1`；跑前 `mkdir -p`（D189）；计时类按 D192 并记负载；
- 报告 `docs/team/reports/P315-dev.md`：先说结论（**0.3.0 能不能发**），再给两张对照表。
