# V100 · P370 的独立验收：全文真的落了盘、预览真的自报、`asks` 真的可数

task: V100
agent: verify
phase: verify
category: verify
change: notice-fulltext-and-asks
specs: notify-and-inbox#The record keeps the whole message, and only a preview is truncated
anchor: none (infra) — change 自带 delta
deltas: -
branch: task/V100-notice-fulltext-verify

## 受检

候选 `dbb490a3`（报告 `docs/team/reports/P370-dev2.md`）。自称：一条 2998 B 的交付在收件箱与 `state/notify.log` 里
从 **152 B（截断且无标记）** 变成 **2998 B 全文**；敲门预览仍是 149 B 但**自报** `truncated=preview:…`；
`--select 7,13,13b,25,12b-pi,47,57` 798 条全绿；8 条红侧各自红在指定断言上。

## 要回答的五件

1. **全文落盘（承重）**：自己造一条 **4 KB** 的完成消息 → 收件箱行与 `notify.log` 事件各**逐字节完整**（给两侧字节数与
   首尾各 40 字符、并 `cmp` 与原文）；而**敲门载荷**里出现 `truncated=preview:<shown>/<total>B full=<path>` 且 `full=`
   真的指得到那一条。
2. **没剪就一个字节都不加**：一条 200 B 的短消息 → 三处都**不带** `truncated=`（一个字节都不加）。
3. **硬上限的记号**：造一条 **70 KB** 假消息 → `truncated=hard-limit:65536/…B` **且 `full=` 缺席**（「原文不存在」的唯一记号）；
   账本不爆、轮转正常。
4. **`asks` 的闭集与窗口**：四条消息（末尾 1 个标记 / 2 个标记 / 标记但在**末尾 400 字之外** / 无标记）→ `asks=1 / 2 / 缺 / 缺`；
   `team digest` 那行读数精确、≤3 条具名、**且不进唤醒判据**（自己确认 `§25` 那两条仍绿）。
5. **没动别人的契约**：`git diff main dbb490a3 -- openspec/changes/turn-notice-in-pm-inbox` 必须为空；A1 的指针行形状与
   A2 的账字段不变；产品面 diff 只在 `team-notify.ts` / `cmd-agents.sh` / `cmd-status.sh`（其它文件点名）。

## 边界

只读代码、破坏只在 `/var/tmp` 私有副本、只写 `docs/team/reports/V100-verify.md` 与自己的线程。不跑整套；
`--select 7,13,13b,25` 与自造场景足够。结论先写 PASS/PARTIAL/FAIL，单列「必须修」与「未验」。
