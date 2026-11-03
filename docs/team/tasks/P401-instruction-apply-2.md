---
id: P401
title: 指令瘦身 Apply 第二片：PM 启动提示词与 worker 席位提示
agent: dev2
category: code
phase: apply
change: instruction-context-slimming
specs: init-skill
anchor: openspec/changes/instruction-context-slimming/specs/init-skill/spec.md
deltas: init-skill
branch: task/P401-instruction-apply-2
---

# P401 · 第二片：两份提示词

第一片（P400）已合入 main：受管块写入器、AGENTS 短宪章、"规则写在标记外"两处提示都已完成，`tasks.md` 的 3.1–3.6 属它。

**本片只做 tasks.md 的 `2.2`（PM 启动提示词）与 `2.3`（worker 席位提示）及其红侧控制（4.1–4.3）。** `2.4`（SKILL/参考手册分工）与 `2.5`（参考手册纠错）留给下一片，别在本片改 `SKILL.md`、`references/*.md`——同批改会互相覆盖。

先读 `design.md` 的编辑映射与 `tasks.md` 2.2/2.3/4.1–4.3 原文，按它做。

## 必须成立

1. **PM 提示词自足但不重复**：首轮动作、续跑、PM 专属决定、授权边界、独立复验、后台收割与"有界内联等待"都要在；细节流程指向既有手册，不重抄。四条写作职责保留。
2. **回复义务对齐已落地的 P396**：默认是"正常完整回答 + 末行控制行（`[[team-reply]]` / `[[team-reply:<标题>]]`，写作代码块里的字面量）"，由扩展发布；标记从最终 transcript 与 Pulse 消失；`team reply post` 只作手工回填/恢复；**不得**出现"先 post 再重复回答"、临时文件或 heredoc 步骤。
3. **worker 提示**（`team_build_prompt` 里的提示文本）：交付步骤要区分 local 与 PM 指定的远端投递，指向真实的 `templates/report.md.tmpl`，写清 assignment/安全/跨项目/报告/提交证据、三种合法收尾状态、以及 lane/notify 的恢复方式。**只改提示文本**：模型/SID 选择、适配器路由、条件注入、launch/notify/runtime 行为一律不动。
4. **红侧必须能变红**（4.3）：给 local 交付加回无条件的 push/PR、删掉三种收尾里的一种、删掉 lane 例外条件——每种都要让对应断言变红，还原即绿。不要新增 prose 守卫框架。
5. **复用既有夹具**：强化 smoke §6 已有的渲染提示用例（local + 有代表性的 remote），并按 4.4 跑 `task-model-routing.sh --select init,dispatch,resume,preview` 证明类别策略/记录模型与 SID 恢复/init 拒绝与写入/预览边界都没变。

## 验收（自己跑，贴 rc 与输出尾）

- `TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh --select 0b,6,13c,17,18b,19,39 </dev/null`（记录实际执行与未跑的键；FAST 跳过要说明）
- `bash skills/teamsmith/tests/task-model-routing.sh --select init,dispatch,resume,preview`
- `openspec validate --all --strict`（用 `~/.cache/openspec-1.8.0/node_modules/.bin/openspec`）、`spec-refs.sh --check`、`section-select.sh --check`、`ledger-ban.sh --names-file .pi/team/forbidden-names.txt`、`git diff --check`
- 4.3 的三条变异各自红/还原绿，贴命令与输出
- 报告写 `docs/team/reports/P401-dev2.md`，点名哪些 tasks.md 条目做了、哪些没做；提交推分支；通知 PM

## 边界

- 只改：`templates/pm-prompt.md.tmpl`、`scripts/lib/cmd-agents.sh` 里的提示文本、以及 `smoke.sh` §6/§13c 等相关断言与 fixtures。
- 不改产品行为代码、不改 `SKILL.md`/`references/`、不跑全量 smoke、不对真实项目跑 init、不合并/归档/发布。
