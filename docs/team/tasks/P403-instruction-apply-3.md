---
id: P403
title: 指令瘦身 Apply 第三片：SKILL 与参考手册的分工与纠错
agent: dev
category: code
phase: apply
change: instruction-context-slimming
specs: init-skill
anchor: openspec/changes/instruction-context-slimming/specs/init-skill/spec.md
deltas: init-skill
branch: task/P403-instruction-apply-3
---

# P403 · 第三片：SKILL 与参考手册

前两片已合入 main：P400（受管块写入器 + AGENTS 短宪章）、P401（PM 与 worker 提示词）。**本片做 `tasks.md` 的 `2.4` 与 `2.5`**：`SKILL.md` 收成索引与职责、详细 runbook 收进既有 references、`references/` 的纠错落到既有家。

先读 `design.md` 的编辑映射与 `tasks.md` 2.4/2.5 原文，按它做；不要另立设计。

## 必须成立

1. **SKILL 只留索引与职责**：命令索引、角色入口、指向 references 的深读表保留；**两处规格点名的声明面必须原样存在**：① 双门禁分工（每次改动判正确性、发布前判性能，附可复制命令）；② `## Agent adapters` 小节 + frontmatter `description` + 深读表那一行，且所有非 Pi 提法保留冻结 seam 的措辞。
2. **详细 runbook 归位**：`authorization`、`gate`、`migration`、`openspec`、`protocol`、`workflows` 等既有 references 各自承担详细流程；`SKILL.md` 与新项目装配（`workflows.md` §A）只留交叉链接，不再当第二个详细家。
3. **纠错落到既有家**（2.5 点名的那几处）：
   - `references/protocol.md` §9 的容量口径补齐 `MemAvailable`、临时根可用性、temp/worktree 的字节与 inode 下限，与派单契约一致；
   - `references/migration.md` §2 "跑一次 `team init`（或 `team bootstrap`）" 与 §2c "下一次 `team init`/`team bootstrap` 会原地重写标记"两处误导性说法改正——既有合法契约时 bootstrap **不会**跑 init 的 AGENTS 写入器；
   - 既有项目刷新契约放在 `migration.md` 的既有家（不改写到别处）。
4. **不新增门禁/不新增文档质量检查**：不许加字数门禁、prose 评分或第二个文档家。

## 验收（自己跑，贴 rc 与输出尾）

- `openspec validate --all --strict`（用 `~/.cache/openspec-1.8.0/node_modules/.bin/openspec`）、`spec-refs.sh --check`、`section-select.sh --check`、`ledger-ban.sh --names-file .pi/team/forbidden-names.txt`、`git diff --check`
- `TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh --select 0b,1b,18b,19,39 </dev/null`（记录跑与没跑；这些段里有 SKILL 解析、协议段与文档一致性断言）
- 报告里给一张**逐条对照**：哪条规则从 `SKILL.md` 移到了哪个 reference（或删掉的理由），以及两处声明面仍在的证据（贴 grep 输出与行号）。
- 报告 `docs/team/reports/P403-dev.md`，提交推分支，通知 PM。

## 边界

- 只改 `skills/teamsmith/SKILL.md`、`skills/teamsmith/references/*.md`、`templates/PROTOCOL.md.tmpl` 与必要断言。
- 不改产品行为代码、不改 P400 的写入器、不改 P401 的提示词、不跑全量 smoke、不合并/归档/发布。
