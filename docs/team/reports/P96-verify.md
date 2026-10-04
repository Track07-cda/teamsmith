# P96 · 独立复验：合并流程的两道检查（P76 `--pre-merge` / P91 `--post-merge`）

agent: verify   status: delivered（任务书 1–4 项全部逐项复核；验证包 **157 ok / 0 bad / 0 script-level**；6 条 finding 见 §4：5 条验证侧发现 + 1 条跨任务的门禁红 F6）
    验证侧无 BLOCKED；但有 **1 条跨任务的门禁红（F6，既有于 main，不归 P76/P91）**：`openspec` 30/0，FAST `✓2759 ✗5`（5 条全部指向 `references/troubleshooting.md` 的 §20，由 `f534ec4b` 引入），需要 PM 路由。
time: 2026-09-23T01:15Z–03:25Z（复验窗口；全量门禁在队列里等了约 68 分钟）
branch: `task/P96-p96`（local 模式：不 push，分支留在 `.worktrees/verify`）   PR/MR: -
change: -（infra，两件工具的独立复核）
brief: `docs/team/tasks/P96-merge-flow-verify.md`
verified revision: main `acd04978`（= P96 任务书提交；技能树与**彼时的** main 逐字节一致，当时 `git diff main -- skills/` 为空）。
    复验期间 main 前进到 `61af37d1`（P93/P97）：`skills/` 下的 delta 只有 `references/protocol.md` 与
    `tests/flip-p72.sh`，**被验的 `scripts/lib/cmd-review.sh` 一字未动**（`git diff acd04978..main -- …/cmd-review.sh` 为空）；
    门禁在 `acd04978` 上跑，F6 的红在 `61af37d1` 上同样存在（`troubleshooting.md` 两支逐字节相同）。
    P95（`--post-merge` 比较基准）在 BOARD 上是 **todo**，没有落地 —— 所以本报告第 4 条确认与记录的是**现状行为**，
    不是修后行为。P76 作者 = dev-bob（P76）· P91 作者 = dev-bob（P91）——**我与作者不同人**。

## 0. 一句话

自造夹具（4 个临时仓库、18 条任务分支、全部自己搭）逐项复核了两道检查：`--pre-merge` 对未跟踪/
已改未提交/已暂存三类未入账记录点名并给出**真能执行的**修法（我原样跑了它，提交落账、再跑收敛），
只查 `docs/team/**`（近邻路径、state/、build/、ignored 都不误报），定位不到就 exit 2 不猜；
`--post-merge` 记录晚到 → 0 + 取它（我原样跑了 checkout 修法），代码晚到（skills/、非 skills/、删除）
→ 非零并点名「必须重新合并」，真合并 → 0，未合并的分支 → 明确措辞（代码非零、纯记录告诉你去取）。
两道检查都不跑门禁、不写记录、不动 HEAD（用 touch 型门禁的正对照钉住）。任务书第 4 条点名的
squash+解冲突误报**确认存在且报非零**（既有行为，P95 细化）；另外找到 3 条 finding（1 条 UX/口径、
2 条边界下界），均不影响上面的 fail-closed 结论。门禁侧：openspec 30/0；FAST `✓2759 ✗5`，
全量 `✓3425 ✗5`，**两边的 5 条红完全同一组、全部来自 main 上既有的一处文档变化（F6：
`references/troubleshooting.md` §20，`f534ec4b`），与 P76/P91 无关**——其余 3425 条
（含 smoke 的 P76 §45 / P91 §48 与全部真进程段落）全绿；零回归的比较基准（P92 复验 tip `613dcc84`）
上这段文档还不存在。

## 1. 我自己的证据 vs 引用

| 类别 | 内容 |
|---|---|
| **我自己的证据（本报告全部数字/输出的来源）** | `docs/team/reports/P96-verify/pkg/`：4 段自造夹具、**157 条断言**、0 bad 0 script-level；每条修法都**原样执行**过；影子翻转 2 组（检查删除 → 假绿 → 恢复）。原始输出在 `pkg/logs/run-20260923-025702-2144972/`。 |
| **引用（我读过、用来对表，但没有原样采信其结论）** | P76/P91 任务书与实现注释（`skills/teamsmith/scripts/lib/cmd-review.sh` 的 `team_cmd_review_premerge`/`team_cmd_review_postmerge`）、smoke §45/§48 的既有夹具（我只用来确认覆盖面，没有跑它当证据）、P95 任务书（已知边界的口径）。 |
| **没有原样采信** | P76/P91 的报告与「已通过」结论一条都没有写进结论；`--pre-merge` 的修法、`--post-merge` 的取记录修法都在我的夹具里真跑了一遍，并把跑完的收敛结果当证据。 |

复跑入口：

```sh
bash docs/team/reports/P96-verify/pkg/run.sh              # 157 ok / 0 bad / 5 finding / 0 skip（全绿侧）
bash docs/team/reports/P96-verify/pkg/run.sh 40           # 只跑边界段
```

## 2. 任务书逐项

| # | 任务书要求 | 结果 | 证据（我的段） |
|---|---|---|---|
| 1① | 未跟踪报告 → 非零 + 点名 + 可粘贴修法 | ✓ | §10 ①；`10-a.log`（3 份、逐条 `[??]`、两条可执行修法） |
| 1② | 已改未提交报告 → 同样点名 | ✓ | §10 ③；`[ M 已改未提交（工作区改动）]` 与 `[A 新文件已暂存未提交]` |
| 1③ | 只有 `state/` 脏 → 不误报 | ✓ | §10 ④；rc=0 且**零输出**（含 build/、ignored、近邻 `docs/team-other/`） |
| 1④ | 定位不到工作树 / `--dir` 混用 → exit 2 | ✓ | §10 ⑤⑥；三种定位失败 + refs-only 正对照 + 五类含混用法全部 exit 2 |
| 2① | 合并后只多了记录 → exit 0 +「记录有更新：取它」 | ✓ | §20 ②；`20-b.log`，并原样执行 checkout 修法 |
| 2② | 分支多了**代码** → 非零 +「必须重新合并」 | ✓ | §20 ③/③b/③c（skills/、extension/、删除） |
| 2③ | 已完全合并（无差异）→ 0 | ✓ | §20 ①（squash 后两边的树相同）+ ⑤（真合并祖先） |
| 2④ | 未合并的分支 → 明确措辞（不是静默 0） | ✓（+1 条下界反例 F5） | §20 ⑥：代码 → rc=1；纯记录 → rc=0 但措辞明确；§40 D3 是边界反例 |
| 3 | 两道检查互斥与既有语义：不跑门禁、不写记录；`--dir` 语义不变 | ✓ | §30（touch 型门禁标记 + 同夹具正对照 + `--dir` 拿错 checkout 拒绝/`--no-gates` SKIPPED） |
| 4 | 已知误报边界：squash + 手工解冲突 → 确认报非零，并写明是既有行为（P95 细化） | ✓ | §40 D1/D2；证据 `40-a.log`、`40-b.log` |
| 5 | 零回归：openspec + FAST + 全量 smoke | **△**（openspec 30/0；FAST `✓2759 ✗5`、全量 `✓3425 ✗5`，两边**同一组** 5 红 = F6，既有于 main，非 P76/P91） | §5 + `final-gates/` |

## 3. 证据

### 3.1 `--pre-merge`（段 10，53 ok / 0 bad / 0 finding）

夹具：临时仓库 + `team init` 脚手架 + `dev`/`dev2` 工作树；任务 `PA` 分支 `task/PA-alpha`。

**① 三类未入账 + 可粘贴修法（真跑）** —— `10-a.log` 尾部：

```
✗ review PA --pre-merge：3 份记录未入账（squash 合并只带已提交内容，它们会被留下）
  工作树：dev（/tmp/p96pkg.asbcHE/pre/.worktrees/dev @ task/PA-alpha）
  未入账（只看 docs/team/ 下；ignored 与其它脏文件不算）：
    dev: docs/team/DECISIONS.md  [ M 已改未提交（工作区改动）]
    dev: docs/team/reports/PA-dev.md  [?? 未跟踪（新文件，从未提交）]
    dev: docs/team/reports/PA-dev/pkg/run.sh  [?? 未跟踪（新文件，从未提交）]
  修法（PM 手工提交；skill 不替 agent 提交，提交带 `Agent:` trailer）：
    git -C …/.worktrees/dev add -A -- docs/team/DECISIONS.md docs/team/reports/PA-dev.md docs/team/reports/PA-dev/pkg/run.sh
    git -C …/.worktrees/dev commit -m "docs(team): PA 未入账记录" -m "Agent: dev"
  → 提交后重跑：team review PA --pre-merge
```

- 我**原样执行**了打印出来的两行（`10-a-fix.sh`）：rc=0，HEAD 前进，提交信息带 `Agent: dev`；
  再跑 `--pre-merge` → rc=0 且零输出（收敛）。
- 只读性：检查本身不改 HEAD、文件仍停留 `??`；`docs/team/reviews/PA.md` 始终不存在（不写记录）。
- 近邻诱饵 `docs/team-other/note.md`、`docs/team-other-note.md` 一个都没被点名（路径作用域按目录组件匹配）。
- 负对照（§10 ④）：worktree 里只有 `scratch.txt`、`build/x.o`、`.pi/team/state/junk`、ignored 的
  `docs/team/inbox/dev.md` 与 `docs/team/reviews/local.log` → rc=0、零输出。

**② fail-closed 与含混用法**（`10-f.log`、`10-g.log`、`10-h.log`）：state+分支+工作树全无 / 分支在但
没有工作树 / 两条 `task/PA-*` 歧义 → 全部 **exit 2**，措辞「定位不到……无法检查（不猜）」；正对照
（无 state、refs 唯一、干净）→ rc=0 零输出，说明 fail-closed 没有把正常定位一起挡掉。
`--pre-merge` 与 `--dir/--branch/--no-gates/--strong/--allow-unresolved-branch/--post-merge` 六种
含混用法全部 exit 2 且点名原因。

**③ 翻转（可证伪）**：把 `team_review_unlanded_records` 影子成空（检查被删除的形状）→ 同一份脏夹具
**rc=0 且零输出**；恢复 → rc=1 且重新点名路径（`10-flip-green/shadow/restored.log`）。

### 3.2 `--post-merge`（段 20，71 ok / 0 bad / 2 finding）

夹具：临时仓库 + 4 条任务分支（squash 合并 3 条、真合并 1 条）+ 2 条从未合并的分支。

- **① 刚合并完**：`20-a.log` → rc=0，「两边的树相同 —— 没有合并后新增」，不误报代码，main HEAD 不动。
- **② 记录晚到（真跑修法）**：`20-b.log` 打印 `记录有更新（合并后分支上又提交了 docs/team/ 下的记录）—— 取它`
  + 一条可粘贴 `git checkout task/PB-beta -- docs/team/DECISIONS.md docs/team/reports/PB-dev-late.md`。
  原样执行 → 在 main 里提交 → 再跑 → rc=0「没有合并后新增」（收敛）。
- **③ 代码晚到**：`20-d.log` → rc=1「✗ 代码有未合并的改动 —— 不能只取记录，必须重新合并并重跑门禁」+ 点名
  `skills/x.sh`；③b `extension/z.txt`（本仓库 `skills/` 之外的代码路径）→ rc=1 +「既不是记录也不是技能代码」；
  ③c 晚到删除 `skills/y.sh` → rc=1 + 点名。
- **④ 记录删除**：④a 分支删掉分叉点就存在的 `docs/team/reports/PD-old.md` → rc=0 + `[删除]` + `git rm -f`
  修法（不劝 checkout）；原样执行 + 提交后收敛为「没有合并后新增」。④b 是边界（见 F2）。
- **⑤ 真合并**：分支 tip 是 main 祖先 → rc=0 +「已经是 main 的祖先（真合并 / fast-forward）」。
- **⑥ 未合并分支**：`20-j.log` 有代码 → rc=1 + 点名 `skills/pf.txt`；`20-k.log` 纯记录 → rc=0 但输出
  「记录有更新（合并后分支上又提交了……）—— 取它」+ checkout 修法（措辞明确，不是静默 0）。
- **⑦ fail-closed**：ID 没有分支 / 两条候选分支 → 全部 exit 2，明说「不报绿」「不接受 --branch」。
- **⑧ 含混用法**：`--dir/--no-gates/--strong/--allow-unresolved-branch/--branch` → 全部 exit 2。
- **⑨ 翻转（可证伪）**：把 `team_review_postmerge_paths` 影子成空 → 同一份「代码晚到」夹具变成
  rc=0 +「两边的树相同」（假绿），更响的那句消失；恢复 → rc=1（`20-flip-*.log`）。

### 3.3 互斥与既有语义（段 30，22 ok / 0 bad / 0 finding）

- 门禁配置成 `touch $F/gate-ran`（一跑必留痕）。同一夹具：`--pre-merge` 命中未入账 rc=1、
  `--post-merge` 记录晚到 rc=0 —— **两次都不产生门禁标记**、不产生 `reviews/<ID>.md`；
  随后**普通复验** `review PS --dir <worktree>` → rc=0、标记出现、记录写出且 `判定: **PASS**`、
  绑定 `task/PS-sem`。正对照证明标记机制有效（不是标记自己坏了）。
- `--dir` 既有语义：拿**别的分支**的 checkout → exit 1 +「checkout 与任务分支不一致（复验会验错东西）」
  + 两支 HEAD；`--dir --no-gates` → rc=0 + 记录 `判定: **SKIPPED**`（不是 PASS 证据）。
- 两道检查都不动 main/分支工作树的 HEAD。

### 3.4 已知误报边界（段 40，11 ok / 0 bad / 3 finding）

- **D1（代码路径）**：main 与分支改同一行 → squash 冲突 → PM 手工解成第三版
  （我在夹具里确证解冲突后的 main **含着分支的改动语义** `branch+other`）→ `--post-merge` **rc=1**：
  `✗ 两边都动过、版本对不上（main 那一版不来自这条分支，分支这一版 main 也没有过）—— 自己看一眼，别直接取`
  + 点名 `skills/x.sh`。**这是既有行为**（P95 任务书自己写的现场），不是本次复验发现的回归。
- **D2（记录路径）**：同一个形状放在 `docs/team/reports/PW-shared.md` 上 → 同样 rc=1 +「版本对不上」。
  即：**退出码 1 不等于「代码缺失」**；在解过冲突的路径上，纯记录晚到也会非零。口径见 F4。
- **D3（下界探针）**：未合并的分支，其 tip 内容恰好等于 main 历史里用过的 blob → 被判 `behind`、
  `rc=0` +「没有合并后新增 —— …… 全部来自 main 一侧」。见 F5。

## 4. Findings（finding 不阻塞；按严重度排序）

| # | 级别 | 现象与最小复现 | 影响与我看到的证据 |
|---|---|---|---|
| **F1** | 低（UX/口径） | **`--post-merge` 打印的取记录修法不收敛**：原样执行 `git checkout <branch> -- …`（不提交）后再跑，仍打印「记录有更新：取它」。`SKILL.md:119-121` 也只说 take them（checkout），没说取完要 commit。 | 照字面执行「取完再看一次」会原地打转；检查本身没坏（提交后就收敛，§20 ② 实测）。证据：`20-b2.log`（同一份输出重现一遍）。建议：修法里补一条 commit（或那句提示改成「取完并提交后再看一次」）。 |
| **F2** | 低（边界，信息性） | **跨合并的「先加后删」被归成 `behind`**：分支在合并前把 `PD-second.md` 加进来（squash 进 main），合并后又删掉它 → rc=0，路径不被点名，措辞说「差异全部来自 main 一侧」。 | 内容层面 main 不缺（分叉点没有这个文件，再合并也不会带走这个删除），所以 fail-closed 结论不受影响；但「分支合并后动过」这一事实被静默、归因也不准确。证据：`20-g2.log`。留给 PM 决定是否进 P95+ 的口径。 |
| **F3** | 已知（任务书点名） | squash + PM 手工解冲突 → 两边都动过的代码路径必报非零（「版本对不上」/「必须重新合并」），即使 main 那一版是 PM 手工合入、含分支改动的解冲突版。 | **P95 的现场**，本报告按任务书要求确认它存在且报非零；P95 落地前这是现状。证据：`40-a.log`。 |
| **F4** | 已知（F3 的另一面） | 同一形状发生在**纯记录**路径上时也 rc=1。 | 配合 F3 一起看：在解过冲突的路径附近，**退出码 1 不能单独解释成「代码缺失」**；P95 细化基准后这条应该收敛。证据：`40-b.log`。 |
| **F5** | 低（下界反例，信息性） | 未合并分支 + tip 内容 == main 历史用过的 blob（main 早已独立走到更新的版本）→ 被判「只是落后」、rc=0、措辞归因 main 一侧。 | 内容层面无缺失（该 blob 曾进过 main），但按任务书 2④「未合并的分支 → 明确措辞（不是静默 0）」这是一条下界反例。证据：`40-c.log`。 |
| **F6** | **中（跨任务，阻塞零回归项）** | **main 在 `acd04978` 上已是 5 红（与 P76/P91 无关）**：FAST `✗ 5`，五条命中全部指向同一个提交 `f534ec4b` 新增的 `references/troubleshooting.md` §20（l.1064-1080）：① `## 20 · …` 用了**中文正文**（9 行 CJK），违反 references 正文全英文不变量；② 该节示例 `team review P82 --post-merge` 不带 `--dir`，撞上「文档在教没有 --dir 的 review」用法守卫；③ 因为真树 references 里已有 CJK，§18 的翻转自测沙箱基线被污染 → 「干净副本被误报」+ 两条「净」翻转误报。 | 5 条红**没有一条**由 P76/P91 或本任务引入：`cmd-review.sh` 在本修订与当前 main 上逐字节相同；troubleshooting.md 的 CJK/用法命中在 `f534ec4b` 里，而该提交晚于 P92 的复验 tip（`613dcc84` 里搜不到这段）。修法属于 smoke 守卫/文档口径（P95 的 grant 正好是 `troubleshooting.md§20 + smoke.sh`，但 P95 仍 todo）——**请 PM 定口径**：要么把 §20 改回英文并给示例补 `--dir` 或用 `.pre/post-merge` 的新形豁免，要么调整不变量并将其写成 P95 的一部分。证据：`pkg/logs/final-gates/fast.log`（l.1050/1611/1620/1621/1626）、`openspec.log`。 |

## 5. 零回归门禁

| 门禁 | 结果 | 日志 |
|---|---|---|
| `openspec validate --all --strict` | `Totals: 30 passed, 0 failed`（rc=0） | `pkg/logs/final-gates/openspec.log` |
| `TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh` | **`✓ 2759 ✗ 5`（rc=1）**，5 条全部 = F6（`troubleshooting.md` §20，`f534ec4b`） | `pkg/logs/final-gates/fast.log` |
| `bash skills/teamsmith/tests/smoke.sh`（全量） | **`✓ 3425 ✗ 5`（rc=1）**，5 条红与 FAST **逐条同一组** = F6；其余 3425 条含全部真进程段落与 P76 §45 / P91 §48 全绿 | `pkg/logs/final-gates/full2.log` |

（全量第一次排队 1800s 命中队列上限未跑（持锁者 dev3 的 smoke，队列消息在 `full.log`）；
第二次 `TEAM_SMOKE_LOCK_WAIT=10800` 重排，等了约 68 分钟后拿到锁跑完（01:56 排队 → 03:25 结束）。）

FAST 的 5 条红（逐条都点名同一个文件，不是 P76/P91 的代码）：

```
✗ 文档在教「没有 --dir 的 review」：references/troubleshooting.md:1070:$ bash … team review P82 --post-merge
✗ 英文正文不变量被破坏（references/** 或 SCOPE.md 的正文里有 CJK）:
     skills/teamsmith/references/troubleshooting.md:1064: ## 20 · `<...>` 报「两边都动过」时先看内容
✗ 翻转自测（净）：只有行内代码里有中文 被误报：troubleshooting.md:1064: ## 20 · ...
✗ 翻转自测（净）：只有围栏代码块里有中文 被误报：troubleshooting.md:1064: ## 20 · ...
✗ 干净副本被误报
```

第 3–5 条是第 2 条的**级联**：§18 的翻转自测从一个拷贝自真树的沙箱（`CJK_SB`）出发，
真树 references 里已经有 CJK 正文（§20），所以“干净副本”基线本身就不干净 —— 检查器没错，
错的是文档；§20 的示例行又正好撞上 §14 的 `--dir` 用法守卫。**与我改/验的东西无关**：
`cmd-review.sh` 在 `acd04978` 与当前 main `61af37d1` 上逐字节相同；FAST 红侧回放表明
P76/P91 的所有断言（含我新写的影子夹具）在这两份树上是绿的（§10⑦/§20⑨）。

## 6. 翻转证据（strong 复验要求的 red → green）

两组影子都在**同一份夹具**上做，红侧是「检查被删除」的形状，绿侧是原实现：

| 组 | 绿侧（red 结果 = 守卫在拦） | 红侧（break → 假绿） | 恢复 |
|---|---|---|---|
| `--pre-merge` | `10-flip-green.log`：rc=1、点名 `docs/team/reports/PA-flip.md` | 影子 `team_review_unlanded_records` → `10-flip-shadow.log`：**rc=0、零输出** | `10-flip-restored.log`：rc=1 |
| `--post-merge` | `20-flip-green.log`：rc=1、「代码有未合并的改动」+ 点名 | 影子 `team_review_postmerge_paths` → `20-flip-shadow.log`：**rc=0、「两边的树相同」**（更响的那句消失） | `20-flip-restored.log`：rc=1 |

## 7. 边界与备注

- 本地模式：分支留在 `.worktrees/verify`，不 push；`verified revision` 的技能树与 main 一致。
- 我没有改任何实现（`grant` 只给报告与证据）；本包全部夹具在 `/tmp`，tmux 调用被 PATH 包装到
  私有 `-L p96pkg-<run>` server，全程 `env -u TMUX -u TMUX_PANE`。
- P95 未落地：F3/F4 的处置口径以 P95 为准；F1/F2/F5 是本次新记录的边界，交 PM 判读。
- F6 是**跨任务的门禁红**（`f534ec4b` 的 `troubleshooting.md §20`），不在本任务的 grant 内，我没有改它；
  请 PM 决定给谁（P95 的 grant 正好盖住 `troubleshooting.md` 与 `smoke.sh`）——在它修好前，
  任何在主分支上跑 FAST/全量门禁的人都会看到同样 5 条红。
