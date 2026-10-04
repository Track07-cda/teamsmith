# P220 · P218 的换人独立验证（版本锚点 + §41 needs）

```
task:   P220
agent:  verify
issue:
change: -
specs:  -
phase:  verify
anchor: none (infra) — 验证 P218
deltas: -
grant:  docs/team/reports/P220-verify.md · docs/team/reports/P220-verify/**
deps:   被验实现**已并入 main**；apply=dev3；你没写过它 —— 合规
status: todo
budget: 小
priority: 中（它保护的是"夹具不许悄悄失效"这条元规则；上一版正是靠人眼才发现）
```

## 要验什么（自己造现场）

1. **锚点跟版本走（决定性）**：在**你自己的** scratch 检出里把版本改成一个**你没见过的值**（例如 `7.3.1-rc2`，改掉 `TEAM_VERSION` 与 `SKILL.md` 两处），跑 §39 —— 必须**仍然全绿**；再改回原版本，同样全绿。
2. **"夹具没生效"必须被点名**：把版本改回一个**与漂移值相同**的写法（或让 sed 的锚点对不上，例如把 `SKILL.md` 里的 `version:` 行缩进改掉），§39 必须**红**并给出"漂移副本没生效/漂移值等于运行版本"这类**点名**，**不许**静默往下跑出一堆别的红。
3. **`needs` 有效**：单独 `--select 41` 必须不再级联（给出 ✓/✗ 数字，并与 `--select 2,41` 对照）。
4. **不误伤**：§39 的原有断言（冲突消息给 `--force` 出路、doctor 行、副本表）在正常路径上仍全绿；§2 不受影响。
5. **影子（≥1 条）**：把"断言副本真的带上漂移值"这一条删掉 → 第 2 项必须红。
6. **门禁**：`openspec validate --all --strict` + 容器内 `--select 39,2,41`（以及你改版本后的那一次）；报告点名"哪些自己跑、哪些引用"；证据包按 D94 留在工作树。
