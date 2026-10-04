# P218 · 版本号改成 0.1.0 之后 `install-shape.sh` 的 sed 空转（含一条变成橡皮章的红侧）+ §41 的 `needs` 缺项

```
task:   P218
agent:  dev3
issue:
change: -
specs:  -
phase:  apply
anchor: none (infra) — 修夹具与选段映射
deltas: -
grant:  skills/teamsmith/tests/** · skills/teamsmith/references/** · docs/team/reports/P218-dev3.md · docs/team/reports/P218-dev3/**
deps:   P214 的现场（§39 与 §41 两节）；根因之一是我把版本从 1.42.0 改成 0.1.0（发布决定），**不是夹具作者的错**
status: todo
budget: 小到中
priority: 高（5 条假红 + **一条红侧失去意义**；红侧变橡皮章比假红更危险）
```

## 现场（P214 实测）

- **§39**：`tests/install-shape.sh` 有 **4 处**（`:480,549,606,608`）用
  `sed -i 's/^  version: "1\.42\.0"/  version: "0.0.1"/' …` 把"已装副本"改成漂移版。源树现在是 `0.1.0` →
  **sed 空转** → 副本没被改坏 → `init` 认为"认得出的副本、无冲突" → 5 条断言连带红；
  **更要紧**：`flip ③`（"把 doctor 的 warn 静默掉"）因为前提已经不成立而**红得莫名其妙 —— 它绿不了，也就证明不了任何事**。
- **§41 的 `needs`**：映射表里 §41 的 `needs` 是 `-`，而夹具要的 `$REPO/.pi/team/state/` 由 §2 建；
  `--select 41` 单独跑会 **✓36 ✗67**（级联），`--select 2,41` 才正常。

## 要做的

1. **版本锚点不许写死**：把 4 处 sed 改成**从单一来源取当前版本**（`package.json` 的 `version` 或 `common.sh` 的 `TEAM_VERSION`），改完之后**任何版本号都不再影响这条夹具**。
2. **证明它不是空转**：加一条断言/自检，要求"改坏之后副本的版本**确实**与运行版本不同"（不成立就报"夹具没生效"，而不是继续往下跑）。
3. **恢复 `flip ③` 的承重性**：在正确的漂移副本上，把 doctor 的 warn 静默掉 → 必须红；恢复 → 绿。
4. **`needs` 补上**：§41 的 `needs` 指向它真正依赖的段（§2），并给一条自检：单独 `--select 41` 不再级联（跑完给出 ✓/✗ 与预期一致）。
5. **门禁**：`openspec validate --all --strict` + 容器内 `--select 39,2,41`；报告点名；**换人复验**。
