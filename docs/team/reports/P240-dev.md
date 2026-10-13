# P240 · 让「崩溃席位 / resume」这条链恢复绿

agent: dev   status: delivered（产品侧已修；夹具侧见 BLOCKED）   time: 2026-10-13T08:50Z
branch: `task/P240-resume-regression`（tip `36cba2b`）   PR/MR: -

## 结论（先说事实，再说判断）

1. 任务书里的 9 红在钉死容器里**复现了**（`--select 11c`：`✓74 ✗9`，与 PM 的表一致）。但那次对照**两边跑的不是同一个选集**：PM 的 baseline 作业是 `--select 6,13,32,11c`（12 段），routing 那次是 `--select 11c`（7 段）。两份作业的原始命令行在证据包里（`pm-baseline-job.txt` / `pm-routing-job.txt`）。
2. 用**同一条命令**在 v0.1.2（上一次全绿门禁的 tip `69692a6`）上跑 `--select 11c`，结果是 `✓75 ✗8` —— 9 红里有 **8 红在合并之前就同样红**。它们不是 routing 合并引入的行为回归，而是**选段闭包缺口**：`--select 11c` 不含 §5（add-agent，建 `.worktrees/dev`）与 §11b3（`wait_window_gone` 定义处）。
3. 用同选集对照才看得出真回归：v0.1.2 `✓230 ✗1`（与 PM 的 baseline 日志逐项一致），e897a7d `✓223 ✗6`。差出来的 5 红分成三类：**产品回归 1 条**（`resume --dry-run` 的清单行被换成 `--print`）、**新合同 vs 旧夹具 2 条**（§11c 的 `up --agents`）、**新合同 vs 旧夹具 2 条**（§32⑧c 的 brief 缺 `category:`）。
4. 产品侧只有那 1 条真回归，已修（一行 + 注释），翻转证据齐（旧代码红 / 删掉那行仍红 / 恢复后绿，且 dry-run 依然一个字节不写）。
5. 其余 4 条与 `--select 11c` 的 8 条都落在 `smoke.sh` / `section-paths.tsv`（P238 的写集合），按任务书边界交回：见文末 `BLOCKED:`。

一句话：**这份任务书假设的「行为回归」有 1 条是真的（已修），其余是「对照取错选集」与「新合同下旧夹具要更新」两类**。

## Deliverables

| Path | What |
|---|---|
| `skills/teamsmith/scripts/lib/cmd-watch.sh` | `team resume --dry-run` 恢复清单行 `  <agent> 可续跑：<task> → <taskfile>`，其后仍照 P228 的合同调 `dispatch --print` 解析同一套预检/计划（拒绝时退非 0、不写盘） |
| `docs/team/reports/P240-dev.md` | 本报告 |
| 仓外证据包 | `pm-skills-ledger/team/reports/P240-dev/`（README.txt 有索引） |

改动本体：

```diff
@@ team_cmd_resume() 的 dry 分支
     if [ "$dry" = "1" ]; then
+      # P240：dry-run 是 PM「一眼看清哪些席位有活可续」的清单入口（workflows.md：the PM looks for itself）。
+      # P228 的合同要求 dry-run 解析与真派单同一套预检/计划（退非 0、不写盘），那条走下面的 --print；
+      # 但清单行本身是既有输出契约（--select 11c / 6k⑥ / M9.3-③ 都钉它），两个都要在：先列清单，再看计划。
+      printf '  %s 可续跑：%s → %s\n' "$a" "$task" "$taskfile"
       team_cmd_dispatch "$a" "$task" "$taskfile" --print || failed=1
```

没有削弱任何断言，也没有回退 S1 的行为：`task-model-routing.sh --select dispatch,resume,transaction,pm,config` 修前修后都是 `RESULT pass=304 fail=0`。

## Verification evidence（都是真跑的）

### 验收命令 1：`openspec validate --all --strict`

```
$ "$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
✓ change/pulse-key-replies
✓ change/task-model-routing
✓ spec/verification
✓ spec/watchdog
Totals: 16 passed, 0 failed (16 items)     RC=0
```

### 验收命令 2：`bash skills/teamsmith/tests/smoke.sh --select 11c`（容器、干净克隆）

```
$ distrobox-host-exec podman run --rm --pid=host --cgroups=enabled --userns=keep-id -e HOME=/tmp \
    -v /tmp/p240-fix:/work -w /work localhost/teamsmith-gate:local \
    bash -c 'git config --global --add safe.directory "*"; bash skills/teamsmith/tests/smoke.sh --select 11c </dev/null'
== 选段 == decision=RUN · 运行 7/125 段 · 未跑 118 段
  ✗ §11c 夹具：5s 内 dev 窗口还在（「窗口仍不在」的前提没成立）
  ✗ 崩溃 agent 的任务记录还在（…/repo/.pi/team/state/dev.env 中找不到 [task=T1.1]）
  ✗ digest 仍把崩溃 agent 算成待办（…/digest-crash.log 中没有匹配 [停了的 agent [0-9]]）
  ✗ 死窗口释放模型槽位（RUNNING=0）（期望 [0]，实际 [可用]）
  ✗ resume --dry-run 能识别待续跑任务（…/resume-dry.log 中找不到 [可续跑：T1.1]）
  ✗ resume 重新派单（…/resume.log 中找不到 [续跑 dev]）
  ✗ resume 后 dev 窗口回来了（期望 [1]，实际 [0]）
  ✗ up --agents 才会续跑 agent（…/up-agents.log 中找不到 [续跑 dev]）
  ✗ （假 pi 秒退：up 同时也如实报了 PM 没起来）（…/up-agents.log 中找不到 [PM 启动失败]）
== 选段结果 ==  ✓ 74  ✗ 9
```

**这一条没有变绿，而且不是本次改动能变绿的** —— 见下面的根因（这条选集不含夹具前置，v0.1.2 上同样是 `✗8/✗9`）。同一段在**够前置的选集**里已经绿：`--select 6,13,32,11c` 下 §11c 从 `✓12 ✗4` 变成 `✓13 ✗3`，少的那条红正是本次修的产品缺陷（`resume --dry-run`）。

### 验收命令 3：`task-model-routing.sh --select dispatch,resume,transaction,pm,config`

```
$ distrobox-host-exec podman run … -v /tmp/p240-fix:/work … \
    bash skills/teamsmith/tests/task-model-routing.sh --select dispatch,resume,transaction,pm,config </dev/null
RESULT pass=304 fail=0 selected=dispatch,resume,transaction,pm,config      RC=0
（修前在 e897a7d 上同样 pass=304 fail=0：本次改动没有让任何路由语义回归）
```

### 验收命令 4：`ledger-ban.sh`

```
$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: names：名单已配置（<home>/Documents/…/.pi/team/forbidden-names.txt，命中即红）
ledger-ban: root=<home>/…/.worktrees/dev scope=published files=1374 hits=0 names=ok user=resolved    RC=0
```

### 验收命令 5：`git diff --check && git status --short`

```
$ git diff --check && git status --short
（空 —— 交付 tip 上工作树干净）
```

### 对照实验（把「回归」和「选集差异」拆开）

| 运行 | 树 | 选集 | 总结果 | §11c | §32 |
|---|---|---|---|---|---|
| A | v0.1.2 `69692a6` | `11c` | `✓75 ✗8` | `✓8 ✗8` | 未跑 |
| B | e897a7d（合并 tip） | `6,13,32,11c` | `✓223 ✗6` | `✓12 ✗4` | `✓69 ✗2` |
| C | v0.1.2 `69692a6` | `6,13,32,11c` | `✓230 ✗1` | `✓15 ✗1` | `✓73 ✗0` |
| FIX | `36cba2b`（本 tip） | `6,13,32,11c` | `✓232 ✗5` | `✓13 ✗3` | `✓69 ✗2` |
| MUTANT | `36cba2b` 删掉新增那行 | `6,13,32,11c` | `✓231 ✗6` | `✓12 ✗4` | `✓69 ✗2` |

C 与 PM 的 `baseline-012-sections` 日志逐项一致（`✓230 ✗1`，§11c `✓15 ✗1`），所以上面的差集不是场地差异。

## 逐条根因（任务书的 9 红 + §32 的两条）

| # | 红（任务书原文） | A（v0.1.2，同命令） | B（e897a7d） | 根因 | 归谁 |
|---|---|---|---|---|---|
| 1 | `§11c 夹具：5s 内 dev 窗口还在` | 红 | 红 | `wait_window_gone` 定义在 §11b3 段内（`smoke.sh:5039`），而 `--select 11c` 的闭包只有 `0/0b/0c/0d/2/4/11c` → 调用处 `command not found`（127）→ `bad`。合并前就红 | 选段闭包（P238） |
| 2 | `崩溃 agent 的任务记录还在`（无 `dev.env`） | 红 | 绿 | 选集里没有 §5 add-agent → `.worktrees/dev` 不存在 → `team_dispatch_execute` 的 P140 工作树守卫（`cmd-agents.sh` `team_dispatch_judge_worktree_present`）拒发、一个字节都不写。手工复跑原文：`✗ worktree 不存在：…/.worktrees/dev（skill 不代做 git）` + `✗ 共 1 个阻塞项`，夹具 state/ 里既无 `dev.env` 也无 `dispatch-dev.attempts.log` | 选段闭包（P238） |
| 3 | `digest 仍把崩溃 agent 算成待办` | 红 | 绿 | 同 #2（记录不存在，digest 无从显示） | 选段闭包（P238） |
| 4 | `死窗口释放模型槽位（RUNNING=0）` | 红 | 绿 | 同 #2（`dev.env` 不存在 → 读不到 model） | 选段闭包（P238） |
| 5 | `resume --dry-run 能识别待续跑任务` | 红 | 红（真回归） | 7 段选集里是 #2 的连带（没有记录）；**12 段选集里是产品回归**：routing 合并把 `printf '  %s 可续跑：%s → %s\n'` 换成了 `team_cmd_dispatch … --print`（`cmd-watch.sh` `team_cmd_resume` dry 分支），既有输出契约（workflows.md「the PM looks for itself」+ 11c/6k⑥/M9.3-③ 三条断言）随之丢失 | **本任务已修** |
| 6 | `resume 重新派单` | 红 | 绿 | 同 #2（没有记录）；12 段选集里 `resume.log` 有 `续跑 dev · T1.1`，派单本身是好的 | 选段闭包（P238） |
| 7 | `resume 后 dev 窗口回来了` | 红 | 绿 | 同 #2/#6 | 选段闭包（P238） |
| 8 | `up --agents 才会续跑 agent` | 绿（v0.1.2 同命令下绿） | 红（真变化） | routing 合并在 `team_cmd_up` 的 tmux 阶段**之前**加了 `team_pm_identity_guard`（`cmd-watch.sh:160`，守卫本体 `common.sh:2563`）：夹具的 PM 从未走过受守卫的启动路径，`state/pm-launch.env` 不存在，而 `TEAM_PM_SESSION_ID` 为空 → continuity 是 `continued:pi -c` → 守卫拒绝并 `return 1`，**连 `--agents` 那步都没走到**。夹具里 `up --agents` 的全部输出只有两行：`teamsmith up · repo（只负责 PM）` + `✗ PM launch identity missing/changed（含 suffix）…` | 新 PM 身份合同是**规格要求**（`openspec/changes/task-model-routing/specs/pm-lifecycle/spec.md`：Missing/legacy/unknown manual-start metadata refuses continuation）→ 夹具要改（P238） |
| 9 | `（假 pi 秒退：up 同时也如实报了 PM 没起来）` | 绿 | 红（真变化） | 同 #8（守卫在 `team_pm_start` 之前就返回了，所以没有「PM 启动失败」那一行） | 夹具要改（P238） |
| 10 | `32⑧c 派单失败` + `worker 窗口的 env 没落盘` | 绿（`✓73 ✗0`） | 红（真变化） | §32 的夹具手写一份 brief：`# M40W 夹具 brief` + `anchor: none (infra) — smoke fixture`，**没有 `category:` 头**；新合同要求「brief 必须唯一 category: header」，`team_dispatch_select_identity` 在预检就拒发。`--select 32 --keep` 的 `8c-dispatch.log` 原文阻塞项：`✗ brief 必须唯一 category: header；显式 override 不豁免` | 新合同是**规格要求**（dispatch delta：Missing/duplicate/malformed 一律拒发）→ 夹具加一行 `category: routine`（P238） |

关于 #8/#9 我要把话说清楚：**「PM 身份缺失就拒绝续跑」是已验收规格的一部分**，不是合并的失误。夹具没有为它准备现场（没让 PM 走过受守卫的启动、没落 `state/pm-launch.env`），所以这两条断言现在验的是新合同，不再是「假 pi 秒退」那个形状。修法在夹具侧（让夹具的 PM 先经受守卫路径启动一次，两条断言就能照旧真验，不需要削弱）；**不建议**把 `up --agents` 改成「PM 守卫拒绝但仍续跑 agent」——那是产品行为变更，要新 spec delta，而且与「refusal 不产生任何进程副作用」这句冲突。这一条我给 PM 决策，默认按夹具改。

## Flip evidence（缺陷修复必备）

同一份夹具现场（12 段选集跑完留下的 `/tmp/p240-ev2/teamsmith-smoke.6ashrU`，`dev.env` 与工作树都在），只换被跑的代码树：

```
$ … team resume --dry-run        # 树 = /tmp/p240-before（e897a7d，修前）
=== agent 命令（adapter: built-in (Pi)）===
=== 提示词（4190 字） ===
RC=0
state_fp_before=773877beac5ce0ba8f39e6cafccd215cb675c4bf2f283026b0aeba82ef252a8e
state_fp_after =773877beac5ce0ba8f39e6cafccd215cb675c4bf2f283026b0aeba82ef252a8e
（没有「可续跑」清单行 → §11c 的 assert_has 红）

$ … team resume --dry-run        # 树 = /tmp/p240-fix（36cba2b，修后）
  dev 可续跑：T1.1 → /evidence/teamsmith-smoke.6ashrU/repo/docs/team/tasks/T1.1-smoke-task.md
=== agent 命令（adapter: built-in (Pi)）===
=== 提示词（5141 字） ===
RC=0
state_fp_before=773877beac5ce0ba8f39e6cafccd215cb675c4bf2f283026b0aeba82ef252a8e
state_fp_after =773877beac5ce0ba8f39e6cafccd215cb675c4bf2f283026b0aeba82ef252a8e
（清单行回来了；两次 state/ 指纹逐字节相同 → dry-run 依旧不写盘）
```

（提示词字数 4190 → 5141 的差是另一个产品提交 `14499ed`（提示词的三态合同）带来的，与本次改动无关。）

再补一条**破坏实现**的对照：把新增的那行从交付 tip 里删掉（变异树 `/tmp/p240-mut`），同选集重跑：

```
#10 11c · agent 续跑是 PM 的事（pulse 不碰） · 用时 19s · ✓12 ✗4
  ✗ resume --dry-run 能识别待续跑任务（…/resume-dry.log 中找不到 [可续跑：T1.1]）
== 选段结果 ==  ✓ 231  ✗ 6      （交付 tip 是 ✓232 ✗5）
```

即那条断言确实由这一行承重，不是橡皮章。

## Decisions and deviations

- 任务书要求的「修后 0 红」我**没有做到，也认为不该由本任务做到**：那 8 条红的主因是选段闭包（`section-paths.tsv` 的 `11c` 行没声明 §5）与两条新合同夹具，都落在 P238 的写集合里，任务书第 5 条要求这种情况下先 `BLOCKED:` 而不能并行改同一文件。产品侧我做到了能做的全部（那 1 条真回归）。
- 没有改任何断言、没有 skip、没有动夹具。
- 没有跑全量门禁（任务书只要求上述验收 + routing 组；PM 的 wrap-up 全量门禁在跑）。**本次跑到的段**：`0 0b 0c 0d 2 4 5 3b 6 11c 13 32`（12/125 段）与 routing 套件的 `dispatch,resume,transaction,pm,config` 五组。**没跑**：其余 113 个 smoke 段、其余 8 个 routing 组、`--flip` 变异套件。
- 我另算了改动路径的选段面 `section-select.sh --paths skills/teamsmith/scripts/lib/cmd-watch.sh` = 48 段，也没跑（本次改动是 dry-run 分支的一行 printf，与那些段无关；PM 的 wrap-up 门禁覆盖它们）。
- 交付树 tip 含 `e897a7d` 之后的另一个产品提交 `14499ed`（提示词三态），所以「修前/修后」的 ✓ 计数差里有一部分不是本次改动；红数差（`✗6 → ✗5`，§11c `✗4 → ✗3`）才是本次改动的效果，逐条可对照。

## Suggested next steps

- 复验请用 **v0.1.2 这批绿基线**对照（任务书要求）：同选集 `--select 6,13,32,11c` 在 v0.1.2 上是 `✓230 ✗1`，本 tip 是 `✓232 ✗5`；两边的差集就是上面表里的 #1（既存）、#8/#9（新合同夹具）、#10（新合同夹具）。
- 若要我继续：把 #8/#9/#10 与闭包缺口一起交给我和 P238 的边界都行，但**不能同时改 `smoke.sh`/`section-paths.tsv`**，得等 P238 落地或由 PM 明确把这几处划给我。

BLOCKED:（按任务书第 5 条的边界交回，全部落在 `skills/teamsmith/tests/`，即 P238/dev-bob 的写集合）

1. **`section-paths.tsv`：`11c` 的 needs 缺 `5`。** 判据与 §6 那一行同源（§5 建的 `.worktrees/dev` 是 §11c 的现场前提；§6 行自己写着「--select 6 ✗15 → 补 5 ✗0」）。另外 §11c 调用了定义在 §11b3 段内的 `wait_window_gone`，闭包不含 §11b3 → 也要加进 needs，或把该 helper 挪进前导段。改完 `--select 11c` 才可能绿（现在 v0.1.2 也是 `✓75 ✗8`）。
2. **`smoke.sh` §11c**：`up --agents` 的两条断言要按新的 PM 身份合同补夹具现场（夹具里让 PM 先经受守卫路径启动、落 `state/pm-launch.env`），两条断言都能照旧真验；**不要**删/弱化。若 PM 决定改成「PM 守卫拒绝时也继续续跑 agent」，那是产品行为变更 + spec delta，需要另派。
3. **`smoke.sh` §32⑧c**：夹具 brief 加一行 `category: routine`（映射里已有；新合同要求唯一 category 头才允许派单）。同段的 `anchor: none (infra)` 保留。
4. **同类（全量门禁里可见，本次选段没跑到）**：§6k⑥ 与 M9.3-③ 用的是手写的**旧格式记录**（`task=/window=/taskfile=`，且 brief 落在 `$TMP` 项目外）；新合同下这类身份必须走 `--fresh` 接管，`resume --dry-run` 也会打印拒绝原因。这两段的夹具要改成新记录 + 项目内 brief；我这次修好清单行后，它们的 `可续跑` 断言会恢复，但同一段里「续跑被叠任务守卫误拦 / 照旧打印派单计划」那几条仍会红，属同一族夹具更新。
5. **旁注（不阻塞，PM 判断）**：§11b4 的渲染探针只 source `common.sh`，而 `team_config_model_violation` 定义在 `cmd-config.sh`（CLI 会把 `lib/cmd-*.sh` 全部 source，产品路径不受影响）→ 全量门禁日志里会出现 `command not found` 与空的 `TEAM_TASK_MODELS:` 理由。这是探针加载面的问题，要么夹具按 `m36_lib` 那样 source 全部 lib，要么把模型判定下沉到 `common.sh`（产品侧取舍，我倾向后者只作为后续可选项）。
