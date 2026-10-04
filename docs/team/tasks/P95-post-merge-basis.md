# P95 · `--post-merge` 的比较基准：从 main 的 tip 改到**该任务的 squash 提交**（低优先）

```
task:   P95
agent:  （等席位）
issue:
change: -                        # 无 change：P91 的精度细化（infra）
specs:  -
phase:  apply
anchor: none (infra) — 只改"与谁比"，判定方向不变（缺代码仍非零）
deltas: -
grant:  skills/teamsmith/scripts/lib/cmd-review.sh · skills/teamsmith/tests/smoke.sh（append-only）· skills/teamsmith/references/troubleshooting.md §20
deps:   P91（同一动词）· **D49/P91 的现场**（squash + PM 解冲突 → 误报）
status: todo（低优先，等席位）
budget: 小
```

> 本地模式：不 push。

## 症状

`squash 合并 + PM 手工解冲突`后，被解过冲突的文件必然"两边都动过" → `--post-merge` 报非零、建议重合并
——**误报**（P82 的 `threads/dev-bob.md`、`smoke.sh` 就是）。

## 要做的

1. **比较基准**：在 main 的提交信息里定位**该任务的 squash 提交**（现有约定：`<ID>[: ]` 前缀或 `Agent:` trailer），
   比较 `分支 ↔ 该提交`（而不是 `分支 ↔ main 的 tip`）。这样"后来者引入的差异"（别人的合并、我的解冲突）
   **不再**计入。
2. **仍要报真形状**：分支带来的**代码路径**在该提交里缺失/不同 → **非零**（语义不变）；
   找不到该提交（分支从未合并）→ 明确说"未找到合并提交"，并回落当前行为（与 main 的 tip 比）。
3. **可证伪**：① 造"解冲突型"历史 → 修后**退出 0**（修前非零）；② 造"代码真的没进来" → **仍非零**；
   ③ 未合并的分支 → 明确措辞。
4. **零回归**：`--pre-merge` 与既有的 `--post-merge` 场景（记录晚到 → 0；代码差异 → 非零）照旧。
