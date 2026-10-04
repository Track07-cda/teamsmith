# P48 · pty-fixture-load-premise apply：前提行 + 顶部归因 + 实验安全规矩

```
task:   P48
agent:  dev3
issue:
change: pty-fixture-load-premise          # 提案已验收：docs/team/reviews/pty-fixture-load-premise-proposal.md（ACCEPTED）
specs:  panel#The project-settings pty fixture judges under a machine premise / verification#The correctness gate judges correctness only …（MODIFIED）/ verification#A load experiment signals only the processes it started
phase:  apply
anchor: change
deltas: panel, verification
grant:  tests/lib/pty-wait.sh · tests/panel-p21.sh · tests/panel-b3.sh（若前提行需要在同一库内接通）· tests/smoke.sh（append-only：§38-b/§38-f 的 SKIP 口径）· tests/panel-cpu.sh（若 §38 前提行的统一打印点在那里）· 如确需，`tests/perf.sh` 的口径引用（只读对照，不改 D33）
deps:   P44（propose，已合并 ccb91ae）· D33/D37 · M59（settled-frame 引擎）
status: todo
budget: 一个工作块（B1 前提行 + 归因；B2 延长与 SKIP/exit 4；B3 实验安全准则的守卫测试与夹具）
overlap: ⚠️ P47（dev-bob，ledger-and-gate-noise apply）同时在飞，也会 append `tests/smoke.sh`：
         你的新段加在文件末尾、小步提交；冲突由 PM 解决。
```

> 本地模式：不 push。**真源 = `openspec/changes/pty-fixture-load-premise/{design.md（§2 决策、§3 常量依据、§4 复现配方、§4b 实验纪律、§5 落点）,tasks.md}`**。

## 三批的要点（细节以 design/tasks 为准）

1. **前提行 + 入口口径**：每个 scenario 在**第一个断言之前**打印 `loadavg_1m/5m`、逻辑核数（`nproc` 或
   `getconf _NPROCESSORS_ONLN`）与**代码无关探针**（`python3 -c pass`/`bash -c true`/`git rev-parse`）的毫秒读数；
   只有**粗负载闸门**（`TEAM_P21_PREMISE_LOAD_FACTOR` 默认 **2.0**）在入口跳过；探针顶
   `TEAM_P21_PREMISE_PROBE_MS` 默认 **120**。
2. **延长与顶部归因**：视界**不放大**（`PTY_WAIT_ITERS`/`PTY_WAIT_PAUSE` 与各站点覆盖原样）；
   场景仍在绘制（`PTY_STALL_ROUNDS` 默认 8 轮内变过）→ 最多 **`PTY_EXT_FACTOR`=3×**；
   到达上限后读数归因：**在绘制 / 探针超顶 / 负载超粗闸门 → 可见 SKIP**（一行点名 wait、轮数、耗时、M59 现场、读数），
   场景到此为止，整体**退出 4**（无断言失败时）；**静态 + 健康 → 红**（带 M59 现场）；
   跳过**计数**并打印，**绝不**能被报成全绿。
3. **实验安全规矩的守卫**（`verification` 的 ADDED requirement）：写一个**可证伪的守卫测试**——
   自有目标可冻结可释放、`TERM`/`INT` 中途被杀必须已释放（不留 `T`）、**非自己启动的目标**与**模式形状目标**
   在发信号前即拒绝并非零退出。若仓库里那个 blackout 脚本还留着，按这条重写或删除（不许留模式形状的目标选择）。

## 必给的翻转（红→绿原始输出）

- 旧视界逻辑（无延长）→ 慢机用例红/SKIP 行为与期望不符；新逻辑 → 该判的仍判；
- **真回归**：把滚轮消费去掉（scratch 树）→ 安静机上**必须红**（前提不是逃避）；
- 探针超顶（人为拉高探针耗时或设上限 1ms）→ 可见 SKIP + 退出 4，且**门禁仍 0**（§38-b/§38-f 打印 SKIP 与原因）；
- 实验守卫：模式形状目标 → 拒绝、零信号；`TERM` 中途 → 无 `T` 残留；
- 还原后 `git status --porcelain` 干净。

## Acceptance

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
bash skills/teamsmith/tests/panel-p21.sh choices groups settings wheel
bash skills/teamsmith/tests/smoke.sh </dev/null          # 交付前全量
```

## Boundaries

- 只碰 `grant:` 列出的路径；**不改** D33 的口径（正确性门禁里不引入墙钟阈值断言）、
  **不改** 27-d/panel-cpu 的既有红线与系数；
- 不 push；不改 `docs/team/**`（报告除外）；矛盾 → `BLOCKED:` 交回 PM。

## Deliverables

- 实现 + 五组翻转原始输出 + 报告 `docs/team/reports/P48-dev3.md`（含前提行的真实读数、延长/归因的分支覆盖、
  以及"实验守卫"的四条证据）。
