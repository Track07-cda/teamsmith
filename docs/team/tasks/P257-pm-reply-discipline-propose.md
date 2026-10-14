# P257 · 把「关键回复要先发布」写进 skill（PM 提示词 + 协议 + 门禁）

task: P257
agent: dev
phase: propose
category: analysis
change: pm-reply-discipline
specs: key-replies
deltas: key-replies
branch: task/P257-pm-reply-discipline-propose
deps: -

## 用户的要求（原文）

用户 2026-10-14：「这个规则应该在 teamsmith 的 skill 里的，不只是你自己的记忆里。」

指的是 PM 侧行为规则：**任何用户需要事后能找回来的结论，先发布到关键回复页，再在对话里发同一份**（里程碑落地、做出裁定、请用户决策之前，各发一条；同一批可合并；只发结论，不发自述性噪音）。今天这条只活在 PM 项目的记忆里，别的项目、别的机器上的 PM 不知道它——这正是用户要修的地方。

## 现状（PM 已核，你复核）

- `team reply` 的**机制**齐全（CLI、存储、面板第五页、`references/protocol.md` §4b 已写明「发布正文再回答」的**理由**与**命令**）。
- **缺的是「谁必须这么做、什么时候做」的指令面**：`templates/pm-prompt.md.tmpl`（每次 `team up` 注入 PM 的提示词）里对 `team reply` **零提及**；`SKILL.md` 的命令表里也没有「什么时候该用它」这一行；门禁里没有任何断言盯着这两处。

## 你要产出的东西

一个 OpenSpec change（落地能力 `key-replies`，即那个已归档能力的 MODIFIED requirement），`openspec/changes/pm-reply-discipline/{proposal.md,design.md,tasks.md}` + `specs/key-replies/spec.md`。要覆盖：

1. **指令面**：在 `templates/pm-prompt.md.tmpl` 里加一段**简短、可执行**的规则（英文，与提示词其余部分同风格），至少说清：什么时候发（里程碑落地 / 做出裁定 / 要用户决策之前）、怎么发（`team reply post --from pm --title '<短标题>' --stdin < <文件>`，正文是**完整那份**）、发完再在对话里发同一份、同一批可合并成一条、只发结论不发过程性噪音。
2. **文档面**：`references/protocol.md` 的 §4b 补上「这是 PM 的常设义务」这层（今天写的是「当你有一个值得留存的答复时」，读起来是可选项）；`SKILL.md` 的命令表里给 `reply` 一行说明它是**给用户的关键结论**的出口（与 `say`/`notify` 的内部通道区分开）。
3. **门禁面（让它不能被悄悄删掉）**：在既有 `tests/key-replies.sh`（或等价）里加断言：PM 提示词模板**必须**含那段规则（按稳定短语断言，不锁死整段文字）、模板里的示例命令必须是**当前可用**的形式（跑一次 `--help` 或对拍），协议与 SKILL 里必须出现同一口径；**红侧**：从模板里删掉该段 → 断言红并点名；把示例命令写成不存在的旗标 → 红。
4. **不做**：不改 `team reply` 的 CLI 行为与存储、不改面板渲染、不改 worker 侧提示词（这条是 PM 与用户之间的通道）、不引入「自动判定哪条重要」（那是判断，不是机械）。

## 边界

- 只写提案；apply 与 verify 另行换人。
- 与在飞任务的分工：**P252（help 分级 + 语言层）** 拥有 `cmd-project.sh` 的 `team help` 段；**P255** 拥有 `references/migration.md`；**P251** 拥有 `references/config.md`。你要碰的是 `templates/pm-prompt.md.tmpl`、`references/protocol.md §4b`、`SKILL.md`、`tests/key-replies.sh`——若发现别人也在改同一文件，先 `BLOCKED:` 给 PM。
- 不合并、不推送；做完 `team notify pm`。
- **排期**：todo（席位空出来再派）。

## 验收（本阶段）

```bash
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
bash skills/teamsmith/tests/spec-refs.sh --check
bash skills/teamsmith/tests/section-select.sh --paths docs/team/reports/P257-dev.md
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check && git status --short
```
