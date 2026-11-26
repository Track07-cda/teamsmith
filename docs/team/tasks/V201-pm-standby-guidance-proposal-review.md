---
id: V201
title: 独立审阅 PM 待命指令修订方案
agent: verify
deps: P504
category: verify
phase: opsx-verify
change: clarify-pm-standby-guidance
specs: init-skill
deltas: -
branch: task/V201-pm-standby-guidance-proposal-review
---

# V201 · 只审待命指令的可执行措辞与授权边界

独立固定 `6c7675d24291d77b418ed1312cd4224b25898864`，只读 `/var/tmp/p508-review-6c7675d2.Qpp3h2`。作者 dev-bob。读 AGENTS、本人线程、归属、D270、P504/P508 和固定方案。只写本人 `docs/team/reports/V201-verify.md`，给 ACCEPTED 或最小具体修订。

- 对 `AGENTS.section.md.tmpl`、PM 开场头尾、原结束情况、生成 PROTOCOL 和设计列的外部引用逐项比对。确保只有生成 AGENTS 定义完整规则：新默认说明在确无可推进工作且没有在等运行/验证/自动返回结果时允许进入而不用重复请示；项目自己要求人工决定依旧成立；空看板或回合结束不够。仅等人的例子不能在仍有自动结果时放行。不能因此允许 PM 自行关闭待命；普通 Pulse、人工恢复及已有实际定时提醒唤醒例外不变。核文字是否会被误读成对运行中的 PM、已有项目、批量修改或重启授权。
- 只审方案列的最小写集：纯人工命令仍可照做、不损坏链接或将 tool-source 升级和日常授权混写，不损坏现有逐字匹配及三种结束方式。对照 `init-skill` 原条文，保留先前自主规则场景真正关心的行为，不能因其过去的具体文件数限制而借本次改动减检查。不给项目做升级、刷新或新测试；没有必要的文字改动可删。
- 在固定检出仅 `PATH="$HOME/.bun/bin:$PATH" TMPDIR=/var/tmp CI=1 OPENSPEC_TELEMETRY=0 openspec validate clarify-pm-standby-guidance --type change --strict --no-interactive` 一次，保留退出码、实际内容核对和 Git 差异检查。只本地提交（V201，`Agent: verify`）。不跑模型、读取测试、渲染、真实会话、产品或构建，不改候选，不推送/合并。保留 V196 的原任务分支、固定证据和会话数据，本单不涉及标签。

## R1 定点复看（保留上轮其他结论）

修订版 `defb5f1b847202051e9302253aec770f56f15c92`，只读 `/var/tmp/p508-review-defb5f1b.Z3zmQ3`。比较 `6c7675d2..defb5f1b`，只核指令漏项：写集、实施清单和原文字审阅场景必须对应 `common.sh` 的 `team_nudge`，仅删 `digest 看详情` 后的待命指令和唤醒承诺；前缀、摘要、语言、计数、发送、队列、重复合并和所有待命/定时提醒行为不变。只跑相同 change strict 和差异检查，不重审已过项，不改脚本、不新增测试。原报告保留 R1 和回执，加定点结论。