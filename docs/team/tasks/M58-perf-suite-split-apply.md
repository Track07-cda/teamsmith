# M58 · perf-suite-split 实施（apply）

```
task:   M58
agent:  dev2
issue:
change: perf-suite-split              # 提案已验收：docs/team/reviews/perf-suite-split-proposal.md（ACCEPTED）
specs:  verification#The correctness gate judges correctness only / verification#The performance suite is separate, self-describing and non-blocking / verification#CI runs the two gates separately and performance does not block / verification#The two gates are discoverable, and the doctor names the next step / panel#Frame assembly is asynchronous, cached and never blocks input
phase:  apply
anchor: change
deltas: panel, verification
grant:  skills/teamsmith/tests/** · skills/teamsmith/scripts/lib/cmd-docs.sh · skills/teamsmith/scripts/lib/cmd-project.sh · skills/teamsmith/references/** · skills/teamsmith/SKILL.md · .github/workflows/**
deps:   M57（propose，已合并）；D33（用户决定）
status: todo
budget: 分批 B1…B5（见 change 的 tasks.md）；做不完交 PARTIAL + 已完成批次
```

> 本地模式：不 push；分支留在 `.worktrees/dev2`。**计划就是 `openspec/changes/perf-suite-split/tasks.md` 的 B1…B5**，
> 本任务书只补边界与 PM 的三条硬要求。

## PM 的三条硬要求（验收会核对）

- **A1 · 双向翻转必须真跑**（不许"我看过"）：① 把一条性能判定**塞回** `smoke.sh` → 守卫**红**；
  ② 从 `tests/perf.sh` **移除**判定标记 → 守卫**红**；③ 还原 → **绿**。三次的**原始输出**贴进 apply 报告。
- **A2 · 参考环境不可用时可见降级**：`team perf` 在**没有钉死镜像**的机器上必须**明确打印**
  "参考环境不可用，本次为宿主判定，结论不作为验收依据"，**不许静默**按宿主结论结案（exit 4 + 醒目提示）。
- **A3 · 正确性覆盖不许缩水**：`d-realpath`（夹具旋钮不得漏进真路径）、premise 行只反映真读数、
  27-d 的异步性（刷新中按键不丢、坏块渲染 `—`）、`gate-hygiene` 的 `ran/queued` 记账、
  "缺 `/usr/bin/time` → 可见 SKIP(exit 4)"**必须留在全量门禁**里（可改写成时间无关的形态）。

## 关键约束（design 已定，别改）

- 判定**移动**不是复制：搬迁后 `smoke.sh` 里**不得**残留任何性能判定（帧预算常量 / CPU 份额比较 / 调用测量夹具）；
- 标记是 `perf.sh` 里的**命名单源常量**（`PERF_FRAME_BUDGET_MS=2000`、`PERF_CPU_MAX_PCT=1`、前提系数），守卫是对这组封闭集合的 grep；
- **红线数值一个都不改**（首帧 2000ms、稳态 ≤1% 单核、装配 2000ms）；
- 性能套件**默认跑钉死镜像**（`--container`），`--host` 明确标注"非参考环境"；两次性能运行**串行**（自己的锁）；
- CI：正确性与性能**两条独立结论**，性能**不阻塞合并**，**发版前必须跑一次并记录数值**。

## Boundaries

- 只碰 `grant:` 列出的路径；**不改** `scripts/lib/{common,outbox,cmd-config,cmd-watch,cmd-agents}.sh` 的既有语义，
  不改 `refuse` 类与写入路径（跨出 → `BLOCKED:` 交回 PM）。
- 不 push；不改 `docs/team/DECISIONS.md`。

## Acceptance (真跑，贴原始输出)

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null     # 正确性门禁：必须仍全绿
bash skills/teamsmith/tests/perf.sh --host                            # 宿主：判红或可见 SKIP，且打印环境自述
bash skills/teamsmith/tests/perf.sh --container                       # 参考环境（镜像 teamsmith-gate:*）
podman run --rm --userns=keep-id --pid=host --cgroups=enabled -e HOME=/tmp -v "<独立 clone>:/work:ro" -w /work teamsmith-gate:m51 bash -c 'openspec validate --all --strict && taskset -c 0-3 bash skills/teamsmith/tests/smoke.sh </dev/null'
```
外加 A1 的三次翻转原始输出、A2 的降级证据、A3 的"删一条正确性断言 → 门禁红"的证据。

## Report

`docs/team/reports/M58-dev2.md`：per requirement 覆盖表 + 每批翻转（红→绿）+ 独立包路径 + A1/A2/A3 三组原始输出。
