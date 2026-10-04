# P100 · 独立验证：P66（排队超时大声失败）+ P94（SCENE_LINES=0 边界）

```
task:   P100
agent:  verify
issue:
change: -                        # 无 change：两件 infra 修正确认（作者都不是你）
specs:  -
phase:  verify
anchor: none (infra) — 复核排队超限的 loud 行为与现场行数为 0 的语义，不改实现
deltas: -
grant:  docs/team/reports/P100-verify.md · docs/team/reports/P100-verify/**（只写报告与证据，不改实现）
deps:   P66（apply=dev-bob）· P94（apply=dev2）
status: todo
budget: 小
```

> 本地模式：不 push。

## 要对抗性验证的（**自造**现场；不要只跑它们的夹具）

### A · P66 排队超限（D50 的两次事故）

1. **自造持锁**：`flock -x <私有锁> sleep N` + 写 `<lock>.holder` → 用 `TEAM_SMOKE_LOCK=<私有锁>
   TEAM_SMOKE_LOCK_WAIT=<小值>` 跑套件 → 必须**点名持有者**（读 holder 文件）且**退出 2**（不是 1、不是 0）。
2. **与门禁真红区分**：造一个**断言失败**的运行 → 退出码必须是 **1**（且不带"排队超限"措辞）——
   两个退出码**不可混同**。
3. **其它加锁失败**：锁路径不可创建（例如父目录只读）→ 措辞是"加锁失败"而不是"排队超时"。
4. **既有口径不变**：`TEAM_SMOKE_NO_LOCK=1` 不排队；FAST 不进锁；`queued=`/`ran=` 账本仍分开记。
5. **红侧**：把守卫逐字节还原成 `exec flock -w`（scratch）→ 复现"静默 exit 1、不点名"的旧形状。

### B · P94 `TEAM_AGENT_SCENE_LINES=0`

1. **自造 560 KB 的 `state/dispatch-<agent>-tail.txt`** → `TEAM_AGENT_SCENE_LINES=0 team status <ID>`
   必须 **rc=0**（修前 141）、**不打印现场块**、并给**显式措辞**；`n=1/3/40` 与既有逐字一致。
2. **边界**：文件只有空行 / 文件不存在 / 行数不足 N —— 三种都不许中止、措辞正确。
3. **第一/第二层来源未变**（活遗体 pane / `pane-dead.txt`）。
4. **红侧**：把读取器还原成 `awk … | tail -n "$n"`（scratch）→ `n=0` 复现 141。

### 共同

- **零回归**：`openspec validate` + FAST +（一次）全量。
- 报告写清"哪些是你自己的证据、哪些是引用"。
