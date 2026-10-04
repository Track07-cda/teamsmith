# P66 · 机器锁排队超时的"大声失败"没发生（exit 1 且不点名持有者）

```
task:   P66
agent:  （等席位）
issue:
change: -                            # 无 change：这是 M51/gate-hygiene 承诺路径的实现缺陷（infra）
specs:  -
phase:  apply
anchor: none (infra) — 修门禁自身"排队超时"路径的输出与退出码，不改门禁判定语义
deltas: -
grant:  skills/teamsmith/tests/smoke.sh
deps:   M51/M25/P26（gate-hygiene 的排队与超时账本）· 2026-09-22 PM 实测（本任务第一现场）
status: todo（等席位）
budget: 极小（十几行）
```

> 本地模式：不 push。

## 现场（PM 实测）

PM 的归档前门禁在 `team_bg_run` 里排队，**30 分钟上限到点**时：

```
$ tail /tmp/post-p55-gate.log
✓ spec/watchdog
Totals: 24 passed, 0 failed (24 items)
另一套全量 smoke 正在跑（2026-09-22T15:34:11+00:00 pid=2944970 cmd=smoke.sh）；本套排队，最多等 1800s
GATE_EXIT=1                      ← 之后什么都没有
```

**机理（读码）**：`smoke.sh` 的排队路径用
`exec flock --close -w "$SMOKE_LOCK_WAIT" "$SMOKE_LOCK" bash …/smoke.sh "$@"`；
`flock -w` **超时返回 1**（不是 2），于是脚本**直接以 1 退出**，
`exec` 之后那行 `printf '排队/加锁失败…'; exit 2` **永远不会执行**。

**后果**：与 gate-hygiene 的承诺相反——**排队超上限本该"大声失败并点名持有者"**，
实际是**静默 exit 1、不点名**，看日志的人只会以为门禁自己红了。

## 要做的

1. 排队路径要么**用 `flock` 的返回码区分**（1=超时 → 打一行点名 `SMOKE_LOCK.holder` 里的持有者 + 等了多少秒 + 退出码按约定），
   要么**放弃 `exec` 形态**改成显式 `flock … bash …; rc=$?; [ $rc = 1 ] && { 打日志; exit 2; }`；
2. **保留** `--close` 的漏锁修复（M23 的教训）与"轮到时打印 `轮到本套了（排过队）`"；
3. **红侧**：用 `TEAM_SMOKE_LOCK=<临时锁>` + 手工持有该锁 + `TEAM_SMOKE_LOCK_WAIT=1` →
   必须看到**点名持有者的一行**且退出码是约定的那个（不是 1，也不是静默）；
   **绿侧**：无竞争时照常跑。
4. 不动的：`TEAM_SMOKE_FAST` 不进锁、`TEAM_SMOKE_NO_LOCK` 的语义、`queued`/`ran` 的账本口径。
