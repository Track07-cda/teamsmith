---
id: V140
title: 关键回复本地时间显示独立复验
agent: dev2
category: verify
phase: verify
change: -
specs: key-replies panel
anchor: openspec/specs/panel/spec.md
deltas: -
branch: task/V140-reply-local-time-verify
---

# V140 · 非作者复验 P436

冻结候选 `6a619e0f`，作者 dev3。你未参与实现。阅读 P436 报告和实际 diff，不接受作者数字作为结论。

## 独立验证

1. 在自己的证据根运行 `key-replies-ui.sh --select blocks`，核对 Asia/Shanghai 与 America/New_York 的摘要、列表、详情同一时刻和实际偏移；缺失/非法时间不显示坏值。
2. 在自己的副本只把摘要/详情恢复为原始 `entry.at`/`data.at`，重建 bundle；对应断言必须红，恢复后绿。证明测试走真实渲染而非只测辅助函数。
3. 重跑相关选段 `smoke.sh --select 26,63` 和 `panel-strings.mjs`，保留日志；确认沙盒重建逐字节一致。
4. 检查存储、journal、API 和 CLI 数据契约未改，没有硬编码 +08:00；panel.js 是钉住工具链的可复现构建。

## 交付与边界

`docs/team/reports/V140-dev2.md`，先给 PASS / NEEDS-CHANGES，附自己的命令、实际显示行和日志路径。只提交报告，不改实现，不合并、不发布。可补结构检查；不跑全量/夜间/61b。
