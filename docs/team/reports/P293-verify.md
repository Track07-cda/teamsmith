# P293 · 按证据勾 `writing-discipline` 清单（归档前置）

- task: P293 ｜ agent: verify ｜ phase: apply ｜ change: `writing-discipline` ｜ specs: `writing-discipline` ｜ deltas: -（未写任何 delta）
- branch: `task/P293-writing-discipline-checklist`（local 模式，不推送）；交付 tip `7ee107da`（写本报告之前的 tip，本报告的提交在其后）
- 结论：**18 项按证据勾**（0.1–0.4、1.1–1.4、2.1–2.3、3.1–3.3、3.4、4.1–4.3），每项的证据写进 `openspec/changes/writing-discipline/tasks.md` 的条目里；**1 项如实留空**（3.5：rubric 口径的判定还不存在）；**5 项按任务书留给 PM**（5.1–5.5 独立验证）。清单从 24 项未勾变成 **6 项未勾**（`grep -c` 实测：未勾 6 / 已勾 18）。
- 写集只有 `openspec/changes/writing-discipline/tasks.md` 与本报告：产品、测试、规格、delta 零改动。

## 0 · 这次做什么、不做什么

**做**：把 apply 与对照阶段已经发生的事，逐条对着已提交的证据（作者报告、复验记录、提交号、命令与 rc）定位，能定位的勾上并写明出处；定位不到的留空并写明查了哪里。**不做**：不重跑门禁（任务书的验收只有三条命令）、不重做 V47 的独立复验、不替任何一步打分。所以下面的每个勾都是**对既有证据的核对**，不是一次新的独立验证；判定的权威仍在 `docs/team/reviews/V47.md` 与 PM 的合并记录里。

## 1 · 勾选清单（逐项：证据在哪 / 我核了什么）

| 条目 | 已提交的证据 | 我的只读复核 |
|---|---|---|
| 0.1 | `docs/team/reviews/writing-discipline-proposal.md`（04f7003b）＋ `docs/team/reports/P286-dev-bob.md` §0.1 的七行对照表 | 七个裁定点都能在表里找到落法；第 6 条改判为 `ten-point` 已在 §1.4 的实现里落地 |
| 0.2 | P286 报告 §0.2（改动前真实输出） | 改动前树 `f97a7f74`：`git grep -ci 'answer the reader\|what it changed'` 非零文件 = 0；`openspec.md` 编号条目 = 10；`report.md.tmpl` 的五个栏位不变 |
| 0.3 | P286 任务书第 4 条授权；提交 eb7aef6a；报告 §0.3（重渲染逐字比对、幂等） | 现树标记块计数 `BEGIN` = 1、`END` = 1；`AGENTS.md` 对 main 的 numstat = 22/3（只动块内） |
| 0.4 | `design.md` 记的基线（130 段 / 28 键）；P286 报告 §0.4 与「Verification evidence」；V47 §8.4 | 现树重跑 `section-select.sh --paths <四文件>`：`decision=RUN · sections=131 · keys=28`，键集与记录逐字同 |
| 1.1 | 提交 177ed0f1；P286 报告 §1.1；V47 §3 的逐面表 | 现树模板 72–77 行即那条 bullet；四条锚点各 1 命中；§12k 段与规格的比对段在选集里保持绿 |
| 1.2 | 提交 177ed0f1 与返修 902007ab；P286 报告「返修轮次 1」；V47 §8.1 的红→绿 | 现树末句已是「Delete what names nothing checkable…」；`pm-prompt.md.tmpl` numstat = 9/0（零删除 ⇒ 代号段与关键结论段原文未动） |
| 1.3 | 提交 2b9e46a2；报告里的 §11b 原文；V47 §3/§8.1 | 现树 §11b 在 833 行；`protocol.md` numstat = 21/0；`No tool verifies that a live author follows this rule` = 1 |
| 1.4 | 提交 2b9e46a2；报告里的 §E 原文；V47 §3 | 现树 `Read for what each finding changes` = 1；`openspec.md` 编号条目仍 = 10 |
| 2.1 | P286 报告 §2.1 的逐句判定表；V47 §8.5 #11 | 合并提交 6a03e25c 的删除行 = 4 行（名册、车道两行旧渲染、`eight-point`），与记录一致 |
| 2.2 | V47 §1 #2/#6/#7/#8/#9；P286 报告的不变量段与自测② | 合并提交的 numstat 只含五个写集文件（＋报告）；六词模式在 `skills/teamsmith/tests/` 命中 0；选集三跑 `✓783 ✗0` |
| 2.3 | P286 报告 §0.2 的栏位清单；V47 §2 的 R2 行 | `report.md.tmpl`、`task.md.tmpl` 不在 6a03e25c 的六个文件里；现树仍是五个 `##` 栏位 |
| 3.1 | V47 §6 与包内 README 的「Fixed before the read」表 | rubric mtime 23:13:55Z 早于首次派单 23:14:17Z；sha256 `a88e2c1e…98f8`，返修包的 rubric 与之逐字节相同 |
| 3.2 | V47 §6（两臂条件）与 §8.2（独立复核夹具对应） | `agents-diff.diff` = 那条 6 行 bullet 的全部差异；arm-A 的 bullet 与修订后模板渲染逐字节相同（644 B）；timeline 两行 `model=` 相同 |
| 3.3 | V47 §6 的派单表与有效轮 | `runs-final/`（2319 B / 2267 B，时间戳两段）；两篇是 stdout 的逐字节拷贝（`cmp` 干净）；`mapping.sealed` 在 `blind/` 之外 |
| 3.4 | `docs/team/reviews/P286.md`（1c8ac91d、7b24fd98） | 「PM 代理读（明确标注，不是用户的判断）」＋ 解封结果（text-1 = arm-A）；**读者表仍是空白模板**（见 §3 差异 3） |
| 4.1 | P286 报告的「Verification evidence」段（含 rc 与输出尾） | 选集 `✓783 ✗0`；全量第二次 `✓4698 ✗3` 且三条红逐条归因；`validate` 23/0→22/0；`spec-refs` undeclared 0；`ledger-ban` hits=0；投影自证 `+4 added` |
| 4.2 | P286 报告本身（随 6a03e25c 并入 main） | 命令/rc/输出尾、§2 不变量、返修轮两侧、「这一轮没做的」与「给 PM 的两个机器事实」两节都在 |
| 4.3 | 提交 177ed0f1 / 2b9e46a2 / eb7aef6a / 902007ab 的 message | 每条都带 `(P286)` 与 `Agent: dev-bob` trailer；分支仍在本地、无 upstream；通知轨迹见 §3 差异 4 |

## 2 · 留空的那一项，与留给 PM 的五项

**3.5（留空）**：条目要的是「按 rubric 的规则给出『改写规则文本』或『保留原样』，写明样本限制」，证据是「结论段 + `grep` 输出」。我查到的是：

- `rubric.md` 的判定规则写定在先（若带规则那臂更吃力且第 2–4 项没有更好 → 改写；若不吃力且第 2–4 项更好 → 原样归档）；
- PM 的代理读有印象（「带规则那篇略深……差别不大」），但**没有按 rubric 的规则写成判定**，rubric 依赖的第 2–4 项计数也没有落表（读者表仍是空白模板）；
- 「材料里不得出现 AI 评分」这一半可以复算：`grep -riE 'score'` 在两份 rubric 上只命中 rubric 自己那句禁令与它对研究的引用（每份 2 行），`runs/`、`blind/` 与两篇正文 0 命中，包内 README 也写明没有任何模型打过分。

所以 3.5 缺的不是「有没有读」，而是**按 rubric 口径写下的判定**——这是读的人（用户或受委托的代理）的判断，按任务书也属于留给你的事项，我不替它下结论。写进 `tasks.md` 的只有事实（3.4 那条）。

**5.1–5.5（按任务书留给 PM，未勾）**：证据都在 `docs/team/reviews/V47.md` 里——5.1 看 §3/§8.4；5.2 看 §5（规则文字全删的变异 → 同一组 28 段仍绿，两态输出在记录里）；5.3 看 §8.5 #6/#7 与 §2 的 R2 行；5.4 看 §8.2（夹具对应与哈希复算）；5.5 看 §8.8 的判定与 §7 的「未做/未测」。本轮我没有重做这些检查。

另：**0.1 我按 apply 的阅读动作勾了**（条目要的是「读 PM 的提案审查并把结论摘进报告」，不是提案复核本身）。若你本意是这一项也留给你，把那一行的 `[x]` 改回 `[ ]` 即可，不影响其余。

## 3 · 与条目字面的差异（如实记，未改原文）

1. **对照材料的实际位置**（3.1–3.4）：在**账外证据包** `pm-skills-ledger/team/reports/V47-verify/` 与 `.../P286-dev-bob/arms-post-fix/`，不是条目字面写的 `docs/team/reports/<对照任务 ID>-<席位>/compare/`。原因在 `.gitignore`：`docs/team/reports/**` 被挡、只放行同层 `*.md`（第 33–34 行），子目录进不了仓库。**材料本身齐**（rubric、task、两份正文、mapping.sealed、sheet 模板、runs、README、变异、复算脚本）。
2. **两臂不是派单而是直接执行**（3.2）：两臂用运行器直接跑 `pi --print --no-session --approve --tools read --model …`，因此没有 `state/dev.env` 片段可查；模型相等由运行器把模型钉死 + timeline 两行 `model=` 相同来保证。
3. **读者表没有被填**（3.4）：`sheet.md` 的 sha256 仍是 README 记录的空白模板哈希 `d0e9796c…fbd6`（两份包逐字节相同）；判断改以 PM 的合并记录留档。这是与「填完 sheet 才解封」流程的差异——解封与判断确实发生了，落纸的位置不是 sheet。
4. **通知的轨迹**（4.3）：两条 `team notify pm` 交付说明只在**主检出的生成文件** `docs/team/inbox/pm.md`（21:34:55Z、23:54:32Z），该目录被 gitignore 挡住，不是提交证据；PM 收讫由合并记录佐证。
5. **全量门禁没有单次全绿**（4.1）：两次全量一次是机器停跑（§33 撞预算 exit 2）、一次 `✓4698 ✗3`，三条红逐条归因（§39 系 main 自带、§40 两条是 `TMPDIR` 形状）。合并后 PM 在冻结克隆 + 钉死容器里的选集是 `✓100 ✗0`、`SMOKE=0`（`docs/team/reviews/P286.md` @ 7b24fd98）。
6. **`workflows.md` §0 的 `eight-point`→`ten-point`**（1.4）：这是提案复核第 6 条授权**折进本变更**的改动（`workflows.md` numstat 7/1 里的唯一删除行），不是越界；条目字面只要求「不碰 `openspec.md`」，那一份确实未动。
7. **`design.md` 里的 PM 提示词草案仍是 F1 之前的版本**（V47 §8.7 的观察）：发出面已修，规格管的是发出的文字；归档会把这份 design 作为历史留下。归档前要不要加一行注明已替换由 PM 定——我没有动它（不在写集）。

## Verification evidence（实跑；只读复核 + 任务书三条验收命令）

### 三条验收命令（任务书的原文命令）

```
$ "$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
✓ change/writing-discipline
Totals: 22 passed, 0 failed (22 items)
rc=0

$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: root=…/.worktrees/verify scope=published files=1648 hits=0 names=ok user=resolved
rc=0

$ git diff --check && git status --short
（无输出；rc=0）
```

`ledger-ban` 的运行发生在本报告写入**之前**（当时 `files=1648`）；本报告写入后按同一条命令复跑仍 `hits=0`、rc=0，此后报告只多本行对复跑结果的复述。

### 只读复核（都在这棵树上跑，未改任何文件）

```
$ git show --numstat --format='' 6a03e25c -- AGENTS.md skills/teamsmith/
22	3	AGENTS.md
21	0	skills/teamsmith/references/protocol.md
7	1	skills/teamsmith/references/workflows.md
6	0	skills/teamsmith/templates/AGENTS.section.md.tmpl
9	0	skills/teamsmith/templates/pm-prompt.md.tmpl

$ git show --format='' 6a03e25c -- AGENTS.md skills/teamsmith/ | grep -E '^-' | grep -v '^---'    # 4 行
-Roster: dev verify dev2 dev3 (editable in `.pi/team/config.sh`).
-- **Never stop mid-task to ask for confirmation**: either deliver (gates run + report + push + PR/MR) or be
-  hard-blocked (notify the PM + PARTIAL report).
-| 2 | `opsx-propose` | … green + the eight-point checklist |

$ git grep -ci 'answer the reader\|what it changed' f97a7f74 -- skills/teamsmith/templates skills/teamsmith/references | grep -v ':0$' | wc -l
0
$ grep -cE '^[0-9]+\. \*\*' skills/teamsmith/references/openspec.md
10
$ grep -rnE 'answer the reader|carries its evidence|earns its place by what it cites|what it changed|When in doubt, delete' skills/teamsmith/tests/ | wc -l
0
$ grep -c '<!-- teamsmith:begin -->' AGENTS.md; grep -c '<!-- teamsmith:end -->' AGENTS.md
1
1
$ grep -n '^## ' skills/teamsmith/templates/report.md.tmpl
6:## Deliverables
12:## Verification evidence (must have actually been run)
34:## Flip evidence (required for defect-fix tasks)
42:## Decisions and deviations
46:## Suggested next steps
$ grep -n '^### 11b\.' skills/teamsmith/references/protocol.md
833:### 11b. A caution earns its place by what it cites; a finding earns its place by what it changes
$ grep -c 'No tool verifies that a live author follows this rule' skills/teamsmith/references/protocol.md; grep -c 'Read for what each finding changes' skills/teamsmith/references/workflows.md
1
1
$ bash skills/teamsmith/tests/section-select.sh --paths <四文件>
decision=RUN
sections=131
keys=28
$ f=openspec/changes/writing-discipline/tasks.md
$ grep -cE '^[[:space:]]*[-*][[:space:]]+\[[[:space:]]\][[:space:]]*' "$f"; grep -cE '\[x\]' "$f"
6
18
```

四个面的义务锚点（工人面模板与 PM 面模板各一遍）：`answer`（1/2）、`names none is deleted`（1/1）、
`carries its evidence stays` / `carries its fact`（1/1）、`what it changed`（1/1）、`11b`（1/1）——与 P286
报告 §1.1 的读数一致。

账外证据包上复算「没有 AI 评分」这半条：

```
$ grep -riE 'score' pm-skills-ledger/team/reports/V47-verify/rubric.md pm-skills-ledger/team/reports/P286-dev-bob/arms-post-fix/rubric.md
…（每份 2 行）No model was asked to score the two texts, and no model score is part of this rubric: …
…（每份 2 行）in this change (an AI reviewer scores a reviewer-oriented rewrite +1.22 on a ten-point scale …)
```

即只命中 rubric 里禁止它的那两句；`runs/`、`blind/` 与两篇正文 0 命中。

### 一条操作事实（给 PM 看板用）

`team change status` 读的是 `$TEAM_MAIN_ROOT/openspec/…` 下的 `tasks.md`（`common.sh:5153` 的
`team_change_checklist_blockers` → `team_change_tasks_file` → `team_spec_abs`），所以它现在仍显示「24 项未勾」；
**本分支并入 main 后**才会显示 6 项未勾（3.5 + 5.1–5.5）。这不是勾选没生效。

## Flip evidence（本任务不是 defect-fix）

不适用（任务书没有要求翻转证据）。可证伪性说明：每个勾都点名了可复查的提交或小节，留空项在同一份文件里
直接可见（`grep` 未勾 = 6）；判据是「已提交证据里找不到支撑就不勾」，3.5 就是这样留空的——如果把它也勾上，
读者表空白与缺少 rubric 口径判定这两件事就会从账上消失。

## Decisions and deviations

1. **3.4 按任务书的指示写成「PM 代理读（已标注）」**，不写成用户的判断；同时把「读者表仍是空白模板」这一
   事实写进条目与 §3。
2. **只勾到 4.3；5.1–5.5 与 3.5 留给 PM。** 0.1 我按 apply 的阅读动作勾了（见 §2 末）。
3. **没有跑门禁**：任务书的验收只有三条命令，全量留给合并前检查（也避免与别的席位抢门禁锁）。上面所有复核
   都是只读命令。
4. **交付前 `git merge main`**（`7ee107da`）：带进 `docs/team/reviews/P286-done.md`、`V47-done.md` 与
   `P286.md` 的合并后读数；无冲突；勾选内容不受影响。
5. 报告正文里的家目录一律写 `$HOME` 或省略；`ledger-ban` 在本报告写入后复跑 rc=0。

## Suggested next steps

- **PM**：按 rubric 口径写下 3.5 的判定（保留原样 / 改写规则文本），勾 5.1–5.5（证据指针在 §2），然后归档。
- **PM**：归档前定 `design.md` 里那段 F1 之前的草案怎么留（V47 §8.7）；我不改它。
- 本分支不再需要改动；若复核后要调整勾（例如 0.1/3.4 你想自己勾），改 `tasks.md` 的那一行即可。
