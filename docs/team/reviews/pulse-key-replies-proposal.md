# pulse-key-replies · Proposal review

时间: 2026-10-09
verdict: **ACCEPTED**
任务: E16（Pulse 关键回复页正式提案）
作者: dev2；评审: pm
受检分支: `task/E16-pulse-key-replies-propose`
受检 HEAD: `b0edd0848eda265d29f85464ddc6ed1d088c0e14`

## 结论与范围

提案符合用户已定方向：Agent 显式发布准备发送的正文，用户从 Pulse 固定第五页进入列表和完整正文；不读取 Pi 历史，不做降噪、审批队列或待办提醒。只接受规划，不批准 apply、真实面板更新、共享来源采纳或归档。

正文原文与安全显示分离、存储失败不阻断正常答复、所有旧答复可翻页访问、面板按需异步读取，均有对应 delta 场景及后续验收出口。128KiB 上限、只增不改的存储及有界索引是本轮工程选择，不是新增用户需求。固定槽位/持久性方案确有实现成本；将其作为可验证设计接受，不把纸面锁、路径安全和中断分析当作已实现保证。10万条 fixture 是读量边界测试，不代表观察到的真实使用规模。

## 独立核对

PM 重新读六份工件并核对写集合：只含本 change 五份文件及作者报告，无产品、另一 change 或 canonical spec 修改。作者树干净，原件保持冻结。

在独立真实 clone 中运行自己的检查，不复用作者检查器：

| 检查 | 结果 |
|---|---|
| 原生 OpenSpec 全量严格校验 | 15/15，rc 0 |
| 引用检查 | 104 refs，retired 0 / undeclared 0，rc 0 |
| 隐私检查（正确名单） | hits 0 / names ok，rc 0 |
| diff / 报告选段 | rc 0 / NONE |
| 收录后的相关 smoke 切片 | `0 0b 0c 0d 18c`：46/0，rc 0；其他120键未跑，逐键清单见 `collected-selected-smoke.log` |
| 当前基线仅投影 replies | 原生 archive、validate、refs 均 rc 0；仅证明结构，不是实施输入 |
| routing → replies 双投影 | 两次原生 archive/validate 及 refs 均 rc 0；所有 routing 的 ADDED/MODIFIED 全文或场景保留，REMOVED 不回流 |
| replies → routing 反序 | 原生结构检查仍绿；独立语义断言明确检出旧四页设置限制回流，不可采纳 |

正序投影保留原三块 panel 场景、类别设置合同与所有 reply 场景；类别设置整块仅最后页位句改变，前文与原场景逐字不变。源 openspec 与冻结 Git 对象一致，无新文件；所有试归档仅在 PM 自建复制品。

证据在仓外 `pm-skills-ledger/team/reviews/E16/`：`run-independent.py`、逐命令日志/`results.tsv`、三个 trial、`recheck-semantic.py`、`semantic-recheck.log`。原生 archive 的未完成任务警告保留，17 个实施项未勾。

## 检查器失败，不掩盖

PM 首轮全文断言错误地把 delta 的 `## REMOVED Requirements` 分组标记附到前一正文，导致 rc 1。第一次修正又使用只存在于新版本的页位句分隔词，导致 rc 1。两轮脚本与后台日志保留；修正为按操作组解析、使用新旧共同句界后，原投影的全文/场景/删除与反序控制全部通过。没有为检查器改提案、canonical 或产品。

## 尚未验证与交接

未实现存储/CLI/第五页，未运行新功能、真实 TUI、性能、端到端或全量 smoke；结构通过不代表可用性通过。body 安全滚动、键鼠/窄屏、持久性与路径替换、并发及真实坏源码反例，必须由后续不同作者 verifier 复验。

依赖完整模型路由私有输入与共享文件单写者交接；P228 的 S1 候选不等于完整输入。两个 change 共享的设置要求及 common/team/panel 路径不得并行抢写。真实归档只能 routing→replies，且须任务完成、独立验证和用户确认。主检出产品关联共享技能软链接，后续采纳须单独授权；当前源配置、共享链接和真实 Pulse 均未改变。
