# 帮助测试与性能测量分开 · 提案审阅

状态：**ACCEPTED**，允许按下列范围实施。接受 `2f162fc3`；非作者最终复核 `c11f9624`，两处关闭，单变更 strict 与差异检查均退出 0。

verify 在固定候选 `79cd6a73` 的独立检出完成审阅（`8f2901f9`、OpenSpec 1.16.0 单 change strict 通过）。CLI 私有副本和退出状态设计成立，真实性能测量保留。接受其两项必须修正的发现：

1. `tasks.md` 的故障副本必须以包含 `skills/teamsmith/` 的根为 `TEAM_HELP_SURFACE_TREE`。当前写法会拼出两层 `skills/teamsmith`，在真正调用 CLI 前就退出；不能拿这个退出冒充原计划的两种失败。
2. `verification` delta 中 *The named replacement cannot hide a lost CLI or renderer assertion* 的封闭例外清单也要加本次单一 perf 替换；其它原文和遗漏检查应失败的判据不变。

返修只修上述两处及作者回执；原审阅者确认两个样本从正确目录进入、本次例外没有扩大。只继续替换一次帮助测试内的测量；真实测量和其他检查不变，独立者随后执行一次三样本行为验证。不改 P481 的历史 705 秒无法分账结论，也不宣称真实测量全程无项目写入。
