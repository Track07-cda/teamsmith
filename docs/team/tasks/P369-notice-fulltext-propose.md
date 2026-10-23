# P369 · propose：完成消息存全文，只在「预览」处截断，且截断必须可见可寻

task: P369
agent: dev-bob
phase: propose
category: analysis
change: notice-fulltext-and-asks
specs: notify-and-inbox#A turn-end notification appends one inbox line and knocks once
anchor: none (infra) — change 自带 delta
deltas: notify-and-inbox/spec.md
branch: task/P369-notice-fulltext-propose

## 用户的裁定（不要重新论证）

> 「为什么要截断？不要截断直接传原文，不要设置限制，本来 LLM 输出就是有限的大不了多少。」

PM 已量过：席位的最后一条消息 **中位 1952 字节、p90 2758、最大 7280**。而现在的实现把它截到
**`TEAM_INBOX_MAX_CHARS`，默认 150 字**，然后这一份截断文本被同时写进**收件箱行**、**`state/notify.log` 事件**、
和**敲门载荷**——三处同一份。今天已出现后果：dev2 的 `P365` 交付末尾写着「两点请裁决：①…②…」，PM 看到的是
`…（\`p365-sel7\` exit=0，即最早那次 \`--select 7\` 的 ✓165 ✗0；其…`，裁决点被截掉，只能去翻报告。

## 要设计的（方向已定，细节你决定）

1. **记录存全文**：收件箱行与明细账/结果账里的正文**不截断**（它们是文件，可 grep、可按行读；没有理由在写入时丢弃）。
2. **只有「预览」截断**：敲门（wake）与屏幕显示仍可以截断——规格里已经要求 wake 是 *truncated preview*，
   这一条不改。但**截断必须可见且可寻**：写法上要能看出「这里被截了、原文多少字节、在哪一行/哪个文件」，
   不许像今天这样静默截断。
3. **认出「这是在问你」**：完成消息末尾出现裁决/确认类标记（请裁决、待你、需要你确认、等你拍板、是否需要我做…）时，
   通知行/指针行带一个可数的字段（例如 `asks=<n>`），`team digest` 多一行点名「N 条完成消息里有待 PM 回答的问题」。
   判据要写成**闭集标记 + 位置（末尾 N 字符内）**，不要「含问号就算」——那会把每一条都算进来。
4. **一个上限仍然要有**（防病态输入：模型输出畸形时不能把账本写爆），但它要**高到不碰正常消息**（PM 建议 64 KB，
   由你判断），而且超限时要**具名**（写 `truncated=hard-limit:65536` 之类，而不是静默切）。

## 提案要交的

`openspec/changes/notice-fulltext-and-asks/`：`proposal.md`（问题、选项、为什么这样选）、
`specs/notify-and-inbox/spec.md`（delta：改哪条、新增哪条；**wake 的 truncated preview 那条语义保持不变**）、
`design.md`（全文落哪里、预览怎么标、`asks` 的判据与闭集、硬上限与它的具名）、`tasks.md`（含每条红侧）。

`openspec validate --all --strict` 绿、`spec-refs.sh --check` 通过。

## 边界

只规划不写实现。写集：change 目录 + 报告。不改扩展代码、不改 `smoke.sh`、不改配置键。
