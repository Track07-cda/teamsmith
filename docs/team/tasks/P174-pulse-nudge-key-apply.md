# P174 · `pulse-nudge-key` apply：叫醒的去重键按**类别集合**算（计数照旧显示，但不参与去重）

```
task:   P174
agent:  dev
issue:
change: pulse-nudge-key          # 提案已验收并合入 main
specs:  watchdog#Repeated reminders for the same batch are rate limited
phase:  apply
anchor: change
deltas: watchdog,panel
grant:  skills/teamsmith/scripts/lib/** · skills/teamsmith/tests/** · openspec/changes/pulse-nudge-key/** · docs/team/reports/P174-<agent>.md · docs/team/reports/P174-<agent>/**
deps:   `openspec/changes/pulse-nudge-key/{design,tasks}.md`（照它的 D1–D4 做 ✓）· P172 的证据包 ✓ · **PM 现场**：`nudges.log` 12:42 / 13:57 / 14:12 / 14:27 四拍，间隔 15 分钟 ✗，而 `TEAM_PULSE_NUDGE_GAP=3600` ✓
status: wip
budget: 一个工作块
priority: 中高（用户抱怨过的噪声；且它是"计数一变就当新一批"这一类）
```

## 交付 = `tasks.md` 全部做完，**三条红侧**各自留原始输出

1. **键 = 类别集合** ✅：正类别名按既有字段顺序序列化 ✓（空集合要有明确表示 ✓）；
   **计数照旧**进日志/文本/`pending` JSON ✓（不许把计数从可见面拿掉 ✗）。
2. **红侧三条**：
   ① **类别不变、计数 1→4** → gap 内**不再叫** ✓（今天的现场 ✓）；
   ② **类别新增一类**（例如多出"待复验"）→ **立刻叫** ✓；
   ③ **类别清空后再次出现** → **再叫** ✓（不许"叫过就不再叫"✗）。
3. **不许破既有承诺** ✅：`standby` 期间不叫 ✓、无待办沉默 ✓（P109 那两条不许破 ✓）。
4. **门禁**：`openspec validate --all --strict` ✓ + 相关段（`3`/`3b`/巡检相关 ✓）+ FAST ✓；
   报告点名"哪些自己跑、哪些引用 P172" ✓；**复验换人** ✓。
