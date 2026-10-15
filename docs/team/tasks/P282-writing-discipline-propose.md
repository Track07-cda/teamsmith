# P282 · 写作纪律：先答读者的问题，谨慎必须有证据（提案）

task: P282
agent: -
phase: propose
category: analysis
change: -
anchor: none (infra) — 提示词与评审口径；不改产品行为
deltas: -
branch: task/P282-writing-discipline-propose
deps: 用户 2026-10-15 给的那份外部研究（NB-Corp/gpt-with-taste 的 research.md，PM 已读）

## 背景（PM 读过的四组证据）

1. 让模型「润色」时 9% 的论断被软化；让它**预先回应审稿人可能的质疑**时 **33%** 被软化，撤回率 0.2% → 9.5%。
2. 这些防御性改写**AI 评审给分更高**（十分制 +1.22），**人类读者读起来更吃力**（七分制 −0.70），理解正确率**相同**。
3. 措辞自信与否：逐点判分准确率一样，**两两比较**明显偏向措辞自信的一方。
4. 「审稿意见只有给出事实、反例或推理缺口时才值得改一句；想象中的反对意见不配得到一个段落。」

**对本项目的意义**：我们的流程就是「AI 写、AI 验」——如果 AI 评审系统性偏爱防御性文字，**验证回路本身就在奖励它**（报告越长越谨慎、信息量不变）。用户点名过 PM 答复里的仪式化段落、重复的「如实说明」、道歉段落、装饰性标记与自造简写。

## 要产出什么

一个 OpenSpec change，至少覆盖：

1. **判据（写进合同，不写措辞）**：一句谨慎的话，要么**点名一个可核查的事实或缺口**（数据、反例、推理缺口、未观测到的边界），要么删掉；**发现必须写明它改变了什么**（实现 / 下一步 / 结论 / 什么都不改）。什么都不改的观察不进正文。
2. **三处表面**：工人提示词模板（`templates/AGENTS.section.md.tmpl`）、PM 提示词模板（`templates/pm-prompt.md.tmpl`）、以及协议里「怎么向用户报告」的那一节；各写**可执行**的几条（先答问题、能删就删、边界只在有证据时声明、发现要带后果）。
3. **评审口径**：PM 复核交付物的清单加一行「每条发现写明它改变了什么」；这一条写在 `references/` 里（PM 用），**不设门禁断言**（D170：措辞与文风由评审把关）。
4. **验证手段**：设计一次**可复算的对照**——同一份任务派两次（一次带这条规则、一次不带），**由人读**两份报告判断（附评分口径与原始材料路径）；明确写出「不用 AI 评审打分」及理由（证据 2/3）。
5. **不变量**：不删「有证据的边界声明」这类句子（它们各自带事实/缺口）；不改退出码、不改门禁断言、不动产品代码。

## 边界

- 只写提案；apply 与 verify 另换人。
- 排期：todo（等席位）。
- 不许把这条做成「更自信」的口号：**判据是「这句谨慎有没有可核查的支撑」**，不是语气。

## 验收（本阶段）

```bash
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
bash skills/teamsmith/tests/spec-refs.sh --check
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check && git status --short
```
