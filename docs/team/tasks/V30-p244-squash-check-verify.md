# V30 · P244（`change status` 认 squash 合并）独立复验

task: V30
agent: verify
phase: verify
category: verify
change: -
anchor: none (infra) — 复验归档前置工具的判据修正
deltas: -
branch: task/V30-p244-verify
deps: P244（apply 已交付，冻结 tip 见派单消息）

## 复验对象

P244 要让 `team change status` 在**按纪律用 `git merge --squash` 的项目**里不再把「已合并」报成 blocker。被检树：PM 冻结的独立 clone（tip 见派单消息）。

作者自报：`§12e` 夹具在改前树（`a671a162`）上 `✓30 ✗12`（红），修后绿；不等价请自己复跑。

## 必须自己做的（不许只复跑作者脚本）

1. **三种状态各造一次现场**（用**你自己的** scratch 仓库，不借作者的夹具）：
   - 真的没合并的分支 → `change status` 必须报「未合并」blocker，并点名分支 tip 与 main 现状；
   - 用 `merge --squash` 把该分支合并（内容进了 main、分支 tip 不是祖先）→ **不再**报「未合并」；
   - 「部分一致」：分支有两笔提交，只把其中一笔的内容放进 main → 必须报**部分一致**（不是通过、也不是笼统的未合并）。
2. **不许假阳**：造一个「分支的两笔改动都已在 main，但分支上还有一笔**从未合并**的新改动」→ 必须仍报未合并（或部分一致）；再确认**内容等价**的判据不是「文件路径出现过」这种弱判据（例如改一个**同名文件的不同内容**，必须被判为不一致）。
3. **回执/内容两条路都要有定论**：作者的实现选了哪条（或两条并用）？在缺少回执的旧记录上表现如何？（报告里写清口径与证据。）
4. **不改既有语义**：`team close` 的门禁行为、`team review` 的判定、`digest` 的「待收尾」列都不得被这次改动改变（抽两条验证）。
5. **§12e 的红绿自证**：在候选树上跑作者声称的段（`smoke.sh --select 12e`），并把改前树（`a671a162`）的同一命令结果找出来对照；若你要声称某条红是既有红，必须用**同一条命令**对照 **v0.1.2**。
6. **容器纪律**：门禁跑在钉死容器 + 干净独立 clone；先看 `/tmp` 余量。
7. **对 PM 的实际影响要实测**：把候选树装到你的 scratch 项目里（或在候选 clone 里跑 `team --root <scratch> change status <id>`），对一个**真的按 squash 合并过**的变更（例如你的 scratch 里自造）确认「分支已并入」不再列为 blocker，而对未合并的仍列。

## 交付

`docs/team/reviews/V30.md`（抬头含机器可读的 `判定: **PASS**` / `判定: **FAIL**` 行；逐条命令 + rc + 证据路径；写明运行模型）；证据包按 D94 放仓外 `pm-skills-ledger/team/reports/V30-verify/`；不改候选、不合并、不推送；结论按协议通知 PM。
