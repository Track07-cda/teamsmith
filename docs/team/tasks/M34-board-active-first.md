# M34 · work 页看板卡：活跃态置顶（用户拍板）

```
task:   M34
agent:  dev3
issue:  
change: -            # "-" if no requirement changes
specs:  -
phase:  -
deps:   P18.1        # 已合并
status: todo
budget: 半个工作块；超出就交 PARTIAL 报告
```

> 本地模式：不 push，任务分支留在 `.worktrees/dev3`。

## Context

用户实机看 work 页后拍板（原话）：「活跃任务应当排在顶部」。

现状（`layout.ts boardBlock`）：行按 BOARD.md 文件序原样渲染，done/dropped 只留最新 keep 条——
活跃行和历史行混在文件序里，活跃任务常常沉底。

**改成**：看板卡的行序 = **活跃态优先**（todo/wip/review/blocked 保持文件序在前），然后是 keep 的
done/dropped（保持文件序，新→老或老→新按你实现里自然的那个，报告里写清楚选的是哪个及为什么）。
计数行、折叠规则（keep/随高度放宽）不动。看板页（kanban，第 4 页）**不改**（它本来按态分车道）。

## Deliverables

1. `layout.ts boardBlock` 的排序调整（不动数据层、不动 kanban）；重建 bundle 并提交。
2. 快照断言：夹具板子（活跃 2 行 + done 8 行）→ 活跃两行在顶部、keep 的 done 在后；**翻转**：
   用旧排序必须红。
3. 之前 P18.1 的大折叠池回归（右栏三卡 + 钉底）不许破。

## Boundaries

- 只动 boardBlock 的排序与其断言；不动 BOARD.md 存储、不动 kanban、不动数据读取器。

## Acceptance (must actually be run; put the output in the report)

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh </dev/null
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh
# 排序前后快照对照 + 翻转实录
```

## Report

`docs/team/reports/M34-dev3.md`。
