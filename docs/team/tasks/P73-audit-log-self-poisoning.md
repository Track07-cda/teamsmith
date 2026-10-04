# P73 · 门禁的隔离扫描会被**自己的审计日志**毒化（`state/tmux-calls.log`，append-only）

```
task:   P73
agent:  （等席位）
issue:
change: gate-isolation-scan-scope
specs:  -
phase:  propose
anchor: change
deltas: verification, boundary
deps:   M36/M67（tmux shim 的审计日志）· M30/12b-j（夹具痕迹扫描）· D45
status: todo（待派）
budget: 小
```

> 本地模式：不 push。**先 propose。**

## 现场（PM 实测，2026-09-22 17:9x）

PM 在 main（已含 P64）上跑 FAST smoke：**`✓2394 ✗1`**，唯一红是

```
✗ 12b-j 隔离：调用方项目的 inbox/state 里没有夹具痕迹（期望 [none]，
  实际 [/…/pm-skills/.pi/team/state/tmux-calls.log]）
```

**根因（已定位）**：dev3 在做 P67 时跑**它自己的假 TUI 夹具**，那些 `tmux new-session/new-window/kill-session`
调用经过 **M36 的 PATH shim**（它在我们的窗口里），shim 把**调用者项目的** `state/tmux-calls.log` 写了两行：

```
17:10:34 sock=/tmp/tmp.OMlJiwDCca/sock/… argv=new-window -d -t p67faketui-45652 …
17:10:39 sock=/tmp/tmp.MHFvqs0nYY/sock/… argv=kill-session -t p67faketui2-62396 … cwd=…/.worktrees/dev3
```

而 `12b-j` 的扫描函数 `real_ledger_hits` 是 **grep 整棵 `.pi/team/state`（只排除 `bg/`）**、
`tmux-calls.log` 又是 **append-only** → **任何人做过一次含夹具字样的 tmux 调用，之后每一轮 smoke 都会红**
（我把 log 里那两行删掉后重跑就好；不删就一直红）。

## 要裁决的

1. **扫描的作用域**：夹具痕迹扫描只应看"**消息/状态记录**"（`docs/team/inbox/**`、`state/` 下的**夹具会写坏的**那些），
   还是也该把**调用审计日志**算进去？给出取舍并论证（要点：审计日志是"谁调了什么"的**记录**，
   不是夹具产出的**状态**；M30 那类泄漏是后者）。
2. **审计日志自身的卫生**：append-only 无上限也会长（今天已 ~1000 行）；要不要**轮转**（保留 N 行/N 天）
   或分片（按 session/caller）？给一个界与理由，并保证**不丢取证能力**（D39 的现场通道依赖它）。
3. **可证伪**：① 往 `state/tmux-calls.log` 里栽一行含夹具字样的记录 → **新口径必须不红**（该文件不在扫描面），
   但**往 `docs/team/inbox/**` 或 `state/` 的真状态里栽** → **必须红**（负对照仍有效）；
   ② 审计日志超过轮转上限 → 老行被裁掉、新行保留（不丢最近取证）。
4. **不许**为了变绿而放宽 M30/12b-j 的**真**泄漏检测（负对照必须照旧能红）。

## 硬要求

- policy B：delta 落 `verification`（扫描口径）+ `boundary`（审计日志的卫生）；
- 可证伪 + 复核方法；**不写实现**；矛盾 → `BLOCKED:` 交回 PM。
