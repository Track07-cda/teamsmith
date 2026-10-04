# P192 · 重写 `pulse-nudge-key` 的 delta（归档基线已前进）

```
task:   P192
agent:  dev
issue:
change: pulse-nudge-key
specs:  watchdog#Repeated reminders for the same batch are rate limited
phase:  apply
anchor: change
deltas: watchdog,panel
grant:  openspec/changes/pulse-nudge-key/** · docs/team/reports/P192-<agent>.md · docs/team/reports/P192-<agent>/**
deps:   `capacity-floor-disk`（2026-10-02 ✓）与 `dispatch-friction`（2026-10-02 ✓）**已归档** → 它们改过 `panel` 的基线 ✓ → 本 change 的 delta（当时按旧基线写 ✓）现在**不匹配** ✗（`openspec validate pulse-nudge-key` 报 delta 解析失败 ✓）。**代码早已在 main** ✓（P174 ✓）→ 本任务**只改 delta 文本** ✓，不许碰实现 ✗。
status: wip
budget: 小（机械 ✓）
priority: 高（它挡住 `pulse-nudge-key` 归档 ✓）
```

## 要做的

1. 读**当前**基线 `openspec/specs/panel/spec.md` 与 `openspec/specs/watchdog/spec.md` ✓，把本 change 的 delta **重写**到与它们**逐条对齐** ✓
   （MODIFIED 的 requirement 文本 = 基线现状 + 本 change 的改动 ✓；ADDED 的不得与基线重名 ✓；**不许丢**本 change 原有的任何 scenario ✓ —— 与 `git show <归档前的分支>:openspec/changes/pulse-nudge-key/...` 对照 ✓）。
2. **保留**本 change 已定的契约（类别集合去重 ✓、空拍重置 ✓、计数仍可见 ✓、`standby` 不叫 ✓）✓ —— 一个字都不许放松 ✗。
3. **验收**：`openspec validate pulse-nudge-key --type change` ✓ 通过 ✓ + `openspec validate --all --strict` ✓ 无新错 ✓；
   **scratch 预演** `openspec archive -y pulse-nudge-key` ✓ 必须成功 ✓（在 `/tmp` 的临时克隆里做 ✓，做完删掉 ✓）；
   报告给出：重写前后 delta 的 scenario 计数对照 ✓（证明没丢 ✓）。
4. 报告点名"哪些自己跑、哪些引用" ✓。
