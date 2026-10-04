# P109 · 巡逻的"待复验"误报：wip 任务的在写报告不该唤醒 PM

```
task:   P109
agent:  （等席位）
issue:
change: -                        # 无 change：巡检的判据（anchor: none (infra)，见下）
specs:  -
phase:  apply
anchor: none (infra) — 只改 `--actionable` 的判据（一处），不动 digest [3] 的显示口径
deltas: -
grant:  skills/teamsmith/scripts/lib/cmd-status.sh · skills/teamsmith/tests/smoke.sh（append-only 一段）· skills/teamsmith/references/troubleshooting.md（一句）
deps:   D46（门禁自欺的同一族）· M9.8（"草稿不叫醒"的既有先例）· 今天实测三次
status: todo（等席位）
budget: 小
priority: 中（噪声：每 30 分钟把 PM 叫醒一次，而 PM 无事可做）
```

> 本地模式：不 push。

## 现场（2026-09-28，三次）

`team digest` 的 [3] 与 pulse 的唤醒计数把**作者还在写**的报告算成"待复验"：

```
[3] 待复验（真任务报告：…）
  P70-dev2（在 dev2 分支上）（门禁段落自述 apply）  →  team review P70
  P98-dev3（在 dev3 分支上）（门禁分段预算 apply（优先））  →  team review P98
```

而这两条对应的席位**正在跑**（dev2/dev3 的 pi 活着）、任务在看板上仍是 `wip` ✗ —— PM 此刻**动不了**。

## 机理（PM 已读码确认，写在任务里省你时间）

`skills/teamsmith/scripts/lib/cmd-status.sh:126 team_reports_pending_list()` 的 `--actionable` 分支只排除三类：
① 看板 `done|closed`；② **草稿**（`team_report_is_draft`，M9.8 "草稿不叫醒"）；③ 已有**有效且新鲜**的复验记录。
**没有**排除"该任务仍 wip 且归属席位在跑" ✗ —— 作者的 in-flight 报告 `status` 写的是 `delivered`（不是 draft ✓）
→ 通过过滤 → 计数 → 每 `TEAM_PULSE_NUDGE_GAP`（30 分钟）唤醒一次 ✗。

## 要做（只有这一处）

1. `--actionable` 再加一条判据：报告所属任务的看板状态是 `todo|wip` **且** 归属席位进程在跑（`team_agent_live`）→ **不计入**（"PM 现在动不了"，与草稿同一理由 ✓）；
2. **必须保留**的反例：`wip` + 席位**不在跑** → **仍要计数** ✓（那才是真待办：PM 要 `team resume` ✓）；
3. `digest [3]` 的**全量列表**（非 `--actionable`）**照旧显示**这些条目 ✓（只是不唤醒）—— 显示口径不许改；
4. **别动** digest [4] 的"未入账记录"判据（D45/P76 的真风险 ✗ 那是另一条路径）；
5. 夹具（append-only 一段）：wip+在跑 → 不计数；wip+停 → 计数；draft/done → 行为不变；并给**红侧**（把新判据影子掉 → 前者又计数 ✓）；
6. `openspec validate --all --strict` + FAST 绿；报告给**红/绿原始输出**。
