# gate-runtime-budget · proposal

## Why

The correctness gate (`openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh`) is 103
sections, ~3258 assertions, 13–20 minutes, one machine lock, one full run at a time. Two things are missing:

- **No per-section accounting.** One header per section and nothing else — no seconds, no counts — so "which
  sections are slow?" needs a hand-built harness (this task's probe, with the report).
- **No mechanical path→section answer.** `references/protocol.md` §9b-2 says "prefer FAST plus the affected
  sections", but nothing says which sections a diff affects, so the default is the whole suite.

## What Changes

- **ADDED — `verification`** (*The run reports each section's outcome counts and its slowest sections*): each
  section's closing line carries its seconds and `✓`/`✗`/`SKIP` counts, and the run ends with a slowest-N
  summary — a report, never a verdict (no threshold, no red mark, no exit-status effect; D33's guard keeps it
  so).
- **ADDED — `verification`** (*A changed-path list selects the sections to run, or the full suite*):
  `tests/section-paths.tsv` maps every section to the paths it covers (with a basis);
  `tests/section-select.sh --paths …` answers `RUN <keys>` / `NONE` / `FULL`, where any path no row claims is a
  **conservative full run** and `docs/**` is the declared exempt class; a selection always includes the
  prologue and the `needs` closure; `smoke.sh --paths`/`--select` consume it; the full suite stays the default
  and the milestone gate.
- **ADDED — `verification`** (*A selected run says what it did not run*): the selection header and the not-run
  list are printed (inside the tail `team review` keeps), `smoke 全绿` is never printed by a selected run, and a
  report resting on one names the sections that did not run.

## Capabilities

Three added `verification` requirements. `deltas: verification`.

## Impact

`skills/teamsmith/tests/**` (agent-owned): `smoke.sh`, `section-paths.tsv` (new), `section-select.sh` (new), a
fixture, the self-checks. Out of scope: any section's assertions/thresholds/skip rules, the performance suite,
the lock/queue, `scripts/**`, and the milestone rule (a selection is a batch filter only).

## Flip

Red before: a FAST run carries no per-section counts and no summary, and "which sections does this diff
affect?" has no mechanical answer. Green after: each section closes with `✓n ✗m SKIPk` plus seconds, the run
ends with the slowest N, and `--paths` answers — `docs/team/BOARD.md` → `NONE`, `scripts/lib/outbox.sh` → `RUN`
naming the delivery sections (`12b`, `12b-h0b`, `12b-h0d`, `12b-pi`, `42`, `46`, …), an unclaimed path →
`FULL`. Break-it: delete the fallback → the unclaimed path yields an empty `RUN` → the fixture goes red.
## Boundaries

Propose only: no `skills/**` change here. The delta **adds** requirements beside the in-flight
`gate-section-accounting` (P70), whose section line this builds on (design D8); the protocol pointer is a
PM-owned one-liner.

## Acceptance

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
bash skills/teamsmith/tests/gate-guard.sh
git status --porcelain
```

## Evidence the report must carry

The validate/FAST tails; two timestamped FAST runs (per-section tables, deltas, load); the probe's numbers
(406 rows, 67/104 sections naming a real-tree path, `docs/**` 0 hits, `openspec/**` 10); the trial archive.
