# agent-pane-survivability · PM proposal review

time: 2026-09-22T11:3xZ · reviewer: pm · verdict: **ACCEPTED**

```
change:  agent-pane-survivability（P49，propose=verify 席位）
tip:     a9055df（task/P49-pane-propose）· validate 21/21
firsthand: 2026-09-22 09:34:03（dev-bob）/ 09:35:57（dev3）两个席位无声消失，现场随 pane 一起没了
```

## Findings

1. **`remain-on-exit` 的设置时机被点明**：窗口先持一条占位命令 → **设选项并读回** → 才把 pane 交给真 harness。
   这条顺序是必须的（否则 `exec` 会与设选项赛跑）✓
2. **只给 agent 窗口**：PM 窗口与 pulse 窗口的形态**不变**，draft 窗口保留它已有的设置 ✓
3. **死 pane 的现场是"可读的遗体"**：`pane_dead=1` + 最后输出**带 scrollback** 可读
   （`capture-pane -S -`；**"可见屏会丢最后一行"是实测过的**）+ tmux 的退出证据
   （`pane_dead_status/signal/time`）✓
4. **保留有界、且不靠定时器**：每个席位窗口**至多保留一个**遗体（下一次 `dispatch`/`resume` 先抓现场再替换）、
   scrollback 由宿主的 `history-limit` 决定（**不放大也不收窄**）、抓取的副本由
   `TEAM_AGENT_SCENE_LINES`（默认 40）界定 ✓
5. **一个真实的陷阱被抓出来**：死 pane 的**前台命令名看起来仍像在跑**，而 tmux 的 `send-keys`
   **会成功但文字落进虚空** ——所以 `team say`/敲打投递必须**按 pane 是否 dead 判定**，
   不得报"已投递"，消息**durable 落进 `docs/team/inbox/<agent>.md`**，输出点名座位已死并带上退出证据 ✓
6. **复用前先抓现场**：`state/dispatch-<agent>-pane-dead.txt`（座位/窗口/时间/退出证据/最后 N 行），
   文案也从"打断一轮"改成"上一个 pane 已死"；三个命令复用后**仍恰好一个窗口**；`teardown` 照旧能删 ✓
7. **四态可读**（watchdog）：`running`/`exited`/`dead`/`absent`，**`running` 的证明规则一字不改**；
   `roster` 三态可辨、legend 说明；`status <ID>` 打印座位状态 + 退出证据 + 最后 N 行（标注来源与时间，
   来源按新旧排序）；机器面新增 `pane`（live/dead）与 `pane_exit`，**`state` 词表不变**（不给消费者假话）✓
8. **异常只在"该席位还有未结束的登记任务"时成立**：`close --keep-window`/`teardown` 之后
   digest/doctor/pending **不得**再报异常（避免把正常收尾变成常驻噪声）✓
9. 它还带了一个**私有 socket 的 tmux 探针**（P1–P10）来量这些 tmux 事实——本提案的前提是量出来的 ✓

## 结论

**ACCEPTED**。apply 排在 P47（ledger-and-gate-noise）之后（都要动 `cmd-status.sh`/`cmd-watch.sh` 的席位面）；verify 换人。
