# P284 · 按证据勾选 orphan-visibility 的清单（归档前置）

agent: dev-bob   status: 交付（28 项勾选，3 项真缺口留空）   time: 2026-10-15T15:56Z
task: P284   phase: apply   category: code   change: orphan-visibility   deltas: -
branch: `task/P284-orphan-checklist`（local 模式：分支留本地，不推送、不合并）
受检树：勾选提交 `ff509408` + 合并提交 `02abc95b`（交付前已 `git merge main`，并入 `dc24026f` 与修订后的 V42 记录 `b879ba4c`）；本报告提交在其上

一句话：把 `openspec/changes/orphan-visibility/tasks.md` 的 §1–§7 共 31 项逐条对着**已提交的证据**核了一遍
——28 项勾选并在行末补证据指针，3 项（1.1 / 4.2 / 7.5）因为找不到任务书点名的证据而**留空**，单列在
「留空的 3 项（真缺口）」；§0（propose 阶段，原先已勾）与 §8（复验/PM 的 3 项）**一行未动**。

## Deliverables

| Path | What |
|---|---|
| `openspec/changes/orphan-visibility/tasks.md` | §1–§7 共 28 项 `[ ]`→`[x]`，每项行末补「· 依据（P284 按证据核对）：…」；3 项留空；§0 与 §8 零改动 |
| `docs/team/reports/P284-dev-bob.md` | 本报告 |

**原文零改写**（自查，可复跑）：剥掉我加的「· 依据（P284 按证据核对）：…」后缀、再把 28 个 `[x]` 还原成
`[ ]` 之后，与原文件（`git show HEAD:openspec/changes/orphan-visibility/tasks.md`，157 行）**逐行逐字节相同**，
差异 0 行。产品代码、夹具、规格、任务书一个字节没动。

## Verification evidence（brief 的三条验收命令，本分支树上实跑；合并 main 之后又重跑了一遍）

```
$ "$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict | tail -2
Totals: 21 passed, 0 failed (21 items)
rc=0

$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: root=$HOME/…/.worktrees/dev-bob scope=published files=1583 hits=0 names=ok user=resolved
rc=0

$ git diff --check; echo rc=$?
rc=0
$ git status --short
?? docs/team/reports/P284-dev-bob.md
```

- Verdict: pass（三条全绿；上面的 `git status` 是报告提交之前的那次 —— 勾选提交 `ff509408` 之后它只剩这份未跟踪的报告，报告提交在其上、提交后为空）。
- Notes: 完整 smoke 全量没跑（本任务只改清单与报告，产品零改动）；与普查有关的选段（§37 / §51b）的证据在
  P276-dev3.md 与 V42.md 里，本次用「本树复跑夹具」复核了它们指向的那份夹具。

## 本树复跑（把证据里「很快的那些」在当前树上重跑，免得指针只指向过往报告）

批次（后台作业 `p284-verify-batch`，148.2s，宿主 loadavg 1 分钟值 2–4 / 32 核，`/tmp` 余量充足）：

```
$ bash skills/teamsmith/tests/seat-visibility.sh | tail -2
== 结果 ==  ✓ 110  ✗ 0  SKIP 0            rc=0
$ bash skills/teamsmith/tests/seat-visibility.sh --flip | tail -2
== 结果 ==  ✓ 16  ✗ 0  SKIP 0             rc=0      （8 条逐条红侧全绿）
$ node skills/teamsmith/tests/panel-strings.mjs | tail -2
ok: contract-key labels — 122 schema keys covered in zh and en
panel-strings: ok                          rc=0
$ bash skills/teamsmith/tests/config-cli.sh | tail -2
== 结果 ==  ✓ 343  ✗ 0  SKIP 0            rc=0
$ bash skills/teamsmith/tests/help-surface.sh --select coverage | tail -2
== 结果 ==  ✓ 9  ✗ 0  SKIP 0              rc=0
$ bash skills/teamsmith/tests/section-select.sh --check | tail -2
== 选段自检 ==  ok 8  bad 0  SKIP 1       rc=0
$ perl skills/teamsmith/tests/signal-lint.pl --legacy /dev/null
signal-lint：干净（扫描 113 个脚本；pid 精确形态全部干净）   rc=0
```

合并 main 之后，交付树上又把前两条重跑了一次：`seat-visibility.sh` **✓110 ✗0**、`--flip` **✓16 ✗0**（rc 都是 0）。
（这次合并只带来 `docs/team/**` 三份账本文件，没有产品/夹具改动。）

## 留空的 3 项（真缺口）

### 1.1 —— 缺「一次普查的 fork/耗时读数」

任务书要的三段证据只到两段：夹具 `census` 组逐字段断言 ✓、真进程现场 ✓（P276-dev3.md §2.8、V42.md §1）。
第三段**在已提交的证据里不存在**。我查了：`docs/team/reports/P276-dev3.md` 全文、`docs/team/reviews/V42.md`
全文（含 §7 的 `/tmp` 与 loadavg 记录）、`skills/teamsmith/tests/seat-visibility.sh`（全文没有计时、没有
fork 计数）、`section-budgets.tsv` 的 51b 行（只有**夹具级**预算 33s，不是一次普查的读数）、smoke §51b
（只打印断言条数）。我没有代为测 fork 计数：本机没有 `strace` / `perf` / `bpftrace`，代测只能给耗时、
给不了 fork 数 —— 那仍然是这一段的半条。留空。

### 4.2 —— `--flip` 臂不存在，而且任务书点名的变异打不到任务书点名的断言

任务书要求一条 `--flip` 臂：「让读数插进容量行 → 必红」。夹具现有 8 条臂（`shape` / `current-window` /
`default-server` / `unjudged` / `naming` / `panel` / `hint-line` / `verify`），要求红侧的 9 项
（1.4 / 2.2 / 2.3 / 2.4 / 3.4 / **4.2** / 4.5 / 5.2 / 6.6）正好少这一条。

我不只数了臂，还在 `/tmp` 的变异树里把这条变异做出来（把 `team_orphan_reading` 插到 `ps` / `status` 既有
输出**之前**，对照 `--select reading`）：

```
$ bash /tmp/p284-mut/tests/seat-visibility.sh --select reading | sed 's/\x1b\[[0-9;]*m//g' | grep -E '✓ 4\.|✗|== 结果 =='
  ✓ 4.2 ps 的既有每一行逐字节不变（开/关普查）
  ✓ 4.2 status 的既有每一行逐字节不变（开/关普查）
  ✗ 4.1 ps/status 的读数块逐字节一致：期望 [孤儿席位进程（主机侧 /proc 普查；…）
== 结果 ==  ✓ 16  ✗ 1  SKIP 0
rc=1
```

4.2 自己的两条断言**照样是绿的**：它的归一化是 `sed '/^孤儿席位进程/,$d'`，而读数块以这个标记开头
（`TEAM_ORPHAN_SCAN=0` 时也是），插到前面会把既有行连同后面的一起截掉，两份被截成同一段前缀。
唯一红的是 4.1 的「`ps`/`status` 的读数块逐字节一致」。

所以这不是「忘了写臂」那么简单：**任务书点名的变异打不到任务书点名的断言**。可选的修法（留 PM 裁）：
把 4.2 的归一化改成位置无关（例如断言读数块必须在最后，或把读数块**整块过滤**而不是从标记处截断），
或者把这条红侧臂改挂在能红的 4.1 断言上（要点名是「读数块必须一致地落在同一个位置」）。我留空、原文未改。

### 7.5 —— `references/troubleshooting.md` 的那一段没写

`references/config.md` 的三个键说明与「孤儿/清理」一段都在（第 174–185 行）。但任务书点名的那段
「孤儿是什么、怎么清、为什么默认不清」在 `references/troubleshooting.md` 里**没有**：该文件唯一的
`orphan`（第 1186 行）讲的是**孤儿 tmux server**（temp-root/sweep 那一章），不是席位进程。
`grep -rn -i orphan skills/teamsmith/references/ skills/teamsmith/SKILL.md README.md` 命中四个文件：
`config.md`（席位进程孤儿，唯一）、`troubleshooting.md`（孤儿 socket）、`memory.md`（第 87 行：路径被移动后
会话记忆被 orphaned）、`openspec.md`（第 124 行：no orphan tasks）。P276-dev3.md 的 Deliverables 表里也
没有列这份文档。这一半没做，留空。

## 实际做法注记（与清单原文不同、但不构成缺口；原文一字未改）

- **1.1 的粗筛是 `ps -ww -eo pid=,args=`**（清单写 `ps -eo pid=,args=`）。多出来的 `-ww` 是不截断长命令行 ——
  正是「argv[0] 是全路径」的真席位不被漏掉的原因（夹具 1008 用例）。
- **1.3 没有专门造「记录比进程新」的用例**：`state/<席位>.env` 的 task 与来源表头都打出来了，但夹具只断言了
  `记录任务=P276` 这个字段（V42 §1 用 `V42CHK` 独立核过它确实来自 env 文件）。已在行末注明。
- **3.1 打印的命令带 `--yes`**（`team reap <pid> --yes`，清单写 `team reap <pid>`）：不带 `--yes` 只是计划态，
  所以读数给的是可执行形态。
- **5.2 的红侧落在夹具、不在 smoke §37**：`m50_dg_norm` 只滤 `RAM 可用` 那一行，独立提示行会同时出现在
  cache 开/关两份输出里，所以「让提示变成独立一行 → M50 必红」这条路径**没有被证明会红**；真正会红的是夹具
  5.1 的「`RAM 可用` 那行必须带着提示」与 `p276-flip-hint-line`（本树 `--flip` ✓16 ✗0）。已在行末注明。
- **6.3 的「调用者自己及其祖先」一臂不在夹具里**（夹具 6.3 有身份为空 / 非席位形状 / 名字拒收 / 名字像的
  进程 / 别的项目），它只在 V42.md §5b 的自造现场里。已在行末注明。
- **7.4 的夹具名是 `tests/seat-visibility.sh`**（清单预计 `tests/orphan-census.sh`），组名
  census/judge/naming/reading/hint/seams/reap，挂在段 51b。§9 的验收命令里也还写着 `orphan-census.sh`
  （原文未改；实际跑的是 `seat-visibility.sh`）。

## 逐条勾选一览（§1–§7，31 项）

| 项 | 判定 | 依据（短；完整指针在 tasks.md 行末） |
|---|---|---|
| 1.1 | 留空 | 见上「留空的 3 项」 |
| 1.2 | 勾 | P276-dev3.md（Requirement 对照）；夹具 census 1006 + 从别的项目调用；V42 §3 反方向 |
| 1.3 | 勾 | 夹具 census 1002（无记录 / 缺 stat / 缺 status）；V42 §1 表；注记见上 |
| 1.4 | 勾 | 臂 `p276-flip-shape`；本树 `--flip` ✓16 ✗0；V42 §2 红侧① |
| 2.1 | 勾 | 夹具 judge 组六个方向；V42 §2 四族 + §5b |
| 2.2 | 勾 | 臂 `p276-flip-current-window`；本树 `--flip` ✓16 ✗0；V42 §2 红侧② |
| 2.3 | 勾 | 臂 `p276-flip-default-server`；本树 `--flip` ✓16 ✗0；V42 §2 红侧③ |
| 2.4 | 勾 | 臂 `p276-flip-unjudged`；本树 `--flip` ✓16 ✗0；V42 §2 红侧④ |
| 3.1 | 勾 | 夹具 naming 组逐条断言；V42 §1；本树 ✓110 ✗0；注记见上 |
| 3.2 | 勾 | 夹具 naming 组零点名 + `≥` 下限 + 未判定分桶；V42 §3；本树 `ledger-ban` rc=0 |
| 3.3 | 勾 | 夹具 naming 组两条「恰好一行、零命令」；V42 §6b |
| 3.4 | 勾 | 臂 `p276-flip-naming`；本树 `--flip` ✓16 ✗0 |
| 4.1 | 勾 | 夹具 reading 组；V42 §4（`up --print` 树哈希）；cmd-watch.sh 的行序（读码） |
| 4.2 | 留空 | 见上「留空的 3 项」 |
| 4.3 | 勾 | 夹具 reading 组只读 + seams 组四种边界；P276-dev3.md Requirement 对照 |
| 4.4 | 勾 | 夹具 reading 组面板面；smoke §37 的 M50-③b；V42 §4 |
| 4.5 | 勾 | 臂 `p276-flip-panel`；本树 `--flip` ✓16 ✗0；V42 §4 末段 |
| 5.1 | 勾 | 夹具 hint 组（阈值三条 + 行尾 + rc=0）；V42 §4 |
| 5.2 | 勾 | 臂 `p276-flip-hint-line`；本树 `--flip` ✓16 ✗0；机制差异见注记 |
| 6.1 | 勾 | 夹具 reap 组 6.1（计划态 / `kill -0` / `reap.log` / rc）；V42 §1 |
| 6.2 | 勾 | 夹具 reap 组 6.2（真进程 + 审计字段逐条）；V42 §1、§5 |
| 6.3 | 勾 | 夹具 reap 组（空身份 / 非形状 / 名字 / 别的项目零点名）；V42 §5、§5b；注记见上 |
| 6.4 | 勾 | 夹具 reap 组 6.4a/6.4b（FIFO 假根）；V42 §5b 两条 TOCTOU |
| 6.5 | 勾 | 夹具 reap 组 6.5 授权矩阵四组；V42 §5b（另加 `TEAM_REAP_YES=1`） |
| 6.6 | 勾 | 臂 `p276-flip-verify`；本树 `--flip` ✓16 ✗0 |
| 6.7 | 勾 | 夹具 6.7 静态走查；本树 `signal-lint.pl --legacy /dev/null` rc=0（113 脚本）；V42 §5 |
| 7.1 | 勾 | `commands.tsv` 的 `cmd reap` 行 + 两级语言 reap 页；本树 help-surface coverage ✓9 ✗0 |
| 7.2 | 勾 | smoke.sh 的 `m50_st_norm` + 四条哨兵；P276-dev3.md §2.6/§2.7（段 37 ✓23 ✗0）；V42 §4 |
| 7.3 | 勾 | schema 三行 + tmpl + config.md + 面板 zh/en 标签；本树 panel-strings ok、config-cli ✓343 ✗0；V42 §6c（段 26 沙盒比对） |
| 7.4 | 勾 | `section-paths.tsv` 第 140 行 + `section-budgets.tsv` 第 143 行；本树 `section-select --check` ✓8 ✗0；注记见上 |
| 7.5 | 留空 | 见上「留空的 3 项」 |

§0 的 4 项（propose，原已勾）与 §8 的 3 项（提案复核 / 独立复验 / 归档门）**一行未动**，按 brief 留给 PM。

## 未做 / 交回 PM

- **三处留空请 PM 裁**：① 1.1 要不要接受夹具级耗时/预算当「一次普查的读写」证据（我没有代测 fork 数）；
  ② 4.2 是改断言（位置无关）还是改臂（挂到 4.1 那条）——需要 PM 定；③ 7.5 补不补 troubleshooting 那一段。
- **§8.1–8.3 一行未动**（复验阶段）。
- **完整 smoke 全量没跑**：本任务只改清单与报告，产品零改动；与普查相关的选段证据在 P276/V42 里，
  本次用「本树复跑夹具 ✓110 ✗0 + `--flip` ✓16 ✗0」复核了它指向的夹具本身。
- 分支 `task/P284-orphan-checklist` 留在本地（local 模式）：勾选提交 `ff509408`、合并提交 `02abc95b`（并入
  `dc24026f` 与 `b879ba4c`）、本报告提交在其上；合并后三条验收命令与两条夹具命令重跑全绿（见上）。
