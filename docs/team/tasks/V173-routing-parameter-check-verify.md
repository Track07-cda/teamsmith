---
id: V173
title: 一次验收正常及五项参数检查，合并后仅短复核
agent: verify
category: verify
phase: opsx-verify
change: routing-parameter-check-dedup
specs: verification
deltas: -
branch: task/V173-routing-parameter-check-verify
---

# V173 · 由你统一执行本批真实行为

固定交付候选b60de2ab（实现68e8e2ea；其后只增加作者报告），PM准备只读独立检出`/var/tmp/p468-review-b60de2ab`。作者dev只做实现/静态，未运行任何本批行为；已提交正式报告，工作树干净。V172的ACCEPTED仅审规划，不能当本次行为已经通过。读AGENTS、自己的线程、verify skill、本brief、proposal review ACCEPTED/D255、固定候选的P468-dev.md及原生contextFiles；OpenSpec沿用1.16，从该固定候选确认3/6，不能用自己分支旧0/6替代。

## 写入与执行

- 稳定verify任务分支只写`docs/team/reports/V173-verify.md`；驱动、旁路、短回放和原件仅在自己唯一/var/tmp根。候选和未来merged始终只读，起止核HEAD、普通/ignored状态及四执行文件/规划依赖字节。不要改实现、已接受规划/delta、正式spec、其它测试或任何真实团队状态。
- 唯一主检出写入例外：从自己的worktree调用`team review P468 --dir /var/tmp/p468-review-b60de2ab --branch b60de2ab`，由工具写P468.md/P468-verify.log并记录实际执行者；OWNERSHIP已临时授权。用自己的临时runner作`TEAM_GATES`，**不能调用默认全量门禁，也不以--no-gates冒充PASS**。分步保留实际命令/stdout/stderr/rc/来源；较慢统一批次team_bg_run后结束回合，完成唤醒再收取，不轮询等待。
- 阶段A仅报告实际已验内容，原生仍3/6。PM接受A并给定merged后，同一模型/SID/分支完成B；真实通过后才在自己的分支从merged精确同步tasks，只勾2.1/2.2/2.3，保留作者1.1–1.3及其余原文，不在只读检出写入。该tasks写权仅B通过后生效。

## 阶段A · 一次受影响行为

先读实际四文件diff和必要相邻源，独立核共享输入/固定期望、fresh部分绑定正例、每项输入及scratch数组隔离、调用shell累计结果、短入口确在项目准备之前。作者source-audit只是源码声明；核原合法启动/quoted literal、PM continuation/metadata/撤销、其它26臂（包括P457两样本）没有被删除或改变，不重跑这些未改组。197/22只是本次盘点，不设置永久PASS/调用数守卫，也不把潜在562当旧实跑数。

依照design Migration和tasks 2.1/2.2，只执行以下一批：

1. **正常boundary一次**：在固定候选执行`bash skills/teamsmith/tests/task-model-routing.sh --select boundary`。分开记录direct规则、真实负向调用、原合法启动/argv/PM尾部的具名结果及实际计数。既定21次launch加一个PM preview应有合法前提、特定诊断、真实rc/argv与完整状态观察；尤其两个list见证不能被standalone extra提前拒绝，PM continued须用同resume-key真实metadata。最终renderer的合法/拒绝观察也要实际成立。
2. **五原故障仅经一次bounded parent取得**：在自己的普通私有副本，仅将现有CORE baseline选择收为parameters、原flip名单收为`extra-shadow template-shadow template-unbound template-roles literal-shell-expansion`；其它实际父消费/变异器/规则/预算字节保持，保存这两处选择差异。起跑前只读确认不会携带整组正常路径；沿用现有前门执行这一轮，每臂自身副本的healthy→原故障→实际脚本字节恢复→restored及父级具名结果一次取得。**不能先单跑五臂，再为父级重跑；不能跑完整--flip/61b。** 具体命令和副本来源如实记录。
3. **原父结果消费短回放**：从第2项实际父消费代码及所得rc/log提取，不另写判定算法；明确标注人工改变的unexpected rc0、rc124、缺必需名、healthy失败、restored失败输入，各须到原父FAIL/非零，真实原结果回放为成功。不是第二轮故障行为，也不能用任意FAIL/setup错误顶替目标规则失败。
4. **既定调用边短旁路**：在同批私有fixture使用原有输入，分别观察worker extra选择前边、worker模板整个写prompt前拒绝边界、最终renderer；真实guard不stub。PM严格采用已接受的real-up方案：合法policy/已停止的私有PM，同时旁路real-up identity预检和start首道identity检查，保留真实guard/最终renderer，用既有fresh provider坏custom模板从真实up观察prompt/诊断变化。不要另做直接start实验，不要求删除任一冗余单点都红。相关输入与源码依据引用design，样本不得因更早的无关拒绝冒称命中；如仍观察不到，给具体缺口，不扩矩阵。
5. 本change严格结构和必要四文件语法/静态同一性；报告最终暂存后ledger-ban及diff/cached-diff。已有版本/源盘点/spec-refs/选择平台未改，复用回执，不再执行这些旧检查。

任何失败保存完整原件，明确区分实现缺陷、检查观察或私有驱动搭建；不要自动重跑完整boundary/parent收集现场。真实缺陷BLOCKED给PM，准确列已过/失败/未执行部分，后续只返修相应项；不删断言、不缩超时、不换目录或用无名吞错换绿。

## 阶段B · 等PM提供固定merged

A真实交付后，PM接受并合并，再提供干净merged检出及SHA。同一verifier正式review绑定该SHA，从merged实际读四执行文件及规划/输入依赖；不能硬编码旧候选目录冒充。字节一致复用A，仅执行一次短`--select parameters`接入及必要结构/报告检查，不重跑正常boundary、五臂parent或调用边样本。若相关字节变化，先交PM收敛对应补验，不自行扩全量。

B全部真实通过后，精确同步自己分支的tasks为6/6并提交最终报告/OpenSpec评估。只把三个verify叶子变为完成，不用planning isComplete代替真实证据；合并前未验证状态、首轮失败或驱动错误均保留历史。

报告按原生verify给Completeness/Correctness/Coherence、既有需求本批六场景和六任务的实际映射、CRITICAL/WARNING/SUGGESTION及复用/未验范围。实现缺陷与等待工作流收尾分清；最终未解决CRITICAL不得归档。保留实际耗时但仅作参考，不宣称整套测试提速。不运行完整CORE/61b/flip、smoke/FAST/meta/夜间、其它路由/功能矩阵、安装/构建/性能或真实模型。原件不git add、PM收存前不删；不merge/push/archive/tag/npm，Conventional Commits含V173和`Agent: verify`，本地交付。
