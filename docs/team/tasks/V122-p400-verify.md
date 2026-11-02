---
id: V122
title: 指令瘦身第一片（P400：受管块边界与 AGENTS 短宪章）独立复验
agent: verify
category: verify
phase: verify
change: instruction-context-slimming
specs: init-skill
anchor: openspec/changes/instruction-context-slimming/specs/init-skill/spec.md
deltas: -
branch: task/V122-p400-verify
---

# V122 · P400 独立复验（非作者）

被验 `task/P400-instruction-apply-1` @ `1840ee84d6ae`（作者 dev）。在你自己的 checkout 上验，不接受作者数字。

## 一、必须独立证明（每条都要你跑出来的输出或反例）

1. **标记外逐字节不变**：造一个"带项目规则"的既有 `AGENTS.md`（标记内故意放几条项目规则，标记外放章节、代码块、CRLF 行、文件末尾无换行的版本各一份），跑真实 `team init` 路径（在**你自己的临时项目**里，绝不是本仓），证明：
   - 标记外内容逐字节相同（用 `cmp`/`sha256` 证，不要只看 diff 摘要）；
   - 标记内被替换成新模板；
   - CRLF 文件与"末尾无换行"文件都正常处理，不被拒绝、不被规范化。
2. **不误改示例**：文档/围栏里的标记文本（受引用、缩进、未闭合围栏）不被当受管段。多对标记要**先数全部候选再决定**，歧义或未闭合要**明确拒绝并给出原因**（不是猜、不是 first-match）。
3. **重复 init 幂等**：连续两次 init 不追加第二对标记、内容不漂移。
4. **旧标记迁移**：`<!-- pi-team:begin/end -->` 迁移后行为与上面一致。
5. **PM 提示**：新 AGENTS 受管块与 PM 提示词里都写明"项目自定义规则写在 Teamsmith 标记之外，升级会替换受管块"；确认真实渲染路径能出这句话（不是只存在模板里）。
6. **短宪章没有吞掉安全红线**：新模板仍保留 worker 的安全/边界/交付地板（对照提案与旧模板逐条点名保留了什么、删了什么），并且没有引入生成器或字数门禁。

## 二、允许的命令

- 你自己临时项目里的 `bash skills/teamsmith/scripts/team init`（**不要**对本仓 pm-skills 跑）
- `bash skills/teamsmith/tests/install-shape.sh`（相关段）、`bash skills/teamsmith/tests/smoke.sh --select 17,26,28,38`（或你论证覆盖的等价选段；跑前 `section-select.sh --check`）
- `openspec validate --all --strict`（用 `~/.cache/openspec-1.8.0/node_modules/.bin/openspec`）、`spec-refs.sh --check`、`ledger-ban.sh --names-file .pi/team/forbidden-names.txt`、`git diff --check`
- 反向自检：放宽/去掉"只认围栏外独占行"或"数全部候选"的判据，对应断言必须变红；还原即绿

## 三、边界与已知红

- 作者报告说 `§38` 有一条红在基线 `5fb64aea` 上就有（`panel-b3` 窗口数）。**你要自己确认这条红在基线与候选上一致**，若候选另有新红必须点名。
- 不跑全量 smoke；不对真实项目跑 init；不改作者分支；不合并/归档/发布。
- 结论写 `docs/team/reviews/V122-verify.md`，第 3 行必须是 `判定: **PASS**` 或 `判定: **NEEDS-CHANGES**`（`team board` 读这一行）。缺陷给具体命令与输出，不要只写建议。
