---
id: A8
title: 归档模型路由三处测试精简
agent: dev3
category: code
phase: archive
change: routing-argv-check-slimming
specs: verification
anchor: openspec/changes/routing-argv-check-slimming/proposal.md
deltas: -
branch: task/A8-archive-routing-slimming
---

# A8 · 仅同步已验证规格并归档

## 前置与授权

- 实现dev-bob，归档由未实现本变更的你执行；P457/V163已关闭。
- 合并f5836f23，同一dev3最终报告b6ae8a5c：独立短反例及唯一完整61b原件已核，合并后适用字节相同、实际Bash/NUL 10/0；Completeness8/8、CRITICAL0、WARNING1为既有全项目strict长文本。
- PM已在reviews/P457.md依D241既有用户授权作出归档决定，不另等用户确认；该W1须如实记录，不扩大为全仓规格修复。
- tasks3.3已据最终证据勾选，原“尚未授权”前言已随状态校正；无实施或真实团队状态操作授权。
- 0.4.7已正式发布，标签fdd3247a及npm原包不变。当前全体变化在开发版，不重新发布。

## 执行及边界

1. 读本change规划、verification正式规格与自身线程，按现有archive skill检查root/status/tasks/sync。`team change status routing-argv-check-slimming`仅能剩A8自己；其它阻塞停止，不强行忽略。
2. 先在/var/tmp唯一私有副本运行本机OpenSpec1.16的原生 `openspec archive -y routing-argv-check-slimming` 并核实际结果，再在自己的任务分支同样原生同步/归档。选项的同步选择已由PM授权为同步已接受delta并归档；不做手写替代归档，不改设计、delta含义或既有Purpose。
3. 写集仅该change移动到日期archive、对应verification正式规格的已接受delta、必要索引引用更新及自己的报告。若原生同步超出已接受delta，报告BLOCKED，不顺手修改别的规格。
4. 在自己的归档分支执行适用短检查（openspec若不在PATH，沿用V163已确认的Bun/CLI路径，不安装新依赖）：

```bash
openspec validate --all
bash skills/teamsmith/tests/spec-refs.sh --check
bash skills/teamsmith/tests/section-select.sh --check
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check
```

不跑全项目strict或61b/full/meta/夜间/安装/性能，不因文档、勾选、归档再启动长矩阵。
5. 核归档tasks全勾、正式verification的五个新场景已同步、非delta内容保持；记录原生输出、实际改变文件及W1、未重跑范围。只删除自己这次具体临时根。
6. 报告写 `docs/team/reports/A8-dev3.md`，小步提交并通知PM，不合并、推送、创建/移动tag或发布npm。
