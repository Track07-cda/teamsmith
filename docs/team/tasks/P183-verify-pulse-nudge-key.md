# P183 · `pulse-nudge-key` 独立验证（换人：propose=verify、apply=dev）

```
task:   P183
agent:  dev2
issue:
change: pulse-nudge-key
specs:  watchdog#Repeated reminders for the same batch are rate limited
phase:  verify
anchor: change
deltas: -
grant:  docs/team/reports/P183-<agent>.md · docs/team/reports/P183-<agent>/**
deps:   提案 `openspec/changes/pulse-nudge-key/`（已验收 ✓）· 实现 **P174**（dev ✓）· 现场：`nudges.log` 12:42/13:57/14:12/14:27 四拍间隔 15 分钟而 `TEAM_PULSE_NUDGE_GAP=3600` ✓ · D31
status: wip
budget: 一次对抗性验证
priority: 中高（用户抱怨过的噪声；判据容易写成"看着对"✓ —— 所以要有影子 ✓）
```

## 要独立证明或证伪的（**自己造时序**，不要只跑它的夹具）

1. **类别集合不变、计数变** ✅：造"未读通知 1" → "未读通知 4"（同一类 ✓）→ **gap 内不再叫** ✓
   （用一个**很短**的 gap 与一个**很长**的 gap 各测一次 ✓ —— 证明它真的读配置 ✓）。
2. **类别新增** ✅：从"只有未读通知" → "未读通知 + 待复验" → **立刻叫** ✓（不等 gap ✓）。
3. **类别清空后回归** ✅：全清 → 沉默 ✓ → 同一类再次出现 → **再叫** ✓（不许"叫过就不再叫"✗）。
4. **计数照旧可见** ✅：`nudges.log` 与面板/`digest` 里的**计数**必须仍是真实数字 ✓（不许为了去重把计数藏掉 ✗）。
5. **影子（必须有）** ✅：把去重键改回"计数文本" → 用例 1 必须**红** ✓；改成"恒不叫" → 用例 2/3 必须红 ✓。
6. **不许破既有承诺** ✅：`standby` 不叫 ✓、无待办沉默 ✓（P109 ✓）。
7. **门禁**：`openspec validate --all --strict` ✓ + 相关段 ✓ + 容器内 FAST ✓；报告写清原始输出与**没有**测到什么 ✓。
