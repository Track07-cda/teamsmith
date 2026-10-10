# E17 · 长作业车道：起完就结束回合、叫醒带结果（正式提案）

agent: dev2   status: PROPOSAL COMPLETE — 待 PM 全文审核与独立评审   time: 2026-10-10T09:47:00Z
branch: `task/E17-long-job-suspend-propose`   PR/MR: -（local 模式，无 push）

## Deliverables

| Path | What |
|---|---|
| `openspec/changes/long-job-suspend/proposal.md` | 目的式车道口径、三态回合结束、可数性、影响与偏离约定的落点 |
| `openspec/changes/long-job-suspend/design.md` | 八个决策：逐面措辞表 / 例外三条的判据 / 三态落地 / 挂起与中断的判定 / 叫醒兜底 / 账本两类行 / 落点偏离 / A·B 两刀排期 |
| `openspec/changes/long-job-suspend/tasks.md` | 未勾的 apply 任务（输入冻结、A 刀车道侧、A 刀通知侧、B 刀提示词与文档、独立验证），含后续验收命令登记 |
| `openspec/changes/long-job-suspend/specs/background-jobs/spec.md` | 新能力：3 requirements / 9 scenarios（工具面合同、账本可数、重启留证） |
| `openspec/changes/long-job-suspend/specs/dispatch/spec.md` | ADDED：1 requirement / 4 scenarios（工人简报的三态与按目的教学车道） |
| `openspec/changes/long-job-suspend/specs/notify-and-inbox/spec.md` | MODIFIED：1 requirement（基线 8 场景逐字节保留 + 5 个新场景） |
| `docs/team/reports/E17-dev2.md` | 本报告 |

完整 tracked 写集合就是上表 7 份；相对派单基线 `47c6fe6` 的 6 份工件共 +689 行、无其他文件
（`git diff --stat 47c6fe6..HEAD`）。**未写产品代码**，未改 `extension/`、`cmd-agents.sh`、`templates/`、
`references/`、`AGENTS.md`；未派 apply、未勾 `tasks.md` 的任何 apply 项、未合并、未 push、未归档、未改任务书。

仓外证据根：`../pm-skills-ledger/team/reports/E17-dev2/`（下文记为 `E`；`E/run.sh` 是五条验收的可复现运行器）。

## 续跑与继承（上一轮额度中断）

本轮开始时分支上只有 PM 的账本提交，`git status` 里是上一轮 `kimi-coding/k3:max` 会话（09:32 撞额度
中断）留下的 6 个**未提交**文件：proposal / design / tasks 与三份 delta。它们内容已相当完整，本会话
全读后**接着改、没有重写**；第一笔提交 `35ef7ad` 即「草稿 + 下面的修正」。

逐条 old → new 清单在 `E/05-corrections/corrections.md`，要点：

1. **纠正一个事实错误（最重要）**：草稿断言「M30 之后 worker 的记录落在自己 worktree 的
   `.pi/team/state/`」，并据此把挂起判定写成「绝不读主工作树的记录」。现场核对
   （`E/04-lane-state-dir/lane-state-dir.txt`）证明本仓相反：`.pi/` 被 gitignore、5 个 worktree 全部
   不带 `config.sh`，team-bg 的前三支解析都不命中 → worker 会话的作业记录/log/账本今天落在
   **主工作树**的 `.pi/team/state/bg/`（265 份 `.job` 里 **231 份**的 `cwd` 在 `.worktrees/` 下；
   今天 08:28–08:56 的 `p228-r6-*.job` 就是 dev 席位的现场）；而 smoke 的 S11 夹具把 `config.sh`
   提交进夹具仓库（`tests/team-bg-harness.mjs:56`），worktree 自带 config，那一支落 worktree 侧 ——
   **两种形状都存在**。team-notify 的 `findRoot` 走 `--git-common-dir`，本来就落主工作树：本仓今天
   两边碰巧一致，S11 形状下会分叉。修正后的规则：**按车道自己的规则解析车道的记录目录；通知侧不得
   拿自己的项目 root 顶替它**；红侧从「读主根即红」改成「读错目录即红」，场景改成两条可判定的形状
   （worktree 自带 config + 主根诱饵；显式 `TEAM_STATE_DIR` + notify root 诱饵）。
2. 把 4 处「会话本地 / session-local」措辞改成「车道自己的目录 / the lane's own state directory」。
3. **写明与任务书措辞的偏离**：任务书写例外是「作业很短、**或**结果卡住下一步且没有别的可做」，
   本设计收成**三条同时成立**（预算 + 阻塞 + 独占），理由在 design 决策 2（「作业很短」没有绝对数字
   时不可核对；「结果卡住我」单独存在就是「这步很重要所以等」的通行证）。
4. **A/B 两刀的测试计划对齐排期**：A 刀用例跑在新的独立入口 `tests/bg-ledger.sh`（不碰 S1 拥有的
   `smoke.sh`），B 刀再折回 smoke §13/§13c 并登记 section-select 映射；`tasks.md` 2.3/3.2/4.3 与
   proposal 的「测试」行同步。

## 落点与任务书头字段（请 PM 改头字段；本席位未改任务书）

任务书头写 `deltas: agent-adapters, dispatch`、`specs: agent-adapters, dispatch`；实际落点是
`background-jobs`（新能力）+ `dispatch`（ADDED）+ `notify-and-inbox`（MODIFIED）。理由（design 决策 7）：

- `agent-adapters` **不动**：它管「启动模板合同 / 首词解析 / PM 适配器 / 冻结缝」，不涉及工具文本；
  内置 Pi 启动命令（`-e` 集合与顺序）本 change 逐字节不变；
- 车道的会话侧（工具面合同、叫醒纪律、账本事件、重启留证）今天**没有规格家** —— `boundary` 只覆盖
  CLI 的 `team bg list/stop` 一侧，所以给它新能力 `background-jobs`；
- 挂起可见性的实现位在 `team-notify.ts`，正是「A turn-end notification …」这条既有 requirement 的行为，
  归 `notify-and-inbox` MODIFIED；
- 工人简报的内容合同（三态 + 车道教学 + 续跑查盘）今天门禁零断言，归 `dispatch` ADDED。

**请 PM 据此改任务书的 `deltas:` / `specs:` 头字段**（按派单纪律由 PM 改，本席位只报告）。

## Verification evidence（本阶段五条验收，全部实际跑过）

运行器 `E/run.sh`，逐条原样执行并保存完整输出与 rc（`E/01-acceptance/*.log`、`results.tsv`）。
本报告写进树之前、在 `35ef7ad` 上的结果：

| 实际命令 | 输出尾部 / rc | 原始证据 |
|---|---|---|
| `"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict` | `Totals: 16 passed, 0 failed (16 items)`；rc=0 | `E/01-acceptance/01-validate-all-strict.log` |
| `bash skills/teamsmith/tests/spec-refs.sh --check` | `judged 104 reference(s) (49 distinct) … retired 0; undeclared 0`；rc=0 | `E/01-acceptance/02-spec-refs.log` |
| `bash skills/teamsmith/tests/section-select.sh --paths docs/team/reports/E17-dev2.md` | `decision=NONE … 豁免类（docs/*）`；rc=0（写报告前文件尚不存在，报告提交后复跑见下） | `E/01-acceptance/03-section-select.log` |
| `bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"` | `files=1320 hits=0 names=ok`；rc=0 | `E/01-acceptance/04-ledger-ban.log` |
| `git diff --check` | 无输出；rc=0 | `E/01-acceptance/05-git-diff-check.log` |

报告提交后在干净树上复跑同一套（含报告本体被 spec-refs / ledger-ban 扫到）：结果见
`E/06-post-report/post-report.tsv` 与 `results.tsv` 的复跑行；若与上表不同，以复跑为准。

### 试归档投影（两棵树，均在 /tmp 副本，源树只读）

`E/02-trial-archive/{current,routing-first}.log`，检查器 `check-projection.sh`（逐项 PASS/FAIL）：

| 树 | 步骤 | 结果 |
|---|---|---|
| `/tmp/e17-trial-current` | `archive -y long-job-suspend` → `validate --all --strict` → 投影检查 | archive rc=0；validate `16 passed / 0 failed`；投影 **PASS** |
| `/tmp/e17-trial-routing-first` | `archive -y task-model-routing` → `archive -y long-job-suspend` → validate → 投影检查 | 两次 archive rc=0（routing 先落 7 个 capability：`+3/~7` dispatch 等）；validate `15 passed / 0 failed`；投影 **PASS** |

投影判据（归档后的 canonical 对照 delta）：notify 的 MODIFIED requirement 新段落 + **13 场景**
（8 基线 + 5 新增）一个不少、与 delta 文本**逐字节一致**；`background-jobs` 新 capability 生成
（Purpose + 3 requirements + 9 scenarios）；`dispatch` canonical 带上新 requirement；每个 delta 的
每个 requirement 在 canonical 里都存在且场景无丢失。两种归档顺序都绿 —— 与在途的
`task-model-routing`（其 deltas 含 `dispatch`）不冲突，因为本 change 的 dispatch 是 ADDED。

## Flip evidence（翻转证据：投影检查有牙齿；本阶段没有产品代码可翻）

绿侧 = 上面两棵树。红侧 = `E/02-trial-archive/flip.sh`（破坏只发生在 /tmp 副本里）：

```text
delta-text-mutated     rc=1    # 把 delta 的 MODIFIED 文本加一个词 → 归档
                               # FAIL archived notify requirement differs from the delta MODIFIED text
canon-scenario-dropped rc=1    # 干净归档后从 canonical 删掉一个新场景 → 单跑检查
                               # FAIL notify archived requirement lost scenarios:
                               #      An explicit state directory is the lane's directory
FLIP: PASS — both mutations went red
```

即：投影检查不是恒绿 —— 文本漂移与场景丢失都会红。

## 基线与新增场景对照（MODIFIED 不许丢场景）

- **逐字节**：`E/03-baseline-compare/modified-vs-baseline.diff` 只有 `+` 行（新增段落 + 5 个场景），
  **零删除、零改写**；`baseline-requirement.md` / `delta-modified-requirement.md` 是两侧原文。
- **基线 8 场景全部在**（`scenario-inventory.txt`）：One summary, one line；A repeated settle inside the
  dedup window is dropped；A dirty PM input box turns the knock into a queued entry；The worktree, not
  the window, names the sender；The line and the knock name the revision；One HEAD, one spelling,
  whatever Git's abbreviation settings are；A notice for an already-judged revision is stale；An idle
  seat branch stamps nothing。
- **新增 5 场景**（每个都能证伪）：A suspended turn is tagged, not alarmed；A dead or reused pid does not
  suspend；An interruption with running jobs names them；A worktree carrying its own config uses its own
  lane records；An explicit state directory is the lane's directory。
- **三个 delta 的计数**（`delta-counts.txt`）：`background-jobs` 3 requirements / 9 scenarios；
  `dispatch` 1/4；`notify-and-inbox` 1/13。

新增 requirement 的红侧思路（均写在 delta 场景里，apply 时按此做破坏回归）：

| Requirement | 红侧 |
|---|---|
| The lane's tool surface teaches suspend-and-wake as the default | 恢复旧措辞（`Harvest it with team_bg_wait before you end your turn` / `harvest every job … before ending your turn`）→ 措辞搜索用例必须红 |
| The lane's ledger makes the wait pattern countable | 删掉 `start` 行；把 `waited_s` 记成作业年龄 → 对应场景必须红 |
| A restart keeps the job's evidence but not the job table | 重启会话把旧记录收进新表，或 session_start 时清掉旧记录 → 场景必须红 |
| The worker prompt makes suspension … a third legal turn end | 任一面（提示词 / AGENTS 模板 / protocol / workflows §E2）缺第三态，或回退旧措辞 → 一致性用例必须红 |

## Decisions and deviations

- 落点偏离任务书头字段（`agent-adapters` → `background-jobs` + `notify-and-inbox`），说明见上；
- 「原地等」例外收成三条同时成立并向任务书措辞说明偏离（design 决策 2）；
- 车道记录目录的修正见「续跑与继承」第 1 条（草稿的事实错误）；
- 声称「可数」的口径：只新增 `start` / `wait` 两类行、不新增文件；旧行形状逐字节不变；
- 不新增 watchdog 待办类（挂起席位的任务本就未完成，现有条款覆盖），只加续跑先查盘的引导。

## 未解问题与未跑项（说清边界）

- **未跑**apply 阶段的产品测试、smoke、bg-ledger 新入口 —— 本阶段只提案，`tasks.md` §6 的命令是
  登记（届时才运行）；`docs/team/reports/E17-dev2.md` 的 `section-select --paths` 在写报告前返回 NONE
  （docs 豁免），报告提交后复跑仍应 NONE。
- 挂起判定的实现要复刻 team-bg 的 root 规则（或抽共享 helper）；具体落点（复制函数还是抽公共模块）
  留给 apply 决定，本提案只钉规则与红侧。
- 归因：本 change 的正确性证据是规格校验与投影；**产品价值判断（这条改动是否值得实现）不在门禁里**，
  留给 PM 与独立评审。
- 未碰其他项目、共享技能软链接与真实配置；未触发 CI、未 push、未合并、未归档。

## Suggested next steps

- PM 全文审 `openspec/changes/long-job-suspend/`，出 proposal review（ACCEPTED 之前不派 apply）；
  评审时建议重点核三处：车道记录目录的修正（E/04 现场）、例外三条与任务书措辞的偏离、A/B 两刀的
  文件边界（S1/S3 释放前只派 A 刀）；
- ACCEPTED 后请 PM 改任务书 `deltas:` / `specs:` 头字段，并冻结输入 tip；
- B 刀需等 `task-model-routing` S1（`cmd-agents.sh`、`smoke.sh`）与 S3（`templates/**`、
  `references/**`）释放对应文件后串行派单。
