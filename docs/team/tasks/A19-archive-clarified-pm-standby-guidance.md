---
id: A19
title: 同步已核对的 PM 待命文字要求并收尾
agent: dev2
deps: P510,V204
category: docs
phase: archive
change: clarify-pm-standby-guidance
specs: init-skill
deltas: -
branch: task/A19-archive-clarified-pm-standby-guidance
---

# A19 · 仅原生同步本次已批准的待命文字要求

实现作者 dev-bob；V204 的独立核对 `938b22c3`、合并版 `f6a32733d44d` 已接受 `dad295e20d8f1ccbbde512b4aa247e1254613c37`。实施记录 `docs/team/reviews/P510.md`，完整评估 `docs/team/reports/V204-verify.md`，未解决项 0；本次文字改动未执行行为、模型或现有项目采用。PM 已按 D241 在 D270 记录可逆小范围确认。先读 AGENTS、本人线程、归属、本简报与原生 `archive` 流程，检查本地规划与确认的清单 7/7、兄弟全部结束；工具 `team change status clarify-pm-standby-guidance` 可以只报本任务自己。若有其它阻塞或已存在目标目录，保留现场报告，不绕过。

只允许 `openspec` 原生归档。使用 `/var/tmp` 自建私有试做根，先从实际分支固定原件试一次 `openspec archive -y clarify-pm-standby-guidance`，核它只会将五份工件原样移动，并只把 `openspec/specs/init-skill/spec.md` 的 **Installed team instructions separate shared rules from role procedures without losing required duties** 按已准 delta 同步。保留 Purpose、其余需求、先前六个场景与批准处的唯一历史限定；只生成这一目标。试做一致才在自己的任务分支正式执行一次同命令。若原生工具仅在明确位置变动 `## Requirements` 周围或目标块边缘空行，保留差异、列确切字节供 PM 判断，不改工具、正文或隐去差异；其余不符应阻塞。不得手工移动/同步或用跳过参数。产品、模板、当前项目、真实运行状态及并行标签变更均不写。

最终执行现有普通 `openspec validate --all`、`bash skills/teamsmith/tests/spec-refs.sh --check`、账本隐私检查、`git diff --check` 与精确文件/`cmp` 核对，记录实际版本和回执；不重跑已知含其余长条款的全仓严格检查，不运行产品行为、模型、生成、安装或发布。仅另写 `docs/team/reports/A19-dev2.md`。本人任务分支小步本地提交 A19 / `Agent: dev2`；不推送或合并，自建临时原件等接收后清，不触他人路径。