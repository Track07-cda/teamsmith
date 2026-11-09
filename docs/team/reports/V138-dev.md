# V138 · delegate-openspec-archive 提案非作者审阅

agent: dev   status: NEEDS-CHANGES   time: 2026-11-09T09:18:01Z
branch: `task/V138-delegate-archive-proposal-review`   HEAD: `e180fdbf`

评审对象：冻结候选 `e180fdbf`（作者 dev2）。只读审阅；未改规划、未实施、未跑全量、未做真实归档、未合并。

## Deliverables

| Path | What |
|---|---|
| `docs/team/reports/V138-dev.md` | 本次非作者审阅：判定、逐项反例与最小修法、命令回执 |
| `openspec/changes/delegate-openspec-archive/` | 只读审阅对象（proposal/design/tasks/delta 均未修改） |

## 结论

**NEEDS-CHANGES**。方向成立：verify/archive 执行交给非实现者，PM 保留审阅、差异核对、合并和用户沟通；不新增永久席位、配置键、状态机或门禁段。问题不在方向，在五个会让 apply 产出错证据或留下相反口径的规划缺口；都能在 proposal/design/tasks 内修完，不需要重做方案。

| # | 阻断项 | 一句话 |
|---|---|---|
| F1 | verify 阶段没有写者与工具归属 | `team review` 把记录写进主检出，并自称「PM 独立复验」「PM 提供」；提案只给 archive 开了工作树授权 |
| F2 | 合并后的门禁没有新主人 | 现行三处写着「PM 在合并后的树上重跑门禁」，提案只删 PM 执行，没有指派谁跑 |
| F3 | 相反口径清单不完整 | 至少 8 处已安装/公开的相反句子不在八份文件与逐文件清单里，含基规格 `verification` 的 Purpose |
| F4 | 移除 PM-proxy 超出用户裁定 | 用户只说 verify/archive 不由 PM 做；现有三处允许小步变更由 PM 代理确认，提案直接删掉 |
| F5 | CRITICAL/WARNING 没有定义与记录位 | 归档前置要求「CRITICAL 清零、WARNING 披露」，但现有记录格式没有严重级字段，也没说什么算 CRITICAL |

---

## Findings

### F1（阻断）· verify 阶段没有写者与工具归属：`team review` 的记录落在主检出并自称 PM

**证据**

- `skills/teamsmith/scripts/lib/cmd-review.sh:91`：记录路径是 `$TEAM_DOCS_ABS/reviews/$1.md`；`:1147`（`common.sh`）`TEAM_DOCS_ABS="$TEAM_MAIN_ROOT/$TEAM_DOCS_DIR"` —— worker 跑这条命令时，记录落在**主检出**的 `docs/team/reviews/`。
- `cmd-review.sh:1353` 写 `# <ID> · PM 独立复验`；`:1356` 写 `- 独立 checkout：…（PM 提供，skill 只读；不信任 agent 工作区）`；`:1437` 写 `## PM 结论`。记录里没有复验者身份字段。
- 提案 design §2（`design.md:26`）说「If more verification is needed, dispatch it; do not run it personally, including by starting a PM-owned background gate」；`:34` 又说 archive 的「All writes are in that worker's own worktree and task branch … the main checkout … remain outside the grant」。verify 侧没有对应授权。
- 任务 1.2 只改 `templates/OWNERSHIP.md.tmpl`，把 PM 拥有的 specs/config 与 **archive brief** 的临时授权分开；没有 verify brief 的记录路径。
- 基规格 `openspec/specs/verification/spec.md:11` 仍写 `team review <ID> --dir <path>` 只对「the checkout **the PM prepared**」运行；`:23` 的场景要求记录「exists in the main worktree」。

**反例**

一个非实现者 V1 按提案执行 verify。它要跑门禁并留下记录，唯一带门禁锁、硬超时和结构化检查的入口是 `team review V1 --dir /tmp/review-M1`。这条命令会：

1. 往**主检出**写 `docs/team/reviews/V1.md`（`docs/**` 在 OWNERSHIP 模板里归 PM）；
2. 在记录里写「PM 独立复验」「PM 提供」「PM 结论」。

也就是说，PM 一步都没做，账本却写着 PM 做了；或者为了让路径归属正确，只能由 PM 来跑这条命令 —— 这正是任务书要防的「名义委派、PM 后台照跑」。若让 V1 自己准备 checkout，则与基规格 `:11` 的「the PM prepared」冲突，需要 MODIFIED delta；提案没有做这个选择。

**最小修法**

1. 在 design §2 和任务 1.2/1.3 明确 verify brief 的临时授权：`docs/team/reviews/<verify-task>.md`（写在自己分支并由 PM 合并），或明确保留「主检出的这一条账本写入」并写进 OWNERSHIP 模板的例外行。
2. 明确谁跑 `team review`：PM 只准备 detached checkout（基规格允许），由 verifier 执行命令；或 verifier 自备 checkout（则补一条 MODIFIED delta 改 `verification#Reviewing needs an independent checkout`）。
3. 记录抬头必须能指向真实执行者：把 `cmd-review.sh:1353/1356/1437` 的写死「PM」改成按任务的 `agent:` 取值（这是 `scripts/lib/cmd-review.sh` 的产品改动，需要加入 Impact），或者明确由 verifier 按现有格式手写记录并说明为什么不走 `team review`（后者会丢掉门禁锁/硬超时的既有保证，不建议）。

### F2（阻断）· 合并后的门禁没有新主人

**证据**

- `skills/teamsmith/references/openspec.md:44`（phase 表 verify 行）：「**PM**: re-runs the gate on the merged tree, decides `done`, and only then proposes archiving」。
- `openspec.md:153`（§5 verify 行）：「then `team board set <ID> done` after re-running the gate on the merged tree」。
- `skills/teamsmith/references/workflows.md:19`（§0 phase 表）：「the PM re-runs the gate on the merged tree and sets `done`」。
- design §1 给 `openspec.md` 的行只点名「Archive owner is PM、PM-proxy、旧工具版本的 verify 入口」，给 `workflows.md` 的行只点名「PM runs `team review`、pre-close gate、fallback `TEAM_GATES`」；这三句「merged tree」不在逐文件清单里。任务 1.3 的「delegated gate execution」是概括，不足以保证 apply 会改这三句。

**反例**

PM 按现行流程 squash-merge M1 进 main。合并后的树是一个新 revision，可能与被验分支不同（冲突解决、squash 内容差异）。现行三处要求 PM 在这个新 revision 上重跑门禁；提案的 delta 又要求 PM「MUST NOT execute … its verification gates」。apply 若照清单只改 phase owner，这三句会留下：PM 继续跑门禁，违反新规则；apply 若删掉它们，合并后的树就没人跑门禁了 —— 归档 worker 的职责是 spec 归档，不是代码门禁。提案没有回答这个分叉。

**最小修法**

在 design §3 和任务 1.3 选一个并写死：

- verifier 在 PM 合并后对 merge commit 再跑一次 `team review`（或由 PM 另派一个 post-merge verify 任务），结果作为 archive brief 的前置；或
- archive worker 在基于合并基线的自己的分支上先跑项目门禁（作为 trial 之外的第二个前置），并把结果写进 archive 报告。

同时把上述三句逐条加进 inventory，并在 delta 的「the revision being archived」处点名「合并后的 revision」，避免「验的是分支、归档的是合并结果」的漂移。

### F3（阻断）· 相反口径清单不完整：八份文件之外仍有已安装/公开的相反句子

**证据（都能直接引用）**

不在八份文件里、但已安装或公开的：

- `skills/teamsmith/templates/memory-seed.md.tmpl:23`：「an agent's report is a claim; **the PM's gates on an independent checkout** are the evidence」。这是 `team init` 装进每个项目的记忆种子模板，PM 会把它写进项目记忆。
- `skills/teamsmith/references/troubleshooting.md:1399`：「`team review` runs the gates against a checkout **the PM prepared** and writes the verdict record itself」。—— 已安装的 runbook。
- `README.md:15`：「The agent's report is a **claim**; **the PM runs the gates** on an **independent checkout** (`team review <ID> --dir …`) and that becomes the evidence」。—— 公开产品描述。
- `skills/teamsmith-init/SKILL.md:85`：「Day-to-day operation lives in the **teamsmith** skill: the PM loop, dispatch, **independent verification**, merging …」。—— init skill 的交接段。
- `openspec/specs/verification/spec.md:5`（基规格 Purpose）：「**The PM's independent check** of an agent's claim: gates run on a checkout the agent never touched …」。delta 只有 ADDED，Purpose 不会随 archive 改写；归档后这条 capability 的 Purpose 仍说 PM 做检查。

在八份文件里、但不在 design 逐文件清单点名的：

- `templates/AGENTS.section.md.tmpl:60`：「**Never claim tests passed without having run them.** The PM re-runs in an independent worktree」。—— design 的 AGENTS 行只列 `Roles / Specs / Delivering`，说「all three operative statements」；这句在 Non-negotiable discipline。
- `templates/PROTOCOL.md.tmpl:28`（Hard rules 1）：「The PM re-runs independently」。—— design 的 PROTOCOL 行只列 `role table / phase flow / verification`。
- `templates/pm-prompt.md.tmpl:100-101`：「Do not run long work in your own session — not a full gate … **A seat does that work, or `team_bg_run` does it in the background**」。—— design 的 pm-prompt 行只列 `PM responsibilities / mandatory verification / spec phases`；这句在 Your loop 的 Background jobs 段。
- `references/workflows.md:174`：§E2 标题「**The PM's background gate**」，整节示范 PM 用 `team_bg_run` 跑 `team review`。—— design 的 workflows 行没有点 §E2。
- `references/protocol.md:45`：「The main worktree (main) belongs to the PM alone: merges, **verification** and documentation happen there」；`:649`：「`review <ID> --dir <the checkout the PM prepared>` runs the gates … (git is prepared by the PM)」。—— design 的 protocol 行说只改「owner/independent-verification and gate-executor paragraphs」，这两句不在该描述内。
- `SKILL.md:52`（命令表 Verify 行）：「`team review <ID> --dir <PM-prepared independent checkout>`」。—— design 的 SKILL 行列了 description/introduction/diagram/PM loop/Specs/non-negotiable rules，没有命令表。

**反例**

apply 按 design 的逐文件清单执行：AGENTS 改角色表、Specs、Delivering 三段；PROTOCOL 改角色表、phase flow、Gates；pm-prompt 改人格、循环第 4 步、Specs。结果是 `AGENTS.section.md.tmpl:60`、`PROTOCOL.md.tmpl:28`、`pm-prompt.md.tmpl:100-101`、`workflows.md:174` 全部原样留下，仍然告诉 PM「重跑」「用 team_bg_run 在后台跑全量门禁」。§19 的新检查落在角色行/归档前置段，抓不到这些句子；独立 verifier 若只按 design 清单逐项核对，也可能漏掉 `templates/memory-seed.md.tmpl` 与 `troubleshooting.md`（它们不在清单里）。

**最小修法**

把 design §1 的逐文件散文换成**逐行清单**：对 `templates/{AGENTS.section,pm-prompt,PROTOCOL,OWNERSHIP,memory-seed}.md.tmpl`、`SKILL.md`、`references/{workflows,openspec,protocol,troubleshooting}.md`、`README.md`、`skills/teamsmith-init/SKILL.md` 跑一次 `grep -nE 'PM.*(verif|archive|gate)|(verif|archive|gate).*PM'`，每个命中写「改 / 保留（理由）」。至少把 `memory-seed.md.tmpl` 与 `troubleshooting.md` 纳入本 change（它们是已安装文件）；`README.md`/`teamsmith-init/SKILL.md` 若不改，就在 proposal 的「不做什么」和 delta 的「shipped guidance」定义里明确排除，别让用户读到「teamsmith 默认」而 README 仍说 PM 跑门禁。基规格 Purpose 由 archive brief 明确要求更新（archive 授权已含 `openspec/specs/<capability>/spec.md`）。

### F4（阻断）· 移除 PM-proxy 超出用户裁定

**证据**

- `references/openspec.md:45`：「**the user** confirms; the PM may confirm as the user's proxy only when it states that plainly and records why (small, reversible, already covered by the approved approach)」。
- `references/openspec.md:154`：「the user's confirmation recorded (who confirmed, **or why the PM acted as proxy**)」。
- `references/workflows.md:20`：「the user confirms (**the PM may act as the user's proxy** only when it says so and records why)」。
- P435 用户裁定（`docs/team/tasks/P435-delegate-archive-proposal.md`）：「verify 和 archive 不要 PM 亲自做」+「用户归档确认仍是前置条件」。没有一句说移除 proxy。
- 提案的 Why 只引「verification and archive are delegated work」；delta 却新增「a PM-proxy confirmation does not satisfy the user's confirmation」（`openspec/changes/delegate-openspec-archive/specs/verification/spec.md:46`）。

**反例**

一个小的、可逆的、已被批准方案覆盖的 change，按现行三处规则 PM 可以代理确认并记录理由；提案生效后它必须等用户。反过来，如果用户确实想删 proxy，提案里也没有记录这条决定，apply 无法判断这是用户裁定还是作者顺手收紧。两种情况下 PM 都会在 archive 前置上做出与用户意图不一致的判断。

**最小修法**

二选一，写进 proposal 的 Why 和 delta：

- 保留现有 proxy 规则（它不与「PM 不亲自 archive」冲突；archive worker 仍检查记录里的确认人与理由），只改执行者；或
- 在 proposal 的 Why 引用用户明确要求移除 proxy 的原话/决定编号，再把 delta 写成「proxy 不再满足」；没有这句引用就按第一条处理。

这是用户级取舍，建议 PM 直接问一句再定。

### F5（阻断）· CRITICAL/WARNING 没有定义与记录位

**证据**

- delta（`openspec/changes/delegate-openspec-archive/specs/verification/spec.md:27`）：「zero unresolved CRITICAL findings, recorded WARNING findings and unverified items」；design `:40`：「unresolved CRITICAL findings always stop the phase」。
- 现有复验记录（`cmd-review.sh` 生成）只有 `判定: **PASS|FAIL|TIMEOUT|SKIPPED|UNKNOWN**` 与「PM 结论」勾选项；`templates/report.md.tmpl` 只有「Notes: what was not verified, known risks, TODOs」。没有 `CRITICAL`/`WARNING` 字段。
- 提案没有给这两个词下定义，也没有说它们写进哪个字段/小节。

**反例**

同一个「某场景没有在真实环境跑过」，verifier A 记为 WARNING + unverified，verifier B 记为 CRITICAL。archive worker 看到两种记录，无法证明「zero unresolved CRITICAL」；「WARNING 与未验证项在确认前披露」也没有固定位置可核对。这条 SHALL 在记录里没有可判定的输入。

**最小修法**

在 delta/design 加两行定义，并在 `templates/report.md.tmpl`（或复验记录的「PM 结论」段）指定记录位：

- CRITICAL：change 的某条 scenario 失败、delta/design 与实现矛盾、或会改变已接受行为的缺陷且没有处置。
- WARNING：不使 scenario 失败的已知限制/未验证项；必须写进固定小节并在用户确认前披露。

若不想改报告模板，就明确把 CRITICAL 映射到现有的 `判定: **FAIL**`，WARNING 映射到 Notes 的固定标题，并说明 archive worker 读哪一行。

### F6（不阻断，但要在 apply 前写准）· `team change status` 自身 archive 任务未完成的语义

**证据**

- design `:46`：「`team change status <id>` does not take that argument and may truthfully show the in-progress archive task as a blocker. The archive instructions must distinguish **that one self entry** from unfinished siblings」。
- `scripts/lib/common.sh:5665` 的 blockers 行格式是 `<tid> · <phase> · <status> · <reason>`，没有「self」标记；`scripts/lib/cmd-status.sh:1357` 只给 verify 任务算 `self-verify` 标记，archive 任务没有。
- `references/workflows.md:281` 仍写 `team change status <change>` 「must exit 0: every task finished + no unchecked item」。

**反例**

archive worker 跑 `team change status C`，看到的 blockers 是 `A1 · archive · wip · …`，没有任何「这是你自己」的标记。设计说「distinguish that one self entry」，但没给判据；worker 只能靠任务书里的自己的 ID 去对。另一方面，`workflows.md:281` 的「must exit 0」在 archive 之前**不可能**成立（archive 任务自己未结束），如果 apply 照抄，会教 worker 去追一个永远达不到的绿，或者为了「让命令变绿」错误地忽略别的 blocker。

**最小修法**

在 design/tasks 写死：archive 行 = blockers 里 `phase=archive` 且 `tid` 等于本任务书 ID 的那一行；命令非零但**唯一**的 blocker 是这一行时不阻断 archive；任何其他行（含 checklist 行）照旧阻断。并把 `workflows.md:281`、`openspec.md:45`、`openspec.md:154` 的「must exit 0 / exits 0」改成「读 blockers，扣除 archive 自己那一行」的表述，不要新增 readiness 开关。

### F7（不阻断）· trial archive 示例仍用 `/tmp/trial`

**证据**

- `references/openspec.md:154`：`cp -r openspec /tmp/trial && (cd /tmp/trial && openspec archive -y <id>)`。
- design `:42` 说要「isolated **disk-backed** scratch directory」；任务 1.3 只说「trial and real local archive」，没有点名替换 `/tmp/trial`。
- 本项目规则：不要用 `/tmp`（15G tmpfs，2026-10-27 曾因历史残留塞满内存）。

**反例**

apply 按 design 改成「disk-backed」但漏掉命令示例；用户照 `openspec.md:154` 复制到 `/tmp/trial`，在小内存机器上重复同一次 `No space left on device`。

**最小修法**

任务 1.3 点名 `openspec.md:154` 这一行，把 `cp -r openspec /tmp/trial` 换成 worker 的磁盘临时根（如 `mktemp -d` 在 `TMPDIR`/项目约定的磁盘路径下），并在同一段说明为什么不放 `/tmp`。

---

## 七条必查的逐条回答

1. **PM 审阅/差异核对/合并权 + 非实现者执行，有没有「名义委派、PM 后台照跑」**：原则在 design `:26` 写清楚了（PM 可做 `--pre-merge`/`--post-merge` 的记录核对，不做门禁），但 F1/F2 是执行层的洞：verify 的记录写者没有授权且自称 PM，合并后的门禁没有新主人。**不通过**，修 F1/F2。
2. **verifier 兼 archive 是否符合用户要求、仍独立于实现者、是否要求第三个永久席位**：符合；`design.md:24` 明确不新增 archive agent 类型/永久 roster/任务类别/配置键/第二份状态文件，独立性的对象是「实现者」而不是「另一个固定席位」；report-only 的 verify 席位由另一个非实现者接 archive。**通过**。
3. **归档前 OpenSpec verification、CRITICAL 清零、WARNING/未验证项披露、用户确认是否完整；移除 PM-proxy 是否冲突/越权**：前置项在文本上齐全；但 F5 让 CRITICAL/WARNING 不可判定，F4 的 proxy 移除超出 P435 用户裁定。**原则通过，条款要补定义/补授权**。
4. **archive 在自己 worktree/branch 写 specs/归档目录、PM 合并，是否与 OWNERSHIP/权限兼容；两个依赖 change 串行是否可执行**：archive 的授权枚举（change 目录、归档目的地、受影响 capability 的 spec、report）与「不写主检出/不推 main」兼容；串行归档用已合并基线和完整 MODIFIED 块比对，`design.md:58` 明确不新增依赖字段/图/锁/状态机，可执行。**通过**；但 F1 的 verify 记录授权仍缺，需一并补。
5. **八份文档与 §19/§12j 是否覆盖所有相反口径；是否建立新流程系统/额外门禁层/不必要状态**：§19 原地加强、§12j 只换 actor、`section-paths.tsv` 只扩一行、不加段/脚本 —— 这条「净零」做对了；但逐文件清单不完整（F3），且 §19 的新检查不覆盖 §E2/merged-tree 这类执行句子，独立 verifier 必须补人工逐行核对。**不通过**，修 F3。
6. **`team change status` 自身 archive 任务未完成的语义是否准确；能不能绕别的 blocker**：机制描述准确（`team_change_readiness` 的 skip 参数只给 done 闸门用；`cmd-status.sh:1381` 调它时不带 skip，所以会如实显示未完成的 archive 行）。但「that one self entry」没有工具标记，且 `workflows.md:281` 的「must exit 0」在归档前不可满足；按 F6 写成「按任务 ID 认领自己那一行，其他 blocker 照旧」即可。**机制通过，措辞要改**。
7. **是否明确不追溯阻塞当前两个已授权委派的 change**：proposal.md 的 Impact 最后一条（「Existing verification and archive assignments continue … they do not wait for this proposal」）与 design `:91`（「P435 does not change current V136 verification or the already authorized separate archives」）都写了。**通过**。附带提醒：`openspec/changes/route-page-check-determinism/tasks.md:25` 仍写「before **PM archives** this change」，两份已授权 change 的 archive brief 要明确以用户授权覆盖这句旧措辞，不要照 change 内旧句子派单。

---

## Verification evidence（实际跑过的命令与尾部）

```
$ cd <repo>/.worktrees/dev && export PATH="$HOME/.bun/bin:$PATH"   # cwd: V138 worktree
$ openspec validate delegate-openspec-archive --type change --strict
Change 'delegate-openspec-archive' is valid
$ echo $?
0
```

```
$ openspec validate --all
...
Totals: 24 passed, 0 failed (24 items)
$ echo $?
0
```

```
$ openspec validate --all --strict
...
Totals: 4 passed, 20 failed (24 items)
$ echo $?
1
```

> 这是冻结 tip 的**既有**状态，不是本提案引入的：24 个条目里 20 个因「Requirement text is very long (>500 characters)」的 WARNING 在 `--strict` 下计数为 failed（共 242 条 WARNING，含 `spec/verification`）。PM 记录里的「OpenSpec 24/24」是非 strict 的结果；design §5 已写「Existing unrelated strict-validation failures must be named rather than fixed in this change or reported as a pass」，apply 报告必须如实点名这 20 项，不能写「strict 全绿」。本 change 自身的 `--type change --strict` 是绿的。

```
$ bash skills/teamsmith/tests/spec-refs.sh
spec-refs: judged 125 reference(s) (49 distinct) in 14166 effective line(s); retired 0; undeclared 0; id families used [D,E,F,M,P,V] named [D,E,F,M,P,V]
$ echo $?
0
```

```
$ bash skills/teamsmith/tests/section-select.sh --check
ok: 段正文点名的真实路径 token 都被各自的行覆盖（563 个 token 检查过；0 个豁免类 token 不参与）
...
== 选段自检 ==  ok 13  bad 0  SKIP 1
$ echo $?
0
```

```
$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: names：名单已配置（/home/<user>/Documents/syncthing/Work/Projects/pm-skills/.git/../.pi/team/forbidden-names.txt，命中即红）
ledger-ban: root=/home/<user>/Documents/syncthing/Work/Projects/pm-skills/.worktrees/dev scope=published files=2500 hits=0 names=ok user=resolved
$ echo $?
0
```

```
$ git diff --check
$ echo $?
0
```

未执行并说明理由：没有跑 `smoke.sh`（本任务是提案审阅，不改测试；§19/§12j 的现有实现按代码逐行核对，足以判断「当前口径接受 PM」和「新检查能否落位」），没有跑全量门禁，没有做 trial/真实 archive，没有做任何规划或产品改动。§19 的现有判据是 `OWNER-EMPTY`（只判非空）与整文件 `INDEPENDENT-VERIFY-MISSING` / `USER-CONFIRM-MISSING`（`smoke.sh:11640/11666/11676`），与 design §1 的描述一致。

## Flip evidence

本任务不是缺陷修复，没有产品代码改动，因此没有 red→green 的翻转证据。提案自带的 §19 变异方案（design §5）我按代码核对了落点：`os_flip_red` 的沙箱副本覆盖 `references/`、`templates/`、`SKILL.md`（`smoke.sh:11769`），可以承载「把 verify/archive owner 改成 PM」「允许未验证归档」等变异；但 F3 列出的句子不在现有 `os_pipeline_hits` 的判据面里，靠 §19 不会自动变红，必须按 F3 补清单/补检查或由独立 verifier 逐行核对。

## Decisions and deviations

- 只读审阅，没有改 `openspec/changes/delegate-openspec-archive/` 的四个规划文件，也没有改任何模板/测试/产品代码。
- 没有替 PM 做取舍：F4（proxy）和 F1 的「谁跑 `team review`/记录写在哪」是产品与用户级选择，报告只给两个可执行选项，不替用户拍板。
- 主检出未动；本报告只写在自己的 worktree 与任务分支。

## Suggested next steps

1. 作者（dev2）按 F1–F5 修 proposal/design/tasks；F6/F7 顺手改准。重点是把「verify 记录谁写、写在哪、记录抬头写谁」「合并后门禁谁跑」「CRITICAL/WARNING 定义与记录位」写成可照做的句子。
2. PM 对 F4 做一次用户确认：保留 proxy 还是移除；把决定写进 proposal 的 Why/delta。
3. 修完重新走非作者审阅；在 ACCEPTED 之前不派 apply 任务。
4. apply 时注意：`openspec validate --all --strict` 在当前 tip 是 20/24 failed 的既有状态，报告要如实点名，不能声称 strict 全绿；本 change 的 `--type change --strict` 必须绿。
5. 当前 V136 与两个已授权委派 archive 的 change 不受本审阅阻塞；它们的 archive brief 要明确以用户授权覆盖 `route-page-check-determinism/tasks.md:25` 的旧「PM archives」措辞。
