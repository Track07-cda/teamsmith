# P56 · 门禁的每一段都必须可归属、可超时、有现场（propose）

```
task:   P56
agent:  dev-bob
issue:
change: gate-section-accounting
specs:  -
phase:  propose
anchor: change
deltas: verification
deps:   2026-09-22 12:03 起的 CI 事故（本任务的第一现场）· P48（pty 延长的硬上限）· M59（失败现场）
status: todo
budget: 一个工作块（只出提案包；不写实现）
```

> 本地模式：不 push。**只 propose。**

## 现场（PM 实测，提案要引用）

- **2026-09-22 的一轮 CI**：run `35723304924` 在 12:03:12 起跑，**21 分 28 秒**跑完整轮
  （`✓2865 ✗1`），随后上传产物失败；**17 分钟**花在 runner 排队上（run 11:46 创建、job 12:03 才起）。
  **PM 先把它读成"卡了 45 分钟"，那是错的**——run 的总时长不等于作业时长，**日志没有"我在哪一段"的自述**，
  这正是把它误判成死锁的原因（本条要在提案里写成论据：**门禁必须能自述进度**）。
- **现场通道连着两次失败**：① 挂载宿主目录到容器 `/tmp` → runner 上零产物；
  ② 改成 `docker cp` 整份 `/tmp` → 上传步骤 `ELOOP: too many symbolic links`（HOME 缓存里的自指软链），
  产物仍为零。**PM 已把收集步骤收窄到现场家族**（`teamsmith-smoke.*` / `panel-p21.*` / `config-cli.*` /
  `pty-wait-selftest.*`）——这条也要进提案的"失败现场必须能离开容器"要求。
- **同一提交在本地固定镜像里是绿的**（`✓2837 ✗0`，约 11 分钟），所以不是确定性的产品死锁；
  而 CI 唯一的红**稳定复现**（`✓108 ✗3`，四轮同样三条），**至今没有 scene dump**——本轮的第 ② 条正是它的门。

## 要裁决的设计问题

1. **每段自述与硬上限**：每个 `section` 必须打印"开始"并带**自增的段落号与时间戳**；
   每段必须在一个**硬超时**里跑（`timeout <预算>`），超时即**点名该段**并非零退出——
   不许出现"整轮卡住但不知道在哪"。
2. **超时即现场**：超时/失败时把该段的**现场**留下（pane 尾巴、夹具日志、进程表快照），
   与 D39 的容器产物通道接上（`docker cp`）。
3. **预算的来源**：每段的预算要有依据（实测表：本地/容器/CI 三处各段的耗时），
   超预算只报"该段超时"而不是"全局假死"；**不许**用超时掩盖真失败（超时必须红）。
4. **空转可辨识**：段落内的**等待/轮询**必须带轮数与上限（P48 的库是范例），
   并在到达上限时给出归因读数；**禁止**无上限的 `while` + `sleep`。
5. **可证伪**：一个夹具注入"某段永远不返回"（`sleep infinity`）→ 门禁在预算内点名该段并非零退出，
   且现场里有该段的证据；反向：正常跑不受影响。
6. **不做**：不改任何段落的**判定语义**、不改 D33（性能不进正确性门禁）、不动 D39 的产物通道。

## 硬要求

- policy B：delta 落 `verification`；每条可证伪、MODIFIED 不删 base scenario；
- 每条 requirement 给复核方法（跑什么、看哪一行、期望值）；
- **不写实现**；现实与上文冲突 → `BLOCKED:` 交回 PM。

## Deliverables

- `openspec/changes/gate-section-accounting/{proposal.md,design.md,tasks.md}`
- `openspec/changes/gate-section-accounting/specs/verification/spec.md`
- 报告 `docs/team/reports/P56-dev-bob.md`
