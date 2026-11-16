# P465 · 帮助入口的单次 canonical 页面生成

**已实施每命令第二次相同 canonical 调用的删除，静态检查通过；未执行行为验收。** 当前 manifest 为 47 行 / 47 个唯一命令，只计受改比较循环，调用结构为 188→141，退休 47 次调用；没有测量实际节省时间。实现提交 `9bee06a8d9e8bdcf105b950bb0f37768a39bcff2` 仅修改测试文件和 1.1 勾选；本报告及 1.2 收口随后单独提交。2.1、2.2 留待非作者执行，不具备归档结论。

agent: dev   status: DELIVERED（仅实现与静态，行为未验）   time: 2026-11-16T11:45:32Z
branch: `task/P465-help-render-once-apply`   PR/MR: -（仅本地）

## Deliverables

| Path | What |
|---|---|
| `skills/teamsmith/tests/help-surface.sh` | 新增最小 `check_route_command`；原正常循环改为同 shell 调用它。三个真实入口各尝试一次，原字节文件比较两次，逐入口收取 rc，仍由原 `finding` / `FIND` / 最终出口负责失败 |
| `openspec/changes/help-route-render-once/tasks.md` | 本轮仅完成 1.1、1.2；2.1、2.2 不勾选，正文不改 |
| `docs/team/reports/P465-dev.md` | 静态回执、调用账、输入身份、复用边界及交给验证者的实际源码位置 |

写集以起点 `8b35c2612c20558bf440eca58cf6606ec9acbee6` 为准；除上面三文件外无写入。proposal/design/delta/元数据、正式 spec、产品代码、其它测试及 CI 均未修改。依据为本分支 `git diff --name-only 8b35c261` 和下述精确区域/树对象核对，不涉及主检出或真实团队配置。

## OpenSpec assessment

读取本项目已有的原生 `openspec-apply-change` skill、OpenSpec **1.16.0** 的 list/status/apply/context；root 为本席位工作树，schema=`spec-driven`，初始 state=`ready` / 0/4，context 无额外成员或规则。读取 apply 返回的 proposal/design/tasks/delta，实施依据为 PM 的 ACCEPTED 记录 `docs/team/reviews/help-route-render-once-proposal.md`。原生 apply 清单按实现与独立行为分工保留后两项，不把 planning 的 `isComplete=true` 当作实现或验证完成。

| Dimension | Score | Evidence |
|---|---|---|
| Completeness | 本单静态范围 1.1、1.2 完成；整变更 2/4 | 实现/输入核账与四条静态命令见下；2.1、2.2 未运行、未勾选 |
| Correctness | 仅静态成立，四场景行为未验 | 三个 `page` 直接重定向、立即取 rc、两个 `cmp -s`、同 shell 调用及原最终出口可见；没有运行受控样本证明这些行为 |
| Coherence | 与 design Decisions 1–3 的静态结构一致 | 文件在现有 `tmp` 内每命令重写；page/清理/其它组/其它 route 块/51 消费者未改；未新增开关、缓存、段或框架 |

## CRITICAL

静态范围内未发现。四场景的正常、坏输入和失败传递尚无本候选的行为证据，须完成 2.1、2.2 后才能对整个变更作结论；这不是本单已通过的检查。

## WARNING

静态范围内未发现设计偏离。下文保留首次只读消费者取段边界错误及旧日志的全轮失败，未将它们改记通过。

## SUGGESTION

None。

## Final assessment

- 判定：**实现及已授权静态范围完成；行为 NOT RUN**。不宣称实际提速、完整帮助检查通过、独立验收通过或可归档。
- 未执行：正常 route、短正常/错页/尾换行/同字节非零/全空非零样本、FIND 调用点破坏/恢复，以及合并后补验；归属原生 2.1、2.2。
- 按任务书不运行其它帮助组/locale 矩阵/routes/pages/完整 51、smoke 真实段、全量/FAST/meta/61b/夜间、真实模型、性能或安装；未编写行为驱动。

## Verification evidence

### 实际静态命令与输出

`bash -n` 在实现后执行一次，rc=0；只做解析，没有执行 `help-surface.sh`。随后在已提交且干净的 `9bee06a8` 上执行后台作业 `p465-static`，总 rc=0，已收割。该作业只运行下列三条静态命令，各自完整日志和 `.rc` 均保存在私有目录 `E=/var/tmp/p465-dev-static.hPAcKA/`，未提交原件。

```text
$ bash -n skills/teamsmith/tests/help-surface.sh
bash-n rc=0

$ PATH="$HOME/.bun/bin:$PATH" CI=1 OPENSPEC_TELEMETRY=0 openspec validate help-route-render-once --type change --strict
Change 'help-route-render-once' is valid
rc=0   # E/openspec-strict.log、E/openspec-strict.rc

$ bash skills/teamsmith/tests/spec-refs.sh --check
spec-refs: judged 122 reference(s) (49 distinct) in 14386 effective line(s); retired 0; undeclared 0; id families used [D,E,F,M,P,V] named [D,E,F,M,P,V]
rc=0   # E/spec-refs.log、E/spec-refs.rc

$ bash skills/teamsmith/tests/section-select.sh --paths skills/teamsmith/tests/help-surface.sh
decision=RUN
sections=141
keys=7
reason=0 ← prologue
reason=0b ← prologue
reason=0c ← prologue
reason=0d ← prologue
reason=12b-h0d ← skills/teamsmith/tests/help-surface.sh
reason=40 ← skills/teamsmith/tests/help-surface.sh
reason=51 ← skills/teamsmith/tests/help-surface.sh
rc=0   # E/section-plan.log、E/section-plan.rc
```

选择器只输出计划，**未执行**上述七键；`sections=141` 是现有清单总数，不是本轮执行段数。没有更改映射以缩减选集。完成 1.2 勾选后再次执行 `PATH="$HOME/.bun/bin:$PATH" CI=1 OPENSPEC_TELEMETRY=0 openspec instructions apply --change help-route-render-once --json`，rc=0，原件 `E/native-apply-2of4.json`：state=`ready`，complete=2 / remaining=2；task 1、2 为 true，task 3、4 为 false。

### 静态调用账与未改区域

执行只读内联 Python：从 `git show 8b35c261:skills/teamsmith/tests/help-surface.sh` 读取旧字节，与候选按 route 标记、正常单命令循环和其后 `# a page never falls back to the menu` 分界作精确比较；用当前 `commands.tsv` 的 `cmd` 行及唯一命令核算，用旧循环和新实际函数中 `page en` 调用点核账。没有 source/执行这些片段。

```text
IDENTICAL all-before-route (page/manifest-loader/other-groups): bytes=65046 sha256=bbc19279df1e22a6df31f853c1f4a73c5635543fa434af8a5e4972d332a9eca5
IDENTICAL route-before-command-loop: bytes=540 sha256=d63d27092fcfc005b6ff29d95f30cc7a518ba46a4c2be85ef8101cec50d45a4b
IDENTICAL all-after-command-loop (other-route/flip/result): bytes=15398 sha256=89e5085f4e67ddff5a095192fe57e8d4327328266d3864453118ef2d9dfb598b
STATIC CALL ACCOUNT: N=47 unique=47 old=188 new=141 retired=47; command comparison loop only
STATIC ASSERTION ACCOUNT: ok sites old=52 new=52 (not an executed assertion count)
STATIC SOURCE AUDIT rc=0; no shell code or controlled-input behavior executed
```

本文件只增加最小函数并替换循环内两条 diff，净 +21 行（27 增 / 6 删）；没有退休成功断言。原 `--help` 差异 finding 的文字前缀保留，末尾加 `（--help）` 点名入口；原 `-h` 差异 finding 不变。新增逐入口非零 finding 属于同一次判定的 rc 保真，不是另一套自检。

### 输入及 51 消费者同一性

下表各文件与任务起点 `8b35c261` 精确相同；前十项也与旧日志源提交 `572856a3` 相同。`section-paths.tsv` 相对旧日志源不相同，未据此声称整棵历史输入未变；相对本单起点则未改。本单全部产品/模板/指引/测试 helper 树对象也相同，分别为 scripts `b062034a15158e6902ac65db7bb10441b51f928f`、templates `ac0d561b5da1651ee8b660f51125b7a421989dfc`、references `2a271aa47d7cb1bafe3f7ffaecc3fdf11473ac12`、tests/lib `156a032e1df0497778680b99f15c86604cb9184f`。

| 相对 `skills/teamsmith/` 的输入 | 字节数 | SHA-256 |
|---|---:|---|
| `scripts/team` | 8828 | `c2b3aad899b6d46828df44f47ecad9cc421b38fa16e93cca4d543accee055414` |
| `scripts/lib/cmd-help.sh` | 28964 | `e42a4934f0d05a36b6ca43fccaa3ca763be1fe4a32d70b14757477f08598851f` |
| `scripts/strings/commands.tsv` | 12366 | `c3d2e55966e117b5cbda8ccebc9955e51445a93adf9d83defbbb715cb878bdd6` |
| `scripts/strings/help.en.tsv` | 45744 | `804331c4d307aa938b3071ee77cbd5b3e5beb15547f06843e2691c8e30900538` |
| `scripts/strings/help.zh.tsv` | 41081 | `f0c2ff81acb9718aef7f78b5bb3e4fb232970f4dfa9b869380d7295ee39d7f62` |
| `tests/routes.sh` | 108261 | `0d1000f46c1a2f6045142a75d477fd6a205a6f935a9dcb5ce7637c6a532df2da` |
| `tests/lib/routes-pages.sh` | 10824 | `3f411d05ed7d576cb6095127b8d12f147a48defe0a8bf2ecc3a1c4eabced941b` |
| `tests/lib/tmp-root.sh` | 31020 | `f544723a7bf0add50ab1d8022a98fc65fd6661448b0c80015fce07457cfcbf3c` |
| `tests/lib/model-policy.sh` | 2330 | `c1dbb1fd16ca2980025328bf8c39881f47597e35014a25803371e7ce830bae70` |
| `tests/lib/bounded-spin.sh` | 5030 | `999c9f38a302f1bb6a404981ec282df1632e1ac7689ad1037ffaacaabed42c3b` |
| `tests/section-paths.tsv` | 75440 | `35ebe0e8467f26528ac87a169621929e4655cb1c97c8fb6ea0e0addad7d54908` |

51 帮助消费者从 `# cli-help（P260）` 注释起到该帮助块未缩进的 `fi` 结束，包含真实调用、`HS_RC` 收取、成功/失败分支，共 **1322 字节**，SHA-256 `1cdcbf9a27ffb1c56b2abb7cf9aeb9cb28d6f1a04cc4b44f8f9cc33b98c497b5`；相对任务起点和旧日志源均精确相同。本轮没有执行该消费者。

首次只读审计误以 `51m` 标记为取段终点，旧提交因此多包含已经退休的 config 检查（旧 1442 字节 / 新 911 字节），Python 以 AssertionError / rc=1 停在旧源比较；外层 shell 随后继续打印状态、创建 E，整体 rc=0，未把它当作审计通过。查看实际差异确认多选的是旧 config 块后，仅更正读取边界到帮助块自身的 `fi`，得上述 1322 字节同一性，修正后的 Python rc=0。没有改测试或重跑行为来取得该结果。

### 可复用原件的身份与限制

本轮实际运行 `sha256sum /var/tmp/rel47-first-order.log`，结果 `9ca9986e014307573cf7577ad6572d6a2d5c59f4f6fccd81158ea7b2375d2545`；原件仍在该具体路径，5904 行，未复制到仓库。实际读取尾部绑定源提交 `572856a3ae57503396019020f58e8e6abcc08db4`、全轮 **5139 成功 / 2 失败、rc=1**。仅沿用其中 help 子脚本 132 条局部成功的既有证据，不把整轮失败、整个 51 的 681 秒或夜间记录说成本批通过/收益。

历史期间产品差异的消费适用性引用已接受 design Migration B 和 `docs/team/reports/V167-verify.md` §7：cmd-project 生成 AGENTS 技能路径、cmd-review 显示根左边界、cmd-watch 注释、common/SKILL 版本元数据各自的限定审阅。该引用不是“全部历史产品依赖未变”；本轮只直接确认上述输入、未改区域、当前树对象和 1322 字节消费者。其它组/不同语言 locale 宽度/coverage/claims/invariants/routes/pages 不在新候选上重跑，不能冒称本次又测过。

### 交给非作者的实际源码位置

以下均在 `skills/teamsmith/tests/help-surface.sh`，受检 blob `bfef2693fd29c5994a4c7b749897d41f1d70984a`，文件 SHA-256 `1fe9872775a4f63856d0019ab93432be6b97aa83fc101a8b0fc961235ce3e707`。

| 实际位置 | 用途 |
|---|---|
| 125–126 | 原 `ok` 与 `finding`，后者在当前 shell 累加 FIND |
| 267–271 | 原 `page`，不改环境/语言/timeout/shim |
| 1296–1320 | 实际共用函数 `check_route_command`；1299–1301 三次渲染与立即取 rc；1313、1316 两次成功对的原字节比较 |
| 1322 起；1333–1337 | 原 `check_route` 中的正常 MG_ORDER 循环、同 shell 实际调用及原全相同成功断言 |
| 1588、1601 | 原 manifest 装载与 route 选组调用 |
| 1604–1606 | 原结果打印及 `FIND=0` 才 exit 0，否则 exit 1 |
| `smoke.sh:23421–23437` | 原 HS_RC 消费与 bad 分支，原文同一性已核，不运行 smoke |

本报告不提供第二套比较函数或行为驱动。非作者按 design Decision 3 从候选原文加载实际函数/正常循环/finding/最终出口，统一执行 2.1；合并后按 2.2 的同一性和短补验收口。

### 暂存后账本扫描与两种 diff-check

报告和 1.2 勾选已暂存后执行后台作业 `p465-ledger`，rc=0，已收割；本节随后补入实际回执。扫描输出已由工具隐去用户名，下面保留其原样 root 以及真实计数；原件为 `E/ledger-ban.log` / `.rc`。两种 diff-check 的日志均为空、rc 均为 0，分别保存于 `E/diff-check.log` / `.rc` 和 `E/cached-diff-check.log` / `.rc`。

```text
$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: root=/home/<user>/Documents/syncthing/Work/Projects/pm-skills/.worktrees/dev scope=published files=2786 hits=0 names=ok user=resolved
$ echo $?
0
$ git diff --check
rc=0
$ git diff --cached --check
rc=0
```

未重跑已完成的结构、引用或选择计划检查；报告收尾是写入这些真实回执并检查最终差异。第一次最终暂存在 `git add` 阶段因本工作树 `index.lock` 存在而 rc=128，后续命令尚未执行；随后检查锁已自行消失，未手动删除锁或改动实现。受检 `help-surface.sh` 仍为实现提交的原 blob，没有在后台检查期间或收尾时改动。

## Flip evidence

**NOT RUN。** 本单明令只实现与静态，未运行正常 route、损坏/恢复短样本或 FIND 调用点变异。所需实际反例及恢复证据由非作者的 2.1 统一承担；本报告没有用 helper 返回值或静态数账替代最终退出码实测。

## Decisions and deviations

无范围偏离：仅原单命令比较和同文件最小函数，1.1/1.2 完成，2.1/2.2 不预勾；静态消费者取段错误及修正见上，不改设计或生产行为。未 merge/push/archive/tag/npm，未更改真实提醒或 standby。

## Suggested next steps

PM 准备独立固定检出并另派非作者执行 2.1；当前实现文件冻结，不追加作者行为预跑。正常 route 仅完整 manifest 一次；坏样本和一次失败接线只用候选实际代码的短驱动。通过后仍由同一非作者承担合并后 2.2，归档另行授权。
