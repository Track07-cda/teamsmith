# P271 · 按事实勾选 `startup-self-heal` 的清单（归档前置）

task: P271
agent: dev-bob
phase: apply
category: code
change: startup-self-heal
specs: init-skill, pm-lifecycle
deltas: -
branch: task/P271-self-heal-checklist
deps: P261（apply 已并入 main，独立复验 V35 第二轮 PASS）

## 要做什么

`team change status startup-self-heal` 现在唯一（也是归档前最后一道）阻塞是 **30 项未勾的清单**（`openspec/changes/startup-self-heal/tasks.md`）。请**按事实**逐项勾选：

- **只勾你确实做过并留有证据的**；每行末尾补一句**证据指针**（提交号 / 报告章节 / 命令与 rc / 夹具名），照 P245/P246 那次的做法。
- **不要勾 PM 或复验的项**（例如「PM 复核提案」「用户确认后归档」「独立复验」这类），留给我；也不要为了勾满而补做超出范围的事。
- 若某项**其实没做**（例如某个夹具没写、某条红侧没跑），**如实留空并在报告里写明缺口**——留空比假勾有价值。
- 你这一轮的返修（F1/F2/O1）已在 `1d0d5272` 起的三个提交里，报告第「返修轮次 1」一节有逐条证据，可直接引用。
- 清单里若有条目与实现**实际做法**不一致（例如换了夹具名、改了落点），把差异写清楚（照 P245 那次「实际做法」注记的写法），不要改原文。

## 边界

- **只改 `openspec/changes/startup-self-heal/tasks.md`** 与你的报告（`docs/team/reports/P271-dev-bob.md`）；**不许**改产品/测试/规格（清单之外一个字不动）。
- 交付前 `git merge main`（此刻 P266/P270 可能已并入）；冲突按双方保留。
- 不合并、不推送；做完 `team notify pm`。

## 验收

```bash
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check && git status --short
```
