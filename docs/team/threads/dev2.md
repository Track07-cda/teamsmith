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
