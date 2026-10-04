# M32 · smoke 的 tty 敏感探针自 detach stdin（PM 在 tmux 窗口直接跑门禁必绿）

agent: dev2   status: done   time: 2026-09-18T14:06:00Z
branch: `task/M32-smoke-tty-detach-stdin-pm-tm`   PR/MR: -（本地模式：不 push，分支留在 `.worktrees/dev2`）

## Deliverables

| Path | What |
|---|---|
| `skills/teamsmith/tests/smoke.sh` | ① 11e 的 `--as-user` 探针**本体落盘**（`$TMP/m32tty-as-user-probe.sh`），探针自己 `</dev/null`；② 新增 **11e2** 段：用 `script -qc` 造「stdin=真 pty / stdout=文件」的外框，跑**同一份字节**的探针，要求仍是「冒充」版 |
| `docs/team/reports/M32-dev2/pkg/{lib.sh,run.sh,10-mechanism.sh,20-gate-pty-fast.sh,30-audit.sh,40-gate-pty-full.sh}` | 独立证据包：机制（自建 scratch 项目 + 自写探针）/ 事故形状下的门禁 / 静态审计 / 全量 pty 门禁 / **就地翻转** |
| `docs/team/reports/M32-dev2.md` | 本报告 |

未改（按边界）：`scripts/**`（含 `cmd-meeting.sh` 的守卫语义）、review 侧 stdin 纪律（M25）、投递/巡检。

## 根因（确认 PM 的钉死结论）

`cmd-meeting.sh:285`：`if [ ! -t 0 ] && [ ! -t 1 ]; then 拒绝：「…agent 进程不得冒充用户…」else 走 TEAM_MEETING_ALLOW_USER_ID 分支`。
PM 在 tmux 窗口里 `bash smoke.sh > log` 时 stdin=pane pty → 判据为假 → 走 else 分支 → 拒绝理由里没有「冒充」→ `assert_has … "冒充"` 假红。

**测试断言不许依赖调用者的 fd 形状**：探针模拟的是「没有 tty 的 agent 进程」，所以 detach 必须是**探针自己的纪律**。

## Verification evidence (must have actually be run)

### 1) 验收①：`</dev/null` 姿势的全量门禁（openspec + 2076 条断言）

```
$ cd .worktrees/dev2 && PATH="$HOME/.bun/bin:$PATH" bash -c 'openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh </dev/null'
- Validating...
✓ spec/agent-adapters
✓ spec/board-and-status
✓ spec/watchdog
Totals: 14 passed, 0 failed (14 items)
…
== 11e2 · M32：--as-user 探针自 detach stdin（外部 stdin=pty 也必须绿） ==
  ✓ M32 夹具有效性：外框的 stdin 确实是 tty（script 真给了 pty）
  ✓ M32 夹具有效性：探针继承到的 stdin 是 tty（事故形状成立）
  ✓ M32 夹具有效性：探针的 stdout 是文件（与事故形状一致）
  ✓ M32：tty 外框下探针仍被拒绝（外部 tty 不会把它放行）
  ✓ M32：拒绝理由仍是「冒充」版（探针自己 </dev/null，与外部 fd 解耦）
  ✓ M32：没有滑到「需要 TEAM_MEETING_ALLOW_USER_ID」那条分支
== 结果 ==  ✓ 2076  ✗ 0
smoke 全绿
EXIT=0        （日志：/tmp/m32-accept1.log，作业 m32-gate-null，391s）
```

### 2) 验收②：快模式（FAST）

```
$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh
== 11e2 · M32：--as-user 探针自 detach stdin（外部 stdin=pty 也必须绿） ==
  ✓ M32：拒绝理由仍是「冒充」版（探针自己 </dev/null，与外部 fd 解耦）
  ✓ M32：没有滑到「需要 TEAM_MEETING_ALLOW_USER_ID」那条分支
== 结果 ==  ✓ 1643  ✗ 0        # 修复前基线 1638（+6 条 M32 断言，另有 1 条 12b-j 指纹行因真团队在跑而按约定降级为提示）
FAST 模式：跳过 20 个真进程段落（…）
smoke 全绿      EXIT=0
```

### 3) 验收③：**在 tmux 窗口里**跑全量门禁（stdin=pane pty、stdout 重定向到文件）

私有 socket（`env -u TMUX -u TMUX_PANE TMUX_TMPDIR=/tmp/m32-tmux-sock-*`），不碰默认 server：

```
$ tmux new-window -d -t m32-gate-$$ -n m32-gate "bash -c 'cd <worktree> && PATH=\$HOME/.bun/bin:\$PATH bash skills/teamsmith/tests/smoke.sh' > /tmp/m32-gate-tmux.log 2>&1; echo EXIT=\$? >> /tmp/m32-gate-tmux.log"
=== 外部形状（pane 自己记录的 stdin）===
pane_stdin=/dev/pts/54 pane_stdin_tty=yes          # ← 事故形状：stdin 是 pty、stdout 是文件
== 11e2 · M32：--as-user 探针自 detach stdin（外部 stdin=pty 也必须绿） ==
  ✓ M32：拒绝理由仍是「冒充」版（探针自己 </dev/null，与外部 fd 解耦）
  ✓ M32：没有滑到「需要 TEAM_MEETING_ALLOW_USER_ID」那条分支
== 结果 ==  ✓ 2076  ✗ 0
smoke 全绿      EXIT=0   GATE_OK          （日志：/tmp/m32-gate-tmux.log，作业 m32-gate-tmux，601s）
```

诚实说明一处**证据瑕疵**：那次跑的同时还有验收①的进程在收尾，我抓「跑着的 smoke 进程 fd0」的探针**误匹配**到了验收①的外层 `bash -c`
（`smoke_pid=2019734 smoke_fd0=/dev/null`），所以那两行**作废**。事后用同一种 tmux 外壳补抓了一次干净的 fd0（FAST 变体）：

```
$ tmux new-window … "WT_DIR=<wt> FD0_OUT=/tmp/m32-tmux-fd0.log SMOKE=<wt>/skills/teamsmith/tests/smoke.sh bash /tmp/m32-fd0-inner.sh > /tmp/m32-tmux-fast.log 2>&1; echo EXIT=\$? >> /tmp/m32-tmux-fast.log"
=== pane 自己看到的 stdin ===
pane_stdin=/dev/pts/45 pane_stdin_tty=yes
=== 门禁进程自己记录的 stdin ===          # 这个进程就是随后那份 smoke 的父进程，中间没有重定向 stdin
smoke_stdin_tty=yes smoke_stdin=/dev/pts/45
=== 门禁结果 ===
  ✓ M32：拒绝理由仍是「冒充」版（探针自己 </dev/null，与外部 fd 解耦）
== 结果 ==  ✓ 1643  ✗ 0
smoke 全绿      EXIT=0   GATE_OK
```

### 4) 独立证据包（PM 可直接复跑）

```
$ bash docs/team/reports/M32-dev2/pkg/run.sh --flip --pty-gate
M32 证据包
  被测树    ：…/worktrees/dev2/skills/teamsmith
  branch/tip：task/M32-smoke-tty-detach-stdin-pm-tm @ 3d72ba3
  smoke.sh  ：sha256=5908b403944cd1c3
  == 10 结果 == ok=10 bad=0 finding=0 skip=0        # 机制：A 门禁形状 / B 事故形状不 detach（红）/ C 事故形状 + detach（绿）
  == 20 结果 == ok=9 bad=0 finding=0 skip=0         # 事故形状下 FAST 门禁：✓ 1643 ✗ 0，5 条关键断言全绿
  == 30 结果 == ok=8 bad=0 finding=0 skip=0         # tty fd 清单 / heredoc 雷扫描 / 探针字节 / 本包不碰 tmux
  == 40 结果 == ok=4 bad=0 finding=0 skip=0         # 事故形状下**全量**门禁：✓ 2076 ✗ 0

  ok 被测树：0 个 bad
== 总结 == 证据成立     EXIT=0          （日志：pkg/logs/ 与 pkg/logs/flip/；作业 m32-pkg-ptygate，481s）
```

> `pkg/logs/` 是运行产物（几百 KB），按 `logs/.gitignore` 不入库 —— 复跑 `run.sh` 会重新生成；关键输出已在本报告里引用。

**证据对应关系**：三个验收姿势都跑在 `smoke.sh` 的最终版本上（`sha256=5908b403944cd1c3`，commit `3d72ba3`）；其后的提交
（`8925413`）只动 `docs/team/reports/**`（本报告 + 证据包），不改 `smoke.sh` 一个字节（`--flip` 跑完恢复后的 sha 也是这个值）。
M28 的 tmux 隔离 lint 会扫 `docs/team/reports/*/pkg`，最终 FAST 门禁里 `✓ M28 真树：变更类 tmux 调用全部有隔离证据` 已覆盖本包的脚本。

## Flip evidence

两条独立信道，都做了「红 → 绿」。**就地破坏实现 → 守门测试必须红 → 逐字节恢复**（`run.sh --flip`，秒级）：

```
$ bash docs/team/reports/M32-dev2/pkg/run.sh --flip
===== 翻转：就地拿掉探测点 </dev/null（破坏实现）→ 20 段必须红 → 恢复 =====
  · 结果行：== 结果 ==  ✓ 1640  ✗ 3
  bad  事故形状下 smoke 有失败项：✗ 拒绝理由说明了冒充（…/mtg-user.log 中找不到 [冒充]）
        ✗ M32：拒绝理由仍是「冒充」版（探针自己 </dev/null…）（…/m32tty-probe-tty.log 中找不到 [冒充]）
        ✗ M32：没有滑到「需要 TEAM_MEETING_ALLOW_USER_ID」那条分支（不该出现 [TEAM_MEETING_ALLOW_USER_ID]）
  bad  关键断言缺失或为红：拒绝理由说明了冒充
  bad  关键断言缺失或为红：M32：拒绝理由仍是「冒充」版（探针自己 </dev/null，与外部 fd 解耦）
  bad  关键断言缺失或为红：M32：没有滑到「需要 TEAM_MEETING_ALLOW_USER_ID」那条分支
  == 20 结果 == ok=4 bad=5 finding=0 skip=0
  ok 翻转成立：破坏实现后 20 段有 5 个 bad（修复前的形状会假红）
  ok 恢复：smoke.sh 与破坏前逐字节相同（sha256=5908b403944cd1c3）
== 总结 == 证据成立     EXIT=0
```

修复前（红）→ 修复后（绿），同一台机器、同一个形状，**机制**由本包自有探针独立钉住（`pkg/10-mechanism.sh`，不复用 smoke 夹具）：

```
  · B …/10-B-pty-inherit.log（rc=1）   # 事故形状 + 探针**继承** stdin（= 修复前）
  · C …/10-C-pty-detach.log（rc=1）    # 事故形状 + 探针自己 </dev/null（= 修复后）
  ok  B：事故形状下不 detach → 拒绝理由里**没有**「冒充」（假红的成因）
  ok  B：确实滑到了 TEAM_MEETING_ALLOW_USER_ID 那条分支
  ok  C：事故形状 + 自己 </dev/null → 仍是「冒充」版（断言与外部 fd 解耦）
  ok  C：没有滑到 TEAM_MEETING_ALLOW_USER_ID 分支
  ok  夹具有效性：外框（script）的 stdin 是 tty / 探针 stdin=tty / 探针 stdout=文件
  == 10 结果 == ok=10 bad=0 finding=0 skip=0
```

B 与 C 的差异**只有一个 token**（`</dev/null`），其余字节完全相同 —— 这就是「探针与外部 fd 解耦」的最小证明。

## 探针自查（deliverable 1 要求的扫描清单）

扫了哪些：`skills/teamsmith/scripts/lib/*.sh` + `scripts/team` + `extension/**`（全仓库找「按 fd 分流」的代码），
以及 `tests/smoke.sh` 里所有模拟 agent 进程的探针。

| 位置 | 是否按调用者 fd 分流 | 是否要 detach |
|---|---|---|
| `scripts/lib/cmd-meeting.sh:285` `[ ! -t 0 ] && [ ! -t 1 ]` | **是**（决定用哪条拒绝文案） | **是** —— 本任务修的就是它（11e 探针 + 11e2 回归） |
| `scripts/lib/common.sh:9` `[ -t 1 ]`（配色） | 是，但只决定 ANSI 码 | 否 —— 断言一律 `grep` 重定向后的文件，`team` 子进程的 stdout 是文件 → 配色本来就关；验收①②③ 里两种形状都 ✗ 0 已实证 |
| `scripts/lib/cmd-review.sh`（门禁 stdin） | M25 已强制 `/dev/null`（review 侧，不在本任务范围） | 否（不动） |
| 其它探针（dispatch/outbox/board/watch…） | 不看 fd；脚本里也没有任何交互式 `read -p` 提示 | 否 |

另外扫了「生成式夹具」的一类雷并修掉：**unquoted heredoc 里的反引号/`$( )` 会被冒烟脚本自己当真命令执行**。
我在 11e2 的外框脚本注释里写了 `` `bash smoke.sh > log` ``，结果 smoke 真的执行了 `bash smoke.sh > log`（在临时仓库里留下一行
`bash: smoke.sh: No such file or directory` + 一个 `log` 文件）。现在：外框脚本用 **quoted heredoc + 环境传参**；
`pkg/30-audit.sh` 有静态扫描（`unquoted=13 quoted=32 risky=0`）钉住这一类。

## Decisions and deviations

- **不动 `cmd-meeting.sh`**：守卫语义（人/agent 分工）是对的，错的是测试依赖外部 fd —— 与任务书边界一致。
- **11e2 用 `script -qc`（不是 tmux）**：tmux 窗口的 stdin 也只是 pane pty，`script` 在 fd 层面等价且不引入 tmux 依赖（快模式也能跑）。
  任务书说「做不到真 tty 时用 script -qc 兜底」—— 这里 script 就是**首选**，并把「形状真的成立」写成夹具有效性断言（拿不到 tty → 先红，不会假绿）。
- **探针本体落盘 + 两处共用同一份字节**：11e 与 11e2 跑的是同一个 `$TMP/m32tty-as-user-probe.sh`；
  谁把 `</dev/null` 拿掉，11e2 必红（翻转已实证）。
- 额外交付独立证据包（不是任务书硬要求）：`--strong` 复验需要可结构化复核的翻转 + 真实存在的包路径，
  且 PM 应能**自己**复现而不是只看我的日志；包内断言全部自写，smoke 只作为被测对象。
- 包内踩到的两个坑（都已修，记在这里免得后人重踩）：① 大日志 + `set -o pipefail` + `printf | grep -q` 会因 **SIGPIPE** 误判
  （断言改成 `grep 文件`）；② `grep -c` 无匹配时打印 `0` 且退出 1，`|| echo 0` 会拼出 `0\n0`（改为 `|| true` + 兜底）。
- `pkg/40-gate-pty-full.sh`（全量门禁的 pty 形状，约 6 分钟）是 opt-in：`run.sh --pty-gate`。

## Suggested next steps

- PM 复验：`team review M32 --strong`（门禁 + 结构化判定）；想自己复现翻转与事故形状：`bash docs/team/reports/M32-dev2/pkg/run.sh --flip`
  （秒级，会就地破坏/恢复 `smoke.sh`，要求该文件无未提交改动），全量 pty 版本加 `--pty-gate`。
- 这类「断言依赖调用者 fd 形状」的检查在别处没有发现第二处；若以后新增按 tty 分流的判据，记得同步更新
  `pkg/30-audit.sh` 的 tty fd 清单（它会把报告外的分流点报成 finding）。
- 无 `BLOCKED:` 项。
