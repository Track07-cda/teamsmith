# P307 · 按事实勾选 `tmux-identity-scope` 的清单（作者侧）

task: P307
agent: dev2
phase: apply
category: code
change: tmux-identity-scope
specs: pm-lifecycle, verification
deltas: -
branch: task/P307-tmux-identity-checklist
deps: P274（写侧，已并入）、P304（读侧，已并入）、V48 + V56（两轮独立复验 PASS）

## 要做什么

`team change status tmux-identity-scope` 的归档前置是**清单 25 项未勾**。按事实勾 `openspec/changes/tmux-identity-scope/tasks.md`：

- **你自己做的那些**（§0 冻结与基线、§1 写侧、§2 读侧、§3 隔离、§4 验收）——每项末尾追加 `· P307 按事实勾：<证据>`（提交号 / 报告小节 / 命令与 rc），**原文一字不动**。
- **PM 与复验的项（§5）留空**，由我勾（引用 V48/V56）。
- **找不到证据的项留空**并单列一节「未勾项与原因」——这道账前七次翻出过真东西（含一条从未真的往回找过的夹具腿）。
- 只动那一份 `tasks.md` 与你自己的报告；产品/测试/规格一个字不动。

## 验收

```bash
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check && git status --short
```
