# M53 · watch-degradation 实施（apply：B1–B4）

agent: dev2   status: DONE   time: 2026-09-21T05:02Z
branch: `task/M53-watch-degradation-apply-doct`（local 模式：不 push，分支留在 `.worktrees/dev2`；PM 复验后本地合并）   PR/MR: -
tip: `72b7b30`   base: `f9aa4d5`   change: `watch-degradation`（proposal review：ACCEPTED）

> 任务书 Report 段写的是 `docs/team/reports/M53-verify.md`；按本仓库惯例（apply = `<ID>-<agent>.md`）完整报告在
> 本文件，`M53-verify.md` 只留一行指针。独立翻转包：`docs/team/reports/M53-dev2/pkg/run.sh`。

## Deliverables

| Path | What |
|---|---|
| `skills/teamsmith/extension/team-inbox-watch.ts` | B1：失败路径的账本行（`errno` / `watches` / `poll_ms` / `fallback=polling` / `forced=1`）+ 耐久记录 `<key>.degraded`；`TEAM_INBOX_WATCH_FORCE_FAIL` 旋钮；成功注册/干净退出删记录；轮询计时器保持无条件安装 |
| `skills/teamsmith/scripts/lib/outbox.sh` | B2：降级类读者 `team_inbox_watch_degraded_files` / `_live` / `team_inbox_watch_watcher_degraded_text`，在「没有注册」那条路之前被 `team_inbox_watch_degraded_text` / `_line` 咨询 |
| `skills/teamsmith/scripts/lib/cmd-project.sh` | B2/B3：doctor 的降级告警复用同一份读者；新增 `inotify 额度` 检查行（警告，不动 `fails`） |
| `skills/teamsmith/scripts/lib/common.sh` | B3：`team_inotify_max_watches` / `_used_watches`（只认可证明完整的同 UID 视图，否则 `unknown`）/ `_probe`（经 `team_js_runner`，超时有界）/ `_headroom_line` |
| `skills/teamsmith/scripts/lib/cmd-watch.sh` | B2：面板 `delivery_warning` 按类拼出后果（没有注册 → 粘贴慢路径；watcher 降级 → 只慢不丢，绝不提粘贴） |
| `skills/teamsmith/scripts/panel/src/strings/{zh,en}.ts` + `panel.js` | B2：模板只留固定前缀（后果由上面那份同一读者提供）；bundle 用钉住的 bun 重建、逐字节可复现 |
| `skills/teamsmith/tests/team-inbox-watch-harness.mjs` | B1/B4：控制快照/恢复、前提探针、S22/S23/S24、逐字 watcher 依赖名单、第三判决 SKIP、严格模式、`TEAM_IW_ONLY` |
| `skills/teamsmith/tests/smoke.sh` | B2/B3/B4：新段 `12b-pi3`（降级可见 + inotify 余量）；`12b-pi` 的具名断言按前提分两支；两次过滤夹具运行 + 严格运行 |
| `docs/team/reports/M53-dev2/pkg/run.sh` | 独立翻转包（F-A…F-E，`ok=9 bad=0`） |

## Requirement coverage（proposal → 代码 → 夹具 → 翻转）

| Requirement（delta） | 代码 | 夹具 / 验收 | 翻转 |
|---|---|---|---|
| `notify-and-inbox`#A watcher registration failure is recorded with its cause | `recordWatchFailure` / `writeDegradedRecord` / `inotifyMaxWatches` / `inotifyUsedWatches`（extension） | harness **S22**（账本行 + `.degraded` 全字段 + `.reg` 路由）、**S24**（干净退出删记录 / 成功注册清旧记录）；smoke 12b-pi ⑨ | F-A |
| `notify-and-inbox`#Delivery continues on the polling fallback while watching is unavailable | `session_start` 里无条件的 `pollTimer`；`TEAM_INBOX_WATCH_FORCE_FAIL` 造同一条失败路径 | harness **S23**（强制失败 + `POLL_MS=200`，一个周期内恰好一次唤醒、形状不变、账本 `wake n=1`）；smoke 12b-pi/M53 过滤运行 | F-B |
| `notify-and-inbox`#The inbox-watch gate measures an unavailable watcher visibly and has a strict path | harness：控制快照/恢复、`TEAM-IW-PREREQ`、逐字 `WATCH_DEPENDENT` 名单、`TEAM-IW-CASE SKIP`、`TEAM_IW_REQUIRE_WATCH`、`TEAM_IW_ONLY`、`TEAM-IW-HARNESS OK (skipped=n)` | smoke 12b-pi 两道分支 + 两次过滤运行（强制不可用 rc=0 / 严格 rc≠0） | F-E |
| `watchdog`#A live degraded channel is reported by `team doctor` and `team status` | `team_inbox_watch_watcher_degraded_text`（outbox）；doctor/status 复用 `team_inbox_watch_degraded_line` | smoke **12b-pi3 ①②③④**（活记录 → 三处都报且不说「没有注册/粘贴」；死 pid / cwd 在外不报；健康安静；`.skip` 措辞逐字不变） | F-C |
| `watchdog`#`team doctor` reports the inotify headroom of the wake channel | `team_inotify_max_watches` / `_used_watches` / `_probe` / `_headroom_line`（common）+ `inotify 额度` 行（cmd-project） | smoke **12b-pi3 ⑤** 四种形状（默认 / 阈值 / stub `errno=ENOSPC` / 无运行时 `unavailable`） | F-D |
| `panel`#The delivery warning covers a degraded wake channel | `team_panel_pm_json`（cmd-watch）+ strings + 重建的 `panel.js` | smoke **12b-pi3 ①③**（`__panel-data` 字段 + `monitor --print` 帧）；26-a/26-b（bundle 确定性与观察者只读） | F-C（同一读者） |
| docs（5.1，无 requirement） | **未做**：`references/**` 是 PM-owned，本任务书未授权 | — | — |

场景级对照（design 5.5）：R1 dry-host / 不可计数 / forced / 成功清记录 → S22 / S24；R2 一个周期内一次、形状不变 → S23；
R3 dry 实名、陈旧不算、健康安静 → 12b-pi3 ①②③；R4 配额+探针 ok / 低余量给修法 / 探针失败 / 无运行时 → 12b-pi3 ⑤；
R5 降级命名正确 / 无注册保留原措辞 / 健康空字段 → 12b-pi3 ①③④；R6 forced 只跳 watcher / 严格拒绝 / 真可用不跳 → smoke 两次过滤运行 + 12b-pi 分支。

## Verification evidence（真跑）

### A. 本机 · `openspec validate` + FAST 门禁

```
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
...
✓ change/watch-degradation
Totals: 17 passed, 0 failed (17 items)

$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
...
== 结果 ==  ✓ 2223  ✗ 0
FAST 模式：跳过 27 个真进程段落（1c·M11 真沙盒窗口|…|36·panel-cpu-premise）——完整门禁请不带 TEAM_SMOKE_FAST 重跑
smoke 全绿
rc=0
```

### B. 容器（与 CI 同路径；独立 clone，非 worktree 挂载）：全量门禁

```
$ distrobox-host-exec podman run --rm --userns=keep-id --pid=host --cgroups=enabled -e HOME=/tmp \
    -v "/tmp/m53-clone-gate:/work:ro" -w /work localhost/teamsmith-gate:m51 \
    bash -c 'openspec validate --all --strict && taskset -c 0-3 bash skills/teamsmith/tests/smoke.sh </dev/null'
Totals: 17 passed, 0 failed (17 items)
...
== 结果 ==  ✓ 2705  ✗ 0
计时断言按负载前提跳过 1 条：27-d 装配红线（loadavg 8.59）—— SKIP 既不是通过也不是失败，阈值未改
smoke 全绿
rc=0
```

（一次中间运行在**并发**跑旧翻转包时于 12b-h 真 pane 段级联红（847 项），干净重跑复现绿：那是我造成的机器负载
假红，不是本改动的回归；记录在此避免误读。）

### C. 三个环境的原始结果行

| 环境 | `TEAM-IW-PREREQ` / 判定 | 原始行 |
|---|---|---|
| 本机（配额已恢复，真 watcher） | `watch=ok` | `TEAM-IW-PREREQ watch=ok forced=0 strict=0` · `TEAM-IW-HARNESS OK (skipped=0)` · doctor：`inotify 额度 ✓ inotify 额度 max_user_watches=524288，已用 unknown（空闲 unknown，底线 1024），注册探针 ok` |
| 容器（CI 路径，`--pid=host`，干净配额） | `watch=ok` | 12b-pi 夹具全绿（runner=node，133 条用例）；全量 2705 ✓ / 0 ✗ |
| 前提不可用（本机旋钮，等价干涸主机） | `errno=ENOSPC forced=1` | 整包 `82 PASS / 51 SKIP / 0 FAIL`、exit 0、`TEAM-IW-HARNESS OK (skipped=51)`；过滤运行 rc=0（`SKIP S2` + `PASS S22/S23`，`skipped=4`）；严格运行 rc=1（`FAIL S2`，`TEAM-IW-HARNESS FAIL (4)`） |

本机 `watches=unknown/524288` 是**设计内**的：distrobox 里 `/proc` 是嵌套 PID 命名空间，局部计数不是总量 → `unknown`；
容器 `--pid=host` 的完整视图下 doctor 才会给出真实占用数。

### D. 手工实录 ①–④（任务书要求）

① 强制失败 → 账本行含 `errno/watches/poll_ms/fallback` 且标明 `forced=1`，`<key>.degraded` 落盘：

```
TEAM-IW-CASE PASS S22 the failure line names errno, watches, poll_ms and fallback=polling :: 2026-09-21T04:19:30.534Z watch unavailable: errno=ENOSPC watches=unknown/524288 poll_ms=200 fallback=polling forced=1
TEAM-IW-CASE PASS S22 the record carries forced=1 :: version=1 | target=m30s:pm | key=m30s_pm-dfe7f8ee | reason=watch-unavailable | errno=ENOSPC | watches=unknown/524288 | poll_ms=200 | forced=1 | since=… | pid=2950054 | cwd=/tmp/teamsmith-iw-ClBH5x/repo | heartbeat=…
```

② 强制失败 + 秒级轮询 → 新 spool 行在一个周期内投递一次（形状不变）：

```
TEAM-IW-CASE PASS S23 a forced-failure session still wakes within one poll interval (200 ms) :: messages=1
TEAM-IW-CASE PASS S23 the fallback wake keeps the live-watcher shape (customType/triggerTurn/followUp) :: {"customType":"team-inbox","triggerTurn":true,"deliverAs":"followUp"}
TEAM-IW-CASE PASS S23 the ledger records the fallback delivery as one wake :: 2026-09-21T04:19:30.935Z wake n=1 total=2 inbox=pm kinds=say
```

③ 非严格 + 不可用前提 → 可见 SKIP（打印前提与原因）；严格模式同前提 → 判红：

```
TEAM-IW-PREREQ watch=errno=ENOSPC watches=unknown/524288 forced=1 strict=0
TEAM-IW-CASE SKIP S2 a new spool line wakes the session (fs.watch, polling disabled) :: watch unavailable (errno=ENOSPC, forced=1)
TEAM-IW-CASE PASS S22 … / TEAM-IW-CASE PASS S23 …
TEAM-IW-HARNESS OK (skipped=4)            # exit 0
TEAM-IW-PREREQ … strict=1
TEAM-IW-CASE FAIL S2 a new spool line wakes the session (fs.watch, polling disabled) :: watch premise unavailable (errno=ENOSPC, forced=1) and TEAM_IW_REQUIRE_WATCH=1
TEAM-IW-HARNESS FAIL (4)                  # exit 1
```

④ doctor：低余量 → 警告 + 修法；健康 → 安静（`✓ … 注册探针 ok`）；无运行时 → `unavailable`（绝不 ok）：

```
! inotify 额度   inotify 额度 max_user_watches=524288，已用 unknown（空闲 unknown，底线 999999999），注册探针 ok；修法：抬高 fs.inotify.max_user_watches=524288（宿主 /etc/sysctl.d/；Syncthing 与 VSCode 是常见占用者）
! 本项目 PM 的投递通道降级：watcher 注册失败（errno=ENOSPC；watches 65312/65536）：唤醒退化为轮询，投递不中断；修法：抬高 fs.inotify.max_user_watches=524288（宿主 /etc/sysctl.d/；Syncthing 与 VSCode 是常见占用者）
! inotify 额度   … 注册探针 unavailable；修法：抬高 …
✓ inotify 额度   inotify 额度 max_user_watches=524288，已用 unknown（空闲 unknown，底线 1024），注册探针 ok        # 健康：安静
```

面板同一条降级（截断的是帧宽，不是措辞）：

```
投递降级：watcher 注册失败（errno=ENOSPC；watches 65312/65536）：唤醒退化为轮询，投递不中断；修法…
```

## Flip evidence（独立包：`docs/team/reports/M53-dev2/pkg/run.sh`）

```
$ bash docs/team/reports/M53-dev2/pkg/run.sh
ok F-A：账本行丢 errno/watches → S22 具名红（rc=1）
ok F-B：失败路径没有轮询计时器 → S23 具名红（rc=1，messages=0）
ok 恢复：同一强制前提下 S22/S23 绿（rc=0）
ok F-C：读者忽略 .degraded → doctor/status 降级行 0；恢复 → 2 行（各一条）
ok F-D：探针恒 ok → stub（errno=ENOSPC）读出「注册探针 ok」；恢复 → errno=ENOSPC
ok F-E①：前提谎报 ok → S2 不再 SKIP，具名 FAIL + 非 0（rc=1）
ok F-E②：严格模式也被改成 SKIP → 退出 0（SKIP 守卫会红）
ok 恢复①：不可用前提 = 可见 SKIP + rc=0（TEAM-IW-HARNESS OK (skipped=4)）
ok 恢复②：严格模式的同一前提具名 FAIL + 非 0（rc=1）
== 结果 == ok=9 bad=0 skip=0
```

关键原始红行（含恢复对照）：

```
F-A 红：TEAM-IW-CASE FAIL S22 the failure line names errno, watches, poll_ms and fallback=polling :: … watch unavailable: poll_ms=200 fallback=polling forced=1
F-B 红：TEAM-IW-CASE FAIL S23 a forced-failure session still wakes within one poll interval (200 ms) :: messages=0
F-C 红：读者忽略 .degraded → status 降级行数 0 / doctor 降级行数 0；恢复 → 各 1
F-D 红：inotify 额度 ✓ … 注册探针 ok（stub 的真值是 errno=ENOSPC）；恢复 → ! … 注册探针 errno=ENOSPC
F-E 红①：TEAM-IW-PREREQ watch=ok forced=0 strict=0（谎报）→ FAIL S2 + rc=1
F-E 红②：严格运行 rc=0 + SKIP S2（严格被改成跳过）
```

旧翻转包（本改动碰了 harness，故全跑；用各自的修复前基点）：

```
TEAM_FLIP_BASE=8b5c7e3 bash skills/teamsmith/tests/flip-m43.sh → exit 0（绿树 133 条用例）
TEAM_FLIP_BASE=ebc43f7 bash skills/teamsmith/tests/flip-p25.sh → exit 0
TEAM_FLIP_BASE=7ea5346 bash skills/teamsmith/tests/flip-m46.sh → exit 0（红树 S14/S15/S16 全红、变异各红）
```

## Decisions and deviations

1. **面板措辞的落点**：design D7 写的是「`strings/{zh,en}.ts` 得到类专属尾巴」。但本任务书的 grant 只到
   `scripts/panel/src/strings/{zh,en}.ts` 与 `scripts/lib/cmd-watch.sh`（`layout.ts`/`types.ts` 未授权），所以把**两类的后果**
   放进 `delivery_warning` 字段（由同一读者产出），模板只留 `投递降级：{reason}`。渲染结果与旧措辞对「没有注册」类逐字
   一致（多出的尾巴同一段文本），降级类得到 `唤醒退化为轮询，投递不中断` 且不提粘贴路径；bundle 重建逐字节可复现，
   26-a/26-b 在容器门禁绿。
2. **`references/**` 的文档（B5 5.1）未写**：PM-owned 且不在 grant 里（见下）。
3. **S21 的名单前缀**：watcher 依赖名单原写 `'S21 '`，漏掉 `S21a/S21b/S21c`；强制前提的整包因此有 3 条 FAIL，
   改成 `'S21'` 后整包 `82 PASS / 51 SKIP / 0 FAIL / exit 0`（B4 的翻转①正是要这种形状被看见）。
4. **`flip-m46` 的注射锚点**：新函数 `writeDegradedRecord` 的函数体头两行与旧包的 `writeSkipRecord` 锚点同形，
   使那个包 exit 2；把局部变量改名 `wdir` 后锚点唯一，包恢复 exit 0（`72b7b30`）。
5. **干涸主机实录**：本机配额在任务中途从 `65536`（耗尽）恢复到 `524288`，所以 design 5.4 的「真干涸」现场由
   **旋钮强制同一前提**复现（C 行 + ③），并在容器里跑健康路径；design 5.6 已把「配额恢复后会转绿」写成证据而非断言。
6. **容器假红**：第一次容器运行与我并发跑的旧翻转包争 CPU，12b-h 真 pane 段级联红；干净重跑（gate4）2705 ✓ / 0 ✗。
   报告里保留这条是为了让后续读者不要把它归因到本次改动。
7. 默认轮询间隔、消息形状、spool 格式/去重、`standby`、outbox 投递守卫都没动；没有任何命令尝试改宿主配额。

## Suggested next steps

- **PM（B5 5.1，需另授权/自写）**：`references/troubleshooting.md` 增加有序排查（扩展日志 `watch unavailable` →
  doctor 的 inotify 行 → 才到代码路径）并交叉链接 §22；`references/config.md` 登记 `TEAM_INBOX_WATCH_FORCE_FAIL`
  为 fixture-only、`TEAM_IW_REQUIRE_WATCH` / `TEAM_IW_ONLY` / `TEAM_IW_KEEP` 为夹具控制。
- **PM 决策**：干涸主机上 `tests/flip-m43.sh` / `flip-p25.sh` / `flip-m46.sh` 的红树运行现在会走 SKIP（同一前提），
  旧包需要 `TEAM_IW_REQUIRE_WATCH=1` 或前提感知分支才能继续红证明；这些文件不在本任务 grant 里，我没有改。
- **PM 决策（F2）**：CI 是否在 `gates.yml` 导出 `TEAM_IW_REQUIRE_WATCH=1`（让 CI 的真实 watcher 覆盖不可静默跳过）。
- **验证方**：按 `team review M53 --strong` 独立复跑；本报告的翻转包 `pkg/run.sh` 可重复执行（只写 /tmp）。
- 归档需独立复验通过且用户确认（AGENTS.md 的 gate）；本分支未 push（local 模式）。
