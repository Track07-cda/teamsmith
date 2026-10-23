# P374 · `§34d 2.1` 的期望值写死了默认锁名，于是任何用私有 `TEAM_SMOKE_LOCK` 跑的人都拿到假红

task: P374
agent: dev
phase: apply
category: code
change: -
specs: verification#The gate judges behaviour only, and never reports a skip as a pass
anchor: none (infra) — 夹具
deltas: -
branch: task/P374-34d-lock-shape

## 事实（V103 复验时撞到，`docs/team/reports/V103-dev3.md` F1）

`skills/teamsmith/tests/smoke.sh:18187-18196`：

```
P287D_DEF="$(gate_lock_default_path)"            # 外层设了 TEAM_SMOKE_LOCK 时，它返回**那把锁**的路径
if [ -z "${TEAM_SMOKE_LOCK:-}" ]; then … else ok "…按同一规矩换输入（避免误判）"; fi
assert_eq "34d 2.1 默认路径 → 伴生锁（同行同目录、basename + .machine）" \
  "$(gate_lock_companion_path "$P287D_DEF")" "$(dirname "$P287D_DEF")/.teamsmith-smoke.lock.machine"
```

第二行已经**明知**外层可能设了私有锁并换了输入，下一个断言却把期望值写成字面量 `.teamsmith-smoke.lock.machine`。
于是 `TEAM_SMOKE_LOCK=/var/tmp/…/7-1.lock` 时实际得到 `.7-1.lock.machine` → **假红**（V103 的 `✓390 ✗1` 就是它）。

## 要做的（一处，最小）

1. 让期望的伴生路径**从同一输入派生**，而不是字面量。注意伴生锁的规则是「同行同目录、`basename` 前加点、后缀 `.machine`」，
   而默认名的 `basename` **本身已带点**——所以派生公式要按真实规则写，别把双点写进去。
   最稳的形态：**断言形状**（同目录、以 `.` 开头、以 `.machine` 结尾、去掉首点后等于 `basename(default)` + `.machine`）
   ＋ 在 `TEAM_SMOKE_LOCK` 未设时**仍然断言那个字面量**（保住「默认名就是 `.teamsmith-smoke.lock`」这条。
2. **红侧**：私有副本里把 `gate_lock_companion_path` 改成「把伴生锁放到临时根下」→ 形状断言必须红；还原必须绿。
3. **两种输入都跑**：一次不设 `TEAM_SMOKE_LOCK`、一次设成 `/var/tmp/<私有>/7-1.lock`，两次 `--select 34d` 都必须全绿
   （这是本条的病根场景）。贴两次读数与 rc。

## 边界

写集：`skills/teamsmith/tests/smoke.sh`（只那两条断言）、报告。不改产品（`gate-lock.sh` 的推导是对的）、不加段、不改别的断言。
