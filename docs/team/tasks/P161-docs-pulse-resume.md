# P161 · 文档更正：巡检**会**在席位停了但任务未结束时自动派单续跑

```
task:   P161
agent:  <下一个空出的席位>
issue:
change: -
specs:  -
phase:  apply
anchor: none (infra) — 只改文档，零行为
deltas: -
grant:  skills/teamsmith/references/** · skills/teamsmith/SKILL.md · docs/team/reports/P161-<agent>.md · docs/team/reports/P161-<agent>/**
deps:   D82（代码行 `cmd-watch.sh:274–278` + `watchdog.log` 的 `resume agent=…` 实测 ✓）· 我 2026-09-23 的撤回是**错的** ✓（要写进文档而不是留在我脑子里 ✓）
status: todo
budget: 小
priority: 中（文档与代码不一致会让下一次"发现"又被误撤回 ✓）
```

## 要做的

1. 找到所有"巡检/看门狗**不**管理 agent / 不碰布局"的说法 ✓（`references/**`、`SKILL.md`、`protocol.md` ✓ —— 用 grep 找 `不管理|does not manage|never resumes|不重启` ✓），
   改成**准确的**一句 ✓：巡检**不会创建/重建会话** ✓，但在**席位停了且其任务未结束**时**会自动派单续跑** ✓（`cmd-watch.sh:274–278` ✓），
   且**standby 时不动** ✓（若代码确有此门 ✓ —— 请核实后照实写 ✓）。
2. 在 `references/protocol.md` 里给出**判据与证据形态** ✓：`watchdog.log` 的 `resume agent=<a> task=<id>` 行 ✓、
   以及"不想让它自动拉起来"的做法 ✓（若存在开关就写开关 ✓，若不存在就**写明不存在** ✓ 并记为候选 ✓）。
3. **零行为改动** ✓（只改文档 ✓）；跑相关文档检查段 ✓ + `openspec validate --all --strict` ✓（不用全量 ✓）。
