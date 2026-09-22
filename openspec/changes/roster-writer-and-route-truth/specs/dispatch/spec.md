## ADDED Requirements

### Requirement: The roster changes only through an explicitly authorized registration

`team add-agent <agent> [--register] [--model <provider/model>|-] [--create|--no-install|--print]` SHALL be the
only CLI route that grows `TEAM_AGENTS`, and `team teardown --agent <agent> --register` the only one that shrinks
it. Both SHALL write through the project contract's one writer, with the roster key's value rule, its fingerprint
CAS and its audit (`memory-and-deps`: "The project contract has exactly one writer, and it preserves what it does
not change"), and `TEAM_AGENTS` SHALL keep class `refuse`. `team add-agent <agent>` for a seat the roster does not
carry and without `--register` SHALL exit 5, name the two routes that really work (hand-editing
`.pi/team/config.sh`, or re-running with `--register`), and MUST NOT open a window, create a worktree, write state
or touch the contract. `--register` for a seat the roster already carries SHALL be a visible no-op (exit 0, no
write, no audit line). `team teardown --register` SHALL require `--agent` (`--all --register` is a usage error,
exit 2) and SHALL refuse a seat the roster does not carry (exit 5 naming the roster, nothing written). Both
entries SHALL accept `--fingerprint <sha256>` with `team config set`'s semantics, and their own read-modify-write
SHALL pass the fingerprint of the bytes they read. `--model <m>` SHALL be validated before any write and SHALL set
that seat's configured model through the same writer and the same pairlist serializer
`team config set-agent-model` uses (`-` removes the override), and SHALL refuse exactly like the roster case when
the seat is outside the roster and `--register` was not given. The roster write SHALL come first (`team add-agent`
cannot build a worktree for a seat the tool does not know), and the command SHALL state what it wrote and what it
did not when the second write does not land. `team help`'s `add-agent` line SHALL print `--register`, `--model`,
`--create`, `--no-install` and `--print`, and `teardown`'s line SHALL print `--register`.

#### Scenario: `--register` grows the roster as one audited write

- **GIVEN** a fixture project whose roster line is `TEAM_AGENTS="dev verify"` among comments and other keys
- **WHEN** `team add-agent api --register --no-install` runs
- **THEN** it exits 0, `diff` shows exactly one changed line reading `TEAM_AGENTS="dev verify api"`, `bash -n`
  exits 0, and `<state>/config.log` gained exactly one `result=ok actor=cli` line naming `TEAM_AGENTS`
- **AND** the printed worktree step is the one `add-agent api --no-install` prints for a seat already in the roster

#### Scenario: The flagless refusal names two routes, and both work

- **GIVEN** the same contract and the sha256 recorded
- **WHEN** `team add-agent api` runs
- **THEN** it exits 5, the message carries `--register` and `.pi/team/config.sh`, the sha256 is unchanged, and no
  window, worktree or state record for `api` exists
- **AND** hand-editing the roster line to `TEAM_AGENTS="dev verify api"` makes `team add-agent api --no-install`
  print the worktree step instead of refusing — the hand edit is the second route, not a fallback that also fails

#### Scenario: Re-registering is a no-op and a stale fingerprint refuses

- **GIVEN** the contract of the first scenario after `api` joined, and its sha256
- **WHEN** `team add-agent api --register` runs again
- **THEN** it exits 0, prints that `api` is already in the roster, the sha256 is unchanged and `config.log` gained
  no line
- **AND** GIVEN a fingerprint read before another writer changed the file, `team add-agent api2 --register
  --fingerprint <stale>` exits 3, names the changed file, writes nothing and appends one `result=conflict` line

#### Scenario: Teardown removes a seat through the writer, and only on request

- **GIVEN** the same contract with `api` in the roster and `api`'s window and state present
- **WHEN** `team teardown --agent api --register` runs
- **THEN** the roster line reads `TEAM_AGENTS="dev verify"` with every other byte unchanged, one `result=ok`
  `actor=cli` line names `TEAM_AGENTS`, and the window/state cleanup of a plain `teardown --agent api` happened too
- **AND** `team teardown --agent api` (no flag) leaves the roster byte-identical (today's behaviour is the default),
  `team teardown --all --register` exits 2 without touching anything, and `team teardown --agent nosuch --register`
  exits 5 naming the roster with the sha256 unchanged

#### Scenario: `--model` is the seat's configured model, not a per-run choice

- **GIVEN** the same contract and a seat `dev` in the roster
- **WHEN** `team add-agent dev --model vendor/m2 --no-install` runs
- **THEN** the `TEAM_AGENT_MODELS` line carries `dev=vendor/m2`, exactly one audit line names that key, and
  `team config list --json` reports the seat with that model and `"override":true`
- **AND** `team config set-agent-model dev vendor/m3` afterwards produces the same line with `vendor/m3` (the two
  routes are the same write), `team add-agent dev --model -` removes the token, and `team add-agent api
  --model vendor/m2` without `--register` exits 5 naming `--register` with nothing written

#### Scenario: A predictable model error writes nothing, and a retry completes

- **GIVEN** the same contract, whose sha256 is recorded
- **WHEN** `team add-agent api --register --model deepseek-flash` runs
- **THEN** it exits 4 naming the accepted `provider/model` shape, the roster still reads `dev verify`, the sha256
  is unchanged and no audit line was written — the model value is judged before the first write
- **AND** re-running with `--model vendor/m2` registers `api` first and then writes its model, in that order in
  `config.log`, and both keys read back as requested

#### Scenario: The help lines print the register route

- **WHEN** `team help` runs
- **THEN** the `add-agent` line carries `--register`, `--model`, `--create`, `--no-install` and `--print`, and the
  `teardown` line carries `--register`
- **AND** the pre-change lines are this check's red side: `add-agent` printed `[--model m]` (a flag the parser
  refused) and neither line mentioned registration at all

### Requirement: The printed route is a route that works

The project's correctness gate SHALL carry a route-sincerity walk (`bash skills/teamsmith/tests/routes.sh`, run by
the correctness gate's `smoke.sh` and runnable standalone) that judges the CLI's printed surface against the CLI's
real one:

- For every usage line of `team help`, every `--flag` the line prints MUST be accepted by that command's own
  parser: the walk runs the command with that flag in a fixture project and fails, naming the command and the
  flag, when the parser answers with the tool's unknown-parameter refusal (for a command that only execs another
  program, the walk reads that program's own argument table instead — declared with the file and the reason). A
  flag only a sibling command accepts MUST NOT satisfy the line. A usage line the walk cannot attribute to a
  command and its flags MUST fail naming the line — an unparsable line is never skipped.
- For every command whose line prints at least one flag, an unknown flag (`--frobnicate-probe`) MUST be refused:
  a command that swallows unknown arguments fails naming the command. This is the walk's non-vacuity control —
  without it, a printed flag that is quietly ignored reads as accepted.
- For every schema note that names a `team` command, that command MUST resolve in the CLI, and the sentence's
  promise MUST really happen in the fixture through a declared promise probe; the set of keys needing a probe is
  derived from the schema, not from a hand-kept list, so a note naming a command with no probe fails naming the
  key, and a named command the CLI does not carry fails naming the key and the command. The probes assert
  effects, not exit codes: the roster's probe changes `TEAM_AGENTS` and writes its audit line, a seat's probe
  writes the model token, the pulse window's probe makes the backend's recorded window call carry the key's value,
  and the model keys' probes make the next spawn's rendered command carry the new model.

The walk MUST NOT touch anything outside its own scratch fixtures: every command it runs runs in a fresh git
repository under `$TMPDIR` with a recording `tmux` shim first on `PATH`, `TEAM_MEETINGS_DIR` inside that fixture,
`stdin` from `/dev/null` and a hard timeout; it removes every directory it creates; it prints one line per usage
line and per probe (never a silent skip) and exits 0 only when every line, control and probe is green.

#### Scenario: The committed tree is green

- **WHEN** `bash skills/teamsmith/tests/routes.sh` runs on this tree, and the correctness gate runs
  `TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null`
- **THEN** both exit 0, the walk prints one `ok` line per usage line it parsed (never a silent skip) and one per
  probe, and no `bad` line

#### Scenario: The field defect is caught, with the command and the flag named

- **GIVEN** a scratch tree whose `add-agent` help line prints `[--model m]` while the parser refuses it (this
  change's red side, measured: `✗ add-agent: 未知参数 --model`, exit 2)
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

- **GIVEN** a scratch tree whose schema gains a key whose note names `team config set-agent-model` while no probe
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
