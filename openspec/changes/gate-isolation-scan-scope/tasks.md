# Tasks: `gate-isolation-scan-scope`

Planning only — nothing in this file is executed by the propose task (P73). One apply brief: the scan's scope and
the log's rotation ride the same change and the same gate run, so they land together; the verify phase is a
separate brief owned by a different agent.

Coverage map (requirement → items): **R1** `verification#The fixture-trace scan reads ledger state, not traffic
records` → 1.1–1.4; **R2** `boundary#The gate's actions are logged, and no window carries a destructive-call
grant` (traffic-record ruling, bound kept, rotation marker) → 2.1–2.3; gate/evidence → 3.1–3.3; the independent
verification phase → 4.1.

How each requirement is re-checked (run what → read which part → expected value):

| Req | Run | Read | Expected |
|---|---|---|---|
| R1 | a scratch root + the real `real_ledger_hits` (extracted from `tests/smoke.sh`), then `TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null` | the scanner's path list; §12b-j and M16's isolation lines | audit log + `state/bg/**` silent; `docs/team/inbox/**`, `state/phantom.log`, `tmux-calls.log.1`, `nested/tmux-calls.log` each named; the negative controls red |
| R2 | the shim with `TEAM_TMUX_REAL` pinned to a stub, against a seeded scratch log; §31c ⑤ | the log's first line and line count | `dropped=1101` then `dropped=2201`; 1000 call lines; newest last; no marker under the bound |
| gate | `openspec validate --all --strict`, FAST + full smoke, `tmux-lint.pl` | the totals and the section lines | validate green; smoke `✗0`; lint 0 RED |

Path grants the apply brief must state (OWNERSHIP): `skills/teamsmith/tests/**` is agent-owned;
`skills/teamsmith/scripts/shim/tmux` is **PM-owned** and needs an explicit grant for this change — the rotation
block in the logging section only, nothing else in the file; `openspec/changes/gate-isolation-scan-scope/**`
belongs to the phase's owner; `docs/team/reports/**` is the agent's own file. `openspec/specs/**`,
`docs/team/tasks/**`, `docs/team/BOARD.md` and the scan's roots/patterns stay PM-owned.

Fixture notes: every fixture clears inherited team identity (`env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_PROJECT
-u TEAM_SESSION`) and writes only inside its scratch tree; the shim probes pin `TEAM_TMUX_REAL` to an exit-0 stub
and never touch the shared default socket, and any private `TMUX_TMPDIR` is `mkdir -p`'ed first (memory #1250);
the smoke's own `TEAM_TMUX_CALLS_LOG` override (`tests/smoke.sh:253`) stays.

## 1. The scan's scope (`verification`, ADDED)

- [ ] 1.1 `skills/teamsmith/tests/smoke.sh` — `real_ledger_hits()` (`:214`): keep `--exclude-dir=bg` and add the
  exclusion of the audit log **by exact path** (`<root>/.pi/team/state/tmux-calls.log`); the two roots, the
  reporting format and the pattern argument stay unchanged; the comment above the function states the
  ledger-state/traffic-record distinction and names the two exclusions. Verify: in a scratch root planted with
  `P73SCAN`, the extracted function returns 0 hits for `state/tmux-calls.log` and `state/bg/gate.log`, and one
  path each for `docs/team/inbox/leak.md`, `state/phantom.log`, `state/tmux-calls.log.1` and
  `state/nested/tmux-calls.log` (the last two are the exact-path pins).
- [ ] 1.2 `tests/smoke.sh` §12b-j (`:6966`): add the audit-log leg — plant a fixture-trace line (session name +
  argv) into the scratch root's `state/tmux-calls.log`, assert the scan reports nothing and the section stays
  green — and the exact-path decoy legs (`.log.1`, `nested/tmux-calls.log`); the planted-inbox negative control
  stays and must stay red. Verify: `TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null` green; in a
  scratch copy where the exclusion is removed (or widened to `--exclude=tmux-calls.log`), the new legs go red
  (flip evidence).
- [ ] 1.3 `tests/smoke.sh` M16's double control (`:10196-10207`): add the audit-log leg beside the existing
  `state/bg` / `state/phantom.log` pair, so the shared scan is pinned at its second call site. Verify: FAST smoke
  green; removing the exclusion makes this leg red.
- [ ] 1.4 Sweep the remaining call sites (`26-l` `:8492`, M98 `:8381`) for comments that still describe the old
  "whole state directory" scope; align the wording only. Verify: `grep -n 'real_ledger_hits' tests/smoke.sh`,
  `bash -n skills/teamsmith/tests/smoke.sh` and the FAST run stay green.

## 2. The audit log's rotation (`boundary`, MODIFIED)

- [ ] 2.1 `skills/teamsmith/scripts/shim/tmux` (logging block `:290-304`): when the bound trips, write the
  rotation marker as the surviving file's first line — ISO-8601 timestamp, `rotation`, `dropped=<N>` — with `N`
  cumulative (the previous marker's `N` plus this rotation's removed call lines) and the newest 1000 call lines
  kept in order; no marker when the bound was not crossed; a missing/unparsable previous marker falls back to
  counting this rotation's removals. Nothing else changes: the per-call line, the socket table, the verdict table,
  the argv pass-through and the FIFO guard stay byte-for-byte. Verify (flip): seed 2100 lines, run one gated call
  through the shim with `TEAM_TMUX_REAL` pinned to a stub — before: 1000 lines, first line `seed 1102`,
  `grep -c rotation` = 0; after: first line `… · rotation · dropped=1101`, newest call line last; then 1100 more
  gated calls → `dropped=2201`.
- [ ] 2.2 `tests/smoke.sh` §31c ⑤ (`:10573-10577`): update the fixture to the marker contract — after the
  rotation assert the first line (timestamp + `rotation` + `dropped=`), one marker plus exactly 1000 call lines,
  the newest call last, no `act=` on the marker, and no marker in a log that never crossed the bound; the existing
  four-action and field assertions stay. Verify: FAST smoke green (the shim section runs in FAST); with the marker
  write removed in a scratch copy the new assertions go red.
- [ ] 2.3 Regression: `perl skills/teamsmith/tests/tmux-lint.pl` exits 0 with 0 RED lines, and
  `bash skills/teamsmith/tests/smoke.sh </dev/null` (full) is green once on the final tip.

## 3. Gate and evidence (the apply's own report)

- [ ] 3.1 Run `PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict`, `TEAM_SMOKE_FAST=1 bash
  skills/teamsmith/tests/smoke.sh </dev/null`, `bash skills/teamsmith/tests/smoke.sh </dev/null` and `perl
  skills/teamsmith/tests/tmux-lint.pl`; paste the tails; `git status --porcelain` clean.
- [ ] 3.2 The report's flip section: the six scope legs (the audit-log leg red before → green after; the other
  five as they must stay), the two rotation probes with their first lines and counts, and the negative-control
  outputs.
- [ ] 3.3 Trial archive on a scratch copy (`rm -rf /tmp/trial-p73 && mkdir -p /tmp/trial-p73 && cp -r openspec
  /tmp/trial-p73/ && (cd /tmp/trial-p73 && openspec archive -y gate-isolation-scan-scope)`) — proves the
  MODIFIED requirement keeps every base scenario and that the delta merges beside the other open changes.

## 4. Independent verification (a different agent — the pipeline's verify phase)

- [ ] 4.1 Re-run, out of tree and on the apply's tip: the six scope legs, both rotation fixtures, the negative
  controls, `openspec validate --all --strict` and the full smoke; the record goes to `docs/team/reviews/<ID>.md`
  with a verdict and any findings (a PASS carrying findings is rework, not archive).
