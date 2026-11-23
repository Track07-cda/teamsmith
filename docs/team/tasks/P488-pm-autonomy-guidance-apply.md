---
id: P488
title: 落地默认 PM 自行推进规则
agent: dev-bob
category: code
phase: opsx-apply
change: pm-autonomy-guidance
specs: init-skill
deltas: -
branch: task/P488-pm-autonomy-guidance-apply
---

# P488 · 只改三份提示文字

按 `docs/team/reviews/pm-autonomy-guidance-proposal.md` 的 ACCEPTED 与固定方案 `f3d8f015`，读自身线程、归属、OpenSpec apply 输出及当前 change 工件，落任务 1.1–1.2。只写 `skills/teamsmith/templates/AGENTS.section.md.tmpl`、`skills/teamsmith/templates/pm-prompt.md.tmpl`、`skills/teamsmith/SKILL.md` 中已定位的文字，以及本人报告；仅勾 `tasks.md` 的 1.x。2.1 由非作者独立审阅，不能代勾。

默认 `AGENTS.md` 模板的角色表后写全规则；其它两份只短指向它、将逐命令授权限定在工具源升级的四项操作，不削弱本地授权、独立复核、刷新说明。原文明确 `--yes` 表达授权而非授权来源。保留只给方案不实施的例子边界。不得改现有项目 `AGENTS.md`、执行初始化/刷新或重启、改生成器/读取/模型/权限/测试/版本或推送。不要顺带改非授权话题，包括其它测试说明。

仅核写集、`git diff --check` 并按 OpenSpec 查询任务进度；不渲染，不启动新会话，不跑模型、读取行为或程序测试。提交精确候选、实际差异回执和未执行范围到 `docs/team/reports/P488-dev-bob.md`。交付即冻结。