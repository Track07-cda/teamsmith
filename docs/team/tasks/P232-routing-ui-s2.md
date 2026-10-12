# P232 · task-model-routing S2：面板侧（类别编辑 + 策略/实际分离）

task: P232
agent: dev2
phase: apply
category: code
change: task-model-routing
specs: panel
deltas: panel
branch: task/P232-routing-ui-s2
deps: P228（S1 核心已独立复验 PASS，V19 第六轮；私有集成 tip `8bea13e7e325b10bb4032fcc9cb59fe4d7fd3` 的 handoff 由 PM 记录）

## 范围

按 `openspec/changes/task-model-routing/tasks.md` §6（6.1–6.4）实现**面板侧**：类别行编辑（任务类别 → 模型映射）、PM 策略与「实际派单记录」的读面分离、移除席位/默认模型的旧交互与标签、旧配置的就地诊断（只指向 CLI `upgrade-models`，不在面板里实现升级或重启）。逐条以该 §6 的文本为准，本条不重述。

写边界：只碰 §6.1 允许的 UI 所有权（`panel/**`、bundle、strings 等）。**不碰** S1 的文件（`scripts/lib/{common,cmd-config,cmd-agents,cmd-watch,cmd-status,cmd-death}.sh` 等）、不碰 `templates/**`、`references/**`、`SKILL.md`、`smoke.sh` 的既有段、canonical specs。需要 S1 侧改动才能修的问题写 `BLOCKED:` 给 PM，不越界改核心。

## 前置（自己核对，不凭报告）

- 你的输入基线是 PM 记录的 S1 私有集成 tip（`8bea13e7e325`）之上；先在任务分支里 `git merge` 该 tip 或按 PM 的 handoff 记录取基线，并在报告里写明你实际用的输入 tip。
- S1 已复验 PASS 的范围：配置/派单/续跑/类别/读证据；S2 不得削弱它（改完跑 §6.4 要求的既有 UI 前门）。

## 验收

```bash
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
bash skills/teamsmith/tests/section-select.sh --paths <你实际改动的路径>
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check && git status --short
```
外加 §6.3/§6.4 要求的真 tmux 面板取证（类别选择器、PM 编辑、实际派单、类别被删后的策略 vs 保留恢复、陈旧指纹、旧配置拒绝、无 spawn/重启；渲染帧与 CLI 日志/配置哈希成对；红侧：把 CLI 路由改成席位写入、或把未来模型当实际显示 → 守卫必须红，还原后绿）。

## 交付

`docs/team/reports/P232-dev2.md`（改动清单、逐条 §6 对应、命令与 rc、渲染帧与哈希、未跑/跳过项单独记）、证据包按 D94 放仓外 `pm-skills-ledger/team/reports/P232-dev2/`；不合并、不推送、不勾你没做完的项；做完 `team notify pm`。之后由**未写过本任务**的席位独立复验。
