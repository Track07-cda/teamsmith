# M62 · spec-backfill-2026-09 证据核对（apply —— 不改行为，只核对）

```
task:   M62
agent:  dev-bob
issue:
change: spec-backfill-2026-09              # 提案已验收：docs/team/reviews/spec-backfill-2026-09-proposal.md（ACCEPTED）
specs:  boundary#Destructive tmux calls that resolve to the shared default socket are refused / boundary#Every gate decision is logged and the gate is injected into the windows / boundary#Destructive tmux fixtures run inside the container / verification#The gate refuses tracked files that still hold conflict markers / delivery-guard#The input-box verdict tolerates pi's update banner / board-and-status#A duplicate board id is refused by default and visible wherever the board is read / board-and-status#The board addresses rows by id, and the agent column has its own entry / board-and-status#The ledger read path stays inside a git-call budget and its cache is an equivalence-checked view / panel#The board page is a kanban over the board's states / panel#The work page's board rows are focusable and open the same detail view
phase:  apply
anchor: change
deltas: boundary, verification, delivery-guard, board-and-status, panel
grant:  openspec/changes/spec-backfill-2026-09/**（**只许改 delta 文本**；不许改任何实现、测试、references）
deps:   M61（propose，已合并）
status: todo
budget: 一个工作块；做不完交 PARTIAL（逐段列出已核对/未核对）
```

> 本地模式：不 push。

## 这个 apply 是什么（别搞错成"写实现"）

本 change 是**回填**：行为**早已落地**，本次 apply 的唯一工作是**逐行核对证据**——
`design.md` 的 **Evidence map** 表里每一条 `文件:行` 都要在**本分支 tip 上**真的对上，
每条 requirement 至少有一个 scenario 能在**今天**失败（可证伪）。**不改任何行为代码**。

## 要做的四件事

1. **逐行核对 Evidence map**（10 条 requirement）：表格里每条给"证据是否成立"（✅ 对得上 / ❌ 对不上），
   对不上的**逐条写清差异**（契约写了什么、代码现在做什么）；**代码与契约矛盾 → 写 `BLOCKED:` 交回 PM，不许改代码**。
2. **跑光它点名的证据**（每条贴原始输出末行）：`smoke.sh` §0d（冲突标记）、§31/§31c（tmux gate + 日志注入）、
   §12b-h0b（横幅）、§4c（重复 ID / assign）、§37（git 调用计数）、`flip-m44.sh`、`container-tmux.sh --selftest`
   （无容器时**可见 SKIP**、有容器时 exit 0）、`panel-b3.sh`（行身份焦点）。
3. **可证伪抽检（至少两条）**：从 10 条里挑两条，**真的把证据打红一次**（例如把冲突标记写进一个临时被跟踪文件 → §0d 红；
   或把 `TEAM_ALLOW_DESTRUCTIVE_TMUX` 的判定注释掉 → gate 不拦），再还原，证明红→绿；贴原始输出。
   （用**临时副本**或可控夹具，别把真仓库搞脏；还原后 `git status --porcelain` 必须干净。）
4. **基线与 tip 的 MODIFIED 复核**：两条 panel requirement 的 base 文本在 tip 上**仍未变**（若变了 → 报告并 `BLOCKED:`）。

## 边界

- 只改 `openspec/changes/spec-backfill-2026-09/**` 里的**文本**（delta/proposal/design/tasks 的措辞修正）；
- **不许**改 `skills/**`、`docs/team/**`、测试、references；发现不一致 → `BLOCKED:`；
- 不动 `## REMOVED`；MODIFIED 不许删 base 的任何 scenario；
- 不 push。

## Deliverables

- 报告 `docs/team/reports/M62-dev-bob.md`：**逐条核对表**（requirement → 证据行 → ✅/❌ → 原始输出末行）
  + 两条翻转的原始输出 + `git status --porcelain` 干净的证据。

## Acceptance

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
bash skills/teamsmith/tests/flip-m44.sh
git status --porcelain
```
