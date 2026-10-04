# P79 · digest 段号重复：`[6]` ×2（P69 的 F1）

```
task:   P79
agent:  dev
issue:
change: -                        # 无 change：既有门禁输出面的编号卫生（infra）
specs:  -
phase:  apply
anchor: none (infra) — 修正既有输出段的编号与随之而来的断言，不改任何判定语义
deltas: -
grant:  skills/teamsmith/scripts/lib/cmd-status.sh · skills/teamsmith/tests/smoke.sh（append-only）· skills/teamsmith/tests/*（受影响的断言）· skills/teamsmith/references/*（若文档提到段号）
deps:   P69 的 F1（`reviews/P69.md`）· P45（B2 选了 `[6]`）· P55（死 pane 段也用了 `[6]`）
status: todo
budget: 小
```

> 本地模式：不 push。

## 现场（P69 实测）

```
$ team digest | grep -E '^\[6\]'
[6] change 归组
[6] 死 pane 席位（窗口是遗体：现场可读；死 pane 不是投递目标，消息已换道收件箱）
```

时序：P24 建 digest 段 → P55（15:36）引入"死 pane 席位"段（用了 `[6]`）→ P45/B2（16:53）为 change 归组也选了 `[6]`。
既有的 `[5]`×2 说明编号历史上有过重复，但**两个 `[6]`** 让"用段号定位"失效。

## 要做的

1. **保留 B2 的 `[6] change 归组`**（它较晚合并、且 `12f` 的断言钉了 `[6]`），
   把 **P55 的"死 pane 席位"段顺延为 `[7]`**；同步它自己的断言、`references/*` 与任何提到该段号的地方。
2. **顺手检查全表**：有没有别的重复段号（`[5]`×2 是什么？）——**列出证据**并给出处置建议；
   若历史段号重复属于"既有现状"，**不要**为了整齐去改无关段（避免把断言面扩大）——给结论与理由即可。
3. **可证伪**：改后 `team digest | grep -E '^\[' ` 的段号**逐行唯一**（写一条断言）；
   反向：把 `[7]` 改回 `[6]` → 该断言红。
4. **零回归**：`openspec validate` + FAST + 全量 smoke。
