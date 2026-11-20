---
id: A14
title: 同步正式规格并收尾帮助测试精简
agent: dev3
category: code
phase: archive
change: help-perf-entry-without-measurement
specs: verification
deltas: -
branch: task/A14-archive-help-perf-entry
---

# A14 · 只同步已验证的规格

P482/V182/P483/V183 均接受关闭，实施者 dev-bob、验证者 verify；D264 依 D241 确认归档。合并执行版本 `282b9dc79dd1c1fb751e50a040f2834612ff26be`，正式 PASS 与证据 `docs/team/reviews/{P483,V183}.md`、报告 `73617359`；四项已勾。两次验证侧准备问题原件保留，不重跑或重新判断行为；真实性能测量与整套未运行，不重写 V174 历史结论。

用现有 OpenSpec 1.16 及原生 status/list/instructions 核对本仓根和 4/4。按 A13 同一做法：本人唯一 `/var/tmp` 私有普通副本先用 `openspec archive -y help-perf-entry-without-measurement` 试做，然后在本人授权任务分支原生执行一次。禁止硬链接、初始化/升级、跳过验证或同步、手写移动/拼接。写集只限五份工件原样移入日期归档目录、`openspec/specs/verification/spec.md` 的具体目标要求同步和本人报告 `docs/team/reports/A14-dev3.md`。目标外正文、标题、Purpose、其它正式规格、全部可执行文件保持逐字节不变。原生同步如果只缩减目标块的普通连续空行，依 A12 既定口径记录具体 diff；实质差异暂停并留证，不重写原规格换绿。

本地提交后验收范围只有原生命令 `openspec validate --all`（普通校验，不称全仓 strict）、`bash skills/teamsmith/tests/spec-refs.sh --check`、原有账本公开文件检查（最终报告暂存后）、`git diff --check` 与工件/规格差异核对。记录实际输出、警告及退出码。不得跑帮助、性能、smoke、真实团队或模型。分步本地提交并报告实际路径、4/4、五个工件比较及目标外字节，未授权 push/合并/发布，也不替 PM 改看板。保留试做与执行原件至 PM 通知；不碰其他人的目录。