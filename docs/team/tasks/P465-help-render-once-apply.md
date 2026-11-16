---
id: P465
title: 删除帮助入口比较的第二次相同页面生成
agent: dev
category: code
phase: opsx-apply
change: help-route-render-once
specs: verification
deltas: -
branch: task/P465-help-render-once-apply
---

# P465 · 只实施已接受的单文件替换

正式授权为 `docs/team/reviews/help-route-render-once-proposal.md` ACCEPTED；P462修订78fef968，V168独立d38f9746已关闭唯一R1。按apply skill读取原生change/context及proposal/design/delta/tasks，不重做设计。你不是提案者，实际行为验收之后交另一席位；本次不跑行为。

## Boundaries / 写入授权

- `skills/teamsmith/tests/help-surface.sh`：仅check_route的单命令比较、正常循环和同文件最小实际共用函数，按已接受design Decisions 1–3实现。
- `openspec/changes/help-route-render-once/tasks.md`：只在实际静态完成后勾1.1/1.2；2.1/2.2保留未勾，不能提前代验证者勾。
- 自己的 `docs/team/reports/P465-dev.md`。

其它产品、tests、CI、正式spec及本change proposal/design/delta/元数据均只读；现有OWNERSHIP的tests归dev及change当前apply owner规则适用。不要因发现旧问题扩大修改；source-only开关、比较旁路、通用提取/变异框架或新的额度/权限/超时/缓存均不授权。保持page/manifest/其它帮助组/其它route块、原finding/最终出口、smoke51消费者和原成功断言不变。当前47命令这一循环4N→3N，不是整个route只有141次。

## 本轮只做静态

真实行为批次由非作者统一跑一次，你不要预跑正常route、短坏样本、完整help/locale/routes/51、smoke真实段、全量/FAST/meta/61b/夜间/真实模型/性能/安装。不要先写一次性行为驱动；实现和静态完成即冻结交付，别为了交报告重跑已完成检查。

实际执行：`bash -n skills/teamsmith/tests/help-surface.sh`；本change的OpenSpec1.16严格结构；`spec-refs.sh --check`；`section-select.sh --paths skills/teamsmith/tests/help-surface.sh`仅静态计划（不执行其中的段）。核实际写集/调用账及page/manifest/其它组/51消费原文同一性。报告暂存后ledger-ban（主git公共目录名单）及两种diff-check。较慢批次后台启动后结束回合，不在回合内等待；报告真实命令/rc，不能把计划写成已执行。

短反例/真实调用点和最终退出的要求以已接受design为准；向验证者交清实际函数名、正常循环及最终出口位置，不给第二套比较答案。旧帮助日志/局部成功/全轮rc1和V167差异消费边界已经写在design，不为凑新全绿而跑旧组。原始日志/快照保留自己本地具体根，报告引用hash/必要尾部，不git add -f，不把运行原件放回仓库。

小步提交Conventional Commits含P465和Agent: dev，原分支保持本地。不merge/push/archive/tag/npm、不改真实团队/提醒/standby或主检出。报告先给实际退休调用/改动与静态结论、未验行为和下一步，不能宣称已提速/行为通过/可归档。非作者将另在PM准备的独立固定检出执行一次正常route和必要短坏腿，合并后只同一性及短补验。
