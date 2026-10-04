# M36 · tmux 运行时闸门（destructive-call gate + call ledger）

agent: dev   status: DONE（待 PM 复验）   time: 2026-09-19T10:20Z
branch: `task/M36-tmux-path-server-kill-server`（local 模式：不 push，分支留在 `.worktrees/dev`）
change: -（规格无变更；运行时门卫 + 门禁）

## Deliverables

| Path | What |
|---|---|
| `skills/teamsmith/scripts/shim/tmux` | 闸门本体：名为 `tmux` 的 PATH 包装。每次调用记一行进 `$TEAM_TMUX_CALLS_LOG`（ISO 时间、解析出的 socket、`TMUX`/`TMUX_TMPDIR`、参数、pid/ppid/cwd、动作 pass/override/refused；超 2000 行留最新 1000 行，同目录临时文件 + mv，尽力而为不挡路，FIFO 目标直接跳过）。解析到**默认 socket**（`/tmp/tmux-<uid>/default`；解析顺序与 tmux 同源：`-S`/`-L` > `$TMUX` 第一个逗号前 > `${TMUX_TMPDIR:-/tmp}/tmux-<uid>/default`，尾斜杠归一，`-L default` 也算默认）的 `kill-server`/`kill-session`/`kill-window`/`kill-pane`（含 tmux 允许的前缀写法）→ 拒绝执行，stderr 醒目一行 + 给出两条出路，exit 64。`TEAM_ALLOW_DESTRUCTIVE_TMUX=1`（记 act=override）或私有 socket（记 act=pass）→ 原样 `exec` 真 tmux。只读命令（`ls`/`list-*`/`display-message`/`capture-pane`/`send-keys`…）从不拦。真 tmux = `TEAM_TMUX_REAL` 优先，否则 PATH 扫描跳过自己（防递归）；找不到 → exit 127 明说。**两条硬原则（返工后写入文件头）：透传保真（判定吃副本、执行透传原始 `$@`）与绝不挂住（缺值/无子命令/`-V` 全透传，由真 tmux 报错）** |
| `skills/teamsmith/scripts/lib/common.sh` | `team_tmux_shim_dir` / `team_tmux_real_bin` / `team_tmux_shim_exports` 三个助手；闸门 exports 前缀注入 `team_pm_launch_cmd`（内置 Pi 与 `TEAM_PM_CMD` 两条路）与 `team_agent_launch_cmd`（内置 Pi 与 `TEAM_AGENT_CMD` 两条路）——每条 PM/worker 窗口启动命令前缀三段 export：`PATH=<scripts/shim>:"$PATH"`、`TEAM_TMUX_CALLS_LOG=<渲染时解析出的 state/tmux-calls.log>`、`TEAM_TMUX_REAL=<渲染时解析的真 tmux>`。shim 文件不在 → 前缀为空，启动语义与以前逐字节一致（fail-open） |
| `skills/teamsmith/scripts/team` | 脚本顶部 `export TEAM_ALLOW_DESTRUCTIVE_TMUX="${…:-1}"`：team CLI 自己的 tmux 调用走显式放行通道（调用点全是仓库脚本，M28 lint 静态管束），但在装了闸门的窗口里照样逐条记日志（act=override）。该变量不进 tmux `update-environment`，agent 窗口不会继承它 |
| `skills/teamsmith/tests/smoke.sh` | ① 顶部卫生：`TEAM_ALLOW_DESTRUCTIVE_TMUX`/`TEAM_TMUX_CALLS_LOG`/`TEAM_TMUX_REAL` 计入「调用者身份」unset（M25 `TEAM_REVIEW_*` 同族），smoke 自己的 shim 日志指到 `$TMP`（真项目账本零污染）；② 6i `LEGACY_REF` 更新为「M36 前缀（字面写死）+ 历史那条逐字节不变」；③ 6 段 print 断言、6j render 诊断断言适配新命令形状；④ 新段 **31c**（见下） |
| `docs/team/reports/M36-dev.md` | 本报告 |

提交序列：`bfa52d7`（shim + 注入 + team 内部放行）→ `ab21306`（smoke 31c + 卫生 + 断言适配）→ `dae295a`/`fc38522`（报告 + 分支名更正）→ **返工**：`dfa5ba2`（shim 两必修）→ `587ed03`（31c ①b 钉子）→ 本报告更新。
门禁/翻转证据跑的就是分支 tip 上的文件。

## 31c 段设计（为什么这样测才安全）

- 「拒绝/override/只读」探针的 PATH 里，shim 之后放的是**桩 tmux**（只记 argv 的假命令）——就算闸门逻辑整个坏掉，被执行的也只是桩，**结构上**碰不到真默认 server；
- 「真杀」只在 `$TMP` 内的私有 server 上做（`TMUX_TMPDIR=<私有>`，M23 同一机制）；
- 段首/段尾各探一次默认 server（只读 `ls`）：它若死在本段运行期间，本段如实报红当第一现场；
- **翻转控制常驻门禁**：同一条 `kill-server` 探针、PATH 里拿掉 shim → 直通桩（rc=0）——证明拒绝断言钉的是 shim 本身（shim 文件被删时同理：探针落到桩，exit 就不是 64）。
- 段内一个教训实录：初版探针把 `TMUX="/tmp/tmux-<uid>/default,12345,0"` **字面**写进 smoke 顶层命令，M28 lint 的文件级白名单（口径 D）有一条「又把 TMUX 指回默认 socket → 白名单失效」规则，把我的探针行判成「白名单失效」、同段后面三条既有形状的 `kill-window` 全部报红 —— lint 在工作。改成引用 `$M36_DEF_SOCK` 变量后恢复绿（探针语义不变）。

覆盖清单（对应 brief）：三态（拒绝四子命令 + 前缀写法 + TMUX 指默认 + `-L default`；override；`TMUX_TMPDIR`/`-L`/TMUX 三种私有写法）、只读不拦、日志全字段 + 2000 行截断（留最新 1000）、四条注入渲染断言（PM/worker × 内置/模板）、真私有 server 起杀 ×2、worker/PM 窗口 env 端到端（真派单 + 真 `team up`，env 里验 PATH 前缀/日志路径/真 tmux 路径；worker 窗口里的一次 ad-hoc `tmux ls` 确实被记进 fixture 的 `state/tmux-calls.log`）、默认 server 前后探活。

## 门禁原文结果（最终，返工后；第一轮数字见 §返工）

调用者机器上有一个活着的默认 server（session `teamsmith`，2026-09-19 08:49:27 创建）：
门禁前 `tmux ls` → `teamsmith: 7 windows (created … 08:49:27 2026) (attached)`；
两轮门禁后 `tmux ls` → `teamsmith: 3 windows (created … 08:49:27 2026) (attached)` —— **同一 server 实例全程活着**（窗口数变化是其它 worktree 自己的窗口起落）。

```
$ openspec validate --all --strict
Totals: 14 passed, 0 failed (14 items)          # VALIDATE_RC=0（返工未动 openspec/）

$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh   # 锁排队后
== 结果 ==  ✓ 1717  ✗ 0                          # FAST_RC=0（①b 24 条新断言全绿）

$ bash skills/teamsmith/tests/smoke.sh                      # 全量，锁排队后
== 结果 ==  ✓ 2168  ✗ 0
smoke 全绿                                       # FULL_RC=0
# 31c 全绿：三态/日志/截断/注入/翻转控制 + ①b（不挂绊线×11、透传保真×9、FIFO×2、
# -S 拒绝）+ 真私有 server 生死 + worker/PM 窗口 env 端到端（均实际运行非跳过）
```

（全文日志当时在 `/tmp/m36r-fast.log` / `/tmp/m36r-full.log`；关键段摘录如上，PM 复验会独立重跑。）

## 翻转实录（最终，返工后第二轮；brief 要求）

```
$ mv skills/teamsmith/scripts/shim/tmux /tmp/m36-shim-away2
$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh
== 结果 ==  ✓ 1682  ✗ 35                         # FLIP_RC=1（红）
  ✗ 闸门 shim 文件在（scripts/shim/tmux）        ← 第一条断言必红 ✓
  ✗ shim 不可执行
  ✗ 裸 tmux kill-server（解析到默认 socket）被拒：exit 64（期望 [64]，实际 [0]）
  ✗ 拒绝文案点名子命令与默认 socket
  ✗ 拒绝路径不执行任何东西（桩没被叫）（stub-calls 不该存在）  ← 没有 shim 时调用真的落地（落桩）
  ✗ kill-session/kill-window/kill-pane 同样被拒（期望 [ 64 64 64]，实际 [ 0 0 0]）
  ✗ TMUX 指向默认 server 也拒 / -L default 也算默认 / -S <默认路径> 同样拒 / 前缀写法也拒（全 rc=0）
  …（日志字段/截断/注入渲染断言共 35 条全红）

$ mv /tmp/m36-shim-away2 skills/teamsmith/scripts/shim/tmux && chmod +x …
$ git status --short → 干净；git diff → 空      # 恢复后与全绿那轮逐字节一致
```

恢复后工作树与通过全量门禁的提交（`587ed03`）逐字节一致（`git diff` 为空），未再重跑第三轮全量门禁（同一批字节）。另注：shim 移除时 6i 的 `LEGACY_REF` 断言在全量模式下也会红（前缀字面写死在参考值里）——双保险。有趣的一点：①b 的「透传保真」断言在 shim 缺席时反而**绿**（桩自己逐字节收全 argv）——保真钉的是「shim 在场时不弄丢旗标」，拒绝钉的才是「shim 在场」，两类断言互补，翻转时由后者红。

## §返工 · PM 复验发现的挂死 + 自查出的透传失真（第一轮交付 → 第二轮修复）

**发现（PM 复验报送）**：我 09:33 的一条手工边界测试（`tmux -L` 缺值）死循环空转了 100 分钟，PM 清理。

**根因 1（挂死，PM 报送项）**：shim 解析循环里 `-L) _sockname="${2:-}"; shift 2` —— `$#=1`（缺值）时 `shift 2` 失败、参数不动、`while` 原地打转。`tmux -L`/`-S`/`-c`/`-f`/`-T` 缺值全部中招。

**根因 2（透传失真，我在复查时自查出来，事故级）**：旧 shim 末尾 `exec "$_real" "$@"` 用的是**被解析循环 shift 过**的 `"$@"` —— `tmux -L priv kill-server` 会把 `-L priv` 吃掉再 exec，**判定打私有、执行打默认**，正是闸门要防的全灭形状。第一轮 31c 没抓住它的原因也如实记录：断言用子串匹配桩输出，而桩收到的「被吃剩的 argv」恰好匹配子串（`'^kill-server$'`）——钉得太弱。

**修复（`dfa5ba2`）**：① 解析移进 `_parse_globals`（函数位置参数 = 副本），每个 `shift 2` 先 `[ $# -ge 2 ] || break` —— 缺值/无子命令/`-V` 全部透传给真 tmux 自己报错，每条循环路径要么 shift ≥1 要么 break；② 判定吃副本、执行透传原始 `$@`，逐字节保真（写进 shim 文件头当硬原则）；③ 日志目标是 FIFO 时跳过记录（写端会阻塞）——账本绝不能挂住调用。

**新钉子（`587ed03`，31c ①b）**：每条边界探针套 10s 超时（挂死回归 → rc=124 直接红）：缺值 ×5、`-V`、无参数、`-2 -v` 开关、`-L`/`-S` 带值；保真断言钉桩收到的**完整 argv**（整文件等值）；日志记原始完整 argv；`-S <默认路径>` 拒绝针；FIFO 不阻塞针。另有一个工程细节：`timeout` 必须放在探针 `env` 里面（shell 函数对 `timeout` 不可见）。

**证据**：修复前本地复现 —— `tmux -L privsock kill-server` 桩只收到 `kill-server`（旗标被吃坐实）；`tmux -L` 缺值 5s 超时 rc=124（死循环坐实）。修复后桩矩阵 9/9，随后 FAST ✓1717 ✗0 / FULL ✓2168 ✗0 / 翻转第二轮 35 红含首条断言。

**第一轮存档数字（已被上文取代，仅留痕）**：openspec 14/14；FAST ✓1693 ✗0；FULL ✓2144 ✗0；翻转 33 红。

## 关键设计决定（备查）

1. **注入点是渲染出的启动命令，不是 `tmux set-environment`**：窗口 harness 是 `bash -lc`，登录 profile 会把 PATH 重建成系统默认（M23 实测），只有 harness 里显式 export 活得到里层。模板路径（`TEAM_PM_CMD`/`TEAM_AGENT_CMD`）也带前缀（在 harness inner 里、模板展开之前）。
2. **fail-open**：shim 缺失 → 空前缀、启动语义不变（gate 是门卫不是命门；31c 的 assert_file + 翻转控制钉存在性，PM 复验独立再钉一次）。
3. **team CLI 内部放行但不匿名**：`TEAM_ALLOW_DESTRUCTIVE_TMUX=1` 只解「拒绝」，日志照样记（act=override）；变量不进 `update-environment`，agent 窗口拿不到它（agent 要放行必须显式写，留下 override 痕迹）。
4. **`send-keys` 算只读**（brief 原话）：不拦、记日志。它只是打字；目标守卫（M11d 的跨 session 拒打）独立存在、不受影响。
5. **嵌套 PATH shim 先到先得**（brief 明示可接受）：窗口里 agent 自己再往 PATH 前面放 tmux 包装会绕过闸门 —— 与 lint 的盲区同级别，见「已知限制」。
6. **`TEAM_TMUX_REAL` 也写进窗口 env**：渲染时从**调用者** PATH 解析真 tmux（跳过 shim 自己），窗口登录 PATH 再怪（M8.1 那类）也不会递归或找不到真身。

## 已知限制 / 建议后续（供 PM 定夺，不在本任务范围）

- **pulse/monitor 窗口不在闸门内**（brief 圈定 PM 与 worker）。pulse 窗口跑的是 `team monitor`（team CLI 进程），其 tmux 调用走内部放行通道；窗口本身 PATH 无 shim，窗口里的手工命令不记日志。
- **合并前已在跑的旧窗口不带闸门**：闸门随窗口启动命令注入，已存在的窗口（包括当前这个 dev 窗口）保持旧环境；新派单/重启的窗口自动带闸门。
- **agent 在自己窗口里再往 PATH 前塞一个 tmux 包装**会绕过闸门（先到先得）。要堵需要更深的挂载（如 alias 审计或 wrapper 链标记），成本/收益不成比例，建议只在事故后再评估。
- **M28 lint 对「文件内自定义隔离包装」是盲区**（它只认登记过的 wrapper/白名单）：31c 自己的 `m36_probe`/`m36_priv` 就是例子（它们确实隔离，lint 不判也不拦）。这与 M28 既有口径一致，未改动。
- `references/agent-adapters.md` 与 `CHANGELOG.md` 属 PM 目录，未动。建议 PM 侧补一句：M36 起所有 PM/worker 窗口启动命令带 tmux 闸门 exports 前缀（`references/agent-adapters.md` 第 10 行那行的注脚级别即可），版本号/CHANGELOG 一并由 PM 定。

## 自检（对应 brief 的非功能要求）

- [x] 门禁两个命令都跑过且原文结果在上文（含锁排队后的真实跑完）
- [x] 翻转一次（移除 shim → 33 红含首条断言）+ 恢复（git diff 为空）都记了
- [x] 默认 server 前后 `tmux ls` 记录在上文（同一实例全程活着）
- [x] 未改 PM 的 `docs/team/tasks/M36-*.md`；未动 PM 目录（references/templates/SKILL.md/CHANGELOG）
- [x] 未 push（local 模式），分支 `task/M36-tmux-path-server-kill-server` 留在 `.worktrees/dev`
