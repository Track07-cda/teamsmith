# P200 · `18c` 的"退场引用被点名"断言**钉在了临时状态**上（归档后必红）

```
task:   P200
agent:  dev
issue:
change: -
specs:  -
phase:  apply
anchor: none (infra) — 只改一条断言的判据与其红侧
deltas: -
grant:  skills/teamsmith/tests/** · docs/team/reports/P200-dev.md · docs/team/reports/P200-dev/**
deps:   现场：里程碑门禁（冻结 tip `3246e0e6` ✓）`18c` **✓21 ✗1** ✗ ——
        `✗ 18c 被 pending change 退场的引用逐条点名（retired 行）… 没有匹配` ✗，而同段的 `--check` 报 `retired 0` ✓；
        根因：该断言要求**当前**有一批"由未归档 change 退场的引用" ✓ —— 而 `spec-rationale-self-contained` **已归档** ✓ →
        `retired` 从 4 变成 **0** ✓（**这是正确行为** ✓）→ 断言**钉在临时状态**上 ✗
status: todo
budget: 小
status_note: 与 P173 的"探针钉在字面量上"同族：**断言不许依赖"某个 change 还没归档"这种临时状态**
priority: 高（它让**每一次**"归档之后"的全量门禁必红 ✗，而且看起来像产品缺陷 ✗）
```

## 要做的

1. **判据改成机制** ✅：用**自己造的 scratch 树**制造"一个未归档 change 退场了一批引用"的**状态** ✓（在那个副本里放一个带 retired 引用的 change ✓），
   断言"逐条点名" ✓ —— **不依赖**真实仓库里某个 change 恰好还没归档 ✓。
2. **红侧（两条）** ✅：① 把点名逻辑关掉（shadow ✓）→ scratch 用例必须红 ✓；② **真实树**在**任何**归档状态下都绿 ✓
   （即：现在（`spec-rationale` 已归档 ✓）绿 ✓，且**再造一个**未归档的 retired 引用也绿 ✓）。
3. **不许删检查换绿** ✗ —— 若你认为这条断言该删 ✓，给出理由 ✓ 并说明"退场引用被点名"这件事由谁保证 ✓。
4. **门禁**：`openspec validate --all --strict` ✓ + 容器内 `--select 18c` ✓ + 容器内 FAST ✓；报告点名"哪些自己跑、哪些引用" ✓。
