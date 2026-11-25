---
id: P500
title: 实施新项目默认模型与预置任务类型
agent: dev-bob
category: code
phase: opsx-apply
change: quick-init-model-defaults
specs: init-skill
deltas: -
branch: task/P500-quick-init-model-defaults-apply
---

# P500 · 实现已独立审阅的首次初始化方案

先读本工作树 AGENTS、本人线程、本任务、OWNERSHIP；按原生 apply 流程读 `openspec/changes/quick-init-model-defaults/` 的全部工件。固定方案 `4cd418c15b31b9b3af4c11ff7f2042ed7b1f9c66` 已有 `docs/team/reviews/quick-init-model-defaults-proposal.md` 的 ACCEPTED（独立报告 `4f3d5eb6`）。D268 与方案定了范围；遵循原生 tasks 1.1–1.4，验证项 2.1 留给非作者，不提前勾选或声称已验收。

## 明授写集

- `skills/teamsmith/scripts/lib/{cmd-project,cmd-bootstrap}.sh`：只做已接受的项目路径判定、模型默认、预览、CLI 提示和原有两参数交接。可以新增一个小 `skills/teamsmith/scripts/pi-saved-model.mjs` 纯读取函数/入口（若现有方式更简单则不用新文件）；复用现有 JS 和模型校验。不复制 Pi 启动选择、不加依赖、配置键、文件读权限限制、测试开关。原流程照常保留依赖/插件检测、旧迁移和已有配置；`common.sh` 先只读，确实须传递现有发现的路径信息且现有值无法用时，报告具体差异给 PM，不在原定义之外增加第二个发现入口。
- `skills/teamsmith/scripts/strings/help.{zh,en}.tsv` 仅两个命令；`README.md`、`skills/teamsmith-init/{SKILL.md,references/bootstrap.md,templates/bootstrap-prompt.md.tmpl}`、`skills/teamsmith/{SKILL.md,references/workflows.md,references/config.md,references/migration.md,templates/config.sh.tmpl,templates/pm-prompt.md.tmpl}` 限与首跑选模型直接矛盾的句子与例子；保持初始化技能的 100 行上限，不加另一份流程说明。非模型事项、已批准的 PM 自主推进条款和旧项目迁移不变。
- 定点复用 `skills/teamsmith/tests/task-model-routing.sh` 现有 `init` 组；仅必要时调整 `skills/teamsmith/tests/lib/model-routing-flips.py` 的原 `init-legacy-proceeds`，不能以改坏测试形参来使旧检查报错。不增加测试套件、通用入口、全仓隔离机制或 §61 段。
- 原生 change 的 `tasks.md` 仅勾选实施 1.1–1.4，及本人 `docs/team/reports/P500-dev-bob.md`。不改其它方案文件或正式规格。只在本人工作树下提交，无关行和旧记录不动。

优先把模型读取及两个入口提交，再提交说明与既有测试替换。新项目默认值只取 Pi 用户设置保存值；显式值优先，先判路径及现有配置，不触碰真实 Pi、主工作树设置、用户正在初始化的项目、全局安装、Pulse 或团队状态。不得把已配置或路径无效当成新项目。只减少选默认时读取；不要为“零读取”删旧插件检测。文件和目录路径、文案、无写入及可选思考档的准确边界见已接受设计，不因容易实现缩减。

## 作者只执行短静态检查

```sh
export PATH="$HOME/.bun/bin:$PATH" TMPDIR=/var/tmp CI=1 OPENSPEC_TELEMETRY=0
# 对所有实际改动的 .sh 做 bash -n；新增 mjs 时 node --check；若改了旧对照的 Python，做不落常驻文件的语法检查。
git diff --check
git diff --cached --check
```

只做实际修改面静态核对与报告所需账本检查。此阶段不运行 `team init`、`bootstrap`、`--select init`、全量、实际模型、依赖安装或任何上线操作；独立验证者在固定候选后集中运行原生 2.1 一次与短反例，既有选段不重复。报告先写实现与兼容结果，附实际提交、静态命令和退出值、将来用哪条命令和读出来的哪项值验收；没有运行的行为均明列。只本地小步提交（Conventional Commits、P500、`Agent: dev-bob`），不推送、合并、归档。遇需扩大路径或改变用户行为的冲突就留下证据，不自行改方案。
