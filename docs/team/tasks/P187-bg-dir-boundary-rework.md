# P187 · `safe-signal-discipline` 返工：`state/bg` **目录自身**也必须在项目内（软链目录不许借道）

```
task:   P187
agent:  dev3                        # 本轮的验证者；返工换人做（D31：写的人不验自己 ✓ → 复验另派 ✓）
issue:
change: safe-signal-discipline
specs:  boundary#Signals go to a recorded pid, never to a name or a pattern
phase:  apply
anchor: change
deltas: boundary
grant:  skills/teamsmith/scripts/lib/cmd-bg.sh · skills/teamsmith/tests/** · openspec/changes/safe-signal-discipline/** · docs/team/reports/P187-dev3.md · docs/team/reports/P187-dev3/**
deps:   独立验证 `docs/team/reports/P175-dev3.md`（枚举项 PASS + 枚举外 finding F1' ✓，含实测输出 ✓）· PM 评审 `docs/team/reviews/P175.md`（**我的裁定：按意图要修** ✓）
status: wip
budget: 小到中
priority: 高（同族逃逸 ✓；且它挡着 `safe-signal-discipline` 归档 ✓ → 也挡着 `signal-gate-pgrep` ✓）
```

## F1'（要修）· `bg` 目录是软链时，记录判定自洽而逃出项目

**现场（验证者实测）**：`state/bg` 是软链（指到别处 ✓）→ `dirname(realpath(记录)) == realpath(bg 目录)` ✓ 两边都解析到同一处 ✓ →
**兄弟项目的真进程被停掉** ✓；`bg list` 也列出兄弟记录 ✓。
**非恶意触发**：多 worktree 共享一份 state（把 `state/bg` 指到共享目录 ✓）✓。

## 要做的

1. **目录也要留在项目内** ✅：解析记录之前，先证明 **bg 目录自身**（`realpath` 后）落在**本项目的 state 目录**内 ✓；
   不成立 → **拒绝**（rc=4 ✓ + 明确诊断，点名 `state/bg` 的解析目标 ✓）；
2. **读侧同一收口** ✅：`bg list` 同样不许列软链目录里的记录 ✓（一条规则 ✓ 不许两套 ✗）；
3. **delta 补一条 scenario** ✅（把这条边界**写进契约** ✓，别再是未声明的 ✓）：例如"`state/bg` 解析到项目外时，`bg stop`/`bg list` 都拒绝并点名" ✓；
4. **红侧（三条）**：① `state/bg` 软链到别处 + 一条指向邻居进程的记录 → **拒** ✓ 且**邻居进程仍然活着** ✓；
   ② 反向：正常 `state/bg`（真目录 ✓）→ 照常收作业 ✓（不许误伤 ✓）；③ 影子：把"目录也在项目内"检查去掉 → ① 必须红 ✓；
5. **门禁**：`openspec validate --all --strict` ✓ + 容器内 `--select 58` ✓ + 容器内 FAST ✓；
   报告点名"哪些自己跑、哪些引用 P175" ✓；**复验换人** ✓（不能是你自己 ✓）。
