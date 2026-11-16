---
id: V171
title: 一次完整粘贴验收与合并后最小复核
agent: verify
category: verify
phase: opsx-verify
change: clipboard-test-session-reuse
specs: verification
deltas: -
branch: task/V171-clipboard-session-reuse-verify
---

# V171 · 由你统一执行本批真实行为

固定候选790bfb35（源码60907db2），PM准备公共git根下的独立工作树 `/var/tmp/p466-review-790bfb35`。作者dev只做实现/静态，没有运行任何clipboard行为；你未实现本change。读自己线程、verify skill、本brief、proposal review ACCEPTED/D252、P466-dev.md与原生contextFiles。OpenSpec用现有1.16；从固定候选读取真实2/5，不用自己尚未合入代码的分支0/5替代。规划审阅V169和旧两条件样本不能当本次实现已验。

## 写入与执行方式

自己稳定verify分支只写 `docs/team/reports/V171-verify.md`；驱动/输入/坏恢复/原件只在自己唯一/var/tmp根。候选和未来merged始终只读，起止核HEAD、普通/ignored状态和受检字节。唯一主检出写入例外：从自己的worktree调用 `team review P466 --dir /var/tmp/p466-review-790bfb35 --branch 790bfb35`，工具写P466.md/P466-verify.log并记录实际执行者；OWNERSHIP已授权。用临时runner作TEAM_GATES，保留每步stdout/stderr/rc/来源，较慢整批team_bg_run后结束回合，完成唤醒再收取。

阶段A只记录已实际覆盖范围，清单仍以候选2/5报告，不提前声称归档就绪。PM给定merged后，同一SID/model/分支完成B，真实通过才在自己分支从merged精确同步tasks，仅勾2.1/2.2/2.3且保留作者1.1/1.2与原文；不在只读检出写入。你不改实现/规划/delta/正式spec/其它测试或任何真实reminder/standby/PM状态，不merge/push/archive/tag/npm，不启动真实模型。

## 阶段A · 串行一次业务批

先独立读diff，不只信作者31/31和8→4：核同函数三处图像观察、同次可见帧理由、图像父rc/种子同shell flag、模式切换顺序、四次实际编辑/目标种子；其它场景、共享库/产品/bundle和31原断言/分支不变。核七主动C-v/一个零按键，四个面板启动含另一CLI直接new-window，项目/server/假PM仍各一次。当前新增12次发送/16次模式写是源码账，不是耗时收益。

1. **唯一一次正常完整clipboard**：按design §5在同一子命令环境只读用原 `team_tmp_root_source` 读source、`team_tmp_root` 读路径，确认取消TMPDIR/TEAM_TMP_ROOT后source=default且为本项目/var/tmp长磁盘根；不改TEAM_PROJECT或靠短命clone凑路径，不默退/tmp。候选cwd执行 `env -u TMPDIR -u TEAM_TMP_ROOT TEAM_B2_KEEP=1 bash skills/teamsmith/tests/panel-b2.sh clipboard`。父runner的TMPDIR仍用私有/var/tmp目录；正常使用候选原bundle，记录实际路径。保留实际私有根、原日志/帧/图片/草稿/理由/工具顺序、七次按键、4次真实启动及三段原5s观察，逐项覆盖八子例。任何等待耗尽都不能因最终rc0被覆盖；不先跑短路径或额外两条件样本。
2. **真实C-v no-op的首例短坏腿**：按design §5只在自己的普通副本改真实App.tsx相应分支并构建坏bundle，用既有TEAM_B2_PANEL驱动从候选摘出的原首例实际函数/工具准备/m/Left/C-v/文件草稿断言；不带未改headless sibling或其它七例，不增产品/测试入口。必须原具名图片数量/内容断言红且实际child rc1，不能只有搭建/构建失败或等待超时。恢复副本原字节/原bundle后仅首例短恢复；不再完整clipboard/b2/38。
3. **结果消费短检**：把上述实际坏腿log/rc交原smoke的p38_verdict，看原父bad/具名38-h失败；静态确认原38-h实际把child rc交给它，不称完整smoke调度。另用候选实际种子准备消费者，在替代的目标等待已完成、其实际读flag之前注入PTY_WAIT_FAILED=1，保留真实return上下文，观察bad/非零/无后续C-v；不能在真实等待前注入被清零。只证明消费，不冒称真实等待引擎故障；一份实际消费短检加四块源码核实即可，不四次重复同检查。
4. 原change严格结构/必要静态同一性和报告最终暂存后ledger-ban、两种diff-check；旧spec-refs/选择器平台未变复用已接受回执，不重复跑。

失败保存完整原件并区分实现、观察或私有驱动搭建；不得自动重跑完整场景收集现场。若确有实现缺陷，报告实际已通过/失败/未执行子例并BLOCKED给PM，后续只收敛必要返修，不靠删断言/缩等待/换路径或set+e/无名||true换绿。

## 阶段B · 等PM提供固定merged输入

A真实交付后由PM接受/合并并提供干净merged检出和SHA。必须从merged实际读源，正式review绑定该SHA，不能硬编码旧候选目录冒充。比对脚本、正常bundle/库/实际输入与规划依赖；字节相同复用A，仅做必要静态/实际结果消费短检，不默认再起面板/构建/首例或完整clipboard。若相关字节变动先交PM收敛补验。B全部真实通过再精确同步清单5/5和最终OpenSpec评估；保留阶段A原件和未验边界，不用planning isComplete代替。

报告按原生verify给Completeness/Correctness/Coherence、1条需求/6场景及5项任务、CRITICAL/WARNING/SUGGESTION和复用/未验范围；工作流未收口项与实现缺陷分清，最终未解决CRITICAL不得归档。完整测试耗时/净提速未测，不作承诺。不跑其它b2场景/38/设置/帮助/配置整组、smoke/FAST/全量/meta/61b/夜间/安装/性能/真实模型。原件不git add -f、未被PM收存前不删；Conventional Commits含V171及Agent: verify，本地交付。
