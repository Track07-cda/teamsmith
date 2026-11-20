---
id: A15
title: 同步两份提醒测试的管理要求并收尾
agent: dev3
category: code
phase: archive
change: reminder-test-temp-root-ownership
specs: verification
deltas: -
branch: task/A15-archive-reminder-test-temp-roots
---

# A15 · 仅同步已独立验证的规格

D265 按 D241 授权，P485/V184/P486/V185 已接受，实施 dev-bob、验证 verify；独立合并版 `191e80974eca1a633f7affd9d66bea110d2384cb`、报告 `327cab87`、`docs/team/reviews/{P486,V185}.md`。清单 7/7；前两轮失败和未验范围保留。不要再运行行为、实际队列、清扫、性能、完整测试或模型。

用现有 OpenSpec 1.16 的 list/status/instructions 核仓根、7/7、仅 `verification` 一项新增要求。按 A14 做法，先在本人独有 `/var/tmp` 普通副本中试做原生 `openspec archive -y reminder-test-temp-root-ownership`，再在本人任务分支实际执行一次。不使用硬链接、skip 选项、手工合并/移动或升级。写集仅五份工件原样移动至日期归档目录、`openspec/specs/verification/spec.md` 增加目标要求和本席位报告。核试做与实际相同、需求及场景顺序/内容和全部目标外正文（含标题、Purpose、原通用临时目录要求）、所有可执行字节不变。仅连接处必要空行按原规记录，出现实质差异则暂停留证，不手改规格来换通过。

验收仅执行 `openspec validate --all`（普通结构，记录真实警告）、`bash skills/teamsmith/tests/spec-refs.sh --check`、账本发布检查和 `git diff --check`，外加工件/规格差异核对。报告 `docs/team/reports/A15-dev3.md` 写命令、输出、rc、7/7、存放路径与未执行范围。本地小步提交，不推送、合并或改看板。保留自己这轮试做和命令原件等 PM 接受，不清理任何其他人的目录。