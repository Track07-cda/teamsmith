---
id: P433
title: reply-observer-skip-focus 正式 OpenSpec 提案
agent: dev2
category: analysis
phase: opsx-propose
change: reply-observer-skip-focus
specs: key-replies verification
anchor: openspec/specs/key-replies/spec.md
deltas: key-replies, verification
branch: task/P433-reply-observer-skip-proposal
---

# P433 · 只写缺观测器重复执行的正式提案

## 输入

已接受研究 `docs/team/reports/P432-dev2.md` §3.1/§4A 与 PM 审阅 `docs/team/reviews/P432.md`；D238 只授权本批提案。阅读真实 `tests/key-replies.sh` 的 bounded、flip、skip_path 和 `tests/lib/proc-io.sh`。

## 已确认的问题

`kr_group_skip_path` 在 `TEAM_REPLY_NO_PROC_IO=1` 下再次执行完整 `bounded,flip`，失败时还带 trace 再跑整组。九个 flip 中只有 `full_scan` 依赖 `/proc/<pid>/io`；其余八臂仍重复执行坏/恢复探针，bounded 也重复大存储准备。要删除的是这些与缺席能力无关的第二遍执行，不是正常覆盖。

## 提案必须明确

1. 缺观测器行为仍由**实际生产判定路径**产生：bounded 读取量跳过、full_scan 具名跳过、可见理由与正常结束；不能用手写日志或另一份“正确输出”自证。
2. 删除 `skip-path` 的完整 `bounded,flip` 子进程及失败后第二遍整组 trace；用最小真实缺席样本替代。正常 bounded 和正常九臂各一次保持原样，不转移到夜间或备用模式。
3. 三条具体诊断与结束状态取代 `skips >= 3` 的计数判据；无关 SKIP 不能顶数。缺观测器既不是静默通过，也不是产品错误。
4. 至少三类红侧：删掉缺席诊断；把缺席误算成功；把缺席判成产品失败。正常 full_scan 的真实读量检查和原九臂仍须能抓原缺陷。共享判定接回父级退出出口，避免 helper 红、父级绿。
5. 保留真实存储、并发、FIFO、权限、内核读量、Pi capture、UI 和其它产品测试，不为本批引入通用运行框架、产品测试开关或第二份规范。
6. `key-replies` 与 `verification` 的义务和计数如何精确修改；只解释被退休的重复执行，不虚增通过数，不放松其它断言。
7. 改前证据优先复用已有日志和源码，不为提案跑完整 §62。Apply 的验收应是受影响短样本加一轮 §62及必要选段，不跑全量/夜间/61b；耗时只报实测，不承诺节省。

## 交付

- `openspec/changes/reply-observer-skip-focus/`：proposal、必要 design、tasks、上述 delta；
- `docs/team/reports/P433-dev2.md`：结论、覆盖映射、旧路径删除点、红侧与未跑范围；
- `openspec validate --all`、该 change strict、`spec-refs.sh --check`、`section-select.sh --check`、账本禁令、`git diff --check`；
- 小步提交，通知 PM。随后由非作者独立审阅，PM 接受前不得 Apply。

## 边界

只写提案和报告；不改产品、测试、正式规格或 CI，不跑长测试，不合并、不归档、不发布。
