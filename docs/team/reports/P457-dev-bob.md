# P457 · 三处重复执行已删除，最终61b通过

agent: dev-bob · status: DELIVERED（实现及验收完成，待独立验证） · time: 2026-11-16
branch: `task/P457-routing-argv-slimming-apply` · PR/MR: -
change: `routing-argv-check-slimming`

## 结论与下一步

两个短入口和父级接线已完成；原变异在各自副本上均取得 **0→1→0**，七种故意损坏子结果的样本都使原父级检查失败并退出 1。末尾第二次原树 CORE 已实际删除，正常 16 组、首个 CORE 和其他 29 臂的分组不变。源码同一性检查与原始输出见下文。

**最终一次完整61b通过：进程rc=0，父级206/0，smoke所选5段25/0；首个正常CORE为3140/0，31臂全部按名失败并完成原脚本恢复，两条改造臂各有0→1→0。** 61b实跑4365s，命令及收尾4377s；这是新用时，不是同场前后净提速。详情与原日志见§5。任务3.1已完成，只有非实现者/合并后3.3保留未勾；本变更不进入0.4.7冻结发布对象。

## Deliverables

| Path | What |
|---|---|
| `skills/teamsmith/tests/task-model-routing.sh` | 重准备之前分流 argv-worker/argv-pm；两条臂各加同副本健康/恢复检查；删除第二 CORE |
| `skills/teamsmith/tests/lib/model-routing-expansion.sh` | 使用真实产品 renderer、PM publisher/loader/guard 和 Bash/NUL 的短检查；原 expansion 函数不变 |
| `skills/teamsmith/tests/section-paths.tsv` | 仅 61b 行登记已有 expansion helper；61 行逐字节未变 |
| `openspec/changes/routing-argv-check-slimming/tasks.md` | 本席位7项完成；独立及合并后验证3.3未勾 |
| 本报告 | 短样本、父级失败传递、静态检查及最终一次完整61b证据 |

提交：`864b88db`（两个短入口）、`2209a4db`（父级替换/删除）。最终可执行字节固定于 `2209a4dbd17aa822f8c2c37026a1198aa0c2d214`：

```text
53b61dbbdd75c384ca6bc1e8e79e9b6c82350b7e5fee02efcb242dd6b38081fb  tests/task-model-routing.sh
18b451753fbb8f97ce5682c5c0b1d9abe8ce75d4e0d7d69e10efb6d04a4352ba  tests/lib/model-routing-expansion.sh
8ef67b83cf3bf07b38cf3e527c9062a4be52d7bf473b03f6739d0599f95323f5  tests/section-paths.tsv
```

上表 `tests/` 相对 `skills/teamsmith/`。后续报告/checklist 提交不改变这些执行文件，不因此重新跑矩阵。

## 1 · 三处删除、四条新增父级检查及保留范围

| 原执行/断言 | 本次处置 | 替代及计数 |
|---|---|---|
| worker-literal-resplit → boundary | 改为 argv-worker；坏树上无关模板/角色/拒绝/PM事务观察不再执行 | 保留原 worker-expansion-literal-argv:extra 名字；父级保留 rc=1/具名红/匹配/形状/字节恢复 |
| pm-literal-resplit → boundary | 改为 argv-pm，extra 与显式 resume 都执行完才返回 | 保留 pm-expansion-literal-argv:extra、pm-resume-literal-argv:builtin；父级条件同上 |
| `flip_run restored "$TREE" "$CORE"` 及 flip-restored-all-green | 真删，不留 slow 或备用入口 | 退休父级成功检查 1 条；舍弃第二次原树重复性取样，不说成逐臂行为恢复 |
| 两臂自己的健康/恢复行为 | 各在变异前/恢复脚本后调用同一个短入口、同一 scratch | 新增 flip-{pm,worker}-literal-resplit-{healthy,restored} 共 4 条父级 check |

源码计数变化为 **−1＋4＝净增 3 条父级检查**；本次完整执行实际父级读数为206/0，旧记录203仅用于解释这三个检查的变化，不作新总数的推定依据。子组的数百条结果从来不计入父级，不拿它们扣 smoke 的单个成功检查，不补成功行去凑旧203。一次完整 flip 的实际 child 调用由原 33 次变为 36 次：一个完整 baseline、31 条坏侧、四个新增健康/恢复短调用；其中两条坏侧不再跑 boundary，末尾原树整组不再跑。

保留 CORE 原样：`policy,machine,init,config,upgrade,dispatch,resume,transaction,limits,preview,sid-readers,pm,heal,adopt,updatecheck,boundary`。源码检查从正常 fixture 的 `git init` 到 `if has flip` 与基准 `6f469a3b` 逐字节相同，包含原真实 worker/PM literal argv 启动与 PM 显式 continuation 检查。正常 expansion 函数后缀、61行也逐字节相同；正常CORE本轮执行结果另由§5实际baseline rc=0及3140/0证明。独立的正常§61入口本轮未运行，不把嵌套CORE当成另外跑过§61。

其余 **29 臂**的实际列表/分组保持：

| 臂 | groups |
|---|---|
| unmapped-override | dispatch |
| required-categories | policy,config,upgrade,dispatch |
| fingerprint / expanding-quote | config |
| recovery-drift | resume |
| partial-publication | transaction |
| unknown-as-zero | limits |
| latest-shell / latest-monitor / monitor-record-drift | sid-readers |
| pm-fallback | pm |
| pm-publication | dispatch,pm |
| extra-shadow / template-shadow / template-unbound / template-roles / literal-shell-expansion | boundary |
| identity-overclaim | dispatch,limits |
| init-legacy-proceeds / template-retired-key / legacy-route-placeholder | init |
| migration-row-removed / no-backup / no-shape-number | heal |
| missing-record-refused / adopt-ignores-yes | adopt |
| updatecheck-equal-prints / updatecheck-ignores-off / updatecheck-print-writes-cache | updatecheck |

逐臂脚本复制/哈希恢复机制未改；不借本次宣称其他臂都做了恢复后的行为复验，也不把它说成模板目录字节恢复。`/var/tmp/p457-source-inventory.log` 保留 31 行前后分组、同一性及计数检查，命令为报告实现阶段的内联 Python，通过 `git show 6f469a3b:<path>` 对比当前源码；rc=0。

## 2 · 短样本：实际 Bash argv 与原变异

执行：

```text
$ bash -n skills/teamsmith/tests/task-model-routing.sh skills/teamsmith/tests/lib/model-routing-expansion.sh
rc=0
$ TMPDIR=/var/tmp bash skills/teamsmith/tests/task-model-routing.sh --select argv-worker,argv-pm
PASS worker-expansion-literal-argv:extra
PASS pm-expansion-literal-argv:extra
PASS pm-resume-literal-argv:builtin
PASS pm-argv-metadata-unchanged
RESULT pass=10 fail=0 selected=argv-worker,argv-pm
rc=0
$ python3 /var/tmp/p457-short-samples.py > /var/tmp/p457-short-samples.log 2>&1
sample_rc=0
```

实际完整命令脚本留在 `/var/tmp/p457-short-samples.py`。它分别复制产品 scripts 到本次独有副本，打 `.routing-mutant` 标记，调用 suite 的 argv-worker/argv-pm（`bash -x`），再调用**未修改的** `tests/lib/model-routing-flips.py <copy> <seat>-literal-resplit`，恢复同一副本原始 scripts 字节后再次执行。两个副本在 finally 中精确删除，不按项目名通配清理。

| seat/phase | child rc | 具名失败 |
|---|---:|---|
| worker healthy | 0 | 无 |
| worker 原变异 | 1 | worker-expansion-literal-argv:extra |
| worker same-copy restored | 0 | 无 |
| PM healthy | 0 | 无 |
| PM 原变异 | 1 | pm-expansion-literal-argv:extra；pm-resume-literal-argv:builtin |
| PM same-copy restored | 0 | 无 |

原始日志：`/var/tmp/p457-short-{worker,pm}-{healthy,mutated,restored}.log`；汇总 `/var/tmp/p457-short-samples.log`。实际 mutator matched：worker `[1]`，PM `[1,1]`；两臂 script 字节字典恢复相等，`owned_sample_cleaned=True`。

固定期望独立写在 Python 中：provider=`vendor`，worker model=`deep/model:high`，PM model=`pm:high`，literal 尾部为 `--label`, `two words`, `--mod*`, `{safe,words}`, `~/routing-note`, `one\two`（一个反斜杠）；显式续跑尾部为 `--session-id`, `fixture-literal-session`。产品 `%q` 输出交给 `bash --noprofile --norc -c "printf '%s\\0' ..."`，Python 读 NUL 后的实际参数，不读产品 token 数组作为答案。私有 cwd 的 `--model=wrong:low` 没进入正常参数。

PM 先在私有 config/state 用真实 publisher 写合法 continued 记录、用真实 loader 加载，extra 走 fresh，resume 明确 `FRESH=0`、`SESSION_ID=''` 和带引号 `TEAM_PM_RESUME_ARGS`。guard 不替换；正常/变异的 renderer 和 shell rc 均为 0，失败属于实际 argv 判断，且 PM extra 失败后仍执行 resume。每次 PM 观察前后 metadata SHA 相同。renderer/setup 非零只产生自己的前置失败，不产生这三个目标失败名。

六条 xtrace 中没有执行 git、tmux、dispatch、sleep 或 stop_fixture_seat；短路径在 git init/长活 recording-pi/正常组准备之前结束。初次合并短入口输出在 `/var/tmp/p457-short-debug.log`；没有运行真实模型或真实团队 PM。

## 3 · 一次性父级接线反例

```text
$ python3 /var/tmp/p457-parent-samples.py > /var/tmp/p457-parent-samples.log 2>&1
parent_samples_rc=0
parent_samples=PASS bounded_two_arms_only=yes unchanged_flip_run_check_exit=yes
owned_parent_cleaned=True
```

后台作业 `p457-parent-samples-r2`，实跑 50.1s、exit=0。该脚本复制当前 skill 到唯一临时树，只将临时 suite 的 CORE 改为 `argv-worker,argv-pm`，mutation 列表改为 `pm-literal-resplit worker-literal-resplit`；逐字节断言 `flip_run`、`check` 和最终 RESULT/出口不变。没有新增提交的过滤入口、runner 或验测试层；这不是完整 31 臂矩阵。

每例运行原父级 `bash <temporary-suite> --flip`，原始日志为 `/var/tmp/p457-parent-<case>.log`：

| case | 临时改坏的内容 | 原父级 FAIL | parent rc / 最终 RESULT |
|---|---|---|---|
| normal | 无 | 无 | 0 / pass=20 fail=0 |
| unexpected-worker-rc | 仅 worker 坏侧短入口在已有检查后退出 2 | flip-worker-literal-resplit-red | 1 / pass=19 fail=1 |
| missing-worker-name | helper 的 worker 目标检查临时改名，保留坏侧 rc=1 | flip-worker-resplit-specific-extra | 1 / pass=19 fail=1 |
| missing-pm-resume-name | helper 的 resume 目标检查临时改名，保留 extra 和坏侧 rc=1 | flip-pm-resplit-specific-resume | 1 / pass=19 fail=1 |
| worker-healthy-fails | 只在 EVIDENCE 标识的 worker healthy 调用把 label 输入改成 wrong | flip-worker-literal-resplit-healthy | 1 / pass=19 fail=1 |
| worker-restored-fails | 同上，仅 restored 调用 | flip-worker-literal-resplit-restored | 1 / pass=19 fail=1 |
| pm-healthy-fails | 只在 PM healthy/extra 调用把 label 输入改成 wrong | flip-pm-literal-resplit-healthy | 1 / pass=19 fail=1 |
| pm-restored-fails | 同上，仅 restored/extra 调用 | flip-pm-literal-resplit-restored | 1 / pass=19 fail=1 |
| normal-restored | 恢复全部临时改动 | 无 | 0 / pass=20 fail=0 |

两条正常父级样本里，实际 CONTROL 都是各臂 healthy rc=0→原变异 rc=1→restored rc=0，source_before/source_restored 相同；其间 PM 原 child `pass=5 fail=2`、worker `pass=2 fail=1`，恢复分别为 7/0、3/0。这些子数不加到父级的 20。

首轮脚本自身断言失败（作业 `p457-parent-samples` exit=1）：解析器把父级 `tail -4` 带出的预期 child FAIL 当成父级失败；原父级实际 RESULT 已是 20/0。仅修正一次性脚本收集范围为 `^FAIL flip-` 后才得到上表；产品/候选未因此改动。保留现场输出 `/var/tmp/p457-parent-{samples,normal}-parser1.log`，不隐去该失败，也不把它解释为候选修复。

## 4 · Verification evidence

OpenSpec 最初不在 PATH（命令 exit=127）；后续显式用已安装的 Bun/CLI，没有安装依赖或改配置：

```text
$ "$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" status --change routing-argv-check-slimming --json
root.source=nearest; root.path=<本 worktree>; planning complete; apply ready
$ "$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" instructions apply --change routing-argv-check-slimming --json
progress total=8 complete=0 remaining=8（实施前）
$ "$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate routing-argv-check-slimming --type change --strict
Change 'routing-argv-check-slimming' is valid
openspec_rc=0
$ bash skills/teamsmith/tests/spec-refs.sh --check
spec-refs: judged 122 reference(s) (49 distinct) in 14321 effective line(s); retired 0; undeclared 0
spec_refs_rc=0
$ bash skills/teamsmith/tests/section-select.sh --check
== 选段自检 ==  ok 13  bad 0  SKIP 1
section_select_rc=0
$ bash skills/teamsmith/tests/section-guard.sh --loop-check
ok: 扫描 86 行清单 / 86 个 while+sleep 循环，配平 86 个
section-guard --loop-check: 全过
loop_check_rc=0
$ git diff --check
rc=0
```

阶段静态日志 `/var/tmp/p457-static.log`；最终61b结束、报告暂存后，同样的当前change严格校验/spec-refs/section-select/loop-check再次执行，结果相同，全部rc=0，最终日志 `/var/tmp/p457-static-final.log`；该日志还记录diff及冻结执行文件同一性rc=0。没有因此重跑短样本或矩阵。section-select 的一个 SKIP 是本 worktree 不存在机器生成的 `.pi/skills`，命名输出明确这是未检查，不是通过。未改循环清单、未增 while+sleep 循环。

### Ledger ban

本分支最终报告已暂存后实跑，日志 `/var/tmp/p457-static-final.log`；阶段原始记录另保留在 `/var/tmp/p457-ledger-stage.log`：

```text
$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: root=<本 worktree> scope=published files=2794 hits=0 names=ok user=resolved
$ echo $?
0
```

`git diff --check && git diff --cached --check` 同在本 worktree 执行，rc=0。报告不包含原始跟踪 .log；证据留在上列本机路径。

## 5 · 最终一次完整61b：实际运行与范围

PM于02:02:08Z释放共用门禁；没有重复此前短样本，没有启动full smoke、meta-suite或其他矩阵。正式长作业为`p457-final61b`：

```text
$ TEAM_META=1 TEAM_SMOKE_FAST=0 bash skills/teamsmith/tests/smoke.sh --select 61b --keep </dev/null
source_revision=3723c7337623f3a7b80822bfd219cffbcfb6d4c9
executable_revision=2209a4dbd17aa822f8c2c37026a1198aa0c2d214
started=2026-11-16T02:04:12Z
finished=2026-11-16T03:17:09Z
rc=0
elapsed_seconds=4377
head_after=3723c7337623f3a7b80822bfd219cffbcfb6d4c9
CONTROL baseline rc=0 elapsed=639s budget=1800s
RESULT pass=3140 fail=0 selected=policy,machine,init,config,upgrade,dispatch,resume,transaction,limits,preview,sid-readers,pm,heal,adopt,updatecheck,boundary
RESULT pass=206 fail=0 selected=flip
61b 路由翻转变异：31 条臂按名变红并还原（RESULT pass=206 fail=0 selected=flip）
#5 61b · 参考 用时 4365s · ✓1 ✗0 SKIP0 · ticks 74
账本自查：5段收口 · 增量 ✓25 ✗0 SKIP0 ｜ 结果行 ✓25 ✗0 —— 一致
== 选段结果 == ✓25 ✗0
```

该命令显式`TMPDIR=/var/tmp`，实际在本worktree/分支运行。receipt保存开始/结束时三个文件SHA，逐字节与上列冻结值相同，HEAD未变；最终报告与checklist提交不触发第二轮矩阵。`p457-final61b-precheck`只是一次没有启动测试的预检查作业，不计为61b执行，也不拿它的退出码当验收证据。

### 计数与时间

实际父级记录有36个带rc的CONTROL：baseline一次、原31条坏侧、四次新增短健康/恢复；31条source_before/source_restored全部相等；没有末尾`restored`原树CORE或flip-restored-all-green。父级原matched/shape/red/具名/source-restored及两臂三个specific检查均PASS。`/var/tmp/p457-final61b-analysis.txt`通过只读Python解析核对这些条件，rc=0；没有重跑测试。

| 本轮执行 | 实际结果 | CONTROL秒数 |
|---|---|---:|
| 正常完整CORE（16组，原真实worker/PM启动与续跑代码未变） | rc=0；3140/0 | 639 |
| PM healthy→原变异→restored | rc=0→1→0；7/0→5/2→7/0 | 1 / 0 / 0 |
| worker healthy→原变异→restored | rc=0→1→0；3/0→2/1→3/0 | 0 / 0 / 0 |
| extra-shadow | 原具名失败、rc=1 | 490 |
| template-shadow | 原具名失败、rc=1 | 857 |
| template-unbound | 原具名失败、rc=1 | 723 |
| template-roles | 原具名失败、rc=1 | 666 |
| literal-shell-expansion | 原具名失败、rc=1 | 529 |
| 其他24条原臂 | 全部rc=1，原分组/恢复检查保留 | 合计409 |

36个CONTROL秒数合计4314，61b段计时4365，两者相差51秒未进一步拆分。秒级读数0表示该调用落在同一秒内，不代表没有执行。不把本轮4365与历史5652/5686或1419相减称为同环境净收益；不声称正常一阶已变快。

本轮两臂的同副本脚本哈希：

```text
pm source_before=8c1fbf200c360624949ad2434525dbaa88bbe41a23cceb4dec8550a10c70279a
pm source_restored=8c1fbf200c360624949ad2434525dbaa88bbe41a23cceb4dec8550a10c70279a
worker source_before=1306aa6b5c27b2a8fdaab39d9516130baf6da46cac00873363985a781e167b97
worker source_restored=1306aa6b5c27b2a8fdaab39d9516130baf6da46cac00873363985a781e167b97
PASS flip-pm-resplit-specific-extra
PASS flip-pm-resplit-specific-resume
PASS flip-worker-resplit-specific-extra
PASS flip-pm-literal-resplit-healthy
PASS flip-pm-literal-resplit-restored
PASS flip-worker-literal-resplit-healthy
PASS flip-worker-literal-resplit-restored
```

### 原始证据及可回读边界

- 命令完整原日志：`/var/tmp/p457-final61b.log`，SHA256 `a3003d80b0d8b470d2f3bdabd516f2a044a68a4d1be1fda9376d9c112c6daaff`。
- 起止revision/文件SHA/rc receipt：`/var/tmp/p457-final61b-receipt.txt`，SHA256 `1ca8116d0202a2952647a4c8cc83ac78c6d206c5c46ce3da769ad564c997dce0`。
- 原父级完整transcript：`/var/tmp/teamsmith-smoke-pm_skills-deb708fe.izNUie/p238-routing-flip.log`，SHA256 `1b0b2d8d9e83d705a149a66bf85d8a4b0964b4ff568d9e69ae375c99340c023e`；同目录有`sections.tsv`、`sections.log`、`run-fingerprint.txt`。该小目录保留给独立验证。
- **嵌套child原目录已由suite原有cleanup移除**：`/var/tmp/teamsmith-task-model-routing-pm_skills-deb708fe.KEvCAe`不存在。父级transcript仍保留每个CONTROL/child RESULT、目标检查的PASS以及同副本哈希；但不能再回读baseline逐项日志、该轮PM完整NUL/metadata或mutation JSON。本报告不声称这些文件仍在，也不把§2保留的短样本日志冒充本轮child原件。这是现有保存行为的边界，不为补这个目录自动再跑矩阵，不扩展本任务写集。

本次只选中`0 0b 0c 0d 61b`五段；**未运行其余136段**，包括独立§61、其他所有一阶/二阶段及完整套件。完整键清单在`/var/tmp/p457-final61b.log`末尾；3140是61b内嵌正常CORE的结果，不是另一次正常§61运行。

## 6 · OpenSpec assessment（实施者自查，不代替独立验证）

| Dimension | Score / 状态 | Evidence |
|---|---|---|
| Completeness | 本席位7/7项完成；总清单7/8 | 1.1–3.2完成；3.3留给非实现者，未提前勾 |
| Correctness | 本次范围内PASS | 三个原失败名、两臂0→1→0、七条父级反例及最终31臂206/0；§2/3/5 |
| Coherence | 与接受方案一致 | 只替换两臂、真删第二CORE；源码同一性、唯一61b行登记、静态检查和实际计数相符 |

### CRITICAL

- None：本次实现检查及唯一完整61b未报告失败；独立验证仍待进行，不把本席位结果当独立结论。

### WARNING

- None：未观察到实现/spec偏离；嵌套原日志的保存边界已在§5明确，不声称拥有已清掉的原件。

### SUGGESTION

- None：不增加本任务范围外的保存机制、守卫或备用执行入口。

### Final assessment

- Counts：CRITICAL 0 · WARNING 0 · SUGGESTION 0（实现者自查）。
- Readiness：可移交非实现者独立验证；不是合并、归档或发布批准。
- 未运行的适用后续检查：3.3独立及合并后验证，因不允许实现者验自己；未跑136个非选中段、全量/FAST smoke、validate --all或发布检查，因为任务只要求当前change严格结构检查及所选61b。正常CORE本轮实际执行一次；不声明全套、正常一阶提速或净耗时收益。

## Decisions and deviations

- PM于01:36:26Z要求暂缓长跑，阶段报告先提交3723c733；02:02:08Z释放后仅启动一次完整61b，完成后收割，不sleep/轮询、不因报告补交重跑。
- 只在本worktree/本任务分支编辑明授文件；未写产品、其他delta/主规格、smoke.sh、变异器、config、版本、主检出或PM的BOARD/验证记录。
- 所有验证均为本地；实现及报告留任务分支，不push、merge、tag、npm或关闭任务，不进入0.4.7冻结发布对象。

## Suggested next steps

1. PM把固定候选与上述原父级日志交给非实现者；按3.3只补适用的短入口及有区分力的接线反例，不因纯报告提交默认重跑长矩阵。
2. 独立验证者判断§5保存边界是否足够支撑本次场景；若具体差异或缺证据确实使长矩阵结果不能复用，先明确缺口，再由PM决定补验，不把不存在的日志当成可读证据。
3. 合并后同一验证者核对可执行文件同一性/索引与关键调用点；有行为差异按差异补验。3.3和关闭/合并仍由对应owner完成。
