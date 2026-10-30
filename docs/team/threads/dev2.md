### 2026-09-14T12:59:33Z · from: pm · re: -
退回 M6.2：F14 的修复不完整（其余 7 条我已独立复验通过：F7/F8/F9/F10/F11/F12/F3 都对，F13 也正确拒绝）。

PM 复现（在 scratch 项目里用你分支的 CLI，报告按**我们自己的模板**写）：

  报告内容（节选）：
    ## Flip evidence
    Red before: guard test failed (see pkg/flip red log)
    Green after: guard test passes
    ## Independent verification package
    pkg/run.sh (written for this task, does not reuse the implementation fixtures)

  命令：team review P1 --dir <checkout> --branch <sha> --strong --no-gates
  记录判定：**不满足** —— "缺：翻转：没有 flip/翻转/red→green/破坏实现 小节标题；独立包：报告里没有指向包/脚本的路径（只提到"独立"这种词不算）"

问题：匹配器不认**我们自己模板里的标题**（templates/report.md.tmpl 就是 `## Flip evidence`），也不认 `pkg/run.sh` 这种路径 → 真报告被判缺证据（正是 F14 那条 finding 本身）。

要求（改完把复现贴回报告）：
1. 判定必须与 `templates/report.md.tmpl` / `references/protocol.md` 里**实际使用的措辞**对齐，大小写不敏感：
   小节标题至少接受 `flip evidence` / `flip` / `red before` + `green after` / `break the implementation`；
   独立包接受形如 `.../pkg/run.sh`、`docs/team/reports/<ID>-<agent>/pkg/...`、任何指向脚本/目录且**真实存在**的路径。
2. 加**双向**回归测试，且测试文本直接取自模板（或读模板文件），这样"检查器 ↔ 模板"不会再漂移：
   - 关键词汤（"这里没有翻转证据，这些词只是出现"）→ 不满足；
   - 模板形状的真报告（含 `## Flip evidence` + red/green 结果 + 真实存在的 pkg 路径）→ 满足。
3. F13 的拒绝行为要保持不变。

### 2026-09-14T17:14:25Z · from: pm · re: -
M7.2 现场提醒（我抓到的，请交付前修掉）：

你的 `skills/teamsmith/tests/flip-m7.2.sh:132` 里这句
  $TEAM notify dev "M7.2 flip：有待办"
在 17:07:53–17:09:46 之间往**真实仓库**的收件箱写了 9 条（`docs/team/inbox/dev.md`），watchdog 因此把我叫醒了 9 次
——也就是说：**夹具把幻影待办喂进了真账本**。这属于"测试隔离"这一类，我们之前踩过一次（smoke 曾经把真实 PM 打死）。

要求（交付前）：
1. 夹具必须在**沙箱仓库**里跑 `team`，并且像 smoke 的 14 节那样：
   - 先清掉继承来的 `TEAM_*` 身份（`env -u TEAM_ROOT -u TEAM_SESSION -u TEAM_DOCS_DIR …` 或显式指定）；
   - 断言 `team paths` 解析出的 `main_root` 就是临时仓库（不是 `/home/.../pm-skills`），**通过之后**才允许调用会写盘的命令
     （`notify` / `say` / `board` / `dispatch`…）。
2. 加一条**反向守卫**：跑完夹具后断言真实仓库的 `docs/team/inbox/**` 与 `.pi/team/state/**` 未被改动（跑前后取 hash 或 mtime 对比，
   任一变化即 fail 并打印差异）。
3. 同样问题在 **smoke 的新段**里也要检查一遍：门禁是每个 agent 每次交付都会跑的，一旦它写真实收件箱，
   等于每次门禁都朝 PM 脸上扔幻影任务。
4. 报告里补一行"隔离证据"：`team paths` 的输出片段 + 真实仓库 inbox 前后 hash 相同。

（M5.1 当时也做过类似的事：为了让配额分支走到，它造了一条未读通知——但那是**夹具仓库**里的通知，不能落到真账本。）

### 2026-09-15T07:47:34Z · from: agent:dev2 · re: -
**用户需求（用户点名要 dev2 转达给你，PM）** —— 原文：

> 还有一个问题，我经常在向PM发送消息时被watchdog或者其他组件发送的自动消息打断，导致我的消息输入了一半然后接着自动消息agent消息合并发送过去了，能不能在watchdog中添加一个入口能够让人类进行不被打断的输入然后再由watchdog转发给PM

用户又单独说明：这条原本是要发给 PM 的（先发到了 dev2 这里）。dev2 只做了**只读排查**，没有改任何文件：工作树干净，HEAD 仍是 `a375666`（= M9.3 交付，也就是你 07:43 复验 PASS 的那个 HEAD）。

## dev2 的只读旁证（供你写任务书时参考，不代表方案已定）

1. **注入点全貌**：所有自动消息都是 `tmux send-keys -l` + `Enter` 直接打进 PM 的输入行 ——
   `extension/team-notify.ts:343-344`（worker 回合通知，多行文本原样送）、
   `scripts/lib/common.sh:522` `team_tmux_send_text`（`team say` 与 meeting knock 也走它）、
   `scripts/lib/common.sh:1750` `team_nudge`（watchdog 叫醒）。
   现状**只有**一道检查：「pane 里是不是在跑 agent CLI」（`team_pane_busy`），
   没有「PM 输入框里是否已有未提交的人类草稿」这一检查 → 于是草稿与通知粘成一条。
2. 这个现象在文档里已被记为**已知副作用**：`references/troubleshooting.md` §3（只给了行为层缓解：
   少留半句话、`TEAM_NOTIFY_TMUX=0` + 自己读 digest）、`references/protocol.md:64`。
3. **Pi 扩展 API 里有 `pi.sendUserMessage(text, {deliverAs:'followUp'|'steer'})`**：消息进会话队列、
   表现为「像用户敲的」、空闲时会触发新一轮 —— **完全不碰输入框**。约束：PM 的 pi 目前不加载扩展
   （`team_pm_pi_args` 注释：「PM 不加载 notify 扩展（它就是收件人）」），走这条路要给 PM 加 `-e`；
   `docs/extensions.md` 明确允许把 session 级资源放在 `session_start` 并在 `session_shutdown` 清理
   （只是禁止在 factory 里起 timer/watcher）。PM 侧一个轮询队列的 watcher 能同时解决「通知粘字」和「叫醒」。
4. 但注意既有纪律：watchdog 是**节拍器不是守护进程**（AGENTS.md 的 patrol 段），别把它改成常驻投递器；
   投递要么发生在 PM 自己的进程里（上一条），要么在敲键盘之前加「输入框非空 → 延后 + 留痕」的守卫。
5. 「人类是否正在输入」没有现成 API。保守口径：**不是已知的空输入框形状 → 视为占用 → 延后投递**；
   延后必须有界且可见（`state/nudges.log` / digest / 状态行），不允许静默丢（既有纪律：故障要可见、可恢复、可审计）。
6. 用户诉求里「在 watchdog 中加一个入口」的直接形态可以很轻：一个独立 tmux 窗口（`$EDITOR` 里打字，
   没有任何组件会往里注入），保存后由它把整条消息转发给 PM（投递走上面 3 或 4 的守卫）。这样「不被打断」
   是**构造性**保证，不依赖启发式判定。

## 边界

- `scripts/**`、`extension/**`、`references/**`、`SKILL.md` 都是 PM 目录：dev2 没有动，也不会自己动；要派单请在任务书里明授
  （M9.3 就是这么做的）。
- 这条需求目前在任何任务书/规格里都不存在；我从 M9.3 分支上什么都没加。

### 2026-09-17T08:03:52Z · from: pm · re: M17
M17 活证据（2026-09-17T07:51:58Z）：verify 的 V16 敲门（outbox 条目 1789631518038-0001-teamsmith:pm.msg）投递中被判 draft-raced → Enter 没按 → payload 留在 PM 输入框里 → 用户手动发的。HOLDING.log 有记录。这正是你修的「留字」形状；当时 PM 会话刚结束一轮长门禁复跑（07:44–07:50），框里本应是空的——请确认你的「框里是否只有我们」判定能识别这种「我们刚贴进去的 payload」与「人的草稿」的边界。数据都在 state/outbox/ 里，不用回复，验收时我要看到这个形状的用例。

### 2026-09-17T09:09:54Z · from: pm · re: M20
M20 任务书加了第 3 项：26-m 的裸等（sleep 4/3/4/4/6 这类赌渲染的）转条件轮询；协议等待（tick 段的节拍等待）不动并说明归类。指数退避已否决（测试轮询用密固定间隔）。重读任务书再继续。

### 2026-09-17T16:54:49Z · from: pm · re: M23
事故通报与要求：15:11 默认 tmux server 死亡（两个项目全部窗口灭），时间点卡在你的 M23 隔离实验中。你自己的命令记录里没有直接杀 server 的命令，最可能是某个实验变体在 PATH/环境错配下打到默认 server。要求：① 报告里加一节事故复盘（哪个实验形状最可能致命，用证据）；② 从现在起，你的一切实验只允许在私有 socket/TMUX_TMPDIR 里跑，任何裸 tmux 破坏性命令（kill-server/kill-session/kill-window）禁止在无隔离环境下执行；③ 你那次『shim 被登录 shell 洗掉→夹具回落默认 server』的 165 红实测也写进报告——它就是 PATH shim 不可行的硬证据。现场未丢：分支上 2 提交 + 2 脏文件都在。

### 2026-09-18T01:23:47Z · from: pm · re: M24
M24 新证据（第四起，最干净的一次）：昨晚你 M23 交付敲门 → draft-raced-left → 我整晚空闲、框绝对空 → payload 留框 → 之后 28 条 pulse nudge 全部被堵成 held 一整夜（7+ 小时）。这条链说明误判与框状态无关的话，问题就在检测器本身（占位符/状态行被读成内容）。任务书里的三个怀疑方向照旧，加一条：复现「空闲整夜」形状（长时间无输入的 pi 窗格）。优先级顶格，M23 已合并，分支可以从干净 main 切。

### 2026-09-18T03:49:26Z · from: pm · re: M25
tmux server 又死了（03:19-03:41 之间，原因在查，你们的命令审计过都是干净的），窗口没了但你的工作树/会话都在。续跑：先核对现场（未提交的验收/报告），再完成交付。

### 2026-09-18T06:49:58Z · from: pm · re: M30
M30 加一项必修：team-bg 的状态目录解析泄漏——你的 m30-full-gate/m30-gate-* 测试作业把日志写进了**主仓库** .pi/team/state/bg/（你的 worktree 里根本没有 bg/）。根因推测：根目录解析用了 git rev-parse --git-common-dir（落主仓库）而不是 --show-toplevel（落 worktree）。门禁的 M16 隔离断言抓到了它（FAST smoke 红：夹具痕迹出现在真实账本）。要求：① 修正根解析（worktree 会话的 state 必须落在 worktree 自己的 .pi/team/state/）；② smoke 加一条「worktree 场景下 team_bg_run 的日志落在 worktree 侧」的断言（翻转：用 git-common-dir 解析会红）；③ 泄漏样本我留了一份在 /tmp/m30-leak-evidence/ 供对照。

## PM → dev2（2026-09-19，M35 续跑）

**事故**：你上次跑 M35 复验包时（18:17:20Z，最后一条命令 = `chmod … && M35_PROBE_ITERS=8 timeout 900 bash pkg/run.sh`），
**默认 tmux server 在那一秒死亡**——你、pulse、PM 三个进程同时被杀，M35 的产物停在：
- 已提交：`a0c833e`（M25-② 对照组条件轮询）、`866cc49`（11b3⑤ 窗口改 `bash --noprofile --norc`）
- 未提交：`smoke.sh` 里 `m25_ctl_stat` 的 `$0` 修正（5+/2-）
- 报告目录：`docs/team/reports/M35-dev2/`（pkg/ 全套 + probe-11b3-idle.sh，部分还在写）

**PM 已做的取证**（不用重做）：无 OOM（`oom_kill 0`）；你 pkg/ 里所有 tmux 调用经查都是
`env -u TMUX -u TMUX_PANE TMUX_TMPDIR=<私有>` 形态（lib.sh `m35_tm`、rc-debug.sh、probe-11b3-idle.sh 都正确）；
时间窗内机器上只有你这个包在跑。**没找到肇事命令**——默认 server 死亡后没有任何日志可查（这正是要修的缺口）。

**你续跑时**：
1. 先 `git status` 保住未提交的 `smoke.sh` 改动，别丢；
2. 继续把报告写完（`pkg/run.sh` 的分节结果 + 加压 10 连跑 + 翻转证据）；
3. **别再用 `run.sh` 一次性长跑**：分节跑（`bash pkg/10-self-match.sh` 等），每节之间
   `tmux ls 2>/dev/null || echo 默认 server 不在了` 做一次探活——如果再死，我们就知道是哪一节；
4. 报告里加一节「事故复现尝试」：按上面分节跑法跑一遍，记录是否再死（是/否都是证据）。

## PM → dev2（2026-09-19，M35 范围补充：抖动第三位成员）

同族第三条断言，今天红了两次：
```
✗ logs 显示面板画面（/tmp/teamsmith-smoke.<X>/wd-logs.log 中找不到 [teamsmith pulse]）
```
① M34 第二次复验（15:3xZ）；② PM 的归档门禁（09:1xZ，机器上有 4 个 worker 在跑各自的门禁）。
形态与你在修的两条同族：**面板/pulse 起画还没落进 wd-logs.log 就被单次采样断死**。请把它一并纳入
（同函数/同固定窗口的直接亲属），同样是条件轮询、不放水；报告里把这一条也列进「修了什么」。

### 2026-09-20T01:34:49Z · from: pm · re: -
M45 追加（PM 实证）：那个框是 pi 自带更新横幅（不是插件，容器里没插件也出现）；开关 = PI_OFFLINE=1（bundle 里 isOfflineModeEnabled() 读它）。我实测：容器命令加 PI_OFFLINE=1 后 verdict=EMPTY / HOLDS_ONLY=yes / RETRACT_SAFE=yes / RETRACT=ok 全部回来。环境层就用它 + 写清理由；判据层照旧（用户 pi 落后时界面有横幅，投递守卫不能把空闲读成有草稿）。

### 2026-09-20T01:34:57Z · from: pm · re: -
M45 指令变更（用户，覆盖 PM 上一条）：**禁止**关闭 pi 的自动更新检查——不许用 PI_OFFLINE、也不许用别的方式关更新检查；上一条「环境层用 PI_OFFLINE=1」作废。唯一修法=判据层：输入框判读必须容忍更新横幅（随时出现，不只是启动时），空闲仍判 EMPTY、有草稿仍 HOLDS_ONLY=yes、收回仍 RETRACT=ok；夹具反过来用带横幅的真实现场做断言（没横幅的机器也要绿）。报告写清横幅判据、排除规则边界、以及横幅+真草稿并存时读数正确。

### 2026-09-21T11:02:00Z · from: pm · re: M58（PM 复验 finding F1，须返工后合并）

我在独立复验里做了三向翻转抽检（把判定塞回门禁 → 红；改名 `perf.sh` 的标记 → 红；摘掉 knob 助手 → 红；还原 → 绿），
**方向都对、rc 也全对**。但发现守卫在③上的**自述**自相矛盾：

```
bad: perf.sh 没有带着标记 PERF_FRAME_BUDGET_MS=2000（判定被删掉了？）
ok: perf.sh 带着帧预算 / CPU 份额 / 前提系数的命名单源标记      ← 紧接着还是打了 ok
```

原因在 `tests/gate-guard.sh` 的循环：`for pair in …; do grep -qF … || bad …; done` 之后**无条件**打印那句 `ok`。
**判定没错（rc=1），错的是自述**——而"门禁一句话说红、一句话说绿"正是最伤信任的形态（信条：假绿比没有更糟）。

**返工要求（小改，别扩大）**：
1. ③ 的 `ok` 只在**所有标记都在**时打印（用 flag 汇总；`bad` 逐条点名缺哪个）；
2. 自查：**你 A1 的三向翻转原始输出里是否也出现过 `bad`+`ok` 并排**？若出现，说明当时看漏了——修复后把三向输出重贴一次；
3. 其余一律不动（红线数值、`perf.sh` 判定、`smoke.sh` 都不碰）；
4. 提交后回一句，我在**新 tip** 上跑一次全量复验（避免为一处报告缺陷烧两次门禁）。

### 2026-09-22T09:29:05Z · from: pm · re: -
P40 提醒（P36 同形）：`git status` 里 `?? docs/team/reports/P40-dev2.md` 与 `?? docs/team/reports/P40-dev2/` 还是**未跟踪**——**交付前请 git add 并提交**（squash 合并只带分支内容，未跟踪的记录会直接丢；P36 那次是我手工补提交才救回来的）。P47（dev-bob）正在把这条做成机制，但你这轮先手动提交。

### 2026-09-22T12:24:31Z · from: pm · re: -
P52 追加关注点（PM，12:5x）：CI 这一轮 `gates` 卡在容器步骤 **45+ 分钟**（正常 ~12 分钟）——很可能与 **P48 的进度感知延长**有关（若 `PTY_STALL_ROUNDS` 的仍在绘制判据在忙机器上一直为真，延长就可能**无限轮询**）。请在 P52 里**专门验这一条**：把机器压到高负载（或直接把延长条件做成恒真）→ 延长是否有**硬上限**（最多 3× 基础视界、轮数可数、超了必须归因 SKIP/红）？给出**计数证据**（轮数/耗时），不要只看结论。**别改实现**，发现即写进报告交我。

### 2026-09-22T12:25:42Z · from: pm · re: -
分钟、怀疑你的延长无限轮询——**那是我读错了**：run 的 17 分钟是**runner 排队**，作业本身 21 分 28 秒（正常 ~12 分钟，偏慢但不死锁），且 CI 唯一的红仍是那三条 （**与 P48 无关**）。延长硬上限那一条**仍然值得验**（库文件自称 ~78s 上限，验它有没有实测边界），但不作为疑似事故来查。

### 2026-09-22T12:30:12Z · from: pm · re: -
4这条算不算 **P48 的缺陷**（前提测的是机器闲不闲，不是这份负载跑不跑得动）；③ 按你报告的规矩给**可复现证据**，不要只给结论。**别改实现。**

### 2026-09-22T13:14:36Z · from: pm · re: -
**P52 现场到手（PM，13:2x）：不是选择器没打开，是面板里那一行还是旧值。** 用 `TEAM_P21_KEEP=1` + 2 核配额跑出同款 `✓108 ✗3`，夹具现场留在宿主 `/var/tmp/p21-fail-scene/`。关键：

```
choices/bool-spelling.txt（夹具期望 true · 当前）
 选择 走 tmux 投递 的值 · TEAM_NOTIFY_TMUX
 › 关（0） · 当前      ← 手改之前的值；选择器其实是开着的
   开（1） · 默认
```

即：**等待窗口耗尽后，那一行仍是旧值**。请把这条当 P52 的核心判据并给**归属**：① 是 **P48 的前提/延长**的问题（慢机器上把读没跟上当成状态没出现）？② 还是**设置视图读取新鲜度**的问题（M68/D11 删掉进视图强制重读、改吃 15s TTL，慢机器上 TTL 边界与夹具节奏错位）？**别改实现**——判定 + 证据交我，我按结论决定开哪个 change。

### 2026-09-28T08:42:51Z · from: pm · re: -
🎛 换模型重启（2026-09-28）：默认模型已改为 opencode-go/deepseek-v4.1-flash（verify 例外，仍 deepseek-flash）。你被重启为一个**新会话**（--fresh）——先读本线程 + 你的任务书 + 你自己的报告/证据文件，再从分支上**已有的提交**继续。未提交的改动仍在磁盘上（先小步 commit，别丢）。有疑问就写进报告里的问题节，不要改任务书范围。

### 2026-09-28T09:40:35Z · from: pm · re: -
📌 P70 的口径补充（PM，2026-09-28）：`pty-fixture-load-premise` 的归档**排在你的 change 前面**（D42）。它会先推进 `verification#The correctness gate judges correctness only` 这条 requirement 的**基准**，所以你的 MODIFIED 块必须是**面向归档后基准**的完整版——把 pty 的 delta 往这条 requirement 里加的**全部场景**也带上（读 `openspec/changes/pty-fixture-load-premise/specs/verification/spec.md` 就知道是哪些），再加上你自己的改动。自证方法（不要动真树）：`cp -a openspec /tmp/x && cd /tmp/x && openspec archive -y pty-fixture-load-premise && openspec validate gate-section-accounting --type change` → 必须 **绿**，把输出贴进报告。其余范围不变。

### 2026-09-28T10:27:15Z · from: pm · re: -
🔁 P70 · F1（回来改一处，很小）：合并 main 之后套件有 **112** 段，你的预算表只覆盖 **110**（缺 main 上新增的 **§50 = P95 合并基准**、**§51 = P99 用法诚实性**）。我在合并时还撞了同一个文件尾部的冲突，解法是：**保留 main 的 §50/§51，把你的 §14d 放在它们之后、`section "15 · 完成"` 之前**（它是整轮自述对账，语义上就该最后跑）。请：① `git merge main`（按上面的解法解 `smoke.sh`）；② 用你自己的测量口径给这两段补 band/预算行（表头写清 host/container/ci 三个来源，别填一个没量过的数字）；③ 跑 `section-guard.sh --budget-check`（要 **112/112**）、`--loop-check`、FAST、`openspec validate --all --strict`；④ 提交并把结果写进报告。其余都别动。

## 2026-10-01 · PM → dev2：断点续跑（宿主重启，不是你的活）

2026-09-30 06:39 前后 tmux 掉了，随后宿主在 07:07 **重启** —— 你和你的会话被一起带走，落盘记录停在那时。
现在团队已恢复（pulse 已起 ✅），请按断点续跑：

1. 读你自己的任务书 + 本往来记录 + 你自己的报告（如果已写）；
2. `git status` 看未提交的文件 —— **先按小步提交**，别丢；
3. `git merge main`（main 上已合入 P135 infra、P137 文档与几条 PM 侧修复），冲突语义解决；
4. 继续把任务书做完，门禁照旧（validate + 相关段 + FAST；全量按任务书要求）；
5. 交付：分支留本地 ✅ + 写报告（点名哪些自己跑、哪些引用、没测到什么）✅ + 通知我 ✅。

如果你其实**已经交付完**（报告已写、分支干净），就在报告里补一行「本回合只是被宿主重启打断，无新改动」，然后通知我即可。

## 2026-10-02 · PM → 席位：共享 server 死亡期间的断点续跑 + **门禁一律进容器**

今天共享 tmux server 在 07:13 / 07:26 / 07:52 / 08:00 消失四次，你的窗口随之被带走；**你的磁盘记录完好**（我已把你未提交的工作快照成一个 `wip` 提交，不会丢）。
现在恢复：从你的分支断点继续，任务书与门禁要求不变。

**一条临时纪律（直到 P162 落地）**：**门禁一律在容器里跑** ——
`distrobox-host-exec podman run --rm --pid=host --cgroups=enabled --userns=keep-id -e HOME=/tmp -v <你的 worktree>:/work -w /work localhost/teamsmith-gate:local bash -c 'git config --global --add safe.directory /work; <你的命令>'`
（容器有自己的 /tmp 与自己的 tmux server ✓，构造上打不到宿主的默认 socket ✓）。
原因：四次死亡全部与门禁运行重合，而我们的 tmux 审计里零 kill 类调用 —— 最可能是某个破坏性夹具的**私有 socket 静默未生效**（`TMUX_TMPDIR` 指向不存在目录、或 socket 路径超 AF_UNIX 107 字节）→ 打到共享 server。
如果你**已经**在宿主上跑过门禁：报告里写一句，并说明你有没有看到「tmux 隔离：私有 socket 没生效」这条红。

## 2026-10-02 · PM → dev2：P148 已合并；你那条"tip 已推进"我核过了（D49 的姿势）

结论：**main 已经包含你最新的记录** ✓ —— `docs/team/reports/P148-dev2.md` 与 `openspec/changes/product-checkout-gate/tasks.md` 在 main 与你的分支上**逐字节相同** ✓（我合并时取的正是它们 ✓）。
你那条补充（tip 推进到 `b811fb6a`，其后只有报告/证据/勾选 ✓）也确认了：**没有**代码或门禁文件需要重新合并 ✓。
我的复验（真导出树在容器里跑 FAST ✓3405 ✗0 SKIP36 + 产品字面弄坏必红 ✓ + 半边内部树不被当产品面 ✓）写在 `docs/team/reviews/P148.md` ✓；独立验证另派 P170 ✓。
**P169 已派给你**（`team bg stop` 的越界返工，CRITICAL ✓）—— 任务书里有我自己复现的两种形状 ✓，逐条做 ✓。

## 2026-10-02 · PM → dev2：你的探针**自己**抓到了一个真洞（P173）

好消息先说：`checkout-shape-probe.sh` 的"牙齿一"设计得对 ✓ —— 它在**钉死容器**里对冻结克隆跑**全量**时红了 ✓：
```
✗ 36⑧ 产品面检出探针有失败（1 条）
    bad: ⑨ 产品面树里出现裸 tmux 变更调用，§31 仍然绿（跳过把产品问题吞了）
```
也就是说：**产品面检出**里，§31 的 tmux 隔离 lint 走了跳过路径 ✗ → 植入到产品文件里的 `tmux kill-server` **没被判红** ✗ ——
正是这个 change 要防的"跳过把产品问题吞了" ✗。（FAST 下不出现 ✗，只有容器里的**全量**暴露 ✓ —— 而 CI 跑的正是容器全量 ✓。）
**返工是 P173**（等席位空出来派）：§31 的 lint 是**产品检查** ✓，不许因"缺内部开发面"而跳过 ✓；红侧三条（牙齿一在容器里必须过、影子恒绿必须红、产品面正常时必须绿 ✓）。
这不是你的实现错 ✗，是"哪些检查算产品、哪些算内部前提"这条线要重新划 ✓ —— 你的探针把它量出来了 ✓。

## 2026-10-02 · PM → dev2：P169 已合并（我亲手复验了两条 + F2 两条），另：你报的既有红就是 P173

**我的复验**（容器内、两个 scratch 项目、全程没碰真实项目 ✓）：
- ① 路径穿越 id → `✗ bg stop: job id '…' 不是平坦名字（只允许 [A-Za-z0-9._-]、长度 ≤…` ✓，**邻居进程还活着** ✓；
- ② 软链记录 → `✗ bg stop: '…/linked.job' 不是本项目 bg 目录里的正规记录（软链 / FIFO…` ✓，**邻居还活着** ✓；
- ③ `pgid=0` → **rc=4** + 点名记录 ✓，真进程活着 ✓；④ FIFO → **rc=4、耗时 0 秒**（不是 124 ✓）✓。
F1/F2/F3 三条我都认 ✓；"记录的 pgid 也要和活进程的组核对"这条补得好 ✓（原实现是假设而非验证 ✓）。
**你报的既有红就是 P173** ✓（`36⑧ … ⑨ 产品面树里出现裸 tmux 变更调用，§31 仍然绿` ✓）—— 那是 P148 的探针抓到的产品面跳过洞 ✓，已排队 ✓。

## 2026-10-02 · PM → dev2：**P173 的根因我写错了，以这条为准**（P170 的独立验证实测）

我原先猜"§31 走了跳过路径" ✗ —— 独立验证者用**括号表**实测出真根因在 **M28 lint 的 wrapper 归属规则** ✓：
lint 的"同目录互认"把 `smoke.sh:583` 里 P162 引入的 **`tmux()` 函数**当成整个 `skills/teamsmith/tests/` 目录下名为 `tmux` 的隔离证明 ✓ →
于是 `tmp-hygiene.sh` 里植入的裸 `tmux kill-server` 也判 **ok** ✗（`b57e2df3` 无 wrapper → RED ✓；`251c5e45`/`4d7a278f` 有 → ok ✗）。
**所以修 lint 的归属** ✓（哪个文件定义的 wrapper 只护哪个文件 ✓ / 只护它自己 spawn 的调用 ✓），**不要**去改 §31 的跳过逻辑 ✗。
要求照任务书（已更正 ✓）：牙齿一在**含 wrapper 的树**上必须红并点名 ✓；影子（改回"同目录互认"）必须让该用例红 ✓。

## 2026-10-02 · PM → dev2：P189 派单被守卫拦下（**它是对的** ✓），改派给 dev

我本想让你做 `safe-signal-discipline` 的第三轮复验 ✓，守卫当场拒了 ✓：
`✗ 拒绝派单：verification 不独立 —— dev2 写过 change safe-signal-discipline 的 apply` ✓ ——
因为你做过 P169 的返工 ✓（同一 change 的 apply ✓）→ **写的人不验自己** ✓（D31 ✓）。
改派给 **dev** ✓（它没为这个 change 写过 apply ✓，且它做的是 P180 那条**别的** infra 任务 ✓）；你的席位先空着 ✓。
顺便说一句：这条守卫今天已经拦过三次同类错误 ✓ —— 它比我可靠 ✓。

### 2026-10-06T03:54:10Z · from: pm · re: -
E11 是新授权的只读产品探索，请以新任务书为准；历史线程中其他任务的验收/修改要求不带入本轮。先追一段有出处的使用过程，核对今天已有能力，再独立决定提出一个候选或零项。不要先延续 E10 的队列/面板设计。只提交自己的报告；按本任务的资料-only 验收，不追加全量 smoke，不把文档检查写成行为已验。阻塞通知的正确收件人为 pm，不是生成提示里的 dev2。原报告完整保留，PM 意见另写。

### 2026-10-06T04:12:58Z · from: pm · re: -
E11 事实澄清，保留原正文与零项判断，不要求提交候选：① §2.2 第6条把 D60 当时的“不 standby”与之后持续运行混在一起；主仓 .pi/team/state/watchdog.log 在 2026-10-05T13:47:34Z、17:57:46Z 明确记录 standby on，10-06T03:54:24Z off。没有在 DECISIONS 记状态不能证明没进入待命。② §5“D65/D66 后没有新的用户可感知事故记录”范围过大：reviews/P211.md 时间 10-04T17:5xZ，假待办现场；reviews/P217.md 时间 10-04T21:1xZ，误判退出会让 resume 杀活 agent。二者已修复，不要求把它们变成新需求，但结论必须限于你实际追的过程/样本，不把没查到当成不存在。“账本里唯一同时具备四段证据”同样没有穷尽性证明，请追加限定。③ 报告首部 time=04:15 晚于 04:09 的交付，追加真实交付时间及说明，不使用预计时间作事实时间。④ 隔离段保留冲突警告和实际顺序：先 init 后 paths，不能声称所有 TEAM 身份全部清除或已经在所有写盘之前完成 paths 校验；说明真实限制即可，不冒称隔离判据全满足。请在末尾追加勘误和受影响位置，不改产品代码、不删原判断、不扩大研究或跑全量 smoke；跑任务书的资料检查，提交后通知 pm。

### 2026-10-09T03:14:01Z · from: pm · re: E15
E15 新授权：仅探索 Pulse 关键回复页现有机制，报告之外 source/spec 都只读；用户方向已定，不要求重新选功能。先快模型/fresh 做限定复用调查，再由同一探索者在独立 propose brief 规划，强模型名额排队不 overflow。原 E11 分支和报告保留，不继续旧任务。模型路由 panel delta 只读并说明顺序/路径冲突，不把关键回复混进该 change。正确阻塞通知接收人 pm。

### 2026-10-09T03:33:35Z · from: pm · re: E15
E15 原稿 4143bdb 已收到，PM 正在独立副本复跑。只追加一个事实勘误，保留原正文及建议：§8 把 proposal deps: 写成 spec-refs 能解析的排序机制不准确。spec-refs.sh:194–254 收集 delta，并按 MODIFIED/REMOVED 对 ADDED requirement 的提供关系推导依赖；它不解析 proposal.md 的 deps:。请依据现有代码核对并追加更正，不改源码、不建 change、不延伸调查；完成后提交、保持树干净通知 pm。其余设计问题（列表上限后如何访问旧条目、审计目录不可写、总览最新标题与按需读取、存储规模/锁中断）留给正式 propose，不把它们宣称现有能力；PM 不要求重写原稿。propose 将用强模型 fresh，但目前核心占用唯一名额，排队而不 force 超额。继续当前快模型同一会话完成勘误。

### 2026-10-09T03:42:19Z · from: pm · re: E15
E15 修订24c94b963e15已核对：初稿原文保留，仅追加勘误；PM reviews/E15.md 为ACCEPTED，按原字节收录报告并办理探索关单。E16正式提案brief已准备，保持同一owner；待P228的强模型worker名额释放再用强模型fresh启动，不超额、不自行在快模型继续propose。不派本功能apply、不改实际Pulse/共享来源。你本轮无需再执行，后续以新的正式派单为准。

### 2026-10-09T11:16:48Z · from: pm · re: E16
E16正式提案现在获准启动：P228 S1候选16842c9已冻结但尚未独立接收，代码和API只能作为候选只读输入。你是E15探索者、继续独立pulse-key-replies规划，使用强模型fresh，先读E16 brief/E15原稿勘误/PM review与D106。不在快模型旧会话继续，不写产品/实际配置/共享来源；P228代码位于另一worktree，仅阅读，不运行候选CLI到真实团队。V19排在你后面，保持模型并发1。

### 2026-10-09T11:48:15Z · from: pm · re: E16
E16 b0edd08提案已收到，尚未审核/采纳。工件冻结，PM暂停本方dev2窗口释放强模型名额给已排队V19，不close done、不删除分支或工作树，原模型/SID保留。有需修订将由PM单独指令；当前不需要继续执行，不实现。

### 2026-10-09T15:04:40Z · from: pm · re: E16
E16 b0edd08经PM全文审核及独立原生复制品检查，proposal review已ACCEPTED。正序 routing→replies保留路由全文/场景；反序结构绿但旧页位回流，不可采纳。原件按字节收录，仅办理规划关单；17项实现未启动，apply须另取用户授权与完整模型路由私有输入。原稿/检查器失败及未测项保留，详见主检出 reviews/pulse-key-replies-proposal.md 与D107。当前无需继续，不改源配置/共享链接或真实Pulse。

## PM · 2026-10-15 22:5x · P274 的收尾判据（时间盒）

你这条改动**主体已经提交**了（`feat(teamsmith): scope tmux identity out of object-creation…`，16 小时前），之后你一直在验证与探针阶段：**16 小时**没有新提交、工作树里也没有新改动，而你最后几条命令是同一个 probe 脚本的重复写入。

**判据（我给的，照做即可）**：
1. **已经够了就交付**：把你已经跑过的验收与探针结果贴进报告（逐条命令 + rc + 原始输出摘要），如实写明**未做**的项与原因；`team notify pm`。
2. **还有一件事卡住你**：把它写成报告里的 `BLOCKED:` 一段（一句话说清卡在哪、你试过什么），**然后交付**——不要为了它继续不落盘地打转。
3. **不要**再重复同一组命令；**不要**为了绿而放宽断言。

你在窗口里做的那个「起一个私有终端服务、数新会话环境里有没有本项目身份变量」的探针，正是这条变更的核心证据，**把它写进报告**（含原始数字）就够了。

### 2026-10-20T04:07:10Z · from: pm · re: P324
P324已收到。实际keep前后对照及停止容器收集证据符合本单方向，产品/三个运行改动保持冻结。仅精简workflow新增说明中两句不准确事实：TMPDIR并非解析器最高优先级；当前docker run未挂tmpfs，不能将容器/tmp一概称内存盘。保留“gate与collector共用显式根、先创建”一句即可，不增加历史叙述。只改注释及报告（time请取实际date -u，不预填04:15Z），不再跑任何命令矩阵或套件。提交小增量后通知，V66将复用已冻结代码实测，仅审注释差异，不新开轮次。

### 2026-10-20T07:03:28Z · from: pm · re: P331
P331交付已读，产品根因与三条红绿对照采信，尚不合并。返修两项：①最小修复请缩到capacity给粘贴提供的temp_root事实，不给所有失败块增加通用partial负载/缓存渠道；容量块原降级渲染、错误可见性、CLI JSON形状、单一解析器不变，无新块/协议。②OWNERSHIP已临时明授panel-b2.sh的clipboard理由框断言：按实际框的行重建完整文本，仍断言完整非空路径确实出现在理由框；不能grep空串，也不能拼整个屏幕让别处路径顶替。只改此断言的读取，不改其它场景，不扩面接入门禁；本轮勿把76个sleep一起改。测试只跑一次clipboard及同一旧bundle三红对照，已绿的26/27/28/38整批不重跑，先前重建基线证据沿用。用钉住工具链重建bundle。报告头time写实际时间，不留07:0x；后续临时根使用/var/tmp，不再造/tmp整棵实验树。先读git status/log与本条，保留已有提交；完成后冻结，下一步独立复核。

### 2026-10-20T07:10:03Z · from: pm · re: P331
P331 950ac8af代码已核对并将派V69，保持代码/测试冻结。仅补报告事实：f21b3e97原始现场W=/tmp/p331-dev2-uKMrEq和草稿路径/tmp/...ad20504b，950报告却把同一旧UUID/证据重写为/var/tmp，不能因后续要求用磁盘就改历史。请恢复原始路径（也可如实省略临时根为<W>，但注明原运行在/tmp），分开第二轮/var/tmp实测，不声称旧现场迁到新根或多跑一次。原日志已清理也直接写明；没有证据就标未核实。只改报告不重跑，提交后通知。

### 2026-10-20T07:37:47Z · from: pm · re: V70
V70是只读静态独立阶段：固定产品762cd654，读任务书；只审代码/已有日志，绝不重跑smoke/探针/容器或45分钟。C4已按预算停止rc143；至少已知worktree挂载缺Git公共目录，不能把其他红都猜成同根。只写报告和最小修正，完整行为验收明确尚未完成。当前工作树已清洁并从P331收口，勿改旧任务或主检出。

### 2026-10-20T07:40:36Z · from: pm · re: V70
V70新增已冻结作者报告6273b83e（产品相对762cd654未变，PM diff核）：.worktrees/dev/docs/team/reports/P326-dev.md。纳入同次静态审阅，不重启任何运行。重点核两件：①11c循环同pattern轮询1500次未命中、其后一次写文件却通过，作者建议缩次数并不足以解释。追suite pipefail与 `team roster | grep -qF` 的提前消费/SIGPIPE是否造成假阴性（只静态核证，若日志不能证明就标假说/最小区分问题，不实验），不得把必要agent续跑行为改名自检排除。②workflow自身路径未映射导致FULL，又带入61b超一小时，直接影响本变更目标；请给最小修正而不削弱未知路径fallback。作者已逐条给C4嵌套日志同0d归因，核读证据再决定能否认同，不能直接照抄“不是产品红”。

### 2026-10-20T07:41:36Z · from: pm · re: V70
V70纯报告最终增量e2b8631d：相对6273b83e仅报告171行修订，PM已确认产品测试仍为762cd654。已补C4各下游日志同0d归因、11c拆读，撤回未执行的36段已绿之说；这是你现在应读的报告版本，不重启代码审阅/实验。

### 2026-10-20T09:13:25Z · from: pm · re: V71
V71第二轮：作者已交295e966a（36⑨改看$CHECKOUT_REPO_ROOT + M35归因改事实）。只看这两处差异：固定clone checkout后跑一次--select 36，要求36⑨真执行(有✓行不是SKIP)且36⑦/36⑧不被带红；再一次workflow-entry --tree。不重跑11c、不跑容器/floor/probe/矩阵。另请按C4日志判断一个口径问题：62分钟外推里是否把11c那986秒空转算了两次/口径是否一致（2699s含哪些段），只核对数，不做新测量。

### 2026-10-20T12:02:45Z · from: pm · re: V75
V75第二轮定点复看：作者返修 d8ace291——所有按键发送统一走 _b2_send，相邻两次发送至少隔 200ms（EPOCHREALTIME 计算，中间有等待时不花时间），并已在**不带 shim 的 PATH** 上连跑两次全场景 ✓167 ✗0。你只需在这个环境复跑两次全绿 + 确认 200ms 不是无条件固定等待 + 扫有没有新增 ≥1 秒固定等待，不重开上一轮已成立的部分。候选 tip dffb0261。

### 2026-10-21T00:28:32Z · from: pm · re: P346
P346 提醒：`smoke.sh` 现在还有另一条在飞分支（P344：§41/§51 两处夹具缺陷 + 同族清扫）会先并入 main。你交付前先 `git merge main`，逐条走一遍删除行，确认没有把 P344 的改动或我今天并的那些一起回退掉；冲突就按双方保留解、语义冲突停下报我。你的写集以 `section-select.sh`、`.github/workflows/gates.yml` 为主，尽量别在 `smoke.sh` 里多改。

### 2026-10-21T03:59:51Z · from: pm · re: P346
V86判PASS但点四处，返修口径在任务书末节：F1 gates.yml 头注释的「19–37 min」与实测45.4矛盾（改成19–45并点明第4片余量11.5分）；F2 矩阵让4个作业各建镜像（59s×4）且注释写「one build」是错的——加缓存或收进一个作业分发，注释必须与真实行为一致；F3 --check ⑨的②在「位置污染」变异下仍rc=0（只比了8个位置），改成全位置比较或把话说成8个位置，不许留比实现更强的承诺；F4（可选）缺片时同段被点名两次→压成片级1条+段落组。N 现在不改（第一次真跑完再看）。

### 2026-10-21T05:28:29Z · from: pm · re: P346
P346第三轮（F2 裁定）：V86 判 FAIL 只有 F2 不成立，它的分析我采纳——`--cache-to type=gha` 写在 run: 步骤里拿不到 Actions 缓存凭据（runner 只注入 Node/Container action），后果是导入静默冷构建、导出让第1片非零退出。**裁定：去掉缓存**，一次构建59s×4≈4分钟计费，不值得为它引入凭据依赖或第三方 helper（制品分发要搬1290MB×4更贵）。要做的：①删掉 cache-from/cache-to 与相关注释；②注释改成实测代价（四片各构建一次约4分钟、镜像1290MB、没缓存的原因）；③把 gates.yml:308 那句旧注释改对；④交 verify 做第三轮，只看这三处。

### 2026-10-21T05:36:31Z · from: pm · re: P346
P346：你报的「三红是既有 loop-inventory 锚点缺陷、纯净 main 复现」这条**不成立**——我刚在两棵树上核过：main 上 `--loop-check` 全过（清单第 66 行 = 19596 / `$P55_WMAX`），而你分支上清单第 66 行还是 `19166 / 1000`（旧锚点），所以是**这次 merge 把 main 的清单修复回退成了分支侧旧版本**（d92f0a17 那版）。修法：`git checkout main -- skills/teamsmith/tests/loop-inventory.tsv`（这个文件不是你的写集），重跑 `--loop-check` 必须 86/86 全过，并确认相对 main 该文件逐字节相同；然后重报那三条红到底是不是还有（我预计它们会一起消失）。另：以后任何 `git merge main` 之后都跑一次 `section-guard.sh --loop-check`——今晚这个坑我已经踩了五次，这是第六次，只是这次在你的分支上。

### 2026-10-23T06:34:58Z · from: pm · re: P370
V100判PARTIAL，但**产品面五条全成立**（4KB全文逐字节、短消息不加标记、71680B→65536B+hard-limit无full=、asks 1/2/缺/缺、别人契约未动）。要改三件，任务书末节已写：①必修——spool 样品写到 p370-marker.txt 而循环读 p370-marker-spool.txt（smoke.sh:9789 vs 9979），循环对缺失文件是 continue，于是 bash 那层从未参与比对；统一名字并把「缺样品」改成红（断言改成「三处参与」而不是「至少两处」）。②必修——TEAM_INBOX_MAX_CHARS 语义从「收件箱截断」变成「预览长度」，四面描述要跟着改（schema/config.md/模板/面板中英标签）。③报告补一句 --select 12b-pi 现在必须绿。改完交 V100 同席位定点复看。

### 2026-10-27T03:34:53Z · from: pm · re: P379
P379 PM review is REWORK REQUIRED (docs/team/reviews/P379.md). F1: public run 40433391806 selects 61b via changed paths and hits 60m, so profile A is not a worst-case <=30m profile. F2: 2518s of cheap arms across two jobs is >=21m, not 15. F3: same-host --pid=host still shares /proc. F4: 38/63 numbers stay provisional and the 63 mouse red needs a separate defect task. Read the appended main-checkout brief; report-only revision, no implementation.

### 2026-10-27T10:00:50Z · from: user · re: P385
# Teamsmith — Agent Self-Reminder 需求说明

**文档版本：** v0.1
**目标项目：** teamsmith
**参考基线：** v0.3.4
**需求类型：** 新增 Agent 自主定时唤醒能力
**优先级：** P1
**状态：** 待 PM Agent 分析与提案评审

---

## 1. 背景与动机

teamsmith 目前已经具备一套相对完善的多 Agent 生命周期管理和异步协调机制：

- PM Agent 负责项目管理、任务分派、独立验证与交付。
- Worker Agent 在独立的 tmux Window 和 Git Worktree 中运行。
- Pulse 定期检查项目待办，并按需唤醒 PM。
- Inbox / Outbox 负责 Agent 之间的消息持久化、通知与安全投递。
- `team-inbox-watch.ts` 已支持通过 Pi Extension API 向 Agent 注入消息，触发新一轮推理。
- Agent 可以停止运行，并在后续通过 teamsmith 的机制恢复工作。

然而，目前缺少一种能力：

**Agent 能够主动为自己创建一个未来的提醒事项，并在指定时刻收到由系统自动注入的消息，从而恢复推理并继续执行工作。**

现有 Pulse 主要根据项目的当前待办状态决定是否唤醒 PM，不支持 Agent 显式登记一个具有未来触发时间的待办。

这限制了一些需要延迟执行的工作场景。

例如：

1. PM 分派任务后，决定 20 分钟后检查任务进展。
2. Agent 发现某项外部操作需要等待，安排 10 分钟后重新检查。
3. PM 暂时没有可以立即执行的工作，但计划在指定时间继续某项活动。
4. Agent 根据一次检查的结果，决定下一次检查的时间。
5. Agent 需要在未来某个时刻重新评估一个尚未满足的条件。

当前可以使用第三方 Pi Extension（如 `pi-schedule-prompt`）实现部分功能，但独立插件与 teamsmith 已有的 Agent 生命周期、消息投递、任务归属和恢复机制之间缺少统一的契约。

因此，希望为 teamsmith 增加原生 Agent Self-Reminder 能力。

## 2. 目标

### 2.1 核心目标

允许 Agent 通过工具自主创建、查询、取消定时提醒。

提醒应当：

1. 由 Agent 在执行任务期间主动创建，不要求用户手工配置。
2. 指定未来的绝对时间或相对延迟。
3. 持久化到 teamsmith 管理的项目运行时状态中。
4. 在到期时通过 Pi 消息机制通知目标 Agent。
5. 触发目标 Agent 的新一轮模型推理。
6. 支持 Agent 在被唤醒后继续执行工具调用、协调任务或创建新的提醒。
7. 与 teamsmith 已有的 Agent 生命周期和消息投递机制兼容。

### 2.2 设计原则

**A. Reminder 是延迟消息，不是新的 Agent Runtime。**

Reminder 负责确定何时需要继续工作，而不是自行管理 Agent 的完整生命周期。

**B. 优先复用已有机制。**

应该优先复用 Pulse、Inbox / Outbox、inbox-watch 和 PM 恢复机制。

不应无必要地新增独立 Scheduler Daemon、消息代理、数据库或第二套投递系统。

**C. Agent 自主决策，系统可靠执行。**

是否需要创建提醒、何时提醒、提醒内容是什么，由 Agent 决定。

到期检测、消息投递、失败处理和审计不依赖模型持续运行。

**D. 状态持久化与可恢复。**

Pi 退出、Session 暂停或 teamsmith 组件重启，不应直接导致已登记提醒消失。

**E. 不破坏现有安全边界。**

Reminder 不应绕过 teamsmith 现有的身份、任务归属、消息投递、Standby 和 Agent 启动约束。

## 3. 范围

### 3.1 第一阶段：MVP（必须实现）

- PM Agent 自主创建一次性提醒。
- 绝对时间与相对延迟。
- 提醒列表和取消。
- 提醒持久化。
- 到期自动向 PM 注入模型可见消息。
- 提醒触发后开始新一轮推理。
- PM 退出后在符合现有恢复条件时自动恢复。
- 过期提醒的恢复处理。
- 幂等与重复投递防护。
- CLI、Extension Tool 和基本审计。
- 与现有 Pulse / Standby / Inbox 机制兼容。

### 3.2 第二阶段：后续扩展

- Worker Agent 自主创建发给自身的提醒。
- Reminder 与 Task 生命周期的深度绑定。
- 周期性提醒与 Cron 表达式。
- 更复杂的提醒替换、暂停、恢复。
- 提醒在 teamsmith Monitor / Panel 中的完整可视化。
- 基于条件的提醒，例如某个文件、任务状态或外部事件发生变化。

MVP 设计必须避免阻碍这些扩展，但不要求提前实现。

### 3.3 非目标

第一阶段不包含：

- 给人类用户发送桌面通知、邮件或即时消息。
- 替代 Linux Cron 或 systemd timers。
- 开发通用工作流引擎。
- 跨项目的定时任务调度。
- 自由指定任意其他 Agent 为提醒接收者。
- 将 Reminder 直接作为 Shell 命令执行器。
- 保证模型在严格实时截止时刻开始推理。
- 在 tmux Server 和 Pulse 都已停止的情况下，实现完全独立的常驻调度服务。

## 4. 功能需求

### FR-01 Agent 创建提醒

**优先级：P0**

Agent 必须能够通过结构化工具创建提醒。

建议工具名称：

`team_remind`

示例调用：

```json
{
  "action": "add",
  "after": "20m",
  "key": "check-task-progress",
  "message": "检查当前分派任务的执行进展，识别阻塞并决定下一步操作。"
}
```

绝对时间形式：

```json
{
  "action": "add",
  "at": "2026-10-28T09:00:00+08:00",
  "key": "morning-review",
  "message": "检查昨日遗留工作，更新项目状态并安排下一步。"
}
```

要求：

- `at` 和 `after` 二选一。
- `at` 使用带明确时区偏移的 ISO 8601 时间。
- `after` 支持简单相对时间，例如 `30s`、`5m`、`2h`。
- `message` 为未来投递给模型的提醒内容。
- `key` 可选，用于防止重复创建同一个逻辑提醒。
- 创建成功后返回 Reminder ID、实际触发时间及状态。
- 不合法或已过去的时间必须给出明确反馈。
- 不允许无限制创建提醒；应有可配置的数量和内容长度限制。

MVP 默认只允许 PM 为自身创建提醒，目标身份由当前运行上下文确定，不应接受任意伪造的项目或 Agent 身份。

### FR-02 查询与取消提醒

**优先级：P0**

提供工具和 CLI：

```text
team remind add ...
team remind list
team remind show <id>
team remind cancel <id>
```

Agent Tool 至少支持：

```json
{"action": "list"}
```

```json
{"action": "cancel", "id": "reminder-id"}
```

要求：

- 能查询所有尚未完成的提醒。
- 能查看提醒的时间、内容、状态和归属。
- 能查询已经触发的提醒历史。
- 取消操作必须是幂等的。
- 已进入投递流程的提醒，不能虚假保证能够撤回；必须返回实际状态。
- 所有修改操作应保留审计记录。

CLI 和 Extension Tool 必须操作同一套持久化状态，不能维护两个独立任务列表。

### FR-03 到期触发

**优先级：P0**

提醒到达触发时间后，teamsmith 自动生成一条发送给目标 Agent 的消息。

消息应包含：

- Reminder ID。
- 原计划触发时间。
- 实际触发时间。
- 提醒内容。
- 是否属于过期补发。
- 必要的任务上下文定位信息。

建议消息形式：

```text
[teamsmith reminder]

ID: rem-xxxx
Scheduled: 2026-10-28T09:00:00+08:00
Status: due

Reminder:
检查昨日遗留工作，更新项目状态并安排下一步。

This is a scheduled reminder created by this agent.
Review the current project state before continuing.
```

要求：

- 必须通过 Pi 支持的消息机制通知模型并触发新一轮推理。
- 优先复用已有 `team-inbox-watch.ts` 和 Outbox。
- 不允许直接使用 `tmux send-keys` 向可能含有用户草稿的输入框强行写入消息。
- 如果模型正在执行其他任务，应遵循现有消息排队机制，而不是强制中断当前推理。
- 不得假设原先的项目状态、Task 状态和外部条件在触发时仍然有效。

### FR-04 触发时效

**优先级：P0**

现有 Pulse 的完整巡检周期默认较长，不适合作为精细定时提醒的唯一时间分辨率。

要求：

- 在 Pulse 正常运行、目标 Agent 不处于禁止唤醒状态时，到期提醒应当在合理的时间内进入投递流程。
- MVP 建议目标：到期后 30 秒内完成入队；实际模型开始推理的时间受 Pi 忙碌状态、恢复启动及资源限制影响。
- 不允许通过把所有完整项目巡检无条件提高到数秒一次的方式实现。
- 可以在现有 Pulse 内增加轻量的到期检查或下一次触发时间管理。
- 不应为 Reminder 另起一套与 Pulse 并行的常驻生命周期管理服务。

具体计时方案由 Explore / Propose 阶段评估。

### FR-05 持久化与恢复

**优先级：P0**

Reminder 必须使用 teamsmith 的项目级运行时状态目录保存。

推荐位置：

```text
.pi/team/state/reminders/
```

要求：

- 提醒创建成功后必须已完成持久化。
- Pi Session 重启后能够恢复未触发提醒。
- Pulse 重启后能够恢复定时状态。
- PM 退出时提醒仍然存在。
- 当 Pulse 恢复运行时，需要检测已经过期但尚未投递的提醒。
- 过期提醒不得静默丢弃。
- 对过期提醒应进行受控补发，并明确标记其已过期。
- 大量积压提醒应当限量处理，避免瞬时触发大量推理请求。
- 如果 PM 需要重新启动，必须遵守 teamsmith 现有的 PM 恢复、身份检查和重启配额规则。

提醒状态属于运行时数据，不应默认纳入 Git 版本管理，也不应直接修改 `BOARD.md` 或 `DECISIONS.md`。

必须明确：Pulse 自身没有运行时，系统不保证提醒在原定时间触发；恢复后应按上述规则处理。

### FR-06 Standby 兼容

**优先级：P0**

当前 `team standby on` 表示 PM 主动停止接受自动唤醒。

MVP 必须遵循这个语义。

- Standby 期间，Reminder 到期不能直接绕过 Standby 唤醒 PM。
- 已到期 Reminder 保留为待处理状态。
- Standby 解除后，系统重新评估这些提醒并进行受控投递。
- Reminder 的检测、入队顺序必须避免通过 Outbox 绕过 Standby 的检查。

未来可以另行设计：

```text
team standby until <time>
```

用于“暂时休眠，到指定时间自动恢复”。

但这不属于当前 MVP，不应通过偷偷改变现有 Standby 语义实现。

### FR-07 Reminder 与 Agent 生命周期

**优先级：P0**

Reminder 必须绑定明确的项目与 Agent 身份。

最少需要记录：

- Project identity
- Owner seat（MVP 为 PM）
- Reminder ID
- Created time
- Due time
- Message
- Status
- 可选关联 Task ID / Key

必须遵守 teamsmith 已有的基于工作目录和项目配置的身份判定原则。

不得允许来自其他项目的环境变量或外部路径将提醒注册到错误项目中。

未来 Worker 支持时，还必须处理：

- Worker Session 重启。
- Worker 切换 Task。
- Task 完成或被取消。
- Worker 被移除。
- 原 Session ID 被替换。

MVP 不要求实现 Worker Reminder，但数据模型与接口不应预设“所有 Reminder 永远属于 PM”。

### FR-08 重复触发与可靠投递

**优先级：P0**

提醒触发需要具备明确的状态机与幂等规则。

建议区分以下状态或等价概念：

| 状态 | 含义 |
|---|---|
| scheduled | 已持久化，等待触发 |
| due | 已到期，等待进入投递流程 |
| queued | 已交给持久化投递队列 |
| delivered | Pi 已接受提醒消息 |
| held / failed | 投递受阻或失败，需要恢复处理 |
| cancelled | 提醒已取消 |

状态名称和具体模型可以调整，但必须保证以下区别：

**到期 ≠ 已入队 ≠ Pi 接受消息 ≠ Agent 完成提醒所要求的工作。**

要求：

- 重复执行到期扫描，不应重复创建同一提醒的投递记录。
- 同一个有效 `key` 在同一 Owner 范围内应具有明确的幂等语义。
- 重试、取消、重新创建必须有清晰的契约。
- 投递过程崩溃后必须能够判断当前状态，并提供恢复路径。
- 对无法确定是否已被 Pi 接受的消息，不应盲目重投。
- 应复用已有 Outbox / inbox-watch 的消息身份和去重能力。
- 无法实现端到端严格 exactly-once 时，应明确实际保证，而不是虚假宣称可靠执行恰好一次。

### FR-09 Agent 自主安排后续提醒

**优先级：P0**

Agent 被 Reminder 唤醒后，必须允许再次创建 Reminder。

例如：

```text
09:00 Agent 检查外部任务
      ↓
任务尚未完成
      ↓
Agent 创建 09:15 Reminder
      ↓
当前回合结束
      ↓
09:15 Agent 被再次唤醒
      ↓
继续检查
```

系统不能仅因为本轮推理来自 Reminder，就禁止再次安排提醒。

但必须防止无限自唤醒循环：

- 拒绝不合理的过去时间或零间隔提醒。
- 设置最小提醒间隔。
- 限制单位时间内创建和触发提醒的数量。
- 支持稳定 Key 防止重复注册。
- 对异常高频自唤醒提供明确日志或保护措施。

防护规则应尽可能简单、可解释、可测试。

### FR-10 可观测性与审计

**优先级：P1**

用户和 PM 应能够明确区分：

- 有哪些 Reminder 正在等待。
- 哪些 Reminder 已到期。
- 哪些已经进入投递队列。
- 哪些已被 Pi 接受。
- 哪些因 Standby、Agent 不可用或投递失败而阻塞。
- 哪些已经取消。

最小 CLI 输出示例：

```text
$ team remind list

ID        OWNER  DUE                  STATUS
rem-001   pm     2026-10-28 09:00     scheduled
rem-002   pm     2026-10-28 09:15     held
rem-003   pm     2026-10-28 10:00     scheduled
```

状态数据与审计日志应尽可能复用 teamsmith 现有的运行时布局和记录习惯。

MVP 不要求修改 TUI，但不应设计出 Panel 日后无法读取的私有或不透明格式。

## 5. 推荐架构边界

下面是推荐的职责分配，并非最终实施方案的强制规定。

| 组件 | 职责 |
|---|---|
| `team_remind` Extension Tool | 向模型暴露创建、查询、取消能力 |
| `team remind` CLI | Reminder 的统一管理入口 |
| Reminder Store | 保存时间、归属、状态和审计数据 |
| Pulse | 到期判断与 PM 恢复协调 |
| Outbox | 持久化消息投递 |
| inbox-watch | 将到期提醒传递给 Pi 模型并触发推理 |

### 5.1 避免重复建设

不得无必要地：

- 建立第二套 Agent 消息系统。
- 建立第二套 PM 恢复系统。
- 在 Reminder 中直接实现与 Pulse 重复的生命周期逻辑。
- 引入新的数据库依赖。
- 将调度状态仅保存在 Extension 的内存定时器中。

### 5.2 不侵入正常 Agent 工作流

Reminder 的存在不能改变普通 Agent 的核心行为：

- Worker 正常完成任务后的通知流程不变。
- PM 对 Worker 的调度与独立验证流程不变。
- Standby 默认行为不变。
- 无 Reminder 的项目不应承担显著额外运行负担。
- 默认不产生额外模型 Token 消耗。

### 5.3 扩展加载

teamsmith 当前的 Extension 采用定向注入模式，而不是所有用户 Pi Session 自动加载全部组件。

新增 Extension Tool 必须遵循这一设计。

它应只出现在能够正确识别项目、拥有合法身份、具备 Reminder 权限的 Pi Session 中。

MVP 应明确实现 PM 的 Extension 加载及可用性检查，并确保 `team doctor` 或等价诊断能发现加载缺失。

## 6. 核心验收场景

以下场景应转化为可自动运行的测试，尽可能纳入现有 Smoke / Integration Test。

### AC-01 基本创建与触发

**Given** PM 正常运行，Pulse 已启动。
**When** PM 创建一条 1 分钟后的 Reminder。
**Then** Reminder 持久化成功；到期后系统向 PM 注入提醒消息，并触发新一轮推理。

### AC-02 Agent 主动创建

**Given** PM 正在执行普通项目任务。
**When** 模型自主判断需要延迟检查，并调用 `team_remind`。
**Then** 不需要用户确认即可创建合法 Reminder，并返回可查询的 ID。

### AC-03 PM 停止后恢复

**Given** PM 创建一条未来 Reminder。
**When** PM 进程结束，但 Pulse 仍正常运行。
**Then** Reminder 到期后，在现有恢复策略允许的前提下，Pulse 能够恢复 PM 并交付提醒。

### AC-04 Pulse 重启

**Given** Reminder 已持久化，但尚未到期。
**When** Pulse 被停止并重新启动。
**Then** Reminder 不丢失，仍然能够被检测和触发。

### AC-05 过期补发

**Given** Reminder 到期时 Pulse 未运行。
**When** Pulse 后续恢复运行。
**Then** 系统识别过期 Reminder，并按照补发规则执行；不得静默删除或无限重复发送。

### AC-06 Standby

**Given** PM 已进入 Standby。
**When** Reminder 到期。
**Then** 不触发自动唤醒；解除 Standby 后，Reminder 仍然可被发现与处理。

### AC-07 忙碌中的 Agent

**Given** PM 正在进行一轮尚未结束的推理。
**When** Reminder 到期。
**Then** 不强行中断当前回合，不污染用户输入草稿；消息通过受控队列等待后续处理。

### AC-08 重复触发

**Given** 某 Reminder 已进入投递流程。
**When** Pulse 多次执行到期检查，或在关键阶段重启。
**Then** 不产生无控制的重复投递，且状态可追溯。

### AC-09 连续自主唤醒

**Given** Agent 因 Reminder 被唤醒。
**When** Agent 判断仍需等待，并创建下一条合法 Reminder。
**Then** 新 Reminder 正常注册，并可以在未来继续唤醒模型。

### AC-10 取消

**Given** Reminder 尚未进入投递流程。
**When** Agent 或用户通过 CLI 取消。
**Then** 到期时不应再次触发该 Reminder。

### AC-11 身份隔离

**Given** 系统中存在不同 teamsmith 项目。
**When** 某个项目的 Agent 创建 Reminder。
**Then** Reminder 仅绑定该项目，不允许跨项目错误投递或操作。

### AC-12 回归兼容

**Given** 现有项目未使用 Reminder。
**When** 运行普通 dispatch、notify、review、standby、pulse 与恢复流程。
**Then** 现有功能行为保持兼容，既有测试继续通过。

## 7. 非功能要求

### 7.1 性能

- Reminder 空闲时应有极低资源开销。
- 到期检查不调用 LLM。
- 不依赖高频全量扫描项目文件。
- 应利用已有 Pulse 运行环境，避免新增不必要的常驻进程。
- 对大量 Reminder 应采用有界处理，避免 CPU、I/O 和模型请求突发。

### 7.2 安全

- Reminder 创建与修改必须验证项目身份。
- 不得通过提醒内容执行任意 Shell 命令。
- Reminder 消息本身只能作为模型可见的任务上下文，后续工具行为仍受原有授权边界约束。
- 不得绕过 Standby、PM 恢复配额和现有权限机制。
- 必须限定提醒文本与存储资源的使用上限。

### 7.3 一致性

- 创建成功即意味着提醒已可靠写入项目状态。
- CLI 与 Extension 使用统一的状态来源。
- 持久化写入必须处理并发及进程意外终止。
- 对消息投递的不确定状态应保留足够证据用于恢复和诊断。

### 7.4 兼容性

- 保持 teamsmith 现有最低环境依赖要求，除非技术论证确实需要调整。
- 不影响当前 Pi Session 启动参数及正常 Extension 加载方式。
- 不应要求已有项目重新初始化才能继续使用原有功能。
- 新增配置项应有安全默认值。

## 8. PM Agent 需要重点调查的技术问题

进入开发前，Explore / Propose 阶段必须形成明确结论：

1. **时间调度机制**：如何在不改变原有完整 Pulse 巡检频率的前提下，实现较短延迟的 Reminder 触发？
2. **消息投递复用**：能否完整复用当前 Outbox / inbox-watch？是否需要增加专门的 Reminder 消息类型？
3. **投递确认边界**：如何区分成功入队、成功交给 Pi、Pi 已接受消息，以及模型实际执行？
4. **PM 恢复时序**：PM 退出后，Reminder 触发、PM 拉起和消息投递如何协调，避免丢失或重复？
5. **Standby 语义**：怎样确保到期 Reminder 不经由现有 Outbox 路径绕过 Standby？
6. **扩展加载**：如何确保 PM 可以调用 `team_remind`，同时不让普通 Pi Session 或未授权 Worker 意外获得该工具？
7. **存储与并发**：如何利用现有 `state/` 约定进行持久化、原子更新和去重？
8. **Worker 扩展性**：MVP 仅支持 PM 的情况下，如何避免未来 Worker Reminder 需要推翻现有数据模型？

对可能影响既有行为的技术取舍，需要在提案中写明理由、替代方案和影响范围。

## 9. 交付要求与 Definition of Done

PM Agent 应按照 teamsmith 现有 OpenSpec 工作流实施，不应直接跳过方案评审进入编码。

### 阶段一：Explore

- 检查现有 Pulse、Inbox / Outbox、inbox-watch、PM 生命周期实现。
- 判断最合适的集成点。
- 识别与 Standby、消息去重、Agent 恢复的潜在冲突。
- 给出简洁的架构备选与取舍建议。

### 阶段二：Propose

- 建立 OpenSpec Change。
- 将本需求转化为可验证的 Delta Specs。
- 给出 API、状态机、存储模型和恢复语义。
- 明确技术范围、兼容性和回归风险。
- 经 PM 正式评审为 ACCEPTED 后才能进入 Apply。

### 阶段三：Apply

- 实现 Reminder 持久化和统一管理接口。
- 实现 Agent Tool。
- 实现到期检测与消息投递。
- 与 PM 恢复及 Standby 集成。
- 编写自动化测试和必要文档。

### 阶段四：Verify

- 由独立于实现者的 Agent 执行验证。
- 覆盖第 6 节全部适用验收场景。
- 执行现有 Smoke Test 和 OpenSpec 严格校验。
- 由 PM 在独立 Checkout 上复核证据。
- 对需要真实 Pi / tmux 环境的场景提供可复现的集成测试。

### 阶段五：Archive

- 完成代码交付与 Review。
- 更新用户文档和相关 Skill 指导。
- 确认 OpenSpec Change 符合归档条件。
- 经现有流程要求的确认后归档。

最终交付应包含：

- 可用的 Agent Reminder Tool。
- 可用的 `team remind` CLI。
- 与现有 Pulse 和消息系统集成的实现。
- 持久化和恢复能力。
- 自动化测试。
- 用户文档。
- OpenSpec 规格与独立验证记录。

## 10. 产品验收标准

本需求是否成功，不以“是否有一个能在指定时间调用回调函数的 Timer”为判断依据。

真正的验收标准是：

> 一个 teamsmith PM Agent 在执行项目工作时，可以自主决定未来需要再次处理的事项，调用工具登记 Reminder，然后正常结束当前回合；当时间到达时，teamsmith 能够在遵守生命周期、Standby、投递安全与资源限制的前提下，将提醒消息送入对应 Pi Agent，并使其继续推理和工作。

整个过程不要求用户保持交互，也不要求模型持续运行或不断进行轮询。

**最终目标：让 Agent 拥有可靠的、受 teamsmith 管理的未来行动触发能力。**

---

## 附：给 PM Agent 的执行指令

请将本文作为需求输入，而不是已经批准的技术设计。

首先检查当前仓库状态、现有规格及实际实现，特别是 Pulse、Inbox / Outbox、inbox-watch、PM 恢复、Standby 和 Extension 加载机制。

优先考虑最小侵入式的原生实现，不要因为存在第三方 `pi-schedule-prompt` 就直接将其作为运行时依赖，也不要在没有必要的情况下重建 Scheduler。

请严格按照 teamsmith 现有的 Explore → Propose → Apply → Verify → Archive 工作流推进。

先完成需求澄清、架构调查、OpenSpec 变更提案与正式评审，再分派实现任务。对需求中允许技术选择的部分自行作出合理决策并记录依据；遇到真正影响产品边界或既有语义的重大取舍，再提交用户裁决。

优先交付一个可靠、简洁、可测试的 PM Self-Reminder MVP，而不是功能庞大的通用调度框架。

### 2026-10-28T02:38:43Z · from: pm · re: P385
P385 PM/V111 verdict: REWORK REQUIRED, no Propose. PM reproduced Pi 1.4.0 sendMessage:void plus asynchronous/deferred behavior. Read the appended main-checkout brief and reviews/P385.md + reviews/V111.md. Preserve the original report; revise to a single-store/direct-watcher hypothesis and run only the bounded isolated controlled-model Pi API probe. Resolve or honestly bound Standby races and one authoritative delivery record. Fresh same-task recovery; no product/spec/change/live-team writes.

### 2026-10-28T05:12:53Z · from: user · re: P385
用户最终产品语义（2026-10-28）：允许进入 Standby，但也允许被 PM 自己建立的提醒叫醒。示例：17:00 Standby，18:00 自有 Reminder 仍会唤醒 PM。此决定覆盖原需求 FR-06 的禁止唤醒，也取代此前尚未定案的 A/B/C；Standby 只抑制普通自动工作。请按主检出 P385 任务书末节做报告-only 增补。

### 2026-10-28T05:14:08Z · from: user · re: P385
用户补充最终语义：用户通过 CLI 创建的 PM-owned Reminder 也允许在 Standby 期间叫醒 PM，与 PM Agent 自己创建的 Reminder 相同。创建来源需审计，普通非 Reminder 自动唤醒仍受抑制。D204 与主检出任务书已纳入。

### 2026-10-28T05:19:59Z · from: user · re: P385
用户继续明确（2026-10-28）：Reminder 在 Standby 中实际唤醒 PM 后，退出 Standby。请把“实际唤醒时自动解除 Standby；仅到期/入队或投递失败但未唤醒不提前解除；记录 reminder ID/source 审计；同批唤醒只解除一次”纳入 P385 最终报告增补。普通自动工作在唤醒后也恢复。

### 2026-10-29T02:26:02Z · from: user · re: P390
用户新决策（2026-10-29）：PM 通过 team say 向其他 agents 发消息时，默认不用 --now 导致传递不及时；要求 team say 默认就是现有 --now 行为，并移除 say 的 --now 参数。范围不扩到 notify、meeting、pulse 或 outbox flush --now。请按 P390 探索任务核查契约与测试，不直接实现。

### 2026-10-30T06:51:02Z · from: pm · re: P397
P395正式提案已ACCEPTED，phase按证据结项（未合并，原分支0e557f47保留）。现派P397：从P379已接受测量直接写gate-execution-slimming提案，独立工作树，不等P396、不再跑全量；详见新任务书和D217。先证明61b减重复且保留观察，再设计耗时均衡分片；不得把具名红侧仍在当成所有附带覆盖不变。

### 2026-10-30T07:03:26Z · from: pm · re: P397
用户已在运行席位选回其配置的模型，并明确要求PM不再帮改。P397初始--model覆盖是PM错误，任务书已纠正：不要为旧启动说明切回OpenAI，不重启或改配置；以后新任务按category，不沿用临时覆盖。主检出init兼容写入调用者未证实，P397仍只读证据/写提案，不等恢复也不跑门禁。

### 2026-10-30T07:43:09Z · from: pm · re: P397
P397冻结4bdcc5b3进入V118独立审，先勿改候选，待结论后集中修订。PM clean-clone结构/试归档已复现20/20、19/19，不跑长矩阵。已确认一项算术问题：design §6的14307-(6719-[2850..3000])-(1190-830)-(1122-960)=[9916..10066]s=165.3..167.8min，并非9344s/155.7min；§38在文中按0节省，差572..722s需逐项解释或更正。完整证据在main的docs/team/reviews/gate-execution-slimming-proposal.md，待V118齐后给最小统一返修单。无Apply授权。

### 2026-10-30T07:57:28Z · from: pm · re: V119
V119新独立审查：P391作者dev3，冻结f5945feb52cd，范围仅最后marker回复衔接/AGENTS边界修订及R1-R3，不重复V113已关六项。你此前P397已交付，4bdcc5b3分支保留，等待V118收齐后集中返修；本次--force仅换审阅任务，不是把P397标done/合并或替你改作者候选。只写V119报告，不跑full smoke/长矩阵，不执行live init。模型按当前verify策略，不带旧override。详读brief和正式review最新两节。

### 2026-10-30T08:13:08Z · from: pm · re: V119
V119协调：PM已修正自己任务书/正式review中的绝对私有家目录，用等价$HOME命令；注入这两个PM文件的小提交4779bcc4和当前tip不改任何P391规划。不要把这种PM元数据命中算作者候选缺陷；可定点重跑ledger，不重做结构检查。P397的V118已交NEEDS-CHANGES，四项集中裁决和更新brief只在main待接回；先完成V119，勿在当前P391分支动P397。
