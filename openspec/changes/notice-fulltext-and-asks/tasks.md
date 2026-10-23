# notice-fulltext-and-asks · tasks

阶段口径：propose 完成（P369）。apply 拆成 **A → B → C → D 四次派单，顺序固定**：

- **A 记录全文 + 硬上限**：单独就是一次可交付的修复（用户报的缺陷就是它）。它同时给出 `__inbox-write` 的
  `lineno=` 协议，B 的 `full=` 依赖它。
- **B 三处预览标记**：敲门载荷 / spool 预览 / wake 预览共用一份语法，必须一起落地（只标一半会得到一个自相矛盾的
  证据面：同一份内容在一处说「被剪了」、在另一处静默）。
- **C `asks=` + digest 一行**：可独立判（计数判据在自己的夹具里）。
- **D 文案与面板标签 + 死默认**：只在 A/B/C 的行为定稿后改措辞，避免文案追着实现跑。

A 声明 `change: notice-fulltext-and-asks`、`deltas: notify-and-inbox`（delta 已由 P369 写入并经 PM 审核）；
**B/C/D 一律 `deltas: -`，不许改 spec 文件**。本文件不是规格：合同在 `specs/notify-and-inbox/spec.md`，
理由与取舍在 `design.md`。

新增断言的性质（复杂度纪律要求写明）：本 change 新增的门禁断言全部是**产品行为的测试**（截断必须具名、问句必须可数），
不是关于我们自己流程的守卫；产品无法自证「它的截断是诚实的」，这一层只能在夹具里证。因此本 change **不退役**任何既有
断言，也**不新增**独立守卫脚本 —— 全部落在既有的 §7/§13/§25/§12b-pi 段里。

## 0 · 共同前提（A/B/C/D 各自都要做）

- [ ] 0.1 `git merge main`；确认 propose 已被 PM 在 `docs/team/reviews/notice-fulltext-and-asks-proposal.md` 判
  ACCEPTED。读完 `design.md` §1–§9 再动手；发现规格自相矛盾 → `BLOCKED:` 交回 PM，**不自行改 delta**。
- [ ] 0.2 改前现场（真实命令 + 输出尾部进报告）：一条 3000 字末消息的 settle 之后，`docs/team/inbox/<seat>.md`
  里 ` :: ` 之后的字节数（`awk -F' :: ' '{print length($2)}'`）、`state/notify.log` 同一事件的字节数、
  `state/outbox/` 里那条 knock 载荷的字节数 —— 三个读数**相等且 ≤ 150**，这就是缺陷的现场。
- [ ] 0.3 写集边界按 `design.md` §9 的表；A/B/C 不碰 `scripts/panel/**`，D 才碰（改面板必须重建 bundle）。
- [ ] 0.4 一次只跑改动点到的段（`--select`），**不要**每改一处跑整套；整套留给合并/发布前一次（后台启动、下一次唤醒收）。
  长跑的日志与现场落在宿主机 bind mount 上，不用 `| tail` 只留尾部。

## 1 · A · 记录存全文 + 硬上限 65536 B

### 1.1 记录路径去掉显示预算

- [ ] 1.1.1 `team-notify.ts`：末消息改为「空白折叠 → 不变」，删掉 `tail(..., cfg.maxChars)` 对记录路径的作用
  （预览仍用它，B 里接上）。写盘的是全文。
- [ ] 1.1.2 硬上限：扁平化后按 UTF-8 字节判，超过 **65536** 时保留前 65536 字节并退到字符边界（`iconv -c` 惯例，
  丢字节、不引入 U+FFFD），字段区追加 `truncated=hard-limit:<kept>/<total>B`，**不带** `full=`。常量写在扩展里，
  旁边一行注释写明它防的是畸形输出。
- [ ] 1.1.3 `__inbox-write` 的返回协议加一行 `lineno=<n>`（持锁写入侧在写完的同一临界区里用 `team_inbox_total` 数），
  追加与截尾重写两条腿都要给。旧读者按 `^state=`/`^first=`/`^key=` 解析，多一行不影响。
- [ ] 1.1.4 **红侧 R1（全文）**：夹具放一条 3000 字末消息 → 记录行 ` :: ` 之后 3000 字、明细同事件 3000 字。
  把 1.1.1 改回 `tail()` → 该断言必红（读出 150）。
- [ ] 1.1.5 **红侧 R2（硬上限具名）**：夹具放一条 200000 B 末消息 → 正文正好 65536 B、字段区有
  `truncated=hard-limit:65536/200000B`、**没有** `full=`。把上限改成「静默切」（切了不写字段）→ 必红。
  再把上限改成 16 KiB → 红侧的另一半：一条 20 KB 的正常消息不该被剪（这条断言就是「上限必须高到不碰正常消息」）。
- [ ] 1.1.6 **不变性**：没有截断的 settle 之后，记录行与明细记录与今天**逐字节相同**（同一夹具跑改前/改后，
  `diff` 空）；这条同时保护 §13 既有的 `×3` / `knock=` / `see=` 断言。

## 2 · B · 三处预览都自己说出「剪了、剪了多少、原文在哪」

### 2.1 一份语法（`design.md` §4）

- [ ] 2.1.1 标记形状固定为 `truncated=preview:<shown>/<total>B`，可选 `full=<path>[:<line>]`；`<shown>/<total>` 是
  UTF-8 字节数，两个数同单位。三处实现（TS ×2、bash ×1）必须产出**同一个字符串形状** —— 用一条断言直接比对三处输出。
- [ ] 2.1.2 只有真的剪了才加标记；没剪 → 一个字节都不加（设计 §7 的第 1 条）。

### 2.2 三处落地

- [ ] 2.2.1 敲门载荷：`> <前 TEAM_INBOX_MAX_CHARS 字>…` 仍是有界预览；摘要行尾部追加标记与
  `full=docs/team/inbox/<seat>.md:<lineno>`（A 的协议）。行号缺失（写盘失败）时省略 `:<n>`，且既有「写失败不敲门」不变。
- [ ] 2.2.2 spool 预览：`team_inbox_watch_deliver` 在 `team_inbox_watch_clip` 剪断时，把标记写成 spool 行的**第 7 个
  Tab 字段**（`<total>` = 扁平化后载荷的字节数，`full=` 取 `durable` 指向的收件箱文件；`durable=-` 时仍写标记、
  因为载荷自己带着 `full=`）。preview 字段本身不变（仍是 ≤ 700 B 的最长整字符前缀，`iconv -c` 一行不改）；
  读侧 `team-inbox-watch.ts` 按 `f[4]`/`f[5]` 取旧字段 → 多一个字段不炸，且旧 spool 行（没有第 7 字段）不得被误判成「被剪了」。
- [ ] 2.2.3 wake 每行预览：`oneLine()` 剪断时追加标记，`<total>` = 它拿到的那份 spool 预览的字节数，
  `full=` = 该行 `durable` 指向的收件箱文件。`id` 与 `src` 的打印位置不变。
- [ ] 2.2.4 **红侧 R3（可见）**：剪断的载荷里没有标记 → 必红（无论剪在哪一层）。
- [ ] 2.2.5 **红侧 R4（可寻）**：标记里的 `full=<path>:<line>` 必须能读出整条消息 —— 断言「按它 `sed -n '<line>p'`
  打印出来的行，` :: ` 之后等于夹具里的全文」。把 `lineno=` 改成扩展自己算的数（例如 `team_inbox_total` 加一）
  → 行号错位 → 必红（这是并发追加下的假定位，必须由持锁侧给数）。
- [ ] 2.2.6 **红侧 R5（每层自己写）**：把 wake 层的标记改成「继承 spool 层那一个」（即不再自己算）→ 160 字剪断后
  这一行既看不到标记也看不到 `full=` → 必红。

## 3 · C · `asks=<n>` 与 digest 的一行

### 3.1 计数判据（唯一实现，在扩展里，数据表）

- [ ] 3.1.1 区域 = 扁平化后末消息的**最后 400 字符**（硬上限之前判）；标记的全部字符落在窗口内才计数。
- [ ] 3.1.2 闭集照抄规格正文（中文 22 条 + 英文 7 条）；最长优先、从左到右、不重叠，ASCII 大小写折叠。
- [ ] 3.1.3 字段 `asks=<n>` 写在字段区（` :: ` 之前）；**没有问句时字段不存在**（不是 `asks=0`）；不进合并键。
- [ ] 3.1.4 `team_notify_pointer_line` 的复制清单加 `asks=`（事件级字段，但 PM 读的是指针行）；`branch=` 等仍不复制。
- [ ] 3.1.5 digest：`[2] 待处理通知` 段多一行（未读指针行里 `asks>=1` 的条数与点名 ≤3 条），为 0 时不打印；
  不进 `team_pending_text`。
- [ ] 3.1.6 **红侧 R6（正交两向）**：
  - 末消息 `两点请裁决：① … ② …` → `asks=1`（记录行与指针行都有），digest 点名 1 条；
  - `这样行吗？那这样呢？还有别的问题吗？` → 无 `asks=`（「含问号就算」的退化实现必红）；
  - 标记在末尾 400 字之外 → 无 `asks=`（窗口失效必红）；
  - `请你确认，请确认` → `asks=2`；`请你确认` → `asks=1`（重叠计两次的实现必红）。
- [ ] 3.1.7 **红侧 R7（digest 归属）**：一条 `asks=1` 的未读指针行 → digest 多一行；`team inbox --ack` 后
  同一命令不再打印（把计数挂在明细或全量历史上 → 必红）；合并 run（`×3` + `asks=1`）只算 1 条（按事件数算 → 必红）。
- [ ] 3.1.8 **不变性**：无问句的 settle 之后，记录行与指针行与改前**逐字节相同**（`diff` 空）。

## 4 · D · 文案、面板标签、死默认

- [ ] 4.1 `references/config.md` 的 `TEAM_INBOX_MAX_CHARS` 描述从「truncation length of the agent's last message
  inside a briefing」改成「预览字数：敲门载荷里引用的末消息字数；记录行与 `state/notify.log` 存全文」。
- [ ] 4.2 `references/troubleshooting.md` 那句「lower the volume with `TEAM_INBOX_MAX_CHARS`」必须改：降它以后只缩短
  预览，不再减少收件箱里的任何字（假话比没有更坏）；给出真正的降噪方式（读完就 `--ack`；`TEAM_NOTIFY_DETAIL_MAX` 管明细代数）。
- [ ] 4.3 `references/agent-adapters.md` 的 wake 预览段补一句：预览被剪时行内有 `truncated=preview:` 与 `full=`。
- [ ] 4.4 面板标签：`zh.ts` 的 `label_TEAM_INBOX_MAX_CHARS`「收件箱摘要字数」→「预览字数」；`en.ts` 的
  `Inbox summary chars` → `Preview chars`（en ≤ 22 格）。改完按钉住的工具链重建：
  `cd skills/teamsmith/scripts/panel && bun install --frozen-lockfile && bash build.sh`，并跑 §28 的键集合走查与
  §26-a 的沙盒重建逐字节比对 —— 手改 `panel.js` 必红。
- [ ] 4.5 死默认：`common.sh:1125` 的 `TEAM_INBOX_MAX_CHARS="${TEAM_INBOX_MAX_CHARS:-150}"` 今天没有 shell 读者。
  唯一读者是 `extension/team-notify.ts:279`，而它用 `readCfg` 直接解析 `.pi/team/config.sh`、不看环境。
  现场（P369 跑过）：`grep -rn 'INBOX_MAX_CHARS' skills/teamsmith/ | grep -v panel.js` → 扩展 1 处、schema 1 处、
  `TEAM_CONFIG_FLAT_KEYS` 1 处、`templates/config.sh.tmpl` 的默认值、docs 3 处、面板标签 2 处 —— **没有一处是 shell 逻辑**。
  删掉 common.sh 那一行（模板里的默认值保留：它是项目配置文件的样子，不是死代码）。删除后
  `team config set TEAM_INBOX_MAX_CHARS 300` 仍生效、§13 的预览长度断言仍绿（证明读者只有扩展）。
  若 apply 时发现真的有 shell 读者 → 不删，在报告里点名是谁。
- [ ] 4.6 **红侧 R8（文案不撒谎）**：把 4.2 改回去（文案仍说「降低它就能降噪」）→ §14b/§18 的文档不变量里若有
  对应断言应红；若没有承接断言，就在报告里写明「无门禁承接」并给出 4.2 的手工读证（这是 `design.md` §8 的取舍）。

## 5 · 验收命令（每个阶段都跑它点到的子集；D 之后跑全套子集）

```bash
PATH="$HOME/.bun/install/global/node_modules/.bin:$PATH" openspec validate --all --strict
bash skills/teamsmith/tests/spec-refs.sh --check
bash skills/teamsmith/tests/smoke.sh --select 7,13,13b,12b-pi,25,47,57,33,28
```

- A：`--select 13,13b,47`
- B：`--select 7,12b-pi,13,57`
- C：`--select 7,13,25`
- D：`--select 28,33,18,14b` + 面板 bundle 重建的逐字节比对

## 6 · 已知边界（不在本 change 里）

- `team digest` 的 `[2]` 段仍打印记录正文全文（`design.md` §8 的第一条退化）：7 KB 的行会出现在 `tail -3` 里。
  若 PM 判终端可读性优先，那是本 change 唯一可以后加的一条，不当场扩。
- 硬上限的病态组合上界（128 MiB/代）用既有的 `TEAM_NOTIFY_DETAIL_MAX` 兜，不新增键。
