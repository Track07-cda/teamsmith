# M12 · 修 smoke 的 PM 适配器段抖动（V9-E1）

agent: dev   状态: 完成（含 PM 复验追加的 26-c；待 PM 再复验）   时间: 2026-09-16 15:09–17:15
branch: `task/M12-smoke-pm-v9-e1`（基于 `ce40437`；修 + 探针包 + 报告，见 `git log ce40437..HEAD`）
PR/MR: -（`TEAM_VCS=local`：不 push，分支留在本地 worktree，PM 复验后本地合并）

## 一句话结论

6i 段的抖动**不是产品竞态**，而是测试用「固定 sleep / 立刻采样」去同步**异步夹具**：`team up` 的承诺只是
「PM 进程起来了」（proof=spawn/argv），**不是**「CLI 已经写出第 N 行」——夹具落盘晚于 `up` 返回是合法时序。
同一条注入（夹具推迟 2s 第一次落盘）下：旧测试确定性红 3 个面 / 6 条断言（判得出「哪条、什么时序」），
新测试 `--measure 24` 全绿；产品代码零改动（diff 只在 `tests/`）。
**追加（PM 复验抓到的 26-c）**：同一族病 —— 断言 diff 两次**实时执行**，而容量行读 `/proc/meminfo`、`/proc/swaps`，
数值天然在动。已钉容量夹具 + 把失败信息里的 ESC 与内容 diff 分开报，见 §7。

## 交付物

| 路径 | 内容 |
|---|---|
| `skills/teamsmith/tests/smoke.sh` | ① 6i 段的夹具同步改成**有界轮询实际条件**（M9.7 纪律）：新增 `pm_wait` / `pm_grew` / `pm_dead` / `pm_file` / `pm_ran_manual` / `pm_wait_delta` / `pm_pane_has` / `pm_scene`；改写 `pm_close_windows` / `pm_wait_seen` / `pm_wait_ready`；6 个采样点前加等待。② 追加：26-c 的两次实时执行对比钉容量夹具（`p10cap`/`p10c`），失败信息把 ESC 与内容 diff 分开报（内容那条带首个差异）。**断言零增减**（该段 549 条、全量 1735 条，与修复前一致） |
| `skills/teamsmith/tests/flip-m12.sh` | 新增探针包：把 6i 的「负载抖动」定形成确定性红/绿（`--probe <面>` 单面诊断 / `--measure N` 连跑报失败率 / 默认对 BASE 与当前树做翻转） |
| `skills/teamsmith/tests/flip-m12-26c.sh` | 新增探针包（追加）：26-c 的同样手法——默认翻转（放大注入下旧红/新绿）、`--measure N`、`--probe base|current` |
| `docs/team/reports/M12-dev.md` | 本报告 |

未改动：产品代码（`scripts/**`、`extension/**`、`references/**`、`SKILL.md`、模板）、6i 之外的任何段落、
任务书与账本、版本号/CHANGELOG（发版归 PM）。

## 任务书要求逐条对照

| # | 要求 | 落地 | 证据 |
|---|---|---|---|
| 1 | 先量出来：该段 ≥20 次连跑 + 失败率 + 失败形态 | 旧测试自然条件 **0/42 红**（空载 24 + load≈20 的 6 + 6 路并发 12）——这台机器自然复现不出来；改用注入把机制定形：3 个面 6 条断言确定性红，逐条见 §1.3 | §1.1、§1.3 |
| 2 | 固定 sleep → 有界轮询（最长 ~5s）；真竞态就修实现；夹具全部回收 | §3：deadline 5s/30s 的有界轮询、超时照旧报红 + 现场；根因在测试的同步方式（产品按 proof=spawn/argv 的契约返回，行为正确，见 §1.2）；本任务全部探针跑完新增 session / 进程 / tmp 目录均为 0（§5） | §3、§5 |
| 3 | 修复后 ≥20 次全绿 + 破坏一次证明断言会红（翻转证据） | 修复后 24/24 全绿；`flip-m12.sh` 三个注入面（同一注入、同一产品代码）：旧测试 ✗3 / ✗1 / ✗2，新测试 549/0 | §2 |
| 追加 1 | 26-c：钉 `TEAM_MEMINFO_FILE`（+ `TEAM_SWAPFILE_PATH`，见 §7.2） | `p10cap` 夹具环境 + `p10c` 包装；26-c 四次真跑全部带上 | §7.2 |
| 追加 2 | 失败信息把「ESC 不符」与「内容 diff 不符」分开报 | 四个分支分开；内容不符那条附首个差异（实测输出见 §7.2） | §7.2 |
| 追加 3 | 证据：钉住后 ≥10 连跑全绿 + 放开钩子变回抖 | 修复后自然 12/12；未修自然 2/16（含 PM 那条逐字一致）；放大注入下未修 3/3 红、修复后 3/3 绿 | §7.3 |

## 1 · 量出来

### 1.1 自然复现（未修改的旧测试；努力过，但没中）

| 条件 | 次数 | 红 | 日志 |
|---|---|---|---|
| 空载（load ≈6） | 24 | **0** | `/tmp/m12/summary.txt`（每轮 `✓549 ✗0`，47s/轮） |
| 16 个 CPU spinner（load ≈20） | 6 | **0** | `/tmp/m12/load-compare.log` |
| 6 路并发同跑（M9.7 的自然复现手法） | 12 | **0** | `/tmp/m12/hunt-before.log` |

诚实结论：**这台机器上自然条件没能复现**（0/42）。V9 记录的 1/3 是门禁期（多个 agent + 多个探针同时在跑）
的产物；要自然复现得靠运气或更极端的时序。所以按 M9.7 的做法（dev2 的自然复现也是并行猎取、16 次里中
1 次），用**注入**把机制定形——它不依赖负载，红/绿是确定的。

测量夹具的保真说明：探针把 `smoke.sh` 的 **0..6i 段**原样截出来（6i 的段前现场、夹具、真窗口一条不少；
6j 之后与 6i 无交集），`SKILL_DIR` 指向当前树；这一段与全量 smoke 的字节级行为一致。夹具实现见
`skills/teamsmith/tests/flip-m12.sh`。另外全量 smoke 本身也在 §4 真跑了 1 次（1735/0）。

### 1.2 机制：`up` 返回 ≠ 夹具已落盘

产品侧（M6.3 F30 / M8.1 的证据链，行为正确，本任务没改）：

1. `team_pm_start` respawn 后**等到有证据**才把 pid 写盘：① 窗口前台进程就是配置的 PM CLI（argv 证据），
   或 ② 窗口 harness 在 `exec` **之前**写下的 `state/pm.pid.spawn` 里的 pid 活着且 cwd 在本项目（spawn 证据）。
2. 非 Pi 路径的 ② 写在 exec 之前，所以 `up` 完全可能在 CLI 执行第一条命令之前就打印
   「PM 已启动（proof=spawn）」并返回 —— 这是契约（wrapper PM 就靠它），不是 bug。
3. 旧测试在那之后**立刻**读夹具产物（`wc -l PM_LOG`、切 PM_LOG 增量、`[ -s pm-bare.log ]`、
   `sleep 0.6` 后抓一次尾屏）。夹具（bash 脚本）从 exec 到第一次 write 有几十 ms 的窗口；负载下变宽 → 假红。

`9df4df6`（V9-E1 的第一次修）只覆盖了 `$PM_LOG` 链（digest → board ls → dispatch --print → READY）：
`pm_wait_seen` 当时只等「PM_SEEN 非空」，随后立刻断言 PM_LOG 里的三行；同一类问题的其余几个面没被覆盖。

### 1.3 失败形态（注入定形；确定性，不靠负载）

注入 `= 2s`（夹具第一次落盘前推迟 2s；产品代码不变）：

| 面 | 注入点 | 旧的哪条断言红 | 时序 |
|---|---|---|---|
| `pm` | `fake-pm.sh` 第一行 write 之前 | `这一轮确实是新的 PM 进程（argv 日志增长）`（期望 grew，实际 same）<br>`resume 参数真的进了这一轮的 argv`（delta 里找不到 `arg1=--continue`）<br>`这一轮真的拉起了新的 PM 进程`（argv 日志增长） | `up` 拿到 spawn 证据即返回 → 旧测试立刻 `wc -l pm-adapter-args.log` / 切增量；新 PM 的 bash 还在启动 |
| `bare` | `pm-bare` CLI 第一行 write 之前 | `裸名字的 CLI 真的在窗口里跑起来了`（`pm-bare.log` 空） | 同上，`respawn` 后立刻 `[ -s pm-bare.log ]` |
| `pane` | 5b 的窗口标记 `printf` 之前 | `重抹窗口输出保留最上面的报错行`（尾屏 `[]` 里找不到 `PANE-MARKER-1`）<br>`空行之后的内容也还在`（找不到 `PANE-MARKER-2`） | `respawn-pane` 后固定 `sleep 0.6` 抓**一次**：pty → tmux 屏幕还没画出来 |
| `manual` | 4b 的人工 respawn `exec` 之前 | **0 条**（不暴露） | 身份判定先命中 wrapper 的 argv（`bash -c 'sleep 2; … fake-pm.sh --manual'` 的命令行里就有 CLI 名字），旧断言在 CLI 起来之前就被满足；这一条改成「等 CLI 真的落盘」属于加固，不算翻转证据 |

红侧小结（注入 2s）：`✓546 ✗3`（pm）、`✓548 ✗1`（bare）、`✓547 ✗2`（pane）；更早一轮逐面矩阵跑法
（`/tmp/m12/pre-inj-*.log`）给出逐字一样的红。

### 1.4 补充：V9-E1 的**本形**也钉了一遍（PM_SEEN 早、digest 链晚）

V9 记录的那三条红是「PM_SEEN 已写、`team board ls` 那条链还没跑完」。把它也做成注入
（`PM_SEEN` 之后、链之前 sleep 2s），对两棵树各跑一次：

```
$ bash /tmp/m12/run-chain.sh
pre-9df4df6: rc=1 == 结果 ==  ✓ 517  ✗ 6
      ✗ 它拿到提示词后第一件事是 team digest（…找不到 [--- fake-pm: team digest ---]）
      ✗ 它也能用 team board ls（…找不到 [--- fake-pm: team board ls ---]）
      ✗ 它也能用 team dispatch --print（…找不到 [--- fake-pm: team dispatch --print ---]）
      ✗ 它跑完了整段（不是半死在那里）（…找不到 [PM_FAKE_READY]）
      （另两条 ✗ 与 V9-E1 无关：旧 smoke 的 1b/6f 断言在今天的树上本就过时——这条实验的红侧
        只用来钉 PM_LOG 链那 4 条）
current: rc=0 == 结果 ==  ✓ 549  ✗ 0
```

即：V9-E1 本形在 `9df4df6` 之后已经关掉；本次 M12 关的是**同一类的其余采样点**。

## 2 · 翻转证据（red → green）

器械（本任务新增，已提交）：`bash skills/teamsmith/tests/flip-m12.sh`
`BASE` = `merge-base HEAD main` = `ce40437c87d0a28b36f8ea1493a616acd64d7964`（修复前的 smoke）。
两边跑的都是**当前树的产品代码**（脚本自检查 `BASE..HEAD` 间 `skills/teamsmith` 除 `tests/` 外无改动，
否则拒绝运行），所以翻转的变量只有「测试怎么同步」。

```
$ bash skills/teamsmith/tests/flip-m12.sh
M12 翻转：同一注入（夹具推迟 2s 落盘）下，旧测试必须红、新测试必须绿
  BASE  smoke=/tmp/teamsmith-flip-m12.*/smoke-base.sh（ce40437c87d0a28b36f8ea1493a616acd64d7964）
  当前  smoke=…/.worktrees/dev/skills/teamsmith/tests/smoke.sh
  probe=pm bare pane

== 注入面 pm ==
  旧测试（BASE）：rc=1 == 结果 ==  ✓ 546  ✗ 3
        ✗ 这一轮确实是新的 PM 进程（argv 日志增长）（期望 [grew]，实际 [same]）
        ✗ resume 参数真的进了这一轮的 argv（…/pm-adapter-delta3.log 中找不到 [arg1=--continue]）
        ✗ 这一轮真的拉起了新的 PM 进程（期望 [grew]，实际 [same]）
  新测试（当前）：rc=0 == 结果 ==  ✓ 549  ✗ 0

== 注入面 bare ==
  旧测试（BASE）：rc=1 == 结果 ==  ✓ 548  ✗ 1
        ✗ 裸名字的 CLI 没跑起来（…/pm-bare.log 空）
  新测试（当前）：rc=0 == 结果 ==  ✓ 549  ✗ 0

== 注入面 pane ==
  旧测试（BASE）：rc=1 == 结果 ==  ✓ 547  ✗ 2
        ✗ 重抹窗口输出保留最上面的报错行（不再被空行挤掉）（[] 里找不到 [PANE-MARKER-1]）
        ✗ 空行之后的内容也还在（[] 里找不到 [PANE-MARKER-2]）
  新测试（当前）：rc=0 == 结果 ==  ✓ 549  ✗ 0

翻转成立：旧测试红、新测试绿（注入面 pm bare pane）
```

### 2.1 修复后连跑 ≥20 次（同一探针，不加注入）

```
$ bash skills/teamsmith/tests/flip-m12.sh --measure 24
M12 测量：当前树 6i 段（截断探针、不加注入）连跑 24 次
  run 1   绿  == 结果 ==  ✓ 549  ✗ 0
  …
  run 24  绿  == 结果 ==  ✓ 549  ✗ 0
失败率：0/24
```

同一条件的 6 路并发复测（`/tmp/m12/hunt-after.log`）：**0/12**。作为对照，旧测试在同样并发下也是
0/12（见 §1.1）——自然条件下两边都不红，修复的收益是「把潜在抖动换成有界等待」，不是「命中率数字下降」；
证明这一点的是 §1.3/§2 的注入翻转。

## 3 · 修法（有界轮询实际条件；M9.7 纪律）

| 采样点（旧写法） | 新写法 | deadline | 为什么这是对的 |
|---|---|---|---|
| `pm_close_windows`：`kill-window` + `sleep 0.3` | kill 后 `pm_wait 5 pm_dead`（`team_pm_pid_live` 不再成立） | 5s | 旧 PM 没死透时 `up` 会判 `running` → 不启动新 PM，随后所有断言连锁红 |
| 2) 崩溃重启：立刻 `pm_lines > LINES1` | `pm_wait 5 pm_grew "$LINES1"` | 5s | 等的是「夹具真的又跑了一轮」这个事实 |
| 2b) resume 对照：立刻切 delta 断言 `arg1=--continue` | `pm_wait_delta 5 "$LINES2" '^arg1=--continue$'` | 5s | 等新增行里出现那个参数 |
| 3) watchdog：立刻 `pm_lines > LINES3` | `pm_wait 5 pm_grew "$LINES3"` | 5s | 同上 |
| 4b) 人工 respawn：`sleep 1` | `pm_wait 5 pm_ran_manual`（CLI 真的写下 `arg1=--manual`） | 5s | 加固：旧断言只需 wrapper 的命令行 |
| 5) 裸名字：立刻 `[ -s pm-bare.log ]` | `pm_wait 5 pm_file "$TMP/pm-bare.log"` | 5s | 等 CLI 落盘 |
| 5b) 尾屏：`sleep 0.6` + 抓一次 | `pm_wait 5 pm_pane_has "PANE-MARKER-2"` | 5s | pty → 屏幕是异步的 |
| `pm_wait_seen`：只等文件非空 | `pm_wait 30 grep -q '^first_line='`（**完整记录**） | 30s | 夹具逐字段追加，非空 ≠ 完整 |
| `pm_wait_ready`：手写 60×0.5s | 同一个 `pm_wait`（0.1s 粒度） | 30s | 统一实现 |

超时语义：等待**不是**把红等成绿——超时后照旧执行原断言（红并打印期望/实际），并在前面打一行
`现场（…）`（`pm_scene`：argv 日志行数 + 尾两行）。所以持续回归只是晚 ≤5s 红，而且红得有证据。

## 4 · 门禁（每个交付 tip 都真跑过：`ca2c95c`、含报告的 tip、26-c 修复后的 tip、最后的探针文件 tip —— 四次结果逐字一致）

```sh
$ openspec validate --all --strict          # 用绝对路径 <home>/.bun/bin/openspec（本 shell 的 PATH 里没有它）
Totals: 12 passed, 0 failed (12 items)

$ bash skills/teamsmith/tests/smoke.sh      # 4m35s
== 结果 ==  ✓ 1735  ✗ 0
smoke 全绿

$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh   # 1m49s
== 结果 ==  ✓ 1334  ✗ 0
FAST 模式：跳过 18 个真进程段落（…|6i·非 Pi PM 端到端|…）
smoke 全绿
```

（FAST 模式本来就跳过 6i 的真窗口段，所以 6i 改动由全量门禁覆盖；§2 的探针又单独把它跑了 24+12+6 次。
26-c 的追加修复后再跑了一遍全量 + FAST，仍是 `✓1735 ✗0` / `✓1334 ✗0`。）

## 5 · 夹具回收 / 隔离

- 探针沿用 smoke 自己的 `cleanup` trap：EXIT 时 `kill-session` 掉自己的 `teamsmith-smoke-<pid>`，非 `--keep`
  就删临时目录。本任务的全部运行（6i 段约 90 次 + 26-c 段约 60 次 + 全量 smoke 3 次 + FAST 2 次）跑完后检查：
  - `tmux ls` 里**没有**新增 `teamsmith-smoke-*`（只剩三条本任务之前就存在的旧 session，见下）；
  - 没有新增 `fake-pm.sh` / `pm-bare` / `fake-tui.py` 进程（fake-tui 无一条启动于本任务窗口）；
  - 没有新增 `/tmp/teamsmith-smoke.*` 目录（现存 12 个的 mtime 都在 11:00 之前）。
- **我观察到的既有残留（不是本任务造成的，我没动它们，报给 PM 决定）**：
  - 3 个孤儿 session：`teamsmith-smoke-2702769`（08:12）、`teamsmith-smoke-43280`（08:53）、
    `teamsmith-smoke-2193632`（09:45）——owner pid 都已死，里面只剩闲置 `zsh`；
  - 8 个 `fake-tui.py`（12b-h 段的夹具，最早 Sep 15 15:18，最新今天 05:55；其中 `253358`/`328915`
    正是 P6 返工 3 记过的那两个）与 12 个 `/tmp/teamsmith-smoke.*` 目录。
  没动的原因：它们不在 6i 段内，且我无法证明没有别的 agent 的探针还在用（P6 的教训是「自己的夹具自己收」）。

## 6 · 风险 / 明确没做的 / 给 PM 的复核建议

- **自然复现率为 0**（0/42）：所以「抖动被修掉」的证据是**机制 + 注入翻转**，不是自然命中率。自然跑的原始
  日志在本任务期间放在 `/tmp/m12/`（临时目录，不随交付提交）；可复现的是提交里的探针包：
  `flip-m12.sh --measure N`（当前树）与 `flip-m12.sh`（注入翻转）。
- **`TEAM_PM_START_WAIT=2`（6i ⑥ 的失败启动夹具）没动**：那是一个 2s 的固定**预算**（不是 sleep）——负载再高时
  harness 可能赶不上，诊断里会缺 `exit : 7`。本任务的全部运行里 0 次发生；改大它要拖慢门禁 4s，
  收益不明显，所以留着并在此记录。若 PM 认为该修，一句话我改。
- **没改产品代码**：如果要求「`up` 必须等 CLI 真的执行了第一条命令才报已启动」，那是产品语义变更
  （proof=spawn 的契约），需要单独提案，不在本任务边界内。
- **4b 的 `manual` 面只加固、不算翻转证据**（旧断言先被 wrapper 的 argv 满足，注入红不了它）——见 §1.3 表。
- **复核建议**：`team review M12 --strong` 跑门禁；另外 `bash skills/teamsmith/tests/flip-m12.sh`
  （约 6 分钟，含 6 次真窗口探针）可复现翻转；`TEAM_FLIP_INJ=3 bash …/flip-m12.sh --probe pm`
  （注入 3s 仍在 5s deadline 内，实测 ✓549 ✗0）可以看 deadline 的余量。
  26-c 追加的证据在 §7（含自然复现与放大注入两组），复核时直接看那一节的表即可。

## 7 · 追加：26-c 的容量行自抖（PM 复验抓到）

### 7.1 现场（可复现，且报错误导来源确认）

26-c 的两条断言把两次**实时执行**逐字对比（`--print` vs 重定向 `--once`；`--print` vs `UI=text --once`），
而容量数据源默认是 `/proc/meminfo` 与 `/proc/swaps`——数值每秒都在动（本机实测 MemAvailable ±100MB/s），
面板容量行的 `可再加 N 个` = `(avail + disk_free − 512) / 6144`（`team_agent_capacity`），在边界附近
两次采样就能差 1；`swap` 列（`team_swap_breakdown` 的 disk_free）同样实时。

自然复现（未修改的 26-c；聚焦探针 = smoke 前导 + 26 段到 26-c，单跑 ~4.3s）：

```
  pre  run 2   红  == 结果 ==  ✓ 17  ✗ 1
        ✗ 26-c 纯文本：重定向的 --once 与 --print 不一致（ESC=0）
  pre2 run 7   红  == 结果 ==  ✓ 17  ✗ 1
        ✗ 26-c 纯文本：TEAM_MONITOR_UI=text 没有走纯文本路径（ESC=0）      ← 与 PM 复验那条逐字一致
```

即自然 2/16；第二条正是 PM 报的形态。**误导点就在这里**：旧 `else` 把「ESC 不符」与「内容 diff 不符」
合成一条，文案固定说「没有走纯文本路径（ESC=…）」，而括号里明明是 `ESC=0`。

### 7.2 修（两件，都在 26-c 内）

1. **钉容量数据源**：`p10cap=(TEAM_MEMINFO_FILE="$TMP/meminfo-plenty" TEAM_SWAPFILE_PATH="$TMP/swaps")`
   + `p10c()` 包装，26-c 的四次真跑全部改走 `p10c`。
   **为什么两个都要钉**：面板容量行的 `swap` 列与 `可再加 N` 走的是 `team_swap_breakdown()`（读
   `/proc/swaps`），`TEAM_MEMINFO_FILE` 只被 `team_mem_stats()` 读——只钉 meminfo 挡不住 swap 列那半条。
   （`ram_avail_mb` 本来就被 `capacity.log` 木偶覆盖，不受影响；26-f 的 `== 4040` 也不变。）
2. **失败信息分开报 + 带差异**：ESC 一条、内容 diff 一条，内容那条附首个差异（时间戳先归一）。
   故意注入差异/ESC 后实测：

```
✗ 26-c 纯文本：TEAM_MONITOR_UI=text 渲染出了 ESC 控制字节（ESC=2）：没走纯文本路径
✗ 26-c 纯文本：TEAM_MONITOR_UI=text 与 --print 内容不一致（ESC=0，时间戳已归一）：19a20 > INJECTED-DIFF-LINE
```

（第二行是往里追加一行后的真实输出；“没走纯文本路径” 只在真有 ESC 时才说。）

### 7.3 证据（要求：钉住后 ≥10 连跑全绿 + 放开钩子变回抖）

| 条件 | 次数 | 红 | 备注 |
|---|---|---|---|
| 未修（`e936923` 的 26-c）、自然 | 16 | **2** | 含 PM 复验那条逐字一致 |
| 未修 + 放大注入 `TEAM_AGENT_MEM_MB=1` | 3 | **3** | 两条 diff 断言都红（确定性） |
| 修复后 + 同一放大注入 | 3 | **0** | 同一注入下红→绿 |
| 修复后、自然 | 12 | **0** | 满足 ≥10 |

放大注入只把「每秒 ±MB 的漂移」放大成「`可再加` 必差 1」（分母从 6144MB 变 1MB），不碰被测对象；
产品代码零改动。夹具已提交：`bash skills/teamsmith/tests/flip-m12-26c.sh`（默认翻转；`--measure N` 连跑当前树；
`--probe base|current` 单面诊断）。它把 smoke 前导 + 26 段到 26-c 截出来单跑（~4.3s/次，所以 10+ 次也很便宜）。
上面这四组数字都能用它复现。
