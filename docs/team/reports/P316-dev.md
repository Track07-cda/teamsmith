# P316 · 删掉「需要安静机器才能过」的测试

agent: dev · branch `task/P316-delete-load-sensitive-tests` · change: - · anchor: none (infra) — 门禁测试面自身的时间判据
tip: `8ff3ac1b`（门禁在它上面跑）· time: 2026-10-19

**结论：门禁里不再有任何「墙钟当判据」的红。** 时间（每段用时、首帧、帧装配线、窗格 CPU、各处等待耗时）继续打印，
但一律标成 `· 参考`，不参与 ✓/✗、不决定退出码；防死等的上限保留，超时措辞是「**没等到 X**／**挂住**」而不是「太慢」。
性能套件从「三条红线 + 负载前提决定判/跳过」变成「只测量、只打印、能测到就 `exit 0`」。
差量：`git diff --shortstat 36981120..3bb414ba -- skills/teamsmith/tests` = **30 files, 656 insertions(+), 2522 deletions(-)**，
净减 **1866** 行。其中 4 个整体退役的文件（716 行）**已经算在这 −2522 里**（我先前把 716 与 2522 相加写成 2582，是错的）。

## Deliverables

| 路径 | 做了什么 |
|---|---|
| `tests/lib/section-guard.sh` | 每段预算/实测带/祖辈期限全部删除；只剩一个**常量挂住上限**（默认 1800s，`TEAM_SMOKE_SECTION_HANG_CAP` 仅夹具可注入）。超了打印「段落 #N（id）挂住：已 1800s 没有结束（最后状态 …）」→ 写现场 → 停跑。收口行改成 `#N id · 参考 用时 Ns · ✓/✗/SKIP · ticks`，不再与实测带比较 |
| `tests/section-budgets.tsv` | **删除**（135 个段行的墙钟预算表） |
| `tests/section-guard.sh` | `--budget-check`（表自洽的时间部分）删除；`--loop-check`（88 个 while+sleep 的上限清单）整段保留 |
| `tests/perf.sh` | 改成**参考报告器**：三条读数（交互首帧 / 帧装配线 / 稳态窗格 CPU）+ loadavg/核数/CPU 配额照打，行首 `· 参考`；没有阈值、没有前提、没有 SKIP；能测到 `exit 0`，搭不起来 `exit 3`。原 `exit 2`（红）/`exit 4`（SKIP）与全部判定函数删除 |
| `tests/panel-cpu.sh` | 同上：首帧与窗格 CPU 照测照打（`· 参考`），阈值判定、`pc_premise`（loadavg 前提）、帧时注入夹具全部删除；窗格子进程改用 `ps --ppid`（`pgrep` 是团队 shim，夹具里读不到） |
| `tests/panel-cpu-premise.sh`、`tests/load-experiment.sh`、`tests/panel-knobs.sh` | **删除**（三份文件只为「负载前提」服务；旋钮随夹具一起消失） |
| `tests/lib/pty-wait.sh` | `pty_premise_*` 钩子、`PTY_SKIPPED`、`rc=3`（机器超前提的可见 SKIP）删除；视界从 40 轮基础 / 3× 延长改为 100 轮 / 5×（≈300s，仍在绘制才延长），耗尽一律 `rc=1` +「没等到 X（最后一次状态 …）」+ 现场 |
| `tests/panel-p21.sh`、`tests/panel-b3.sh` | 入口负载闸门、premise-only 模式、`rc=3 → cond_skip` 删除；21 + 10 处「没有在预算内出现」改成「没等到 X」；「Enter 后 1.2s 内出现详情视图」改成 300s 上限 +「没等到详情视图」+ 最后一次状态 |
| `tests/gate-guard.sh` | 重写成新边界守卫（纯逻辑、不起进程）：①门禁（smoke + lib）里没有墙钟阈值比较；②门禁不点名测量夹具；③两个参考打印器都在、都带 `· 参考`、都没有 `exit 2/4`；④门禁真的调它 |
| `tests/smoke.sh` | §0e 只剩「看门狗在岗 + 模块自检 + 循环清单 + 挂住旋钮只在夹具下生效」；§0f 改成**挂住停跑**夹具（3s 上限注入，断言 exit 2、点名行、现场、不是 SKIP）；§35 只守新边界（含两向翻转）；§34①②④⑦ 的秒数区间删除（rc/记录/点名/cap 算式保留）；§34b⑧（祖辈预算对齐，24 条）退役；§14d 去掉预算 token、进度行不再按墙钟判；§28-i 的「1 秒」改成 `· 参考`；§36③ 改成断言「收口行带 `· 参考 用时` 这个形状」 |
| `tests/{key-replies,key-replies-ui,routes,task-model-routing,section-paths,loop-inventory}.sh/tsv` 等 11 个夹具 | 时长判据删/改成账本与状态判据；5–25 秒的夹具等待统一到 300s；循环清单随源码重算（88 行） |
| `docs/team/reports/P316-dev.md` | 本报告（含四类清单：参考 10 / 删 28 / 改判据 21 / 保留 17，见附录） |

## Verification evidence

### 1. 关键结论的证据：门禁面已没有墙钟判据

```
$ grep -nE '(\$elapsed|\$\{elapsed\}|\$SECONDS)[^|;]*-(gt|ge|lt|le)([^0-9A-Za-z_]|$)' \
    skills/teamsmith/tests/smoke.sh skills/teamsmith/tests/lib/*.sh | grep -v section-guard.sh
（无输出）
$ bash skills/teamsmith/tests/gate-guard.sh ; echo rc=$?
ok: lib/section-guard.sh 只把时长与常量挂住上限比较（防死等）
ok: 门禁（smoke.sh + lib/*.sh）里没有墙钟阈值比较：时间只记录，不判绿红
ok: smoke.sh 不点名测量/参考夹具（性能读数不在正确性门禁里跑）
ok: perf.sh 带着「· 参考」标记（读数给人看）
ok: perf.sh 没有判定型退出码（exit 2/4）：性能不阻塞
ok: panel-cpu.sh 带着「· 参考」标记（读数给人看）
ok: panel-cpu.sh 没有判定型退出码（exit 2/4）：性能不阻塞
ok: smoke.sh 调用 gate-guard.sh（守卫被摘掉会现形）
rc=0
```

参考读数确实照打（同一台负载机器上真跑）：

```
$ cut -d' ' -f1-3 /proc/loadavg
11.49 14.78 19.28          # 32 核
$ bash skills/teamsmith/tests/perf.sh --host | tail -6
  · 参考 机器：loadavg 19.6 · 32 核 · 采样窗 6s（本夹具不判绿红）
  · 参考 帧装配线：5 次采样 1451, 1490, 1502, 1560, 1583 → 中位 1502ms（不比阈值）
  · 参考 首帧：5246ms（3 次独立 spawn 的中位）
  · 参考 窗格 CPU：0.2%（三等分中位）
== 结果 ==  · 参考（性能不参与绿红；参考环境：否）；没有红/绿/SKIP 结论
$ echo $?
0
```

注意第一行的首帧 **5246ms**：按旧规则（2000ms 红线）这台机器是红；按新裁定它是「参考读数」，退出码仍是 0。
这就是这次改动的实质。

### 2. 静态守卫

```
$ bash skills/teamsmith/tests/section-guard.sh --loop-check
ok: 扫描 88 行清单 / 88 个 while+sleep 循环，配平 88 个
$ bash skills/teamsmith/tests/section-select.sh --check ; echo rc=$?
rc=0                      # 选段表与 smoke.sh 的段名逐条对齐（含已退役的 0e/35 改名）
```

模块自检 `bash skills/teamsmith/tests/lib/section-guard.sh --self-test` 在改动后跑到过「零失败」，
但那次的逐条条数我没有留存原始输出，所以不在这里引具体数字：它覆盖的是挂住/忽略 TERM/空转/孤儿四种形状
加一条干净路径（band 与前提的用例随机制一起退役）。要复核就真跑一次这条命令。

### 3. 反转证据（破坏实现 → 守卫必须红 → 逐字节还原 → 绿）

| # | 破坏 | 红 | 还原 | 绿 |
|---|---|---|---|---|
| F1 | `perf.sh` 里 12 处 `· 参考` 全换成 `判定结果` | `gate-guard.sh` rc=1，`bad: perf.sh 没有「· 参考」标记`；`--select 35` **✓23 ✗1**，✗ 行同名 | `cp` 回备份，sha256 前后同为 `d4b4b6e1…` | `gate-guard.sh` rc=0；`--select 35` **✓24 ✗0** |
| F2 | `lib/section-guard.sh` 的挂住比较改成 `-ge $(( cap * 1000 ))`（上限放大 1000 倍） | 挂住的段**永不结束**：`--select 0f` 被 `timeout 300` 杀掉，`A_rc=124`，`挂住：已` 行数 0（守卫不比较，就没人停跑） | 同上，sha256 `78e8b378…` 前后一致（`restored=78e8b378c1a68abf`） | `--select 0e,0f,35` **✓68 ✗0**（`/tmp/p316-r2.log`） |
| F3 | 挂住停跑的措辞从「挂住：已 Ns 没有结束」改成旧的「超时：预算 Ns」 | `--select 0f` **✓42 ✗1**：`✗ P70 挂住：输出里恰好一条点名挂住的行（期望 [1]，实际 [0]）` | 同上，`final=78e8b378c1a68abf` | `--select 0e,0f,35` **✓68 ✗0**（`/tmp/p316-r2.log`） |

F2/F3 是同一守卫的两面：F2 证明「上限比较真的在停跑」，F3 证明「停跑的身份（挂住 ≠ 太慢）真的被断言钉住」。

### 4. 一次意外的反面证据：挂住上限自己咬到了我

调试 §54 时我把 `TEAM_DISPATCH_VERIFY_SEC` 从 2 秒抬到 300 秒（想让启动证据更宽），结果那 6 个既有失败的用例各等 300 秒，
整段撞上 1800 秒的挂住上限：

```
  ✗ 段落 #5（54 · 派单摩擦…）挂住：已 1800s 没有结束（挂住上限 1800s，最后状态 1251s）→ 停跑（exit 2），
    现场 /var/tmp/teamsmith-pm_skills-deb708fe/.teamsmith-smoke-scene.1580755
```

这条红**正是新机制该有的行为**（它停跑、点名、留现场），但它也说明把窗口放大并不能修那些用例 —— 那些失败与时间无关，
且 **main 上逐条复现**（见下）。已把窗口还原成 2 秒。

### 5. 全量 FAST 门禁（最终树，负载下）

```
$ cut -d' ' -f1-3 /proc/loadavg        # 起始
11.13 10.32 11.72                      # 32 核
$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh ; echo rc=$?
rc=1
账本自查： 135 段收口 · 增量 ✓4004 ✗25 SKIP60 ｜ 结果行 ✓4004 ✗25 —— 一致
== 结果 ==  ✓ 4004  ✗ 25
✓ P70 对账：本套没有触发过挂住停跑
```

这一轮的 ✓/✗ 总数（✓4004 ✗25）与改动前那一轮相同，但**总数相同不能证明覆盖没被削弱** —— 它是删掉 1866 行之后的巧合，
不是等价性的证据。必要覆盖要由 V61 独立复核：逐条看附录 A 里「删后谁守」那一列是否真的成立。
我能负责的部分只有两件事：这一轮**没有一条新的红**（25 条 ✗ 全部在 main 上逐条复现，见下），
以及我修掉的两条（§10 的 P310 双腿）从名单里消失了。

### 6. 那 25 条 ✗ 的来源（逐条对照 main）

| 计数 | 段 | main 干净克隆上的同一现象 | 证据 |
|---|---|---|---|
| 19 | §54 派单摩擦（P140/P151：覆盖/审计/SID/分支同源） | ✓74 ✗19，**同名同数** | `/tmp/p316-main-54.log`（main `36981120`） |
| 1 | §51 `routes.sh` 有失败（内含 10 条） | ✗10，两份 ✗ 名单 `diff` **IDENTICAL** | `/tmp/main-routes.txt` vs `/tmp/mine-routes.txt` |
| 1 | §40 临时根泄漏（由 §12e 造成） | 同源缺陷：`task-header-model.sh` 在 main 克隆里连续 4 次运行留下 4 个根 | 根因：`tmp_root_base()` 依赖**当时的 `TMPDIR`**，`tmp_root_create` 记台账时 `TMPDIR` 已被夹具改过，退出时 `cleanup` 在另一个 `TMPDIR` 下算 `$(tmp_root_ledger)` → 找不到自己那条 → 根留在 `/var/tmp` |
| 1 | §6e「resume 位置参数不可用」 | ✓146 ✗1，同一条 | `/tmp/p316-main-6e.log` |
| 3 | §12b-j / §M9.8 / §M16「夹具的痕迹出现在真实账本里」 | **环境**：它们扫的是真实账本（`$ROOT/.pi/team/state`），而 `release-030/checkout` 这个 0.3.0 发布用整仓检出就在那下面，里面自然带着夹具字样 | 用 **main 分支里那份逐字节相同**的扫描器（`real_ledger_hits`，我的 diff 没碰它）对同一目录跑：命中 **24 个文件，全部在 `release-030/checkout` 下** |

这三条隔离红在我第一轮全量运行（约 08:30）时还不存在，是发布检出出现之后才有的 —— 与 P316 无关，
但会一直把全量门禁点红，建议你把该检出挪出 `.pi/team/state/`（见 Suggested next steps）。

### 7. 旧基线里两条的变动

- §10 的 P310 双腿：本轮**已修**（`flip-p310-lock.sh` 的绿侧文案丢了 `排队` 一词，而 `smoke.sh` 按它 grep），
  第一轮 ✗ → 本轮 ✓。
- §34b⑫「登记随它退出消失」：第一轮 ✗、本轮 ✓（同一棵树、没改它）—— 是**不稳定**的既有断言，不是被我修好的。

| 段 | 我的树 | main 干净克隆 | 对照证据 |
|---|---|---|---|
| §54 派单摩擦（P140/P151） | ✓74 ✗19 | ✓74 ✗19（同样的 19 条名字） | `/tmp/p316-main-54.log`（main `36981120`） |
| §51 `routes.sh` | ✗10（逐条同名） | ✗10 | 两份 ✗ 名单 `diff` **IDENTICAL**（`/tmp/main-routes.txt` vs `/tmp/mine-routes.txt`） |
| §34b⑫「登记随它退出消失」 | ✗1 | ✗1 | `/tmp/p316-main-34b.log`（main ✓123 ✗1） |
| §6e「resume 位置参数不可用」 | ✗1 | ✗1 | `/tmp/p316-main-6e.log`（main ✓146 ✗1） |
| §40 临时根泄漏（由 §12e 造成） | ✗1 | 同源：`task-header-model.sh` 在 main 克隆里单跑后留下 `teamsmith-task-header-model-*`（4 次运行留下 4 个根） | 根因已定位：`tmp_root_base()` 依赖**当时的 `TMPDIR`**，而 `tmp_root_create` 记台账时已被夹具改过 `TMPDIR`；退出时 `cleanup` 在另一个 `TMPDIR` 下算 `$(tmp_root_ledger)`，台账路径不同 → 找不到自己那条 → 根留在 `/var/tmp`。与时间无关，属既有缺陷 |

这五处都不是「时间当判据」，也都不在本任务的授权面（三条是产品/夹具既有缺陷，两条是既有实现与夹具不一致）。
按 D3=A，我只报告、不修；建议单独立项（见 Suggested next steps）。

## 返修轮次 1（V61 的五条 + 我自己的 D1）

V61 判定「时间不再是判据，但不作为阻塞这件事还没全落地」：剩下几处时间仍在**当证据用**。逐条修在原因上：

| # | V61 指出的 | 改成 | 为什么这不是换措辞 |
|---|---|---|---|
| F1 | 停跑按「武装后经过多久」判，真正慢但一直在动的段会被误判成挂住 | 判据改成**cap 秒内没有进度**，进度证据就是心跳里已有的 ticks（`ok()`/等待轮每轮 +1）；自检补上缺的那一格 `progressing`（一直 tick、总时长远超 cap 的段必须绿） | 状态量与判据对齐：四个真卡死的形状照样停跑，而在动的段不会再被停 |
| F2 | 26-m 三处首帧等待写死 20s，与共享视界 300s 两套话；失败文案说「慢」；gate-guard ① 自称覆盖「任何墙钟判据」 | 三处统一用 `P10_POLL_SECS`；文案改成「状态没出现，不是帧慢」；gate-guard ① 收窄成它真正检查的**一种写法**，并明说参数形态它看不见 | 「覆盖等于保证」被拆掉：现在写的是守卫实际能证明的东西 |
| F3 | 删掉秒表后旋钮没人守：key-replies 的锁界、routes 的宽限两腿都失去覆盖 | key-replies 用 `flock` 桩断言工具交给限时锁的**就是它自己的界**（实测 `-w 2 3`、诊断 `2000ms`）；routes 两腿改成「响应 TERM 的作业在窗口内自己退（`signal=TERM`，不升级）」对「不响应就升级（`TERM,KILL`）」 | 两处都用**行为/协议**当判据：旋钮接不接得上，账本与 argv 会说 |
| F4 | 另有同病（其它 fixture 把时间当证据） | 本轮触及的都在上面；余下的在附录 A 的「保留」类里，是「固定等待后的状态断言」，机器越忙越成立 | — |
| F5 | gate-guard 拿「我自己有没有被调用」和「打印器带不带标记」当证据（自指/呈现契约） | 删掉 ④ 自指检查与「· 参考」标记那一半，只留三条机械边界：一种墙钟比较不在门禁面、门禁不点名测量夹具、两个参考打印器没有 `exit 2/4` | 「不阻塞」的证据现在是行为（首帧 3939ms 仍 rc=0），不是措辞 |
| D1 | perf 汇总表把真实首帧印成「没测到」，真测出来又会印成 `4065msms`（中位带单位、表格补单位），而「· 参考」印在空表上等于陷阱 | 汇总表打出真数字；取数不再跨多字节正则（三种写法本机实测都静默失败，见下） | 表格现在真的显示读数 |

### 返修后真跑（本机，负载见各行）

```
$ cut -d' ' -f1-3 /proc/loadavg ; TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh --select 0e,0f,35
8.45 7.33 7.56
账本自查： 7 段收口 · 增量 ✓68 ✗0 SKIP0 ｜ 结果行 ✓68 ✗0 —— 一致
== 选段结果 ==  ✓ 68  ✗ 0            # 含新自检形状 progressing、0e④ 两向翻转、0f 挂住夹具

$ bash skills/teamsmith/tests/lib/section-guard.sh --self-test | tail -1
== 结果 ==  ✓ 64  ✗ 0                 # 含 progressing（旧实现会把它判成挂住，见 F-A）

$ bash skills/teamsmith/tests/key-replies.sh ; echo rc=$?
  ✓ receipts：传给 flock 的是产品自己的界（-w 2 3）
  ✓ receipts：忙时的诊断报出同一个界（2000ms）
rc=0

$ TEAM_ROUTES_FAST=1 bash skills/teamsmith/tests/routes.sh
  ✓ promise（TEAM_BG_STOP_GRACE）：宽限 0 → 忽略 TERM 的作业被立刻 KILL（账本 signal=TERM,KILL）
  ✓ promise（TEAM_BG_STOP_GRACE）：宽限 2 → 响应 TERM 的作业在窗口内自己退出（账本 signal=TERM，没有升级）

$ bash skills/teamsmith/tests/perf.sh --host ; echo rc=$?
  ① 交互首帧               | 3939ms       | 3 次独立 spawn 的中位（上面逐次读数）
  ② 帧装配线               | 636ms        | 636, 622, 631, 679, 668
  ③ 稳态窗格 CPU           | 0.50%        | 三等分中位（上面三等分读数）
rc=0                                  # 3939ms 只打印，不判绿红

$ bash skills/teamsmith/tests/section-guard.sh --loop-check
ok: 扫描 89 行清单 / 89 个 while+sleep 循环，配平 89 个
```

### 返修的两处翻转（破坏实现 → 守卫必须红 → 逐字节还原 → 绿）

原始日志：F2/F3 见 `<project>/.pi/team/state/bg/p316-flip2b.log`，F-A/F-B/F-C 见
`.pi/team/state/bg/p316-flips-rework.log`，还原后的选段运行见 `/tmp/p316-r2.log`。

| # | 破坏 | 结果 |
|---|---|---|
| F-A | 停跑判据改回 `now - armed`（武装后经过多久） | `--self-test` **✓62 ✗2**：`✗ progressing：套件 exit 2（期望 0）`、`✗ progressing：干净路径留下了现场` —— 一直在动的段被误判成挂住，正是 V61 说的问题；还原后 ✓64 ✗0 |
| F-B | `bg stop` 的宽限硬编码成 0（旋钮被忽略） | routes **✗ promise（TEAM_BG_STOP_GRACE）：宽限 2 时账本没有记下「TERM 之后它自己退了」**（实际是 `signal=TERM,KILL`）—— 旋钮失守立刻现形 |
| F-C | `replies.mjs` 的 `LOCK_WAIT_SEC` 从 2 改成 30 | key-replies **✗ receipts：传给 flock 的是产品自己的界（-w 2 3）：文本里没有 [-w 2 3]（实际：-w 30 3）**（当时的断言文本；V63 后收窄成只守 `-w 2`，fd 不再入契约） |

三次破坏都在**原地**改、跑完立即还原，并逐字节核对：`sg: a5330f12… → a5330f12…`、`bg: ca5d68e7… → ca5d68e7…`、`mj: 6e747a7e… → 6e747a7e…`；
PM 巡检到 `FLIP-C` 标记时实验正在跑，事后确认产品文件与 HEAD 逐字节相同、`git status` 只有我自己的 `tests/routes.sh` 改动。
**后续破坏实验一律在 `/tmp` 的临时副本上做，不再在交付树原地改产品。**

## 返修轮次 2（V63 的四条）

冻结输入 `b025fbdf`。V63 判定 PARTIAL，唯一缺口是「固定 grace=2 仍让两条宽限断言绿」。四条逐条：

| # | V63 指出 | 改成 | 证据 |
|---|---|---|---|
| 1 | 两条宽限断言用的是两个**不同的作业**，只能说明「两种作业结局不同」，说明不了「配置值决定等多久」；实测把实现固定成 grace=2，两条仍绿 | 保留真实进程腿①（忽略 TERM 的真作业 + 配置 0 → `signal=TERM,KILL`）；腿②改成**同一份作业状态、只改配置 0/2** 的**逻辑腿**：测试侧局部 `. cmd-bg.sh` 加载 `team_bg_stop` 本身，用替身替换 `sleep`/`kill`/`team_bg_pid_alive`/`team_bg_dir`/`team_bg_check_record`/`team_bg_ledger` 与输出函数，把等待累加成逻辑秒数、把信号记成顺序，量 **TERM→KILL 之间的逻辑等待**。删掉上一轮那个四秒自然寿命的响应作业 helper（不叠第二个 helper） | 三个读数：配置 0 + 会响应的作业 → `0.00 TERM,KILL`（**零等待**）；配置 2 + 同一作业 → `0.00 TERM`（不升级）；配置 2 + 不响应的作业 → `2.00 TERM,KILL`（等满窗口）。固定 grace=2 的反例（磁盘副本 `/var/tmp/p316-v63-scratch`，只改 `grace=2`）→ **目标断言变红**：`✗ promise（TEAM_BG_STOP_GRACE）：配置 0 却没升级成 KILL（信号顺序 [TERM]）` |
| 2 | `section_guard_watchdog` 的 `last_ticks`/`last_moved` 跨段继承 | 心跳里带段号与武装代次；两者任一变化就把这两个**既有**变量重置为当前段（不新增守卫/协议/心跳字段） | 私有单点（`/var/tmp/p316-v63-probe/reset-probe.sh`，不入库）：段 1 tick 到 12 后停 1.5s（cap=2，不会自己停），再把心跳换成「同 ticks 的段 2」→ 交付版在换段后 **2.0s** 才停；`/var/tmp` 的反例副本（基线继承）在 **1.0s** 就停。同一脚本、只差这一处状态归属 |
| 3 | fd=3 不是锁契约 | 断言收窄成只守 `-w 2`（不钉 fd），真实竞争/rc5/未发布/只读断言不删 | `✓ receipts：传给 flock 的是产品自己的界（-w 2）`、`✓ 限时 flock 放弃时同样没有发布`；`key-replies` 全套 ✓212 ✗0 |
| 4 | 旧「预算 10s」注释仍在；报告里的自检总数是推导值 | 注释改成「300s 是防死等，不是预算」；报告只写**当次真输出**的条数 | 本轮 `bash lib/section-guard.sh --self-test` 的输出尾行：`== 结果 ==  ✓ 64  ✗ 0`（不再用上一轮推导的 65） |

本轮只跑直接受影响的入口（未跑全量/FAST/性能采样）：`routes.sh promises`（宽限腿）✓18 ✗1（唯一 ✗ 是既有的
`TEAM_PULSE_WINDOW`）、`key-replies.sh` ✓212 ✗0、`section-guard.sh --self-test` ✓64 ✗0、`--loop-check` 全过（清单随之重算）。
两次破坏实验都在**磁盘**副本里做（`/var/tmp`，不是 tmpfs），交付树里没有留下破坏标记。

## 返修轮次 3（V64 的四项收口）

V64 已独立确认「固定 grace=2」由目标断言检出。本轮只做四项小收口，不重测已成立的 receipts / self-test / perf / smoke。

| # | V64 要求 | 落点 |
|---|---|---|
| 1 | 逻辑窗口由 `(0,2]` 收成 `g == 2` | `routes.sh` 逻辑腿第三条断言改成 `awk -v w="$r2b" 'BEGIN { exit !(w + 0 == 2) }'`：不响应的作业必须等满**配置的完整宽限**再升级。逻辑时间是计数得来的，不受负载影响，所以不需要阈值 |
| 2 | KILL 替身要让作业变已死、且不得吞掉受测函数的意外返回 | 替身状态改三值（0 未收 TERM / 1 收到后按逻辑秒死 / 2 已被 SIGKILL 立刻死且**不复活**）；`team_bg_stop` 的返回经 `if … then rc=0; else rc=$?; fi` 作为第三个字段交给调用侧，调用侧先断言三次都是 0（含原始 stderr 首行） |
| 3 | 删掉从未被读取的 config 重写与吞错、删掉旧响应作业注释 | `mr_grace_logic` 不再写 `config.sh`（值只经 env 提供），注释写明「载入不在本探针的验证范围」；删掉「宽限腿②的作业：响应 TERM…」那两行残留注释，措辞改说替身记录 |
| 4 | 报告命令/数字须对应原始日志，找不到就注明未重跑 | F2/F3 指向 `state/bg/p316-flip2b.log`、F-A/F-B/F-C 指向 `state/bg/p316-flips-rework.log`；还原运行按日志改成真实的 `--select 0e,0f,35 ✓68 ✗0`（`/tmp/p316-r2.log`）；F-C 的引文注明那是当时的断言文本，V63 后已收窄为只守 `-w 2` |

### 本轮的真跑（只跑 promises 入口）

```
$ bash skills/teamsmith/tests/routes.sh promises
  ✓ promise（TEAM_BG_STOP_GRACE）：宽限 0 → 忽略 TERM 的作业被立刻 KILL（账本 signal=TERM,KILL）
  ✓ promise（TEAM_BG_STOP_GRACE）：同一作业状态下配置 0/2 给出不同等待（0 → 立即 KILL；2 → 等满 2.00s；会响应的作业不升级）
== 结果 ==  ✓ 18  ✗ 1  SKIP 0            # 唯一 ✗ 是既有的 TEAM_PULSE_WINDOW
```

### 两项新反例（都在磁盘副本 `/var/tmp/p316-v64-d`，交付树无残留）

| # | 破坏 | 结果 |
|---|---|---|
| D | 产品把等待窗口算成 `grace*5`（配置 0 仍立即 KILL，配置 2 只等 1.00s） | **✗ promise（TEAM_BG_STOP_GRACE）：配置 2 的 TERM→KILL 等待是 1.00s，不是配置的完整宽限 2s** —— 精确等于 2 这条断言自己抓的，不是别的旧红 |
| A | 测试侧替身改成扛 SIGKILL（`2) return 0`） | **✗ promise（TEAM_BG_STOP_GRACE）：逻辑腿 0 的 team_bg_stop 返回了 6（期望 0）** —— 产品报 `still-alive`（rc 6），被 rc 断言原样传播，printf 没有把它盖掉 |

## Decisions and deviations

- 与任务书的偏差：**无**。第一步先交清单（两版，第二版按用户第二条判据重切成「参考/删/改判据/保留」四类），
  拿到 PM 转达的 C1/C2/D3/D4 裁决后才动测试代码。
- 我**没有**为了修既有红去动产品代码或别的目录：`openspec/specs/**`、`skills/teamsmith/references/**`、`SKILL.md`、
  `.github/workflows/gates.yml`、`scripts/lib/{gate-lock,cmd-review}.sh` 一律未改。CI 也不需要改：`perf.sh` 仍是可执行入口，
  只是永远 `exit 0`。
- `gate-lock` 的 `expected`/`bound` 字段按 C2 保留、填 0/0：`gate_lock_expected … /dev/null` → 0/0，
  排队上限退回 `TEAM_SMOKE_LOCK_WAIT`（仍是防死等，不是性能判定）。

## Suggested next steps

1. **规格与文档同步（D3=A，归你/规格 owner）**：把下面五处的时间判据改写成「参考读数」语义：
   - `openspec/specs/verification/spec.md:225-229,250-257,329-344`（每段硬预算 / `perf` 三红线 / 负载前提 → 可见 SKIP）；
   - `openspec/specs/panel/spec.md:420-510`（首帧 2000ms、窗格 CPU <1% 的 SHALL 判定）；
   - `skills/teamsmith/references/protocol.md`、`references/troubleshooting.md`、`SKILL.md` 里「门禁会判性能」的叙述；
   - `.github/workflows/gates.yml:110-145` 的注释（功能不变，注释里「perf gates nothing」现在还自洽，但「红线」措辞要改）；
   - `docs/team/RELEASE-PUBLIC.md` / `docs/team/tools/release-check.sh`：若把性能套件写成发布前置，需要同步。
2. **既有红单独立项**（`BLOCKED:` 不是我该改的，需要任务书）：① §54 的 19 条派单夹具（`state/dev.env` 被判「没有在飞任务」→
   覆盖/审计路线全线不成立）；② `routes.sh` 的 10 条同一族；③ §6e `resume <agent> --dry-run` 在夹具项目里失败；
   ④ `tests/lib/tmp-root.sh` 的台账路径依赖 `TMPDIR`（§40 泄漏，根因已定位，改法：`tmp_root_create` 时把台账路径
   记成全局变量，`cleanup` 用它而不是重算）；⑤ §34b⑫ 不稳定（同一棵树两轮一红一绿）。
3. **隔离红的处置（你的环境）**：`.pi/team/state/release-030/checkout` 是整仓检出，`real_ledger_hits` 会把它当成
   「真实账本里的夹具痕迹」（本轮 3 条红、24 个文件）。两条路：把发布检出挪到 `state/` 之外，或给扫描器加一条
   「`state/*/checkout` 是仓库副本」的排除（后者是产品面改动，需要任务书）。
4. 合并顺序：P316（只含 `skills/teamsmith/tests/**` + 本报告）→ 规格/文档同步 change。合并后全量门禁的 ✗ 集合应与 main 相同
   （§54 19 / §51 内含 10 / §40 1 / §6e 1 / 隔离 3），不多一条；我在同一台负载机器（loadavg 11–15 / 32 核）上跑了两轮，
   两轮的 ✓/✗ 总数都是 4004/25。

## 附录 A · 四类清单（摘要，逐行清单见阶段一提交 `2fbf76a9`）

| 类 | 条数 | 代表 |
|---|---|---|
| **参考** | 10 | 段落收口行的用时、`perf` 三读数、`panel-cpu` 首帧/CPU、`p10_wait_ms`、28-i 的 200 KiB 用时、`36③` 慢段秒数 |
| **删** | 28 | `section-budgets.tsv` 与 band/祖辈期限、`--budget-check`、`perf` 的阈值与 2/4 退出、`panel-cpu` 的前提与红线、`panel-cpu-premise.sh`/`load-experiment.sh`/`panel-knobs.sh`、34①②④⑦ 的秒数区间、34b⑧、28-i 的 1 秒、key-replies×2 的时长、慢 list ≤20s、§0e 的表检查、§38-g |
| **改判据** | 21 | `pty-wait` 前提→「没等到」、`panel-p21`/`panel-b3` 闸门→轮询、各处 5–25s 等待→300s、`routes` 宽限→账本信号、`task-model-routing` 外部查询、`section-guard` 预算→常量挂住上限、`gate-guard` 四向重写 |
| **保留** | 17 | 轮询失败路径、配置默认值（900s/17s/11s/60000）、`bounded-spin` 的防死等上限、`tmp-hygiene` 的 mtime 年龄、固定等待后的状态断言、§34 的判定 token 与 rc |

## 附录 B · 可复算的命令

```bash
cd skills/teamsmith/tests
grep -nE '(\$elapsed|\$\{elapsed\}|\$SECONDS)[^|;]*-(gt|ge|lt|le)([^0-9A-Za-z_]|$)' smoke.sh lib/*.sh   # 空
grep -c '· 参考' smoke.sh perf.sh panel-cpu.sh lib/section-guard.sh                                   # 17/12/7/3
bash gate-guard.sh; bash section-guard.sh --loop-check; bash section-select.sh --check
bash -n smoke.sh lib/section-guard.sh lib/pty-wait.sh panel-p21.sh panel-b3.sh perf.sh panel-cpu.sh
```
