---
id: P462
title: 帮助页相同入口只生成一次的最小提案
agent: dev2
category: analysis
phase: opsx-propose
change: help-route-render-once
specs: verification
deltas: verification
branch: task/P462-help-route-once-proposal
---

# P462 · 沿用P432，只规划正常route的一处重复

用户已授权持续精简完整测试、不要过度防御；沿用D237/D238/D245和P432 §3.2/4B，不重做全仓调研。配置这一批P461/V167已关闭，A9仅同步规格/归档，与本单无代码写入重叠。

PM已核当前 `help-surface.sh:check_route`：每个MG_ORDER命令用两次相同环境的 `page en help "$c"`，分别比较真实 `--help` 和 `-h`，即每命令四次CLI。只规划一次取得canonical原始字节、分别与两个真实别名入口比较，目标4N→3N；N按当前manifest核实，不把P432的47硬当当前数。保留尾换行与原字节比较，不用命令替换丢字节；只在本次单个检查使用，不做跨命令/语言/locale/宽度缓存。

## 唯一写集与交付

按本机OpenSpec1.16原生流程建立唯一change `help-route-render-once` 的proposal/design/verification delta/tasks及自己的 `docs/team/reports/P462-dev2.md`。先读propose skill、原生根/context/rules；仅规划，交非作者审阅后才能实施。不要改正式spec、产品、tests、CI、真实团队状态、主检出。

方案要说清实际删除哪一次调用、三个入口和逐字节判断仍在、alias错误页/失败如何继续变成具名finding并传到原退出结果；短反例必须走同一实际判定，不复制一套正确答案。不得为省一次CLI造新框架、全局缓存、额度/超时/权限限制、产品测试开关或旁路实现。若不值得就明确给出原码证据，不能为了交提案扩项。

本批不碰：不同locale/宽度的真实页面矩阵、coverage/claims/invariants、未知token/无项目/不写状态行为、routes.sh与D的pages、显式--flip全目录改造、组页统一ok文案、模型/配置/面板测试。不能把整段51的681秒或显式--flip的成本当作本次节省。

## 最小后续验收计划也要写进设计

沿用P461的分工，未来实现者只改代码/静态；非作者统一跑一次受影响正常route、必要具名短坏样本和失败接线，合并后字节同一性+短补验。未改help其余组/locale/routes/整个51要按实际源码/输入同一性与已有原件复用，不默认重跑；有真实相关差异才补相应入口。别为每个坏样本再顺带完整帮助检查，不要求新的全量或性能对照；所有尚未测量的节省明确不作秒数承诺。

## 本轮实际规划检查

不运行完整help/route/locale/routes/51、smoke真实段、全量/meta/61b/夜间/安装/性能。静态能回答就不做样本；若确需，只补一条私有目录的三入口短样本，不据它声称全manifest已验。实际使用OpenSpec1.16本change严格结构、spec-refs/section-select静态登记、报告暂存后的ledger-ban与两种diff-check；较慢批次后台跑并结束回合。不安装/升级。

小步提交Conventional Commits含P462和Agent: dev2。报告先给推荐最小范围、4N→3N实际计数/原代码证据、实施/验收成本及哪些旧执行退休，再给真实回执/未验证；不能宣称已实现或整套已提速。不merge/push/archive/tag/npm，只清自己的本次精确临时根。主根.cortexkit是旧目录；正常后台记录不是未知源码污染，不扩修工具。
