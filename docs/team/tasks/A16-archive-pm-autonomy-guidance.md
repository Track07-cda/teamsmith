---
id: A16
title: 同步 PM 自行推进的说明要求并收尾
agent: dev2
category: docs
phase: archive
change: pm-autonomy-guidance
specs: init-skill
deltas: -
branch: task/A16-archive-pm-autonomy-guidance
---

# A16 · 只同步已接受的文字要求

P488 实施 dev-bob；V188 非作者 dev3 的 `e0a4eb1f` 接受合并版 `d26f0ef60b561011e911ecf4683345a3e8123e35`，清单 3/3。D266 本版授权、D241 与本次窄范围收尾确认见主检出 `DECISIONS.md`。沿 A15 用 OpenSpec 1.16 的 list/status/instructions 核根和 3/3，先在本人独有 `/var/tmp` 普通副本试做 `openspec archive -y pm-autonomy-guidance`；预览无业务差异后在授权任务分支实际执行一次。不使用手工合并/移动、硬链接或跳过参数。仅允许五份工件原样移动、`openspec/specs/init-skill/spec.md` 同步已核一条目标要求和本席位报告。对照目标外正文及所有可执行文件不变、原场景仍在；如工具只收掉目标处连续空行按 A12 记录，其余意外差异不继续。

只核普通 OpenSpec 结构、原引用检查、最终报告公开文件检查和 `git diff --check`，记录真实输出/警告/退出码；不用全仓 strict，不重做文案审阅、渲染、规则读取、模型、产品或发布测试，不改当前项目、配置、模型或版本，不推送。不重跑已接受证据。报告 `docs/team/reports/A16-dev2.md`，本地提交，保留本次试做原件至 PM 收取。