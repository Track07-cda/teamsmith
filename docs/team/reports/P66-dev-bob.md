# P66 · 门禁锁排队超上限：从「静默 exit 1」改成「一行点名持有者 + exit 2」

agent: dev-bob   status: DONE   time: 2026-09-23T02:40:00Z
branch: `task/P66-p66`（本地模式：不 push；`58028428` 守卫 + `32308f6f` 守门断言）   PR/MR: -

## Deliverables

| Path | What |
|---|---|
| `skills/teamsmith/tests/smoke.sh` | ① 排队守卫改造：marker 区分「排队超限」与「门禁真红」，超限 = 一行点名持有者 + `exit 2`；② §34b 断言（5 组 25 条）；③ 队列子进程自检出口 `SMOKE_LOCK_SELFTEST_CHILD`（夹具闩 + 大声打印） |
| `docs/team/reports/P66-dev-bob/pkg/**` | 证据包：`10` 现场重放 / `20` 守卫可证伪 / `30` 基线红归属（`bash docs/team/reports/P66-dev-bob/pkg/run.sh` 可重跑） |

## 事故与修复

现场：归档前门禁在 `team_bg_run` 里排队，1800s 上限到点时日志只有

```
另一套全量 smoke 正在跑（2026-09-22T15:34:11+00:00 pid=2944970 cmd=smoke.sh）；本套排队，最多等 1800s
GATE_EXIT=1                      ← 之后什么都没有
```

机理（读码 + `pkg/10-legacy` 重放实证）：排队路径是
`exec flock --close -w "$SMOKE_LOCK_WAIT" "$SMOKE_LOCK" bash …/smoke.sh "$@"`。
`flock -w` 等锁超时返回 **1**，而 `exec` 已经把本进程换掉了 —— 紧跟其后的
`printf '排队/加锁失败…'; exit 2` **永远执行不到**，脚本以 1 退出且一句解释都没有。
更糟的是 `smoke.sh` 自己的门禁失败**也是** `exit 1`：只看返回码无法区分「排队超限」与「门禁真红」。

修复（显式形态 + marker 文件，与 `cmd-review.sh` 的 `queue_marker` 同形）：

```bash
SMOKE_LOCK_MARKER="$(mktemp "${TMPDIR:-/tmp}/teamsmith-smoke-queue.XXXXXX" …)"
flock --close -w "$SMOKE_LOCK_WAIT" "$SMOKE_LOCK" bash -c \
  'marker="$1"; shift; date +%s > "$marker"; exec "$@"' _ "$SMOKE_LOCK_MARKER" \
  bash "$SKILL_DIR/tests/smoke.sh" "$@"
# 没有 marker（= 没拿到锁）：
#   rc=1  → 一行「排队超限：等满 Ns 仍拿不到门禁锁 <lock>（持锁者：<lock>.holder 的内容）→ 本套**没有运行**…」→ exit 2
#   rc≠1  → 「排队/加锁失败：flock 没能把本套跑起来（…rc=…）」→ exit 2
# 有 marker（= 本套真的跑过了）→ exit "$SMOKE_LOCK_RC"   # 子进程的退出码原样透传（含它自己的 1）
```

marker 是「真的拿到锁」的唯一证据：`flock -w` 超时与被包裹的命令自己 `exit 1` 的返回码**都是 1**
（§34b⑤ 与 `pkg/10` 都实测钉住了这一点），所以返回码本身不足以做判据。

保留不动（任务书第 2、4 条）：`--close`（M23 漏锁修复）、`TEAM_SMOKE_FAST` 不进锁、`TEAM_SMOKE_NO_LOCK`
语义、`queued`/`held` 标记口径、以及「轮到本套了（排过队）」那行（§34b③ 钉住）。

新增的队列子进程自检出口 `SMOKE_LOCK_SELFTEST_CHILD`：只在**已经是队列子进程**（`SMOKE_LOCK_WRAPPED=1`）、
`TEAM_SMOKE_FIXTURE=1`、且值是非负整数时生效，生效时大声打印一行后按该码退出；非夹具路径**忽略并打印**
（与协议里 fixture 旋钮的规矩一致）。它存在的唯一原因：让「真的排到队、然后按给定码结束」这条路径可被
测试，而不必在门禁里递归跑整套套件。**正常运行（没有这个变量）语义一个字不变。**

## 守门断言（§34b，25 条）

| 组 | 钉住什么 |
|---|---|
| ① 红侧 | 持锁 + `WAIT=1` → `exit 2`；一行里同时有 `<lock>.holder` 的内容、等了多少秒、「没有运行」；holder 没有被改写（子套件一次都没跑）、输出里没有段落头、没有「轮到本套了」 |
| ② 绿侧 | 空闲锁 → 子进程真的跑起来（holder 被它改写成 `cmd=smoke.sh`）、退出码原样透传（0）、没有排队噪音 |
| ③ 排到了 | 有竞争但上限内拿到 → 排队行 + 「轮到本套了（排过队）」照旧 |
| ④ rc 透传反例 | 子进程自己 `exit 1`（真红的门禁）→ 父进程 `exit 1`，**绝不**报成排队超限/加锁失败 |
| ⑤ premise | 旧形状（`exec flock -w`）超限 = `rc 1` + **零字节输出**（只看返回码不可能区分两者） |
| ⑥ 卫生 | 队列 marker 不留残留 |

四组都用私有锁（`$TMP/p66/lock`，`flock --close` 手工持有，kill 即释放）+ 私有 `TMPDIR`，
**绝不碰机器锁**，也不起 tmux/pi。段内内层 smoke 都是真入口（同一条排队守卫），只是拿到锁后立刻退出。
夹具自身耗时实测 **≈5.0s**（`pkg` 的三次 FAST 里同样只占这个量级），对 FAST 与全量门禁都是这个增量。

## Flip evidence (required for defect-fix tasks)

| 侧 | 树 | 结果 |
|---|---|---|
| 红 · 现场重放 | 同一棵树 + 守卫区域**逐字节还原成 base**（`exec flock -w`） | `rc=1`；输出只有排队那行，**之后再无一句**（`pkg/logs/10-legacy.log`） |
| 绿 · 现场重放 | 交付树 | `rc=2` + `排队超限：等满 1s 仍拿不到门禁锁 …（持锁者：… cmd=p66-holder）→ 本套**没有运行**…` |
| 红 · 守卫可证伪 | 变异树（旧守卫）+ FAST 全跑 | `34b` ✗ **4 条**，正是 ① 组（`exit 2` 那条在内）；其余 21 条仍绿（说明红的是这次修复的判据，不是夹具噪声） |
| 绿 · 守卫可证伪 | 交付树 + FAST 全跑 | `34b` ✗ **0 条**；整棵交付树除既有文档红外无新红 |

变异不是手搓一个「像旧版」的片段，而是用
`git show <base>:skills/teamsmith/tests/smoke.sh` 的**对应区域逐字节贴回**（生成器内部对区域内逐字节、
区域外零漂移、`SMOKE_LOCK_WRAPPED` 导出必须在场等做了断言）。第一版手搓 awk 变异漏掉了
`export SMOKE_LOCK_WRAPPED=1`，结果子进程自己二次排队 → 红侧出现一片**假红**（12 条）；换成逐字节还原后
红侧收敛成 4 条真红。这条教训值得留在包里：**变异本身也要可证伪**。

另外踩到第二个坑（与产品代码无关，但会影响整个仓库的门禁）：证据包的沙盒（`git archive` 出的仓库副本）
第一版建在 `pkg/out/` 下 —— §31 的 M28 tmux 隔离 lint 会扫 `docs/team/reports/*/pkg/**` 的脚本类文件，
于是那些副本里 M28 之前的旧证据包让 lint 报**148 条未隔离命令**，交付树的门禁因此变红（而且任何人在这棵树
上跑门禁都会中招）。已修：沙盒改到 `${TMPDIR:-/tmp}/p66-pkg-out`，`run.sh` 里加了一道「`P66_OUT` 不许落在
仓库树里」的拒绝。修完后 `perl skills/teamsmith/tests/tmux-lint.pl` 在交付树上 **红 0 条**（见下）。

## Verified commands (all really run on this machine)

（待 pkg3 收尾后补全；日志在 `docs/team/reports/P66-dev-bob/pkg/logs/`）

## Decisions and deviations

- 只动 `skills/teamsmith/tests/smoke.sh`（任务书 `grant:` 的唯一路径）+ 自己的报告/证据包
  （`docs/team/reports/P66-dev-bob/**`）。没碰 `references/**`、`openspec/**`、`scripts/**`。
  `openspec/specs/verification/spec.md` 的队列条文（`verification#The hard timeout covers the gate run,
  not the queue`）讲的是 `team review` 自己的排队账本（`queued/ran/limit`），**没有**对「smoke 自身的排队上限」
  下过条款，所以按 `anchor: none (infra)` 不需要改规格，也没有 BLOCKED。
- 新增了 `SMOKE_LOCK_SELFTEST_CHILD`（理由见上；默认不生效且总是打印）。
- 旧形状里那行 `printf '排队/加锁失败：flock 起不来…'; exit 2` 本来是**死代码**；现在它对应
  「没有 marker 且 rc≠1」，位置改了、语义保留。

## Findings (not in this task's scope)

- **保护分支上本来就有 5 条红**，与 P66 无关，全部来自文档不变量检查，来源是 `f534ec4b`
  （`skills/teamsmith/references/troubleshooting.md` 第 20 节）：英文正文里出现中文标题、以及一段没有 `--dir`
  的 `team review` 用法示例（`:1064` / `:1070`）。证据：`pkg/30` 在 base（不含本任务改动）的树上跑 FAST 得到
  同一组 5 条 ✗，交付树去掉 §34b 后的 ✗ 集合与它一一对应 —— **本任务没有引入新红**，但门禁在保护分支上
  是红的，需要 PM 处置（`docs/**` 与 `references/**` 归 PM）。
- 顺带记录（不改，避免越界）：`§34` 的 `p34_hold` 用 `flock -x … sleep N`（**不带 `--close`**），kill 掉 flock
  后 `sleep` 仍捏着锁 fd —— 那些私有锁因此实际要等 `sleep` 自己走完才释放（§34 的 cap 都很宽，所以现在不红）。
- **给后续证据包作者的坑（本任务踩过，已修）**：`docs/team/reports/*/pkg/**` 是 M28 tmux 隔离 lint 的扫描
  范围，而证据包常常要在沙盒里放一份仓库副本来跑门禁 —— 副本一旦落在 `pkg/` 下，lint 会把副本里 M28 之前
  的旧证据包全部当成真调用（实测 **148 条红**），**这棵树上任何人跑门禁都会红**。沙盒必须建在仓库树外
  （本包：`${TMPDIR:-/tmp}/p66-pkg-out`，并且 `run.sh` 拒绝 `P66_OUT` 落在仓库里）。

## Suggested next steps

- 复验：`bash docs/team/reports/P66-dev-bob/pkg/run.sh`（三次 FAST ≈ 20–35 分钟，取决于机器负载；
  `pkg/logs/` 里已存了本轮日志，可先读）。
- 门禁红：见上面 finding，需要 PM 处置 `references/troubleshooting.md` 的两处文档不变量。
