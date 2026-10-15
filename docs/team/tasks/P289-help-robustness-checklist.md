# P289 · 按证据勾选 `help-robustness` 的清单（归档前置）

task: P289
agent: -
phase: apply
category: code
change: help-robustness
specs: help-surface
deltas: -
branch: task/P289-help-robustness-checklist
deps: P278（apply 已并入 main）、V41（独立复验 PASS；**但见 P278 记录里的席位缺陷**）

## 要做什么

`team change status help-robustness` 的归档前置是清单未勾（23 项）。请**按证据**逐项勾 `openspec/changes/help-robustness/tasks.md`：

- 每勾一项必须在**已提交的证据**里找到支撑（作者报告 `docs/team/reports/P278-verify.md`、复验记录 `docs/team/reviews/V41.md` 的小节、提交号、命令与 rc）。**找不到就留空**并写明你查了哪里。
- **不要勾 PM 与复验的项**（提案复核、独立复验、第三方补验、归档），留给我。
- 条目与实现实际做法不一致时写清差异，不改原文。**发现真缺口就如实留空并单列一节**（前几轮都是靠这一步翻出真缺口的）。
- 只动那一份 `tasks.md` 与你自己的报告；产品/测试/规格一个字不动；交付前 `git merge main`。

## 验收

```bash
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check && git status --short
```
