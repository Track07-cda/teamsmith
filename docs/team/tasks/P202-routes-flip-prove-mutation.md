# P202 · `routes.sh` 的翻转② 没有兑现：**夹具的变异可能没落地**（M21 那一族）

```
task:   P202
agent:  dev
issue:
change: -
specs:  -
phase:  apply
anchor: none (infra) — 只改夹具的翻转与其自证
deltas: -
grant:  skills/teamsmith/tests/routes.sh · skills/teamsmith/tests/** · docs/team/reports/P202-dev.md · docs/team/reports/P202-dev/**
deps:   现场：**发布前最终门禁**（冻结 tip `8ca694c` ✓）`51` 段 **✓1 ✗1** ✗ ——
        `✗ 翻转②没有兑现（rc=1）：… ✗ 断言 L38：add-agent --fresh 被自己的解析器拒绝（原文：✗ add-agent: 未知参数 --fresh）` ✗；
        **PM 实测**：在**真树**上照 `routes.sh:1330` 的 sed 做同样的变异 ✓ → `routes.sh walk` **rc=1** ✓ 且日志里**有** `add-agent --fresh` ✓
        → 也就是说**真树上变异有效** ✓，而翻转②在**它自己的 scratch 树**里**没有兑现** ✗ → 夹具的变异**可能没落地** ✗（M21 的"补丁静默 no-op"同族 ✓）
status: todo
budget: 小
priority: **高（发布阻塞项）**
```

## 要做的

1. **定位** ✅：查 `mr_scratch_tree`（`routes.sh` 顶部 ✓）给翻转②的那份副本**是否**包含当前形状的 `cmd-project.sh` ✓
   （`sed` 模式 `add-agent <a> \[--register\]` ✓ 与副本里的**实际文本**逐字比 ✓）；给出**它为什么没兑现**的确切原因（行号 ✓）。
2. **修** ✅：让翻转②的变异**在它的树上确实生效** ✓，且判据仍是"walk 红并点名 `add-agent --fresh`" ✓（不许放松 ✗）。
3. **加一条**（**M21 的教训，本任务的真正价值**）✅：**每个翻转在判红之前必须先证明自己的变异落地了** ✓ ——
   例如：变异后 `grep -c` 目标文本由 1 变 0 ✓ / 由 0 变 1 ✓，**不成立就报"变异没落地（夹具缺陷）"** ✗ 而不是报"没兑现" ✗。
   给这一条**自己的红侧** ✓（故意写一个不匹配的 sed → 必须报"变异没落地" ✓）。
4. **门禁**：`openspec validate --all --strict` ✓ + 容器内 `--select 51` ✓ + 容器内 FAST ✓；报告点名"哪些自己跑、哪些引用 PM 的实测" ✓；**复验换人** ✓。
