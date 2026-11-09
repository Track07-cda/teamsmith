---
id: V141
title: 关键回复诊断输出修复独立复验
agent: dev3
category: verify
phase: verify
change: -
specs: key-replies
anchor: openspec/specs/key-replies/spec.md
deltas: -
branch: task/V141-reply-diagnostics-verify
---

# V141 · 非作者复验 P437

冻结候选 `8c5270a6`，作者 dev。你未参与实现。阅读 P437 报告和实际 diff；作者数字不是结论。

## 独立验证

1. 在自己的私有 Pi/tmux 与证据根中运行 `reply-capture-real.sh`，重点取得：
   - `recover-skip:ineligible` 写入 diagnostics.log；
   - raw PTY、最终帧、print stdout/stderr 均无 `[team-reply]`；
   - 正常带标记回复仍清理并 saved，回复存储恰增一条。
2. 在自己的源码副本恢复 `process.stderr.write(line)`，同一终端断言必须红；恢复后绿。
3. 运行 `reply-capture.mjs --all` 和 `key-replies.sh --select workflow`，保留日志；确认发布资格、绑定、writer、存储和状态机没有变化。
4. 检查扩展不再有常规诊断直写终端；doctor/runtime 仍能解释不可用状态。主检出任务书的一条账本禁令已由 PM 改为占位符，不作为产品缺陷。

## 交付与边界

`docs/team/reports/V141-dev3.md`，先给 PASS / NEEDS-CHANGES，附自己的命令、原始输出和日志路径。只提交报告，不改实现，不合并、不发布。可补结构检查；不跑全量/夜间/61b，不消耗真实远端模型，不接触真实团队会话。
