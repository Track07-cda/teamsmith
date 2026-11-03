---
id: V123
title: 指令瘦身第二片（P401：PM 与 worker 提示词）独立复验
agent: verify
category: verify
phase: verify
change: instruction-context-slimming
specs: init-skill
anchor: openspec/changes/instruction-context-slimming/specs/init-skill/spec.md
deltas: -
branch: task/V123-p401-verify
---

# V123 · P401 独立复验（非作者）

被验 `task/P401-instruction-apply-2-v2` @ `38ff1431`（作者 dev2）。在你自己的 checkout 上验，不接受作者数字。

## 一、必须独立证明（每条要有你自己的输出或反例）

1. **PM 提示词与已落地的 P396 一致**：默认是"正常完整回答 + 末行控制行"（`[[team-reply]]` / `[[team-reply:<标题>]]` 写作代码块字面量），由扩展发布；标记从终稿与 Pulse 消失；`team reply post` 只作手工回填/恢复。**不得**出现"先 post 再重复回答"、临时文件或 heredoc 作为默认步骤。按**渲染后的真实提示词**判断，不是看模板里有没有某个词。
2. **worker 提示按路线结算**：local 与 PM 指定的 remote 投递要分开描述，指向真实的 `templates/report.md.tmpl`，写清 assignment/安全/跨项目/报告/提交证据、三种合法收尾状态、lane/notify 恢复。**不得**再有"无条件 push/PR"的句子当作 local 的默认。
3. **行为零改动**：`team_build_prompt` 之外（模型/SID 选择、适配器路由、条件注入、launch/notify/runtime）在 `scripts/lib/cmd-agents.sh` 里逐行未变——请用 `git diff` 逐 hunk 判，不要只看函数名。
4. **红侧成立**：给 local 交付加回无条件 push/PR、删掉三种收尾里的一种、删掉 lane 例外条件，三种都要让对应断言变红；还原即绿。
5. **瘦身没有吞掉义务**：对比渲染前后，点名保留了哪四条写作职责、三种收尾、有界内联等待、后台收割、独立复验、授权边界；删的是重复而不是职责。

## 二、允许的命令

- `TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh --select 0b,6,13c,17,18b,19,39 </dev/null`（记录实际跑与没跑）
- `bash skills/teamsmith/tests/task-model-routing.sh --select init,dispatch,resume,preview`
- `openspec validate --all --strict`（`~/.cache/openspec-1.8.0/node_modules/.bin/openspec`）、`spec-refs --check`、`section-select --check`、`ledger-ban --names-file .pi/team/forbidden-names.txt`、`git diff --check`
- 自己渲染提示词（例如在临时项目里跑 dispatch 的 `--print`）对比，不要只读模板

## 三、边界

- 不跑全量 smoke；不改作者分支；不合并/归档/发布；不对真实项目跑 init。
- 结论写 `docs/team/reviews/V123-verify.md`，第 3 行必须是 `判定: **PASS**` 或 `判定: **NEEDS-CHANGES**`。缺陷给命令与输出尾，不给泛泛建议。
