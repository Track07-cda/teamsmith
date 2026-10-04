# M70 · spec-backfill-2026-09 独立验证（verify 阶段）

```
task:   M70
agent:  dev2
issue:
change: spec-backfill-2026-09        # propose=M61（dev-bob）、apply=M62（dev-bob）→ verify 必须换人（D31）
specs:  boundary#Destructive tmux calls that resolve to the shared default socket are refused / boundary#Every gate decision is logged and the gate is injected into the windows / boundary#Destructive tmux fixtures run inside the container / verification#The gate refuses tracked files that still hold conflict markers / delivery-guard#The input-box verdict tolerates pi's update banner / board-and-status#A duplicate board id is refused by default and visible wherever the board is read / board-and-status#The board addresses rows by id, and the agent column has its own entry / board-and-status#The ledger read path stays inside a git-call budget and its cache is an equivalence-checked view / panel#The board page is a kanban over the board's states / panel#The work page's board rows are focusable and open the same detail view
phase:  verify
anchor: change
deltas: boundary, verification, delivery-guard, board-and-status, panel
grant:  docs/team/reports/M70-dev2.md · docs/team/reports/M70-dev2/**（只写报告与证据，不改实现）
deps:   M61（propose）· M62（apply）· **M67（已合并：tmux 闸门按目标判定——boundary 那几条现在为真）**
status: todo
budget: 一个工作块（只写复验证据与报告，不改实现）
```

> 本地模式：不 push。

## 验什么

这是**回填 change**（每条 requirement 都是"现状即契约"）：你的工作是**独立复核 design 的 Evidence map**——
10 条 requirement 每条至少一个 scenario **今天能失败**（可证伪），证据行在 **main 的 tip 上**真的对得上。

**重要前提变化**：M62 时代第 1a 条（boundary 闸门）是 BLOCKED 的；**M67 已把闸门重做落地**
（判定按目标、环境零授权、argv token、词汇表 `pass/allowed-owned/refused/explicit-flag`）。
delta 里 boundary 三条的措辞是 M61 时代写的——**你要逐字核对它们与 M67 之后的现实是否一致**：
- 若 requirement 说"refused（exit 64）"而现实仍是这个 → ✅；
- 若 requirement 的措辞**还写着旧模型**（例如提到 `TEAM_ALLOW_DESTRUCTIVE_TMUX` 的 override 语义、
  或没提 `allowed-owned`/`explicit-flag`）→ 这是**回填与现实漂移**，**逐条列出来**（不自行改 delta，
  写进报告的 `BLOCKED:`/`finding`，交 PM 裁决是改 delta 还是接受）。

## 必做

1. **逐条复核 Evidence map**（10 条）：证据行在 main tip 上对得上 ✅/❌，每条至少一个 scenario 可证伪；
2. **boundary 三条用 M67 后的真实行为重验**（私有 socket 直通 / 默认 socket 的 refused /
   `allowed-owned` / token 的 explicit-flag / 环境变量零授权）——smoke §31c 现在是新写法，跑它并贴结果；
3. **其余各条**跑它点名的段：§0d（冲突标记）、§12b-h0b（横幅）、§4c（重复 ID/assign）、§37（git 调用计数）、
   `flip-m44.sh`、`panel-b3.sh`（行身份焦点）、`container-tmux.sh --selftest`（无容器可见 SKIP）；
4. **两条翻转**：挑两条真的把证据打红一次再还原（临时副本，还原后 `git status` 干净），贴原始输出。

## Acceptance

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
bash skills/teamsmith/tests/flip-m44.sh
```

## Boundaries

- **不改实现**（`scripts/**`、`tests/**`、`extension/**`、`openspec/**` 一律不改）；漂移/矛盾 → 报告 `BLOCKED:` 交 PM；
- 不 push；不改 `docs/team/**` 里 PM 的文件。
