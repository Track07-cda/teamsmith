# P365 · apply A2：敲门结果落进项目内的账，digest 点名「已记录、未敲门」

task: P365
agent: dev2
phase: apply
category: code
change: turn-notice-in-pm-inbox
specs: notify-and-inbox#A notice whose knock was skipped is recorded with its reason and named by digest
anchor: none (infra) — change 自带 delta
deltas: notify-and-inbox
branch: task/P365-notice-ledger-a2
deps: A1 已并入 main（`P364` / `V96`）；`P367` 已并入（选段表 `needs` 修好）

## 只做 A2

照 `openspec/changes/turn-notice-in-pm-inbox/` 的 `proposal.md` §3、`design.md` 关于结果账那一节、`tasks.md` 段 2：

1. **每次 settle 写一条结果记录** 到 `state/notify-knock.log`：ISO、席位、任务、状态类、
   `outcome=enqueued|skipped:<类>`、`pointer=ok|failed`、行身份。**跳过原因是闭集分类**，未知类原样打印而不是丢弃。
2. **有界**：沿用 `TEAM_NOTIFY_DETAIL_MAX`，越界轮转到 `state/notify-knock.log.1`，只留一代，轮转在扩展日志里点名。
   **不新增配置键**（因此不动 schema/模板/config.md/面板标签这四面）。
3. **`team digest` 多两行**（为 0 不打印）：本轮「已记录但未敲门」的条数与原因分类；最近一次 `pointer=failed`。
   读数要能回答用户那句「为什么我没收到通知」。

## 必须交的证据

1. **四种 outcome 各一条真记录**：`enqueued`、`skipped:suspended`、`skipped:<另一个被跳过的路径>`、`skipped:notify-off`；
   贴 `state/notify-knock.log` 的原文（脱敏）。
2. **未知类不吞**：造一个不在闭集里的原因 → 必须原样出现在账里（贴行），digest 的分类行把它显示为「其它（原样）」。
3. **轮转**：把上限调小（测试内）→ 必须产生 `.1`，且扩展日志点名一次；账本身不超过上限。
4. **digest 两行**：造 3 条未敲门 + 1 条 `pointer=failed` → digest 的两行读数必须精确（贴输出）；清掉后两行消失。
5. **digest 计数不变**：A1 的「一条通知只数一次」不受影响（`--select 25` 贴读数）。
6. 轻量收口：`bash -n`、`--loop-check`、`section-select.sh --check`、`openspec validate --all --strict`、
   `spec-refs.sh --check`、账本禁令、`git diff --check`。

## 边界

写集：`skills/teamsmith/extension/team-notify.ts`、`skills/teamsmith/scripts/lib/cmd-status.sh`（digest 那两行）、
必要时 `tests/smoke.sh` 的对应断言、报告。**不新增配置键**、不改敲门判据、不动 A1 的指针行形状、不碰面板。
