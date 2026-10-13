# P238 · 路由前门进闸门 + 组自足 + 选段归属（三个坑一起）

agent: dev-bob   status: DONE（六条验收命令全跑；§61/§61b 两档绿，三处红侧齐）   time: 2026-10-13
branch: `task/P238-routing-suite-gate`   PR/MR: -（local 模式，不推送）

## Deliverables

| Path | What |
|---|---|
| `skills/teamsmith/tests/task-model-routing.sh` | 坑 1：新增 `routing_group_setup`，按**选中的组**逐组准备自己的前置（夹具 state 目录），准备失败时 `FAIL group-setup:<组>` 点名，而不是让下游断言各红一遍（`4676fa2`） |
| `skills/teamsmith/tests/section-paths.tsv` | 坑 3：八个段的跨深通配（`skills/*`、`skills/teamsmith/tests/*` 一类）收窄成它们真读的路径；新增 `61` / `61b` 两行，把路由夹具**按文件**精确登记（`880bde4` + 合并） |
| `skills/teamsmith/tests/smoke.sh` | 坑 2：新增 §61（分组前门：FAST 12 组 / live 13 组）与 §61b（`--flip` 变异自检，live 专跑、FAST 显式可见 SKIP）（`a3b3f71`） |
| `skills/teamsmith/tests/section-budgets.tsv` | 两段的预算行，band 来自本轮实测（`8047489`） |
| `skills/teamsmith/tests/lib/model-routing-flips.py` | 顺带修 `init-legacy-proceeds` 臂的陈旧期望（见 Flip evidence 末段；`33aafa6`） |
| `docs/team/reports/P238-dev-bob.md` | 本报告 |

两次把 `main` 并入本分支：`5b0a66c`（P237/P240 等）、`5a083df`（P239；冲突面正是这三个文件，按语义双方保留，见 Decisions）。
未碰产品代码（`scripts/lib/**`、`extension/**`、`panel/**`、`templates/**`、`references/**`）；未删任何 `--flip` 臂；未削弱既有断言。

## Verification evidence（六条验收命令，全部真跑过）

### ① openspec validate --all --strict

```
$ "$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
✓ spec/verification
✓ spec/watchdog
Totals: 16 passed, 0 failed (16 items)
rc=0
```

### ② 坑 1：逐组单独跑（13 行，`pm` 必须 103/0）

```
$ for g in policy machine init config upgrade dispatch resume transaction limits preview sid-readers pm boundary; do
>   out=$(bash skills/teamsmith/tests/task-model-routing.sh --select "$g" 2>&1)
>   printf '%-12s rc=%s %s\n' "$g" "$?" "$(printf '%s' "$out" | tail -1)"
> done
loadavg at start: 3.32 3.74 5.00
policy       rc=0 secs=1 RESULT pass=26 fail=0 selected=policy
machine      rc=0 secs=0 RESULT pass=3 fail=0 selected=machine
init         rc=0 secs=3 RESULT pass=44 fail=0 selected=init
config       rc=0 secs=2 RESULT pass=19 fail=0 selected=config
upgrade      rc=0 secs=4 RESULT pass=41 fail=0 selected=upgrade
dispatch     rc=0 secs=28 RESULT pass=89 fail=0 selected=dispatch
resume       rc=0 secs=18 RESULT pass=78 fail=0 selected=resume
transaction  rc=0 secs=55 RESULT pass=106 fail=0 selected=transaction
limits       rc=0 secs=16 RESULT pass=63 fail=0 selected=limits
preview      rc=0 secs=6 RESULT pass=44 fail=0 selected=preview
sid-readers  rc=0 secs=11 RESULT pass=251 fail=0 selected=sid-readers
pm           rc=0 secs=3 RESULT pass=103 fail=0 selected=pm
boundary     rc=0 secs=347 RESULT pass=2431 fail=0 selected=boundary
loadavg at end: 3.93 3.47 4.33
```

修前同一条命令（同一台机器，未提交的工作树）：`pm rc=1 RESULT pass=74 fail=29`，其余 12 组 rc=0；
那 29 条红的最早一条是 `pm-partial-publication-record`，诊断
`skills/teamsmith/scripts/lib/common.sh:2584: …/.pi/team/state/.pm-launch-test-nonce: No such file or directory`
—— 夹具 state 目录当时由 `boundary` 组正文的 `mkdir -p "$STATE"` 创建，`pm` 组依赖兄弟组先跑过。
原始输出（29 条红全名单 + 诊断原文）：`logs/pm-before.log`。

### ③ 坑 2：新段两档

live（13 组全跑 + `--flip` 全量，合并树 `5a083df`，tip 与用时）：

```
$ bash skills/teamsmith/tests/smoke.sh --select 60,61,61b
#5 60 · 账本禁令：家目录 / 私有网段 / 用户名 / 他项目名（P212 · D94） · 用时 6s · ✓18 ✗0 SKIP1 · ticks 19
#6 61 · 任务类别模型路由：分组前门（P228 · task-model-routing） · 用时 466s · ✓1 ✗0 SKIP0 · ticks 1
#7 61b · 任务类别模型路由：翻转变异自检（P228 · task-model-routing） · 用时 4549s · ✓1 ✗0 SKIP0 · ticks 1
== 选段结果 ==  ✓ 41  ✗ 0
loadavg at start: 8.96 10.28 12.12
tip: 5a083df Merge branch 'main' into task/P238-routing-suite-gate
rc=0 secs=5051
loadavg at end: 3.02 3.72 5.02
```

FAST（12 组，不含 `boundary`；`61b` 显式可见 SKIP）：

```
$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh --select 61
  ✓ 61 路由分组前门（FAST · 组 policy,machine,init,config,upgrade,dispatch,resume,transaction,limits,preview,sid-readers,pm）全绿（RESULT pass=677 fail=0 selected=policy,machine,init,config,upgrade,dispatch,resume,transaction,limits,preview,sid-readers,pm）
#5 61 · 任务类别模型路由：分组前门（P228 · task-model-routing） · 用时 119s · ✓1 ✗0 SKIP0 · ticks 1
== 选段结果 ==  ✓ 22  ✗ 0
```

### ④ 坑 3：选段归属

```
$ bash skills/teamsmith/tests/section-select.sh --paths skills/teamsmith/tests/task-model-routing.sh skills/teamsmith/tests/lib/model-routing-boundary.sh
decision=RUN
sections=127
keys=8
reason=0 ← prologue
reason=0b ← prologue
reason=0c ← prologue
reason=0d ← prologue
reason=12b-h0d ← skills/teamsmith/tests/task-model-routing.sh, skills/teamsmith/tests/lib/model-routing-boundary.sh
reason=40 ← skills/teamsmith/tests/task-model-routing.sh, skills/teamsmith/tests/lib/model-routing-boundary.sh
reason=61 ← skills/teamsmith/tests/task-model-routing.sh, skills/teamsmith/tests/lib/model-routing-boundary.sh
reason=61b ← skills/teamsmith/tests/task-model-routing.sh
0	prologue

```

```
$ bash skills/teamsmith/tests/section-select.sh --check
ok: 段正文点名的真实路径 token 都被各自的行覆盖（496 个 token 检查过；0 个豁免类 token 不参与）
ok: 账本归属（ledger-scan 60）声明有效：9/9 个账本样例被它覆盖
== 选段自检 ==  ok 8  bad 0  SKIP 1
rc=0
```

修前（收到任务书时那张表 + 当时的选段器，用 `--table logs/paths-before.tsv` 重放同一对路径）：**23 个键**
（`0 0b 0c 0d 2 4 5 3b 6 6f 6i 6j 12b-h0d 18 19 28 38 40 55 56 59` + 前导），其中**没有一个跑路由入口**。
修后：**8 个键**，路由段 `61` / `61b` 在列，外加两处**故意保留**的递归扫描段（`12b-h0d` 段内
`grep -rln … tests`、`40` 段内 `tmp-hygiene.sh --lint` 扫 `tests/**/*.sh`）。

### ⑤ 固定验收行（本分支树上，报告已在本树）

```
$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: names：名单已配置（…/.pi/team/forbidden-names.txt，命中即红）
ledger-ban: root=…/.worktrees/dev-bob scope=published files=1391 hits=0 names=ok user=resolved
$ echo $?
ledger-ban: names：名单已配置（…/.pi/team/forbidden-names.txt，命中即红）
ledger-ban: root=…/.worktrees/dev-bob scope=published files=1391 hits=0 names=ok user=resolvedRC
```

### ⑥ git diff --check && git status --short

```
$ git diff --check && git status --short
diff --check: clean
status lines: 0
```

### 证据包（按 D94 放仓外）

`../pm-skills-ledger/team/reports/P238-dev-bob/`：

- `logs/live-60-61-61b.log`（顺序 ③ 的完整日志）、`logs/fast-postmerge-…`、`logs/select-31-58-real-tree.log`
- `logs/p238-pm-before.log`（坑 1 的红：29 条全名单 + 诊断）、`logs/p238-pergroup-{before,after}.txt`
- `logs/flip-first-run.log`（第一次全量 `--flip` 的 22 条臂与那条红）
- `logs/paths-before.tsv`（收到时的选段表副本）、`logs/selection-diff.txt`（全树前后选集差异）、
  `logs/selection-paths.txt`（坑 3 的前后对照）
- `scripts/selection-diff.py`（可重跑的全树对照）、`scripts/red-sides.sh`（下面三处红侧的可重跑脚本）

## Flip evidence

三处红侧都做成脚本，PM 可以在干净 clone 里重跑：`bash ../pm-skills-ledger/team/reports/P238-dev-bob/scripts/red-sides.sh <tree> <case>`。

### 坑 1 红侧：还原「逐组 setup」→ `--select pm` 必须再红

```
$ bash …/scripts/red-sides.sh . group-setup
rc=1  RESULT pass=74 fail=29 selected=pm
first red: FAIL pm-partial-publication-record
diagnostic: skills/teamsmith/scripts/lib/common.sh: line 2584: /tmp/teamsmith-task-model-routing.8SKPxQ/repo/.pi/team/state/.pm-launch-fixture-opaque-pm: No such file or directory    （state 目录不存在；文件名的具体后缀随调用点变化，PM 那次是 .pm-launch-test-nonce）
```

（脚本只删掉调用 `routing_group_setup` 的那个循环 —— 也就是把修复本身还原；跑完自动还原文件。）

### 坑 3 红侧：同一对路径对「收到时的表」→ 选段结果不含任何路由段

```
$ bash …/scripts/red-sides.sh . section-paths
decision=RUN
sections=127
keys=23
reason=0 ← prologue
reason=0b ← prologue
reason=0c ← prologue
reason=0d ← prologue
reason=2 ← needs:4, needs:5, needs:26
reason=4 ← needs:6j, needs:6, needs:3b
reason=5 ← needs:6j, needs:6f, needs:6i, needs:6, needs:3b
reason=3b ← needs:6
reason=6 ← needs:6f, needs:6i
reason=6f ← needs:6j
reason=6i ← needs:6j
reason=6j ← skills/teamsmith/tests/task-model-routing.sh, skills/teamsmith/tests/lib/model-routing-boundary.sh
reason=12b-h0d ← skills/teamsmith/tests/task-model-routing.sh, skills/teamsmith/tests/lib/model-routing-boundary.sh
reason=18 ← skills/teamsmith/tests/task-model-routing.sh, skills/teamsmith/tests/lib/model-routing-boundary.sh, needs:28
reason=19 ← skills/teamsmith/tests/task-model-routing.sh, skills/teamsmith/tests/lib/model-routing-boundary.sh
reason=26 ← needs:28
reason=27 ← needs:28
reason=28 ← skills/teamsmith/tests/task-model-routing.sh, skills/teamsmith/tests/lib/model-routing-boundary.sh, needs:38
reason=38 ← skills/teamsmith/tests/task-model-routing.sh, skills/teamsmith/tests/lib/model-routing-boundary.sh
reason=40 ← skills/teamsmith/tests/task-model-routing.sh, skills/teamsmith/tests/lib/model-routing-boundary.sh
reason=55 ← skills/teamsmith/tests/task-model-routing.sh, skills/teamsmith/tests/lib/model-routing-boundary.sh, needs:56
reason=56 ← skills/teamsmith/tests/task-model-routing.sh, skills/teamsmith/tests/lib/model-routing-boundary.sh
reason=59 ← skills/teamsmith/tests/lib/model-routing-boundary.sh
0	prologue
0b	prologue
0c	prologue
0d	prologue
2	needs:4, needs:5, needs:26
4	needs:6j, needs:6, needs:3b
5	needs:6j, needs:6f, needs:6i, needs:6, needs:3b
3b	needs:6
6	needs:6f, needs:6i
6f	needs:6j
6i	needs:6j
6j	skills/teamsmith/tests/task-model-routing.sh, skills/teamsmith/tests/lib/model-routing-boundary.sh
12b-h0d	skills/teamsmith/tests/task-model-routing.sh, skills/teamsmith/tests/lib/model-routing-boundary.sh
18	skills/teamsmith/tests/task-model-routing.sh, skills/teamsmith/tests/lib/model-routing-boundary.sh, needs:28
19	skills/teamsmith/tests/task-model-routing.sh, skills/teamsmith/tests/lib/model-routing-boundary.sh
26	needs:28
27	needs:28
28	skills/teamsmith/tests/task-model-routing.sh, skills/teamsmith/tests/lib/model-routing-boundary.sh, needs:38
38	skills/teamsmith/tests/task-model-routing.sh, skills/teamsmith/tests/lib/model-routing-boundary.sh
40	skills/teamsmith/tests/task-model-routing.sh, skills/teamsmith/tests/lib/model-routing-boundary.sh
55	skills/teamsmith/tests/task-model-routing.sh, skills/teamsmith/tests/lib/model-routing-boundary.sh, needs:56
56	skills/teamsmith/tests/task-model-routing.sh, skills/teamsmith/tests/lib/model-routing-boundary.sh
59	skills/teamsmith/tests/lib/model-routing-boundary.sh
```

### 坑 2 红侧：临时改坏一个路由断言（PM 的模型回落）→ 两档各自真红一次

```
$ bash …/scripts/red-sides.sh . section-mutation fast
  #5 61 · 任务类别模型路由：分组前门（P228 · task-model-routing） · 用时 119s · ✓0 ✗1 SKIP0 · ticks 1
账本自查： 5 段收口 · 增量 ✓21 ✗1 SKIP0 ｜ 结果行 ✓21 ✗1 —— 一致
== 选段结果 ==  ✓ 21  ✗ 1
smoke 有失败项（--keep 保留现场）
```

```
$ bash …/scripts/red-sides.sh . section-mutation live
  #5 61 · 任务类别模型路由：分组前门（P228 · task-model-routing） · 用时 453s · ✓0 ✗1 SKIP0 · ticks 1
账本自查： 5 段收口 · 增量 ✓21 ✗1 SKIP0 ｜ 结果行 ✓21 ✗1 —— 一致
== 选段结果 ==  ✓ 21  ✗ 1
smoke 有失败项（--keep 保留现场）
```

### 顺带修的 `--flip` 陈旧臂（改前红 → 改后绿）

第一次全量 `--flip`（改动前，tip 与本分支同代）在 22 条臂里给出 **1 条红**：
`FAIL flip-init-legacy-proceeds-plain` —— 该臂的意图是「拆掉 P235 的退休键闸门」，但只短路了
`team_config_legacy_model_keys` 时，plain `init` 路径仍被 P235 的模型策略解析器独立拒绝（夹具里没有
合法的新策略），于是 `init-legacy-plain-refused` 永远不红（臂头的命名期望形同虚设）。

A/B 证明这是**既有缺陷**、不是 P238 引入：拿 P238 之前的夹具（`git show 2280d06:…`）配同一个单函数变异，
红数一模一样（8 条，且没有 plain 那条）。修法：该臂连 `team_init_model_policy_resolve` 一并短路，
让「闸门被拆掉」这件事真的到达三条路径；定向复跑该臂：三条命名期望
（`init-legacy-{plain,force,bootstrap}-refused`）全红、还原后全绿。

最终 live 的 `--flip` 全绿：**22 条臂按名变红并还原**（`RESULT pass=143 fail=0`，见顺序 ③ 的 live 输出）。

## Decisions and deviations

### 分档：FAST 12 组 / live 13 组 / `--flip` 只在 live

判据取自任务书「全量门禁能咬住路由回归、FAST 的成本不失控」。实测：`boundary` 单组 **404s**，其余 12 组合计
**156s** —— 真 tmux window 家族是整套时长的大头，所以 FAST 跑 12 组（纯夹具：私有 tmux socket +
记录桩 pi + 私有临时根，不起真 pi、不碰共享 server，与 §59 同一形状），live 再加 `boundary`（13 组）。
`--flip` 每条臂都要跑一遍分组，整体（4549s）排除在 FAST 之外，但 FAST 里是**可见 SKIP**（`fast_skip`）而不是静默省略。

### 预算依据（都是本轮实测，不是估的）

| 段 | band（实测） | budget（×4，floor 60） | 实测（本轮） | 负载 |
|---|---|---|---|---|
| §61 | 513s | 2052 | live 466s（13 组）/ FAST 126s（12 组） | 8.96→3.02（live） |
| §61b | 4900s | 19600 | 4549s（22 条臂） | 同上 |

`section-guard.sh --budget-check`：全过（127/127 段有行且预算 ≥ 4×band）。

### 坑 3 收窄的范围与两处保留

按文件精确登记路由夹具（`task-model-routing.sh`、`lib/model-routing-{boundary,expansion,roles}.sh`、
`lib/model-routing-flips.py`、`lib/model-policy.sh`），并把八个段的跨深通配收窄成它们真读的路径
（逐段对照段正文与段内点名 token）。全树对照（`git ls-files` 每条路径的前后键集，`logs/selection-diff.txt`）：
**251 条路径的选集变了；新增的键只有 `61` `61b`，删掉的键只有 `18 19 28 38 55 56 59 6j`** ——
这次收窄只做减法，唯一的加法是路由两段。
两处**保留**通配并写进 basis：`12b-h0d`（段内递归 grep 整棵 tests 树找第二份几何实现）、
`40`（`tmp-hygiene.sh --lint` 扫 `tests/**/*.sh`）——它们是**真的驱动面**，不是懒写。

### 与 main 的两次合并

`5b0a66c`（P237「长作业挂起提示」等）与 `5a083df`（P239「账本归属 + 报告模板固定验收行」）。
冲突面三次都在同三个文件上，按语义双方保留：§60 里 P239 新加的 ⑤ 账本归属夹具留在 §60 内，
我的 §61/§61b 排在其后；选段表保留我收窄后的 55/56/59、取 main 的 60 行（含 `ledger-claim.sh`）、
再加 61/61b；预算表取 main 更新后的 60 数、加我的 61/61b。

### 发现但**不属于本任务边界**的红（A 类，已归 P242）

合并 `task-model-routing` 后全量门禁 `✓4478 ✗224`（v0.1.2 为 `✓4653 ✗0`）。我在合并树的 FAST 结构自检
（`0e,36,40,14d,61`）里看到唯一的红是 `36⑧ 产品面检出探针有失败（17 条）`，根因复现为：

- **A9**：`tests/lib/model-routing-{boundary,expansion,roles}.sh:190/16/17` 用裸 `tmux new-window`
  → M28 隔离 lint 3 条 RED（在 main 的解包树上复跑同一条 lint，同样 3 条）；
- **A1**：§6f 读 `dispatch --print` 不再落盘的提示词文件（`--select 31,58` 真树上 ✓407 ✗21 = §6f 20 + §31 1）。

两者都写在 main 的 `docs/team/tasks/P242-routing-a-fixtures.md`（A 类 210 条、B 类 14 条，deps 明写
「P238 必须先交付」）与 BOARD 的 P242 行里，属夹具侧合同更新，**不由本任务修**（改了它就要动 §6f/§31c
等的期望与 M28 隔离方式，超出任务书边界，也会与 P242 的写集合冲突）。

### 未做项与已知边界

- **`boundary` 组的「修前单独跑」没有有效数据**：我在它跑动中改了同一个脚本，bash 增量读取行号错位
  （`line 434: ' fi'`），那一行作废、不作证据；修后的 13 行是干净的（本报告顺序 ②）。
- 本任务**没有**在钉死容器（`teamsmith-gate:local`）里跑全量门禁：任务书的验收命令是选段级
  （新段两档 + 逐组 + 选段 + 账本行），且 P242 的交付会重跑全量。合并树上的全量门禁现在是
  `✓4478 ✗224` 起步（A/B 类红另计），单靠本任务无法让它全绿。
- §61 的 live 档在合并前用 `--select 61,61b` 跑过一次（513s / guard 900s 预算不足 → 已把预算行补上），
  合并后的正式证据是顺序 ③ 那次（466s / 4549s，`--select 60,61,61b`，rc=0）。

## Suggested next steps

- P242（A 类夹具侧）可以直接在本分支的选段表上继续：`--paths` 现在会把路由夹具精确选中 §61/§61b，
  改夹具不会再把 18/19/28/38/55/56/59/6j 一起拖进来。
- 若要验证「改坏路由代码 → 门禁真的红」，用 `--select 61`（FAST 档约 2 分钟）即可；`--flip` 那条 75 分钟的
  臂只在 live 档跑，适合在合并/归档前的全量里跑一次。
- `boundary` 单组 404s 是 §61 live 档的主要成本；若以后要压 FAST 之外的成本，可考虑把 boundary 再切成
  「纯逻辑探针」与「真 tmux window」两半，前者进 FAST。
