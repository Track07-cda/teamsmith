# pty-fixture-load-premise · proposal

## Why

`panel-p21.sh choices` is a correctness fixture whose verdict depends on the machine. The PM measured
`✓ 48 ✗ 89` three times at `loadavg ≈ 11` and `✓ 110 ✗ 0` twice at `loadavg ≈ 2` — the same rows, the same
code, "only whether it waited" — and M74's verifier carried "look at the load first" as known noise. Since D33
the correctness gate must not turn red because a correct operation was slow, and that is exactly what the
fixtures' wait horizons now do — the same false red, through a side door.

Reconnaissance (this block, `nproc=32`) measured the shape: with the unchanged knobs the section is green at
`loadavg` 8.4–11.3 (97 s), in parallel runs (97 s each), under a fork storm at 12.5–20.0 (104 s), with all 32
cores saturated at 15.7–42.4 (114 s) and in a traced run whose 53 waits needed 1–4 rounds against a 40-round
base. **The 1-minute load average does not separate green from red** — the PM's red
sample sits inside the band of every green run measured here — so there is no `k × cores` crossing to calibrate.
What that run lacked was the *time* for the next needle-bearing frame.

## What Changes

- **MODIFIED — `verification`** (*The correctness gate judges correctness only*): a fixture that waits on a real
  process treats its horizon as a failure detector, never as a judgment; at exhaustion it attributes from in-run
  evidence (is the scene still painting? the load line; a code-independent probe). A machine over the premise
  becomes a **visible SKIP** — readings printed, counted, never green and never a failure, the gate still
  exiting 0; a healthy machine with a static scene still **fails**, and the readings stay real on the real path.
  No wall-clock or CPU-share red line is added, and the constants are calibrated from measured bands stated in
  the requirement.
- **ADDED — `panel`** (the fixture's own premise): the premise line; a progress-aware extension while the scene
  keeps painting; the attribution at the ceiling; exit status **4** = skipped, no conclusion; `smoke.sh`
  §38-b/§38-f mapping `4 → a visible SKIP` (0 green, 1 failure); the injection knobs honored only under the
  fixture switch; the FAST/full split untouched.

## Flip

Red before: a wait horizon cut to six rounds on a quiet host makes the same bundle report those timeouts as `✗`
(exit 1 — the PM's shape). Green after: the same run under an injected over-premise reading reports `SKIP` with
the readings and exits 4, while the wheel regression still exits 1 on a quiet host.

## Boundaries

Propose only: no `scripts/**`, `tests/**` or `references/**` change here. Not in scope: new pty scenarios, the
M59 engine's semantics, the performance suite and its thresholds, and the FAST/full split. No horizon or red
line is relaxed or scaled.

## Acceptance

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
git status --porcelain
```

## Evidence the report must contain

The measured table with its command lines and tails, the red side's reproduction command, and the calibration
arithmetic tying each constant to a measured band.
