# P36 · PM 会话交接：`team up --fresh-pm` + init 交接段 + 同 cwd 活会话提示

agent: dev2   status: DONE（A/B/C 实现 + smoke 夹具 + 文档 + 翻转证据；本地模式，未 push）
branch: `task/P36-pm-fresh-pm-init-cwd`   PR/MR: -（local 模式：分支留在本地 worktree，PM 复验后本地合并）
task:   P36   phase: apply
change: -     specs: -     anchor: `pm-lifecycle#PM liveness is proven, not inferred`（本次不改判活语义，只是复用它旁边的 /proc 只读助手）
verdict: 三项全做；A 的裁断写进 `team help`；C 只提示不阻断且不改 M6.5；翻转 4+3 条红、还原后 37/0 绿；门禁见 §6

## 0. 结论（一句话）

`team up --fresh-pm` 现在能明确地**只给这一次启动**开一场新对话（不 `-c`、不 `--session-id`、模板路径
`{resume_args}` 渲染为空；不写配置、不改变巡检/守护按配置拉起的行为），`--print` 会先打出「会话判定」与渲染出的
完整命令；init skill 的交接写成了三步（bootstrap → 退出本会话 → `team up [--fresh-pm]`）；`team up` 在真的要启动
PM 之前会用只读 `/proc` 探测同 cwd 的活 PM CLI 会话，命中就点名 pid 并给出两条出路，**不阻断**、也不碰 M6.5 的
判活/替换语义。

## 1. 交付内容（Deliverables）

| Path | What |
|---|---|
| `skills/teamsmith/scripts/lib/common.sh` | `team_pm_fresh_launch()`（本次启动旋钮）+ `team_pm_pi_args` 的 fresh 分支 + `team_pm_continuity` 的 `fresh:` 分支 + `team_pm_continuity_note` 的新会话文案；`team_agent_expand` 的 `{resume_args}` 在 fresh 下渲染为空；C 的只读探测器 `team_pm_other_sessions_in_dir()`（`ps` 粗筛 + `/proc/<pid>/cwd` + `team_proc_cmdline_is_bin`，复用 M39 的 args 快照） |
| `skills/teamsmith/scripts/lib/cmd-watch.sh` | `team_cmd_up` 解析 `--fresh-pm`、导出 `TEAM_PM_FRESH_LAUNCH=1`；`--print` 追加「—— 本次启动 —— / 会话判定：… / 完整命令：…」；启动前在 idle/unknown/foreign(force) 三条路径调 `team_pm_same_dir_warn`；running 时说明 `--fresh-pm` 不影响已在跑的 PM |
| `skills/teamsmith/scripts/lib/cmd-project.sh` | `team help` 的 `up` 行：新旗标 + 优先级裁断 + 「只影响这一次启动」 |
| `skills/teamsmith-init/SKILL.md` | `## 2. Handoff` 改为明确的交接三步（含 `--fresh-pm` 与同目录提示的含义） |
| `skills/teamsmith/references/troubleshooting.md` | §15 两行：`--fresh-pm` 的一次性裁断；同 cwd 提示的成因/出路；并说明 `--print` 打判定与完整命令 |
| `skills/teamsmith/tests/smoke.sh` | 新增 `§11b4 · PM 交接：--fresh-pm 与同 cwd 活会话提示（P36）`（①`--print` 快慢都跑，②③真跑对照，④⑤C 正反向，段尾还原现场）；14c 的 FAST 跳过表补条目 |
| `docs/team/reports/P36-dev2/pkg/p36-checks.sh` | 可独立复跑的翻转/证据夹具（私有 tmux server + 临时仓库，37 条断言，`== 结果 ==` 汇总） |
| `docs/team/reports/P36-dev2/pkg/out/**` | 夹具原始输出（基线绿 / 翻转 A 红 / 翻转 C 红 / 还原绿）与全量门禁日志 |

## 2. A：`team up --fresh-pm`

### 2.1 裁断（写进 `team help` 的 up 行）

```text
  up [--agents] [--print] [--fresh-pm]
                 恢复 PM：建 tmux 场地 + 把 PM 拉起来（默认 pi -c 续上本目录上一个会话）
                 --fresh-pm = 本次启动新开一场对话（不 -c；旧会话文件原样留在历史里，作为开工记录）；
                 它最优先：这一次启动里 TEAM_PM_SESSION_ID / TEAM_PM_RESUME_ARGS 都不生效，且只影响
                 这一次启动、不写进配置（守护/巡检按配置拉起 PM 时照旧续跑；--print 会打出判定与命令）
```

- **优先级裁断**：`--fresh-pm`（本次、显式、人刚敲的）> `TEAM_PM_SESSION_ID` > `TEAM_PM_RESUME_ARGS` > 历史 `-c`。
  理由：配置键是长期默认值，旗标是「就这一次」的人造意图；与 dispatch/resume 的 `--fresh` 同族
  （只影响这一次、不写配置）。`team_pm_start` 只被这一次 `up` 调用，旗标由 `team_cmd_up` 导出，
  进程退出即消失 —— 巡检/守护的启动命令里没有它。
- **实现落点**：`team_pm_fresh_launch()` + `team_pm_pi_args`（本次跳过 `-c`/`--session-id`/resume 参数）+
  `team_agent_expand` 的 `{resume_args}`（模板路径本次渲染为空）+ `team_pm_continuity` 的 `fresh:` 分支
  （成功文案与 `--print` 共用同一判定）。
- **模板路径的边界（写清）**：`{session_id}` 是**身份**而不是续跑开关 —— 按
  `references/agent-adapters.md` 的契约，CLI 自己的续跑参数走 `TEAM_PM_RESUME_ARGS` + `{resume_args}`。
  所以 `--fresh-pm` 只把 `{resume_args}` 渲染为空，不动 `{session_id}` 的值（把它清空会破坏
  `--session-name {session_id}` 这类把 id 当身份的模板）。

### 2.2 `--print` 证据（原始输出，夹具 `/tmp/p36-probe.rEgtDz/repo`；`pkg/out/2a-print-continued.txt`、`2b-print-fresh.txt`）

```text
$ bash skills/teamsmith/scripts/team up --print | tail -3

—— 本次启动 ——
会话判定：continued:pi -c（本目录上一个会话）
完整命令：… cd /tmp/p36-probe.rEgtDz/repo && printf "%s\n" $$ > …/pm.pid.spawn && exec pi \
  --provider deepseek --model deepseek-flash -e …/team-bg.ts -e …/team-inbox-watch.ts \
  --skill …/teamsmith -c  @…/state/pm-prompt.md
```

```text
$ bash skills/teamsmith/scripts/team up --print --fresh-pm | tail -3

—— 本次启动 ——
会话判定：fresh:--fresh-pm（本次启动新开会话，不带 -c；旧历史留在原会话文件里）
完整命令：… cd /tmp/p36-probe.rEgtDz/repo && printf "%s\n" $$ > …/pm.pid.spawn && exec pi \
  --provider deepseek --model deepseek-flash -e …/team-bg.ts -e …/team-inbox-watch.ts \
  --skill …/teamsmith  @…/state/pm-prompt.md          ← 没有 -c（两个空格就是省略的旗标位置）
```

### 2.3 真跑证据（`pkg/out/1-baseline-green.log` 节选，专用假 PM 参数逐行落盘）

```text
== 20 · A：真跑（--fresh-pm 不带 -c；默认带 -c） ==
  ✓ 20-① pm 窗口在 idle（idle:bash）
  ✓ 20-② team up --fresh-pm 退出码 0
  ✓ 20-③ --fresh-pm 真的把 PM 拉起来了
  ✓ 20-④ 成功文案说这是新开会话
  ✓ 20-⑤ 假 PM 把参数落盘了
  ✓ 20-⑥ --fresh-pm 的命令行没有 -c          ← 原始 argv 里没有 -c（不是只看标签）
  ✓ 20-⑦ 提示词照旧走 @文件
  ✓ 20-⑧ --fresh-pm 起出的 PM 判定为 running
  ✓ 20-⑨ pm 窗口回到 idle（idle:bash）
  ✓ 20-⑩ 默认 team up 退出码 0
  ✓ 20-⑪ 默认成功文案说续用 -c
  ✓ 20-⑫ 假 PM 把默认那一轮的参数落盘了
  ✓ 20-⑬ 默认那一轮真的带 -c（⑥的对照）       ← 对照组：不加旗标时 -c 还在
== 20 结果 == ✓ 13 ✗ 0
```

### 2.4 `--print` 与模板路径（`pkg/out/1-baseline-green.log` §10）

```text
  ✓ 10-① up --print 退出码 0
  ✓ 10-② 默认明说这一次续用 -c
  ✓ 10-③ 默认渲染出的命令带 -c
  ✓ 10-④ up --print --fresh-pm 退出码 0
  ✓ 10-⑤ --fresh-pm 的判定是 fresh:
  ✓ 10-⑥ fresh 时不再说续跑
  ✓ 10-⑦ fresh 渲染出的命令不带 -c
  ✓ 10-⑧ fresh 仍带 @提示词文件
  ✓ 10-⑩ --fresh-pm 压过 TEAM_PM_SESSION_ID
  ✓ 10-⑪ --fresh-pm 压过 TEAM_PM_RESUME_ARGS
  ✓ 10-⑫ 模板路径默认把 {resume_args} 渲染出来
  ✓ 10-⑬ --fresh-pm 下模板路径的 {resume_args} 渲染为空
== 10 结果 == ✓ 12 ✗ 0
```

## 3. C：同 cwd 活会话提示

### 3.1 口径

- 探测器 `team_pm_other_sessions_in_dir <dir>`：`ps -ww -eo pid=,args=` 一次粗筛（argv 里出现 PM 可执行
  文件 basename）→ `team_proc_cmdline_is_bin`（精确判 argv，且**排除我们自己的启动 harness**）→
  `team_proc_cwd` 必须等于该目录（canonicalize）→ 输出 pid。
- **只读**：不写 state、不写日志、不改 `team_pm_state` / `team_pm_alive`、不改变 `unknown/foreign/idle`
  的替换语义；只在 `team up` 真的要启动 PM 的三条分支（`idle` / `unknown` / `foreign` + `TEAM_REPLACE_FOREIGN_PM=1`）
  里调用；`running`/`starting` 时不探测（没有启动发生）。
- **不阻断**：提示后照常 `team_pm_start`。

### 3.2 正向/反向原始输出（`pkg/out/1-baseline-green.log` §30）

```text
== 30 · C：同 cwd 活会话提示（正向/反向） ==
  ✓ 30-① pm 窗口在 idle（idle:bash）
  ✓ 30-② 夹具进程的 cwd 真的在项目根（探测前提）
  ✓ 30-③ 有同 cwd 活会话时 up 退出码 0（提示不阻断）
  ✓ 30-④ 同 cwd 有活 PM CLI 会话 → 打提示
  ✓ 30-⑤ 提示点名了那个 pid
  ✓ 30-⑥ 提示给出出路（--fresh-pm）
  ✓ 30-⑦ 提示不阻断（PM 照常启动）
  ✓ 30-⑧ pm 窗口回到 idle（idle:bash）
  ✓ 30-⑨ 反向前提：同 cwd 已经没有 PM CLI 进程
  ✓ 30-⑩ 反向用例 up 退出码 0
  ✓ 30-⑪ 没有同 cwd 活会话时不打提示
  ✓ 30-⑫ 反向用例里 PM 照常启动
== 30 结果 == ✓ 12 ✗ 0
```

提示原文（`team up` 的 stderr，节选）：

```text
! 检测到同目录（/tmp/p36-flip.XXXXXX/repo）还有 1 个活着的 pi 会话：pid 3998882
!   默认的 -c 按目录续上一个会话：两个进程同时写同一个会话文件，可能互相覆盖
  建议：先退出它；或者在干净的新会话里跑 team up --fresh-pm（本次新开一场对话）
```

### 3.3 「不算 PM 判活」的旁证

- 探测用的助手与判活助手**不同源**：`team_pm_state` / `team_pm_alive` 一行未改（`git diff` 里可核对，
  本次只新增函数与调用点）。
- ④ 现场里 `team up` 的判定仍然是 `running:*`（PM 真的起来了），提示只多打三行，退出码 0；
  ⑤ 现场里没有同 cwd 进程时同样的 `team up` 不再打印提示。
- `--print` 不调用探测器（它不启动任何东西），所以「正常项目里 `--print` 对正在跑的 PM 误报」不会发生。

## 4. B：init skill 的交接段（改后原文）

`skills/teamsmith-init/SKILL.md` 的 `## 2. Handoff`：

```markdown
The handover itself is three steps, and the middle one is the one people skip:

1. **Bootstrap.** `bash <teamsmith>/scripts/team bootstrap [--agents "dev verify"]` — it prints the plan first
   with `--print`, and a rerun is idempotent.
2. **Leave the room — or prove you are the PM.** `team up` starts the PM in this project's tmux session, and the
   PM is a *different* conversation from this one. Exit this session once bootstrap is done (keep it only if this
   session already lives in the PM window).
3. **Start the PM.** `bash <teamsmith>/scripts/team up [--fresh-pm]`. By default `up` continues **the last
   conversation in this directory** (`pi -c`) — which is *this init conversation*, so the PM wakes up with the
   init history. Add `--fresh-pm` to start the PM on a clean conversation instead (the old session file stays in
   history as the kickoff record); it wins over `TEAM_PM_SESSION_ID` / `TEAM_PM_RESUME_ARGS` for that one launch
   and is not written into the config. `team up --print` shows the decision and the exact command.

   If step 3 prints `检测到同目录 … 还有 … 活着的 … 会话`, a session started in this directory is still running:
   exit it first, or rerun with `--fresh-pm` — continuing one session from two processes at once would have both
   write the same session file.
```

（同一节首段仍保留「day-to-day 在 `teamsmith` skill」的指向；文件 86 行，仍低于 init-skill spec 的 100 行上限。）

## 5. 翻转证据（红 → 绿，原始输出）

夹具：`bash docs/team/reports/P36-dev2/pkg/p36-checks.sh`（私有 tmux server + 临时仓库，37 条断言）。

### 5.1 基线（实现原样）绿

```text
== 10 结果 == ✓ 12 ✗ 0
== 20 结果 == ✓ 13 ✗ 0
== 30 结果 == ✓ 12 ✗ 0
== 结果 == ✓ 37 ✗ 0
RC=0
```

### 5.2 红①：去掉 `--fresh-pm` 的分支

```sh
sed -i 's/^  if team_pm_fresh_launch; then :$/  if false; then :/' skills/teamsmith/scripts/lib/common.sh
sed -i 's/&& team_pm_fresh_launch; then val=""/\&\& false; then val=""/' skills/teamsmith/scripts/lib/common.sh
```

```text
  ✗ 10-⑦ fresh 渲染出的命令不带 -c（不该出现 [ -c ]）
  ✗ 10-⑩ --fresh-pm 压过 TEAM_PM_SESSION_ID（不该出现 [--session-id]）
  ✗ 10-⑬ --fresh-pm 下模板路径的 {resume_args} 渲染为空（不该出现 [--continue]）
== 10 结果 == ✓ 9 ✗ 3
  ✗ 20-⑥ --fresh-pm 的命令行里出现了 -c
== 20 结果 == ✓ 12 ✗ 1
== 结果 == ✓ 33 ✗ 4
RC=1
```

注意 10-⑤/⑥（标签断言）在翻转下**仍然绿**：红的只有「渲染出的命令 / 真实 argv」那几条 —— 说明测试
钉的是行为而不是文案。

### 5.3 红②：去掉 C 的探测

```sh
sed -i 's|^  pids="\$(team_pm_other_sessions_in_dir "\$TEAM_MAIN_ROOT")"$|  pids=""   # FLIP-C：探测被摘掉|' \
  skills/teamsmith/scripts/lib/cmd-watch.sh
```

```text
  ✗ 30-④ 同 cwd 有活 PM CLI 会话 → 打提示（… 中找不到 [检测到同目录]）
  ✗ 30-⑤ 提示点名了那个 pid（… 中找不到 [pid 3998882]）
  ✗ 30-⑥ 提示给出出路（--fresh-pm）
== 30 结果 == ✓ 9 ✗ 3
== 结果 == ✓ 34 ✗ 3
RC=1
```

### 5.4 还原 → 绿，工作树干净

```sh
git checkout -- skills/teamsmith/scripts/lib/common.sh skills/teamsmith/scripts/lib/cmd-watch.sh
```

```text
$ git status --porcelain
?? docs/team/reports/P36-dev2/            ← 只有本任务的报告目录（随后提交；提交后整个工作树干净）
$ bash docs/team/reports/P36-dev2/pkg/p36-checks.sh | tail -4
== 30 结果 == ✓ 12 ✗ 0
== 结果 == ✓ 37 ✗ 0
RC=0
```

原始日志：`pkg/out/2-flip-A-red.log`、`pkg/out/3-flip-C-red.log`、`pkg/out/4-restored-green.log`。

## 6. 门禁与验收

（见 `pkg/out/6-help.txt`、`pkg/out/7-openspec.txt`、`pkg/out/8-fast-smoke.log`、`pkg/out/9-full-smoke.log`；
本节在最终一次跑完后补齐原始输出尾。）

## 7. 边界与未做

- 未 push（local 模式）；未改 `docs/team/**` 里 PM 的文件（只新增 `docs/team/reports/P36-dev2/**` 我自己的报告目录）。
- **未动** M6.5 的判活/替换语义、agent 的 `--fresh` 语义、outbox/通知路径、`team_pm_start` 的调用者（watchdog/pulse 行为逐字节不变）。
- 唯一新增的内部旋钮是 `TEAM_PM_FRESH_LAUNCH`（只由 `team up --fresh-pm` 导出，进程退出即失效，不进配置）。
- 已知取舍：自定义 CLI 的 `{session_id}` 不受 `--fresh-pm` 影响（续跑契约走 `{resume_args}`，见 §2.1）。
