## MODIFIED Requirements

### Requirement: The project contract has exactly one writer, and it preserves what it does not change

`.pi/team/config.sh` (the project contract) SHALL be written only by `team config set` and the roster's two
authorized entries (`team add-agent … --register`, `team teardown … --register`), through the one implementation
shared with `team init`/`team bootstrap` (the hardened `team_config_set_in_file`); the console calls that command
as a subprocess and MUST NOT open the contract for writing itself. A write SHALL preserve
every byte it does not change — comments, blank lines, the order of the keys and, on the changed line, the
inline comment — SHALL append a key the file does not carry as a line of its own at the end of the file (a
missing final newline MUST NOT join it to the previous line), and SHALL leave the file parseable
(`bash -n` exits 0). `team config list [--json]` SHALL be the machine-readable read of the same file: the
resolved path, the fingerprint, one record per key (name, class, kind, current value, default, whether the file
carries it, its inline comment) and the newest audit lines; `team config log [N]` SHALL print the newest audit
lines (default 10). A caller that asks for a value the writer cannot represent (a line break, a `#`) SHALL fail
loudly: the command exits non-zero and a caller inside another command (`team init`, `team bootstrap`) MUST
report the failure and exit non-zero rather than continuing without the key.

The roster is a contract value like any other: a registration SHALL be a read-modify-write through that same
implementation, with the value validated, the write protected by the sha256 fingerprint of the bytes the command
read (a change in between is exit 3 with one `result=conflict` audit line and no write) and exactly one
`result=ok` audit line in `<state>/config.log` with `actor=cli` per written value. `TEAM_AGENTS` SHALL keep class
`refuse`: `team config set TEAM_AGENTS …` SHALL keep exiting 5, the console SHALL keep refusing the key, and the
refusal SHALL name the register entry rather than a command that cannot write it. The roster value SHALL be a
space-separated list of seat names, each matching `[A-Za-z0-9][A-Za-z0-9._-]*`, each appearing once, none of them
`pm` (the PM seat is not a roster member); the rule is the roster key's value rule (`list` kind), so a value that
violates it is exit 4 naming the offending token, nothing written, and the same rule is what
`team config list --json` reports as that key's `warning` (naming the token) when the file already carries one —
the write side and the read side MUST NOT grow two rules.

A schema note that names a maintenance route SHALL name only a route that works on a project that already carries
a contract: the identity keys' note SHALL name hand-editing `.pi/team/config.sh`, and when it names `team init` it
SHALL name `team init --force` together with its cost (`--force` re-renders the whole file and overwrites every
other key with the template's value), because a bare `team init` prints `skip` and leaves the contract
byte-identical.

#### Scenario: One changed line, everything else byte-identical

- **GIVEN** a contract whose `TEAM_PULSE_NUDGE_GAP="900"  # 15min` line sits among comments, blank lines and
  other keys
- **WHEN** `team config set TEAM_PULSE_NUDGE_GAP 1200 --yes` runs
- **THEN** `bash -n` exits 0, `diff` shows exactly one changed line, and that line still carries `# 15min`

#### Scenario: A missing key is appended on its own line

- **GIVEN** a contract whose last line has no trailing newline
- **WHEN** a key the file does not carry is set
- **THEN** the old last line is unchanged and the new `KEY='value'` line follows it on a line of its own (the
  pre-change writer joins them, which is the flip)

#### Scenario: A value that cannot be represented is refused, loudly

- **GIVEN** a contract and the values `two\nlines` and `a # b`
- **WHEN** each is set
- **THEN** both exit non-zero naming the reason, the contract's sha256 is unchanged, and `team init --gates 'a # b'`
  in a scratch project also exits non-zero instead of silently dropping the key

#### Scenario: The write is atomic

- **GIVEN** a writer loop performing 50 sets and a reader loop sampling the contract
- **WHEN** the reader hashes and `bash -n`s every sample it read
- **THEN** every sample is either the old bytes or the new bytes and parses, and no `config.sh.*` temporary file
  survives the run

#### Scenario: The roster's authorized entry is this writer, and the key stays refuse

- **GIVEN** a fixture project whose roster line is `TEAM_AGENTS="dev verify"` among comments and other keys
- **WHEN** `team add-agent api --register` runs
- **THEN** `diff` shows exactly one changed line, reading `TEAM_AGENTS='dev verify api'` (the writer's canonical
  single-quoted form — the contract's quoting is the writer's, not the caller's), every other byte is
  unchanged, `bash -n` exits 0, and `<state>/config.log` gained exactly one `result=ok actor=cli` line naming
  `TEAM_AGENTS` with the old and the new value
- **AND** `team config set TEAM_AGENTS 'dev verify api more' --yes` still exits 5, its message names `--register`,
  `team config list --json` reports `"class":"refuse"` for the key, and the contract's sha256 is the register
  write's

#### Scenario: The roster value has one rule, and a violating value is refused

- **GIVEN** a contract whose sha256 is recorded
- **WHEN** `team add-agent 'api/1' --register`, `team add-agent pm --register`, and `team add-agent api --register`
  against a contract whose roster already reads `dev api api` are attempted
- **THEN** each exits 4, names the offending token (or `pm`, or the repeated token) and the accepted shape, and the
  sha256 is unchanged
- **AND** a hand-edited contract whose roster reads `dev api/1` makes `team config list --json` report `api/1` in
  that key's `warning`, and the same value is what the register entry refuses — one rule, read and write

#### Scenario: The identity note names a route that works on an existing project

- **GIVEN** a fixture project with a rendered contract whose `TEAM_GATES` is set to `bash my-own-gate.sh`
- **WHEN** the schema notes of `TEAM_PROJECT`, `TEAM_SESSION` and `TEAM_PM_WINDOW` are read, and the routes they
  name are exercised
- **THEN** the notes name hand-editing `.pi/team/config.sh`, and the `team init` they name (if any) is
  `team init --force` with its re-render cost stated
- **AND** a hand edit of `TEAM_PROJECT` changes what `team paths` prints, a bare `team init` re-run leaves the
  contract's sha256 unchanged (the measured pre-change note promised exactly this no-op as a route), and
  `team init --force` does change it by restoring the template's `TEAM_GATES` value — the cost the note names
