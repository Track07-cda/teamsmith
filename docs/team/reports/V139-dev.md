# V139 · delegate-openspec-archive 返修定点复核

agent: dev   status: NEEDS-CHANGES   time: 2026-11-09T10:08:23Z
branch: `task/V139-delegate-archive-rework-review`   HEAD: `b99166d9`

评审对象：冻结返修候选，规划 `3cb3a783`、报告 `b99166d9`（作者 dev2）。只读复核：未改规划、未实施、未跑试归档或真实归档、未跑选段或全量 smoke、未合并、未推送。

## Deliverables

| Path | What |
|---|---|
| `docs/team/reports/V139-dev.md` | 本次定点复核：判定、逐项关闭结论、阻断项与最小修法、实测命令回执 |
| `openspec/changes/delegate-openspec-archive/` | 只读评审对象（proposal/design/tasks/delta 均未修改） |

## 结论

**NEEDS-CHANGES**。V138 的 F1–F7 与 PM 五项裁定、两项联动，除 F6 的一处判据取值外全部关闭；剩下的一条阻断项不是方向问题，是一句话的精确度问题：**「自身 blocker」按 `phase` 字面比较，而 blockers 行里的 phase 是任务书原样值**，项目近期 12 份简报写的是 `opsx-*`，归档简报一旦照此写 `opsx-archive`（或 `-`），归档任务自己那一行就不被认成自身项，于是重新变成「archive 前必须让 `team change status` exit 0」的死结——正是 F6 要修的那个现象。

| 项 | 状态 | 一句话 |
|---|---|---|
| F1 | 关闭 | 执行者与主检出记录/日志例外写进了 design §2、OWNERSHIP、Impact 与 10/10b；身份来源是既有的运行时目录推导，不是被审任务的 `agent:` |
| F2 | 关闭 | 同一 verifier 合并后续跑；三句旧 merged-tree 逐条点名；`--branch <merged-sha>` 用现有实现即可绑定合并 revision |
| F3 | 关闭 | 12 文件 54 命中逐条 CHANGE/KEEP，未映射 0 条；Purpose 原文逐字一致，且排在 native archive 之后单独一笔文档提交 |
| F4 | 关闭 | 限定 PM-proxy 保留，proposal/design/delta 无删除句 |
| F5 | 关闭 | 严重级直接引 generatedBy 1.16.0 的定义与 Final assessment；报告模板确实缺这四个位置，属真实改动而非重述 |
| F6 | **未关闭（阻断）** | 判据写成 `phase=archive`，但行里的 phase 是简报原样值（`opsx-archive`/`-` 不会被认成自身项） |
| F7 | 关闭 | `/var/tmp` 下 `mktemp -d` 唯一目录，只清理该确切路径 |

另外一条不阻断的 WARNING（V139-F2）：verify 任务自己的复验记录目前由 PM 手写、提案没有指派，见下。

## Findings

### V139-F1（阻断）· 「自身项」按 phase 字面比较，与 blockers 行里 phase 的实际取值不一致

**证据**

- blockers 行的 phase 字段是任务书 `phase:` 的原样值。`common.sh:5619-5640` 的 `team_change_tasks` 对 phase 只做 `phase = val(...)` 取值，`common.sh:5665` 用格式串 `%s · %s · %s · %s` 原样打印 `$tphase`；把 `explore|propose|apply|verify|archive` 之外的值归一成空的只有 `team_task_phase`（`common.sh:5114` 的 `case "$p" in explore|propose|apply|verify|archive) ;; *) p="" ;;`），blokers 渲染链不经过它。
- 实测现场：本仓 `team change status delegate-openspec-archive` 打印 `P435 · opsx-propose · wip · …`——phase 是原样的 `opsx-propose`，不是归一后的 `propose`。
- 语料：`docs/team/tasks/` 中 `phase: opsx-verify` 4 份、`phase: opsx-propose` 3 份、`phase: opsx-explore` 3 份、`phase: opsx-apply` 2 份（V132、V135–V137、P428–P435 等近期简报），`phase: -`（含带注释形式）33 份。没有任何工具会拒绝这些拼写：`cmd-agents.sh:1316` 只把不认识的值归一为空，派单照常放行。
- 提案侧只写 `phase=archive`：design §3（`design.md:168`）、tasks 1.6（`tasks.md:12`）、delta 的 `The archive task recognizes only its exact self blocker` 场景（`specs/verification/spec.md`「the row whose phase is archive and whose task ID equals this brief's ID」）。提案任何一处都没有规定归档简报的 `phase:` 取哪个拼写。

**反例**

PM 照近期写法在归档简报里写 `phase: opsx-archive`。归档 worker 跑 `team change status <change>`，得到 `A1 · opsx-archive · wip · …`。按 delta：自身项仅限 phase 为 `archive` 且 ID 等于本简报的那一行，其余任何 blocker 都阻断；这一行 phase 是 `opsx-archive`，于是不是自身项 → 归档被自己那一行挡住。写 `phase: -` 同理（行里是 `-`）。而 design 同时禁止「把任何 archive 阶段的行都当自身」，worker 也没有别的合法读法，正确动作只能是 BLOCKED 回 PM，用户侧的归档被拖一次往返。

注意这不是工具行为需要改：`team board set A1 done` 的归档闸门按 **ID** skip 自身（`team_done_phase_evidence` 的 archive 分支传 `team_change_readiness "$change" "$id"`），所以只有「读 `team change status` 的人」会踩到这个字面比较。

**最小修法**（一句话，不新增开关、不改运行时）：design §3 与 tasks 1.6 写死「归档简报声明 `phase: archive`（枚举原值；`opsx-archive`/`-` 不算），blockers 行的 phase 就是简报原样值」，delta 场景同步加这半句；或者把判据改成「ID 等于本简报 ID 的那一行 + 它的 phase 与简报自己的 phase 值相同（且该值为 archive）」。

### V139-F2（不阻断，但要在 apply 前写准）· verify 任务自己的复验记录仍由 PM 手写，提案没有指派

**证据**

- `phase: verify` 任务的 done 证据是它**自己的**复验记录：`common.sh:5390` 要求 `docs/team/reviews/<verify-task>.md` 且判定 PASS（`common.sh:5437` 同步给下一步）。
- 现网 V132、V135–V138 的这类记录全是手写、抬头带「（PM）」：`# V1xx · 独立复验任务记录（PM）` / `# V136 · 归档前 openspec-verify 任务记录（PM）`；`grep -l '复验方式' docs/team/reviews/V13*.md` 无输出（没有一份是 `team review` 生成的），也没有 `agent:` 字段。
- 提案把被验记录的名字钉在**被审任务** ID 上（design §2：「The reviewed task ID need not be the verifier's own assignment ID」），所以 verify 任务自己的 `<verify-task>.md` 不会被工具生成；proposal/design/tasks/delta 没有一处说这份记录由谁写、算什么性质。

**反例**

apply 后 PM 按新默认派 verify 简报给 worker，worker 跑 `team review <impl-ID>` 生成 `reviews/<impl-ID>.md`（执行者写 worker，正确）。PM 随后 `team board set <verify-task> done`，闸门要 `reviews/<verify-task>.md` PASS——这份没人被指派写。PM 只能照旧手写一份带「（PM）」的存根；归档 worker 若去看它判断「独立验证是否完成」，就会看到一份 PM 抬头的手写记录，正是 F1 要消掉的那种归属混淆，只是上移了一层。

**最小修法**：design §2 + tasks 1.2 补一句——verify 任务自身的 done 证据由 PM 以「PM 接受记录」写入 `docs/team/reviews/<verify-task>.md`（PM 拥有的 docs 写入，不跑门禁），标题写明是 PM 接受而非验证执行；被验实现任务的工具记录 `<impl-ID>.md` 才载执行者与 SHA。要归档就必须读工具记录那条（design §3 已写「the latest centralized review identifies the verified merged SHA」）。

## 必查项逐条

| 必查项 | 结论 | 依据 |
|---|---|---|
| verify 的真实执行者与主 review/log 例外 | 关闭 | design §2 把执行者钉在调用者运行时目录身份，记录/日志例外只到 `docs/team/reviews/<ID>.md` 与 `<ID>-verify.log`；身份推导工具已存在（`gate_lock_seat_of_dir` 在 `cmd-review.sh:1173,1204` 已经在用，推导本体 `team_seat_from_paths` 在 `common.sh:805`）；Impact 列了 `cmd-review.sh` 与 10/10b，tasks 1.3/2.2 要求真实 verifier 执行并做红/还原变异 |
| 同一 verifier 的合并后验证 | 关闭 | design §3 单列三句旧 merged-tree（`workflows.md:19`、`openspec.md:44,153`，我逐条核对原文确实是「PM re-runs the gate on the merged tree」），并明确 `--post-merge` 是检查不是这次验证；`--branch <merged-sha>` 可用：`team_resolve_branch`（`cmd-review.sh:58-60`）原样返回 `--branch` 参数，`rev-parse --verify "<sha>^{commit}"` 接受提交号，无需新开关 |
| 12 文件 54 命中与 Purpose 独立提交 | 关闭 | 逐文件实测命中数 4/1/6/2/1/11/7/9/6/3/2/2，合计 54；与 design §1 的点名行逐条比对**未映射 0 条**（脚本回执见下）；设计里 Before 块与 `openspec/specs/verification/spec.md` 现有 Purpose 逐字相等；archive skill 明确「Preserve existing `## Purpose` sections completely untouched」（`.pi/skills/openspec-archive-change/SKILL.md`），所以「先 native archive、后单独 Purpose-only 文档提交」的顺序成立 |
| 保留限定 PM-proxy | 关闭 | proposal Why/What Changes、design §4、delta `Limited PM-proxy confirmation is retained` 三处一致保留「小步、可逆、已被批准方案覆盖 + 记确认人与理由」；首轮「proxy 不再满足」的句子已不在 delta 里（grep `proxy` 只剩保留语义） |
| OpenSpec 固定严重级和报告位 | 关闭 | `.pi/skills/openspec-verify-change/SKILL.md`（`generatedBy: "1.16.0"`）里的定义与 design §4 对得上：CRITICAL（未完成任务/缺实现/已删需求仍实现/改名需求找不到，行 90–119）、WARNING（实现可能偏离规格、场景未覆盖、design 决策未遵循，行 133–153）、SUGGESTION（代码模式偏差，行 162）、三维表与 `Not verified (<reason>)`（行 174–179）、Final assessment 的计数与措辞（行 201–205）、不确定时取低严重级（行 213）。`openspec instructions verify` 确实是无效命令（实测报 `Artifact 'verify' not found in schema 'spec-driven'`）。`templates/report.md.tmpl` 现在没有这四个位置 → tasks 1.4 是真改动 |
| archive 自身 blocker 的精确判定 | **未关闭** | 规则与 `workflows.md:281`、`openspec.md:45,154` 的「exit 0」改写方向正确（三处原文均已核实），但 phase 取值见 V139-F1 |
| `/var/tmp` 试归档 | 关闭 | design §5 给 `mktemp -d -p /var/tmp teamsmith-archive.XXXXXX`、独立项目子目录、只 `rm -rf` 该确切路径；替换对象点名 `openspec.md:154`（原文确实是 `cp -r openspec /tmp/trial`） |
| `cmd-review.sh` 身份来源与测试任务可执行 | 关闭（测试可用既有夹具实现） | 身份来源不是被审任务的 `agent:`，而是运行时目录：`gate_lock_seat_of_dir`（`gate-lock.sh:530`）→`team_seat_from_paths`（`common.sh:805`），主检出→`pm`、`<main>/<worktrees>/<名字>`→该名字；`cmd-review.sh:1353,1356,1437` 三处硬编码原文与 design 引用一致。测试可执行：段 `10`/`10b` 本来就在夹具里跑真 `team review` 并断言记录内容，夹具已有多处 `worktree add` 造 `.worktrees/<name>` 的例子，变异侧已有复制 `$SKILL_DIR` 后 sed 再跑的既有写法（`smoke.sh:89-92`、`:5824`、`:10247`）；`section-paths.tsv` 的 10/10b/19/12j 行已如实登记它们读的文件（含 `report.md.tmpl`、`README.md`），tasks 2.3 要求按实际读取更新 |

## Verification evidence（实际跑过的命令与尾部）

工作树 `…/.worktrees/dev`，`export PATH="$HOME/.bun/bin:$PATH"`，`openspec 1.16.0`，HEAD `b99166d9`。

```
$ openspec validate delegate-openspec-archive --type change --strict
Change 'delegate-openspec-archive' is valid          # rc=0

$ openspec validate --all
Totals: 24 passed, 0 failed (24 items)               # rc=0

$ openspec validate --all --strict
Totals: 4 passed, 20 failed (24 items)               # rc=1（主检出同命令：3 passed, 20 failed (23 items)）
```

`--strict` 的 20 项失败是既有的：19 个 spec 的 `Requirement text is very long (>500 characters)` 警告 + `change/agent-self-reminder` 缺 delta，0 ERROR；P435 报告已如实写明同一组数字（`before_totals`/`after_totals` 都是 4/20/24）。所以：「OpenSpec 24/24」是**不带 `--strict`** 的结果；design §6 的验收命令 `openspec validate --all --strict` 在当前环境不可能绿，apply 只能照 design 已写的口径「点名既有失败、不静默放过」。

```
$ bash skills/teamsmith/tests/spec-refs.sh
spec-refs: judged 126 reference(s) (49 distinct) in 14201 effective line(s); retired 0; undeclared 0; id families used [D,E,F,M,P,V] named [D,E,F,M,P,V]   # rc=0

$ bash skills/teamsmith/tests/section-select.sh --check
== 选段自检 ==  ok 13  bad 0  SKIP 1                 # rc=0

$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: root=…/.worktrees/dev scope=published files=2501 hits=0 names=ok user=resolved   # rc=0（含本报告落盘后）

$ git diff --check
# 无输出，rc=0

$ git diff --name-only e180fdbf..HEAD
docs/team/reports/P435-dev2.md
openspec/changes/delegate-openspec-archive/design.md
openspec/changes/delegate-openspec-archive/proposal.md
openspec/changes/delegate-openspec-archive/specs/verification/spec.md
openspec/changes/delegate-openspec-archive/tasks.md
```

清单覆盖（12 文件 / 54 命中 / 未映射 0）：

```
templates/AGENTS.section.md.tmpl   hits= 4 rows= 5
templates/pm-prompt.md.tmpl        hits= 1 rows= 5
templates/PROTOCOL.md.tmpl         hits= 6 rows= 7
templates/OWNERSHIP.md.tmpl        hits= 2 rows= 3
templates/memory-seed.md.tmpl      hits= 1 rows= 1
SKILL.md                           hits=11 rows=14
references/workflows.md            hits= 7 rows= 9
references/openspec.md             hits= 9 rows=11
references/protocol.md             hits= 6 rows= 7
references/troubleshooting.md      hits= 3 rows= 3
README.md                          hits= 2 rows= 2
skills/teamsmith-init/SKILL.md     hits= 2 rows= 2
total grep hits: 54
unmapped hits: []
```

（rows 多于 hits 的部分是 design 明写的 supplement 行：跨行、大小写不匹配的相反句。）

delta 结构：6 条 requirement、15 个 scenario；design 的 Before 块与 `openspec/specs/verification/spec.md:5-7` 逐字相等（脚本比对 `True`）。

## 反例/翻转证据

本任务不修缺陷，没有 red→green 的翻转；阻断项的反例已在 V139-F1 给出，证据是代码行（`common.sh:5619-5665`）加现场输出（`P435 · opsx-propose · wip · …`），不需要改坏产品去复现。

## 未验证 / 边界

- 未跑 smoke（选段或全量）、未做变异、未跑试归档或真实归档、未实施任何改动——按任务书「只审提案」。
- design §6 列的 apply 验收命令里，`section-select --check`、`spec-refs`、change strict 我复跑通过；`openspec validate --all --strict` 仍是既有红（见上），Apply 时不能当通过。
- 12 文件清单我按当前 HEAD 的源文件核对（`e180fdbf..HEAD` 只动了 4 份规划 + 1 份报告，指引文件与 `e180fdbf` 逐字相同，所以基线行号可用）。
- 未验证「每个 KEEP 的理由是否都成立」这一层语义判断到 reviewer 能独立成立的程度：我核对的是每条命中都有一条带理由的判定、没有漏项；KEEP 的理由本身（例如 `pm-prompt.md.tmpl:163` 是 roster/gates 上下文）与该行原文一致。

## Ledger ban（固定行，在本工作树跑）

```
$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: root=…/.worktrees/dev scope=published files=2501 hits=0 names=ok user=resolved
$ echo $?
0
```

## 决策与偏差

- 判定取 NEEDS-CHANGES 而不是 ACCEPT-with-WARNING：V139-F1 落在任务书点名的「archive 自身 blocker 的精确判定」这一必查项上，且有在用拼写的具体反例；修法是一句话，现在改比 apply 之后改 12 份指引便宜。
- 未把 `--all --strict` 既有红算成提案缺陷：它与 `e180fdbf` 完全一致（P435 报告已给前后对照），且 design §6 已写明「既有严格失败要点名、不许静默通过」。
- 没有重开方向：verify/archive 交由非实现者执行、PM 只保留派单/审阅/合并/沟通，这一用户裁定不在本次复核范围内。

## Suggested next steps

1. dev2（或 PM 指定者）按 V139-F1 在 design §3、tasks 1.6、delta 自身项场景各补半句；V139-F2 的指派句建议一并补，避免复审第二轮。
2. 复审只需看这两处改动 + 相应段落的措辞一致性，其余关闭项不必重跑。
3. 复审通过后由 PM 出 ACCEPTED，再按 change 纪律派 Apply；本报告不构成对 Apply 的授权。
