---
id: P429
title: route-page-check-determinism 正式 OpenSpec 提案
agent: dev2
category: analysis
phase: opsx-propose
change: route-page-check-determinism
specs: dispatch verification
anchor: openspec/specs/dispatch/spec.md#The printed route is a route that works
deltas: openspec/changes/route-page-check-determinism/specs/dispatch/spec.md openspec/changes/route-page-check-determinism/specs/verification/spec.md
branch: task/P429-route-page-check-proposal
---

# P429 · 只写 P428 接受样本的正式提案

## 输入

- 已接受探索：`docs/team/reports/P428-dev2.md`；PM 审阅：`docs/team/reviews/P428.md`。
- 样本只含 `51m` 的④、⑪、⑬页面内容判定；不扩展到 `36`、`61b` 或其它测试面。
- D234 的总边界仍然有效。

## 交付

在 `openspec/changes/route-page-check-determinism/` 中写完整提案：`proposal.md`、必要的 `design.md`、`tasks.md` 和上述两个 delta。
任务清单只覆盖该样本，不写实施代码、测试代码或产品代码。

提案必须明确：

1. 删除④、⑪、⑬各自的一次完整 `walk`，不是新增快速路径后保留旧执行；
2. 从原走查提取同一文件内容判定，真实 `§51` 调用它，不能形成第二套解析器；
3. ④、⑪保留受损真实 renderer 的单页执行与正常对照；⑬的真实清单→枚举→读取接线仍由原 `§51` 覆盖；
4. 所有真实 CLI 参数、配置承诺、Pi、tmux、进程与窗口测试保持不变；
5. `dispatch` 的页面内容义务与 `verification` 的断言身份/计数约定如何用 MODIFIED Requirements 精确变更，不能虚增断言数；
6. 至少两类红侧：受损真实帮助页仍被同一判据抓住；把共享判定改坏时对应测试必须红；
7. 短验收命令、旧路径消失的检查方式、实测口径，以及不跑全量/61b 的边界；
8. 守卫净零：新文件判定与两次单页验证替代三条旧重型路径，不新增另一层“检查测试是否被删”的守卫。

## 审阅要求

- `openspec validate --all` 必须通过；
- `spec-refs.sh --check`、`section-select.sh --check`、`ledger-ban.sh --names-file <主检出名单>`、`git diff --check`；
- 报告 `docs/team/reports/P429-dev2.md`，列出实际运行与未运行的检查；
- 小步提交，通知 PM。之后由非作者独立审阅，PM 接受前不得 Apply。

## 边界

只写提案与报告；不修改正式规格，不运行全量门禁或变异矩阵，不合并、不发布。
