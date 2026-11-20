# 帮助测试与性能测量分开 · 提案审阅

状态：**退回两处定点修订**，未批准实施。

verify 在固定候选 `79cd6a73` 的独立检出完成审阅（`8f2901f9`、OpenSpec 1.16.0 单 change strict 通过）。CLI 私有副本和退出状态设计成立，真实性能测量保留。接受其两项必须修正的发现：

1. `tasks.md` 的故障副本必须以包含 `skills/teamsmith/` 的根为 `TEAM_HELP_SURFACE_TREE`。当前写法会拼出两层 `skills/teamsmith`，在真正调用 CLI 前就退出；不能拿这个退出冒充原计划的两种失败。
2. `verification` delta 中 *The named replacement cannot hide a lost CLI or renderer assertion* 的封闭例外清单也要加本次单一 perf 替换；其它原文和遗漏检查应失败的判据不变。

返修 `2f162fc3` 已交付；PM 核对只有两处方案文件和作者回执变动，未改实现。交原审阅者在新固定检出定点复看。不再做计时归因或运行帮助、性能、完整测试。不改 P481 的历史 705 秒无法分账结论。
