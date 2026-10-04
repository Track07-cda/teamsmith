# P43 · ledger-and-gate-noise：门禁指纹不再因队友活动假红 + 未入账记录扫到 worktree + `--json` 空 override（propose）

```
task:   P43
agent:  dev-bob
issue:
change: ledger-and-gate-noise
specs:  -
phase:  propose
anchor: change
deltas: verification, board-and-status, memory-and-deps
deps:   D34（M28 假红实测）· M31（记录未入账警告）· P36（报告在 worktree 未跟踪的险情）· M74（JSON 非法坐实）
status: todo
budget: 一个工作块（只出提案包；不写实现）
```

> 本地模式：不 push。**只 propose。**

## 三件要收口的事（都有原始证据，提案要引用而不是重新发明）

### ① D34 · M28 容器自检的"宿主指纹"把瞬时客户端算进去 → 假红
- 证据：`docs/team/DECISIONS.md` D34；实测 `前 2dc577da… ≠ 后 9c2754d9…`，**同一时刻直接重跑
  `container-tmux.sh --selftest` → rc=0**、指纹 `3b1f7842…`（三个值互异）；根因在
  `tests/container-tmux.sh:100` 的 `host_tmux_fingerprint()` 把 `ps -eo pid=,args= | grep tmux`
  **全量快照**算进指纹。
- 要裁决：指纹**只留稳定事实**（默认 socket 的 `stat` + 默认 server 的 `list-sessions` + **只算 tmux server 进程**，
  忽略瞬时客户端）；**红侧仍要能抓"隔离没生效"**（容器里杀了宿主 server → 必须红）。
- 要给出**判据的可证伪面**：并发跑一个 tmux 客户端（`tmux list-sessions` 循环）时，自检**不得**假红；
  而"容器逃逸"那一侧仍红。

### ② M31 扩容 · "记录未入账"警告扫不到 agent worktree
- 证据：`team_untracked_records()`（`cmd-status.sh:497`）只扫 `$TEAM_MAIN_ROOT`；P36 的报告 +
  证据包曾在 `dev2` 的 worktree 里**未跟踪**（squash 会丢，PM 手工补提交才救回）。
- 要裁决：警告**遍历 `.worktrees/*`**（以及主检出），逐条点名 `<agent>: docs/team/reports/…`；
  仍然**只提醒不阻断**；**不许**把 worktree 里正常的未跟踪产物（门禁临时物）误报成记录——
  判据要按 `docs/team/{reports,reviews}` 前缀过滤（与主检出口径一致）；给出反向夹具（普通脏文件不报警）。

### ③ `team config list --json` 在"席位模型 override 为空"时产出非法 JSON
- 证据：M74 坐实（`"seats":[…,"override":}]`）；main 上同样（pre-existing）。
- 要裁决：字段序列化（空 → `""` 或 `null`，**给一个裁断并写死**）；回归断言要包含
  "`TEAM_AGENT_MODELS` 含 `<seat>=`（空 override）"的形状；顺带给 `--json` 的**所有**输出加一条
  "能被 `python -m json.tool` 解析"的通用断言（一次覆盖，便宜）。

## 硬要求

- **policy B**：三条各自落到 `verification`（M28 指纹的前提与红侧）、`watchdog` 或 `board-and-status`
  （记录可见性——按能力语义选一个并说明）、`memory-and-deps`（`--json` 的字段契约）；
  每条可证伪、MODIFIED 不删 base scenario；
- 每条 requirement 给"复核方法"（跑什么、看哪段、期望值）；
- **不写实现**；发现现实与上文冲突 → `BLOCKED:` 交回 PM。

## Deliverables

- `openspec/changes/ledger-and-gate-noise/{proposal.md,design.md,tasks.md}`
- `openspec/changes/ledger-and-gate-noise/specs/*/spec.md`
- 报告 `docs/team/reports/P43-dev-bob.md`
