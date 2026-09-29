# Tasks: `destructive-call-forensics`

Planning only — nothing in this file is executed by the propose task (P131). One apply brief: the shim's logging
block, the smoke legs and the scan's third exclusion ride the same change and land together — the new fixtures are
red until the shim writes the file, and the exclusion is what keeps the gate green over the real project once it
does. The verify phase is a separate brief owned by a different agent.

Coverage map (requirement → items): **R1** `boundary#A destructive call's record outlives the call log's rotation`
→ 1.1, 1.2, 2.1; **R2** `boundary#The gate's actions are logged, and no window carries a destructive-call grant`
(the `retention=failed` field and “those exact paths”) → 1.2, 2.1, 3.1; **R3**
`verification#The fixture-trace scan reads ledger state, not traffic records` (third exact-path exclusion) → 2.2,
2.3; gate/evidence → 3.2–3.4; independent verification → 4.1.

How each requirement is re-checked (run what → read which part → expected value):

| Req | Run | Read | Expected |
|---|---|---|---|
| R1 | the shim with `TEAM_TMUX_REAL` pinned to an argv-recording stub and `TEAM_TMUX_CALLS_LOG` in a scratch dir; §31c ⑤ plus the new legs | the two files' lines, counts and first lines | the refused line is in both files byte-identical; the call log's rotation drops its own copy, the retention file keeps it; `pass` calls add nothing; the retention file rotates 2101 → marker `dropped=1101` + 1000 lines |
| R2 | the same probes with the retention path a directory and with a FIFO; the base §31c ①②③④⑤⑥ legs | the call's line, stderr, exit codes | `retention=failed` on the call's line, the `✗` diagnostic naming the path on stderr, exit 0 / 64 unchanged, no hang; every base assertion still green |
| R3 | a scratch root + the real `real_ledger_hits` (extracted from `tests/smoke.sh`); §12b-j and M16 legs | the paths the scan reports | `tmux-calls.log.forensics` is silent; `.forensics.1`, `nested/tmux-calls.log.forensics`, `phantom.log` and `inbox/leak.md` are each named; the existing negative controls keep their counts plus the new legs |
| gate/evidence | `openspec validate --all --strict`, FAST + full smoke, `tmux-lint.pl` | the totals and the section lines | validate green; smoke `✗0`; lint 0 RED |

Path grants the apply brief must state (OWNERSHIP): `skills/teamsmith/tests/**` is agent-owned;
`skills/teamsmith/scripts/shim/tmux` is **PM-owned** and needs an explicit grant for the logging block
(`:293–:338`) only — the socket table, the target/verdict parsing, the argv pass-through and the exec block stay
byte-for-byte; `skills/teamsmith/references/troubleshooting.md` §18 is **PM-owned** and needs an explicit grant for
that section's log paragraph only; `openspec/changes/destructive-call-forensics/**` belongs to the phase's owner;
`docs/team/reports/P131-dev3.md` and `docs/team/reports/P131-dev3/**` are the agent's own. Deltas:
`openspec/changes/destructive-call-forensics/specs/boundary/spec.md` and
`openspec/changes/destructive-call-forensics/specs/verification/spec.md`.

Fixture notes: every fixture clears inherited team identity (`TEAM_ROOT TEAM_MAIN_ROOT TEAM_PROJECT TEAM_SESSION`)
and writes only inside its scratch tree; default-socket refusals run with `TEAM_TMUX_REAL` pinned to the
argv-recording stub (`m36_probe*` already does this) and never touch a real server; the retention fixtures derive
their path from their own `TEAM_TMUX_CALLS_LOG` and reset both files at the start of each leg (`m36_refuse` /
`m36_allow` reset the log only); the failure leg captures stderr itself (the helpers discard it) and wraps every
probe in `timeout 10`; the 2100-line seeds are written directly to the file, as the existing ⑤ legs do.

## 1. The shim's logging block (`boundary`, ADDED + MODIFIED)

- [ ] 1.1 `scripts/shim/tmux` (`:293–:338`): derive the retention path as `"$_log".forensics` and, for every call
  whose action is not `pass`, append the **same formatted line** (byte-identical — build it once) to that file,
  with the call log's own bound applied to it: past 2000 lines the oldest go and the newest 1000 stay, the
  surviving file's first line is the same `· rotation · dropped=<N>` marker with the same cumulative counting and
  the same unreadable-count restart; a FIFO retention target is skipped (never blocked on); a `pass` call creates
  no file and appends nothing. Verify: in a scratch dir with `TEAM_TMUX_REAL` a stub — a refused `kill-server`
  probe leaves `tmux-calls.log.forensics` holding exactly the log's line
  (`grep -F "$(tail -1 tmux-calls.log)" tmux-calls.log.forensics`), a `tmux ls` probe adds nothing, and after
  seeding 2100 retention lines one refused call leaves the marker `dropped=1101` plus exactly 1000 lines whose
  last is that call.
- [ ] 1.2 Same block: attempt the retention append **before** the call log's line is written, and when it does not
  happen append `retention=failed` to that same line (trailing field, no new `act=` token) and print a `✗`-marked
  diagnostic on stderr naming the retention path; the verdicts, exit codes, argv pass-through and the
  one-line-per-call rule stay untouched. Verify: with the retention path pre-created as a **directory** — an
  `allowed-owned` probe still reaches the stub, exits 0, and its line carries both `act=allowed-owned` and
  `retention=failed` while stderr names the path; a refused probe still exits 64 with the stub untouched; with the
  retention path a **FIFO** the probe returns within `timeout 10` and prints the same diagnostic; after removing
  the directory a fresh refused call writes an unsuffixed line.
- [ ] 1.3 Regression on the untouched contract: `git diff` over the shim shows changes **only** in the logging
  block — the socket table, the identity binding, the target parsing, the verdict table, the refusal block and the
  argv/token exec block are byte-for-byte identical. Verify: `git diff -U0 -- skills/teamsmith/scripts/shim/tmux`
  and the full §31c section stay green.

## 2. The fixtures (`boundary` + `verification`)

- [ ] 2.1 `tests/smoke.sh` §31c (after the existing ⑤ rotation legs): add the five legs of R1/R2 — (a) the
  retained line is byte-identical to the call log's line; (b) after 2100 call lines are seeded and one more gated
  call runs, the call log no longer holds the refused line while the retention file still holds it; (c) three
  read-only calls and one private-socket `kill-server` leave the retention file byte-identical (compare `md5sum`
  or `cmp`) while the call log gains their `act=pass` lines — the verdict decides, not the subcommand; (d) seeding 2100 retention lines + one refused call yields the marker
  `dropped=1101` plus 1000 lines, while a second gate with three lines + one refused call has four lines and no
  marker; the seed includes a `pass`-shaped line and the rotation drops it with the rest (nothing in the file is
  exempt); (e) the directory/FIFO failure leg of 1.2. Update the section's contract comment to name the sibling
  file and the `retention=failed` field. Verify: `TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh
  </dev/null` green; each leg goes red when 1.1/1.2 is reverted in a scratch copy (flip evidence for the report).
- [ ] 2.2 `tests/smoke.sh` — `real_ledger_hits()` (`:462`): add the third exclusion **by exact path**
  (`<root>/.pi/team/state/tmux-calls.log.forensics`) beside the audit-log and `bg/` exclusions, and update the
  comment above it; §12b-j (`:7644–:7691`): plant the fixture trace into `.pi/team/state/tmux-calls.log.forensics`
  (the scan must stay silent) and into `.pi/team/state/tmux-calls.log.forensics.1` and
  `.pi/team/state/nested/tmux-calls.log.forensics` (both must be reported); the existing count assertions grow by
  the two decoys and the “six leak legs” wording becomes eight. Verify: `TEAM_SMOKE_FAST=1` green; removing the new
  exclusion (or widening it to a basename glob) makes the retention leg and the two decoys fail as expected.
- [ ] 2.3 `tests/smoke.sh` M16's double control (`:11481–:11495`): add the retention leg beside the audit-log one
  (a planted record there is silent) and one decoy (`nested/tmux-calls.log.forensics` is caught); update the
  count line. Verify: FAST green; dropping the exclusion makes the leg red.

## 3. Docs and evidence

- [ ] 3.1 `references/troubleshooting.md` §18's log paragraph (PM-granted): state the retention file's path and
  contract (only non-`pass` lines, the same bound/marker, `retention=failed` + stderr on failure) and the third
  exact-path scan exclusion. Verify: the paragraph matches the delta wording, and `grep -n 'forensics'
  skills/teamsmith/references/troubleshooting.md` lands in §18.
- [ ] 3.2 Run `PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict`,
  `TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null`,
  `bash skills/teamsmith/tests/smoke.sh </dev/null` and `perl skills/teamsmith/tests/tmux-lint.pl`; paste the
  tails; `git status --porcelain` clean.
- [ ] 3.3 The report's flip section: for each of the five smoke legs, the red output before the shim change (a
  scratch copy of the shim without 1.1/1.2) and the green output after; the byte-identity probe; the failure probe
  with its stderr; the scan legs with their decoys. The report also states the untouched contract (1.3).
- [ ] 3.4 Trial archive on a scratch copy (`rm -rf /tmp/trial-p131 && mkdir -p /tmp/trial-p131 && cp -r openspec
  /tmp/trial-p131/ && (cd /tmp/trial-p131 && openspec archive -y destructive-call-forensics)`) — proves both
  MODIFIED requirements keep every base scenario and that the deltas merge beside the other open changes.

## 4. Independent verification (a different agent — the pipeline's verify phase)

- [ ] 4.1 Re-run, out of tree and on the apply's tip: the five smoke legs, the scan legs with their decoys, the
  negative controls, `openspec validate --all --strict` and the full smoke; the record goes to
  `docs/team/reviews/<ID>.md` with a verdict and any findings (a PASS carrying findings is rework, not archive).
