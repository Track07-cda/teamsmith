# P377 · 0.3.4 冻结门里 61b 那一条红：`flip-init-legacy-proceeds-bootstrap` 测不到东西

agent: dev   status: delivered   phase: apply   change: -   deltas: -   category: code
specs: `verification#The gate judges behaviour only, and never reports a skip as a pass`
anchor: none (infra) — 定点诊断 + 夹具契约修复
branch: `task/P377-routing-bootstrap-flip`（local 模式，未推）   time: 2026-10-26T11:06Z

## 结论（先看这一段）

**这是翻转契约缺陷，不是产品缺陷；已按最小改动修好。**

那一条红的原因是：这条臂用 `[ "$RC" != 0 ]` 给 bootstrap 分支判红，而**变异 scratch 不是可安装的 skill 源** ——
scratch 只拷 `scripts/references/templates/extension`（`task-model-routing.sh:1447`），没有 `SKILL.md`、也没有
`teamsmith-init` / `handover` 两个兄弟技能。于是变异体里 bootstrap 拆掉模型策略闸门后，**照样** rc=1：它是在
`✗ 技能源不合法：… 没有 SKILL.md` 处死的，不是被闸门拦住的。

实测（本报告 §2 的 `init-cmds.log`）：

| 树 | `bootstrap --no-pulse --agents dev` | 为什么 rc≠0 |
|---|---|---|
| 未变异（真树） | rc=1 | `✗ bootstrap: … 还在用退休的模型键（TEAM_DEFAULT_MODEL TEAM_AGENT_MODELS）—— 任何写入之前停住` + 两条路线 + 推导命令 |
| 变异体（scratch） | rc=1 | 已过闸门（`模型策略 vendor/light ［独立 PM：vendor/pm:high］`、`配置已存在…保留你的设置`），随后 `✗ 技能源不合法：… 没有 SKILL.md` |

所以 `init-legacy-bootstrap-refused` 在**两侧都绿**：它从来没有在测这条变异，臂也就永远点不到它的名。

**修法（`skills/teamsmith/tests/task-model-routing.sh:1490-1502`）**：同一条非 `--print` 路径上，闸门被拆掉后真正消失的是
拒绝输出里的推导路线 —— 命名断言改成 `^FAIL init-legacy-bootstrap-derived$` 与
`^FAIL init-legacy-bootstrap-startup-route$`；rc 侧的翻转由**不装 skill** 的 `--print` 路径证明
（变异体该步 rc=0 → `^FAIL init-legacy-print-refused$`）。产品夹具与产品代码**一行未动**
（`init-legacy-bootstrap-refused` 仍留在 `:829`，在真树上照旧承重）。

新断言可证伪（§4）：变异体 3/3 命中，未变异真树 0/3、未变异同形 scratch 0/3 —— 老的 `-refused` 则是变异体 0、
未变异 0（两侧皆 0，等于永远红，这正是冻结门那条红）。

## Deliverables

| Path | What |
|---|---|
| `skills/teamsmith/tests/task-model-routing.sh` | `init-legacy-proceeds` 臂的 bootstrap 命名断言：rc 断言（scratch 上不可判别）→ 拒绝输出的两条路线断言 + `--print` 的 rc 断言；注释写明实测原因 |

改动 11 行（+10/−1），只在这个 case 分支里；`model-routing-flips.py`、产品库、产品夹具都未改。

## Verification evidence (must have actually been run)

### 1 · 单臂复现（私有目录，不是整套 82 分钟）

复制集合与翻转循环完全一致（`task-model-routing.sh:1443-1449` 的 scratch 形状），变异脚本也是仓库里那一个：

```
$ BASE=/var/tmp/p377-dev/repro
$ for d in scripts references templates extension; do cp -a skills/teamsmith/$d "$BASE/control/skills/teamsmith/"; \
    cp -a skills/teamsmith/$d "$BASE/mutant/skills/teamsmith/"; done
$ touch "$BASE/mutant/.routing-mutant"
$ python3 skills/teamsmith/tests/lib/model-routing-flips.py "$BASE/mutant" init-legacy-proceeds
{"mutation": "init-legacy-proceeds", "changes": [
  {"file": "…/mutant/skills/teamsmith/scripts/lib/cmd-project.sh", "matched": 1,
   "before": "b69dbb56…", "after": "24ff0340…"},
  {"file": "…/mutant/skills/teamsmith/scripts/lib/cmd-project.sh", "matched": 1,
   "before": "24ff0340…", "after": "022b5088…"}]}
```

变异体里 `team_config_legacy_model_keys` 变成 `return 0`，`team_init_model_policy_resolve` 变成打印
`vendor/light` / `vendor/pm:high`（与臂的目的逐字一致）。

### 2 · 变异体 `--select init`：老断言缺席、新断言在场

```
$ TMPDIR=$BASE/tmp TEAM_ROUTING_TREE=$BASE/mutant TEAM_ROUTING_EVIDENCE=$BASE/evidence-mutant-after \
    bash skills/teamsmith/tests/task-model-routing.sh --select init; echo rc=$?
RESULT pass=29 fail=39 selected=init
rc=1
$ grep -c '^FAIL init-legacy-bootstrap-refused$' mutant-init-after.log        → 0
$ grep -n '^PASS init-legacy-bootstrap-refused$' mutant-init-after.log        → 37:PASS init-legacy-bootstrap-refused
```

bootstrap 那一步的原始输出（`…/evidence-mutant-after/*/init-cmds.log`，逐字节照抄，路径略）：

```
command=bootstrap --no-pulse --agents dev
rc=1
teamsmith bootstrap · init-legacy
  名册        dev
  模型策略    vendor/light ［独立 PM：vendor/pm:high］
  版本控制    local ｜ 门禁 <无> ｜ 安装 <无>
  巡检        跳过
  配置已存在：…/init-legacy/.pi/team/config.sh（保留你的设置）
✗ 技能源不合法：…/mutant/skills/teamsmith 没有 SKILL.md —— 目录名与 frontmatter 的 name 必须一致
  miss  teamsmith-init（源 …/mutant/skills/teamsmith-init 不在：随包发布的技能少装了一个）
  miss  handover（源 …/mutant/skills/handover 不在：随包发布的技能少装了一个）
✗ 找不到可安装的 skill 源（…/mutant/skills/teamsmith 与它软链背后的 skills/ 里没有合格的技能目录）
```

同一棵树上的另外四步（这就是「闸门确实被拆掉了」的正面证据）：

| 命令 | 变异体 rc | 未变异真树 rc |
|---|---|---|
| `init --no-skills --session init-legacy --agents dev` | **0**（写盘） | 1（拒绝） |
| `init --force … --task-models routine=p/new --pm-model p/pm` | **0** | 1（拒绝） |
| `bootstrap --no-pulse --agents dev` | 1（装 skill 处死） | 1（闸门拒绝） |
| `bootstrap --no-pulse --agents dev --print` | **0** | 1（拒绝） |
| `config set TEAM_NOTIFY_TMUX 1 --yes` | **0** | 5（拒绝） |

### 3 · 未变异对照：真树 `--select init` 全绿

```
$ TMPDIR=$BASE/tmp TEAM_ROUTING_EVIDENCE=$BASE/evidence-realtree-control \
    bash skills/teamsmith/tests/task-model-routing.sh --select init; echo rc=$?
RESULT pass=68 fail=0 selected=init
rc=0
```

真树上同一段 legacy 输出（证明产品侧拒绝完好，且推导命令逐字为 `config upgrade-models --task-models
'dev=p/old default=p/old' --pm-model 'p/old' --dry-run`）：

```
command=bootstrap --no-pulse --agents dev
rc=1
✗ bootstrap: …/init-legacy/.pi/team/config.sh 还在用退休的模型键（TEAM_DEFAULT_MODEL TEAM_AGENT_MODELS）—— 任何写入之前停住
  项目模型策略是破坏式升级：bootstrap 不是迁移路径（init --force 也不是）
  路线 ① 手工事务（先预览）：team config upgrade-models --task-models 'dev=p/old default=p/old' --pm-model 'p/old' --dry-run
  路线 ② 启动事务（机械形状由它迁移）：team up（--print 只预告，--no-migrate 只报告）
```

另有一个**同形未变异 scratch**（同样的四个目录、不打变异）复跑：`RESULT pass=67 fail=1`，唯一红是
`FAIL init-bootstrap-fresh-rc`（该副本本来就装不了 skill，与本次判据无关）—— 它在这里只有一个用途：
证明新断言不是「任何一跑都在场」的橡皮章（见下）。

### 4 · 新断言的判别力（三棵树对照）

```
pattern                                         mutant  unmutated-same-shape  real-tree-control
^FAIL init-legacy-bootstrap-refused$               0              0                    0
^FAIL init-legacy-bootstrap-derived$               1              0                    0
^FAIL init-legacy-bootstrap-startup-route$         1              0                    0
^FAIL init-legacy-print-refused$                   1              0                    0
```

臂级检查在新日志上的 rc：老的 `grep -q … -refused` → **rc=1**（就是冻结门那条红）；新的
`-bootstrap`（derived）→ **rc=0**、`-bootstrap-startup` → **rc=0**、`-print` → **rc=0**。

### 5 · 轻量收口

```
$ bash -n skills/teamsmith/tests/task-model-routing.sh; echo rc=$?
rc=0
$ git diff --check; echo rc=$?
rc=0
$ bash skills/teamsmith/tests/ledger-ban.sh --names-file \
    "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"; echo rc=$?
ledger-ban: root=/home/<user>/…/.worktrees/dev scope=published files=2195 hits=0 names=ok user=resolved
rc=0
```

（`files=2195` 含本报告本身；同一行命令在写完本报告后复跑，读数见文末「收口复跑」。）

- Verdict: **pass**（本臂的检查现在会因变异而红、因还原而绿；控制绿）。
- Notes：
  - **没有跑**整套 `--select flip`（82 分钟）和全量门禁 —— 任务书明确只要单臂复现；臂级检查的改动只在这一条 case 分支里。
  - **没有跑**其他 30 条臂；它们的 `$TMP/flip-$mutation.log` 解释方式未变。
  - 本臂的检查数 3 → 5（§61b 的 `RESULT pass=` 会 +2，200 → 202）；**退役**的是那条不可判别的 rc 期望，
    **替换**为同一路径的两条路线断言 + 不装 skill 路径的 rc 断言（净 +2，全在既有臂内；没有新增段、没有新增夹具）。
  - 受检对象与 `d8a21c03` 的产品代码相同：`git diff --stat d8a21c03 HEAD` → 3 个 `docs/` 文件、`skills/` 零差异。

## Flip evidence (required for defect-fix tasks)

**red → green**（同一份变异日志、同一组 grep，改前/改后）：

```
# 改前：臂点不到名（冻结门那条红）
$ grep -q '^FAIL init-legacy-bootstrap-refused$' mutant-init-after.log; echo $?
1

# 改后：三条命名断言逐条命中
$ grep -q '^FAIL init-legacy-bootstrap-derived$' mutant-init-after.log; echo $?
0
$ grep -q '^FAIL init-legacy-bootstrap-startup-route$' mutant-init-after.log; echo $?
0
$ grep -q '^FAIL init-legacy-print-refused$' mutant-init-after.log; echo $?
0
```

**反向控制（断言不是橡皮章）**：同一组 grep 打在未变异真树与未变异同形 scratch 上 **0/3 命中**（§4 表），
也就是「变异没落地 → 臂必须红」这一条仍然成立。老期望之所以是错的，不是因为断言太严，而是因为它测的那个量
（非 `--print` bootstrap 的 rc）在变异 scratch 上被装 skill 的失败钉死，控制与变异两侧同为非零。

## Decisions and deviations

- **只改翻转契约，不改 scratch 形状**。另一条能让老断言变红的路是让 scratch 可安装（补拷 `SKILL.md` 与
  `teamsmith-init`/`handover`），那会让**全部 31 条臂**跑在一棵新形状的树上，必须整套 82 分钟重跑才能说清楚，
  超出本任务书的验收范围（且它的失败形态与 P320 那次「copy 复数写成 `extensions`」不同：这里不是写错名字，
  而是 scratch 刻意只拷运行 CLI 需要的那四个目录）。所以按任务书「最小修复」处理，并把这条记为后续可选项。
- 没有改 `init-legacy-bootstrap-refused`（产品夹具）——它在真树上是对的，`--select init` 68/0 就是证据。
- 未新增段、未跳过任何断言、未把「缺拒绝」变成 skip。

## Suggested next steps

- 若要给**非 `--print` 的 bootstrap** 一条 rc 级别的翻转（现在是消息级别），需要给变异 scratch 一个可安装的
  skill 源（`SKILL.md` + 兄弟技能），并整套重跑 `--select flip`；这是 PM 的取舍，不是本任务的既定范围。
- 0.3.4 的冻结门需要在最终 tip 上重跑 §61b（或整套门禁），确认本条红消失且其余 30 条臂不变。

## 收口复跑（本文件写完之后）

```
$ git diff --check; echo rc=$?
rc=0
$ git status --porcelain
?? docs/team/reports/P377-dev.md          # 仅本报告，随后提交
$ bash -n skills/teamsmith/tests/task-model-routing.sh; echo rc=$?
rc=0
$ bash skills/teamsmith/tests/ledger-ban.sh --names-file \
    "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"; echo rc=$?
ledger-ban: root=/home/<user>/…/.worktrees/dev scope=published files=2195 hits=0 names=ok user=resolved
rc=0
```
