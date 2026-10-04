# P211 · 看板裁决 `dropped` 的报告不该再算「待复验」

```
task:   P211
agent:  <空出的席位>
issue:
change: -
specs:  -
phase:  apply
anchor: none (infra) — 只改待复验清单的判据与其夹具
deltas: -
grant:  skills/teamsmith/scripts/lib/cmd-status.sh · skills/teamsmith/tests/** · docs/team/reports/P211-<agent>.md · docs/team/reports/P211-<agent>/**
deps:   现场（PM 实测）：看板两行 `V1.1` 都是 **dropped**，而 `team digest` 仍把它列进「待复验 1」并让巡逻叫醒 PM；
        代码里跳过的集合只有 `done|closed`（`cmd-status.sh:182`、`:319`、`:529`），`dropped` 不在其中
status: todo
budget: 小
priority: 中（假待办会一直叫醒 PM；而"看板已裁决"这条规矩本来就有）
```

## 要做的

1. **判据**：`dropped` 与 `done`/`closed` 同等对待（看板已裁决 → 不进待复验清单），三处判断点一致；被跳过的要能**点名**（既有 `team_reports_skipped_by_board` 已做这件事）。
2. **可证伪**：① 造一份报告，看板行 `dropped` → 清单里不出现，且"已按看板跳过"里点名；② 看板行 `wip` → 仍出现（不许一并放过）；③ 影子：把 `dropped` 从集合里去掉 → ① 必须红。
3. **门禁**：`openspec validate --all --strict` + 相关段 + 容器内 FAST；报告点名"哪些自己跑、哪些引用"；**复验换人**。
