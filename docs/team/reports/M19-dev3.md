# M19 · PM 启动指引缺口：pulse 没在跑要明说拉起来（SKILL.md + AGENTS 模板）

agent: dev3   status: done   time: 2026-09-17T08:15Z
branch: `task/M19-pm-pulse-skill-md-agents`   PR/MR: -（local 模式：不 push，分支留在 `.worktrees/dev3`，PM 复验后本地合并）

## Deliverables

| Path | What |
|---|---|
| `skills/teamsmith/SKILL.md:99` | 启动清单引用块里加一行动作指引：`team pulse status` 之后明确「没在跑且不在待命 → 拉起（`team pulse up`）；待命时不动」。一句话，未展开 |
| `skills/teamsmith/templates/AGENTS.section.md.tmpl:98-99` | "Periodic patrol" 一节新增 bullet **Bring it up at session start**：pulse 没在跑且未待命时 `team pulse up` 是 PM 的职责，`standby on` 时不动 |
| `AGENTS.md`（本仓库） | 用 `team init` 重渲染 teamsmith 段（改名后文案 + 新 bullet）；`git diff` 只落在 `<!-- teamsmith:begin -->`…`<!-- teamsmith:end -->`（1–131 行）之内 |

两个提交（分支 tip = `82a7e10`）：

```
409e74e docs(teamsmith): M19 say who starts the pulse at session start
82a7e10 docs(team): M19 re-render the teamsmith section (pulse rename catch-up)
```

## Verification evidence (must have actually been run)

```
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
Totals: 13 passed, 0 failed (13 items)

$ bash skills/teamsmith/tests/smoke.sh            # 全量，08:08:54 → 08:15:18
== 结果 ==  ✓ 1827  ✗ 0        (rc=0)

$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh
== 结果 ==  ✓ 1424  ✗ 0        (rc=0)

$ grep -n "pulse up" skills/teamsmith/SKILL.md
80:| Patrol (pulse) | `team pulse up\|down\|restart\|status\|logs` …（P8 起就有的表行，非本次改动）
99:> If the pulse is not running and you are not on standby, bringing it up (`team pulse up`) is part of your job; on standby, leave it alone.   ← 新增的启动清单行
232:- **The pulse is configured by the PM**: `team pulse up` runs …（原有）
284:- **No container dependency**: … (`team pulse up`).（原有）

$ grep -n "pulse up" skills/teamsmith/templates/AGENTS.section.md.tmpl
95:- **The PM owns the pulse**: `team pulse up|status|logs|down` …（原有行，见下方说明）
98:- **Bring it up at session start**: if the pulse is not running and you are not on standby, `team pulse up` is part of
99:  the PM's job -- no one else will do it; while `standby on` is set, leave it alone.   ← 新增 bullet

$ grep -c "watchdog" AGENTS.md
1
106:  pulse stops waking it (backlog still lands in `state/watchdog.log`). A human runs `team standby off`.
```

- Verdict: pass
- Notes:
  - 模板那条 grep 是**弱检查**：第 95 行原有的 `team pulse up|status|logs|down` 就已经命中，修前也会「通过」。所以新 bullet 的位置与内容单独列出（第 98–99 行），报告末尾的翻转证据也以它为准。
  - `AGENTS.md` 里仅剩的 1 处 `watchdog` 是**真实状态文件名** `state/watchdog.log`（实现：`cmd-watch.sh:12 team_watch_log()` → `$TEAM_STATE_DIR/watchdog.log`；别名期不随 CLI 改名，符合任务书「别名期 CLI 名除外逐行说明」）。
  - `team init` 幂等：`.pi/team/config.sh`、`docs/team/{BOARD,ROADMAP,OWNERSHIP,DECISIONS,PROTOCOL}.md`、`threads/README.md`、`.gitignore` 全部 skip，只有 `AGENTS.md` 段落被刷新（日志见下）。
  - 未验证项：无。未改 `pm-prompt.md.tmpl`、未碰 `scripts/**`、未加任何「代码级自动拉起 pulse」的行为。

`team init` 的实际输出（节选）：

```
teamsmith init → <home>/Documents/syncthing/Work/Projects/pm-skills/.worktrees/dev3
skip  …/.pi/team/config.sh（已存在，--force 覆盖）
skip  …/docs/team/BOARD.md（已存在）
skip  …/docs/team/ROADMAP.md（已存在）
skip  …/docs/team/OWNERSHIP.md（已存在）
skip  …/docs/team/DECISIONS.md（已存在）
skip  …/docs/team/threads/README.md（已存在）
skip  …/docs/team/PROTOCOL.md（已存在）
✓ update …/AGENTS.md（协议段落已刷新）
skip  .gitignore
```

### 重渲染等价性自检（证明 sed 规范化没有夹带别的变化）

`team init` 渲染 `{{SKILL_DIR}}` 用的是**调用方 checkout** 的技能目录（见"偏差"一节）。规范化路径后，我另跑一次 `team_render`（同一模板 + 本项目的真实取值）与文件里的段落逐字节对比：

```
$ sed -n '/<!-- teamsmith:begin -->/,/<!-- teamsmith:end -->/p' AGENTS.md > /tmp/M19-section-with-markers.txt
$ env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_SKILL_DIR -u TEAM_SESSION bash -c '… team_render \
    skills/teamsmith/templates/AGENTS.section.md.tmpl \
    "PROJECT=pm-skills" "DOCS_DIR=docs/team" "SESSION=teamsmith" "PM_WINDOW=pm" \
    "SKILL_DIR=<repo-main>/skills/teamsmith" "AGENTS=dev verify dev2 dev3" \
    "GATES=$(team_detect_gates)" "WORKTREES_DIR=.worktrees" "PROTECTED_BRANCH=main"' > /tmp/M19-section-canonrender.txt
$ diff /tmp/M19-section-with-markers.txt /tmp/M19-section-canonrender.txt
IDENTICAL ✓   （131 行 vs 131 行，零差异）
```

## Flip evidence (文档任务的等价物：改前红 / 改后绿)

**① SKILL.md 启动清单行** —— 改前只有"看状态"，没有任何动作（红）；改后带动作（绿）：

```
$ git show ec2b502:skills/teamsmith/SKILL.md | sed -n '99p'     # 改前
> Division of labour: **the pulse is a metronome** ("is there work?" every 15 minutes by default): it wakes you

$ sed -n '99p' skills/teamsmith/SKILL.md                        # 改后
> If the pulse is not running and you are not on standby, bringing it up (`team pulse up`) is part of your job; on standby, leave it alone.
```

**② AGENTS 模板 Periodic patrol** —— 改前只有"谁拥有 pulse"（不告诉启动是职责）；改后多一条：

```
$ git show ec2b502:skills/teamsmith/templates/AGENTS.section.md.tmpl | sed -n '95,97p'   # 改前：bullet 列表到 "There is exactly one backend …" 就结束
- **The PM owns the pulse**: `team pulse up|status|logs|down` -- by default it runs `team monitor` in a
  `pulse` window of the same tmux session (…) and patrols
  on an interval. There is exactly one backend (that window) -- no container, no systemd.

$ sed -n '95,99p' skills/teamsmith/templates/AGENTS.section.md.tmpl                      # 改后
- **The PM owns the pulse**: … no container, no systemd.
- **Bring it up at session start**: if the pulse is not running and you are not on standby, `team pulse up` is part of
  the PM's job -- no one else will do it; while `standby on` is set, leave it alone.
```

**③ `team init` 前后的 AGENTS.md diff（关键段）** —— 可见改动全部在 teamsmith 段内：

```diff
@@ -1,7 +1,7 @@
-This project runs a team of agents: a **PM (orchestrator)** in tmux `pm-skills:pm` owns tasks and merge
+This project runs a team of agents: a **PM (orchestrator)** in tmux `teamsmith:pm` owns tasks and merge
@@ -12,7 +12,7 @@
-Roster: dev verify dev2 (editable in `.pi/team/config.sh`).
+Roster: dev verify dev2 dev3 (editable in `.pi/team/config.sh`).
@@ -57,7 +57,7 @@
-      │  on turn end, automatically: appends docs/team/inbox/<agent>.md + knocks pm-skills:pm
+      │  on turn end, automatically: appends docs/team/inbox/<agent>.md + knocks teamsmith:pm
@@ -74,7 +74,7 @@
-… # idempotent: config + docs skeleton + worktrees + watchdog window + next steps
+… # idempotent: config + docs skeleton + worktrees + pulse window + next steps
@@ -90,22 +90,24 @@
-The watchdog is a **metronome that wakes the PM**, …
+The pulse is a **metronome that wakes the PM**, …
-- **The PM owns the watchdog**: `team watchdog up|status|logs|down` … in a `watchdog` window …
+- **The PM owns the pulse**: `team pulse up|status|logs|down` … in a `pulse` window …
+- **Bring it up at session start**: if the pulse is not running and you are not on standby, `team pulse up` … while `standby on` is set, leave it alone.
-- Every **15 minutes** … (`TEAM_WATCH_INTERVAL=900`, …)
+- Every **15 minutes** … (`TEAM_PULSE_INTERVAL=900`, …)
-  watchdog stops waking it (backlog still lands in `state/watchdog.log`)…
+  pulse stops waking it (backlog still lands in `state/watchdog.log`)…
-bash <skill>/scripts/team watchdog-status      # interval / standby / pending / PM state
+bash <skill>/scripts/team pulse status        # interval / standby / pending / PM state
```

`git diff --stat`（相对基线 `ec2b502`）：

```
 AGENTS.md                                         | 22 ++++++++++++----------
 skills/teamsmith/SKILL.md                         |  1 +
 skills/teamsmith/templates/AGENTS.section.md.tmpl |  2 ++
 3 files changed, 15 insertions(+), 10 deletions(-)
```

## Decisions and deviations

- **`team init` 的调用方式（重要）**：`team init` 把渲染结果写到 `$TEAM_MAIN_ROOT/AGENTS.md`，而 `TEAM_MAIN_ROOT` 默认解析到**主工作树** —— 从这里直接跑会改主工作树（红线：不碰主工作树），而且改动落在主工作树里也没法提交到本分支。因此用 `TEAM_MAIN_ROOT="$PWD"` 把输出钉在本工作树。
- **真实取值而非硬编码默认值**：`team init` 不读配置里的 `TEAM_SESSION`/`TEAM_AGENTS`，无参数时会渲染成 `$(basename TEAM_MAIN_ROOT)`/"dev verify"（我实测过一次：会写成 `dev3:pm` + roster `dev verify`）。所以显式传 `--session teamsmith --agents "dev verify dev2 dev3"` —— 取的就是本仓库 `.pi/team/config.sh`（第 8、12 行）里的真实值。副效果是顺手把文档里两处过期值改对：`pm-skills:pm` → `teamsmith:pm`（实际 session 就是 teamsmith，`tmux ls` 可证）、roster 补上 dev3（ceccf9c 已改名册）。**如果 PM 认为这两行不该动，回退它们即可，与改名文案无关。**
- **`{{SKILL_DIR}}` 规范化（7 处）**：init 用**调用方 checkout** 的技能目录渲染这个值，直接提交会把文档指向 `.worktrees/dev3/…`（工作树删了就断）。渲染后把这 7 处取值改写为仓库主路径，并用「同模板 + 同取值重渲染后逐字节 diff」证明改写后的段落就是标准渲染结果（见上，IDENTICAL）。
- 报告路径按派单提示写 `M19-dev3.md`（任务书正文写 `M19-dev.md`；本任务实际在 dev3 名下，BOARD 行 M19 标的是 `dev`，`team review M19` 按 `reports/M19-*.md` 取候选）。
- 只改了任务书点名的三个文件 + 本报告；`pm-prompt.md.tmpl`、`scripts/**` 未动，未加代码级自动拉起。

## Suggested next steps

- PM 复验：独立 checkout 上跑 `openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh`；本分支 `82a7e10` 可直接本地合并。
- **值得单独立项的上游问题（本次未改代码）**：`team init` ① 渲染路径写死 `$TEAM_MAIN_ROOT`（在 worktree 里跑就会改主工作树，PM 之外的执行者要么越界、要么得覆盖变量）；② 忽略已加载配置里的 `TEAM_SESSION`/`TEAM_AGENTS`（无参数时回落到硬编码默认值），这正是本仓库 AGENTS.md 漂移成 `pm-skills:pm` / `dev verify dev2` 的原因；③ `{{SKILL_DIR}}` 用调用方 checkout 路径而不是项目主路径。三条都在 `scripts/**`（PM 独占），建议写成一条维护任务。
- 与 M18 合起来才闭环：M18 修信号（digest 如实显示 pulse 在不在跑），M19 修指引（没在跑就拉起来）—— 两条都进 `main` 后，用户手动注入 skill 的会话应当自己把 pulse 拉起来。
