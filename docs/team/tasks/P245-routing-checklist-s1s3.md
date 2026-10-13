# P245 · 路由变更清单：勾选 S1（§1–§5）与 S3（§7）两段

task: P245
agent: dev
phase: apply
category: infra
change: task-model-routing
specs: dispatch
deltas: -
branch: task/P245-routing-checklist-s1s3
deps: P228（S1 apply）、P235（S3 apply）——两段都已并入 main

## 背景

`openspec/changes/task-model-routing/tasks.md` 的清单**整份未勾**（27 项），而 `team change status` 把「清单未勾完」列为归档前 blocker。按本项目纪律，**清单由做过该段工作的人按事实勾选，PM 不代勾**。你是 S1（§1–§5）与 S3（§7）两段的作者。

## 要做的事

在 `openspec/changes/task-model-routing/tasks.md` 里，把你**确实做过**的项打勾，每行在末尾补一个简短证据指针（提交 sha / 报告 §/测试组名 / 记录路径）。规则：

1. **按事实**：做过就勾并给指针；**与原文写法不同但目的达成**（例如交付方式、切片顺序、实现手段变化）→ 勾上并在该行注明「实际做法：…」；**确实没做** → 留空并在报告里写明为什么。
2. **属于别的阶段/别人的项不要勾**：§6 是 S2（另一位作者）、§8 是 PM/独立验证阶段——留给它们。
3. 若发现清单里某一项要求的东西**其实没做或做得不完整**，那是重要发现：留空 + 在报告里点名（这会挡住归档，正是它的用途）。
4. 只改这一个文件（外加你的报告）；不要动产品代码、不要动 `openspec/changes/pulse-key-replies/`、不要动 `section-*.tsv`。

## 已有证据（可直接引用，但请自己核一遍再引）

- S1：提交在 main 的历史里（`git log --grep P228`）、报告 `docs/team/reports/P228-dev.md`、独立复验 `docs/team/reviews/V19.md`（六轮）、门禁段 `§61` 的 routing 组（`tests/task-model-routing.sh --select <group>`）。
- S3：`git log --grep P235`、报告 `docs/team/reports/P235-dev.md`、独立复验 `docs/team/reviews/V23.md`。

## 验收（贴真实输出）

```bash
bash skills/teamsmith/scripts/team change status task-model-routing   # 清单项数应显著下降
git diff --check && git status --short
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
```

## 交付

`docs/team/reports/P245-dev.md`（勾了哪些、注明「实际做法」的有哪些、留空了哪些及原因）；不合并、不推送；做完 `team notify pm`。PM 合并后做 §8（PM/验证阶段）的勾选与归档。
