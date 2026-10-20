# V75 · P336 的独立验收：写信用夹具的等待改造

task: V75　agent: dev2　status: **PASS（第二轮 · `dffb0261`）**　time: 2026-10-20T14:52Z
phase: verify　change: `-`　branch: `task/V75-panel-b2-waits-verify`

> **要不要读哪一段**：第二轮（返修后的 `dffb0261`）的结论在本节下面与文末「第二轮」一节；从 `## 结论（先读这一段）`
> 起的正文是第一轮对 `6703cc11` 的记录，**原文保留**（它判的那个字节已经作废，但里面那几项已成立的结论仍有效）。

**第二轮一句话**：不带 tmux shim 的 PATH 上连跑两次全场景都是 `✓167 ✗0`（482 s / 483 s，`没等到=0`）；
那 200 ms 是**条件性**的（`keys` 场景插桩：60 次发送只有 24 次真的睡了，合计 4.8 s，其余 35 次一秒没花）；
没有新增 ≥1 秒的固定等待（`sleep` 11 → 12 处，唯一新增就是那一行 pacing，上限 0.2 s）。细节见文末。

受检（第二轮）：`dffb0261`（产品面 24 行：`_b2_send` + `keys`/`type_text` 两个包装；文件 md5
`d695d264c2160792bec82a8eb49c6642`）。第一轮受检：`6703cc11`（产品面只有一个文件
`skills/teamsmith/tests/panel-b2.sh`：实现 `8f4fdcad` + 只改注释的
`b4dfdc36`；该文件 md5 `9a9861de883967723f7de8d8504f9efb`）。对照：`main`（`6e007670`）同一文件
（md5 `83062f4e5ca2ff0f647abc6de62fbd75`）。两棵都导出成独立树跑，我的工作树里这个文件一个字没动。

实验环境：宿主上跑，私有 `TMPDIR`（`/var/tmp/…`）+ 私有 `TMUX_TMPDIR` + 私有 socket（`-L p13b2-<pid>`），
32 核，实验期间 load 4–11。开跑前按任务书 `ps` 过一遍：另一个席位的整套 smoke（`--paths …`，pid 423833）
已经在跑，我等了 7 分钟它没结束，按「确认后记录」的口径继续（它全程在跑，到我这轮 attribution 阶段还在；
这也是墙钟数字只作参考的原因）。

## 结论（先读这一段）

**FAIL。三个问题里前两个的答案是「一条没少」「等对了状态」；第三个没有绕法，但候选自己带来了新的红。**

1. 候选在这台机器上**两次全场景都红**：`✓163 ✗4`（run1 576 s / run2 565 s，各 4 次 `没等到`），
   报告里写的是 `✓167 ✗0` 四次、`没等到=0`。
2. 四次红全在 `scenario_keys`，形状是「按键没生效」，不是断言被放松：

   ```
   run1
   ✗ B2 词/行/前向删除 → Zalpha （期望 [Zalpha ]，实际 [Zalpha beta]）
   ✗ B2 ctrl+k 删的是逻辑行（整行 45 字符），不是绘制行（期望 [<换行>second]，实际 [45 个 x + <换行>second]）
   ✗ B2 ring：ctrl+y 放回新的，alt+y 换成旧的 → 空格+gamma（期望 [ gamma]，实际 [alpha beta gamma]）
   ✗ B2 ring 累积：alt+y 换回合并的一条（期望 [ beta gamma]，实际 [alpha]）
   run2（同样的四条，中间的取值又不一样 —— 说明是时序，不是逻辑）
   ✗ B2 词/行/前向删除 → Zalpha （期望 [Zalpha ]，实际 [alpha Zbeta]）
   ✗ B2 ring：ctrl+y 放回新的，alt+y 换成旧的 → 空格+gamma（期望 [ gamma]，实际 [alpha beta]）
   ```

   每条前面紧跟一行 `没等到 …：100/500 轮（耗时约 35–37 s；…缺 [@@draft … @@]）`。
3. **归属**（同一台机器、同一时刻，§5 的六次对照）：候选 `keys` = ✗4 / ✗3；`main` 那份 = ✗1 / ✗1
   （另一种既有红：面板还没起来就按了 `m`，草稿是空的）；**候选 + 把这 20 处连发按键之间机械补回 0.4 s
   暂停（41 处）= ✓23 ✗0 两次**；候选在**带 agent 会话 tmux shim 的 PATH** 下 = ✓23 ✗0 两次。
4. **机制**（§5.2）：Ink 7.1.1 的 `useInput` 对每个 stdin `data` 块只解析一次，多字符块按「粘贴」整串交给
   调用方 —— 两个背靠背的 `tmux send-keys` 落进同一次 read 就合成一次输入，控制键被吞。`main` 那份里
   这种连发 **0 处**（每个键之间都有 `sleep`），候选 **20 处**。shim 每次 tmux 调用多 ~16 ms
   （20 次调用：0.04 s → 0.36 s），正是这点延迟把作者的运行拆成了两次 read。
5. 所以作者的 `✓167 ✗0 ×4` 不是编的，但它**依赖运行环境里有一个不属于产品的 PATH 包装**；CI、门禁容器、
   普通 shell 都没有这个包装，同一份字节就红。修法很小：连发的按键之间补一个短暂停（我机械补了 41 处，
   `keys` 两次全绿；全场景结果见 §5.4）。**这不是让我改实现 —— 我只交证据和方向。**

## 1 · 断言与场景：一条没少

自己的抽取（不抄报告）。先把两个版本导成副本，再抽：

```
$ git show main:skills/teamsmith/tests/panel-b2.sh > base.sh      # main = 6e007670
$ git show 6703cc11:skills/teamsmith/tests/panel-b2.sh > cand.sh
$ join_cont() { awk '{ if (sub(/\\$/, "")) { printf "%s", $0; next } print }' "$1"; }
$ asrt() { join_cont "$1" | grep -oE '(^|[^[:alnum:]_])(assert_eq|assert_has|assert_match|assert_not_has|cap_has|cap_not_has|cond_skip|ok|bad)[[:space:]]+"'; }
$ diff <(asrt base.sh) <(asrt cand.sh) && echo identical
identical
$ asrt base.sh | wc -l; asrt cand.sh | wc -l
200
200
$ names() { sed -n 's/^ALL="\(.*\)"$/\1/p' "$1"; grep -oE '^scenario_[a-z]+\(\)' "$1" | tr -d '()' | sed 's/^scenario_//'; }
$ diff <(names base.sh) <(names cand.sh) && echo identical
identical
$ names cand.sh | tr '\n' ' '
cursor keys multiline clipboard draft editor receipt settle pause paste actions cursor keys multiline clipboard draft editor receipt pause paste actions settle
```

场景名与 `ALL=` 里的顺序两边完全一致（11 个：cursor keys multiline clipboard draft editor receipt settle
pause paste actions）。这 200 行里有 4 行是 helper 自身的定义（`assert_eq() { … ok/bad … }` 那种），
把定义行排掉是 **184 处调用点**（`assert_eq` 95 / `assert_has` 45 / `assert_not_has` 7 / `assert_match` 1 /
直接 `ok`·`bad` 33 / `cond_skip` 3），有序序列两边逐字节相同 —— 两种抽法结论一样。

第三份对照：夹具**对被测算面做了什么**（`keys` / `type_text` / `tmux` 子命令 / `team` 子命令 / 直接写
`state/draft.md`）按语句序列比，两边 412 条，只差三处基础设施行（`pty_cap` 新增的 capture-pane、
`wait_panel` 失败路径改成 `pty_cap`、`resize_pane` 的函数体换行）—— 也就是说改动只落在「每一步之后怎么等」。

**答案（一）：一条没少，也没有一条被改宽松。**

## 2 · 全场景两次

同一棵候选树、两个独立私有根，`TEAM_B2_KEEP=1` 留现场：

```
run1  rc=1  wall=576s  == 结果 ==  ✓ 163  ✗ 4   没等到=4
run2  rc=1  wall=565s  == 结果 ==  ✓ 163  ✗ 4   没等到=4
```

（报告 §4.2/§4.3 是 `383s / ✓167 ✗0`，连跑三次 + 交付前一次都 `没等到=0`。我这边两次都红，见 §5 的归属。）

## 3 · 那两条原本的红（3.1 standby）：是「等对了状态」

任务书要求的翻转：**在候选树上只把这两条的等待改回固定 `sleep`，断言一字不动**。

| 跑法 | 树 | rc | 墙钟 | 结果 |
|---|---|---|---|---|
| flip1/2/3 | 候选 + `wait_frame '· 待命 on'`、`wait_frame '待命 off'` → `sleep 3` | 1 / 1 / 1 | 34 / 25 / 23 s | ✓10 ✗1 ×3 |
| pre1/pre2 | `main` 原文件（未改） | 1 / 1 | 26 / 26 s | ✓9 ✗2 ×2 |
| ctl1 | 候选原样 | 0 | 30 s | **✓11 ✗0** |

flip 三次红都在同一条（CLI 真值）：

```
✗ 3.1 CLI 报告 standby off（…/actions/status-off.txt 里找不到 [standby: off]）
```

保留现场里的因果链（`ftmp/…/actions/standby-off.txt`、`status-off.txt`、`standby-on.txt`）：

- 按下理由的 `Enter` 之后，`standby-on.txt` 的标题带**仍是** `… 巡检 900s · 待命 off`（旧值），只有回执行是
  `✓ 待命 on（原因：lunch）`；
- 3 s 后按 `s`，那一帧的标题带还是 `· 待命 off`，底下却打开了 `╭─ 待命原因 ─╮` —— 面板缓存里的
  `standby.on` 还是 false，于是 `s` 走了「开理由行」那一支；同一刻 CLI 是 `standby: on`。
- 也就是说：**固定等待下，帧断言 `待命 off` 反而是在旧帧上蒙对的**（flip 的三次里它都过了），真正抓住问题
  的是 CLI 那条。pre1/pre2 又给出两种别的形状（`✗ 3.1 理由没有覆盖消息草稿（实际 []）`、`✗ 3.1 再按 s
  回执显示待命 off` + CLI 红），同一根因、红点漂移 —— 这正是「固定秒数」的病。

候选为什么是等对了：等的是标题带上的 `· 待命 on`，它与 `s` 的开关判定读的是**同一份数据** ——
标题带的文字由 `panel/src/layout.ts:386-388` 从 `panel.standby.on` 画，`s` 的动作守卫在
`panel/src/App.tsx:729` 读 `dataRef.current.panel?.standby?.on`；两者同源（`layout()` 吃的是渲染那一帧，
`dataRef` 只会在新帧到达时被替换，`App.tsx:1928`），标题带写着 on ⇒ 守卫读到的也是 on。等完之后再按 `s`，
`actions` 场景 11 条全绿（ctl1）。

**答案（二）：等对了状态。**（顺带一条：那条帧断言 `3.1 再按 s 回执显示待命 off` 的针 `待命 off` 分不清
「回执」和「标题带」，flip 里它就是靠旧标题带过的 —— 断言本身是这个弱形状，但它是**改前改后逐字节相同**
的既有断言，不是 P336 放松的。）

## 4 · 剩下 11 处固定等待（逐条）+ 被点名的上界

候选里 `sleep` 命令正好 **11 处**（`main` 那份 220 处 / 217 行），逐条对得上报告 §3 的 11 行：

| 行 | 位置 | 我的判读 |
|---|---|---|
| 165 | `new-session … 'sleep 600'` bootstrap 占位 pane | 占位进程，不是等待 —— 同意 |
| 644 | 假 `wl-paste` 的 `hang) exec /bin/sleep 60` | 被测对象（工具挂死），不是等待 —— 同意 |
| 867 | 假编辑器 `sleep "${TEAM_B2_EDITOR_HOLD:-2}"` | 模拟人在编辑器里停住 —— 同意 |
| 498 | undo 历史空后再按 ctrl+- 后 0.6 s | 幂等空操作，帧与文件都不变 —— 同意 |
| 744 | 挂死工具后 5 s | 否定观察的窗口，`Z` 必须落在这段窗口里 —— 同意 |
| 811 / 815 | `⑦` 两段 5 s 空闲 | 同上的否定观察（不按 C-v 就不起工具）—— 同意 |
| 908 | `B3` 挂起期间 1.3 s | 断言本身就是「窗口内画面没变」—— 同意 |
| 954 | 真 vi 的 `Escape` 后 0.3 s | vi 的 ESC 消歧超时，外部工具 —— 同意 |
| 1037 | `2.5` 的 6 s | 慢桩节流间隔，观测量就是「隔了一轮」 —— 同意 |
| 1180 | `2.7 error` 重试后 3 s | 同一条回执，没有新状态 —— 同意 |

**没有漏报的 `sleep`**：`grep -nE '\bsleep\b' cand.sh` 的 11 行代码全在这张表里（另有两行是注释）。
**没有把 sleep 塞进循环**：候选里唯一的循环是 `for i in $(seq 1 12); do keys Up; done`（不发 sleep）和
runner 的场景循环；`main` 里那两处「循环 + sleep」的等待（`wait_panel` 的 40×0.25 轮询、editor 场景两处
`for i in $(seq 1 25) … sleep`）在候选里都换成了真等待。夹具没有覆盖任何 `PTY_*` knob（`grep -c PTY_ cand.sh`
= 0），全用库默认值。

**被点名的上界（报告没有写）**：库默认 `PTY_WAIT_ITERS=100`、`PTY_EXT_FACTOR=5`，即**基础视界 100 轮、
上限 500 轮**。我这台机器上实测（§5.5）：

```
静态现场、真 capture：rc=1 rounds=100 ceiling=500 elapsed=35256ms（0.35 s/轮）
上限外推（500 轮 × 0.35 s）：约 176 s / 一次耗尽
成功路径（条件成立）：rounds=1，256 ms
```

也就是说：**一次等待的上界 ≈35 s（静态）/ ≈176 s（仍在绘制），远在 60 s 之上**，而且耗尽**不致命**
（`wait_frame`/`wait_state` 把引擎判定交回调用方，脚本继续，靠紧随其后的断言判红）。单次有界没问题，
**合起来无界**：候选在全场景里有 **161 处 `wait_*` 调用点**（另有 3 处是 helper 内部委派），产品整体坏掉时
最坏是 161 × 35 s ≈ 1.6 h 才跑完（对比改前 217 处固定等待合计约 186 s）。这次 4 次 `没等到` 让 run1 多烧了约 145 s —— 真实发生过。接 P327 进门禁前值得
定一个夹具级预算（例如「本轮耗尽超过 N 次就停跑并点名」），否则一次产品回归就是小时级的红。

## 5 · 归属实验（候选为什么红）

### 5.1 六次对照（同一台机器，前后 9 分钟）

```
candA  rc=1 189s ✓19 ✗4  没等到=4     # 候选原样
baseA  rc=1  55s ✓22 ✗1  没等到=0     # main 原文件（每个键之间 0.4 s）
burstA rc=0  58s ✓23 ✗0  没等到=0     # 候选 + 相邻按键之间补回 0.4 s（41 处，别的一字不改）
candB  rc=1 154s ✓20 ✗3  没等到=3
baseB  rc=1  54s ✓22 ✗1  没等到=0
burstB rc=0  58s ✓23 ✗0  没等到=0
```

`base` 那一条红是**另一种既有红**：`✗ B2 词/行/前向删除（期望 [Zalpha ]，实际 []）` —— 保留现场里那一帧
根本没有写信托盘（面板还没起来就按了 `m`），是「固定 10 s 起画面 + 0.8 s」猜出来的病，正是 P336 想治的
那一类。`burstfix` 两次全绿，说明**候选的问题就是那 20 处连发**。

### 5.2 机制

- `skills/teamsmith/scripts/panel/node_modules/ink/build/hooks/use-input.js:40`：每个 stdin `data` 块只做
  一次 `parseKeypress(data)`；同一个文件的文档（第 7 行）写明「如果是多字符（粘贴），回调只被调用一次，
  整串作为 `input` 交出去」。
- 两个 `tmux send-keys` 是两次写；面板还没有读到第一份时第二份就到了同一个 read buffer 里 —— 于是一次
  `useInput` 得到 `\x17\x01…` 这样的整串，控制键那一支不被识别，按键被吞。
- 候选把这 20 组按键的间隔取消了（「两个按键之间没有任何状态被读 → 那次等待直接删掉」这条规则），
  `main` 里每组之间都有 0.4 s。这就是「删等待」与「删同步」的差别：**按键之间不读状态，不等于不需要间隔**。

### 5.3 作者的运行环境解释了它的四次绿

把 agent 会话注入的 tmux shim 放回 PATH（并把它自己的日志指到私有文件），同一份候选字节：

```
shimA rc=0 44s ✓23 ✗0 没等到=0   （shim 记到 365 次 tmux 调用）
shimB rc=0 43s ✓23 ✗0 没等到=0   （364 次）
```

shim 的代价直接量过：

```
20 次 tmux -V：直接调 /usr/bin/tmux 0.04 s；经 shim 0.36 s          （每次多 ~16 ms）
```

~16 ms 足以把两次 send-keys 拆成两次 read。结论：候选的绿**不是靠产品状态，而是靠一个只在 agent 窗口里
存在的 PATH 包装**。门禁容器/CI/普通 shell 没有它，所以在那些地方同一份字节是红的。

### 5.4 修法（只作为方向，没有改实现）

在候选副本上机械地把「相邻两条按键语句之间」补回 `sleep 0.4`（20 组、共 41 处；其余一字不改）后：
`keys` 两次 ✓23 ✗0，全场景一次 **`rc=0 wall=422s == 结果 == ✓167 ✗0`（`没等到=0`）** —— 同一台机器、
同一个干净环境、同一份断言集（167 条全部跑到），只是把按键之间的节奏留下了。这正是把「删等待」与
「按键节奏」拆开：状态等待照旧（那部分是对的），只把**键盘事件的间隔**留下。

### 5.5 引擎上界的实测

```
trivial-cap   rc=1 rounds=100 ceiling=500 elapsed=34993ms
tmux-capture  rc=1 rounds=100 ceiling=500 elapsed=35256ms（0.35 s/轮）
success-path  rc=0 rounds=1  elapsed=256ms
```

## 6 · 私有性

调用者默认 server 前后各一次快照（真 tmux，避开 agent shim）：**server pid 两次都是 `2767298`**；
本会话 `teamsmith` 的 5 个窗口（pm/pulse/dev/dev-bob/dev2）**pane pid 逐行相同**；两份快照里
`p13b2`（夹具 socket 名）**各 0 行**。唯一的差异是另一个项目的 worker 窗口在同窗口期开了又关
（不在本项目，与本轮无关）：

```
$ diff caller-before.txt caller-after.txt
19,20c19,21
< <另一项目>:4:dev4 pane=2740262
< <另一项目>:5:dev5 pane=346227
---
> <另一项目>:4:dev5 pane=346227
> <另一项目>:5:dev pane=1670655
> <另一项目>:6:dev4 pane=1962583
```

实验全程 `TMPDIR` / `TMUX_TMPDIR` 都是私有目录，夹具的 socket 是 `-L p13b2-<pid>`；夹具不碰
`TEAM_SMOKE_LOCK`（`grep -c LOCK panel-b2.sh` = 0），所以我没有抢机器级门禁锁，也没有跑整套门禁。

一处环境选择要说清：我这一轮把 agent 会话注入的 tmux shim 从其 PATH 上拿掉了（它会往真实仓库的
`state/` 写调用日志），用的是 `/usr/bin/tmux`。这不是「为红找环境」—— §5.3 在同一份字节上把 shim 放回去
重跑两次，两次都绿；两种环境都量了，结论因此是「绿依赖 shim 的延迟」而不是「绿依赖我的环境」。

## 7 · 轻量收口（在候选树上）

```
$ bash -n cand/skills/teamsmith/tests/panel-b2.sh ; echo rc=$?
rc=0
$ ( cd cand && PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict | tail -1 )
Totals: 21 passed, 0 failed (21 items)
$ git diff --check main...6703cc11 -- skills/teamsmith/tests/panel-b2.sh ; echo rc=$?
rc=0
$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: root=<本席位 worktree> scope=published files=1906 hits=0 names=ok user=resolved   (rc=0)
```

（`openspec` 不在登录 PATH 上，只在 `$HOME/.bun/bin/openspec`，所以带前缀跑；不是跳过。）

## 8 · 报告本身的偏差（不影响上面的结论，但要点名）

- 报告 §1 拿 `ctrl+w ×2` 举例说「所以写成 `> alpha` + `!beta gamma`」—— **代码里没有这根反向针**：那一处
  用的是 `wait_draft "B2 两次 ctrl+w" 'alpha'`（读草稿文件，不存在前缀问题）。emoji 那条
  （`'│ > 中文' '!🙂'`，`cand.sh:364`）是真的。规则本身站得住，举的例子有一半不是代码里的做法。
- 报告的 `✓165 ✗2 → ✓167 ✗0` 里，改前那两条之一在我的 pre1 里换成了
  `✗ 3.1 理由没有覆盖消息草稿（实际 []）` —— 同一个根因（面板帧/缓存没跟上，`s` 开了理由行，理由把它当成了
  消息草稿），红点漂移。这不推翻它的结论，但它写的「那两条」其实是一类。

## 9 · 我没做的

- 没有跑容器里的门禁，也没有跑整套 `smoke.sh`（任务书要求不跑）。测试面只有这一个夹具。
- 没有验证 P327 的接线（夹具目前不在任何门禁段里），所以「进门禁后会怎样」我只有 §4 的推算（小时级红）。
- 没有去修实现：`burstfix` 那 41 处只活在我的实验树里（报告里给的是变换规则），候选树一个字没动。

## 附：实验件（我的运行根，pid 作用域；夹具根与私有 server 已按显式路径清掉）

`/var/tmp/v75-dev2-1173527/`（34 MB）：

- `burstfix/` —— §5.4 的候选 + 41 处暂停（可直接跑）；
- `logs/` —— 主实验（`run1/run2/flip1-3/pre1-2/ctl1/burst-all` 日志、调用者默认 server 的前后快照、两份
diff、`scenes/` 里 §3 的那几帧与 CLI 输出）；`logsA/` 是 §5.1 的六次对照，`logsB/` 是 §5.3 的 shim 两次与
§5.5 的引擎上界；
- `cand.sh` / `base.sh` / `full.diff` / `run-*.sh` / `*.py` —— 抽取与变换脚本。

候选树与对照树分别是 `git archive 6703cc11` 的导出和 `git show main:…` 的覆盖，随时可重建。收尾时删掉了
17 个夹具根（`TEAM_B2_KEEP=1` 留的）、13 个私有 `TMPDIR` 基（里面的 node 编译缓存）与全部私有 tmux server：
收尾后 `ps` 里没有 `p13b2` 进程，每个私有 `TMUX_TMPDIR` 下都没有活 server。

## 第二轮 · 返修后的独立验收（`dffb0261`）

### R1 受检与差异

- 候选 `dffb0261` = `6703cc11` + `d8ace291`（产品面 24 行）+ 报告更新。产品文件 md5
  `d695d264c2160792bec82a8eb49c6642`，与 `git show dffb0261:skills/teamsmith/tests/panel-b2.sh` 一致 ——
  我跑的就是这个字节（导出成 `/var/tmp/v75-dev2-1173527/r2/cand`，独立树）。
- 产品面只多一处：`keys`/`type_text` 合并到 `_b2_send`，`B2_KEY_GAP_US=200000`，用 `EPOCHREALTIME` 打两个
  时间戳，**只有「上一次发送结束 → 这一次发送开始」不足 200 ms 时才补睡差值**。
- 断言与场景没被碰到（重跑第一轮那两条抽取，只是确认返修没顺手改判据）：`diff <(asrt base.sh) <(asrt cand.sh)`
  为空、两边各 200 行 / 184 处调用点；`diff <(names …)` 为空。这一项不重开第一轮的结论。

### R2 两次全场景（不带 shim 的 PATH）

```
run1  rc=0  wall=482s  == 结果 ==  ✓ 167  ✗ 0   没等到=0
run2  rc=0  wall=483s  == 结果 ==  ✓ 167  ✗ 0   没等到=0
```

环境与第一轮同口径，只换了候选字节：`PATH=/usr/local/bin:/usr/bin:/bin:$HOME/.bun/bin:$HOME/.local/bin`
（`command -v tmux` = `/usr/bin/tmux`，**没有** `teamsmith/scripts/shim`）、私有 `TMPDIR`/`TMUX_TMPDIR`、
`TEAM_B2_KEEP=1`、`bash 5.3.9`、跑前 `ps` 里没有别人的 `smoke.sh`、起跑 loadavg 4.30（第一轮是 8–11）。
同一条命令在上一轮那批字节上是 `✓163 ✗4`（576 s）——同一台机器、同一个环境、同一份断言集。

### R3 那 200 ms 是条件性的（插桩，不是读代码推断）

把候选原样复制一份，只在 `_b2_send` 里加一行日志（睡没睡、睡了多久），跑当初红过的那个场景（`keys`）：

```
sends 60 = FIRST 1 + SLEEP 24 + FREE 35
paced：24 次 × 约 199.9 ms = 合计 4.798 s（该场景墙钟 57 s，占 8.4%）
free ：距上一次发送 min 285 ms / 均值 1048 ms / max 10.9 s —— 中间隔了 wait_* / cap / 断言
```

- **不是无条件固定等待**：60 次发送里只有 24 次真的睡了，而且全是「上一次发送在 53–82 µs 之前」那种背靠背
  连发；其余 35 次一秒没花。插入的那 24 次正是当初被吞掉的那几处。
- 静态读数对得上：`_b2_last_send` 只在 `_b2_send` 内打戳，`wait_*` / `cap_*` / 断言都不碰它 —— 中间读过一次
  状态，间隔早就超过 200 ms。
- 上限就是 `B2_KEY_GAP_US` = 200 ms，比任务书禁止的「秒级掩盖」低一个量级；`keys`/`type_text` 是唯一出口
  （文件里除 `_b2_send` 之外没有裸 `send-keys`）。

### R4 没有新增 ≥1 秒的固定等待

`sleep` 命令从 11 处变成 12 处，唯一新增是 R3 那一行 pacing（≤0.2 s）；其余 11 处**逐字未变**（行号整体 +20，
因为插了 21 行代码）：

```
165  'sleep 600' 占位 pane    664  hang) exec /bin/sleep 60    887  sleep "${TEAM_B2_EDITOR_HOLD:-2}"
518  0.6（幂等空操作的观察窗）  764/831/835  5 s 否定观察         928  1.3 s 画面静止窗
974  0.3（vi ESC 消歧）       1057  6 s 节流间隔                1200  3 s 同回执重试
215  pacing ≤0.2 s（新增，条件性）
```

### R5 额外的负载样本（超出三件事，我加的）

`keys` 场景两次在「机器在忙」的现场都是绿的：

```
load-keys  rc=0  79s  ✓23 ✗0  （我自己起的 24 个 burner = 0.75 × 32 核，实测 loadavg 25.7–27）
busy-keys  rc=0  57s  ✓23 ✗0  （我自己的 burner 全清；别人家的门禁把 loadavg 压到 12.4）
```

**两条我自己的瑕疵要写明（harness 的，不是产品的）**：

- 那份负载 harness 的 `stop_load` 没生效：`burners` 数组是在 `start_load … | tee` 的管道子 shell 里更新的，
  父 shell 看到的是空数组 —— 所以 `load-keys` 跑完后 24 个 burner 还活着、loadavg 一直挂在 25 左右。我已按
  显式 pid 全部杀掉（两次各 24 个，共 48 个）。这不影响 R5 那个样本的负载前提（它确实跑在 ≈0.8 × 32 核上），
  但 `load.txt` 里「load stopped」那一行是假的。
- 更早那次（14:44）因为 burner 继承了管道写端，harness 卡在 `start_load | tee` 上没有往下走；我杀父进程时
  留下了一个孤儿夹具（pid 288447 + 私有 server `p13b2-288447`）。它在 14:5x 按显式 pid 与 socket 名清掉了，
  它那次运行的结果我**没有**采用。

### R6 边界

- 200 ms 限的是**写**间隔，不是**读**延迟：面板事件循环若被饿死超过 200 ms，两次写仍可能落进一次读。R5 只有
  两个忙碌样本（0.4× 与 0.8× 核，都绿），不能证明极端情况；P327 接线后如果门禁机器常跑到 1× 核以上，值得再取
  样本 —— 这是我唯一还担心的残余风险。
- `EPOCHREALTIME` 要 bash ≥ 5，这不是新依赖：项目本来就以 bash ≥ 5 为下限
  （`skills/teamsmith/scripts/lib/cmd-project.sh:383` 对 `bash` 做 `BASH_VERSINFO[0] >= 5` 的检查；本机 5.3.9）。
- 报告 §7.2 写「全场景有 45 段连发、93 处相邻发送」；我插桩量到的是 `keys` 单个场景 24 次 paced 发送。口径不同
  （我数的是真的睡了的那几次），不逐条对账。
- 没有跑容器门禁、没有跑整套 `smoke.sh`（任务书要求不跑）；P327 的接线仍未验。

### R7 第二轮收尾

树干净、分支不变；这一节的证据都在 `/var/tmp/v75-dev2-1173527/r2/`（`logs/summary.txt`、`run1/run2/inst`、
`send-pacer.log`、`load.txt`、`load-keys.log`、`busy-keys.log`、`cand/` 导出树、`inst/` 插桩树）。
