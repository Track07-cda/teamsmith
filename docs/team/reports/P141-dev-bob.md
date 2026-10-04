# P141 · `capacity-floor-disk` propose：容量地板补磁盘/inode 腿（防 ENOSPC 打死席位）

agent: dev-bob   status: done（R1 返工后）   time: 2026-10-01
branch: `task/P141-propose`   PR/MR: -（local 模式：分支留在工作树，未 push）
change: `capacity-floor-disk`（phase `propose`；`deltas: dispatch,watchdog,panel`；起点 `main@12a0ff98`，共 merge 三次 main：开工、P135 收尾、R1 返工时合入 PM 的评审记录 `a7c4d8c2`；三次都与本 change 无文件交集，merge 后 validate 均 16/0）

## Deliverables

| Path | What |
|---|---|
| `openspec/changes/capacity-floor-disk/proposal.md` | Why / What Changes / Capabilities / Impact / What flips / Acceptance / Boundaries / Evidence（493 词） |
| `openspec/changes/capacity-floor-disk/design.md` | D1–D8 裁断：单一阈值对、拒绝+逃生、`TEAM_DISK_STATS_FILE` 接缝、判定路径、可见面、修法归属、测试与 flip；**D8 = R1 的 schema 注册**（三行、`0` 的 danger、标签、env-only 段的收窄） |
| `openspec/changes/capacity-floor-disk/specs/dispatch/spec.md` | MODIFIED `The capacity floor protects the host`：磁盘/inode 腿 + schema 注册 + 5 条新 scenario（原 2 条逐字保留） |
| `openspec/changes/capacity-floor-disk/specs/watchdog/spec.md` | MODIFIED `Restart quota and capacity logging`（tick 行带读数）+ MODIFIED `` `team doctor` reports the temp root's headroom ``（每个文件系统一行，+3 scenario） |
| `openspec/changes/capacity-floor-disk/specs/panel/spec.md` | MODIFIED `The status band …`：`panel.capacity.disk` 与面板带读数（+2 scenario）；ADDED `The disk floor's keys are contract rows the console carries`（R1：三行的 class/默认值/标签，+1 scenario） |
| `openspec/changes/capacity-floor-disk/tasks.md` | 依赖排序的 apply 计划：覆盖映射表、复验表、路径授权、8 组 21 项（第 8 组 = schema 行与标签）、5.4/5.5 两条 R1 场景、flip |
| `docs/team/reports/P141-dev-bob/recon.sh` + `recon.log` | 现状取证 + 提议设计的原型在夹具上的三场景原始输出 |
| `docs/team/reports/P141-dev-bob/logs/validate{,-r1}.txt`、`status{,-r1}.txt`、`deltas{,-r1}.json` | 门禁与 openspec 解析的原始输出（首轮 + R1 后重跑） |

提交（本地分支 `task/P141-propose`，`git log --oneline main..HEAD`）：

```
a82df003  docs(team): P141 recon — the capacity floor has no df, and the proposed disk/inode leg's three scenarios run on a fixture
87cf4cf0  docs(openspec): propose capacity-floor-disk — the dispatch floor gains a disk/inode leg so a full tmpfs cannot kill a seat mid-turn
1267d1bf  docs(openspec): P141 design — seven rulings for the disk leg: one floor, refusal with an env override, one df/fixture seam
ba41e905  docs(openspec): P141 deltas — dispatch capacity floor (MODIFIED), watchdog log + doctor rows, panel band carry the disk/inode readings
d038849f  docs(openspec): P141 tasks — dependency-ordered apply plan with a coverage map, the five-fixture smoke matrix and its flip
a548922f  docs(team): P141 report — the propose deliverable, the delta→requirement map, the 17 scenarios, the rulings and the raw recon
ad93ed58  docs(openspec): P141 change metadata — the scaffolded .openspec.yaml
e7812b20  docs(openspec): P141 design D8 — the floor's knobs are schema rows so the 0 escape is audited instead of a hand-edit
5d3fa88b  docs(openspec): P141 dispatch delta — the thresholds and the seam are contract rows, and the escape is a scenario
63ec47f9  docs(openspec): P141 panel delta — an ADDED requirement pins the three keys' rows and labels
84cc8396  docs(openspec): P141 tasks — section 8 for the schema rows and labels, plus the escape and doc consequences
a24ca03f  docs(openspec): P141 proposal — schema registration reaches What Changes, Impact and What flips
```

（清单之后另有两次纯字面的报告修订，不重跑验收；R1 后的验收输出在 `logs/*-r1.*`。）

## Delta → requirement map

| delta 文件 | requirement | 变更 | scenarios |
|---|---|---|---|
| `specs/dispatch/spec.md` | `The capacity floor protects the host` | MODIFIED（原 body 保留，追加磁盘/inode 腿、可见读数与 schema 注册） | 2 原有（逐字）+ 5 新 |
| `specs/watchdog/spec.md` | `Restart quota and capacity logging` | MODIFIED（tick 行追加磁盘/inode 读数） | 2 原有（1 条 body 扩写） |
| `specs/watchdog/spec.md` | `` `team doctor` reports the temp root's headroom `` | MODIFIED（temp root → 每个被判定文件系统一行，同一底线） | 2 原有（按名字保留，body 适配）+ 3 新 |
| `specs/panel/spec.md` | `The status band answers "who is in charge" and "is there work"` | MODIFIED（面板带与 `panel.capacity.disk` 带读数） | 2 原有（1 条 body 扩写）+ 2 新 |
| `specs/panel/spec.md` | `The disk floor's keys are contract rows the console carries` | ADDED（R1：两个阈值 + 夹具接缝的 schema 行、class/默认值/标签） | 1 新 |

`openspec show capacity-floor-disk --json --deltas-only` 读出 `deltaCount: 5`（三个文件、五个 requirement），
与任务书 `deltas: dispatch,watchdog,panel` 仍一一对应（panel 文件里两条：R1 的 ADDED + 原 MODIFIED）；
`openspec status` 4/4 artifacts complete。

## Scenario inventory（19 条；10 新 / 4 body 适配）

**dispatch（7）**：① `Low free disk swap…`（原有）② `zram pages…`（原有）③ `A full temp root refuses…`（新：夹具
120 MB / 40000 inode → 非 0，点名路径/读数/阈值 + `修法：…tmp-hygiene.sh --sweep`；`TEAM_TMP_MIN_FREE_*=0` 放行）
④ `Plenty of disk allows…`（新：5 GB / 2.9M → 放行且容量行打印两路径读数）⑤ `An unreadable filesystem is silent…`
（新：无记录 → 放行、无拒绝无警告、不印数字）⑥ `A filesystem without an inode table…`（新：`itotal=0` 充足放行；
字节低时只按字节拒）⑦ **`The floor's escape hatch is reachable through the audited writer`（R1 新：拒绝 →
`team config set … 0 --allow-danger --yes` 写一行 `result=ok` → 同一派单放行）**。

**watchdog（7）**：tick 两条（`Capacity is recorded per tick` 扩写为两文件系统的字节+inode）；doctor 五条
（healthy / low temp root / **low worktrees root（新）** / unreadable / **no inode verdict（新）**）。

**panel（5）**：`The band mirrors…`（扩写：`panel.capacity.disk` 条目存在）；**`The disk readings reach…`（新）**；
**`A filesystem that cannot be read is not assigned a number`（新：`—`/无数字）**；`Standby…`（原有）；
**`The three keys reach the view and the machine read`（R1 新：三条记录 + 设置视图三行的标签）**。

## Rulings（任务书点名要裁的，全部写进 design，供复审）

1. **拒绝 vs 警告 → 拒绝**（D2）：实测代价是一个席位中途阵亡（报告/证据俱失）；1 GiB/100k 是余量不是悬崖；
   逃生是显式的 `TEAM_TMP_MIN_FREE_MB=0` / `TEAM_TMP_MIN_FREE_INODES=0`（与 `TEAM_MIN_AVAIL_MB=0` 同形），
   **不**走 `--force`（那是身份/账本守卫的带审计门）。R1 之后这两条键进了 schema，逃生走审计写入器
   （`team config set … 0 --allow-danger`，见 Ruling 8），不再是「只能手改 config.sh」。
2. **阈值键——与任务书示例名不同（需 PM 复审，见「Decisions」）**：复用 P53 已在 doctor 行落地的
   `TEAM_TMP_MIN_FREE_MB` / `TEAM_TMP_MIN_FREE_INODES`，把语义从「临时根告警」扩为「worker 将写入的文件系统的
   拒单底线」。任务书示例名 `TEAM_MIN_AVAIL_DISK_MB` / `TEAM_MIN_AVAIL_INODES` 标记为「如」；若另立新键，
   同一批文件系统上会有两个阈值（doctor 告警一对、派单拒绝对），必然漂移。改名的机械成本只有一行实现 + 两行
   文档，PM 若要示例名可一行切换。
3. **默认值依据**（D1 表）：「一轮门禁的根 95 MB / 11,797 文件（另一轮 9 MB / 1,246），被 KILL 掉的
   `config-cli` 根 99 MB / 10,954 文件」→ 1024 MB ≈ 10 轮字节余量、100000 inode ≈ 9 个根的余量；事故现场是
   0 字节 / 3,811,434 中仅剩 4,645 inode。
4. **判定对象**（D4）：临时根 `${TMPDIR:-/tmp}` + **派单目标席位的工作树**；无目标的共享面（巡逻行/`team up`/
   `team ps`/面板/doctor）用 worktrees 根。不扩大巡检（非目标）。
5. **接缝**（D3）：`TEAM_DISK_STATS_FILE`（`path<TAB>total<TAB>avail<TAB>itotal<TAB>ifree`，最长前缀匹配），
   生产路径是 `df -P -k` + `df -P -i` 第 2 行 —— 与 doctor 行同两调用（P53 实测 3.7 ms/对）。
6. **修法归属**（D6，D58）：临时根 → `tmp-hygiene.sh --status` 再 `--sweep`（只用它自己可证明的归属）；
   工作树文件系统 → 点名路径让人腾空间，不冒充 tmp-hygiene 的活。
7. **可见**（D5）：派单通过时打印一条 `容量：…`（RAM/swap + 两文件系统读数），拒绝时读数在拒绝里；
   `capacity.log`、doctor 行、面板带/`panel.capacity.disk` 同一组数字；读不到渲染 `无法读取`/`n/a`/`—`。
8. **阈值与接缝进 schema**（D8，R1）：三行注册（两个 `apply` 阈值 + 一个 `refuse` 夹具旋钮）；`0` 保留与
   `TEAM_MIN_AVAIL_MB=0` 同形的 danger 确认与一行审计；三个键都要 zh/en 标签（≤22 格，双向门禁）；
   `references/config.md` 的 env-only 段收窄到 `TEAM_TMP_KEEP`/`TEAM_TMP_SWEEP_AGE`。只注册本 change 引入的
   旋钮，完整性检查本身不扩（PM 另开任务）。

## R1 返工（PM 评审 NEEDS-CHANGES → 本轮）

评审记录：`docs/team/reviews/capacity-floor-disk-proposal.md`（判定 **NEEDS-CHANGES**，其余全部通过，只差 R1）。
R1 的原文要求：两个阈值键注册进 config schema（默认 1024/100000、与 `TEAM_MIN_AVAIL_MB` 同类、带 zh/en
标签）；本 change 引入的任何新旋钮（含 `TEAM_DISK_STATS_FILE`）一并注册（测试旋钮用 `refuse` 类）；至少补两条
scenario：① 审计写入器 `team config set TEAM_TMP_MIN_FREE_MB 0` 成功并让派单放行；② 面板/`config list` 能看到
这两个键（带标签）。

本轮改了五处：

| 文件 | 改动 |
|---|---|
| `design.md` | 新增 **D8**：注册表（键/class/kind/default/danger/suggest/group）、`0` 的 danger 语义（`--allow-danger`，一次 `result=ok` 审计）、标签与 22 格门禁、`references/config.md` 的 env-only 段只留 `TEAM_TMP_KEEP`/`TEAM_TMP_SWEEP_AGE`；明确**不**扩完整性检查 |
| `specs/dispatch/spec.md` | MODIFIED 追加 schema 注册段（`apply`/`mb`/`int`/`delivery`/`refuse` 接缝）+ 新 scenario：拒绝 → `team config set TEAM_TMP_MIN_FREE_MB 0 --allow-danger --yes` 写一行 `result=ok` → 同一派单放行（基线 2 条逐字保留，2→7） |
| `specs/panel/spec.md` | 新 ADDED requirement `The disk floor's keys are contract rows the console carries` + scenario：`team config list --json` 三条记录（`apply`/默认值/`delivery`、接缝 `refuse`）与设置视图三行的标签（主文本不出现 `TEAM_…`） |
| `tasks.md` | 新增第 8 组（8.1 schema 三行、8.2 zh/en 标签 + 重建 bundle、8.3 数键数的夹具）、5.4/5.5 两条场景、7.1 改为把两键写进 config.md 的反引号键表并收窄 env-only 段；授权列表加 `cmd-config.sh` |
| `proposal.md` | What Changes 增 ADDED panel 条、dispatch 条点明审计逃生；Impact 加 `cmd-config.sh` 与 `src/strings`；What flips 增「逃生不再靠手改」 |

验证（本轮原始输出）：

```
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
…
Totals: 16 passed, 0 failed (16 items)          # logs/validate-r1.txt

$ openspec status --change capacity-floor-disk
Progress: 4/4 artifacts complete                # logs/status-r1.txt

deltaCount 5
dispatch MODIFIED 7 · panel ADDED 1 · panel MODIFIED 4 · watchdog MODIFIED 2 · watchdog MODIFIED 5
                                                # logs/deltas-r1.json 的机械读数
```

基线的四条 MODIFIED requirement 场景逐条保留（dispatch 2→7、panel status band 2→4、watchdog 2→2、doctor 3→5，
丢失 0；四条 MODIFIED 合计新增 9），加上 panel 的 1 条 ADDED requirement（+1）：本轮共 19 条、10 新。
R1 的两处新增是 dispatch 的审计逃生 scenario 与 panel 的三键 scenario；没有改任何实现代码、没有改
`openspec/specs/**` 基线、没有动完整性检查。

## Verification evidence

```
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
…
✓ change/capacity-floor-disk
…
Totals: 16 passed, 0 failed (16 items)          # logs/validate.txt（首轮）/ logs/validate-r1.txt（R1 后重跑，同 16/0）

$ openspec status --change capacity-floor-disk
Progress: 4/4 artifacts complete
[x] proposal [x] specs [x] design [x] tasks     # logs/status.txt；R1 后 logs/status-r1.txt（同 4/4）
```

现状取证 + 原型三场景（`bash docs/team/reports/P141-dev-bob/recon.sh`，原始输出 `recon.log`）：

```
== 1 current: the capacity floor reads meminfo/swaps only ==
disk/inode reads inside the floor: NONE          # grep 后的可证伪读数：floor 里没有 df/inode
== 2 current: the capacity line has no disk reading ==
RAM 可用 8000MB ｜ 磁盘 swap 空闲 64511MB ｜ 估算可再加 11 个 agent
== 3 real readings the floor would judge (today it does not look at them) ==
tmp root        avail=7727248 kB of 15245736 kB
tmp root inodes free=3017840 of 3811434
worktree root   avail=303232680 kB of 975437824 kB
worktree inodes free=0 of 0 (0 total = fs does not report inodes)   # btrfs：inode 腿不适用
unreadable path df: /nonexistent-p141: No such file or directory / rc=1
== 4.1 scenario ①  artificially low quota -> refuse (raw) ==
REFUSE  /tmp/teamsmith-p141-recon.RB1TFt: avail 120.0MB < floor 1024MB
REFUSE  /tmp/teamsmith-p141-recon.RB1TFt: free inodes 40000 < floor 100000
guard rc=1
== 4.2 scenario ②  plenty -> allow, measured readings printed ==
ALLOW   /tmp/teamsmith-p141-recon.RB1TFt: avail 5.0GB · inode 2978499
guard rc=0
== 4.3 scenario ③  unreadable -> silence, allow ==
guard rc=0 (no output above = silent)
== 4.4 inode table not reported (filesystem says 0) -> the bytes leg still judges ==
ALLOW   /tmp/teamsmith-p141-recon.RB1TFt: avail 5.0GB · inode n/a
REFUSE  /tmp/teamsmith-p141-recon.RB1TFt: avail 120.0MB < floor 1024MB   # itotal=0 + 字节低：只按字节拒
```

- Verdict: **pass**（propose 的验收 = `openspec validate --all --strict`，16/0；三场景 + 两个反向控制已有原始输出）
- Notes（**没跑的**，点名）：
  - **没跑 smoke**：本任务只写 `openspec/changes/capacity-floor-disk/**` 与
    `docs/team/reports/P141-dev-bob/**`，未触任何代码路径（`recon.sh` 是报告目录里的独立原型，不 source 生产函数），
    按 P136 的先例 propose 验收只跑 validate；FAST/全量是 apply 的验收（tasks 6.2/6.3）。
  - 原型**不是**生产实现：它证明接缝与三种判定的形状可表达，实现要在 apply 里落到 `common.sh`（tasks 1.x）。
  - `df` 真实读数是**实时**的（tmp 7.4 GB、worktree 289 GB），与 D67 事故时点不同，报告只把它当「健康机器不会
    误触」的证据；满盘场景全部走夹具。

## Before / after（原型级；propose 任务，不涉及修改代码）

```
改动前（真实现）：floor 无 df/Inode 读取（recon 1 NONE），容量行只有 RAM/swap/agent（recon 2）
改动后（原型夹具）：满 → 两腿拒绝并给读数（recon 4.1）；充足 → 放行并带读数（4.2）；
                    读不到 → 静默放行（4.3）；itotal=0 → inode 不判、字节照判（4.4）
```

真正「break the implementation → 红 → restore → 绿」的 flip 写在 tasks 5.2（apply 执行，报告必须附两侧原始输出）。

## Decisions and deviations

- **偏离任务书示例键名**（D1，最重要的一条）：改为复用 `TEAM_TMP_MIN_FREE_MB` / `TEAM_TMP_MIN_FREE_INODES`。
  理由与备选见 Rulings 第 2 条。若 PM 坚持任务书示例名，改法是加一对新键并让旧键成为回退，但会在同一批文件系统上
  留两个阈值——建议维持现裁断。
- **`--force` 不给磁盘腿**：与内存地板一致（环境级冒险用显式写法，拒绝里打印它）；R1 后这条逃生是 schema
  键的 `0`：`TEAM_TMP_MIN_FREE_MB=0 team dispatch …` 与审计写入器 `team config set TEAM_TMP_MIN_FREE_MB 0 --allow-danger --yes` 两条路等价（都不走 `--force`）。
- **R1 逆转到 P53 的 env-only 裁断**（D8）：两个阈值键从「刻意不进配置面」改为 `apply` schema 行。这不是顺手
  扩大配置面：它们现在是**拒单底线**，审计写入器与设置视图必须够得着 `0`；只这三个键（两个阈值 + 夹具接缝）
  进 schema，`TEAM_TMP_KEEP`/`TEAM_TMP_SWEEP_AGE` 仍留在环境变量面，完整性检查本身不动。
- **P140 并存**：`dispatch-friction` apply 进行中时，磁盘腿在它的一遍式拒绝里就是一条带 `修法：` 的 blocker；
  本 change 的 requirement 只承诺字段（路径/读数/阈值/修法），不绑定排版，两者谁先合都不冲突。
- 任务书 `grant` 只给 `openspec/changes/capacity-floor-disk/**` 与报告目录：本任务严格遵守，未改任务书、未改
  `openspec/specs/**`、未改任何 skills 代码。

## Suggested next steps

- PM 复审：`docs/team/reviews/capacity-floor-disk-proposal.md`（首轮 NEEDS-CHANGES，只差 R1；本轮已补）。
  复审时请特别看 **R1 的五处改动**（`logs/deltas-r1.json` 的 deltaCount 5 与场景计数）、**D1 的键名裁断**
  （Rulings 2）与 **D8 的 schema 注册**（Rulings 8）。按流程，apply 任务书必须等这份 review ACCEPTED。
- ACCEPTED 后派 apply：任务书需要授权 `skills/teamsmith/scripts/lib/**` 的具名 hunk（含 `cmd-config.sh` 的三行
  schema）、`scripts/panel/**`（含 `src/strings/{zh,en}.ts` 与重建 bundle）、`tests/**`（agent 自有）、
  `references/{config,troubleshooting}.md`（tasks「Path grants」一节已列）。
- apply 的验收按 tasks 6.x：`openspec validate --all --strict` + FAST + 全量 smoke，flip 见 5.2。
