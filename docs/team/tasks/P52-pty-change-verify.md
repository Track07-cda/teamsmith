# P52 · pty-fixture-load-premise 独立验证（verify 阶段）

```
task:   P52
agent:  dev2
issue:
change: pty-fixture-load-premise
specs:  panel#The project-settings pty fixture judges under a machine premise / verification#The correctness gate judges correctness only …（MODIFIED）/ verification#A load experiment signals only the processes it started
phase:  verify
anchor: change
deltas: panel, verification
grant:  docs/team/reports/P52-dev2.md · docs/team/reports/P52-dev2/**（只写报告与证据，不改实现）
deps:   P44（propose）· **P48（apply，dev3）**——apply 作者不是你；D33（性能不进正确性门禁）· D37（实验只动自有 PID）
status: todo
budget: 一个工作块（只写复验证据与报告）
```

> 本地模式：不 push。

## 要对抗性验证的（每条给可复现命令 + 原始输出）

1. **前提行是真读数**：`panel-p21.sh choices` 首行必须带**真** `loadavg_1m/5m`、**真**核数（与 `nproc` 对比）、
   探针毫秒数；**注入不生效**：设 `TEAM_P21_PREMISE_PROBE_MS=1`/`TEAM_P21_PREMISE_LOAD_FACTOR=0.01` 时，
   **真路径必须忽略它们并打印"忽略 …"**（`premise-only` 模式也是这个面）。
2. **延长有界、静态不延长**：自己造一个"慢但在绘制"的场景（例如把某段渲染人为放慢，或调 `PTY_WAIT_ITERS`/`PTY_STALL_ROUNDS` 的组合）
   → 必须**等到**而不是立刻红；再造一个**静态现场**（例如等一个永不出现在的状态）→ **在安静机上必须红**（不是 SKIP、不是延长到天荒地老）。
3. **顶部归因与退出码**：探针超顶（把 `TEAM_P21_PREMISE_PROBE_MS` 调小到真路径生效的方式？——**若旋钮不许漏进真路径，就用 `premise-only` 或直接读代码 + 单测证明**）
   → **可见 SKIP + rc=4**；门禁侧 `p38_verdict` 必须把 rc=4 记成 **SKIP（带原因）而不是 pass**；
   一个 SKIP 不得让汇总行看起来全绿（**自己造一次**：让某个场景 SKIP、其余绿，看结果行与计数）。
4. **D37 的守卫（自己跑）**：`load-experiment.sh --guard-test` → 全绿；**再自己破坏一次**：
   把归属检查删掉 → 非自有目标被**真的**发了信号（红侧要有证据），还原 → 绿；
   确认脚本里**没有**主机级名字/命令行匹配（结构钉）。
5. **零残留**：跑完这些之后，全机**没有 `T` 状态进程**、没有遗留的私有 tmux server、没有新的 `/tmp` 泄漏
   （`ls /tmp/panel-p21.*` 应为空）。
6. **零回归**：`panel-p21.sh groups settings wheel`、`choices`、`panel-b3.sh`、`panel-cpu.sh`（如适用）、
   FAST smoke、**全量 smoke**——各自的结果行。

## 至少两条变异（红→绿原始输出）

- 把延长上限改回"不延长" → 慢机用例红/行为与期望不符；
- 把 rc=4 在 `p38_verdict` 里映射成 ok → 记账断言红；
- 还原后 `git status --porcelain` 干净。

## Acceptance

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
bash skills/teamsmith/tests/panel-p21.sh choices
bash skills/teamsmith/tests/load-experiment.sh --guard-test
```

## Boundaries

- **不改实现**；缺陷写清楚交回 PM；变异只在临时副本；
- **绝不对不属于你的进程发信号**（D37；违反即事故）；
- 不 push；不改 `docs/team/**` 里 PM 的文件。
