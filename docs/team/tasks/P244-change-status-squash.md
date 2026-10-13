# P244 · `change status` 的「分支已并入 main」判据要认 squash 合并

task: P244
agent: dev3
phase: apply
category: infra
change: -
anchor: none (infra) — 归档前置工具的判据修正，不改产品行为
branch: task/P244-change-status-squash
deps: -

## 缺陷（PM 2026-10-13 实测）

`team change status <id>` 是归档前置的权威工具（P209 引入），它把「apply/verify 任务的分支是否已并入 main」作为 blocker 之一，判据是**分支 tip 是否为 main 的祖先**。但本项目**按纪律用 `git merge --squash` 合并**（PM 的合并方式），squash **永远不会**让分支 tip 成为祖先——所以：

- 已按流程合并并关单的任务，在 `change status` 里**永远**显示为 blocker（原文自己都写了「squash 合并不会让分支 tip 变成祖先」）；
- 于是「所有任务完成」这个信号对任何改过代码的 change 都是**恒假**，归档前置的核心判据失效（PM 只能绕过它人工判断）。

实测（PM，`team change status task-model-routing` / `pulse-key-replies`）：已合并的 P232/P235/P238 等与在飞的 P242 都落在同一条 blocker 文案里，无法区分「真的没合并」与「按纪律 squash 合并过」。

## 要求

1. **正确的判据**：对「分支已并入」给出一个在 squash 合并下也成立、且**不能假阳**的判定。可选方向（你选并给依据）：
   - 用**内容**判定：分支的改动是否已存在于 main（例如 `git diff --quiet main <branch>` 为空，或按 tree/补丁等价比较）；
   - 或用**合并回执**：PM 合并时记录的分支名 + 合并后 main 的 tip + 分支 tip + 补丁指纹，`change status` 读回执并核对（回执缺失或对不上才判 blocker）。
   **必须**保留反向：真的没合并（内容不在 main）时必须仍然报 blocker，并点名「分支 tip / main 现状」。
2. **对「已关单但分支未合并」的旧记录**：给出明确口径（例如回执缺失时按内容判定，而不是一律判 blocker）。
3. 输出可读：blocker 文案要能区分「未合并」「已按 squash 合并（有回执/内容一致）」「内容部分一致」三种。
4. **不改** `team close` 的行为（它另有一套门禁，工作正常）；只改 `change status`（以及它复用的判定函数）。
5. **红侧**（各给可跑的失败证据）：① 造一个真的没合并的分支 → 必须报 blocker；② 用 `merge --squash` 合并一个分支后 → **不再**报「未合并」blocker（其余 blocker 照旧）；③ 造一个「分支有一半改动在 main、另一半不在」的情形 → 报「部分一致」而不是通过。

## 验收（贴真实输出）

```bash
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
bash skills/teamsmith/tests/smoke.sh --select <你改动落到的段>
bash skills/teamsmith/tests/section-select.sh --check
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check && git status --short
```

注意：`section-select.sh` 与 `smoke.sh` 可能正被 P242 持有——若你交付时它已合并就从 main 起手；若未合并，先只做产品侧的改动与自己的夹具入口，并在报告里写明。

## 交付

`docs/team/reports/P244-dev3.md`（复现、判据设计依据、改动、三条红侧的前后证据、未做项）；不合并、不推送；做完 `team notify pm`，随后由未写过本任务的席位独立复验。

## 返修轮次 1（2026-10-13，独立复验 V30 判 FAIL：1 项必修 F1）

复验记录 `docs/team/reviews/V30.md`（受检 `b9b242ee`）：方向对、三种状态与两个反例都过，**但有一条必修**。

**F1（假阳，必修）**：`git diff --name-only`（默认 `core.quotePath=true`）对**非 ASCII / 含引号 / 含反斜杠**的路径会输出 **C 转义并加双引号**的串；实现把这一整串当成字面 pathspec 再 `git diff 分支 main -- …`，于是这些路径**永远匹配不到** → `still` 为空 → 判成 `merged`。V30 的现场（判据层）：

```
FAIL s11  want=unmerged  got=merged     branch-only path 从未进 main
quoted-name probe: git diff --name-only base s11 = ["\344\270\255\346\226\207.txt"]
control core.quotePath=false on s11: state=unmerged   ← 换成不转义就正常，坐实是转义问题
```

端到端后果：一个**内容从未进 main** 的 change 会被报成 `ready（无：全部任务已结束）`——正是「不能假阳」这条要求的直接违反。

**修法要求**（你选并说明依据）：用 NUL 分隔、不转义的输出（例如 `git diff --name-only -z`）并用能承受任意字节的传递方式（数组 / `xargs -0`）逐路径比对内容；**不要**用字符串拼接后当 pathspec。修完给出：

- 判据层红绿对照：含非 ASCII、含空格、含 `"`、含 `\` 的路径各一条 → 未合并/部分一致/已合并三态判定正确（改前是「假阳 merged」）；
- 端到端小现场：一个**没进 main** 的 change 必须仍显示未合并 blocker（改前显示 ready）；
- 回归：V30 已过的三态与两个反例不许回退；`smoke.sh --select 12e` 在**改前树**（`a671a162`）红、修后绿。
- 另：把 `git -c core.quotePath=false` 这种「靠调用方设置」的替代方案在报告里评一句（为什么选或不选）。

修后冻结新 tip，由 **V30 第二轮**（同一复验任务、换会话）复验；只有 PASS 才关闭 V30。
