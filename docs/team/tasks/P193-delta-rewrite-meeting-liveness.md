# P193 · 重写 `meeting-liveness` 的 delta（归档基线已前进）

```
task:   P193
agent:  dev
issue:
change: meeting-liveness
specs:  meeting#A knock names the turn it announces
phase:  apply
anchor: change
deltas: meeting,notify-and-inbox
grant:  openspec/changes/meeting-liveness/** · docs/team/reports/P193-<agent>.md · docs/team/reports/P193-<agent>/**
deps:   `capacity-floor-disk` / `dispatch-friction` **已归档** ✓ → `panel` 基线前进 ✓ → 本 change 的 delta 不匹配 ✗；**P160 的返工已合入 main** ✓ → 代码就位 ✓ → 本任务**只改 delta 文本** ✓。归档还差 **P182** 的换人复验 ✓。
status: wip
budget: 小（机械 ✓）
priority: 中高（它挡住 `meeting-liveness` 归档 ✓）
```

## 要做的

1. 读当前基线 ✓，把 delta 重写到对齐 ✓（同 P192 的口径 ✓：MODIFIED 文本 = 基线现状 + 本 change 改动 ✓；ADDED 不重名 ✓；**scenario 一个不丢** ✓ —— 与归档前的版本对照 ✓）。
2. **保留**已定的契约（发现性 ✓、过期可关 ✓、投递安全（忙则排队并如实报 ✓）、身份按记录名并集 ✓、`task=`/`tip=` 的 12 位标识 ✓）✓ —— 不许放松 ✗。
3. **验收**：`openspec validate meeting-liveness --type change` ✓ + `validate --all --strict` ✓ + scratch 预演 `archive -y meeting-liveness` ✓ 成功 ✓（临时克隆 ✓ 用完删 ✓）；报告给 scenario 计数对照 ✓。
