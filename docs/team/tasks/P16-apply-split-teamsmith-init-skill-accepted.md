# P16 · apply: split-teamsmith-init-skill（提案已 ACCEPTED）

```
task:   P16
agent:  dev3
issue:  
change: split-teamsmith-init-skill
specs:  init-skill: Initialization guidance lives in a dedicated teamsmith-init skill; init-skill: The daily skill no longer carries initialization guidance; init-skill: Both descriptions route cleanly and both skills load; init-skill: One CLI, one copy of every tool file; init-skill: One version source, unchanged fingerprint scope; init-skill: Existing projects and running sessions see zero change
phase:  apply
deps:   P15          # 提案评审 ACCEPTED：docs/team/reviews/split-teamsmith-init-skill-proposal.md
status: todo
budget: 一个工作块；超出就交 PARTIAL 报告
```

> 本地模式：不 push，任务分支留在 `.worktrees/dev3`。

## Context

用户拍板直接拆（「那肯定不把CLI工具拆开，这得保持统一」）。规划产物已在主线：
`openspec/changes/split-teamsmith-init-skill/`（proposal.md / design.md / tasks.md / specs/init-skill/spec.md），
PM 评审 `docs/team/reviews/split-teamsmith-init-skill-proposal.md` = **ACCEPTED**（D2 保留：workflows.md §A 缩成指路）。

**apply 的依据是 change 目录里的 tasks.md（4 节 + 附录 A），逐条执行、逐条打勾。** 下面是 PM 加的边界与提醒，不改变 tasks.md 内容：

- **版本号**：本 change 随下次发布 bump——tasks 4.1 的具体号定为 **1.40.0**（1.39.0 昨天已发）。本任务的提交里就改三处（common.sh / 两个 SKILL.md 的 metadata.version）+ CHANGELOG 顶部加 v1.40.0 条目。
- **M23 已合并**：smoke.sh 现在有私有 socket（TMUX_TMPDIR）+ 全量门禁互斥锁——你在重排 smoke 断言时**不许**碰这两个机制；遇到冲突以保留 M23 行为为准。
- **翻转证据是硬要求**（tasks 3.1/3.2/3.4/3.5/3.6 每条都有「改坏→红→还原」），每条都要在报告里给输出。
- **安装软链（tasks 4.2）由 PM 执行**，你只需在报告里给出命令与预期 `readlink` 输出；不要动 `~/.agents/`。
- smoke 重排面大（~130 处），按 design D6 的逐类清单走；漏一处门禁当场红，属于可观测，不用怕，但要修到绿。

## Deliverables

按 `openspec/changes/split-teamsmith-init-skill/tasks.md` 的 1.1–4.4；报告 `docs/team/reports/P16-dev3.md`。

## Boundaries (do not do)

- 不动 `~/.agents/`；不动 `.pi/team/`；不创建第二个 CLI；不复制 references/templates 到两侧。
- 不动 M23 的私有 socket / 互斥锁机制；不动 pulse/派单/复验/合并的任何行为。
- 不改 `openspec/specs/`（delta 已在 change 里，归档是 PM 的事）。

## Acceptance (must actually be run; put the output in the report)

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh
# + tasks.md 里每条的「验证」命令；翻转证据逐条贴输出尾部
```

## Report

`docs/team/reports/P16-dev3.md`（格式见 `templates/report.md.tmpl`）：tasks 逐项打勾、门禁输出尾部、翻转证据、未验证项/风险、与提案的出入（如有）。
