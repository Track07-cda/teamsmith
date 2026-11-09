---
id: V143
title: 模型配置变化与回复捕获修复独立复验
agent: dev2
category: verify
phase: verify
change: -
specs: key-replies
anchor: openspec/specs/key-replies/spec.md
deltas: -
branch: task/V143-reply-config-change-verify
---

# V143 · 非作者复验 P438

冻结候选 `4363501c`，作者 dev。你未参与实现。阅读 P438 报告和实际 diff；作者数字不是结论。

## 独立验证

1. 在自己的私有 Pi/tmux 与证据根运行 `reply-capture-real.sh`：通过产品 CLI 修改隔离项目任务模型，确认配置字节和 inode 变化后，带标记回复仍清理并 saved，runtime/doctor 仍 ready。
2. 在自己的源码副本恢复 configHash/configIno 身份判据与 doctor 哈希比较，同一真实 CLI 修改必须红；恢复后绿。不得只调用作者旋钮。
3. 核对至少一个真实身份边界仍拒绝：root/state/session/process/pane 任一项变化；不能被“忽略普通配置”带成全部忽略。
4. 运行 `reply-capture.mjs --all`、`key-replies.sh --select workflow`、doctor 选段 `smoke.sh --select 1,2,3`，保留完整日志。
5. 检查配置路径、普通文件、属主、符号链接、主检出和写入面判据没有放宽；未改模型路由或捕获归属。

## 交付与边界

`docs/team/reports/V143-dev2.md`，先给 PASS / NEEDS-CHANGES，附自己的命令、原始输出和日志路径。只提交报告，不改实现，不合并、不发布。可补结构检查；不跑全量/夜间/61b，不接触真实团队会话或真实模型凭据。
