---
id: V125
title: 指令瘦身第三片（P403：SKILL 与参考手册）独立复验
agent: verify
category: verify
phase: verify
change: instruction-context-slimming
specs: init-skill
anchor: openspec/changes/instruction-context-slimming/specs/init-skill/spec.md
deltas: -
branch: task/V125-p403-verify
---

# V125 · P403 独立复验（非作者）

被验 `task/P403-instruction-apply-3` @ `5bba516e`（作者 dev）。

## 必须独立证明

1. **两处声明面仍在**（`design.md`/提案点名的硬性要求，按**渲染与最终文件**判）：
   - `SKILL.md` 与 `references/protocol.md` 都还写明双门禁分工（每次改动判正确性、发布前判性能），并给可复制命令；正确性门禁里不出现墙钟红线。
   - `SKILL.md` 的 `## Agent adapters` 小节、frontmatter `description`、深读表那一行都在，且**所有非 Pi 提法仍带冻结 seam 措辞**（逐个点名，不要只看有没有那两节）。
2. **没有丢职责**：随机抽三条原来写在 `SKILL.md` 的流程（你自己挑，例如授权、门禁锁、跨项目会议），确认它现在在**既有** reference 里有等价的、可执行的描述，而不是被删或指向不存在的文件。给出你抽的三条与命中行号。
3. **纠错确实改对**（不是改个措辞）：`references/migration.md` 里"既有合法契约时 bootstrap/init 不会重跑 AGENTS 写入器"的说法与**代码实际行为**一致——请用你自己的临时项目实测一次 `bootstrap`（非 init）确认；`references/protocol.md` §9 的容量口径与派单打印的容量行字段一致（对照 `team dispatch --print` 的输出）。
4. **PROTOCOL 模板仍是可用的摘要**：`templates/PROTOCOL.md.tmpl` 渲染后仍给出日常 OpenSpec 命令与归档命令（smoke §19 断言的那几条），且没有把详细 runbook 复制进来。
5. **红侧**：把双门禁分工那句删掉、或把非 Pi 提法的 seam 措辞改掉、或让某条流程失去落点，对应断言必须变红；还原即绿。

## 允许的命令

- `TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh --select 0b,1b,14b,18,18b,19,39,64 </dev/null`
- `bash skills/teamsmith/tests/spec-refs.sh --check`、`section-select.sh --check`、`ledger-ban --names-file .pi/team/forbidden-names.txt`、`openspec validate --all --strict`（`~/.cache/openspec-1.8.0/node_modules/.bin/openspec`）、`git diff --check`
- 你自己的临时项目（bootstrap 实测），不要在 pm-skills 主检出上跑

## 边界

- 不跑全量 smoke；不改作者分支；不合并/归档/发布。结论写 `docs/team/reviews/V125-verify.md`，第 3 行 `判定: **PASS**` 或 `判定: **NEEDS-CHANGES**`。
- 这一片之后整个 change 要进整体独立复验，所以**漏掉的职责现在点出来比以后补便宜**。
