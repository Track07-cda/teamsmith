# P199 · `delivery-truth` **再复验**（P197 修完判据与 delta 之后，换人）

```
task:   P199
agent:  verify
issue:
change: delivery-truth
specs:  delivery-guard#Queue impediments are factual, bounded and recoverable
phase:  verify
anchor: change
deltas: -
grant:  docs/team/reports/P199-<agent>.md · docs/team/reports/P199-<agent>/**
deps:   P194 的独立验证（F1 缺 `run-start.txt` 被接受 / F2 同 ID 重复标记被接受 ✓）· 返工 **P197**（在 main ✓）· PM 评审 `docs/team/reviews/P194.md` ✓ · **配方用法**：宿主上跑 `bash skills/teamsmith/tests/fixtures/delivery-truth-real/run-case.sh <case> HEAD 0 0.99.2`（它自己进容器 ✓）；`P163_EVIDENCE=<目录>` 需先按 README 装**钉住的 0.99.2 运行时** ✓；**不要**用 `--shared` 克隆 ✓
status: wip
budget: 一次对抗性验证
priority: 高（`delivery-truth` 归档的唯一前置）
```

## 要独立证明或证伪的

1. **F1 闭合** ✅：删掉 `run-start.txt` ✓ → 判据**必须拒绝**并点名 ✓（不许 PASS ✗）；**影子**：把该检查去掉 → 必须红 ✓。
2. **F2 闭合** ✅：追加**同 ID** 的第二个 `run_start` ✓ → 必须拒绝并点名"几条/第几行" ✓；
   追加**异 ID** ✓、标记**不在第一行** ✓ → 拒 ✓；**影子**：把"恰好一条"改回"集合相等" → 同 ID 那条必须红 ✓。
3. **反向不误伤** ✅：正常现场 ✓ → 照旧出判据 ✓（PASS ✓）。
4. **P163 的承诺抽查** ✅：两连跑现场重置 ✓（两次 `run` 戳不同、每次 2 turns ✓）、宿主 1.0.0 帧"扣住且可见报告" ✓。
5. **门禁**：`openspec validate --all --strict` ✓ + 容器内 `--select 57` ✓ + 容器内 FAST ✓；报告写清原始输出与**没有**测到什么 ✓。
