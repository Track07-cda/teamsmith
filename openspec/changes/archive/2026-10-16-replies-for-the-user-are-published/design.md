# replies-for-the-user-are-published · 设计

## Context

动机、用户两次口径与现状复核见 proposal（数字与路径都在那里）。以下是本轮读取的基线事实（均为当前磁盘状态）：

- **纪律面已归档**：change `pm-reply-discipline`（`openspec/changes/archive/2026-10-15-pm-reply-discipline/`）把
  「关键结论先发布」写进了三处指令面（`templates/pm-prompt.md.tmpl`、`references/protocol.md` §4b、`SKILL.md`），
  并在 `tests/key-replies.sh` 里立了 `guide` 组守着它们；`openspec/specs/key-replies/spec.md` 的两条要求
  （`Publication does not gate the normal answer or create work`、`The key-conclusion duty is shipped on its
  instruction surfaces and held by the gate`）就是本变更要改的那两条，其余八条一条不动。
- **门禁现状**：`guide_spec()`（`tests/key-replies.sh:1055`）给三处表面各定一组锚点；`guide_check_surface()` 用
  `grep -qiF`（大小写不敏感）逐条判，缺哪条就把它列进红文案；`kr_group_guide` 另外跑 `guide-example`（真 CLI 对拍 +
  `--frobnicate-probe` 控制臂）与四条变异副本。今天实测 `--select guide` → **✓18 ✗0**。
- **面板现状**：第 5 页的块是 `replyListBlock()`（`scripts/panel/src/layout.ts:1371`），第一行永远是
  `replyNavLine()`，其后是槽位计数 / 尾部告警 / 条目行；空 store 与降级读数在 `:1387` 早退。字符串表是扁平
  `key → string` 映射（`src/strings/types.ts` 的 `Strings` 是索引签名），`tests/panel-strings.mjs` 判两张表的键集
  相等与占位符一致；`panel.js` 是**提交的构建产物**，`tests/smoke.sh:11030-11050` 在沙盒里重建并逐字节比对。
- **P264 的分类规则**（`docs/team/reviews/P264-classification.md`，已 done）：「没有机器面、而那串字是某个要紧行为的
  唯一证据 → **留一条稳定 token**（不是整句）」；逐字节快照与文案风格类断言已从门禁拿掉。
- **D170**：门禁只对**逻辑类**（行为与状态）有效；文本类由设计与评审把关。本变更的两类断言分别是「表面带着这条判据」
  与「印出来的示例命令被真解析器接受」。

## Goals / Non-Goals

**Goals**：把触发从「三类时点」换成**按读者**，让它在**三处指令面**上都存在、丢了会红；让边界可执行（一句话就能判：
这条回复是写给谁的）；让**关键回复页说清它是什么、谁发布**，同时写明面板**不**做自动检测；把「印出来的示例命令真的
能用」这条行为断言原样保留。

**Non-Goals**：不改 `team reply` 的 CLI/存储/退出码/编号/并发；不给面板加任何动作、mouse target 或聊天读取；不做
「哪条回复是写给用户的」的语义判定；不改 worker 提示词与 `team say`/`notify` 的通道语义；不迁移历史回复。

## Decisions

### 1. 三处表面的落点与共享 token

判据要**同时**进三处，共享一个冻结 token：**`written for the user`**。推荐文本（apply 按此落笔；措辞可以润，token
不能丢）：

| 表面 | 改哪里 | 推荐文本（改动部分） |
|---|---|---|
| `templates/pm-prompt.md.tmpl:31-35` | 现有那段整体改写 | 「**Replies written for the user go to the reply page first.** Answering a question, reporting progress, giving a conclusion or a ruling, asking the user to decide, summarising a delivery or a verification — whenever the reply is written for the user, publish the complete reply -- not a summary -- with `team reply post …`, then send that same body in the conversation. Replies written to the patrol, to another seat, to another project's PM and tool receipts stay out; ask **who is this reply written for?** when it is not obvious, and treat an unsettled case as written for the user. A batch may be one reply.」 |
| `references/protocol.md:142` | 常设义务那句的触发清单 | 同一判据的参考面写法：「…publish the **complete conclusion** — the whole answer, not a summary — when the reply is **written for the user** …」 |
| `references/protocol.md` §4b | 代码块之后新增边界段（≤5 行） | 「**The reader decides.** A reply written for the user is published however short it is — an answer, a progress report, a conclusion, a ruling, a decision you ask for, a delivery summary. A reply written to the patrol, to another seat or to another project's PM is not for the user and stays in its channel, and a tool receipt is not a reply. When it is not obvious, ask who the reply is written for; if that cannot be settled, treat it as written for the user.」 |
| `SKILL.md:54`（command table 行） | 触发清单 | 「(**any reply written for the user**: a landed milestone, a ruling, an answer, a progress report, a decision you ask the user for)」 |
| `SKILL.md:250`（Non-negotiable bullet） | 同一份纪律的第二处副本 | 「Before a milestone lands, before you issue a ruling, and whenever the reply is **written for the user** …」 |

三面**不要求逐字相同**（语域不同），只共享 token——与 P257 的既有裁定一致。

### 2. 边界写死，且不进门禁

边界是一句话：**这条回复是写给谁的**。写给用户的 → 发布（不论长短、不论话题）；写给巡检/席位/别的项目 PM 的与工具
回执 → 不发布；**判不准时按「写给用户」处理**。它**不进门禁**：判「这条回复是写给谁的」是语言判断，没有任何机器面；
D170 把这一类交给设计与评审。规格里**不**写一条假装能测它的场景——诚实边界（`key-replies` 那条要求末尾）继续说明
「没有任何工具能验证某个活着的 agent 是否照做、某条回复是不是写给用户的」。

### 3. 冻结 token 的代价（必须写明）

token 是**合同的一部分**：它能被删、被改词，改了门禁就红（例如有人把 `written for the user` 改写成
`the reader is the user`，语义不变但门禁会红——那属于改合同，要走一次提案或由 PM 在复验里点名放行）。备选（不设
token、只靠评审）与用户「标记使用情况不理想」的诉求相悖——用户要的是**使用**变好，而「表面带着这条判据」是唯一可
机判的那一半。所以：token 进断言，措辞不进。apply 落地时注意一个实现细节：`guide_spec()` 的锚点串现在是**单引号**
字面量，本 token 没有撇号，可以直接沿用单引号写法。

### 4. 门禁正好两类（存在性 + 行为），红侧是组内断言

- **存在性**：`guide_spec` 给三处各加 token（command table 用 `row:` 前缀，要求它落在 `| Key replies |` 行内——
  只写在 bullet 里不算）。红侧：既有变异 ①②③ 各自删掉/替换整段，红文案里必须**列出 `[written for the user]`**
  （证明三处各自承重）；新增变异 ⑤ 只把模板里的 token 换成别的说法（`written for the user` → `written for a
  person`，句子仍通顺）→ 必须红并点名 `prompt template` 与 `[written for the user]`，还原后绿（证明这个 token 单独
  承重）。
- **行为**：`guide-example` 原样保留——模板里那行示例命令必须被**真解析器**接受（rc=0、`outcome=saved`、槽位 +1），
  控制臂（同一 argv + `--frobnicate-probe`）必须 rc=2、诊断含「未知参数」、槽位不变。本变更**不改**这行命令，只要求
  它继续被背书。
- 组内**不**新增任何措辞/语气/句子形状断言；`guide-surfaces` 的红文案只点名「哪个面缺了哪个 token」，不要求任何句子。
- 「写给巡检/席位/别的项目 PM 不算」这一极**不进断言**：没有它规则仍然成立（判据是读者），它的缺失不会让规则反向；
  它属于文本类，由评审把关。

### 5. 面板那一行：位置、文案、只读与诚实边界

- **键与文案**：`zh.ts` / `en.ts` 各加 `replyPageNote`；**PM 复核要求这一行带上规则的自测题**，所以推荐
  zh `「这条回复是写给谁的？」——PM 写给用户的回复都在这里`、
  en `"who is this reply written for?" — replies the PM wrote for the user`（问题放句首：59 列截断时问题与「谁发布」
  都还看得见；它的尾巴被截掉属于正常 `truncLine` 行为）。文案是文本类（不进断言），PM 在提案评审里可以直接改。
- **位置**：`layout.ts:1386` 之后紧跟一行 dim（`truncLine(ln(seg(... 'dim')), innerW)`），即在导航行之后、槽位计数之前
  ——空 store 与降级读数走早退分支时也带着它。代价：列表可视行数少 1（`room = Math.max(1, budget - lines.length)`），
  四档宽度下仍 ≥1 行；既有断言没有一条数行数，snapshot 组判的是「渲染得出来 + 无超宽 + 非半截帧」。
- **只读与诚实边界**：这一行是 `seg()` 纯文本，无 hit 目标、无动作；规格里写死「面板不读聊天/会话/历史，不许承诺自动
  标记」，并用第二个场景（记录到的读者调用只有有界的 key-reply 块）给它一个可失败的形状。
- **产物**：改了 `src/**` 就必须重建 `panel.js`（`bun install --frozen-lockfile && bash build.sh`，本机实测
  `registry.npmjs.org` 可达、bun 在 `$HOME/.bun/bin/bun`）；不重建 → §26-a 的沙盒重建逐字节比对红。

### 6. 第 5 页那一行的断言（存在性/行为，不超过两条）

`key-replies-pty.sh`：`pages` 组（zh）加一条 `assert_has` 断言那一行在窗格里；`language` 组把它并进 en 的
`want_frame`。红侧天然存在（从 layout 删掉那一行 → 两条断言都红）。不加新机制、不加新组。

### 7. 与既有规格不冲突（逐条核过）

- `key-replies` 的另八条要求一字不动；`extension-slash` / `boundary` / `writing-discipline` 与本题无关。
- 「答读者的问题优先」（`templates/pm-prompt.md.tmpl:22`，writing-discipline 的写作纪律）与本题**不冲突也不重复**：
  那条讲**怎么写**（先答后述、只留带证据的句子），本题讲**发不发**（写给用户的回复要发布到关键回复页）。
- **与本要求自己的一条旧句的关系，本变更按 PM 的复核裁法处理**：原文是「a reply carries conclusions rather than
  process narration」（只发结论、不发过程）。按读者判的话**不能**用它排除「写给用户的汇报」，所以本变更把它收成一则
  **内容要求**并写死反向句：「a reply written for the user is never held back because of what kind of reply it is …
  no reply becomes unpublishable by reading like process rather than like a conclusion」（页面收的是实质正文，不是
  流水账）。这是有意的改写，不是遗漏；旧句与新句都在 delta 的 diff 里看得见。
- 面板那条 ADDED 与「跨宽度与语言可读」不重复：后者是渲染/本地化，前者是页面**语义**（这一页是什么、谁发布）。

## Risks / Known limitations

1. **token 会随措辞改动而红**（决策 3 的代价，已知且明示）。PM 若在评审里改词，须同时改 `guide_spec`。
2. **判「这条回复是写给谁的」不可机判**：边界由评审与人读差异把关，门禁只证「判据在场上 + 示例命令能用」；这与规格
   既有的诚实边界一致，不新增承诺。
3. **「判不准按写给用户处理」会让页面偏吵**：这是用户诉求的方向（漏标记才是问题），但 PM 若认为吵，删掉这一句即可
   （proposal 裁定点 5）。
4. **面板那一行占 1 行可视高度**：四档宽度下仍可渲染（预算下限 `Math.max(2, …)` 不变）；如 PM 认为不可接受，替代
   方案是只在空 store 时显示（代价：页面平常不说明自己，与需求相悖）。
5. **`panel.js` 必须在有网络的机器上重建**：否则 §26-a 在无网环境只是可见跳过，提交的 bundle 会与源漂移。
6. **既有红不是本变更的**：`spec-refs.sh --check` 今天 rc=1（`extension-slash/spec.md:47 → docs/team/tasks/P1.md`），
   基线对照一致；修它在 PM 的地盘（proposal 裁定点 7）。
7. **§62 的选段缺口**（`section-paths.tsv:153` 不含这三处路径）：proposal 裁定点 6；不补的话「只改这三处」的增量跑
   选不到 §62，守卫要等全量或显式 `--select 62`。

## 验证计划（apply / verify）

- apply：三处文本 + `guide_spec` 三行 + 变异 ⑤；面板 1 键 ×2 表 + layout 1 行 + 重建产物；pty 两条断言；按 proposal 的
  Acceptance 逐条跑（`--select guide`、`--all`、`--select pages,language`、rebuild、`panel-strings.mjs`、
  `smoke.sh --select 26,28,62`、`validate --all --strict`、投影自证）。
- verify（**另一席位**，不是 apply 作者）：在独立克隆上重跑同一串；自己重做变异 ①②③⑤ 与还原，并独立造一次「把 token
  换成同义说法」的变异，确认红的是 token 而不是别的锚点；在真树上手工做一次「删掉那一行 → pty 红 → 还原 → 绿」；
  核 `panel.js` 与 `src/**` 一致（重建后的字节比对）。
