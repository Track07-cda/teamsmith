# P295 · 按证据勾选 `seat-interrupt-entry` 的清单（归档前置）

task: P295
agent: dev2
phase: apply
category: code
change: seat-interrupt-entry
specs: boundary
deltas: -
branch: task/P295-seat-interrupt-checklist
deps: P292（apply 已并入 main）、V49（独立复验 PASS）

## 要做什么

`team change status seat-interrupt-entry` 的归档前置是**清单 20 项未勾**。请**按证据**逐项勾 `openspec/changes/seat-interrupt-entry/tasks.md`：

- 每勾一项必须能在**已提交的证据**里找到支撑：作者报告 `docs/team/reports/P292-dev3.md` 的小节、复验记录 `docs/team/reviews/V49.md` 的小节、提交号、命令与 rc。**找不到就留空**并写明你查了哪里。
- **不要勾 PM 与复验的项**（提案复核、独立复验、归档），留给我。
- 条目与实现实际做法不一致时写清差异，不改原文；**发现真缺口就如实留空并单列一节**（前几轮都是靠这一步翻出真缺口的）。
- 只动那一份 `tasks.md` 与你自己的报告；产品/测试/规格一个字不动；交付前 `git merge main`。

## 验收

```bash
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check && git status --short
```
