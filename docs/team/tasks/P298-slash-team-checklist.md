# P298 · 按证据勾选 `slash-team` 的清单（归档前置）

task: P298
agent: dev2
phase: apply
category: code
change: slash-team
specs: agent-adapters, boundary, init-skill
deltas: -
branch: task/P298-slash-team-checklist
deps: P270（apply 已并入 main）、V50（独立复验 PASS）

## 要做什么

`team change status slash-team` 的归档前置是**清单 30 项未勾**。请**按证据**逐项勾 `openspec/changes/slash-team/tasks.md`：

- 每勾一项必须能在**已提交的证据**里找到支撑：作者报告 `docs/team/reports/P270-dev.md` 的小节、复验记录 `docs/team/reviews/V50.md` 的小节（**含段 42 两侧对照与四次负载读数**）、提交号、命令与 rc。**找不到就留空**并写明你查了哪里。
- **不要勾 PM 与复验的项**（提案复核、独立复验、归档），留给我。
- 条目与实现实际做法不一致时写清差异，不改原文；**发现真缺口就如实留空并单列一节**（这条账最近翻出过五处真东西，其中一处是主分支上的活红）。
- 只动那一份 `tasks.md` 与你自己的报告；产品/测试/规格一个字不动；交付前 `git merge main`。
- 记账一条：段 42 的 9 条红**已知**是「夹具钉住旧版 Pi 帧」造成的环境漂移（`docs/team/DECISIONS.md` D194，另有 P297 处理），清单里若遇到它，**按已知环境红记**并指向 D194，不要当成待修项重复立案。

## 验收

```bash
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check && git status --short
```
