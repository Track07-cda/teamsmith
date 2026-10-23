# V104 · 定点补验：`turn-notice` 里那处「同席位既实现又复验」的账

task: V104
agent: dev-bob
phase: verify
category: verify
change: turn-notice-in-pm-inbox
specs: notify-and-inbox#A turn-end notification appends one inbox line and knocks once
anchor: none (infra) — 定点补验
deltas: -
branch: task/V104-p368-spot

## 为什么有这一单

`team change status turn-notice-in-pm-inbox` 给 V99 打了一个标记：`self-verify: dev（作者任务 P373）` ——
V99（复验 P368 的 `bg-ledger` 夹具改动）的执行席位是 `dev`，而 `dev` 后来又做了本 change 的 `P373`。
**同一席位在同一 change 里既实现又复验**，这是团队硬规矩的反例，账是我派单时没查引起的。

不重开 V99 的结论（它验的是 P368 的夹具契约，与 P373 的红侧是两件事），只做一次**定点补验**把这个缺口补上。

## 要做的（很窄）

1. **P368 的核心主张**自己复现一次：`bg-ledger --select merge,detail` 绿；把 `merge`/`detail` 从 `§13c` 的
   bg-ledger 子集里去掉 → `--select 13c` 必须**可见地红并点名**（不是静默少跑）；还原必须绿。
2. **A1 的计数契约**抽查一条：`[auto] agent:<本席>` 的行**不**让该席位未读 +1，而**指针行**让它 +1（造现场读两个数）。
3. 在 `docs/team/reviews/turn-notice-in-pm-inbox.md` 末尾追加一节 `## 定点补验（V104）`：结论 + 两处读数 + 一句
   「V99 的结论仍成立，本单只补『同席位』这个纪律缺口」。

## 边界

只读代码、破坏只在 `/var/tmp` 私有副本、只写那份 review 记录末尾一节与自己的线程。不跑整套、不跑容器。
结论写 PASS / FAIL。
