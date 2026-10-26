# gate-waiter-patience · 一次合法的长时门禁不该让等它的人失败

## Why

门禁锁的等待上限今天**恒等于** `TEAM_SMOKE_LOCK_WAIT`（默认 1800 s），所以一次合法的长跑会让所有等待者按
30 分钟 FAIL。这不是推测，是两条链一起断的结果：

- **生产者断了。** `gate_lock_cap` 的上限本是 `clamp(expected − 已跑 + 60, W, 4W)`，`expected` 由
  `gate_lock_expected` 按 `section-budgets.tsv` 求和。P316（`d92f0a17`）删掉预算表，`smoke.sh:559`/`:637`
  与 `cmd-review.sh` 的三处调用于是都读不到表：实测 `gate_lock_expected smoke.sh /dev/null` →
  `0<TAB>121500<TAB>135`，即 `expected=0`、`bound=121500`（135 段 × 900 的默认值）。`remaining` 恒为负 →
  `cap` 恒落回下限 `W`。
- **代价的形状已经存在，只是还没被撞上。** 记录里的产品基线约 **35 分钟**，比 30 分的 `W` 大；它由许多段组成，
  **段边界与段内断言都在推进心跳**（`ok()/bad()` 与等待轮每轮都 +1 tick），正是本 change 要照顾的那种「合法、
  持续有进展、总时长超过 `W`」的运行。今天没撞上是「长跑 + 有等待者」没同时发生，不是设计。同一段边界也写明：
  **单段内超过 `W` 的单次子进程**（§61b 那种，段内没有断言、也就没 tick）不属这类运行 —— 按源码推断它今天会被
  自己的挂住上限停掉（未实测），本 change 不改变它（`design.md` §7）。

P328（`docs/team/reports/P328-dev-bob.md` 动作 2）把它点名为「守一个没有生产者的数」，并写下诚实边界：
「真正要修的行为今天就在发生；删算式不会修它，只会让它从『残留承诺』变成『写明的行为』。修它要改
`verification` 的一条 requirement」。本 change 就是那条 requirement。

## What Changes

等待者的耐心改为跟随**持有者的心跳**，而不是预算投影：

- **心跳还在动 → 继续等，上限抬到硬顶 `4 × TEAM_SMOKE_LOCK_WAIT`。** 段守卫（P281）每个 tick 重写
  `<tmp>/.teamsmith-smoke-heartbeat.<pid>`，那就是「这一次运行还在推进」的现场证据。
- **心跳停了 `W` 或根本没有 → 上限就是今天的 `W`，行为与文案形状一字不改**：一行 `排队超限`、点名持有者、
  `本套**没有运行**`（`FAIL`，不是 `TIMEOUT`），§34b①/⑦ 的断言原样成立。区别只在失败行多说明一句**为什么**：
  「心跳已停 Ns」还是「没有可用心跳」。
- **删掉 `expected` 在 cap 里的分支**：`gate_lock_cap` 的 `clamp(remaining + 60, W, 4W)` 与它打印的 `remaining=`
  一起退场。`expected`/`bound`/`sections` **仍写在记录里、仍被打印**（§34b② 断言它们存在），只是不再决定耐心 ——
  它们是诊断字段，不是耐心来源。P329 只删了假注释与几条自造数字的断言，算式本身由本 change 删。
- **心跳从「本锁所有活登记里最新的那一个」读，不是从持有者记录那一个字段读**：实测顶层 `smoke.sh` 的
  `.holder` 公布的是**取锁包装器** pid 的心跳路径，而实际被写的是它子进程登记（`.runs/<pid>.run`）里那条；
  `team review` 的 `.holder` 直接写 `heartbeat=-`（它跑的门禁是子进程）。只读 `.holder`，今天两种真实形状都
  读不到心跳，等于没改。
- **心跳来源复用既有锁路径与活登记，不新增认证也不新增监测。** 读取不校验登记与当前持有者的祖先关系：一条
  **遗留但仍活着**的登记（例如泄漏的孤儿段守卫）还在 tick 时，会把上限顶在 `4W`，而真正的持有者可能已卡死 ——
  默认值下最坏是 2 小时（不是无限），这条有界放宽由本 change 明写接受（`design.md` §3）。
- **规格只改一条**：`verification#The hard timeout covers the gate run, not the queue` 的排队上限段落；
  生效文档 `skills/teamsmith/references/protocol.md` §9b-2 同轮对齐，不留第二份口径。

**不做**：不新增预算表、调度器、监测器、第二个等待机制；不抬 `TEAM_SMOKE_LOCK_WAIT` 与 `4×` 的默认值；不碰
CI 的 60 分钟上限、`TEAM_REVIEW_TIMEOUT` 的记账与 `PASS|FAIL|TIMEOUT|SKIPPED|UNKNOWN` 闭集。

## Capabilities

### New Capabilities

（无）

### Modified Capabilities

- `verification`: `The hard timeout covers the gate run, not the queue` —— 排队上限从「按记录公布的 expected 投影」
  改成「跟随活运行的段心跳」，并明确 `expected`/`bound` 不再决定耐心。

## Impact

**改动的文件（apply 写集，逐条明授）**

- `skills/teamsmith/scripts/lib/gate-lock.sh`：`gate_lock_cap` → 心跳耐心读数（删投影分支）；新增 mtime 读法与
  「最新的活心跳」一处实现（`gate_lock_patience` / `gate_lock_patience_pair`）。
- `skills/teamsmith/tests/smoke.sh`：两处排队点（`:536`、`:548` 的行与算式）、§34⑦ 的算式对账、§34b⑨ 剩下的两条
  断言改成心跳口径的纯函数腿，再加上分支表里今天没有任何断言覆盖的四条（边界 `silent_for == W`、文件不在、
  硬顶、`team review` 形状的正例与它的「只读 `.holder`」反例 —— 逐条见 `tasks.md` §3）。
- `skills/teamsmith/scripts/lib/cmd-review.sh`：`team review` 的排队点（读上限、排队行、`gates_out` 的原因）。
- `skills/teamsmith/tests/perf.sh`：性能锁的排队点（同一个读数函数；`state=none` → 仍是 `W`）。
- `skills/teamsmith/references/protocol.md` §9b-2：排队上限段落的旧口径。
- `openspec/changes/gate-waiter-patience/**`（本文件、`design.md`、`tasks.md`、`specs/verification/spec.md`）。

**顺序**：P329 先落地（它改 §34⑦/§34b⑨ 的同一批断言与 `gate-lock.sh` 的席位推导），本 change 的 apply 排在它之后，
理由与逐行分工见 `design.md` §5。

**验收口径**：propose 阶段只交 `openspec validate --all --strict`、`spec-refs.sh --check`、`git diff --check`，
以及在 `/var/tmp` 的 openspec 副本上试归档一次（归档后 validate 仍全过）。实现阶段的红侧（心跳停 / 心跳新鲜 /
旧记录退回 W / 硬顶 4W）逐条写在 `tasks.md`。
