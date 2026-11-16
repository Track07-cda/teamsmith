---
id: V170
title: 帮助页去重的单次独立行为验收与合并后短复核
agent: dev3
category: verify
phase: opsx-verify
change: help-route-render-once
specs: verification
deltas: -
branch: task/V170-help-render-once-verify
---

# V170 · 本批行为只由你集中执行一次

候选固定 `3fde5e70`，源码提交9bee06a8；PM准备 `/var/tmp/p465-review-3fde5e70`。实现者dev没有运行任何帮助行为，只做静态；报告P465-dev.md给出实际函数/循环/出口位置及源字节。你未参与实现，可独立验证。正式方案为 `help-route-render-once-proposal.md` ACCEPTED，按原生verify skill读取OpenSpec1.16 context及本change四工件；当前2/4是作者实现/静态完成，未来2.1/2.2未执行。不要把阶段A称成归档就绪。

## 写入授权

- 自己稳定dev3工作树只写 `docs/team/reports/V170-dev3.md`；临时runner/输入/坏恢复/原件仅自己本次唯一 `/var/tmp` 根，TMPDIR指向已创建的私有磁盘目录。
- 候选及后续merged独立检出始终只读，起止核HEAD/普通与ignored状态；不得写驱动、日志或勾选到候选。
- 唯一主检出例外：从自己worktree发起 `team review P465 --dir <固定检出> --branch <固定SHA>`，工具写 `docs/team/reviews/P465.md` / `P465-verify.log`，实际执行者dev3；不得手填PASS或写其它主文件。OWNERSHIP同步明授这两个工具输出。
- 阶段B收到PM提供merged SHA/独立检出并实际全部通过后，可在自己分支从该merged版本同步 `openspec/changes/help-route-render-once/tasks.md`，只勾已完成2.1/2.2，保留作者1.1/1.2及原文。阶段A只报告完成范围，不写候选或提前代勾。
- 不改实现、正式spec/规划/其它测试/CI/超时/跳过，不merge/push/archive/tag/npm，不操作真实提醒/standby/PM或外部模型。

## 阶段A · 独立冻结候选

先独立读diff及适用原件，核仅局部helper/循环改变、47命令结构188→141、原52个ok调用点不减；page/manifest/其它组/其它route/结果/51消费不变，不能仅信作者静态数字。实现函数 `check_route_command` 在1296–1320，循环1333–1337，finding125–126，最终出口1604–1606；以实际源为准，不硬用行号裁片段。

用自己的临时runner作为TEAM_GATES，从自己worktree执行上述正式review；所有业务串行一次，较慢命令team_bg_run后立即结束回合，完成唤醒后收取。runner独立保留每步完整stdout/stderr/rc，不只依赖工具尾日志。

1. 固定候选cwd仅一次正常 `bash skills/teamsmith/tests/help-surface.sh --select route`，完整当前manifest。核真实三入口及原全部route结果；只把3N记为受改循环结构账，不冒称整个route调用量。
2. 依design Decision3的一次性短驱动：只替换page的受控原字节/rc输入和单命令MG_ORDER，读取候选实际helper、正常循环、finding/ok及最终出口原文，记录片段来源/hash。正常、两别名错页/仅尾换行差异、三入口各自同字节非零（含全空）及恢复都走同一实际判断。逐项核argv三入口各一次、具名finding、无假全相同成功行、最终1/恢复0；不为坏输入重跑正常route，不实现第二套cmp或拼预期日志。
3. 唯一调用点坏腿：在自己的短副本把helper调用放进subshell，保持坏输入及实际代码其余部分；必须因FIND丢失、最终错误地exit0而让预期exit1的检查报错。不能把提取/语法/搭建失败算目标红，恢复同一副本字节并短验。临时驱动不要求产品source-only开关或新的通用框架。
4. 本change严格结构、必要静态同一性及报告暂存后ledger-ban/diff-check。未改的映射/选择器/spec-refs复用作者回执，不重复整套静态平台。其它帮助组/locale/宽度/coverage/claims/invariants/routes/pages/整个51，按design已绑定rel47原件及V167消费差异复用，不默认重跑，不把全轮rc1说成全绿。

任何失败保存原件，区分产品判断、驱动搭建和观察错误。准备错误若尚未执行场景，修自己的接线继续未做部分；已完成正常/坏腿不为补收据重复。不得用set+e/无注释||true吞掉意外失败。

## 阶段B · 合并输入已到

本次固定merged为 `7d768f1a134e88e72e74fd43f6c34788718b8a3a`，PM已准备干净 `/var/tmp/p465-review-merged`。阶段A的cf05b321和正式P465候选记录已被接受，见V170.md；现由同一模型/SID/分支执行B，不重做A。注意原run.sh硬编码候选目录，必须从本merged读取实际片段、绑定新SHA并只执行规定的短补验，不能复用旧目录冒称merged。实际通过后同步自己分支2.1/2.2及最终报告，按原许可提交，不等额外确认；现阶段未预判未来结果。

A报告提交并通知PM后，保持同一模型/SID/分支；PM接受/合并后提供干净merged检出和SHA。正式review需绑定该merged，不可用硬编码候选runner冒称merged。先比实际helper/调用点/出口/所有输入与依赖字节，相同则复用A，只短补一条正常、一条损坏/恢复，并记来源及真实最终退出；不再跑全manifest route/完整帮助。相关字节变化先交PM收敛补验，不默认全量。

收到merged输入即授权你在B真实通过后同步自己的2.1/2.2清单和报告并提交，不再等额外确认；不是预判未来结果。报告给四场景/全部task的Completeness/Correctness/Coherence、CRITICAL/WARNING/SUGGESTION、未验/复用/跳过及原件，不只依赖shell PASS。PM最终接受后才关单/另派非实现者归档。

不运行其它帮助组、51、smoke真实段、全量/FAST/meta/61b/夜间/安装/性能/真实模型；不测整套耗时。原件留本地不git add -f，未经PM收存不要清理。Conventional Commits含V170/Agent: dev3，分支本地交付。
