# P172 · `pulse-nudge-key` propose：叫醒的**去重键**按"哪一类待办"算，不按**计数文本**算

```
task:   P172
agent:  verify                        # propose 只写 openspec/changes/**（不违反 D36）
issue:
change: pulse-nudge-key
specs:  watchdog#The patrol only wakes the PM when there is pending work
phase:  propose
anchor: change
deltas: watchdog,panel
grant:  openspec/changes/pulse-nudge-key/** · docs/team/reports/P172-verify.md · docs/team/reports/P172-verify/**
deps:   `TEAM_PULSE_NUDGE_GAP=3600`（2026-09-28 起 ✓）· **现场（PM 2026-10-02 实测）**：12:42「未读通知 1」✓ → 13:57「未读通知 3」✓ → 14:12「未读通知 4 · 待复验 1」✓ → 14:27「未读通知 4」✓ —— **间隔 15 分钟** ✗（远小于配置的 3600s ✓）；同一批活儿的**计数一变，文本就变** ✗ → 去重键失效 ✗
status: wip
budget: 一个提案
priority: 中高（用户明确抱怨过"每 15 分钟叫一次" ✓；且这是"计数噪声"这一类 ✓）
```

## 现场（我实测）

`nudges.log`：`12:42:34 未读通知 1` · `13:57:35 未读通知 3` · `14:12:35 未读通知 4 · 待复验 1` · `14:27:35 未读通知 4`
→ 配置 `TEAM_PULSE_NUDGE_GAP='3600'`（`config.sh:64` ✓，审计日志里 2026-09-28 从 1800 改到 3600 ✓）却**没起作用** ✗。
机制猜测（你核实 ✓）：去重键是**提醒文本** ✓ → 收件箱计数一变（每条 worker 回执 +1 ✓）文本就变 ✓ → 每拍都是"新的一批" ✗。

## 要 propose 的（**可证伪**，且**不许**把"该叫醒"一起压掉）

1. **先量**：读 `cmd-watch.sh` 的 nudge 生成与去重路径 ✓，给出**确切**的键是什么 ✓（行号 ✓）与 `nudges.log` 的写入条件 ✓。
2. **改键的语义** ✅：键应是"**哪几类待办**（如 `inbox>0` ✓ `reports>0` ✓ `stopped>0` ✓ `meetings>0` ✓）"的**集合** ✓，
   **不是**具体计数 ✗；计数仍要出现在**文本**里 ✓（读者需要知道几条 ✓），但它不参与去重 ✓。
3. **不许把真事压掉** ✅：**类别集合发生变化**（例如从"只有未读通知"变成"未读通知 + 待复验"✓）→ **必须**立刻叫 ✓；
   类别集合不变、只是计数涨了 → **按 gap 压** ✓（这就是本次要修的噪声 ✓）。
4. **可证伪（三条）**：① 类别不变、计数 1→4 → **gap 内不再叫** ✓；② 类别新增一类 → **立刻叫** ✓；
   ③ 类别清空再回来 → **再叫** ✓（不许"叫过就不再叫"✗）。
5. **边界**：`standby` 期间照旧不叫 ✓；无待办照旧沉默 ✓（P109 的既有承诺不许破 ✓）。
6. 交付：`openspec/changes/pulse-nudge-key/{proposal,design,tasks}.md` + `specs/{watchdog,panel}/spec.md` ✓ +
   `openspec validate --all --strict` ✓ + MODIFIED 不丢基线场景（前后对照 ✓）+ 每条 What flips 有红侧 ✓。
