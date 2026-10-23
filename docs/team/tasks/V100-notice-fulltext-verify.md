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

## 第二轮（定点复看，只验你点的两处 + 一条连带；候选 `c1a3f4d0`）

作者按你 §9/§10 改了：① 三处形状比对现在比**三份真样品**（缺一份 = 红，不是 `continue`）；② `TEAM_INBOX_MAX_CHARS`
的新语义（预览长度）落到四面：`cmd-config.sh` schema、`templates/config.sh.tmpl`、`references/config.md`、以及面板中英
`label_TEAM_INBOX_MAX_CHARS`（含按钉住工具链重建 `panel.js`）。它自报变异树上 `--select 12b-pi` = `✓472 ✗2`（正是那两条）。

**只做四件：**

1. **`--select 12b-pi` 在候选上必须绿**（你上一轮实测 `✓470 ✗1`）；贴读数与 rc。
2. **三份样品各有真写入者**：静态核 `grep -n 'p370-marker-(knock|spool|wake)\.txt'`，三个名字各有「写」与「读」两侧；
   再自己造一次「删掉 spool 样品」→ 必须**红并点名缺哪一份**（不是静默 continue）。
3. **四面描述一致**：schema 描述、`config.md`、模板注释、面板中英标签四处的措辞都表达「预览长度」且互相不矛盾；
   面板若改了源码，`panel.js` 必须是按钉住工具链重建的（`--select 26-a` 的沙盒重建逐字节比对）。
4. **没有顺手改语义**：`git diff main <候选> -- skills/teamsmith/scripts/lib/cmd-agents.sh` 里，`TEAM_INBOX_MAX_CHARS`
   仍只作用于**预览**（记录侧无预算）——贴那一处 diff 证明。

结论只写 PASS 或 FAIL。仍不跑整套；`--select 12b-pi,13b,26-a` 与自造场景足够。

