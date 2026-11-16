# P461 · 配置检查去重与七个选段准备独立化

本轮实际删除 §51 第二个配置子进程及其成功/失败/缺文件分支，保留 §33 完整无参数入口；原样移动 91 行准备代码，删除七条仅为取得准备定义的 `needs:33`。实现和静态验收完成 **3/7**：仅勾选 1.1、1.2、2.1；1.3、2.2、3.1、3.2 未执行且留空。没有运行真实 smoke 段，也没有测量提速。

agent: dev   status: DELIVERED（P461 实现 + 静态范围；非独立行为验收）   time: 2026-11-16T09:54:02Z
branch: `task/P461-config-dedup-apply`   PR/MR: -（本地交付，不推送）

## Deliverables

| Path | What |
|---|---|
| `skills/teamsmith/tests/smoke.sh` | 删除 §51 配置重复块和对应说明；§33 父级原文、§51 routes/help 调用及其汇总/输入原文不变；完整路径/shim/十四函数准备移到首个 section 前 |
| `skills/teamsmith/tests/section-paths.tsv` | 33 增加 cmd-config 路径 token，51 删除 config-cli token；12e–12k 的七条 needs 改为 `-`，说明改为公共前导准备，其他行/needs 不动 |
| `openspec/changes/config-check-execution-dedup/tasks.md` | 仅 1.1、1.2、2.1 勾选；每次勾选后刷新原生 instructions，依次确认 1/7、2/7、3/7 |
| `docs/team/reports/P461-dev.md` | 本报告及实际命令、退出码、字节比较和未执行边界 |

提交：`578c3a79`（删除调用及两 token）、`dbd52fd2`（移动准备及七条边）、`910fdf08`（静态结果对应的两项勾选）。静态批次固定在 `dbd52fd226be77885ef0357e6a37d962e549c41c` 上，起止 HEAD 相同；`git diff --exit-code dbd52fd2 -- skills/teamsmith/tests/smoke.sh skills/teamsmith/tests/section-paths.tsv` 为 0，之后没有改变受测两文件。

相对派单起点 `58725e7c`，本报告加入前只改上述两编排文件和 tasks 复选框；相对接受基线 `9e3833bb` 多出的 BOARD/OWNERSHIP/brief 是 PM 起点提交的内容，不是本席位写入。产品代码、三个子脚本、循环清单、正式 spec、proposal/design/delta、CI 和实际团队配置没有改动。

## OpenSpec assessment

本表仅为 apply 作者的实现/静态自查，不代替 opsx-verify。

| Dimension | Score | Evidence |
|---|---|---|
| Completeness | 本轮 3/3，整体 3/7 | 原生 apply 清单仅 1.1/1.2/2.1=true；四项实际行为/独立/合并后验证保持 false |
| Correctness | 静态通过，真实行为未执行 | 严格 change 校验 rc=0；选择器 13/0/SKIP1；141 个副本静态自足；七键计划各只带四个前导及自身 |
| Coherence | 与已接受设计一致 | Git 原 blob 比较证明准备块/消费者/33 父级/51 保留部分不变，整份 smoke 仅指定删除/说明/移动；表恰改两 token 和七条边/依据 |

## CRITICAL

None — 在本轮明授的实现和静态范围内没有发现需越写集的缺口；真实行为仍按下文保留待验，不据此判断整个 change 完成。

## WARNING

None — 本轮未变更接受方案或追加跳过/拒绝条件；唯一实际 SKIP 是原检查器因本工作树没有机器生成的 `.pi/skills` 而披露的缺前提。

## SUGGESTION

None。

## Final assessment

- Counts: CRITICAL 0 · WARNING 0 · SUGGESTION 0（仅本轮实现/静态自查）。
- Readiness: 可交 PM 准备冻结检出并安排非作者验证；不可称整体完成、真实行为已验、完整套件通过或已经达到某项时间收益。
- Unverified applicable checks and reasons: 1.3（正常33及指定负例/原局部日志复用）、2.2（七次真实独立运行及缺 brief 定义负例）、3.1（非作者全部场景审查）、3.2（候选/合并版本独立证据）全部按 D246/P461 留给后续流程。

## Verification evidence

所有命令从自己的 `<repo>/.worktrees/dev` 发起；报告中的个人绝对目录统一替换为 `<home>` / `<repo>`，命令、返回码和其他输出保持原样。环境为：

```sh
export PATH="$HOME/.bun/bin:$PATH" TMPDIR=/var/tmp CI=1 OPENSPEC_TELEMETRY=0
```

### 工具、根与原生进度

```text
$ command -v openspec
<home>/.bun/bin/openspec
$ openspec --version
1.16.0
$ openspec list --json
root.path=<repo>/.worktrees/dev
root.source=nearest
config-check-execution-dedup: completedTasks=0 totalTasks=7（实现前）
$ openspec status --change config-check-execution-dedup --json
schemaName=spec-driven; actionContext.mode=repo-local
changeRoot=<本工作树>/openspec/changes/config-check-execution-dedup
$ openspec instructions apply --change config-check-execution-dedup --json
实现前 state=ready total=7 complete=0 remaining=7
1.1 勾选后 total=7 complete=1 remaining=6
1.2 勾选后 total=7 complete=2 remaining=5
2.1 勾选后 state=ready total=7 complete=3 remaining=4
sourcePath=<本工作树>/openspec/changes/config-check-execution-dedup/tasks.md
line 7: 1.1 true; line 8: 1.2 true; line 13: 2.1 true
line 9: 1.3 false; line 14: 2.2 false; line 18: 3.1 false; line 19: 3.2 false
```

上述原生命令均 rc=0。本工作树无 `.pi/skills`；只读使用 PM 主检出的现有 apply skill，未安装/升级、未初始化另一个 root、未把 planning artifacts 的 `isComplete` 当作实施完成。

### 静态批次

后台作业 `p461-static` 已收取，rc=0，40.5s；入口与逐条原件保留在 `/var/tmp/p461-static.RHl0wX/`（`run.sh`、`results.tsv`、各具名 `.log`、一次性 `compare.py`），共享工具日志为 `.pi/team/state/bg/p461-static.log`。背景日志头因工具容量限制不完整，逐条原件不受影响；以下使用逐条原件。

```text
$ openspec validate config-check-execution-dedup --type change --strict
Change 'config-check-execution-dedup' is valid
rc=0
$ bash -n skills/teamsmith/tests/smoke.sh
rc=0
$ bash skills/teamsmith/tests/section-select.sh --check
ok: needs 声明全部存在且指向更早的段（105 条）
SKIP（条件不满足）: 行 19 的字面模式在检出里不存在（检出形状 internal，机器生成面（工具在本机生成、不进仓库））：.pi/skills
ok: 段正文点名的真实路径 token 都被各自的行覆盖（585 个 token 检查过；0 个豁免类 token 不参与）
== 选段自检 ==  ok 13  bad 0  SKIP 1
rc=0
$ bash skills/teamsmith/tests/section-select.sh --self-sufficient
== 段副本自足 == ok 141 bad 0（141 个键；段体函数 433 个，assert_* 未定义 0 个，整份套件的命令词 831 个）
rc=0
$ bash skills/teamsmith/tests/section-guard.sh --loop-check
ok: 扫描 86 行清单 / 86 个 while+sleep 循环，配平 86 个
section-guard --loop-check: 全过
rc=0
$ bash skills/teamsmith/tests/spec-refs.sh --check
spec-refs: judged 122 reference(s) (49 distinct) in 14360 effective line(s); retired 0; undeclared 0; id families used [D,E,F,M,P,V] named [D,E,F,M,P,V]
rc=0
```

七个键各执行一次下列选择计划，**不是 smoke 执行**：

```sh
for key in 12e 12f 12g 12h 12i 12j 12k; do
  bash skills/teamsmith/tests/section-select.sh --select "$key" || exit
done
```

七次各 rc=0，均 `decision=RUN sections=141 keys=5`；各自输出恰为 `0/0b/0c/0d/<该键>`，没有33。原件为 `select-12e.log` 至 `select-12k.log`。

```sh
for path in skills/teamsmith/tests/config-cli.sh skills/teamsmith/scripts/lib/cmd-config.sh skills/teamsmith/tests/task-header-model.sh ci/config-dedup-unclaimed; do
  bash skills/teamsmith/tests/section-select.sh --paths "$path" || exit
done
```

| Path | 本轮实际计划，均 rc=0 |
|---|---|
| config-cli.sh | RUN/7 keys：0 0b 0c 0d 12b-h0d 33 40；不含51 |
| cmd-config.sh | RUN/22 keys：含33、51及原有归属/依赖 |
| task-header-model.sh | RUN/7 keys：0 0b 0c 0d 12b-h0d 12e 40；不含33 |
| ci/config-dedup-unclaimed | FULL；没有任何行声明，也不在豁免类 |

### Git 原 blob 核对

```text
$ python3 /var/tmp/p461-static.RHl0wX/compare.py
config-cli.sh: equal bytes=99890 sha256=a4a018b5c4a883e6929b95634dbcc32adf7cf489a40a5ebdcf1568c11a91a88c
routes.sh: equal bytes=108261 sha256=0d1000f46c1a2f6045142a75d477fd6a205a6f935a9dcb5ce7637c6a532df2da
help-surface.sh: equal bytes=81545 sha256=2ea27c25d7aabf25b95e103d966e4f8b49e6ca265b79da29999d28ff7c964b98
33 parent, no-argument call/nonzero/missing branch: equal bytes=691 sha256=21cbe69b12856439cb6bd63ac30c388d7a15816798d5f5e42c5712817a10bfde
51 retained routes/help argv/order/inputs/summaries/FAST: equal bytes=2092 sha256=fa72271c0651df0c109d9532a4c1f86c9ce60d9cb808ee9f8223d3ece59f4690
12e-12k consumer bodies and live prerequisites: equal bytes=59603 sha256=9e42060ba1cf6c709815dad94e2215848719158f58a56705ec69d6e216050261
complete path/shim/preparation block: equal bytes=5296 sha256=858f3984d05a25eb91f4c6460ae384494d0a20adf3d51d2bbcdd41487d71e193
preparation: 91 lines / 14 functions / precedes first section; bytes unchanged
entire smoke after only approved deletion/comment/move: equal bytes=1907359 sha256=1572178e9c4894112e2b18a60b570ab3b4baf5a157d80e04c1a2213360cb8b4f
source count: top-level config child 2 -> 1; list/validate/roster top-level groups each 2 -> 1; not measured execution
table: exactly 2 path tokens + 7 needs/basis changed; all other rows/needs/headers identical
loop inventory: equal bytes=9465 sha256=30b9981cd74109e493086e23fc23644ba2cfcd869e11a7eed1b2a645831054f7
Git original-blob comparison: PASS; baseline=9e3833bb
rc=0
```

比较脚本通过 `git show 9e3833bb:<path>` 取原 blob，以完整区域 byte equality 比较；再将旧 smoke 只应用已批准的块删除、两行说明替换、完整准备块移动，断言与整个新文件完全相等。表按行精确比较，恰九行变化，只有两 token 和七个 needs/依据。脚本只在本次临时目录，不加入永久检查器。准备现位于 `smoke.sh:1823–1913`，首段位于1920，33父调用位于17475后，51保留调用位于23400后。

初次一次性比较命令有 Python 非 ASCII bytes literal 语法错误，没有得到比较结果；修正比较脚本写法后重新执行，以上列出的独立批次原件 rc=0，仓库源码没有因此改动。

### 报告暂存后的检查

首轮暂存后 ledger-ban 检出报告中三处个人绝对目录，`files=2760 hits=3 names=ok user=resolved`，rc=1；已将这三处改为上述占位符，未放宽扫描。改正后在自己的分支重新暂存报告并重跑，结果如下（root 的个人目录按上文替换）：

```text
$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: root=<repo>/.worktrees/dev scope=published files=2760 hits=0 names=ok user=resolved
$ echo $?
0
$ git diff --check
rc=0（无输出）
$ git diff --cached --check
rc=0（无输出）
```

原件：`/var/tmp/p461-static.RHl0wX/ledger-ban.log`（首轮红）、`ledger-ban-final.log`（修正文档后绿）。

## Flip evidence

NOT RUN — 本单按 D246/P461 只实现和静态验收。真实33、roster假成功坏腿、config child短setup失败、缺p24_brief坏腿、validate/writer原红/恢复日志的核对都由后续非作者执行；没有把源码次数比较冒称故障翻转证据。

## Decisions and deviations

- 无实施范围偏离；没有新增助手平台、缓存、配置项、跳过规则、防护分支或测试段。
- 静态删除账：顶层 config 子进程2→1，list/validate/roster顶层组各2→1，七条准备依赖7→0。这些是源码/计划计数，不是实际完整运行的时长；完整运行原本只执行一个33，不能把七个局部选择减少的33相加成全量收益。
- 原51日志未在本轮读取或复用为通过证据；本轮只核接受基线到实现的脚本/父调用/输入原文同一性，原局部日志绑定和期间产品差异审查仍属1.3/3.1。
- 未运行 smoke 任何真实段、完整config/help/routes、坏样本、全量/FAST/meta/61b/夜间、安装或真实模型；唯一具名静态 SKIP 已在上文披露。
- 临时目录仅本次 `/var/tmp/p461-static.RHl0wX`，为后续复核保留原件；没有清理其他席位目录、项目级通配或主检出内容。

## Suggested next steps

PM 准备独立冻结检出，交未参与实现的席位按已接受 design 的最小表完成1.3/2.2/3.1：一次正常33保留child/嵌套原件、七键分别新TMP运行、指定必要坏腿、原51来源/消费源码差异核对。随后仍由独立验证者核合并版本，3.2完成前不关闭整体change。本分支只留本地，不merge/push/tag/archive。
