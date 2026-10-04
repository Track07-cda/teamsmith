# P76 · 合并时机也查「未入账记录」（D45）apply

```
task:   P76（apply；本地模式，不 push）
change: -（infra：给 PM 的合并步加自检，不改任何既有判定语义；anchor none）
specs:  -
branch: task/P76-p76
base:   b698b80d（merge-base HEAD main）
tip:    fbf5ca27（代码提交；本报告与证据包是它之后的 docs-only 提交 —— PM 复验对象是分支 tip）
机器:   nproc=32 · 本块期间 ambient loadavg 约 3.6–5.2（同机另有 PM 与别的席位的门禁在跑）
```

## Deliverables

| Path | What |
|---|---|
| `skills/teamsmith/scripts/lib/cmd-review.sh` | `--pre-merge` 模式 + 扫描/定位/打印四个新函数（只加不改） |
| `skills/teamsmith/SKILL.md` | 回环第 5 步 + git/forge 第 3b 步（先落账、再合并） |
| `skills/teamsmith/references/protocol.md` | §8e 新增「Before the merge, land the worktree's records.」| 
| `skills/teamsmith/tests/smoke.sh` | 追加 §44（append-only，27 条断言） |
| `docs/team/reports/P76-dev-bob/pkg/` | 独立复现/翻转包（`run.sh` 入口） |

## 结论

合并前的「未入账记录」检查已落地为**一条命令**：`team review <ID> --pre-merge`。

| 行为 | 实测 |
|---|---|
| 有 `docs/team/**` 未入账记录 | 退出码 **1**；逐条 `<agent>: <path>  [XY 说明]`；给可粘贴的修法（`git -C <工作树> add -A -- …` + 带 `Agent:` trailer 的 commit）|
| 没有 | 退出码 **0**、**零输出**（安静，能直接当合并门用）|
| 定位不到任务分支的工作树 | 退出码 **2**（fail closed：不让「没检查」看起来像「没问题」） |
| 副作用 | 只读：不跑门禁、不写复验记录、不动工作树、**不替 agent 提交** |

检查范围刻意窄：只查**这个任务分支的工作树**里 `<docs>/**` 下的记录；`state/`、构建产物、ignored
文件都不拦路。为什么要这一步：`git merge --squash` 只带**已提交**内容，worker 留在工作树里的报告/
证据包（`??`）或改了没提交的记录（` M`）合并不带它们，工作树一被复用/复位就永久丢了 —— D45 当天
同一个形状丢了 5 次（P36/P40/P42/P65/P67），而既有的 M31/P47 digest 警告**合并流程从来不跑**。

## 交付明细（对应任务书五条）

### 1 · 合并前的检查（一条命令）

`skills/teamsmith/scripts/lib/cmd-review.sh`：

- `team_review_unlanded_records <worktree>`：`git status --porcelain --untracked-files=all -- <docs>`，
  逐行 `<XY>\t<path>`（包内文件也逐条点名）。
- `team_review_unlanded_label <XY>`：认识的 porcelain 码给中文说明，其它落兜底（不编语义）。
- `team_review_premerge_worktree <ID>`：`team__resolve_branch`（state → refs 的 `task/<ID>-*`）拿到任务
  分支，再扫 `.worktrees/*/` 找停在它上面的工作树 → `<agent>\t<worktree>\t<branch>`。
- `team_cmd_review_premerge <ID>`：0/1/2 三态 + 打印（见上表）。
- `team_cmd_review`：新增 `--pre-merge`（与 `--dir`/`--no-gates`/`--strong`/`--allow-unresolved-branch`/
  `--branch` 互斥，含混用法退出 2）。**既有复验路径没有行为改动**（`team_cmd_review` 的执行路径只在
  `[ -n "$id" ]` 之后多了一个早退分支）。

`--pre-merge` 的真实输出（P76 夹具）：

```
✗ review P76 --pre-merge：3 份记录未入账（squash 合并只带已提交内容，它们会被留下）
  工作树：dev（/tmp/p76-manual.WqCR9S/.worktrees/dev @ task/P76-smoke）
  未入账（只看 docs/team/ 下；ignored 与其它脏文件不算）：
    dev: docs/team/DECISIONS.md  [ M 已改未提交（工作区改动）]
    dev: docs/team/reports/P76-dev.md  [?? 未跟踪（新文件，从未提交）]
    dev: docs/team/reports/P76-dev/pkg/run.sh  [?? 未跟踪（新文件，从未提交）]
  修法（PM 手工提交；skill 不替 agent 提交，提交带 `Agent:` trailer）：
    git -C /tmp/p76-manual.WqCR9S/.worktrees/dev add -A -- docs/team/DECISIONS.md docs/team/reports/P76-dev.md docs/team/reports/P76-dev/pkg/run.sh
    git -C /tmp/p76-manual.WqCR9S/.worktrees/dev commit -m "docs(team): P76 未入账记录" -m "Agent: dev"
  → 提交后重跑：team review P76 --pre-merge
```

同一条命令在**真仓库、真分支**上的自检（本任务自己的报告与证据包当时还没提交，正是 D45 的形状）：

```
$ bash skills/teamsmith/scripts/team review P76 --pre-merge
✗ review P76 --pre-merge：5 份记录未入账（squash 合并只带已提交内容，它们会被留下）
  工作树：dev-bob（…/.worktrees/dev-bob @ task/P76-p76）
  未入账（只看 docs/team/ 下；ignored 与其它脏文件不算）：
    dev-bob: docs/team/reports/P76-dev-bob.md  [?? 未跟踪（新文件，从未提交）]
    dev-bob: docs/team/reports/P76-dev-bob/pkg/10-green.sh  [?? 未跟踪（新文件，从未提交）]
    dev-bob: docs/team/reports/P76-dev-bob/pkg/20-flip.sh  [?? 未跟踪（新文件，从未提交）]
    dev-bob: docs/team/reports/P76-dev-bob/pkg/lib.sh  [?? 未跟踪（新文件，从未提交）]
    dev-bob: docs/team/reports/P76-dev-bob/pkg/run.sh  [?? 未跟踪（新文件，从未提交）]
  …（修法 + Agent: dev-bob trailer，同下）
rc=1
```

（本条命令的下一步就是本报告的提交 —— 几秒后的提交把这份记录入账。）

### 2 · 同步文档（含「为什么」）

- `SKILL.md`：协作回环第 5 步改成「**先落账、再合并**」（并写清 squash 只带已提交内容、D45 五次、
  PM 手工提交带 `Agent:` trailer）；「git 与 forge」一节加第 **3b** 步（verification 之后、merge 之前）。
- `references/protocol.md` §8e：新增「**Before the merge, land the worktree's records.**」段 —— 同一套
  事实、命令、退出码语义、以及「ignored 与 `<docs>/` 之外的脏文件不算、定位不到 fail closed」。

### 3 · 不许越界

命令只**打印**修法，从不执行：`pkg` 夹具 §44 ① 钉住「HEAD 不动 + 文件仍是 `??`」；修法里的 commit
带 `Agent: <agent>` trailer（谁提交的必须是真的，PM 手工提交也照 D45 的样子）。

### 4 · 可证伪（smoke §44 + 独立翻转包）

`tests/smoke.sh` 追加第 44 节（append-only，27 条断言，纯逻辑、FAST 与全量都跑）：专用夹具仓库
（`git init` + `team init` + 脚手架入账）→ 任务工作树 `task/P76-smoke` + `state/dev.env:task=P76`。

| 情形 | 断言 |
|---|---|
| ① 未跟踪报告 + 包内文件 + 已改未提交的 `DECISIONS.md` | rc=1；三条逐条点名；修法列全路径；`Agent: dev`；不写复验记录；HEAD 不动；文件仍 `??` |
| ② 提交后 | rc=0 且**零输出** |
| ③ 只有 `scratch.txt` / `build/` / `state/` / ignored 的 inbox+`reviews/*.log` | rc=0 且零输出（负对照） |
| ④ 反向（可证伪） | 同源探针影子掉扫描（= 检查被删除的形状）→ 同一份夹具退出 0、零输出 |
| ⑤ 含混用法 / 定位不到 | `--pre-merge --dir` 退出 2；删掉工作树+分支后退出 2 并点名「无法检查」 |

独立复现包（不动工作树，把 `skills/{teamsmith,teamsmith-init}` 拷进临时目录、在副本里删掉检查、
把 §44 段落逐字节抽出来跑）：`docs/team/reports/P76-dev-bob/pkg/run.sh` —— 见「翻转证据」。

### 5 · 零回归

- `team review` 的既有复验路径：diff 里的删除只有两行（`local …` 多了 `pre_merge=0`、usage 字符串
  多了一行 `--pre-merge` 用法）；既有的 checkout 一致性 / clean 守卫 / 门禁 / 记录写入一字未改，
  `team_cmd_review` 的执行路径只在 `[ -n "$id" ]` 之后多了一个 `--pre-merge` 早退分支。
- 基线（未改动的 `b698b80d`）：`TEAM_SMOKE_FAST=1` **✓2447 ✗0**。
- 改后：见「门禁」一节；当前 main 上没有已知红 `12b-j`（基线 FAST 与改后 FAST 都全绿，那条不在）。

## 验收命令与输出（实跑）

```
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
✓ spec/verification
✓ spec/watchdog
Totals: 28 passed, 0 failed (28 items)

$ bash -n skills/teamsmith/scripts/lib/cmd-review.sh && bash -n skills/teamsmith/tests/smoke.sh
（无输出，语法通过）

$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh    # 基线（b698b80d）
== 结果 ==  ✓ 2447  ✗ 0
smoke 全绿
```

全量门禁（brief 的命令）：

```
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh
✓ change/test-tmp-hygiene
…
Totals: 28 passed, 0 failed (28 items)
（全量 smoke，不带 TEAM_SMOKE_FAST：日志里 0 条「SKIP（FAST 模式）」）
…
== 44 · P76 合并前的未入账记录检查（D45） ==
  ✓ P76 夹具仓库 init 成功
  …（本段 27 条全绿，逐条见上）
== 结果 ==  ✓ 3119  ✗ 0
smoke 全绿
GATE_RC=0
```

（门禁锁：起跑时本机还有另一套全量 smoke 在跑（dev3 的席位），本套先排队、拿到锁后跑；
两次 `openspec validate` 都是 28/28。全量 smoke 共约 33 分钟（含排队），无 FAST 跳过。）

## 翻转证据（flip）

按「破坏实现 → 守门测试必须红 → 恢复」的形状做了一遍（改的是**真树**，跑的是 `TEAM_SMOKE_FAST=1`
的整段 smoke，不是只跑 §44）：

```
# 1) 变异：把「未入账」扫描影子成空（= 检查被删除）
$ python3 …（把 team_review_unlanded_records 的 body 换成 `:`）；bash -n 通过
$ sha256sum skills/teamsmith/scripts/lib/cmd-review.sh
d6b127a5…  → 变异后 git diff --stat: 1 file changed, 2 insertions(+), 3 deletions(-)

# 2) 红侧：同一份 §44 夹具，只有检出断言红，别处一条不掉
$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh
== 44 · P76 合并前的未入账记录检查（D45） ==
  ✗ P76 ①：有未入账记录 → 非零退出（能当合并门）（期望 [1]，实际 [0]）
  ✗ P76 ①：点名未入账份数（… 中找不到 [3 份记录未入账]）
  ✗ P76 ①：未跟踪的报告点名（<agent>: <path> + 状态）（…）
  ✗ P76 ①：已改未提交的记录同样点名（…）
  ✗ P76 ①：报告包里的文件逐条点名（--untracked-files=all）（…）
  ✗ P76 ①：修法是一条可粘贴的 git add（列出全部路径）（…）
  ✗ P76 ①：修法里的提交带 Agent: trailer（谁提交的要说真话）（…）
  ✗ P76 ①：给出提交后重跑的下一步（…）
  ✗ P76 ④：探针（同源）照旧非零退出（期望 [1]，实际 [0]）
  ✗ P76 ④：探针照旧点名路径（…）
== 结果 ==  ✓ 2464  ✗ 10        （10 条红全在 §44 的 ①/④ 检出断言上；②③⑤ 与其余 2454 条全绿）
SMOKE_RC=1

# 3) 恢复：git checkout -- 后哈希回到变异前的值
$ git checkout -- skills/teamsmith/scripts/lib/cmd-review.sh
$ sha256sum skills/teamsmith/scripts/lib/cmd-review.sh
d6b127a555def35cd8c280cf897ff1469cf7df75a50d0aa8a30837c299f2ca13   # == 变异前
$ git status --short                                                # 干净
$ bash -n skills/teamsmith/scripts/lib/cmd-review.sh                # 通过

# 4) 绿侧：同一段 §44 又全绿
```

独立复现包（不需要改真树，也不需要 tmux/pi；把 §44 段落逐字节抽出来跑，副本里删检查）：

```
$ bash docs/team/reports/P76-dev-bob/pkg/run.sh
===== 10-green.sh =====
== 段落结果 == ok=27 bad=0
  ok  绿树：§44 全绿（rc=0）
== 10 结果 == ok=1 bad=0 finding=0

===== 20-flip.sh =====
  ok  变异生效：副本里的 team_review_unlanded_records 已影子成空
  ✗   P76 ①：有未入账记录 → 非零退出（能当合并门）（期望 [1]，实际 [0]）
  …（另 9 条同族红）
== 段落结果 == ok=17 bad=10
  ok  变异树：§44 非零退出（守门红了）
  ok  变异树：恰好 10 条红（= §44 里依赖「未入账」检查的检出断言）
  ok  变异树：全部红都落在 ①/④ 的检出断言上（②/③/⑤ 不被带红）
  ok  变异树：① 那条「非零退出」断言在红名单里（守门的关键一条）
== 20 结果 == ok=5 bad=0 finding=0
```

## Decisions and deviations

- **入口选 `team review <ID> --pre-merge`，不新增 `team merge-check`**：新动词要改 `scripts/team`
  （分发）与 `cmd-project.sh`（help 行），两处都在任务书 `grant:` 之外；旗标把改动面收在
  `cmd-review.sh` 里（brief 的第一个例子也正是它）。`--pre-merge` 与复验旋钮互斥（用法错退出 2）。
- **定位不到工作树 = 退出 2（fail closed）**：brief 只规定「有未入账 → 非零、没有 → 安静」，没说
  查不了怎么办；按 F7 的同族口径选「不假装检查过」，并在消息里写明「工作树若已删除，未入账文件
  也随之消失」这条事实。
- **不查主工作树**：`team review` 自己会把 `reviews/<ID>.md` 写在主工作树且**故意**在合并前不提交，
  把主工作树纳进来会让这道门对每次正常流程都假红。检查对象 = 合并分支所在的工作树（正是 D45 的
  丢失形状）。
- **不改 `team close`**：close 发生在合并之后，那时工作树可能已被复用/复位；合并门放在合并前才有意义。
- **不改 `cmd-project.sh` 的 help 行**（不在 grant 内）：`team help` 的 review 一行暂时没有
  `[--pre-merge]`；SKILL.md 与 protocol.md 都已写明（见「建议的下一步」，一行即可补上）。

## 建议的下一步（给 PM）

- 一行收尾：`skills/teamsmith/scripts/lib/cmd-project.sh:77` 的 review 用法串加 `[--pre-merge]`
  （grant 外，留给 PM）。
- 复验：`team review P76 --dir <独立checkout>`；证据包 `docs/team/reports/P76-dev-bob/pkg/run.sh`
  可原样复跑（纯逻辑、无 tmux/pi、不动工作树）。
- 若要更强的默认覆盖：可考虑在 `team close --status done` 也打一行同类警告（本任务未做，避免
  改变既有无回归面）。
