# P198 · 重写 `delivery-truth` 的 delta（MODIFIED 少了基线已有的 scenario）

```
task:   P198
agent:  dev
issue:
change: delivery-truth
specs:  delivery-guard#Queue impediments are factual, bounded and recoverable
phase:  apply
anchor: change
deltas: delivery-guard
grant:  openspec/changes/delivery-truth/** · docs/team/reports/P198-dev.md · docs/team/reports/P198-dev/**
deps:   `openspec validate delivery-truth --type change` 报 **MODIFIED「An automated send never types into a non-empty input box」omits scenario(s) the current baseline has** ✓（基线被更早的归档推进过 ✓）· 代码早已在 main ✓（P147 ✓）→ **只改 delta 文本** ✓
status: todo
budget: 小
priority: 高（它挡住 `delivery-truth` 归档 ✓，而该 change 还在等 P197 的判据返工 ✓ → 两条并行 ✓）
```

## 要做的

1. 读**当前**基线 `openspec/specs/delivery-guard/spec.md` ✓，把该 MODIFIED requirement 的**全部基线 scenario** 抄进来 ✓（**一条不许少** ✗）+ 本 change 的改动与新增 ✓；
2. 保留本 change 已定契约 ✓（几何闭集 ✓、队列终态可见且可恢复 ✓、notify 三处同名 ✓）✓；
3. **验收**：`openspec validate delivery-truth --type change` ✓ 通过 ✓ + `openspec validate --all --strict` ✓ **无新错** ✓；
   scratch 预演 `archive -y delivery-truth` ✓ 成功 ✓（临时克隆 ✓ 用完删 ✓）；报告给 scenario 计数对照（前/后 ✓，证明不丢 ✓）。
