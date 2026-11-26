---
id: V202
title: 独立验证看板连续方向键逐步移动
agent: verify
deps: P505
category: verify
phase: verify
change: -
specs: panel#The board page is a kanban over the board's states
deltas: -
branch: task/V202-panel-board-batched-keys-verify
---

# V202 · 只验现行看板连续按键的修复

候选 `f6182e925c5480e41e5d403d906c6ce6a3cf2500`，独立检出 `/var/tmp/p509-review-f6182e92.d2TU2D`，作者 dev3。等 V201 审阅结束再开本单；V196 的任务、会话和原件保持暂停，不修改或恢复。读 AGENTS、本人线程、P505/P509 报告、归属与已有 panel 需求。只在隔离位置保存证据，使用候选自带 `panel.js`，不改本会话项目、待命、工具缓存或运行中的 Pulse。

- 复用 P505 原数据、尺寸、真实 tmux 同一命令送 `Up Up Up` 和实景光标判据；复制 `/var/tmp/p505.YT5XZF/run.sh`、输入及必要材料到本席位私有根，只修改源路径/输出等必要处，不动原件。原红侧 = `862733ea` 的三键停在 Other、逐次正常证据，复核实际原件，不能只转述；在新候选只跑正常三键并核确实到 `M39 Second`，用标题和唯一光标区分同 ID。新旧走同一断言，不能拆发或靠加延时。不要重复 Node 追踪或为同一个缺陷再构建反向 bundle。
- 同一短运行补实际一例连续方向键后马上 Enter 打开最后那行（只用目标标题、唯一编号或特有正文证明，不能只看到任何详情）；并核一处视窗跟随/焦点仍正确。对照原 `scn_board` 的重复行断言被换成真正同批 `Down Down`，前面仍能选中两行、实际刷新保焦。可在同一短运行以原行顺序复用该断言，不重跑整个 B3、折叠、标签或 P503。源码核顺序、展开/折叠及鼠标原帧引用不被替代，不扩到工作页；按事实标未运行面。
- 通过 `TEAM_GATES='bash /var/tmp/<你的私有根>/<runner>' bash skills/teamsmith/scripts/team review P509 --dir /var/tmp/p509-review-f6182e92.d2TU2D --branch f6182e925c5480e41e5d403d906c6ce6a3cf2500` 保存两份原生记录。私有命令核真实执行文件、项目和 tmux；唯一背景作业、结束回合后等完成通知。报告实际回执、帧、原件或不能到达的点，只提交 `docs/team/reports/V202-verify.md`，本地小步提交 V202 / `Agent: verify`，不推、不合并、不过度重复。通过后同一人对合并版另做短核。