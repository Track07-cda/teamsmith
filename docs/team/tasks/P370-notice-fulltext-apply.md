# P370 · apply：通知存全文、预览自报、`asks` 可数

task: P370
agent: dev2
phase: apply
category: code
change: notice-fulltext-and-asks
specs: notify-and-inbox#The record keeps the whole message, and only a preview is truncated
anchor: none (infra) — change 自带 delta
deltas: notify-and-inbox
branch: task/P370-notice-fulltext-apply

## 依据

提案已 ACCEPTED（`docs/team/reviews/notice-fulltext-and-asks-proposal.md`，作者报告 `docs/team/reports/P369-dev-bob.md`），
delta / design / tasks 在 `openspec/changes/notice-fulltext-and-asks/`。**照它实现，不要重新设计。**

PM 复跑过它的结构性主张，要求你在 design 的理由段把措辞改准：`openspec archive` **会拦住**「丢掉当前规格已有场景」
的 MODIFIED 块（逐条点名场景），**静默只发生在散文**；复现命令：
两条 pending change 同标题、原块 + 各自一句散文、场景一个不少 → 归档 A 后 A 的散文在，归档 B 后 A 的散文消失且无报错。

## 硬要求（不满足就是没做完）

1. **记录存全文**：`docs/team/inbox/<seat>.md` 的行与 `state/notify.log` 的事件都不带显示预算（只有既有的空白折叠）。
2. **预览截断自报**：每一处剪的地方写 `truncated=preview:<shown>/<total>B full=<path>[:<line>]`，**没剪就一个字节都不加**；
   三层（敲门载荷 / spool 预览 / wake 每行预览）各写各的，不许共用一份。
3. **硬上限 65536 字节（常量，不是配置键）**：超限写 `truncated=hard-limit:65536/<原文>B` **且不带 `full=`**
   —— 这个「没有 `full=`」是「原文在任何地方都不存在」的唯一记号，必须有断言钉住。
4. **`asks=<n>`**：末消息**末尾 400 字**内的**闭集**标记（22 中文 + 7 英文，最长优先、左到右、不重叠、ASCII 折叠），
   缺席即不写 `asks`（不是 `asks=0`）；`team digest` 的 `[2]` 段多一行（未读指针行、≤3 条具名、**只显示不进唤醒判据**）。
5. **不改 `turn-notice-in-pm-inbox` 的 delta**、不改 A1/A2 已有的行形状与计数字段。

## 必须交的证据

- 全文落盘：一条 4 KB 完成消息 → 收件箱行与 `notify.log` 事件各**完整**（给字节数与首尾各 40 字符），而敲门载荷里
  带 `truncated=preview:…` 且 `full=` 指向那条行。
- `asks`：造 4 条消息（末尾 1 个标记 / 2 个标记 / 标记但在 400 字之外 / 无标记）→ `asks=1 / 2 / 缺 / 缺`，digest 那行读数精确。
- 硬上限：造一条 70 KB 的假消息 → `truncated=hard-limit:65536/…B`、**无 `full=`**、账本不爆。
- 红侧各一条：把预览标记去掉 → 断言红；把 `asks` 的 400 字窗口改成全文扫 → 「400 字之外」那条必须红（区分出来）。
- 段读数：`--select 7,13,25,6`（按 delta 的 tasks.md 里点名的段）；轻量收口全套。

## 边界

写集：`skills/teamsmith/extension/team-notify.ts`、`skills/teamsmith/scripts/lib/cmd-agents.sh`、
`skills/teamsmith/scripts/lib/cmd-status.sh`、必要时 `skills/teamsmith/tests/smoke.sh` 与 `tests/bg-ledger*.{sh,mjs}`、报告。
不改产品其它面、不新增配置键、不碰面板。
