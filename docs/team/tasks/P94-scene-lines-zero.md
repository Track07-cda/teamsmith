# P94 · `TEAM_AGENT_SCENE_LINES=0` 让 `team status` 中止（P88 的 F1）

```
task:   P94
agent:  （等席位）
issue:
change: -                        # 无 change：P75 读取器的边界修正（infra）
specs:  -
phase:  apply
anchor: none (infra) — 修 `SCENE_LINES=0` 的边界语义，不改既有现场来源
deltas: -
grant:  skills/teamsmith/scripts/lib/cmd-status.sh · skills/teamsmith/tests/smoke.sh（append-only）· skills/teamsmith/references/*（一句）
deps:   **P88 的 F1**（`reviews/P88.md`）· P75（同函数的上一轮）
status: todo（等席位）
budget: 极小
```

> 本地模式：不 push。

## 现场（P88 实测）

```
$ TEAM_AGENT_SCENE_LINES=0 bash skills/teamsmith/scripts/team status T9.88   # tail 文件 560 KB
  → rc=141（SIGPIPE），席位段的现场块不出来
```

**机理**：`cmd-status.sh:1171-1177` 的 `awk … | tail -n "$n"`，`n=0` 时 `tail -n 0` 立刻退出 →
awk 写端吃 SIGPIPE → 调用链 `pipefail` → `rc=141`。（与 P28 的 `printf | grep -q` 同族。）

## 要做的

1. **`n=0` 的明确语义**：按配置**不显示**现场块，并给**显式措辞**（例如"按 `TEAM_AGENT_SCENE_LINES=0`：不打印画面"）；
   **绝不允许**命令中止（rc 必须是正常值）。
2. **不许**改变 `n>=1` 的任何行为（含中间空行保留、不足 N 给全部、只有空行的措辞）。
3. **可证伪**：`TEAM_AGENT_SCENE_LINES=0` → `rc=0` + 显式措辞 + 不打印画面（当前 rc=141 → 红）；
   `n=1/3/40` 三例与既有断言逐字不变。
4. **零回归**：`openspec validate` + FAST + 全量 smoke。
