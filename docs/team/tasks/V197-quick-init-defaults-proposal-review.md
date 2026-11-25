---
id: V197
title: 独立审阅新项目默认模型和任务类型方案
agent: dev3
category: verify
phase: opsx-verify
change: quick-init-model-defaults
specs: init-skill
deltas: -
branch: task/V197-quick-init-defaults-proposal-review
---

# V197 · 核对首次初始化的正式方案

作者 dev2；冻结交付 `315ca5d3798a0313557f6affcfc68c46630205f2`，独立干净检出 `/var/tmp/p499-review-315ca5d3.sIhrYj`。读本席位线程、归属、D268、P499 任务与固定树原生工件。用户要求直接初始化三个任务类型；Pi 用户设置里的默认模型是缺省值。方案尚未实施，本单唯一写入 `docs/team/reports/V197-dev3.md`，给 ACCEPTED 或 REWORK 与最小修改，不改候选。

1. **最短路径与真实配置边界。** 对照 `team init` / `bootstrap` 实际配置发现与写入路径，重点查首次、已有缺项、已有合法值、显式配置路径、旧配置与 `init --force` 会不会互相串线。两条首次入口共用取值，明确 `bootstrap --print` 有值显示实际拟用值、没值给下一步且不写入、显式无效不回退。判断是否只需把已解析的两值交给现有 `init`（重复使用已有格式校验不等于重复读 Pi），避免为一次读取另造外部接口、环境开关或第二条写入路径。
2. **取实际 Pi 用户设置，而非猜模型。** 仅从已保存的用户设置取字段，考虑 `PI_CODING_AGENT_DIR`、无 Pi 可执行文件、无法读取、嵌套 model ID 和思考级别后缀；用现有模型校验与启动代码确认值会不会改变或误解为另一个模型。只依赖已有运行时，不读凭据、真实项目/信任、不启动 Pi；两项全显式或旧项目不尝试读取。确定不重新实现 Pi 启动选择，默认缺失不因为试图输出占位命令而让新项目半写。
3. **项目能直接用，不扩大权限。** 确认三种初始类型、显式整张映射或仅指定 PM、现有派单与续跑约束和已写项目的稳定性；检查 README/技能/两份帮助当前遗漏点、规格中旧必填句是否已覆盖，报错能只动当前场景。不得把用户说“不让指定”读成移除命令行配置或取消非作者验收。
4. **定点验收可执行。** 核 `task-model-routing.sh --select init` 的依赖、函数与现有 `init-legacy-proceeds` 检查。判断能否复用同组现有场景而不重跑 §61 或其它组。样本要通过实际无参数入口读取默认、预览同写入、部分显式与全显式、真实无写入及重入。独立对照应仅重用最短的默认用例/命令，不为一个错误路径再次跑整组；现有检查不要因为扩范围而再叠一轮。指出最少必要的修正。用户个人设置和现有项目均不动。

只在固定检出做一次 `openspec validate quick-init-model-defaults --type change --strict --no-interactive`（`PATH="$HOME/.bun/bin:$PATH" TMPDIR=/var/tmp CI=1 OPENSPEC_TELEMETRY=0`），方案的规格引用回执引用 P499，报告保存实际命令/退出值。报告改动用 `git diff --check`、暂存用 `git diff --cached --check`。不运行 `team init`、`bootstrap`、模型、实际测试选段、构建或完整测试；不要把结构通过当成行为通过。报告本地小提交（含 V197、`Agent: dev3`），不推送、合并、归档或接手实现。