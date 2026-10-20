# P336 · 写信用夹具：固定 sleep 换成有界状态等待

agent: dev   status: delivered（含 V75 返修）   time: 2026-10-20T12:01Z
branch: `task/P336-panel-b2-bounded-waits`   phase: apply   change: `-`
写集：`skills/teamsmith/tests/panel-b2.sh` + 本报告
提交：`8f4fdcad`（换等待）、`b4dfdc36`（只改三行注释）、`d8ace291`（返修：连发的按键分到两次 stdin 读）+ 本报告
（写集只有这一个产品文件）

## 结论先写

1. 220 处 `sleep` 里的 209 处换成既有的 `lib/pty-wait.sh`（等「那件事为真」+ 帧静止），剩 11 处，
   §3 逐条给了理由。切下来的固定等待合计 186.1 秒（其余 686.2 秒是 600 秒占位 pane、60 秒假工具、
   15 秒三段否定观察、6 秒节流间隔等，见 §3）。
2. **断言集合一条没动**：186 行断言行改前改后逐字节相同（§4.1 的 diff 是空的）；场景名集合相同
   （11 个，名字与顺序不变）。
3. **V75 的 FAIL 属实，返修见 §7**：我删掉按键之间的等待之后，两个背靠背的 `send-keys` 会落进同一次
   stdin 读、被 Ink 当成一次粘贴，控制键被吞 —— 这个洞只在 PATH 里**没有** tmux shim 时暴露（shim 每次
   调用多 ~16 ms）。改法是一个发送口：相邻两次发送之间至少留 200 ms（不是在等状态，见 §7），有等待夹在
   中间时一秒也不花。**验收环境换成不带 shim 的 PATH**：连跑两次全场景 `✓167 ✗0`（§7.3）。
4. 全场景墙钟：改前 `460s / ✓165 ✗2`，改后 `383s / ✓167 ✗0`（连跑三次见 §4.3）。改前那两条红与本任务无关，是预先存在的竞态，
   §5 给了我自己实测到的现象与能证到的边界；它在我这里变绿是因为等待的**判据**换了（等旗标带上的
   「待命 on」），不是因为放宽断言。
5. 私有性、轻量收口见 §4.4、§4.5。没有新增夹具、等待库、门禁段或时限预算；接线（进 smoke）仍是 P327。

## 1 · 为什么是 `pty-wait.sh`，以及夹具要为它补什么

`lib/bounded-spin.sh` 的契约是「受管的**后台自旋/看门进程**」：`bounded_spin <interval> <cap_s> <cap_bytes>
<log> [parent]`，它每轮写一行时间戳、按父进程与上限收工，没有「等一个谓词成立」的入口 —— 这里要的是
后者，所以不选它。

`lib/pty-wait.sh` 的契约正是「caller 提供当前画面（`pty_cap`），引擎等到**条件成立且帧静止**」，
耗尽时自带现场（等待名 / 轮数 / 耗时 / 缺什么 / pane 末行 / 超时后再捕获一次），并把判定交回调用者。
它对这套面板有一处现成的正确性：两次捕获只差标题带上的 `HH:MM:SS` 算同一帧 —— 控制台每秒只重画那一格
（`panel/src/main.tsx` 里那支写在 React 之外的时钟），别的内容不按秒变。

夹具给它三样东西：

- **`pty_cap` = 面板可见区的捕获**（`capture-pane -p`，不带 `-S` 回滚）。用可见区是为了不让上一轮留在
  回滚区里的旧文本把这一轮的等待提前放行 —— 这也是同一个夹具里 `vis_row` / `draft_rows` 的取法。
- **capture 末尾可选追加一行夹具状态**：`@@cursor x y @@` 与 `@@draft <转义正文> @@`。理由：引擎只能看
  帧文本，而「插入点」（终端光标）与 `state/draft.md` 是断言要读、却都不在帧文本里的两样状态。把它们作为
  capture 的一部分交给**同一个**引擎，仍是「条件 + 静止」，不是第二套等待逻辑；行尾的 ` @@` 是收尾符，
  `@@draft ad @@` 不会命中 `@@draft ad\nb @@` 这种前缀。（`pty-wait.sh` 唯一的缺口就是这个：没有通用的
  谓词入口。真要补，把这三行换成引擎的一个 `--predicate` 就够了，我没有新建第三个库。）
- **面板与假 PM 窗格的「起来了」**：面板等标题带上的 `teamsmith pulse`（并且帧静止之后才返回），
  假 TUI 等它把输入框画出来（`fixture TUI`）—— 原来那两处分别是「40 次手写轮询 + 0.4s」和「sleep 1」。

**耗尽不致命**：`wait_frame` 把引擎的判定原样返回（0 等到 / 1 耗尽），脚本继续往下走，紧随其后的断言
照旧执行。于是缺陷的样子是「没等到 X + 现场」紧接那条 ✗，而不是被一次提前放行掩盖出来的绿 —— 这是
「不许放宽断言」的落地方式：操作符、期望值、执行顺序都没换。

## 2 · 每一处现在等的是什么

四类，按断言的读法分：

| 断言读什么 | 等待 | 例 |
|---|---|---|
| 帧上的目标行 | `wait_frame "<标签>" '<目标行>'` | `keys m` 后等 `Enter 发送`（写信托盘画出）；`Escape` 后等 `!Enter 发送`（托盘收起） |
| 草稿文件 | `wait_draft "<标签>" '<逐字节期望>'` | `type_text 'Z'` 后等 `alphXa\nbeta`；`ctrl+-` 后等 `ad` |
| 插入点 | `wait_cursor "<标签>" <x> [y]` | `→` 后等 7（宽字形一步）；`↑` 后等 6（钳到较短行）；`keys m` 后等 12（插入点在第二行） |
| 回执 | `wait_frame ... '· queued'` | Enter 提交后等回执自己的尾部 `· queued` / `· delivered` / `· held` |

另外四条规则：

- **两个按键之间没有任何状态被读 → 那次等待直接删掉**。pty 本身是队列，按键顺序不变；
  改前的 `keys C-w; sleep 0.4; keys M-b; sleep 0.4; …` 现在是一串裸按键，只在最后一个动作之后等它的结果。
- **期望文本是前一次画面文本的前缀时，补一个反向针**：`ctrl+w ×2` 之后等 `> alpha` 会命中旧帧里的
  `> alpha beta gamma`，所以写成 `> alpha` + `!beta gamma`；emoji 退格那条同理写成 `│ > 中文` + `!🙂`。
- **尺寸**用整幅宽的 `─` 条判定：≥60 列的布局有 41 个连着的 `─`，40 列的布局一行装不下 41 个，
  于是 `resize_pane 40 30` 等 `!41×─`、`resize_pane 120 30` 等 `41×─`，再叠上引擎的帧静止。
- **回执不能等裸 `queued`**：草稿正文写着 `queued thought` 时，那一帧里早有 `queued` —— 第一次跑就是
  这么红的（§5）。回执一律等它自己的尾部 `· queued`（`receiptQueued` 的原文 `… · queued`）。

## 3 · 保留的 11 处固定等待（逐条理由）

| # | 位置 | 为什么没有状态可等 |
|---|---|---|
| 1 | `server_up` 的 `-c 'sleep 600'` bootstrap 占位 pane | 任务书点名允许的占位进程；它不起任何被测行为 |
| 2 | 假剪贴板工具 `hang) exec /bin/sleep 60` | 它本身就是被测对象（「工具挂死」），不是夹具在等什么 |
| 3 | 假编辑器脚本 `sleep "${TEAM_B2_EDITOR_HOLD:-2}"` | 模拟人在 `$EDITOR` 里停住；4s 就是「挂起期间不重绘」那段窗口的长度 |
| 4 | `B2 undo：历史空了再按 ctrl+-` 后 0.6s | 幂等空操作：帧与文件都不变，没有可等的状态 |
| 5 | `B4 挂死工具` 后 5s | 探测的结局是「什么都不发生」（无回执行、无文件、无忙行）；而这条要证明的正是「工具还挂着时面板照旧可输入」，Z 必须落在这段窗口里 |
| 6-7 | `B4 ⑦ 空闲 5s` ×2（写信关着/开着） | 「一段窗口里没起过剪贴板工具」是否定观察，可等的只有「窗口过去了」自己；两段 5s 就是被测长度 |
| 8 | `B3 挂起期间屏幕静止` 1.3s | 断言本身是「一窗口内画面没变」；「不会重绘」没有事件 |
| 9 | `B3 真 vi` 的 `Escape` 后 0.3s | vi 的 ESC 消歧超时（ESC 紧接 `:` 之前它得先真正离开插入模式），不是产品的状态 |
| 10 | `2.5` 的 6s | 等的是一个**纯粹的节流间隔**：慢桩每次读数据 `TEAM_B2_SLOW_SLEEP=4s`，6s 是它一轮加余量 |
| 11 | `2.7 error` 重试后 3s | 重试拿到的是同一条回执（compose 不关、文字不变），帧上没有新状态 |

## 4 · 证据

### 4.1 一条不少

```
$ names() { sed -n 's/^ALL="\(.*\)"$/\1/p' "$1"; sed -n 's/^    \([a-z]*\)) scenario_.*/\1/p' "$1"; }
$ diff <(names <(git show HEAD:skills/teamsmith/tests/panel-b2.sh)) <(names skills/teamsmith/tests/panel-b2.sh)
(no difference)

$ asrt() { grep -nE '(^|[^[:alnum:]_])(assert_eq|assert_has|assert_match|assert_not_has) |(^|; ) *(ok|bad|cond_skip) "' "$1" | sed -E 's/^[0-9]+://'; }
$ diff <(asrt <(git show HEAD:skills/teamsmith/tests/panel-b2.sh)) <(asrt skills/teamsmith/tests/panel-b2.sh)
(no difference)
$ wc -l  # 断言行条数
186 186
```

`git diff --stat` 只有 `skills/teamsmith/tests/panel-b2.sh` 一个文件（本报告另计入）。

第三份：夹具**对被测算面做了什么**（所有 `keys` / `type_text` 调用，去行尾注释后按多重集合比）也逐项相同——
所以改动只落在「每一步之后怎么等」：

```
$ acts() { grep -v 'send-keys' "$1" | grep -v '^[[:space:]]*#' \
    | grep -oE '(keys|type_text) [^;|&)]*' | sed -E 's/#.*$//; s/[[:space:]]+$//' | sort | uniq -c; }
$ diff <(acts head0.sh) <(acts skills/teamsmith/tests/panel-b2.sh)
(no difference)     # 两边都是 64 项、209 次调用（`send-keys` 与注释行不算调用点）
```

### 4.2 耗时对照（参考值，不作判据）

改前（HEAD 原样，私有磁盘 `TMPDIR=/var/tmp/p336/base-tmp`、私有 `TMUX_TMPDIR=/var/tmp/p336/tmux`）：

```
$ cd skills/teamsmith/tests && export TMPDIR=… TMUX_TMPDIR=…
$ bash panel-b2.sh --all
BASELINE rc=1 elapsed=460s
== 结果 ==  ✓ 165  ✗ 2
```

改后（同一个私有磁盘与同一个私有 socket 目录）：

```
$ bash panel-b2.sh --all
run1 rc=0 383s 没等到=0 == 结果 ==  ✓ 167  ✗ 0
```

改前 `✓ 165 ✗ 2` / `460s`，改后 `✓ 167 ✗ 0` / `383s`：同一台机器（两次跑时 load average 都在 12–14），
同一份私有磁盘与 socket 目录。**注意这两组数字都是 PATH 里带 tmux shim 时跑的**（shim 让每次 tmux 调用
多 ~16 ms），用来对照「固定等待」这一项的变化是够的，但它**不能**当作验收：不带 shim 的环境会暴露
§7 那个连发缺陷，所以最终验收用的全是 §7.3 那两次。
两条原来的红变成了绿（见 §5），断言集合一条没变（§4.1），所以不是少判了两条；墙钟少 77 秒（约 17%）。

结论（两条：一个是环境事实，一个是本次改动的账）：

- 这套夹具的墙钟主要不在 `sleep` 上：11 个场景各自要重启若干次面板，而**面板自己从 `new-session` 到画出
  第一帧要 ~7.5 秒**（实测：同一个空项目里连续捕获 26 次，前 14 次窗格是空的，第 15 次（约 7.5s）首帧出现，
  之后帧稳定）。全场景里 `start_panel` 被调用 25 次（另加 16 次 `start_pm`），面板启动这一项就是 190 秒上下。
- 本次切掉的是 186.1 秒固定等待；换上去的等待本身每次要一次稳定确认（0.25s 间隔的第二次捕获），
  所以净节省远小于 186 秒。**如实说：本机上全场景墙钟的改善是十几个百分点，不是量级**；真正的收益是
  每处等待现在等的是「那件事为真」，机器忙时不再靠猜——§5 那条竞态就是这个差别的直接证据。

### 4.3 连跑三次 + 交付前一次

```
$ for i in 1 2 3; do bash panel-b2.sh --all; done
run1 rc=0 383s 没等到=0 == 结果 ==  ✓ 167  ✗ 0
run2 rc=0 398s 没等到=0 == 结果 ==  ✓ 167  ✗ 0
run3 rc=0 398s 没等到=0 == 结果 ==  ✓ 167  ✗ 0
```

交付前又在**最终树**上（§5 那处注释修正之后）跑了第四次：

```
final rc=0 369s 没等到=0 == 结果 ==  ✓ 167  ✗ 0
```

交付字节因此等于被跑过的字节：`8f4fdcad`（换等待）+ `b4dfdc36`（只改那三行注释，断言与场景集合不变，
§4.1 的两条 diff 在最终树上重跑仍为空）。

这四次都是 rc=0、`✓ 167 ✗ 0`，**没有一次出现「没等到 …」**（`grep -c 没等到` = 0 ×4；环境是带 shim 的
PATH，那时 §7 的连发缺陷还没暴露 —— 真正的验收看 §7.3）：每一次等待都是在
条件成立的那一刻放行的，没有一次靠视界耗尽；也没有为了变绿去放大上界（`PTY_WAIT_ITERS` / `PTY_EXT_FACTOR`
一个字没动，仍是库里那份默认值）。任务书交办的「跑之前先 `ps` 确认没有别人的 `smoke.sh`」在**实验开始前**
做过（当时没有）；这四次的窗口（10:17–10:45 UTC）里，默认 server 上出现过别的 smoke 的 anchor 窗口，
我的夹具在私有 server 与私有磁盘上、不受它影响，但那会让墙钟数字偏大。

### 4.4 私有性

- 全程只用私有 tmux server：夹具里每一处 tmux 调用都带 `-L "$sock"`（`sock="p13b2-$$"`），
  `grep -n 'tmux ' skills/teamsmith/tests/panel-b2.sh | grep -v -- '-L "\$sock"'` 只剩 `tmux_iso_guard_soft`
  的收尾前置、socket 文件清理与 `command -v tmux` 三处。
- 私有 socket 目录：`TMUX_TMPDIR=/var/tmp/p336/tmux`（运行期间该目录下只有 `p13b2-<pid>`）。
- 私有磁盘：夹具根都在 `/var/tmp/p336/{base-tmp,after-tmp}` 下，`tmp_root_reap_all` 回收；结束时
  `ls -A /var/tmp/p336/after-tmp` 是空的（0 项），`/var/tmp/p336/tmux/tmux-<uid>/` 下私有 socket 也全清了
  （0 项）。我为了看现场用 `TEAM_B2_KEEP=1` 留下的六份探针根（`teamsmith-panel-b2-…`，逐个点名删的）
  也一并清掉；原始日志留在 `/var/tmp/p336/*.log`，报告里引用的都在。
- 调用者默认 server 的三次快照（实验开始前 / 中途 / 结束后各打一次）：

```
$ tmux list-windows -a -F '#{session_name}:#{window_index}:#{window_name}:#{pane_pid}' | sort > tmux-<when>.txt
$ grep -c p13b2 tmux-{before,mid,after}.txt
tmux-before.txt    windows=20  p13b2=0
tmux-mid.txt       windows=20  p13b2=0
tmux-after.txt     windows=19  p13b2=0
```

  这一栏在看的是「我的对象有没有漏到调用者的 server 上」：三份快照都是 0。期间 window 表的**内容**变过
  （别的项目的 pane pid 变了、本会话里几个席位的窗口换了 pane、还多了一个 `teamsmith-smoke-anchor-*`），
  那是同期其他席位和别人在跑的 smoke，不是我这一侧；窗口数 20→19 是别人家的窗口开了又关。

### 4.5 轻量收口

```
$ bash -n skills/teamsmith/tests/panel-b2.sh && echo OK
OK
$ git diff --check && echo clean
clean
$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: root=… scope=published files=… hits=0 names=ok user=resolved   (rc=0)
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
Totals: 21 passed, 0 failed (21 items)
```

`openspec` 不在本机 PATH 上（它只在 `~/.bun/bin/openspec`，登录 shell 也不加这个目录），所以验收行按上面的
`PATH=…` 前缀跑；不是跳过。

## 5 · 环境里本来就红的那两条（改前实测），以及我改到了什么边界

改前全场景跑出两条红，都在 `scenario_actions`：

```
✗ 3.1 再按 s 回执显示待命 off（…\/actions/standby-off.txt 里找不到 [待命 off]）
✗ 3.1 CLI 报告 standby off（…\/actions/status-off.txt 里找不到 [standby: off]）
```

我自己看到的现场（`TEAM_B2_KEEP=1` 单跑 `actions`，保留的捕获）：

- 第二次按 `s` 之后，帧上的不是「待命 off」，而是**待命原因输入行又开着**（`╭─ 待命原因 ─…` / `│ >`）；
  同一时刻 `team standby status` 仍是 `standby: on（…原因：lunch）`。
- 也就是说 `s` 走的是「开关判定读到 off → 打开理由行」这一支：判据是面板帧里的 `panel.standby.on`
  （`panel/src/App.tsx` 的 `runAction` 读 `dataRef.current.panel.standby.on`）。
- 把那段固定等待从 3s 加到 12s、20s 各跑一次，**仍然红**（原始输出 `/var/tmp/p336/actions-probe20.log`）；
  而改成「等标题带里写着 `· 待命 on` 之后再按第二下」就绿了。
- 产品侧不是没刷新：`setStandby` 提交之后确实调了 `refreshNow()`（`panel/src/main.tsx` 的 `setStandby`，
  `refreshNow` 在 `res.ok` 之后无条件执行），所以这一格不是「动作之后忘了失效缓存」。那一帧的读数走
  `team __panel-data` 子进程（`frame` 块 `timeoutMs: 10000`），保留的 `standby-on.txt` 里同时出现
  「✓ 待命 on」回执与标题带 `· 待命 off` —— 提交成立、帧还没带上。机器 load 12–14 时子进程排队/超时会
  把这个旧值留很久（这也是 20s 仍红的最可能解释）；我没有继续查到确凿的那一步（不在我的写集）。
- 因此夹具侧的正确判据就是「标题带写着 `· 待命 on`」，而不是任何固定秒数；产品侧「回执成立而帧长期不跟上」
  值得另立一条任务（要的话拿 `standby-on.txt` 当反例），但本任务没有它的写集。

改法（仍在夹具里，没有放宽任何断言）：

```bash
  # s 的开关判定读面板缓存里的 standby.on（产品侧 setStandby 不主动 invalidate，下一轮节奏才带上）：
  # 固定 3s 正好撞在 3s 刷新节奏的边界上，时红时绿。等旗标带里真的写着 on 再按第二下。
  wait_frame "3.1 面板缓存看到待命 on" '· 待命 on'
  keys s; wait_frame "3.1 待命 off 的回执" '待命 off'
```

两次跑出红的原始日志：`/var/tmp/p336/before.log`（全场景，改前）、`/var/tmp/p336/scn-actions.log`（改前单跑）。
翻转证据因此是「同一台机器、同一条断言：改前红（20s 固定等待也红）/ 改后绿（等旗标带）」。

## 6 · 没验到的 / 边界

- `pty-wait.sh` 只能看帧文本。插入点与草稿文件是我把夹具状态附在 capture 末尾才等到的（§1）；如果
  以后给引擎加一个通用谓词入口，那三行可以撤掉，等待语义不变。
- 有两处等待等的其实是「状态**没变**」（`B4 无工具`、`B4 只读`：探测的唯一结局是「什么都没发生」）。
  它们不再是盲等，但仍不是「等到一件新事」——引擎的稳定确认只保证这两次捕获一致，不保证探测已经结束。
  真正证明探测结束的是紧跟其后、由产品行为决定的断言（草稿逐字节不变、没有临时文件、没有 team 动作）。
- 保留了 11 处固定等待（§3）。其中 5、6-7、8 三段属「窗口里什么都没发生」的否定观察，本来就没有事件可等；
  它们的时长就是被测对象的时长，不该被「状态等待」吃掉。
- 时序数字只作参考，而且这台机器实验期间 load average 12–14、另一个席位在同项目里跑 smoke（默认 server 上
  的 `teamsmith-smoke-anchor-*` 窗口），面板启动时间因此偏大。想复现 §4.2 的数字，值得在空闲机器上再跑一次。
- 没有动 `smoke.sh` / `section-paths.tsv` / 产品实现 / 任何时限与预算；这个夹具仍然不在任何门禁段里，
  接线是 P327。

## 7 · 返修（V75 FAIL 后）：连发的按键必须落进两次 stdin 读

### 7.1 缺陷属实，我自己复现了

V75 在**不带 tmux shim 的 PATH** 里跑我的候选：两次全场景 `✓163 ✗4`，四条全在 `scenario_keys`，形状是
「按键没生效」。我在自己的树上也复现了（先 `scenario_keys` 两遍）：

```
$ NOPATH="$(echo "$PATH" | tr ':' '\n' | grep -v 'teamsmith/scripts/shim' | paste -sd:)"
$ PATH="$NOPATH" command -v tmux
/usr/bin/tmux
$ PATH="$NOPATH" bash panel-b2.sh keys     # 两遍
run1 rc=1 == 结果 ==  ✓ 20  ✗ 3 没等到=3
run2 rc=1 == 结果 ==  ✓ 19  ✗ 4 没等到=4
```

红的都是这一段形状的序列：

```
没等到 B2 ctrl+k 删整逻辑行：… 缺 [@@draft \nsecond @@]
✗ B2 ctrl+k 删的是逻辑行（整行 45 字符），不是绘制行
没等到 B2 ring：alt+y 换回旧的：… 缺 [@@draft  gamma @@]
✗ B2 ring 累积：alt+y 换回合并的一条（空格+beta+空格+gamma）（期望 [ beta gamma]，实际 [alpha]）
```

机制与 V75 写的一致：Ink 的 `useInput` 对每个 stdin 数据块只解析一次，多字符块整串按「粘贴」交给调用方；
两个背靠背的 `send-keys` 挨得太近就合成一次输入，`C-w`/`M-b`/`C-k`/`M-y` 这些控制键就没了。带 shim 时每次
`tmux` 调用多 ~16 ms，正好把它们分开 —— 所以那四轮 `✓167 ✗0` 是**环境依赖的绿**，不能算数。

### 7.2 改法：一个发送口，相邻两次发送之间留 200 ms

`keys()` 与 `type_text()` 合并到 `_b2_send()`：

```bash
B2_KEY_GAP_US=200000
_b2_send() { # <send-keys argv…>
  local now us rem
  now="${EPOCHREALTIME//[!0-9]/}"
  if [ -n "${_b2_last_send:-}" ]; then
    us=$(( now - _b2_last_send ))
    rem=$(( B2_KEY_GAP_US - us ))
    if [ "$rem" -gt 0 ]; then
      sleep "$((rem / 1000000)).$(printf '%06d' $((rem % 1000000)))"
    fi
  fi
  tmux -L "$sock" send-keys -t "$sess:panel" "$@" 2>/dev/null
  _b2_last_send="${EPOCHREALTIME//[!0-9]/}"
}
keys() { _b2_send "$@"; }
type_text() { _b2_send -l "$1"; }
```

三点属性，都是为了守住任务书的划线：

- **它不是状态等待**，代码注释里写明了理由：这些键的效果大多要一串按完才可见（`C-a` 本来就在行首、
  `C-d` 在行尾、`C-b` 到行首后再按也看不出变化），挨个等状态等不到；而全场景有 45 段连发、93 处相邻发送，
  每处再写一遍同样的「等不到」只会重复 93 次。
- **只在真的挨得近时才花时间**：上一次发送已经过去 ≥200 ms（中间有 `wait_*`、`cap_to`、断言）就一秒也不睡。
  量级上是全场景多几秒，不是秒级的掩盖（任务书禁止的是把暂停设到秒级）。
- **不碰断言、不删场景**：§4.1 的三份 diff 在返修后重跑仍为空（场景名、186 行断言行、209 次调用点）。

能改成状态等待的那几处（例如 `type_text 'raw1'` 之后）本来就在序列末尾由断言的等待覆盖，中间再加一次是
同一件事做两遍；真正危险的是中途那些**看不出效果**的键，它们只能靠这个最短间隔分开。

### 7.3 验收：不带 shim 的 PATH 上连跑两次全场景

```
$ NOPATH="$(echo "$PATH" | tr ':' '\n' | grep -v 'teamsmith/scripts/shim' | paste -sd:)"
$ PATH="$NOPATH" command -v tmux
/usr/bin/tmux
$ for i in 1 2; do PATH="$NOPATH" bash panel-b2.sh --all; done
noshim-run1 rc=0 414s 没等到=0 | == 结果 ==  ✓ 167  ✗ 0
noshim-run2 rc=0 406s 没等到=0 | == 结果 ==  ✓ 167  ✗ 0
```

两次都全绿、都 rc=0、**没有一次「没等到 …」**。返修前同一个环境是 `✓163 ✗4`（V75）与 `✓20 ✗3 / ✓19 ✗4`
（我在 `scenario_keys` 上复现的两遍），返修后同一个场景在同一个环境里 `✓23 ✗0` 两遍，全场景两遍 `✓167 ✗0`。

### 7.4 返修没有动到的部分

- V75 已确认成立的四项原样保留：209 处状态等待、186 行断言未变、11 个场景、剩余 11 处固定等待的理由。
- 没有碰 `smoke.sh` / `section-paths.tsv` / 产品实现；没有加大 `PTY_WAIT_ITERS` / `PTY_EXT_FACTOR`；
  没有新增库或夹具。接线仍是 P327。
