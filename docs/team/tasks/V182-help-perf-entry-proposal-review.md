---
id: V182
title: 独立审阅帮助测试与性能测量分开的方案
agent: verify
category: verify
phase: opsx-verify
change: help-perf-entry-without-measurement
specs: verification, help-surface
deltas: -
branch: task/V182-help-perf-entry-proposal-review
---

# V182 · 只审方案，不实施、不运行行为批次

P482 作者 dev2，待审固定提交 `79cd6a73421a19c6cc5af3496660852a9b814829`，PM 干净检出 `/var/tmp/p482-review-79cd6a73.19EgNI`，只读。先读 P481 接受记录及 P482 原任务、交付；以实际差异判定，不重做既有计时归因。

核查：净删一次无效测量，不以短超时冒充通过；现有帮助入口及项目不变可真正验证、真实性能测量入口原样保留且不混为通过。具体检查现有脚本能否用私有复制替换唯一目标、是否缺启动依赖、被测输入的坏版本是否能进入所说路线，而不是测试了另一份 CLI 或碰当前项目。两个反例应分别确实命中提前返回和变更状态、并有不同证据，不能被同一种准备错误误充；不要为理论上的其它情况要求新增机制。确认只替换这一断言、未误改既有需求或场景。指出必须修哪里或直接接受，注明真实性能全程无写入没有被此检查证明。不单列已在方案边界中如实披露的事项作阻塞，除非与产品需求实质冲突。

只做静态差异、该 change 的 `openspec validate help-perf-entry-without-measurement --strict`（用 1.16；仅改本次 PATH）及必要的语法、现有调用路径检查。不跑实际性能、help、smoke、整套，不制造补充验收批次；不改方案或中央记录。交 `docs/team/reports/V182-verify.md`，写清独立结论、命令和退出码，本地提交，不推送。此任务仅审提案，正式行为验证另派。

首轮两处必修的返修候选 `2f162fc3815a6e27d509ddf081173110a72b010c`，新的 PM 干净检出是 `/var/tmp/p482-review-2f162fc3.6yTRnt`。只比较 `79cd6a73..2f162fc3` 的 `tasks.md` 和 verification delta，核两个故障样本根目录与旧场景的例外清单；仅做本 change strict 与 diff 核查，不重开首轮审阅、不执行行为样本。续接本分支及报告，保留首轮原回执，提交最终接受或拒绝。
