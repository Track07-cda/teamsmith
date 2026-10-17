# P311 · `tmux-identity-scope` 的最后两格：改动前基线冻结 + §32 门禁接线

agent: dev-bob   status: delivered（两格都落地；`--select 32` 在 tip 上的那一次排队未轮到，见文末「交付时的树」）   time: 2026-10-17
branch: `task/P311-tmux-identity-wiring`   PR/MR: -（本仓 local 模式，分支留本地）

## 答案先说

1. **0.3 的基线有主了**：改动前那棵树是 `637b7ae0`（= `a1a53292^`，「V48 round 2 dispatched」；本 change 的第一个产品提交
   `a1a53292` 之前），`v0.2.0`（`7e2fa494`）是它的祖先。在这棵树上实测到的改动前读数是：`team up`（stub PM）之后
   server 全局环境 **11 个**本项目 `TEAM_*`、本项目**会话作用域 0 个**；项目 B 的新 pane 继承同样 11 条；在 B 目录跑
   `team up` → **rc=1 + `身份冲突被拒`**、会话集合逐行未变；`smoke.sh --select 32` = **✓72 ✗0**（10s，wall 14.48s）。
   把今天的夹具放到这棵旧树上跑（新夹具 × 旧产品）→ **✓40 ✗24 rc=1**，①c/①d 点名「期望 [0]，实际 [11]」并逐条列出
   11 个泄漏变量 —— 这就是 0.3 想要的「改动前读数」，而且它是夹具自己给的，不是事后叙述。
2. **1.6 接上了，并且是带牙的**：`smoke.sh` §32 新增 ⑨ 块，全量模式跑 `tests/tmux-identity-leak.sh --all`；FAST 下
   **可见 SKIP**；夹具 `rc=77`（跳过不是通过）、夹具缺失、夹具没打出结果行，三种形状**都判红**。`--select 32` 从
   改动前的 **✓72 ✗0 / 10s** 变成 **✓73 ✗0 / 35s**（多出来的那一条就是夹具的收口行，夹具内部的 66 条在它自己的日志里）；
   `section-paths.tsv` 的 §32 行补了 `common.sh` 与夹具路径；`section-budgets.tsv` 的 §32 行按实测重填
   **35.00 / 140**（host 35s×2、container 27s；`--budget-check` 135/135 通过）。
3. **红侧三条在变体树/变异表上验过**（真树零改动）：删 §32 → `--select 32`「未知 key：32」+ `--check` 点名；
   夹具文件不在 → `--select 32` 红 + `--check` 点名缺的字面模式；patterns 去掉 `common.sh` → 改 `common.sh` 不再选中 32；
   （第 4 条「夹具报 `rc=77` → 红」是代码判断、没有用变异臂验，理由见 Flips 段末。）原始输出见
   `docs/team/reports/P311-dev-bob/logs/red-sides.log`。

## Deliverables

| Path | What |
|---|---|
| `skills/teamsmith/tests/smoke.sh` | §32 新增 ⑨ 块：全量跑 `tests/tmux-identity-leak.sh --all`；FAST 可见 SKIP；`rc=77`/夹具缺失/无结果行都判红（并印出夹具自己的 ✗） |
| `skills/teamsmith/tests/section-paths.tsv` | §32 行 patterns 补 `skills/teamsmith/scripts/lib/common.sh` 与 `skills/teamsmith/tests/tmux-identity-leak.sh`（basis 同步） |
| `skills/teamsmith/tests/section-budgets.tsv` | §32 行按实测重填：host 35.00（14.7/15.0/?）、container 27.00（17.0）、band 35.00、budget 140、ci `-`，并把追测记录写进表头 |
| `openspec/changes/tmux-identity-scope/tasks.md` | 0.3 与 1.6 按事实勾上，各带证据 |
| `docs/team/reports/P311-dev-bob.md` | 本报告 |

证据层（`.gitignore` 的 `docs/team/reports/**`，不入库）：`logs/baseline-0.3.log`（改动前基线原始输出）、
`logs/baseline-fixture.log`（旧树上既无夹具、以及新夹具 × 旧产品的红）、`logs/fixture-today.log`（今天的夹具 `--all`）、
`logs/measure-host.log`（host / container 的 §32 计时）、`logs/fast32.log`（FAST 的可见 SKIP）、
`logs/red-sides.log`（四条红侧）、`logs/acceptance.log`（验收命令与输出尾）。

## 0.3 · 改动前的基线（冻结那棵树，不冻结时间）

**点名的树**：`637b7ae0 docs(team): V48 round 2 dispatched [skip ci]` = `a1a53292^`。
取法：`git archive 637b7ae0 | tar -x` 到私有临时根 → `git init` → 一次性提交（不与本仓共享 `.git`，也不可能被本分支影响）。
`v0.2.0` 是它的祖先（`git merge-base --is-ancestor v0.2.0 637b7ae0` → 是），所以「`v0.2.0` 或落地前最后一个提交」两者在
本次取的是后者：它就是 `tmux-identity-scope` 落地前的那个提交。

### ① 机制探针（私有 socket 岛）

```
1a 启动者 TEAM_PROJECT=leaky 起 server 后 全局环境 TEAM_* 条数：1
1a 全局环境里的值：TEAM_PROJECT=leaky
1b 另一个客户端（TEAM_PROJECT=second）新建 session 后 全局环境：TEAM_PROJECT=leaky
1b mech2 的 pane 环境（继承自全局环境，不是发起调用的客户端）：
    TEAM_PROJECT=leaky
1c new-session -e TEAM_PROJECT=scoped 之后 全局环境 TEAM_* 条数：1（-e 不动全局环境）
1c mech3 会话作用域 TEAM_* 条数：1（-e 写会话作用域）
1d 空岛上的 list-sessions rc=1，kill-server rc=1；岛里有没有 socket 文件：0 个（0 = 没建 socket）
```

结论：`new-session` 把**启动者**的环境写进全局环境；`-e` 只写会话作用域；`list-*`/`kill-*` 在不存 server 时既不连也不建。

### ② 真 CLI：`team up`（stub PM）+ 数一遍全局环境与会话作用域

```
init rc=0
up rc=0
2a server 全局环境 TEAM_* 条数：11
    TEAM_ASSUME_YES=0
    TEAM_CONFIG_FILE=
    TEAM_MAIN_ROOT=/tmp/…/A
    TEAM_PI_BIN=/definitely-not-pi
    TEAM_PM_BIN=/tmp/…/stub-pm.sh
    TEAM_PM_CMD=/tmp/…/stub-pm.sh
    TEAM_PROJECT=A
    TEAM_ROOT=/tmp/…/A
    TEAM_SESSION=base-…
    TEAM_TMUX_CALLS_LOG=/tmp/…/A/.pi/team/state/tmux-calls.log
    TEAM_TMUX_REAL=/usr/bin/tmux
2b 本项目会话作用域 TEAM_* 条数：0
```

**与提案里的 12 的差别，说清楚**：提案「现状复核」第 2 条在同一机制上数到 **12**，因为它那次调用者环境里还钉了
`TEAM_SIGNAL_CALLS_LOG` / `TEAM_SIGNAL_REAL` 两条闸门变量；本次探针的 pin 集合里换成 `TEAM_PI_BIN`，也没有 signal 两条。
机制是同一个（「调用者环境 → 全局环境」），条数取决于调用者钉了哪几把桩。两次读数都指向同一件事：
**全局环境里是本项目的身份，会话作用域里一个都没有**。

### ③ 受害面：项目 B 的 pane + 在 B 目录跑 `team up`

```
3a 项目 B 新 session 的 pane 里 TEAM_* 条数：11（同一批值）
3b 在 B 目录跑 team up：rc=1
    拒绝措辞命中：身份冲突被拒
    ✗ 身份冲突被拒（up）：当前目录属于 'B'，而继承的环境指向别的项目
      TEAM_ROOT=/tmp/…/A（继承） ≠ /tmp/…/B（按目录推导）
      TEAM_MAIN_ROOT=/tmp/…/A（继承） ≠ /tmp/…/B（按目录推导）
3c 拒绝前后 server 上的 session/window 快照：
    前：base-…；前：baseB-…
    后：base-… [pm ]；后：baseB-… [tmux ]
    结论：会话集合逐行相同（被拒的 team up 什么都没建）
3d 全局环境在 ③ 之后 TEAM_* 条数：11
```

### ④ `smoke.sh --select 32` 改动前

```
#6 32 · 身份 = 运行时目录（M40：继承的 TEAM_* 不许静默赢过 cwd） · 用时 10s · ✓72 ✗0 SKIP0 · ticks 72
== 选段结果 ==  ✓ 131  ✗ 0
wall=14.48s  rc=0
```

### ⑤ 夹具在改动前那棵树上

```
$ cd /tmp/…/tree && bash skills/teamsmith/tests/tmux-identity-leak.sh --all
bash: skills/teamsmith/tests/tmux-identity-leak.sh: No such file or directory
rc=127
```

夹具是 P274/P304 写的，改动前的树上不存在 —— 所以「夹具在改动前的读数」只能这样取：把**今天的夹具**放进同一棵树。

```
$ cd /tmp/…/tree && bash skills/teamsmith/tests/tmux-identity-leak.sh --all    # 新夹具 × 旧产品
  ✓ ①a 夹具项目 init 成功
  ✓ ①b 泄漏形状下 team up 跑完
  ✗ ①c server 全局环境里本项目 TEAM_* 条数（期望 [0]，实际 [11]）
       ↑ 泄漏：TEAM_ASSUME_YES=0 … ↑ 泄漏：TEAM_TMUX_REAL=/usr/bin/tmux      （11 条逐条点名）
  ✗ ①d 同一 server 上项目 B 的 pane 里 TEAM_* 条数（期望 [0]，实际 [11]）
  ✗ ②a 本项目会话作用域里的 TEAM_* 条数（期望 [4]，实际 [0]）
  ✗ ⑤c 残留形状下 team up 退出码 0（自愈：不再拒绝）（期望 [0]，实际 [1]）
  ✗ ⑦b 点名残留变量 TEAM_ROOT（…里找不到 [TEAM_ROOT=…/leakB]）
  …
== tmux-identity-leak 结果 ==  ✓ 40  ✗ 24
rc=1
```

这就是 0.3 真正要的东西：同样的夹具、同样的命令，在改动前的树上 **24 条红**（写侧泄漏 11 条、会话作用域 0 条、
读侧自愈与 doctor 残留行整组缺失），在今天的树上是 **0 条红**（见下面验收）。

### ⑥ 没有碰真实 server

私有 socket + 私有 fixture 项目，前后各取一次**默认 socket** 的会话列表，逐字节相同（那一行是另一个项目的会话名，按账本禁令不写进仓库，只保留窗口数与创建时刻作为同一性证据）：

```
=== 默认 socket 读数（跑前）===          === 默认 socket 读数（跑后）===
<另一个项目的会话> 3 1792219500             <另一个项目的会话> 3 1792219500
teamsmith 5 1792219263                    teamsmith 5 1792219263
```

探针自己也在起跑时把继承的 `TEAM_*` 与 `TMUX*` 全摘掉（第二版加的：第一版把调用者的 8 条身份变量算进了 ① 的读数，
日志里留着那次读数 8 → 修掉后是 1，两次都在 `logs/baseline-0.3.log` 的修订记录里）。

## 1.6 · §32 门禁接线

### 接线本身

`smoke.sh` §32 末尾新增 ⑨ 块（`skills/teamsmith/scripts/lib/…` 一个字节没动，本任务只碰 `tests/`）：

- 全量模式：`bash "$SKILL_DIR/tests/tmux-identity-leak.sh" --all`，解析它最后那行 `== tmux-identity-leak 结果 == ✓66 ✗0`；
  rc=0 且结果行存在 → `ok`；否则 `bad` 并把夹具自己的 ✗ 行（前 8 条）印在段里，不用翻日志；
- `rc=77`（P308 的「跳过不是通过」）→ **红**，并把它那句原文打出来：接上之后「机器上没有 tmux」不会假绿；
- 夹具文件不在 → 红（点名路径），不是静默跳过；
- FAST 模式 → `fast_skip`（可见 SKIP，收尾的 FAST 汇总里也会列名）。

### 实测（三条：host ×2、门禁镜像 ×1）

```
--- host run 1（loadavg1 14.69/32 核）
#6 32 … · 用时 35s · ✓73 ✗0 SKIP0 · ticks 73
  ✓ 32⑨ 身份作用域夹具全绿（✓ 66  ✗ 0）
== 选段结果 ==  ✓ 132  ✗ 0          rc=0 wall=40s
--- host run 2（loadavg1 15.02）
同上：用时 35s · ✓73 ✗0；✓ 32⑨ …（✓ 66 ✗ 0）；== 选段结果 == ✓ 132 ✗ 0；wall=41s
--- container（localhost/teamsmith-gate:local 1d723525ee58，镜像里 tmux 在 /usr/local/bin）
/usr/local/bin/tmux · tmux 3.7b
#6 32 … · 用时 27s · ✓73 ✗0 SKIP0 · ticks 73
  ✓ 32⑨ 身份作用域夹具全绿（✓ 66  ✗ 0）
rc=0 wall=33s（loadavg1 16.98）
```

**本机 tmux 可用的证据**：宿主 `/usr/bin/tmux -V` → `tmux 3.7b`，夹具的 ⓪ 前提行也是
`✓ ⓪ 夹具给的 PATH 让闸门解析到真 tmux（/usr/bin/tmux）并执行成功 —— tmux 3.7b`；镜像里是
`/usr/local/bin/tmux` → `tmux 3.7b`。（注意 `command -v tmux` 在这个席位里解析到的是产品闸门
`skills/teamsmith/scripts/shim/tmux`，所以「本机 tmux 可用」这条一律用**绝对路径**取证据。）

FAST 下的可见跳过：

```
SKIP（FAST 模式） 32⑨·身份作用域夹具（真 tmux） —— 要真 tmux server 与真窗口（全量门禁跑）
#6 32 … · 用时 4s · ✓54 ✗0 SKIP2 · ticks 56
FAST 模式：跳过 2 个真进程段落（32⑧·spawn 清洗（真窗口）|32⑨·身份作用域夹具（真 tmux））——完整门禁请不带 TEAM_SMOKE_FAST 重跑
```

### 预算表（按实测重填，规则不变：budget = max(ceil(band×4), 60)，band = max(host, container, ci)）

| 列 | 旧值（P70，接线前） | 新值（P311 实测） |
|---|---|---|
| host | 9.00 | 35.00（run1 35s / run2 35s） |
| budget | 60 | 140 |
| band | 9.00 | 35.00 |
| loadavg1 | 10.6/?/14.0/10.5 | 14.7/15.0/? |
| container | 8.00 | 27.00 |
| container loadavg1 | 12.9 | 17.0 |
| ci | - | -（local 模式不 push） |

```
$ bash skills/teamsmith/tests/section-guard.sh --budget-check
ok: 预算表覆盖 135/135 个 section 且每行都满足 max(ceil(band×4), 60)
section-guard --budget-check: 全过
$ bash skills/teamsmith/tests/section-guard.sh --loop-check
ok: 扫描 86 行清单 / 86 个 while+sleep 循环，配平 86 个
```

### 选段表

`section-paths.tsv` 的 §32 行补两条：`skills/teamsmith/scripts/lib/common.sh`（夹具与段都读它 —— 改它必须重跑 §32）
与 `skills/teamsmith/tests/tmux-identity-leak.sh`（`--check` 的 token 方向要求：段正文里点名的真实路径必须被本行 patterns 覆盖）。

```
$ bash skills/teamsmith/tests/section-select.sh --paths skills/teamsmith/scripts/lib/common.sh
decision=RUN
sections=135
keys=44
reason=2 ← skills/teamsmith/scripts/lib/common.sh, needs:11f, needs:11h, needs:26, needs:32, needs:42, needs:43, needs:5, needs:4
reason=32 ← skills/teamsmith/scripts/lib/common.sh
$ bash skills/teamsmith/tests/section-select.sh --check
ok: 段 ↔ 行一一对应（源码 135 段 / 表 135 行）
ok: 段正文点名的真实路径 token 都被各自的行覆盖（523 个 token 检查过；0 个豁免类 token 不参与）
== 选段自检 ==  ok 8  bad 0  SKIP 1
```

## Flips：红侧四条（真树零改动）

驱动脚本：`docs/team/reports/P311-dev-bob/logs/p311-red-sides.sh`（变体树：真 `.git`、产品面软链、`tests/` 逐文件软链，
只有 `smoke.sh` / `section-paths.tsv` 是真副本 —— 照 `tests/flip-p158.sh` 的形状）。原始输出：`logs/red-sides.log`。

| 臂 | 变异 | 必须红的地方 | 实测 |
|---|---|---|---|
| 对照 | 无（真树） | `--check` 绿、`--paths common.sh` 选中 §32 | `--check rc=0（ok 8 bad 0 SKIP 1）`；`reason=32 ← skills/teamsmith/scripts/lib/common.sh` |
| A（红侧①的后半） | 把 §32 整段从 `smoke.sh` 删掉 | `--select 32` 不再跑夹具 + 选段审计发现 | `--select 32` **rc=2「未知 key：32」**，日志里没有夹具结果行；`--check` **rc=1**，`bad: 表里有 key 在源码里找不到：32` |
| B（红侧①的前半） | 夹具文件不在（§32 的调用点还在） | `--select 32` 红 + 审计点名缺的路径 | `--select 32` **rc=1「32⑨ 缺 tests/tmux-identity-leak.sh」**；`--check` **rc=1**，`bad: 行 32 的字面模式在工作树里不存在：skills/teamsmith/tests/tmux-identity-leak.sh` |
| C（红侧②） | §32 行 patterns 去掉 `common.sh` | 改 `common.sh` 时 §32 不再被选中 | 变异前 `reason=32 ← …common.sh`；变异后**没有** `reason=32`（rc=0），其余声明 `common.sh` 的段照常选中（`reason=2 ←`） |

```
== P311 红侧结果 ==  全绿   （三条臂 + 对照全部按预期；redsides_rc=0）
```

**第 4 条没验，说清楚**：⑨ 块里还有一条「夹具 `rc=77` → 判红」的分支（P308 的「跳过不是通过」，也就是本机没有 tmux 时的形状）。
它是三行判断，我**没有**用变异臂验过：验它要跑全量模式的 §32，而全量模式要排门禁锁 —— 当时另一个席位的一整套全量门禁在跑，
我的 `--select 32` 排队 7 分钟没轮到就撤了（见文末）。**能证明的是**：夹具自己在没有 tmux 时确实返回 77（P308 的报告 +
`tests/flip-p308-*.sh`），而 ⑨ 块只在这一个条件上判绿 —— `rc=0` **且**结果行存在；`rc≠0` 一律红（缺夹具那条臂验的就是
`rc≠0` → 红这条通路）。

### 另一条翻转：同一夹具，旧产品 ↔ 新产品

| 树 | 命令 | 结果 |
|---|---|---|
| `637b7ae0`（改动前）+ 今天的夹具 | `tmux-identity-leak.sh --all` | **✓ 40 ✗ 24**，rc=1（①c/①d 期望 [0] 实际 [11]；②a 期望 [4] 实际 [0]；⑤c/⑦b 读侧整组缺失） |
| 今天的树 | 同上 | **✓ 66 ✗ 0**，rc=0（23.15s） |

## Verification evidence（真跑过的命令与输出尾）

```
$ bash skills/teamsmith/tests/tmux-identity-leak.sh --all
  ✓ 隔离：真实仓库账本面未被改动（docs/team/inbox + .pi/team/state，0 个文件逐一 sha256 相同）
  ✓ 隔离：本轮的临时根已回收（跑前 1 个同族根 → 跑后 0 个）
== tmux-identity-leak 结果 ==  ✓ 66  ✗ 0
rc=0  wall=23.15s
```

```
$ bash skills/teamsmith/tests/smoke.sh --select 32
  ✓ 32⑨ 身份作用域夹具全绿（✓ 66  ✗ 0）
#6 32 · 身份 = 运行时目录（M40：继承的 TEAM_* 不许静默赢过 cwd） · 用时 35s · ✓73 ✗0 SKIP0 · ticks 73
== 选段结果 ==  ✓ 132  ✗ 0
rc=0  wall=40s / 41s（两次，loadavg1 14.7 → 15.0）
```

（上面这条是在 `aa2572f0` 上取的；交付 tip 上那一次排队没轮到 —— 差别与覆盖它的证据见文末「交付时的树」。）

```
$ bash skills/teamsmith/tests/section-select.sh --paths skills/teamsmith/scripts/lib/common.sh     # 见上面「选段表」
$ bash skills/teamsmith/tests/section-guard.sh --budget-check                                     # 135/135 全过
$ bash skills/teamsmith/tests/section-guard.sh --loop-check                                        # 86/86 配平
$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh --select 32                               # 32⑨ 可见 SKIP，rc=0
```

- Verdict: 夹具 `--all`、§32 接线、选段表、预算表、`--budget-check`、`--loop-check`、四条红侧：**pass**。
- 没验的：完整门禁（135 段）本轮**没有**全量跑 —— 本任务只改 `tests/` 里的接线与两张表，按「按改哪选哪段」的规矩
  只跑 §32 与两张表的自检；PM 复验时若要全套，另计时间。`ci` 列留空（local 模式不 push）。
- 台账禁令（固定验收行，在本 worktree 的本分支树上跑）：

```
$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: root=…/.worktrees/dev-bob scope=published files=1741 hits=0 names=ok user=resolved
$ echo $?
0
```

  第一次跑这一行时它**红了**（`hits=1`）：报告里引用的默认 socket 读数带上了另一个项目的会话名（名单里有的那个）。
  改法是把那一行的会话名换成占位符、保留窗口数与创建时刻作同一性证据；改完 `hits=0`。

## 交付时的树

交付 tip 只比 `7b9b0ad5` 多两件：`openspec/changes/tmux-identity-scope/tasks.md` 的两个勾与本报告。这一组轻验收在
**本报告已是最终文本**的树上跑（`logs/acceptance.log`）：

```
$ bash skills/teamsmith/tests/tmux-identity-leak.sh --all
  ✓ 隔离：真实仓库账本面未被改动（docs/team/inbox + .pi/team/state，0 个文件逐一 sha256 相同）
  ✓ 隔离：本轮的临时根已回收（跑前 1 个同族根 → 跑后 1 个）
== tmux-identity-leak 结果 ==  ✓ 66  ✗ 0
rc=0  wall=23s

$ bash skills/teamsmith/tests/section-select.sh --paths skills/teamsmith/scripts/lib/common.sh
decision=RUN · sections=135 · keys=44 · reason=32 ← skills/teamsmith/scripts/lib/common.sh      rc=0

$ "$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
Totals: 21 passed, 0 failed (21 items)                                                          rc=0

$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: root=…/.worktrees/dev-bob scope=published files=1741 hits=0 names=ok user=resolved   rc=0

$ git diff --check                                                                              rc=0
$ git status --short      →  「M openspec/changes/tmux-identity-scope/tasks.md」「?? docs/team/reports/P311-dev-bob.md」
```

最后那两行就是本节这次提交的内容；提交之后同一条 `git status --short` 为空（`logs/` 是 `.gitignore` 的证据层）。

**一条没在 tip 上重跑的**：`smoke.sh --select 32` 在 `aa2572f0` 上跑过两次（35s / 35s，✓73 ✗0），交付 tip 上那一次我排进了
门禁锁队列 —— 前面是另一个席位的一整套全量门禁，等了 7 分钟没轮到，我把这条排队撤了：撤掉是怕它占着队列挡 PM 自己的复验跑。
`aa2572f0` → tip 的差别只有 `section-budgets.tsv` 的一行数据与本报告/清单勾，而那一行数据由**在 tip 上跑的**
`--budget-check`（135/135）覆盖。PM 复验时会重跑 §32；若与我这里写的读数不一致，以复验为准。

## Decisions and deviations

- **`section-paths.tsv` 除了 `common.sh` 还补了夹具路径**：任务书只点了 `common.sh`，但 `section-select.sh --check` 的另一
  个方向要求「段正文里点名的真实路径必须被该行 patterns 覆盖」，⑨ 块点名了夹具 → 不补就红（实测：B 臂的
  `--check` 正是这条）。两行都补，方向一致。
- **`--select 32` 的读数是 35s 而不是「夹具 23s + 原段 10s」的 33s**：夹具在段里跑时与 §32 前面的夹具共用机器
  （loadavg1 15/32 核），单跑的 23s 是空载读数。取最差（35s）做 band，符合表头「取最差」的口径。
- **0.3 的基线树取 `637b7ae0` 而不是 `v0.2.0`**：任务书给的两选一里，「落地前最后一个提交」更贴题（`v0.2.0` 是它的祖先，
  中间还夹着本 change 的提案与评审提交，但没有产品代码）。两棵树上 `smoke.sh --select 32` 的读数相同（夹具都还不存在）。
- **提案里 12 条与本报告 11 条的差别**已在上面写清：pin 集合不同，机制相同；没有去凑数。
- 本任务没碰产品代码（`skills/teamsmith/scripts/**` 一个字节没动），只动 `tests/` 与 change 的 `tasks.md`。

## Suggested next steps

- PM 复验：`git diff main...HEAD -- skills/teamsmith/tests` 只有三份测试面文件；重点看 §32 ⑨ 的三种红分支（77 / 缺夹具 /
  无结果行）是否够狠，以及预算 140 是否接受（若要把 ci 列也填上，得等一次 push 后的 CI 计时）。
- 归档 `tmux-identity-scope` 前，`0.3` 与 `1.6` 的勾已按事实补上；清单里其余格（5.1–5.4）已由 PM 按 V48/V56 勾过。
