# Tasks: `gate-hygiene`

Five apply batches in this order: **G1** the review queue phase and its accounting (`verification`), **G2** the
load premise in the gate's assembly assertion (`panel`), **G3** the same premise in `panel-cpu.sh`, **G4** the
resource discipline in the docs (no requirement — the brief's C), **G5** gates, flips and real-path evidence.
G1 lands first because its queue protocol is what the docs (G4) describe and what the fixtures of G2/G3 run
under. This is planning only; no item here is executed by the propose task.

Coverage map (requirement → items): `verification` "The hard timeout covers the gate run, not the queue" →
1.1–1.7; `panel` "Frame assembly is asynchronous, cached and never blocks input" (MODIFIED) → 2.1–2.5, 3.1–3.4;
the FAST/full discipline and the lock's *why* → 4.1–4.4 (documentation by decision: the brief rules it out of
the spec).

Path grants an apply brief must state (OWNERSHIP): `skills/teamsmith/scripts/**` (the CLI and its libs) is
**PM-owned** and must be granted explicitly; `skills/teamsmith/references/**`, `skills/teamsmith/templates/**`,
`skills/teamsmith/SKILL.md` and `AGENTS.md` are PM-owned as well; `skills/teamsmith/tests/**` belongs to
`agent:dev`; `openspec/changes/gate-hygiene/**` belongs to the phase's owner; `openspec/specs/**`,
`docs/team/**` and the ledger stay PM-owned.

Fixture note: every review fixture in these batches sets `TEAM_GATES` to a stub and points `TEAM_SMOKE_LOCK` at
a **private temporary path** — no fixture may touch the machine lock `/tmp/teamsmith-smoke.lock`, and no fixture
may hold the machine lock. Locks are held by a helper process that releases on exit; the tmux-shim / record-only
pattern is not needed here (the queue phase runs before any window exists). `[real]` items need the machine lock
free or a deliberately held fixture lock; they are never the only evidence for a requirement.

## 1. G1 — the review queue phase and its accounting (verification, ADDED)

- [ ] 1.1 `scripts/lib/cmd-review.sh`: the gate-lock resolver — path `${TEAM_SMOKE_LOCK:-${TMPDIR:-/tmp}/teamsmith-smoke.lock}`,
  cap `TEAM_SMOKE_LOCK_WAIT` (default 1800, non-numeric → default), holder read from `<lock>.holder`; `flock`
  optional (absent → printed notice, no queue). Verify: a fixture with each value shape prints the resolved path,
  cap and holder.
- [ ] 1.2 `scripts/lib/cmd-review.sh`: the queue phase — acquire with `flock --close -w <cap> <lock> bash -c '…'`
  **before** the timeout clock; the inner command writes the run-start marker (`date +%s` to a temp file) and the
  holder line, then execs the existing `timeout … env … bash -c "$TEAM_GATES"`; `SMOKE_LOCK_WRAPPED=1` in the
  environment skips the queue (an ancestor holds it); `--no-gates` and an empty `TEAM_GATES` keep today's paths
  byte-for-byte. Verify: the queue fixtures of 1.5.
- [ ] 1.3 `scripts/lib/cmd-review.sh`: the accounting and the record — `queued = marker − review_start`,
  `ran = end − marker`; the gate line prints `（硬超时 Ns；排队 Ns；实际运行 Ns）`; the queue-cap path (no
  marker) writes `判定: **FAIL**` plus one line stating the gate **did not run**, the cap and the holder, and
  returns non-zero; `TIMEOUT` keeps the closed token and gains `ran=Ns`; the PM-conclusion block gains the
  queue-cap case ("this is not a verdict about the code — wait for the holder or raise the cap"). Verify: 1.5's
  record assertions plus `team_review_verdict` returning exactly `TIMEOUT`/`FAIL`.
- [ ] 1.4 `tests/smoke.sh` (dev-owned): export the wrapped marker for the suite's own subtree and a private
  `TEAM_SMOKE_LOCK` path, so a nested `team review` fixture neither waits on the machine lock nor deadlocks
  against the suite that holds it (full mode inherits `SMOKE_LOCK_WRAPPED=1`; FAST mode holds nothing and must
  still leave the machine lock untouched); the suite's own `SMOKE_LOCK` bookkeeping stays as it is. Verify: the
  regression that the existing review fixtures (T1.1, M25, F9–F17) pass in both FAST and full mode, and that
  none of them waits.
- [ ] 1.5 `tests/smoke.sh`: a new section for the requirement — (a) lock held 3 s + `TEAM_REVIEW_TIMEOUT=5` +
  `TEAM_GATES` that needs 3 s → `PASS` with `queued 3s / ran 3s / limit 5s` in the record; (b) lock held +
  `TEAM_SMOKE_LOCK_WAIT=2` → non-zero, `FAIL`, record names the holder and "the gate did not run"; (c) the same
  run makes **no** window/tmux call and leaves the board unchanged; (d) a nested review with
  `SMOKE_LOCK_WRAPPED=1` under a held lock returns immediately with `queued 0s`; (e) a `PATH` without `flock`
  prints the not-enforced notice and still runs the gate. Verify: the section's tail.
- [ ] 1.6 Flips: (a) move the lock acquisition inside the timed region → (a) becomes `TIMEOUT` (red); (b)
  delete the cap check → (b) queues to the cap/hangs (red); (c) write `判定: **TIMEOUT(ran=3s)**` → the
  `team_review_verdict` assertion goes red because the parser returns `none`; restore all three → green. Verify:
  both tails per flip.
- [ ] 1.7 Real-path check `[real]`: `team review` on a real checkout with the machine lock free → the record
  shows `queued 0s / ran Ns / limit 1800s` and the gate runs as before; the same with a fixture holding the real
  lock at a small cap → `FAIL` naming the fixture. Verify: both records pasted.

## 2. G2 — the load premise in the gate's assembly assertion (panel, MODIFIED)

- [ ] 2.1 `tests/smoke.sh`: `p27_perf_premise` — read the load (fixture override `TEAM_SMOKE_LOADAVG`, else
  `/proc/loadavg` field 1) and the cores (`nproc`, else `getconf _NPROCESSORS_ONLN`); enforce when
  `load ≤ 0.75 × cores`, else skip; print both numbers, the threshold and the decision on one line. Verify: the
  boundary cases (24.0/32 → enforce, 24.1/32 → skip) via the override.
- [ ] 2.2 `tests/smoke.sh` 27-d: premise holds → the existing 5-sample median judgment against 2000 ms,
  unchanged; premise fails → `SKIP（负载前提不成立：loadavg X > 0.75 × N）` with the samples and the load,
  incrementing a timing-skip counter that is **separate** from `SKIP_N` (14c audits `SKIP_N` against the FAST
  segmentation) and reporting no `bad`. Verify: 2.4's cases.
- [ ] 2.3 `tests/smoke.sh` result block: when the timing-skip counter is non-zero, print one line naming the
  skipped timing assertion(s) and the load, so the review record's 25-line tail carries the skip; exit status
  unchanged (a skip is not a failure). Verify: a run with `TEAM_SMOKE_LOADAVG` above the premise shows the line
  in the result block and exits 0.
- [ ] 2.4 `tests/smoke.sh` fixtures: (a) `TEAM_SMOKE_LOADAVG=26` + `TEAM_SMOKE_FRAME_DELAY_MS` injection →
  skip line with the measured median and no red; (b) `TEAM_SMOKE_LOADAVG=0.5` + injection → red (the red line
  did not move); (c) `TEAM_SMOKE_LOADAVG=0.5`, no injection → green. Verify: the section's tail.
- [ ] 2.5 Flips: (a) make the premise always-skip → (b) goes red; (b) make it always-judge → (a) goes red
  (the M49 false red); (c) read the cores as 0 or skip the core count → the threshold line and (b) go red;
  restore → green. Verify: both tails per flip.

## 3. G3 — the same premise in `panel-cpu.sh` (panel, MODIFIED)

- [ ] 3.1 `tests/panel-cpu.sh`: the premise helper with the same rule and the fixture override
  `TEAM_PANEL_CPU_LOADAVG`; premise fails → print the interactive first-frame ms, the pane CPU percentage and
  the load, and exit **4** (a skip is neither a pass nor a red); premise holds → today's judgments (first frame
  ≥ 2000 ms or pane CPU ≥ 1 % → red, exit 2). Verify: 3.3's cases.
- [ ] 3.2 `tests/panel-cpu.sh` header: document the exit-code table (0 pass / 2 red / 3 setup / 4 skipped by
  the load premise) and the premise, next to the existing red-line description. Verify: the header lists all
  four codes and the threshold.
- [ ] 3.3 `tests/panel-cpu.sh` fixtures: (a) load reading above the premise + a first frame past 2000 ms →
  exit 4 with the measured numbers and the load; (b) load reading below the premise + the same slow frame →
  exit 2; (c) load reading below the premise + a healthy frame → exit 0. Verify: the three exit codes and the
  summary lines.
- [ ] 3.4 Flip: remove the premise → (a) reports red (exit 2) instead of skipping; restore → exit 4. Verify:
  both tails.

## 4. G4 — the resource discipline in the docs (brief C, no requirement)

- [ ] 4.1 `references/protocol.md` §9b: one paragraph — the full gate is the machine's single shared resource;
  `TEAM_SMOKE_FAST=1` for in-batch self-tests, the full suite for delivery and review; the gate lock (path,
  holder, `TEAM_SMOKE_LOCK_WAIT` cap, the wrapped marker) and the queue/run accounting; the load premise and the
  visible skip; pointer to the specs instead of restating them. Verify: the section names the lock, the cap and
  the premise, and links both requirements.
- [ ] 4.2 `templates/AGENTS.section.md.tmpl` + `AGENTS.md`: the operational half for agents — FAST in batch, full
  before delivery/review, the queue exists and is bounded, a busy machine yields a visible SKIP rather than a red.
  The template is the source and the two files agree. Verify: rendering a scratch `team init` project contains
  the paragraph; `diff` of the corresponding sections is empty.
- [ ] 4.3 `SKILL.md`: the diagnostics row (`team smoke`) states the FAST/full purpose split and the queue; the
  tests-table row repeats the FAST/queue sentence where it already contrasts the two modes. Verify: `grep` shows
  both rows carry the queue sentence and `team help` is unchanged.
- [ ] 4.4 Consistency check: the three docs use the same key names (`TEAM_SMOKE_LOCK`, `TEAM_SMOKE_LOCK_WAIT`,
  `SMOKE_LOCK_WRAPPED`) and the same premise formula as the implementation; no doc restates a requirement body.
  Verify: one grep per token across the three files returns the same spelling.

## 5. G5 — gates, flips and acceptance

- [ ] 5.1 Confirm the new smoke section is registered in the suite's section list and that FAST mode prints its
  usual explicit skips (no silent omissions). Verify: the FAST run's skip table still matches the segmentation.
- [ ] 5.2 `PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh`
  — green on the full suite; paste the tail. Verify: exit 0.
- [ ] 5.3 Run the flip matrix of 1.6, 2.5 and 3.4 in sequence, each with its red and green tails. Verify: all
  three flips.
- [ ] 5.4 Trial archive on a scratch copy
  (`rm -rf /tmp/p26-trial && mkdir -p /tmp/p26-trial && cp -r openspec /tmp/p26-trial/ && (cd /tmp/p26-trial &&
  openspec archive -y gate-hygiene)`) — proves the MODIFIED `panel` block keeps every base scenario and the
  ADDED `verification` requirement is valid. Verify: the trial output.
- [ ] 5.5 Real evidence for both requirements in one run: the gate green with the load premise holding (or the
  skip line naming the load), and a completed review record carrying the queue accounting. Verify: both tails
  pasted in the report.
