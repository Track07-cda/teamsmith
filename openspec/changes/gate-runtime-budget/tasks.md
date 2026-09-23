# Tasks: `gate-runtime-budget`

Planning only — nothing in this file is executed by the propose task (P97). **Two apply briefs plus one
independent verify brief.** Apply #1 (the accounting) touches the section line everything else rides on, so it
lands first and alone; apply #2 (the map + selector) then consumes it. The PM sequences apply #1 against
`gate-section-accounting`'s apply (P70): whichever lands first owns the close line, the other extends it.

Coverage map (requirement → items):

- **R1** *The run reports each section's outcome counts and its slowest sections* → 1.1–1.5
- **R2** *A changed-path list selects the sections to run, or the full suite* → 2.1–2.6
- **R3** *A selected run says what it did not run* → 3.1–3.4
- gate evidence → 4.1–4.3; the independent verify phase → 5.1.

How each requirement is re-checked (run what → read which part → expected value):

| Req | Run | Read | Expected |
|---|---|---|---|
| R1 | `TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null` | the per-section close lines, the sums, the slowest-N summary, `== 结果 ==` | exit 0 (on a green tree); one close line per started section incl. the last; `Σ✓/Σ✗/ΣSKIP` equal the result line's totals; the summary names at most 5 sections by seconds |
| R1 | `bash skills/teamsmith/tests/flip-m33.sh` and `bash skills/teamsmith/tests/gate-guard.sh` | the red-mark counts and the full-run-token expectations; the guard's directions | both green; no close line carries `  \033[31m✗\033[0m`; no duration compared to a threshold outside the section-guard module |
| R1 | the fixture that slows one section on purpose (fixture switch on, no assertion change) | that section's close line and the run's verdict | the seconds are printed, the section is **not** red, the exit status is unchanged |
| R1 | FAST before/after the change on the same tree | the `✓/✗/SKIP` totals and the exit status | identical (the Non-Goal: nothing relaxed); on this block's tree the pre-change FAST totals are `✓2759 ✗5 SKIP33` with main's pre-existing `14b`/`18` red named in the report |
| R2 | `bash skills/teamsmith/tests/section-select.sh --paths docs/team/BOARD.md docs/team/reports/P97-dev3.md` | the decision line | `decision=NONE` and an explicit "no section needs to run" |
| R2 | `bash skills/teamsmith/tests/section-select.sh --paths skills/teamsmith/scripts/lib/outbox.sh` | the decision line and the `key`/`why` rows | `decision=RUN`; the list includes the delivery keys the rows declare (seed: `12b`, `12b-h0`, `12b-h0b`, `12b-h0c`, `12b-h0d`, `12b-pi`, `12b-pi2`, `12b-pi3`, `26`, `27`, `42`, `44`, `46`, `47`) plus the prologue and the `needs` closure |
| R2 | `bash skills/teamsmith/tests/section-select.sh --paths ci/some-new-thing` | the decision line | `decision=FULL`, the path named as unclaimed |
| R2 | `bash skills/teamsmith/tests/section-select.sh --check`, then in scratch trees with (a) one row removed, (b) one row's patterns narrowed so a path its text names is uncovered, (c) an unknown `needs` key, (d) the exempt class claimed by a row | the verdict lines | clean green; each scratch tree red naming the section (and the token + line for (b)); restoring makes it green |
| R2 | `bash skills/teamsmith/tests/smoke.sh --select 17` | the section headers and `17`'s close line | `15b`'s header precedes `17`'s; `17`'s counts equal the full run's (a selection must not become vacuous) |
| R3 | `bash skills/teamsmith/tests/smoke.sh --select 12b` and its `tail -25` | the header, the result token, the not-run list | header names the decision and the unselected keys; the last 25 lines carry the not-run list; result is `== 选段结果 ==`; no `smoke 全绿`; no `== 结果 ==` |
| R3 | `bash skills/teamsmith/tests/smoke.sh --paths docs/team/BOARD.md` | the whole output | the no-section line, no result line, no `smoke 全绿`, no section header, exit 0 |
| R3 | `bash skills/teamsmith/tests/smoke.sh --select no-such-section` | the message and exit status | non-zero, the key named, no section started |

Path grants the apply brief must state (OWNERSHIP): `skills/teamsmith/tests/**` is **agent-owned** — the apply
touches `smoke.sh`, `section-paths.tsv` (new), `section-select.sh` (new), the fixture/self-test files it adds
and (if it wants the pointer) nothing else; `openspec/changes/gate-runtime-budget/**` belongs to the phase's
owner; `docs/team/reports/**` is the agent's own file. `skills/teamsmith/references/protocol.md` (the one-line
pointer to the selector in §9b-2) is **PM-owned**: the apply brief grants that file explicitly or the PM
applies the line itself. `openspec/specs/**`, `docs/team/tasks/**`, `docs/team/BOARD.md` stay PM-owned.

Fixture notes: every new fixture clears inherited team identity (`env -u TEAM_ROOT -u TEAM_MAIN_ROOT
-u TEAM_PROJECT -u TEAM_SESSION`; the suite's own unset block already covers `TEAM_*`/`TMUX`/`TMUX_PANE`) and
writes only inside its own scratch tree; nested suite runs use `TEAM_SMOKE_FAST=1`, a private
`TEAM_SMOKE_LOCK` and their own temp root (the suite's FAST branch already does this); the selector and the
`--check` runs are pure logic (no process, no tmux, no git) so they belong in FAST; the fixture switch
(`TEAM_SMOKE_FIXTURE=1`) gates every new knob and the ignore notices are asserted; `flip-m33.sh` compatibility
is pinned twice (the close line carries no colour-red mark; a selected run never prints `smoke 全绿`).

## 1. Accounting: counts, summary, and the red lines it must not move (apply #1, `verification` R1)

- [ ] 1.1 `tests/smoke.sh`: capture the counters at each `section()` call and print the previous started
  section's close line carrying its id, its seconds and the deltas of `PASS`/`FAIL`/`SKIP_N` since it started;
  keep the run's own list of started sections; close the last started section before the result line. Verify: a
  FAST run has exactly one close line per started section (including the last), `Σ✓/Σ✗/ΣSKIP` over the close
  lines equal the `== 结果 ==` totals, and the two runs' close-line count equals the number of started sections.
- [ ] 1.2 The slowest-N summary: printed before the result line, N = 5, `SMOKE_SLOWEST_N` honoured only under
  `TEAM_SMOKE_FIXTURE=1` (and printed as ignored otherwise); each row carries the id, seconds and counts, sorted
  descending. Verify: the clean run's summary names at most 5 sections; with the fixture switch and a small N
  the number changes; without the switch an injected value is ignored with the notice.
- [ ] 1.3 The accounting is not a red line: the counts are plain text (no `  \033[31m✗\033[0m`), no duration is
  compared to a threshold outside the section-guard module, and a deliberately slowed section stays green.
  Verify: `bash skills/teamsmith/tests/gate-guard.sh` green; the slowed-section fixture's line shows its seconds
  and the run stays green; `bash skills/teamsmith/tests/flip-m33.sh` green with unchanged red-mark counts.
- [ ] 1.4 Totals invariance (Non-Goal): the change adds/removes no assertion. Verify: `git diff` shows no added
  or removed `ok`/`bad`/`assert_*` call (a count of those call sites is identical before/after) and the FAST
  before/after runs print identical `✓/✗/SKIP` totals and identical exit status on the same tree.
- [ ] 1.5 A selected run obeys the same accounting (lands with #2's flags; until then the full-run form is the
  check): the `#<N>` counter numbers the started sections from 1, every started section has a close line, and
  the sums equal the run's own totals. Verify: `bash skills/teamsmith/tests/smoke.sh --select 0,0b` closes both
  sections with counts and its totals match.

## 2. The map and the selector (apply #2, `verification` R2)

- [ ] 2.1 `tests/section-paths.tsv` (new): one row per section in the sources (`key`, `id`, `patterns`,
  `needs`, `basis`) plus the `#`-comment header (exempt class, prologue keys, matcher semantics). Seed: the
  committed probe `docs/team/reports/P97/probe-section-paths.tsv` (406 tokens) and the fixture→section lookups
  in `docs/team/reports/P97-dev3.md`. Verify: `--check` green; the row count equals the `section "…"` count in
  `smoke.sh`; every key equals exactly one section id's short label.
- [ ] 2.2 `tests/section-select.sh` (new): the matcher (one function, documented `case` glob semantics), the
  decision output (`decision=FULL|NONE|RUN`, `reason=`, `key<TAB>why`), `--select`, `--list`, and the hard
  errors (unknown key, path outside the repository, malformed row). Verify: the three decision shapes (docs-only,
  a product path, an unclaimed path) and both hard errors' exit statuses and messages.
- [ ] 2.3 `--check` in both directions: a section without a row; a row without a section; a duplicate key; a
  literal pattern that does not exist; the exempt class claimed by a row; a `needs` key that does not exist or
  refers to a later section; and a real-tree path token named in a section's text that its row does not cover.
  Verify: green on the clean tree with the checked counts printed; each scratch-tree flip red and naming the
  section (the last one also names the token and its line); restoring is green.
- [ ] 2.4 `tests/smoke.sh --paths`/`--select`: consume the selector; `FULL` prints the notice and runs
  everything; `NONE` prints the no-section line and exits 0 with nothing run (and takes no gate lock); `RUN` runs
  the prologue, the selected sections and their `needs` closure in source order and nothing else; an unknown key
  exits 2 with nothing run; the run's own whole-run self-checks (`14c`'s FAST skip-list assertion, the tmp-root
  guard, the result-line accounting) do not fire merely because an unselected section was neither run nor
  skipped. Verify: the four shapes' outputs plus a FAST pure-logic section asserting them by nested runs.
- [ ] 2.5 R3's visibility from the suite side (with 3.1–3.3): the selection header, the distinct result token
  and the not-run list inside the last lines. Verify: `tail -25` of a `--select` run carries the not-run list;
  `smoke 全绿` and `== 结果 ==` appear nowhere in a selected run.
- [ ] 2.6 Prerequisites validated by counts (the vacuity guard): for at least the outbox selection and one
  further selection, compare each selected section's counts with a full run's; a section whose `✓` count falls
  below the full run's gets its missing `needs` (or its row is widened so the path answers `FULL`). Verify: the
  comparison table (selected vs full, per section) in the report and the `17` needs `15b` fixture asserting
  `17`'s counts are unchanged.

## 3. A selected run says what it did not run (apply #2, `verification` R3)

- [ ] 3.1 The header: one line before the first section naming the decision, `n/M` sections and the unselected
  keys; `--paths` with a `FULL` decision prints the fallback reason; `NONE` prints the no-section line.
  Verify: the fixture's assertions on the header for a `RUN` and a `NONE` shape.
- [ ] 3.2 The tokens: `== 选段结果 ==` instead of `== 结果 ==`, and `smoke 全绿` is unreachable in any
  selection mode. Verify: the fixture greps both tokens in a selected run; `flip-m33.sh` stays green (the
  full-run path is unchanged).
- [ ] 3.3 The not-run list in the tail: the list is printed within the last lines so the gate-output tail
  `team review` records carries it. Verify: `tail -25` of a selected run contains it; the review record's form
  is unchanged (`git diff` names no `cmd-review.sh`).
- [ ] 3.4 The exit status: a selected run's status reports only the sections it ran (0 iff none of them
  failed), and a `NONE` run exits 0 without a result line. Verify: the green selected run's status and a
  selected run with one failing section (fixture) returning non-zero.

## 4. Gate and evidence (the apply's own report)

- [ ] 4.1 `PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict`, `TEAM_SMOKE_FAST=1 bash
  skills/teamsmith/tests/smoke.sh </dev/null`, `bash skills/teamsmith/tests/gate-guard.sh`, `bash
  skills/teamsmith/tests/flip-m33.sh`, `bash skills/teamsmith/tests/section-select.sh --check`, and (once)
  `bash skills/teamsmith/tests/smoke.sh </dev/null` — paste the tails and the full run's wall time. On a tree
  whose pre-existing red is still open (see the report's finding), say so and keep the red attributed.
- [ ] 4.2 The evidence table: the per-section tables of two FAST runs with the load recorded (the consistency
  numbers), the selector's own wall time, the `--check` flips (a) – (d), the totals invariance, and the
  selected-vs-full counts comparison (2.6).
- [ ] 4.3 The pointer: if the brief grants `skills/teamsmith/references/protocol.md`, add the one line in §9b-2
  that names `section-select.sh --paths` as the mechanical form of "FAST plus the affected sections"; otherwise
  the PM applies it and the report says so.

## 5. Independent verification (a different agent — the pipeline's verify phase)

- [ ] 5.1 Rerun, out of tree and on the apply's tip: the two decision shapes and the fallback, `--check` with
  each flip, a selected run's header/tokens/tail, the vacuity fixture (`17`/`15b`), the totals invariance, the
  D33 flip, `gate-guard.sh`, `flip-m33.sh`, `openspec validate --all --strict` and the full smoke; the record
  goes to `docs/team/reviews/<ID>.md` with a verdict and any findings (a PASS carrying findings is rework, not
  archive).
