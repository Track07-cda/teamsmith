# P192 · 重写 `pulse-nudge-key` 的 delta（归档基线已前进）

```
task:    P192
agent:   dev
change:  pulse-nudge-key
phase:   apply
tip:     a8786315（delta 改写）；本报告与证据目录的提交紧随其后 = 分支 HEAD
base:    836c8f6a（main tip：P193 重写已合入、meeting-liveness 已归档；写 delta 前先 `git merge main`）
branch:  task/P192-apply（local 模式：不 push，分支留在本地 worktree，PM 复验后本地合并）
status:  delivered
```

## 0. 判定摘要（逐条对照任务书「要做的」）

| 任务书条目 | 判定 | 证据（自己跑的） |
|---|---|---|
| **1** 按**当前**基线重写 delta，逐条对齐 | ✅ | 红侧 `validate` 点名 panel 丢 3 条基线场景、`archive` 当场中止；重写后 `validate pulse-nudge-key` 通过、scratch 预演归档 `+0 ~2 -0` 成功（§2、§3） |
| **1a** MODIFIED 文本 = 基线现状 + 本 change 改动 | ✅ | panel prose 改为**当前基线整段原文** + 本 change 原有的「当前计数可见」段落；5 条基线场景逐字复制，本 change 自家场景原样保留（`07-no-loss-check.log`：findings=0） |
| **1b** ADDED 不重名、scenario 一个不丢 | ✅ | 本 change 只有 MODIFIED 两处（`openspec show --deltas-only`）；`09-align-after.log` 无 MISSING、无 COLLISION；计数对照见 §1.5 |
| **2** 保留已定契约（类别集合去重 / 空拍重置 / 计数仍可见 / `standby` 不叫） | ✅ | 四条的原文句子都在归档后的规格里在位（§1.4 逐条引用）；old-delta 场景与 change 段落逐字节未动（§3 翻转证据 M2） |
| **3** 验收三命令 + 计数对照 | ✅ | §2：`validate pulse-nudge-key` ✓ / `validate --all --strict` 17/1（唯一红 = 既有的 delivery-truth，非本任务引入，重写前为 16/2）/ scratch 预演 `archive -y` ✓；临时克隆与两个 mutation 副本已全删 |
| **4** 报告点名哪些自己跑、哪些引用 | ✅ | §4 |

## 1. 改了什么

只改一个文件（brief grant 内）：`openspec/changes/pulse-nudge-key/specs/panel/spec.md`，提交 `a8786315`。

### 1.1 先 merge main（前置，非可选项）

分支 tip 原本停在 `fd85cfab`（P193 的 delta 改写提交），此后 main 快进过 **P193 合并**与
**`meeting-liveness` 归档**（`61aa7859`）。这两次让基线又前进了一格：

- `openspec/specs/panel/spec.md` 的 status band 需求多了 `meetings` 计数子句与
  `The band carries unread meeting turns` 场景；
- `openspec/specs/watchdog/spec.md` 的 pending-work 需求多了 `未读会议` 子句（**rate-limit 需求本身未动**）。

任务书要求按**当前**基线重写，验收 `validate --all --strict` 也以 main 的口径为准，所以先
`git merge main`（fast-forward 到 `836c8f6a`），再动手。

### 1.2 `specs/panel/spec.md` —— 真正挡住归档的那条（**重写**）

当前基线的 `The status band answers "who is in charge" and "is there work"` 在
`capacity-floor-disk` 之后多了磁盘契约与两条磁盘场景，在 `meeting-liveness` 之后又多了 unread meeting
子句与一条会议场景；本 change 的 delta 是按旧基线写的，**MODIFIED 整块替换会静默丢掉这 3 条**。
重写后（`rewrite-panel-delta.py`，机械合成，可重跑）：

- **prose** = 当前基线整段原文 + 本 change 原有的「当前 pending 快照 / JSON 字段含义 / observer 只读」
  段落（该段落逐字节未动）；磁盘子句、`meetings` 子句、`panel.capacity.disk` 子句逐字在位；
- **场景** = 基线 5 条**逐字**（含两条磁盘场景、一条会议场景）+ 本 change 的
  `A suppressed reminder does not freeze the displayed counts`，共 6 条（重写前 3 条）。

### 1.3 `specs/watchdog/spec.md` —— 核对后**未改**

它的 MODIFIED 块本来就是「基线原文 + 本 change 改动」：基线那两句
（`The pulse SHALL NOT repeat a reminder for an unchanged pending batch more often than
TEAM_PULSE_NUDGE_GAP seconds (default 900).`）被完整保留，两条基线场景
（`The second tick stays quiet`、`Standby suppresses the nudge`）逐字在位，后面是本 change 的 7 条。核对证据：
`09-align-after.log` 无 MISSING、`12-green-trial-no-loss.log` 里 watchdog 的 lost=0、`13-trial-specs-diff.txt`
显示其唯一 `-` 行是 `-seconds (default 900).` 这处「句尾接写」（净效果零删除）。

### 1.4 契约逐条保留（任务书第 2 条）

| 契约 | 归档后规格里的原文（节选） |
|---|---|
| 类别集合去重 | `a batch SHALL be identified by the set of positive pending categories: inbox, reports, todo, wip, review, blocked, stopped and meetings`；`Counts and descriptive text MUST NOT affect that identity`；`While that set is nonempty and unchanged, a tick inside the gap MUST append no reminder … and MUST submit no new pulse reminder` |
| 空拍重置 | `A tick that observes no pending categories SHALL rearm the next nonempty batch, including when emptiness is observed under standby`；场景 `An empty tick rearms the returning batch`、`Emptiness under standby still rearms without waking` |
| 计数仍可见 | `The reminder text and state/nudges.log SHALL keep the current counts whenever a reminder is generated`；panel `SHALL reflect the current pending snapshot rather than the last reminded snapshot`；场景 `A suppressed reminder does not freeze the displayed counts` |
| `standby` 不叫 | `Standby MUST still suppress reminders and PM startup; rearming MUST NOT itself send a message`；`suppression MUST NOT postpone the next allowed reminder` |

### 1.5 scenario 计数对照（重写前 = `HEAD` 836c8f6a 的 delta，重写后 = 工作树）

| delta 文件 | 重写前 | 重写后 | 说明 |
|---|---|---|---|
| `pulse-nudge-key/panel` | 1 req / **3** scen | 1 req / **6** scen | +3 全是**补回的基线场景**（disk ×2、unread meeting ×1）；本 change 的 3 条一条未丢，其中与基线同名的 2 条按基线逐字对齐 |
| `pulse-nudge-key/watchdog` | 1 req / **9** scen | 1 req / **9** scen | 未改：2 条基线 + 7 条本 change |
| **合计** | **12** | **15** | 丢失 0；新增 3 条均为基线原文 |

完整前后清单见 `03-counts-before.log` / `08-counts-after.log`（`scenario-counts.py` 可重跑）。

## 2. 验收命令（原始输出；红/绿两侧都留档）

### 2.1 绿侧（交付树）

```
$ openspec validate pulse-nudge-key --type change            # 05-green-validate-change.log
Change 'pulse-nudge-key' is valid
rc=0

$ openspec validate --all --strict                            # 06-green-validate-all.log
✗ change/delivery-truth
✓ change/pulse-nudge-key
Totals: 17 passed, 1 failed (18 items)                       # 重写前是 16/2（01）；唯一红与本次改动无关
Details: openspec validate delivery-truth --type change
rc=1

$ cd /tmp/p192-trial && openspec archive -y pulse-nudge-key   # 11-green-trial-archive.log
Applying changes to openspec/specs/panel/spec.md:
  ~ 1 modified
Applying changes to openspec/specs/watchdog/spec.md:
  ~ 1 modified
Totals: + 0, ~ 2, - 0, → 0
Specs updated successfully.
Change 'pulse-nudge-key' archived as '2026-10-03-pulse-nudge-key'.
rc=0

$ python3 archive-no-loss.py specs-before openspec/specs <archived change>   # 12
panel:     requirements 40->40  scenarios 201->202  lost_req=0 lost_scenarios=0
watchdog:  requirements 18->18  scenarios  59-> 66  lost_req=0 lost_scenarios=0
（其余 11 个能力 0 变化）
findings=0
rc=0

$ bash skills/teamsmith/tests/spec-refs.sh --check --root "$PWD"   # 14
spec-refs: judged 101 reference(s) (49 distinct) in 9941 effective line(s); retired 4; undeclared 0
rc=0
```

### 2.2 红侧（重写前的 delta，scratch 树 `/tmp/p192-red`）

```
$ openspec validate pulse-nudge-key --type change            # 02-red-validate-change.log
✗ [ERROR] panel/spec.md: MODIFIED "The status band answers …" omits scenario(s) the current spec still has:
"The disk readings reach the band and the JSON", "A filesystem that cannot be read is not assigned a number",
"The band carries unread meeting turns". …
rc=1

$ openspec archive -y pulse-nudge-key                          # 10-red-trial-archive.log
panel MODIFIED failed … current spec contains scenario(s) not present in the modified block: …
Aborted. No files were changed.
rc=1
```

### 2.3 scratch 预演做了什么（临时目录已全删）

`11` 的预演 = 把交付树的 `openspec/` 拷到 `/tmp/p192-trial`，先存 `specs-before`，再 `archive -y`；
`13-trial-specs-diff.txt` 是归档前后 `openspec/specs/{panel,watchdog}/spec.md` 的完整 `diff -u`：
83 行 `+`（含 2 行文件头）、3 行 `-`（含 2 行文件头），净新增 81 行、净删除 1 行 —— 那 1 行是
`-seconds (default 900).`（同一句的换行重排，在 `+` 侧连同本 change 的追加完整保留）。`12` 再按 requirement/scenario **名字集合**对照一次：
lost_req=0、lost_scenarios=0，且 delta 的每条场景都确认落进归档后的规格。

### 2.4 边界声明（本任务没有碰的东西）

- `11` 的归档预演会让 `pulse-nudge-key` 进入 archive —— 我只在 `/tmp` 的**一次性克隆**里做，
  仓库内没有任何归档动作（`git status` 显示只有 delta 与报告目录两处改动）。
- 本任务**未碰**实现代码（`skills/**` 一字未动）、未碰 `openspec/specs/**`、未碰 change 的
  proposal/design/tasks，也未碰其他人的分支/worktree。

## 3. Flip evidence（红 → 绿）

| 侧 | 命令 | 结果 |
|---|---|---|
| 红 | `openspec validate pulse-nudge-key --type change`（旧 delta） | ✗ 点名缺 3 条基线场景（`02`） |
| 红 | `openspec archive -y pulse-nudge-key`（旧 delta，scratch） | ✗ `Aborted. No files were changed.` rc=1（`10`） |
| 红 | `openspec validate --all --strict`（旧 delta） | 16/2：pulse-nudge-key + 既有 delivery-truth（`01`） |
| 绿 | `openspec validate pulse-nudge-key --type change`（`a8786315`） | ✓ valid rc=0（`05`） |
| 绿 | `openspec validate --all --strict` | 17/1：只剩既有的 delivery-truth（`06`） |
| 绿 | `openspec archive -y pulse-nudge-key`（scratch） | ✓ `+0 ~2 -0` rc=0（`11`） |

**破坏实现 → 守卫必须失败 → 还原**（两次 mutation，均在 `/tmp` 副本里做，做完即删）：

| mutation | `openspec validate` | 我的 no-loss 守卫 |
|---|---|---|
| M1：从 delta 里删掉基线场景 `The band carries unread meeting turns` | ✗ rc=1，**点名该场景**（`15`） | — |
| M2：从 delta 里删掉本 change 自家场景 `A suppressed reminder does not freeze the displayed counts` | ✓ 仍 valid rc=0（`16`，说明 validate 只护基线、不护本 change 契约） | ✗ rc=1，`LOST old-delta scenario: A suppressed reminder does not freeze the displayed counts`（`17`） |

M2 是这次特意加的一侧：**validate 绿不等于本 change 的契约没丢**，`no-loss-check.py` 才是护住
「本 change 原有场景一条不丢」的那道判据；交付树在这个判据下 findings=0（`07`）。

## 4. 我跑了什么 / 我没跑什么 / 引用了什么

**自己跑的**：`git merge main`；`openspec validate` ×2（红绿两侧）；scratch 预演 `archive -y`
（红侧 + 绿侧）；`archive-no-loss.py`、`no-loss-check.py`、`alignment-check.py`、`scenario-counts.py`
四个机械比对；两次 mutation（M1/M2）；`spec-refs.sh --check`。证据与脚本都在
`docs/team/reports/P192-dev/`，可在仓库根直接重跑。

**没跑**：`smoke.sh`（FAST 与全量都没跑）。理由：本任务只改
`openspec/changes/pulse-nudge-key/specs/panel/spec.md` 的文本（分支 vs main 的 diff 只有这一个
非-docs 文件），任务书的验收命令就是 validate ×2 + scratch 预演 + 计数对照；smoke 第 59 段跑的是
**代码夹具** `tests/pulse-nudge-key.sh --all`（`smoke.sh:18904`），不读这个 delta，且当前机器上
P191 的门禁容器正在跑（`teamsmith-p191-gate-…`），按「一次一道门」的纪律不并发起第二道。文本级
门禁我用 `spec-refs.sh --check` 补上了（§2.1 绿）。若 PM 要全量 smoke，我可以补跑。

**引用的（不是我跑的）**：`docs/team/reports/P193-dev.md`（同类 delta 重写的前例与 F3 的顺序耦合判断）、
`docs/team/reviews/P193-done.md`（PM 对「只改 delta 与报告、无 smoke」的验收口径）、
`git show HEAD:openspec/changes/pulse-nudge-key/specs/panel/spec.md`（重写前 delta）、
归档后的 `openspec/changes/archive/2026-10-02-capacity-floor-disk/` 与
`…/2026-10-03-meeting-liveness/`（当前基线这两处增量文本的来源）。P174 的实现（`68e0f68b`）本任务未动。

## 5. 需要 PM 知道 / 顺带发现

**F1 · 两个既有红与本任务无关（我的 alignment 脚本也会列出来）**
`09-align-after.log` 剩两条 finding：① `delivery-truth/delivery-guard` 缺基线场景
`A meeting knock never lands on a draft` —— 这正是 P193 F3 预告的「归档 meeting-liveness 会让
delivery-truth 变 stale」，与 pulse-nudge-key 无关；② `signal-gate-pgrep/boundary` 的 MODIFIED 名不在
基线里 —— 它自己的 proposal 已写明「有效基线是 P159 未归档的 delta，需 PM 先同步 P159」，同样与本任务无关。
两者都不影响 `openspec validate pulse-nudge-key`。

**F2 · change 的 tasks.md 有 1 条未勾（10/11）**
未勾的是 4.2「另一个 agent 重放 verify」——本来就该在复验阶段才勾。`archive -y` 会打一行
`Warning: 1 incomplete task(s) found. Continuing due to --yes flag.` 后继续；P193 交付时同样是 10/11。

**F3 · 归档顺序：pulse-nudge-key 不再挡别人**
我 grep 了所有活跃 change 的 delta：声明 `panel` 的只有 `delivery-truth` 与 `pulse-nudge-key`，而
delivery-truth 改的是 `The deferred-delivery queue…` 与 `A human can write to the PM…` 两条需求，
**不碰 status band**；声明 `watchdog` 的只有本 change。即：归档 pulse-nudge-key 不会让任何其它在跑
change 的 delta 变 stale（delivery-truth 的 panel delta 也不会因此再走一遍）。

## 6. 证据包（`docs/team/reports/P192-dev/`）

| 文件 | 内容 |
|---|---|
| `01-red-validate-all.log` | 红侧：`validate --all --strict` 16/2 |
| `02-red-validate-change.log` | 红侧：`validate pulse-nudge-key` 点名缺 3 条基线场景 |
| `03-counts-before.log` / `08-counts-after.log` | 重写前/后全部 delta 的 requirement/scenario 计数（§1.5） |
| `04-align-before.log` / `09-align-after.log` | MODIFIED 场景 ⊆ 基线、ADDED 不重名：前 3 findings（含本任务的 panel），后 1+1（都是 F1 的既有项） |
| `05-green-validate-change.log` / `06-green-validate-all.log` | 绿侧 validate（17/1） |
| `07-no-loss-check.log` | 基线 5 条 + 本 change 3 条全部逐字节在位，findings=0 |
| `10-red-trial-archive.log` | 红侧 scratch 预演：`Aborted. No files were changed.` |
| `11-green-trial-archive.log` | 绿侧 scratch 预演：`+0 ~2 -0`、归档为 `2026-10-03-pulse-nudge-key` |
| `12-green-trial-no-loss.log` / `archive-no-loss.py` | 归档后名字集合对照：lost_req=0、lost_scenarios=0，delta 场景全部落地 |
| `13-trial-specs-diff.txt` | 归档前后 `specs/{panel,watchdog}` 完整 diff（83+/3-，3- 全是文件头与一处换行重排） |
| `14-spec-refs-check.log` | 有效文本（基线 + 未归档 delta）的 `docs/team` 引用走查：undeclared 0 |
| `15`/`16`/`17-mutation-*.log` | 两次破坏性 mutation 的红侧（M1 validate 红；M2 validate 绿但 no-loss 红） |
| `rewrite-panel-delta.py`、`no-loss-check.py`、`alignment-check.py`、`scenario-counts.py`、`archive-no-loss.py` | 可重跑脚本 |

临时目录 `/tmp/p192-red`、`/tmp/p192-trial`、`/tmp/p192-mut`、`/tmp/p192-mut2`、`/tmp/p192-old-delta.md`
已全部删除（`ls` 报 not found）。

## 7. 边界与自检

- 改动清单（`git show --stat a8786315`）：唯一内容是
  `openspec/changes/pulse-nudge-key/specs/panel/spec.md`；本任务**未碰** `skills/**`、
  `openspec/specs/**`、`openspec/changes/pulse-nudge-key/{proposal,design,tasks}.md`、
  `docs/team/**`（除本报告与证据目录）。
- 分支状态：`task/P192-apply`，local 模式不 push；除把 main 快进并入本分支（§1.1）外未做任何合并，也
  未 merge 到 main。报告与证据提交后 `git status --porcelain` 应为空（唯一未跟踪项就是本报告目录，已一并提交）。
- 未读任何凭据文件；未 push、未 merge main 以外的分支、未 rebase/删除分支、未改仓库设置。
