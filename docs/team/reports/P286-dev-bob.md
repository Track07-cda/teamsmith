# P286 · 写作纪律：apply（三处表面 + 评审读法 + 本仓 AGENTS.md 重渲染）

agent: dev-bob   status: delivered（含返修轮次 1；待独立复验）   time: 2026-10-15T23:5xZ
branch: `task/P286-writing-discipline-apply`　tip `30ddf3c4`（第二次 merge main 之后、写本报告前的交付 tip；本报告自身的提交在其后）
change: `writing-discipline` · 规格 `openspec/changes/writing-discipline/specs/writing-discipline/spec.md`（4 条 ADDED）
deltas: -（不写 delta 文件；`openspec/changes/writing-discipline/**` 一个字节未动）

> 返修轮次 1（V47 的 F1）已落地：改动与红/绿两侧见下面第一节。本报告其余部分写的是第一轮交付的内容，
> 其中的 tip 与门禁读数属于那一轮，返修后的读数集中在第一节。

三个提交，按小步切：

| 提交 | 内容 |
|---|---|
| `177ed0f1` | 工人面 `templates/AGENTS.section.md.tmpl` + PM 面 `templates/pm-prompt.md.tmpl` |
| `2b9e46a2` | `references/protocol.md` §11b + `references/workflows.md` §E 与 §0 的 ten-point |
| `eb7aef6a` | 本仓 `AGENTS.md` 标记块重渲染 |

两次 `git merge main`（任务书要求「交付前 merge main」）：`de66696b`（main @ `f2a45df8`），
复验期间 main 又前进了 25 个提交（含 `cmd-help.sh` / `help-surface.sh` / `config-cli.sh` 的真产品改动），
于是再合一次 → `01cb9ae1`（main @ `345823ab`），两次都无冲突。我对 main 的差集始终是**那 5 个文件 +65 −4**。

## Deliverables

| Path | What |
|---|---|
| `skills/teamsmith/templates/AGENTS.section.md.tmpl` | Non-negotiable discipline 新增一条 bullet（四条义务 + 指向 `references/protocol.md` §11b），+6 行 |
| `skills/teamsmith/templates/pm-prompt.md.tmpl` | `## Talking to the user` 内新增一段（同四条义务 + 指向 §11b），+9 行；代号段与「重要结论上回复页」段一字未动 |
| `skills/teamsmith/references/protocol.md` | §11 之后新增 `### 11b.`（判据 + 短理由 + 诚实边界），+21 行、删除 0 行（§9b 与 §11 原文未碰） |
| `skills/teamsmith/references/workflows.md` | §E 新增 PM 复核读法；§0 阶段表 `eight-point` → `ten-point`，+7 −1 行 |
| `AGENTS.md` | 标记块按模板重渲染（`team_render` + `team_write_section`），+22 −3 行；块外零改动 |
| `docs/team/reports/P286-dev-bob.md` | 本报告 |

写集之外零改动（见「不变量」）。改动前的基线日志在 `docs/team/reports/P286-dev-bob/logs/baseline.txt`，
该子目录被 `.gitignore` 挡住（`docs/team/reports/**` 只放行同层 `*.md`），关键内容贴在第 0.2 节。

## 返修轮次 1（2026-10-15，V47 的 F1）：PM 面那句长度偏好已换成支持判据

**结论**：V47 的 F1 成立，已修。`templates/pm-prompt.md.tmpl` 的规则段末尾原本是

> answer. When in doubt, delete: a short answer that answers the question beats a defensive one. See

现在改成

> answer. Delete what names nothing checkable: what stays is what the reader can verify. See

——「删」的依据从篇幅挪回**证据**（点名不到可核查之物的话才删），与同一段里已写明的四类判据
（一次测量 / 一个反例 / 推理里的缺口 / 未观测到的边界）以及「带证据的边界句不许删」一致。
改动只有这一句：提交 `902007ab`（`1 insertion(+), 1 deletion(-)`），`templates/pm-prompt.md.tmpl` 之外零改动。

**另外三处表面逐句核过**（任务书要求「只改真正违反 R1 场景 2 的」）：工人模板 bullet、`protocol.md` §11b、
`workflows.md` §E 都没有同类句子。那两处出现「自信 / 更强势 / 更强」词族的地方都是**否定句**，而且是规格点名
要写的反向陈述——§11b 的 `This is not an instruction to sound more confident, more assertive or shorter`、
§E 的 `a longer or more defensive report is not stronger evidence`（R3 要求写的就是这一句）；除此之外
`workflows.md` 与 `references/openspec.md` 未动，§11b 的 `§11` 与代号词表规则也一字未改。

### 红侧：作者自测把这句话抓回来了（任务书要的翻转证据）

自测脚本在**树外**（`pm-skills-ledger/team/reports/P286-dev-bob/check-writing-rule.py` + `run-selfcheck.sh`），
因为规格 R3 场景 5 要求门禁不持有这条措辞（`skills/teamsmith/tests/` 里仍是零命中，见 0.4 那节的旧读数与
本轮 `grep`）。它读五个面（工人模板、本仓渲染后的 `AGENTS.md`、PM 模板、§11b、§E），问两件事：
A 有没有语气/篇幅**偏好**（否定句显式豁免，避免把 §11b 那句合法否定误判）；
B 每个面是否仍点名支持判据，并把删除规则绑在判据上（`names none/nothing/no fact`）。

```
$ bash run-selfcheck.sh <worktree>          # 原始输出：logs/selfcheck-summary.txt
### arm green — the delivered tree
ok   rc=0 (checker green on the delivered tree)
### arm M1 — templates/pm-prompt.md.tmpl (V47 读出的那句话原样放回)
ok   rc=1, names the surface and the offending text
### arm M2 — templates/pm-prompt.md.tmpl (支持判据整句删掉)
ok   rc=1, names the surface and the offending text
### arm M3 — references/protocol.md (§11b 的判据清单删掉)
ok   rc=1, names the surface and the offending text
### arm M4 — templates/AGENTS.section.md.tmpl (工人 bullet 里写回「更自信 / 更短」)
ok   rc=1, names the surface and the offending text
== SELF-CHECK OK == green on the delivered tree; every mutant caught and named
```

M1 的红侧原文（与 V47 的 R1 逐句核等价的一条：红，并点名文件、判据类别与该句原文）：

```
-- PM prompt template (skills/teamsmith/templates/pm-prompt.md.tmpl)
   A tone/length:  RED (1 hit(s))
      ! length preference (short/concise/brief judged better): When in doubt, delete: a short answer that answers the question beats a defensive one.
   B criterion:    RED (4/4 classes named); missing: the delete-rule bound to the criterion (names none/nothing)
```

交付树的绿侧原文（同一脚本、同一命令）：

```
-- PM prompt template (skills/teamsmith/templates/pm-prompt.md.tmpl)
   A tone/length:  OK (0 hits, 0 negated statement(s) allowed)
   B criterion:    OK (4/4 classes named; delete-rule bound to the criterion)
-- protocol §11b (skills/teamsmith/references/protocol.md)
   A tone/length:  OK (0 hits, 1 negated statement(s) allowed)
      ~ negated, allowed: … This is not an instruction to sound more confident, more assertive or shorter …
   B criterion:    OK (4/4 classes named; delete-rule bound to the criterion)
-- review runbook §E (skills/teamsmith/references/workflows.md)
   B criterion:    OK (3/4 classes named (absent: a measurement); delete-rule bound to the criterion)
== OK == every surface passes both checks
```

M2（PM 面删掉判据那一句）与 M3（§11b 删掉判据清单）都读到 `B criterion: RED (0/4 classes named …)`；
M4（工人面写回语气/篇幅偏好）读到 `A tone/length: RED` 并点名那句。四条原始日志：
`logs/selfcheck-red-M{1,2,3,4}.txt`，总表 `logs/selfcheck-summary.txt`。

### 验收命令（返修后、合过 main 的树 @ `48ab0989`）

```
$ bash skills/teamsmith/tests/section-select.sh --paths <四个文件>
decision=RUN · sections=131 · keys=28        # 与第一轮同一组键（日志 logs/section-select.txt）
$ bash skills/teamsmith/tests/smoke.sh --select 0,0b,…,12k
账本自查： 28 段收口 · 增量 ✓783 ✗0 SKIP10 ｜ 结果行 ✓783 ✗0 —— 一致
== 选段结果 ==  ✓ 783 ✗ 0                    # exit 0 · 301.0s · 未跑 103 段（日志 logs/select-28sections.txt）
$ "$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
✓ change/writing-discipline
Totals: 23 passed, 0 failed (23 items)       # rc=0
$ bash skills/teamsmith/tests/spec-refs.sh --check
spec-refs: judged 111 reference(s) (49 distinct) in 12357 effective line(s); retired 0; undeclared 0   # rc=0
$ git diff --stat -- skills/teamsmith/ | grep -vE '<四个面>'
（空；grep rc=1）
$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: … hits=0 names=ok                 # 本报告写完后跑的这次 rc=0
$ git diff --check && git status --short
（无空白错误；树干净——选段跑前跑后 HEAD 与 status 逐字一致）
```

`git diff --stat main HEAD -- skills/teamsmith/` 仍是那四个面 `43 insertions(+), 1 deletion(-)`
（`protocol.md +21`、`workflows.md +7 −1`、`AGENTS.section.md.tmpl +6`、`pm-prompt.md.tmpl +9`）；
`openspec/`、`scripts/**`、`extension/**`、`tests/**` 仍在差集之外。本轮两次 `git merge main`：第一次 34 个提交（含门禁锁
的真产品改动 `gate-lock.sh`），第二次 8 个提交（账本记录 + 门禁锁变更的归档投影，其中唯一非账本文件是
`openspec/specs/verification/spec.md`）；两次都无冲突，`skills/teamsmith/**` 在第二次里零改动。
`protocol.md` §9b 仍未在本树落地，未碰。

第二次合并后又在同一组 28 段上重跑一次（tip `30ddf3c4`）：

```
账本自查： 28 段收口 · 增量 ✓783 ✗0 SKIP10 ｜ 结果行 ✓783 ✗0 —— 一致
== 选段结果 ==  ✓ 783 ✗ 0                    # exit 0 · 282.6s（日志 logs/select-28sections-merged.txt）
$ "$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
Totals: 22 passed, 0 failed (22 items)       # rc=0；23 → 22 是归档把那个 change 变成了 spec，不是掉了检查
$ bash skills/teamsmith/tests/spec-refs.sh --check
spec-refs: judged 111 reference(s) (49 distinct) … retired 0; undeclared 0   # rc=0
$ git diff --stat -- skills/teamsmith/ | grep -vE '<四个面>'   # 空（grep rc=1），git diff --check 无输出，status 干净
```

### 两臂对照：夹具文字未变，另跑了一份返修后的盲包

任务书说「改动落定后重跑两臂、重生成盲包」。核过之后一部分**不需要重跑**、一部分我另跑了一份：

- 两臂的差异是**工人面**那条 bullet（`fixtures/agents-diff.diff` 的全部内容），而 F1 改的是 **PM 提示词**。
  `arms-post-fix/fixture-correspondence.txt` 在返修后的树上复算：arm-A 的 bullet 与「用修订后的模板渲染出的
  同一条 bullet」逐字节相同（644 B），两臂之差仍是那一条 6 行 bullet；`task.md` / `rubric.md` / `sheet.md`
  与 V47 的副本逐字节相同（sha256 与 V47 记录里的 `99053abf…` / `a88e2c1e…` / `d0e9796c…` 一致）。
  **所以 V47 那份盲包对修订后的规则仍然成立**——夹具字节没变，变的是 PM 面。
- 任务书要「重跑」，所以另跑了一份返修后的盲包：`pm-skills-ledger/team/reports/P286-dev-bob/arms-post-fix/`。
  配方与 V47 的有效轮相同（同一份任务消息、同一模型 `deepseek/deepseek-flash:max`、各自 `--no-session`、
  只给 `read` 工具、cwd 是私有 /tmp 副本），先跑到达性探针证明两臂只差那条规则：arm-A `YES`、arm-B `NO`；
  两篇产物 3294 B / 2638 B，去掉标识后掷硬币指派 `text-1` / `text-2`（首字节 180，偶数 → text-1 = arm-A），
  映射封存在 `blind/` 之外的 `mapping.sealed`；读者表 `sheet.md` 仍是空的，**人读那一步等读者**，
  没有任何模型给这两篇打过分。

这份返修后的盲包有一处必须说清：**跑它的是 apply 作者，不是 verify 席位**。两篇是原样 stdout（与 `runs/`
逐字节相同，`cmp` 干净），配方全部落在 `run-arms.sh`，但「换人跑」这件事写在这里，供 PM 与复验席位判。
V47 那份仍是同一实验的另一个随机抽样（夹具相同），选哪份给读者由 PM 定。

### 这一轮没做的（都不是本席位能做的）

- **读者表与判定**：R4 的结论由人读产出（用户；不读则由 PM 代理并标注），本报告不给分、不给结论。
- **全量门禁**：本轮只跑 28 段选段（任务书的验收命令就是选段）；未跑的 103 段被日志逐个点名；
  交付前/归档前的整套门禁按惯例由 PM 在合并前跑。
- **归档**：PM 在独立复验通过且用户确认后跑 `opsx-archive`（第一轮的树外投影自证仍在下一节里）。

## 0.1 提案复核的七个裁定点（逐条落笔）

| 裁定点 | PM 的裁定 | 本 apply 怎么落的 |
|---|---|---|
| 1 change id | `writing-discipline` | 任务书头部已写；未改任何 change 文件 |
| 2 评审口径落 `workflows.md` §E | 是 | §E 加读法；**没碰** `references/openspec.md`（`grep -cE '^[0-9]+\. \*\*'` 仍 = 10） |
| 3 本仓 `AGENTS.md` | 授权重渲染标记块 | 用 `team init` 的渲染路径（`team_render` + `team_write_section`）刷新；没跑 `team init` |
| 4 对照放在 verify 阶段 | 是 | 本阶段不构造两臂；材料路径按 `design.md` 第 5 节留给 verify |
| 5 不动工人注入提示词 | 是 | `scripts/**` 零改动 |
| 6 `workflows.md` §0 的 `eight-point` | 改判「折进本变更」（改成十点或不写数字，我定） | 改成 `ten-point`（前后对照见下） |
| 7 新能力 + 四条 ADDED | 是 | 交付面就是四个文件；未碰任何既有 requirement |

裁定点 6 的取舍：数字是读者自查的锚点，删掉它就得回头数 §4 的条目，所以**改对数字**而不是删掉；
`references/openspec.md` §4 的实际条目数 = 10（0.2 的基线里量过）。

## 0.2 改动前基线（真实输出，改动之前在同一棵树上取的）

```
$ grep -rci 'answer the reader\|what it changed' skills/teamsmith/templates/ skills/teamsmith/references/
   … 21 个文件全部 :0（含四个目标文件）
# 事后可复核的形式（从 git 里的改动前树 f97a7f74 重取，结论相同：一处命中都没有）
$ git grep -ci 'answer the reader\|what it changed' f97a7f74 -- skills/teamsmith/templates skills/teamsmith/references | grep -v ':0$' | wc -l
0
$ grep -cE '^[0-9]+\. \*\*' skills/teamsmith/references/openspec.md
10
$ sed -n '17p' skills/teamsmith/references/workflows.md
| 2 | `opsx-propose` | the explorer, same agent (planning only — no code) | the PM's **proposal review is ACCEPTED** in `reviews/<change>-proposal.md`: `openspec validate --all --strict` green + the eight-point checklist |
$ grep -nE '^#{1,3} ' skills/teamsmith/templates/report.md.tmpl
6:## Deliverables
12:## Verification evidence (must have actually been run)
34:## Flip evidence (required for defect-fix tasks)
42:## Decisions and deviations
46:## Suggested next steps
```

后两项同时是 R2 的「不新增必需栏位」的证据：`report.md.tmpl` 的栏位在本次交付里**一个都没加**，
`git diff --name-only main HEAD` 里根本没有 `templates/report.md.tmpl` 与 `templates/task.md.tmpl`。

## 四个面写进去的原文

`skills/teamsmith/templates/AGENTS.section.md.tmpl`（Non-negotiable discipline，「范围/报告/磁盘交接」bullet 之后）：

```
- **A report is read for its answer first, and every sentence carries its evidence**: state what the brief's
  question resolves to before the account of how you got there. A caution, a limitation or a boundary earns its
  place by what it cites — a measurement, a counterexample, a gap in the reasoning, or a boundary you did not
  observe — and a sentence that names none is deleted; one that carries its evidence stays. Every finding states
  what it changed: the implementation, the next step, the conclusion, or nothing; an observation that changed
  nothing stays out of the body. See `{{SKILL_DIR}}/references/protocol.md` §11b.
```

`skills/teamsmith/templates/pm-prompt.md.tmpl`（`## Talking to the user: a code never stands alone` 内，代号段之后）：

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

`skills/teamsmith/references/protocol.md`（§11 之后，纯追加）：

```
### 11b. A caution earns its place by what it cites; a finding earns its place by what it changes

The rule in this section is about **support**, not tone. A sentence that hedges, qualifies, warns or sets a boundary
stays only when it names something the reader can check — a measurement, a counterexample, a gap in the reasoning,
or a boundary that was not observed; a sentence that names none is deleted, not kept as evidence of care. When the
evidence no longer supports a claim, say what the evidence does support instead of narrowing the claim, and never
delete a boundary statement that carries its evidence: it names exactly what this rule asks for. A finding,
likewise, states what it changed — the implementation, the next step, the conclusion, or nothing; an observation
that changes nothing does not stand between the reader and the answer. This is not an instruction to sound more
confident, more assertive or shorter (the measurements are in *Defensive Writing in GPT Models*, arXiv:2610.11355);
the vocabulary rule of §11 stands unchanged.

The reason is who rewards which text. In that study's comparison an AI reviewer scores a reviewer-oriented rewrite
higher (+1.22 on a ten-point scale) while the human readers find it harder to read (−0.70 on a seven-point scale)
with comprehension unchanged: a caution written for an imagined reviewer is paid for by the reader, so it has to
carry its evidence to earn its place.

**No tool verifies that a live author follows this rule.** The gate asserts nothing about wording — it can stay
green over a document that hedges everywhere — so whether a sentence earns its place is decided by the review that
reads the diff, and a surface that later loses the rule is caught there, by the reviewer naming the surface.
```

`skills/teamsmith/references/workflows.md` §E（三条既有段落之后）：

```
**Read for what each finding changes.** While you read the report and the review record, check that every finding
states what it changed — the implementation, the next step, the conclusion, or nothing. A caution that names no
fact, counterexample, reasoning gap or unobserved boundary is a finding to delete, not evidence of thoroughness,
and a longer or more defensive report is not stronger evidence. This is a reading rule, not a gate: no section
checks the wording (see [references/protocol.md](protocol.md) §11b).
```

§0 阶段表那一行：`… green + the eight-point checklist |` → `… green + the ten-point checklist |`。

**语气类措辞的禁令**：四个面里没有「更自信 / 更强硬 / 更短更有力」这类词；protocol.md §11b 明写
`This is not an instruction to sound more confident, more assertive or shorter`。断言这一点的机器读法：

```
$ grep -rn -iE 'more confident|more assertive|stronger|assertive|bolder' <四个面>
skills/teamsmith/references/protocol.md:802:confident, more assertive or shorter (the measurements are in *Defensive Writing in GPT Models*, arXiv:2610.11355);
skills/teamsmith/references/workflows.md:171:and a longer or more defensive report is not stronger evidence. This is a reading rule, not a gate: no section
$ sed -n '800,803p' skills/teamsmith/references/protocol.md
…
This is not an instruction to sound more
confident, more assertive or shorter (the measurements are in *Defensive Writing in GPT Models*, arXiv:2610.11355);
$ sed -n '170,172p' skills/teamsmith/references/workflows.md
… a caution that names no
fact, counterexample, reasoning gap or unobserved boundary is a finding to delete, not evidence of thoroughness,
and a longer or more defensive report is not stronger evidence. …
```

即：**这两个词族在四个面里只出现在否定句里**——一条明说「这不是叫你更自信/更强硬/更短」，另一条明说
「更长或更防守的报告不是更强的证据」。除此之外没有任何一处把语气当成要求。

## 1.1–1.4 四个面的语义锚点（grep 证据）

```
$ for f in skills/teamsmith/templates/AGENTS.section.md.tmpl skills/teamsmith/templates/pm-prompt.md.tmpl; do … done
== skills/teamsmith/templates/AGENTS.section.md.tmpl
  answer                                         1
  names none is deleted|names something checkable 1
  carries its evidence stays|carries its fact    1
  what it changed                                1
  11b                                            1
== skills/teamsmith/templates/pm-prompt.md.tmpl
  answer                                         2
  names none is deleted|names something checkable 1
  carries its evidence stays|carries its fact    1
  what it changed                                1
  11b                                            1
$ grep -n '^### 11b\.' skills/teamsmith/references/protocol.md
793:### 11b. A caution earns its place by what it cites; a finding earns its place by what it changes
$ grep -c 'No tool verifies that a live author follows this rule' skills/teamsmith/references/protocol.md
1
$ grep -c 'Read for what each finding changes' skills/teamsmith/references/workflows.md
1
```

R3 的「诚实边界」（没有工具能验证活作者是否遵守、门禁对此保持绿色、由评审点名）就写在 §11b 第三段，
并在工人面 / PM 面 / §E 各有一处指针。

## Verification evidence (must have actually been run)

以下每条都在**交付 tip `01cb9ae1`**上跑过；输出尾按原样贴。

### 0.4 选段（任务书第一条验收命令）

```
$ bash skills/teamsmith/tests/section-select.sh --paths \
    skills/teamsmith/templates/AGENTS.section.md.tmpl skills/teamsmith/templates/pm-prompt.md.tmpl \
    skills/teamsmith/references/protocol.md skills/teamsmith/references/workflows.md
decision=RUN
sections=131
keys=28
（28 个键：0 0b 0c 0d 2 4 4b 5 3b 6 6d 6e 6f 6i 7b 9 10 11 13c 14b 15b 15c 17 18 18b 19 33 12k）
```

基线（改动之前）同一条命令是 `decision=RUN · sections=130 · keys=28`——集合相同，131 是因为复验期间 main 合进来
一个新段落（b 的孤儿席位普查），与本次写集无关。

### 验收选集：`smoke.sh --select <28 键>`（交付 tip 上，rc=0）

```
$ bash skills/teamsmith/tests/smoke.sh --select 0,0b,0c,0d,2,4,4b,5,3b,6,6d,6e,6f,6i,7b,9,10,11,14b,15b,15c,13c,17,18,18b,19,33,12k
== 选段 == decision=RUN · 运行 28/131 段 · 未跑 103 段
  ✓ 7.2 checklist gains point 9
  ✓ 7.2 checklist gains point 10
  ✓ 7.2 checklist now has exactly ten points
  ✓ 7.4 rendered AGENTS carries the paragraph
  ✓ 7.4 rendered PROTOCOL carries it
  ✓ 7.4 repo AGENTS.md 与模板逐字一致（模板是源）
  ✓ 7.4 PROTOCOL 模板也带这段
#27 33 · 项目契约的读写面（P22/B1：team config 单一写入口 + schema） · 用时 116s · ✓1 ✗0 SKIP0 · ticks 1
#28 12k · 模板与文档（P24/B7） · 用时 1s · ✓32 ✗0 SKIP0 · ticks 32
账本自查： 28 段收口 · 增量 ✓783 ✗0 SKIP10 ｜ 结果行 ✓783 ✗0 —— 一致
== 选段结果 ==  ✓ 783  ✗ 0
  这次不跑的键：0e 0f … 63 64（103 个键，全列在日志里）
  选段运行不是全套门禁（交付 / 复验 / 归档仍跑整套）；引用它的报告必须点名没跑的段
```

同一条选段在改动前（第一轮）与第一次 merge main 之后各跑一次，三次都是 **✓783 ✗0**。

### 全量门禁（覆盖整套 131 段；任务书未要求的额外证据）

第一次全量在 **§33 的运行预算上停跑**（`exit 2` = 门禁自己停跑，不是对代码的判定），停在**与本次改动无关**的一段：

```
$ bash skills/teamsmith/tests/smoke.sh
== #87 33 · 项目契约的读写面（P22/B1：team config 单一写入口 + schema） == 2026-10-15T17:58:10+00:00 · 预算 164s
  … 段落 #87（33 · …）已运行 60s（预算 164s）；最慢：#63 12b-h0c … #64 12b-pi … #79 26 …
  … 段落 #87（33 · …）已运行 120s（预算 164s）；最慢：#63 12b-h0c … #64 12b-pi … #79 26 …
  ✗ 段落 #87（33 · 项目契约的读写面（P22/B1：team config 单一写入口 + schema））超时：预算 164s，实际 164s，最后进度 85s → 停跑（exit 2），现场 /var/tmp/p286-tmp/.teamsmith-smoke-scene.3069576
full rc=2
```

- §33 跑的是 `tests/config-cli.sh`；本变更没碰任何 `scripts/**`、任何测试文件。
- §33 的实测带是 41s，预算是它的 4 倍 = 164s；同一棵树上**这一段在三次选段里都通过**（118s / 117s / 116s，✓1 ✗0）。
- 停跑时刻的机器读数：作业日志第一行 `[2026-10-15T18:01:36] loadavg: 33.48 29.72 22.14`（门禁前提是 ≤ 0.75 × 32 核 = 24）。
  归因：**负载**把一段本来就在预算边缘的段落推过线，不是回归。

第二次全量（第一次 merge main 之后，18:07:32–21:06:49，`loadavg1` 33.48 → 12.55）：

```
账本自查： 130 段收口 · 增量 ✓4698 ✗3 SKIP16 ｜ 结果行 ✓4698 ✗3 —— 一致
== 结果 ==  ✓ 4698  ✗ 3
```

三条红逐条归因（都不是本次改动引入的）：

| 红 | 原文 | 归因 |
|---|---|---|
| §39 ×1 | `✗ 39 install-shape.sh 有失败` / `✗ teamsmith-init/SKILL.md 超行数（102）` | 该文件在我的分支与 main **逐字节相同**（`git show main:skills/teamsmith-init/SKILL.md \| wc -l` = 102 = 我的 HEAD；我的差集里没有 `teamsmith-init/*`）。`docs/team/reports/P271-dev-bob.md` 已用 **main 的干净克隆**做过 A/B：同一段在 main 上也是 `✓0 ✗1`、同一条红 |
| §40 ×2 | `✗ P223 反向对照：不带 --keep 时根还在` / `✗ 日志里也没有「保留临时根：」` | 只在 `TMPDIR` 不在 `/tmp` 时出现（我为了绕开 `/tmp` 只剩 1.2 GB 用了 `/var/tmp/p286-tmp`）；`docs/team/reports/P255-dev-bob.md` 的 r2/r5 对照表写过同一现象。**在交付树上直接翻绿验证**（下面第 3 条命令） |

**同一交付 tip、默认 `TMPDIR` 下的对照**（把这两类红分开）：

```
$ bash skills/teamsmith/tests/smoke.sh --select 39,40          # 不设 TMPDIR
#5 39 · npm CLI 与项目 skill 安装 · 用时 43s · ✓0 ✗1 SKIP0
        ✗ teamsmith-init/SKILL.md 超行数（102）
  ✓ P223 反向对照也走了同一条 re-exec
  ✓ P223 反向对照：不带 --keep 时根被收走（判据分得出两者）
  ✓ P223 反向对照：日志里也没有「保留临时根：」
#6 40 · 临时根纪律（P53：TMPDIR / owned 家族 / 泄漏断言 / lint） · 用时 29s · ✓21 ✗0 SKIP0 · ticks 21
== 选段结果 ==  ✓ 42  ✗ 1
```

即：§40 那两条**是 `TMPDIR` 的形状问题**（同一棵树上换回默认 `TMPDIR` 就 ✓21 ✗0），§39 那一条**是 main 自带的红**。
套件自己的收尾行也印证了第 40 段的独立性：`✓ 40 泄漏断言：本轮创建的临时根一个都没留下`。

### 规格 / 账本 / 不变量（交付 tip 上）

```
$ "$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
Totals: 23 passed, 0 failed (23 items)                                     # rc=0
$ bash skills/teamsmith/tests/spec-refs.sh --check
spec-refs: judged 111 reference(s) (49 distinct) in 12220 effective line(s); retired 0; undeclared 0; id families used [D,E,F,M,P,V] named [D,E,F,M,P,V]   # rc=0
$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: root=…/.worktrees/dev-bob scope=published files=1614 hits=0 names=ok user=resolved        # rc=0
$ git diff --stat -- skills/teamsmith/ | grep -vE 'templates/(AGENTS\.section|pm-prompt)\.md\.tmpl|references/(protocol|workflows)\.md'
（空；rc=1）
$ git diff --stat main HEAD -- skills/teamsmith/        # 交付前的等价、有意义形式
 skills/teamsmith/references/protocol.md           | 21 +++++++++++++++++++++
 skills/teamsmith/references/workflows.md          |  8 +++++++-
 skills/teamsmith/templates/AGENTS.section.md.tmpl |  6 ++++++
 skills/teamsmith/templates/pm-prompt.md.tmpl      |  9 +++++++++
 4 files changed, 43 insertions(+), 1 deletion(-)
$ git diff --name-only main HEAD | grep -E '^(openspec/|skills/teamsmith/scripts/|extension/|scripts/)' || echo '(absent)'
(absent)
$ git diff --name-only main HEAD | grep -E 'templates/(report|task)\.md\.tmpl' || echo '(absent)'
(absent)
$ git diff --check && git status --short                 # 交付 tip 上（报告提交前）
（无空白错误）
```

`ledger-ban` 这行是在本报告写进树之后跑的（本条输出的 `files=1614` 就是含本报告的那一次运行）；
报告正文里的家目录一律写成 `$HOME` / 省略，没有绝对家目录路径、私有网段、用户名或他项目名。
**本条输出取自提交前的最后一次运行；此后报告只多了一行对本行的复述。**

### 2.1 删除项逐句核对（规则「带证据的边界声明不许删」的自查）

`git diff main HEAD | grep '^-[^-]'` 一共 4 行删除，逐条过：

| 删除的句子 | 它点名了事实/缺口吗 | 判定 |
|---|---|---|
| `-Roster: dev verify dev2 dev3 (editable in …)`（`AGENTS.md`） | 否：名单行被模板重渲染成含 `dev-bob` 的当前值 | 模板/事实的旧版本，删 |
| `-- **Never stop mid-task to ask for confirmation**: either deliver (gates run + report + push + PR/MR) or be` / `  hard-blocked (notify the PM + PARTIAL report).`（`AGENTS.md` 两行） | 否：这是**车道三态段**的旧渲染，模板里的当前版本（三态 + 后台车道 + 内联等待预算）逐字覆盖它 | 漂移刷新，删旧留新 |
| `… green + the eight-point checklist \|`（`workflows.md`） | 否：它点名的是**错的**条数（实际 10 条） | 事实错误，改成 `ten-point` |

留存的带证据边界句（未动，逐字仍在）：车道三态段与后台车道的内联等待预算（`AGENTS.section.md.tmpl`
的 `**Never stop mid-task…**` bullet，该文件删除行数 = 0）、§12k 逐字比对的
`**The change is the assignment unit** … while a sibling is unfinished.`、§11 的代号段（`protocol.md` 删除 0 行）、
`pm-prompt.md.tmpl` 的代号段与「关键结论」段（该文件删除行数 = 0）。

### 0.3 渲染幂等与「模板是源」

```
$ bash <team_render AGENTS.section.md.tmpl … | team_write_section AGENTS.md>
✓ update AGENTS.md（协议段落已刷新）
$ sed -n '/<!-- teamsmith:begin -->/,/<!-- teamsmith:end -->/p' AGENTS.md > block.md
$ diff -q block.md <fresh render of the template>        # → 无差异（两次 merge main 后各重验一次）
$ grep -c '<!-- teamsmith:begin -->' AGENTS.md; grep -c '<!-- teamsmith:end -->' AGENTS.md
1
1
$ awk '/\*\*The change is the assignment unit\*\*/,/while a sibling is unfinished\./' AGENTS.md | diff - \
    <(awk <same> skills/teamsmith/templates/AGENTS.section.md.tmpl)      # → 无差异（§12k 比的正是这一段）
```

这次刷新顺带清掉了块里累积的漂移：车道三态 bullet、任务类别/模型 bullet、范围/磁盘交接 bullet、
roster 里的 `dev-bob`——它们是**模板的当前文本**、不是我的新文字。

### 投影自证（归档会写出的规格树自洽，在树外的副本上做）

```
$ cp -a openspec /var/tmp/p286-wd-trial/openspec && (cd /var/tmp/p286-wd-trial && … openspec archive -y writing-discipline && … validate --all --strict)
Applying changes to openspec/specs/writing-discipline/spec.md:
  + 4 added
Totals: + 4, ~ 0, - 0, → 0
Specs updated successfully.
Change 'writing-discipline' archived as '2026-10-15-writing-discipline'.
✓ spec/writing-discipline
Totals: 23 passed, 0 failed (23 items)                    # rc=0
```

两处读数值得归档阶段知道（都是 dry run 的观测，不是请求）：归档把 change **改名搬进** `openspec/changes/archive/`，
产出目录名 `2026-10-15-writing-discipline` 与 `archive/` 里已有的同名形状（`2026-10-15-pm-reply-discipline`、
`2026-10-15-startup-self-heal`、`2026-10-15-orphan-visibility` …）一致；归档后的 `validate --all --strict`
是 23 passed / 0 failed，与归档前的同一个总数。

## Flip evidence (required for defect-fix tasks)

本任务不是 defect-fix。为了让交付**可证伪**，做了两处有牙齿的检查（都在树外做，不污染交付面）：

```
# ① 渲染比对不是橡皮章：在副本的标记块里注入一行漂移 → 比对必须报差异
$ sed -i '/^  nothing stays out of the body. See /i  XX injected drift line' <copy of AGENTS.md>
$ diff -q <block of the copy> <fresh render>      # → 差异被检出
# ② 门禁不读这些措辞（R3 的「由评审而非门禁守」）：同一模式在 tests/ 命中 0，在模板上命中 3
$ grep -rcE 'answer the reader|carries its evidence|what it changed|earns its place' skills/teamsmith/tests/ | grep -v ':0$'
（空；rc=1）
$ grep -cE 'answer the reader|carries its evidence|what it changed|earns its place' skills/teamsmith/templates/AGENTS.section.md.tmpl
3
```

规格 R3 场景 2 的对抗读（从**副本**里删掉某一面 → 门禁前后都绿、由评审点名那个面）属 verify 席位的
5.2，本报告不替它判定。

## Decisions and deviations

1. **裁定点 6 取「改成 ten-point」**（而不是删掉数字），理由见上；这是本 apply 唯一超出四个「写面」的一行改动，
   且已在任务书第 3 条里被点名。
2. **本仓 `AGENTS.md` 用渲染路径刷新**，与 `team init` 同源；**没有**跑 `team init`（不碰 config、不重渲染其它文档）。
3. **门禁的临时根用 `TMPDIR=/var/tmp/p286-tmp`**：当时宿主 `/tmp` 已用 93%（余 1.2 GB），而整套门禁的临时根峰值
   279.7 MB / 35857 文件。**机器锁路径保持默认** `/tmp/teamsmith-smoke.lock`，因此与其它席位依旧串行；
   换私有锁或删共享锁都不做（M23）。副作用是 §40 的两条 P223 反向对照变红，已用「默认 `TMPDIR` 的同一棵树」
   对照分开（见上）。
4. **两次 merge main**：第二次是因为 main 在复验期间前进了 25 个提交（含真产品改动）。合并后重跑了验收命令与
   渲染幂等/逐字比对，证据都在本报告里。
5. **不碰 `references/protocol.md` §9b**（任务书边界）：本次对 protocol.md 是纯追加，`git diff` 删除行数 = 0；
   两次 merge 都无冲突（§9b 与 §11/§11b 不同节）。

## 给 PM 的两个机器事实（不是请求，是复验排期的输入）

1. **全量门禁在这台机器上会随机停跑**：§33 的实测带 41s、预算 164s，但只要 1 分钟负载到 ~33（核电 32 核），
   它就会撞线（本次全量第一次就是这样停的，而同一棵树的三次选段里它 116–118s 通过）。复验尽量挑
   `loadavg ≤ 24` 的窗口，或把它记成机器事实而不是红。
2. **门禁锁的排队会长于一次门禁**：本轮有一次 `--select` 排队满 5400s 也没拿到锁（我前面排着别的席位的全量与
   我自己的全量），门禁自己给出「本套**没有运行**，这不是对代码的判定」并退出 2。给复验留足
   `TEAM_SMOKE_LOCK_WAIT`。

## Suggested next steps

- verify 席位（另一个 agent、独立检出）：按规格逐条点四个面的义务；跑 0.4 那套选段与整套；做对抗读
  （删掉某一面 → 门禁两态都绿、由评审点名那个面；`templates/report.md.tmpl` 无新栏位；`references/openspec.md` 仍十条）。
- 对照（`tasks.md` 3.x）由 verify 席位构造两臂并交用户读；材料路径按 `design.md` 第 5 节。
- 归档阶段：`opsx-archive` 由 PM 跑，前提是独立复验通过且用户确认；规格树的自洽已在树外 dry run 过（+4 added，23 passed / 0 failed）。
