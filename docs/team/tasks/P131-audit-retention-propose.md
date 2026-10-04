# P131 · 破坏性调用记录的**长保留**（propose）

```
task:   P131
agent:  dev3
issue:
change: destructive-call-forensics      # 名字可由 explorer 改，但必须是"长保留 + 取证"这一件事
specs:  boundary#<你 propose 时新增/修改的那条 requirement>
phase:  propose
anchor: change
deltas: -
grant:  openspec/changes/<id>/** · docs/team/reports/P131-dev3.md · docs/team/reports/P131-dev3/**
deps:   M36/M41 的 tmux 闸门与审计日志（`state/tmux-calls.log` ✓ 有界 1000 行 + `dropped=N` 自报 ✓ M73/P77 ✓）· D57（本项目只做 Skill 内的事 ✓ 不碰外部环境 ✓）
status: todo
budget: 一个提案
priority: 中高（用户选 3A ✓）
```

## 现场（PM 实测）

2026-09-29 查**第 8 次默认 server 死亡**时 ✗：窗口内的 `act≠pass` 记录**已被后续 `pass` 记录挤出**有界日志 ✗
→ "读不到 ≠ 没发生" ✓ 语义没坏 ✓，但**取证能力丢了** ✗✓（同一天两次同形 ✓）。用户裁定：**长保留** ✓。

## 要 propose 的（每条都要**可证伪**）

1. **`act≠pass` 必须长保留** ✓（`refused` / `allowed-owned` / `explicit-flag` / `override` 等，**以现有闭集为准** ✓）：
   存哪 ✓（技能内 ✓ 例如 `state/` 下的独立文件 ✓）、格式 ✓、有界多少 ✓、怎么轮转 ✓、
   与主日志**怎么对齐** ✓（时间戳 + 身份 + 原文 ✓，使两条可互证 ✓）。
2. **写入失败必须可见** ✓（写不进去要报 ✗，**不许静默** ✗）—— 呼应哲学"假绿比没有更糟" ✓。
3. **主日志契约不变** ✓：仍有界 ✓、仍自报 `dropped=N` ✓、现有解析器不变 ✓（MODIFIED 时**不得丢掉基线场景** ✓）。
4. **反向证据** ✓：植入一条 `pass` 记录 → **不承诺**长期保留 ✓（避免"全都留"变成无界增长 ✗）。
5. **跨任务规则** ✓ → 需要 `requirement + scenario` 锚（policy B ✓）；scenario 至少覆盖：
   ① 灌满主日志后**破坏性记录仍在** ✓ ② 长保留文件**有界** ✓ ③ 写入失败**可见** ✓ ④ `pass` 不被承诺 ✓。
6. **非目标** ✓：不改闸门的**判定逻辑**（M67/D36 ✓）；不改 `default` socket 规则 ✓；不做外部环境改动（D57 ✓）。
