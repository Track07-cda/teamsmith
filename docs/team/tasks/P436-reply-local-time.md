---
id: P436
title: 关键回复时间统一按本地时区显示
agent: dev3
category: code
phase: apply
change: -
specs: key-replies panel
anchor: openspec/specs/panel/spec.md
deltas: -
branch: task/P436-reply-local-time
---

# P436 · 修正关键回复的 UTC 显示不一致

## 现场与根因

`replies.mjs` 以 ISO UTC 存储 `at`，保持不变。`layout.ts` 的 `replyTimeLabel()` 已把列表时间转为本地 `MM-DD HH:mm`，但：

- `replySummaryBlock` 直接拼接 `entry.at`；
- `replyViewerBlock` 直接把 `data.at` 填入 `replyDeclared`。

所以同一回复在列表是本地时间，在首页摘要/详情却是 UTC。

## 要做的

1. 只改显示层，复用一条时间格式化路径，不改存储、journal、API 数据或 CLI 契约。
2. 列表、首页最新回复和详情都按**阅读者本地时区**显示。列表/摘要保持紧凑 `MM-DD HH:mm`；详情显示完整本地日期时间并带实际偏移（例如 `2026-11-09 17:19 +08:00`），不得硬编码 +08:00。
3. 非法/缺失时间仍按现有降级，不崩溃、不显示 `Invalid Date`。
4. 文案不增加解释性括注或时区说明段落。

## 验收

- 用同一 UTC 输入在至少两个 `TZ` 下验证本地转换与偏移；证明摘要和详情不再直接显示原始 `…Z`。
- 保留列表原有显示，详情/摘要/列表对应同一时刻。
- 更新相关面板测试，至少一条反向改坏：恢复直接拼接原始 `at` 必须红。
- 修改 panel 源码后按钉住工具链重建提交的 `panel.js`。
- 跑相关面板/关键回复选段、`panel-strings.mjs`（若触及文案）、结构检查、账本禁令和 `git diff --check`；不跑全量/夜间/61b。

## 交付与边界

只改 panel 显示与对应测试/构建产物，报告 `docs/team/reports/P436-dev3.md`，提交本地分支并通知 PM。之后由非作者复验；不合并、不发布。
