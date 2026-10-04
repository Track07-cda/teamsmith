# M56 · watch-degradation 独立验证（verify 阶段）

```
task:   M56
agent:  verify
issue:
change: watch-degradation
specs:  notify-and-inbox#A watcher registration failure is recorded with its cause / notify-and-inbox#Delivery continues on the polling fallback while watching is unavailable / notify-and-inbox#The inbox-watch gate measures an unavailable watcher visibly and has a strict path / watchdog#A live degraded channel is reported by team doctor and team status / watchdog#team doctor reports the inotify headroom of the wake channel / panel#The delivery warning covers a degraded wake channel
phase:  verify
anchor: change
deps:   M53（apply，已交付，tip 由 PM 在派单时点名）
status: todo
budget: 一个工作块（只写复验证据与报告，**不改实现**——这是你的席位边界）
```

> 本地模式：不 push；只写 `docs/team/reports/M56-verify.md`（+ `docs/team/reports/M56-verify/` 证据目录）。

**为什么是你**：这条 change 的 apply 由 **dev2** 做（`task/M53-watch-degradation-apply-doct`），
按 D31「不许自己验自己（按 change 判定）」，验证必须换人 —— 你是该 change 的独立验证者。
**你只写报告与证据，不改任何实现**（`skills/teamsmith/scripts/**`、`extension/**`、`tests/**` 一律不改；发现缺陷 → 写清楚交回 PM）。

## 要对抗性验证的五条（每条给可复现命令 + 原始输出）

1. **强制失败 → 兜底真的投递**：在**你自己的临时项目/夹具环境**里制造"注册必然失败"的场景（夹具旋钮），
   把轮询周期压到秒级，证明**一个新的 spool 行在一个周期内被投递一次**，且这条唤醒**不是新的消息形状**；
   并证明账本/耐久记录里**标明 forced**（不能只信实现里的注释）。
2. **旋钮不能漏进真路径**：不带夹具开关时，`TEAM_INBOX_WATCH_*`/forced 一类旋钮**不得改变真实判定**；
   给出真路径下的对照（同一命令、两次运行、只有旋钮有无之分）。
3. **doctor 的三态**：有运行时 → 报配额 + 探针结论；余量低 → **警告 + 修法**；**没有运行时时必须 `unavailable`，绝不 `ok`**；
   并证明**陈旧记录不算证据**（造一条旧记录 → doctor/status 不把它当活的降级）。
4. **门禁前提的可见性 + 严格模式**：配额耗尽/不可用前提时打印**可见 SKIP（含原因与实测用量）**；
   严格模式下**同一前提仍判红**；并证明这条 SKIP **不掩盖**其它断言（SKIP 计数与 ✗ 计数分开）。
5. **写入路径与既有语义没被动**：`standby`、消息形状、spool 格式、去重、outbox 投递守卫、默认轮询周期**逐条对照未变**
   （用 diff 或断言证明，不要只用"我看过"）。

## 还要回答 PM 的一个疑点（写成 finding，不改实现）

PM 在**本机**跑 `team review M53` 时，门禁 **2720 ✓ / 1 ✗**，唯一的红是
`panel-cpu-premise c-healthy：机器安静（loadavg 3.96 ≤ 4.00）却判红（首帧 neverms、CPU 0.50%）`；
而**同一个夹具在钉死容器里（load ~4.8）全绿 ✓18 ✗0**（PM 实测）。
本机与容器的最大环境差异是：**宿主 inotify 配额已耗尽（65312/65536，`fs.watch` 直接 ENOSPC）**。

**请你判定**：这条红是**环境所致**，还是**面板首帧真的退化了**（例如 M50 的读路径改动带来的副作用）？
方法和证据由你定（例如：查面板启动路径是否注册 watcher / 在容器里用受限配额复现 / 对 main 与 M53 分支做同机对照）。
结论要能被别人复跑，不要给"大概是环境"这种话术。

## Acceptance

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
bash skills/teamsmith/tests/smoke.sh </dev/null          # 本机（会看到"可见 SKIP"；把原始结果行贴出来）
# 容器内（与 CI 同路径；挂**独立 clone**，别挂 git worktree）
```
报告里请给出：本机与容器**两份**结果行，以及上面五条的逐条证据。

## Boundaries

- **不改实现**（席位边界）；不改 `docs/team/**` 里 PM 的文件；不 push。
- 需要新夹具才能验证时，把夹具写在**你的证据目录**里（`docs/team/reports/M56-verify/`），不要改 `tests/**`。
