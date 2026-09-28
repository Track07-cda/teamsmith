# Tasks: `gate-section-accounting`

Planning only — nothing in this file is executed by the propose task (P56). Two apply briefs plus one
independent verify brief; the measured budget table is a deliverable of apply #1 (items 2.1–2.3), because the
bounds are only honest with their measurement.

Coverage map (requirement → items): **R1** the correctness gate judges correctness only (MODIFIED) → 3.1–3.3;
**R2** every gate section accounts for itself, and a stuck section is named (ADDED) → 1.1–1.7, 2.1–2.5;
**R3** every wait in the gate is bounded and attributes at its cap (ADDED) → 4.1–4.4; gate/archive → 5.1–5.3;
the independent verification phase → 6.1.

How each requirement is re-checked (run what → read which part → expected value):

| Req | Run | Read | Expected |
|---|---|---|---|
| R1 | `TEAM_SMOKE_FIXTURE=1 TEAM_SMOKE_FRAME_DELAY_MS=2600 TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null`, then `bash skills/teamsmith/tests/gate-guard.sh` | the exit status and the run's timeout lines; the guard's four directions | exit 0, every section's start line carries a budget, **no** timeout line; the guard green, including the direction that only the section-guard module compares a duration to a threshold |
| R2 | the stuck-section fixture (nested FAST run, 1.5/2.1): `TEAM_SMOKE_FIXTURE=1 TEAM_SMOKE_STUCK_SECTION=0c TEAM_SMOKE_SECTION_BUDGET=3 TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null` | exit status; the line carrying `#<N>` + id + budget + elapsed; the progress lines; the absence of `== 结果 ==`; the scene dir under `${TMPDIR:-/tmp}` | exit 2; exactly one named timeout line; no result line, no later section, no `SKIP` for that section; the progress lines name the section while it runs; the scene names the section, the stuck process and the last progress reading and still exists after the run |
| R2 | `TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null` (clean) | the start/closing lines and `sections.tsv`; the exit status; the absence of a scene dir | exit 0; strictly increasing `#<N>` with one budget each; one closing line and one `sections.tsv` row per section; no timeout line; no scene |
| R2 | `bash skills/teamsmith/tests/section-guard.sh --budget-check` (and in a scratch tree with one budget lowered, and with one row removed) | the per-row verdict lines and the offending section | clean tree green; each scratch tree red and naming the section; restoring is green |
| R3 | `bash skills/teamsmith/tests/section-guard.sh --loop-check` (and in a scratch tree with a new `while :; do sleep 1; done`) | the inventory rows and the offending file:line | clean green with 43 `while`+`sleep` rows (each with a cap or a named structural bound); the scratch tree red naming file:line; restoring is green |
| R3 | the exhausted-wait fixture (4.3) | the attribution line and the section's `ticks` | one line naming the wait with `3/3` and the last reading; the wait returns non-green; `ticks` advanced during the wait |

Path grants the apply brief must state (OWNERSHIP): `skills/teamsmith/tests/**` is **agent-owned** — the apply
touches `smoke.sh`, `lib/section-guard.sh` (new), `section-budgets.tsv` (new), `section-guard.sh` (new),
`gate-guard.sh`, the loop-inventory file, and the fixture/self-test files it adds; `openspec/changes/
gate-section-accounting/**` belongs to the phase's owner; `docs/team/reports/**` is the agent's own file. **No
PM-owned path is required**: `.github/workflows/gates.yml` and `ci/Containerfile` stay untouched (D39's channel
and the pinned image already suffice), and documenting the bounds in `references/protocol.md` is **not** part of
this change. `openspec/specs/**` and `docs/team/tasks/**` stay PM-owned.

Fixture notes: every new fixture clears inherited team identity (`env -u TEAM_ROOT -u TEAM_MAIN_ROOT
-u TEAM_PROJECT -u TEAM_SESSION`, and the suite's own unset block already covers `TEAM_*`/`TMUX`/`TMUX_PANE`)
and writes only inside its own scratch tree; the nested stuck run uses `TEAM_SMOKE_FAST=1` (no machine lock, no
tmux) and its own temp root; the scene's placement test asserts the directory is `$TMPDIR`-relative, dot-prefixed
and **outside** the run's temp root; the budget/loop checks are pure logic (no process, no tmux) so they run in
FAST; `flip-m33.sh` compatibility is pinned because it counts colour-marked red lines and greps `smoke 全绿` —
the new closing lines must not carry colour-red marks and the stop path must not print the result line.

## 1. Section accounting: self-description and the bound (apply #1, `verification` R2)

- [ ] 1.1 `tests/smoke.sh` `section()` (`:161`): print the start line `== #<N> <id> == <ISO-8601> · 预算 <B>s`
  with a monotone run counter starting at 1, and print the previous section's closing line (`#<N>`, elapsed
  seconds) before the new start line; append each started section to a TSV record with the header
  `no id start elapsed_s ticks` under the run's temp root. Verify: a FAST run's output has one start line and one
  closing line per section with strictly increasing `#<N>`, and `wc -l` of the record equals the number of
  started sections.
- [ ] 1.2 `tests/section-budgets.tsv` (new): one row per section in the sources with the measured band
  (`max_host_s`, `max_container_s`, `ci_s`, the load recorded per measurement), `budget_s` and the provenance
  (revision + image tag); the derivation rule (`budget_s = max(ceil(band × factor), floor)`, factor 4, floor 60 s)
  in the header. Verify: `awk` over the table shows every `section "…"` id in `smoke.sh` has a row and every row
  satisfies the arithmetic and the floor.
- [ ] 1.3 `tests/lib/section-guard.sh` (new): the watchdog (double-forked like the M33 tripwire, not in the job
  table), the builtin-written heartbeat, the trip marker, the scene writer, the descendant walk and the
  `TERM`→`KILL` escalation — **never a process-group signal**; the stop/ack handshake and the clean-exit sweep.
  Verify: the probe shape (`docs/team/reports/P56/probe-section-guard.sh`) re-run against the module's own
  self-test exits 0 on all five shapes (stuck child, `TERM`-ignoring child, clean, builtin spin, spin + `TERM`
  trapped out) and the caller's process group is intact in each.
- [ ] 1.4 the suite's safe points: `section()`, `ok()`, `bad()` and the bounded-wait rounds check the trip marker
  and exit 2 with the named line; install the `TERM` trap that exits 2; arm the guard after the private tmux
  setup and disarm it before the result line and in `cleanup`. Verify: the injected stuck run exits 2 through the
  safe-point path, prints no result line and runs no later section; re-running with the marker check removed lets
  the same run reach its section's end (the break-it flip).
- [ ] 1.5 the fixture-only knobs (`TEAM_SMOKE_STUCK_SECTION`, `TEAM_SMOKE_SECTION_BUDGET`,
  `TEAM_SMOKE_PROGRESS_INTERVAL`, `TEAM_SMOKE_GUARD_POLL`) honoured only under `TEAM_SMOKE_FIXTURE=1`, printed as
  ignored otherwise. Verify: with the switch off and a stub budget set, the start lines carry the table's budgets
  and the ignore notices are printed; with it on, the injected values are used and the start line says so.
- [ ] 1.6 the progress self-report: one bounded line every `SMOKE_PROGRESS_INTERVAL` (default 60 s) while a section
  is in progress — `#<N>`, id, running elapsed, the slowest sections so far from the timing record — plus one
  warning line when a section closes above its table band. No new red line: it must not stop a run or make a
  section fail (D3), and it must be silent for a section that finishes inside the interval. Verify: with the
  fixture switch on and a small interval, the stuck fixture's output carries the progress lines; the clean FAST
  run prints none for sections inside the interval and still exits 0.
- [ ] 1.7 `flip-m33.sh` compatibility: the closing lines carry no colour-red marks and the stop path prints no
  result line. Verify: `bash skills/teamsmith/tests/flip-m33.sh` stays green.

## 2. The basis: measurement, checks and the scene (apply #1, `verification` R2)

- [ ] 2.1 measure and fill the table: a full local run and a run in the pinned image
  (`distrobox-host-exec podman run --rm … localhost/teamsmith-gate:local` or `ci/Containerfile`-built image), each
  with the per-section lines and the load recorded; the CI column from the first CI run's log; the seed is
  `docs/team/reports/P56/fast-section-times.tsv`. Verify: the report carries the three columns with their command
  lines and load readings, and every budget in the table is ≥ the band × 4 and ≥ 60 s.
- [ ] 2.2 `tests/section-guard.sh --budget-check` (new): every section has a row, every budget satisfies the
  arithmetic and the floor, the provenance is recorded, and an unlisted id resolves to the bounded default.
  Verify: green on the clean tree; a scratch tree with one budget lowered below the band × factor is red and names
  the section; a scratch tree with one row removed is red and names the section; restoring either is green.
- [ ] 2.3 the scene, asserted end to end: the stuck fixture's scene directory is `${TMPDIR:-/tmp}`-relative,
  dot-prefixed and outside the run's temp root; it survives the run (no `--keep`) and carries the section summary,
  the last progress reading, the descendant tree with the stuck command, the fixture-log tail and the partial
  timing record; the CI's existing collection needs no change. Verify: the fixture's assertion lines plus
  `grep -n 'docker cp' .github/workflows/gates.yml` unchanged.
- [ ] 2.4 the stuck-section fixture (a smoke section, FAST): a nested FAST run with the fixture switch on, the
  stuck knob on an early section and a small budget, asserting exit 2, the named line within the tail `team
  review` records (`tail -25`), no result line, no later section, no `SKIP` attribution, and the scene's
  evidence. Verify: the section's lines; the break-it (marker check removed in a scratch tree) turns it red.
- [ ] 2.5 the normal-run self-description assertions: exit 0, strictly increasing `#<N>`, one budget per start
  line, one closing line and one record row per section, no timeout line, no scene directory. Verify: the
  section's lines, plus the FAST run under load (the seed run's shape).

## 3. D33 stays green (apply #2, `verification` R1)

- [ ] 3.1 `tests/gate-guard.sh`: add the direction that the timing record is data — the only module comparing a
  duration to a threshold is `tests/lib/section-guard.sh`; a duration comparison reintroduced into the gate's
  other sources is red. Keep the existing closed marker sets and the perf-suite direction untouched. Verify:
  `bash skills/teamsmith/tests/gate-guard.sh` green; a scratch tree with `[ "$elapsed" -gt 5 ]` added to
  `smoke.sh` is red; restoring it is green.
- [ ] 3.2 the D33 flip stays green: `TEAM_SMOKE_FIXTURE=1 TEAM_SMOKE_FRAME_DELAY_MS=2600 TEAM_SMOKE_FAST=1 bash
  skills/teamsmith/tests/smoke.sh </dev/null` exits 0 with no frame-budget/CPU-share judgment and no timeout line.
  Verify: the run's tail plus the new scenario's own assertion lines.
- [ ] 3.3 the performance suite and its thresholds are untouched: `git diff --stat` names no `perf.sh`,
  `panel-cpu.sh` or `panel-cpu-premise.sh` change. Verify: the diff stat.

## 4. Bounded waits (apply #2, `verification` R3)

- [ ] 4.1 the loop inventory (new file) + `tests/section-guard.sh --loop-check`: every one of the 43
  `while`+`sleep` loops in the gate's sources is listed with its cap, or with the structure that bounds it (the
  three today: `smoke.sh:360`, `panel-cpu.sh:286`, `flip-m7.2.sh:187`). Verify: `--loop-check` green with the
  inventory count printed; a scratch tree with a new `while :; do sleep 1; done` is red and names file:line;
  restoring is green.
- [ ] 4.2 the attributed wait helper (with the heartbeat refresh at each round) and its use by the new fixture
  code; `tests/lib/pty-wait.sh` stays untouched. Verify: `bash skills/teamsmith/tests/lib/pty-wait.sh --self-test`
  and `bash skills/teamsmith/tests/panel-p21.sh wheel` stay green.
- [ ] 4.3 the exhausted-wait fixture: a wait with cap 3 against a state that never arrives prints one line with
  the wait's name, `3/3` and the last reading, returns non-green, and the section's `ticks` advanced. Verify: the
  fixture's lines plus the record row's `ticks > 1`.
- [ ] 4.4 the three cap-less loops: either bound them or record their structural bound in the inventory with the
  reason. Verify: `--loop-check` green and the inventory rows name each of the three.

## 5. Gate and archive (the apply's own report)

- [ ] 5.1 `PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict`, `TEAM_SMOKE_FAST=1 bash
  skills/teamsmith/tests/smoke.sh </dev/null`, `bash skills/teamsmith/tests/gate-guard.sh`, `git status
  --porcelain` clean, and (full, once) `bash skills/teamsmith/tests/smoke.sh </dev/null` — paste the tails and
  the full run's total wall time beside the number of progress lines it printed.
- [ ] 5.2 the report's flip section: the stuck run's named line and scene (before/after), the break-it flip
  (marker check removed → the stuck run reaches its section end), the budget-check flip (lowered budget → red),
  the loop-check flip, and the clean run's per-section accounting.
- [ ] 5.3 D40 precondition (both directions): if `openspec/changes/pty-fixture-load-premise` archives before this
  change's apply branch is reviewed, **rewrite the MODIFIED block against the new base** (carry its added
  scenarios) and re-record the delta; conversely, if this change archives first, that change's delta needs the
  same rewrite. Measured in the propose block: a trial archive of this change on a scratch copy merges cleanly
  (`+ 2 added, ~ 1 modified`) and then leaves the trial tree at **21 passed, 1 failed** —
  `pty-fixture-load-premise`'s pending delta omits the scenario this archive added. A trial archive
  (`mkdir -p /tmp/trial-p56 && cp -r openspec /tmp/trial-p56/ && (cd /tmp/trial-p56 && openspec archive -y
  gate-section-accounting)`) proves the MODIFIED requirement keeps every base scenario and merges next to the
  other open changes — and names the sibling that must be rewritten.

## 6. Independent verification (a different agent — the pipeline's verify phase)

- [ ] 6.1 Rerun, out of tree and on the apply's tip: the stuck fixture (exit 2, named line, no result line, the
  scene's evidence and its survival outside the temp root), the clean run's accounting, `--budget-check` and
  `--loop-check` with their flips, the D33 flip, `gate-guard.sh`, `openspec validate --all --strict` and the full
  smoke; the record goes to `docs/team/reviews/<ID>.md` with a verdict and any findings (a PASS carrying findings
  is rework, not archive).
