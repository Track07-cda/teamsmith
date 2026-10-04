# P92 · gate-isolation-scan-scope 独立复验（F1/F2 修复后·换人）

agent: verify   status: delivered（任务书五项全部成立；**0 finding**；openspec 30/0 · lint 0 红 · FAST 2712/0 · 全量 3378/0）
time: 2026-09-23T00:40Z
branch: `task/P92-p92`（local 模式：分支留在 `.worktrees/verify`，不 push）   PR/MR: -
change: `gate-isolation-scan-scope`（deltas: `verification`, `boundary`；phase: verify）
brief: `docs/team/tasks/P92-scan-scope-reverify.md`
verified revision: 复验 tip = main `613dcc84`（**技能树**与 main 逐字节一致：`git diff main -- skills/` 为空，smoke/shim blob 相同；本分支只有报告与证据提交）。
    propose = dev（P73）· apply = dev2（P77）· 返工 = dev3（P87）——**我（verify）与这三个席位都不同人**。
    red 侧回放用 P87 开工前的真实基线 `c3b8caf2`（= P83 的 verify tip；`git show c3b8caf2:…` 取出，
    smoke sha256 `d6a1ffcd597b552b…`、shim sha256 `c4ba417d19e7891e…`，与 P87 报告记录一致）。
    复验期间 main 又前进了（至 `0d658583`，P90/P91 等）；这些提交**没有触碰**扫描/轮转相关的行
    （`git diff 613dcc84..main -- skills/teamsmith/tests/smoke.sh skills/teamsmith/scripts/shim/tmux`
    里 `real_ledger_hits|12b-j|rotation|tmux-calls|dropped=` 无任何增删）。本报告的结论对应
    `613dcc84` 的技能树；合并到新 main 后请在最终 tip 上复跑门禁（本次全量在 `613dcc84` 上 3378/0）。

## 0. 一句话

按任务书自造植入点对抗性复验了扫描作用域（五条腿 + 子目录同名 + 两条流量记录 + 边角形状）、
审计日志语义（真私有 socket tmux 调用必须入账、扫描不得因此红）、轮转口径（marker 形状/闭集词表/
唯一 1000 行/二次累计/读不出 N 不累计）与正向控制仍在；并用**真实修前基线 `c3b8caf2` 回放**拿到
F1/F2 的红侧，用四个**克隆副本变异**证明已发货断言真的能红。**任务书点名的每一项都成立，没有 finding**。

## 1. 我自己的证据 vs 引用

| 类别 | 内容 |
|---|---|
| **我自己的证据（本报告数字的来源）** | `docs/team/reports/P92-verify/pkg/`：6 个段落、**112 条断言**、逐条自造植入点；真 tmux 调用一律 `lib.sh` 的 `p92_tmux()`（私有 `-L p92pkg-$$` socket、已 `mkdir -p` 的私有 `TMUX_TMPDIR`、`env -u TMUX -u TMUX_PANE`）。原始输出在 `pkg/logs/`。 |
| **引用（我重跑过，但夹具/断言逐字节抽取，不是我写的）** | smoke §12b-j 的负对照块与 M16 的双向对照块（`extract_12bj_control`/`extract_m16_control` 从 smoke.sh 逐字节抽出）、`ob_leak_scan`；§31c ⑤ 的 marker 锚定正则与闭集四值我在 §30/§31 里复刻（smoke blob `2f3e37ca8955`）。 |
| **没有原样采信** | P87 报告的结论一条都没有直接写进结论；每条都以我自己的夹具或 git 历史回放重做。修前基线不是 P87 的快照（仓库里不存在），而是从 git 历史 `c3b8caf2` 取原始文件。 |

## 2. 任务书逐项

| # | 任务书要求 | 结果 | 证据（我的） |
|---|---|---|---|
| 1 | 五条腿全部点名；两条流量记录静默 | ✓ | §3.1（六条账本腿点名、两条静默） |
| 1 | 反向腿：bg 排除放宽成 basename → 两条 bg 腿红 | ✓ | §3.1 反向腿 + §3.4 变异 b（FAST ✗7，两条 bg 腿在**已发货断言**上红） |
| 2 | 真调一次 tmux（私有 socket）→ 调用必须进 `state/tmux-calls.log`，扫描不得因此变红 | ✓ | §3.2（new-session + kill-session 真执行、真入账；扫描 0 命中） |
| 2 | 反向：把它从排除里去掉 → `12b-j` 红 | ✓ | §3.2 反向腿 + §3.4 变异 a（FAST ✗10） |
| 3 | 2100 行 → 首行严格 marker、不含 `act=`（全表核对闭集四值）、唯一 1000 条调用行 | ✓ | §3.3 P1（marker 行零 `act=`；全表每个 `act=` 都是四值之一，且四值都出现） |
| 3 | 第二次轮转累计 | ✓ | §3.3 P2（`dropped=2201`） |
| 3 | 读不出 N 的那次不参与累计（F2） | ✓ | §3.3 P3/P4/P5/P6/P7（修前基线同题全红） |
| 4 | `12b-j` / M16 的正向腿照旧能红 | ✓ | §3.4 变异 d（扫描恒空 → 12b-j 六条正向腿 + M16 正腿 + 26-l 自检全红） |
| 5 | 零回归：openspec + FAST + 全量 smoke（当前 main 零红） | ✓ | §4：openspec 30/0 · lint 红 0 · FAST `✓2712 ✗0` · 全量 `✓3378 ✗0` |
| — | 至少三条变异（红→绿原始输出，只在 scratch 副本上） | ✓ | §3.4（包内 4 条 + 克隆 FAST 4 条） |
| — | 还原后实现树干净 | ✓ | §3.5 |

## 3. 证据

复跑入口（只写 mktemp 临时根；red 侧指向临时文件，仓库实现树一字不改）：

```sh
bash docs/team/reports/P92-verify/pkg/run.sh                    # 绿侧 112 ok / 0 bad（pkg/logs/pkg-green.log）
P92_SMOKE_SRC=/tmp/p92-pre/scan.pre.sh bash docs/team/reports/P92-verify/pkg/10-scope.sh   # 修前红侧
P92_SHIM_SRC=/tmp/p92-pre/shim.pre     bash docs/team/reports/P92-verify/pkg/30-rotation.sh
# 上面两个 /tmp/p92-pre/* = git show c3b8caf2:<path>（真实修前基线，不是复制品）
```

### 3.1 扫描作用域（§10，绿侧 23 ok）

| 植入位置 | 期望 | 修后 `613dcc84` | 修前 `c3b8caf2` |
|---|---|---|---|
| `docs/team/inbox/bg/leak.md` | **点名** | 点名 ✓ | **静默 ✗**（F1） |
| `.pi/team/state/nested/bg/leak.md` | **点名** | 点名 ✓ | **静默 ✗**（F1） |
| `.pi/team/state/tmux-calls.log.1`（同名兄弟） | **点名** | 点名 ✓ | 点名 |
| `docs/team/inbox/leak.md` | **点名** | 点名 ✓ | 点名 |
| `.pi/team/state/phantom.log` | **点名** | 点名 ✓ | 点名 |
| `.pi/team/state/nested/tmux-calls.log`（子目录同名） | **点名** | 点名 ✓ | 点名 |
| `.pi/team/state/bg/gate.log` | 静默 | 静默 ✓ | 静默 |
| `.pi/team/state/tmux-calls.log` | 静默 | 静默 ✓ | 静默 |

修前回放 `pkg/logs/red-10-scope-preF1.log`：**bad=10**——两条 bg 腿漏报、命中数 4≠6、源码里是
`--exclude-dir=bg`（basename glob），没有 bg 的确切路径前缀。修后 §10 bad=0。

边角形状（全部实测点名）：尾斜杠根、根路径带空格、更深/大写的 `bg` 目录、`bgx/` 目录（前缀必须带斜杠才出局）、
**名为 `bg` 的普通文件**、**名为 `tmux-calls.log` 的目录里的文件**（排除只限那个路径本身）——只有
`state/bg/` 目录树出局。反向腿（唯一一行突变：给 grep 加回 `--exclude-dir=bg`）→ 两条 bg 腿
变静默、命中数 6→4：

```
ok      反向腿红：[§10 期望点名] docs/team/inbox/bg/leak.md 在突变体下被静默
ok      反向腿红：[§10 期望点名] .pi/team/state/nested/bg/leak.md 在突变体下被静默
ok      反向腿红：突变后只剩四条命中（两条 bg 腿丢失）（4）
```

### 3.2 审计日志语义（§20，绿侧 14 ok）

经 shipped shim、私有 `-L p92pkg-$$` socket **真调两次 tmux**（`new-session` + `kill-session`），
`TEAM_TMUX_CALLS_LOG` 钉在临时根；真 tmux `has-session` 证明调用真的落地：

```
① 经闸门的私有 socket new-session 成功（透传到真 tmux）（0）
① 会话真的建起来了（真 tmux has-session rc=0）（0）
① 日志恰一条调用行（1）
   日志首行：2026-09-23T00:21:49+00:00 · act=pass · sock=/tmp/p92pkg.VQa8aq/tmux/tmux-1000/p92pkg-1008584 · TMUX=- · TMUX_TMPDIR=/tmp/p92pkg.VQa8aq/tmux · argv=-L p92pkg-1008584 new-session -d -s p92faketui-audit-1008584 -c /tmp/p92pkg.VQa8aq · pid=… ppid=… cwd=…
② 私有 socket kill-session 成功（0）；② 会话真的没了（1）；② 两次调用都进了日志（2）
③ 日志动作词汇都在闭集四值内（无）
④ 真调用后扫描仍静默（审计日志是流量记录，不算账本痕迹）（0）
④ 同根的负对照仍然点名（扫描没变哑）（1）
```

反向腿（拿掉 `$0 != audit &&`）：扫描立刻点名 `…/state/tmux-calls.log`。
修前 `c3b8caf2` 的扫描**已经**有审计排除（P77 加的），所以这次 F1/F2 修复没有回退它：
`P92_SMOKE_SRC=/tmp/p92-pre/scan.pre.sh` 跑 §20，④ 仍为 0（`pkg/logs/red-20-audit-preF1.log`）。

### 3.3 轮转语义（§30，绿侧 56 ok）

| 探针 | 检查 | 修后 | 修前 `c3b8caf2` |
|---|---|---|---|
| P1 | 2100 条四值循环调用行 + 1 调 → marker `dropped=1101`、恰 1000 条调用行、全表闭集四值 | ✓ `… · rotation · dropped=1101` | ✓ |
| P2 | 第二次轮转累计 | ✓ `dropped=2201` | ✓ |
| P3 | 读不出 N（`dropped=abc`）+ 2100 → 从 0 重算 `1101` | ✓ | **`1102` ✗**（把旧 marker 当调用行，F2） |
| P4 | marker + 恰 2000 调用行 → **不轮转**、旧 marker 原样 | ✓ 2001 行 | **误轮转成 1001 行、旧 marker 被重写 `dropped=1001` ✗** |
| P5 | 超大 N（`99999999999999999999`）→ 按读不出，`1094`，不写回绕假数 | ✓ | **写回绕假数 ✗** |
| P6/P7 | `dropped=` / `dropped=+5` → 读不出，从 0 重算 `1101` | ✓ | ✗ |
| P8 | 前导 0 `dropped=008` = 可读十进制 → `8+1101=1109` | ✓ | **算术中止，日志停在 2102 行 ✗** |
| P9 | 首行是调用行、argv 里含 marker 形状 → 不当作 marker（`1102`） | ✓ | （P77 起同族防护） |
| P10 | marker 在第 2 行（外部拼接）→ 按无 marker（`1102`） | ✓（观察，见 §5） | — |

marker 严格形状 `^<ISO> · rotation · dropped=<N>$`、marker 行零 `act=`、全表 `act=` 只出现四值
（P1 里四个值都出现，证明词表检查有牙）。修前回放 `pkg/logs/red-30-rotation-preF2.log`：**bad=10**。

并发观察（§32，30 轮双并发轮转，观察不判红）：无 marker=0 · 多 marker=0 · 两条并发调用行同时存活=30/30 ·
形状异常=0（`pkg/logs/pkg-green.log` §32 note）。

### 3.4 变异（红→绿；只在 scratch 副本上，仓库实现树一字不改）

**套件级（克隆副本 + 完整 FAST 门禁；每例只改一行/一处，diff 在 `pkg/clones/mutant-*.diff`）**

| 变异 | 完整 FAST 结果 | 红的是哪些**已发货断言**（原始输出 `pkg/logs/red-fast-mutant-*.plain.log`） |
|---|---|---|
| a · 拿掉审计日志排除 | `✓ 2703 ✗ 10` rc=1 | `✗ 12b-j 负对照：审计日志是调用记录，不算账本痕迹（M7.2 红侧的成因）（期望 [0]，实际 [1]）`；`✗ M16 隔离对照：审计日志 tmux-calls.log 是调用记录，不算账本痕迹（期望 [0]，实际 [1]）`；另有 8 条计数级联 |
| b · bg 排除改回 basename | `✓ 2706 ✗ 7` rc=1 | `✗ 12b-j 负对照：inbox/bg/ 里的痕迹必须被点名（bg 排除是确切路径，不是目录名）（期望 [yes]，实际 [no]）`；`✗ 12b-j 负对照：state 下嵌套的 bg/ 里的痕迹也必须被点名（期望 [yes]，实际 [no]）`；`✗ M16 隔离对照：inbox/bg/ 里的痕迹必须被抓到（期望 [1]，实际 [0]）` |
| c · marker 写入带 `act=rotation` | `✓ 2707 ✗ 6` rc=1 | `✗ ⑤ 首行是轮转标记（ISO 时间 · rotation · dropped=1101）`（锚定正则不再匹配）；`✗ ⑤ 标记不是调用行（不带 act=）`；`✗ ⑤ 真调用行恰一条（期望 [1]，实际 [2]）`；`✗ ⑤ 第二次轮转：dropped 累计（2201）`；`✗ ⑤ 读不出 N …（1101）`；`✗ ⑤ 超大 N …（1094）` |
| d · 扫描恒空（`return 0`） | `✓ 2698 ✗ 15` rc=1 | 12b-j 六条正向腿 + `✗ 26-l 隔离守卫自检：故意泄漏没被抓到（这条隔离断言是空的）` + M16 三条正向腿——**守卫变哑时控制块确实会红** |
| — · 绿侧 main tip | `✓ 2712 ✗ 0` rc=0 | `smoke 全绿`（`pkg/logs/green-fast.plain.log`） |

**包内（§10/§20/§31/§40 的反向腿，逐条红→绿）**：bg→basename（两条 bg 腿静默）· 拿掉审计排除
（扫描点名日志）· marker 带 `act=`（锚定形状 + 闭集词表双红）· 三个变异实现在**逐字节抽取的**
12b-j/M16 控制块上变红（`pkg/logs/pkg-green.log` 里全部以「反向腿红 / …变异…红」的 ok 行记录）。

**真实修前基线的红→绿**（不是构造的变异，是 `c3b8caf2` 原件回放）：

| 段 | 修前 | 修后 |
|---|---|---|
| §10（F1） | `bad=10`（两条 bg 腿漏报、basename glob） | `bad=0` |
| §30（F2） | `bad=10`（P3 写 1102、P4 误轮转、P5 回绕假数、P8 算术中止） | `bad=0` |

### 3.5 实现树干净（还原后）

```
$ git diff --stat 613dcc84..HEAD -- skills/                 # 空（本分支 = 613dcc84 技能树 + 报告/证据提交）
$ git diff --stat main..HEAD -- skills/                     # 非空（main 已前进到 0d658583；本分支不含它的新改动）
$ git hash-object skills/teamsmith/tests/smoke.sh           # 2f3e37ca8955…（= 613dcc84 同名 blob）
$ git hash-object skills/teamsmith/scripts/shim/tmux        # 409afd7534bd…（= 613dcc84 同名 blob）
$ git status --short                                        # 空（报告与证据已提交在 task/P92-p92 上；只有 docs/team/reports/**）
```

所有夹具只写 mktemp 临时根（`/tmp/p92pkg.*`）；真 tmux 调用全部落在私有 `-L p92pkg-$$` socket 上，
`TEAM_TMUX_CALLS_LOG` 钉在临时根——真项目 `main` 的 `docs/team/inbox`、`.pi/team/state` 零写入。

## 4. 零回归门禁（最终 tip `613dcc84`）

| 门禁 | 结果 | 证据 |
|---|---|---|
| `openspec validate --all --strict` | `Totals: 30 passed, 0 failed (30 items)` rc=0 | `pkg/logs/openspec-validate.log` |
| `perl tests/tmux-lint.pl`（含本包被扫） | 红 0 条；36 条在 16 个历史豁免文件里 | FAST 31a 段 + 单独运行 |
| `TEAM_SMOKE_FAST=1 bash tests/smoke.sh </dev/null` | `✓ 2712 ✗ 0` rc=0（657s）；跳过 33 个真进程段落 | `pkg/logs/green-fast.plain.log` |
| `bash tests/smoke.sh </dev/null`（全量） | `✓ 3378 ✗ 0` rc=0，`smoke 全绿`；0 个 FAST 式跳过（31b 容器段与 31c 真私有 server 生死/指纹翻转都真跑） | `pkg/logs/green-full.plain.log` |

四个变异副本的 FAST 全部 rc=1（预期红侧），见 §3.4。

## 5. Findings 与观察

- **必修 finding：无。** 任务书要求的每一项都成立，且红侧（修前基线 + 变异）都能真红。
- **观察（不判红，记录以免后来者当成缺陷）**：
  1. **P10**：marker 只被当 marker 当它出现在**首行**（spec 的定义就是首行）。外部把 marker 拼到第 2 行时，
     shim 按「无 marker」处理（计数从 0 重算，`dropped=1102`）——这不是 spec 覆盖的形状，行为可见且不编造数。
  2. **§32 并发轮转**：30 轮双并发里没有观察到丢行或多 marker；设计 D2/Risks 已声明竞态可能丢一次
     marker 写入（spec 只承诺顺序写入下 newest 1000 存活）。本次未复现，记录备查。
  3. §10 的源码形状检查用 `grep -F 'audit'` 认「按精确路径变量比对」——这是**实现形状**检查（绿侧过），
     不是 spec 断言；修前基线用的是内联 `grep -vxF`，所以回放时该条会红，属于预期差异。
  4. 排队观察（与 P92 主题无关，印证 D50）：我第一次那套全量 smoke 用默认 `TEAM_SMOKE_LOCK_WAIT=1800`
     排队超时后，`exec flock -w` 直接返回 1、`exec` 之后那句「排队/加锁失败」永远不会执行——作业**静默**
     以 rc=1 结束（日志里没有任何失败行）。改 `TEAM_SMOKE_LOCK_WAIT=14400` 重排后拿到锁并跑完。
