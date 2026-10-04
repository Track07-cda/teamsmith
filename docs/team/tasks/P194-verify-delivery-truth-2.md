# P194 · `delivery-truth` 独立验证（P163 之后，换人）

```
task:   P194
agent:  dev-bob
issue:
change: delivery-truth
specs:  delivery-guard#Queue impediments are factual, bounded and recoverable
phase:  verify
anchor: change
deltas: -
grant:  docs/team/reports/P194-<agent>.md · docs/team/reports/P194-<agent>/**
deps:   P147（实现 ✓）· P157（第一轮验证 ✓，两条 finding ✓）· 返工 **P163**（在 main ✓）· PM 复验（两连跑 ✓ 见合并提交 ✓）· **配方用法**：`bash skills/teamsmith/tests/fixtures/delivery-truth-real/run-case.sh <case> HEAD 0 0.99.2` 在**宿主**上跑（它自己进容器 ✓）；`P163_EVIDENCE=<目录>` 需先按 `fixtures/delivery-truth-real/README.md` 装**钉住的 0.99.2 运行时**（需要网络 ✓ 一次性 ✓）；**不要**用 `--shared` 克隆（容器里解析不到 alternate ✓）
status: todo
budget: 一次对抗性验证
priority: 高（它是 `delivery-truth` 归档的唯一前置 ✓）
```

## 要独立证明或证伪的

1. **F1 现场重置** ✅（P163 修的 ✓）：**连跑两次**同一 case ✓ → 两次的 `run` 戳**不同** ✓、`dev_turns` **都是 2** ✓（不许 4 ✗）；
   **影子**：把"每次重置现场"改成"沿用旧目录" ✓ → 第二次必须红 ✓（或 judge 拒判 ✓）。
2. **判据 fail-closed** ✅：删掉 `run-start.txt` ✓ / 写**两个**戳 ✓ / 留一个**旧** case 目录 ✓ → `judge-second.py` 必须**拒绝出判据** ✓（不许给绿 ✗）。
3. **F2 宿主版本** ✅：1.0.0 真帧用例断言"**扣住且可见报告**" ✓（不是丢失、不是假绿 ✓）；**影子**：把判据 shadow 回"见框内有东西就静默吞掉" ✗ → 该断言必须红 ✓。
4. **P147 的承诺不许破** ✅（抽查 ✓）：几何闭集 ✓、队列终态可见 ✓、notify 三处同名 ✓（各自造一条即可 ✓）。
5. **门禁**：`openspec validate --all --strict` ✓ + 容器内 `--select 57` ✓ + 容器内 FAST ✓；报告写清原始输出与**没有**测到什么 ✓。
