# M50 · 读操作性能：仓库根一次解析 + 进程内扫描（A 段交付报告）

agent: dev2   status: DONE   time: 2026-09-21T02:12:00Z
branch: `task/M50a-m50`（内容 = M50 分支 `task/M50-digest-89s` 的 tip `d46fd4e` ＋ 本报告与证据；**实现零改动**。local 模式不 push，PM 复验后本地合并）   PR/MR: -

## 0 · 任务与边界

M50 的实现已经在磁盘上（6 个提交，tip `d46fd4e`），但作者 dev 三轮会话没能交付报告；M50a 由 dev2
把**已经完成的活**写成可复验的报告与证据 —— 不重新实现、不改 `skills/teamsmith/**` 的任何文件。
本分支相对 `d46fd4e` 的改动只有 `docs/team/reports/M50-dev*`（§7 有 diff 证明）。

## 1 · Deliverables（交付物）

| Path | What |
|---|---|
| `docs/team/reports/M50-dev.md` | 本报告（M50 的交付报告） |
| `docs/team/reports/M50a-dev2.md` | M50a 的精简报告（同一结论；`team review M50a` / `team_find_report` 按任务名前缀取报告，需要这个名字） |
| `docs/team/reports/M50-dev/pkg/run.sh` | 独立复现包入口：base/main/after 三实现 × 同一份真语料，gitshim 计数 + 墙钟 + 逐行对照（`lib.sh` + `10-perf.sh` + `20-parity.sh` + `30-flip.sh`，用法见 `pkg/README.md`） |
| `docs/team/reports/M50-dev/evidence/probe-run.txt` | 复现包这次运行（2026-09-21T02:05Z）的完整输出（✓12 ✗0 finding 2） |
| `docs/team/reports/M50-dev/evidence/*-digest-calls.txt` | main / M50 / 缓存关三种跑法的 git argv 汇总（`uniq -c`） |
| `docs/team/reports/M50-dev/evidence/digest-*.diff` | 逐行对照的原始 diff（base-vs-after 与 cacheoff-vs-on 是 0 字节 = 逐字节一致） |
| `docs/team/reports/M50-dev/evidence/digest-*.out` | main / base / after 三份 digest 全文 |
| `docs/team/reports/M50-dev/evidence/{fast,full}-smoke.log` | 两次门禁的全文日志（已去 ANSI 色） |
| `docs/team/reports/M50-dev/evidence/{smoke-34.txt,gate-totals.txt,openspec-validate.txt}` | 34 段实际结果行、三段门禁的总计行、openspec 原始输出 |

M50 的实现（**本任务未改**，供对照理解 A 段覆盖表）：

| 提交 | 内容 |
|---|---|
| `b3afe08` | PM 替 dev 提交的 wip 快照：根解析一次 + 进程内扫描骨架（6 文件 +836 行） |
| `b3357f1` | 回退 doctor 的耗时块（B 段重切范围之外；块保留在 `b3afe08` 供后续任务复活） |
| `c545f7f` | smoke 第 34 段：根一次 + 单进程扫描守卫（36 报告 + 3 复验记录夹具；cache-off > 50 非空转；含 `[3]` 34 行生产者回归钉） |
| `0518bb1` | 坏源等价：BOARD 不可读时 loader 不死、读者逐个回落直读；smoke 26-i 注入 shim 随之改道 |
| `b9ca5d5` | `set -e` 下 `team__review_subject_tip` / `team_resolve_branch` 的 rc 捕获修复 + 34 段加固 |
| `d46fd4e` | 预热分档（breadth / `--reports`）：status 与轻面板块不再为报告 trio 付账 |

## 2 · A 段覆盖表（M50a brief 的四条）

| A 项 | 做了没有 | 证据在哪 |
|---|---|---|
| **A1 仓库根一次解析**（`team board row <ID>` 的 git 调用 ≤ 1） | ✅ 做了 | 实现：`common.sh` 的 `team_dir_roots_load`（一次 `rev-parse --path-format=absolute --show-toplevel --git-common-dir`）＋ `_TEAM_DIR_ROOTS_MEMO` 进程级 memo；`team_load_config` 在身份已锁定时不再重问 `team_is_git_repo`。证据：smoke 34 ①/①b/①c 全绿（`evidence/smoke-34.txt`）；本报告 §3 真语料 3→1（两次独立采样一致） |
| **A2 digest / status / panel-data 单进程扫描**（digest git 调用 ≤ 50，判定逐条不变） | ✅ 做了 | 实现：`common.sh` 的扫描缓存层（BOARD 列/行/状态、worktree→branch、refs tip、复验抬头、保护分支 tree 集、工作树 reports 跟踪/脏集、agent state、逐 id 判定 memo）＋ `team_scan_warm [--reports]` 两档预热 + 写路径 `team_scan_invalidate` + `TEAM_SCAN_CACHE=0` 整体回落；digest / status / `__panel-data` 都在单进程内扫描。证据：smoke 34 ②/②b/②c/③/③b 全绿；本报告 §3（1692→36）与 §4（与基点逐字节一致） |
| **A3 gitshim 前后数字** | ✅ 做了 | 本报告 §3（自建 shim，**没有**复用 dev/PM 留在 `/tmp` 的现场）；原始输出 `evidence/probe-run.txt` + `evidence/before-digest-calls.txt` + `evidence/after-digest-calls.txt`；复跑入口 `docs/team/reports/M50-dev/pkg/run.sh 10` |
| **A4 门禁** | ✅ 做了 | 本报告 §5：openspec 15 passed / 0 failed；FAST smoke ✓1890 ✗0；full smoke ✓2379 ✗0；smoke 34 段 17 条实际结果行照贴；全文日志在 `evidence/fast-smoke.log` 与 `evidence/full-smoke.log` |

## 3 · Verification evidence：前后实测（gitshim + 墙钟）

### 3.1 方法（`pkg/run.sh 10` 可一键复跑）

- 三个**实现树**用 `git archive` 从对象库取出到临时目录（不碰任何工作树）：
  `main` = `76cdc7d`（当前保护分支）、`base` = `5060604`（M50 基点）、`after` = 本分支 tip `d46fd4e`；
- 三条命令都从**本工作树**（`.worktrees/dev2`）的同一份真语料上跑（`BOARD.md` 139 行 / 13.7KB；
  `docs/team/reports` 16M；`docs/team/reviews` 2.8M；5 个 agent 工作树）；
- PATH 最前放一个记录 argv 的 `git` 包装器（`printf '%s\n' "$*" >> "$M50A_GITLOG"; exec /usr/bin/git "$@"`），
  计数 = `wc -l`；墙钟 `/usr/bin/time -f '%e'`；
- 每条命令跑前清空 gitlog；身份变量（`TEAM_ROOT` / `TEAM_MAIN_ROOT` / …）显式清掉，避免继承的会话身份串味。

### 3.2 数字（2026-09-21T02:05Z，复现包本次运行）

| 命令 | main（旧实现） | after（M50 分支） | 变化 |
|---|---|---|---|
| `team board row M48` | 3 次 git / 0.04s | **1 次 / 0.06s** | 根解析 3→1 |
| `team board ls` | 3 次 / 1.28s | **1 次 / 0.14s** | 3→1 |
| `team digest` | **1692 次 / 62.55s** | **36 次 / 3.37s** | 调用 ≈47×↓、墙钟 ≈18.6×↓ |
| `team status` | 38 次 / 0.72s | 24 次 / 0.77s | 只降调用（墙钟在本机是噪声） |
| `team __panel-data --no-activity` | 35 次 / 2.19s | 30 次 / 1.93s | 同上 |

三次独立采样互相印证（同一方法、同一机器、不同时间）：

| 采样 | digest 前后 | 墙钟前后 |
|---|---|---|
| dev2 首次探针（01:50Z） | 1694 → 37 | 63.81s → 3.50s（第二遍 3.42s） |
| dev2 复现包复跑（02:05Z） | 1692 → 36 | 62.55s → 3.37s |
| PM 侧（M50 brief 背景） | 1708 → 37 | 63.5s → 3.44s |

±1~2 次调用的抖动来自两次运行之间语料/工作树状态变化（例如本轮新增的证据目录），不是实现差异。

### 3.3 1692 次是从哪来的（旧实现头号调用，`evidence/before-digest-calls.txt`）

```
    353  -C …/.worktrees/dev-bob  rev-parse --abbrev-ref HEAD
    349  -C …/.worktrees/verify   rev-parse --abbrev-ref HEAD
    321  -C …/.worktrees/dev3     rev-parse --abbrev-ref HEAD
    253  -C …/.worktrees/dev      rev-parse --abbrev-ref HEAD
    209  -C …/.worktrees/dev2     rev-parse --abbrev-ref HEAD
     87  -C …/pm-skills           for-each-ref --format=%(refname:short) refs/heads/task/
```

= **1485 次「每份报告问一次它在哪个分支」** + 87 次「每条待复验记录列一次 refs」（for-each-ref）
+ 每份报告三次 `rev-parse/ls-files/diff` 的逐文件提问 + 每次辅助调用重复解析仓库根。

M50 分支的 36 次是**每工作树一轮固定 6 条**（`status --porcelain`、`rev-parse HEAD^{tree}`、
`@{upstream}`、`rev-list --count main..HEAD`、`ls-files -- docs/team/reports`、`diff --name-only HEAD -- …`）
× 5 个工作树 = 30，加主仓 5 条（`worktree list`、`status --untracked-files=all`、`ls-files`、
`log --format=%T --max-count=200 main`、`for-each-ref refs/heads/`）与 dev2 的 1 次根解析
（新形状：`rev-parse --path-format=absolute --show-toplevel --git-common-dir`）。
完整 36 行清单见 `evidence/after-digest-calls.txt`。

## 4 · Verification evidence：内容一致性（逐行对照）

对照前做同一套规范化（`pkg/lib.sh` 的 `m50a_norm`，对三份输出一视同仁）：去掉 `RAM 可用` 容量行、
首行时间戳、`（<pid>，proof=argv）`、`  skill …` 会话版本行。

| 对照 | 结果 | 证据 |
|---|---|---|
| **base（5060604，M50 之前）vs after** | **逐字节一致**（diff 0 字节） | `evidence/digest-base-vs-after.diff`（空）+ `digest-base.out` / `digest-after.out` |
| **main vs after** | **只有 1 行差异**，且正是已知的 M48 行 | `evidence/digest-main-vs-after.diff` |
| `[3] 待复验` 段 base vs after | 逐字节一致（6 行） | `pkg/20-parity.sh` 的断言 ③ |
| 缓存关 vs 开（同一实现） | 逐字节一致（diff 0 字节） | `evidence/digest-cacheoff-vs-on.diff`（空） |

差异原文（`evidence/digest-main-vs-after.diff`）：

```diff
@@ -2,7 +2,6 @@
 
 [1] 容量与存活
   待办             无（pulse 不会打扰 PM）
-!   BOARD 有重复 ID：V1.1 ×2、M4.3 ×2、M6.3 ×2（board add 会拒绝新重复；board set / assign 按 ID 寻址）
```

**已知并需解释**：M50 分支基点（`5060604`）早于 M48，这条「BOARD 有重复 ID」提示由 M48 引入 ——
分支输出少的是**基点旧**，不是 M50 的回归。main 的 `docs/team/BOARD.md` 当前确有 V1.1 / M4.3 / M6.3
三组重复 ID，合并后该行应当回来（PM 会另跑一次确认）。

## 5 · Verification evidence：门禁

### 5.1 命令与结果（FAST 在报告提交前先跑了一次；提交后的重跑见文末 Acceptance stamp）

```
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
Totals: 15 passed, 0 failed (15 items)                              # rc=0

$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
== 结果 ==  ✓ 1890  ✗ 0                                             # rc=0（tip d46fd4e）
smoke 全绿

$ bash skills/teamsmith/tests/smoke.sh </dev/null
== 结果 ==  ✓ 2379  ✗ 0                                             # rc=0（全量，tip d46fd4e）
smoke 全绿
```

### 5.2 smoke 第 34 段（root-resolved-once + single-process scan）实际结果行

```
== 34 · 读路径性能：根一次解析 + 单进程扫描（M50） ==
  ✓ M50 夹具仓库 init 成功
  ✓ M50 隔离：team paths 的 main_root 就是 M50 夹具仓库
  ✓ M50 隔离：身份用的是本轮临时 session
  ✓ M50 夹具有效：60 份报告文件（含工作树副本）+ 3 条复验记录就位
  ✓ M50 夹具有效：去重后的主候选 36（主仓 12 + bob 12 + carol 12）
  ✓ M50-① board row 的 git 调用数 ≤ 1（实测 1）
  ✓ M50-① board row 真的读到了那一行（不是空输出蒙混）
  ✓ M50-①b 子目录里 board row 的 git 调用数 ≤ 1（实测 1）
  ✓ M50-①c cache 开/关 board row 输出逐字节一致
  ✓ M50-② digest 的 git 调用数 ≤ 50（实测 19）
  ✓ M50-② digest 真的扫到了工作树里的报告（不是空扫描蒙混）
  ✓ M50-② SKIPPED 记录照旧带标记列出（判定语义没动）
  ✓ M50-②c [3] 待复验列全 34 行（生产者不在带记录的报告上死掉）
  ✓ M50-②b 夹具非空转：cache-off 同口径 260 次 git > 50（旧形状会被这扇门抓住）
  ✓ M50-②c digest cache 开/关输出逐字节一致（滤时间戳与容量行）
  ✓ M50-③ status cache 开/关输出逐字节一致（滤容量行）
  ✓ M50-③b __panel-data cache 开/关逐字段一致（掩 timestamp 与 capacity 块）
```

## 6 · Flip evidence（非空转：同一判据抓得住旧形状）

M50a 本身不改实现，没有「定点破坏 → 守卫变红」的翻转形状；A 段的判据用**双向**证据钉住：

**red（失败侧 = 旧形状）**：`team digest` 在旧形状下 git 调用必须 > 50 —— 实测三种旧形状全部越线：

```
✗ main（旧实现）                : 1692 次 > 50   （§3；同一判据会红）
✗ M50 分支 · TEAM_SCAN_CACHE=0  : 1690 次 > 50   （实现自带的对照开关 = 旧的逐文件形状）
✗ smoke 34 夹具 · cache-off     :  260 次 > 50   （evidence/smoke-34.txt）
```

**green（通过侧 = M50 实现）**：

```
✓ M50 分支 · 缓存开             :   36 次 ≤ 50   （真语料；墙钟 3.37s）
✓ smoke 34 夹具 · 缓存开        :   19 次 ≤ 50
✓ team board row M48            :    1 次 ≤ 1    （真语料；旧实现 3 次）
```

复跑入口：`bash docs/team/reports/M50-dev/pkg/run.sh 30`（并断言关/开两侧 digest 输出逐字节一致 ——
`evidence/digest-cacheoff-vs-on.diff` 为 0 字节）。结论：≤1 / ≤50 这扇门不是空转；若哪天实现回归到
逐文件子进程，它在真语料上就会红（而不是「文档里说快了」）。

## 7 · 实现零改动的证明

本分支只在 `d46fd4e` 之上新增报告与证据目录；`skills/teamsmith/**` 一行未改（提交后重跑）：

```
$ git diff --stat d46fd4e..HEAD -- skills/teamsmith
（空）
$ git diff --stat d46fd4e..HEAD
 docs/team/reports/M50-dev.md     | … 
 docs/team/reports/M50a-dev2.md   | …
 docs/team/reports/M50-dev/…      | …
```

## 8 · 未完成项（B 段：明确未做）

| B 项 | 状态 | 原因 |
|---|---|---|
| `state/board-index.json` 派生索引 | **未做** | PM 2026-09-20T17:0x 重切范围：M50 本次只交 A 段，B 段另立任务 |
| 性能门槛断言（digest < 5s / panel-data < 1.5s） | **未做** | 同上；当前只有 smoke 34 的 **git 调用数**判据（与机器无关），没有墙钟断言 |
| doctor 报告读路径耗时 | **未做** | 同上。dev 的快照里实现过（`b3afe08` 的 `cmd-project.sh` +18 行），已按重切范围在 `b3357f1` 回退，内容保留在 `b3afe08` 供后续任务复活 |

## 9 · 结论：PARTIAL（A 段全交；B 段按 PM 重切范围未做）

- M50 **A 段**：全交 —— 根解析一次与单进程扫描都已实现并有守卫（smoke 34），门禁 openspec / FAST /
  full 全绿，真语料前后数字独立复现（1692→36 次、62.55s→3.37s），与基点输出逐字节一致（判定语义没动）。
- M50 **B 段**：未做，原因是 PM 已把 M50 重切为「只交 A」（`M50-digest-perf.md` 的「重切范围」段），
  B 留给后续任务；这不是遗漏。
- M50a 自身（把已完成的活写成报告 + 证据）：交付完成。未发现实现问题，**无 `BLOCKED:`**。

## Decisions and deviations

- **报告命名**：主报告按 M50a brief 的指定写成 `docs/team/reports/M50-dev.md`（沿用 M50 约定）；
  另加 `docs/team/reports/M50a-dev2.md` 精简版，因为 `team review M50a` / `team_find_report` 按
  任务名前缀取报告。两者结论一致，精简版不引入新结论。
- **before 的口径**：按 brief 用 `main`；另加 `base=5060604`（M50 之前）对照 —— main 与分支之间
  混着 M48/M49/M51 的改动，只有基点对照能单独证明「M50 自己的改动不改判定」。
- **不复用旧现场**：没有用 dev / PM 留在 `/tmp` 的 gitshim 与测量输出，全部用 `git archive` +
  自建 shim 重跑（`pkg/` 可一键复现）。
- **prod 语义未验证项**：无。判定语义的等价性用「基点 vs 分支逐字节一致 + cache 关/开逐字节一致」
  两层钉住；M48 那行差异已定位为基点旧。

## Acceptance stamp（报告提交后的重跑）

下面这组命令在**报告与证据提交之后的 tip** 上重跑（报告提交 `2d7e3fa`，本 stamp 提交紧随其后；
实现 tip 仍是 `d46fd4e`，报告提交是 docs-only）：

```
$ git -C .worktrees/dev2 status --porcelain
（空 —— 只应有报告相关改动；提交后为空）
$ git diff --stat d46fd4e..HEAD -- skills/teamsmith
（空 —— 实现零改动）

$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
Totals: 15 passed, 0 failed (15 items)                              # rc=0

$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
== 结果 ==  ✓ 1890  ✗ 0                                             # rc=0
smoke 全绿
```

本次重跑全文：`evidence/fast-smoke-final.log`（与 `evidence/fast-smoke.log` 同为 1890/0，
后者是实现 tip `d46fd4e` 上带的 34 段结果来源）。

## Suggested next steps

- 合并后：PM 在 main 上复跑一次 `team digest`，确认 `!   BOARD 有重复 ID：…` 行仍在（M48 的行为）。
- 另立任务做 B 段：派生索引 `state/board-index.json`（硬约束：索引 == 直接解析）、性能门槛断言、
  doctor 耗时报告；`b3afe08` 里有可复活的 doctor 块。
- 若想要**墙钟**门槛：本机 `status` 的墙钟是噪声（38→24 次调用、0.72→0.77s），digest 的 62.55s→3.37s
  则差距巨大；墙钟断言应在负载可控的环境里设，并带负载前提（P27 的既有纪律）。
