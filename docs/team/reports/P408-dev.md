# P408 · 三份小规格的长需求拆分试点

agent: dev   status: DELIVERED   time: 2026-11-12T05:04:43Z
branch: `task/P408-spec-clarity-pilot`   PR/MR: -

结论：15 条 MODIFIED 改写、两段 canonical Purpose 补写及 V157 的四项句级返修均已完成。`d8c20e7c` 补回读行的 `<ID>`/`<n>`/`<slug>` 形状及拒绝时点名 command/token；`81041d81` 补回「而不是仅缩窄主张」，并把 AI 评分理由的主体改回规格文本或其指向记录。最终隔离试归档后，三份规格各自 `--strict` 都是 rc=0、0 warning；目标长需求告警从 15 降为 0，全局从实测 239 降为 224。change 保持未归档，等待 V157 定点复核。

## Deliverables

| Path | What |
|---|---|
| `openspec/changes/spec-clarity-burn-down/proposal.md` | 声明纯措辞改写、三份能力范围、不改行为且不在交付树归档 |
| `openspec/changes/spec-clarity-burn-down/tasks.md` | 三份规格与证据清单 |
| `openspec/changes/spec-clarity-burn-down/specs/writing-discipline/spec.md` | 4 条完整 MODIFIED；正文均不超过 500 字符 |
| `openspec/changes/spec-clarity-burn-down/specs/extension-slash/spec.md` | 6 条完整 MODIFIED；正文均不超过 500 字符 |
| `openspec/changes/spec-clarity-burn-down/specs/help-surface/spec.md` | 5 条完整 MODIFIED；正文均不超过 500 字符 |
| `openspec/specs/writing-discipline/spec.md` | 仅按 PM 例外授权替换 Purpose 的 TBD；requirement/scenario 未改 |
| `openspec/specs/help-surface/spec.md` | 仅按 PM 例外授权替换 Purpose 的 TBD；requirement/scenario 未改 |
| `docs/team/reports/P408-dev.md` | 实测结果、逐需求行为对照和最终交付证据 |

## OpenSpec assessment

| Dimension | Score | Evidence |
|---|---|---|
| Completeness | PASS | 15/15 条长需求都有完整 MODIFIED block；15 个原标题不变；43 个原场景逐字保留，新增 17 个 WHEN/THEN 场景承接移出的边界与枚举 |
| Correctness | PASS | 最终试归档合并为 `+0 ~15 -0 →0`；目标长需求告警 15→0；三份 strict 均 rc=0、0 warning；V157 四项缺失均有正文/场景承接，43 个原场景仍逐字保留 |
| Coherence | PASS | `openspec validate spec-clarity-burn-down --strict` rc=0；`spec-refs --check` 为 `undeclared 0`；未改 canonical spec、产品代码或测试 |

## CRITICAL

- None. 首轮发现的两条 Purpose 占位告警已由 PM 在任务书末尾明确授权补写；单独提交 `769fdb1b` 只替换两段 TBD，最终三份 strict 全绿。

## WARNING

- None.

## SUGGESTION

- None.

## Final assessment

- Counts: CRITICAL 0 · WARNING 0 · SUGGESTION 0.
- Readiness: 任务书规定的适用验收及 V157 四项返修已完成，可交 V157 定点复核；未归档、未推送。
- Unverified applicable checks and reasons: None。全量 smoke 与真实归档由任务书明确排除；全局 strict 已运行，仍因范围外 224 条长需求及既有空 delta 等问题 rc=1，本片只要求并证明长需求数严格下降。

## 行为零改动对照

路径缩写：`W=openspec/changes/spec-clarity-burn-down/specs/writing-discipline/spec.md`，`E=.../extension-slash/spec.md`，`H=.../help-surface/spec.md`。每行列出原需求的判定主旨及其在 delta 中的正文/场景行；原场景全部保留，新增场景只承接原正文细节。

| 原需求与判定文字（摘句） | 改后位置 |
|---|---|
| W「caution…SHALL be kept only when it names something the reader can check…otherwise SHALL be deleted」 | `W:4` 正文；`W:6-23` 保留支持测试、禁止语气指令、保留有据边界 |
| W「A finding SHALL state what it changes…An observation that changes nothing SHALL NOT…body」 | `W:26` 正文；`W:28-33` 保留后果写法、禁止新增必填栏目、正文排除规则 |
| W「The rule SHALL travel with the tool…held by reading rather than by the gate」 | `W:36` 正文；`W:38-66` 逐一保留四个表面及其职责、人工评审边界、不得增删门禁断言/退出码 |
| W「SHALL be judged by a human…An AI reviewer's score MUST NOT…」 | `W:69` 正文；`W:71-86` 保留预先固定 rubric、材料与盲标、单读者限制及四组 AI 测量依据 |
| E「register exactly one…`/team`…arguments…unchanged…project root…session's directory」 | `E:4` 正文；`E:6-19` 保留无模型工具、原样 argv 与项目 cwd |
| E「accept only…one table…Every other…refused before any process…menu/completion…same table」 | `E:22` 正文；`E:24-54` 保留 read/action 形状、指名拒绝、表增删同时改变菜单与准入 |
| E「`up`…`--fresh-pm`…refused…without controlling stdin…bounded wait…terminated」 | `E:57` 正文；`E:59-71` 保留 PM 会话理由、终端归属、超时终止且不遗留/不续等 |
| E「single line…200…notification…non-zero…failure…500 lines or 64 KiB…beginning and end」 | `E:74` 正文；`E:76-101` 保留四种结果呈现、退出码与完整输出读取提示 |
| E「MUST NOT…confirmation…authorization flag…CLI's guards…三个环境变量 MUST NOT be inherited」 | `E:104` 正文；`E:106-119` 保留用户 `--yes`、环境剔除及 CLI 的写授权/派单/容量/身份/生命周期判定 |
| E「available…project-local…`.pi/extensions/`…MUST NOT…second load path」 | `E:122` 正文（含两个 init-skill 锚点）；`E:124-129` 保留主检出可用、未安装 worktree 不可用、只注册一次 |
| H「three levels…one machine-readable command manifest…Every command…reachable…unknown…exit 2…without a project」 | `H:4` 正文；`H:6-72` 保留入口形式、manifest 字段、内部名闭集、alias、未知 token、无项目及不得启动进程 |
| H「English by default…`TEAM_LANG`…prose only…missing key…marker…MUST NOT change…machine-readable output」 | `H:75` 正文；`H:77-108` 保留 en/zh/未知语言、环境唯一来源、缺键回退及机器输出字节不变 |
| H「prose…manifest…closed vocabularies…closed placeholder set…Every value…probe…Usage…unchanged」 | `H:111` 正文；`H:113-154` 保留字段/占位符双向闭集、六类效果探针、usage 与 dispatch 锚点 |
| H「Except…`team say --now`…names/exit codes unchanged…`--print`/`--json` byte-identical」 | `H:157` 正文；`H:159-199` 保留 say 例外、outbox/draft、四组字面 flags、状态与机器输出兼容 |
| H「bytes…NOT depend on…locale…own locale-independent counter…No printed line…`TEAM_HELP_WIDTH`」 | `H:202` 正文；`H:204-221` 保留 UTF-8、代码点宽度、禁用 locale 测宽、非法值警告及环境唯一来源 |

自动结构核对另确认：`writing-discipline` 原场景 8/8、`extension-slash` 14/14、`help-surface` 21/21 均逐字保留；三份标题集合完全相等；15 条新正文均 ≤500 字符。没有需求标题变化，因此没有引用需要更新。

## Verification evidence (must have actually been run)

基线在分支起点 `2814587a` 实测为 239，而不是任务书估计的 240；差 1 不被人为调整。

```
$ openspec validate spec-clarity-burn-down --strict
Change 'spec-clarity-burn-down' is valid
rc=0

$ grep -c 'Requirement text is very long' /var/tmp/p408-spec-clarity/before-all.log
239
```

首轮试归档留下两条 Purpose 告警后，PM 追加 Purpose 补写例外；`769fdb1b` 单独提交两段 TBD 替换。V157 四项返修后，在 `/var/tmp/p408-spec-clarity/v157-repair-trial/project` 重新复制最终 `openspec/` 并运行原生归档：

```
$ (cd /var/tmp/p408-spec-clarity/v157-repair-trial/project && openspec archive -y spec-clarity-burn-down)
Totals: + 0, ~ 15, - 0, → 0
Specs updated successfully.
Change 'spec-clarity-burn-down' archived as '2026-11-12-spec-clarity-burn-down'.
rc=0
```

最终试归档后的三份 strict 结果：

```
$ (cd /var/tmp/p408-spec-clarity/v157-repair-trial/project && openspec validate writing-discipline --strict)
Specification 'writing-discipline' is valid
rc=0

$ (cd /var/tmp/p408-spec-clarity/v157-repair-trial/project && openspec validate extension-slash --strict)
Specification 'extension-slash' is valid
rc=0

$ (cd /var/tmp/p408-spec-clarity/v157-repair-trial/project && openspec validate help-surface --strict)
Specification 'help-surface' is valid
rc=0

$ grep -c 'Requirement text is very long' /var/tmp/p408-spec-clarity/v157-repair-all.log
224
$ grep -h 'Requirement text is very long' /var/tmp/p408-spec-clarity/v157-repair-{writing-discipline,extension-slash,help-surface}.log | wc -l
0
$ grep -h '\[WARNING\]' /var/tmp/p408-spec-clarity/v157-repair-{writing-discipline,extension-slash,help-surface}.log | wc -l
0
```

V157 返修后的结构与四项语义对照：

```
writing-discipline: titles=4 unchanged; original scenarios preserved=8; bodies<=500=yes
extension-slash: titles=6 unchanged; original scenarios preserved=14; bodies<=500=yes
help-surface: titles=5 unchanged; original scenarios preserved=21; bodies<=500=yes
V157 four repairs: all present
```

全局 strict 改前 rc=1（239 条长需求，另有既有 Purpose/空 delta 问题），试归档后 rc=1（224 条长需求，其他问题不属于本片）；这里只把 **239→224** 作为本片计数证据，不宣称全局通过。

```
$ bash skills/teamsmith/tests/spec-refs.sh --check
spec-refs: judged 122 reference(s) (49 distinct) in 14071 effective line(s); retired 0; undeclared 0; id families used [D,E,F,M,P,V] named [D,E,F,M,P,V]
rc=0

$ bash skills/teamsmith/tests/section-select.sh --check
ok: 段 ↔ 行一一对应（源码 141 段 / 表 141 行）
SKIP（条件不满足）: … .pi/skills
== 选段自检 ==  ok 13  bad 0  SKIP 1
rc=0

$ git diff --check
rc=0
```

- Verdict: **pass（任务书规定的适用验收）**.
- Notes: 未运行全量 smoke，未改产品行为，未在真实树归档。临时证据保存在 `/var/tmp/p408-spec-clarity/`；交付以本报告摘录和分支文件为准。
- Ledger ban（报告落盘后在本 worktree 运行）:

```
$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: root=/home/<user>/Documents/syncthing/Work/Projects/pm-skills/.worktrees/dev scope=published files=2737 hits=0 names=ok user=resolved
rc=0
```

## Flip evidence

N/A — 本任务是可读性改写，不是缺陷修复；原生试归档的 `~15`、目标长需求告警 `15→0` 和结构保留检查是本次对照证据。

## 给剩余 17 份规格的可复制做法（6 行）

1. 先记录实际长需求数，不把 Purpose 等其他告警混入改写数量。
2. 每条 MODIFIED 复制完整需求与全部原场景，保持原标题不变。
3. 正文只留判定主旨；把枚举、边界、测量值和路径职责移到 WHEN/THEN/AND 场景。
4. 新场景必须能分别证伪，不能用「原文仍成立」之类自指句子代替行为。
5. 跑 change strict 与 `spec-refs --check`，再逐字核对原场景并做正文长度检查。
6. 在 `/var/tmp` 的 openspec 副本试归档，比较前后告警数；真实归档仍等独立复验和用户确认。

## Decisions and deviations

- 基线采用实测 239，而非任务书的 240；净下降为 15。
- 使用隔离副本试归档来观察 MODIFIED 合并后的主规格，因为未归档 delta 不改变 canonical spec 的单独校验结果。
- 按 PM 的 Purpose 补写例外直接编辑两份 canonical spec 的 Purpose；其它 canonical requirement/scenario 未改。V157 返修只动两处 delta 文件中的四个句子，未处理其建议项。未在交付树归档，未改产品代码/测试，未跑全量 smoke，未推送远端。

## Suggested next steps

- 交 V157 定点复核四项句级返修、最终三份 strict 和结构/语义对照；通过后再按流程请求用户确认归档。
