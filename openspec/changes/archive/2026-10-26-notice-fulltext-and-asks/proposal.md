# notice-fulltext-and-asks · 完成消息存全文，只在「预览」处截断，且截断必须可见可寻

## Why

缺陷不是「截得太多」，而是**截断发生在记录之前，而且不留任何痕迹**。

`skills/teamsmith/extension/team-notify.ts:469` 在算出末消息的同一行就把它裁掉了：

```ts
if (completed) last = tail(messageText(message.content), cfg.maxChars)   // tail(): slice(0, max-1) + '…'
```

这一份 `last` 随后被写进**三处**：`docs/team/inbox/<seat>.md` 的记录行（` :: <末消息>`）、
`state/notify.log` 的每事件明细记录、以及敲门载荷（`> <last>`）。于是：

1. **账本在写入时丢内容。** 收件箱行与明细文件是本地的、可 grep 的、可按行读的文件 —— 一份 7280 字节的交付在
   磁盘上只剩 150 字加一个省略号，原文任何地方都没有留下。PM 事后要回答「这个席位到底说了什么」只能去翻
   agent 的报告或会话文件，而通知本身就是为这件事存在的。
2. **截断没有标记。** 文本里的 `…` 与模型自己写的省略号无法区分，读者不知道「这里被截了、原文多大、在哪里能读全」。
   实测后果（PM 已记录，P365）：dev2 的交付末尾写着「两点请裁决：①…②…」，PM 收到的是
   `…（\`p365-sel7\` exit=0，即最早那次 \`--select 7\` 的 ✓165 ✗0；其…` —— **裁决点被截掉，而通知没有说它被截掉**，
   PM 只能去翻报告才发现有两件事等他裁决。
3. **量级完全不相称。** PM 在本仓实测席位的最后一条消息：**中位 1952 字节、p90 2758、最大 7280**。150 字的预算
   把 p90 的消息砍掉约九成。这不是「节省」——收件箱一天的字节数由事件数决定（`TEAM_NOTIFY_DETAIL_MAX` 2048），
   而不是由每行长度决定。

另外两件事跟着这条缺陷一起存在：

- **「这是不是在问我」今天无法计数。** 一条末尾带「请裁决 / 待你确认 / 需要你拍板」的交付与一条纯汇报在
  `team digest` 里长得一样，PM 只能逐行读完才知道有没有待答的问题。
- **没有一条「病态输入」的闸。** 模型输出畸形时（例如整段日志被当成末消息）应该有一个上限，但它必须是
  **具名**的，而不是今天这种静默切。

## 用户的裁定（不重新论证，只落实）

> 「为什么要截断？不要截断直接传原文，不要设置限制，本来 LLM 输出就是有限的大不了多少。」

## What Changes

1. **记录存全文。** 收件箱行与 `state/notify.log` 明细里的正文不再截断；末消息只做一件与截断无关的变换：
   空白折叠成一行（收件箱是按行读的文件，这一条今天就有，不改）。
2. **只有「预览」截断，而每一处截断都自带标记。** 敲门载荷、spool 预览（700 字节）、wake 每行预览
   （`TEAM_INBOX_WATCH_PREVIEW`，160 字）三处仍是有界的，但被剪的那一份自己写出
   `truncated=preview:<shown>/<total>B` 与 `full=<文件>[:<行>]`。wake 是 *truncated preview* 这条既有语义
   **一个字不改**——本 change 只让「被剪过」这件事说出来。
3. **认出「这是在问你」。** 末消息**末尾 400 字**内出现**闭集**里的裁决/确认标记时，通知行（以及 PM 的指针行）
   带一个可数字段 `asks=<n>`；`team digest` 的待处理通知段多一行，点名「N 条完成消息里有待 PM 回答的问题」。
   判据是**闭集标记 + 位置**，不是「含问号就算」——那会把每一条都算进来。
4. **一个上限仍然要有，而且要具名。** 消息超过 **65536 字节**（扁平化后、按字符边界切）时，记录的正文保留前
   65536 字节，字段区写 `truncated=hard-limit:65536/<原文字节>B`，且**不带 `full=`**——因为那份原文并不存在
   于磁盘任何地方，读者必须能从这一行本身看出这一点。上限是**常量，不是配置键**：它是给畸形输出的最后一道闸，
   不是一个调参口（用户明确不要限制；给一个能关掉的旋钮等于把这条闸变成偏好）。

## Options considered

选中的是 **B**。

| | 方案 | 结论 |
|---|---|---|
| A | 维持现状：全链路 150 字 | 拒绝。这就是缺陷本身；它对「PM 收到通知后要做什么」没有帮助，还让账本说谎（读起来像完整交付）。 |
| B | 记录存全文；预览有界且**每一处剪都具名**；`asks=` 计数；硬上限 64 KiB 常量化并具名 | **选中**。文件存全文（可 grep、可按行读、可 diff），屏幕与敲门只留预览但预览指向全文；病态输入有闸且闸会说话。 |
| C | 连预览也不设界：敲门与 wake 都带全文 | 拒绝。两条既有契约直接反对：wake 的 *bounded preview*（`notify-and-inbox#Delivery continues on the polling fallback while watching is unavailable`）与 spool 行的 700 字节界（并发 `>>` 追加要尽量落在一次 write 里）；而且把 7 KB 打进 PM 的输入框会淹没对话框本身。 |
| D | 全文落一个旁路文件（`state/last-message/<id>.txt`），行里只留指针 | 拒绝。多一跳：读者要多做一次映射才知道该读哪一行（指针指向指针）；`docs/team/inbox/<seat>.md` 本来就是读者要打开的那份文件，`see=` 也已经在 pm.md 里承担了「指路」。除了多一个文件，D 没解决 A 的任何一条。 |

## 为什么本 change 一条 MODIFIED 都没有（交给审阅的一条判断）

同一 capability 有一条**未归档**的 change（`turn-notice-in-pm-inbox`，P363–P368/V96–V99）正在 MODIFY
同一条 requirement 标题（`A turn-end notification appends one inbox line and knocks once`，为它加指针行）。
若本 change 也写一条该标题的 MODIFIED：

- 以**基线**文本为底 → 归档本 change 时 `openspec archive` 会**拦住**「丢掉当前规格里已有场景」的 MODIFIED 块并逐条
  点名被丢掉的场景，所以**场景**丢不掉；丢的是**散文** —— 指针行那条 requirement 的散文会被基线版替换，而且**没有
  任何报错**（PM 在提案审阅里复跑过，命令与读数见 `design.md` §0）；
- 以**该 pending 文本**为底 → 顺序反过来时本 change 的新增句被覆盖，同样只发生在散文层面、同样无报错。

`spec-refs.sh` 对「同一条 requirement 有两份 pending 版本」没有裁决规则，两种顺序都会在**散文**上静默丢一份。所以本 change
**只新增两条 requirement**（全文/预览标记、`asks`），不改任何既有条目的一个字：契约是**并集**，归档顺序因此不影响
结果，`wake 的 truncated preview` 那条语义也就从根本上没有被碰过。

## Impact（apply 阶段的写集，本阶段只规划）

| 面 | 文件 | 改什么 |
|---|---|---|
| 记录与预览 | `skills/teamsmith/extension/team-notify.ts` | 末消息不再 `tail()`；扁平化后按 65536 字节具名封顶；算 `asks=`；敲门载荷改为「有界预览 + 标记 + `full=`」 |
| 写入口 | `skills/teamsmith/scripts/lib/cmd-agents.sh` | `__inbox-write` 的返回协议加一行 `lineno=<n>`；指针行派生复制 `asks=` |
| digest | `skills/teamsmith/scripts/lib/cmd-status.sh` | 待处理通知段多一行（未读指针行里 `asks>=1` 的条数与点名） |
| spool 预览 | `skills/teamsmith/scripts/lib/outbox.sh` | `team_inbox_watch_deliver` 剪断时追加标记（保持既有字符边界规则） |
| wake 预览 | `skills/teamsmith/extension/team-inbox-watch.ts` | `oneLine(...)` 剪断时追加标记与 `full=` |
| 配置文案面 | `skills/teamsmith/references/{config,troubleshooting,agent-adapters}.md`、`scripts/panel/src/strings/{zh,en}.ts` + 重建的 `scripts/panel/panel.js` | `TEAM_INBOX_MAX_CHARS` 的语义从「收件箱正文截断」改成「预览字数」；面板标签同步（今天写着「收件箱摘要字数」，改后会变成假话） |
| 死代码 | `skills/teamsmith/scripts/lib/common.sh:1125` | 该键的 shell 默认值没有任何 shell 读者（扩展自己读配置文件）。按「no non-stick code」删掉，或证明有读者后留下 |
| 门禁 | `skills/teamsmith/tests/smoke.sh` | §13 的夹具（真跑扩展）+ §7/§25 的 digest 断言 |

## 边界（本 change **不**动）

- wake 的 *truncated preview* 语义、`TEAM_INBOX_WATCH_PREVIEW` 的默认值、spool 的 700 字节界与它的字符边界规则。
- 合并键、合并行字段语义、敲门去重身份（`line|<key>|<first>`）、指针行的 `knock=` run 级规则、未读计数判据
  （`team_inbox_line_is_record`）。
- 手动 `team notify` 的载荷（它今天就是全文，无需标记）。
- **不新增配置键**；硬上限是常量。
- `team digest` 打印的记录正文仍然是全文（见 `design.md` §8 的取舍与理由）。

## 验收（apply 阶段的门槛，本阶段只写下来）

`openspec validate --all --strict` 绿、`tests/spec-refs.sh --check` 通过；apply 只跑受影响的选段
（`7,13,13b,12b-pi,25,47,57,33,28`），整套留给合并/发布。
