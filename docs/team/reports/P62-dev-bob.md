# P62 · fixture-waits-for-landed-reads（propose）

task: P62   agent: dev-bob   status: 交付（propose：变更包 + 门禁 + 报告；**不实现**）   time: 2026-09-22T15:35Z
branch: `task/P62-propose`（local 模式，不 push）   PR/MR: -（本仓库无远端投递）
change: `fixture-waits-for-landed-reads`（deltas: `verification`，ADDED-only）   phase: propose

**总结论**：变更包已落盘并通过门禁自证——`openspec validate --all --strict` **25/25**、试归档
`+ 2 added, ~ 0`（归档后其余 24 项仍全绿）、**零 `skills/**` 改动**（propose 边界）。两条 requirement 都带
可伪证的场景与复核配方；未写实现。门禁里的唯一红（FAST 与全量各一条）是 **main 上既有的 §40 lint
finding**，与本变更无关，已归因、已通知 PM（见“门禁的红”）。

## Deliverables

| Path | What |
|---|---|
| `openspec/changes/fixture-waits-for-landed-reads/proposal.md` | Why / What Changes / Flip / Boundaries / Acceptance / Evidence |
| `openspec/changes/fixture-waits-for-landed-reads/specs/verification/spec.md` | delta：**ADDED ×2**（数据态断言的有界等待；量测对象固定），共 6 条可伪证场景 |
| `openspec/changes/fixture-waits-for-landed-reads/design.md` | 现场与证据（P52 §C / F2 / F4）、规则边界、D1–D6 裁定、三条可复现的注入配方、逐 requirement 复核方法、残余 |
| `openspec/changes/fixture-waits-for-landed-reads/tasks.md` | 一个 apply brief（B1–B4）+ 一个 verify brief（不同 agent）、覆盖映射、路径授权、夹具纪律、残余 |
| `docs/team/reports/P62-dev-bob.md` | 本报告 |

## 任务书逐条对照（硬要求）

| 任务书条目 | 落点 | 复核方法 |
|---|---|---|
| ① 夹具等“数据态”，不等骨架/固定 sleep；有界 + 归因；不得变性能阈值（M59/D48、D33） | delta §1（requirement + 4 场景，含“不判时长”场景） | 场景 1/2 的注入配方见 design §3 D2 配方 A |
| ② 同类邻居（D44 F2：`panel-b3.sh` collapse 固定 sleep + 单次 capture） | delta §1 场景 3 + tasks 2.1–2.4 | design §3 D2 配方 B（`TEAM_B3_PANEL` 慢首帧） |
| ③ F4：量测对象固定（中性/参考树，而非调用工作树） | delta §2（requirement + 2 场景）+ tasks 3.1–3.4 | design §3 D2 配方 C（两棵工作树，同一 root、同一结论） |
| ④ 可伪证：延迟注入（旧红/新绿）+ 数据永不落定（到顶点名，不假绿） | delta §1 场景 1/2；tasks 1.1/1.2 Verify | 同上配方 A（P52 §C 已给 0s/6s/6s+5× 视界的基线） |
| policy B：delta 落 `verification` | `specs/verification/spec.md`（唯一 delta 文件） | `openspec validate --all --strict` |
| MODIFIED 不删 base scenario | **本变更不用 MODIFIED**（design §3 D4：base requirement 已有两个未归档 MODIFIED，第三个会造成 D7/D40 的互相重写）；两条均 ADDED，不存在删 base 的场景 | 试归档 `+ 2 added, ~ 0, - 0` |
| 每条 requirement 给复核方法 | design §5 表（requirement → 场景 → 配方/命令）；tasks 每条 Verify | 本报告“门禁的红”之外的命令均可复跑 |
| 不写实现 | `git show --stat` 只有 `openspec/changes/**`；`skills/**` 零改动 | `git diff --stat main...HEAD` |

## Verification evidence

### 1 · 规格校验（propose 的唯一硬门禁）

```
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
✓ change/fixture-waits-for-landed-reads
…
Totals: 25 passed, 0 failed (25 items)        # rc=0
```

### 2 · 试归档（integration check：ADDED 不与 base/其它变更相撞）

```
$ mkdir -p /tmp/p62-trial && cp -r openspec /tmp/p62-trial/openspec && (cd /tmp/p62-trial && openspec archive -y fixture-waits-for-landed-reads)
Applying changes to openspec/specs/verification/spec.md:
  + 2 added
Totals: + 2, ~ 0, - 0, → 0
Change 'fixture-waits-for-landed-reads' archived as '2026-09-22-fixture-waits-for-landed-reads'.
$ (cd /tmp/p62-trial && openspec validate --all --strict)
Totals: 24 passed, 0 failed (24 items)        # 归档后其余未归档变更仍全绿
```

**踩到的坑（记录，未改文档）**：`references/openspec.md` §5 的试归档单行是
`cp -r openspec /tmp/trial && (cd /tmp/trial && openspec archive -y <id>)`——当 `/tmp/trial` 不存在时它把
**内容**拷成 `/tmp/trial/*`，而 CLI 解析的是“包含 `openspec/` 的最近祖先”，于是报
`Error: Change '<id>' not found. No active changes exist in this root.`（`openspec list` 也说 `No active changes found.`）。
要把副本落在**名为 `openspec` 的目录**里（上表命令即正确形态）。该文档是 PM 独占（`skills/teamsmith/references/**`），
本 task 只记录，不越界修改；tasks 4.2 已写成正确命令。

### 3 · 门禁（AGENTS 的两件套）

```
$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
== 结果 ==  ✓ 2367  ✗ 1
FAST_RC=1

$ bash skills/teamsmith/tests/smoke.sh </dev/null      # 全量（14:59 排队，15:17 拿锁，约 17 分钟）
  38-b panel-p21.sh choices 全绿（ ✓ 110 ✗ 0 SKIP 0）
  38-f panel-p21.sh groups/settings/wheel 全绿（ ✓ 102 ✗ 0 SKIP 0）
== 结果 ==  ✓ 2898  ✗ 1
FULL_RC=1
```

**门禁的红（唯一一条，FAST 与全量相同）——不是本变更的，已归因并已通知 PM**：

```
✗ 40 lint 有 finding（rc=1）：…/skills/teamsmith/tests/container-tmux.sh:159: 名字不在 owned 家族
  （${TMPDIR:-/tmp}/fpcheck.XXXXXX）—— 必须是 teamsmith-<kind>.XXXXXX
…/container-tmux.sh:215: 名字不在 owned 家族（${TMPDIR:-/tmp}/fpcheck2.XXXXXX）—— 必须是 teamsmith-<kind>.XXXXXX
```

- 直接复跑即可独立证明：`bash skills/teamsmith/tests/tmp-hygiene.sh --lint` → `2 个 finding`、`rc=1`；
- 归属：这两行由 **P47 `6ca5595c`**（ledger-and-gate-noise）落盘，lint 由 **P53 `34e6c00c`**（test-tmp-hygiene）
  引入；`6ca5595c` 是 `34e6c00c` 的祖先（`git merge-base --is-ancestor` 验证），而 P53 报告的验收跑在其
  frozen tip `cf5bbdc` 上（当时 lint 只数到 4 个模板，现在 6 个）——所以这是**落地集成后**才在 main 上出现的红；
- 与本变更无关：`git diff --stat main...HEAD` 只含 `openspec/changes/**`，lint 扫的是 `tests/**`；
- 归 **P60**（test-tmp-hygiene 独立验证，BOARD `wip`）或 PM 处置；已 `team notify pm`（2026-09-22 15:2x）。

### 4 · 交付面

```
$ git status --porcelain          # （报告提交前）空
$ git log --oneline main..HEAD
docs(openspec): P62 — rules for the review recipes and the trial-archive path
docs(openspec): P62 — design decisions and the task plan for fixture-waits-for-landed-reads
docs(openspec): P62 propose fixture-waits-for-landed-reads — proposal and the verification delta
```

- Verdict: **规格与变更包 pass**（validate 25/25、试归档 +2 added、零 `skills/**` 改动）；
  **门禁 pass 未取得**——唯一红是 main 上既有的 §40 lint（他人变更，见上）。
- Notes（没跑的、已知风险）：
  - 本 task **没有**跑任何注入/夹具（propose 边界：不写实现、不改夹具）；红侧配方与基线数字来自
    `docs/team/reports/P52-dev2.md`（§C / F2 / F4），每条在 design §3 D2 都给了可复现命令，apply/verify 必须实跑并贴尾巴；
  - design §1.1 的代码行号按**本工作树**核对（`main.tsx:792`、`App.tsx:1211`），P52 报的是它当时的行号（788-793 / 1251-1258），
    两处都在 design 里标注了；
  - 全量门禁的 38-b/38-f 这次会跑（非 FAST），两条都绿——说明当前基线本身干净，F2 的红是负载相关、不是恒红。

## Flip（计划的红 → 绿；apply 拥有，本 task 未执行）

1. **A**：scratch 的 `panel-p21.sh` CLI wrapper 在 `__panel-data --block settings` 前 sleep 6s →
   pre-change 红（`非规范拼写的手改值原样显示成当前条目` 等，2 核配额 5/5 的形状 `✓ 108 ✗ 3`；P52 §C 的 0s 绿/6s 红/6s+5× 视界仍红）；
   post-change **在延迟落定后绿**（等的是“行上已是新值”，不是骨架）；
2. **A′**：延迟超过 cap → 有界等待到顶，一行点名等待与所等的数据态，**不是**假绿；
3. **B**：`TEAM_B3_PANEL` 慢首帧 → pre-change 单次采样红（`pulse 窗口里是控制台` / `恢复后同一窗口里又是控制台`，P52 F2 6 次红 4 次）；
   post-change 有界轮询到“屏上是控制台”后绿；
4. **C**：`panel-cpu.sh` 默认参数分别在本工作树与全新工程跑 → pre-change 3683ms vs 391ms、一侧 rc=2；
   post-change 打印同一被测 root、同一结论。

## Decisions and deviations

1. **只用 ADDED，不用 MODIFIED**（design §3 D4）：`verification#The correctness gate judges correctness only`
   目前挂着两个未归档 MODIFIED（`pty-fixture-load-premise`、`gate-section-accounting`），
   `gate-section-accounting` 的 D7 已实测“谁先归档、另一个的 delta 必须按新 base 重写”。ADDED 不参与这场重写，
   试归档证明 `+ 2 added, ~ 0, - 0` 且其余 24 项仍绿。**这是对任务书 “MODIFIED 不删 base scenario” 的保守化解读：
   不删 base 场景的最强形式就是不动那条 base requirement。** 若 PM 更希望把规则并入该 base requirement，
   请在 apply 前裁定——那会把本条变更卷入上面的重写顺序。
2. **量测对象固定 = 中性工程 + 被测 bundle 分离**（design §3 D3）：`panel-cpu.sh` 测夹具自建的中性工程
   （经 `lib/tmp-root.sh` 的 owned 家族），而被测的仍是 `--tree` 指的那份 bundle/CLI；`perf.sh --tree`
   继续指“被测代码”，输出同时点名“量测 root”和“被测 bundle”。
3. **wait 的引擎复用而非新造**（design §3 D1）：`panel-p21.sh` 用它已有的 `pty_wait_frame`（settled frame + 前提归因）；
   `panel-b3.sh` 今天不 source `pty-wait.sh`，实现可 source 或加一个同样纪律的小 helper——但必须计数、有 cap、
   到顶一行归因，并进入 `gate-section-accounting` 的 loop inventory。cap 必须在 fixture 头里带测得 band（D5）。
4. **范围收口的普查**（D6）：只普查本变更碰的三个 fixture（`panel-p21.sh`/`panel-b3.sh`/`panel-cpu.sh`）；
   别处同类形状写成 finding 交 PM 排期，不静默扩大也不静默放过。
5. **偏差：无**（其它与任务书一致）。

## Suggested next steps

- **PM 提案复审**（`docs/team/reviews/fixture-waits-for-landed-reads-proposal.md`，ACCEPTED 才派 apply）。
  十条清单里值得当场点开的两处：① checklist 7——两条 ADDED 是否与 base 的
  `verification#The correctness gate judges correctness only`、`…The performance suite is separate…` 重复
  （design 已用“引用不重述”处理，试归档也证明名字不相撞）；② checklist 8——一个 apply brief（B1–B4）能否装下。
- apply brief 里请写进 tasks 的三条决定：路径授权（`tests/**` 是 agent:dev 的；`smoke.sh` 只在加 FAST 钉子时才授权）、
  D2 三条注入配方必须实跑、D5 的 band 记录。
- **不是本变更的红**：§40 lint 的 `container-tmux.sh:159/215`（`fpcheck.*` 不在 owned 家族）——建议放进 P60 的
  finding 或在 P60 复验前由 PM 决定谁改（是改这两行的名字，还是让 lint 对 `--fingerprint-check` 的私有目录豁免；
  前者更符合 P53 的“一个 owned 家族”规则）。在修掉之前，每个席位的 FAST/全量门禁都会红在这一条。
- `references/openspec.md` §5 的试归档单行命令建议补 `mkdir -p`（PM 独占路径，见“踩到的坑”）。
