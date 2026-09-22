# gate-section-accounting · design

Status: propose phase (planning only — no `skills/**` change in this task). Every measured number below was
taken in this task's block; the raw artifacts are committed next to the report
(`docs/team/reports/P56/{probe-section-guard.sh,probe-section-guard.log,probe-section-guard.v1.log,
fast-section-times.tsv,fast-run-tail.txt}`) so the apply and the verify can re-run the same shapes.

## 0. The incident, stated precisely

- **2026-09-22 12:03** (PM's brief): `main`'s CI `gates` job sat in the step `Gates (pinned container)` for
  **45+ minutes** against a normal whole-run time of **~12 minutes**; the job timeout is **60 minutes**.
  **The logs were not available** (an in-progress job's logs 404), so **not one line said which section it was
  in** — and after the job ends, the log tail will show a partial suite with no self-report either.
- The **same commit** in the **local pinned image** ran the whole smoke **green** (`✓2837 ✗0`, ~11 minutes).
  So this is not a deterministic product deadlock: something in the run was *waiting*, and the environment
  (4 cores, slower, no TTY, cgroup differences) is inside the loop.
- P48's progress-aware extension has a **hard ceiling** on every pty wait (`~26 s` base × `PTY_EXT_FACTOR=3`
  ≈ **78 s**), so the stall was **not** inside a pty wait; P52 is verifying that ceiling separately.
- The gate is one **12 107-line bash script with 92 inline `section` blocks** (`skills/teamsmith/tests/smoke.sh`).
  It prints a section header (`== <id> ==`, `section()` at `:161`) but **no timestamp**, **no budget**, **no
  elapsed time**, and **no bound**: the first clock that can stop a section is the *outer* one — `team review`'s
  `TEAM_REVIEW_TIMEOUT` (1800 s, `cmd-review.sh:544`) or the CI job's `timeout-minutes: 60`
  (`.github/workflows/gates.yml`) — and neither names a section.
- D39's channel already exists and works: the CI does **not** `--rm` the gate container, then
  `docker cp teamsmith-gates-run:/tmp/. .ci-artifacts/` (`if: always()`), then uploads with
  `include-hidden-files: true`. Two earlier attempts through bind mounts produced zero files on the runner, so
  `docker cp` is the channel that carries evidence out. **This change must not touch it — it must land its
  scene where that step already collects** (`/tmp`, dot files included).

**The gap this change closes**: the run cannot say *where it is*, *how long it has been there*, *what it is
waiting for*, or *when it stopped making progress* — and nothing bounds a single section. One line in the log
would have turned the 45-minute incident into a named section plus a scene.

## 1. What was measured in this block

### 1.1 The local instrumented FAST run (the seed for the budget table)

`TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null`, every output line timestamped
(`perl -MTime::HiRes=time`) → `docs/team/reports/P56/fast-section-times.tsv`. Result **`✓2350 ✗0`, exit 0**,
**92 sections, 561.5 s wall** (premise: `nproc=32`, 1-minute `loadavg` **10.59** at start — three full gates
from other seats were in flight; the suite's own header calls FAST "目标 < 60s", i.e. the machine inflated it
~9×). The slowest rows (full table in the TSV):

| sections (slowest) | elapsed (s) | | sections | elapsed (s) |
|---|---|---|---|---|
| `38 · 设置选项（M55）` | 56.9 | | `33 · 项目契约的读写面（P22/B1）` | 33.3 |
| `34 · 门禁锁：排队/运行分开记账（P26/G1）` | 47.4 | | `15c · harness 与插件清单（M29）` | 21.8 |
| `12b-pi · M30 投递换道` | 40.6 | | `17 · 迁移指南与 doctor 指引（M7.1）` | 20.8 |
| `26 · 面板（pulse-tui-panel）` | 37.9 | | `12b-pi3 · M53 降级通道可见` | 20.6 |
| `39 · npm CLI 与项目 skill 安装（P40）` | 33.7 | | `12b · 延后投递与草稿入口` | 17.1 |

This is a **loaded** machine, which is the right side of the band: a budget derived from an idle run would be
the false red this project keeps paying for. The **full-mode** run was measured in the same block (queued behind
the other seats' gates, `docs/team/reports/P56/full-section-times.tsv`): **`✓2879 ✗1`, 1050.1 s wall** for 91
sections (one red, the pre-existing host-environment `31b2` leg — see the report), with the heavy tail the FAST
run cannot show: **`38` 291.5 s**, `26` 67.5 s, `12b-h0b` 62.4 s, `34` 47.4 s, `12b-pi` 40.6 s. The container
column was not measurable in this block (three full gates from other seats held the machine lock), so the apply
owns it; the derivation rule (§3 D2) does not depend on these absolute values — but two measured rows already
shape it: `38`'s 291.5 s makes a 4× budget for it ~1166 s, i.e. **larger than any whole-run ceiling the outer
timeouts could host** (§3 D3), and the FAST run showing ~9× its intended budget under load is why the band must
come from a loaded run.

### 1.2 The poll-loop census (requirement *Every wait in the gate is bounded*)

| | count |
|---|---|
| gate source files scanned (`skills/teamsmith/tests/*.sh`, `tests/lib/*.sh`) | 51 |
| `while` loops with a `sleep` in the body | **43** |
| of those, carrying **no visible cap** | **3** |

The three, each structurally bounded and therefore inventory entries with a named bound rather than rewrites:
`smoke.sh:360` (the M33 tripwire: exits on the stop file or the owner's death), `panel-cpu.sh:286` (the CPU
sampler: bounded by `sub_end`, a computed deadline), `flip-m7.2.sh:187` (a diagnostic sampler: bounded by the
stop file its caller writes). So the audit is mechanical (43 rows) and the code change is small.

### 1.3 The mechanism probe (what the bound can and cannot rely on)

`docs/team/reports/P56/probe-section-guard.sh` (throwaway; the apply builds the real module). **v2: 41/41 green**
over five shapes — a stuck foreground child (`sleep infinity`), a child that ignores `TERM`, a clean section, a
builtin spin (`while :; do :; done`), and a builtin spin that also traps `TERM` out. **v1** (kept as
`probe-section-guard.v1.log`) measured three facts that decided the design:

1. **Killing a section's stuck child does not stop the suite**: bash reports `Terminated` and executes the *next*
   command. A watchdog that only kills the child races the suite's own exit (v1 case A: the suite ran to `exit 0`
   after its stuck child was killed).
2. **A `TERM` trap is not a deterministic stop channel**: bash defers it while a foreground child runs, and it can
   fire *after* the next command (`AFTER` printed before the trap at t+30 s in the isolated test). Only the
   *builtin* spin shape stops on `TERM` alone (v2 case D).
3. **A `ps | tail` snapshot can miss the stuck child** on a busy machine (v1 case A); the scene must carry the
   suite's **descendant tree** explicitly, not only a bounded whole-table snapshot.

## 2. Goals / Non-Goals

**Goals**
- Every section says *where the run is* (`#<N>`, id, ISO-8601 timestamp, budget) and *how long it took*.
- Every section has a hard budget with a **recorded measured basis**; the first section over it stops the run
  with a red that names it, and leaves a scene that outlives the run and the container.
- A run that some **outer** clock kills (the review's 1800 s, the CI job's 60 minutes) is still attributable: the
  run says where it is and how long it has been there while it runs, and which sections were slowest so far.
- The gate's waits are capped, counted and attributed; no unbounded `while`+`sleep` remains.
- All of it is falsifiable inside the gate (a nested stuck run, a budget-table check, a loop-inventory check).

**Non-Goals**
- Changing any section's **decision semantics** (no assertion, threshold, fixture or skip rule of an existing
  section changes), D33's split (performance stays out of the correctness gate), or D39's artifact channel.
- Explaining the 2026-09-22 stall itself; this change makes the next one nameable.
- Removing the outer timeouts (`TEAM_REVIEW_TIMEOUT`, the CI job's 60 minutes): they stay as the outermost
  backstops, now *below* the gate's own accounted budgets instead of above an unattributed run.
- A skip/attribution that turns a bound trip green on a slow machine: the brief is explicit (`超时必须红`), and
  §3 D6 states the D33 boundary that keeps that honest.

## 3. Decisions

### D1 — The bound is a heartbeat watchdog plus a trip marker; **not** a `timeout` around a refactored section

The brief's shape is "each section runs under a hard timeout". The obvious implementation — wrap each section
body in `timeout <budget>` — requires the body to be a function (or a re-exec'd section), and this suite is one
linear script whose sections share shell state across boundaries: `$TMP`/`$REPO`/`$SESSION` evolve section by
section, dozens of section-local variables are read by later sections, and cleanup/traps/`jobs` semantics are
global. Forking a section away loses exactly that state, and a killed section leaves the *next* section running
against a half-built fixture — the M59 cascade class (a missed step upgraded into dozens of bogus failures).
Rejected alternatives, each with the reason it fails:

- **(a) Per-section `timeout` + a function-per-section refactor (92 bodies).** State loss (above), a very large
  mechanical diff in the one file every other task touches, and `timeout` still only signals its direct child —
  the fixtures' own children/tmux panes survive and the *next* section inherits them.
- **(b) Cooperative-only bound** (check a deadline at each safe point). `sleep infinity` never reaches one; the
  probe's v1 case A shows the shell simply continues — the falsifiability requirement fails.
- **(c) Kill the process group.** In a non-interactive run the suite, `team review`, the CI step and the seat
  that started the gate share one process group; `kill -TERM -$pgid` would kill the caller (memories #1019,
  #1087). Never.
- **(d) `setsid` the suite at startup so a group kill is safe.** It changes the run's session/controlling-tty
  context, which fixtures assert on (`10c-②` builds a background process group *with a tty*; M25's whole point),
  and it needs a tool the gate image may lose. Not worth it when (e) exists.
- **(e) The chosen mechanism**: a double-forked **watchdog** (the M33 tripwire's proven pattern: `( … & )`, the
  stop/ack file handshake, "not in the job table" so a bare `wait` cannot hang), a **heartbeat file** written
  with a builtin (`printf … > file`, no fork per assertion) that carries `sec_no|armed_epoch|budget|elapsed|ticks`,
  and a **trip** that is three independent channels:
  1. the **trip marker** file — written by the watchdog *first*; every safe point in the suite (`section()`,
     `ok()`, `bad()`, every `assert_*` through them, and each round of a bounded wait) checks it and exits 2 with
     the named line. This is the deterministic channel; v1's findings 1 and 2 are exactly why the other two
     cannot be the primary.
  2. the watchdog **stops the stuck section's descendants** (`TERM`, then `KILL` after a bounded grace), walked
     from `/proc/<pid>/task/*/children` — never a process group, with the watchdog excluded — and then signals
     the suite itself (`TERM`, then `KILL`), which is what makes the deferred trap of a builtin-spin section
     fire (probe case D) and what bounds a suite that ignores the marker.
  3. a script-level `trap … TERM` that exits 2, for the shapes where no safe point is ever reached.

  The **scene is written before any signal** (evidence first, probe cases A–E), and the run's exit status is 2
  when the suite reaches a safe point or its trap, and a signal status (137/143, still non-zero) when the
  watchdog had to `KILL`. Both are non-zero, which is what the review needs.

### D2 — Budgets come from a committed table with a recorded derivation, and a completeness check

`skills/teamsmith/tests/section-budgets.tsv` is the one place budgets live: one row per section —
`id`, the measured band (`max_host_s`, `max_container_s`, and the CI column once a run has produced it), the
load recorded with each measurement, `budget_s`, and the provenance (revision + image tag). Header rule:
`budget_s = max(ceil(band × 4), 60)` with the band being the **worst observed** value, not an idle one (§1.1
measured the FAST run at ~9× its intended budget under load, so a band taken from an idle run is worthless).
An unlisted section resolves to a bounded default (so a new section can never be unbounded between its commit
and its measurement) and its start line says so. `bash tests/section-guard.sh --budget-check` is the falsifiable
basis check: every section in the sources has a row, every row satisfies the arithmetic and the floor, and the
provenance is recorded; a lowered budget or a missing row is red.

Why not tighter: the bound is a **liveness detector** for the incident's shape (a section that never returns),
and the review's gate has to stay green for a correct-but-slow machine (§3 D6). A budget that fires on a merely
slow machine is a false red — a *measured* table with a 4× factor over the worst loaded observation is the widest
bound that still detects the stall inside the review's 1800 s.

### D3 — The run self-reports while it runs; no second wall-clock red line

The measured full run (§1.1) decided this. 91 sections' generous budgets sum to far more than the review's
1800 s or the CI job's 60 minutes, so a **run-level budget** was the obvious answer to "what if every section is
merely slower" — and the measurements rule it out: the 1050 s loaded host run against a total budget that must
stay *below* `TEAM_REVIEW_TIMEOUT` (1800 s) leaves only ~1.7× headroom, and section `38` alone may legitimately
take ~1166 s under a 4× band. A total budget that could fire on a uniformly slower machine would be exactly the
perf red line D33 forbids, and a total budget above 1800 s would never fire inside a review — it would just be
the outer timeout with extra steps.

So the run carries **no second red line**; it carries a **self-report**: while a section is in progress the
watchdog prints one bounded progress line every `SMOKE_PROGRESS_INTERVAL` seconds (default 60), carrying the
section's `#<N>` and id, the elapsed time, and the slowest sections so far from the timing record; a section that
closes above its table band prints one warning line (informational, no verdict). The consequences:

- a **stuck** section is caught by its own budget (the incident's shape) and named with a scene;
- a **uniformly slower** run (the case a total budget would have redded) is attributable instead: the review's
  `TIMEOUT` or the CI job's kill leaves a log whose last progress line names the section, its elapsed time and
  the slow sections — the 2026-09-22 incident's actual question ("45 minutes, no idea where") is answered
  without inventing a wall-clock red line, and a human or the PM can then act on the environment reading.

This is deliberately weaker than a hard run-level bound and deliberately honest: no measured basis supports a
whole-run ceiling below the outer timeouts, and inventing one would recreate the false-red class P48 was about.

### D4 — The scene: placement, contents, bounds, and the channel it already has

- **Placement**: a dot-prefixed directory under the resolved temp root (`${TMPDIR:-/tmp}/.teamsmith-smoke-scene.<pid>/`),
  **outside** the run's own temp root (`/tmp/teamsmith-smoke.XXXX`), because the suite's failure path deletes
  its temp root unless `--keep` (D39's 追记二), and because `/tmp` is exactly what the CI's existing
  `docker cp teamsmith-gates-run:/tmp/. .ci-artifacts/` collects (dot files included). **No workflow change.**
  The name joins M33's dot-prefixed incident family, which P53's `tmp-hygiene.sh --status` already lists as a
  diagnostic that `--sweep` never deletes — compatible by construction.
- **Timing**: written **before** the stop signals (a scene that only appears after the kill can be lost to the
  very hang it describes; the in-progress CI log 404 is the same lesson from the other side).
- **Contents**, each bounded: the summary (section `#<N>`, id, budget, elapsed, mode, lock/queue state); the
  last progress reading; the suite's descendant tree (explicitly — v1 finding 3) plus a bounded whole-table
  `ps`; the tails of the files the run wrote under its temp root during that section; the last lines of every
  pane on the run's private tmux server when one exists; the partial timing record; the effective knob values
  and, when set, the ignore/warning lines.
- **Bounds**: per-file line and byte caps (the apply picks the numbers; the scene must never become its own
  incident) and a bounded file count.
- **Clean runs leave nothing**: the heartbeat/trip/marker files are swept on a clean exit (the M33
  `smoke_tmp_sweep` discipline), and no scene directory is created unless a trip happened.

### D5 — Waits: one inventory, one attributed helper, the heartbeat at every round

The census (§1.2) is the work: **43** `while`+`sleep` loops go into one inventory file (the shape of the
existing `tmux-lint-legacy.txt`: file, line, the cap it carries, or the structure that bounds it), the three
cap-less loops get their structural bound named, and the check is a pure-logic FAST section: a new uninventoried
loop, or an inventoried one that lost its cap, is red. New waits (and the fixture that exercises them) use one
helper that counts rounds, refreshes the section heartbeat every round, and prints the attribution line at the
cap (name, `n/cap`, the state it waited for, the last reading) before returning non-green.
`tests/lib/pty-wait.sh` is the model and is **unchanged**: its settled-frame semantics, its bounded extension
and its premise/attribution behaviour are the reference implementation of this requirement, and its loops are
inventory rows, not rewrites.

### D6 — D33 stays green, and the boundary is stated in the spec

The correctness gate must not turn red because a correct operation was slow, and this change introduces the one
clock that *can* stop a section. The boundary is written into `verification#The correctness gate judges
correctness only` (MODIFIED): the bound is a liveness detector derived from a recorded measured band; it must not
be tightened below that band; a section inside its bound stays green however slow the machine is; a trip is a
red that names the section, never a skip; and the timing record is data, never a verdict. The pure-logic guard
`gate-guard.sh` gains a direction that keeps it that way (the only module comparing a duration to a threshold is
the section guard; a duration comparison reintroduced into the gate's other sources is red). The performance
suite, its thresholds, the `MARK_*` sets and D33's split are untouched, and the existing D33 flip (the
assembly-delay fixture, `TEAM_SMOKE_FRAME_DELAY_MS=2600` in FAST) stays green — it is the reverse side of this
change's boundary.

### D7 — D40: this delta modifies a requirement another open change already modified

`openspec/changes/pty-fixture-load-premise` (P44/P48, **not yet archived**) writes a MODIFIED delta for the same
requirement, `verification#The correctness gate judges correctness only`. This change's MODIFIED block is written
against the **current base** (the tree as it is today) and carries all three base scenarios verbatim.
**Measured in this block** (trial archive on a scratch copy, `cp -r openspec /tmp/trial-p56/ && cd /tmp/trial-p56
&& openspec archive -y gate-section-accounting && openspec validate --all --strict`): archiving this change
succeeds (`+ 2 added, ~ 1 modified` into `specs/verification/spec.md`), and the trial then reports
**`21 passed, 1 failed — pty-fixture-load-premise`**, because that pending delta no longer carries the scenario
this archive added — D40's collision, in the symmetric direction. Therefore: whichever of the two archives
first, the **other one's delta must be rewritten against the new base** before the tree passes
`openspec validate --all --strict` — the apply brief and the archive precondition must say so, and the trial
archive is the integration check (D40's rule 3). The two added requirements do not collide with any open
change's delta.

### D8 — Knobs cannot weaken the gate from the environment

Budget overrides (`TEAM_SMOKE_STUCK_SECTION`, `TEAM_SMOKE_SECTION_BUDGET`, `TEAM_SMOKE_PROGRESS_INTERVAL`,
`TEAM_SMOKE_GUARD_POLL`) are honoured **only** under the fixture switch (`TEAM_SMOKE_FIXTURE=1`, the existing
convention) and are printed as ignored otherwise, so an inherited `TEAM_*` value cannot silently disarm the
bound (the M25/M47 class). A legitimately slower machine is fixed by a **measured change to the table**, which is
reviewable, not by an environment variable.

## 4. The shapes the apply must implement (contract for the implementer)

| Element | Shape |
|---|---|
| section start | `== #<N> <id> == <ISO-8601> · 预算 <B>s` — `#<N>` monotone from 1, one per section, no gaps |
| section close | one line carrying `#<N>` and the elapsed seconds (no `✓`/`✗` counters: `flip-m33.sh` counts red-marked lines) |
| timing record | `<temp root>/sections.tsv`, header + one row per started section: `no id start elapsed_s ticks` |
| heartbeat | `${TMPDIR:-/tmp}/.teamsmith-smoke-heartbeat.<pid>`: `sec_no|armed_epoch|budget|elapsed|ticks`, written by a builtin |
| trip marker | `${TMPDIR:-/tmp}/.teamsmith-smoke-trip.<pid>`: created by the watchdog at the trip; checked at safe points |
| scene | `${TMPDIR:-/tmp}/.teamsmith-smoke-scene.<pid>/` (dot-prefixed, outside the temp root; bounded files) |
| budgets | `skills/teamsmith/tests/section-budgets.tsv` + the derivation header; default for unlisted ids |
| bounds | section budget from the table; progress interval 60 s (a self-report, not a verdict); the outer clocks (`TEAM_REVIEW_TIMEOUT` 1800 s, the CI job 3600 s) stay the outermost backstops |
| exit | trip → `exit 2` (safe point / trap) or the signal status (watchdog `KILL`); both non-zero; no result line |
| knobs | fixture-switch-only, ignored-with-notice otherwise |
| guard module | `skills/teamsmith/tests/lib/section-guard.sh` (watchdog, heartbeat, trip, scene, budget lookup) |
| checks | `skills/teamsmith/tests/section-guard.sh --budget-check`, `… --loop-check` (or a smoke section; the apply may split) |

## 5. Coverage

| Requirement | Decisions | Apply items |
|---|---|---|
| `verification#The correctness gate judges correctness only` (MODIFIED) | D6, D7 | 3.1–3.3 |
| `verification#Every gate section accounts for itself, and a stuck section is named` (ADDED) | D1–D4, D8 | 1.1–1.6, 2.1–2.4 |
| `verification#Every wait in the gate is bounded and attributes at its cap` (ADDED) | D5 | 4.1–4.3 |

## 6. Residual risks, stated rather than hidden

1. **An uninterruptible section** (a process in `D` state, e.g. a stuck I/O in the container) cannot be stopped
   by any signal. The watchdog's report and scene are already written, the suite is *not* stopped, and the outer
   backstops (review 1800 s, CI job 60 min) still apply. The scene names the process and its state, which is the
   diagnosis this change can honestly promise.2. **A section whose stuck work escaped its descendant tree** (a fixture that `setsid`s its own child): the marker
   still stops the run and the scene names the section, but the orphan is not signalled by the watchdog (by
   design — D1(e) refuses pattern-matched kills; the fixtures' ownership rules are P53's).
3. **False-bound risk on a machine slower than the band by more than the factor.** The brief makes a trip red
   (`超时必须红`), so this is a red by contract. The mitigation is built in: the band is taken from *loaded*
   measurements, the factor is 4, the scene carries the load/premise readings, and the fix is a measured table
   change. This is the price of ever being able to say "the run stopped at section #N". For the *uniformly
   slower* case there is no bound at all (D3): the progress lines and the closing lines make the outer timeout
   attributable instead of guessing at a whole-run ceiling the measurements do not support.
4. **Table rot.** The completeness check (`--budget-check`) plus the unlisted-section default bound the window in
   which a section can be unbounded; a CI log whose per-section line exceeds the table budget is the signal to
   re-measure (the CI column is part of the table's provenance).
5. **The 2026-09-22 stall is not explained.** This change makes the next occurrence nameable in one line; it does
   not claim to know which section that run was in.
