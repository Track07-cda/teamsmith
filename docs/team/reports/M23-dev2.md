# M23 · smoke 并发互相卡死：夹具改私有 tmux socket + 全量门禁互斥

agent: dev2   status: DELIVERED   time: 2026-09-17T18:10:00Z
branch: `task/M23-smoke-tmux-socket`   PR/MR: -（本仓库 local 模式，分支留本地，PM 复验后本地合并）

## Context（任务书给的现场 + 我实测到的）

任务书记录：2026-09-17 `team review` 的两轮门禁（M21 09:05、V16 10:33）与另一套 smoke 并发时，
**都在 6i 段同一断言后卡到 1800s 硬超时**（TERM 被忽略、KILL 才杀掉）；同一棵树无人并发时 ~110s 飞过。
对照组：V15/V16 的对抗探针包用私有 tmux socket 从来不互相干扰。

我这一轮实测到的四件事（各节给数据）：

1. **共享 tmux 命名空间是可重放的确定性事实**（`docs/team/reports/M23-dev2/pkg/namespace-demo.sh`）：不隔离时，另一套 run 能
   `list-sessions` 看见本套的夹具 session、一行 `kill-session` 删掉它、`wait-for -S` 能放开本套
   「永远等下去」的占位 pane（channel 名是 server 全局的）。
2. **两套全量 smoke 并发实测**（`docs/team/reports/M23-dev2/pkg/concurrent-probe.sh`，默认 server，75s 无输出=卡住判定）：
   两套都在 ~265s 内跑完、**0 次卡住**，但**各多出 1–2 条红**（三条不同的计时敏感断言）——
   「并发会互相影响」是真的，但今天没能复现 1800s 那种卡死。
3. **唯一被我抓到的真实卡死现场（10:33 V16 复验期间）**：smoke → `bash -lc 'command -v pm-bare || echo MISSING'`
   （smoke.sh 的夹具）→ `host-spawn`，**28 分钟 0% CPU**，最后被自己的 `timeout 1800` 杀掉。
   这是**登录 shell** 路径（distrobox 的 `/etc/profile.d/distrobox_profile.sh` 在每个 `bash -lc` 里为
   DISPLAY/WAYLAND_DISPLAY/XAUTHORITY 调 `host-spawn`），不是 tmux 路径。
4. **我自己第一版实现漏过锁**（探针抓到，见 Flip ④）：`exec 9>>lock` + `flock -n 9` 会被夹具留下的
   后台子进程（占位 `sleep 3600`）继承 fd → 脚本退出后锁不释放 → 后续每一套都在门口排队。

**诚实边界**：1800s 卡死是间歇性的，用 2 套并发跑 265s×2 没复现（探针没抓到 stall）。所以修复不押
「某一个资源一定先卡住」的假设：既把 tmux 那层做成**构造性隔离**（治本），也把**全量门禁串行化**
（覆盖所有跨进程/机器资源通道，包括上面第 3 条这种非 tmux 的卡死）。

## Deliverables

| Path | What |
|---|---|
| `skills/teamsmith/tests/smoke.sh`（私有 socket） | `TMUX_TMPDIR=$TMP/tmux` → 本轮拥有自己的 tmux server（socket `$TMP/tmux/tmux-<uid>/default`，server 名仍是 `default`）。夹具与**产品**调用（产品一律用 PATH 里的裸 `tmux`，175 处、无 `TEAM_TMUX*` 覆盖点）都落在它上面；调用者原本的 `TMUX`/`TMUX_PANE` 先清掉，若调用者本来在 tmux 里，则在本轮私有 server 上重建等价身份（anchor session），避免「在 tmux 里」这个判定前提被静默降级。`TEAM_SMOKE_NO_PRIVATE_TMUX=1` 退回调用者的 server（对照实验） |
| `skills/teamsmith/tests/smoke.sh`（互斥锁） | **全量**默认串行：`flock --close -w <wait> <lock> bash smoke.sh` 把自己包起来（锁挂在 flock 进程上，脚本与子孙都不持有 fd）。第二套打印排队消息（带持有者 pid）+ `轮到本套了`；超时 exit 2 并写明「不是断言失败，是被另一套占着」；FAST 不排队 |
| `skills/teamsmith/tests/smoke.sh`（防护断言） | 2 条常驻自检：①本轮 server 的 socket 在私有目录 ②本轮的探测 session **没有**出现在调用者的默认 server 上（默认 server 不在跑时跳过）。另外把探测守卫那条的「跳过」文案改成能区分「没有 tmux」与「调用者不在 tmux 会话里」 |
| `docs/team/reports/M23-dev2/pkg/namespace-demo.sh` | 最小复现 + 隔离证明：BEFORE（共享：看得见 / channel 放得开 / 删得掉）vs AFTER（`TMUX_TMPDIR`：三条全部不成立 + 默认 server 干净） |
| `docs/team/reports/M23-dev2/pkg/concurrent-probe.sh` | 并发探针：同机 N 套全量 smoke 同跑，逐套带时间戳记日志；某套 75s 无输出就抓现场（进程树 + wchan + `tmux list-sessions` 是否还答应 + session/pane 清单）。会识别「在门口排队」并在报告里标注为互斥锁的预期行为，不误报卡住 |

## 诊断：干扰通道（最小复现 + 数据）

### ① 共享 tmux 命名空间（确定性、可重放）

```sh
$ bash docs/team/reports/M23-dev2/pkg/namespace-demo.sh
== BEFORE（不隔离：两套都走默认 server）==
  ok  BEFORE ①：B 从默认 server 上**看得见** A 的 session
  ok  BEFORE ③：B 的 `wait-for -S m23-namespace-demo-channel` **放开了** A 的「永不等完」占位 pane（channel 是 server 全局的）
  ok  BEFORE ②：B 用一行 `kill-session` **删掉了** A 的夹具 session
== AFTER（smoke.sh 现在的做法：各自 TMUX_TMPDIR → 各自的 default server）==
  ok  AFTER ①：B 在自己的 server 上**看不见** A 的 session（两个 server 互不可见）
  ok  AFTER ②：B 的 `kill-session -t teamsmith-smoke-A2066948` 在 B 的 server 上**无对象可删**（rc≠0）
  ok  AFTER ③：B 的 `wait-for -S m23-namespace-demo-channel` 落空，A 的占位 pane **还在等**（channel 不再全局）
  ok  AFTER ④：默认 server 上没有 demo 的 session（socket 真的换了目录：…/tmuxA/tmux-1000/default）
== 结果 == BEFORE 共享（现场）· AFTER 隔离成立
```

**这个通道今天在真实 smoke 里还没被踩到**：smoke 的夹具 session 名都带 pid（`teamsmith-smoke-$$`、
`teamsmith-smoke-m11-$$`、`p10-*-$$`、`teamsmith-foreign-$$`），清理只用自己那一套名字，所以「跨 run
删除/列错」是**潜在**通道。排查过、确认不是通道的：全局 tmux option（产品只设 session 级
`destroy-unattached`）、outbox 的 `.lock`（按项目，且有界）、`/tmp/review-<id>`（只在文案里出现）、
`foreign-session` 这个固定名（`kill-session` 清理一个从没被建出来的 session）。

### ② 同机资源争用（实测：会多红）

```sh
$ M23_OUT=/tmp/m23-probe-before bash docs/team/reports/M23-dev2/pkg/concurrent-probe.sh 2 1500 75
共享的 tmux socket：/tmp/tmux-1000/default（存在（默认 server））
run 1: rc=1 用时≈265s 卡住片段=0 末行=… smoke 有失败项
run 2: rc=1 用时≈266s 卡住片段=0 末行=… smoke 有失败项
```

两套都跑完（**没有 stall**），但各多出红（互不相同，全是计时敏感断言）：

| run | 多出来的红（这些断言在单跑时全绿） |
|---|---|
| 1 | `✗ attempts 行带决策证据（state=…）`、`✗ pulse 输出里没有 agent 续跑动作（不该出现 [续跑]）` |
| 2 | `✗ （假 pi 秒退：up 同时也如实报了 PM 没起来）` |

### ③ 抓到的真实卡死：登录 shell + `host-spawn`（非 tmux 通道）

```
bash(某套 smoke) ─ bash -lc 'command -v pm-bare || echo MISSING' ─ host-spawn ─ {host-spawn}
                                          0% CPU，28 分钟，最后被 timeout 1800 杀掉
```

`bash -lc` 会读 `/etc/profile.d/distrobox_profile.sh`，那里为 `DISPLAY`/`WAYLAND_DISPLAY`/
`XAUTHORITY`/`XAUTHLOCALHOSTNAME` 各调一次 `host-spawn sh -c …`。今天我用 24–40 路并发压测
`host-spawn` 没能复现卡住（每次 11–44ms 返回；目前这条通道 rc=127 快速失败），所以**只报「在这里
卡过一次」**，不宣称根因。

## 修复（取舍）

- **私有 socket（治本，选 2a）**：`TMUX_TMPDIR` 是 tmux 官方开关，socket 目录换成 `$TMP/tmux/tmux-<uid>/`。
  为什么不是 PATH shim（我先做了、实测否决）：窗口 harness 是 `bash -lc`，登录 profile（Debian
  `/etc/profile` + distrobox）会把 PATH 重建成系统默认值 —— shim 在里层消失，产品在窗口里的 tmux 调用
  回落到默认 server，**整套全量因此 165 ✗**（M6.5/6 的 PM 拉起断言全红：`state/pm.pid 缺失`、
  `PM 启动失败`）。`TMUX_TMPDIR` 是环境变量，会随 tmux server 传进每个 pane，里层同样有效。
- **全量互斥（治标但覆盖所有通道，选 2b）**：单靠 socket 隔离解决不了 ③ 与机器级争用，而且两套全量
  并发本身就会互相影响（②）。所以再加一把机器级锁：同机第二套**排队**。实现用
  `flock --close -w … <lock> bash smoke.sh` 重新 exec 自己 —— 锁挂在 flock 进程上，脚本与它的子孙都
  拿不到那个 fd（第一版 `exec 9>>` 漏锁，见 Flip ④）。
- **两个都做的理由**：socket 隔离让「tmux 这一层」构造性互不可见，并保护调用者/评审的默认 server
  不被测试污染（这条本身就是既有纪律：测试不该碰真实 session）；锁覆盖所有剩余通道（同一台机器上
  任何共享资源）。只做锁会在 `TEAM_SMOKE_NO_LOCK=1` 时把风险全暴露；只做 socket 则 ③ 仍会卡。
- **不降判定力**：探测守卫那条断言依赖「在 tmux 里」这个前提，若直接把 `TMUX` 清掉它会**永久降级成
  跳过**；所以调用者在 tmux 里时本轮重建等价身份，让那条断言照跑（实测仍在跑）。

## Verification evidence (must have actually been run)

**最终树 `e886f4e`**（本报告的代码部分；报告自身的提交只动 `docs/`）。brief 的三段验收都实跑，输出尾巴：

```sh
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh   # 17:29–17:34
Totals: 13 passed, 0 failed (13 items)                                  ← openspec，rc=0
  ✓ tmux 隔离：本轮 server 的 socket 在私有目录（/tmp/teamsmith-smoke.hFBsvO/tmux/tmux-1000/default）
  ✓ tmux 隔离：默认 server（/tmp/tmux-1000/default）上没有本轮的 session（没污染调用者的场地）
  ✓ 探测守卫：不认别的项目的 tmux session
== 结果 ==  ✓ 1848  ✗ 0                                                rc=0（用时 ~290s）

$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh                # 17:34–17:36
== 结果 ==  ✓ 1433  ✗ 0                                                rc=0
```

**并发实验（brief 第三条：两套全量同跑，双双在预期时间内完成）**

| | 修复前（旧树：默认 server、无锁） | 修复后（`e886f4e`） |
|---|---|---|
| 命令 | `concurrent-probe.sh 2 1500 75`（14:46） | 同左（17:56，输出在 `/tmp/m23-final-probe`） |
| run 1 | rc=1，265s，**1844 ✓ / 2 ✗** | rc=0，285s，**1848 ✓ / 0 ✗** |
| run 2 | rc=1，266s，**1845 ✓ / 1 ✗** | 排队 285s → rc=0，共 569s，**1848 ✓ / 0 ✗**（日志里有「轮到本套了（排过队）」） |
| 卡住（75s 无输出） | 0 次 | 0 次（排队被识别为预期行为，不算卡住） |
| 跑完后的锁 | —（没有锁） | `flock -n` 立刻可拿 → **无漏锁** |
| 双跑多出来的红 | `attempts 行带决策证据` / `[续跑]` / `假 pi 秒退` | 无 |

两套日志都带时间戳；探针脚本在报告包里，可原地重跑。

## Flip evidence (required for defect-fix tasks)

**① 命名空间：共享 vs 隔离（确定性、可重放）** —— `docs/team/reports/M23-dev2/pkg/namespace-demo.sh` 的 BEFORE/AFTER
（输出见前面「诊断 ①」）：不隔离时另一套看得见、放得开（channel）、删得掉；隔离后三条全部不成立，默认 server 干净。

**② 隔离自检不是摆设（break → red → restore）**：把 `TMUX_TMPDIR` 那一行拿掉（其余不动）后跑 FAST：

```sh
$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh       # 隔离被人为破坏
  ✗ tmux 隔离：私有 socket 没生效（期望 /tmp/teamsmith-smoke.dWqzCA/tmux/tmux-1000/default，TMUX_TMPDIR=未设）
== 结果 ==  ✓ 1432  ✗ 1     rc=1
$ git checkout -- skills/teamsmith/tests/smoke.sh && git diff --exit-code -- skills/teamsmith/tests/smoke.sh
（还原后文件与 HEAD 逐字节一致；之后的全量 1848 ✓ / 0 ✗ 就是在还原后的树上跑的）
```

同一段逻辑的独立诊断脚本里，第二条断言（「本轮 session 出现在默认 server 上」）也真的报 `probe there=yes` /
`bad-detected` —— 即那一半同样有效，不是永远绿。

**③ 输掉的那一版：PATH shim 被自己的全量门禁否决**（机制选择的翻转证据）：shim 版全量 **165 ✗**
（M6.5/6 的 PM 拉起断言整段红：`state/pm.pid 缺失`、`PM 启动失败`、`假 agent 的 argv 没落盘`），
原因是窗口 harness 是 `bash -lc`、登录 profile 重置 PATH；换 `TMUX_TMPDIR` 后同一套全量 **1848 ✓ / 0 ✗**。
两版都在提交历史里（`00d0534` → `34e01e2`）。

**④ 锁的两版：漏锁 → `flock --close`**。第一版 `exec 9>>lock` + `flock -n 9` 被自己的探针抓到漏锁：夹具留下的
后台子进程 `sleep 3600`（cwd `/tmp/teamsmith-smoke.DanW4c/p8-env-repo`，ppid=1）继承了 fd 9，于是**下一轮两套探针
都在门口排队**（`flock -n` 报 HELD，持有者就是那个 sleep）。换成包裹式后：

```sh
$ flock --close -w 5 /tmp/m23-lock-test bash -c 'sleep 2; (sleep 20)&'   # 命令里故意留一个活过它的后台子进程
during: lock HELD ✓            # 命令跑的时候锁在
after flock exits: lock FREE ✓ # flock 退出后立刻可拿 —— --close 让子进程拿不到那个 fd
```

正式探针跑完后的 `flock -n /tmp/teamsmith-smoke.lock` = **FREE**（两次运行都有记录）。

**⑤ 重新 exec 丢过「调用者在不在 tmux 里」**：让锁包住整个脚本后，第二趟看不到 `TMUX`（第一趟已经清掉），
于是 12 条「前提是在 tmux 里」的断言被跳过（探针两套都 1836 ✓ / 0 ✗，而单跑是 1848）。把答案 export
出去后（`e886f4e`）恢复 1848 ✓ / 0 ✗。

## Decisions and deviations

- 修复选「2a + 2b 组合」，因为实测（②）证明「并发会互相影响」，而 socket 隔离只覆盖 tmux 通道。
- **没有改 `scripts/lib` 的产品行为**：产品调用全是裸 `tmux`，`TMUX_TMPDIR` 对它透明；私有 server 只由
  smoke 自己安装 → 不涉及 BLOCKED。
- **第一版 shim 被自己的全量门禁否决**（165 ✗），换成 `TMUX_TMPDIR`；两次都写在提交历史里（可审计）。
- **第一版锁被自己的并发探针抓到漏锁**（orphan `sleep 3600` 持 fd 9 → 后续门禁排队），换成
  `flock --close` 包裹式；这条也写在提交历史里。
- 排队超时用 exit 2（与 smoke 既有的「参数不合法」出口一致），并写清「不是断言失败，是被另一套占着」。
- 互斥默认等 1800s：一次全量 ~200s，够排 8 套；持有者进程死掉时 flock 由内核释放，不会留幽灵锁。
- `TEAM_SMOKE_NO_PRIVATE_TMUX=1` / `TEAM_SMOKE_NO_LOCK=1` 是**对照实验**旋钮，不是产品开关。

## Risks / not verified

- 1800s 那种卡死**没有复现**（2 套并发 265s×2、0 stall）。因此不能宣称「根因已修」，只能宣称：
  ①共享命名空间这条通道被构造性关闭；②同机第二套全量不再并行（串行化覆盖任何资源争用）；
  ③真卡死时可更快定位（探针有现场快照 + 隔离自检会指出「没走私有 socket」）。
- ② 多出来的三条红不在本任务范围（串行化后不会再被并发触发），建议各开一条小任务排根因。
- 互斥锁的副作用：某套卡住时其它套会在门口排队到 `TEAM_SMOKE_LOCK_WAIT`（默认 1800s）后 exit 2；
  消息里带持有者 pid + 开始时间。这是「排队」的应有代价，不是新故障。
- `timeout 1800` 的「TERM 被忽略」形状与本次改动无关（TERM 只发给直接子进程，门禁脚本是后代）；
  套上 flock 后仍是同一个进程组，行为不变。

## Suggested next steps

- 三条并发红值得各开一条小任务（`concurrent-probe.sh` 可当复现装置）。
- ③ 的登录 shell/host-spawn 通道建议独立评估（改 lib 的窗口 harness 或给夹具的 `bash -lc` 加
  `timeout` 都在本任务边界之外：前者是产品行为、后者改断言语义）。
- 若 PM 想把「并发实验」纳入常规验收，可以直接用 `pkg/concurrent-probe.sh 2 1500 75`
  （已会识别排队行为，不会把排队误报成卡住）。
