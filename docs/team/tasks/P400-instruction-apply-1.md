---
id: P400
title: 指令瘦身 Apply 第一片：AGENTS 短宪章 + init 只动 Teamsmith 章节并提示自定义规则写在标记外
agent: dev
category: code
phase: apply
change: instruction-context-slimming
specs: init-skill
anchor: openspec/changes/instruction-context-slimming/specs/init-skill/spec.md
deltas: init-skill
branch: task/P400-instruction-apply-1
---

# P400 · 第一片：受管块与 init 的边界

依赖已就绪：P393、P396 的指令改动已在 main，`openspec/changes/instruction-context-slimming/` 提案已合入并被 D218 接受。**先读 `openspec/changes/instruction-context-slimming/{proposal,design,tasks}.md` 与 `specs/init-skill/spec.md`，按它实现，不要另立设计。**

本片只做 `tasks.md` 里属于"受管块与 init 边界 + AGENTS 短宪章"的那几条（你自己在报告里点名做了哪几条编号）。其余片（PM 提示词瘦身、SKILL/参考手册分工、worker 席位提示）不在本片。

## 必须成立的行为（每条都要有会变红的断言）

1. **更新边界**：`team init` 只替换 `<!-- teamsmith:begin -->` 与 `<!-- teamsmith:end -->` 之间的内容；标记外的所有字节（章节、项目规则、空行、CRLF、文件末尾有无换行）逐字节不变。标记外的内容**不得**按标题或关键词做模糊匹配。
2. **不误改示例**：文档里被引用、缩进、或位于未闭合围栏内的标记文本一律当普通内容；只有"围栏外、独占一行"的精确标记对才算受管段。多对标记要**先数全部候选**再决定，不许 first-match；歧义或未闭合围栏要**明确拒绝并给出确切原因**，不许猜。
3. **重复 init 幂等**：连续 init 两次不追加第二对标记、不产生内容漂移。
4. **旧标记迁移**：旧的 `<!-- pi-team:begin/end -->` 按既有规则迁移，迁移同样不许改到标记外或示例里的文本。
5. **PM 提示**：AGENTS 受管块里（或 PM 启动提示词里，按提案落点）明确写出：**项目自定义规则要写在 Teamsmith 标记之外，不要手工塞进受管块**；并说明升级会替换受管块内容。提示要在真实渲染路径上出现，不是只写在文档里。
6. **AGENTS 短宪章**：按提案把模板改成共享短宪章（权限/安全/阅读顺序/交付地板），不删 worker 安全红线；不加生成器、不加字数门禁。

## 验收（自己跑，贴输出）

- 现有 `AGENTS.md` 夹具升级测试（用 `templates/AGENTS.section.md.tmpl` 造一个"带项目规则"的既有文件）：改前演示**旧行为会吃掉标记内项目规则**、改后逐字节保留标记外内容；CRLF 文件与"末尾无换行"文件各一例。
- 重复 init 幂等、旧标记迁移、示例里的标记不被改写，各一条。
- 反向自检：把"只认围栏外独占行"这条判据去掉/放宽，对应断言必须变红；还原即绿。
- `bash skills/teamsmith/tests/smoke.sh --select 26,28,38,17`（或你能论证覆盖 §17 受管块、§26 模板、§28 契约键、§38 控制台的那几段；跑前先 `section-select.sh --check`），`openspec validate --all --strict`（本机用 `~/.cache/openspec-1.8.0/node_modules/.bin/openspec`）、`spec-refs.sh --check`、`ledger-ban.sh`、`git diff --check`。
- 跑完写 `docs/team/reports/P400-dev.md`，提交推分支，通知 PM。**不要跑全量 smoke，不要对真实项目运行 `team init`，不要改现场 AGENTS.md。**

## 边界

- 只改：`skills/teamsmith/scripts/lib/cmd-project.sh`（写入器）、`skills/teamsmith/templates/AGENTS.section.md.tmpl`、必要时 `templates/pm-prompt.md.tmpl` 的提示行、相关测试与 fixtures。**不要**改 P393/P396 刚落地的 say/标记回复行为。
- 不发布、不归档、不合并、不动 `.pi/team/` 下真实状态。
