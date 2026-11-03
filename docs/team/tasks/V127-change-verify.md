---
id: V127
title: 指令瘦身 change 整体独立复验（含逐条职责工作表）
agent: verify
category: verify
phase: verify
change: instruction-context-slimming
specs: init-skill
anchor: openspec/changes/instruction-context-slimming/specs/init-skill/spec.md
deltas: -
branch: task/V127-change-verify
---

# V127 · 整个 change 的独立复验

被验对象：`openspec/changes/instruction-context-slimming/` 的全部实现，已在 main 落地为四次合并——
P400（受管块写入器 + AGENTS 短宪章）、P401（PM 与 worker 提示词）、P403（SKILL 与参考手册）、P404（两处声明面断言）。逐片复验见 `docs/team/reviews/{P400,P401,P403,P404,V122,V123,V125,V126}.md`。

**你要做的是三件前四片没做的事**，不是把它们再跑一遍。

## 一、渲染前后对照（tasks 6.1）

用**同一组参数**渲染 before/after 的 AGENTS、PM 提示词、worker 提示词（渲染函数在产品里，不要手抄模板），报实际行数/字节差异，并举 1–2 个"删掉的是重复、不是职责"的具体例子。注意：verbose 夹具的缩水不能当作真实模板缩水的证据。

## 二、逐条职责工作表（tasks 6.2，**本片的核心**）

对**整个 change 的 diff**（不是单文件）给出工作表：每条规则从哪来 → 现在在哪 → 为什么删它不丢职责。以下四行是规格点名的，必须单独成行并给出文件与行号：

- (a) `verification` 的双门禁分工在 `SKILL.md` 与 `references/protocol.md` **都**在，且正确性门禁里没有墙钟红线；
- (b) `SKILL.md` 的 frontmatter `description`、`## Agent adapters` 小节、深读表行都在，每个非 Pi 提法都带冻结 seam 措辞；
- (c) 渲染后的 AGENTS 段与 PM 提示词都写明"项目规则放在标记之外"，并指向 `references/migration.md` 而不是重抄操作步骤；
- (d) PM 的回复小节与已落地的 P396 文本一致（无 post-then-repeat、无临时文件/heredoc 作为默认）。

**判实际渲染后的最终文件，不做关键词存在性检查。** 任何一条职责找不到新家，就停下来判 NEEDS-CHANGES 并点名。

## 三、行为与红侧抽验（tasks 6.3）

从四片里各挑**一条**最关键的断言，在独立 clone 上自己重跑红/绿（不要复用作者或前四轮复验的数字），尤其：
- 受管块：标记外逐字节不变（含 CRLF、末行无换行）、歧义拒绝；
- 提示词：local 交付无 push/PR、回复走标记；
- 参考手册：`bootstrap` 不重刷既有契约、`init` 才刷；
- 声明面：删掉双门禁整段必红。

## 允许的命令

- `bash skills/teamsmith/tests/smoke.sh --select 0b,1b,6,17,18,18b,19,39 </dev/null`（先记 FAST 与非 FAST 的差别）
- `bash skills/teamsmith/tests/install-shape.sh`、`bash skills/teamsmith/tests/install-shape.sh flip`、`bash skills/teamsmith/tests/task-model-routing.sh --select init,dispatch,resume,preview`
- `openspec validate --all --strict`（`~/.cache/openspec-1.8.0/node_modules/.bin/openspec`）、`spec-refs --check`、`section-select --check`、`ledger-ban --names-file .pi/team/forbidden-names.txt`、`git diff --check`
- 你自己的临时项目；不要在 pm-skills 主检出上跑 init/bootstrap

## 边界与产出

- 不跑全量 smoke（除非你自己判断某条断言必须靠它）；不改任何产品文件；不合并/归档/发布；**不替 PM 决定归档**——归档要用户确认。
- 结论写 `docs/team/reviews/V127-verify.md`，第 3 行 `判定: **PASS**` 或 `判定: **NEEDS-CHANGES**`；工作表正文写在同一文件里（PM 要拿它去跟用户过一遍）。
- 若你发现某条职责只是"看起来有家"，实际那家是空指针或过时描述，按缺陷报，并给出你打开的那一行。
