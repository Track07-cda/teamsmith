# P293 · 按证据勾选 `writing-discipline` 的清单（归档前置）

task: P293
agent: verify
phase: apply
category: code
change: writing-discipline
specs: writing-discipline
deltas: -
branch: task/P293-writing-discipline-checklist
deps: P286（apply 已并入 main）、V47（两轮独立复验，第二轮 PASS）

## 要做什么

`team change status writing-discipline` 的归档前置是**清单 24 项未勾**。请**按证据**逐项勾 `openspec/changes/writing-discipline/tasks.md`：

- 每勾一项必须能在**已提交的证据**里找到支撑：作者报告 `docs/team/reports/P286-dev-bob.md` 的小节、复验记录 `docs/team/reviews/V47.md` 的小节（你刚做过那一轮，熟）、提交号、命令与 rc。**找不到就留空**并写明你查了哪里。
- **不要勾 PM 与复验的项**（提案复核、独立复验、用户确认、归档），留给我；**人读那一步**如实写成「PM 代理读（已标注）」，不要写成用户的判断。
- 条目与实现实际做法不一致时写清差异，不改原文；**发现真缺口就如实留空并单列一节**。
- 只动那一份 `tasks.md` 与你自己的报告；产品/测试/规格一个字不动；交付前 `git merge main`。

## 验收

```bash
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check && git status --short
```
