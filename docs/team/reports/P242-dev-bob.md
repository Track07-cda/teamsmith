# P242 · 让 210 条 A 类红按新合同转绿（夹具/期望更新，不削弱断言）

agent: dev-bob   status: **交付完成**（合并树全量绿；分支留在本地，工作树干净）   time: 2026-10-13
tip: 分支头（本报告自身的提交）；**受门禁的代码/测试树 = `4cb980f7`**（其后只有本报告这一份账本文件的提交，产品面与测试面未再改动）   base: 已并入 `main`（`git merge main`，账本面）
branch: `task/P242-routing-a-fixtures`（local 模式：不推送，分支留在本地）   deps: P238（已交付并已并入 main）；P241 的产品侧修法已并入本分支
受检清单：`docs/team/reports/V25-verify.md` §3（A1–A9 聚类）——本报告只按那份清单施工，不重做分类。

## 结论（先说事实，再说判断）

1. **A 类的五个根因全部按「夹具/期望跟上新合同」改完，产品代码一行未动**（`scripts/lib/**`、`extension/**`、`panel/**`、`references/**`、`templates/**` 都没有改动；`git diff --stat 54316ea^..HEAD -- skills/teamsmith/{scripts,extension,panel,references,templates}` 为空）。
2. **每个聚类的红绿对照都在**（见 §逐聚类红绿对照）：红侧来自同一容器 + 干净 clone 的**改前**选集运行（`logs/base.log`），绿侧来自同一命令的**改后**运行与全量门禁。
3. **分类清单之外还有 8 处「同一家族」的陈旧夹具**，都在类别守卫放行后才露出来（§6g 假 agent 的位置参数、§6f 的 `{extra_args}` 次序、§22 半条记录与它的两种判定、§54 半条记录、§54 R6 的旧 SID 字面量、§54 R6 断言自身的参数序、§25 ⑥ 的第二个夹具仓库身份、§26 记录插入点的 pending 计数），逐条归因在 §新暴露的红；它们的性质与 A 类相同（合法输入在新合同下变了），不是产品回归。
4. **A9 的隔离 lint 双向都验过**：收到的树 3 条 RED → 交付树干净 → 把一处包装还原成裸 `tmux` 必须红、点名该文件（`logs/a9-lint-flip.log`）；`--flip` 的 22 条变异臂也全绿（`RESULT pass=143 fail=0 selected=flip`）。
5. **全量收口（合并树 `4cb980f7`，钉死容器 + 干净 clone）`== 结果 ==  ✓ 4727  ✗ 0`、`smoke 全绿`**；同一棵树上 `task-model-routing.sh` 默认 13 组 `RESULT pass=2962 fail=0`。A 类清零：相对 v0.1.2 的 224 条全消，没有留下新的、需要归因的红。
6. **两条必须先讲清的环境/任务书事实**：
   - brief 的验收命令 ④ `task-model-routing.sh --select all` **按字面跑不通**（套件无 `all` 组，rc=2）；等价全量档是不带 `--select` 的默认 13 组，已跑绿（见 §验收命令 ④）。
   - 容器里的 scratch 若挂在宿主 `/tmp`（15 G tmpfs，常被**其它任务的遗留临时根**占到只剩几百 MB），会低于派单的磁盘底线（默认 1024 MB），于是「磁盘不足 → 拒绝派单」会造出一批与夹具无关的红；本任务剩下的运行一律把 scratch 指到磁盘目录（§环境发现）。

## Deliverables

| Path | What |
|---|---|
| `skills/teamsmith/tests/smoke.sh` | A1–A8 的夹具与期望更新（10 个 brief 位置、§6f 读 `--print` 标准输出、§6h 用完整 assignment 摆前置、§6i/§6j/§11b3 的失败终态、§25 的 PM 身份发布（两个夹具仓库）、§26-g 的 committed assignment、§54/§22 的完整记录与两种半条记录的判定、§41 的身份绑定、§11b4 的 P36 模板与身份发布） |
| `skills/teamsmith/tests/lib/tmux-iso.sh` | 新增 `routing_fixture_tmux`（路由夹具的私有 server 调用包装，缺私有 `TMUX_TMPDIR` 时响失败） |
| `skills/teamsmith/tests/lib/model-routing-{boundary,expansion,roles}.sh` | 三处 `new-window` 改走上面的包装（A9） |
| `skills/teamsmith/tests/section-budgets.tsv` | §61b 的实测带 4900 → **5000s**（budget 20000），依据：V28 在钉死容器里实测 4946s（loadavg 3.4→4.9），已越过旧带；§0e/§14d 复检绿（`--select 0e,14d` → `✓51 ✗0`） |
| `docs/team/reports/P242-dev-bob.md` | 本报告 |
| 仓外证据包（D94） | `pm-skills-ledger/team/reports/P242-dev-bob/`：`logs/`（改前选集、改后选集、逐次修复的选集、§26 单跑、v0.1.2 §26 对照、A9 lint 红绿、路由 `--select all` 逐字与默认 13 组、`--flip`、全量）＋ `scripts/`（可重跑的容器门禁脚本） |

提交（每步一个 Conventional Commit，带 `Task: P242` 与 `Agent: dev-bob` trailer；`main..HEAD` 中属本任务的 16 笔）：

```
5b97add9 docs(team): P242 report — environment findings, new reds, --select all
4cb980f7 test(smoke): P242 fix the R6 assertion's argument order
3edee654 docs(team): P242 report — merge note, §61b band basis, --select all finding
ed1c10cc test(gate): P242 raise §61b's measured band above the fresh measurement
62a6bc62 Merge branch 'main' into task/P242-routing-a-fixtures
f3bafa47 test(smoke): P242 pin both half-record shapes in §22 ④
dbb5a7d2 test(smoke): P242 fix the §22 empty-record case and §25's M98B identity
7d45e43d docs(team): P242 delivery report draft (full gate still running)
39f0ecd1 test(smoke): P242 bind the P36 PM template and publish its identity record
5178874f test(smoke): P242 finish the §6h/§6i/§54 contract updates
0ab37fef test(smoke): P242 fix the §25 identity fixture and §26-g record placement
b2edc457 test(smoke): P242 write §22's fixture state as complete assignment records
34e82ea1 test(smoke): P242 make the non-Pi fixture agent consume its identity selector
d0e74887 test(smoke): P242 give the P55/P140 fixtures the identity and record shape
22634616 test(smoke): P242 update the class-A fixtures to the routing contract
54316ea1 test(routing): P242/A9 route fixture tmux calls through an isolated wrapper
ddae6f49 Merge branch 'main' into task/P242-routing-a-fixtures   # 起分支时并入 P238
```

## 逐聚类红绿对照（红 = 改前选集运行，绿 = 改后）

红侧命令（同一台机器、同一镜像、同一份干净 clone 的清单来源 V25）：

```
bash scripts/gate-select.sh base --select 6,6f,6g,6h,6i,6j,22,54,12g,12h,12i,25,26,11b3,11c,31c,32
```

（`scripts/gate-select.sh` 做三件事：从本分支 `git clone` 一份干净树到 `/tmp` → 在 `localhost/teamsmith-gate:local` 里跑 `smoke.sh --keep --select …` → 日志落仓外。全部原始日志：`logs/base.log`、`logs/fix1.log`。）

### A1 · `dispatch --print` 不落盘提示词（§6f 18 条）

- 红：`✗ 落盘提示词含通知段落（…/prompt-dev-T1.1.md 中找不到 [Notify the PM when your turn ends]）`、`✗ 自敌意摘要[control] 逐字节送达 PM 收件箱（期望 [shipped the parser]，实际 []）`（`M32_NCMD` 从不再更新的旧文件里抓命令，抓空后整条矩阵级联）。
- 改：新增 `m32_prompt_from_print()`，从 `--print` 标准输出的 `=== 提示词（N 字）` 段取本次派单的提示词；②③③c③d③e 五处都改为读它（`M32_PF` 现在指向 `$TMP/m32-prompt-*.md`）。真派单的落盘没有丢：§6 的真窗口段新增 `assert_file state/prompt-dev-T1.1.md` + 内容断言。
- 绿：§6f `✓114 ✗21 → ✓135 ✗0`（改前/定稿全量；改前那 21 条里 18 条属 A1，其余 3 条属 A4 的两条误判与 `{extra_args}`）。
- 合法输入变化：**读 stdout 不是放宽**——断言的内容（通知段、摘要路径、逐字节送达、缺/空文件必须失败、坏模板降级）一条没少；变的只是这份提示词的来源。规格 `dispatch/spec.md` 的「previews cannot mutate launch state」要求预览不得写盘，所以旧来源（文件）在产品行为下必然不再更新。

### A2 · brief 必须唯一 `category:` 头（162 条）

- 红：`✗ ✗ brief 必须唯一 category: header；显式 override 不豁免` → 整段级联（§41 的 `✗ P55 ①：派单失败`、§12g 的 `✗ 12g A1 合法锚 → 放行（期望 [0]，实际 [1]）`、§22 的 `✗ M9.3-①：--force 应当放行`、§54 的 `✗ R4：末行计数 = 3`…）。
- 改（10 处 brief 夹具，全部用项目映射里真实存在的类别 `routine`）：
  1. §41 `T9.55-brief.md` 与 `T9.57-brief.md`；
  2. §54 `p140_brief()`；
  3. §22 `m93_brief()` 与两份 M93E 任务书；
  4. §6g `T1.2-nonpi-brief.md`；
  5. §12g/12h/12i 共用的 `p24_brief()`；
  6. §31c `M36W-brief.md`；7. §32 `M40W-brief.md`。
- 绿：§41 `✓96 ✗0`（改前不在选集里）、§12g `✓68 ✗7 → ✓75 ✗0`、§12h `✓29 ✗13 → ✓42 ✗0`、§12i `✓13 ✗4 → ✓17 ✗0`、§31c `✓270 ✗6 → ✓287 ✗0`、§32 `✓69 ✗2 → ✓73 ✗0`、§6g `✓5 ✗14 → ✓18 ✗0`、§54 `✓39 ✗31 → ✓70 ✗0`（那 31 条里也含 R4 的三项阻塞计数）。
- 合法输入变化：smoke 夹具配置是 `TEAM_TASK_MODELS="routine=deepseek/deepseek-flash …"`（`P235_MODELS`），`category: routine` 是**项目真有的类别**，不是为了让测试过的空头类别；规格要求「恰好一个非空 `category:` 头」正是这些夹具原本就该写的东西。§54 的「共 3 个阻塞项」保持 3：缺 category 原本是第 4 项（不在本节被测的三项里），补上后三项不变。

### A3 · 同任务换模型必须 `--fresh`（§6h 14 条）

- 红：`✗ A1：拒绝理由说清楚是「复用会话」（m43-a1.log 中找不到 [拒绝复用这个会话]）`、`✗ M4.3 A3：大窗口模型被误拒`、`✗ A8：启动命令用的是本次 --model（… 找不到 [--provider sub2api --model gpt-5.6-sol]）`、`✗ A9：roster 显示已用/窗口并标出超窗`。
- 改：新增 `m43_commit_model()`，在每个窗口守卫用例前用 `smoke_assignment` 把 dev 的已提交身份指向本次要用的模型（同任务、同 sid），再验守卫本身：A1/A2 小窗口拒绝、A3 大窗口放行且复用同一 sid、A4 `--allow-overflow` 醒目放行、A5 `--fresh` 用新 sid、A6 未知窗口走保守阈值、A7 `TEAM_MODEL_WINDOWS` 覆盖、A8 启动命令用本次 `--model`、A9 roster/ps 的 `400k/272k ⚠`（A9 先把身份钉回 `M43_ROSTER_MODEL`）。
- 绿：§6h `✓42 ✗15 → ✓57 ✗0`（改前 15 条 = A3 的 14 条 + A5b 的 1 条；后半段还留着 B1 的那 2 次 kill 断言）。
- 合法输入变化：**新合同的意图就是「同任务换模型 = `--fresh`」**，窗口守卫只在续跑同一模型时才有意义；旧夹具直接对已有 assignment 的 T1.1 换模型，于是被换模型守卫挡在窗口守卫之前 —— 断言的目标（窗口守卫/覆盖/roster）没变，只是把「席位确实在用这个模型续跑」这条前置按新合同写出来（完整 v1 记录）。

### A4 · 自定义模板必须绑定身份占位符（§6f 3 条 + §6i 1 条 + §41 连带）

- 红：`✗ quoted JSON body 被误判成畸形占位符`、`✗ 相邻占位符被误判`、`✗ nit：{extra_args} 里的 {cwd} 没有被二次展开（… 找不到 [--x {cwd}]）`；§6h 同族的 `✗ 配了 {resume_args} → 文案说明怎么延续`（PM 侧）。
- 改：三处合法模板补上 `--model {model} --provider {provider} --session-id {session_id}`；§6i 的 `PMCMD_R` 补 `--model {model} --provider {provider}`；§41 的 `p55-agent`/`p55-agent-fast` 模板补三个身份 selector（那两段的 ⑤A 复用与 ⑤C `resume` 都是 guarded continuation，不绑身份会在类别守卫放行后新红）；§11b4 的 P36 模板 `mycli run {resume_args} {prompt}` 补 `--model {model} --provider {provider}`（PM 侧只要求 provider/model + `{resume_args}`）。
- 绿：§6f `✓135 ✗0`（去掉了 `✗ {extra_args}…`）、§41 `✓96 ✗0`、§11b4 `✓33 ✗0`（这一节不在改前选集里；PM 补充项记的同命令对照是 v0.1.2 `✓33 ✗0`、合并 P241 的候选 `✓32 ✗1`，本任务修完回到 `✓33 ✗0`）。
- 合法输入变化：这三个用例测的是「合法写法不能被误伤」（quoted JSON body / 相邻占位符）与「`{extra_args}` 只插一次」，**不是**「不绑身份的模板也能续跑」；补绑定后语义不变（渲染值仍被逐条断言）。`{extra_args}` 的次序改到身份组之后是守卫的规则（未知 arity 排在身份/恢复参数之后），渲染出的 `--x {cwd}` 照旧断言。

### A5 · 失败的自定义启动不留在窗口里（§6i/§6j 3 条）

- 红：`✗ 窗口没被连诊断一起杀掉（报错还在 pane 里）（pm-adapter-failpane.txt 中找不到 [FAKE-PM-FAIL]）`、`✗ M8.2：窗口没被连诊断一起杀掉（报错还在 pane 里）`。
- 改：断言换成「窗口终态不存在」；CLI 自己的报错原文仍由**诊断文件**断言（`pm-launch-failed.log` 的 `FAKE-PM-FAIL`、`dispatch-adapter-launch-failed.log` 的 `M82-WORKER-DIE`、`render :`、`exit : 7`、尾屏字节数），并保留「诊断用的是 harness 自抓的那一份」。
- 绿：§6i `✓124 ✗3 → ✓128 ✗0`、§6j `✓37 ✗1 → ✓38 ✗0`。
- 合法输入变化：规格（`dispatch/spec.md` / `pm-lifecycle` delta）写明「启动证明/发布失败 → 未提交的 PM/worker 会被停掉」；证据链没有丢——诊断文件里就是那份 pane 尾屏。

### A5b · 失败路径多杀一次窗口（§6h 1 条）

- 红：`✗ B1：残留窗口被显式 kill-window（失败路径也是真做，不是只在文案里说）（期望 [2]，实际 [3]）`。
- 改：断言改成「≥2 次且窗口终态不存在」（下一行 `B1：失败后的窗口终态 = 不存在` 原样保留）。
- 绿：§6h `✓57 ✗0`。
- 合法输入变化：新失败事务在 `[ -z pid ]` 块里杀一次、再经 `team_dispatch_attempt_fail` 杀一次（同一窗口，第二次是 no-op）；规格没有钉精确次数，钉的是「真做 + 终态不存在」。

### A6 · PM 连续性与新启动路径（§11b3 1 条 + §6i 1 条）

- 红：`✗ 期望 running:*（窗口里的进程就是配置的 agent），实际 missing`（§11b3 ⑤ 的 `TEAM_PM_START_WAIT=0` 失败拉起）。
- 改：§11b3 改为断言「失败的拉起**不留下 PM**（missing/idle）」——新合同（`pm-lifecycle` delta）要求未提交的 PM 被停掉；后面的「不再拉起/配额 0 行/只起过一次」照旧成立。§6i 见 A2/A4 的重叠部分。
- 绿：§11b3 `✓56 ✗1 → ✓57 ✗0`；§6i 一部分见 A5。
- 合法输入变化：「靠窗口证据认出上一拍已经起来的进程」这条旧前提被新合同取消了（失败即停），所以这一拍的正确期望是「没有 PM」；旧夹具的其余断言（不重复拉起、不吃配额、只起过一个）一条没减。

### A7 · patrol 的 PM 连续性（§25 3 条）

- 红：`✗ M9.8-②：这一拍按「待复验 1」判成有待办（m98-b-watch.log 中找不到 [待复验 1]）`、`✗ M9.8-③：未读通知照旧叫醒（对照）`、`✗ M9.8-⑥：磁盘代码变了 25s 仍按旧代码判定`。
- 改：给 M98 夹具一份**可证明的 PM 启动身份** —— 用产品自己的 `team_pm_metadata_publish` 在同样环境里发一份续跑档记录（`TEAM_PM_FRESH_LAUNCH=0`），并且先 `mkdir -p .pi/team/state`（状态目录是运行时目录，夹具此前靠别的段顺手创建）。产品判据一个字节没动。
- 绿：§25 `✓53 ✗3 → ✓58 ✗0`（这三条就是 ② ③ ⑥）；同一次运行里 §26 从 `✓136 ✗12` 到 `✓149 ✗0`。
- 合法输入变化：新合同要求「有可证明的 PM 身份才叫醒/续跑」（`pm-lifecycle` delta），M9.8 的夹具原来没有 PM，正好落在这条守卫上；补一份真身份后，节测的仍是「唤醒计数 = digest 可行动清单」。

### A8 · 面板会话大小按 committed assignment 关联（§26 2 条）

- 红：`✗ 26-g agent 表：session_tokens 非空（真实会话文件）`、`✗ 26-g agent 表：elapsed 保留在 JSON 里`。
- 改：在 §26-g 之前（26-f 的 `1/2/1/4` 计数之后）用 `smoke_assignment` 写一份 dev 的完整 v1 记录，sid 与会话文件名同源（`$P10SESS-dev`）、worktree = 夹具工作树。
- 绿：§26 `✓136 ✗12 → ✓149 ✗0`（改前的 12 条 = 本聚类的 2 条 + §26-m 的 10 条环境观察，后者见 §未做/未归因项）。
- 合法输入变化：规格（`dispatch/spec.md`）要求「会话文件必须匹配 committed assignment 的 SID/worktree，miss 时读作 unavailable，不得退回邻居会话或伪造 0」——夹具以前只造会话文件、不写记录，所以面板只能读作 unavailable；补记录是这个夹具本来的 GIVEN。插在 26-f 之后是因为「有 task=（且没在跑）会进 pending.stopped」，26-f 的 `1/2/1/4` 是另一个 GIVEN。

### A9 · 新测试库的裸 tmux（§31 + §36⑧ 探针）

- 红：`✗ M28 真树有未隔离的 tmux 变更命令` + lint 原文：
  ```
  RED  skills/teamsmith/tests/lib/model-routing-boundary.sh:190  tmux new-window -d -t routing-fixture -n boundary-anchor sleep 600
       缺：-L/-S + unset TMUX + 私有 TMUX_TMPDIR
  RED  skills/teamsmith/tests/lib/model-routing-expansion.sh:16  tmux new-window -d -t routing-fixture -n expansion-anchor sleep 600
  RED  skills/teamsmith/tests/lib/model-routing-roles.sh:17      tmux new-window -d -t routing-fixture -n role-anchor sleep 1200
  ```
- 改：`tests/lib/tmux-iso.sh` 新增专用包装（`env -u TMUX -u TMUX_PANE TMUX_TMPDIR="${TMUX_TMPDIR:?routing fixture requires a private TMUX_TMPDIR}" tmux "$@"`），三处调用改走它。**没有放宽 lint**，也没有删断言。
- 绿：§31 `✓8 ✗1 SKIP2 → ✓9 ✗0 SKIP2`（M28 真树那条从红变绿）；容器里同一条命令的`task-model-routing.sh`（默认 13 组）与 `--flip` 都绿（见 §验收命令 ④），说明包装在运行时也不回落到默认 socket（缺私有目录时响失败）。
- Flip（红侧可重跑，`logs/a9-lint-flip.log`）：
  ```
  ① 收到的树（三处裸 tmux）→ 3 RED · rc=1
  ② 交付树               → 干净 · rc=0
  ③ 交付树里只把 boundary 一处还原成裸 tmux → 1 RED（点名 model-routing-boundary.sh:190）· rc=1
  ④ 还原                 → 干净 · rc=0
  ```

## 新暴露的红（类别守卫放行后才露出来的同族陈旧夹具，逐条归因）

| # | 段 | 红（改前/首次入选集） | 归因 | 修法 |
|---|---|---|---|---|
| 1 | §6g | `✗ 非 Pi dispatch 失败` + 8 条级联（假 agent 秒退 exit=1） | F5 把模板改成 `--session-id {session_id}` 起手，而夹具的假 agent 仍按位置读 `$1=cwd` → `cd --session-id` 失败 | 假 agent 先消费 `--session-id <sid>`，再按位置取 `{cwd}/{prompt_file}/{skill_dir}`（断言不变） |
| 2 | §6f | `✗ nit：{extra_args} 里的 {cwd} 没有被二次展开` | 未知 arity 的 `{extra_args}` 被放在身份组之前，argv 角色守卫拒绝 | `{extra_args}` 移到身份 selector 之后（渲染出的 `--x {cwd}` 照旧断言） |
| 3 | §22 | `✗ M9.3-①：--force 应当放行`、`✗ M9.3-②/③/④/⑤` 共 13 条 | `m93_state()` 手写的半条记录（model/window/worktree/task/taskfile/branch）在新合同下「自称是 assignment 记录」，被判 `legacy/unknown assignment_version` 拒 | `m93_state()` 改用 `smoke_assignment` 写完整 v1 记录 |
| 3b | §22 ④/⑤ | `✗ M9.3-④：task= 为空时不该拒绝` + `✗ 照旧打印派单计划`（⑤ 控制组同源，3 条） | 换成完整记录后，④ 的「半条记录 + 空 `task=`」变成新合同的 **incomplete taskfile** 拒绝（解析器要求必需字段非空；⑤ 控制组被 ④ 留下的记录连累）。旧夹具把「task= 为空」当成合法状态，新合同下任何带 assignment 字段的文件都必须完整 | ④ 用新合同下的两种合法「没有在飞任务」形状（无文件 / 只有记账键的非记录文件）继续测「判不出信号就不拦」，并**新增**两条断言钉住新合同的另一半：`assignment_version=1` 但字段不全 → `incomplete`，没有版本号的半条 → `legacy/unknown assignment_version`，两者都必须给 `--fresh` 出路且不打印计划；末尾清掉记录（⑤ 控制组靠它） |
| 4 | §54 | `✗ R5/R6/P151A` 的一批（含 `✗ R6：成功派单写下本轮 sid（期望 [1]，实际 [0]）`） | 同 3：R5/R6/P151A 手写半条记录；R6 还钉了旧分配形状的 SID 字面量 `p140-force-dev` | 新增 `p140_state()`（完整 v1 记录，支持覆盖 sid/sid_bytes/started）；R6 的 SID 断言改成新形状 `<session>-<seat>-<ts>-<pid>-<r1>-<r2>` |
| 5 | §6i | `✗ 配了 {resume_args} → 文案说明怎么延续`、`✗ resume 参数真的进了这一轮的 argv` | 续跑选择器变了（`--continue`）而**已发布的 PM 身份记录**还是默认档 → 守卫正确拒绝 | 启动前用同一套环境发布 `--continue` 档记录，验完还原默认档（复现：不发布时的拒绝原文 `PM launch identity missing/changed`） |
| 6 | §26 | `✗ 26-f 状态带：待办 1/2/1 与总数 4`（首版把记录插在 26-f 之前） | 有 task= 且没在跑的席位会进 `pending.stopped`，26-f 的 GIVEN 是另一个 | 记录改插在 26-g 之前（26-f 之后） |
| 7 | §25 ⑥ | `✗ M9.8-⑥：磁盘代码变了 25s 仍按旧代码判定`（选段现场：M98B 的 `watchdog.log` 每拍只有 `PM continuity blocked；人工 team up --fresh-pm`） | ⑥ 用**第二个**夹具仓库 `$M98B` 跑长命巡逻循环；A7 的 PM 连续性守卫排在「有待办」分支之前，所以没有可证明身份的 M98B 永远写不出唤醒理由（也就永远看不到「待复验 1」） | `m98_pm_identity()` 改成接仓库参数，对 `$M98` 与 `$M98B` 各发布一份可证明身份（与 ② ③ 同一套修法） |
| 8 | §54 R6 | `✗ ^sid=p140-force-dev-[0-9]+-[0-9]+-[0-9]+-[0-9]+$（R6：成功派单写下本轮 sid…）中没有匹配`（**只在我不带 `--keep` 的全量里出现**） | 我自己的断言写错参数序（与夹具无关）：这个文件的 `assert_match` 签名是 `<文件> <正则> <标签>`，我把标签放在了第一位 → grep 拿标签当文件名去搜 | 按签名改正（并在断言前加一次调试 dump 复现：当时的 `dev.env` 里 sid 已是新形状）；§54 复跑 `rc=0` |

PM 在派单里给的已知项 **§11b4（P36 PM 交接）**也按 A4 修了夹具模板，并且补了「渲染前发布与本次环境一致的 PM 身份记录」（原因同上表 #5：模板绑定只是第一道守卫，第二道是已发布记录的 model/resume_key）。复核证据（宿主机 scratch 项目，`team_pm_launch_cmd` 单独探针）：continued 渲染含 `--continue` 与 `--model deepseek-flash`，fresh 渲染不含 `--continue`。

PM 点名的 **§11c（选段闭包缺口 `wait_window_gone` 未定义）**按边界**没有动**（归 P238 的自足性范围）。

## 环境发现：临时根的磁盘底线会把夹具运行变成大片红（复验请注意）

第一次全量（树 `39f0ecd`，容器 `-v /tmp/p242-scratch-full:/scratch`）拿到 `✓4711 ✗8`，其中**5 条与夹具无关**：

```
✗ 拒绝派单：临时根 /scratch 磁盘不足（可用 671.8 MB < 底线 1024MB）…
✗   读数：可用 671.8 MB（inode 2880350）（总 14.5 GB）
✗   修法：bash …/tmp-hygiene.sh --status 看清单，再 --sweep 回收（只回收归属可证的根）
```

- `/scratch` 挂在宿主机的 `/tmp`（15 G tmpfs），运行期间只剩 ~450–670 MB：**其它团队/其它任务留下的临时根**占着大头（当时 `/tmp/teamsmith-task-model-routing.WfjL0b` 3.0 G、`.mvJ9Gc` 2.3 G，`/tmp/teamsmith-key-replies.*` 若干，合计 ≈10 G；这些根不归本任务，我没有动它们）。
- 派单的磁盘底线（`TEAM_TMP_MIN_FREE_MB` 默认 1024）一旦不满足，**每一次 dispatch 都被拒**——§54 的 R5/R6/P151A 那一批红全部来自这里（把 `/scratch` 换成磁盘路径后同一段全绿，见 `logs/d25.log`：只剩 §22 ④/⑤ 与 §25 ⑥ 三条真红）。
- 对策（本任务剩下的容器运行一律照此，邻座的 V27/V28 也是这个用法）：把容器里的临时根与现场放到**磁盘**上——

```
distrobox-host-exec podman run … -e TMPDIR=/scratch -v "$HOME/p242-scratch-<tag>":/scratch …
```

**给复验席位的提醒**：复验（尤其全量）请同样把 scratch 指到磁盘目录，或先确认 `/tmp` 的可用空间 ≥ 几 GB，否则会复现同一批与夹具无关的「磁盘不足 → 拒绝派单」红。

## 全量收口

命令（钉死容器 `localhost/teamsmith-gate:local` + 干净 clone，brief 的验收口径；脚本 `scripts/final-acceptance.sh`；scratch 全部在磁盘目录，见 §环境发现）：

```
git clone --branch task/P242-routing-a-fixtures --single-branch <main> "$HOME/p242-clone-final"
distrobox-host-exec podman run --rm --pid=host --cgroups=enabled --userns=keep-id -e HOME=/tmp -e TMPDIR=/scratch \
  -v "$HOME/p242-clone-final":/work -v "$HOME/p242-scratch-final":/scratch -w /work localhost/teamsmith-gate:local \
  bash -c "git config --global --add safe.directory '*'; bash skills/teamsmith/tests/smoke.sh </dev/null"
```

结果（树 `4cb980f7`，工作树 `dirty=0`；开跑 `2026-10-13T17:44:54+00:00` loadavg 1.4/1.7/2.4 → 收口 `20:06:28+00:00` loadavg 1.8/1.7/1.8，≈2h21m）：

```
#123 61 · 任务类别模型路由：分组前门（P228 · task-model-routing） · 用时 490s · ✓1 ✗0 SKIP0 · ticks 1
#124 61b · 任务类别模型路由：翻转变异自检（P228 · task-model-routing） · 用时 4883s · ✓1 ✗0 SKIP0 · ticks 1
账本自查： 126 段收口 · 增量 ✓4727 ✗0 SKIP19 ｜ 结果行 ✓4727 ✗0 —— 一致

== 结果 ==  ✓ 4727  ✗ 0
smoke 全绿
```

同行命令下看 A 类清零（三棵树的数字，命令都是同一个 `smoke.sh` 全量或 `--select` 选集）：

| 树 | 命令 | 结果 | 说明 |
|---|---|---|---|
| 改前（合并 P241 的候选，V25 的清单来源） | 全量 `smoke.sh` | `✓4478 ✗224` | 224 = A 类 210 + B 类 14（V25 分类） |
| v0.1.2（tag `v0.1.2`） | `--select 26`（同命令对照） | `✓148 ✗0` | 选集模式本身不坏（用于归属 §26-m 的观察） |
| 本任务交付树 `4cb980f7` | 全量 `smoke.sh` | **`✓4727 ✗0`** | A 类与 B 类全消 |

门禁总时长 2h21m，其中 §61b 一段 4883s —— 这是 §61b 的**实测**（与 P238 的 4883s 只差几秒），而 V28 在负载更高的机器上量到 4946s，所以本任务把该段的实测带抬到 5000s（预算 20000，见 Deliverables）。

## Flip evidence（红 → 绿、破 → 立）

这是「夹具/期望跟上新合同」的任务而不是修缺陷，所以「翻转证据」由三层组成，全部可重跑：

1. **逐聚类红→绿（同一条命令）**：红侧 `scripts/gate-select.sh base --select 6,6f,6g,6h,6i,6j,22,54,12g,12h,12i,25,26,11b3,11c,31c,32` → `✓1325 ✗149`（`logs/base.log`）；修完后先跑同一命令的 A2/A3/A7/A8/B3 段落子集 `--select 6,22,25` → `rc=0 全绿`（`logs/d28.log`），再由定稿全量覆盖到全部 126 段（`✓4727 ✗0`）。每一聚类的红/绿原文在 §逐聚类红绿对照与 §新暴露的红。
2. **A9 的破-立矩阵**（`logs/a9-lint-flip.log`，可整段重跑）：
   ```
   ① 收到的树（三处裸 tmux）        → 3 RED · rc=1
   ② 交付树                        → 干净 · rc=0
   ③ 交付树里只还原 boundary 一处     → 1 RED（点名 model-routing-boundary.sh:190）· rc=1
   ④ 还原                          → 干净 · rc=0
   ```
3. **深度翻转（套件自己的 22 条变异臂）**：容器里 `task-model-routing.sh --flip` → `rc=0`，末行 `RESULT pass=143 fail=0 selected=flip`（22 条臂按名变红后还原，基线臂 `RESULT pass=2962 fail=0`）—— 证明 A9 的包装在变异下仍成立（其余 21 条臂与 A 类无关，见 `logs/routing-flip.log`）。

另外，**新增的护栏本身也验过红**：§22 ④ 的两条新断言（`assignment_version=1` 但字段不全 → `incomplete`；无版本号的半条记录 → `legacy/unknown assignment_version`）在旧夹具形状下就是那次运行的红（`logs/d25.log` 原文 `✗ 拒绝说清记录不完整` / 首版 `legacy/unknown assignment_version`），改成合法形状后转绿。

## 验收命令（真实输出）

### ① openspec validate --all --strict（宿主机，工作树 = 定稿树）

```
$ "$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
…
✓ change/task-model-routing
✓ spec/verification
✓ spec/watchdog
Totals: 16 passed, 0 failed (16 items)
rc=0
```

### ② section-select.sh --check（宿主机，工作树）

```
$ bash skills/teamsmith/tests/section-select.sh --check
ok: 豁免类（docs/*）没有任何行声明
ok: 前导段声明有效（0 0b 0c 0d）
ok: 段正文点名的真实路径 token 都被各自的行覆盖（496 个 token 检查过；0 个豁免类 token 不参与）
ok: 账本归属（ledger-scan 60）声明有效：9/9 个账本样例被它覆盖
== 选段自检 ==  ok 8  bad 0  SKIP 1
rc=0
```

### ③ smoke.sh 全量（容器 + 干净 clone）

见 §全量收口：`== 结果 ==  ✓ 4727  ✗ 0`、`smoke 全绿`。

### ③b 合并 main（PM 2026-10-13 的要求）

```
$ git merge main --no-edit
… 10 files changed, 296 insertions(+), 4 deletions(-)   # 全部是账本/评审/任务书
$ git diff --stat f3bafa4 HEAD -- skills/                # 合并没有改产品/测试面
（空）
```

### ④ task-model-routing.sh（brief 的 `--select all` 与等价的全量档）

**brief 里这条命令按字面跑不通**（套件没有 `all` 这个组名，`--select all` 被参数校验拒为 rc=2）：

```
$ bash skills/teamsmith/tests/task-model-routing.sh --select all
unknown group: all
rc=2
```

等价的全量档 = 不带 `--select`（套件自己的默认 13 组：`policy,machine,init,config,upgrade,dispatch,resume,transaction,limits,preview,sid-readers,pm,boundary`）；加上 `--flip` 就是 §61b。两者都在合并后的树上跑：

```
$ bash skills/teamsmith/tests/task-model-routing.sh
…
RESULT pass=2962 fail=0 selected=policy,machine,init,config,upgrade,dispatch,resume,transaction,limits,preview,sid-readers,pm,boundary
rc=0

$ bash skills/teamsmith/tests/task-model-routing.sh --flip
PASS isolation-root
PASS isolation-home
…
RESULT pass=143 fail=0 selected=flip
rc=0
```

（`task-model-routing.sh` 不在本任务的写集合里，所以我没有给它加 `all` 别名；若 PM 认为任务书的写法要成立，那属于该套件或任务书的后续修订，见 §未做/未归因项。）

### ⑤ ledger-ban.sh（宿主机，工作树）

```
$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: names：名单已配置（/home/<user>/Documents/syncthing/Work/Projects/pm-skills/.git/../.pi/team/forbidden-names.txt，命中即红）
ledger-ban: root=/home/<user>/Documents/syncthing/Work/Projects/pm-skills/.worktrees/dev-bob scope=published files=1404 hits=0 names=ok user=resolved
rc=0
```

### ⑥ git diff --check && git status --short

```
$ git diff --check && git status --short
（diff --check 无输出）
（status 无输出）
rc=0
```

定稿后再跑的两项快检查（只改本报告这一份账本文件之后）：`smoke.sh --select 0d` 冲突标记守卫（扫全树，含本报告）与 `ledger-ban.sh`（同 ⑤，扫被跟踪的整棵树）—— 两者都在最终树上绿，原文见交付消息与 `logs/` 下对应文件。

## 未做 / 未归因项

- **产品代码**：一行未动（见结论 1 的 diff 证据）。
- **`task-model-routing.sh --select all`**：不接受 `all` 组名（rc=2）；未在该套件里加别名（不在写集合），本报告改成等价命令取证。
- **§11c 选段闭包缺口**（`wait_window_gone` 未定义）按任务书归 P238 的自足性范围，本任务未改。
- **§26-m 的 `pane=0 字节`**：只在**带环境异常的选集运行**里出现过（tmpfs scratch + 两台其它门禁容器并发）；最终全量 `✓4727 ✗0` 里 §26 全绿，同命令 `--select 26` 在 v0.1.2（`✓148 ✗0`）与本树（`✓149 ✗0`）都绿。作为环境观察留档（`logs/base.log`、`logs/my26.log`、`logs/v012-select-26.log`），未做产品改动，也未归因给任何聚类。

## Evidence package（仓外，D94）

`../pm-skills-ledger/team/reports/P242-dev-bob/`（3.7 MB）：

- `logs/base.log`：改前选集（`✓1325 ✗149`；这 149 条落在这些段的 A 类清单里，逐条见 §逐聚类红绿对照与 §新暴露的红）
- `logs/fix1.log`：改后第一次选集（`✓1544 ✗43`，剩下的全是 §新暴露的红与 §26-m）
- `logs/d22.log` / `d25.log` / `d26.log` / `d27.log` / `d28.log`：逐次修复的选集（诊断与最终的 `rc=0`）
- `logs/my26.log`：`--select 26` 单跑全绿；`logs/v012-select-26.log`：v0.1.2 同命令对照（全绿）
- `logs/a9-lint-flip.log`：A9 的四步红绿对照
- `logs/full-aborted.log`：首次全量（tmpfs scratch + 并发门禁，`✓4711 ✗8`，含 5 条磁盘底线红）
- `logs/full.log`：定稿树的最终全量（`== 结果 ==  ✓ 4727  ✗ 0`、`smoke 全绿`）
- `logs/routing-select-all.log` / `routing-default.log` / `routing-flip.log`：brief ④ 的逐字事实、等价 13 组全绿、22 条变异臂全绿
- `logs/0d-final.log`：定稿后只改账本文件，再跑冲突标记守卫的原文（`✓21 ✗0`，含本报告）
- `scripts/{gate-select.sh,final-acceptance.sh,routing-all.sh,routing-flip.sh,routing-both.sh,gate-full.sh}`：可重跑的容器门禁脚本（scratch 已指向磁盘目录）
