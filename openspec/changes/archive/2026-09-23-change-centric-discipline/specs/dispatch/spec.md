## ADDED Requirements

### Requirement: A brief names at most one change id

The brief header's `change:` line SHALL carry exactly one change id — a single token matching
`[A-Za-z0-9][A-Za-z0-9._-]*` — or `-` for a task that belongs to no change. A brief with more than one `change:`
line, or a value that is not a single token (a comma list, two whitespace-separated ids, an id plus `-`), MUST be
refused by `team dispatch` before any window is opened, and by `--print` as well, so no printed plan looks right
while the brief is wrong. The refusal MUST print the offending line and both accepted forms, and MUST NOT change
the task's board status.

#### Scenario: Two change ids in one brief are refused

- **GIVEN** a brief whose header reads `change: alpha, beta` (and a second one reading `change: alpha beta`)
- **WHEN** `team dispatch dev T1.1 <brief>` runs
- **THEN** it exits non-zero, prints the offending line and the accepted forms (`one id` or `-`), and requests no
  tmux window

#### Scenario: A second `change:` line is refused

- **GIVEN** a brief with two `change:` lines (`alpha` and `beta`)
- **WHEN** `team dispatch dev T1.1 <brief>` runs
- **THEN** it exits non-zero and names both lines, instead of silently using the first one

#### Scenario: `--print` refuses the same brief

- **WHEN** `team dispatch dev T1.1 <brief> --print` runs on the two-id brief
- **THEN** it exits non-zero and prints no prompt

#### Scenario: One id, and `-`, are allowed

- **GIVEN** a brief whose header reads `change: alpha` and one whose header reads `change: -` (with a declared anchor)
- **WHEN** each dispatch runs with `--print`
- **THEN** neither is refused for its `change:` value and the printed prompt names the brief path

#### Scenario: A refused dispatch leaves the board alone

- **GIVEN** a board row `| T1.1 | … | todo |`
- **WHEN** the dispatch of the two-id brief is refused
- **THEN** `team board row T1.1` still reports `todo`

### Requirement: A change-less brief declares its spec anchor

A brief whose `change:` value is `-` (or whose header has no `change:` line) SHALL declare its anchor in one of two
forms: a non-empty `specs:` value naming a capability that resolves to `openspec/specs/<capability>/spec.md` — and,
when a `#<requirement>` name is given, a requirement heading in that file — or `anchor: none (infra)` followed by a
non-empty reason. `team dispatch` MUST refuse — before any window is opened, and for `--print` as well — when
neither form is present or malformed, or when a named capability or requirement does not resolve, MUST name both
accepted forms and the path it looked for, and MUST NOT change the task's board status. `--force` MUST proceed with
a warning and one audit line naming the task and the missing anchor.

#### Scenario: Neither form is refused

- **GIVEN** a brief with `change: -`, `specs: -` and no `anchor:` line
- **WHEN** `team dispatch dev T1.1 <brief>` runs
- **THEN** it exits non-zero, prints both accepted forms (`specs: <capability>#<requirement>` and
  `anchor: none (infra) — <reason>`), and opens no window

#### Scenario: `anchor: none` without a reason is refused

- **GIVEN** a brief with `change: -` and `anchor: none (infra)`
- **WHEN** the dispatch runs
- **THEN** it exits non-zero and says the reason after the marker is required

#### Scenario: An honest infra anchor proceeds

- **GIVEN** a brief with `change: -` and `anchor: none (infra) — CI runner environment and test portability`
- **WHEN** `team dispatch dev T1.1 <brief> --print` runs
- **THEN** it is not refused for this reason and prints no anchor warning

#### Scenario: A resolving requirement anchor proceeds

- **GIVEN** a brief with `change: -` and
  `specs: panel#The board page is a kanban over the board's states`
- **WHEN** `team dispatch dev T1.1 <brief> --print` runs
- **THEN** it is not refused and the printed prompt keeps the anchor line

#### Scenario: An unresolvable anchor is refused

- **GIVEN** a brief with `change: -` and `specs: no-such-capability#…`, and another with
  `specs: panel#A requirement that does not exist`
- **WHEN** each dispatch runs
- **THEN** it exits non-zero and names the `openspec/specs/…` path it looked in

#### Scenario: `--force` records the override

- **GIVEN** the anchor-less brief of the first scenario
- **WHEN** `team dispatch dev T1.1 <brief> --force` runs
- **THEN** it proceeds, warns that the anchor is missing, and appends exactly one line to `state/watchdog.log`
  naming the task and the missing anchor

### Requirement: Two unfinished tasks of one change do not write the same delta file

`team dispatch` SHALL refuse to start a task whose delta targets intersect those of another unfinished task of the
same change. A brief's `deltas:` value SHALL be a comma-separated list of the change's capabilities whose delta
file the task will write, or `-` for a task that writes none; **when the `deltas:` line is absent, the task MUST be
treated as targeting every delta file of its change**. The refusal MUST name the sibling task, its board status, the
shared delta file(s) and both declarations, MUST NOT change any board status, and MUST come before any window is
opened (and for `--print` as well). `--force` MUST proceed with a warning and append exactly one audit line naming
both tasks and the shared file.

#### Scenario: Two tasks declaring the same delta are refused

- **GIVEN** an unfinished sibling task `M1` of change `alpha` whose brief declares `deltas: panel`, and a new brief
  for `alpha` declaring `deltas: panel`
- **WHEN** `team dispatch dev M2 <brief>` runs
- **THEN** it exits non-zero and names `M1`, its board status, `openspec/changes/alpha/specs/panel/spec.md` and both
  declarations

#### Scenario: A task that writes no delta proceeds

- **GIVEN** the same sibling `M1` and a new brief for `alpha` declaring `deltas: -`
- **WHEN** `team dispatch dev M2 <brief> --print` runs
- **THEN** it is not refused, and the output states which declarations were compared

#### Scenario: A missing declaration is treated as the whole delta set

- **GIVEN** a sibling task of the same change whose brief has no `deltas:` line
- **WHEN** a new brief for that change declares `deltas: panel` (or has no `deltas:` line either)
- **THEN** the dispatch is refused, and the message says the missing line was read as "every delta file of the
  change"

#### Scenario: Different changes are never compared

- **GIVEN** an unfinished task of change `alpha` declaring `deltas: panel` and a brief for change `beta` declaring
  `deltas: panel`
- **WHEN** `team dispatch dev B1 <brief> --print` runs
- **THEN** it is not refused, because the two delta files live in different change directories

#### Scenario: A finished sibling does not block

- **GIVEN** a sibling task of the same change whose board status is `done`
- **WHEN** a new brief declaring the same delta is dispatched
- **THEN** it is not refused

#### Scenario: `--force` proceeds with one audit line

- **GIVEN** the conflicting pair of the first scenario
- **WHEN** `team dispatch dev M2 <brief> --force` runs
- **THEN** it proceeds, prints the shared file as a warning, and appends exactly one line to `state/watchdog.log`
  naming `M1`, `M2` and that file
