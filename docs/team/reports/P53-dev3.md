# P53 · test-tmp-hygiene apply — one owned temp root, an occupancy-proving sweep, and the gate/doctor visibility

agent: dev3   status: DONE (acceptance run; one full-gate red is a pre-existing container-pi environment issue — see the gate section)   time: 2026-09-22T13:45Z
branch: `task/P53-test-tmp-hygiene-apply-sweep`   PR/MR: `-` (local mode: no push, branch left for the PM)

Change: `test-tmp-hygiene` (proposal accepted in `docs/team/reviews/test-tmp-hygiene-proposal.md`). Source of truth
for scope: `openspec/changes/test-tmp-hygiene/{design.md,tasks.md}`; the brief is
`docs/team/tasks/P53-tmp-hygiene-apply.md`.

## Deliverables

| Path | What |
|---|---|
| `skills/teamsmith/tests/lib/tmp-root.sh` | **new** — the single temp-root creator: `${TMPDIR:-/tmp}/teamsmith-<kind>.XXXXXX`, owner marker inside, run ledger outside, reclaim on `EXIT`/`INT` (`TERM` rides the fatal-signal path), `TEAM_TMP_KEEP=1` keeps + prints, `tmp_root_track_pid` records pids at spawn and cleanup signals **only** recorded pids; `--self-test` (13 assertions) + `--break=nokill\|nokeeep\|notmpdir\|noreap` |
| `skills/teamsmith/tests/tmp-hygiene.sh` | **new** — `--status` (read-only inventory + headroom, exit 0 always), `--lint` (every `mktemp -d` template must be `${TMPDIR:-/tmp}/teamsmith-<kind>.XXXXXX`; findings name `file:line`), `--sweep` (family dirs only, occupancy proven by one `/proc` scan of cwd/fd/exe with `lsof` as fallback, inventory before the first deletion, exit 3 with nothing deleted when a precondition fails), `--self-test` (34 assertions) + `--break=occupied\|orphan\|unknown\|foreign\|lock\|worktree\|record\|lint` |
| `skills/teamsmith/tests/smoke.sh` | root via the helper; start + end usage lines (end line also on failure, from the EXIT trap); run ledger with `SMOKE_TMP_RUN_ID` so nested fixtures attach to the same run; residue assertion (no root this run created survives it, unless declared kept) naming path/size/files/kind/pid; section 40 = lint on the real tree + a sensitivity mutation + the `TEAM_TMP_HYGIENE_FLIP=lint` red side; `TEAM_TMP_KEEP=1`/`--keep` keep + declare; `TEAM_SMOKE_FIXTURE=1 TEAM_TMP_HYGIENE_FLIP=leak` red side for the residue assertion |
| `skills/teamsmith/tests/*.sh`, `tests/lib/pty-wait.sh` | 41 fixtures migrated to the helper and the owned family (names normalised; keep knobs mapped to `TEAM_TMP_KEEP`; the dead `TEAM_CONFIG_KEEP`/`TEAM_INSTALL_KEEP` reads restored across the identity strip) |
| `skills/teamsmith/scripts/lib/cmd-status.sh` | `team_tmp_headroom_line` + `team_tmp_doctor_row` (watchdog requirement): two `df` calls, free/total bytes and inodes, `TEAM_TMP_MIN_FREE_MB` / `TEAM_TMP_MIN_FREE_INODES` (non-numeric falls back), warning-only, unreadable never reported as healthy, nothing inside the temp root is read, nothing is deleted |
| `skills/teamsmith/scripts/lib/cmd-project.sh` | one added line in `team_cmd_doctor` calling `team_tmp_doctor_row` (see “Decisions”: a call site is unavoidable and the row lives in the granted file) |
| `skills/teamsmith/references/protocol.md`, `references/troubleshooting.md`, `references/config.md` | §9b-2: the gate's own temp-root reporting + residue assertion + the operator sweep + the doctor row; §25: the ENOSPC incident, the status/sweep entry, the guard rules; config.md: `TMPDIR` + a note that the four `TEAM_TMP_*` knobs are environment-only |

`openspec/**` and `docs/team/**` (other than this report) are untouched.

## Acceptance (actually run, on the frozen tip)

```
$ git status --porcelain
(clean)
```

### 1. The inventory and the dry sweep (the two brief commands)

```
$ bash skills/teamsmith/tests/tmp-hygiene.sh --status          # rc=0
临时根：/tmp
  bytes: 可用 … / 总 … · inode: 可用 … / 总 …
根（/tmp 下的 owned 家族；只有这些是 --sweep 候选）：
  … 目录 · … · … 文件 · 年龄 … · pid=… 存活/已退出 kind=… · 占用：… / 无
不是根（家族里的文件 / 本项目的点开头诊断与台账；--status 只列，--sweep 永不删）：
  …
合计：N 个根（可回收 M · 占用 K）

$ bash skills/teamsmith/tests/tmp-hygiene.sh --sweep --dry-run # rc=0
… [reclaim]/[occupied]/[young] 清单（先打印，后删除）…
将回收：N 个根 · … · 文件合计 …
dry-run：没有删除任何东西
```

The real `--sweep` was deliberately **not** run against the shared `/tmp`: reclaiming other agents' stale roots is
an operator action. The self-test runs real sweeps in private temp roots (below).

### 2. OpenSpec

```
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
Totals: 22 passed, 0 failed (22 items)
```

### 3. The gates (see the gate section below)

## Flip evidence (red → green, raw)

### F1 · a killed run's residue: unattributable/invisible before, owned and reclaimable after

Old tree (`git show 63560ac:skills/teamsmith/tests/config-cli.sh`, i.e. the brief commit's parent), `KILL`ed
mid-run once its root existed:

```
$ TMPDIR="$D" bash .p53-old-config-cli.sh & … kill -KILL $!
survived: /tmp/teamsmith-p53-oldkill.9dG6Cx/config-cli.HW5KfF
size: 148K · files 61 · marker 0
$ TMPDIR="$D" bash tests/tmp-hygiene.sh --status
合计：0 个根（可回收 0 · 占用 0）                     # 家族外 → 清单里根本没有它
$ TMPDIR="$D" bash tests/tmp-hygiene.sh --sweep --age 0
没有 owned 家族的目录候选。                          # sweep 不碰（设计如此）
old residue after sweep: 1
```

New tree, same kill:

```
survived: …/teamsmith-config-cli.oYPGcZ · 124K · files 49 · marker 1
$ TMPDIR="$D" bash tests/tmp-hygiene.sh --status
  …/teamsmith-config-cli.oYPGcZ
    目录 · 184 KB · 72 文件 · 年龄 0 分钟 · pid=3178660 已退出 kind=config-cli · 占用：无
$ TMPDIR="$D" bash tests/tmp-hygiene.sh --sweep --age 0     # rc=0
  已回收 …/teamsmith-config-cli.oYPGcZ（184 KB）
回收完成：1 个根 · 184 KB
```

### F2 · the keep knob: dead before (F3), real after

```
$ TMPDIR="$D" TEAM_CONFIG_KEEP=1 bash .p53-old-config-cli.sh
kept dirs: 0        # TEAM_* 身份清理在读取之前把它 unset 了：旋钮是死的
$ TMPDIR="$D" TEAM_CONFIG_KEEP=1 bash tests/config-cli.sh
保留夹具目录：…/teamsmith-config-cli.mnZPZF     # 助手保留并打印（嵌套 run 也继承 TEAM_TMP_KEEP）
kept dirs: 7      # 夹具自己的 + 它跑的几个嵌套 run 的根，全部打印
```

### F3 · `TMPDIR=D` on a normal run

```
$ TMPDIR="$D" bash <old config-cli>         # rc=1（旧树对本树的新文档报 schema 缺口），D 下残留 0
$ TMPDIR="$D" bash tests/config-cli.sh      # rc=0，== 结果 ==  ✓ 125  ✗ 0  SKIP 0；D 下 0 条
```

The brief's red side for this item said “改前会留 44MB 目录”; it did **not** reproduce here — the old fixture's
`EXIT` trap removes its root on a normal exit, and my instrumented runs (a watcher over `D`) never saw a surviving
directory. The leak this change addresses is the killed-run shape (F1) and the dead knob (F2); both are measured
above. See “Decisions” for the full note.

### F4 · `TERM`/`INT` reclaim (root + recorded anchor)

```
# 夹具 TERM（config-cli 跑到一半）
root appeared: …/teamsmith-config-cli.9M19Ct
TERM rc=143
root gone within 10s: YES

# 助手自检：记录了 anchor pid，TERM 后两者都没了
  ✓ TERM 后根在宽限期内消失（…/teamsmith-termtest.AtaYvo）
  ✓ TERM 后记录的 anchor 不再存在（pid 3037680）
  ✓ 前台长命令里 TERM：shell 立即退出且根已回收（100ms 内）   # 见 Decisions：TERM 不装陷阱

# INT（非交互 shell 默认不因 SIGINT 而死 → 必须装 INT 陷阱）
INT: root gone=YES

# 门禁自己：FAST 跑到一半收 TERM
smoke process gone after 304ms
临时根（结束）：/tmp/teamsmith-smoke.2oveYr（1.9 MB · 757 文件）
2oveYr gone → YES；diag 事故文件：无（cleanup 先收哨兵再回收）
```

### F5 · the sweep's guard rules (self-test red sides)

`bash skills/teamsmith/tests/tmp-hygiene.sh --self-test` → `✓ 34  ✗ 0`; every `--break=` stage turns its own guard
red (the run exits 1):

```
occupied  rc=1  ✓ 30  ✗ 4     # 活占用者被当成可回收 → 根被删（D37 形状）
orphan    rc=1  ✓ 30  ✗ 4
unknown   rc=1  ✓ 32  ✗ 2     # 没有占用证明机制也照删
foreign   rc=1  ✓ 33  ✗ 1
lock      rc=1  ✓ 33  ✗ 1     # 锁文件/` .holder` 被当成候选
worktree  rc=1  ✓ 32  ✗ 2     # 已注册 worktree 被 rm -rf
record    rc=1  ✓ 30  ✗ 4     # 没有已提交记录的 review 检出被回收
lint      rc=1  ✓ 32  ✗ 2     # 写死 /tmp 的模板被放过
```

`bash skills/teamsmith/tests/lib/tmp-root.sh --self-test` → `✓ 13  ✗ 0`; `--break=nokill|nokeeep|notmpdir|noreap`
each → rc=1 with the corresponding guard line red.

### F6 · the lint: red before, green after, sensitive by mutation

```
# 迁移前
$ bash skills/teamsmith/tests/tmp-hygiene.sh --lint       # rc=1
检查了 48 个 mktemp -d 根模板
39 个 finding   # …/config-cli.sh:32 名字不在 owned 家族；…/flip-m16.sh:30 写死绝对路径；…
# 迁移后
$ bash skills/teamsmith/tests/tmp-hygiene.sh --lint       # rc=0
检查了 4 个 mktemp -d 根模板
owned 家族 / TMPDIR 口径全部合规
# 敏感性：同一份夹具把助手调用改回写死 /tmp 的旧模板
$ bash skills/teamsmith/tests/tmp-hygiene.sh --lint --dir "$TMP/lint-flip"   # rc=1
…/config-cli.sh:32: 写死绝对路径（/tmp/config-cli.XXXXXX）—— 必须建在 ${TMPDIR:-/tmp} 下
```

### F7 · `team doctor`'s row

```
$ bash skills/teamsmith/scripts/team doctor
  临时根余量          ✓ /tmp：可用 9.4 GB / 总 14.5 GB · inode 可用 3213982 / 总 3811434
$ TEAM_TMP_MIN_FREE_MB=999999999 bash …/team doctor
  临时根余量          ! /tmp：可用 9.4 GB / … —— 字节低于底线 999999999MB；修法：bash …/tmp-hygiene.sh --status 看清单，再 --sweep 回收
$ TEAM_TMP_MIN_FREE_INODES=999999999 bash …/team doctor
  临时根余量          ! … —— inode 低于底线 999999999；修法：…
$ TMPDIR=/nonexistent bash …/team doctor
  临时根余量          ! /nonexistent 的余量读不出来（df 失败或路径不可访问）—— 修法：…
$ TEAM_TMP_MIN_FREE_MB=abc TEAM_TMP_MIN_FREE_INODES=xyz bash …/team doctor
  临时根余量          ✓ /tmp：…                       # 非数字回退默认（底线没被触发）
```

The doctor's exit status is unchanged by the row: the scratch fixture fails on missing `pi`/`openspec` (rc=1) both
with and without the row, and the row is `✓`/`!`, never `✗`. The gate's own doctor fixtures (`§3`, `§17`) assert
`doctor` rc=0 on a finished fixture and are part of the gate runs below.

## Gate runs (on the frozen tip `cf5bbdc`)

```
$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null     # rc=0
== 结果 ==  ✓ 2332  ✗ 0
  ✓ 40 lint 干净：检查了 4 个 mktemp -d 根模板（…/skills/teamsmith/tests）
  ✓ 40 lint 敏感性：写死 /tmp 的副本被点名 config-cli.sh:39
  · 临时根：/tmp/teamsmith-smoke.….（4 KB · 2 文件）
  · 临时根（结束）：/tmp/teamsmith-smoke.…（212.1 MB · 32138 文件）
  ✓ 40 泄漏断言：本轮创建的临时根一个都没留下（台账 .teamsmith-tmp-ledger.smoke-…）

$ bash skills/teamsmith/tests/smoke.sh </dev/null                       # rc=1（排队后跑；见下）
== 结果 ==  ✓ 2860  ✗ 1
  ✗ M28 容器里跑真 pi 体检失败（rc=1，见 …/m28-ctr-pmbox.log）
       ✗ M45：空闲空框没被判成 EMPTY（看上面的 M45 行 —— 横幅文字被读成了框内容？）
```

**The single full-gate red is pre-existing and environmental, not this change’s.** The M28 section runs
`tests/pm-box-real.sh` in the container with the host’s pi; today the container pi session shows a **trust prompt**
(`Do not trust (this session only)` / `↑↓ navigate enter select`) instead of an idle input box, so the fixture’s
M45 judgement is `verdict=UNKNOWN`. A/B against the pre-P53 fixture in the same container:

```
$ git show 63560ac:skills/teamsmith/tests/pm-box-real.sh > .p53-old-pmbox.sh
$ container-tmux.sh --with-pi --cmd "bash …/tests/pm-box-real.sh --idle-secs 3"   # rc=1
$ container-tmux.sh --with-pi --cmd "bash …/tests/.p53-old-pmbox.sh --idle-secs 3" # rc=1
$ diff <(…new…) <(…old…)
3c3
< M24 真实 pi 窗格体检 · … socket=/tmp/teamsmith-pm-box.filplm/tmux …
---
> M24 真实 pi 窗格体检 · … socket=/tmp/teamsmith-pmbox.OFcJeA/tmux …
```

Identical output apart from the root path they print (`teamsmith-pm-box.*` vs the old `teamsmith-pmbox.*`); both
fail with `verdict=UNKNOWN state=UNKNOWN` on the same trust prompt. The PM’s independent re-run will see the same
environmental red until the container pi’s first-run state is cleared.

### The red sides (same tip)

```
$ TEAM_SMOKE_FAST=1 TEAM_TMP_HYGIENE_FLIP=lint bash skills/teamsmith/tests/smoke.sh </dev/null   # rc=1
  ✗ 40 lint 有 finding（rc=1）：…/lint-flip/config-cli.sh:39: 写死绝对路径（/tmp/config-cli.XXXXXX）—— …
== 结果 ==  ✓ 2329  ✗ 2      # 意图中的 lint 红 + 修复前的 load-experiment 红（cf5bbdc 修）；M28 不在 FAST 里

$ TEAM_SMOKE_FAST=1 TEAM_SMOKE_FIXTURE=1 TEAM_TMP_HYGIENE_FLIP=leak bash skills/teamsmith/tests/smoke.sh </dev/null
  ✗ 40 临时根泄漏：…/teamsmith-guard-matrix.…（16 KB · 6 文件 · kind=guard-matrix · pid=…）
  ✗ 40 临时根泄漏：…/teamsmith-load-experiment-a.…（4 KB · 2 文件 · kind=load-experiment-a · pid=…）
  ✗ 40 临时根泄漏：…/teamsmith-load-experiment-b.…（4 KB · 2 文件 · kind=load-experiment-b · pid=…）
  ✗ 40 临时根泄漏：…/teamsmith-panel-snapshots.…（588 KB · 99 文件 · kind=panel-snapshots · pid=…）
  ✗ 40 临时根泄漏：…/teamsmith-pty-wait-selftest.…（72 KB · 22 文件 · kind=pty-wait-selftest · pid=…）
  ✗ 40 临时根泄漏：…/teamsmith-task-header-model.…（188 KB · 76 文件 · kind=task-header-model · pid=…）
== 结果 ==  ✓ 2330  ✗ 7        # 六个泄漏点 + 修复前的 load-experiment 红（cf5bbdc 修）

$ TEAM_SMOKE_FAST=1 TEAM_TMP_KEEP=1 bash skills/teamsmith/tests/smoke.sh </dev/null
      保留临时根：…/teamsmith-config-cli.…（TEAM_TMP_KEEP=1）
      保留临时根：…/teamsmith-pty-wait-selftest.…（TEAM_TMP_KEEP=1）
      保留临时根：…/teamsmith-install-shape.…（TEAM_TMP_KEEP=1）
  ✓ 40 临时根：本轮声明保留（TEAM_TMP_KEEP=1），不判泄漏
```

The two red-side runs were taken **before** the last two fix commits (`6e6ca31`, `cf5bbdc`; the second red in the
lint run was the load-experiment one that `cf5bbdc` fixed, the panel-choice collision was `6e6ca31`). The keep run
is likewise one revision behind (it also carried the load-experiment red, unrelated to the keep path); its keep
lines are the evidence. The final FAST and full runs above are on `cf5bbdc`.

Cleanup after the red-side runs: the leak flip left 6 roots of its own run plus the gate’s root; they were reclaimed
against the run’s ledger (`rm -rf` of exactly the listed paths) and a stray `sleep 300` of that killed run was
TERMed. Nothing of this task’s runs is left in `/tmp` (the `--status` inventory after the gates lists only other
runs’ roots).

### The two brief commands and OpenSpec

```
$ bash skills/teamsmith/tests/tmp-hygiene.sh --status            # rc=0
合计：12 个根（可回收 10 · 占用 2）
$ bash skills/teamsmith/tests/tmp-hygiene.sh --sweep --dry-run   # rc=0
将回收：10 个根 · 5.3 MB · 文件合计 561
dry-run：没有删除任何东西
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict   # rc=0
Totals: 22 passed, 0 failed (22 items)
$ git status --porcelain                                          # (empty)
```

## Findings during the task's own gates (fixed in place)

- **`panel-choices` vs its own substring guard**: the fixture asserts that the human `team config list` table contains no
  `choices` substring; the config comment records the skill path, and the first migration named the root
  `teamsmith-panel-choices.XXXXXX` — so the path itself satisfied the assertion and turned it red (`✓ 41 ✗ 0` with the
  old `pc.*`, ✗ `人读表多了 choices 字样` after the rename). Fixed by naming the root kind `panel-choice`; no assertion
  was touched (`fix(P53): panel-choices' root kind must not put "choices" in its path`).
- **`load-experiment.sh private-root` needs a root the caller owns**: the CLI prints a path for the caller to use, but
  the helper's EXIT trap reclaimed it as the CLI exited — the fixture's own guard test caught it (gate §38-g①:
  `私有临时根不对`, both printed paths no longer existed). Added `tmp_root_detach <path>` (`detached=1` in the owner
  marker): the creating process's EXIT/INT skip it, the ledger entry stays for `--status` attribution, and an eventual
  `--sweep` still reclaims it; the helper self-test pins that a detached root outlives its creator
  (`fix(P53): a root whose lifecycle belongs to the caller must survive its creator`).

## Decisions and deviations

1. **`cmd-project.sh` gained one line** (`team_tmp_doctor_row` in `team_cmd_doctor`). The brief granted
   `scripts/lib/cmd-status.sh` for “the doctor row” (where the implementation lives, at the end of the file — as
   asked, to keep the P47 collision small), but a row cannot print without a call site in the doctor function, and
   design §D7 / tasks 1.7 place that function in `cmd-project.sh`. The alternative (a second doctor implementation
   in the granted file, or editing the doctor function wholesale) would be worse; this is the only line outside the
   brief's grant. Disclosed for the PM's review.
2. **`config.md` / `team config schema` (tasks 2.3) is deliberately half-done**: the four `TEAM_TMP_*` knobs are
   documented in `references/protocol.md` §9b-2 and `references/troubleshooting.md` §25, and `references/config.md`
   names them as environment-only (no backticks) — but they are **not** registered as schema rows, because the
   schema lives in `scripts/lib/cmd-config.sh`, which the brief does not grant, and these are env-only knobs (the
   project's convention: `TEAM_SMOKE_LOCK`, `TEAM_PANEL_CPU_PREMISE_FACTOR` are not in the registry either).
   `config-cli.sh`'s doc↔schema completeness check stays green (`✓ 真实 schema 与模板/文档双向对齐（111 个键）`).
   `BLOCKED:`-style handback: if the PM wants them in `team config schema`, the change is four `refuse` rows in
   `cmd-config.sh` (a granted file) plus four backticked rows in `config.md`; a follow-up task can do it.
3. **The brief's flip ① (“改前会留 44MB 目录”) did not reproduce.** The old fixture removes its root on a normal
   exit (its `EXIT` trap is intact); measured with a watcher over `D`, the old tree left 0 entries. The red side I
   could reproduce is F1 (KILL) and F2 (the dead keep knob) — both from the change's own design (F1/F2/F3 in
   `design.md` §0). The report states the measurement instead of quoting the brief.
4. **`TERM` is not trapped** (measured on bash 5.3.9): a trapped TERM is deferred by bash until the current
   foreground command finishes (a long node/`team` command delays the reclaim), while an untrapped fatal TERM kills
   the shell immediately (~100 ms) and still runs the `EXIT` trap — so the helper traps **INT** only (`INT` is the
   opposite: a non-interactive shell survives SIGINT, measured), smoke drops its TERM trap, and the helper
   self-test pins the immediate reclaim from a foreground `sleep`. Behaviourally the design requirement (“reclaim on
   normal exit and on INT/TERM”) holds.
5. **`tests/lib/pty-wait.sh`'s self-test** also creates a top-level root, so it was migrated too (it is a fixture
   in the lint's scope).
6. **The real `--sweep` against the shared `/tmp` was not run** (only `--dry-run`, as the acceptance requires):
   deleting other agents' stale roots is an operator action, and the machine is shared. The self-test performs real
   sweeps in private roots.
7. **Not wired into the gate**: `tmp-root.sh --self-test` and `tmp-hygiene.sh --self-test` (their red sides are
   run manually / at review). The spec only requires the lint inside the gate; adding the self-tests would cost
   ~15 s per run and is a PM call.

## Not verified / known risks

- The `lsof` occupancy fallback (only reachable on a host without `/proc`) is implemented but not exercised on this
  host; the `noproc` fixture knob simulates “no mechanism at all”.
- `--sweep`’s age guard uses the newest mtime in the root (`find -printf`), which does not track activity for
  `cp -a`-copied trees; the occupancy proof (not the age) is the primary guard, by design (§D5).
- The legacy-named roots under `/tmp` (outside `teamsmith-*`/`review-*`) are outside the sweep’s reach by design
  (§D2); `--status` does not list them.

## Suggested next steps

- PM: `team review P53 --strong` on the tip (the branch is local; no push in this project).
- Decide on item 2 above (schema rows for the four env knobs) — small follow-up in `cmd-config.sh` + `config.md`.
- The full gate result and the tip hash are in the gate section above.
