# P88 · 独立验证：P75（尾部现场裁剪）· P79（digest 段号）

```
task:   P88
agent:  verify
issue:
change: -                        # 无 change：两件 infra 修正确认（各自 apply 作者都不是你）
specs:  -
phase:  verify
anchor: none (infra) — 复核两件无 change 的 infra 修正（P75 尾部现场裁剪 / P79 段号），不改契约
deltas: -
grant:  docs/team/reports/P88-verify.md · docs/team/reports/P88-verify/**（只写报告与证据，不改实现）
deps:   P75（apply=dev3）· P79（apply=dev）——两位都不是你
status: todo
budget: 小
```

> 本地模式：不 push。

## 要对抗性验证的

1. **P75（`team_status_tail_scene`）**：自己造三例 —— ① 内容 + 尾部多个空行（`SCENE_LINES=3` → 必须有 3 行内容）；
   ② 只有空行 → 明确"没有可读内容"（**不是**静默空块）；③ 行数不足 N → 给现有全部；
   ④ **中间空行必须保留**（不许把中间的也裁掉）；⑤ **第一/第二层来源**（活遗体 pane、`pane-dead.txt`）语义**未变**（自查代码 + 一例）。
2. **P79（digest 段号）**：`team digest | grep '^\['` → **段号逐行唯一**（唯一豁免历史 `[5]×2`，你自己核对它确实是历史）；
   把 `[7]` 改回 `[6]`（scratch 副本）→ 该断言**红**；`[1]–[7]` 顺序与既有段语义未变。
3. **零回归**：`openspec validate` + FAST + 全量 smoke（当前 main 应零红）。
4. **报告要写清**：哪些是它自己的证据、哪些是引用；如发现任何不一致 → 点名文件与命令交回 PM。
