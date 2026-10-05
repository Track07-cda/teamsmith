# P225 · P222 的换人独立验证（机器生成面 / 证据层缺席的跳过 + 文档更正）

```
task:   P225
agent:  verify
issue:
change: -
specs:  -
phase:  verify
anchor: none (infra) — 验证 P222
deltas: -
grant:  docs/team/reports/P225-verify.md · docs/team/reports/P225-verify/**
deps:   被验实现**已并入 main**（`73ae5a77`）；apply=dev；你没写过它 —— 合规。
        **注意**：这条改动把 16 条红变成**跳过**，所以它的风险方向是"跳过把真问题一起吞掉"。
status: todo
budget: 中
priority: 高（它决定公开仓 CI 能不能有信誉；判松了就是"红改成跳过"的自欺）
```

## 要验什么（**自己造形状**，别复用 §36 的探针断言）

1. **三个形状各跑一遍**（自己构造，不要用它的 scratch 目录）：
   - **公开混合**：账本/`openspec/changes`/`AGENTS.md`/`SCOPE.md` 在，`.pi/prompts`、`.pi/skills`、证据层不在 → §19/§31/§58/§36 必须**零红**，且跳过**逐条点名**缺的是哪一类（把点名行抄进报告）。
   - **完整内部**：把 `.pi/prompts`（五个 `opsx-*.md`）与 `.pi/skills`（五个 `openspec-*`）放回去 → 同一批断言必须**照旧判定**（给出 ✓/✗ 数字，证明它们真的执行了，不是跳过）。
   - **纯产品面**：六个内部面都不在 → P148 的既有行为不变。
2. **救生通道必须双向可证伪**：
   - 把两个 lint 的**全部注册文件**从仓外归档复原进树里（`pm-skills-ledger/team/reports/**`，共 17 个）→ 两个 lint **必须判定**（不再跳过）；先核对 sha256 是否与清单相符；
   - 再**篡改其中一条**（追加一行）→ 基线**必须判红**并点名该文件。
3. **牙齿（最关键）**：在**公开混合形状**里往**夹具**（`skills/teamsmith/tests/**`）追加裸 `tmux kill-server` 与 `pkill -f` → §31/§58 **必须各红一条**并点名 `file:line`。这条不成立就是"把红改成跳过"的自欺，直接判 FAIL。
4. **形状探针**：`checkout-shape-probe.sh` 自己跑一遍（它在 §36 里被驱动），确认它的牙齿断言仍在（产品文件里的 `pkill -f` 照旧判红、缺失的产品面条目照旧判红、以及那条影子）。
5. **文档**：核对 README 与 `references/openspec.md` 的说法与**钉住的 1.8.0 实际生成物**一致（自己跑 `openspec init --tools pi` 到一个 scratch 目录里数一数生成了什么；`openspec config list` 打印的 profile 是什么）。
6. **门禁**：`openspec validate --all --strict` + 容器内 §19/§31/§58（§36 约 12 分钟，若跑就报时间）；报告点名"哪些自己跑、哪些没跑"；证据包按 D94 留在工作树。
