---
id: V177
title: 独立验证Pulse项目设置精简的实际操作
agent: dev3
category: verify
phase: opsx-verify
change: pulse-project-settings-simplify
specs: panel, memory-and-deps, verification
deltas: -
branch: task/V177-project-settings-behaviour-verify
---

# V177 · 当前仅核已保存真实帧，不再启动界面

保持本V177原模型/SID/分支，实际实现者dev，你仍为非作者。先读AGENTS/本人线程/OWNERSHIP及本brief；原生工件和你已提交的报告为范围及证据，不重审全案。旧十场景及第二轮补验均已实际执行，下面替换原执行安排，不是继续再跑UI。

最新交付`a96864aa3dfd64820836d0e526d9500401a66662`，测试修订`391ef8ee53feeedf3b19de8731ce9d1a9466b9d6`。PM新独立clean源`/var/tmp/p471-review-a96864aa.Ohz1ip`；相对已验5f3f320a只有wheel等待第二needle由屏外“输入其它值”改为“· 当前”及作者报告。产品源/bundle/共用fixture字节不变；标题、原超时及后续滚动/退出断言不变。作者仅bash语法/diff rc0、6/9不变，未再运行UI或其它静态。回执的占位提交号不作证据，以上均是PM实际Git核对值。

## 本次唯一短核对

1. 直接核5f3f320a..a96864aa真实差异及产品/bundle/其余fixture同一性，不重建或编译。源保持clean及无ignored产物。
2. 从候选实际`cat-picker.txt`那条唯一`pty_wait_frame`调用读取两个needle，调用原`tests/lib/pty-wait.sh`匹配器，不在临时driver写一份与候选无关的预期来冒充测试。对你第二轮保留的真实长列表打开帧应通过；真实关闭帧及另一个真实非routine选择器帧应拒绝。只读取保存画面，不能新造假帧、启动tmux/CLI/UI或跑原场景；原打开/滚轮4→6/退出不穿透均有实际证据，不再实跑。
3. 读取已存的路由原件，关闭第二轮临时cut路径错误的证据缺口。直接用结构化原件路径核真实错误set-agent-model argv、8条目标红、配置未改，以及唯一正常policy29/0、正确dry-run/yes和唯一类别配置变更。你原postrun-saved-evidence.json已列这些事实，核实际文件而非仅复述报告；不再跑policy或原driver，不把重读计成新运行。

证据根沿用`/var/tmp/V177-repair.dS0eVN`，可在本人唯一子目录写极短核对脚本/输出。第1轮177/16和第2轮55/2正式FAIL与各自私有round1/round2副本均保留，不改旧计数或临时错误说明。原模型来源变异的3条有效红已核表达式同一性、结合第二轮正常来源检查复用，不重复变异。D261完整typecheck仍rc2/四旧错，1.6仅按已接受边界完成，不把旧错误改绿。

## 正式执行和交付

本人稳定工作树调用正式工具，TEAM_GATES仅上述短核对的实际脚本：

```sh
TEAM_GATES='bash /var/tmp/<本人证据根>/verify-saved-settings.sh' \
  bash skills/teamsmith/scripts/team review P471 \
  --dir /var/tmp/p471-review-a96864aa.Ohz1ip \
  --branch a96864aa3dfd64820836d0e526d9500401a66662
```

保留原review锁/超时。实际命令用team_bg_run后结束回合，完成唤醒再收取；不在回合内等。新正式记录明确“保存帧匹配+同一性/既有记录核对”，不能写成在新tip重跑原UI全绿。只写本人分支`docs/team/reports/V177-dev3.md`；主检出例外仅正式生成`reviews/P471.md`与`P471-verify.log`。

追加最终Completeness/Correctness/Coherence、真实命令/rc/帧匹配和复用映射。报告区分：原批次+定点补验的产品结果已接收；一行测试条件经保存帧核对；完整类型旧FAIL；未来3.1未给merged输入。不要因3.1未到阶段否定候选已完成事实，也不先声称可归档。只必要本人报告diff，不再ledger/编译/build/strings/strict/spec-refs/矩阵/任何真实模型/团队状态。Conventional Commits含V177、`Agent: dev3`，本地提交不push/merge/archive。原件不清，等待PM保存。

## 合并后（当前不执行）

PM给独立merged SHA后仍由你核UI源/bundle/相关测试/CLI读取同一性；相同复用组合证据，仅执行原3.1的打开设置、一个入口返回与必要结构/引用短接入，不重跑本批。已知P473提醒测试一行、账本/任务勾选差异不影响本UI；真实相关差异先交PM裁范围。当前不提前启动该接入。
