# P277 · 四条已合并变更的清单按证据勾选（归档前置）

task: P277
agent: verify
phase: apply
category: code
change: -
anchor: none (infra) — 账本记账，不改产品
deltas: -
branch: task/P277-archive-checklist-sweep
deps: cli-help（P260/V38）、panel-preview-and-compose（P249/V33）、pm-reply-discipline（P267/V37）、turn-notice-merge（P251/V34）——四条都已并入 main 并通过独立复验

## 要做什么

这四条变更的代码都已合并、独立复验通过，**唯一剩下的归档前置是清单未勾**（分别 38 / 4 / 5 / 23 项）。请**按证据**勾选：

- **判据**：每勾一项，必须能在**已提交的证据**里找到支撑——作者的交付报告章节、提交号、复验记录的对应小节、或命令与 rc。**找不到证据就留空**，并在报告里写「未找到证据 + 你查了哪里」。
- **不要勾 PM 与复验的项**（提案复核、独立复验、归档、PM 的全量门禁），那些留给我；也**不要为了勾满而补做超范围的事**。
- **不许改产品/测试/规格**：只改四条变更各自的 `openspec/changes/<id>/tasks.md` 与你的报告。
- **你已经做过其中一条的复验**（V39 是另一条任务的复验，与本任务无关；本任务不做任何验证跑，只做记账），所以对 `turn-notice-merge` 那条你**没有**独立复验记录可用——它的证据来源是 `docs/team/reviews/V34.md` 与作者报告，照引用即可。
- **清单条目与实现实际做法不一致**（换了夹具名、改了落点）时，把差异写清楚（照 P245「实际做法」注记的写法），不要改原文。
- **发现真缺口就如实留空并单独列一节**：例如「某项要求文档改了但文档没改」这类。P271 与 P273 两轮就是靠这一步翻出了两处真缺口（一处文档说假话、一处 apply 没冻结改动前基线）。

## 交付

- 四条 `tasks.md` 的勾选（每行带证据指针）；
- `docs/team/reports/P277-verify.md`：逐条清单表（勾了/留空 + 证据 + 你查了哪里）、**缺口单列一节**、以及一份「这四条变更现在的归档前置状态」小结（哪条已齐、哪条还缺什么）。

## 边界

- 只动那四个 `tasks.md` 与你自己的报告；不碰 main 上的其他文件；不合并、不推送；做完 `team notify pm`。
- 交付前 `git merge main`。

## 验收

```bash
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check && git status --short
```
