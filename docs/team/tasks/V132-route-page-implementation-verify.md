---
id: V132
title: route-page-check-determinism 实现独立复验
agent: dev3
category: verify
phase: opsx-verify
change: route-page-check-determinism
specs: dispatch verification
anchor: openspec/changes/route-page-check-determinism/tasks.md
deltas: -
branch: task/V132-route-page-implementation-verify
---

# V132 · 非作者实现复验（tasks 3.3）

## 输入与职责

冻结候选 `a5ed228e`，作者 dev。你没有参与实现；提案审阅不能替代本次行为复验。阅读 change 全部规划、P430 报告、实际 diff 与作者证据根 `/var/tmp/P430-route-pages.Xukuyb`。

PM 已在候选上重跑结构检查：OpenSpec 22/22、spec refs 121、section-select ok13、账本禁令 hits0、diff check。不要把这些当行为证据。

## 必须独立做的事

1. 在自己的检出/证据根中运行同一 `bash skills/teamsmith/tests/routes.sh pages`，保留完整日志；确认真实七次结果、四个 renderer 调用 rc=0 且非空、④不断言 FIND==1、⑪失败来自集合差、⑬缺 group 为唯一 finding、正常/还原无 finding。
2. 在自己的隔离副本分别做两类共享判定改坏：跳过列 0 归属；删除集合差但保留特殊字面量。对应 `替代④`/`替代⑪`必须红，正常输入仍绿，恢复后回绿。不得只引用作者翻转日志。
3. 运行 `bash skills/teamsmith/tests/routes.sh walk control promises refusals`，与作者改前规范化清单比较页面、CLAIM、判定和计数；发现身份或计数丢失即拒绝。
4. 审查三条旧完整 walk 确已删除且没有备用路径；`mr_flips` 无条件调用同一 `pages` 并检查三条具名成功结果；真实 walk 的两个共享调用点在同 shell 且失败进入 `failed=1`。这部分按提案是源码审查，不冒充受损真实 walk 的行为测试。
5. 核对旧⑪基线配方只改 scratch renderer、测试源码未改；④/⑬没有被伪称本轮重跑。实际执行量与耗时不得被换算成未测的三臂节省。

## 工具与边界

固定镜像需要时用 `distrobox-host-exec podman`，不要直接 podman；日志落自己 `/var/tmp` 的专属目录。不要修改真实项目，不跑全量 smoke、完整 51m/flips、36、61b 或公开 CI，不起真实团队席位。

## 交付

- `docs/team/reports/V132-dev3.md`：先给 **PASS / NEEDS-CHANGES**，每条结论附自己的命令和日志；拒绝只复述作者结果。
- 可补跑结构检查；只提交报告，不改实现或规划，不勾选任务，不合并、不归档、不发布。通知 PM。
