# P300 · 提案：写给用户的回复必须发布到关键回复页（change `replies-for-the-user-are-published`）

agent: dev   status: delivered   time: 2026-10-16
branch: `task/P300-answer-must-be-posted-propose`   PR/MR: -（local 模式：分支留本地，PM 复验后本地合并）
phase: propose   change: `replies-for-the-user-are-published`（2 条 MODIFIED `key-replies` + 1 条 ADDED `panel`）
修订：第 3 轮（PM 的提案复核：内容要求的反向句 + 面板那一行的自测题；第 1、2 轮见文末）

## 结论（先给答案）

**提案在磁盘上，产品文件一个字节都没改；apply 之前等 PM 的提案评审。** 判据按用户第二次澄清写成**按读者**：

- **写给用户的回复 → 必须发布**：回答用户的问题、汇报状态与进度、给出结论或裁定、请用户决策、交付与复验的要点摘要，
  以及任何其他读者是用户的回复；**不论长短、不论话题大小**；
- **不算**：写给 `pulse`/巡检的门控回执、写给其他席位（工人）的派单与协调、写给另一个项目 PM 的跨项目消息、工具自动
  生成的回执——读者不是用户；
- **判不准时按「写给用户」处理**（用户报的是漏标记，宁可多一条也不要漏一条；PM 可删这一句，见提案裁定点 5）。

四条验收：`validate`、`ledger-ban`、`git diff --check && git status --short` **三条绿**，`spec-refs.sh --check` **红**
——红的是**既有**缺陷（`extension-slash` 规格引用了声明表里不存在的槽位形状），与本提案无关，基线对照在 §3。

**哪三处**（判据进三处指令面，共享冻结 token `written for the user`）：

| 表面 | 落点 | 加什么 |
|---|---|---|
| `templates/pm-prompt.md.tmpl` | `:31-35` 现有那段整体改写 | 按读者判的规则 + `written for the user` + 那句自问 `who is this reply written for?` + 不发布的三类 |
| `references/protocol.md` §4b | `:142` 常设义务那句 + 代码块后新段 | 同一判据；新段写「读者决定」（算什么、不算什么、判不准怎么办） |
| `SKILL.md` | `:54` command table 行 + `:250` bullet | 触发清单改成 `any reply written for the user: …`（两处副本同改） |

**门禁断言什么**（D170：只两类，措辞/语气不设断言）：① **存在性**——三处各带 token `written for the user`（command
table 用 `row:` 前缀，必须落在 `| Key replies |` 行内），任一处丢了 → 红并**点名那个面与丢的判据**；既有变异 ①②③
各自删段/换行后红文案里必须出现 `[written for the user]`，另加变异 ⑤「只把 token 换成 `written for a person`」→ 红 →
还原绿。② **行为**——`guide-example` 原样保留：模板里那行示例命令必须被真 CLI 接受（rc=0、`outcome=saved`、槽位 +1），
控制臂（+`--frobnicate-probe`）必须 rc=2、诊断含「未知参数」、槽位不变。「写给巡检/席位/别的项目 PM 不算」这一极
**不进断言**（没有它规则仍然成立；它属文本类，由评审把关）。

**Pulse 那一行**：第 5 页列表在导航行之后、槽位计数之前加一行来自 zh/en 表的说明（键 `replyPageNote`，推荐
`「这条回复是写给谁的？」——PM 写给用户的回复都在这里` / `"who is this reply written for?" — replies the PM wrote
for the user`）——**PM 复核要求这一行带上判据的自测题**，问题放句首（59 列截断时问题与「谁发布」都还在）；它是陈述
不是控件，页面只读不变；**诚实边界**写进规格与 design——面板不读聊天/会话/历史，无法自动检测用户刚问了什么、刚收到
了什么，不承诺自动标记。

## Deliverables

| Path | What |
|---|---|
| `openspec/changes/replies-for-the-user-are-published/proposal.md` | 用户两次口径（第二条为准）、现状复核（逐条带度量）、四块改动、裁定点 1–7、验收命令、Out of scope、修订说明 |
| `.../design.md` | 三处落点与推荐文本、token 的代价、门禁两类与红侧设计、面板那一行的位置与只读边界、与旧句「只发结论不发过程」的取代关系、风险与已知限制 |
| `.../tasks.md` | 0 冻结/基线/投影 · 1 三处指令面 · 2 门禁（含变异 ⑤） · 3 Pulse 第 5 页（含重建产物） · 4 裁定点落地 · 5 验收交付 · 6 独立验证 |
| `.../specs/key-replies/spec.md` | MODIFIED ×2：`Publication does not gate the normal answer or create work`（触发换成按读者 + 两极 + 判不准的默认）、`The key-conclusion duty is shipped on its instruction surfaces and held by the gate`（三处义务同判据、门禁失败形状补一条、写明只判在场与行为、诚实边界补「无人能判某条回复是不是写给用户的」） |
| `.../specs/panel/spec.md` | ADDED ×1：`The key replies page states what it is and who publishes into it`（第 5 页一行说明「这是 PM 写给用户的回复」+ 两条场景：两语言四档宽度都在 + 无 mouse target；「没有东西替用户标记」用记录到的读者调用只有有界 key-reply 块来钉） |

## 现状复核（我核过的度量）

- **触发今天只有三类时点，三处如此**：`templates/pm-prompt.md.tmpl:31`、`references/protocol.md:140`、`SKILL.md:54`
  （同文件 `:250` 是第二份副本）。**三处都没有「读者是谁」这条判据。**
- **拟用 token 三处 0 命中**：`grep -ciF "written for the user"` 对这三个文件都是 **0**（同一轮实测的另三个候选
  `the reader is the user` / `the reply is for the user` / `the user is the reader` 也都是 0）；`grep -c replyPageNote`
  对两张字符串表也都是 **0**。
- **门禁已有牙且过了 D170 分类**：`tests/key-replies.sh:1055` 的 `guide_spec()` + `guide_check_surface()` 逐条点名 +
  `kr_group_guide` 的四条变异 + `guide-example` 的真 CLI 对拍。今天实测 `--select guide` → **✓18 ✗0**。P264（已 done）
  的裁定「没有机器面、而那串字是某个要紧行为的唯一证据 → 留一条稳定 token」正是本变更新增锚点的归类。
- **旧句「只发结论、不发过程」按 PM 复核的裁法处理**：三处原有一句「publish conclusions, not process narration」。按
  读者判的话**不能**用它排除「写给用户的汇报」，但 PM 允许它作为**内容要求**保留；所以 delta 把它收成一则内容要求并
  写死反向句（「a reply written for the user is never held back because of what kind of reply it is … no reply
  becomes unpublishable by reading like process rather than like a conclusion」）。三处文本同口径改，design 决策 7
  与 tasks 1.5 都点名，改前/改后在 diff 里看得见。
- **基线**：`openspec validate --all --strict` → **22 passed / 0 failed**；`section-select.sh --paths <三处表面>` →
  `sections=133 / keys=26`（**不含 62**，见裁定点 6）。

## Verification evidence

### 1. `openspec validate --all --strict`

```bash
$ "$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
✓ spec/writing-discipline
Totals: 23 passed, 0 failed (23 items)          # 基线 22/0；本 change 进去后 23/0
```

### 2. 投影自证（归档会写出什么）

```bash
$ rm -rf /tmp/p300-proj2 && mkdir -p /tmp/p300-proj2 && cp -a openspec /tmp/p300-proj2/openspec
$ (cd /tmp/p300-proj2 && "$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" archive -y replies-for-the-user-are-published \
    && "$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict)
  + 1 added
Totals: + 1, ~ 2, - 0, → 0
Specs updated successfully.
Change 'replies-for-the-user-are-published' archived as '2026-10-16-replies-for-the-user-are-published'.
Totals: 22 passed, 0 failed (22 items)
```

既有场景**逐字保留**（MODIFIED 整条替换，所以这是必须核的一件事）：把归档后的 `key-replies` 规格与 HEAD 逐行比，
**被删掉的 `#### Scenario` 行 = 0、被删掉的 WHEN/THEN/AND 行 = 0**，新增 Scenario 行 = 1；条数对照：`key-replies`
11 条要求 / 场景 26 → 27，`panel` 44 条要求 / 场景 238 → 45 / 240。

### 3. `spec-refs.sh --check`（红，且是既有的）

```bash
$ bash skills/teamsmith/tests/spec-refs.sh --check ; echo rc=$?
undeclared openspec/specs/extension-slash/spec.md:47 docs/team/tasks/P1.md
spec-refs: judged 112 reference(s) (50 distinct) in 12668 effective line(s); retired 0; undeclared 1; id families used [D,E,F,M,P,V] named [D,E,F,M,P,V]
rc=1
```

**基线对照**（同一命令，`--root` 指向一份**只**把本 change 目录删掉的 `openspec/` 副本——其余在飞 change 照旧，
这样差的只有我这一份），以及「本分支没碰那个文件」：

```bash
$ rm -rf /tmp/p300-base2 && mkdir -p /tmp/p300-base2 && cp -a openspec /tmp/p300-base2/openspec \
    && rm -rf /tmp/p300-base2/openspec/changes/replies-for-the-user-are-published
$ bash skills/teamsmith/tests/spec-refs.sh --check --root /tmp/p300-base2 ; echo rc=$?
undeclared openspec/specs/extension-slash/spec.md:47 docs/team/tasks/P1.md
skip: no ledger under /tmp/p300-base2/docs/team — 没有账本可引用；声明表与 id 族键照判，退场判据照判（pending change 仍在）
spec-refs: judged 112 reference(s) (50 distinct) in 12626 effective line(s); retired 0; undeclared 1; id families used [D,E,F,M,P,V] named [D,E,F,M,P,V]
rc=1
$ git show HEAD:openspec/specs/extension-slash/spec.md | grep -n docs/team/tasks/P1.md
47:- **WHEN** the user submits `/team dispatch dev P1 docs/team/tasks/P1.md`, and then `/team config set TEAM_AGENTS "x"`
```

两侧的 undeclared 计数都是 1、同一行；那行出自 `86c7ada9`（slash-team 归档，PM 的提交），本分支未碰该文件。
**结论：这条红与本提案无关；修它在 PM 的地盘**（提案裁定点 7 给了两种修法）。我**没有**动 `openspec/specs/**` 与
`tests/spec-ledger-refs.tsv`。

### 4. `ledger-ban.sh`

```bash
$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt" ; echo rc=$?
ledger-ban: names：名单已配置（$HOME/.pi/team/forbidden-names.txt，命中即红）
ledger-ban: root=… scope=published files=1690 hits=0 names=ok user=resolved
rc=0
```

### 5. `git diff --check && git status --short`

```bash
$ git diff --check ; echo rc=$?          # rc=0，无空白错误
$ git status --short                     # 无输出（报告提交前）
$ git log --oneline -3
1fd12375 docs(openspec): P300 review round — the content norm keeps its teeth, and the page carries the criterion's question
14474c41 docs(openspec): P300 rework — the reader criterion, and the change renamed to replies-for-the-user-are-published
f0a7ca65 docs(team): P300 report reworked for the reader criterion (change renamed)
```

## Decisions and deviations

- **判据换成按读者，而不是叠加**：用户第二条澄清说的是「总之就是不希望用户漏掉的回复…都要添加」，PM 也写明「以这条
  为准」，所以第一轮的「回答用户的问题」不再是独立触发，而是**写给用户的回复**的一个例子。三处的推荐文本按此重写；
  `answering a question the user asked` 这类旧说法如果留着，会让读者以为判据还是话题。
- **旧句「只发结论、不发过程」收成一则内容要求**（上面「现状复核」最后一条）：PM 复核裁定它可以作为内容要求保留、
  但**不许**拿它排除写给用户的汇报；delta 因此保留了它的内容面并写死反向句，三处文本同口径，diff 里看得见，
  免得复验者以为是我漏抄。
- **token 选 `written for the user`**：它是用户那句「写给用户的」的英文说法，三处都能自然嵌进去，今天三处 0 命中
  所以非空洞。代价明写在 design 决策 3：改词（例如换成 `the reader is the user`）就红，改 token 属于改合同。
- **「写给巡检/席位/别的项目 PM 不算」不设断言**：没有这一极规则仍然成立（判据是读者），它的缺失不会让规则反向；
  加一条 token 会让门禁去管文本，违反 D170。它由评审把关。
- **「判不准按写给用户」进了规格**（推荐，PM 可删，裁定点 5）：它把边界变成一句话而不是一道判断题，方向与用户诉求
  一致（漏标记才是问题）。删它不牵动其他任何东西。
- **change 改名** `answer-must-be-posted` → `replies-for-the-user-are-published`：旧名是上一轮判据的产物，会把范围
  误读窄；改名只动目录（`git mv`），没有别处引用它。**PM 的提案评审文件名请用新 id**
  （`docs/team/reviews/replies-for-the-user-are-published-proposal.md`）。
- **面板那一行选中「导航行之后、槽位计数之前」**：空 store 与降级读数会走早退分支（`layout.ts:1387`），放在这个位置
  它们也带这一行。代价是列表可视行数少 1（四档宽度下仍 ≥1 行；既有断言没有一条数行数，snapshot 组判的是渲染正确性
  而非逐字节比对）。
- **`panel.js` 必须重建**（提交产物）：apply 用 `bun install --frozen-lockfile && bash build.sh`；本机实测
  `registry.npmjs.org` 可达（HTTP 200）、bun 在 `$HOME/.bun/bin/bun`，这条不构成阻塞。
- **§62 的选段缺口**（`tests/section-paths.tsv:153` 不含这三处路径）：P257 留给 P264 而 P264 已 done 未收；提案列成
  裁定点 6 并**推荐补**，但不在本阶段替 PM 决定。
- 没有为了绿放宽任何既有断言；没有删/弱化任何东西；只改了我自己的地盘（`openspec/changes/**` 本 change 目录 + 本报告）。

## 本轮没验到的产品行为（如实列出）

- **产品门禁一律没跑**：本阶段只写提案，`key-replies.sh --select guide|--all`、`key-replies-pty.sh`、
  `smoke.sh --select 26,28,62`、`panel-strings.mjs`、`panel.js` 重建**都还没跑**（三处表面与面板一行都还没落笔）。
  它们在 proposal「Acceptance」的 apply 段与 tasks.md 里逐条列着。
- **没有任何工具能判「某条回复是不是写给用户的」，也没有工具能证明某个活着的 PM 照做了**——这是能力本身的诚实边界，
  写在规格里；本轮没有把这条限制缩水成一句好听的话。
- **`spec-refs.sh --check` 是红的**（既有缺陷，基线对照见 §3）；它要在 PM 处置裁定点 7 之后才会绿。
- 本轮**没跑全量门禁**（提案阶段没有产品改动）；也没碰主检出、没推送、没合并。

## 修订记录

| 轮次 | 触发 | 事实 |
|---|---|---|
| 第 1 轮（tip `1fd263b0`） | 用户第一条口径「对于用户的问题的直接回答必须标记关键回答」 | change `answer-must-be-posted`：触发 = 「回复的主要目的是回答用户的问题」，token `the user's question`，面板那行写「对你提问的回答与关键结论」 |
| 第 2 轮（tip `14474c41`→`f0a7ca65`） | 用户第二条口径「希望用户能够看到的回复都要添加；回复 Pulse 的、其他 agent 的不需要算」，PM 明示「以任务书新增的判据一节为准」 | 判据改成**按读者**（写给用户的都要发布；写给巡检/席位/别的项目 PM 的与工具回执不算；判不准按写给用户），token 换成 `written for the user`，面板那行改成「写给用户的回答、汇报与结论」，change 改名 |
| 第 3 轮（本轮，tip `1fd12375`） | PM 的提案复核（`06:26:25Z`）：结构检查全过，退回一处「判据比用户口径窄」+ 要求把自测题写进面板那一行 | 退回的那一条第 2 轮已经满足（PM 当时看的是第 2 轮之前的稿）；本轮补上 ① 把「只发结论、不发过程」收成内容要求并写死反向句，② 面板那一行带上判据的自测题 `who is this reply written for?` |

三轮之间**没有**产品文件改动；第 1、2 轮的产物只存在于 git 历史里（`1fd263b0`→`14474c41`→`f0a7ca65`），旧名目录已
`git mv` 掉。

## Suggested next steps

1. PM 写提案评审 `docs/team/reviews/replies-for-the-user-are-published-proposal.md`，逐条裁 1–7（默认按提案的推荐
   版本），pass 之前**不派 apply**。
2. apply 派单：写集与红线在 `tasks.md` 的抬头与 §1–3；验收命令在 proposal 的 Acceptance。
3. 裁定点 7 的既有红（`extension-slash/spec.md:47`）建议另行处置——它今天就让 `spec-refs.sh --check` 红，与本 change
   无关，但会让 apply 的同一条验收也红。
