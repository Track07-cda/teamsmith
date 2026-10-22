# V99 · P368 的独立验收（轻量）：两条断言按新契约量流量了吗

task: V99
agent: dev
phase: verify
category: verify
change: turn-notice-in-pm-inbox
specs: notify-and-inbox#A turn-end notification appends one inbox line and knocks once
anchor: none (infra) — 夹具判据
deltas: -
branch: task/V99-bg-ledger-verify

## 受检

候选 `38ee09b7`（报告 `docs/team/reports/P368-dev3.md`）。它声称：两条断言改成按新契约量流量（指针行 / `[manual]` 行），
**A1 的计数判据一个字没动**；合并语义仍在记录行与指针行两处验；`merge`/`detail` 折进 `§13c` 的 bg-ledger 子集，
**去掉这两个键该段可见地红**（实测 ✗2）。读数：`--select merge,detail` 22/0、全套八组 220/0、`--select 13c` 463/0、`--select 13` 67/0。

## 要回答的三件

1. **契约没被偷偷改回去**：`git diff main 38ee09b7 -- skills/teamsmith/scripts` 必须**为空**（A1 的计数判据在产品侧，
   夹具不该动它）；若产品侧有改动，点名。
2. **两条断言现在量的是流量而不是记录**：读改动，指出它们现在各用哪一行来量（指针行还是 `[manual]`），
   并自己造现场确认：`[auto] agent:<本文件席位>` 的行**不**让未读 +1，而**指针行**让它 +1。贴读数。
3. **承接缺口真的补上了**：把 `merge`/`detail` 从 `§13c` 子集里去掉 → `--select 13c` 必须**可见地红**并点名
   （不是静默少跑）；还原必须绿。这条是本轮唯一能防「以后又悄悄漏跑」的东西。

## 边界

只读代码、破坏只在 `/var/tmp` 私有副本、只写 `docs/team/reports/V99-dev.md` 与自己的线程。跑 `--select merge,detail`
（bg-ledger 直跑）与 `--select 13c` 各一次即可，**不跑整套**。结论先写 PASS/PARTIAL/FAIL。
