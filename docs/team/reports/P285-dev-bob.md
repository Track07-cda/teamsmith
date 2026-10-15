# P285 · 补齐 `orphan-visibility` 的三项缺口（清单 1.1 / 4.2 / 7.5）

agent: dev-bob   status: delivered   time: 2026-10-15T16:44:51Z
branch: `task/P285-orphan-gaps`   PR/MR: -（local 模式：分支留在本地，PM 复验后本地合并）

## Deliverables

| Path | What |
|---|---|
| `skills/teamsmith/tests/seat-visibility.sh` | census 组补上 1.1 的第三段证据（**一次真 /proc 普查的 fork 与耗时读数**，`ps` 垫片计数）；reading 组的 4.2 断言改成「既有块哨兵 + 读数整块在最后」；`--flip` 新增两条臂 `p276-flip-into-capacity` / `p276-flip-one-ps` |
| `skills/teamsmith/references/config.md` | `TEAM_ORPHAN_SCAN` 行补上默认值与「关掉它会发生什么」（三个读数面、digest 提示、`team reap --orphans`） |
| `skills/teamsmith/references/troubleshooting.md` | 新增 §28「Orphan seat processes: the agent still runs, its pane is gone」 |
| `openspec/changes/orphan-visibility/tasks.md` | 1.1 / 4.2 / 7.5 三处 `[ ]`→`[x]`，行末各给证据指针；其余 28 项与 §0 / §8 一字未动 |

**产品代码一个字节没动**：`common.sh` / `cmd-status.sh` / `cmd-watch.sh` / `cmd-reap.sh` 全部未改 —— 1.1 的读数在夹具侧用 `ps` 垫片就能测，不必为「可测」去动实现（brief 的边界：只在必须时才动）。

## Verification evidence（brief 的六条验收命令，本分支树上实跑）

```
$ bash skills/teamsmith/tests/seat-visibility.sh | tail -2
== 结果 ==  ✓ 122  ✗ 0  SKIP 0                      rc=0（19.8s；改前 110 条，新增 12 条）

$ bash skills/teamsmith/tests/seat-visibility.sh --flip | tail -2
== 结果 ==  ✓ 20  ✗ 0  SKIP 0                       rc=0（10.1s；改前 16 条，新增两条臂）

$ grep -rn 'TEAM_ORPHAN_SCAN' skills/teamsmith/references/ | head
skills/teamsmith/references/troubleshooting.md:1426:So the decision stays with a human (or the PM) in front of a named list. `TEAM_ORPHAN_SCAN=0` turns the whole reading
skills/teamsmith/references/config.md:181:| `TEAM_ORPHAN_SCAN` | `1` | whether the host-side census runs at all. `0` = read no process's environment: `team ps`, `team status` and `team up` print one named skip line instead of the reading, `team digest` adds no hint, and `team reap --orphans` refuses (exit 2) — cleanup then needs an explicit pid (`team reap <pid> --yes`). It exists for hosts where reading another process's environment is refused; the reading — and the cleanup plan it feeds — needs the default `1` |

$ "$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict | tail -1
Totals: 21 passed, 0 failed (21 items)              rc=0

$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: root=$HOME/…/.worktrees/dev-bob scope=published files=1587 hits=0 names=ok user=resolved
rc=0

$ git diff --check; echo rc=$?
rc=0
$ git status --short
（空）
```

选段回归（同一个后台批次，2155.9s；宿主 loadavg 正常，`/tmp` 余量充足）：

```
$ bash skills/teamsmith/tests/config-cli.sh | tail -2
== 结果 ==  ✓ 343  ✗ 0  SKIP 0                      rc=0
$ bash skills/teamsmith/tests/help-surface.sh --select coverage | tail -2
== 结果 ==  ✓ 9  ✗ 0  SKIP 0                        rc=0
$ bash skills/teamsmith/tests/section-select.sh --check | tail -1
== 选段自检 ==  ok 8  bad 0  SKIP 1                 rc=0
$ bash skills/teamsmith/tests/smoke.sh --select 51b,6j,15c,17,26,28
== 选段结果 ==  ✓ 869  ✗ 0
  #20 51b · 孤儿席位进程普查（P276 · change: orphan-visibility） · 用时 30s（预算 132s） · ✓2 ✗0 SKIP0
      ✓ 51b 孤儿席位普查夹具全绿（123 条断言）
      ✓ 51b 孤儿席位普查逐条红侧全绿（21 条）
```

选段依据：`section-paths.tsv` 里声明了 `references/config.md` / `references/troubleshooting.md` 的五段（6j / 15c / 17 / 26 / 28）加夹具承载段 51b（两者取并集后由选择器补前导段与 needs 闭包，共 20 段）。

- **没跑**：完整 smoke 全量（按纪律留给 PM 复验与合并）；选段日志里点名的其余 110 个键未跑。
- **未断言**：1.1 的**耗时**是打印出来的读数、不是断言（机器负载会让它漂；钉数字等于让夹具去断言机器性能）。断言的是可证伪且与负载无关的那一条：**一次普查只 fork 一次 `ps`**。
- 与普查有关的其余回归（smoke §37 的 M50 归一化等）未在本轮重跑，指针仍在 P276-dev3.md / V42.md；本次以 51b 的完整夹具（含 reap 组真进程与逐条红侧）覆盖夹具本身。

## Flip evidence（缺陷修复：红 → 绿）

### 1.1 —— 缺「一次普查的 fork/耗时读数」

**修前红**：P284 报告的实测 —— 夹具里没有任何计时或计数（全文没有 fork 计数），本机也没有 `strace`/`perf`/`bpftrace`，第三段证据在已提交的证据里不存在，该项只能留空。

**修后绿**（census 组实跑）：

```
  ✓ 1.1 一次普查（真 /proc）退出 0（=0）
  ✓ 1.1 一次普查只 fork 一次 ps（机器级粗筛，不是每个 pid 一次）（=1）
  ✓ 1.1 那次 ps 的形态是候选粗筛（-eo pid=,args=）
  ✓ 1.1 一次普查的读数：/proc 下 273 个 pid → 粗筛候选 38 个 → 记录 12 条；ps 调用 1 次；耗时 642ms
```

**破坏实现 → 守卫必红**（`--flip` 臂 `p276-flip-one-ps`：把 `team_orphan_candidates` 换成「每个 pid 调一次 `ps`」）：

```
  ✓ p276-flip-one-ps：还原 → 绿
  ✓ p276-flip-one-ps：破坏 → 指定用例红
```

夹具侧的 `ps` 垫片就是 brief 建议的那个做法，也是唯一能给**证伪**读数的做法（本机没有 strace 类工具）；垫片只在 census 组内装/卸，别的组一次都不会多一个 fork。

### 4.2 —— 任务书点名的变异打不到点名的断言

**修前红**：P284 在 `/tmp` 的变异树里实测 —— 把读数插到既有输出**之前**，4.2 自己的两条断言**照样是绿的**：它的归一化 `sed '/^孤儿席位进程/,$d'` 会把既有行连同后面的一起截掉，两份被截成同一段前缀；唯一红的是 4.1 的「读数块一致」。任务书点名的变异与点名的断言对不上。

**修后绿**（reading 组实跑）：

```
  ✓ 4.2 ps 的既有每一行逐字节不变（开/关普查；容量行在内的全部既有块）
  ✓ 4.2 ps 既有块【RAM 可用】在读数之前（读数整块在最后）
  ✓ 4.2 ps 既有块【存活：】在读数之前（读数整块在最后）
  ✓ 4.2 ps 既有块【MODEL】在读数之前（读数整块在最后）
  ✓ 4.2 ps 既有块【agent 会话】在读数之前（读数整块在最后）
  ✓ 4.2 ps 既有块【活跃窗口】在读数之前（读数整块在最后）
  ✓ 4.2 status 的既有每一行逐字节不变（开/关普查）
  ✓ 4.2 status 既有块【AGENT】在读数之前
  ✓ 4.2 status 既有块【session: OC2】在读数之前
  ✓ 4.2 status 既有块【BOARD：】在读数之前
```

**破坏实现 → 守卫必红**（`--flip` 臂 `p276-flip-into-capacity`：读数插进容量行之后）：

```
  ✓ p276-flip-into-capacity：还原 → 绿
  ✓ p276-flip-into-capacity：破坏 → 指定用例红
```

块名哨兵不是装饰：只比「两边相等」时，「读数插到开头」会把两份都截成空、照样相等 —— 那正是 P284 那个假阴性的形状。

### 7.5 —— 文档缺一段

**修前红**：`grep -rn -i orphan skills/teamsmith/references/` 里 `troubleshooting.md` 唯一的命中是**孤儿 tmux server**（temp-root 那一章，第 1186 行），席位进程孤儿只写在 `config.md`；「孤儿是什么、怎么清、为什么默认不清」这一段不存在。

**修后绿**：`troubleshooting.md` 新增 §28（验收的 `grep -rn 'TEAM_ORPHAN_SCAN' skills/teamsmith/references/` 命中它的第 1426 行，见上）；`config.md` 的 `TEAM_ORPHAN_SCAN` 行补上默认值与关掉后的三处行为。`team help` 的既有页面零改动 —— `help-surface.sh --select coverage` ✓9 ✗0 钉住这一条。

## Decisions and deviations

1. **4.2 的归一化怎么做（brief 把做法留给我）**：brief 写「断言既有每一行逐字节相同（容量行 / 存活块 / 模型表 / 会话块 / 窗口列表）」。两种直译做法都不行：① 直接比两次全量输出 —— 容量行每轮都变（`RAM 可用`、`临时根 … 可用`、`inode` 都是实时值，同一秒里两次也不会相同）；② `grep -v 'RAM 可用'` 丢掉那一行 —— 变异臂正好从那里逃掉（P284 已知）。所以：既有行统一抹平数字（`sed -E 's/[0-9]+/N/g'`），**并且**给每个既有块一条哨兵，断言「逐字节相同 **且** 这些块都落在读数之前」。容量行仍在被比对的集合里，只是不再被每轮都变的数字绑架；既有声明一条没有放宽。
2. **产品代码不动**：见上「产品代码一个字节没动」。
3. **`-ww` 保留**：粗筛是 `ps -ww -eo pid=,args=`（比清单多一个 `-ww`）—— P284 已在「实际做法注记」里注明「不截断长命令行，`argv[0]` 是全路径的真席位才不会被漏掉」；本次不改（读数断言按实际形态 `-eo pid=,args=` 的子串匹配，`-ww` 不影响它）。
4. **1.1 的耗时是读数不是断言**：见上「未断言」注记。
5. 其余按 brief 原文执行，没有范围扩张：不改 `smoke.sh`、不改 `section-*.tsv`、不加新契约键、不重写帮助页。

## Suggested next steps

- 三处 `[ ]`→`[x]` 已按证据勾上，新证据写成 `· 依据（P285 补齐）：…`（与 P284 的 `· 依据（P284 按证据核对）：…` 同风格），其余 28 行与 §0 / §8 零改动。`orphan-visibility` 的 apply 侧现在是 28/28。
- 建议 PM 复验时按「写的人不验自己的活」派**另一席位**，重点不是重跑绿侧（夹具自己会跑），而是核两件事：两条新臂的**变异方向**是否就是任务书点名的形状（`p276-flip-one-ps` = 每个 pid 一次 `ps`；`p276-flip-into-capacity` = 读数插进容量行），以及 1.1 的读数是否真的钉住了「先一次 `ps` 筛候选再读 `/proc`」。
- 复验通过后由 PM 归档本 change（`openspec/changes/orphan-visibility/` → archive）。
- 分支留在本地（local 模式）：`task/P285-orphan-gaps`，四个提交（本报告在内）。
