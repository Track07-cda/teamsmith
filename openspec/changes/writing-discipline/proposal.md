# writing-discipline · 写作纪律：先答读者的问题，谨慎必须有证据

## Why

用户 2026-10-15 给了外部研究（`NB-Corp/gpt-with-taste` 的 `docs/research.md`），并点出本项目的现实：**AI 写、
AI 验**。如果 AI 评审系统性偏爱防御性文字，那么我们的验证回路**本身就在奖励它**——报告越长越谨慎、信息量
不变，而评审读的是报告。用户此前已多次点名同一现象：PM 答复里的仪式化段落、重复的「如实说明」、道歉段落、
装饰性标记与自造简写。

四组证据（本次提案逐条核过原文；来源与证据层级写明）：

1. **防御性改写会软化论断**。Junchi Liao《Defensive Writing in GPT Models》（arXiv:2610.11355，v1 2026-10-08，
   v2 10-13）对 77 段英文计算机科学段落做改写实验：让模型「润色」时 9% 的论断被软化；让它**预先回应审稿人
   可能的质疑**时升到 **33%**，撤回率从 **0.2% 升到 9.5%**。摘要原文：「checked against the full papers,
   GPT-6-astra's retractions mostly correct overstated claims …, but **most added qualifications are
   redundant**」；「the qualifications follow the request: they are absent under polishing, appear with any
   request to check the claims, and peak when the prompt names a reviewer's concerns」。
2. **这套文字是写给想象中的审稿人的，不是写给读者的**。同一篇论文的读者实验：AI 评审给「回应审稿人」的版本
   打分**更高**（十分制 **+1.22**），人类读者（**4 人**，小样本）读起来**更吃力**（七分制 **−0.70**），
   **理解正确率相同**。摘要的结论句：「AI reviewers score such rewrites higher and score them lower once only
   the qualifications are removed, while human readers in a small study find them harder to read. **Combining
   AI writing with AI review may reward qualifications that readers pay for.**」（+1.22/−0.70 的具体数字取自
   该研究的笔记（recipe 的 `docs/research.md`），方向与摘要一致；本提案不引用未核实的第三手转述。）
3. **AI 评分不能当风格尺子**。ACL SRW 2026 `2026.acl-srw.33`《Confidence as a Tie-Breaker》在 5,120 条多语言
   QA 上实测：修好多语言模板并加质控后，逐点准确率 **99.8%**、措辞自信与否几乎无差，但两两比较里
   **1,276/1,280** 偏向措辞自信的一方（摘要原文）。NAACL 2025 的 **EMBER**（`2025.naacl-long.452`）同样报告
   LLM 判官对认识论标记（尤其不确定词）有负向偏差，判定会被措辞左右而不只看内容。
4. **发现要有后果**。arXiv:2605.20668《On the limits and opportunities of AI reviewers》（45 位领域科学家、
   469 小时、2,960 条审稿意见、82 篇 Nature 系论文）把审稿意见拆成 correctness/significance/evidence，并把
   「对次要问题过度苛责（overly critical stance on minor issues）」列为 AI 评审的 16 个反复出现的弱点之一。
   研究笔记据此给出的做法：一条意见只有在**给出事实、反例或推理缺口**时才值得改一句；**想象中的反对意见不配
   得到一个段落**。对我们的报告与复验记录：一条发现要先说清它**改变了什么**。

所以本变更要立的**判据不是语气**，而是**支撑**：这句谨慎有没有可核查的东西在身上。三处表面（工人提示词模板、
PM 提示词模板、协议里「怎么向用户报告」那一节）各写可执行的四条，PM 复核交付物的读法加一行，**不设门禁断言**
（用户 2026-10-14 的文本类裁定：措辞与文风由设计与评审把关）。

## What Changes

### 1. 判据进合同（写进规格，不写措辞）

- **一句谨慎只有在点名可核查的东西时才留下**：数据/测量、反例、推理缺口、未观测到的边界；否则删掉。证据不再
  支持某个论断时，改成说清证据**支持什么**，不是把论断收窄。
- **一条发现要写明它改变了什么**：实现 / 下一步 / 结论 / 什么都不改。什么都不改的观察不进正文（最多进证据
  附录）；后果写在发现自己的句子里，**不新增必需栏位/章节**（那会把判据变成仪式，栏位会被填满而判断消失）。
- **不变量**：带事实或缺口在身上的**边界声明不删**——它们正是判据留下的那一类；规格明文禁止把这条读成
  「更自信 / 更果断」的语气建议。

### 2. 三处表面 + 一处评审口径（各写可执行的几条）

| 表面 | 谁读它 | 它要写什么 |
|---|---|---|
| `templates/AGENTS.section.md.tmpl` | 每个工人（阅读顺序第 1 步就是 AGENTS.md） | 先答简报问的问题、再给证据；能删就删（点名不到东西的谨慎就是删）；边界只在带证据时声明、带了就留；发现要带后果。英文短块，落在 Non-negotiable discipline，避开车道三态段与 §12k 逐字比对的那一段 |
| `templates/pm-prompt.md.tmpl` | PM（每次启动注入） | 同样的四条，落在既有的 `## Talking to the user` 小节（该节已统管 user-facing output）；不新开章节、不动关键回复段与代号段 |
| `references/protocol.md` §11 | 会话之外的参考面，后代重读 | 判据本体 + 理由（按支撑判、不按语气；写给想象中的审稿人的文字会被 AI 评审奖励，代价由读者付），保留既有的代号规则，并写明**诚实边界**：没有工具能证明某个活着的作者照做了 |
| `references/workflows.md` §E | PM 复核交付物时 | 一行读法：每条发现写明它改变了什么；没有支撑的谨慎是**一条待删的发现**，不是周全的证据；更长更防御的报告不是更好的证据 |

四条的措辞由 apply 阶段定稿；规格只写义务（谁必须说什么），不 lock 整段文字。

### 3. 由评审守，不设门禁（D170）

**不新增、不修改、不删除任何门禁断言**，不改退出码、不动产品代码（用户 2026-10-14 裁定：文本类不进代码门禁；
门禁只判可观察的行为与状态；为措辞本身立的断言属于要清理的那一类）。因此评审口径落在 `references/workflows.md`
§E，**不**落进 `references/openspec.md` 的提案审查清单——那份清单被 `tests/smoke.sh` 两处断言（§12k `:15702`、§19 的
`os_pipeline_hits` `:9711`）与 `tests/flip-p23.sh` 的翻转对钉死为**恰好十条**，加第十一条等于同时改门禁断言（违反本变更
自己的不变量）。

代价写清：没有门禁 ⇒ 以后有人改这几处文件时，没东西会红。补偿是评审（PM 每次读 diff 与交付物）＋四个文件的
改动都会选进既有门禁段的选集（改这几个文件会跑 §12k/§13c/§14b/§15c/§18/§19 等段，它们守的是各自既有的合同，
会顺带把「文件被大改」暴露出来），以及规格里明写「这条由评审守、由评审点名丢了它的那个面」。

### 4. 验证手段：一次由人读的对照（设计见 design.md）

同一份任务派两次，两个臂**只差这一段文本**（其余逐字相同：同一份任务书、同一类别与模型、各自 fresh 会话）；
**由人**按**事先写定**的评分口径读两份报告并填表，臂与标签的映射**读前封存**；材料（两份原始报告 + 评分口径 +
读者表）落在记录点名的路径上，可复算。**不采用 AI 评审打分**，理由就是证据 2/3：AI 评审奖励的正是这条规则要
去掉的那类文字。样本限制（一个任务、一个读者）写进记录，不当统计结论用。

### 5. 范围外（正面写清）

不改门禁断言/退出码/机器输出/配置键；不动产品代码（`scripts/**`、`extension/**`、`panel/**`）；不删带证据的
边界声明；不做「更自信」的语气改造；不引入风格打分器；不改报告模板与任务书模板的形状（`templates/report.md.tmpl`
`templates/task.md.tmpl` 零改动：判据写在 AGENTS 段里，不改成栏位）；不动 `references/openspec.md` 的十条清单。

## Capabilities

### New Capabilities

- **`writing-discipline`**（新能力）：四条 ADDED requirement ——
  ① 谨慎只带证据留下（判据本体 + 「不删带证据的边界声明」不变量 + 禁止读成语气建议）；
  ② 发现必须写明它改变了什么（且不新增必需栏位）；
  ③ 规则随三处表面与评审读法发出、由**评审**而非门禁守（含诚实边界）；
  ④ 规则的效果由**人读的对照**判定，AI 评审打分不得作为接受信号（含理由的数字）。

**不新增任何 MODIFIED**：本变更不改既有 requirement 的行为。两处相邻但不同题，已在 design 里逐条对齐：
`key-replies#The key-conclusion duty is shipped on its instruction surfaces and held by the gate` 守的是 PM 模板
里的**另一段**（关键结论先发布，本变更一个字不动），且本变更的「带证据的边界声明不删」正是对它的保护；
`dispatch#The worker prompt makes suspension on background jobs a third legal turn end and teaches the lane by
purpose` 守的车道三态段同样逐字不动（模板、协议、workflows §E2 四处），本变更加的是不同小节。

## Impact

- **提示词与文档面**（本变更的全部产品面）：
  `skills/teamsmith/templates/AGENTS.section.md.tmpl`（加一条 bullet）、
  `skills/teamsmith/templates/pm-prompt.md.tmpl`（在 `## Talking to the user` 内加一段）、
  `skills/teamsmith/references/protocol.md`（§11 下加 `### 11b.` 子节）、
  `skills/teamsmith/references/workflows.md`（§E 加一行读法）。
- **本仓自己的 `AGENTS.md`**（PM 独占）：它是模板的渲染副本（`cmd-project.sh` 的 `team_render` + `team_write_section`
  就地刷新标记块）。模板改了而它不重渲染，本仓工人读到的还是旧协议段，而门禁只逐字比对「change is the assignment
  unit」那一段 —— 静默漂移。见裁定点 3。
- **规格面**：新增 `openspec/specs/writing-discipline/spec.md`（归档后），delta 在
  `openspec/changes/writing-discipline/specs/writing-discipline/spec.md`。
- **夹具/对照面**：对照材料落在 `docs/team/reports/<对照任务 ID>-<席位>/compare/`（报告槽位之内，不入产品面）。
- **兼容性**：无运行时行为变化、无新配置键、无状态写入、无面板改动、无退出码变化、零门禁断言变化；`openspec validate
  --all --strict`、`spec-refs.sh --check`、`ledger-ban.sh` 保持绿。
- **在飞写者**（逐个核过在飞 change 的 Impact）：三个文件无在飞写者；`references/protocol.md` **有**——
  `gate-lock-hygiene` 写它的 **§9b**（排队纪律），本变更写 §11/§11b（面向用户的报告那一节），**同文件不同节**，
  apply 交付前 `git merge main`，冲突按双方保留。其余在飞 change（`help-robustness`、`orphan-visibility`、`slash-team`、
  `tmux-identity-scope`）只**引用**这些文件，写集不含它们。`P264`（门禁瘦身）读这四个文件的既有断言；本变更不动断言，
  不重复它的工作。
- **排期**：一个 apply 席位（四个文件 + 可选的本仓 AGENTS.md 重渲染），verify 由**另一席位**在独立检出上重跑并
  做对抗读；对照与用户读在其后（裁定点 4）。

## 需要 PM 裁定的点（提案按推荐版本落笔）

1. **change id = `writing-discipline`**。任务书头部是 `change: -`（propose 阶段 change 目录还不存在，chicken-and-egg），
   所以 id 由本提案定；**后续 apply/verify 的任务书必须写 `change: writing-discipline`**（否则 `team change status`
   与 dispatch 的 change 守卫看不到它们）。推荐：是。
2. **评审口径落 `references/workflows.md` §E**，不落 `references/openspec.md` 的提案审查清单（§12k `:15702` 与 §19 的
   `os_pipeline_hits` `:9711` 各一条断言、外加 `flip-p23.sh:234` 的翻转对，把那份清单钉成恰好十条；加第十一条就是改门禁断言）。推荐：是。
3. **本仓 `AGENTS.md` 是否在本变更里重渲染**。推荐：**在 apply 任务书里授权该文件**（只刷新 `<!-- teamsmith:begin -->`
   … `<!-- teamsmith:end -->` 标记块），否则本仓工人读到的仍是旧协议段而门禁看不见。若 PM 不愿授权，apply 报告写
   `BLOCKED:` 并把渲染命令交给 PM。
4. **对照的执行放在哪个阶段**。推荐：verify 阶段由**独立席位**跑（构造两臂 + 派两次 + 交付盲包），人读由**用户**
   完成（用户明确委托时 PM 可代理，且必须写明是代理）；对照不通过不改产品，只决定**这段文本要不要改写**再归档。
5. **工人注入提示词不动**（`scripts/lib/cmd-agents.sh` 属产品代码，任务书不变量禁止）。规则的到达路径是工人读
   AGENTS.md（阅读顺序第 1 步）。若 PM 要它也进注入提示词，那是另一条任务书（需要 `scripts/**` 授权）。
6. **附带发现（本变更不做，交 PM 记录）**：`references/workflows.md` §0 的阶段表写「the **eight-point** checklist」，
   而 `references/openspec.md` §4 是**十条**（§12k 也按十条断言）。它改变的是：读者照 §0 去核对时会数错条目，
   修法是那一行改成 ten-point（或不再写数字）。不在本变更范围（本变更只动 §E），**本提案不动它**，只点名。
7. **delta 形状：新能力 + 四条 ADDED**（而不是去 MODIFIED `key-replies`/`dispatch` 的既有 requirement）。推荐：是 ——
   题不同（那两条守的是各自段落的义务与机制），且新增能力不必碰别人的既有场景逐字保留的要求。

## Acceptance（apply / verify 阶段执行；本阶段只写提案，不跑）

```bash
# 门禁（改这四个文件时会被选中的既有段，容器里跑更稳：tests/container-tmux.sh -- …）
bash skills/teamsmith/tests/section-select.sh --paths \
  skills/teamsmith/templates/AGENTS.section.md.tmpl skills/teamsmith/templates/pm-prompt.md.tmpl \
  skills/teamsmith/references/protocol.md skills/teamsmith/references/workflows.md
bash skills/teamsmith/tests/smoke.sh --select <上面打印的段号>      # 至少覆盖 12k / 13c / 14b / 15c / 18b / 19 / 3b / 11
bash skills/teamsmith/tests/smoke.sh                                # 交付与复验前各一次全量（TEAM_SMOKE_FAST=1 只在批量里用）
# 规格与账本
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
bash skills/teamsmith/tests/spec-refs.sh --check
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
# 本变更自己的不变量（第 2 节的三条）
git diff --stat -- skills/teamsmith/ | grep -vE 'templates/(AGENTS.section|pm-prompt)\.md\.tmpl|references/(protocol|workflows)\.md'   # 必须为空
grep -rcE 'answer the reader|<本变更用的锚点词>' skills/teamsmith/tests/    # 门禁不读这些措辞：0 命中
# 投影自证（归档会写出的规格树必须自洽）
rm -rf /tmp/wd-trial && mkdir -p /tmp/wd-trial && cp -a openspec /tmp/wd-trial/openspec \
  && (cd /tmp/wd-trial && "$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" archive -y writing-discipline \
      && "$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict)
```

对照（第 4 节，verify 阶段）的命令与路径不写在这里：`tasks.md` 第 3 节逐条给出，产物在
`docs/team/reports/<对照任务 ID>-<席位>/compare/`。

## 本阶段已跑（propose 验收，2026-10-15）

```bash
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict   # → 22 passed, 0 failed（含本 change）
bash skills/teamsmith/tests/spec-refs.sh --check                          # → judged 111 / undeclared 0; rc=0
bash skills/teamsmith/tests/ledger-ban.sh --names-file …                  # → hits=0 rc=0（原文见报告）
git diff --check && git status --short                                    # → rc=0（原文见报告）
bash skills/teamsmith/tests/section-select.sh --paths <四个文件>           # → 基线选集（写进 design）
```
