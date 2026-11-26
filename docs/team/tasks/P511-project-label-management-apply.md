---
id: P511
title: 在 Pulse 项目设置添加任务标签管理
agent: dev-bob
deps: P507,V203,P497,V196
category: code
phase: apply
change: project-label-management
specs: board-and-status, panel
deltas: -
branch: task/P511-project-label-management-apply
---

# P511 · 项目设置里的任务标签

P507/V203 的方案 `4719a407`、`a4ba11e4` 已接受（`docs/team/reviews/project-label-management-proposal.md`）；原标签版 `c9fbb5e705e15763048c803adee9187ca18cfef5` 合并并经同一独立验证者复核。现在按受审变更实施。不复开 P497 缺陷修复、不把本功能放到任务看板或帮助设置首页。初步逐源确认 `label ls` 的三字段定义、define/edit/delete 仍由同一入口负责、分隔符和可选 board 数据不变，原命令没有该定义写入的机器结果。任务 1.1 在本人分支对照实际最终代码/同名原要求后记录；若发现可见行为不兼容，停止产品改动并指出需要定点复审的差异，不新增另一种格式。

先读 AGENTS、线程、归属、此任务、apply skill 与当前 `openspec instructions apply --change project-label-management --json` 给出的全部文件。以原生要求为唯一功能范围，完成清单 1.1–2.3 与 3.1/3.2 的现有测试改动，不勾 3.3 的独立验收。授权路径仅：
- `skills/teamsmith/scripts/{team,task-labels.mjs,lib/cmd-docs.sh,strings/help.en.tsv,strings/help.zh.tsv}`：只接现有三条定义写入的可选机器结果及其参数/使用说明；不要改普通 CLI、算分、发布/目录限制、标签数据或另立流程。
- `skills/teamsmith/scripts/panel/src/**`：只在设置原有二级入口基础上接表单、现有项目命令、精确字段、当前结果与定点刷新，原窄屏、返回和其他设置不变。只用原构建生成 `scripts/panel/panel.js`，不换包或依赖。可同步 `scripts/panel/README.md` 的用户入口。
- `skills/teamsmith/tests/panel-p21.sh` 只改 settings 既有场景及其直接试验准备；保留既有命令页面与模型记录内容/返回检查。按 3.1 移用原通用鼠标导航，不新增一组测试；真实 CLI 读写与不写项目配置要可核。若确需其它文件，先报路径及原因。
- 本 change 的 `tasks.md` 只勾上述已完成项；交付报告 `docs/team/reports/P511-dev-bob.md`。并行 A20 与其它规格、标签测试、巡检、旧项目、当前 Pulse、待命、初始化及发布不写。

优先提交同一个定义入口的少量改动，再提交设置、构建与受影响测试；静态执行修改 shell 的 `bash -n`、修改模块的 `node --check`、原面板类型/词条检查与锁定依赖的原 build，记录命令、退出码、包哈希和最短可检查的改动映射。仅建立当前已批准的真实设置验收，不自行启动该行为批次或整套。交另一位验证者在固定候选调用一次 `panel-p21.sh settings`；不为它重跑原标签 46 项。若现有构建依赖已齐全不再安装；长命令走后台。小步本地提交 P511 / `Agent: dev-bob`，不推送、合并、更新现场或发行。

## 首次独立验证后：只修原测试的文字输入

`eb95c48e` 原生 FAIL（25 秒、15/1）。报告 `04cff028` 和 `.pi/team/state/evidence/P511/round1/`：鼠标已打开新增表单，实际编辑器为空，第一次 `-用户 反馈` 无保存调用。`panel-p21.sh` 的 `type_text` 使用 `tmux send-keys -l` 未分隔参数，且丢掉 stderr；后面的 `-9007199254740993` 也走这条路。原记录不能证实该次 tmux 退出值，不当作产品拒绝。仍用原 P511 会话和分支，唯一代码写集 `skills/teamsmith/tests/panel-p21.sh`：复用同一文字发送方法明确分隔参数，保留原文本的精确值与原帧判断，让标签段文字发送失败时直接发生可读失败、保留退出与错误，不再只等画面。一次核该段三个文字输入及共用调用，不放宽任何原断言、不增加等待或新测试；源码、构建包、设置与正式规格不能改。

只做修改文件的 `bash -n`、Git 差异核对。可在自己的隔离 tmux 一次性空窗对两个相同前导减号文本确认旧/新发送动作与退出、无产品调用；若未执行照实记。不要跑 settings、整套或构建，独立验证只使用新固定候选补未达到操作，旧失败和实际证据保留。提交修正与报告，候选未定仍不能派验。
