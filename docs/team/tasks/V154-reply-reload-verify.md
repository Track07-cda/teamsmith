---
id: V154
title: 关键回复 reload 锁泄漏修复独立复验
agent: dev3
category: verify
phase: verify
change: -
specs: key-replies
anchor: openspec/specs/key-replies/spec.md
deltas: -
branch: task/V154-reply-reload-verify
---

# V154 · 非作者复验 P446

候选 `82897271`，作者 dev2。你未参与实现。重点不是接受“超时消失”，而是验证删除能力记录后锁真的释放。

## 独立验证

1. 在私有真实 Pi/tmux 中复跑 `reply-capture-real.sh --select=lifecycle` 与完整套件：两个原 reload 超时恢复，marker 清理、保存、身份和 doctor 不变。
2. 直接执行 publish → remove → publish，证明 remove 不再清理不存在的 temp、锁和目录描述符正确关闭；恢复旧 temp 生命周期后应按名失败/重新超时，恢复后绿。
3. 运行 `remind-tool-node.mjs`、`key-replies.sh --select workflow`、`smoke.sh --select 62,67` 和结构/账本检查。保留原始日志，未跑全量/夜间/61b。

报告 `docs/team/reports/V154-dev3.md`，先给 PASS / NEEDS-CHANGES，附自己的命令、原始事件/锁证据和未跑范围。只提交报告，不改实现、不合并、不发布。

**在 V153 完成后使用 dev3 席位。**
