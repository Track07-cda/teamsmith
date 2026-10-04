# P78 · bottom-border-candidate-selection（propose）— 交付报告

agent: verify   status: delivered（propose 完成，等 PM 提案审查）   time: 2026-09-22T19:05:00Z
branch: `task/P78-propose`（local 模式：分支留在 `.worktrees/verify`，不 push）   PR/MR: -
change: `bottom-border-candidate-selection`（phase=propose，owner=verify；deltas=`delivery-guard`）
brief: `docs/team/tasks/P78-bottom-border-propose.md`
tip: `task/P78-propose` HEAD（`git log --oneline -5`：提案 `cadce48e` → 证据包 `c0e1adc3` → 报告 → 帧清单修正 `71151e97`，其后只有本报告自身的措辞修正）

## Deliverables

| Path | What |
|---|---|
| `openspec/changes/bottom-border-candidate-selection/proposal.md` | 提案：Why / What（ADDED `delivery-guard`）/ Flip / Capabilities / Boundaries / Acceptance / 报告必须包含的证据 |
| `openspec/changes/bottom-border-candidate-selection/specs/delivery-guard/spec.md` | delta：**一条 ADDED requirement** —— *The bottom border is the lowest qualifying rule row below the cursor*，9 个 scenario（brief 的五个形态 + 代价形态 + `holds_only` 后果 + 真帧不回归 + 同源/影子） |
| `openspec/changes/bottom-border-candidate-selection/design.md` | 设计：候选表（A–E，逐个带证伪帧）、ADD vs MODIFIED 的裁决（归档顺序）、单点决策与红侧影子、镜像代价与不可分性证明、fixtures 方案、风险表、复核计划、apply 边界 |
| `openspec/changes/bottom-border-candidate-selection/tasks.md` | 一个 apply brief（B1 规则/B2 帧与门禁/B3 端到端与文档）+ 覆盖表 + 路径授权 + 每项的 verify 命令 |
| `docs/team/reports/P78-verify/pkg/{lib,10-frames,20-ambiguity,30-real-frames,40-guard-matrix,50-alternatives,run}.sh` | 本报告全部数字的可复跑探针（纯函数：不开 tmux、不跑 pi、不改实现树；§40 在临时副本上打补丁） |
| `docs/team/reports/P78-verify/logs/pkg-{10,20,30,40,50}.log`、`pkg-run.log` | 原始输出（下面所有 tail 的来源） |

## Verification evidence（全部真跑，下面是原始输出）

```
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
✓ change/bottom-border-candidate-selection
...
Totals: 28 passed, 0 failed (28 items)          # exit 0
$ PATH="$HOME/.bun/bin:$PATH" openspec status --change bottom-border-candidate-selection
Progress: 4/4 artifacts complete   [x] proposal [x] specs [x] design [x] tasks
```

```
$ bash docs/team/reports/P78-verify/pkg/run.sh
== 10 结果 == ✓28 ✗0 · findings=0 · skip=0
== 20 结果 == ✓4 ✗0 · findings=0 · skip=0
== 30 结果 == ✓15 ✗0 · findings=0 · skip=0
== 40 结果 == ✓7 ✗0 · findings=0 · skip=0
== 50 结果 == ✓3 ✗0 · findings=1 · skip=0
== run 结果 == ✓57 ✗0 · findings=1 · skip=0      # exit 0
```

### 1. 候选表：今天的「最近候选」vs 提案的「最低合格候选」（`pkg-10.log`）

```
  head (today = nearest candidate):
    F1 draft-rule-below-cursor           (cy=2) geometry=[1 3] box_nows=[] verdict=idle-read=EMPTY rc=0
    F2 draft-rule-only                    (cy=2) geometry=[1 3] box_nows=[] verdict=idle-read=EMPTY rc=0
    F3 wider-rule-below-cursor            (cy=2) geometry=[1 5] box_nows=[────…(140)…drafttext] verdict=idle-read=NOT-EMPTY rc=1
    F4 spinner-row-below-cursor           (cy=2) geometry=[1 5] box_nows=[──⠋Blanching…0s…drafttext] verdict=idle-read=NOT-EMPTY rc=1
    F5 cursor-mid-draft                   (cy=3) geometry=[1 5] box_nows=[draftline1draftline2draftline3] verdict=idle-read=NOT-EMPTY rc=1
    F6 conversation-rule-below-box        (cy=2) geometry=[1 3] box_nows=[] verdict=idle-read=EMPTY rc=0
    F7 draft-rule-below-cursor-line       (cy=2) geometry=[1 3] box_nows=[halfasentence] verdict=idle-read=NOT-EMPTY rc=1 holds_only=only-ours
    F8 draft-rule-blank-region            (cy=2) geometry=[1 3] box_nows=[] verdict=idle-read=EMPTY rc=0

  lowest (the proposed rule):
    F1 geometry=[1 5] …drafttextbelowmyownrule… verdict=idle-read=NOT-EMPTY rc=1
    F2 geometry=[1 4] box_nows=[──…] verdict=idle-read=NOT-EMPTY rc=1
    F3 / F4 / F5 与 head 逐字相同
    F6 geometry=[1 4] … verdict=idle-read=NOT-EMPTY rc=1        # 文档化的镜像代价
    F7 geometry=[1 5] box_nows=[halfasentencerulemoredraft] holds_only=extra-text
    F8 geometry=[1 5] verdict=idle-read=NOT-EMPTY rc=1
```

- **红侧（缺陷在场）**：F1/F2 今天判 `EMPTY`（框截短、草稿规则行下方的草稿内容不在框内）；F7 的 `holds_only` 对
  「等于规则行上方那段」的 payload 回 `only-ours`（截断框与 payload 相同）。
- **绿侧（提案规则）**：F1 `[1 5]`、F2 `[1 4]`、判 `NOT-EMPTY`；F7 全框读出、`extra-text`。
- **② 更宽横线 / ③ spinner 形态行**：两条规则下都不变（都不是下边框候选 → 留在框内当内容 → 忙）。
- **⑤ 光标在草稿中间**：不变（三行全读出）。

### 2. 不可分性证明（`pkg-20.log`）

```
  F2  sha256: e463c80cddc00efb84456a93b151536cd2683da923a789a5381baacb4f5053a6
  F2b sha256: e463c80cddc00efb84456a93b151536cd2683da923a789a5381baacb4f5053a6
  ok    20a the two readings are the same bytes (a rule cannot tell them apart)
```

brief 的形态 ①b（草稿只有一行规则行）与形态 ④（框下方紧邻会话里的规则行）**是同一份字节**；一个判据只能给
两者同一个结论，规格选不能粘连的那一侧（内容 → 忙）。对照：形态 ⑩（会话区规则行在框**上方**）在今天的
**最高**顶边框规则下已经会撑大框 → 忙（`20c`），即镜像代价在顶侧本来就是被规格接受的写法。

### 3. 真帧不回归 + 结构测量（`pkg-30.log`）

```
  pi-0.87.0-one-line-draft.txt        cy=26  geometry=[25 27] idle-read=NOT-EMPTY rc=1
  pi-0.87.0-draft-half-sentence.txt   cy=26  geometry=[25 27] idle-read=NOT-EMPTY rc=1
  pi-0.87.0-empty-box.txt             cy=26  geometry=[25 27] idle-read=EMPTY rc=0
  pi-0.85.1-update-banner.txt         cy=26  geometry=[24 29] idle-read=EMPTY rc=0
  pi-0.87.0-project-trust-prompt.txt  cy=16  geometry=[] overlay=trust-prompt rc=0
    （同一批帧在 lowest 规则下逐字相同：30a–30e proposed 全 ok）
  structure:
    pi-0.87.0-one-line-draft.txt        rules=2 lowest=27 rule_rows_below=0
    pi-0.87.0-draft-half-sentence.txt   rules=2 lowest=27 rule_rows_below=0
    pi-0.87.0-empty-box.txt             rules=2 lowest=27 rule_rows_below=0
    pi-0.85.1-update-banner.txt         rules=6 lowest=29 rule_rows_below=0
    pi-0.87.0-project-trust-prompt.txt  rules=2 lowest=16 rule_rows_below=0
```

两份实测布局里，框下边框之下**没有任何整行 ─**（0.87.0 的 28–30 行是 cwd/usage/mc；0.85.1 的 30 行是页脚），
所以「最低候选」在真帧上取到的就是真下边框本身——代价形态在实测布局里不可达。

### 4. 回归：guard-matrix 两方向逐行相同（`pkg-40.log`）

```
  unmodified tree:     rc=0  == 结果 ==  ✓ 31  ✗ 0
  lowest-candidate copy: rc=0  == 结果 ==  ✓ 31  ✗ 0
  ok 40d no failed assertion in the lowest-candidate copy
  ok 40f every state line is identical (no verdict moved; nothing new went red)
  ok 40g the tree under review is untouched by this section
```

（19 个 pane 状态 + 12 条 `holds_only`/pin；补丁只打在 `$TMPDIR` 的副本上，被测树 hash 前后一致。）

### 5. 被否决的替代方案各自的证伪帧（`pkg-50.log`、`pkg-10.log` §10h）

```
  50 · E（丢掉配对约束 = 取光标下方最低整行 ─，上面随便一条规则行当顶边框）
    pairing rule (the spec keeps it): geometry=[] box_nows=[] verdict=idle-read=NOT-EMPTY rc=1   # 未知形状路径
    unpaired alternative:             geometry=[1 3] box_nows=[] verdict=idle-read=EMPTY rc=0    # 幽灵框 → 空 → 会白打字
  10h · C（只有「两个候选之间区域非空」时才取下边框）
    falsifier: F8（草稿 = 规则行 + 一个空行）仍然 geometry=[1 3] box_nows=[] idle-read=EMPTY      # 洞重开
```

### 未跑的门禁（明确说明）

`TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null` 与全量 smoke **本回合没有跑**：门禁锁
`/tmp/teamsmith-smoke.lock` 被 dev3（`/tmp/p75-full2.log`，全量）、dev-bob（P68 全量）与 dev（FAST）占用
（`pgrep` 实测），propose 任务的记录验收是 `openspec validate --all --strict`（28/28 通过）。full gate 在
apply/verify 的计划里（`tasks.md` 3.3），我这边没有把它当作已通过。

## Flip evidence（缺陷修复类要求）— 红→绿原始输出

红侧：`pkg-10.log` 的 head 表 F1/F2（`geometry=[1 3]`、`box_nows=[]`、`idle-read=EMPTY`）与 F7 的
`holds_only=only-ours`；P74 的独立复验在真实工具上先量到同样形状（`docs/team/reports/P74-dev2/pkg/20-border.sh`
§20h/20h2）。

绿侧：同一批帧在 lowest 规则下（影子实现，生产代码只差候选循环方向）F1 `[1 5]`、F2 `[1 4]`，判
`NOT-EMPTY`；F7 `holds_only=extra-text`。

反向（可证伪）：把候选决策影子成旧的「最近优先」，两条红帧必须翻回 `EMPTY`（`pkg-10.log` 10a/10b 的 head
断言；`pkg-20.log` 20b）——apply 的门禁段必须常驻这条影子方向；控制帧（F3/F4/F5 + 5 份真帧）在两种方向下
都不得变。

## Findings（给 PM 提案审查用）

1. **F1（brief ② 与 ④ 不能同时按字面满足）**：brief 要求「④ 框下方紧邻会话里的规则行 → 不许把框撑到会话
   文本上」，但 ①b（草稿只有一行规则行）与 ④ 是**同一份字节**（sha256 相同），任何结构性规则只能给同一个
   结论。设计选了**保守侧**（内容 → 忙），并把镜像代价写进 troubleshooting §3；请 PM 在提案审查里确认这个
   裁决（这是本提案唯一一处不按 brief 字面执行的地方，理由与证伪帧在 design §3/§6）。
2. **F2（ADDED 而非 MODIFIED）**：brief 第 4 项要求给理由。base requirement 对下边框候选**只字未提**（没有
   可改写的既有语句），且 `one-line-draft-judgement` 已复验但**尚未归档**——MODIFIED delta 会与它的归档顺序
   互相覆盖（谁后归档谁把对方的 requirement 文本整段替换掉）。ADDED 无此耦合，base 的 13 条 scenario 保持不动。
3. **F3（提案字数）**：`proposal.md` 644 词，超过 `openspec/config.yaml` 的「under 500 words」约定；与已接受
   的先例同形（`one-line-draft-judgement` 694 词、`settings-view-groups` 1083 词）。若 PM 要求压缩，我可以把
   Flip/Evidence 两节折进 design。
4. **F4（成本方向的诚实性）**：新规则会把「框下方有整行 ─」的 pane 判忙（交付等待，不粘连）。实测两份布局
   不可达；若未来布局在框下画规则行，属**已知代价**而不是静默失效，且必须和顶侧代价并列写在 §3。

## Decisions and deviations

- **裁决：下边框 = 光标下方**最低**的合格候选**（合格 = 与顶边框候选配对：等宽整行 tier1 / spinner 形态
  tier2），保留 M45 横幅排除、两遍回退、严格在光标行下方找（V9-A10）、未知形状走「按今天投递 + 一条告警」。
- 与 brief 的偏差只有 F1 一处（④ 按保守侧裁决并文档化）；其余按 brief 逐项交付。
- 候选表把 brief 的三个备选都量过：② 更宽的规则行**本来就不是候选**（不等宽、不配对），③ spinner 行从来
  不是**下**边框候选（只作 tier2 顶边框），⑤ 光标在草稿中间本来就读全三行——它们的 value 是回归钉而不是修复。
- 红侧用「影子候选顺序」实现，**不加生产开关**（P67 的 `M24_SHADOW_CHROME` 模式）；`flip-m45.sh` 的跨树探针
  保持为「同源」的唯一例外。
- 没有改实现、没有改 base spec、没有改 `openspec/specs/**`；`docs/team/tasks/**` 只读。
- 交付后的自审修正（`71151e97`）：`tasks.md` 2.1 与 `design.md` §7 的存储帧清单从 7 张补齐为 8 张
  （漏了 `p78-draft-rule-below-cursor-line.txt`，它正是 `holds_only` scenario 与 §10g 用的帧）；修完
  `openspec validate --all --strict` 复跑 28/28。

## Suggested next steps

1. **PM 提案审查**：写 `docs/team/reviews/bottom-border-candidate-selection-proposal.md`（ACCEPTED / NEEDS-CHANGES），
   重点看 F1 的裁决与 F2 的 ADDED 选择；`git show cadce48e --stat` 与 `docs/team/reports/P78-verify/pkg/run.sh`
   可复跑全部数字。
2. 归档顺序：`one-line-draft-judgement` 与本 change **无先后约束**（ADDED 的好处）；两者都在用户确认后归档。
3. apply 派单（**不是 dev3**，P74 的 F1 明确要求换人）：任务书按 `tasks.md` 的三个批次 + 路径授权
   （`scripts/lib/outbox.sh`、`tests/**`、`references/troubleshooting.md`），apply 的交付必须带红/绿两方向的
   门禁段与全文 smoke 尾巴；随后由第三方独立验证。
