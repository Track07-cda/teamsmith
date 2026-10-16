# writing-discipline · 设计

## Context

动机、证据与证据层级见 proposal「Why」。以下是本提案**读过并测量过**的基线事实（当前磁盘状态，不是待实现能力）。

### 三处表面的现状（本 worktree 实测，2026-10-15）

| 表面 | 规模 | 现状 | 缺口 |
|---|---|---|---|
| `skills/teamsmith/templates/AGENTS.section.md.tmpl` | 160 行；Non-negotiable discipline 8 条 bullet | 有「范围/报告/磁盘交接」「不要没跑就说通过」「小步提交」；有车道三态段与「The change is the assignment unit」段（§12k 逐字比对的对象） | **0 命中**「先答读者 / 发现写明改变了什么 / 能删就删 / 边界只在有证据时声明」（`grep -ci 'answer the reader\|what it changed'` = 0） |
| `skills/teamsmith/templates/pm-prompt.md.tmpl` | 135 行；`## Talking to the user: a code never stands alone` 在 `:12` | 该节统管 user-facing output：代号带名字、长列表逐行自明、关键结论先发布（`key-replies` 的锚点） | 同上 0 命中；PM 写给用户的**文字本身**没有任何判据 |
| `skills/teamsmith/references/protocol.md` | 791 行；§11 在 `:775` | §11 只讲代号规则；§4b 讲关键回复；§9c 讲强复验 | 同上 0 命中；没有「按支撑判、不按语气」的参考面 |
| `skills/teamsmith/references/workflows.md` | 488 行；§E 在 `:149` | §E 有三条：跑 `team review`、**PM 必须自己读 diff**、长门禁走后台车道 | 同上 0 命中；复核交付物时没有「发现带后果」的读法 |

四份文件的 `grep -ci` 在**全树 templates/** 与 references/**（21 个文件）里都是 0 —— 这条规则今天只活在
PM 的项目记忆里，不随工具走（与 `pm-reply-discipline` 立项时的形状完全一样）。

### 门禁的现状（决定了「谁来守」）

- `tests/smoke.sh` §12k 断言 `references/openspec.md` 的提案审查清单**恰好十条**
  （`assert_eq … grep -cE '^[0-9]+\. \*\*' … "10"`，`:15702`），逐字比对模板与仓库 `AGENTS.md` 的
  「The change is the assignment unit … while a sibling is unfinished.」那一段（`:15714` 取模板、`:15720` 取仓库文件，
  仓库侧按前提可 SKIP），并断言 `references/protocol.md` 含四个 change 守卫的名字（`:15708-15712`）；
  `tests/flip-p23.sh:234` 有「删掉清单第 10 点 → 必红」的翻转对。
- `tests/smoke.sh` §19 的 `os_pipeline_hits()`（`:9686`）另有同题一条：按 awk 数 `openspec.md` 的编号清单，不是 10 就报
  `CHECKLIST-COUNT`（`:9711`），并配一条 `os_flip_red` 翻转（`:9795`）——**同一件事两道，动清单必红两处**。
- `tests/smoke.sh` §13c 的 `p237_has`/`p237_absent`（`:7220`/`:7228`）对四个面断言 `long-job-suspend` 的车道三态锚点与
  **退休措辞**（`Harvest every job|before your turn ends|costs a turn` 不得回潮，见 `:7212-7245`）。
- `tests/smoke.sh` §19 的 `os_pipeline_hits` 断言 `openspec.md` 的清单条数、`AGENTS.section.md.tmpl` /
  `PROTOCOL.md.tmpl` / `SKILL.md` / `workflows.md` 都含 `opsx-apply`、`ACCEPTED`、`independent` 与用户确认措辞。
- `tests/smoke.sh` §3b/§11/§14b/§15c/§18b/§18/§33 也读其中若干文件（git 归 PM、已删命令不得回潮、help 与 harness
  清单、拆分不变量、英文正文不变量、`section-paths.tsv` 的选段自检）。
- **基线结论**：这条写作规则今天**一个字都不在**，而门禁全绿（`openspec validate --all --strict` → 21 passed /
  0 failed；`spec-refs.sh --check` → `undeclared 0`，rc=0）—— 即「门禁不持有它」这件事有当场的可证伪证据，
  不是宣称。
- 改这四个文件会被选中的段（`tests/section-select.sh --paths <四个文件>` 基线：`decision=RUN`、`sections=130`、
  `keys=28`）：`0 0b 0c 0d 2 4 4b 5 3b 6 6d 6e 6f 6i 7b 9 10 11 13c 14b 15b 15c 17 18 18b 19 33 12k`（含 prologue 与
  needs 传递）。apply 必须按选集跑，交付与复验各跑一次全量。

### 阅读：规格里「带证据的边界声明」今天长什么样（不变量保护的对象）

例：`AGENTS.section.md.tmpl` 的「One gate at a time … a queue past the cap is a loud FAIL naming the holder,
not a TIMEOUT. On a busy machine the panel timing lines … print the measured values and the load and skip visibly
instead of reporting a red the machine owes」——它带着**未观测到的边界与前提**（负载前提、三档采样），按本变更的
判据属于**必须留**的那一类。本变更的 diff 不得删掉任何这类句子（任务清单 2.1 逐句核对）。

## Goals / Non-Goals

**Goals**：判据进合同（按支撑判，不按语气）；三处表面各写可执行的几条（工人面 / PM 面 / 协议面）＋ PM 的评审读法
一行；把「由评审守、不设门禁」写成合同的一部分（含诚实边界）；把「这条规则有没有让文字更好」交给一次**可复算的
人读对照**，并写明为什么**不用** AI 评审打分。

**Non-Goals**：不改任何门禁断言/退出码/机器输出/配置键；不动产品代码（`scripts/**`、`extension/**`、`panel/**`）；
不改 `templates/report.md.tmpl` 与 `templates/task.md.tmpl` 的形状（不加栏位）；不删带证据的边界声明；不做语气
改造；不引入风格打分器；不动 `references/openspec.md` 的十条清单；不动 `pm-reply-discipline` 与 `long-job-suspend`
守着的段落。

## Decisions

### 1. 判据是「支撑」，并把「不是语气」写成规格条款

规格 R1 的正文同时写三件事：留下条件（点名测量/反例/推理缺口/未观测边界之一）、删除默认（点名不到就删）、
**禁止读成语气建议**（`MUST NOT be phrased as "be more confident" …`）。第三件事是这次立项最容易走偏的方向
（研究笔记的标题就是「不是让模型听起来更自信」），所以它进合同、进场景（场景 2 直接判「有没有语气指令」），
不只是设计里的劝告。

### 2. 三处表面各司其职；四条义务是同一套**义务**，不是同一段字节

| 面 | 为什么是它 | 它必须说的四条 |
|---|---|---|
| `templates/AGENTS.section.md.tmpl` | 每个工人阅读顺序的第 1 步就是 AGENTS.md；它渲染进每个项目的协议段 | 先答问题再给证据；点名不到的谨慎就是删；边界只在带证据时声明、带了就留；发现写明它改变了什么 |
| `templates/pm-prompt.md.tmpl`（`## Talking to the user` 内） | 该节已统管 user-facing output（代号规则、关键回复都在这里）；PM 每次启动都读到 | 同上四条（PM 对用户的语域） |
| `references/protocol.md` §11 下的 `### 11b.` | §11 就是「怎么向用户报告」那一节；会话之外的参考面，后代重读 | 判据本体 + 理由 + 保留代号规则 + **诚实边界**（没有工具能证明某个活着的作者照做了） |
| `references/workflows.md` §E | PM 复核交付物时的 runbook | 一行读法：每条发现写明改变了什么；没支撑的谨慎是待删项；更长更防御 ≠ 更强的证据 |

四面的**语义锚点**（apply 定稿措辞，但下列语义一个都不能丢）：`answer … first`、`names`（点名可核查的东西）、
`delete`（删除默认）、`boundary … evidence`（带证据的边界声明留下）、`what it changed`（发现的后果）、
`no tool can verify`（诚实边界，协议面）。规格按**义务**写，不 lock 整段文字（避免任何润色都变红）。

### 3. 落点：`## Talking to the user` 内加段；协议用 `### 11b.`；AGENTS 段加一条 bullet

- PM 模板：加在代号规则段之后、关键结论段之前；**不新开顶级章节**（该节已统管 user-facing output；两份副本
  必然漂移）。草案（英文，7 行）：

  ```
  **Answer the reader's question first, and keep only the sentences that carry their evidence.** Lead with the
  conclusion and the next step; how you got there comes after. A caution, a limitation or a warning stays only when
  it names something checkable — a measurement, a counterexample, a gap in the reasoning, a boundary you did not
  observe; when the evidence no longer supports a claim, say what it does support rather than narrowing the claim,
  and never delete a boundary sentence that carries its fact. Every finding states what it changed — the
  implementation, the next step, the conclusion, or nothing; an observation that changes nothing is not part of the
  answer. When in doubt, delete: a short answer that answers the question beats a defensive one. See
  `{{SKILL_DIR}}/references/protocol.md` §11b.
  ```

- 工人模板：Non-negotiable discipline 里**「范围/报告/磁盘交接」那条 bullet 之后**加一条（同题相邻），
  **不碰**车道三态 bullet、不碰「The change is the assignment unit」段（§12k 的 awk 区间），措辞里不得出现
  §13c 的退休短语（`before your turn ends` 等）。草案：

  ```
  - **A report is read for its answer first, and every sentence carries its evidence**: state what the brief's
    question resolves to before the account of how you got there. A caution, a limitation or a boundary earns its
    place by what it cites — a measurement, a counterexample, a gap in the reasoning, or a boundary you did not
    observe — and a sentence that names none is deleted; one that carries its evidence stays. Every finding states
    what it changed: the implementation, the next step, the conclusion, or nothing; an observation that changed
    nothing stays out of the body. See `{{SKILL_DIR}}/references/protocol.md` §11b.
  ```

- 协议：§11 之后加 `### 11b. A caution earns its place by what it cites; a finding earns its place by what it
  changes`（`###` 子节在协议里是既有形态：5b-1、9b-2、9b-3、The tool checks step 3 …）。内容 = 判据 + 理由
  （短，两段）+ 诚实边界；**§11 既有的代号段原文一字不动**。apply 若更愿意用 `## 11b.` 顶级节也可以 —— 规格
  写的是「协议里面向用户的报告那一节」，不是标题层级。

- runbook：§E 现有的三条之后加一段（草案）：

  ```
  **Read for what each finding changes.** While you read the report and the review record, check that every finding
  states what it changed — the implementation, the next step, the conclusion, or nothing. A caution that names no
  fact, counterexample, reasoning gap or unobserved boundary is a finding to delete, not evidence of thoroughness,
  and a longer or more defensive report is not stronger evidence. This is a reading rule, not a gate: no section
  checks the wording (see `references/protocol.md` §11b).
  ```

### 4. 由评审守，不设门禁：理由、代价与补偿

**理由**：用户 2026-10-14 的文本类裁定（门禁只判可观察的行为与状态，措辞/排版/术语由设计与评审把关）；
并且 `references/openspec.md` 的十条清单被 §12k（`:15702`）与 §19 的 `os_pipeline_hits`（`:9711`，配 `flip-p23.sh:234`
的翻转）各钉死一条 —— 把评审口径加进那份清单就会**改门禁断言**，违反本变更自己的不变量。所以评审读法落
`references/workflows.md` §E。

**代价（写明）**：没有门禁 ⇒ 以后谁删掉某面的一段话，没有东西会红；四份文件会随其它改动一起被编辑。

**补偿**：① 规格里明写「由评审守、由评审点名丢了它的那个面」，评审读 diff 是制度化的动作（PM 每次合并前读
diff 已经是纪律）；② 这四个文件都落在既有门禁段的选集里（改它们会跑 §12k/§13c/§14b/§15c/§18/§19 等），大改
会被这些段的既有断言（以及它们对这四个文件其它合同的要求）照出来；③ 对照（第 5 节）会在规则落地后读一次真实
产物；④ 本条要求的两个失败方向都写进场景（「面丢了 → 评审点名」「证据句被删 → diff 逐句核对」）。

与 `P264`（门禁瘦身）的关系：P264 若复核断言分类，本 change **不新增**任何文本类断言，因此不需要它的分类；
它要清理的是既有的文本类断言（例如 §12k 的 `CHECKLIST-COUNT` 与 §13c 的锚点短语），与本变更不冲突。

### 5. 对照设计（规格 R4 的展开）

**臂**：两个夹具项目（各自 `team init --session write-cmp-w / write-cmp-o --gates true`），除工人协议段那一条
bullet 外**逐字相同**；`diff -u arm-w/AGENTS.md arm-o/AGENTS.md` 的输出必须是**恰好那一段**（这条差异就是
「一次带、一次不带」的可核对形式）。任务书同一份（字节相同）、同一 `category:`、同一模型、各自 `--fresh`
会话；两边的 `state/dev.env` 里记录的模型必须相等（不等就作废重跑）。

**任务**：一次**刻意小**的受限分析（例如给一份带缺口的小材料，要求回答一个是/否问题并给证据）。造一个容易
触发防御性文字的场景（材料里有一个**未观测到的边界**与一个**要人判的点**），但规模控制在一次会话内完成。

**评分口径**（`compare/rubric.md`，**在派单之前**写定并记时间与哈希；不得在看到报告后改）：

1. 读一遍之后，读者能否写出报告的**答案**与**下一步**（是/否 + 原文摘录）；是否需要回头找答案。
2. **没有支撑的谨慎**的条数（限定/警告/边界句中，没有点名测量/反例/推理缺口/未观测边界者）。
3. **不写后果的发现**的条数（没有写明改变实现/下一步/结论/什么都不改者）。
4. **删掉不丢信息的句子**的条数（删除测试）。
5. 阅读吃力程度：**1–7 分**（与证据 2 的人类读者量表同形），以及读者有没有被迫重读。

**盲法与封存**：两份报告按掷硬币的顺序复制成 `arm-A.md` / `arm-B.md`（除复制外零编辑），臂→标签的映射写进
`mapping.sealed`，**读者读完并填完 `sheet.md` 之后**才解封。诚实限制：读者知道被测规则，所以 rubric 的前三项
问的是**信息**（能不能答出、有多少句没支撑、有多少发现没后果），第 5 项（主观吃力感）放在最后。

**判定规则**（同样先写定）：这不是统计实验。若带规则的那臂**更吃力**且第 2–4 项**没有更好**，则**改规则文本**
（更短、更贴读者）后再归档；若它不吃力（或更省力）且第 2–4 项更好，规则按原样归档。结论写进对照的
`README.md` 与复验记录，并写明样本限制（一个任务、一个读者）。

**为什么不用 AI 评审打分**：规格 R4 的数字（+1.22 / −0.70、1,276/1,280、理解相同）——用 AI 打分就是拿一个已知
偏爱这类文字的尺子去量「删掉这类文字」的收益。读者是**人**（用户；用户明确委托时 PM 可代理，且记录里必须写明
是代理）。

**材料路径**：`docs/team/reports/<对照任务 ID>-<席位>/compare/`（`rubric.md`、`arm-A.md`、`arm-B.md`、
`sheet.md`、`mapping.sealed`、`README.md`；夹具的 AGENTS.md 差异与两份 `state/dev.env` 片段一并留档）。

**成本**：两次真实席位会话 + 一次人读。任务刻意做小；这是一个**判断**，不是统计。

### 6. 不变量与它的证明方式（任务清单第 2 节）

| 不变量 | 怎么证 |
|---|---|
| 不删带证据的边界声明 | diff 逐句列出删除项，每条说明它点名不到任何事实/缺口；列出留存的边界句（如车道三态段、AGENTS 的模板比对段）|
| 不新增/修改/删除门禁断言与退出码 | `git diff --stat` 只含四个文件（＋授权的 `AGENTS.md`）；对四个文件的新锚点词在 `tests/` 里 `grep` 命中 0；跑选中段的 `smoke.sh` 全绿 |
| 不把判据变成仪式（不加栏位） | `templates/report.md.tmpl`、`templates/task.md.tmpl` 不在 diff 里；报告形状零新增栏位 |
| 不动既有段落 | `key-replies` 的关键结论段、车道三态段、§11 代号段、§12k 的十条与模板比对段逐字节不变（`git diff` 只显示新增行与预期删除行）|

### 7. 与既有 requirement 的关系（逐条对齐，避免平行陈述）

- `key-replies#The key-conclusion duty is shipped on its instruction surfaces and held by the gate`：**不同题**
  （那条讲「关键结论先发布」的义务与它自己的门禁）。本变更在同一模板文件里**新增另一段**，不删不改它；
  本变更的规格里还专门写了「带证据的边界声明不删」，与那条的既有内容方向一致。
- `dispatch#The worker prompt makes suspension on background jobs a third legal turn end and teaches the lane by
  purpose`：那条要求四个面（含本变更动的模板与 §E）都有车道三态；本变更加在**别的**小节，且新增文本里不得
  出现那条禁掉的退休措辞。
- `verification#The record states what was verified`：讲**机器写的复验记录**的内容；本变更讲**发现自身的后果**，
  范围不同（前者是 `team review` 写什么，后者是人写什么）。
- `boundary#Specs are the contract`：本 delta 不含 `docs/team/…` 引用，不提未登记的记录 id；证据数字写在规格
  正文里（规格自洽，不把证据委托给账本）。

## Findings（附带发现，写明它改变了什么）

1. **`references/workflows.md:17` 的「the eight-point checklist」与 `references/openspec.md` §4 的十条不一致**
   （§12k 也按十条断言）。改变的是：照 §0 的阶段表去核对提案审查的人会数错条目。处置：**不在本变更范围**
   （本变更只动 §E），交 PM 另记一条（修法为那一行改成 ten-point 或去掉数字）。它不改本变更的任何设计。
2. **本仓 `AGENTS.md` 是模板的渲染副本，而门禁只逐字比对其中一个段落**（§12k 7.4）。改变的是：模板改了而
   `AGENTS.md` 不重渲染时，本仓工人读到旧协议段，门禁**看不见**这次漂移。处置：裁定点 3（apply 授权重渲染，
   或 PM 自己跑；渲染只动 `<!-- teamsmith:begin -->`…`<!-- teamsmith:end -->` 标记块，`team_write_section` 就地
   刷新，幂等）。
3. **工人注入提示词（`scripts/lib/cmd-agents.sh`）不含这条规则**，规则对工人的到达路径是 AGENTS.md（阅读顺序
   第 1 步）。改变的是：一个不读 AGENTS.md 的自定义 adapter 工人看不到它。处置：**本变更不动产品代码**
   （任务书不变量）；若 PM 要它也进注入提示词，另开一条 `scripts/**` 授权的任务书。

## Risks

| 风险 | 影响 | 处置 |
|---|---|---|
| 被读成「更自信」的口号 | 恰恰是研究点名要避免的方向（听着果断 ≠ 有支撑） | 规格明文禁止语气措辞 + 场景 2 直接判它；协议 §11b 写明「不是 tone 规则」 |
| 被读成「删掉一切谨慎」 | 会删掉带证据的边界声明（本项目最贵的一类句子） | 规格 R1 末句 + 场景 1/3；任务清单 2.1 逐句核对删除项 |
| 没有门禁 ⇒ 以后静默丢失 | 规矩腐蚀 | 规格写「评审守 + 点名丢它的面」；对照跑一次真实产物；四个文件改动的选集覆盖既有段（决策 4） |
| 对照 n=1，读不出差别 | 一次判断被误当结论 | 判定规则先写定、结论只作「改写 or 保留」的输入；样本限制强制写进记录；不做统计宣称 |
| 盲法不彻底 | 读者可能认出带规则的那臂 | rubric 前三项问信息、主观项放最后；映射读前封存；限制写明 |
| 与在飞写者撞车 | 四个文件被同时改 | 三个文件无在飞写者；`references/protocol.md` 的在飞写者是 `gate-lock-hygiene`（§9b），本变更写 §11/§11b，**不同节**；交付前 `git merge main`，冲突按双方保留。`P264` 只读它们的既有断言 |

## Open Questions

无改变「要建什么」的未决项。需要 PM 拍板的是 proposal「需要 PM 裁定的点」1–7，每条都给了推荐版本；PM 的裁定
进 `docs/team/reviews/writing-discipline-proposal.md`，apply 任务书按它落笔（若与推荐不同，apply 按裁定改写判定）。
