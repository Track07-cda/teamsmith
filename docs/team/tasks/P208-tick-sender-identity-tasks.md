# P208 · `sender-identity-refusal` 收尾：按事实勾选 16 项清单（归档前置）

```
task:   P208
agent:  dev                         # 它是 apply 作者 ✓（别人代勾会失真 ✗）
issue:
change: sender-identity-refusal
specs:  -
phase:  apply
anchor: change
deltas: -
grant:  openspec/changes/sender-identity-refusal/tasks.md · docs/team/reports/P208-dev.md · docs/team/reports/P208-dev/**
deps:   独立验证 `docs/team/reports/P206-verify.md`（行为 PASS ✓ + F1 ✓）· PM 评审 `docs/team/reviews/P206.md` ✓
status: done
budget: 十分钟
priority: 高（它是该变更归档的唯一前置）
```

## 要做的

1. **逐条按事实勾选** ✅ `openspec/changes/sender-identity-refusal/tasks.md` 的 16 项（1.1–1.3 ✓ 2.1–2.5 ✓ 3.1–3.2 ✓ 4.1–4.4 ✓ 5.1–5.2 ✓）：
   **你亲跑过的** → `[x]` ✓；**只引用别人证据、自己没跑的** → 勾上但**注明"引用 P206"** ✓（不许假装亲跑 ✗）；**没做也做不了的** → 写明原因 ✓。
2. **重跑**受影响段落 ✓（`--select 47` ✓）+ `openspec validate --all --strict` ✓ + 容器内 FAST ✓。
3. 报告只写这三件事的结果 ✓；**复验换人** ✓（这次由 verify 抽查勾选是否与证据相符 ✓ —— 不重跑全部 ✓）。
