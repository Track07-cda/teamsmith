# V102 · 独立复验 `turn-notice-in-pm-inbox` 的 5.1–5.4

task: V102
agent: dev-bob
phase: verify
category: verify
change: turn-notice-in-pm-inbox
specs: notify-and-inbox#A turn-end notification appends one inbox line and knocks once
anchor: none (infra) — change 自带 delta
deltas: -
branch: task/V102-turn-notice-verify

## 受检

`turn-notice-in-pm-inbox` 的实现（A1 = P364、A2 = P365、夹具 = P368）都已并入 main 并由 V96/V98/V99 验过。
要勾的是清单 `5.1–5.4` 四条**复验项**。

## 要做的

1. **5.1**：在自己的克隆上定点**执行** `--select 7,13,25`（不是查表），贴结果行与**新增断言的原文**
   （A1 的指针行三条、A2 的账行与 digest 两行）。
2. **5.2**：反向对照只做两条（其余由 apply 阶段的红侧表覆盖，别重复）：**R4**（合并时取新事件的 `knock=` →
   已敲门的 run 被扩展后显示成被跳过，必须红）与 **R6**（指针行改写记录行 → 记录行字节对照必须红）。
3. **5.3**：`openspec validate --all --strict`、`spec-refs.sh --check`、`spec-refs.sh --flips`、账本禁令、`git diff --check`。
4. **5.4**：写 `docs/team/reviews/turn-notice-in-pm-inbox.md`（命令、输出尾部、判定、未测项说明）。

## 边界

只读代码、破坏只在 `/var/tmp` 私有副本、只写那份 review 与自己的线程。不跑整套；清单条目**不要勾**，交 PM。
结论先写 PASS/PARTIAL/FAIL。
