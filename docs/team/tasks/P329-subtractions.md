# P329 · 三处减法：§58 内联翻转、cap 算式里的假话、两份「席位=运行时目录」

task: P329
agent: dev-bob
phase: apply
category: code
change: -
anchor: none (infra) — P328 清点后的三条裁定，全部是删除/合并，不新增机制
deltas: -
branch: task/P329-subtractions
deps: **P326 必须先落地**（它正在写 `smoke.sh` / `section-paths.tsv` / `section-select.sh`；同一批文件不许两个写者）。派单前 PM 会确认 P326 已并入 main。

## 三件事，都来自 P328 的裁定

### 1 · §58 的三条内联翻转：删两条，留 flip②

在 `skills/teamsmith/tests/smoke.sh` 的 §58 里：

- **删 `58 翻转①`（干净文件不报红）与 `58 翻转③`（`kill "$pid"` 不报误报）**，连同它们往 `$P159_SB` 写的两份源码。理由：`signal-lint.pl --selftest` 的夹具表（29 例）已经把每例写成 `case.sh` 用 `--root` 扫过一遍，`clean` 类里有 `kill_term_pid` 等对应形状，删掉的两条是它的子集。
- **`58 翻转②` 原样保留**：它断言的是「种下的 `pkill -f` 被判红**并按 `file:line` 点名**」，而 `--selftest` 只判红/净、不判位置。在旁边加一行注释写明这个分工：「夹具表判红/净，本条判位置」。

### 2 · cap 算式：删假话与只为自造数字服务的断言，不动代码

`scripts/lib/gate-lock.sh` 的 `gate_lock_cap`（`cap = clamp(remaining + 60, W, 4W)`）**保留**。要做的是：

- 删掉 `smoke.sh` 里那两处调用后的注释「P316：预算表退役；expected/bound 为 0/0」——实测 `bound=121500`，这句话是假的；改成「P316 之后没有生产者 → `expected=0`，cap 退回 W」。
- 删掉 §34⑦ 与 §34b⑨ 里**只为自造 `expected=400/300` 服务**的 cap/remaining 断言。
- **保留**：§34b①/⑦（排队超限大声失败、点名持有者）、以及「读不到 `expected` 时退回 W」这条真行为的断言。

### 3 · 两份「席位 = 运行时目录」：共享推导，不共享失败语义

`scripts/lib/common.sh` 的 `team_sender_from_dir` 与 `scripts/lib/gate-lock.sh` 的 `gate_lock_seat_of_dir` 是同一套推导的两份实现。合并成一份（`gate_lock_seat_of_dir` 调用 `team_sender_from_dir`，或把推导抽成一个函数给两边用），**但失败语义保持不同**：

- 锁记录：解析不出就写 `?`，**记录必须写成功**（它是诊断证据）。
- `team notify`：解析不出**必须拒绝**（发给谁都不知道）。

`smoke.sh` §34b⑨ 里「解析不出写 `?`」的断言保留；把「与 notify 逐字同源」的断言改成「调用同一推导函数」的可核形状（例如两边对同一组目录给出相同结果，而失败时的行为各一条）。

## 边界

- 不动 `signal-gate.sh` / `team-bg-stop.sh` / `panel-b2.sh` / `panel-p21.sh`（P318 刚落地，本轮不碰）。
- 不动任何产品行为语义（第 3 条是等价重构 + 失败语义保持不变）。
- **守卫净零**：这三条全是减法，不许新增检查器/夹具/预算表。
- 两处不是「配方」而是「断言」的改动，必须给红侧：把 fake 注释放回去（第 2 条）、把 `gate_lock_seat_of_dir` 改回自己那份实现并改坏一条解析规则（第 3 条）→ 对应断言必须红。

## 验收

```bash
bash skills/teamsmith/tests/section-select.sh --paths skills/teamsmith/tests/smoke.sh skills/teamsmith/scripts/lib/gate-lock.sh skills/teamsmith/scripts/lib/common.sh
bash skills/teamsmith/tests/smoke.sh --select 34 34b 58
openspec validate --all --strict
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check && git status --short
```

报告里报三组数字：§58 段断言数、§34/§34b 段断言数、`gate-lock.sh` 行数；三处都要「删了多少、留了什么、红侧是哪一条」。
