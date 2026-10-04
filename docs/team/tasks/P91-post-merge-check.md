# P91 · 合并之后的核对：分支在合并后又动了什么（D45 的另一半）

```
task:   P91
agent:  dev-bob
issue:
change: -                        # 无 change：把 P76 的合并前检查补成"合并前 + 合并后"（infra）
specs:  -
phase:  apply
anchor: none (infra) — 给 PM 的合并流程补上"合并后核对"，不改任何判定语义
deltas: -
grant:  skills/teamsmith/scripts/lib/cmd-review.sh · skills/teamsmith/SKILL.md（合并流程一节）· skills/teamsmith/references/protocol.md · skills/teamsmith/tests/smoke.sh（append-only）
deps:   P76（同族的前一半）· **D49**（2026-09-22 的现场：P82 合并后又提交两条记录提交）· D45
status: todo
budget: 小
```

> 本地模式：不 push。

## 现场（D49）

P82 在 16 个提交时被 squash 合并，作者随后又提交两条**只动记录**的提交 → main 的记录停在旧版。
P76 的 `--pre-merge` **看不到**这种（它发生在合并**之后**）。

## 要做的

1. 给 PM 一条**合并后**可跑的核对（例如 `team review <ID> --post-merge`，或并进 `team close <ID>` 输出）：
   对指定任务分支打印**分支相对 main 的差异**（`main..task/<分支>` 的 `docs/team/**` 与 `skills/**` 两条线**分开**说）：
   - `docs/team/**` 有差异 → "记录有更新：取它"（打印 `git checkout <分支> -- <路径>` 可粘贴修法）；
   - `skills/**` 有差异 → **更响**："**代码有未合并的改动 —— 不能只取记录，必须重新合并并重跑门禁**"（非零退出）。
2. **文档**：合并流程（SKILL.md/PROTOCOL.md）补一句"合并后若作者仍在动，先跑这一步"。
3. **可证伪**：夹具里造两种形状（只动记录 → 提示取记录、退出 0；动代码 → 非零 + 点名）；反向把检查删掉 → 断言红。
4. **零回归**：`--pre-merge` 的既有语义不变；`openspec validate` + FAST + 全量 smoke。
