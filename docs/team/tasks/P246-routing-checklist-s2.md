# P246 · 路由变更清单：勾选 S2（§6 面板段）

task: P246
agent: dev2
phase: apply
category: infra
change: task-model-routing
specs: panel
deltas: -
branch: task/P246-routing-checklist-s2
deps: P232（S2 apply，已并入 main；独立复验 V21 PASS）

## 背景与要求

同 P245（见 `docs/team/tasks/P245-routing-checklist-s1s3.md` 的背景说明）：你是 S2（§6）的作者，请在 `openspec/changes/task-model-routing/tasks.md` 里把 §6.1–§6.4 中**你确实做过**的项打勾并补证据指针（提交 sha / 报告 §/测试组名）。

- 按事实勾；**实际做法与原文不同**（例如共享 UI 所有权的取得方式、夹具适配的落点）→ 勾上并注明「实际做法：…」；
- 确实没做或做不完整的 → 留空 + 在报告里点名（这会挡住归档，正是它的用途）；
- 不要勾 §1–§5、§7、§8（别的阶段/作者）；只改这一个文件 + 你的报告。

证据可引用：`git log --grep P232`、报告 `docs/team/reports/P232-dev2.md`、独立复验 `docs/team/reviews/V21.md`、门禁里的 p21/choices 组。

## 验收（贴真实输出）

```bash
bash skills/teamsmith/scripts/team change status task-model-routing
git diff --check && git status --short
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
```

## 交付

`docs/team/reports/P246-dev2.md`；不合并、不推送；做完 `team notify pm`。
