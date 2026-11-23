---
id: P490
title: 恢复 PM 升级说明与既有检查一致的用语
agent: dev2
category: code
phase: opsx-apply
change: -
specs: init-skill#Installed team instructions separate shared rules from role procedures without losing required duties
deltas: -
branch: task/P490-upgrade-guidance-wording
---

# P490 · 只改 PM 启动模板一句开头

V186 对发布候选 `2201a79d` 的第二次自检 216/1/3：61b 的正常对照失败，才没有运行后面的 31 个故意改坏场景。子组日志未保留。PM 只读定位到一个确定不匹配：`tests/task-model-routing.sh` 的 `init-guidance-separate-gates` 要求两份升级说明都有 `separate recorded gates`；迁移说明仍有，P488 启动模板改成 `keep four steps separately recorded`。修复这个已证实的不一致，不宣称已证明它是历史运行的唯一原因。

只改 `skills/teamsmith/templates/pm-prompt.md.tmpl` 这一个开头，例如 `For a Teamsmith tool-source upgrade, keep four separate recorded gates:`，在保留明确的升级范围、四个操作和每个命令的原审批边界前提下恢复与迁移文档相同的词。不要改测试、规格、产品行为、现有项目规则、配置、版本或运行会话。作者只核写集和 `git diff --check`，由原发布验证者执行受影响的已有检查；不要跑初始化、会话、模型、完整自检或任何额外测试。提交 `docs/team/reports/P490-dev2.md`，报告精确差异、提交和实码，留本地，不推送。