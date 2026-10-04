# P120 · §36⑦ 两条绿侧夹具在深 caller TMPDIR 下的环境假红（apply）

- **agent**: dev-bob
- **status**: delivered
- **phase**: apply
- **change**: `-`（`anchor: none (infra)` —— 只改 §36 的夹具判定，不改选段器/账本/裁决语义）
- **branch**: `task/P120-36⑦-tmpdir-infra-apply`（local 模式：分支留在本地 `.worktrees/dev-bob`，不 push；PM 复验后本地合并）
- **base**: `184a6ac7`（P120 brief）
- **实现提交**: `11e8d9df`（`skills/teamsmith/tests/smoke.sh`，只在 §36⑦ 内改：+判定 helper、两条绿侧改用它、红侧加守卫）
- **报告包**: `docs/team/reports/P120-dev-bob/logs/`（原始输出逐份落盘）

## 0. 结论

| brief 条目 | 结果 |
|---|---|
| 1. 先复现：深 TMPDIR（≥60 字符）跑 §36，抓出那两条红 | ✅ 复现 `✓110 ✗2`、`EXIT=1`，两条恰是 `36⑦ 夹具依赖键 --select 3b/6 的选集有红`；触发路径 = 嵌套 run 的前导段 §0c（私有 tmux socket 143–146 字节 > AF_UNIX 上限 107），键自己的收口行照旧 `✓37 ✗0` / `✓6 ✗0`（§1） |
| 2. 按 D33/P62 修：前置起不来 → 可见 SKIP + 归因点名深 caller TMPDIR；不靠墙钟 | ✅ 新增 `p117_green_verdict`，读嵌套日志的状态（P115 的 `p98_nest_state` 口径）：真红优先 → 照旧红；rc=0 → 收口行必须 `✗0`；其余 env → `cond_skip` + 归因（含「深 caller TMPDIR」与 socket 字节数）（§2） |
| 3. 红侧：让绿侧断言的实质坏掉 → 必须照旧红 | ✅ 原有两条红侧（3b 删 `needs:5`、6 删 `needs:3b`，即 needs 闭包坏掉）照旧红，且新判定出口对它们照旧给红（4 条断言）；另有合成两向夹具（环境红+真红 → 红；环境红+收口行 ✗0 → SKIP）；翻转变异 → 7 条守卫红（§4） |
| 4. 不碰 FAST 守卫 / 选段器 / 账本 | ✅ 只动 §36⑦；`section-select.sh --check` 7/7 绿；FAST 自检（14c）与账本断言一条未改（§5） |
| 5. 证据：深/默认两个方向 + FAST 全绿 + openspec validate | ✅ 深：`✓119 ✗0 SKIP7`；默认：`✓126 ✗0`；FAST 全量：`✓3052 ✗0`；`openspec validate --all --strict` 13/13（§3、§5） |

**判定：交付完成。** 修复前深 TMPDIR 下 2 条假红且结论文字误指选段器；修复后同一条命令下两条变成
**可见 SKIP + 归因**，默认 TMPDIR 下照旧 `✓`（承诺没放松）。

## 1. 复现：触发路径（深 caller TMPDIR → 嵌套 run 的私有 socket 超限）

命令（`$D` 长度 61 ≥ 60）：

```bash
D=/tmp/p120deep/$(printf 'a%.0s' $(seq 1 47)); mkdir -p "$D"      # len=61
cd .worktrees/dev-bob
TEAM_SMOKE_FAST=1 TEAM_SMOKE_NO_LOCK=1 TMPDIR="$D" \
  bash skills/teamsmith/tests/smoke.sh --select 36
```

原始输出 `logs/10-repro-deep-raw.log`：

```
  ✗ 36⑦ 夹具依赖键 --select 3b 的选集有红（rc=1；own=[#8 3b · git 归 PM（skill 不执行、也不过度包装 git） · 用时 3s · ✓37 ✗0 SKIP0 · ticks 37]）
  ✗ 36⑦ 夹具依赖键 --select 6 的选集有红（rc=1；own=[#9 6 · dispatch · 用时 0s · ✓6 ✗0 SKIP1 · ticks 7]）
#5 36 · 选段与分段账本自检（P98 · gate-runtime-budget） · 用时 111s · ✓89 ✗2 SKIP5 · ticks 96
== 选段结果 ==  ✓ 110  ✗ 2
```

**路径链**（每一环都在日志里可查）：

| 环节 | 路径 | 长度 | 结果 |
|---|---|---|---|
| 调用者 TMPDIR | `/tmp/p120deep/aaa…aaa` | 61 | — |
| 外层 run 的 TMP | `$TMPDIR/teamsmith-smoke.XXXXXX` | 84 | — |
| 外层 run 的私有 socket | `$TMP/tmux/tmux-1000/default` | **107** | 正好卡在 AF_UNIX 上限上 → 外层 §0c 隔离自检 ✓（所以顶层不红） |
| 嵌套 run 的 TMPDIR | `$TMP/p98-nest-tmp` | 97 | — |
| 嵌套 run 的私有 socket | `$TMPDIR/teamsmith-smoke.XXXXXX/tmux/tmux-1000/default` | **143**（§36⑤ 的 locksel 夹具 146） | `bind` ENAMETOOLONG → 嵌套 §0c 报 `tmux 隔离：私有 socket 没生效` → 嵌套 rc=1 |

**失败面只有判定方式**：嵌套 run 里键自己的收口行是 `#8 3b … ✓37 ✗0` / `#9 6 … ✓6 ✗0` ——
绿侧夹具要断言的实质（needs 闭包自足、选集全绿）**并没有坏**；坏的是前置环境（私有 socket 绑不上）。
两条夹具却用**裸 rc** 判定（`[ "$P117_GRC" -eq 0 ]`），于是把环境红记成了产品红。这正是 P115 已经修过的
§36③/④同族形状，只是这两条新夹具没接上 P115 的判定出口。

## 2. 修法（D33/P62：判定看状态，不看墙钟）

只动 `skills/teamsmith/tests/smoke.sh` §36⑦（`p117_own_line` 之后）。新增 `p117_green_verdict`：

```bash
p117_green_verdict() { # <key> <日志> <rc> → ok / 可见 SKIP + 归因 / bad
  line="$(p117_own_line "$log" "$key")"
  # ① 键自己的收口行有真红（✗>0）→ 照旧红（环境归因不许吞真红）
  # ② rc=0 → 收口行必须在且 ✗0（缺行也是夹具坏，照样红）
  # ③ 其余交给 p98_nest_state：env → 可见 SKIP + 归因；其它形状 → bad
}
```

- **两条绿侧夹具**（`--select 3b` / `--select 6`）改用判定出口；**承诺与标题一字不改**
  （正常环境下输出与原来逐字一致：`✓ 36⑦ 夹具依赖键 --select 3b 的选集全绿（#8 3b …）`）。
- **归因**：env 时 `cond_skip` 的文案点名「深 caller TMPDIR 导致嵌套 run 的私有 socket 不可用」，
  并附 `p98_nest_state` 从嵌套日志里取出的一手证据（`私有 socket 没生效 … ｜ 私有 socket 路径 143 字节 > AF_UNIX 上限 107`），
  **不带任何墙钟/sleep 判定**。
- **未碰**：FAST 守卫（14c）、选段器、账本、`p98_nest_state`/`p98_nest_verdict` 本身、其它段。
- `section-select.sh --check` 依旧 7/7：段正文没有引入未声明的路径 token。

## 3. 两向证据

### 3.1 深 TMPDIR（修复后）→ 可见 SKIP + 归因，不假红

同一条命令（`logs/20-postfix-deep-raw.log`，`EXIT=0`、`✓119 ✗0`）：

```
  SKIP（条件不满足） 36⑦ 夹具依赖键 --select 3b 的选集全绿 —— 深 caller TMPDIR 导致嵌套 run 的私有 socket 不可用（前置环境起不来，rc=1）：tmux 隔离：私有 socket 没生效（期望 …/p98-nest-tmp/teamsmith-smoke.mjKJyg/tmux/tmux-1000/default，TMUX_TMPDIR=… ｜ 私有 socket 路径 143 字节 > AF_UNIX 上限 107
  SKIP（条件不满足） 36⑦ 夹具依赖键 --select 6 的选集全绿 —— 深 caller TMPDIR 导致嵌套 run 的私有 socket 不可用（前置环境起不来，rc=1）：… ｜ 私有 socket 路径 143 字节 > AF_UNIX 上限 107
== 选段结果 ==  ✓ 119  ✗ 0
```

（同一日志里其余 5 条 SKIP 是 P115 已修的同族夹具；§36⑥ 的两向夹具在深 caller 下照旧全绿。）

### 3.2 默认 TMPDIR（修复后）→ 承诺照旧成立

`TEAM_SMOKE_FAST=1 TEAM_SMOKE_NO_LOCK=1 bash skills/teamsmith/tests/smoke.sh --select 36`
→ `logs/30-postfix-default-raw.log`，`EXIT=0`、`✓126 ✗0`：

```
  ✓ 36⑦ 夹具依赖键 --select 3b 的选集全绿（#8 3b · git 归 PM（skill 不执行、也不过度包装 git） · 用时 2s · ✓37 ✗0 SKIP0 · ticks 37）
  ✓ 36⑦ 夹具依赖键 --select 6 的选集全绿（#9 6 · dispatch · 用时 0s · ✓6 ✗0 SKIP1 · ticks 7）
```

两条是 `✓` 而不是 SKIP：判定出口只有在 rc≠0 且能归因到环境前置时才允许跳过。

### 3.3 红侧：绿侧断言的实质坏掉 → 照旧红

- **套内（每次门禁都跑）**：3b 删 `needs:5`、6 删 `needs:3b`（needs 闭包 = 这两条绿侧断言的承重实质）
  → `--select 3b/6` 在该键上红（`✗8` / `✗7`），并且**经新判定出口也是红**（新增 4 条断言：
  `判定出口照旧红` + `没把真红当环境跳过`）。
- **合成两向**（直接喂判定，不增嵌套跑成本）：
  - 环境红 + 键自身真红（收口行 `✗7`）→ 出口发 ✗、不 SKIP（**真红优先**）；
  - 环境红 + 收口行 `✗0` → 出口是可见 SKIP、归因点名「深 caller TMPDIR」、不带 ✗。

## 4. Flip evidence（红 → 绿 → 破 → 恢复）

| # | 形状 | 命令 | 结果 | 证据 |
|---|---|---|---|---|
| ① | **红 before**（修复前，深 TMPDIR） | §1 命令 | `✓110 ✗2`、`EXIT=1`，两条都被误记为产品红 | `logs/10-repro-deep-raw.log` |
| ② | **绿 after**（修复后，深 TMPDIR） | §3.1 | `✓119 ✗0 SKIP7`，两条变可见 SKIP + 归因 | `logs/20-postfix-deep-raw.log` |
| ③ | **绿 after**（修复后，默认 TMPDIR） | §3.2 | `✓126 ✗0`，两条照旧 `✓` | `logs/30-postfix-default-raw.log` |
| ④ | **破**：把判定改坏（`rc≠0` 一律当环境跳过，绕过收口行真红） | `TEAM_SMOKE_FAST=1 … --select 36`（默认 TMPDIR） | `✓119 ✗7`、`EXIT=1`：合成两向的 3 条 + 红侧的 4 条守卫全部红（绿侧本身仍 ✓，因为它 rc=0） | `logs/40-flip-mutant-raw.log` |
| ⑤ | **恢复**：`git checkout -- skills/teamsmith/tests/smoke.sh` | `bash -n … && git diff --stat` | 回到 `11e8d9df`；`bash -n` 过、工作树对该文件零 diff | 见 §7 过程记录 |

变异补丁（④，仅存在于那次运行）：

```bash
perl -0pi -e 's/(  local key="\$1" log="\$2" rc="\$3" line out st ev sl\n)/$1  if [ "\$rc" != "0" ]; then cond_skip "36⑦ …" "P120 翻转：非零一律当环境跳过"; return 0; fi\n/' skills/teamsmith/tests/smoke.sh
# → grep 命中 13356 行；运行；git checkout -- 恢复（git diff --stat 该文件为空）
```

## 5. 门禁

| 门禁 | 结果 | 原始输出 |
|---|---|---|
| FAST 全量（`TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh`，不选段、带机器锁） | `== 结果 ==  ✓ 3052  ✗ 0`、`smoke 全绿`、`EXIT=0` | `logs/50-fast-full-raw.log` |
| `openspec validate --all --strict` | `Totals: 13 passed, 0 failed`、`EXIT=0` | `logs/60-openspec-validate.log` |
| `bash skills/teamsmith/tests/section-select.sh --check` | `== 选段自检 ==  ok 7  bad 0` | `logs/65-selector-check.log` |
| 全量门禁（非 FAST，`bash skills/teamsmith/tests/smoke.sh`） | `== 结果 ==  ✓ 3718  ✗ 0`、`smoke 全绿`、`EXIT=0`；§36 `✓105 ✗0 SKIP0`（两条绿侧照旧 `✓`） | `logs/70-full-gate-raw.log` |

### 5.1 全量门禁

`bash skills/teamsmith/tests/smoke.sh`（默认带锁；排队到 02:22 才进锁，整套 25 分钟）跑完 113 段：
`✓ 3718 ✗ 0`、`smoke 全绿`，账本自查 `增量 ✓3718 ✗0 ｜ 结果行 ✓3718 ✗0 —— 一致`；
§36 `#95 … ✓105 ✗0 SKIP0`（两条绿侧在默认 TMPDIR 下照旧 `✓`）。原始输出逐字节在
`logs/70-full-gate-raw.log`。PM 的 `team review` 仍会在独立 worktree 重跑整套。

## 6. 原始输出索引（`docs/team/reports/P120-dev-bob/logs/`）

| 文件 | 内容 |
|---|---|
| `10-repro-deep-raw.log` | 修复前、深 TMPDIR（len=61）、`--select 36`：2 条假红 |
| `20-postfix-deep-raw.log` | 修复后、深 TMPDIR：两条变 SKIP + 归因，`✓119 ✗0` |
| `30-postfix-default-raw.log` | 修复后、默认 TMPDIR：两条照旧 `✓`，`✓126 ✗0` |
| `40-flip-mutant-raw.log` | 判定改坏（非零一律跳过）：7 条守卫红，`EXIT=1` |
| `50-fast-full-raw.log` | FAST 全量：`✓3052 ✗0` |
| `60-openspec-validate.log` | `openspec validate --all --strict`：13/13 |
| `70-full-gate-raw.log` | 全量门禁（若已完成） |

上述日志均为命令的逐字节原始输出（含 ANSI），报告里的引用只是裁剪行。

## 7. 决定与偏差（过程留痕）

1. **深 TMPDIR 选 61 字符**：brief 要求 ≥60。61 是刻意取的值 —— 外层 run 的私有 socket 正好 107 字节
   （AF_UNIX 的边界，bind 实测 107 OK），所以**顶层 §0c 自检保持绿**，复现出的 2 条红全部且只来自
   §36⑦ 那两条夹具；若 TMPDIR 再深，顶层 §0c 自己也会红（那是另一层、同族的环境问题，不在本任务范围）。
2. **判定 helper 放在 §36⑦ 而不是复用 `p98_nest_verdict`**：两条夹具的承诺里多一条「键自己的收口行
   `✗0`」，需要在状态判定之前先看收口行（真红优先）；直接复用 `p98_nest_verdict` 会把「env 红 + 键自身
   真红」误判成 SKIP。两者共用 `p98_nest_state`/`p98_nest_sock_len`，口径一致。
3. **没有改任何既有断言的语义**：两条绿侧在正常环境下的输出逐字不变；红侧、账本断言、FAST 自检
   只增不改。
4. **全量门禁**：本任务只改 §36（逻辑段，FAST 也照跑）；按 brief 的验收面先跑 FAST 全量 + validate，
   再补一次全量门禁（§5.1，带机器锁排队执行）以符合团队「交付前跑整套」的纪律。

## 8. Status

**delivered**。修复前深 caller TMPDIR 下 `✓110 ✗2`（两条环境假红）；修复后同一条命令 `✓119 ✗0 SKIP7`
（两条变成可见 SKIP + 点名归因），默认 TMPDIR 下 `✓126 ✗0`（承诺照旧成立），红侧有对照、变异有守卫，
FAST 全量 `✓3052 ✗0`、全量门禁 `✓3718 ✗0`、`openspec validate --all --strict` 13/13。

建议 PM：`team review P120 --strong`（独立 worktree 跑整套；深 TMPDIR 复跑命令见 §1）。

## 9. 建议的下一步（不在本任务范围）

- §36 里其它**裸 rc 判定**的嵌套跑（若有新增）统一走 `p98_nest_verdict`/`p117_green_verdict` 口径，
  避免同族再犯。
- 验证包/复验包的 TMPDIR 预算（P112/P115 已把验证包压到 len ≤22）可以顺带写进验证包模板，减少
  环境假红的触发面。
