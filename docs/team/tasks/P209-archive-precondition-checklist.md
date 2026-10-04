# P209 · 归档前置要看**清单**：`tasks.md` 还有未勾项时，`team change status` / 归档必须拒绝

```
task:   P209
agent:  dev2
issue:
change: -
specs:  -
phase:  apply
anchor: none (infra) — 只改归档前置与其夹具
deltas: -
grant:  skills/teamsmith/scripts/lib/** · skills/teamsmith/tests/** · skills/teamsmith/references/** · docs/team/reports/P209-<agent>.md · docs/team/reports/P209-<agent>/**
deps:   **同族第三次** ✗：P151 F3（`dispatch-friction` 23 项 0 勾 ✓）· P175 F3（`safe-signal-discipline` 24 项 0 勾 ✓）· **P206 F1**（`sender-identity-refusal` 16 项 0 勾 ✓）——
        每次都要人发现 ✗ → 机制缺口：`team change status` 只看"映射任务是否完成" ✓、**不看 `tasks.md` 的勾选** ✗
status: done
budget: 小到中
priority: 中高（"事件要变成机制" ✓ —— 否则还会有第四次 ✓）
```

## 要做的

1. **判据** ✅：`team change status <id>` 增加一项 **checklist** 检查 ✓：该 change 的 `tasks.md` 里**未勾项 > 0** → **blockers 里点名**（几条 ✓ + 前三条的行号/标题 ✓）+ **退出码非 0** ✓（与现有 blockers 一致 ✓）。
2. **归档侧** ✅：`openspec archive` 是外部命令 ✗ ✓ → 在**我们**的归档例程/文档里加一道 ✓（`references/openspec.md` 的归档清单 ✓ + `team change status` 的退出码 ✓ 作为前置 ✓）；**不许**去改 openspec 本身 ✗。
3. **可证伪（三条）** ✅：① 造一个 change 有未勾项 → `status` 非 0 且点名 ✓；② 全勾 → 0 ✓；③ **反向**：清单里勾了但映射任务未完成 → 仍然阻塞（既有的那一条 ✓ 不许被新检查顶掉 ✓）。
4. **别误伤** ✗：允许"勾上并注明原因"的项（例如"引用 P206" ✓）—— 检查只数 `[ ]` ✓。
5. **门禁**：`openspec validate --all --strict` ✓ + 相关段 ✓ + 容器内 FAST ✓；报告点名 ✓；**复验换人** ✓。
