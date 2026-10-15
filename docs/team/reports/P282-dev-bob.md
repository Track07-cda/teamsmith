# P282 · 写作纪律：先答读者的问题，谨慎必须有证据（提案）

agent: dev-bob   status: DONE   time: 2026-10-15T17:20:03Z
branch: `task/P282-writing-discipline-propose`   PR/MR: -（本仓 local 模式，分支留本地）

## Deliverables

| Path | What |
|---|---|
| `openspec/changes/writing-discipline/proposal.md` | 提案：四组证据（逐条核过原文）、要立什么判据、三处表面 + 一处评审口径、不设门禁的理由与代价、裁定点 1–7、范围外、后续验收命令 |
| `openspec/changes/writing-discipline/specs/writing-discipline/spec.md` | 规格 delta：新能力 `writing-discipline` 的 **4 条 ADDED requirement**、10 条 scenario（英文，规格自洽、含理由数字） |
| `openspec/changes/writing-discipline/design.md` | 设计：基线测量、四面义务表、三段草案原文（工人 bullet / PM 段 / 协议 §11b / runbook 段）、对照设计（臂 / rubric / 盲法 / 判定规则 / 材料路径 / 成本）、不变量证明方式、与既有 requirement 的逐条对齐、三个附带发现、风险表 |
| `openspec/changes/writing-discipline/tasks.md` | 执行清单：`0 冻结` / `1 三处表面` / `2 不变量` / `3 对照` / `4 验收与交付` / `5 独立验证`，含「要求 ↔ 条目」对照表（防孤儿任务） |
| `docs/team/reports/P282-dev-bob/logs/` | 本阶段验收与翻转的原始日志（**只在工作树里，不入库**：D94 —— `docs/team/reports/**` 只有正文 `*.md` 进仓库）。本报告把每条关键输出都粘了进来；PM 若要看全量，在我的工作树读这两个文件，或按报告里的命令重跑 |

**本阶段的边界**：只写提案四件套。产品文件（四个表面 + 本仓 `AGENTS.md`）**一个字节都没改**——那是 apply 席位的事
（`git status` 的最终状态只有上面这些新文件，见「验收」节）。

## Verification evidence（真实命令与输出尾）

全部原始输出：`docs/team/reports/P282-dev-bob/logs/propose-acceptance.txt`（本机工作树，不入库；含本报告引用的每一行）。

```
$ "$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
✓ change/tmux-identity-scope
✓ spec/verification
✓ spec/watchdog
✓ change/writing-discipline
Totals: 22 passed, 0 failed (22 items)
rc=0

$ bash skills/teamsmith/tests/spec-refs.sh --check
spec-refs: judged 111 reference(s) (49 distinct) in 11892 effective line(s); retired 0; undeclared 0; id families used [D,E,F,M,P,V] named [D,E,F,M,P,V]
rc=0

$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: root=$HOME/Documents/syncthing/Work/Projects/pm-skills/.worktrees/dev-bob scope=published files=1590 hits=0 names=ok user=resolved
rc=0

$ git diff --check && git status --short
diff-check-rc=0
?? openspec/changes/writing-discipline/
```

**本报告与证据日志写完之后，在同一棵分支树上又跑了一遍**（账本面变了，数字取这一次；原始输出追加在日志同一文件）：

```
$ bash skills/teamsmith/tests/spec-refs.sh --check
spec-refs: judged 111 reference(s) (49 distinct) in 11892 effective line(s); retired 0; undeclared 0; id families used [D,E,F,M,P,V] named [D,E,F,M,P,V]
rc=0

$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: root=$HOME/Documents/syncthing/Work/Projects/pm-skills/.worktrees/dev-bob scope=published files=1591 hits=0 names=ok user=resolved
rc=0

$ "$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
Totals: 22 passed, 0 failed (22 items)
rc=0
```

**选段基线**（写进 design 的事实，不是断言）：

```
$ bash skills/teamsmith/tests/section-select.sh --paths \
    skills/teamsmith/templates/AGENTS.section.md.tmpl skills/teamsmith/templates/pm-prompt.md.tmpl \
    skills/teamsmith/references/protocol.md skills/teamsmith/references/workflows.md
decision=RUN
sections=130
keys=28
reason=13c ← skills/teamsmith/templates/AGENTS.section.md.tmpl, skills/teamsmith/templates/pm-prompt.md.tmpl, …
reason=12k ← skills/teamsmith/templates/AGENTS.section.md.tmpl, skills/teamsmith/references/protocol.md
（完整 keys：0 0b 0c 0d 2 4 4b 5 3b 6 6d 6e 6f 6i 7b 9 10 11 13c 14b 15b 15c 17 18 18b 19 33 12k）
```

## Flip evidence

这不是缺陷修复（propose 阶段没有实现可破坏），但两条**可证伪**的证据都在本阶段跑了，原始输出在
`docs/team/reports/P282-dev-bob/logs/spec-refs-flip.txt`：

### 1. 归档投影自证（delta 写出来的规格树真的自洽）

```
$ rm -rf /tmp/wd-trial && mkdir -p /tmp/wd-trial && cp -a openspec /tmp/wd-trial/openspec \
  && (cd /tmp/wd-trial && "$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" archive -y writing-discipline \
      && "$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict)
Specs to update:
  writing-discipline: create
Applying changes to openspec/specs/writing-discipline/spec.md:
  + 4 added
Totals: + 4, ~ 0, - 0, → 0
Change 'writing-discipline' archived as '2026-10-15-writing-discipline'.
✓ spec/writing-discipline
Totals: 22 passed, 0 failed (22 items)
```

（投影只写 `/tmp`，真树零写入；`+ 4 added / ~ 0` 说明 4 条 ADDED 全部落地、没有意外的 MODIFIED/REMOVED。）

### 2. 规格合规是**判**出来的，不是碰巧绿的（红 → 绿）

在投影副本里植入一条**具体、未声明**的账本引用（`docs/team/reports/P282-dev-bob.md`），走查必须红并点名：

```
# control（未动）
spec-refs: judged 111 reference(s) … undeclared 0 ; rc=0

# 植入一条具体引用后
undeclared openspec/specs/writing-discipline/spec.md:109 docs/team/reports/P282-dev-bob.md
spec-refs: judged 112 reference(s) (50 distinct) … undeclared 1 ; rc=1

# 还原后
spec-refs: judged 111 reference(s) … undeclared 0 ; rc=0
```

### 3. 「门禁不持有这条规则」有当场的可证伪证据（而不是宣称）

同一棵树上：`grep -ci 'answer the reader\|what it changed'` 在 `templates/**` 与 `references/**`（21 个文件）
**全为 0**，而 `openspec validate --all --strict` 与 `spec-refs.sh --check` 全绿。即：规则今天一个字都不在，
门禁照样绿 —— 规格第三条要求的「由评审守、门禁不持有它」在**改动前**就被现场证明了。

## Decisions and deviations

1. **change id = `writing-discipline`**：任务书头部是 `change: -`（propose 阶段目录还不存在），id 由本提案定并发在
   提案裁定点 1 里；**后续 apply/verify 的任务书必须写 `change: writing-discipline`**。
2. **`openspec new change` 的副产品已清掉**：它生成了 `openspec/config.yaml` 与 `change/.openspec.yaml`；2026-10-15
   归档的那批 change 都没有这两个文件（最近六份都没有 `.openspec.yaml`），所以按现状删掉，`validate` 仍 22/22。
3. **评审口径落 `references/workflows.md` §E**，不落 `references/openspec.md` 的十条清单：那份清单被 `smoke.sh`
   §12k（`:15702`）与 §19 的 `os_pipeline_hits`（`:9711`，配 `flip-p23.sh:234` 的翻转）各钉一条，加第十一条就是
   改门禁断言（违反任务书不变量「不改门禁断言」）。这是**裁定点 2**。
4. **delta 形状 = 新能力 + 4 条 ADDED，零 MODIFIED**：既有的 `key-replies#The key-conclusion duty …` 与
   `dispatch#The worker prompt …` 守的是同文件里的**别的段落**，本变更只新增段落；design 里逐条对齐了这三条关系
   （裁定点 7）。
5. **本仓 `AGENTS.md` 未改**（PM 独占）：它是模板的渲染副本，而 `smoke.sh` §12k 7.4 只逐字比对「change is the
   assignment unit」那一段 —— 模板改了不重渲染就是**门禁看不见的漂移**。写进裁定点 3（推荐在 apply 任务书里授权）。
6. **附带发现（只点名，没动手）**：`references/workflows.md:17` 写「the eight-point checklist」，而
   `references/openspec.md` §4 是十条（§12k/§19 按十条断言）。它改变的是「照 §0 核对的人会数错条目」；处置是 PM
   另记一条（改那一行或去掉数字），**不在本变更范围**（本变更只动 §E）。
7. **未跳步**：没有为了「更整齐」去动 `templates/report.md.tmpl`/`templates/task.md.tmpl`（规格里写了「不得新增必需
   栏位」）；没有去改 `scripts/**`（工人注入提示词，产品代码）。
8. 除 `openspec/changes/writing-discipline/**` 与 `docs/team/reports/P282-dev-bob/**` 外**零文件改动**（日志里
   `git status --short` 只有新目录）。

## 未验证 / 限制（点名，别当成已验）

- **没跑门禁**（propose 阶段按任务书只跑验收四行；四条表面一个字节都没改，`smoke` 选集在这一阶段没有可判对象）。
  apply 阶段必须按 design 记录的那 28 个 keys 跑选集，交付与复验前各一次全量。
- **对照实验只有设计，没有执行**（任务书范围就是「设计一次可复算的对照」）；臂构造、rubric、盲法与判定规则在
  design 第 5 节，执行在裁定点 4 指的位置。
- **三处表面的文字是草案**（design 里三段英文草案 + 落点）；规格只写义务，apply 阶段定稿，措辞由评审读。
- 提案引用的 `+1.22 / −0.70` 取自研究的笔记（recipe 的 `docs/research.md`），方向与 arXiv 摘要一致；摘要级数字
  （9% / 33% / 0.2%→9.5% / 1,276-of-1,280 / 99.8% / 45 位专家 / 2,960 条意见）逐条核过原文，出处写在提案里。

## Suggested next steps

1. **PM 的提案审查**（阶段门）：`docs/team/reviews/writing-discipline-proposal.md`，按 `references/openspec.md` §4
   的十条清单逐条判，**并逐条裁提案里的裁定点 1–7**（每条都给了推荐版本）。**未 ACCEPTED 不得派 apply**。
2. ACCEPTED 后派 **apply**：任务书写 `change: writing-discipline`（`deltas: writing-discipline`），授权四个表面文件；
   若同意裁定点 3，一并授权本仓 `AGENTS.md`（只刷新标记块）。
3. apply 后再派**独立 verify**（第三个席位，不是 apply 作者）：按 tasks.md 第 5 节做对抗（删一面 → 评审判定必须失败
   且点名；门禁删前删后都绿）与对照材料复算。
4. 裁定点 4 的人读需要一个**人**：建议在你方便时用一次短读（两份报告 + 一张表）——它是这次改动的接受信号，不是统计实验。
5. 附带发现（`eight-point` vs 十条）交你记录；它不阻塞本变更。
