---
id: V146
title: 账本路径生成源修复独立复验
agent: dev3
category: verify
phase: opsx-verify
change: -
specs: verification init-skill
anchor: openspec/specs/verification/spec.md
deltas: -
branch: task/V146-ledger-path-generation-verify
---

# V146 · 非作者复验 P440

冻结候选 `2dfaa44e`，作者 dev。你未参与实现。阅读 P440 报告和实际 diff；作者数字不是结论。

## 独立验证

1. 在自己的隔离项目中，从 `.worktrees/verify` 执行真实 `team review`：记录仍含实际执行者、 reviewed SHA、真实命令和结果，但模板、锁、报告摘录与门禁尾部均无 main/home 绝对路径；公开账本扫描 hits=0。
2. 分别生成源仓、普通项目、`--no-skills` 三种 PROTOCOL：相对命令路径真实存在或只显示明确占位；无绝对 home；不伪造安装路径。
3. 在自己的源码副本分别恢复 review 绝对路径写盘和 init 绝对 SKILL_DIR，具名断言必须红；恢复后绿。
4. 运行 `smoke.sh --select 10,10b,17,19`、`spec-refs`、`section-select --check`、`openspec validate --all` 和结构检查。继承的历史 hits 由 PM 清理，不要求你改历史文件。
5. 核对执行仍使用真实路径，ledger-ban/forbidden names 未放宽，review 执行者与证据语义未变。

## 交付

`docs/team/reports/V146-dev3.md`，先给 PASS / NEEDS-CHANGES，附自己的命令、生成样例、红/绿/恢复和未跑范围。只提交报告，不改实现，不合并、不发布。可补 OpenSpec assessment；不跑全量/夜间/61b。
