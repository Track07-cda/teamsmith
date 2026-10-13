# V25 · routing 合并后全量门禁的红清单与分类

- task: V25（只读诊断，不改产品/测试/规格）
- agent: verify · branch: `task/V25-red-inventory`
- 受检 tip：`14499ed`（冻结克隆 `/tmp/ljs-gate`，钉死容器 `localhost/teamsmith-gate:local`）
- 基线：`v0.1.2`（tag `ca7c176`，产品树与 `69692a6` 逐字节相同）——上一次全绿的全量门禁
- 全量门禁现场（PM 的作业 `ljs-wrapup-gate`）：`openspec validate --all --strict` RC=0；smoke **✓4478 ✗224**，22 个段带红

## 1. 结论摘要

合并 `task-model-routing`（`e897a7d`）之后，全量门禁的 224 条红里：

- **A（夹具/期望按新合同更新）：210 条**，集中在 5 个根因：
  1. **brief 必须有唯一 `category:` 头**，而 9 个夹具 helper/内联 brief 没写 → 162 条级联（§41 的 69 条、§54 的 31 条、§22 的 16 条、§6g 的 14 条、§12h 的 13 条、§12g 的 7 条、§31c 的 6 条、§12i 的 4 条、§32 的 2 条）；
  2. `dispatch --print` 不再落盘提示词（规格明写；`dispatch/spec.md` “previews cannot mutate launch state”）→ §6f 18 条；
  3. 同任务换模型必须 `--fresh`，M4.3 夹具按旧语义换模型 → §6h 14 条；
  4. 自定义模板必须绑定身份占位符、失败的不提交窗口/PM 会被停掉 → §6f 3 条、§6h 1 条（多杀一次窗口）、§6i 3 条、§6j 1 条、§11b3 1 条；
  5. patrol 的 PM 连续性拒绝（§25 3 条）与会话大小按 committed assignment 关联（§26 2 条）。
- **A（测试代码自身）：2 条**——routing 合并新加的 3 个测试库用裸 `tmux`，违反既有的 M28 隔离合同（§31 1 条；§36⑧ 的探针红也是同一形状，外加探针 ⑩ 用例的闭环里含 §6f）。
- **B（产品回归）：14 条**，三条线：
  - `team resume --dry-run` 丢了「可续跑」清单行（§11c 1 条 + §6k 1 条）——**PM 已立 P240，修在 main `e09a710`**；
  - `common.sh` 单独被 source 时 PM 启动路径崩（`team_config_model_violation: command not found`，§11b4 1 条）；
  - **`team inbox --ack` 的记账键写进 assignment 文件**：`state/<seat>.env` 被 `inbox_lines=N` 变成「legacy 记录」，该席位下一次非 fresh 派单被拒（§11c 6 条 + §15b 5 条，一条根因）。
- **未定：0 条**（原先挂起的两块——§11c 与 §15b——已复现并合并到上面的 B 第三条）。
- **C（未归档 change 造成的假红）：0 条**。逐条核对过：§12g/§12h/§12i 的红**全部**停在 `brief 必须唯一 category: header` 这一条前置拒绝上（12g/12h/12i 的守卫实现只读任务书 + 看板，不读 change 的归档状态），`task-model-routing` 未归档本身没有制造任何红。
- **D（选集/顺序/环境假红）：0 条**。同命令、同镜像、干净克隆的 v0.1.2 全量基线逐条对照（§6）：224 条里没有一条在基线里是红的；177 条逐字同断言、13 条同断言改写、34 条换了说法/条数（基线侧仍是 ✓）。

一句话给修复方：**这份清单的主体不是产品坏了，而是测试夹具没跟上新合同**；要动产品的只有三处：`cmd-status.sh` 的收件箱记账（B3，11 条）、`common.sh` 的自足性（B2，1 条）、`--dry-run` 清单行（B1，2 条，P240 已修在 main）。

## 2. 证据与方法

| 证据 | 命令（同一前提） | 结果 |
|---|---|---|
| 合并 tip 全量 | 冻结克隆 `14499ed` + 钉死容器：`openspec validate --all --strict` && `bash skills/teamsmith/tests/smoke.sh </dev/null>` | `✓4478 ✗224`，日志 `/tmp/ljs-gate.log`（PM 作业） |
| v0.1.2 全量基线 | 同一镜像、同一命令、干净克隆 `/tmp/v25-base`（`v0.1.2` = `ca7c176`，产品树与 `69692a6` 逐字节相同） | **✓4652 ✗1 SKIP19**；唯一红是 §57 子套件的一例 `DRAFT-CJK`（现场敏感，与本次 224 条无关；合并 tip 上 §57 是 ✓1 ✗0）。结果行与段账自己一致 |
| §11c 单段（合并 tip） | `--select 11c,15b --keep` | 崩溃链 ✓、`--dry-run` ✗（P240）、选段器缺 `wait_window_gone` |
| §15b 单段（合并 tip） | `--select 15b` | `✓26 ✗0`；同一段在全量里 ✗5（见 §3 B3） |
| §11c/§15b 前缀复现 | 打了诊断补丁的副本：`--select 7,7b,8,11b,11b2,11b3,11b4,11,11c` 与 `--select 11,11b,15b`（都 `--keep`） | 逐条复现全量：11c `✓8 ✗7`、15b `✓21 ✗5`；派单日志 `legacy/unknown assignment_version`；`state/dev.env` = `inbox_lines=N`。这是 B3 的定位证据 |
| §25/§26 单段（合并 tip） | `--select 25,26 --keep` | §25 的红原文是 `PM launch identity missing/changed…`；§26 的 dev 行 `session_tokens: 0 / session_window: 0 / text: "-"`，无 `dev.env` |
| §36⑧ 检出形状探针 | 宿主机直接跑 `tests/checkout-shape-probe.sh`（14499ed，900s 超时被我截断，但已跑完全部 bad 用例） | 17 条 `bad:`（与门禁 §36⑧ 自己报的 17 条一致），全部归因于 §31 的裸 tmux（A9）与 §6f 的提示词红（A1） |

**选段器的一个既有缺陷（不是本任务的红，但污染对照）**：`--select` 生成的包装脚本里 `wait_window_gone` **没有定义**（`teamsmith-select.NNNNNN.sh: line N: wait_window_gone: command not found`），凡是走 `--select` 跑 §11c 的对照都会把「5s 内 dev 窗口还在」那条前提打成假红。PM 在 D145-3c 里已经踩到过这个形状；我给结论时只把**全量对全量**当作分类依据，选段结果只用于定位。

## 3. 逐条分类（按根因聚类）

字段：段号段名 / 条数 / 红的形态 / 判定 / 依据 / 修法归属。

### A1 · `dispatch --print` 不再落盘提示词（18 条）

- 段：§6f「agent adapter（任意 TUI agent）」——`落盘提示词含通知段落`、`自定义 CLI → 明说不是 Pi`、`提示词给出摘要文件路径`、`让 worker 原样跑固定命令`、`旧模板的 {summary}…`、敌意摘要矩阵 8 条、`摘要文件不存在/为空时 notify 不该成功`、`{summary_file} 渲染成路径`、`坏模板 → is unusable / into the report`。
- 现场：夹具断言 `state/prompt-dev-T1.1.md` 的内容；该文件现在只在**真派单**时写。规格（`openspec/changes/task-model-routing/specs/dispatch/spec.md`，Requirement “Launch assignments are complete transactions and previews cannot mutate launch state”）逐字要求：`dispatch --print`、resume dry-run 与被拒的预检 **SHALL NOT create/modify prompt files**。产品行为是意图内的；夹具读的是一份不再被更新的旧文件（敌意摘要矩阵的 `M32_NCMD` 甚至从这份旧文件里抓命令，抓空后整条矩阵级联）。
- 修法（owner `skills/teamsmith/tests/smoke.sh`）：让这一段用一次**真派单**（假 agent）把提示词落盘，或把断言改成读 `--print` 的标准输出 / 从输出里取通知命令。不要动产品。

### A2 · brief 必须有唯一 `category:` 头（162 条）

- 规格：`dispatch/spec.md`——「A brief SHALL declare exactly one `category:` header token … Missing, duplicate, empty or malformed declarations always refuse before any side effect and in preview as well」。
- 现场：拒绝原文 `✗ brief 必须唯一 category: header；显式 override 不豁免`。夹具的 brief 是**自己拼**的，没写这行：
  - §41（69 条）：`$REPO/.pi/team/state/T9.55-brief.md`（`task/agent/change/anchor` 有，无 category）；派单被拒后整段（①–⑦ 的窗口、遗体、roster/status/digest/doctor、复用）全部级联。
  - §54（31 条）：`p140_brief()` 生成的 fixture brief。
  - §22（16 条）：`m93_brief()`。
  - §6g（14 条）：`$REPO/.pi/team/state/T1.2-nonpi-brief.md`。
  - §12h（13 条）／§12g（7 条）／§12i（4 条）：`p24_brief()`。
  - §31c（6 条）：`.pi/team/state/M36W-brief.md`；§32（2 条）：32⑧c 的 brief。
- 修法（owner `skills/teamsmith/tests/smoke.sh`）：给所有 brief helper 补 `category: routine`（或该段语义对应的类别）；§54 的“末行计数 = 3”要改成 4 或给 fixture brief 补 category 后再数。

### A3 · 同任务换模型必须 `--fresh`（14 条）

- 段：§6h「派单：会话规模 vs 模型窗口」的 A1/A3/A4/A6/A7/A8/A9。
- 规格：`dispatch/spec.md`——同任务恢复保留 committed model/SID，换模型（含 suffix）必须 `--fresh`；`--allow-overflow` 也不能绕过换模型限制。
- 现场：夹具对 T1.1（已有 committed assignment，model=deepseek-flash）依次用 `--model sub2api/gpt-5.6-sol`、`big/wide` 等派单，全部被换模型守卫拒在窗口守卫之前，于是 A1 的 `272000`/`÷ 4`/`--allow-overflow`、A3 的「复用同一个 session id」、A4 的放行警告、A6 的保守阈值、A7 的窗口覆盖、A8 的启动命令、A9 的 `400k/272k` 都拿不到目标输出。
- 修法（owner `skills/teamsmith/tests/smoke.sh`）：把 M4.3 夹具改成「先 `--fresh` 建立目标模型的 assignment，再验证窗口守卫」，或在同一模型下做窗口覆盖；**保留**这些断言的强度（它们测的窗口守卫仍在新规格里）。

### A4 · 自定义模板必须绑定身份占位符（3 条）

- 段：§6f 的 `quoted JSON body 被误判成畸形占位符`、`相邻占位符被误判`、`nit：{extra_args} 里的 {cwd} 没有被二次展开`。
- 现场：这三条期望「合法模板被接受」，但现在 T1.1 是同任务续跑（夹具自己写了 committed assignment），模板只绑了 `{prompt}`/`{cwd}`/`{prompt_file}`，没绑 `{provider}`/`{session_id}` → 新守卫以 `guarded continuation lacks bound {provider}` 拒绝。规格（`dispatch/spec.md`）明写「Frozen custom templates must consume the resolved identity placeholders to claim Pi continuity」。
- 修法（owner `skills/teamsmith/tests/smoke.sh`）：模板里加 `--provider {provider} --session-id {session_id}`，或让这几条用无 committed assignment 的任务跑。

### A5 · 失败的自定义 agent/PM 启动会停掉未提交窗口（2 条）

- 段：§6j `M8.2：窗口没被连诊断一起杀掉（报错还在 pane 里）`；§6i `窗口没被连诊断一起杀掉（报错还在 pane 里）`。
- 规格：`dispatch/spec.md`——adapter 立刻非 0 退出时派单失败，诊断（渲染命令、解析到的二进制、退出码、窗口尾屏）落 `state/dispatch-<agent>-launch-failed.log`；`pm-lifecycle` delta——「any uncommitted new PM is stopped」。夹具期望“报错还留在 pane 里”，与新产品形态冲突。
- 修法（owner `skills/teamsmith/tests/smoke.sh`）：断言改成「窗口终态不存在 + 诊断文件里含 CLI 的报错原文」。

### A5b · 失败路径多杀一次窗口（1 条）

- 段：§6h `B1：残留窗口被显式 kill-window（期望 2，实际 3）`。
- 现场：新的失败事务在 `[ -z pid ]` 块内杀一次、又经 `team_dispatch_attempt_fail` 杀一次（同一窗口，第二次是 no-op）。窗口终态仍「不存在」，既有语义没丢；夹具数的是调用次数。
- 修法（owner 可二选一）：把断言放宽成「≥2 次且终态不存在」（owner `skills/teamsmith/tests/smoke.sh`），或删掉失败块里那次冗余 kill（owner `skills/teamsmith/scripts/lib/cmd-agents.sh`）。规格没有钉精确次数。

### A6 · PM 连续性/新启动路径（4 条）

- §11b3 `期望 running:*，实际 missing`：夹具的剧本是「TEAM_PM_START_WAIT=0 的失败尝试其实已经把进程起来了 → 下一拍靠窗口证据认出它」。新合同相反：启动证明/发布失败时**停掉未提交的 PM**（`pm-lifecycle` delta），所以下一拍看到的就是没有 PM。修法：夹具改成断言「失败的尝试不留下 PM」或让这一拍重新拉起。
- §6i `配了 {resume_args} → 文案说明怎么延续`、`resume 参数真的进了这一轮的 argv`：PM 模板 `fake-pm.sh {resume_args} --pf {prompt_file} --ask {prompt}` 没绑身份占位符 → guarded continuation 被新守卫拒（`pm-lifecycle` delta：changed/unknown identity 不得自动续跑，给 `up --fresh-pm` 出路）。修法：模板里绑 `{provider}`/`{session_id}`，或改成 fresh 用例。
- §11c `up --agents 才会续跑 agent`：`team up --agents` 现在先过 PM 连续性守卫；没有一个可证明的 PM 身份时它直接停在那里（不打印「续跑 dev」），这是与 A7 同族的形态。修法：夹具给 PM 一份可证明的身份，或把断言改成 `up --agents` 的新拒绝/新文案。
- 归属：owner `skills/teamsmith/tests/smoke.sh`；产品侧行为有规格依据。

### A7 · patrol 的 PM 连续性拒绝（3 条，已复现确认）

- 段：§25 `M9.8-②/③/⑥`——`team watch --once` 的输出里没有 `待复验 1` / `未读通知 1`。
- 现场（`--select 25,26 --keep`，14499ed）：`m98-b-watch.log` 的全文就是
  `✗ PM launch identity missing/changed（含 suffix）；先保留 BOARD/threads/reports 磁盘交接，再 team up --fresh-pm；不改 Pi 历史`
  + `✓ watch --once 完成（日志：.pi/team/state/watchdog.log）`。库侧判据（`team_pending_text`/可行动清单）全绿；缺的是 watch 那一拍的叫醒文案——M9.8 夹具的 PM 从未启动过（无 launch metadata），新 `team_watch_once` 在“有待办但 PM 没在跑”之前加了 `team_pm_identity_guard`，`pm-lifecycle` delta 要求「Patrol reports a continuity blocker but never auto-freshens, respawns or consumes a restart slot」。
- 判定 **A**：夹具要给这个项目一份可证明的 PM 启动身份（或在断言里认这条新拒绝）。产品行为有规格依据，owner `skills/teamsmith/tests/smoke.sh`。

### A8 · 面板会话大小按 committed assignment 关联（2 条，已复现确认）

- 段：§26 `26-g session_tokens 非空`、`elapsed 保留在 JSON 里`。
- 规格：`dispatch/spec.md`——会话文件必须匹配 committed assignment 的 SID/worktree，miss 时读作 unavailable，不得退回邻居会话或伪造 0。
- 现场（`--select 25,26 --keep`，14499ed）：`repo/.pi/team/state/dev.env` 不存在；面板 JSON 里 dev 行是 `session_tokens: 0, session_window: 0, session_text: "-"`，`elapsed` 键缺席。P10 夹具只造了 `…_$P10SESS-dev.jsonl` 会话文件，没有给 dev 写 assignment 记录；新 `monitor.mjs` 先解析 `state/dev.env` 的 worktree+sid，拿不到就返回 null。
- 修法（owner `skills/teamsmith/tests/smoke.sh`）：夹具用 `smoke_assignment "$P10R" dev P10X routine … "…/$P10SESS-dev"` 写一条完整 assignment（sid 与该会话文件名同源）。

### A9 · 新测试库的裸 tmux（2 条）

- 段：§31 `M28 真树有未隔离的 tmux 变更命令`（RED 三条：`tests/lib/model-routing-boundary.sh:190`、`model-routing-expansion.sh:16`、`model-routing-roles.sh:17` 的 `tmux new-window -d -t routing-fixture …`）；§36⑧ 的探针里 §31 的同类形状（产品面树与混合形状用例，15 条 `bad:` 中的多数）。
- 判定：M28 是**测试代码的既有契约**（隔离 lint + 豁免清单），产品树没有回归。修法：三个新库走套件的 tmux 包装（或按契约登记豁免），**不要删这条检查**。owner `skills/teamsmith/tests/lib/model-routing-*.sh`。
- §36⑧ 另有 20 条来自 §58 的选段闭环里包含 §6f（探针的 ⑩ 用例：`--select 58` 的闭环含 6f），所以这条红在 6f 修好后应随之收敛；探针自身的打印也点到了这一点（`nest-po10.log` 的 20 条全是 §6f 的 A1）。

### B1 · `team resume --dry-run` 丢了清单行（2 条）

- 段：§11c `resume --dry-run 能识别待续跑任务`；§6k `6k ⑥ P210：resume --dry-run 把裸 shell 的席位列成可续跑`。
- 现场：`cmd-watch.sh` 的 `team_cmd_resume --dry-run` 被改成 `team_cmd_dispatch … --print`，不再打印 `  可续跑：<task> → <brief>`。§6k 的红还叠了一个「任务书在项目外」的拒绝（夹具自己的 brief 在 `/tmp/…/m37-task.md`）。
- 修法：恢复清单行（P240 已做，main `e09a710`）；§6k 若还想测“裸 shell 席位可续跑”，夹具的 brief 应放进项目内。owner `skills/teamsmith/scripts/lib/cmd-watch.sh`（P240）。

### B2 · `common.sh` 单独 source 时 PM 启动路径崩（1 条）

- 段：§11b4 `P36 ①：模板路径默认把 {resume_args} 渲染出来`（stderr 里伴随两次 `/work/skills/teamsmith/scripts/lib/common.sh: line 1340/1367: team_config_model_violation: command not found`）。
- 现场：夹具的 `p36_render()` 按既有约定只 source `common.sh` 再调 `team_pm_launch_cmd`；新代码把 `team_config_model_violation` 放在 `cmd-config.sh`，而 `common.sh` 的 `team_model_policy_issues`/`team_pm_identity_guard` 在**另一条文件**里调用它 → 只在“只 source common.sh”的探针里炸。产品自己的注释（common.sh 附近）明确保留「只 source common.sh 的夹具退回 0」这一形状。
- 修法（owner `skills/teamsmith/scripts/lib/common.sh`）：把模型形状判定下沉到 common.sh（或让 `team_model_policy_guard` 在函数缺席时退回可诊断的 no-op）；不建议改夹具——同一段里 §15b 也用这个形状并且绿。
- 复现（宿主）：见 §7。

### B3 · `inbox --ack` 的记账键把没有 assignment 的席位变成 legacy 记录（11 条：§11c 6 条 + §15b 5 条）

- 现象：§11c 的崩溃剧本在 #43 的派单被拒（派单日志原文：`✗ ✗ dev: legacy/unknown assignment_version；保留磁盘交接，dispatch dev T1.1 … --fresh`），于是 `state/dev.env` 没有 `task=T1.1`，其后的 digest/ps/resume/up --agents 级联；§15b 在 #53 被同一条拒绝挡住（rc=1，没走到依赖告警那一行）。
- 补充：`up --agents` 这一条在两种语境里都能红——没有可证明的 PM 身份时是 PM 连续性拒绝（A6/A7 同族），而**在全量这次**它跟随的是上面这条 legacy 拒绝（其余 5 条同一根源）；归本组以反映全量现场。
- 复现（14499ed、钉死容器、干净副本）：
  - `--select 7,7b,8,11b,11b2,11b3,11b4,11,11c` → 11c `✓8 ✗7`，7 条与全量逐条一致；pre-dispatch 的 `state/dev.env` 只有 14 字节 `inbox_lines=4`；
  - `--select 11,11b,15b` → 15b `✓21 ✗5`（与全量同样的 5 条），`state/dev.env` = `inbox_lines=2`，派单日志同一条 legacy 拒绝。
- 机制（三步）：
  1. §11 `team close T1.1` → `team_state_clear dev` 删掉 `state/dev.env`；
  2. §11b/§11b2 的 `team inbox --ack` → `cmd-status.sh:929` 调 `team_state_set dev inbox_lines N` → `common.sh:1735 team_state_set` 在文件不存在时**新建** `state/dev.env`，里面只有这一行记账键；
  3. §11c/§15b 对 dev 的非 fresh 派单 → `team_dispatch_identity_recover` 读到该文件 → `team_assignment_parse`（`common.sh:1441`）判 `assignment_version != 1` → `legacy/unknown assignment_version` → 拒绝并要求 `--fresh`。
- 判定 **B（产品回归）**：v0.1.2 的 `state/<seat>.env` 没有版本 schema，`inbox_lines` 只是个普通记账键；合并把同一个文件变成版本化 assignment 记录，却让旧记账路径继续写它。任何「close 过某席位、之后又 ack 过收件箱」的项目都会让该席位下一次派单被拒（除非 `--fresh`）。
- 修法（两条，建议都做）：
  1. 主修（owner `skills/teamsmith/scripts/lib/cmd-status.sh`）：收件箱记账别写 assignment 文件 —— 用 sidecar（如 `state/<seat>.inbox` 或 `state/inbox-lines/<seat>`）；
  2. 防御（owner `skills/teamsmith/scripts/lib/common.sh`）：identity recovery 把「既无 `assignment_version` 也无任何 assignment 字段」的文件当成「没有记录」（fresh 可走），只有真正带 legacy assignment 字段的记录才按 legacy 拒绝。

## 4. 总量与分布

| class | 条数 | 说明 |
|---|---|---|
| A | 210 | §3 的 A1–A9 聚类（其中 A2 一类 162 条） |
| B | 14 | B1 2 条（P240 已修）、B2 1 条（`common.sh` 自足性）、B3 11 条（`inbox --ack` 写坏 assignment 记录） |
| 未定 | 0 | 原挂起的两块已定位到 B3 |
| C | 0 | 未归档 change 没有制造红（§12g/h/i 全部停在 category 前置拒绝） |
| D | 0 | §6：同命令全量基线逐条对照，没有一条红在基线里是红的 |
| 合计 | 224 | 与门禁结果行一致 |

修完 A 之后的预测（同一前提复跑全量）：
- 9 个 brief helper 补 `category:` → §41/§54/§22/§6g/§12g/§12h/§12i/§31c/§32 共 162 条应全绿（它们的 ✓ 断言已经证明除这一条外逻辑都在）；
- §6f 18 条（A1）修好 → 它自身全绿，且 §36⑧ 探针里经 §58 闭环带出的 20 条也随之消失；
- §6h 换模型语义 → 14 条（A3）+1 条（A5b）；
- 三个新测试库走隔离包装 → §31 1 条 + §36⑧ 的剩余部分；
- §6i/§6j/§11b3/§25/§26 的夹具更新 → 其余 A；
- 全绿前还差 §11c 的 6 条（B3 5 条 + up --agents 1 条）与 §6k 的 1 条（B1 已修），以及 §15b 的 5 条（同属 B3）。

## 5. 需要更多证据的地方

除 §6 的 v0.1.2 全量对照（判定 D）之外，没有挂起的未定项；原先把 §11c/§15b 挂在“未定”的两块已经在下面的复现里定位成 B3 一条根因。

## 6. v0.1.2 全量基线对照（判定 D）

同命令（`openspec validate --all --strict` + `bash skills/teamsmith/tests/smoke.sh </dev/null>`）、同镜像（`localhost/teamsmith-gate:local`）、干净 clone、全量 124 段：

| 树 | 结果 | 备注 |
|---|---|---|
| v0.1.2（`ca7c176`，产品树与 `69692a6` 逐字节相同） | **✓4652 ✗1 SKIP19** | 唯一红是 §57 内部子套件的 `✗ DRAFT-CJK：say: dev 没在跑（窗口 p147:dev 不在）`；合并 tip 上同一段是 `✓1 ✗0`，PM 记录的 v0.1.2 `✓4653 ✗0` 也是绿的 —— 这是 §57 的现场敏感例，与本次 224 条无关 |
| 合并 tip（`14499ed`） | **✓4478 ✗224** | PM 的作业日志，逐字节同 md5 于账本副本 |

逐条对照方法与结果（`/tmp/v25/compare_baseline.py`，脚本随证据归档）：去掉断言里的证据括号后归一化，在**同一段**内用 difflib 找最佳匹配（阈值 0.85），再看那条基线行是 ✓ 还是 ✗：

| 对照结论 | 条数 | 说明 |
|---|---|---|
| `green-on-baseline` | 177 | v0.1.2 同一段里有逐字相同的断言且为 ✓ |
| 同断言改写（r 0.69–0.82） | 13 | 如 §22 `M9.3-①：--force 是显式覆盖 → 放行`、§41 `P55 ①：派单成功`、§36⑧ `产品面检出探针全绿`；基线侧 ✓ |
| 换了说法/条数（r < 0.6） | 34 | 如 §41 的 `§40 夹具：kill 前的 pgid 安全检查失败`（基线没有这一条，同段最佳匹配是 ✓）、§54 的 `R4/R5` 文案引用、§12g 的嵌套证据行（`12g A1 打印了提示词`）；基线侧最佳匹配同样是 ✓ |
| **`RED-on-baseline`** | **0** | 逐段统计“最佳匹配的判定字符”全部为 ✓：41→✓×69、54→✓×31、6f→✓×21、6h→✓×15、6g→✓×14、12h→✓×13、… |

结论：**D = 0**。224 条红全部是合并引入的（A 或 B），每一条都有同命令的全量基线对照支持；不存在由选段闭包、段落顺序或运行环境造出的假红。

关于选段：我们的 `--select` 对照（§2）因为选段器的 `wait_window_gone` 缺陷而只能用于定位，不能用于判定；分类不依赖它们。

## 7. 复现命令（B 条目，都可直接跑）

**B1（`resume --dry-run`，P240 已修）**

```bash
# 任意已初始化的项目，或有 committed assignment 的席位：
team resume --dry-run | grep '可续跑'   # v0.1.2：有；14499ed：无（改成 team_cmd_dispatch --print 了）
# 全量里的现场：bash skills/teamsmith/tests/smoke.sh --select 11c（resume-dry.log 里找不到 [可续跑：T1.1]）
```

**B2（`common.sh` 自足性）—— 已实测的红/绿对照**

```bash
# 最小项目：git init + .pi/team/config.sh（TEAM_TASK_MODELS/TEAM_PM_MODEL 齐备）
env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_SKILL_DIR bash -c '
  cd "$PROJECT"
  . <tree>/skills/teamsmith/scripts/lib/common.sh
  team_load_config >/dev/null 2>&1
  team_pm_launch_cmd "$PWD/.pi/team/state/pm-prompt.md" "$PWD/.pi/team/state/pm.pid.spawn"'
# 14499ed：两条 `common.sh: line 1340/1367: team_config_model_violation: command not found`，rc=1，输出空
# v0.1.2 ：rc=0，打印完整的 PM 启动命令（带 -c 与 @pm-prompt.md）
```

**B3（`inbox --ack` 写坏 assignment 文件）**

```bash
# 容器里、同一镜像、干净副本（1–2 分钟）：
rm -rf /tmp/v25-b3 && git clone -q --no-local /tmp/ljs-gate /tmp/v25-b3 && cd /tmp/v25-b3 && git checkout -q 14499ed
distrobox-host-exec podman run --rm --pid=host --cgroups=enabled --userns=keep-id -e HOME=/tmp -e TMPDIR=/scratch \
  -v /tmp/v25-b3:/work -v /tmp/v25-b3-scratch:/scratch -w /work localhost/teamsmith-gate:local \
  bash -c 'git config --global --add safe.directory "*"; bash skills/teamsmith/tests/smoke.sh --keep --select 11,11b,15b </dev/null'
# 期望（修好后）：15b ✓26 ✗0；实际（14499ed）：15b ✓21 ✗5，dispatch-deps.log 第一行
#   ✗ ✗ dev: legacy/unknown assignment_version；保留磁盘交接，dispatch dev T1.1 … --fresh
# 同样形状的第二份现场：--select 7,7b,8,11b,11b2,11b3,11b4,11,11c → 11c ✓8 ✗7
# 对照（同一命令、v0.1.2）：两个选集都全绿 / 只剩断言改写差异
# 代码链：cmd-status.sh:929（team inbox --ack → team_state_set inbox_lines）
#         common.sh:1735（team_state_set 追加创建 state/<seat>.env）
#         common.sh:1441（team_assignment_parse：assignment_version != 1 → legacy/unknown）
```

## 8. 给 PM 的拆分建议（一个 owner 一条线，串行改同一文件）

1. **`skills/teamsmith/tests/smoke.sh`（P238 持有）**：A1（6f 用真派单）、A2（全部 brief helper 补 `category:`）、A3（M4.3 换模型语义）、A4（身份占位符）、A5（adapter 失败形态）、A5b（kill 计数）、A6（M7.2/6i/11c 新语义）、A7（M9.8 的 PM 身份）、A8（P10 assignment）。
2. **`skills/teamsmith/tests/lib/model-routing-*.sh`**：A9（三个库走隔离包装）。
3. **`skills/teamsmith/scripts/lib/cmd-status.sh`**：B3 主修（收件箱记账移出 assignment 文件）；`common.sh` 防御性判读（assignment-less 文件 = 无记录）。
4. **`skills/teamsmith/scripts/lib/common.sh`**：B2（模型形状判定/守卫的 common.sh 自足性）。
5. **`skills/teamsmith/scripts/lib/cmd-watch.sh`**：B1（`--dry-run` 清单行，P240 已在 main `e09a710` 修好）；§6k 的 fixture brief 放进项目内。
6. 以上修完后在同一容器里复跑全量：预期 A 的 210 条与 B 的 14 条全部转绿（D 已经是 0，不需要再用对照解释任何一条）。

## 9. 交付物与验收

| 交付物 | 位置 |
|---|---|
| 本报告（分类表 + 汇总 + 每条 B 的最小复现） | `docs/team/reports/V25-verify.md`（分支 `task/V25-red-inventory`） |
| 机器可读 CSV（224 行；字段 section / assertion / class / cluster / evidence / spec / owner / fix） | 仓外 `pm-skills-ledger/team/reports/V25-verify/V25-reds.csv` |
| 逐条基线对照（含匹配比例与匹配到的基线行） | 仓外同目录 `baseline-compare.tsv` |
| 两份全量日志（合并 tip / v0.1.2）、选段复现日志、对照脚本 | 仓外同目录 |

只读约束：本任务没有修改任何产品、测试、规格或配置；分支上的提交只有本报告。

## 10. 附录：224 条红逐条清单（compact；完整字段见仓外 CSV）

| # | 段 | 断言（截断） | class | 聚类 |
|---|---|---|---|---|
| 1 | 6f | 落盘提示词含通知段落（/tmp/teamsmith-smoke.NLYVqd/repo/.pi/team/state/prompt-dev-T1.1.md 中找不到 [Notify the … | A | A1 |
| 2 | 6f | 自定义 CLI → 明说不是 Pi（没有自动通知）（/tmp/teamsmith-smoke.NLYVqd/repo/.pi/team/state/prompt-dev-T1.1.md 中找… | A | A1 |
| 3 | 6f | 提示词给出摘要文件路径（teamsmith 生成的）（/tmp/teamsmith-smoke.NLYVqd/repo/.pi/team/state/prompt-dev-T1.1.md 中… | A | A1 |
| 4 | 6f | 让 worker 原样跑固定命令（/tmp/teamsmith-smoke.NLYVqd/repo/.pi/team/state/prompt-dev-T1.1.md 中找不到 [no su… | A | A1 |
| 5 | 6f | 旧模板的 {summary} 渲染成「读摘要文件」的引用（不做文本插值）（[] 里找不到 [cat /tmp/teamsmith-smoke.NLYVqd/repo/.pi/team/sta… | A | A1 |
| 6 | 6f | 敌意摘要[control] 逐字节送达 PM 收件箱（期望 [shipped the parser]，实际 []） | A | A1 |
| 7 | 6f | 敌意摘要[dquote] 逐字节送达 PM 收件箱（期望 [fixed the "no session" hint]，实际 []） | A | A1 |
| 8 | 6f | 敌意摘要[subst] 逐字节送达 PM 收件箱（期望 [$(touch /tmp/teamsmith-smoke.NLYVqd/m32-det/mark)]，实际 []） | A | A1 |
| 9 | 6f | 敌意摘要[breakout] 逐字节送达 PM 收件箱（期望 [x"; touch /tmp/teamsmith-smoke.NLYVqd/m32-det/mark; echo "]，实际 … | A | A1 |
| 10 | 6f | 敌意摘要[backtick] 逐字节送达 PM 收件箱（期望 [`touch /tmp/teamsmith-smoke.NLYVqd/m32-det/mark`]，实际 []） | A | A1 |
| 11 | 6f | 敌意摘要[apostrophe] 逐字节送达 PM 收件箱（期望 [it's fixed]，实际 []） | A | A1 |
| 12 | 6f | 敌意摘要[braces] 逐字节送达 PM 收件箱（期望 [see {agent} and {summary_file} and {cwd}]，实际 []） | A | A1 |
| 13 | 6f | 敌意摘要[newline] 逐字节送达 PM 收件箱（期望 [first line second line]，实际 []） | A | A1 |
| 14 | 6f | 摘要文件不存在时 notify 不该成功 | A | A1 |
| 15 | 6f | 摘要文件为空时 notify 不该成功 | A | A1 |
| 16 | 6f | {summary_file} 渲染成路径（推荐形态，shell 里不读文件）（/tmp/teamsmith-smoke.NLYVqd/repo/.pi/team/state/prompt-d… | A | A1 |
| 17 | 6f | 坏模板 → 提示词通知段改成「配置不可用」（F8）（/tmp/teamsmith-smoke.NLYVqd/repo/.pi/team/state/prompt-dev-T1.1.md 中找… | A | A1 |
| 18 | 6f | 并告诉 worker 把摘要写进报告（F8）（/tmp/teamsmith-smoke.NLYVqd/repo/.pi/team/state/prompt-dev-T1.1.md 中找不到 … | A | A1 |
| 19 | 6f | quoted JSON body 被误判成畸形占位符 | A | A4 |
| 20 | 6f | 相邻占位符被误判 | A | A4 |
| 21 | 6f | nit：{extra_args} 里的 {cwd} 没有被二次展开（/tmp/teamsmith-smoke.NLYVqd/m32-extra-cmd.log 中找不到 [--x {cwd}… | A | A4 |
| 22 | 6g | 非 Pi 命令用的是配置的假 agent（/tmp/teamsmith-smoke.NLYVqd/cmdline-nonpi.log 中找不到 [/tmp/teamsmith-smoke.N… | A | A2 |
| 23 | 6g | {cwd} 指向它自己的 worktree（/tmp/teamsmith-smoke.NLYVqd/cmdline-nonpi.log 中找不到 [/tmp/teamsmith-smoke.… | A | A2 |
| 24 | 6g | {session_id} 是 teamsmith 的 session（/tmp/teamsmith-smoke.NLYVqd/cmdline-nonpi.log 中找不到 [teamsmit… | A | A2 |
| 25 | 6g | 非 Pi dispatch 失败 | A | A2 |
| 26 | 6g | 非 Pi agent 跑完整条回路（写文件 → 提交 → 报告 → 通知）（缺 /tmp/teamsmith-smoke.NLYVqd/fake-agent.done） | A | A2 |
| 27 | 6g | 非 Pi agent 真的在窗口里跑起来了（缺 /tmp/teamsmith-smoke.NLYVqd/fake-agent.mark） | A | A2 |
| 28 | 6g | 它拿到了 teamsmith 的 session id（/tmp/teamsmith-smoke.NLYVqd/fake-agent.mark 中找不到 [sid=teamsmith-smo… | A | A2 |
| 29 | 6g | {prompt_file} 也是真的（/tmp/teamsmith-smoke.NLYVqd/fake-agent.mark 中找不到 [prompt=/tmp/teamsmith-smok… | A | A2 |
| 30 | 6g | 窗口在（agent:adapter）（期望 [1]，实际 [0]） | A | A2 |
| 31 | 6g | 非 Pi agent 的提交落在它自己的分支上（期望 [2]，实际 [0]） | A | A2 |
| 32 | 6g | 它写了自己的报告（缺 /tmp/teamsmith-smoke.NLYVqd/repo/.worktrees/adapter/docs/team/reports/T1.2-adapter.m… | A | A2 |
| 33 | 6g | 报告内容来自它自己（/tmp/teamsmith-smoke.NLYVqd/repo/.worktrees/adapter/docs/team/reports/T1.2-adapter.md… | A | A2 |
| 34 | 6g | PM 收到了它的通知（走 TEAM_AGENT_NOTIFY_CMD）（/tmp/teamsmith-smoke.NLYVqd/repo/docs/team/inbox/pm.md 中找不到… | A | A2 |
| 35 | 6g | 活动流显示日志尾部（没有 Pi 会话也行）（/tmp/teamsmith-smoke.NLYVqd/monitor-nonpi.log 中找不到 [non-pi log B]） | A | A2 |
| 36 | 6h | A1：拒绝理由说清楚是「复用会话」（/tmp/teamsmith-smoke.NLYVqd/m43-a1.log 中找不到 [拒绝复用这个会话]） | A | A3 |
| 37 | 6h | A1：报出选中模型的窗口（来自 Pi 模型目录，不是猜的）（/tmp/teamsmith-smoke.NLYVqd/m43-a1.log 中找不到 [272000]） | A | A3 |
| 38 | 6h | A1：说清 token 是粗糙估算（JSONL 字节 ÷ 4）（/tmp/teamsmith-smoke.NLYVqd/m43-a1.log 中找不到 [÷ 4]） | A | A3 |
| 39 | 6h | A1：给出显式放行的出路（/tmp/teamsmith-smoke.NLYVqd/m43-a1.log 中找不到 [--allow-overflow]） | A | A3 |
| 40 | 6h | M4.3 A3：大窗口模型被误拒 | A | A3 |
| 41 | 6h | A3：复用的是同一个 session id（/tmp/teamsmith-smoke.NLYVqd/m43-a3.log 中没有匹配 [--session-id teamsmith-smok… | A | A3 |
| 42 | 6h | M4.3 A4：--allow-overflow 仍被拒 | A | A3 |
| 43 | 6h | A4：放行是醒目的警告（不是静默）（/tmp/teamsmith-smoke.NLYVqd/m43-a4.log 中找不到 [你显式放行了偏大的会话]） | A | A3 |
| 44 | 6h | A6：明说窗口解析不到（/tmp/teamsmith-smoke.NLYVqd/m43-a6.log 中找不到 [解析不到 nope/unknown 的窗口]） | A | A3 |
| 45 | 6h | A6：报出用的是保守阈值（不小于 200k）（/tmp/teamsmith-smoke.NLYVqd/m43-a6.log 中找不到 [保守阈值 200000]） | A | A3 |
| 46 | 6h | M4.3 A7：显式窗口覆盖没生效 | A | A3 |
| 47 | 6h | A8：启动命令用的是本次 --model（不是 state 里的旧模型）（/tmp/teamsmith-smoke.NLYVqd/m43-a8.log 中找不到 [--provider su… | A | A3 |
| 48 | 6h | A9：roster 显示已用/窗口并标出超窗（/tmp/teamsmith-smoke.NLYVqd/m43-roster.log 中找不到 [400k/272k ⚠]） | A | A3 |
| 49 | 6h | A9：ps 显示 dev 的会话大小（/tmp/teamsmith-smoke.NLYVqd/m43-ps.log 中找不到 [400k/272k]） | A | A3 |
| 50 | 6h | B1：残留窗口被显式 kill-window（失败路径也是真做，不是只在文案里说）（期望 [2]，实际 [3]） | A | A5b |
| 51 | 6i | 配了 {resume_args} → 文案说明怎么延续（/tmp/teamsmith-smoke.NLYVqd/pm-adapter-up3.log 中找不到 [续跑：--continue]… | A | A6 |
| 52 | 6i | resume 参数真的进了这一轮的 argv（/tmp/teamsmith-smoke.NLYVqd/pm-adapter-delta3.log 中找不到 [arg1=--continue]… | A | A6 |
| 53 | 6i | 窗口没被连诊断一起杀掉（报错还在 pane 里）（/tmp/teamsmith-smoke.NLYVqd/pm-adapter-failpane.txt 中找不到 [FAKE-PM-FAIL… | A | A5 |
| 54 | 6j | M8.2：窗口没被连诊断一起杀掉（报错还在 pane 里）（/tmp/teamsmith-smoke.NLYVqd/m82-die-pane.txt 中找不到 [M82-WORKER-DIE… | A | A5 |
| 55 | 6k | 6k ⑥ P210：resume --dry-run 把裸 shell 的席位列成可续跑（[teamsmith resume · repo | B | B1 |
| 56 | 11b3 | 期望 running:*（窗口里的进程就是配置的 agent），实际 missing | A | A6 |
| 57 | 11b4 | P36 ①：模板路径默认把 {resume_args} 渲染出来（[] 里找不到 [--continue]） | B | B2 |
| 58 | 11c | 崩溃 agent 的任务记录还在（/tmp/teamsmith-smoke.NLYVqd/repo/.pi/team/state/dev.env 中找不到 [task=T1.1]） | B | B3 |
| 59 | 11c | digest 仍把崩溃 agent 算成待办（/tmp/teamsmith-smoke.NLYVqd/digest-crash.log 中没有匹配 [停了的 agent [0-9]]） | B | B3 |
| 60 | 11c | 死窗口释放模型槽位（RUNNING=0）（期望 [0]，实际 [可用]） | B | B3 |
| 61 | 11c | resume --dry-run 能识别待续跑任务（/tmp/teamsmith-smoke.NLYVqd/resume-dry.log 中找不到 [可续跑：T1.1]） | B | B1 |
| 62 | 11c | resume 重新派单（/tmp/teamsmith-smoke.NLYVqd/resume.log 中找不到 [续跑 dev]） | B | B3 |
| 63 | 11c | resume 后 dev 窗口回来了（期望 [1]，实际 [0]） | B | B3 |
| 64 | 11c | up --agents 才会续跑 agent（/tmp/teamsmith-smoke.NLYVqd/up-agents.log 中找不到 [续跑 dev]） | B | B3 |
| 65 | 15b | 缺依赖不阻塞派单（--print 退出码 0）（期望 [0]，实际 [1]） | B | B3 |
| 66 | 15b | dispatch 告警依赖缺失（/tmp/teamsmith-smoke.NLYVqd/dispatch-deps.log 中找不到 [依赖缺失（不阻塞派单）]） | B | B3 |
| 67 | 15b | 告警点名 magic-context（/tmp/teamsmith-smoke.NLYVqd/dispatch-deps.log 中找不到 [magic-context]） | B | B3 |
| 68 | 15b | 告警点名 OpenSpec（/tmp/teamsmith-smoke.NLYVqd/dispatch-deps.log 中找不到 [OpenSpec]） | B | B3 |
| 69 | 15b | 告警每次派单只一行（期望 [1]，实际 [0]） | B | B3 |
| 70 | 22 | M9.3-①：--force 应当放行（见 /tmp/teamsmith-smoke.NLYVqd/m93-a-force.log） | A | A2 |
| 71 | 22 | 覆盖后真的走到派单计划（/tmp/teamsmith-smoke.NLYVqd/m93-a-force.log 中找不到 [=== agent 命令]） | A | A2 |
| 72 | 22 | M9.3-②：已结束的任务不该拦（见 /tmp/teamsmith-smoke.NLYVqd/m93-c-finished.log） | A | A2 |
| 73 | 22 | 照旧打印派单计划（/tmp/teamsmith-smoke.NLYVqd/m93-c-finished.log 中找不到 [=== agent 命令]） | A | A2 |
| 74 | 22 | M9.3-②：看板 done 时不该拦 | A | A2 |
| 75 | 22 | 照旧打印派单计划（/tmp/teamsmith-smoke.NLYVqd/m93-c-boarddone.log 中找不到 [=== agent 命令]） | A | A2 |
| 76 | 22 | M9.3-③：续跑被叠任务守卫误拦 | A | A2 |
| 77 | 22 | 续跑照旧打印派单计划（/tmp/teamsmith-smoke.NLYVqd/m93-d-same.log 中找不到 [=== agent 命令]） | A | A2 |
| 78 | 22 | resume --dry-run 仍把 M93C1 当成可续跑（/tmp/teamsmith-smoke.NLYVqd/m93-d-resume.log 中找不到 [可续跑：M93C1]） | A | A2 |
| 79 | 22 | M9.3-④：没有 state 时不该拒绝（见 /tmp/teamsmith-smoke.NLYVqd/m93-e-nostate.log） | A | A2 |
| 80 | 22 | 照旧打印派单计划（/tmp/teamsmith-smoke.NLYVqd/m93-e-nostate.log 中找不到 [=== agent 命令]） | A | A2 |
| 81 | 22 | M9.3-④：task= 为空时不该拒绝 | A | A2 |
| 82 | 22 | 照旧打印派单计划（/tmp/teamsmith-smoke.NLYVqd/m93-e-emptytask.log 中找不到 [=== agent 命令]） | A | A2 |
| 83 | 22 | M9.3-⑤：只剩一份任务书仍被拒（见 /tmp/teamsmith-smoke.NLYVqd/m93-f-single.log） | A | A2 |
| 84 | 22 | 控制组真的走到派单计划（/tmp/teamsmith-smoke.NLYVqd/m93-f-single.log 中找不到 [=== agent 命令]） | A | A2 |
| 85 | 22 | 控制组派的就是 M93E 这一次的 scope（/tmp/teamsmith-smoke.NLYVqd/m93-f-single.log 中找不到 [prompt-m93c-M93E.md]… | A | A2 |
| 86 | 25 | M9.8-②：这一拍按「待复验 1」判成有待办（/tmp/teamsmith-smoke.NLYVqd/m98-b-watch.log 中找不到 [待复验 1]） | A | A7 |
| 87 | 25 | M9.8-③：未读通知照旧叫醒（对照）（/tmp/teamsmith-smoke.NLYVqd/m98-c-watch.log 中找不到 [未读通知 1]） | A | A7 |
| 88 | 25 | M9.8-⑥：磁盘代码变了 25s 仍按旧代码判定（「待复验 1」没出现）—— 唤醒理由会比 digest 旧 | A | A7 |
| 89 | 26 | 26-g agent 表：session_tokens 非空（真实会话文件）（python: ） | A | A8 |
| 90 | 26 | 26-g agent 表：elapsed 保留在 JSON 里（python: ） | A | A8 |
| 91 | 31 | M28 真树有未隔离的 tmux 变更命令（见 /tmp/teamsmith-smoke.NLYVqd/m28-lint.log） | A | A9 |
| 92 | 31c | gateprobe 派单失败 | A | A2 |
| 93 | 31c | worker 窗口的 env 没落盘（gateprobe 没跑起来） | A | A2 |
| 94 | 31c | ⑪ worker 窗口里的 ad-hoc tmux 调用被记进 state/tmux-calls.log（/tmp/teamsmith-smoke.NLYVqd/repo/.pi/team/… | A | A2 |
| 95 | 31c | ⑪ 窗口日志带动作字段（/tmp/teamsmith-smoke.NLYVqd/repo/.pi/team/state/tmux-calls.log 中找不到 [act=]） | A | A2 |
| 96 | 31c | ⑪ CLI 自己的破坏性调用记 act=allowed-owned（M67 R2）（/tmp/teamsmith-smoke.NLYVqd/repo/.pi/team/state/tmux-… | A | A2 |
| 97 | 31c | ⑪ 记下的目标就是 CLI 自己的命名对象（/tmp/teamsmith-smoke.NLYVqd/repo/.pi/team/state/tmux-calls.log 中找不到 [argv… | A | A2 |
| 98 | 32 | 32⑧c 派单失败 | A | A2 |
| 99 | 32 | 32⑧c worker 窗口的 env 没落盘（探针没跑起来） | A | A2 |
| 100 | 12g | 12g A1 合法锚 → 放行（期望 [0]，实际 [1]） | A | A2 |
| 101 | 12g | 12g A1 打印了提示词（不是被拒）（[✗ ✗ brief 必须唯一 category: header；显式 override 不豁免 | A | A2 |
| 102 | 12g | 12g A2 合法锚 → 放行（期望 [0]，实际 [1]） | A | A2 |
| 103 | 12g | 12g A2 打印了提示词（不是被拒）（[✗ ✗ brief 必须唯一 category: header；显式 override 不豁免 | A | A2 |
| 104 | 12g | 12g A3 合法锚 → 放行（期望 [0]，实际 [1]） | A | A2 |
| 105 | 12g | 12g A3 打印了提示词（不是被拒）（[✗ ✗ brief 必须唯一 category: header；显式 override 不豁免 | A | A2 |
| 106 | 12g | 12g --force 确实越过了守卫（走到了建窗口）（期望 [yes]，实际 [no]） | A | A2 |
| 107 | 12h | 12h 不写 delta 的任务放行（期望 [0]，实际 [1]） | A | A2 |
| 108 | 12h | 12h alpha 的未结束兄弟不会拦别的 change（期望 [0]，实际 [1]） | A | A2 |
| 109 | 12h | 12h 已结束的兄弟不拦（期望 [0]，实际 [1]） | A | A2 |
| 110 | 12h | 12h 兄弟 done（且有证据）→ 不拦（期望 [0]，实际 [1]） | A | A2 |
| 111 | 12h | 12h --force 越过守卫（走到建窗口）（期望 [yes]，实际 [no]） | A | A2 |
| 112 | 12h | 12h [real] --force 派单成功（期望 [0]，实际 [1]） | A | A2 |
| 113 | 12h | 12h [real] 审计恰好一行（期望 [1]，实际 []） | A | A2 |
| 114 | 12h | 12h [real] 审计行点名两个任务与文件（/tmp/teamsmith-smoke.NLYVqd/p24/12h/.pi/team/state/watchdog.log 中找不到 [M… | A | A2 |
| 115 | 12h | 12h [real] monitor 的事件列看得到这条审计（[teamsmith pulse · 12h  08:30:07  巡检 900s · 待命 off | A | A2 |
| 116 | 12h | P140/R3：D1 按改行建议（deltas: -）写入后放行（期望 [0]，实际 [1]） | A | A2 |
| 117 | 12h | P140/R3：D2 按改行建议（deltas: panel）写入后放行（期望 [0]，实际 [1]） | A | A2 |
| 118 | 12h | P140/R3：D3 按改行建议（deltas: -）写入后放行（期望 [0]，实际 [1]） | A | A2 |
| 119 | 12h | P140/R3：逗号列表 panel, verification 被接受（示例形状真的能用）（期望 [0]，实际 [1]） | A | A2 |
| 120 | 12i | 12i 换一个 agent → 放行（期望 [0]，实际 [1]） | A | A2 |
| 121 | 12i | 12i 作者任务 dropped → 放行（期望 [0]，实际 [1]） | A | A2 |
| 122 | 12i | 12i 作者信号缺失（无 agent:）→ 放行（期望 [0]，实际 [1]） | A | A2 |
| 123 | 12i | 12i --force 越过守卫（期望 [yes]，实际 [no]） | A | A2 |
| 124 | 36 | 36⑧ 产品面检出探针有失败（17 条） | A | A9 |
| 125 | 41 | P55 ①：派单失败 | A | A2 |
| 126 | 41 | P55 ①：启动证据（spawn 证明）照常（/tmp/teamsmith-smoke.NLYVqd/p55-dispatch-1.log 中找不到 [含启动校验]） | A | A2 |
| 127 | 41 | P55 ①：agent 窗口的 remain-on-exit 读回是 on（设了且读回）（期望 [on]，实际 []） | A | A2 |
| 128 | 41 | P55 ①：agent 画面正常（marker 画上）（/tmp/teamsmith-smoke.NLYVqd/p55-pane-alive.txt 中找不到 [P55-MARK-5]） | A | A2 |
| 129 | 41 | P55 ①：席位恰好一个窗口（期望 [1]，实际 [0]） | A | A2 |
| 130 | 41 | §40 夹具：kill 前的 pgid 安全检查失败（p55w pid= pgid= my=1652836） | A | A2 |
| 131 | 41 | P55 ②：kill/等待遗体失败 | A | A2 |
| 132 | 41 | P55 ②：kill 之后窗口还在（pane_dead=1，遗体留存）（期望 [1]，实际 []） | A | A2 |
| 133 | 41 | P55 ②：退出证据 signal=9（不是退出码，是死因）（期望 [9]，实际 []） | A | A2 |
| 134 | 41 | P55 ②：窗口没跟 pane 一起消失（期望 [1]，实际 [0]） | A | A2 |
| 135 | 41 | P55 ②：遗体画面可读（-S - 含 scrollback；探针 P10：可见屏幕会丢最后一行）（/tmp/teamsmith-smoke.NLYVqd/p55-corpse.txt 中找… | A | A2 |
| 136 | 41 | P55 ③：输出点名座位已死 + 退出证据（/tmp/teamsmith-smoke.NLYVqd/p55-say.log 中找不到 [pane 已死（signal=9）]） | A | A2 |
| 137 | 41 | P55 ④：roster 四态 ③ dead（行内带退出证据）（/tmp/teamsmith-smoke.NLYVqd/p55-roster.log 中没有匹配 [^p55w +▲ 已死 s… | A | A2 |
| 138 | 41 | P55 ④：机器面断言失败 | A | A2 |
| 139 | 41 | P55 ④：status 点名该任务登记的席位（/tmp/teamsmith-smoke.NLYVqd/p55-status.log 中找不到 [座位 p55w]） | A | A2 |
| 140 | 41 | P55 ④：status 带退出证据（/tmp/teamsmith-smoke.NLYVqd/p55-status.log 中找不到 [signal=9]） | A | A2 |
| 141 | 41 | P55 ④：现场块标注记录时间（/tmp/teamsmith-smoke.NLYVqd/p55-status.log 中找不到 [记录时间：]） | A | A2 |
| 142 | 41 | P55 ④：现场块含 marker 行（/tmp/teamsmith-smoke.NLYVqd/p55-status.log 中找不到 [P55-MARK]） | A | A2 |
| 143 | 41 | P55 ④：TEAM_AGENT_SCENE_LINES=2 → 恰好两行现场（期望 [2]，实际 [0]） | A | A2 |
| 144 | 41 | P55 ④：digest 点名死 pane 席位（/tmp/teamsmith-smoke.NLYVqd/p55-digest.log 中找不到 [死 pane 席位]） | A | A2 |
| 145 | 41 | P55 ④：digest 行带退出证据（任务未结束 = 异常）（/tmp/teamsmith-smoke.NLYVqd/p55-digest.log 中找不到 [! p55w pane 已死… | A | A2 |
| 146 | 41 | P79：死 pane 段是 [7]，且只有段号变（正文逐字节同 P55）（/tmp/teamsmith-smoke.NLYVqd/p55-digest.log 中找不到 [[7] 死 pan… | A | A2 |
| 147 | 41 | P79：段号按序 [1]–[7]、[5] 历史重复成对（期望 [1 2 3 4 5 5 6 7]，实际 [1 2 3 4 5 5 6]） | A | A2 |
| 148 | 41 | P55 ④：doctor 一条告警点名死席位（/tmp/teamsmith-smoke.NLYVqd/p55-doctor.log 中找不到 [死 pane 席位 p55w]） | A | A2 |
| 149 | 41 | P55 ④：doctor 告警带退出证据（/tmp/teamsmith-smoke.NLYVqd/p55-doctor.log 中找不到 [signal=9]） | A | A2 |
| 150 | 41 | P55 ④：doctor 告警给现场入口（team status <ID>）（/tmp/teamsmith-smoke.NLYVqd/p55-doctor.log 中找不到 [status … | A | A2 |
| 151 | 41 | P55 ④：pending 的 stopped 计入「任务未结束 + 死 pane」的席位（期望 [1]，实际 [0]） | A | A2 |
| 152 | 41 | P55 ⑤A：复用 dispatch 失败 | A | A2 |
| 153 | 41 | P55 ⑤A·dispatch：复用消息点名「上一个 pane 已死」+ 证据（/tmp/teamsmith-smoke.NLYVqd/p55-reuse-1.log 中找不到 [上一个 p… | A | A2 |
| 154 | 41 | P55 ⑤A·dispatch：新一轮的启动证明照常（spawn nonce）（/tmp/teamsmith-smoke.NLYVqd/p55-reuse-1.log 中找不到 [含启动校验… | A | A2 |
| 155 | 41 | P55 ⑤A·dispatch：替换后恰好一个窗口（期望 [1]，实际 [0]） | A | A2 |
| 156 | 41 | P55 ⑤A·dispatch：新窗口仍带 remain-on-exit on（期望 [on]，实际 []） | A | A2 |
| 157 | 41 | P55 ⑤A·dispatch：现场文件记了座位（/tmp/teamsmith-smoke.NLYVqd/repo/.pi/team/state/dispatch-p55w-pane-dea… | A | A2 |
| 158 | 41 | P55 ⑤A·dispatch：现场文件记了退出证据（/tmp/teamsmith-smoke.NLYVqd/repo/.pi/team/state/dispatch-p55w-pane-d… | A | A2 |
| 159 | 41 | P55 ⑤A·dispatch：现场文件记了死亡时刻（/tmp/teamsmith-smoke.NLYVqd/repo/.pi/team/state/dispatch-p55w-pane-d… | A | A2 |
| 160 | 41 | P55 ⑤A·dispatch：现场文件的画面含 marker（/tmp/teamsmith-smoke.NLYVqd/repo/.pi/team/state/dispatch-p55w-p… | A | A2 |
| 161 | 41 | P55 ⑤A·dispatch：TEAM_AGENT_SCENE_LINES=3 → 现场恰好三行（期望 [3]，实际 [0]） | A | A2 |
| 162 | 41 | §40 夹具：kill 前的 pgid 安全检查失败（p55w pid= pgid= my=1652836） | A | A2 |
| 163 | 41 | P55 ⑤B 前置：第二轮 kill 没等到遗体 | A | A2 |
| 164 | 41 | P55 ⑤B：--fresh 复用失败 | A | A2 |
| 165 | 41 | P55 ⑤B·--fresh：复用消息点名「上一个 pane 已死」+ 证据（/tmp/teamsmith-smoke.NLYVqd/p55-reuse-2.log 中找不到 [上一个 pa… | A | A2 |
| 166 | 41 | P55 ⑤B·--fresh：新一轮的启动证明照常（spawn nonce）（/tmp/teamsmith-smoke.NLYVqd/p55-reuse-2.log 中找不到 [含启动校验]… | A | A2 |
| 167 | 41 | P55 ⑤B·--fresh：替换后恰好一个窗口（期望 [1]，实际 [0]） | A | A2 |
| 168 | 41 | P55 ⑤B·--fresh：新窗口仍带 remain-on-exit on（期望 [on]，实际 []） | A | A2 |
| 169 | 41 | P55 ⑤B·--fresh：现场文件记了座位（/tmp/teamsmith-smoke.NLYVqd/repo/.pi/team/state/dispatch-p55w-pane-dead… | A | A2 |
| 170 | 41 | P55 ⑤B·--fresh：现场文件记了退出证据（/tmp/teamsmith-smoke.NLYVqd/repo/.pi/team/state/dispatch-p55w-pane-de… | A | A2 |
| 171 | 41 | P55 ⑤B·--fresh：现场文件记了死亡时刻（/tmp/teamsmith-smoke.NLYVqd/repo/.pi/team/state/dispatch-p55w-pane-de… | A | A2 |
| 172 | 41 | P55 ⑤B·--fresh：现场文件的画面含 marker（/tmp/teamsmith-smoke.NLYVqd/repo/.pi/team/state/dispatch-p55w-pa… | A | A2 |
| 173 | 41 | P55 ⑤B·--fresh：TEAM_AGENT_SCENE_LINES=3 → 现场恰好三行（期望 [3]，实际 [0]） | A | A2 |
| 174 | 41 | §40 夹具：kill 前的 pgid 安全检查失败（p55w pid= pgid= my=1652836） | A | A2 |
| 175 | 41 | P55 ⑤C 前置：第三轮 kill 没等到遗体 | A | A2 |
| 176 | 41 | P55 ⑤C：resume 复用失败 | A | A2 |
| 177 | 41 | P55 ⑤C·resume：复用消息点名「上一个 pane 已死」+ 证据（/tmp/teamsmith-smoke.NLYVqd/p55-reuse-3.log 中找不到 [上一个 pan… | A | A2 |
| 178 | 41 | P55 ⑤C·resume：新一轮的启动证明照常（spawn nonce）（/tmp/teamsmith-smoke.NLYVqd/p55-reuse-3.log 中找不到 [含启动校验]） | A | A2 |
| 179 | 41 | P55 ⑤C·resume：替换后恰好一个窗口（期望 [1]，实际 [0]） | A | A2 |
| 180 | 41 | P55 ⑤C·resume：新窗口仍带 remain-on-exit on（期望 [on]，实际 []） | A | A2 |
| 181 | 41 | P55 ⑤C·resume：现场文件记了座位（/tmp/teamsmith-smoke.NLYVqd/repo/.pi/team/state/dispatch-p55w-pane-dead.… | A | A2 |
| 182 | 41 | P55 ⑤C·resume：现场文件记了退出证据（/tmp/teamsmith-smoke.NLYVqd/repo/.pi/team/state/dispatch-p55w-pane-dea… | A | A2 |
| 183 | 41 | P55 ⑤C·resume：现场文件记了死亡时刻（/tmp/teamsmith-smoke.NLYVqd/repo/.pi/team/state/dispatch-p55w-pane-dea… | A | A2 |
| 184 | 41 | P55 ⑤C·resume：现场文件的画面含 marker（/tmp/teamsmith-smoke.NLYVqd/repo/.pi/team/state/dispatch-p55w-pan… | A | A2 |
| 185 | 41 | P55 ⑤C·resume：TEAM_AGENT_SCENE_LINES=3 → 现场恰好三行（期望 [3]，实际 [0]） | A | A2 |
| 186 | 41 | P55 ⑥：短命 agent 派单失败 | A | A2 |
| 187 | 41 | P55 ⑥：正常退出后 pane 活着（pane_dead=0 —— harness exec 回 shell）（期望 [0]，实际 []） | A | A2 |
| 188 | 41 | P55 ⑥：exited 席位 resume 失败 | A | A2 |
| 189 | 41 | P55 ⑥：resume 后恰好一个窗口（期望 [1]，实际 [0]） | A | A2 |
| 190 | 41 | §40 夹具：kill 前的 pgid 安全检查失败（p55w pid= pgid= my=1652836） | A | A2 |
| 191 | 41 | P55 ⑦ 前置：kill 没等到遗体 | A | A2 |
| 192 | 41 | P55 ⑦：digest 仍点名遗体席位，但标明无登记任务（刻意保留）（/tmp/teamsmith-smoke.NLYVqd/p55-digest-closed.log 中找不到 [· p… | A | A2 |
| 193 | 41 | P55 ⑦：roster 仍如实显示遗体（诚实 ≠ 异常）（/tmp/teamsmith-smoke.NLYVqd/p55-roster-closed.log 中找不到 [▲ 已死 sign… | A | A2 |
| 194 | 54 | R4：末行计数 = 3（一次列全）（[✗ 拒绝派单：P200 的任务书 change: 行不合法 —— change: 的值是 `panel（说明）` —— 只接受一个 change id（… | A | A2 |
| 195 | 54 | R5：--print 也是同一份三项拒绝（[✗ 拒绝派单：P200 的任务书 change: 行不合法 —— change: 的值是 `panel（说明）` —— 只接受一个 change … | A | A2 |
| 196 | 54 | R5：粘贴三条修法后重派通过（期望 [0]，实际 [1]） | A | A2 |
| 197 | 54 | R5：重派真的起了 worker（假证据）（[✗ ✗ brief 必须唯一 category: header；显式 override 不豁免 | A | A2 |
| 198 | 54 | R5：重派真的开了一个窗口（期望 [yes]，实际 [no]） | A | A2 |
| 199 | 54 | R5：--print --force 两个覆盖项都放行（rc=0）（期望 [0]，实际 [1]） | A | A2 |
| 200 | 54 | R5：--force 真派单成功（假启动证据）（期望 [0]，实际 [1]） | A | A2 |
| 201 | 54 | R5：真派单走到开窗（[✗ ✗ brief 必须唯一 category: header；显式 override 不豁免 | A | A2 |
| 202 | 54 | R5：--force 恰每个覆盖项一行审计（期望 [2]，实际 [0]） | A | A2 |
| 203 | 54 | R5：审计行一（叠任务）（/tmp/teamsmith-smoke.NLYVqd/p140/force/.pi/team/state/watchdog.log 中找不到 [显式覆盖叠任务]） | A | A2 |
| 204 | 54 | R5：审计行二（锚缺失）（/tmp/teamsmith-smoke.NLYVqd/p140/force/.pi/team/state/watchdog.log 中找不到 [覆盖锚缺失]） | A | A2 |
| 205 | 54 | R6：成功派单写下本轮 sid（期望 [1]，实际 [0]） | A | A2 |
| 206 | 54 | R6：成功派单写下 sid_bytes（期望 [1]，实际 [0]） | A | A2 |
| 207 | 54 | R6：quota 预提示不阻断、不改退出码（期望 [0]，实际 [1]） | A | A2 |
| 208 | 54 | R6：预提示之后照旧打印计划（[✗ ✗ brief 必须唯一 category: header；显式 override 不豁免 | A | A2 |
| 209 | 54 | R6：一个字节没长的上一轮被点名（工具自己的粗粒度词）（[✗ ✗ brief 必须唯一 category: header；显式 override 不豁免 | A | A2 |
| 210 | 54 | R6：点名上一轮的会话（[✗ ✗ brief 必须唯一 category: header；显式 override 不豁免 | A | A2 |
| 211 | 54 | P151/F1：整行原样粘贴真的生效（rc=0）（期望 [0]，实际 [1]） | A | A2 |
| 212 | 54 | P151/F1：粘贴后真的派出去（不是又一个拒绝）（[✗ ✗ brief 必须唯一 category: header；显式 override 不豁免 | A | A2 |
| 213 | 54 | P151/F1：粘贴的路线真的开了窗（期望 [yes]，实际 [no]） | A | A2 |
| 214 | 54 | P151/F2：粘贴后同一派单通过（期望 [0]，实际 [1]） | A | A2 |
| 215 | 54 | P151/F3：粘贴容量修法（仍带低内存环境）后真的能派（期望 [0]，实际 [1]） | A | A2 |
| 216 | 54 | P151/F3：覆盖路线走到开窗（[✗ ✗ brief 必须唯一 category: header；显式 override 不豁免 | A | A2 |
| 217 | 54 | P151/F5：首轮派单成功（假启动）（期望 [0]，实际 [1]） | A | A2 |
| 218 | 54 | P151/F5：shim 在启动时写了 8 字节（本轮产出）（期望 [8]，实际 [0]） | A | A2 |
| 219 | 54 | P151/F5：sid_bytes 记的是**启动前**的字节数（旧实现会记成启动后的 8）（期望 [0]，实际 []） | A | A2 |
| 220 | 54 | P151/W3：同任务另一 slug 的分支被接受（期望 [0]，实际 [1]） | A | A2 |
| 221 | 54 | P151/W3：计划里点名守卫接受的分支（[✗ ✗ brief 必须唯一 category: header；显式 override 不豁免 | A | A2 |
| 222 | 54 | P151/W3：提示词写的是工作树的分支（[✗ ✗ brief 必须唯一 category: header；显式 override 不豁免 | A | A2 |
| 223 | 54 | P151/W3：真派单成功（期望 [0]，实际 [1]） | A | A2 |
| 224 | 54 | P151/W3：state 的 branch= 与提示词同源（期望 [task/P1-legacy]，实际 []） | A | A2 |
