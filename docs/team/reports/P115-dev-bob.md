# P115 · §36 嵌套跑假红：判定看状态 + 环境前置可见 SKIP 归因（apply）

- **agent**: dev-bob
- **status**: delivered
- **phase**: apply
- **change**: `-`（`anchor: none (infra)` —— 只改 §36 的夹具等待/判定，不改选段器或账本行为）
- **branch**: `task/P115-36-infra-apply`（local 模式：分支留在本地 `.worktrees/dev-bob`，不 push；由 PM 复验后本地合并）
- **base**: `efa2185d`（P115 brief；实现提交 `708155d9`）
- **交付物**: `skills/teamsmith/tests/smoke.sh`（只在 §36 内改 + 段首三个 helper；不动选段器 / 账本 / 其他段）
- **报告包**: `docs/team/reports/P115-dev-bob/logs/`（原始输出逐份落盘）

## 0. 结论

| brief 条目 | 结果 |
|---|---|
| 1. 先复现：竞争下跑 §36，抓出三条断言的真实触发路径 | ✅ 竞争（3×`--select 36` + 24 自有 burners，loadavg 6.7→39.4）**全绿**；真正的触发路径是**嵌套 run 自己的前导段 §0c**：调用者 TMPDIR 深 → 嵌套私有 tmux socket 路径 116–119 字节 > AF_UNIX 上限 107 → 绑不上 socket → `私有 socket 没生效` → 嵌套 rc=1（§1） |
| 2. 按 D33/P62 修：判定看状态；拿不到锁/被排队 → 可见 SKIP + 归因；保留红侧 | ✅ `p98_nest_state`/`p98_nest_verdict` 读嵌套日志把 rc 分成 green/env/red；env → `cond_skip` + 归因（含 socket 字节数与原文）；真红 → `bad`（§2） |
| 3. 不许放松：`照自己的参数走（负例仍被拒）`语义原样 | ✅ 该断言与 36④ 的泄漏负例一个字没改；36⑥ 真红侧三个配置照旧红（§3.2） |
| 4. 证据：竞争 → 不假红；真红 → 仍红；FAST 全绿；openspec validate | ✅ 深 TMPDIR `✓105 ✗0 SKIP5`；竞争下 3×`✓110 ✗0`；36⑥ 两向夹具全绿；FAST 见 §5；`openspec validate --all --strict` 16/16 rc=0（§5） |
| 5. 报告点名触发路径与保留的红侧，附原始输出 | ✅ 本报告 §1（触发路径）、§3.2（红侧）、§6（原始输出索引） |

**判定：交付完成。** 修复前：深 TMPDIR 下 `✓87 ✗5`（与 P111 现场 `✓2996 ✗5` 同形、同五条）。修复后：
深 TMPDIR 下 `✓105 ✗0 SKIP5`（五条各带环境归因，不再是产品红）；默认/浅 TMPDIR 与竞争下全绿；真红侧三个配置照旧红。

## 1. 复现：真实触发路径（不是竞争，也不是锁）

### 1.1 竞争实验 → 全绿（先排除"看起来是竞争"）

用项目自己的负载手法（`skills/teamsmith/tests/load-experiment.sh burn 24`，只烧自己 spawn 的进程）压着
**3 套并发 `--select 36`** 跑（浅 TMPDIR，各自私有临时根与私有 tmux socket）：

```
$ base=/tmp/p115c2.$$; for i in 1 2 3; do mkdir -p "$base/t$i"; TMPDIR="$base/t$i" TEAM_SMOKE_FAST=1 \
    bash skills/teamsmith/tests/smoke.sh --select 36 & done          # + 24 个自有 CPU burners
rc1=0 rc2=0 rc3=0
s36-1/2/3: == 选段结果 ==  ✓ 92  ✗ 0
```

原始输出：`logs/11-prefix-contention-3x.log`、`logs/11-prefix-contention-burn.log`。
FAST 模式不排队（只有每进程私有的 `teamsmith-smoke-fast-$$.lock`），§36 的嵌套跑要么 `TEAM_SMOKE_NO_LOCK=1`、
要么用 §36 自己的私有锁 —— **没有任何一段被"排队到"**。竞争本身复现不出假红。

### 1.2 真实触发路径：嵌套 run 的前导段 §0c（私有 tmux socket 路径超 AF_UNIX 上限）

把调用者的 TMPDIR 压深（模拟 P111 验证包的 `/tmp/p111-pkg.<pid>/s60-fast-tmp`）后**确定性复现**了
与现场形状完全一致的 5 条假红（`✓87 ✗5`，`EXIT=1`）：

```
$ export TMPDIR=/tmp/p115deep.1671651/s36-fast-tmp; mkdir -p "$TMPDIR"
$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh --select 36
  ✗ 36③ 选段嵌套跑退出 0（期望 [0]，实际 [1]）
  ✗ 36③ 故意变慢的段照旧绿（退出码 0）（期望 [0]，实际 [1]）
  ✗ 36④ 选段子进程里的嵌套 smoke 照自己的参数走（负例仍被拒）（期望 [0]，实际 [1]）
  ✗ 36④ 注入的必红段没被选中 → 选段仍退出 0（期望 [0]，实际 [1]）
  ✗ 36⑤ 锁空闲：--select 0b 的排队路径仍然跑过滤副本（退出 0）（期望 [0]，实际 [1]）
== 选段结果 ==  ✓ 87  ✗ 5
```

**哪一段被饿到/挂了**：不是选段器，也不是锁 —— 是**嵌套 run 的前导段 `0c`（静态检查里的 tmux 隔离自检）**。
嵌套 run 的 TMPDIR 是 `$TMP/p98-nest-tmp`（或 §36⑤ 的 `$TMP/p98-locksel/tmp`），它自己的私有 tmux socket 落在
`<那个 TMPDIR>/teamsmith-smoke.XXXXXX/tmux/tmux-1000/default`：

| 嵌套日志 | socket 路径字节数 | 唯一红行 |
|---|---|---|
| `p98-nest-run.log`（36③） | **116** | `✗ tmux 隔离：私有 socket 没生效` |
| `p98-slow.log`（36③ 慢段） | **116** | 同上 |
| `p98-leak.log`（36④） | **116** | 同上 |
| `p98-failA.log`（36④） | **116** | 同上 |
| `p98-locksel-green.log`（36⑤） | **119** | 同上 |

Linux `AF_UNIX` 的 `sun_path` 上限是 **107 字节**（P111-dev3 实测：107 bind OK / 108 `ENAMETOOLONG`），
`tmux new-session` 建私有 server 时 bind 失败（stdout 被夹具吞掉），于是 `[ -S "$SMOKE_TMUX_SOCK" ]` 为假 →
§0c 报隔离自检红 → 嵌套 run rc=1 → 五条"嵌套跑退出 0"全被这个**环境前置**带红。嵌套 run 本身是健康的：
同一份日志里默认 server 没被污染 ✓、账本自查 `一致`、选段/账本断言全 ✓。

这 5 条正好是**所有 rc=0 且带真段正文的嵌套跑**：36③×2、36④ 泄漏侧、36④ failA、36⑤ 锁绿侧；
唯一不受影响的嵌套跑是 36④ FULL 兜底（空壳变体没有段正文，不跑 §0c 正文），所以现场恰好是 5 条而不是 6 条。

原始输出：`logs/10-prefix-deep-5-red.log`、`logs/12-prefix-deep-nested-nest.log`、`logs/12-prefix-deep-nested-locksel.log`。

## 2. 修法（D33/P62：判定看状态，不看墙钟）

只动 §36：段首新增三个 helper + 五个 rc=0 断言改用判定出口 + §36⑤ 的持锁等待改成看锁状态。

### 2.1 `p98_nest_state` → green / env / red

读**子进程留下的日志**（去 ANSI）而不是拿墙钟猜"它该跑完了"：

1. `rc=0` → `green`；
2. 有红行（`^  ✗ `）且**全部**都是 `私有 socket 没生效` → `env`（嵌套 run 自己的前导段起不了私有 tmux）；
3. 没有红行且日志里有 `^排队超限：` → `env`（锁排队 exit 2，点名 holder —— brief 点名的"拿不到锁/被排队"形状）；
4. 其它任何形状 → `red`：有非环境红行时点名第一条；`rc≠0` 却连一条红行都没有（不可归因）也判红。

`p98_nest_verdict <标题> <rc> <日志>`：`green`→`ok`；`env`→`cond_skip`（可见
`SKIP（条件不满足）` + 归因）；`red`→照旧 `bad`。归因由 `p98_nest_sock_len` 从日志里取出嵌套 socket 路径，
超过 107 字节时在归因里带上字节数（`… ｜ 私有 socket 路径 117 字节 > AF_UNIX 上限 107`）。

### 2.2 五个断言改用判定出口（语义不变）

`36③ 选段嵌套跑退出 0`、`36③ 故意变慢的段照旧绿（退出码 0）`、`36④ 选段子进程里的嵌套 smoke 照自己的参数走（负例仍被拒）`、
`36④ 注入的必红段没被选中 → 选段仍退出 0`、`36⑤ 锁空闲：--select 0b 的排队路径仍然跑过滤副本（退出 0）` —— 标题与承诺一字不改，
只把 `assert_eq rc 0` 换成 `p98_nest_verdict`（rc=0 时行为逐字一致）。

### 2.3 §36⑤ 的持锁等待：`sleep 0.4` → 看锁状态

原来等 0.4s 再写 `.holder`（赌`flock`起来了）；现在用 `flock -n <lock> true` **探锁失败 = 被持有**做有界轮询
（50×0.1s，到顶报夹具红）。判定依据是状态，不是墙钟。

### 2.4 §36⑥ 两向夹具（每次套件都跑，PM 复验会原样重跑）

| 夹具 | 造的形状 | 期望 |
|---|---|---|
| 环境侧 | 真树 + 嵌套 TMPDIR 压深到 socket 路径超限（默认 `/tmp` 下实测 119 字节，私有浅 TMPDIR 下 134 字节；随调用者 TMPDIR 变长只增不减） | 判 `env`、归因点名 `私有 socket 没生效`、路径字节数 > 107、断言出口是可见 SKIP 且无红标 |
| 锁排队侧 | 合成日志：`排队超限：…（持锁者：pid=999 cmd=p115-holder）`，rc=2 | 判 `env`、归因带出 holder |
| 混合侧 | 合成日志：`私有 socket 没生效` + 一条真红 | 判 `red` 并点名真红（**环境归因不许吞真红**） |
| 不可归因侧 | rc=1、一条红行都没有、也不是锁排队 | 判 `red`（不得被当成环境跳过） |
| 真红侧 ×3 | 三条受保护配置（`--select 0b` / `--select 0c`（慢段变体）/ `--select 1`（泄漏变体））各注入一条真的 `bad` | 判 `red`、归因点名注入行、断言出口发红标 |

真红侧的注入点与受保护断言的选择参数一一对应；注入落地都有 `grep` 夹具自检（"注入没打上"会红）。

## 3. 两向证据

### 3.1 环境前置 → 不假红（深 TMPDIR）

```
$ export TMPDIR=/tmp/p115deep3.3288111/s36-fast-tmp; mkdir -p "$TMPDIR"
$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh --select 36
  SKIP（条件不满足） 36③ 选段嵌套跑退出 0 —— 嵌套 run 的前置环境起不来（rc=1）：tmux 隔离：私有 socket 没生效（…） ｜ 私有 socket 路径 117 字节 > AF_UNIX 上限 107
  SKIP（条件不满足） 36③ 故意变慢的段照旧绿（退出码 0） —— … 117 字节 …
  SKIP（条件不满足） 36④ 选段子进程里的嵌套 smoke 照自己的参数走（负例仍被拒） —— … 117 字节 …
  SKIP（条件不满足） 36④ 注入的必红段没被选中 → 选段仍退出 0 —— … 117 字节 …
  SKIP（条件不满足） 36⑤ 锁空闲：--select 0b 的排队路径仍然跑过滤副本（退出 0） —— … 120 字节 …
#5 36 · 选段与分段账本自检（P98 · gate-runtime-budget） · 用时 65s · ✓84 ✗0 SKIP5 · ticks 89
账本自查： 5 段收口 · 增量 ✓105 ✗0 SKIP5 ｜ 结果行 ✓105 ✗0 —— 一致
== 选段结果 ==  ✓ 105  ✗ 0          # EXIT=0
```

原始输出：`logs/20-postfix-deep-full.log`（同一命令的完整 stdout：五个 SKIP 原文 + 36⑥ 全部 ✓，其中环境侧夹具
在深调用者下造出 **150 字节** 的 socket 路径）、`logs/20-postfix-deep-skip5.log`（只留 SKIP 行与结果的裁剪版）。
五个 SKIP 的归因直接引用嵌套日志的原文与字节数 —— 判定是数据，不是措辞。

### 3.2 真红 → 仍红

- **套件内**：36⑥ 三个真红侧（§2.4）每跑必验，判 `red` + 出口红标；混合侧证明真红优先级；不可归因侧证明不越权跳过。
- **Flip 2/3**（§4）用两个方向破坏判定，看到守卫夹具分别变红（4 条 / 2 条）。
- 36④ 原有的"选中必红段 → 非零退出 + 点名注入行"断言原样保留，仍是独立的一条红侧。

### 3.3 竞争下 → 不假红（修复后复跑）

修复后同一负载手法（3×`--select 36` + 24 burners，loadavg 6.66 → **39.41**）：

```
rc1=0 rc2=0 rc3=0
s36-1/2/3: == 选段结果 ==  ✓ 110  ✗ 0（skip=0）
```

原始输出：`logs/21-postfix-contention-3x.log`、`logs/21-postfix-contention-burn.log`。
浅 TMPDIR 下五个受保护断言都是 `✓`（不会多用 SKIP），36⑥ 的深路径夹具照常造 env 形状并判 env。

## 4. Flip 证据（红→绿 + 破坏守卫 → 夹具红）

**Flip 1（红 → 绿）**：§1.2 的深 TMPDIR 复现 `✓87 ✗5 EXIT=1` → §3.1 的 `✓105 ✗0 SKIP5 EXIT=0`。
同一形状、同一命令，只差判定逻辑。

**Flip 2（把 env 归因关掉）**：`if [ "$ne" -gt 0 ] && [ "$ne" -eq "$nr" ]` → `[ "$ne" -gt 999 ]…`
（`${ne}` 恒 ≤ 红行总数，env 分支永不成立）：

```
mutA landed=1 ; rc=1
✗ 36⑥ 环境侧（深 TMPDIR） 判类（期望 [env]，实际 [red]）
✗ 36⑥ 环境侧（深 TMPDIR） 归因点名 [私有 socket 没生效]（[] 里找不到 [私有 socket 没生效]）
✗ 36⑥ 环境侧经断言出口是可见 SKIP（不判红）（[… ✗ …] 里找不到 [SKIP（条件不满足）]）
✗ 36⑥ 环境侧经断言出口没有红标（不该出现 [✗]）
== 选段结果 ==  ✓ 106  ✗ 4
```

**Flip 3（让 env 压过真红）**：条件改成 `if [ "$ne" -gt 0 ]; then`（只要有一条环境红就跳过）：

```
mutB landed=1 ; rc=1
✗ 36⑥ 混合（环境红+真红） 判类（期望 [red]，实际 [env]）
✗ 36⑥ 混合（环境红+真红） 归因点名 [P115 夹具：真红（混合形状）]（[tmux 隔离：私有 socket 没生效…] 里找不到 …）
== 选段结果 ==  ✓ 108  ✗ 2
```

两次变异后 `git checkout` 还原，`git status --short` 为空（原始输出 `logs/30-mutA-env-guard-red.log`、
`logs/30-mutB-mixed-guard-red.log`）。

## 5. 门禁

| 门禁 | 结果 |
|---|---|
| `TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh`（全套 FAST，rc=0，818s，loadavg 12.05） | `== 结果 == ✓ 3034 ✗ 0` · `smoke 全绿` · 113 段收口（`增量 ✓3034 ✗0 SKIP33 ｜ 结果行 ✓3034 ✗0 —— 一致`）· §36 自身 `✓89 ✗0 SKIP0` · 无超时/现场。P111 基线是 `✓3001 ✗0 SKIP33`；§36 的增量是 +18（= 36⑥ 新夹具），其余增量来自 P111 之后 main 上别的合并；SKIP 总数不变（默认浅 TMPDIR 下 36⑥ 不触发 skip） |
| `openspec validate --all --strict` | `Totals: 16 passed, 0 failed (16 items)`，rc=0（`logs/40-openspec-validate.log`） |
| 全套非 FAST（协议里的交付门禁，占机器锁；rc=0，1424s，loadavg 5.5） | `== 结果 == ✓ 3699 ✗ 0` · `smoke 全绿` · 112 段收口（`增量 ✓3699 ✗0 SKIP0 ｜ 结果行 ✓3699 ✗0 —— 一致`）· §36 自身 `✓89 ✗0 SKIP0` · P70 对账：无超时、无现场。全量比 FAST 少 1 段是既有差异（`14c 快模式自检` 只在快模式起跑，P111-dev3 §7 已记录） |

基线对照（P111-dev3 §7）：FAST `✓3001 ✗0 SKIP33` / §36 `✓71`；全量 `✓3655 ✗0 SKIP2`。
本次 §36 从 `✓71` 到 `✓89`（+18 = 36⑥ 新夹具），全套增量里其余 ✓ 来自 P111 之后 main 上别的合并，不是本任务语义改动。

## 6. 实现与边界

- 改动范围：`skills/teamsmith/tests/smoke.sh` 的 §36 内（三个 helper、五个断言调用点、§36⑤ 等待、
  36⑥ 新块）。选段器、账本、预算表、其他段零改动（`git diff --stat`：1 file，+127 −8）。
- **没有放松任何既有承诺**：负例仍被拒（rc=2）、账本/收口行/红标计数语义、FULL 兜底、慢段照旧绿都不变；
  36③/36④/36⑤ 的其余断言与 §36 的账本断言原样跑。
- `cond_skip` 的标记会进 `SKIP_SEGS/SKIP_N`，因此深 TMPDIR 的 FAST 收尾行会把 5 条条件 SKIP 列在
  `FAST 模式：跳过 N 个真进程段落（…）` 里（`cond_skip` 的既有行为，11e2/26-a 等段同理）；
  默认/浅 TMPDIR 的 canonical FAST 计数与 P111 基线一致（36⑥ 不触发 skip）。
- 若"私有 socket 建不起来"是夹具自身回归（路径很短也建不出），嵌套判定也会归 env —— 但这个回归
  **外层 §0c 自己会先红**，判定不背这个锅：§36 只拒绝把它重复计成"选段器的产品红"。
- 未做：不改 §0c / 选段器 / 账本；不 push（local 模式）；不改任务书。

## 7. 原始输出索引（报告包）

| 文件 | 内容 |
|---|---|
| `logs/10-prefix-deep-5-red.log` | 修复前：深 TMPDIR `✓87 ✗5` 全量尾部 |
| `logs/12-prefix-deep-nested-*.log` | 修复前：嵌套 run 日志（唯一红行 + socket 路径） |
| `logs/11-prefix-contention-*.log` | 修复前：3×并发 + 24 burners（全绿） |
| `logs/20-postfix-deep-skip5.log` | 修复后：深 TMPDIR `✓105 ✗0 SKIP5`（裁剪：只留五个 SKIP 与结果行） |
| `logs/20-postfix-deep-full.log` | 修复后：深 TMPDIR 同一次运行的完整 stdout（含 36⑥ 全部 ✓，环境侧路径 150 字节） |
| `logs/21-postfix-contention-*.log` | 修复后：3×并发 + 24 burners（`✓110 ✗0`，loadavg 39） |
| `logs/30-mutA-env-guard-red.log` | Flip 2：env 分支关掉 → 4 条 36⑥ 守卫红 |
| `logs/30-mutB-mixed-guard-red.log` | Flip 3：env 压过真红 → 2 条 36⑥ 混合守卫红 |
| `logs/40-openspec-validate.log` | `openspec validate --all --strict`（16/16） |
| `logs/50-full-fast.log` | FAST 全套原始输出（`✓3034 ✗0`；关键行另存 `50-full-fast-summary.txt`） |
| `logs/60-full-gate.log` | 全套非 FAST 原始输出（交付门禁；关键行另存 `60-full-gate-summary.txt`） |
