---
id: V167
title: 配置测试去重的独立行为验收及合并后复核
agent: verify
category: verify
phase: opsx-verify
change: config-check-execution-dedup
specs: verification
deltas: -
branch: task/V167-config-dedup-verify
---

# V167 · 全部受影响行为只在本轮实际运行一次

候选固定 `b26bd4196a20`，PM准备 `/var/tmp/p461-review-b26bd419`。实现者dev未运行任何真实smoke；其静态批次原件在 `/var/tmp/p461-static.RHl0wX/`、报告 `P461-dev.md`。你没参与实现，可以验证；上一单V166只审规划，不是本轮行为通过证据。

先按AGENTS/自己的线程/本brief读，再读verify skill与本change原生status/instructions及全部contextFiles，采用OpenSpec1.16。正式接受在 `config-check-execution-dedup-proposal.md`、D246；执行方式以已修订design最小表为准，不恢复首轮REWORK里的重复命令。3/7是实现/静态已完成，四项真实/独立/合并后工作尚未执行，本单负责该剩余范围；阶段A不冒称归档就绪。

## 所有写入的边界

- 自己稳定的verify工作树和分支只写 `docs/team/reports/V167-verify.md`。
- PM的候选/后续merged独立检出只读，开始/结束核HEAD、普通及ignored状态；一切运行原件、临时runner、坏/恢复树只在自己本次 `/var/tmp` 精确根，TMPDIR=/var/tmp。
- 唯一主检出写入例外是从自己的工作树发起 `team review P461 --dir <固定检出> --branch <固定SHA>`，让工具写 `docs/team/reviews/P461.md`/`P461-verify.log`；实际执行者必须verify，不能手工填PASS或改其它记录。
- 阶段B在PM接受候选并提供merged SHA后，可在自己的任务分支同步 `openspec/changes/config-check-execution-dedup/tasks.md` 的实际已验结果；先从该merged版本读取保留作者三项，只对本单已完成的1.3/2.2/3.1/3.2勾选。阶段A不要为改清单而写候选，报告逐项区分实际完成与待merged输入。
- 不修实现、产品、正式spec、规划、其他测试/CI/超时/跳过，不merge/push/archive/tag/npm，不建真实提醒/改standby或重启真实团队，不调用外部真实模型；原有私有tmux/受控进程前提照常运行，不能把real腿改成shim或FAST。

## 阶段A：独立冻结候选

先读diff与作者原件，独立核对确实只删一个配置顶层调用、移动同一5296字节/91行/14函数完整块、两token/七边、消费者/33父级/51保留调用不变，没有抹掉真实检查。不能仅信作者的PASS。

只安排一次串行批次，保留每个子命令自己的完整原件/rc（不依赖工具有界尾日志）。用你自己的临时runner作为TEAM_GATES，从自己的工作树发起正式review，长命令 `team_bg_run` 后结束回合。正常步骤不可因收据脚本出错重跑；修观察脚本后从现有原件继续缺项。

必须完成已接受design的全部最小表：

1. **正常33一次。** 在固定候选cwd：
   `TMPDIR=/var/tmp TEAM_CONFIG_KEEP=1 bash skills/teamsmith/tests/smoke.sh --select 33 --keep </dev/null`
   KEEP是现有开关，保留外层child与内层拒绝/注释坏恢复日志，避免退出清理把证据删掉。核无参数默认组完整、真实CLI/写盘/拒绝与父级成功，不用外层✓数代替组名；不额外全跑config-cli。
2. **七键各独立一次。** 分别 `TMPDIR=/var/tmp bash skills/teamsmith/tests/smoke.sh --select <key> --keep </dev/null`，key为12e/12f/12g/12h/12i/12j/12k，每次新TMP，不合跑替代。核实际段头/输出无33及配置child，具名检查、自己的项目、live前提/具名跳过仍在。
3. **已有坏恢复直接读原件。** 从本轮33保存的 `refuse-flip-green0/red/restored.log`、`flip-red/green.log` 核TEAM_PROJECT错误接受/注释丢失的准确报错、坏腿非零及恢复；不另跑validate/writer。只有具名证据确实缺失，才补缺的一腿并解释。
4. **roster假成功一坏腿。** 在自己的scratch坏产品树，用原 `TEAM_CONFIG_TREE=<scratch-tree> bash <候选>/skills/teamsmith/tests/config-cli.sh roster`。须因注册成功但名册未变而按正确字节断言失败，不把setup错误当目标红；正常/恢复用本轮33及精确还原字节证明，不再完整跑配置。
5. **父级失败短接线。** 原父级字节不变的前提下，用真实config-cli短setup失败走33（design的空树TEAM_CONFIG_TREE例子），核child确为缺CLI setup=3且smoke非零/点名失败；不再完整跑坏树默认组，不冒称这个setup样本重跑了assertion=1。
6. **缺准备一坏腿。** 仅在自己的scratch候选副本删除 `p24_brief` 定义，保留 `p24_project/p24_change` 和真实项目路径/shim；单选12e须非零、点名缺定义且有具名行为失败。不能删project造成空根路径；恢复用字节还原及正常独立12e，不重复七键。
7. **51剩余检查复用证据。** 原 `/var/tmp/rel47-first-order.log`/572856a3全轮rc1，局部routes/help成功及routes原SKIP保持原样。独立核三子脚本hash、父调用/汇总/顺序/输入、原提交→接受基线→候选期间消费源码差异是否影响证据，再沿用局部记录；不能仅引用V166一句通过，也不能无条件以整个产品树相同假装相同。发现实际相关差异才补对应原入口，不默认整段51。
8. 原生change严格结构、spec-refs/选择器check与self-sufficient/loop、四路径/七键计划各一次；暂存报告后ledger-ban/diff-check。未声明路径仍FULL但不要真跑FULL；静态SKIP必须具名保留。

预期坏腿的非零要在runner逐个收取并核诊断，不以set+e/||true笼统吞掉其它失败。每个实验只改自己的临时树，精确还原并比较真实字节。实际子日志必须留存到PM接受/收存后再清理，不为补被删原件重新跑业务。

## 阶段B：由PM提供合并输入后再执行

阶段A报告提交并通知PM，不自行合并。PM接受/合并后提供干净merged检出和SHA，同一会话核两编排文件、三子脚本/消费者与候选同一性，跑必要短结构/选择或原函数样本，并让正式review记录绑定merged。受测字节不变时不重跑33、七键、坏腿、51或完整矩阵。先保留原候选和原件，只有新差异影响证据才补对应入口。

阶段B实际通过并获PM接受后，同步自己的清单副本与报告，确保原生7/7和实际证据一致；不得在收到merged输入前提前勾3.2。最终OpenSpec评估逐项回答Completeness/Correctness/Coherence、两个requirement/五场景及全部未验证项，不把尚未执行的阶段B写成PASS或零CRITICAL归档就绪。

## 不运行

全量/FAST全量、完整51/help/routes变异矩阵、meta/61b/夜间、安装/性能、额外正常全组配置或原样重复；不为本批测整套耗时。不把七个单选省掉33的局部收益乘七计入正常完整运行。

## 报告与交付

自己的原报告包含候选/merged/实际执行者/命令/rc、具名结果、原51复用及条件、每个跳过与原始失败、最小表逐项映射、flip证据与原件路径。先给结果及业务后果，观察只有改变结论才放正文。保留不完整/失败，不写不存在的日志。短收据若自己写错，只修读取并继续剩余检查，不把正常场景重跑。提交仅本任务分支，先交阶段A；之后由PM发送阶段B输入，不等人类逐项确认。
