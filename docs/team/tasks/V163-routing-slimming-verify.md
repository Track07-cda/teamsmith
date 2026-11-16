---
id: V163
title: 模型路由三处精简实现独立复验
agent: dev3
category: verify
phase: opsx-verify
change: routing-argv-check-slimming
specs: verification
deltas: -
branch: task/V163-routing-slimming-verify
---

# V163 · 独立验证P457，复用最终长跑而不重跑

候选d7eee672，实际可执行字节固定2209a4db；PM准备干净独立检出 `/var/tmp/p457-review-d7eee672`。作者dev-bob；你仅审过规划V162，未实现本变更。

输入：本change的proposal/design/specs/tasks，已接受规划记录、P457报告及其命令receipt、完整父级transcript。报告中所有原始日志路径实际读取；不能仅采信作者PASS。完整61b已唯一运行一次，4365s，父级206/0、正常CORE3140/0、31臂；子目录按旧suite机制已清掉，父级CONTROL/RESULT/具名错误/恢复哈希及短样本原件仍在。

## 仅做必要独立检查

1. 审源码差异，三处旧执行实际删除、没有slow备用；早期短分流在git/录参长活/dispatch之前，真实PM guard及显式resume不绕开；保留正常16组/首CORE/其他29臂、61行及实际计数。坏树无关观察舍弃明示而非声称全覆盖等价。
2. 独立运行候选两个短入口及原变异的同副本0→1→0，确认child rc/三条具名失败、PM两项都执行。只做能区分接线正确与漏消费的最小父级反例（可复用并审读作者一次性两臂runner，不新增永久测试）。不为凑数重跑所有相邻排列。
3. 实读原完整61b日志/receipt/hash：HEAD固定、执行文件三份哈希、首CORE、全部31臂、36个CONTROL、两条健康/恢复、父级206/0与末尾rc0对应。子目录被清理的边界要记录，但不因此自动重跑长矩阵；只有发现具体证据无法支持某个必要主张时点名最小补验，不自行开整套。
4. 执行本change严格结构、索引、spec refs、循环清单、ledger-ban、diff-check等适用短检查。做OpenSpec completeness/correctness/coherence assessment，任务3.3的合并后部分尚未发生，不冒充已完成；其他7项核真实证据。

`team review P457 --dir /var/tmp/p457-review-d7eee672 --branch d7eee672 --strong --no-gates` 只记录候选/执行者并检查报告，不能称全量执行。中央仅授权 `docs/team/reviews/P457.md` / `P457-verify.log`，本人报告 `docs/team/reports/V163-dev3.md` 在自己的分支；不改实现/规划/主检出。

## 合并约束

0.4.7标签fdd3247a已经验证冻结，正在等待用户公开发布授权；P457不在其中。PM当前不推进main，最新V163任务书与看板变更在主根磁盘保留，后续账本提交由PM处理，不要替PM提交主根。

本轮先给候选PASS/必要返修。通过后等PM在发布窗口结束后提供merged-SHA干净检出，同一你再核可执行同一性/适用短入口与调用点，并完成最终assessment；没有实际差异时不重跑61b、full、meta、夜间、安装或性能。独立复验不等于把作者的小时级运行再执行一遍。

长命令仅后台，本任务应只有短样本；不轮询窗口/睡眠。不合并、推送、归档或发布。完成候选报告后提交并通知PM，保持可续跑。
