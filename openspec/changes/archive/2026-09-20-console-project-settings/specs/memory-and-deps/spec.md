## ADDED Requirements

### Requirement: The project contract has exactly one writer, and it preserves what it does not change

`.pi/team/config.sh` (the project contract) SHALL be written only by `team config set`, through the one
implementation shared with `team init`/`team bootstrap` (the hardened `team_config_set_in_file`); the console
calls that command as a subprocess and MUST NOT open the contract for writing itself. A write SHALL preserve
every byte it does not change — comments, blank lines, the order of the keys and, on the changed line, the
inline comment — SHALL append a key the file does not carry as a line of its own at the end of the file (a
missing final newline MUST NOT join it to the previous line), and SHALL leave the file parseable
(`bash -n` exits 0). `team config list [--json]` SHALL be the machine-readable read of the same file: the
resolved path, the fingerprint, one record per key (name, class, kind, current value, default, whether the file
carries it, its inline comment) and the newest audit lines; `team config log [N]` SHALL print the newest audit
lines (default 10). A caller that asks for a value the writer cannot represent (a line break, a `#`) SHALL fail
loudly: the command exits non-zero and a caller inside another command (`team init`, `team bootstrap`) MUST
report the failure and exit non-zero rather than continuing without the key.

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

### Requirement: A write is accepted only against the file the writer read

`team config list --json` SHALL report `fingerprint` as the sha256 of the contract's bytes at the moment it read
them. `team config set … --fingerprint <sha256>` SHALL compare the current sha256 and, when it differs, refuse
with exit 3, one message naming that the file changed since it was read, nothing written and one audit line with
`result=conflict`; any byte change counts, including a change in a comment elsewhere. A write without
`--fingerprint` is the caller's explicit "use the file as it is now" and proceeds (documented). `--dry-run` SHALL
perform every check — class, value, fingerprint — and SHALL write neither the contract nor an audit line.

#### Scenario: A stale fingerprint refuses the write

- **GIVEN** a contract read at fingerprint A and then changed by another writer
- **WHEN** `team config set TEAM_GATES 'bash gate.sh' --yes --fingerprint A` runs
- **THEN** it exits 3, names the changed file, the contract's sha256 is the other writer's, and the audit log
  gained one `result=conflict` line naming the expected and the actual fingerprint

#### Scenario: The current fingerprint writes

- **GIVEN** a contract read at its current fingerprint
- **WHEN** the same command runs with that fingerprint
- **THEN** it exits 0 and exactly the requested line changed

#### Scenario: A dry run writes nothing

- **GIVEN** a contract whose bytes and audit log are recorded
- **WHEN** `team config set … --dry-run` runs with a stale fingerprint, with an invalid value and with a valid one
- **THEN** the three runs report conflict (3), invalid (4) and valid (0) respectively, and neither the contract
  nor the audit log changed

### Requirement: A value is validated, quoted by the writer, and never copied from the caller's quoting

`team config set` SHALL refuse a key the schema does not know or marks as read-only (exit 5, the message naming
the route for that key) and a value that fails the key's kind, range or enumeration check (exit 4, the message
naming the accepted domain). The written form SHALL be produced by the writer: the key, `=`, the value in single
quotes, so that sourcing the contract yields exactly that value as data — no variable expansion, no command
substitution, no globbing, no word splitting — and the caller's own quoting MUST NOT be reused. A value that
cannot be represented (a line break, a `#`) SHALL be refused, and a key the notify extension parses through its
flat `KEY="value"` reader MUST NOT be written with a `'` in the value (that reader has no escape). A valid value
that would disable a shipped guard or stop a loop or a queue from working (the danger list: the capacity floors
at 0, `TEAM_PULSE_INTERVAL` below 60, `TEAM_REVIEW_TIMEOUT` below 60, `TEAM_PULSE_MAX_RESTARTS=0`,
`TEAM_DEFER_TTL=0`, `TEAM_OUTBOX_MAX=0`, `TEAM_SQUASH_LOOKBACK=0`, the `TEAM_REVIEW_ALLOW_*` overrides at 1, a
non-empty `TEAM_MEETING_ALLOW_USER_ID`, and a `TEAM_PULSE_WINDOW` change while a pulse backend is running) SHALL
be refused unless `--allow-danger` is given, and `--dry-run` SHALL report it with exit 7; danger SHALL never
make an invalid value legal. The write SHALL go through a temporary file in the contract's directory, pass
`bash -n` before it is moved into place, keep the file's mode, and leave the original bytes in place on any
failure (including a failed check). The value is validated as it will be written: the environment's version of a
key MUST NOT make an invalid argument legal.

#### Scenario: The injection flip

- **GIVEN** a contract and the value `$(touch PWNED)`
- **WHEN** `team config set TEAM_GATES '$(touch PWNED)' --yes` runs and the contract is then sourced
- **THEN** `bash -n` exits 0, no `PWNED` file exists, and the key reads back byte-identical as data
- **AND** the pre-change writer's output — a double-quoted assignment that executes the substitution when the
  file is sourced — is the red side of this flip

#### Scenario: Quoting round-trips

- **GIVEN** the values `a && b | c`, `say "hi"`, `$HOME/x` and `a'b`
- **WHEN** each is set (the last one on a key the notify extension does not parse) and the contract is sourced
- **THEN** each variable reads back byte-identical to the value that was set

#### Scenario: Kinds, ranges and enumerations are refused before the write

- **GIVEN** a contract whose sha256 is recorded
- **WHEN** `TEAM_PULSE_INTERVAL=0`, `TEAM_NOTIFY_TMUX=maybe`, `TEAM_MONITOR_UI=colour` and
  `TEAM_AGENT_MODELS='dev'` (no `=`) are set
- **THEN** each exits 4, names the accepted domain, and the sha256 is unchanged

#### Scenario: The danger list warns and needs the explicit flag

- **GIVEN** a contract and `TEAM_MIN_FREE_SWAP_MB=0`
- **WHEN** it is set without the flag, then with `--dry-run --allow-danger`, then with `--allow-danger --yes`
- **THEN** the first exits 7 with the guard named, the second exits 0 writing nothing, the third writes it
  **AND** `TEAM_PULSE_INTERVAL=0 --allow-danger` still exits 4 (danger does not make an invalid value legal)

#### Scenario: A failed write leaves the original bytes

- **GIVEN** a contract whose sha256 is recorded
- **WHEN** the internal writer is called with a value that produces a file failing `bash -n` (the hostile
  trailing-backslash case the old writer wrote silently)
- **THEN** the writer exits non-zero, the sha256 is unchanged, and no temporary file remains

### Requirement: Every attempt is audited in one line

Every `team config set` attempt that passes argument parsing SHALL append exactly one line to
`<state>/config.log`: a UTC ISO-8601 timestamp, the result (`ok`, `refused`, `invalid`, `conflict`,
`danger-refused`, `write-error`), the actor (`--actor`, default `cli`; the console passes `panel`), the key, the
old and the new value and, for a conflict, the expected and the actual fingerprint. The line SHALL be one line
whatever the values contain, and a `--dry-run` SHALL NOT write one. `team config log [N]` and
`team config list --json`'s audit tail SHALL read at most the file's last 16 KiB and print at most the newest N
lines. When the audit line itself cannot be written the command SHALL still report the write's real outcome and
warn about the audit failure — a missing audit line MUST NOT be reported as a failed write.

#### Scenario: One line per attempt, refusals included

- **GIVEN** a fixture contract and a fresh audit log
- **WHEN** one valid set, one invalid set and one conflict are attempted
- **THEN** the log holds exactly three lines, in order `result=ok`, `result=invalid`, `result=conflict`, each
  naming the key, and the values are single-quoted inside the line

#### Scenario: A value with spaces stays one line

- **GIVEN** `TEAM_GATES='a && b'`
- **WHEN** it is set
- **THEN** the audit log gained exactly one line and `team config log 1` prints it unchanged

#### Scenario: The actor is the caller's, and the console passes its own

- **GIVEN** `TEAM_ACTOR` unset and `--actor panel`
- **WHEN** the same key is set twice, once without and once with the flag
- **THEN** the two audit lines carry `actor=cli` and `actor=panel`

#### Scenario: The reader is bounded

- **GIVEN** a 10 MiB audit log whose last line is known
- **WHEN** `team config log 5` runs, and `team config list --json` reads the audit tail
- **THEN** both finish promptly, print at most five lines, and the newest line is the log's last one

### Requirement: A seat's model is read and written as a seat, never by composing the pair list in the caller

`team config list --json` SHALL report a `models` block — `{default, known[], seats: [{agent, model, source,
override}]}` — where `seats` covers every roster seat (`TEAM_AGENTS`) plus `pm`, `model` is the model the CLI
displays for that seat, `source` is one of `config` / `explicit` / `record` with exactly the semantics of
`team_agent_model_src` (`common.sh`: no record → `config`; the record's `model_src=explicit` → `explicit`; a record
differing from the seat's configuration resolution → `record`), and `override` says whether the seat carries a
token in `TEAM_AGENT_MODELS` (for `pm`: whether `TEAM_PM_MODEL` is set). `known[]` SHALL be the union of the
configured and the recorded models. `team config set-agent-model <seat> <model|->` SHALL write the pair list (or
`TEAM_PM_MODEL` for the `pm` seat) itself — the CLI parses and re-serializes the tokens; the caller never composes
them — through the same writer, fingerprint CAS, audit and `--dry-run`/`--yes` rules as `team config set`, with two
added validations: the seat MUST be a roster seat or `pm` (otherwise exit 5 naming the roster) and the model MUST
have the `provider/model` shape (otherwise exit 4). `-` SHALL remove the seat's override, leaving the fallback
(`TEAM_DEFAULT_MODEL`) in force. The whole-value validator of `TEAM_AGENT_MODELS` SHALL apply the same seat rule:
a token naming a seat the roster does not carry is exit 4, and one already in the file SHALL be reported by
`team config list --json` as a warning naming the token, never silently ignored.

#### Scenario: Setting one seat's model touches only that token

- **GIVEN** `TEAM_AGENT_MODELS` carrying `dev=` and `verify=` tokens among comments and other keys
- **WHEN** `team config set-agent-model dev kimi-coding/k3-256k --yes` runs
- **THEN** `diff` shows exactly one changed line, which carries `dev=kimi-coding/k3-256k` and still carries
  `verify=`'s token unchanged, and the audit gained one line with the key and the new whole value

#### Scenario: Removing an override falls back to the default

- **GIVEN** the same contract and a `TEAM_DEFAULT_MODEL`
- **WHEN** `team config set-agent-model dev - --yes` runs
- **THEN** the `dev=` token left the line with every other byte unchanged, and `team config list --json`'s
  `models.seats[dev]` reports `TEAM_DEFAULT_MODEL`'s value with `source=config` and `override=false`

#### Scenario: An unknown seat is refused, in the pair form and in the whole value

- **GIVEN** a contract whose sha256 is recorded
- **WHEN** `team config set-agent-model dev4 x/y --yes` and `team config set TEAM_AGENT_MODELS 'dev4=x/y' --yes`
  run
- **THEN** the first exits 5 and the second exits 4, each naming the roster, and the sha256 is unchanged

#### Scenario: A model without the provider shape is refused

- **GIVEN** the same contract
- **WHEN** `team config set-agent-model dev deepseek-flash --yes` runs
- **THEN** it exits 4 naming the accepted `provider/model` shape and nothing was written

#### Scenario: The three sources are the CLI's, not the caller's

- **GIVEN** three fixtures: a seat with no record, a seat whose record was written by an explicit `--model`, and a
  seat whose record differs from its configuration resolution
- **WHEN** `team config list --json` runs for each
- **THEN** the sources are `config`, `explicit` and `record` respectively, and `team ps`'s line for the same seat
  carries the matching Chinese label (`配置` / `显式` / `历史记录`)

#### Scenario: An unknown seat already in the file is reported

- **GIVEN** a hand-edited `TEAM_AGENT_MODELS` with a `dev4=x/y` token
- **WHEN** `team config list --json` runs
- **THEN** the key's record carries a warning naming `dev4`, and `models.seats` carries no `dev4` row

#### Scenario: The PM seat writes TEAM_PM_MODEL

- **GIVEN** a contract with `TEAM_AGENT_MODELS` and `TEAM_PM_MODEL`
- **WHEN** `team config set-agent-model pm kimi-coding/k3-256k --yes` runs
- **THEN** `TEAM_PM_MODEL`'s line carries that model, `TEAM_AGENT_MODELS` is byte-identical, and the audit names
  `TEAM_PM_MODEL`
