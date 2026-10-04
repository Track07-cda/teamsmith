# M53 · watch-degradation 实施（apply）

```
task:   M53
agent:  dev2
issue:
change: watch-degradation                 # 提案已验收：docs/team/reviews/watch-degradation-proposal.md（ACCEPTED）
specs:  notify-and-inbox#A watcher registration failure is recorded with its cause / notify-and-inbox#Delivery continues on the polling fallback while watching is unavailable / notify-and-inbox#The inbox-watch gate measures an unavailable watcher visibly and has a strict path / watchdog#A live degraded channel is reported by team doctor and team status / watchdog#team doctor reports the inotify headroom of the wake channel / panel#The delivery warning covers a degraded wake channel
phase:  apply
anchor: change
deltas: notify-and-inbox, watchdog, panel
deps:   M52（propose，已合并）
grant:  extension/team-inbox-watch.ts · scripts/lib/{outbox,common,cmd-project,cmd-watch}.sh · scripts/panel/src/strings/{zh,en}.ts · tests/team-inbox-watch-harness.mjs · tests/smoke.sh
status: todo
budget: 分批 B1…B4（见 change 的 tasks.md）；做不完交 PARTIAL + 已完成批次清单
```

> 本地模式：不 push；分支留在 `.worktrees/verify`。**计划就是 `openspec/changes/watch-degradation/tasks.md` 的 B1…B4**，本任务书只补边界与三条 PM 审查要点。

## PM 审查时点出的三条（当成硬要求）

1. **旋钮的自证**：夹具强制失败时，账本行与 `<key>.degraded` 记录里必须**标明这是强制的**（forced），
   否则未来的读者会把测试造成的事故当成真实事故；给一条断言钉住这个标记。
2. **轮询兜底要可证伪**：不许只在提案里承诺 —— 夹具必须**把轮询周期压到秒级**（夹具旋钮），
   在**强制失败**的前提下观察到一个全新的 spool 行**在一个周期内**被投递一次，并断言这条唤醒**不是新的消息形状**。
3. **doctor 的措辞**：降级 ≠ 故障。警告必须给**修法**（提高 `fs.inotify.max_user_watches` 或检查探针），
   并且**健康时必须保持安静**（不刷屏）；"陈旧记录不算证据"那条要有反向夹具。

## 环境前提（重要，直接影响你的验收）

本机**宿主 inotify 配额已耗尽**（`64737 /bin/syncthing`，合计 65312–65361 / 65536；`fs.watch` 直接 ENOSPC）。
所以：

- **B4 的严格模式**在容器/CI（配额干净）里才是主判据；本机跑时，非严格路径应当打印**可见的 unavailable 前提**而不是判红；
- 验收时**两个环境都要报**：本机（应显示"可见 SKIP/unavailable"）与**钉死容器/CI**（应真实判红/判绿）；
  容器里的复现命令见 M51 的 brief（`podman run --userns=keep-id --pid=host --cgroups=enabled`、
  **必须挂独立 clone**——挂 `git worktree` 会因 `.git` 指针失效而误报 M44 守卫红）。

## Boundaries

- 只碰：`extension/team-inbox-watch.ts`、`scripts/lib/outbox.sh`（降级记录读取）、`scripts/lib/common.sh` + `cmd-project.sh`（doctor/status 的余量探针）、
  `scripts/panel/src/strings/{zh,en}.ts`、`tests/team-inbox-watch-harness.mjs`、`tests/smoke.sh`（新段 12b-pi3 等）。
- 不改：默认轮询周期与兜底节奏、消息形状、spool 格式与去重、`standby` 语义、outbox 投递守卫。
- 不改 `docs/team/DECISIONS.md`；不 push。
- **不许**在实现里试图修改系统配额（那需要特权，属用户/运维动作）——只报告与提示。

## Acceptance (真跑，贴原始输出)

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
# 容器（与 CI 同路径，4 核语义；挂独立 clone）
podman run --rm --userns=keep-id --pid=host --cgroups=enabled -e HOME=/tmp \
  -v "<clone>:/work:ro" -w /work teamsmith-gate:m51 bash -c 'openspec validate --all --strict && taskset -c 0-3 bash skills/teamsmith/tests/smoke.sh </dev/null'
```
外加**手工实录**（按 tasks.md 的翻转清单）：
① 强制失败 → 账本行含 `errno/watches/interval` 且**标明 forced**，`<key>.degraded` 落盘；
② 强制失败 + 秒级轮询 → 新 spool 行在一个周期内被投递一次（贴账本行）；
③ 非严格模式 + 不可用前提 → **可见 SKIP**（打印前提与原因）；严格模式同前提 → **判红**；
④ doctor：余量低 → 警告 + 修法；健康 → 安静；无运行时 → "unavailable"（**绝不 ok**）。

## Report

`docs/team/reports/M53-verify.md`：per requirement 覆盖表 + 每批翻转（红→绿）+ 独立包路径 + 三个环境的原始结果行（本机 / 容器 / FAST）。
