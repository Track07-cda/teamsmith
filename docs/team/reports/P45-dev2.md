# P45 · change-centric-discipline B2：digest 的 `[6]` 段 + 面板的 change token

agent: dev2   status: DONE（分支未合并：local 模式交 PM 复验）   time: 2026-09-22T16:13:30Z
branch: `task/P45-change-centric-discipline-b2`   PR/MR: -（local 模式：不 push，分支留在本地 worktree）

phase: apply · change: `change-centric-discipline` · deltas: `board-and-status` —— **没有改 delta 文本**，
只实现它（B2 的 requirement 已在 P23 写定）。

## Deliverables

| Path | What |
|---|---|
| `skills/teamsmith/scripts/lib/cmd-status.sh` | digest 的 `[6] change 归组` 段 + `team_change_token_text` / `team_change_group_lines` |
| `skills/teamsmith/scripts/lib/cmd-watch.sh` | `team_panel_change_tasks_json`；`team_panel_changes_json` 每个 change 带 `tasks` / `tasks_more` |
| `skills/teamsmith/scripts/panel/src/types.ts` | `ChangeTaskToken`；`ChangeRow.tasks` / `tasks_more` |
| `skills/teamsmith/scripts/panel/src/layout.ts` | change 行下的 token 行；宽度不够**整行丢弃**（不截断、不折行、不重排） |
| `skills/teamsmith/scripts/panel/panel.js` | 重建的 bundle（两次构建字节一致，sha256 `ee770bad…`） |
| `skills/teamsmith/tests/smoke.sh` | 新段 `12f · change 归组（P45/B2：digest 的 [6] 段 + 面板 token）`（27 条断言） |
| `docs/team/reports/P45-dev2.md` + `pkg/` | 本报告、翻转台 `flip.sh`、原始日志与比对产物 |

提交：`18ed2754`（digest [6]）· `882b646c`（面板 + bundle）· `670a79d3`（smoke 12f）· 本报告（末条）。

## 真源对账（`openspec/changes/change-centric-discipline/tasks.md` §2）

| 项 | 状态 | 证据 |
|---|---|---|
| 2.1 digest `[6]`：每行一个未归档 change（有界行宽）、token + readiness、两个标记、无事一条 dim 空行、`[1]`–`[5]` 不重编号 | ✅ | `pkg/12f-section.txt`（12f 断言 1–10）；`pkg/section-headers-bytes.txt`（前六行 `cmp` 无差异） |
| 2.2 面板：每个 change `tasks` 数组（id/phase/board/verdict，≤8）+ `tasks_more`；布局在 change 行下画 token 行、放不下整行丢弃 | ✅ | 12f 断言 12–13（JSON）+ 17–22（布局）；`pkg/flip-c.out` 是这一条的翻转 |
| 2.3 smoke 新段 `12f` | ✅ | `pkg/12f-section.txt`：27 ✓ / 0 ✗ |
| 2.4 翻转：只去掉面板读取的归组（digest 侧保留）→ 面板断言红、字节稳定性绿 | ✅ | `pkg/flip-d.out`：5 红（2 条 JSON + 2 条布局 + 1 条对照）而两条 `--print/--json 逐字节一致` 仍是绿 |

## Verification evidence（都是真跑过的）

### 门禁 ①：`openspec validate --all --strict`

```
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
...
Totals: 24 passed, 0 failed (24 items)
rc=0
```

### 门禁 ②：`TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null`

```
$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
== 结果 ==  ✓ 2394  ✗ 1
rc=1
```

唯一红是 `40 lint`，**与 P45 无关、在 P45 的第一条实现提交之前就红**（见下「既有红」）；12f 段 27 条全绿。
完整日志 `pkg/fast-gate.log`。

### 门禁 ③：交付前的全量 `bash skills/teamsmith/tests/smoke.sh </dev/null`

```
$ bash skills/teamsmith/tests/smoke.sh </dev/null
== 结果 ==  ✓ 2925  ✗ 1
rc=1
```

同样是那一条既有红（`40 lint`）；`12f` 段在这条 2925 条断言的全量跑里也是 **27 ✓ / 0 ✗**，
`28-c 快照`、`M50-②`（20 次 git）、`35/38-a/38-b/38-g` 全绿。完整日志 `pkg/full-gate.log`。

（这次全量跑在 `9955ca6d` 上；之后只追加了 `pkg/full-gate.log` 本身 —— `docs/team/**` 不在任何段落的
扫描面里：0d 只看冲突标记、14b 明确不扫 `docs/**`、40 只扫 `tests/**`。）

### 新段 `12f` 单独跑一遍

smoke 没有段选择器，段输出是从门禁日志里整段摘出来的（`pkg/12f-section.txt`，与 P24 的 report 同做法）：

```
== 12f · change 归组（P45/B2：digest 的 [6] 段 + 面板 token） ==
  ✓ 12f [6]：alpha 的 token 与 not-ready 标记
  ✓ 12f [6]：任务指向不存在的目录 → 标记点名
  ✓ 12f [6]：目录没有任务指向 → 标记
  ✓ 12f [6]：change: - 的任务不归任何 change
  ✓ 12f [6]：token 上限 8 + 「+N」尾巴
  ✓ 12f [6]：第 9 个任务不打印（token 有界）
  ✓ 12f [1]–[5] 段头逐字节不变、新段是 [6]
  ✓ 12f [6] 的 token 与 team change status alpha 一致
  ✓ 12f [6]：change 列表有界（8 行 + 「+N」尾巴）
  ✓ 12f [6]：无事时一条 dim 空行
  ✓ 12f 面板：__panel-data --block changes 是合法 JSON
  ✓ 12f 面板：alpha 的每个 token 带 id/phase/board/verdict（M1 PASS）
  ✓ 12f 面板：token 数组有界（8 个 + tasks_more=2）
  ✓ 12f 机器出口：--print 渲染出了帧（后面的「不该出现」断言不是空跑）
  ✓ 12f 机器出口：--print 不带 change 的 token（console-only）
  ✓ 12f 机器出口：--json 的 panel 里没有 tasks 字段（console-only）
  ✓ 12f 机器出口：变化真的落在面板块里（字节不变的对照成立）
  ✓ 12f 机器出口：change 数据面变化前后 --print 逐字节一致（滤时间戳）
  ✓ 12f 机器出口：change 数据面变化前后 --json 逐字节一致（滤时间戳）
  ✓ 12f 布局：160 列帧渲染出来了
  ✓ 12f 布局：放得下的 token 行照常渲染
  ✓ 12f 布局：放不下的 token 行整行丢弃（不截断、不折行）
  ✓ 12f 布局：丢弃那一行后与「本来就没有这些 token」逐字节一致（不重排布局）
  ✓ 12f 布局：宽度够（270 列）时 token 行渲染出来
  ✓ 12f 布局：270 列的帧没有行溢出（最长 270 列）
  ✓ 12f 读成本：digest 的 git 调用数 ≤ 50（实测 4）
  ✓ 12f 读成本：计数那一跑真的渲染了 [6] 段（不是空转）
```

## `[1]`–`[5]` 段头的字节比对

`pkg/section-headers-bytes.txt`：拿基线（`69979035` 的 `cmd-status.sh`）与实现各跑一次 digest，`grep '^\['`
之后 `head -6 h.new | cmp - h.base` **无差异**；第 7 行才是新增的 `[6] change 归组`。12f 里另有一条把
这六行钉成字面量的断言（`12f [1]–[5] 段头逐字节不变、新段是 [6]`），所以将来谁改了老段头，门禁会红。

## digest 的耗时与读成本（任务书：把耗时读数报出来）

`pkg/digest-cost.txt`（同一个工作树、同一份 `docs/team`，只换 `cmd-status.sh`）：

```
variant  time     git_calls
base     5.63s    40        (69979035 的 cmd-status.sh)
new      6.36s    50        (本任务实现)
```

- 多出来的 10 次 git 全是 readiness 判据（`team_task_open_reason` 对**未结束**的映射任务查分支/记录）；
  design §6 明确要求 digest 与 `team change status` 用**同一个**谓词，所以这是设计内的账，不是新扫描层。
- M50 的断言跑在**没有 change 目录**的 M50 夹具上：实测 **20** 次（与改动前逐条相同，`pkg/fast-gate.log`
  的 `M50-②` 行）；12f 夹具（2 个有任务的 change + 1 个空目录 + 1 个缺失目录）实测 **4** 次。
- 任务映射的扫描用 `team_change_tasks`（严格 `change:` 读取的唯一实现，一次 awk 扫全部任务书）；
  `[6]` 段不 spawn `team` 子进程、不新增 git 调用面。

## bundle 确定性 + 面板静态检查

```
$ bash skills/teamsmith/scripts/panel/build.sh     # 两次
panel.js written (953596 bytes, sha256 ee770bad1b1c677ad32d2fd01a73612a0a1778158bbe1027373391a9c9f3a4fa)
panel.js written (953596 bytes, sha256 ee770bad1b1c677ad32d2fd01a73612a0a1778158bbe1027373391a9c9f3a4fa)
$ cmp build1.js panel.js        → 两次构建字节一致；git status 不带 panel.js
$ bunx tsc --noEmit             → rc=0
$ node tests/panel-strings.mjs "$PWD"   → panel-strings: ok（键集合 / 无表外 CJK / 111 个契约键）
$ bash tests/panel-snapshots.sh → panel-snapshots 全绿（52 ✓；固定 data 的 stub 没有 tasks → 快照不动）
```

## Flip evidence（红 → 绿；翻转台 `pkg/flip.sh`，scratch = `git worktree add --detach HEAD` 的副本）

翻转台把 smoke 截断在 12g 之前（12f 之后与本任务无关的段落不跑），因此每条结论都只看 12f 段。
每一步都有原始日志（`pkg/flip-<mode>.log` = 完整 smoke 日志，`pkg/flip-<mode>.out` = 摘出的 12f 段）。

### green（不改任何东西）

```
$ bash docs/team/reports/P45-dev2/pkg/flip.sh green
12f 段：✓ 27 ✗ 0
P45FLIP green rc=0 12f_fail=0
```

### a —— 去掉 `[6]` 的 readiness 标记（`pkg/flip-a.out`、`pkg/flip-a.log`）

```
$ bash docs/team/reports/P45-dev2/pkg/flip.sh a
12f 段：✓ 23 ✗ 4
  ✗ 12f [6]：alpha 的 token 与 not-ready 标记
  ✗ 12f [6]：任务指向不存在的目录 → 标记点名
  ✗ 12f [6] 的 token 与 team change status alpha 一致
  ✗ 12f 读成本：计数那一跑真的渲染了 [6] 段（不是空转）
P45FLIP a rc=1 12f_fail=4
```

### b —— token 上限 8 → 99（`pkg/flip-b.out`、`pkg/flip-b.log`）

```
$ bash docs/team/reports/P45-dev2/pkg/flip.sh b
12f 段：✓ 23 ✗ 4
  ✗ 12f [6]：token 上限 8 + 「+N」尾巴
  ✗ 12f [6]：第 9 个任务不打印（token 有界）
  ✗ 12f [6]：change 列表有界（8 行 + 「+N」尾巴）
  ✗ 12f 面板：token 数组有界（8 个 + tasks_more=2）
P45FLIP b rc=1 12f_fail=4
```

### c —— 面板 token 行「宽度不够也渲染」+ 重建 bundle（`pkg/flip-c.out`、`pkg/flip-c.log`）

```
$ bash docs/team/reports/P45-dev2/pkg/flip.sh c
12f 段：✓ 25 ✗ 2
  ✗ 12f 布局：放不下的 token 行整行丢弃（不截断、不折行）（不该出现 [G01 todo]）
  ✗ 12f 布局：丢弃 token 行改变了别的行（重排了）
P45FLIP c rc=1 12f_fail=2
```

### d —— 只去掉**面板读取**的归组，digest 侧保留（任务书 2.4）（`pkg/flip-d.out`、`pkg/flip-d.log`）

```
$ bash docs/team/reports/P45-dev2/pkg/flip.sh d
12f 段：✓ 22 ✗ 5
  ✗ 12f 面板：alpha 的每个 token 带 id/phase/board/verdict（M1 PASS）
  ✗ 12f 面板：token 数组有界（8 个 + tasks_more=2）
  ✗ 12f 机器出口：变化真的落在面板块里（字节不变的对照成立）
  ✗ 12f 布局：放得下的 token 行照常渲染
  ✗ 12f 布局：宽度够（270 列）时 token 行渲染出来
P45FLIP d rc=1 12f_fail=5
```

两条 `12f 机器出口：… --print/--json 逐字节一致` **不在红名单里**（仍然绿）⇒ 面板块与机器出口是分开断言的。

### 还原

四条翻转都跑在 `git worktree add --detach HEAD` 的 scratch 里，工作树一个字节都没动；跑完
`git status --porcelain` 只剩本报告目录（随后提交），`git worktree list` 没有留下 scratch。

## Independent package

- 翻转台（本任务自己写的，独立于实现夹具）：`docs/team/reports/P45-dev2/pkg/flip.sh`
  —— `bash docs/team/reports/P45-dev2/pkg/flip.sh <green|a|b|c|d>`（scratch = `git worktree add --detach HEAD`，
  跑完自清）。它跑的是**门禁自己的 12f 断言**（截断版 smoke），不是我另写的一套。
- 逐模式原始日志：`docs/team/reports/P45-dev2/pkg/flip-<mode>.log`（完整 smoke）与 `flip-<mode>.out`（12f 段）。
- 门禁原始日志：`docs/team/reports/P45-dev2/pkg/fast-gate.log`（FAST）与 `full-gate.log`（全量）。
- 比对产物：`docs/team/reports/P45-dev2/pkg/section-headers-bytes.txt`（段头 `cmp`）、
  `digest-cost.txt`（A/B 耗时与 git 调用数）、`digest-6-sample.txt`（`[6]` 段样张）、
  `preexisting-lint-red.txt`（既有红的双侧复现）。

## Decisions and deviations（决策与偏差；都在设计文本之内）


- **归档的 change 不算「目录不存在」**：`openspec/changes/archive/*-<id>` 存在时 `[6]` 不再列该行。
  归档是正常终点（`openspec list` / `team change status` 同样只认活动目录）；否则本仓库 21 个已归档
  change 会在 `[6]` 里以「change 目录不存在」占满 section。真缺失（如 `spec-delta-gate`）照旧点名。
- **标记行排在前、正常行排在后**：spec 要求「没有任务指向它」「任务指向不存在的目录」必须可见而不是
  静默；8 行上限一旦套在全部行上，繁忙仓库（本仓库 11 个活动 change）会把异常挤进 `+N`。标记行因此
  先打；上限只吃正常行。
- **token 上限与 section 行上限共用一个常量 `TEAM_CHANGE_TASK_CAP=8`**：一处定义、digest 与面板同源；
  翻转 b 证明它同时管住两处。
- **面板没有「缺失目录」标记**：面板的 change 行来自目录列表 / `openspec list`，没有可挂靠的行；
  design §7 的那两个标记属于 digest 段。异常由 `[6]` 点名（12f 断言 2）。
- **布局丢弃规则用「整行放不下就不画」**（`display width > block width`），不是按档位阈值：档位只决定
  右栏宽度，规则本身与档位解耦；翻转 c 用 160 列（右栏 70 < 95 列的 token 行）证明丢弃、270 列证明渲染。
- **多个 change 共用 `TEAM_CHANGE_TASK_CAP` 的环境变量默认值**（`${TEAM_CHANGE_TASK_CAP:-8}`）：给门禁/夹具
  留一个不碰源码的旋钮，不设就是 8。

## BLOCKED / 既有红（不属于 P45 的 grant）

`40 lint`（P53 的 `tests/tmp-hygiene.sh --lint`）在**基线 `69979035` 的纯检出**上就红，两条 finding 都在
`skills/teamsmith/tests/container-tmux.sh:159,215`（`mktemp -d "${TMPDIR:-/tmp}/fpcheck.XXXXXX"` 不在
`teamsmith-<kind>.XXXXXX` 家族里）。复现与两侧输出：`pkg/preexisting-lint-red.txt`。

- 时间线：`container-tmux.sh` 的那两行是 P47 的 `6ca5595c`（11:46Z）加的；P53 的 lint 是 `34e6c00c`
  （14:31Z）落的 —— **P53 是在 P47 之后落地的**，两边各自的复验都没看到合并后的形状。
- P45 的 grant 只有 `cmd-status.sh` / `cmd-watch.sh` / `panel/src/**` / `panel.js` / `smoke.sh`，**不能**改
  `container-tmux.sh`，所以没有自行修。**谁修**：`container-tmux.sh` 现在属于 `ledger-and-gate-noise`
  （P47/dev-bob）的产物；最小修法是把两个 `fpcheck*` 目录改成 `teamsmith-<kind>.XXXXXX`（或让 P53 的 lint
  把这类「私有 tmux socket 目录」显式排除）。这条红不影响 12f 的 27 条断言。
- 本报告的每条门禁记录都以「✓2394 ✗1（唯一红 = 上面这条既有红）」的形式给出，避免读者以为 P45 全绿。

## Suggested next steps

- PM 复验时：`team review P45 --dir <独立 checkout> --strong`；本任务的实现提交是 `18ed2754`、`882b646c`、
  `670a79d3`（local 模式，分支没 push）。
- P45 之后 `change-centric-discipline` 只剩 B3–B8；`[6]` 段与面板 token 是 B2 的读数面，B6 的归档前提
  与 B2 共用 `team_change_readiness`（同一谓词），可以按 tasks.md 的顺序继续。
- 既有红（section 40 lint）建议单独开一条给 P47/container-tmux 的返工或 P53 的 lint 口径修；
  否则每个 agent 的 FAST 门禁都会带 1 条与己无关的红。
