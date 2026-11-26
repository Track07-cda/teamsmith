---
id: P505
title: 定位任务标签看板连续按键只移动一行
agent: dev3
category: analysis
phase: opsx-explore
change: task-labels
specs: board-and-status,panel
deltas: -
branch: task/P505-task-label-keyboard-diagnosis
---

# P505 · 只定位现有任务标签候选的键盘阻塞

P497 和 V196 保持 blocked，无实施/验收放行，原证据 `docs/team/reports/V196-verify.md` / `19f9023c`、`openspec/changes/task-labels/BLOCKED.md`、`.pi/team/state/evidence/P497/round2`。先用原数据从输入发送、Ink 收取、按键处理到选中状态追一笔，不重开标签的设计，也不把整组再跑一遍。读冻结 `4cbc5bc78eeeca78cef535c727dd22379d9360c0`；只在本人隔离目录读取候选或解出必要文件，禁止动真实看板和既有失败原件。候选中三次 Up 的期望是移动三行，现只一行；对照单键逐次、同三键连续发送，先判断三次是不是都到应用、是否都按同一旧焦点处理。只有在需要区分既有缺陷与本次引入时，才对已经合并的 `862733ea` 或引入前的对应控件做同一项短对照，取得的 tty 原件、键序和坐标均留存，未观测的不推断。若环境本身有问题，说明证据，不能加长等待、用拆成单键代替连续键判据或把测试通过当产品修复。

同时只读核对标签候选与最近更新看板在哪些共用代码位置冲突，指出最小接回现行 `main` 的改动点。默认按最近更新、显式按优先级、同分按原表顺序；项目设置的标签管理另任务，不改这里的验收范围。不改候选、测试、正式要求、分支历史、会话或任何项目配置。只提交 `docs/team/reports/P505-dev3.md`（短复现用 `/var/tmp`，不写产品、不启整组选段/第三轮验收），把根因、最小修点或仍缺的证据及对齐范围给 PM。长活后台走完成通知；实际命令、退出码和 Git 差异检查留证，本地小步提交，禁止推送、合并。