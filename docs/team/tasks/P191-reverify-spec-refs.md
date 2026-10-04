# P191 · `spec-rationale-self-contained` 换人复验（P185 修了 F1/F2 之后）

```
task:   P191
agent:  verify
issue:
change: spec-rationale-self-contained
specs:  boundary#Specs are the contract, and a published spec stands on its own
phase:  verify
anchor: change
deltas: -
grant:  docs/team/reports/P191-<agent>.md · docs/team/reports/P191-<agent>/**
deps:   第一轮 `docs/team/reports/P184-verify.md`（F1 通配行吞具体引用 / F2 畸形行静默丢弃 ✓）· 返工 **P185**（在 main ✓）· PM 复验（四条变异 ✓）· D31
status: wip
budget: 一次对抗性验证
priority: 中高（它是该 change 归档的唯一前置 ✓）
```

## 要独立证明或证伪的（**自己造变异**）

1. **F1** ✅：往声明表里加一条**通配** `ledger` 行（如 `docs/team/reports/P191*.md` ✓）→ 走查必须**拒绝加载**并点名表名+行号 ✓；
   再确认**具体引用**按**确切相等**判 ✓（不是正则 ✓）：造一条只差一个字符的引用 ✓ → 未声明 ✓ 红 ✓。
2. **F2** ✅：缺列 ✓、`basis` 空 ✓、`kind` 非法 ✓ 三种畸形行各一条 → 必须**拒绝并点名行号** ✓（不许静默丢弃 ✗）。
3. **影子（两条）** ✅：把"通配即拒"改成"通配照收" → 用例 1 必须红 ✓；把"畸形行即拒"改成"忽略" → 用例 2 必须红 ✓。
4. **不误伤** ✅：本树绿 ✓（99 条引用/0 未声明 ✓）；合法 `slot` 行（含 `<…>` ✓）与 `ledger`/`example` 行照旧工作 ✓。
5. **门禁**：`openspec validate --all --strict` ✓ + 相关段（`18c` ✓）✓ + 容器内 FAST ✓；报告写清原始输出与**没有**测到什么 ✓。
