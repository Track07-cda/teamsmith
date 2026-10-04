# P65 · agent-pane-survivability 独立验证（verify 阶段）

```
task:   P65
agent:  dev2
issue:
change: agent-pane-survivability
specs:  dispatch#An agent window outlives its pane and keeps a bounded scene / dispatch#A dead pane is never a live seat, and reuse keeps its evidence / watchdog#A dead pane is a seat condition with a readable scene, and never a running seat
phase:  verify
anchor: change
deltas: dispatch, watchdog
grant:  docs/team/reports/P65-dev2.md · docs/team/reports/P65-dev2/**（只写报告与证据，不改实现）
deps:   P49（propose）· **P55（apply，dev）**——apply 作者不是你
status: todo
budget: 一个工作块
```

> 本地模式：不 push。

## 要对抗性验证的（给可复现命令 + 原始输出）

1. **`remain-on-exit` 的时机**：窗口**先持占位命令** → 设选项并**读回** → 才交给 harness。
   自己造一个"harness 秒退"的假 agent：**选项仍必须在**（否则装置与 respawn 之间会漏）。
   **红侧**：去掉"设完读回"那一步 → 断言红。
2. **遗体可读且证据在**：SIGKILL 掉 pane → 窗口仍在、`pane_dead=1`、`pane_dead_signal=9`、
   `capture-pane -S -` 仍能看到最后输出（含**滚出可见屏**的行 —— 自己人为滚一屏验 `-S -` 的必要性）。
3. **死 pane 不是活座位**（这条是本 change 的安全面）：
   - `team say` 对死 pane → 输出**不得**出现已投递字样、**消息 durable 进 `docs/team/inbox/<agent>.md`**、
     **死 pane 画面逐字节不变**（自己前后 sha256 比对）；
   - 复用（`dispatch` / `--fresh` / `resume`）→ `state/dispatch-<agent>-pane-dead.txt` **先出现**且含退出证据与
     最后 N 行；之后**恰好一个窗口**；
   - `teardown --agent` 能删掉遗体窗口。
4. **四态与机器面**：`running` 的**证明规则不得改变**（自己造四种现场：真在跑 / 窗口在但 agent 退了 /
   遗体 / 无窗口），`roster` 三态可辨 + 图例；`status <ID>` 的现场块**标注来源与时间**；
   机器面 `pane`/`pane_exit` 与 `state` 词表不变；`doctor` 一行、`digest` 点名；
   **`close --keep-window` / `teardown` 之后不得再报异常**（噪声判据）。
5. **有界保留**：`TEAM_AGENT_SCENE_LINES` 生效（自己设 3 验行数）；**不许**改 `history-limit`；不新增定时器。
6. **零回归**：FAST + 全量 smoke（**当前 main 上有一条既有 lint 红（`container-tmux.sh` 的 fpcheck 根，P64 在修）**——
   如仍红，点名区分，不算本 change 的回归）。

## 至少三条变异（红→绿原始输出）

- 去掉 `remain-on-exit` 的设置 → 遗体断言红；
- 删掉 `say` 对死 pane 的换道 → "不报已投递 + 落收件箱"红；
- roster 把遗体显示成"在跑" → 四态断言红；
- 还原后 `git status --porcelain` 干净。
