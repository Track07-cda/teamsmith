# P55 · agent-pane-survivability apply：pane 留现场 + 四个座位状态 + 机器面

```
task:   P55
agent:  dev
issue:
change: agent-pane-survivability          # 提案已验收：docs/team/reviews/agent-pane-survivability-proposal.md
specs:  dispatch#An agent window outlives its pane and keeps a bounded scene / dispatch#A dead pane is never a live seat, and reuse keeps its evidence / watchdog#A dead pane is a seat condition with a readable scene, and never a running seat
phase:  apply
anchor: change
deltas: dispatch, watchdog
grant:  skills/teamsmith/scripts/lib/cmd-agents.sh · cmd-watch.sh · cmd-status.sh（roster/status/doctor 行；**只加在文件末尾**）· cmd-docs.sh（若 digest 行在此）· skills/teamsmith/scripts/team（若需接线）· skills/teamsmith/references/protocol.md（一句）· skills/teamsmith/tests/smoke.sh（append-only）· skills/teamsmith/tests/panel-*.sh（仅当机器面断言需要）
deps:   P49（propose，已合并）· P47（已合并：cmd-status.sh 的记录扫描）· M6.5（判活语义**不动**）
status: todo
budget: 一个工作块（B1 remain-on-exit + 现场 / B2 死 pane 的交付与复用 / B3 四态与机器面 / B4 夹具）
overlap: ⚠️ P53（dev3，/tmp 卫生）也改 `cmd-status.sh`（doctor 行）：你的行加在文件末尾、小步提交。
```

> 本地模式：不 push。**真源 = `openspec/changes/agent-pane-survivability/{design.md,tasks.md}`。**

## 硬要求

1. **设选项的时机**：窗口先持占位命令 → 设 `remain-on-exit` **并读回** → 才交给 harness；
   **只给 agent 窗口**（PM 与 pulse 不变，draft 窗口保持原样）。
2. **死 pane = 可读遗体**：`capture-pane -S -`（带 scrollback）+ `pane_dead_status/signal/time` 可读；
   每席位至多保留一个（下次 dispatch/resume 先抓现场再替换）；`TEAM_AGENT_SCENE_LINES`（默认 40）界定副本；
   **不碰** `history-limit`。
3. **死 pane 不是活座位**：`team say`/敲打投递按 `pane_dead` 判定、**不得报已投递**、
   消息 durable 进 `docs/team/inbox/<agent>.md`、输出点名座位已死 + 退出证据；
   复用前把现场写进 `state/dispatch-<agent>-pane-dead.txt`（座位/窗口/时间/退出证据/最后 N 行），文案改成"上一个 pane 已死"；
   三个命令复用后**仍恰好一个窗口**；`teardown` 照旧能删。
4. **四态**（`running`/`exited`/`dead`/`absent`）：**`running` 的证明规则一字不改**；`roster` 三态可辨 + legend；
   `status <ID>` 打印状态 + 退出证据 + 最后 N 行（标注来源与时间）；机器面加 `pane`/`pane_exit`，
   **`state` 词表不变**；`doctor` 一行告警 + 场景命令；`digest` 点名；
   **异常只在"该席位还有未结束的登记任务"时成立**（`close --keep-window`/`teardown` 后不得再报）。
5. **不许新增定时器**、不许把死 pane 当活座位、不许改 M6.5 与投递的既有回退语义。

## 必给的翻转（红→绿原始输出）

- 杀掉 pane（SIGKILL）→ 窗口还在、`pane_dead=1`、`signal=9`、capture 里仍有 marker 行；
- 去掉 `remain-on-exit` 设置 → 那条断言红（窗口消失）；
- 对死 pane 发 `team say` → 输出**不得**出现已投递字样、收件箱多一行、死 pane 内容逐字节不变；
- 复用（dispatch/--fresh/resume）→ 现场文件先出现且含退出证据、窗口恰好一个；
- `close --keep-window` 后 → digest/doctor/pending **不再**报异常；
- 还原后 `git status --porcelain` 干净。

## Acceptance

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
bash skills/teamsmith/tests/smoke.sh </dev/null          # 交付前全量
```
