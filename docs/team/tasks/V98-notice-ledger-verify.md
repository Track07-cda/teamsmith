# V98 · P365（A2）的独立验收：结果账与 digest 的两行

task: V98
agent: verify
phase: verify
category: verify
change: turn-notice-in-pm-inbox
specs: notify-and-inbox#A notice whose knock was skipped is recorded with its reason and named by digest
anchor: none (infra) — change 自带 delta
deltas: -
branch: task/V98-notice-ledger-verify

## 受检

候选 `412b7e32`，报告 `docs/team/reports/P365-dev2.md`。自跑 `--select 7,13,25` = `✓234 ✗0`，含五处红侧。

它自报三件要 PM 知的（**PM 已裁**）：F1 是 `bg-ledger.sh` 两条断言假设了 A1 之前的计数（承接缺口，另派 P368）；
F3 是写集偏差——账本写入点在 `cmd-agents.sh`，而 `tasks.md §2.1.1` 就写在那里（写集行漏列，**PM 认这个偏差**）；
F2 是 `suspended` 分支没有扩展级单独断言（只有同位置间接覆盖），记为未验项。

## 要回答的四件

1. **账本真的在写、且闭集外不吞**：自己造四种 outcome（`enqueued` / `skipped:suspended` / `skipped:notify-off` /
   一个闭集外的类）→ 贴 `state/notify-knock.log` 原文；闭集外那个必须**原样**落账，digest 显示成「其它（原样）」。
2. **有界与轮转**：把上限调小 → 必须出现 `.1`、扩展日志点名一次、当前代不超上限；**旧代不计入** digest（要验这一点）。
3. **digest 两行是「只显示、不入计数」**：造 3 条未敲门 + 1 条 `pointer=failed` → 两行读数精确；`team inbox pm --ack`
   后「未敲门」消失而「指针缺失」**不消失**；账本不随阅读变；清掉后两行一起消失。**并且**这两行**不进** `team_pending_text`
   （唤醒计数不变——`§25` 已断言，你要自己确认真红了）。
4. **红侧两条自造**：把「未知类原样」改成丢弃 → 该断言红；把轮转去掉 → 有界那条红。还原必须绿。

## 边界

只读代码、破坏只在 `/var/tmp` 私有副本、只写 `docs/team/reports/V98-verify.md` 与自己的线程。不跑整套；
`--select 7,13,25` 与你自己造的场景足够。结论先写 PASS/PARTIAL/FAIL，并单列「必须修」与「未验」。
