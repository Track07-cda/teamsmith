---
id: A13
title: 同步规格并收尾项目设置精简
agent: dev2
category: code
phase: archive
change: pulse-project-settings-simplify
specs: panel, memory-and-deps, verification
deltas: -
branch: task/A13-archive-project-settings-simplify
---

# A13 · 只收尾已独立验收的设置变更

你未实施本change（实现者dev，独立验证者dev3）。P470/V175/P471/V177均已接受关闭；D262依据用户D241的授权确认这次归档，不再逐项等人类确认。验证者最终c03a27051e34，正式`reviews/P471.md`绑定merged967da9843ed46c884bcabae29dea5e1a850954e9，执行者dev3；原生9/9、本change无未解决CRITICAL/待返修WARNING。候选组合证据及21秒merged短接入已通过，archive不重复它们。

边界先读明白：D261四个既有OutboxListBlock TS2339仍是完整typecheck FAIL/rc2；原177/16、55/2及临时cut失败原件保留，最终PASS不是抹去这些记录或全仓全绿。完整计时V174也没有改判。此单不修编译、不改任何产品或测试、不操作真实Pulse/配置/提醒/待命、不发布新版。

## 执行与写集

1. 先读AGENTS、本人线程、OWNERSHIP、archive/sync skills、本change七个工件及三份目标正式spec。沿用OpenSpec1.16原生list/status/instructions核自己的根/9of9/实际planningHome与artifactPaths；archive guidance仅advisory，specs规则快照按现有流程读取一次，适用规则不抄进正文。明确只选`pulse-project-settings-simplify`；`team change status`只有A13自身未完成属预期，任何其他未完成项点名BLOCKED。不安装/升级/初始化新OpenSpec根。
2. 按既有最短路径，在本人唯一/var/tmp普通独立副本先试原生`openspec archive -y pulse-project-settings-simplify`，读完整输出和生成spec；试做通过再在本人稳定任务分支实际原生执行一次。不得hardlink、手写移动/合并、跳同步/验证或造比较框架。普通Git差异、七工件逐文件核对、目标需求/场景块及目标外正文比较足够。
3. 唯一写集：本change七工件（含.openspec.yaml）整体原样移入原生日历archive；正式`openspec/specs/panel/spec.md`、`memory-and-deps/spec.md`、`verification/spec.md`仅同步已接受delta；本人`docs/team/reports/A13-dev2.md`。panel四REMOVED、三ADDED、三MODIFIED，另两spec各一MODIFIED；改动范围只按已验delta，不重新起草正文。三Purpose/原标题及未点名需求/场景保持不变，不留delta-style headers，不写其它change或账本。临时spec写权已授，交付后归还PM。
4. 如果原生同步只把普通段落的连续空行减少为单空行，保留具体diff并记录格式变化即可，不因它另开返修，也不加normalize或ignore-whitespace过滤器。需求/场景的内容与顺序、目标外正文不许有实质变化；其它差异保留现场并BLOCKED，不能手修已验delta/Purpose去换绿。
5. 真正归档后在本人任务分支各执行一次以下短检查，保存实际命令/stdout/stderr/rc。慢批次用team_bg_run后结束回合，正常唤醒再收，不回合内等/轮询。

```sh
export PATH="$HOME/.bun/bin:$PATH" TMPDIR=/var/tmp CI=1 OPENSPEC_TELEMETRY=0
openspec validate --all
bash skills/teamsmith/tests/spec-refs.sh --check
# 最终报告暂存后，仅沿用项目既有名单路径，不读取名单正文。
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check
git diff --cached --check
```

全仓沿用非strict，不称全仓strict已过；native提示按事实保留。版本、平台和源盘点未变，复用原回执，不重复。不得运行UI/CLI用例、settings/policy/flip/快照、完整类型检查/build/strings、smoke/FAST/meta/夜间、真实Pi/模型、计时或安装，不把归档当新产品验证。

## 交付

报告先回答真实归档路径/原根/9of9、七工件原样及三正式spec与delta一致、其余正文和全部可执行字节不变，再列真实短检查和格式差异。保留D261类型失败及组合验收的边界，不能将旧失败改写成已重新运行全绿。报告只指向已有V177完整评估，不复制一份新设计或需求清单。

每个可核步骤及时小提交，Conventional Commits含A13和`Agent: dev2`；分支仅本地交付，不push/merge/tag/npm、不替PM勾板或写接受。原始日志不git add -f。自己的试做/记录原件先留给PM收存，未通知前不删本次试做根；不得清理P471/V177或其他人的任何目录。
