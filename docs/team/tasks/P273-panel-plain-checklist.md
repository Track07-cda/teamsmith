# P273 · 按事实勾选 `panel-plain-language` 的清单（归档前置）

task: P273
agent: dev3
phase: apply
category: code
change: panel-plain-language
specs: panel, key-replies, memory-and-deps
deltas: -
branch: task/P273-panel-plain-checklist
deps: P266（apply 已并入 main；独立复验 V36 第三轮 PASS）

## 要做什么

`team change status panel-plain-language` 现在唯一阻塞是 **25 项未勾的清单**（`openspec/changes/panel-plain-language/tasks.md`）。请**按事实**逐项勾选：

- 只勾你确实做过并留有证据的，每行末尾补一句**证据指针**（提交号 / 报告章节 / 命令与 rc / 夹具名）。
- **不要勾 PM 或复验的项**（提案复核、独立复验、归档），留给我；也不要为了勾满而补做超范围的事。
- 某项若其实没做，**如实留空并在报告里写明缺口**。
- 清单条目与实现实际做法不一致时，把差异写清楚（照 P245 那次「实际做法」注记的写法），不要改原文。

## 边界

- 只改 `openspec/changes/panel-plain-language/tasks.md` 与 `docs/team/reports/P273-dev3.md`；产品/测试/规格一个字不动。
- 交付前 `git merge main`；不合并、不推送；做完 `team notify pm`。

## 验收

```bash
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check && git status --short
```
