# E8 · explore：harness 能力探测 + 后台任务完成通知插件

agent: verify   status: DONE   time: 2026-09-17T17:45:00Z
branch: `task/E8-explore-harness-pi`   PR/MR: -（本仓库 local 模式，分支留本地，PM 复验后本地合并）

探索任务，只产报告不改实现。起因（brief）：PM 把 ~6 分钟的长门禁放到后台 tmux 窗口跑，做完没人知道；
用户拍的插件方向 + 两个提示：① init 要知道用户用的 harness（点头了 oh-my-pi），有的 harness 自带后台任务，
那时不必自建；② init 应能给 pi 用户推荐后台任务类扩展。

**证物**：`docs/team/reports/E8-verify/`（`citations.md` 是全部**原文引用**，`probes/` 是可复跑的探针与驱动，
`logs/` 是本次全部实测输出；`bash run-all.sh` 一键复跑，沙盒在 `/tmp/e8-sandbox`，不碰任何项目/团队配置）。

**验收命令**（brief 要求，已实跑；全文 `logs/gates-openspec-fast-smoke.log`）：

```
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
Totals: 13 passed, 0 failed (13 items)                    （rc=0）

$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh
== 结果 ==  ✓ 1430  ✗ 0        smoke 全绿                （rc=0）
```

本任务只新增 `docs/team/reports/E8-verify.md` 与 `docs/team/reports/E8-verify/**`，**未动** `skills/**`、
`openspec/**`、账本，因此上面这条门禁的结果与本报告同树成立。

## 结论摘要（逐问一句话，证据在下面各节）

1. **oh-my-pi（omp）确实自带后台任务**：它是 **pi 的 fork**（MIT），`bash` 有 background-job dispatch、
   `hub` 能 wait/cancel/subscribe 长进程、`/jobs` 列 async tool jobs、`task` 并行子 agent；完成通知就是
   「Background job completed」system notice（issue #689 是它的投递语义缺陷记录）。
2. **pi 扩展足够做出这件事（已实测）**：能注册自定义工具、能 spawn 脱离进程并立刻返回，且能在
   **事件处理器之外**用 `pi.sendMessage(…, {triggerTurn:true, deliverAs:'followUp'})` **把 idle agent 唤醒**
   ——RPC 事件流里能看到 `agent_settled → agent_start`（零用户输入）。
3. **生态里已有成熟包，不必自写**：`pi-background-tasks` 2.5.0 与 `@aliou/pi-processes` 0.12.0 都在本机
   pi 0.85.1 上**装上即用**；`pi-background-tasks` 的 `bg_run` 在实测里完成了「立刻返回 → 回合结束 → 完成通知
   → 唤醒 agent」的全链路。
4. **init/doctor 探测清单可落地且不花模型调用**：探 harness（pi vs omp vs 自定义 adapter）、探包
   （`.pi/settings.json` + `pi list --approve`）、探**真的加载了**（`pi --mode rpc` 发 `get_commands` 看
   `bg`/`jobs`/`ps` 是否注册）；探到→不推荐，探不到→推荐安装，omp→什么都不用装。
5. **与 teamsmith 的接口**：PM 的后台复验建议直接换成「后台任务包 + 完成通知」，把 tmux 敲窗降为兜底；
   worker 的「回合结束不许有未收割后台作业」**能机械执行**（探针证明：已收割静默 / 未收割唤醒），
   代价是插件要自己记账（`agent_settled` 时登记未收割作业），因为 omp issue #689 证明「无脑通知」会多烧回合。
6. **推荐**：**不要自写 runner**；Phase 1（半天）＝ doctor/init 探测 + 推荐安装文案 + 把 PM 的后台门禁
   写法写进文档；Phase 2（可选，1 天）＝ 若要零第三方依赖，自写 ~100 行的 `team-bg.ts`（照 `file-trigger.ts`
   的形态 + 复用 `team-notify.ts` 的守卫）。风险：第三方包的 blast radius（`pi-background-tasks` 会全局挂
   Anthropic attribution provider）、包很年轻（版本 1–48 不等）、唤醒过量（#689）。

---

## 1. oh-my-pi 是否真支持后台任务（Q1）

**是什么**：`omp` 是 **pi 的 fork**（作者 can1357；README：「omp is a fork of Pi … rewritten as a coding-first
surface: sessions, subagents, slash commands, extensions — all TypeScript, all MIT」），入口 <https://omp.sh>，
源码 <https://github.com/can1357/oh-my-pi>。扩展形态与 pi 相同（README：「An extension is a TypeScript module.
**Same tool API, same slash-command registry, same hotkey table, same TUI primitives the built-ins use.**」）。

**后台任务能力（README 原文）**：

- 工具 `bash`：「workspace shell with 46 in-process coreutils, optional PTY, and **background-job dispatch**」
- 工具 `hub`：「**message live agents, wait on or cancel background jobs, and supervise long-running processes**」
- 工具 `task`：「fan out subagents in parallel, optionally workspace-isolated」
- UI：`Alt+A` 打开 Agent Hub，能看每个 subagent 的活动/用量、读它的实时 transcript、**steer / revive（唤醒 parked）/ kill**。

**完成如何通知启动它的 agent**：`docs/agent-hub.md` —— 「`/jobs` prints a snapshot of running and recently
settled asynchronous tool jobs」；完成通知本身是 system notice（见下），且 GitHub issue #689 的原标题就是
「"Background job completed" keeps triggering the agent after turn concluded」。

**它的已知投递缺陷（issue #689，2026-04-11 报 / 2026-04-12 关）** —— 这条对 teamsmith 直接有用，

> The "Background job completed" system notice is delivered after the agent has finished execution. In many
> cases this leads to the agent being supplied the same information that was already processed again, if it
> already **awaited the jobs before**. … each will trigger exactly one additional turn, causing multiple
> (possible expensive) loops …
> Expected: **(1) Do not deliver "Background job completed" for jobs that were already awaited；(2) Group
> multiple pending "Background job completed" into a single system notice to be delivered as soon as the
> agent is free.**

→ 结论：**omp 用户不需要我们自建后台任务**；但「什么时候该通知、通知要不要唤醒」这条设计题**omp 自己都踩过**，
我们若自写必须把 #689 的两条（已收割不通知、多条合并成一条且等 agent 空闲）写进设计。

（未做：本机没有 omp，未安装实测 —— 上面全部是官方 README/docs 与 issue 的原文引用。装着能不能跑、
它的扩展发现路径是否与 pi 相同，属未验证。）

## 2. pi 扩展能力边界（Q2：实测 + 文档原文）

### 2.1 文档给出的边界

- **pi 没有内置后台 bash**（`docs/usage.md`）：「It intentionally does not include built-in MCP, sub-agents,
  permission popups, plan mode, to-dos, or **background bash**. You can build or install those workflows as
  extensions or packages, or use external tools such as containers and tmux.」
- **注册自定义工具**：`pi.registerTool({name, label, description, parameters, async execute()})`——文档明确
  「works both during extension load and after startup… New tools are refreshed immediately in the same session」。
- **主动唤醒**：`pi.sendMessage(message, {deliverAs, triggerTurn})`；文档原文：
  「`triggerTurn: true` — **If agent is idle, trigger an LLM response immediately.** Only applies to `"steer"`
  and `"followUp"` modes」。`deliverAs` 三档：`steer`（当前回合的工具调用跑完后插进去）、`followUp`
  （等 agent 没有工具调用了再送）、`nextTurn`（只排队，不打扰）。`pi.sendUserMessage()` 等价于用户真的打了字，
  总是触发一轮。
- **生命周期钩子**（`agent_settled` = 「no retry/compaction/follow-up left」；`rpc.md`：settled 后「Pi will
  not continue automatically through retry, compaction retry, or queued follow-up messages」）——这就是
  「现在真的闲了」的可靠信号，也是 `team-notify.ts` 现在用的钩子。
- **约束**：`factory` 里**不许**起后台资源（process/socket/watcher/timer），要放到 `session_start`，
  并在 `session_shutdown` 里收尾 —— 自写插件必须遵守这条。
- **官方示例 `examples/extensions/file-trigger.ts`（41 行）** 就是「外部完成 → 唤醒会话」的教科书形态：
  `fs.watch('/tmp/agent-trigger.txt')` → `pi.sendMessage({...}, {triggerTurn: true})`。

### 2.2 实测（`probes/bg-wake.ts` + `probes/drive.py`，日志 `logs/probe1-wake.log`、`logs/probe1-ext.log`）

自写扩展注册 `bg_demo(tag)`：spawn 脱离子进程（`sleep 3` 后写输出文件）→ 工具**立刻返回** pid；子进程 exit
时在 **async 回调里**（不在任何事件处理器里）调 `pi.sendMessage(..., {triggerTurn:true, deliverAs:'followUp'})`。
用 `pi --mode rpc` 驱动（deepseek-flash，`--no-session`），RPC 事件流（`logs/probe1-wake.log` 节选，时间是同一棵树）：

```
+   2.4s  tool_execution_start tool=bg_demo
+   2.4s  tool_execution_end tool=bg_demo err=False
+   2.4s  message_end role=toolResult text='job alpha started (pid 574844); this tool returns immediately, a notice will arrive when it exits'
+   2.8s  message_end role=assistant text='DONE'
+   2.9s  agent_end / agent_settled                 ← 回合结束、agent 空闲，作业还在跑
+   5.4s  agent_start                               ← 零用户输入，被唤醒
+   5.4s  message_end role=custom text='bg_demo(tag=alpha) finished with exit code 0; output file: /tmp/e8-sandbox/out-alpha.txt'
+   8.0s  message_end role=assistant text='alpha finished (exit 0). Standing by.'
+   8.0s  agent_settled
```

扩展自己的日志（`logs/probe1-ext.log`）印证三个时刻互相对得上：
`tool bg_demo returned immediately pid=574844`（17:32:54.554）→（17:32:55.012 agent_settled）→
`child exited code=0 → pi.sendMessage(triggerTurn:true)`（17:32:57.557）→ 17:33:00.199 turn_end/agent_settled。

**最小可行形态**（Q2 的答案）：约 60–100 行 TypeScript —— 一个 `registerTool` + 一张 job 表 + `child.on('exit')`
里的 `sendMessage(triggerTurn)`（再加 §5 的收割/合并规则）。不需要 pi 改任何东西。

### 2.3 顺带验证的「收割即静默」（`probes/bg-wake2.ts` + `probes/drive2.py`）

同一扩展的两种用法，一对可证伪的对照（日志 `logs/probe2-awaited.log` / `logs/probe2-unawaited.log` /
`logs/probe2-ext.log`）：

| 场景 | 期望 | 实测 |
|---|---|---|
| agent 用 `bg_wait2` **收割**了作业再结束回合 | 完成时**静默**（不再唤醒） | `bg_wait2` 在 +5.3s 把结果内联返回；+6.5s settled；插件日志 `child exited … -> SUPPRESSED (already harvested by bg_wait)`；此后**没有** `bg-demo2` 的 custom 消息 |
| agent **没等**就结束回合（`bg_demo2` → 直接回 DONE） | 完成时**唤醒** | +2.5s settled → +5.1s `agent_start` + custom 消息 → +6.2s settled |

（诚实标注一个干扰项：`probe2-awaited.log` 里 5.9s 多了一次 `ctx_reduce` 工具调用 —— 那是本机**全局**装的
`@cortexkit/pi-magic-context` 扩展自己注入的 follow-up，不是我们的通知；这也说明「回合之外多了一轮」不能当
判据，判据必须是**插件自己的 job 表**。）

## 3. 生态检索：有没有现成的 pi 后台任务扩展（Q3）

**有，而且不止一个**。npm registry 实测（2026-09-17，`curl https://registry.npmjs.org/<pkg>`）：

| 包 | latest | 最后发布 | 版本数 | 形态 |
|---|---|---|---|---|
| `pi-background-tasks` | 2.5.0 | 2026-09-04 | 25 | `bg_run/bg_status/bg_logs/bg_result/bg_kill` + `bg_delegate` + fusion；命令 `/bg /jobs /logs /kill …`；EventBus 通道；durable 通知 |
| `@aliou/pi-processes` | 0.12.0 | 2026-08-27 | 48 | `process` 工具 + `/ps` 系列 UI；「被自动叫回来」；多个 fork 衍生 |
| `pi-better-background-tasks` | 0.2.13 | 2026-09-17 | 32 | durable 后台 shell 任务、watchers、日志 |
| `pi-monitor-plugin` | 0.1.1 | 2026-06-18 | 2 | background/monitor/loop/schedule + **idle-aware 通知** |
| `pi-event-monitor` | 0.1.0 | 2026-05-12 | 1 | 进程退出/输出匹配/文件写入时**唤醒会话** |

同一份 `pi-processes` README 还列了：`pi-tian-background-terminals`（"replaces Pi's built-in Bash with
automatic background yielding, **completion notifications**, and a `/ps` viewer"）、`pi-patty-bg-tasks`
（Claude Code 风格）、`@richardgill/pi-background-bash`、`pi-bash-bg`、`pi-pwsh-notify`（Windows）、
`pi-tripwire`、`@cortexkit/aft-pi` 等十多个同类。

**实测（本机 pi 0.85.1，全部在沙盒项目里，`logs/`）**：

1. **装得上、项目级、1 秒**：`pi install npm:pi-background-tasks@latest -l` → `added 3 packages in 1s`，
   rc=0，`.pi/settings.json` = `{"packages":["npm:pi-background-tasks@latest"]}`
   （`logs/settings-project-pi-background-tasks.json`）；`pi install npm:@aliou/pi-processes -l` →
   `added 4 packages in 970ms`（`logs/settings-project-aliou-pi-processes.json`）。
2. **真的加载了**（不花模型调用）：`pi --mode rpc` + `{"type":"get_commands"}` ——
   `pi-background-tasks` 注册了 `bg, bg-clear, bg-tasks, bg-update, fusion, fusion-models, jobs, kill, logs, tasks`
   （外加它自带的 `claude-cache`）；`@aliou/pi-processes` 注册了 `ps, ps:clear, ps:dock, ps:kill, ps:logs,
   ps:pin, ps:settings`（`logs/commands-registered.txt`）。
3. **端到端解决了 PM 的问题**（`probes/drive3.py`，`logs/probe3-installed-package.log`）：让 agent 调
   `bg_run{name:"e8probe",command:"sleep 4; echo e8-done"}` 后**直接结束回合**（明确要求不要等），
   RPC 事件流：

```
+  2.4s  tool_execution_end tool=bg_run    text='Started background task e8probe (b35bbf096) … PID: 1234996 …'
+  3.2s  message_end role=assistant text='DONE'
+  3.2s  agent_settled                      ← 作业还在跑，agent 已空闲
+  6.4s  agent_start                        ← 包自己把 agent 叫回来了
+  6.4s  message_end role=custom text='<background-task-notification><task-id>b35bbf096</task-id>
                                          <task-name>e8probe</task-name><status>compl…'
+  7.3s  message_end role=assistant text='后台任务 e8probe 已完成（退出码 0）。'
+  7.3s  agent_settled
```

**「推荐安装」vs「自写」的判断**：

- **推荐安装**（首选）：PM 的全部诉求（长门禁后台跑 + 做完有人知道）已被 `pi-background-tasks` 这类包
  直接覆盖，且实测 1 秒装好、加载正常、唤醒可靠。
- 但有两个必须写进推荐文案的坑：
  1. **用户自己拍的 `/bg` 不唤醒模型**（包页原文：「User-launched `/bg` tasks notify in the UI but do
     **not** automatically wake a follow-up model turn.」）——想让 agent 被叫回来，必须由 **agent 调 `bg_run`**，
     或者接受「只有 UI 提示」。这条直接决定 teamsmith 的用法说明怎么写。
  2. **blast radius**：`pi-background-tasks` 的 README 自述「Normal installations **globally load** the
     package-owned Claude Code OAuth attribution/sanitization provider for Anthropic sessions」——
     它不只是后台任务，会顺带接管 Anthropic 路线的 attribution。对这个仓库（多 provider、含订阅账号）
     这是个要交代清楚的副作用；更窄的替代是 `@aliou/pi-processes`（纯进程管理，48 个版本更成熟，
     但要接受它的 fork 家族生态）。
- **自写**只在两种情况下值得：① 要**零第三方依赖**进关键路径；② 要把「收割/未收割」这类 teamsmith 规则
  做成硬机制（§5）。

## 4. init/doctor 的 harness 能力探测（Q4 设计）

现有 `team doctor` 已经是 `check/pass/warn/fail` 表格（`skills/teamsmith/scripts/lib/cmd-project.sh:295+`：config /
docs 骨架 / bash / git / tmux / pi / agent adapter / agent notify / 门禁 / 名册 / worktree …）。建议加三行，
**都不花模型调用**：

| 新检查 | 命令（全部实测过） | 判定与行为 |
|---|---|---|
| `harness` | `command -v omp` + `omp --version`；否则 `pi --version`（已有）；`TEAM_AGENT_CMD` 非空 → 自定义 adapter | omp → `! omp 自带后台任务（bash 后台派发 / hub wait·cancel / /jobs）→ 不需要装插件`；pi → 走下一行；自定义 → `! 后台能力取决于该 harness，无法探测` |
| `background jobs`（包探测） | `pi list --approve` 与项目 `.pi/settings.json` 里找已知包名 | 命中 → `✓ npm:pi-background-tasks@latest（项目级）`；未命中 → `! 长任务会阻塞回合：`pi install npm:pi-background-tasks@latest -l``（或更窄的 `npm:@aliou/pi-processes`） |
| `background jobs`（**加载**探测，可选加固） | `pi --mode rpc` 发 `{"type":"get_commands"}`，grep 该包的命令签名（`bg`/`jobs`/`ps`） | 设置里有包但命令没注册 → `! 包在 settings 里但没加载（跑 pi list --approve 核对；命令签名缺失）` |

**探测到 / 探测不到 的行为**（写进 init 文案）：

- **探测到**（或 harness = omp）：不推荐任何东西；在 `docs/team/` 的交接说明里写一句「长任务走后台任务工具，
  完成会自动叫回你」；pulse/tmux 敲窗仍保留为兜底（老路径不改）。
- **探测不到**：`init` 打印一条**可复制**的推荐（`pi install npm:pi-background-tasks@latest -l`）+ 一句
  「装不了就退回现有方案：后台 tmux 窗口 + `team notify`/收件箱」（PM 的原垫底方案），并把这个决定写进
  「记录在案的边界」，避免以后每次都要重新讨论。
- **探测的诚实性**：doctor 只能证明「包在、命令注册了」；「这一次运行里它会真的唤醒」是运行期行为
  （本节实测过，但探测本身不去跑一个真任务 —— 那会花模型调用、也可能真的起进程）。

## 5. 与 teamsmith 的接口（Q5）

**现状（仓库内证据）**：`skills/teamsmith/extension/team-notify.ts` 在 `agent_settled` 时写 PM 收件箱 +
（可选）敲 tmux 窗口；同一个文件里已经在用 `pi.sendMessage({customType:'teamsmith-reloaded'}, {deliverAs:'followUp',
triggerTurn:true})` 叫醒会话 —— 也就是说 **teamsmith 的通知通道与唤醒机制今天就在手边**。

**PM 的后台复验（`team review`）走插件后长什么样**（两种，按体检结果选）：

- **A（装了后台任务包）**：PM 让 agent 调后台任务工具（`bg_run` / `process`）跑门禁，PM 回合正常结束；
  门禁完成 → 包的 terminal notification → PM 被唤醒去读结果。PM 不再需要「知道哪个 tmux 窗口在跑什么」。
  注意 A 的两个前提：**必须是 agent 侧启动**（用户 `/bg` 不唤醒，§3）、**通知要合并**（多条一起到，别一条一轮）。
- **B（不装包，零依赖）**：保留 tmux 窗口，但让完成方**写一个 trigger 文件**（`file-trigger.ts` 的形态），
  或者直接复用 teamsmith 自己的收件箱文件；PM 侧由一个 ~40 行的扩展 `fs.watch` → `sendMessage(triggerTurn)`。
  适合「只想补这个洞、不想引第三方」的场景。

**worker 侧规则「回合结束不许有未收割后台作业」如何被机械执行**（这是我实测过的部分）：

1. 插件维护一张 **job 表**（session 级），`agent_settled` 时检查「未收割」集合；
2. 未收割 → 按 §2.3 的判据**唤醒并提醒**（探针 2 证明「收割过就静默 / 没收割就唤醒」是可判定的）；
3. 已收割 → **静默**（omp issue #689 的第 1 条）；同一拍有多条 → **合并成一条**再投递（第 2 条）；
4. 同时把 `settled-with-unharvested=<n>` 追加进 `state/` 的日志（一行一事件）——这样 PM 的复验、
   `team digest` 甚至门禁脚本都能*读*到「这个 worker 结束回合时还有没收割的作业」，规则就从口头约定
   变成可检查的事实。这正好复用 teamsmith 现有的「事件证据」习惯（`state/*.log`）。

**可选的更深接口**：`pi-background-tasks` 暴露了 EventBus 通道（`pi-background-tasks:request:v1` /
`:response:v1` / `:terminal:v1`，操作 `capabilities/run/status/logs/kill`），文档自述是「the integration point
for orchestrators that need non-blocking package-managed work with bounded logs and correlated terminal events」。
teamsmith 若要认真编排（PM 派后台复验、worker 后台跑门禁），可以订阅 `terminal:v1` 而不是自己扫日志；
代价是**多一个第三方契约依赖**，建议等 Phase 1 的数据说话。

## 6. 推荐方案与工作量（Q6）

**推荐：Phase 1 先「探测 + 推荐 + 文档」，不自写 runner。**

| 阶段 | 内容 | 谁做 | 工作量 | 证据支撑 |
|---|---|---|---|---|
| **P1** | doctor 加 `harness`/`background jobs` 三行检查（§4 的命令都已实测）；`init` 打印可复制的推荐文案（含「omp 不用装」「用户 `/bg` 不唤醒」两条坑）；在 `docs/team/` 里把「长门禁怎么跑」写成固定配方（agent 侧启动 + 完成唤醒 + 合并通知） | PM/dev | **0.5 天**（探测部分 ~2 小时，文案/文档 ~2 小时） | §3 的安装/加载/端到端实测 + §4 的命令 |
| **P2** | 若要零第三方依赖：自写 `skills/teamsmith/extension/team-bg.ts`，~100–150 行（`registerTool` + job 表 + `exit` 唤醒 + 收割/合并 + `state/bg.log`），复用 `team-notify.ts` 的守卫与去重；worker 规则由它登记、PM 侧读日志 | dev | **1 天**（含 2 个翻转测试：未收割→唤醒、已收割→静默） | §2.2/§2.3 的探针可直接改造成测试 |
| **P3** | worker 也用后台任务（跑长门禁、长构建）；把「收割后结束回合」写进 worker 提示词 + 复验检查项 | PM/dev | 0.5–1 天（要先有 P1/P2 的运行数据） | 同上 + omp #689 的两条规则 |

**风险（逐条给依据）**：

1. **第三方 blast radius**：`pi-background-tasks` 自述会全局加载 Anthropic attribution provider（§3）；
   本仓库多 provider + 订阅账号，装之前应让用户知道。更窄的 `@aliou/pi-processes` 可作为平替。
2. **包年轻**：`pi-event-monitor` 1 个版本、`pi-monitor-plugin` 2 个；主力两个（25/48 个版本、最近
   2026-09-04 与 2026-08-27）维护活跃，但仍应钉版本（`@latest` 建议改成显式版本）。
3. **唤醒过量**：omp #689 的原文教训；设计里必须有「已收割不通知 + 多通知合并 + 空闲才投递」。
4. **`triggerTurn` 的投递语义**：只在 `steer`/`followUp` 有效，且「idle 才立刻起一轮」——agent 忙的时候会
   排队/插队，选哪一档是产品决定（PM 的后台复验建议 `followUp`；worker 的紧急纠偏才用 `steer`）。
5. **omp 用户**：他们自带后台能力；推荐文案必须分叉，否则会去装只服务 pi 的包（omp 与 pi 扩展 API 相同，
   但「推荐装什么」不该假定是 pi）。

## 7. 未验证 / 边界

- 只读探索：**没有**改 `skills/**`、`openspec/**`、任何项目/团队配置；两个包只装在 `/tmp/e8-sandbox/proj*`
  的**项目级** settings 里（沙盒），探针扩展用 `-e` 加载、没有安装。
- **没装 oh-my-pi**（本机没有）：Q1 全部结论来自官方 README / `docs/agent-hub.md` / issue 原文，属**引文证据**，
  不是实测。
- 未实测：包在**交互 TUI** 下的表现（我用的是 `--mode rpc`）；`pi-background-tasks` 的 `/bg`（用户启动路径）
  为什么不唤醒 —— 只有包页自述，没有源码级验证；多包共存（`pi-background-tasks` + `@aliou/pi-processes` 同时装）
  的冲突未测。
- 探针里的模型调用用的是本机默认 `deepseek/deepseek-flash`（很小）；探针脚本与日志已提交，可一键复跑
  （`bash docs/team/reports/E8-verify/run-all.sh`；注意它**会**花少量模型调用，`probes/*.py` 里 PI 路径写死
  本机 `<home>/.bun/bin/pi`）。
- 提交的驱动脚本在跑完后做过一次小改（用 `select` 替代阻塞 `readline`，避免驱动在第二个 `agent_settled`
  之后再干等超时）；日志里的**事件序列不受影响**（改动只影响等待时长）。

## Decisions and deviations

- **实测优先的取舍**：Q1 只能用引文（本机没有 omp，装一个 fork 属于大动作且越界风险高）；Q2/Q3 全部做了
  实测（自写探针 + 装两个包 + RPC 事件流 + 端到端唤醒）。
- **没有自写插件**：按「先探测/推荐」的顺序，本任务不产出实现（brief 也要求不改 `skills/**`）；§2.2 的探针
  是自写路线的最小验证，留作 P2 的起点。
- **Q4 的「加载探测」建议用 RPC `get_commands`** 而不是解析 `pi --help`：`get_commands` 是官方契约
  （扩展/提示模板/skill 都在里面），实测可靠；`pi list --approve` 只证明「装了这个包」。

## Suggested next steps

- 给用户拍三件事：① 是否接受第三方包进关键路径（`pi-background-tasks` vs `@aliou/pi-processes` vs 自写）；
  ② 推荐文案里 `pi install … -l` 是**项目级**（默认建议）还是全局；③ P2 要不要排期（自写 `team-bg.ts`）。
- 若同意 P1：把 §4 三行检查 + §3 的推荐文案落成一个 `M2x`/`P1x` 任务（`skills/**`，PM 派单）；
  测试用 `probes/gate-capability-probe` 形态（`pi --mode rpc` + `get_commands`，零模型调用，可进 smoke）。
- 归档这份探索时：`citations.md` 的原文引用建议保留，它是「为什么推荐装而不是自写」的唯一论据链。
