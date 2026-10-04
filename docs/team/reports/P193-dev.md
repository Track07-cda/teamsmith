# P193 · `meeting-liveness` 的 delta 重写（归档基线已前进）

```
task:    P193
agent:   dev
change:  meeting-liveness
phase:   apply
tip:     8ffb9f42（delta 改写）；本报告与证据目录的提交紧随其后 = 分支 HEAD
branch:  task/P193-apply（local 模式：不 push，分支留在本地 worktree，PM 复验后本地合并）
status:  delivered
```

## 0. 判定摘要（逐条对照任务书「要做的」）

| 任务书条目 | 判定 | 我的证据（自己跑的） |
|---|---|---|
| **1 把 delta 重写到与当前基线对齐** | ✅ | §1、§2；红侧 `validate` 点名 panel 丢 2 条场景 + `archive` 当场中止；绿侧 `validate meeting-liveness` 通过、scratch 预演 `archive -y` 成功（`+4 ~7 -0`） |
| **1b MODIFIED 文本 = 基线现状 + 本 change 改动** | ✅ | §1 的两处文件改写（panel 重写 + meeting 补回基线子句）；`09-prose-diff.log` 逐 requirement 词级对照：剩下仅剩**本 change 自己的**替换/追加，meeting 一节已无任何 `-BASE` 行 |
| **1c ADDED 不重名、scenario 一个不丢** | ✅ | §1 计数表（56 → 58，+2 是补回的基线场景）；`08-alignment-check.log`：无 MISSING、无 COLLISION |
| **2 保留已定契约（发现性/过期可关/投递安全/身份并集/12 位标识）** | ✅ | 只重写文本、未动任何 change 场景的语义；五个 delta 的场景计数除 panel 补回基线的 2 条外逐条不变（§1 表） |
| **3 验收三命令** | ✅（一红一绿已如实标注） | §2：`validate meeting-liveness` ✓ / `validate --all --strict` 18/1（唯一红 = `pulse-nudge-key`，P192 的活，非本任务引入）/ scratch 预演 `archive -y` ✓；临时克隆已删（§6 尾） |

## 1. 改了什么

只改两个文件（均为 `openspec/changes/meeting-liveness/specs/**`，brief 的 grant 内），提交 `8ffb9f42`：

### 1.1 `specs/panel/spec.md` —— 真正挡住归档的那条（**重写**）

当前基线 `The status band answers "who is in charge" and "is there work"` 在 `capacity-floor-disk`
（2026-10-02 归档）之后多了两段磁盘契约与两条场景；本 change 的 delta 是 2026-09-30 按旧基线写的，
`MODIFIED` 整块替换会在归档时把它们**悄悄丢掉**。改写后：

- prose = **当前基线原文** + 本 change 的两处改动：① pending counts 里加 `unread meeting turns`；
  ② `panel.pending` 带 `meetings` 并计入 `total`。基线的磁盘子句（temp root / worktrees root 的
  available bytes / free inodes、`—` 占位、`panel.capacity.disk` 每文件系统一项或 `null`）逐字保留。
- 场景 = 基线 4 条（含两条磁盘场景）+ 本 change 的 `The band carries unread meeting turns`（追加在末尾）。

### 1.2 `specs/meeting/spec.md` —— 基线子句补回（**一行**）

`Meetings are bounded` 的 delta 把基线里的 `(with --yes, because it changes shared state)` 掉了（不是本 change
的改动），补回后该段 = 基线原文 + 本 change 的追加。取舍与理由见 §5 F2。

### 1.3 另外三个 delta —— 逐条核对，**未改**

`notify-and-inbox`、`delivery-guard`、`watchdog` 的 `MODIFIED` 块都已经是「基线原文 + 本 change 改动」：
`09-prose-diff.log` 里它们的差异只有本 change 自己的插入/替换（delivery-guard 的
`keep today's behaviour (cross-project)` → 本 change 的排队语义，是本 change 的意图），
`08-alignment-check.log` 里无 MISSING / 无 COLLISION。

### 1.4 scenario 计数对照（重写前 = `HEAD~1`，重写后 = 工作树）

| delta 文件 | 重写前 | 重写后 | 说明 |
|---|---|---|---|
| `meeting/spec.md` | 18 | 18 | MODIFIED 1→6（基线 1 条在）；ADDED 4 条共 12 |
| `notify-and-inbox/spec.md` | 12 | 12 | MODIFIED 4→8、1→4 |
| `delivery-guard/spec.md` | 17 | 17 | MODIFIED 13→14、2→3 |
| `panel/spec.md` | **3**（基线 4，**缺 2** ✗） | **5**（基线 4 全在 ✓） | +`The disk readings reach the band and the JSON`、+`A filesystem that cannot be read is not assigned a number` |
| `watchdog/spec.md` | 6 | 6 | MODIFIED 3→6 |
| **合计** | **56** | **58** | 没有丢任何本 change 的 scenario，+2 全是补回的基线场景 |

## 2. 验收命令（原始输出尾部；红/绿两侧都留档）

### 2.1 红侧（`HEAD~1` 的 delta，scratch 树 `/tmp/p193-red`）—— `01-red-before.log`

```
$ openspec validate meeting-liveness --type change
Change 'meeting-liveness' has issues
✗ [ERROR] panel/spec.md: MODIFIED "The status band answers "who is in charge" and "is there work"" omits
scenario(s) the current spec still has: "The disk readings reach the band and the JSON", "A filesystem that
cannot be read is not assigned a number". ...
rc=1

$ openspec archive -y meeting-liveness
panel MODIFIED failed for header "### Requirement: The status band answers "who is in charge" and "is there work""
- current spec contains scenario(s) not present in the modified block: "The disk readings reach the band and the
JSON", "A filesystem that cannot be read is not assigned a number". Refresh the change spec before archiving to
avoid dropping scenarios.
Aborted. No files were changed.
rc=1

$ openspec validate --all --strict        # 重写前
Totals: 17 passed, 2 failed (19 items)     # change/meeting-liveness + change/pulse-nudge-key
```

### 2.2 绿侧（交付树）—— `02`、`03`、`04`、`06`、`10`

```
$ openspec validate meeting-liveness --type change            # 02-green-validate-change.log
Change 'meeting-liveness' is valid
rc=0

$ openspec validate --all --strict                            # 03-green-validate-all.log
✓ change/meeting-liveness
✗ change/pulse-nudge-key
Totals: 18 passed, 1 failed (19 items)
Details: openspec validate pulse-nudge-key --type change
rc=1        # 唯一红是 P192 的 pulse-nudge-key（本任务未引入；重写前是 2 红）

$ cd /tmp/p193-trial2 && openspec archive -y meeting-liveness  # 04-green-trial-archive.log
Applying changes to openspec/specs/panel/spec.md:  ~ 1 modified
Totals: + 4, ~ 7, - 0, → 0
Specs updated successfully.
Change 'meeting-liveness' archived as '2026-10-03-meeting-liveness'.
rc=0        # 0 条删除 = 没有丢基线

$ bash skills/teamsmith/tests/spec-refs.sh --check --root <worktree>   # 10-spec-refs-check.log
spec-refs: judged 101 reference(s) (49 distinct) in 10163 effective line(s); retired 4; undeclared 0
rc=0
```

### 2.3 scratch 预演做了什么（临时克隆已删）

`04` 的预演 = 把交付树的 `openspec/` 整份拷到 `/tmp/p193-trial2`，先存 `specs-before`，再 `archive -y`；
`05-trial-specs-diff.txt` 是归档前后 `openspec/specs/**` 的完整 `diff -u`（16 hunk / 5 个文件），
`11-no-loss-check.log` 是按 requirement/scenario **名字集合**再跑一次预演的对照（不受换行重排影响）：

```
$ python3 docs/team/reports/P193-dev/no-loss-check.py <specs-before> <specs-after>
delivery-guard     req 11->11  scenarios  55-> 57  lost_req=0 lost_scenarios=0 gained_req=0 gained_scenarios=2
meeting            req  6->10  scenarios   9-> 26  lost_req=0 lost_scenarios=0 gained_req=4 gained_scenarios=5
notify-and-inbox   req 19->19  scenarios  60-> 67  lost_req=0 lost_scenarios=0 gained_req=0 gained_scenarios=7
panel              req 40->40  scenarios 200->201  lost_req=0 lost_scenarios=0 gained_req=0 gained_scenarios=1
watchdog           req 18->18  scenarios  56-> 59  lost_req=0 lost_scenarios=0 gained_req=0 gained_scenarios=3
（其余 8 个能力 0 变化）
RESULT: OK — nothing lost
rc=0
```

逐条核过的重点：

- `panel`：prose 段以整段替换出现（改写后行宽重排，`05` 里成对的 `-`/`+`），但磁盘子句在 `+` 侧逐字在位，
  **两条磁盘场景根本没进 diff（= 未变）**；archive 统计 `- 0`、`05` 里**没有任何 `-### Requirement` /
  `-#### Scenario` 行**、`11` 的 lost=0 —— 三者合起来才是「只加不丢」的完整证据；
- `meeting`：`05` 第 72 行是上下文行（行首空格）`team meeting close … (with --yes, because it changes shared
  state).` —— 即归档后仍在、未被删；
- `watchdog` / `notify-and-inbox` / `delivery-guard`：它们的 MODIFIED prose 只出现本 change 自己的插入/替换
  （`09-prose-diff.log`），`11` 的 lost=0。

## 3. Flip evidence（红 → 绿）

| 侧 | 命令 | 结果 |
|---|---|---|
| 红 | `openspec validate meeting-liveness --type change`（`HEAD~1` delta） | ✗ 点名 panel 丢两条场景（`01-red-before.log`） |
| 红 | `openspec archive -y meeting-liveness`（`HEAD~1` delta） | ✗ `Aborted. No files were changed.` rc=1（同上） |
| 绿 | `openspec validate meeting-liveness --type change`（`8ffb9f42`） | ✓ `Change 'meeting-liveness' is valid` |
| 绿 | `openspec archive -y meeting-liveness`（scratch） | ✓ `+ 4, ~ 7, - 0` rc=0 |

## 4. 我跑了什么 / 我没跑什么 / 引用了什么

**自己跑的**：§2 的五条命令 + `01`～`11` 的证据文件（脚本在 `docs/team/reports/P193-dev/*.py`，可在仓库根
重跑）；另加两个机械比对（scenario ⊆ / prose 词级对照）。

**没跑**：`smoke.sh`（FAST 与全量都没跑）。理由：本任务只改 `openspec/changes/meeting-liveness/specs/`
下的文本，任务书的验收命令就是 validate ×2 + scratch 预演；smoke 不读该目录（`grep openspec/changes
skills/teamsmith/tests/smoke.sh` 命中的都是历史 change 的夹具与 `12e` 的临时目录夹具，不读本 change 的
delta）。文本级门禁我用 `spec-refs.sh --check` 补上了（§2.2 绿）。若 PM 要全量 smoke 我可以补跑。

**引用的（不是我跑的）**：`docs/team/reviews/meeting-liveness-proposal.md`（P134 提案审查：当时
`panel 2→3`、五条 delta 一条场景不丢）；`git show c90d5cfe:` / `git show HEAD~1:`（重写前 delta；
确认 `--yes` 子句在 propose 时就被掉了）；P139/P160/P182 的实现与复验记录（实现侧未动，一条都没改）。

## 5. 需要 PM 裁决 / 顺带发现

**F1 · brief 的 `deltas:` 头与实际挡路者不一致（需要 PM 确认口径）**
`deltas: meeting,notify-and-inbox`，但 `openspec validate meeting-liveness` 报的、以及预演能证明会丢文本的
是 **`panel`**（`meeting`/`notify-and-inbox` 的 validate 结构本就通过，meeting 只有 §1.2 那处 prose 遗漏）。
`panel` 在本 change 里只有 P134/P139 声明过、无其他在跑任务声明，grant 又覆盖
`openspec/changes/meeting-liveness/**`，所以我按任务书 deps 里写的「panel 基线前进 → delta 不匹配」改了它。
若 PM 本意是另有任务负责 panel，请告诉我，我把这块回退成待办。

**F2 · `--yes` 子句：我选了「基线保真」，但这里有一处基线自身的不一致（需要 PM 一句裁决）**
基线 `meeting` 里**唯一**的 `--yes` 陈述就是这句「`team meeting close` … (with `--yes`, because it changes
shared state)」；实现里 `team_allow_write` 只被 `team_meeting_open` 调用（`cmd-meeting.sh:315`），
`team_meeting_close` 连 `--yes` 参数都不接受（`-*) team_usage_die`），本 change 自己的场景
（`An expired meeting can be closed`、`close --stale`）也都是不带 `--yes` 跑 close。
- 我按 brief 的「MODIFIED 文本 = 基线现状 + 本 change 改动」**保留/补回**了这句：它是基线现状，
  本 change 并没有声明要删它（删了 meeting 能力就再也没有 `--yes` 的任何陈述，而 `open --yes` 是真的、
  `TEAM_CONFIRM_WRITES` 默认 1）。
- 代价：归档后的 `meeting` 规格里，这句 prose 与本 change 的无 `--yes` close 场景并存（这处不一致是基线
  带来的，不是本任务引入的）。
- 另一条路（P134 对 F3 的口径：规格与现实不符就在 delta 里纠正、并在提案/设计里点名）是把这句删掉并写进
  `design.md`。要哪条由 PM 定；改动都是一分钟的事。

**F3 · 归档顺序耦合（预演实证，供 PM 排期）**
`06-green-trial-validate.log`：把 `meeting-liveness` 归档进 scratch 后，**另两个在跑 change 立刻变 stale**：

```
✗ delivery-truth  — delivery-guard MODIFIED 缺 "A meeting knock never lands on a draft"
✗ pulse-nudge-key — panel MODIFIED 缺 "The disk readings…"、"A filesystem that cannot be read…"、"The band carries unread meeting turns"
```

即：① 先归档 `meeting-liveness` → **delivery-truth 需要一个 delta 重写任务**（目前没有），且 P192
（pulse-nudge-key，按**今天**的基线重写）要再走一遍；② 先归档 `pulse-nudge-key` → 本 change 的 panel delta
需要再补它的追加。这是 D40/D42 的既有规则，但这次两个 change 的 panel delta 同时在飞，建议 PM 明确先后。

## 6. 证据包（`docs/team/reports/P193-dev/`）

| 文件 | 内容 |
|---|---|
| `01-red-before.log` | 红侧：`HEAD~1` delta 的 validate（点名 panel）+ archive 中止 + `validate --all` 17/2 |
| `02-green-validate-change.log` / `03-green-validate-all.log` | 绿侧 validate（18/1，唯一红 = pulse-nudge-key） |
| `04-green-trial-archive.log` | scratch `archive -y meeting-liveness`：`+4 ~7 -0`、归档为 `2026-10-03-meeting-liveness` |
| `05-trial-specs-diff.txt` | 归档前后 `openspec/specs/**` 完整 diff（16 hunk；证明只加不丢） |
| `06-green-trial-validate.log` | 归档后的 scratch 树 validate：16/2（F3 的顺序耦合证据）+ 两条失败全文 |
| `07-scenario-counts-before-after.log` | §1.4 的计数表（`before` = `git show HEAD~1:`，`after` = 工作树） |
| `08-alignment-check.log` / `alignment-check.py` | 机械比对：MODIFIED 存在且场景 ⊆、ADDED 不重名 |
| `09-prose-diff.log` / `prose-diff.py` | 逐 requirement 词级 prose 对照（`-BASE` = delta 未携带的基线文本） |
| `10-spec-refs-check.log` | 有效文本（基线 + 未归档 delta）的 `docs/team` 引用走查：undeclared 0 |
| `11-no-loss-check.log` / `no-loss-check.py` | 再跑一次 scratch 预演，按名字集合对照 requirement/scenario：lost_req=0、lost_scenarios=0 |
| `scenario-counts.py` | 计数脚本（在仓库根 `python3` 直接重跑） |

临时目录 `/tmp/p193`、`/tmp/p193-red`、`/tmp/p193-trial`、`/tmp/p193-trial2`、`/tmp/p193-check` 已全部删除
（`ls` 报 not found）；证据全部落在仓库内的 `docs/team/reports/P193-dev/`。

## 7. 边界与自检

- 改动清单（`git show --stat 8ffb9f42`）：`specs/meeting/spec.md`、`specs/panel/spec.md`；
  本任务**未碰** `skills/**`、`openspec/specs/**`、`openspec/changes/meeting-liveness/{proposal,design,tasks}.md`、
  `docs/team/**`（除本报告与证据目录）。
- `git status --porcelain` 在本报告提交后应为空（唯一未跟踪项就是本报告的目录，已提交）。
- 未读任何凭据文件；未 push、未 merge、未动 main。
