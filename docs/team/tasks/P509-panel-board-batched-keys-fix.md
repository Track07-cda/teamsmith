---
id: P509
title: 修复 Pulse 看板连续方向键漏步
agent: dev3
deps: P505
category: code
phase: opsx-apply
change: -
specs: panel#The board page is a kanban over the board's states
deltas: -
branch: task/P509-panel-board-batched-keys-fix
---

# P509 · 连续按键使现行看板逐键移动

P505 `7273d427f64e` 同用三键证实冻结标签候选和已合入 `862733ea` 均收妥三键、处理三次、却从同一已绘制焦点出发。修现行主线通用看板，不修 P497 分支；只执行正式 panel 的已有方向键导航与原行选中约定，不建新需求、不新增操作。先读 AGENTS、本人线程、归属、P505 根因与源、证据及 D271。仅 `skills/teamsmith/scripts/panel/src/App.tsx` 第四页导航焦点与必要窗口更新、按原 `build.sh` 重建 `panel.js` 和更新对应 README 数值；仅必要时调整既有 `skills/teamsmith/tests/panel-b3.sh` 的 `scn_board` 同号导航断言；本人 `docs/team/reports/P509-dev3.md`。

每个方向键在当前可导航的显示顺序，以上一个键实际选中的原行作为下一键起点；沿用现有状态引用和顺序，不新设第二份状态、计时/等待或终端输入层。共用看板同一次读中的方向移动与随后 Enter 按最新选中行处理；鼠标仍按它所在画面的原行引用。选中身份、窄宽、跨栏/栏尾和已折合栏规则、自动刷新、历史顺序、工作页都不变。若发现工作页同类现象，只报告，不在本单扩。不要接受含旧排序的标签候选。

用行为覆盖替换现有 `scn_board` 的 `dup-next`、`dup-3` 连续单步片段，保留同号停靠、刷新后唯一光标及文件内容，发一次多键而非拆开等帧才发送；最终仍命中明确不同标题。由非作者在独立检出用 P505 **现有**私有短复现、同一数据和发送方式验证原版连续三键漏步、修复版三键走三行，并核一处视窗/焦点和既有 B3 替换断言；不造通用框架、不为此重复 P503 的完整行为、标签/折叠或全量。不加测试开关和时间阈值。

作者只用固定面板依赖做 `tsc --noEmit`、原构建 `bash skills/teamsmith/scripts/panel/build.sh`、如修改测试做 `bash -n`，再执行 Git 差异和账本检查。记录实际命令、回执、证据和下一步，分步本地提交 P509 / `Agent: dev3`。行为交另一席位，不重跑 P505/P503 或其它场景。不得动运行中的 Pulse、当前项目设置、已阻塞 P497/V196、其它分支、依赖、发布；不合并、不推送。