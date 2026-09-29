## ADDED Requirements

### Requirement: The run reports each section's outcome counts and its slowest sections

A run of `skills/teamsmith/tests/smoke.sh` SHALL report, once per started section and no later than the
line that closes it, the section's elapsed time in seconds and the outcome counts accumulated while it ran:
the number of `✓` assertions, the number of `✗` assertions, and the number of `SKIP` attributions, in a
form the section's own line carries (for example `12b · … · 41.2s · ✓37 ✗0 SKIP1`). It SHALL print the
closing line for the last started section before the run's result line, so every started section is
accounted for. At the end of the run it SHALL print one summary of the **slowest N sections** (N = 5, a
fixture-only knob may change it), each with its id, its seconds and its counts.

The counts SHALL be deltas of the run's own counters: summed over the closing lines they SHALL equal the
totals the run's result line prints, so the accounting can be checked against the run itself.

This accounting SHALL be a **report and never a verdict**: no line it adds may carry the colour-red mark the
gate's red-line counting matches (`  \033[31m✗\033[0m`), no duration it reports may be compared to a
threshold by it, a section that is merely slow MUST stay green, and neither the closing lines nor the
summary may change the run's exit status or suppress a subsequent section. A run that selects sections
(`verification#A changed-path list selects the sections to run, or the full suite`) numbers the sections it
actually starts from 1 and obeys the same rule.

#### Scenario: A green run accounts for every section and closes with the slowest ones

- **WHEN** `TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null` runs on a clean tree
- **THEN** it exits 0, every started section has exactly one closing line carrying its `✓`/`✗`/`SKIP` counts
  and its seconds (including the last section, whose closing line precedes `== 结果 ==`), the sums of the
  per-section counts equal the totals in `== 结果 ==`, and a slowest-N summary naming at most five sections
  with their seconds is printed before the run ends

#### Scenario: The accounting is not a red line and does not disturb the existing red-line counters

- **GIVEN** the gate's sources with one section made slower on purpose under the fixture switch (no
  assertion, threshold or skip rule changed)
- **WHEN** the run finishes and `bash skills/teamsmith/tests/flip-m33.sh` runs
- **THEN** the slower section's line carries its measured seconds, no closing line carries the red mark
  `  \033[31m✗\033[0m` (a count of `✗` assertions is plain text, not the marker), the run stays green, and
  `flip-m33.sh` reports the same red-mark counts and the same full-run token expectations as before

#### Scenario: A failing section is described, not decided, by the counts

- **GIVEN** a run in which one section's assertion fails
- **WHEN** that section closes and the run ends
- **THEN** its closing line reports at least one `✗`, the run's exit status is the same as it was before the
  accounting existed, and the sections after it still run

### Requirement: A changed-path list selects the sections to run, or the full suite

`skills/teamsmith/tests/section-paths.tsv` SHALL be the one place a path→section claim lives, with comment
header lines documenting the exempt path class, the prologue keys and the matcher's semantics, and one row
per section carrying the section's key, its id as the sources spell it, the repo-relative patterns it
covers, the keys of the sections that must run before it, and the basis of the claim. `bash
skills/teamsmith/tests/section-select.sh --paths <path>…` SHALL answer with `decision=FULL|NONE|RUN` and
exit 0 without running the suite and without calling git (the caller supplies the paths, for example from
`git diff --name-only <base>...HEAD`):

- **`NONE`** — every given path is in the declared exempt class (`docs/**`, the team ledger) and no row
  claims it: no gate section needs to run, and the output says so.
- **`RUN`** — every given path is claimed: the answer lists the keys whose patterns match, always including
  the prologue keys and the transitive closure of the rows' `needs` keys, and names the paths behind each
  key.
- **`FULL`** — at least one given path is claimed by no row and is not exempt: the answer names those paths
  and prescribes the full suite (running more is always safe; running too little is not).

With `--check` the selector SHALL verify its own basis in pure logic: every section in the gate's sources
has exactly one row and every row's key resolves to exactly one section; a literal pattern (one without a
wildcard) exists in the tree; the exempt class is claimed by no row; every `needs` key exists and
refers to a section that appears earlier in the sources; and a real-tree path token named inside a section's
own text (under the documented normalizer for the suite's path variables) is covered by that row's
patterns — a section that reads a path it does not declare is red and names the token and its line. An
unknown key, a path outside the repository, or a malformed row SHALL exit non-zero with the reason and run
nothing.

`bash skills/teamsmith/tests/smoke.sh --paths <path>…` and `bash skills/teamsmith/tests/smoke.sh --select
<key>[,<key>…]` SHALL run the selection: the prologue, the selected sections and their `needs` closure, in
source order, with the unselected sections not executed; an unknown key exits non-zero and runs nothing. A
run without either flag SHALL behave exactly as before (every section runs) — the full suite stays the
default and the delivery/review/archive gate, and a selection is a batch filter that never changes what a
selected section asserts.

#### Scenario: A docs-only diff needs no section, and a run that selects says so

- **WHEN** `bash skills/teamsmith/tests/section-select.sh --paths docs/team/BOARD.md
  docs/team/reports/P97-dev3.md` runs, and then `bash skills/teamsmith/tests/smoke.sh --paths
  docs/team/BOARD.md` runs
- **THEN** the selector prints `decision=NONE` and states that no section needs to run, and the suite run
  prints that no section was affected, starts no section (no `== <id> ==` header appears), prints no result
  line, prints no `smoke 全绿`, and exits 0

#### Scenario: A product path selects the sections that cover it, and their prerequisites

- **WHEN** `bash skills/teamsmith/tests/section-select.sh --paths skills/teamsmith/scripts/lib/outbox.sh`
  runs, and the resulting selection is run with `--select`
- **THEN** the decision is `RUN`, the listed keys include every key whose row declares that path (the data
  file is the authority) plus the prologue and the closure of their `needs` keys, and the selected run's
  output contains their section headers and none of the unselected sections'

#### Scenario: A section's prerequisites run with it instead of being assumed

- **GIVEN** the selector's data declares that section `17` needs `15b` (the gate's own comment says `17`
  reuses the fake settings/spec tree `15b` builds)
- **WHEN** `bash skills/teamsmith/tests/smoke.sh --select 17` runs
- **THEN** the output carries `15b`'s header before `17`'s, and `17`'s closing line reports the same counts
  as in a full run of the same tree (a selection must not turn its assertions into a vacuous pass)

#### Scenario: A path no row claims falls back to the full suite

- **WHEN** `bash skills/teamsmith/tests/section-select.sh --paths ci/some-new-thing` runs
- **THEN** the decision is `FULL`, the output names that path as unclaimed, and the run it prescribes is the
  full suite — the fallback cannot be reached by claiming too little

#### Scenario: A weakened or incomplete table is red, not silently narrow

- **GIVEN** the clean tree, then a scratch tree whose table loses one section's row, then a scratch tree
  whose row for one section no longer covers a path that section's own text names
- **WHEN** `bash skills/teamsmith/tests/section-select.sh --check` runs in each
- **THEN** the clean tree is green, both scratch trees exit non-zero and name the offending section (and, in
  the second, the token and its line), and restoring either makes it green again

### Requirement: A selected run says what it did not run

A run that selects sections SHALL NOT be mistakable for a full run: before its first section it SHALL print
one header naming the decision, how many of the gate's sections it will run and which keys it will not, its
result line SHALL use a distinct token (`== 选段结果 ==`, never `== 结果 ==`) and the run MUST NOT print the
full-run token `smoke 全绿` in any selection mode. The not-run list SHALL appear within the last lines of
the run's output, so the output tail that `team review` records
(`verification#The record states what was verified`) carries it without a rerun. A report whose evidence is
a selected run SHALL name the sections that did not run and MUST NOT present the run as a full-suite run;
`PASS` for a selected run means the sections it ran were green, never that the gate ran.

#### Scenario: The selection is visible in the run and in the recorded tail

- **WHEN** `bash skills/teamsmith/tests/smoke.sh --select 12b` runs and the last 25 lines of its output are
  read
- **THEN** the header names the decision and the unselected keys, the last 25 lines contain the not-run list,
  the result line reads `== 选段结果 ==`, `smoke 全绿` appears nowhere in the output, and the exit status
  reports only the sections that ran

#### Scenario: A run with no affected section runs nothing and claims nothing

- **WHEN** `bash skills/teamsmith/tests/smoke.sh --paths docs/team/BOARD.md` runs
- **THEN** it prints that no section is affected, prints no result line at all, prints no `smoke 全绿`, runs
  no section, and exits 0 — the message is a decision, not a green gate

#### Scenario: An unknown selection is refused before anything runs

- **WHEN** `bash skills/teamsmith/tests/smoke.sh --select no-such-section` runs
- **THEN** it exits non-zero, names the unknown key, and starts no section
