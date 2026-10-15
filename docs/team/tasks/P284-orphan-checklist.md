# P284 · 按证据勾选 `orphan-visibility` 的清单（归档前置）

task: P284
agent: dev-bob
phase: apply
category: code
change: orphan-visibility
specs: seat-visibility, board-and-status, boundary
deltas: -
branch: task/P284-orphan-checklist
deps: P276（apply 已并入 main）、V42（独立复验 PASS）

## 要做什么

`team change status orphan-visibility` 的归档前置是清单未勾。请**按证据**逐项勾选 `openspec/changes/orphan-visibility/tasks.md`：

- 每勾一项必须能在**已提交的证据**里找到支撑：作者报告章节（`docs/team/reports/P276-dev3.md`）、复验记录（`docs/team/reviews/V42.md` 的对应小节）、提交号、或命令与 rc。**找不到证据就留空**，并在报告里写明「未找到 + 你查了哪里」。
- **不要勾 PM 与复验的项**（提案复核、独立复验、归档、PM 的合并门禁），留给我。
- 清单条目与实现实际做法不一致（换了夹具名、改了落点）时写清差异（照 P245「实际做法」注记的写法），不改原文。
- **发现真缺口就如实留空并单列一节**——前四轮（P271/P273/P277 等）都是靠这一步翻出真缺口的。
- **只动那一份 `tasks.md` 与你自己的报告**；产品/测试/规格一个字不动；交付前 `git merge main`。

## 验收

```bash
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check && git status --short
```
