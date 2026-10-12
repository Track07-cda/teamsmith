# P236 · long-job-suspend 返工：挂起判定必须按作业的归属范围（不是「项目里有活作业就都算挂起」）

task: P236
agent: dev-bob
phase: apply
category: code
change: long-job-suspend
specs: notify-and-inbox
deltas: notify-and-inbox
branch: task/P236-suspend-owner-scope
deps: P230（A 刀已并入 main）；V20（A 刀独立复验 PASS）

## 缺陷（PM 2026-10-12 在真实运行里发现）

A 刀的挂起判定读的是**项目 state 目录里的活作业**，没有把作业与「结束回合的那个会话」对上，于是：

- `dev` 席位在自己的工作树里起了 `p235-acceptance2`（`.job` 记录里 `cwd=…/.worktrees/dev`）；
- `dev2` 席位（任务 P232、工作树 `.worktrees/dev2`、当时没有任何自己的作业）回合结束时，收件箱发出的是
  `[auto·interrupted] agent:dev2 · P232 · … · awaiting=p235-acceptance2` —— **把别人的作业算成了自己挂起**。

也就是说：只要项目里任何一个席位在做长作业，其他席位每次结束回合都会被打上挂起（或带着 `awaiting=`）的标签。这既污染 `awaiting=` 的可信度，也让「挂起 vs 中断」这个判据（A 刀的主要价值）再次失真。

## 要求

1. **按归属判定**：`team-notify.ts` 的挂起判定只把**属于本会话**的活作业算数。现成可用且已在 `.job` 记录里的字段是 `cwd=`（作业启动时的工作目录，也正是拥有它的那个席位的工作树）——以「作业 `cwd` 与本会话的工作树/cwd 相同」为归属判据（路径需按真实路径解析，避免软链与尾斜杠差异）。
2. **fail-closed**：记录缺 `cwd`、不可读、路径解析失败、或存在歧义时，一律**不判挂起**（退回原有非挂起形状），不得猜测。
3. **不改 A 刀已通过的判据**：`awaiting=` 与 `[auto·suspended]` 的其它语义、`uncommitted=` 保留、完成/未完成两条分支、以及 `start`/`wait` 两类账本行都不许回退。
4. **测试**（写进 `tests/bg-ledger.sh` 的 `suspend-shape` 组或新增 `owner-scope` 组，并在 `smoke.sh` 里按既有方式登记）：两个席位各有自己的活作业时，各自只认自己的 id；只有一个席位有作业时，另一个席位**不得**出现 `awaiting=`/`suspended`；缺 `cwd` 的畸形记录不判挂起。**红侧**：把归属判据删掉（退回「项目里有活作业即算」）→ 对应用例必须红；还原后绿。

## 验收

```bash
bash skills/teamsmith/tests/bg-ledger.sh --select wording,ledger,suspend-shape,owner-scope,flip
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
bash skills/teamsmith/tests/section-select.sh --paths skills/teamsmith/extension/team-notify.ts skills/teamsmith/tests/bg-ledger.sh
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check && git status --short
```

## 边界与交付

只碰 `extension/team-notify.ts`、`tests/bg-ledger*.{sh,mjs}` 与门禁登记；不碰派单/路由/提示词（那属 routing S3）。报告 `docs/team/reports/P236-dev-bob.md`，证据包按 D94 放仓外；不合并、不推送；做完 `team notify pm`，再由**未写过本任务**的席位独立复验（A 刀已并入 main，这次返工也要并入才收口）。
