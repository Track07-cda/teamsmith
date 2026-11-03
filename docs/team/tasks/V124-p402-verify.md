---
id: V124
title: P402（init 渲染取契约值）独立复验
agent: verify
category: verify
phase: verify
change: instruction-context-slimming
specs: init-skill
anchor: openspec/changes/instruction-context-slimming/specs/init-skill/spec.md
deltas: -
branch: task/V124-p402-verify
---

# V124 · P402 独立复验（非作者）

被验 `task/P402-init-render-from-config` @ `5482e8a8`（作者 dev）。

## 背景（PM 实测，已被作者修掉）

本项目 `.pi/team/config.sh` 有 `TEAM_SESSION="teamsmith"`、`TEAM_AGENTS="dev verify dev2 dev3 dev-bob"`。旧代码在**既有契约**下仍用 `session="${session:-$project}"`、`agents="${agents:-dev verify}"`，于是裸 `team init` 把受管块渲染成 `pm-skills:pm` 与 `dev verify`——受管块是 agent 读到的"PM 在哪、有谁"，写错就是文档撒谎。

## 必须独立证明

1. **复现修复**：自己造一个有契约（session/agents 都非默认）的临时项目，跑**裸** `team init --no-skills`（不传 `--session`/`--agents`），受管块的会话名与名册必须是契约值。用 `sed -n` 打印那两行，不要只说"通过"。
2. **红侧**：把回落顺序改回"目录名/硬编码默认"（在你的私有副本上），同一断言必须变红；还原即绿。贴两次命令与输出。
3. **对照组**：无契约的新项目裸 init 仍写目录名与默认名册（两条路径没被合并）。
4. **不误伤**：显式 `--session`/`--agents`/`--docs`/`--pm-model` 仍然优先；`--force` 重渲染的语义未变；`TEAM_GATES` 为空时不被检测结果顶替（作者加了一个 `gates_from_config` 分支，请判断它是否会把"契约里写了空门禁"错当"未配置"）。
5. **范围**：`cmd-project.sh` 之外没有产品行为改动；`openspec/changes/instruction-context-slimming/specs/init-skill/spec.md` 的那条 delta 与新行为一致（读全文，不只看 diff 那一行）。

## 允许的命令

- `bash skills/teamsmith/tests/install-shape.sh`（完整矩阵）与 `bash skills/teamsmith/tests/install-shape.sh flip`
- `bash skills/teamsmith/tests/smoke.sh --select 17 </dev/null`
- `openspec validate --all --strict`（`~/.cache/openspec-1.8.0/node_modules/.bin/openspec`）、`spec-refs --check`、`section-select --check`、`ledger-ban --names-file .pi/team/forbidden-names.txt`、`git diff --check`
- 你自己的临时项目（不要在 pm-skills 主检出上跑 init）

## 边界

- 不跑全量 smoke；不改作者分支；不合并/归档/发布。结论写 `docs/team/reviews/V124-verify.md`，第 3 行是 `判定: **PASS**` 或 `判定: **NEEDS-CHANGES**`。
