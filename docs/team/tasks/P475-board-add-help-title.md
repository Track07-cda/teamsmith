---
id: P475
title: 修正看板新增命令帮助漏写必填标题
agent: dev2
category: code
phase: opsx-apply
change: -
specs: help-surface#Every behaviour a help page states is declared and probed
deltas: -
branch: task/P475-board-add-help-title
---

# P475 · 帮助显示看板新增所需的参数

`skills/teamsmith/scripts/strings/commands.tsv` 的 board 行把 add 显示为只要 ID；`skills/teamsmith/scripts/lib/cmd-docs.sh` 实际要求标题，后面还接受可选 agent、deps。按实际入口统一文案：`board add <ID> <title> [agent] [deps] [--allow-dup]`。唯一产品写集为该 TSV 的 board 行，只改这一条用法；不改解析器、错误处理、语言规则、其它命令、测试或规格。

作者静态核对该行和现有解析并实跑 `git diff --check`；另写自己的 `docs/team/reports/P475-dev2.md` 报告、分步本地提交（P475 / Agent: dev2）。另派非作者用默认英文及中文帮助就地验证渲染（包含旧输出对照），仅在隔离项目验证按新帮助可新增指定标题；不改本项目看板、不开整组帮助/全量，不新增测试框架或常驻断言。不推送、不合并、不发版。
