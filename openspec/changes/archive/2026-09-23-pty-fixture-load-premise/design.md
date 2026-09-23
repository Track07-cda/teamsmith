# pty-fixture-load-premise · design

Status: propose phase (planning only). Every number below was measured in this task's block on this host
(`nproc=32`, `node v24.19.0`, `node` + private tmux server + the committed `panel.js`); the raw commands are in
the report `docs/team/reports/P44-dev3.md` and the scripts are reproduced verbatim there so the apply and the
verify can re-run the same shapes.

## 0. The problem, stated precisely

`skills/teamsmith/tests/panel-p21.sh choices` (and the `groups settings wheel` batch behind smoke §38-f) runs
against a real panel in a private tmux server. Every step that depends on the console having *reached a state*
goes through `tests/lib/pty-wait.sh`'s `pty_wait_frame`: it polls `capture-pane`, requires the needles to be on a
**settled** frame (two masked captures 0.25 s apart are identical), and gives up after a bounded number of
rounds (`PTY_WAIT_ITERS`, default 40 × 0.35 s pause + 0.25 s settle ≈ 26 s wall; several sites override to 30/40
rounds, two cheap sites to 6/8).

Giving up is reported as an assertion **failure** (`bad`, exit 1). That is the defect class:

- the horizon is a *failure detector* — a claim about **time**;
- the verdict it produces is about the **code**;
- and time is the machine's dimension, so on a machine that is busy the second does not follow from the first.

The PM measured the consequence: `✓ 48 ✗ 89` three times in a row at `loadavg ≈ 11`, `✓ 110 ✗ 0` twice at
`loadavg ≈ 2`; same rows, same code, "the difference is only whether it waited". Since D33 the correctness gate
must not fail because a correct operation was slow, so this is a false red arriving through a side door — and it
costs whole review rounds (M74's verifier carries "look at the load first" as known noise in its brief).

## 1. What was measured, and what it rules out

Every row is `bash skills/teamsmith/tests/panel-p21.sh choices` with the **unchanged** knobs unless noted.
`probe` is the code-independent machine probe (`python3 -c pass` + `bash -c true` + `git rev-parse`, 5-6 rounds,
printed in ms): it measures how long this machine needs to *start processes*, which is the fixture's dominant
machine dependency.

| # | composition | loadavg_1m min/mean/max | probe ms | result | wall |
|---|---|---|---|---|---|
| PM-1 | quiet host (PM, ×2) | ≈ 2 | – | `✓110 ✗0` | ~2.5 min |
| PM-2 | busy host (PM, ×3, identical counters) | ≈ 11 | – | `✓48 ✗89` | – |
| M74 | quiet host (M74 verifier) | 0.9–2.6 | – | `✓110 ✗0` | – |
| M1 | ambient team work, one run | 8.41 / 10.00 / 11.12 | 12 | `✓110 ✗0` | 97 s |
| M5 | **two** sections in parallel | 9.03 / 9.65 / 11.31 | 12–16 | `✓110 ✗0` each | 97 s each |
| M6 | + an 8-worker `git`+`python3`+`bash` fork storm | 12.51 / 17.92 / 20.02 | 13–16 | `✓110 ✗0` | 104 s |
| M7 | 24 heavy CPU burners (all 32 cores saturated) | 15.71 / 35.50 / 42.44 | 19–34 | `✓110 ✗0` | 114 s |
| M10 | ambient + another tree's live fixture | 10.54 / 15.36 / 20.53 | 13–16 | `✓110 ✗0` | 99 s |
| M11 | ambient, `TEAM_P21_TRACE=1` (rounds histogram) | 6.12 / 8.24 / 9.47 | 12–16 | `✓110 ✗0` | 96 s |

Three findings, all of which shape the design:

**F1 — the load average does not separate green from red.** The PM's red sample (`loadavg ≈ 11`) lies **inside**
the load band of every green run measured here (up to `42.44`, i.e. 1.33 × cores, with all 32 cores saturated —
M7's burners fork `date` per iteration, so a spawn storm rode along). No monotone threshold
`loadavg ≤ k × cores` can be calibrated as a crossing:
every candidate `k` below 1.33 would also skip runs that were *observed to judge correctly*, and there is no
measured red above it either. The brief's design question 2 therefore has a measured answer, and it is a
negative one: **a load-average premise is not derivable from this data** (`load ≈ 2 / 5 / 11 / 20` does not
exist as a crossing on this host: 2 judged, 11 red *and* green, 20 judged, 42 judged).

**F2 — the fixture is robust against CPU load, and the horizon has 10–40× slack.** M11 traced all **53** waits
of a green run: **42** needed one round, **8** needed two, one needed four, one six (the scenario's own negative
fixture, which is *supposed* to exhaust its 6-round budget) and one twenty (the panel's cold first frame, whose
budget is 80). The base horizon is 40 rounds, so a state wait has 10–40× slack, and full CPU saturation raises
the machine's spawn cost only from 12 ms to 34 ms (2.8×) while the run stays green and 17 % slower. So the PM's
red was not "a busy CPU": the *needle latency* must have exceeded ~26 s while the *machine's* external readings
would still have looked healthy by the bands measured here. That is a composition this block could not
reproduce (the report lists the four shapes tried); the design must therefore not pretend it can *detect* that
composition from the outside.

**F3 — the only in-run evidence that attributes an exhaustion is the fixture's own.** The engine already
collects it: at a timeout it prints the wait's label, its rounds and duration, whether the frame is still
moving, the pane tail and whether the pane is dead. Under load the panel can also legitimately render its
*documented degraded* state (an empty/`—` block until the next good read, `panel#Frame assembly is asynchronous,
cached and never blocks input`), which is a machine-caused state a *state assertion* would misread as a code
failure. There is no external reading with a measured band that separates these cases.

## 2. The three candidate policies, and the decision

**A. Load premise only** (the brief's option 1: `loadavg_1m > k × cores` → visible SKIP). Rejected as the
*primary* instrument by F1: no `k` has a measured crossing, and any `k` inside the measured green band turns
*judged* runs into *skipped* ones without evidence that it prevents a single false red (it would skip at
`loadavg ≥ 8` on a host whose ambient team load is routinely 8–11 — the coverage is lost exactly when the PM
runs the delivery gate). A coarse guard *above* the measured band is kept (see D3 below) as a cheap early-out.

**B. Bigger budgets only** (option 2). Rejected as *sufficient*: F2 shows a 2.8× slower machine is still green
with 10–40× slack, so a *fixed* larger budget buys nothing measurable; a *fixed* budget scaled by the load
reading would re-import F1's failure; and a larger budget makes a real failure slower to discover.

**C. Budget + premise, with the premise evaluated *at the exhaustion*** (option 3, chosen). The horizons stay
exactly as they are (they are the failure detector and the cheap-failure guarantee); the *verdict* they produce
is decided by evidence collected **at that moment**, and the fixture is given a bounded way to *keep making
progress* before it gives up:

- **progress-aware extension** — at the base horizon, if the scene is still painting (the masked capture changed
  within the last `PTY_STALL_ROUNDS` rounds), keep polling up to `PTY_EXT_FACTOR × base`. A merely slow machine
  is then still *judged* (D33's "slower-but-correct stays green" is honoured by *waiting*, not by relaxing a
  threshold), while a scene that has stopped changing gets no extension at all — the extension can never hide a
  static failure.
- **attribution at the ceiling** — read the machine then and decide:
  - the scene is still painting **or** the probe is over its ceiling **or** `loadavg_1m` is over the coarse
    guard → this wait and the rest of the scenario are a **visible SKIP**: the scenario stops (bounded cost),
    the line names the wait, its rounds/elapsed time, the M59 scene and the readings, the summary counts a skip
    and the fixture exits **4** ("skipped, no conclusion" — the same convention `tests/panel-cpu.sh` and
    `tests/perf.sh` already use), so `smoke.sh` §38-b/§38-f print `SKIP（条件不满足）` with the reason and the
    gate stays exit 0.
  - the scene is static **and** the machine is under the premise → **red** with the M59 scene: on a machine that
    is demonstrably healthy, "the state never appeared" is a code verdict. This is what keeps the brief's
    requirement 3 (a real regression must stay red on a quiet host) true for the ~40 `wait_* || bad` sites of
    the fixture, which are the ones a regression like a broken key would trip.
- **no entry-level judgment** — the premise line is *printed* for every scenario (readings only, no skip), so the
  run is self-describing and the record shows what the machine looked like; only the coarse guard skips at entry.

The residual risk is stated rather than hidden: a machine-side stall that is **static** for longer than the
ceiling *and* leaves the external readings healthy (a `SIGSTOP`/cgroup-throttle shape) still produces a red.
This block **tried** to measure that shape and did not finish the attempt (the blackout script's process
pattern was too broad, it was stopped for the safety of other agents' live fixtures, and up to that point its
run read `✓70 ✗0` with no wait timeout, so the row stays *unmeasured* — see the report's interference note).
The mitigation is the printed scene (readings + "frozen" evidence) plus the coarse guard; the alternative —
treating every unattributable exhaustion as a SKIP — would silently disarm the fixture's ~40
state-reachability assertions, which is the failure mode the brief's item 3 forbids.

## 3. Constants, their measured basis, and how to re-derive them

| constant | value | basis / method | red side |
|---|---|---|---|
| base horizons (`PTY_WAIT_ITERS` and the sites' overrides) | **unchanged** (40/30/8/6, 0.35–0.4 s pause) | M1/M5/M6/M7/M10/M11: a green needle needs 1–4 rounds at every measured composition (53 waits traced: 42×1, 8×2, 1×4), so the base is a failure detector with 10–40× slack | unchanged (static failure still reds) |
| `PTY_STALL_ROUNDS` | 8 | a round costs ~0.6–0.85 s (two captures + 0.25 s settle + 0.35 s pause), so 8 rounds ≈ 5–7 s of *identical* masked frames. In the `choices` scenario the panel runs with `P21_REFRESH=3600` (the pane's own refresh is off by design, so that the read-window assertion is meaningful) and the only periodic paint is the masked clock: 5–7 s without a change is "not painting", while any interaction-driven repaint lands well inside it (measured needles: 1–4 rounds) | a scene that keeps painting forever is skipped, never red (a speed problem, not a state problem — D33) |
| `PTY_EXT_FACTOR` | 3 | the extension must cover the "slow but painting" case; it is bounded so a red can never take more than `3 × 26 s` per wait and the scenario stops at the first unattributable exhaustion (cost bound measured: worst case ≈ 80 s + the scene) | none needed: the extension is never applied to a static scene, and a *painting* scene with the needle missing for 78 s is attributed to the machine |
| `PTY_PREMISE_PROBE_MS` | 120 ms | measured probe band 12–34 ms across `loadavg` 8.4 → 42.4 (M1/M5/M6/M7); 120 ms is ≈ 3.5 × the highest measured value, i.e. outside every composition measured here | **to be measured by the apply** with the reproduction recipes (`storm.sh`, `burn.sh`, `starve.sh`, §4) and recorded in the report; if no composition reaches 120 ms, the constant stays a *guard* and the horizon/progress evidence remains the authoritative signal — the requirement states this asymmetry, it does not pretend the probe is calibrated for a class we could not reach |
| `PTY_PREMISE_LOAD_FACTOR` (coarse entry guard) | 2.0 × cores | deliberately **outside** the measured band (the highest measured green is 1.33 × cores); it exists to avoid burning minutes on a grossly overloaded host, not as a crossing | none measured; documented as conservative |

The method is the repo's own (`panel#Frame assembly…`: "both factors are calibrated from measurement, not
chosen"): measure the band where the fixture *judges* and the band where it *cannot*, and place the constant
outside the first and inside the second — with the difference that here the second band could not be produced by
CPU load at all, which is exactly why the constant that *decides* is the in-run one and the external ones are
guards.

## 4. Reproduction recipes (for the apply's calibration and the verify's red sides)

The scripts are in the report (`docs/team/reports/P44-dev3.md`, verbatim); the shapes are:

- `storm.sh <workers> <secs>` — N workers looping `git status` + `python3 -c pass` + `bash -c true` (the same
  spawn shape the team's own gates produce).
- `burn.sh <n> <secs>` — N CPU burners (measured: 24 of them took a 32-core host to `loadavg` 42–48).
- `blackout.sh <freeze_s> <owner_pid> <pid>…` — `SIGSTOP`/`SIGCONT` on the fixture's panel: the *machine-side
  stall with healthy readings* that the policy *cannot* attribute (it reds, visibly and with the scene). The
  attempt in this block was stopped before it could produce that red — its first version selected targets by a
  `pgrep` pattern and so froze **other seats'** fixture panels (the 09:12 incident; the report's interference
  note). The compliant version signals only the owner's subtree, refuses anything else, and releases in an
  `EXIT`/`INT`/`TERM` trap with an interruptible hold; its guard test is
  `docs/team/reports/P44-dev3/blackout-guard.selftest.sh` (10 sides, all green). The shape is therefore stated as
  the residual, not as a measured row.
- `probe.sh <tree> [rounds]` — the code-independent probe; `sample3.sh` samples it every 5 s next to
  `loadavg`/`procs`/`iowait` while a section runs.

## 4b. Experiment discipline (the 09:12 incident, a rule from the brief's append)

While measuring, this block's freeze script selected its targets with `pgrep -f 'panel.js.*--root /tmp/panel-p21'`
and SIGSTOPped three panels — two of them other seats' (the PM's P42 verification fixture among them). No process
was left stopped (verified afterwards), the PM was notified, and the brief appended the rule the proposal must
carry. Its substance: **a load experiment may only signal processes it started itself** — it records the owner it
spawned and refuses every other target *before* sending a signal; pattern/name matching across the host is not a
usable selection rule because its boundary cannot be shown to exclude another seat's process. `SIGSTOP` is paired
with a `CONT` release on `EXIT`/`INT`/`TERM`, the hold must be interruptible (`sleep & wait`, not a foreground
`sleep`, which defers bash's traps), whole-machine load comes from processes the experiment owns (spin processes,
`stress-ng`), and fixtures use their own temp root and tmux socket. It lands as a falsifiable requirement in
`verification` (`A load experiment signals only the processes it started`, four scenarios), the guard test ships
with the calibration scripts, and the apply's calibration batch runs under it.

## 5. Delta placement (policy B) and what each requirement promises

- `verification` — **MODIFIED** `The correctness gate judges correctness only` (the D33 requirement): the
  pipeline's gate-premise rule for *fixtures that wait on a real process*. It gains the premise/attribution
  rule, the "a skip is never a pass and never a red" accounting, the "the premise is not an escape" clause, the
  "readings are real in the real path" clause, and the calibration clause. All three base scenarios are kept
  verbatim; four new scenarios carry the new rule.
- `verification` — **ADDED** `A load experiment signals only the processes it started`: the measurement discipline
  the 09:12 incident forced (ownership, refusal, the `CONT` release, reclaimable load, private fixtures), with its
  four scenarios and its guard test.
- `panel` — **ADDED** `The settings-view pty fixture judges under a machine premise`: the fixture's own contract
  (premise line, extension, exhaustion rule, exit status `4`, smoke §38-b/§38-f mapping, the reverse fixture,
  the knobs under the fixture switch, the FAST/full split). `panel`'s existing requirements are untouched (no
  MODIFIED, so no base scenario can be lost).

Conflict check (checklist item 7): `grep -n 'premise' openspec/specs/*/spec.md` shows the `panel` performance
premise (the perf suite, D32/D33) and the `verification` gate rule — this change adds the *pty wait* premise,
which is a different subject (a wait horizon, not a measurement threshold). No statement is duplicated or
superseded; the new `panel` requirement points at the same `references/philosophy.md` principle ("a false green
is worse than nothing") rather than restating it.

D33 mapping (checklist item 8 of the brief): no wall-clock or CPU-share *red line* enters the gate. The horizons
are unchanged and remain failure detectors; the premise removes machine speed from the *verdict* (a skip, not a
green and not a red); the performance suite, its thresholds and its non-blocking status are untouched. The one
new number the gate reads (`PTY_PREMISE_PROBE_MS`) is a *machine* reading, never compared against the panel's
behaviour.

## 6. Coverage and boundaries

- Coverage: the *skip* path, the *red* path and the *green* path are each observable with the fixture-switch
  knobs (`TEAM_P21_PREMISE_*`, `TEAM_P21_STALL`) on a quiet host, so the change's scenarios are testable in a
  review block without controlling the machine. The behavioral reverse fixture (the view's wheel consumption
  removed in a scratch tree, bundle rebuilt there) is the red side of "the premise is not an escape"; the
  existing structural pins (§38-d/§38-e) stay in FAST and stay red-capable.
- Out of scope: new pty scenarios; the M59 engine's semantics (only the horizon/verdict handling is extended);
  the performance suite and D33's thresholds; the FAST/full split; the panel's own degraded-read behaviour.
- Paths: `skills/teamsmith/tests/panel-p21.sh` and `tests/lib/pty-wait.sh` are `agent:dev`'s; `tests/smoke.sh` is
  the gate's (an apply brief must grant it); `openspec/specs/**` and `docs/team/**` stay PM-owned.
- Granularity: one apply brief is enough, but the work splits naturally into two verifiable batches — (1) the
  engine + fixture (premise line, extension, attribution, exit 4, knobs, self-test), (2) the smoke wiring
  (§38-b/§38-f rc=4 mapping, the FAST pins untouched) plus the calibration table. The tasks list says which item
  belongs to which batch.
