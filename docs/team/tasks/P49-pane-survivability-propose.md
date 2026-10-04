# P49 · 席位窗口不许"无声消失"：死掉的 pane 要留下现场（propose）

```
task:   P49
agent:  （等席位）
issue:
change: agent-pane-survivability
specs:  -
phase:  propose
anchor: change
deltas: watchdog, pm-lifecycle
deps:   M6.5（PM 判活是"证明"而非推断）· 2026-09-22 09:34/09:36 两个席位窗口无声消失（本任务的第一现场）
status: todo（等席位）
budget: 小到中（一个提案包；1–2 条 requirement、5–8 条 scenario）
```

> 本地模式：不 push。**只 propose。**

## 现场（PM 今日实测，提案要引用）

- **09:34:03（dev-bob）与 09:35:57（dev3）两个席位的 pi 会话停止写**；稍后 `team roster` 显示它们
  **`· 无窗口`** —— 窗口没了、pi 进程没了、**pane 的现场也没了**；
- 两个席位当时都有**未提交的工作**（dev-bob 6 个文件、dev3 4 个文件），PM 只能**手工快照提交**保命；
- 排查：**无 OOM**（`journalctl -k` 自 09:30 起 0 条）、**shim 审计在 09:30–09:36 没有任何 tmux 调用记录**
  （09:18 之后最近的一条破坏性记录是 PM 自己的 `kill-window -t teamsmith:dev3`，即 P48 派单的清理），
  所以**"为什么消失"至今没有直接证据**——不是因为没查，而是因为**现场被 tmux 一起带走了**。

## 要裁决的设计问题

1. **让 pane 留下现场**：给 **agent 的窗口**（`team dispatch`/`resume` 启动的那些）设 `remain-on-exit`
   （或等价的"pane 退出后保留 + 可读回显"机制），使 pi 退出/被杀后**窗口仍在**、最后几屏输出可读，
   `team roster`/watchdog/面板能读到"**pi 已退出 + 最后 N 行**"；
   - 要处理：`remain-on-exit` 之后 `team resume`/`dispatch --fresh`/`teardown` 的**语义别退化**
     （重建前要能识别"死 pane"并清理，不许把死 pane 当活席位）；
   - 要裁决 **PM 窗口**是否也设（PM 判活是"证明"路线，改动要谨慎）；
   - 要裁决**保留多久/多大**（pane 回显有上限；给一个界，别让它无限攒内存或把 review 输出淹没）。
2. **可见性的口径**：`team roster` 现有的 `○ 窗口在但 pi 已退出（team resume 可续）` 与新的"死 pane + 现场"
   要合成一个**可机器读**的状态（digest/`--json` 也能看到），且**不改变** M6.5 的判活语义
   （`running` 仍必须是"证明"）。
3. **失败留痕**：死掉的 pane 的最后 N 行要能被 `team status <ID>` 或 doctor 指出来（不要只留在 tmux 里）。
4. **别把"死 pane"变成新噪声**：正常 `teardown`/`close --keep-window` 之后的窗口不该被报成"异常退出"；
   给出判据与反向夹具。

## 硬要求

- policy B：delta 落 `watchdog`（可见性/状态）与 `pm-lifecycle` 或 `dispatch`（启动/重建语义，选一个并说明）；
  每条可证伪、MODIFIED 不删 base scenario；
- 每条 requirement 给复核方法；
- **不写实现**；矛盾 → `BLOCKED:` 交回 PM。

## Deliverables

- `openspec/changes/agent-pane-survivability/{proposal.md,design.md,tasks.md}`
- `openspec/changes/agent-pane-survivability/specs/*/spec.md`
- 报告 `docs/team/reports/P49-<agent>.md`
