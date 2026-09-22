# Design: `perf-suite-split` — one gate per question

## 1. Context

Read-only recon on this checkout (branch point `fd4fcf6`), measured 2026-09-21. Every claim below was checked
here; where the brief's number differs, the measured one is used.

- **The gate pair and its callers.** The gate is `openspec validate --all --strict && bash
  skills/teamsmith/tests/smoke.sh </dev/null` (`ci/Containerfile` `CMD`, `.github/workflows/gates.yml`,
  `references/protocol.md` §9b). `team review` runs it as `TEAM_GATES` under a hard timeout, on the shared
  `TEAM_SMOKE_LOCK` **before** the timeout clock starts (gate-hygiene; §34). `team smoke` is the front door
  (`cmd-docs.sh:128`); the full suite takes ~10 minutes in the pinned image (`gates.yml` comment).
- **The wall-clock / CPU judgments inside the gate path** (verified by reading the sources, not taken from the
  brief):
  1. `smoke.sh` §27-d: five samples of `team monitor --print --no-activity` in the smoke fixture, their median
     compared `[ "$med" -le 2000 ]` (`:9141`, `:9151`), premise `loadavg ≤ 0.75 × cores` (`:9112–9124`), injection
     knob `TEAM_SMOKE_FRAME_DELAY_MS` (`:9165–9171`), a self-check of the median logic (`:9188`).
  2. `smoke.sh` §35 (`:11268–11382`): the fixture tests *of that judgment* — injected load/cores boundary cases,
     "the injection is honored", and "the real path ignores the knobs".
  3. `smoke.sh` §36 (`:11384–11409`) runs `panel-cpu-premise.sh`, which drives `panel-cpu.sh` four times:
     first frame ≥ 2000 ms and pane CPU ≥ 1 % are red (`panel-cpu.sh:337,340`), premise 0.25
     (`panel-cpu.sh:47–66`), median-of-three (`:166–190, :293–300`), exit 4 for a premise miss or a missing GNU
     time (`:111, :329`).
  Measured here today: FAST smoke 27-d median **395 ms** over five samples (fixture repo, loadavg 8.96) — the
  loose line; the tight line is the real checkout's first frame.
- **Same tree, same machine, 30 seconds apart** (this host, 32 logical cores):
  | run | environment | loadavg | first frame (3 samples → median) | pane CPU | verdict |
  |---|---|---|---|---|---|
  | host | distrobox, `/usr/bin/node`, root = this worktree | 6.13 | 3445 / 3413 / 3415 → **3415 ms** | 0.50 % | **RED** (budget 2000 ms), premise held |
  | container | pinned `localhost/teamsmith-gate:local` (image from `ci/Containerfile`), same path mounted read-only | 5.60 | 208 / 209 / 209 → **209 ms** | 0.50 % | OK, rc 0 |
  The premise held in both (threshold 0.25 × 32 = 8.00), so the 16× gap is **not** load: the environment decides
  the number. This is the measured form of D32's conclusion ("the acceptance environment for timing red lines is
  the pinned container"); the cause of the host gap is not diagnosed here and is not needed for this change.
- **Correctness coverage of the same requirement today**: §27-a (block protocol, no `spawnSync` in the render
  path), §27-b (block isolation: an unreadable `BOARD.md`/missing capacity log), §27-c (fast reader ≡ canonical),
  §27-d's JSON shape, §28-i (detail reader, path boundary, truncation), §26/§28 layout, i18n, contrast,
  snapshots. The keystroke pty probe (`tests/panel-keyprobe.sh`) is **report evidence only** — no gate section
  invokes it (P12/P13/P18 reports).
- **Not wall-clock, and staying**: the P10 bounded liveness polls (`:8715` default 10 s, 20 s for the first
  frame) wait for a condition and were converted from fixed sleeps in M20 (typical frame 1.24–1.6 s quiet, 4.1 s
  at load 7–8); §37's git-call counts (`≤1`, `≤50`) are deterministic and load-independent; §34's queue
  accounting is the review path's own semantics.
- **Entries and surfaces to touch**: `team smoke` (`cmd-docs.sh`), the command list (`cmd-project.sh:79`), the
  doctor (`cmd-project.sh:313`, `check/pass/warn/fail`), `SKILL.md` (command table + deeper reading),
  `references/protocol.md` §9b-2 (the operational gate rule), `references/workflows.md`,
  `.github/workflows/gates.yml`, `docs/team/PUBLISH.md`. The pinned image (`ci/Containerfile`) exists on this
  host as `localhost/teamsmith-gate:local` and pins tmux 3.7b / node 24.19.0 / bun 1.3.14 / pi 0.86.0 /
  openspec 1.8.0 / GNU time.

## 2. Root cause

1. **Two questions share one verdict.** "Did it happen?" (correctness) and "how fast was it?" (performance) are
   asserted by the same suite, so the gate's colour is a function of the machine. A correctness gate must not
   depend on who else is competing for CPU — the mirror image of a false green is a false red that blocks merges
   for a reason nobody can act on.
2. **The premise filters load, not environment.** The measured table above has the premise holding in both runs;
   the environment alone moved the first frame 16×. Load-average gating cannot fix that (D32's open
   "quiet but not fast enough" gap).
3. **There is no place to look at the performance numbers.** They exist only inside a ~10-minute correctness
   suite, so "run the perf check" and "run the correctness gate" cannot be decided separately (the user's D33).

## 3. Goals / Non-Goals

**Goals.** (R1) The correctness gate contains no wall-clock/CPU red line, mechanically guarded. (R2) The
performance suite is one command, self-describing, host- and container-runnable, with red / visible-skip / green
distinguishable. (R3) Not one correctness assertion is lost in the move. (R4) CI runs the two gates with
independent conclusions; performance does not block and is recorded before a release. (R5) Docs and `team doctor`
name the division and the next step. (R6) Thresholds, premise factors, medians, `exit 4` and the gate-lock
accounting are unchanged.

**Non-Goals.** Recalibrating the premise or adding a "can this machine hold the line" probe (D32's follow-up,
frozen by R6); new correctness coverage (the keystroke probe stays report-evidence); moving the bounded liveness
polls; touching `refuse`/CAS/write/authz; a `make perf`; changing the gate lock or `team review`'s record
format; diagnosing the host/container gap.

## 4. Decisions

### D0. Spec homes

| # | Promise | Capability | Delta |
|---|---|---|---|
| R1 | the correctness gate judges correctness only, guarded both ways | `verification` | ADDED |
| R2 | the performance suite is separate, self-describing, exit-coded, host+container, own lock, never in a review | `verification` | ADDED |
| R4 | CI runs the two gates separately; performance is non-blocking and recorded pre-release | `verification` | ADDED |
| R5 | docs and `team doctor` name the division and the next step | `verification` | ADDED |
| R3/R6 | the panel requirement keeps its correctness promises and its numbers; the judgment moves to the performance suite | `panel` | MODIFIED |

`verification` owns R1/R2/R4/R5 because it owns the gates and the review path. `panel` gets a **MODIFIED**
requirement rather than an ADDED one: the base requirement already owns the two numbers and the premise, so a new
requirement would be a parallel statement about the same behavior.

### D1. What counts as a wall-clock red line — and what stays

"In scope" = an assertion whose pass/fail is a threshold on the **magnitude** of elapsed wall-clock time or of a
process's CPU share, i.e. a performance verdict. "Stays" = a bounded liveness wait (a deadline for a condition
that must eventually become true; failing it means the operation did not happen, and its budget is a multiple of
the measured worst case) or a deterministic count.

| Today | Kind | After |
|---|---|---|
| §27-d: sample loop, median, `p27_assembly_judge`, median self-check, `TEAM_SMOKE_FRAME_DELAY_MS` injection, premise (0.75) | performance verdict | **moves to `tests/perf.sh`** |
| §35: boundary/verdict fixtures for that judgment, injection honored | judgment self-tests | **moves to `tests/perf.sh`** (with the new knobs) |
| §35f: the real path ignores the knobs and prints so | correctness (anti-backdoor) | **stays in the gate** — rewritten time-independently (D7) |
| §36 → `panel-cpu-premise.sh` → `panel-cpu.sh` (first frame, pane CPU, premise 0.25, exit 4) | performance verdict | **moves to `tests/perf.sh`** |
| `panel-cpu.sh`'s knob notices + premise line truthfulness (`d-realpath`) | correctness (anti-backdoor) | **stays in the gate** via `panel-cpu.sh`'s premise-only mode (D7) |
| §27-a/b/c, §27-d JSON shape, §28-i reader, §26/§28 surfaces | correctness | **unchanged** |
| §34 queue accounting, `queued`/`ran`, hard timeout | correctness of the review path | **unchanged** |
| P10/26-m/27 bounded polls (10 s / 20 s) | liveness correctness | **unchanged**, explicitly out of scope |
| §37 git-call counts | deterministic structural check | **unchanged** |
| `panel-keyprobe.sh` (keystrokes survive a refresh) | correctness, report-evidence only today | **unchanged** (its gate residency is not this change) |

The one judgment that is not a red line but looks like one: `panel-cpu.sh` needs GNU time for the **tree CPU
figure** it prints alongside its samples. That figure is not a verdict input; a missing tool makes it exit 4
(already the semantics spec'd in `panel#…`), and the driving fixture follows it into the SKIP.

### D2. Entry and naming: `tests/perf.sh`, fronted by `team perf`

- `skills/teamsmith/tests/perf.sh` is the suite, runnable directly (`bash skills/teamsmith/tests/perf.sh`) — the
  same shape as `bash skills/teamsmith/tests/smoke.sh` in CI and the container, so CI needs no shell wrapper.
- `team perf` is a thin front door next to `team smoke` (`cmd-docs.sh`), so `team help` lists it and the docs can
  use the short form.
- **Rejected — `team smoke --perf`**: a flag on the correctness command blurs the boundary this change exists to
  draw; the two gates must be independently invocable with independent conclusions.
- **Rejected — `make perf`**: the repo has no Makefile and no make dependency; it would add a build layer for one
  command.
- Container usage: `team perf --container` (equivalently `bash tests/perf.sh --container`) runs the same script
  inside the `ci/Containerfile` image; the exact engine/`podman run` line is documented for copy-paste
  (`references/protocol.md` / `workflows.md`).

### D3. Suite contents, aggregation and exit codes

Judgments (each keeps its current measurement rule and threshold):

| # | Judgment | Measurement | Threshold | Premise factor |
|---|---|---|---|---|
| 1 | interactive first frame | cold spawn, median of three samples, all printed | < 2000 ms | 0.25 |
| 2 | frame assembly line | five samples of `team monitor --print --no-activity`, median | ≤ 2000 ms | 0.75 |
| 3 | steady-state pane CPU | three equal sub-windows of the sampling window, median | < 1 % of one core | 0.25 |

Self-tests inside the suite (so the judgment stays falsifiable — the M51 lesson):
- the premise boundary cases (`loadavg == factor × cores` holds; `+0.1` does not);
- an injected slow frame → the judgment is **red** (proves the suite is not always green);
- an injected over-premise load → the judgment is a **visible SKIP**;
- the new knobs are ignored in the real path and the ignore is printed.

Exit codes: **0** every judgment ran and was green; **2** ≥1 red; **4** no red but ≥1 visible skip (including a
missing tool or a missing image/engine when a container verdict was requested), with the measured values and the
reason printed; **3** setup failure (no tmux, no JS runtime, no bundle). A red dominates a skip: a red is
reported even if another judgment skipped. The summary is a table of every judgment with its verdict, median,
samples and premise.

### D4. Environment: the pinned image is the reference; the host is the named alternative

**Decision.** The suite's verdicts come from the pinned `ci/Containerfile` image when it is available
(`team perf` runs in it by default); `team perf --host` runs on the host and prints that it is not the reference
environment. When the container path is unavailable (no engine, or the image is missing) the suite prints the
reason and the exact build/run command, and falls back to the host — clearly labelled — rather than failing: the
suite must stay usable on a machine without containers, but a host number is never silently presented as the
reference.

**Why the container is the reference** (with this change's own measurements, §1): same tree, same host, same
minute, premise held in both — host 3415 ms (RED) vs container 209 ms (OK). The gate already runs in this image
(M47), D32 accepted it as the timing-verdict environment, and the pre-release number should be produced by the
same environment CI uses. If the host were the default, the suite would keep emitting reds that are about the
host, which is the failure mode this change is meant to end.

**Why the host is kept**: R2 requires "run once on this machine"; it is the developer's first signal, it needs no
engine, and the environment self-description plus the `--host` label make it honest.

**Self-description** (always printed, before the verdicts): host/container, visible logical cores (`nproc`, with
`getconf` fallback and any `TEAM_PERF_CORES` override named), the CPU quota (`cpu.max`) or its absence, the
loadavg, the JS runtime and tmux versions, and `git rev-parse --short HEAD`. No quota is imposed by default; if
one is used, the visible cores must match it (prefer a cpuset over `--cpus`) so the premise reads the right core
count — the suite prints both if they disagree.

### D5. Locks: the performance suite gets its own

`TEAM_PERF_LOCK` (default `${TMPDIR:-/tmp}/teamsmith-perf.lock`), acquired with the same `flock --close -w`
pattern smoke uses, with `TEAM_PERF_LOCK_WAIT` (default 1800 s) and a printed holder. Two performance runs
serialize so they do not perturb each other's measurement.

The suite **never** takes `TEAM_SMOKE_LOCK`: the correctness gate's lock is the merge path's resource (a review
queues on it before its hard timeout), and a performance run must not delay a review. Before measuring, the suite
does a **read-only** non-blocking probe of the smoke lock and, when it is held, prints the holder's name and a
notice that the correctness gate is running (the premise and the self-description then decide what the numbers
mean). This is the design's answer to "own lock or read-only": own lock for serialization, read-only awareness of
the gate lock, never a lock on it.

### D6. Migration: move, with a two-sided mechanical guard

The judgment is **moved**, not copied: after the change the gate has no dormant copy, and `tests/perf.sh` is the
only place the thresholds are compared.

The gate carries a pure-logic guard section (FAST-safe, no processes), which fails when:
1. the correctness gate's own file (`smoke.sh`) contains a perf-judgment marker — the frame-budget constant, the
   CPU-share comparison, or an invocation of a measuring fixture (`panel-cpu.sh`, `panel-cpu-premise.sh`,
   `perf.sh`); **or**
2. the knob-integrity helper `tests/panel-knobs.sh` (D7) is missing, has lost its premise-only invocation, or
   drives the measuring fixture `panel-cpu-premise.sh`; **or**
3. `tests/perf.sh` does **not** contain the judgment markers (a lazy move that deletes the line without landing
   it in the suite).

The markers are named single-source constants in `perf.sh` (`PERF_FRAME_BUDGET_MS=2000`, `PERF_CPU_MAX_PCT=1`,
the premise factors), so the guard is a grep over a small closed set rather than a fragile textual match; the
brief's suggested `budget 2000` string is subsumed by marker (1). The gate reaches the premise-only mode through
the `tests/panel-knobs.sh` helper, so `smoke.sh` itself never names a measuring fixture — that is what makes
marker (1) checkable. Both directions are flipped by hand in the apply report: reintroduce the judgment into
`smoke.sh` → guard red; remove it from `perf.sh` → guard red; restore → green.

### D7. The knob-integrity check stays in the gate, time-independently

`panel-cpu.sh` gains a **premise-only mode** (`TEAM_PANEL_CPU_PREMISE_ONLY=1`): it prints the premise line and
`pc_notice` for every injected `TEAM_PANEL_CPU_*` knob, exits 0, and starts no tmux/node — no duration is judged.
A new tiny fixture `tests/panel-knobs.sh` sets all three knobs with the fixture switch off, runs that mode and
asserts the three ignore notices and that the premise line carries the real load/core count (no `9999`, no
`1 cores`). The gate's §36 rewrite calls `panel-knobs.sh` (and nothing else panel-measuring), which keeps
`smoke.sh` free of both the knobs and the measuring fixtures. This is the `d-realpath` promise with the
measurement removed: cheap, FAST-safe, and red when the fixture switch stops guarding the real path. The
measurement-attached `d-realpath` cases (verdicts, control run) live in the performance suite, where the judgment
now is.

### D8. CI and the pre-release record

`gates.yml` gains a second job (`perf`) alongside the unchanged `gates` job. The perf job runs in the same pinned
image on its own runner (so it does not contend with the correctness job) with the perf step marked
`continue-on-error: true`: the step's red is visible in the log and as an annotation, the correctness job's
conclusion stays independent, and nothing blocks a merge (the workflow already triggers only on `main` pushes and
manual dispatch, so it never gated a merge in the first place — the design makes that explicit instead of
accidental). The pre-release record: `docs/team/PUBLISH.md`'s release checklist names the perf command and where
its numbers are recorded (the container run, with the environment self-description pasted).

### D9. Docs and doctor

- `SKILL.md`: `team perf` in the command table and the deeper-reading row, one paragraph stating the division
  (correctness on every change; performance separately and before a release) with both copy-pasteable commands;
  the optional-helpers paragraph keeps naming `/usr/bin/time` where it is needed.
- `references/protocol.md` §9b-2: rewritten so the gate section states that the correctness gate judges no
  wall-clock line, the perf suite owns the three numbers, its lock is `TEAM_PERF_LOCK`, and the premise text
  stays with the numbers.
- `references/workflows.md`: the runbook gains the two commands in their places (everyday gate; the release
  step).
- `team doctor`: a `perf suite` line next to the other checks — present → `pass` with the command; absent →
  `warn` with the actionable next step (`team update`, or the path to install), never a hard failure (the suite
  is part of the skill, not a hard dependency).

### D10. What is frozen (R6) and why the moved judgment cannot rot

Frozen, verbatim: the 2000 ms / 2000 ms / 1 % thresholds, the 0.75 / 0.25 factors, the median-of-three/five
rules, `exit 4` for a visible skip, the fixture-switch rule for knobs, `TEAM_SMOKE_LOCK`'s accounting, and the
`refuse`/CAS/write/authz paths. The suite keeps the judgment falsifiable through its own self-tests (D3); the
gate keeps the suite honest through the two-sided guard (D6); the release checklist and CI keep it running (D8).

## 5. Risks and open items

- **The suite goes unrun after the split.** Mitigations: the guard requires its marker to exist, `team doctor`
  names it, `PUBLISH.md` makes it a release step, CI runs it with its own log, and the proposal's acceptance
  spot-checks it once.
- **A host red is misread as a regression.** Mitigation: the reference is the container; the host run is labelled
  and prints load/cores/quota, and D32's rule (qualify before claiming) is stated in the docs.
- **The premise's quiet-but-slow gap remains** (this host held the premise at 6.13/32 and still read 3415 ms).
  Out of scope by R6; the self-description makes it diagnosable, and the design records it as a follow-up rather
  than silently widening the premise.
- **Bounded liveness polls** (10 s / 20 s) could still be load-flaky on a busy machine. Out of scope; D1 states
  the boundary explicitly so a future change can decide with evidence.
- **Container mode ergonomics**: engine resolution (podman/docker/`distrobox-host-exec`), image build policy and
  the cpuset-vs-quota question are implementation details for apply; the design fixes only the rule (reference =
  the image; a missing engine/image is printed, not silent).

## 6. Verification plan (for the apply and verify tasks)

1. **R1 flip**: `TEAM_SMOKE_FIXTURE=1 TEAM_SMOKE_FRAME_DELAY_MS=2600 TEAM_SMOKE_FAST=1 bash
   skills/teamsmith/tests/smoke.sh </dev/null` → red on the pre-change tree (27-d), exit 0 after.
2. **R2 flips**: the suite with an injected slow frame → exit 2 with the numbers; with an injected over-premise
   load → exit 4; the self-tests green.
3. **Guard flip**: reintroduce the 27-d judgment into the gate (and, separately, delete the marker from the
   suite) → guard red; restore → green.
4. **R3 flips**: delete the knob-ignore check, a §27-b isolation assertion, and §34's queue scenario, one at a
   time → the gate red; restore → green.
5. **Environment evidence**: one `--host` run and one `--container` run, with the self-description and the
   medians pasted into the report.
6. **Gates**: `PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict` and the full
   `bash skills/teamsmith/tests/smoke.sh </dev/null` on the branch; `git status --porcelain`.
7. **Docs/doctor**: the grep from the delta's scenario, the doctor's present and absent cases.
8. **Trial archive** before the PM's archive step (`cp -r openspec /tmp/trial && (cd /tmp/trial && openspec
   archive -y perf-suite-split)`), to catch a MODIFIED/ADDED collision against the base specs.
