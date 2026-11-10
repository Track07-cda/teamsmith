## MODIFIED Requirements

### Requirement: The printed route is a route that works

The project's correctness gate SHALL carry a route-sincerity walk (`bash skills/teamsmith/tests/routes.sh`, run by
the correctness gate's `smoke.sh` and runnable standalone) that judges the CLI's printed surface against the CLI's
real one:

- For every usage line of the help surface — the level-0 menu (`team help`), every level-1 group page and every
  level-2 command page (`help-surface#The help surface is a level-0 menu, a page per group and a page per command`
  defines the levels) — every `--flag` the line prints MUST be accepted by that command's own
  parser: the walk runs the command with that flag in a fixture project and fails, naming the command and the
  flag, when the parser answers with the tool's unknown-parameter refusal (for a command that only execs another
  program, the walk reads that program's own argument table instead — declared with the file and the reason). A
  flag only a sibling command accepts MUST NOT satisfy the line. A usage line the walk cannot attribute to a
  command and its flags MUST fail naming the line — an unparsable line is never skipped.
- The walk's working set SHALL come from the same command manifest the renderer reads (the single source
  `help-surface#The help surface is a level-0 menu, a page per group and a page per command` names), not from
  whatever text a rendered page happens to yield: for every command the manifest carries, every usage line it
  declares MUST be printed on that command's page and probed, and a command the CLI accepts while the manifest
  omits it MUST fail naming that command. Coverage is therefore "every command × every usage line it prints",
  and the walk SHALL print the number of commands and usage lines it judged. The pre-change walk read one prose
  block (`team help`) and judged 42 of the CLI's commands; a page's own usage line was not judged at all.
- For every command whose line prints at least one flag, an unknown flag (`--frobnicate-probe`) MUST be refused:
  a command that swallows unknown arguments fails naming the command. This is the walk's non-vacuity control —
  without it, a printed flag that is quietly ignored reads as accepted.
- For every schema note that names a `team` command, that command MUST resolve in the CLI, and the sentence's
  promise MUST really happen in the fixture through a declared promise probe; the set of keys needing a probe is
  derived from the schema, not from a hand-kept list, so a note naming a command with no probe fails naming the
  key, and a named command the CLI does not carry fails naming the key and the command. The probes assert
  effects, not exit codes: the roster's probe changes `TEAM_AGENTS` and writes its audit line, a category's probe
  writes the category token, the pulse window's probe makes the backend's recorded window call carry the key's value,
  and the model keys' probes make the next new task's rendered command carry the new model while same-task recovery keeps its assignment.
- For every refusal route the CLI prints (`修法：<command>` and `改行：<exact line>`), the walk SHALL apply the
  printed route in a fixture and re-run the command that refused. A clearing route — a `改行：` line, or a command
  that removes the condition (a `git switch`, a `git worktree add`) — MUST make that blocker disappear; an
  override route (`--force`, `--fresh`, a configuration knob) MUST be honored: the re-run proceeds under that
  route's own contract (its warning, and for a real launch its audit line), so a printed route can never be a
  line the tool itself refuses. A route that no longer clears its blocker, or is no longer honored, fails naming
  the family and the route. The families the walk exercises are declared in the walk itself (fixture → expected
  blocker → printed route kind → expected effect); a `修法：`/`改行：` family with no entry fails naming the
  family, so no printed route can go quietly unexercised. A `改行：` route is applied by writing that exact line
  into the brief header; a `修法：` route is applied by running it, inside the fixture, under the walk's recording
  `tmux` shim and its hard timeout.

The walk MUST NOT touch anything outside its own scratch fixtures: every command it runs runs in a fresh git
repository under `$TMPDIR` with a recording `tmux` shim first on `PATH`, `TEAM_MEETINGS_DIR` inside that fixture,
`stdin` from `/dev/null` and a hard timeout; it removes every directory it creates; it prints one line per usage
line, per probe and per refusal route (never a silent skip) and exits 0 only when every line, control, probe and
route is green. It prints one line per level and per page it judged, so a level that was never read is visible
as a missing group of lines rather than as silence.

The page-content controls for a column-zero command line, an undeclared command-page usage and an unread group
level SHALL use the same complete file judgement as this real walk: usage parser, continuation rules,
menu/group/command comparisons, attribution, page/level read state, `ok`/`finding` accounting and failure status.
The shared operations SHALL emit the findings and update the executing harness's `FIND`, not just return a value
for a caller to translate. The real walk SHALL invoke them in the current shell, preserve failure propagation at
its page/level call sites, and still render/read every real-manifest page before finishing level judgement.
A planned render job or empty file MUST NOT count as a page read. CLI claims, controls, promise probes and refusal
routes SHALL remain unchanged.

For exactly those three controls, the gate SHALL replace, not supplement or defer, each control's complete
nested `walk`. The column-zero and undeclared-usage controls SHALL each render the relevant single page with
the real damaged renderer and with the unmutated-tree renderer, then use that shared judgement. Each render
MUST exit 0 and produce a nonempty file. The negative result MUST carry the intended rule's finding, not another
rule's matching literal; each normal result MUST exit 0 without findings. The unread-group control SHALL judge
valid menu/command pages with no group read record, then with a valid group page restored; missing group MUST be
its sole negative finding. Real manifest-to-page wiring remains in the unshortened real walk. Missing files,
syntax errors, renderer failure or timeouts MUST NOT stand in for the expected named content failure.

These replacements SHALL run through the same script's explicit `bash skills/teamsmith/tests/routes.sh pages`
section. Executing non-FAST `mr_flips` SHALL unconditionally call that entry once, require child exit 0 and at
least the three distinct successful case-result lines `替代④`, `替代⑪`, `替代⑬`; a missing command, helper or
named case MUST fail, never skip. The sample itself SHALL fail if one of those named results is absent or failed.
Acceptance SHALL use that identical entry and environment scaffold; no independent runner, second parser,
product test mode, new smoke section or deletion-policing guard SHALL be introduced. Default/FAST/meta section
selection remains unchanged.

#### Scenario: The committed tree is green

- **WHEN** `bash skills/teamsmith/tests/routes.sh` runs on this tree, and the correctness gate runs
  `TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null`
- **THEN** both exit 0, the walk prints one `ok` line per usage line it parsed, one per probe and one per refusal
  route (never a silent skip), and no `bad` line

#### Scenario: The field defect is caught, with the command and the flag named

- **GIVEN** a scratch tree whose `add-agent` help line incorrectly prints retired `[--model m]` while its parser refuses it with exit 2
- **WHEN** the walk runs against it
- **THEN** it exits non-zero and names `add-agent` and `--model`, and the other usage lines stay green

#### Scenario: A sibling command's flag does not satisfy the line

- **GIVEN** a scratch tree whose `add-agent` help line prints `[--fresh]` — a flag `dispatch` really accepts,
  `add-agent` does not
- **WHEN** the walk runs against it
- **THEN** it exits non-zero naming `add-agent` and `--fresh`

#### Scenario: A command that swallows unknown flags fails the control

- **GIVEN** a scratch tree whose `ps` parser no longer refuses unknown arguments (today's measured shapes are
  `version` and `meeting list`, which accept them and run)
- **WHEN** the walk runs against it
- **THEN** it exits non-zero naming `ps`

#### Scenario: A command-block line the walk cannot attribute is a failure

- **GIVEN** a scratch tree whose command block carries a line at column 0 that no command owns while it prints a
  flag (the pre-fix `board add|assign|set|row|ls … [--allow-dup]` shape — measured: `cmd-project.sh:32` is not
  indented, so an indentation-based parse would skip it and leave `--allow-dup` unjudged)
- **WHEN** the walk runs against it
- **THEN** it exits non-zero naming that line instead of skipping it

#### Scenario: A schema route naming a command that does not exist fails

- **GIVEN** a scratch tree whose `TEAM_GATES` note names `team frob off`
- **WHEN** the walk runs against it
- **THEN** it exits non-zero naming `TEAM_GATES` and `team frob`

#### Scenario: A schema note naming a command without a promise probe fails

- **GIVEN** a scratch tree whose schema gains a key whose note names `team config set-task-model` while no probe
  entry covers that key
- **WHEN** the walk runs against it
- **THEN** it exits non-zero naming the added key as a note that names a command without a promise probe, naming
  no other key

#### Scenario: A broken promise is a failure, not a warning

- **GIVEN** a scratch tree whose roster registration no longer changes `TEAM_AGENTS` (the write path is broken
  while the command still exits 0)
- **WHEN** the walk runs against it
- **THEN** it exits non-zero naming `TEAM_AGENTS`'s probe — the probes assert the effect, so a command that
  reports success without doing the sentence's work cannot pass

#### Scenario: The walk leaves the caller alone

- **WHEN** the walk finishes
- **THEN** no directory it created remains under `$TMPDIR`, the caller's project (`docs/team`, `.pi/team/state`,
  `git status`) is unchanged, and the real tmux session was never its target (every tmux call came from its shim)

#### Scenario: The new flag is a printed route like any other

- **GIVEN** the committed tree's `dispatch` usage line prints `--branch <name>` (the pre-change line did not, and
  the pre-change parser answered `✗ dispatch: 未知参数 --branch`, measured)
- **WHEN** the walk runs
- **THEN** the `dispatch` line's `--branch` claim is probed against the dispatch parser and stays green, and the
  sibling-flag and unknown-flag controls still hold

#### Scenario: A printed fix that stops clearing its blocker fails the walk

- **GIVEN** a scratch tree whose branch-refusal route prints a `git switch` to a branch that belongs to another
  task (the fixed command no longer clears the branch blocker)
- **WHEN** the walk runs against it
- **THEN** it exits non-zero naming the refusal family and that route, while the other families stay green

#### Scenario: Applying every printed route clears the composite refusal

- **GIVEN** the committed tree's composite clearing fixture (a malformed `change:` line, a malformed `deltas:`
  line and a worktree on another task's branch)
- **WHEN** the walk applies every `改行：` line and every clearing `修法：` command the refusal printed
- **THEN** the re-run of the same dispatch no longer reports any of those blockers

#### Scenario: An override route is honored, not just printed

- **GIVEN** the unfinished-previous-task family, whose printed route is the re-dispatch with `--force`
- **WHEN** the walk applies that printed route
- **THEN** the re-run proceeds under the override's own contract (the warning naming the task it overrides), and
  the walk records the family as honored instead of as cleared

#### Scenario: A printed route family with no walk entry fails

- **GIVEN** a scratch tree whose refusal prints a `修法：` route for a family the walk has no entry for
- **WHEN** the walk runs against it
- **THEN** it exits non-zero naming that family instead of skipping it

#### Scenario: A level-2 page's bad usage line is caught

- **GIVEN** a scratch tree whose level-2 `dispatch` page prints `--ghost-probe` (a flag `dispatch` refuses)
  while the menu's own `dispatch` line is clean
- **WHEN** the walk runs against it
- **THEN** it exits non-zero naming that page and `--ghost-probe` — the pre-change walk read only `team help` and
  stayed green here

#### Scenario: A command the manifest omits fails the coverage arm

- **GIVEN** a scratch tree whose command manifest drops `bg` while the CLI still accepts it
- **WHEN** the walk runs against it
- **THEN** it exits non-zero naming `bg`, and the other commands' lines stay green

#### Scenario: Every level is judged, not just the menu

- **WHEN** the walk runs on the committed tree
- **THEN** it prints an `ok` line for the menu, for each group page and for each command page it judged, its
  summary carries the number of commands and usage lines it judged, and the level-0 menu's own scale check runs

#### Scenario: The replacement controls still catch real renderer defects

- **GIVEN** separate scratch renderer copies with the original column-zero `board add <ID> [--allow-dup]`
  defect and undeclared `dispatch --ghost-probe` usage, and normal renderers from the unmutated tree
- **WHEN** each renders only its corresponding `help board` or `help dispatch` page and the shared complete
  file judgement used by the real walk reads it
- **THEN** all four render commands exit 0 with nonempty output; the damaged board's shared attribution finding
  contains `列 0 的行`, `无法归属` and that complete board line; the damaged dispatch's shared multiset-difference
  finding contains `dispatch`, `页与清单不一致`, `页上多出` and complete `dispatch --ghost-probe`
- **AND** the special `ghost-probe` literal finding alone cannot satisfy the dispatch case; both normal pages
  exit 0 without findings, and successful `替代④`/`替代⑪` results identify the retired controls without CLI probes;
  the real walk continues to probe every manifest claim separately

#### Scenario: The unread-level replacement judges pages read rather than pages planned

- **GIVEN** valid menu and command files but no actual group read record, even if a group file is planned
- **WHEN** each supplied nonempty file passes the shared per-page judgement and level judgement finishes,
  and then the otherwise identical input is judged with a valid group file/read record restored
- **THEN** the menu and command pages emit no findings; the first level finish emits exactly one finding,
  `group 这一级一条都没被判到`, while the restored input exits 0 without findings and yields `替代⑬`
- **AND** a separately supplied empty page emits the original `帮助面缺一页` finding and does not register as
  read; this cannot substitute for the sole-missing-group witness. This control runs no renderer or complete
  walk; the real walk still derives all pages from the real manifest and judges the files it actually reads

#### Scenario: A damaged shared judgement makes its own negative control fail

- **GIVEN** a scratch copy that silently skips the shared column-zero attribution failure, and another that
  removes the shared command-page multiset-difference finding while leaving the special-literal check intact,
  without a load, syntax or renderer error
- **WHEN** `bash skills/teamsmith/tests/routes.sh pages` runs against each copy
- **THEN** the first run fails `替代④` for the missing attribution diagnosis, and the second fails `替代⑪`
  for the missing difference diagnosis even if a different finding still names `ghost-probe`; normal inputs
  still pass without findings
- **AND** restoring the shared judgement makes the identical sample command succeed again

#### Scenario: Three redundant complete walks are retired rather than rescheduled

- **WHEN** the explicit `routes.sh pages` controls run and their commands are inspected, and the non-FAST
  `mr_flips` call site is reviewed
- **THEN** the gate unconditionally invokes the identical sample entry with checks of exit and all three
  successful named results; the column-zero and undeclared-usage cases execute their single-page renderer
  experiments and shared judgement, and the unread-group case executes only its file judgement
- **AND** none of these three controls performs a complete nested walk, fixture-project initialization or
  whole-manifest CLI claim loop, through either the old call site or a replacement helper or later schedule;
  the real walk and every other route control retain their previous execution scope
