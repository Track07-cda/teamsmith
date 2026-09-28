# memory-and-deps Specification

## Purpose

What teamsmith requires from its environment (long-lived PM memory and an OpenSpec root) and where the truth lives:
OpenSpec owns specs and the change workflow, teamsmith owns the evidence ledger, and the disk wins over any memory.
Why: `references/philosophy.md` (handover-ready, no rival spec system) and `references/openspec.md`.
## Requirements
### Requirement: magic-context and OpenSpec are required dependencies

The project SHALL treat the PM's cross-session memory (magic-context) and OpenSpec as required: `team doctor` MUST
fail (non-zero) when magic-context is not detected, when the OpenSpec CLI cannot be resolved, or when the spec
directory is missing, and each failure MUST print the concrete fix. `TEAM_REQUIRE_MAGIC_CONTEXT=0` and
`TEAM_REQUIRE_OPENSPEC=0` SHALL downgrade the check to a warning for environments where the tool is deliberately
absent.

#### Scenario: A missing dependency fails the environment check

- **GIVEN** `TEAM_PI_SETTINGS_FILE` points at a fixture without magic-context and `TEAM_OPENSPEC_BIN=/nonexistent`
- **WHEN** `team doctor` runs
- **THEN** it exits non-zero, names both dependencies, and prints the fix command for each
- **AND** the same command with `TEAM_REQUIRE_MAGIC_CONTEXT=0 TEAM_REQUIRE_OPENSPEC=0` exits 0 and only warns

#### Scenario: A missing spec directory is a failure with a fix

- **GIVEN** `TEAM_SPEC_DIR` points at a directory that does not exist
- **WHEN** `team doctor` runs
- **THEN** it exits non-zero and the message contains the `openspec init --tools none` fix

### Requirement: Tool resolution is visible

The OpenSpec CLI and spec root SHALL be configurable (`TEAM_OPENSPEC_BIN`, default `openspec`, an absolute path
allowed; `TEAM_SPEC_DIR`, default `openspec`) and the resolved values MUST be reported by `team paths` together with
the requirement switches, so the PM never has to guess which binary and directory are in use.

The resolved JS runtime SHALL be reported the same way: `team paths` MUST carry `js_runner` (the resolved path —
`TEAM_JS_BIN` first, else `node`, `bun` or `tsx` on `PATH`) and `require_js` (the effective value of
`TEAM_REQUIRE_JS`, default `1`) next to the existing keys.

#### Scenario: Paths expose the resolved tools

- **WHEN** `team paths` runs with `TEAM_OPENSPEC_BIN=/usr/bin/true TEAM_SPEC_DIR=openspec`
- **THEN** the output contains `"/usr/bin/true"` as the OpenSpec binary and `"openspec"` as the spec directory

#### Scenario: Paths expose the resolved runtime

- **WHEN** `team paths` runs with `TEAM_JS_BIN=/usr/bin/node`, and then with `TEAM_REQUIRE_JS=0`
- **THEN** the first output contains `"/usr/bin/node"` as `js_runner` and `"1"` as `require_js`, and the second
  contains `"0"` as `require_js`

### Requirement: Spec management belongs to OpenSpec

teamsmith MUST NOT grow a second, rival requirement/specification format: the only requirement artifacts in the
project are the OpenSpec specs under `TEAM_SPEC_DIR`, and the change workflow is OpenSpec's. A behavior promise that
cannot be made falsifiable yet MUST be written as prose in `references/` instead of being turned into a requirement.

#### Scenario: No rival requirement tree

- **WHEN** every Markdown file in the repository is searched for `### Requirement:` blocks
- **THEN** all of them live under `openspec/specs/`, and none under `skills/teamsmith/`

#### Scenario: An invalid spec fails the project gate

- **GIVEN** a change whose delta would drop a scenario from an existing requirement (the measured defect class:
  both arbiters were run against exactly this shape on 2026-09-16)
- **WHEN** the project gate runs (`TEAM_GATES`), and when the phase-5 trial archive runs on a scratch copy
- **THEN** `openspec validate --all --strict` refuses the change at gate time, and the trial archive refuses it with
  "scenario(s) not present in the modified block" — the base specs themselves are only ever written through archive
  (direct edits are out of process), so no gate can see a base spec that archive did not produce
- **AND** restoring the scenario in the delta makes both pass

### Requirement: The disk is the source of truth, memory is a convenience

Project memory (magic-context) SHALL only accelerate recall: every decision, piece of evidence and piece of pending
work MUST be reconstructible from files on disk (BOARD, ROADMAP, DECISIONS, reports, reviews, threads, state) after
a restart or a compaction, without reading any memory store. The Chinese name the tool and its console use for the
correspondence records in `docs/team/threads/` SHALL be `往来记录` — `线程` reads as an operating-system thread —
while the directory path, the command `team thread` and the English term `thread` stay unchanged.

#### Scenario: Pending work survives a memory-less start

- **GIVEN** a project with one unread notification and one report awaiting review, and no memory store available
- **WHEN** a fresh shell runs `team digest`
- **THEN** both items are listed as pending work

#### Scenario: Decisions are on disk, not only in memory

- **WHEN** a key decision was made in a task
- **THEN** its rationale and impact are written in `docs/team/DECISIONS.md` (or the task's review record) and are
  readable without any memory tooling

#### Scenario: The renamed label keeps the path and the command

- **GIVEN** a fixture project with an initialized docs skeleton and no `docs/team/threads/dev.md`
- **WHEN** `team thread dev` runs, and then `team thread dev "note" --from pm --re X1` runs
- **THEN** the first output names `往来记录` and the path `<docs>/threads/dev.md`, and the second appends one entry
  to that same file — the directory and the command name did not change with the label

#### Scenario: The rendered threads README carries the new label

- **GIVEN** a scratch project
- **WHEN** `team init --agents "dev verify" --force` renders the docs skeleton
- **THEN** `docs/team/threads/README.md` contains `往来记录`, contains no `线程`, and its path is unchanged

### Requirement: A JS runtime is a required dependency

The JS runtime the panel bundle runs on SHALL be required like magic-context and OpenSpec (see the capability's
"magic-context and OpenSpec are required dependencies" requirement): `team doctor` MUST fail (non-zero) when none of
`node`, `bun` and `tsx` resolves on `PATH` and `TEAM_JS_BIN` names nothing usable, and when the resolved runtime's
major version is below the minimum the shipped panel bundle declares (`node` 20 or `bun` 1.3 today). The failure MUST
name the path or version it resolved and print the fix. `TEAM_REQUIRE_JS=0` SHALL downgrade this one check to a
warning; it does not give the panel a degraded mode of its own — the panel still requires a runtime (`panel`).

#### Scenario: A machine without a JS runtime fails the environment check

- **GIVEN** a `PATH` without `node`, `bun` and `tsx`, `TEAM_JS_BIN` unset, and the other required dependencies still
  resolvable (a stub OpenSpec CLI on `PATH` and `TEAM_REQUIRE_MAGIC_CONTEXT=0`)
- **WHEN** `team doctor` runs, and then `TEAM_REQUIRE_JS=0 team doctor` runs
- **THEN** the first run exits non-zero, names node and bun and prints the fix
- **AND** the second exits 0 and only warns

#### Scenario: An unusable or too-old runtime is named

- **GIVEN** `TEAM_JS_BIN` pointing first at a file that is not executable and then at a shim that prints `v18.0.0`
- **WHEN** `team doctor` runs against each of the two
- **THEN** the first run exits non-zero and names that path, and the second exits non-zero naming the version `18` and
  the required minimum

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
`pm` (the PM seat is not a roster member); an `add` SHALL validate its seat argument as **that single token
before any write** — a name carrying whitespace is two tokens in the value, not a seat, so the command SHALL exit 4
with the contract byte-identical and no `result=ok` line rather than smuggle both in; the rule is the roster key's
value rule (`list` kind), so a value that violates it is exit 4 naming the offending token, nothing written, and the
same rule is what
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
- **WHEN** `team add-agent 'api/1' --register`, `team add-agent pm --register`, `team add-agent 'api 1' --register`
  (and the same name with a tab for the space), and `team add-agent api --register` against a contract whose roster
  already reads `dev api api` are attempted
- **THEN** each exits 4, names the offending token (or `pm`, or the repeated token) and the accepted shape, and the
  sha256 is unchanged; the whitespace name also leaves no `result=ok` line — the pre-change entry appended its two
  legal tokens and wrote that line before failing, which is the flip
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
token in `TEAM_AGENT_MODELS` (for `pm`: whether `TEAM_PM_MODEL` is set). `known[]` SHALL be the union of the configured
and the recorded models — every seat's displayed model, the `pm` seat's resolution (`TEAM_PM_MODEL` when set, else
`TEAM_DEFAULT_MODEL` resolved exactly as the PM's launch resolves it, an empty one falling back to the schema
default) included — deduplicated in
first-seen order; the same set is the vocabulary `choices.values` reports for a `model`-kind key. `team config set-agent-model <seat> <model|->` SHALL write the pair list (or
`TEAM_PM_MODEL` for the `pm` seat) itself — the CLI parses and re-serializes the tokens; the caller never composes
them — through the same writer, fingerprint CAS, audit and `--dry-run`/`--yes` rules as `team config set`, with two
added validations: the seat MUST be a roster seat or `pm` (otherwise exit 5 naming the roster) and the model MUST
have the `provider/model` shape (otherwise exit 4). `-` SHALL remove the seat's override, leaving the fallback
(`TEAM_DEFAULT_MODEL`) in force. The whole-value validator of `TEAM_AGENT_MODELS` SHALL apply the same seat rule:
a token naming a seat the roster does not carry is exit 4, and one already in the file SHALL be reported by
`team config list --json` as a warning naming the token, never silently ignored.

Every seat row SHALL be serialized with a value in every field: `override` is always a JSON boolean (`true` when
the seat carries a token, `false` when it does not), and an empty model is the JSON string `""`, never a field with
no value and never `null`. A token whose value is empty (`dev=`) is a **present** override whose model resolution
falls back exactly like an absent token: the seat's displayed model is the fallback (`TEAM_DEFAULT_MODEL`, or the
recorded model when the source rules say `record`), and that one resolution is what `team ps`/`team roster`
display, what the seat's row reports, and what the dispatch renderer uses. A source label (`配置` / `显式` /
`历史记录`) MUST NOT appear as a `model` or in `known[]`.

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

#### Scenario: The known set carries the PM seat's model

- **GIVEN** a fixture contract whose `TEAM_AGENT_MODELS` does not name the PM's model and whose `TEAM_PM_MODEL` is
  `kimi-coding/k3-256k`, plus a roster seat whose `state/<seat>.env` records a model differing from its
  configuration resolution
- **WHEN** `team config list --json` runs
- **THEN** `models.known` carries `kimi-coding/k3-256k` exactly once, `models.seats`' `pm` row shows it with
  `override` true, and `TEAM_PM_MODEL`'s `choices.values` contains it
- **AND** with `TEAM_PM_MODEL` removed the `pm` row falls back to the default while the roster seat's recorded
  model stays in `known`, each model appearing once

#### Scenario: An empty token is a present override with the fallback model

- **GIVEN** a contract whose sha256 is recorded, whose `TEAM_AGENT_MODELS` carries `dev=` and whose
  `TEAM_DEFAULT_MODEL` is `vendor-a/model-a`
- **WHEN** `team config list --json` and `team ps` run
- **THEN** `models.seats`' `dev` row reports `model` `vendor-a/model-a`, `source` `config` and `override` true;
  `team ps`'s line for that seat carries the same model with the `配置` label; `models.known` carries
  `vendor-a/model-a` and no source label; and the contract's sha256 is unchanged

#### Scenario: The empty token resolves the same way in the dispatch renderer

- **GIVEN** the same contract
- **WHEN** `team dispatch dev --print` runs
- **THEN** the rendered launch command carries `vendor-a/model-a` — the empty token does not render an empty model

#### Scenario: An empty default still resolves to the fallback

- **GIVEN** a contract whose `TEAM_DEFAULT_MODEL` is empty and whose `TEAM_AGENT_MODELS` carries `dev=`
- **WHEN** `team config list --json` runs
- **THEN** the `dev` row exists with `"model"` equal to the CLI's resolved default (the schema default for
  `TEAM_DEFAULT_MODEL`) and `"override":true`, and the document parses as JSON

#### Scenario: The PM row resolves exactly like the PM's launch

- **GIVEN** a contract whose `TEAM_DEFAULT_MODEL` and `TEAM_PM_MODEL` are both empty
- **WHEN** `team config list --json` and the PM launch renderer (`team up --print`) run
- **THEN** the `pm` row's `model` is the model the rendered command passes as its `--provider`/`--model` pair —
  the resolved default, never `""` — and its `override` is false

### Requirement: The machine read reports each key's choice set, and the schema is its only source

`team config list --json` SHALL report, for every key record (a key the file carries but the schema does not
included), a `choices` field derived from the same `team_config_schema()` row the validator reads:
`{source, values[], min, max, empty, note}`.

- `source` SHALL be `schema` when the vocabulary comes from the row itself (`bool`'s two canonical values, an
  `enum`'s `constraints`, a numeric kind's suggestion column), `known` when it is this project's model vocabulary
  (the `models` block's `known`, for the `model`, `pairlist`, `winlist` and `pattern` kinds), and `none` when the
  kind has no vocabulary.
- `values[]` SHALL be the ordered vocabulary: for `bool`/`enum` the key's **closed** accepted domain, for the
  other kinds the offered vocabulary (free text stays valid), and `[]` when there is none.
- `min`/`max` SHALL carry the numeric kinds' accepted bounds as strings (`''` = unbounded) and be empty for other
  kinds, so a reader can name the accepted interval without re-parsing the schema.
- `empty` SHALL be true exactly when the writer accepts the empty value for this key (a `path`/`model` spec ending
  in `,opt`, or a kind that accepts `''`).
- `note` SHALL be the command's optional explanation and empty when there is nothing to say.

The field SHALL be derived from the row the validator uses — the command MUST NOT carry a second option table —
and every value the read reports (a `values` entry or a suggestion-column entry) SHALL be a value that key's
validator accepts; a schema row whose offered value its own validator refuses SHALL fail the project's fixture
gate rather than be filtered silently. The field is additive: `team config list`'s human table, every existing
`--json` record field and `team monitor --print`/`--json` keep their current bytes and columns. The command MUST
NOT read the machine's Pi model catalogue (`~/.pi/agent/models.json`, `models-store.json`) to build `values`: the
model vocabulary is project data, so a catalogue entry whose endpoint no longer answers never becomes an offered
option.

#### Scenario: The field is the schema, per kind

- **GIVEN** a fixture project initialised from this tree
- **WHEN** `team config list --json` runs
- **THEN** `TEAM_BRANCH_MODE` reports `source` `schema` with `values` `["task","agent"]`; `TEAM_MONITOR_UI`
  reports `["auto","tui","text"]` in that order; `TEAM_NOTIFY_TMUX` reports `["1","0"]`; `TEAM_PULSE_INTERVAL`
  reports `min` `60`, `max` ``, `empty` false and the schema's suggestion column as `values`;
  `TEAM_AGENT_BIN` reports `empty` true while `TEAM_PI_BIN` reports `empty` false; `TEAM_GATES` reports
  `source` `none` with `values` empty
- **AND** a key the file carries and the schema does not still gets a record, with `known` false and
  `source` `none`

#### Scenario: A value the read offers and the validator refuses is a gate failure

- **GIVEN** a scratch copy of the CLI whose `TEAM_PULSE_INTERVAL` suggestion column reads `30` while the row's
  minimum is `60`, and a fixture contract
- **WHEN** the project's config fixture runs against that tree and walks every key's offered values through
  `team config set <KEY> <value> --dry-run`
- **THEN** it exits non-zero naming `TEAM_PULSE_INTERVAL` and `30`
- **AND** restoring the tree's own suggestion column makes it pass — the gate, not a silent filter, is what keeps
  the field honest

#### Scenario: The model vocabulary is project data, not the machine's catalogue

- **GIVEN** a fixture `HOME` whose Pi model catalogue names `sub2api/gpt-5.6-luna` and an `openrouter/…` entry,
  and a project contract naming one default model plus one seat model
- **WHEN** `team config list --json` runs with that `HOME`
- **THEN** `models.known` and every `model`/`pairlist`/`winlist`/`pattern` key's `choices.values` carry only the
  project's configured and recorded models, and no catalogue-only provider appears in either
- **AND** the command's read of the contract is otherwise unchanged (same fingerprint, same records)

#### Scenario: The field is additive and nothing else moves

- **GIVEN** a fixture project and two contracts whose values differ
- **WHEN** `team config list`, `team config list --json`, `team monitor --print` and `team monitor --json` run
  under each
- **THEN** the human table keeps its `KEY CLASS KIND VALUE` header and carries no choices column, the `--json`
  record keeps every existing field name and type next to the new `choices`, and neither machine exit carries a
  `choices` field

### Requirement: The worker-launch keys are an internal frozen seam, not a supported extension point

The four worker-launch keys (`TEAM_AGENT_CMD`, `TEAM_AGENT_NOTIFY_CMD`, `TEAM_AGENT_LOG_GLOB`,
`TEAM_AGENT_BIN`) SHALL stay in the schema with class `apply` and keep every behaviour they have today. The
schema row and `references/config.md` SHALL describe them as an **internal seam (frozen)** — reserved for a
possible future non-Pi adapter, **no compatibility promise**, and not asked in the new-project questionnaire.
The marking SHALL live in the schema row's free-text column so `team config list --json` reports it verbatim
on each of the four records (the console shows it under the row, the same place a `refuse` key's route is
shown), and the schema's own header comment SHALL document the free-text column as the same route/note field
for `apply` keys. The human table (`KEY CLASS KIND VALUE`), the writer's validation, quoting, CAS, audit and
danger rules, the four keys' validated domains and the value of the keys' `class` SHALL be unchanged; the
questionnaire's silence is the `init-skill` capability's promise, this requirement owns the schema and
documentation marking.

#### Scenario: The marking reaches the machine read, and the walk makes it falsifiable

- **GIVEN** a fixture project initialised from this tree
- **WHEN** `team config list --json` runs
- **THEN** each of the four records reports `"class":"apply"`, its existing `kind`/`form`/`default` fields
  unchanged, and a `"route"` naming the frozen seam (`内部接缝（frozen）`) together with the no-compatibility
  promise, while `team config list`'s human header is still `KEY CLASS KIND VALUE`
- **AND** the fixture's red side — a scratch tree via `TEAM_CONFIG_TREE` whose `TEAM_AGENT_CMD` row lost its
  marking — makes the config section exit non-zero and name `TEAM_AGENT_CMD`; restoring the marking is green

#### Scenario: The keys stay writable and their domains do not change

- **GIVEN** a contract whose sha256 is recorded
- **WHEN** `team config set TEAM_AGENT_CMD 'myagent {prompt}' --yes`, then
  `team config set TEAM_AGENT_BIN /nonexistent/cli --yes`, then
  `team config set TEAM_AGENT_CMD $'line1\nline2' --yes` are attempted
- **THEN** the first two exit 0 and each appends exactly one `result=ok` audit line, the third exits 4 naming
  the single-line rule with the sha256 unchanged, and no write to the four keys is ever refused with the
  frozen text as its route (class stays `apply`, not `refuse`)

#### Scenario: Templates keep the keys and stop offering a worked example

- **GIVEN** `templates/config.sh.tmpl` and a contract freshly rendered from it
- **WHEN** both are read
- **THEN** the rendered adapter section carries the frozen wording and still declares the four keys (empty),
  and it offers no ready-to-use example of another CLI — worked examples live only in
  `references/agent-adapters.md`, under the frozen wording
- **AND** the `config-cli.sh` completeness walk (schema ↔ template ↔ `references/config.md`) stays green with
  no test edit

### Requirement: The machine read reports each key's functional group, and the schema is its only source

`team config list --json` SHALL report, for every key record, a `group` field: for a key the schema carries, the
schema row's **tenth column** verbatim — a closed ASCII token matching `^[a-z][a-z0-9-]*$` — and for a key the
file carries and the schema does not know, the empty string.

- The group SHALL be the row's own data: the command MUST NOT carry a second group table, and it MUST NOT derive
  the group by parsing the schema's section comments (they are documentation, not a grammar). A key added to the
  schema SHALL appear under its group with the console bundle unchanged.
- Every schema row SHALL declare a group. A row whose tenth field is missing, or whose token does not match the
  shape above, SHALL fail the project's fixture gate naming the key (and the token where there is one) — the read
  MUST NOT invent a default group, drop the row, or filter the malformed token silently.
- The read is the only carrier: the human `team config list` table, every existing `--json` record field,
  `team monitor --print` and `team monitor --json` SHALL keep their current bytes and columns, and no machine
  exit other than `team config list --json` SHALL carry the field.

#### Scenario: The group is the row's tenth column, per section

- **GIVEN** a fixture project initialised from this tree
- **WHEN** `team config list --json` runs
- **THEN** `TEAM_PROJECT` reports `group` `identity`, `TEAM_PULSE_INTERVAL` reports `panel`, `TEAM_DEFAULT_MODEL`
  reports `seat-model` and `TEAM_GATES` reports `workflow`, and the records' `group` values are exactly the tokens
  the schema's rows carry, in the schema's own row order
- **AND** a key the file carries and the schema does not still gets a record, with `group` `""`

#### Scenario: A missing or malformed token is a gate failure

- **GIVEN** a scratch copy of the CLI whose `TEAM_GATES` row lost its tenth field, and a second scratch copy
  whose `TEAM_PULSE_INTERVAL` token reads `NoPe!`
- **WHEN** the project's config fixture runs its group walk against each tree
- **THEN** it exits non-zero naming `TEAM_GATES` in the first and `TEAM_PULSE_INTERVAL` with `NoPe!` in the
  second — the gate, not a silent default, is what keeps the field honest
- **AND** restoring each row makes the walk pass

#### Scenario: The field is additive and nothing else moves

- **GIVEN** a fixture project and two contracts whose values differ
- **WHEN** `team config list`, `team config list --json`, `team monitor --print` and `team monitor --json` run
  under each
- **THEN** the human table keeps its `KEY CLASS KIND VALUE` header and gains no group column, the `--json`
  record keeps every existing field name and type next to the new `group`, and neither machine exit carries a
  group field

### Requirement: Every machine read is a JSON document, and an empty value is a value

Every command whose contract is a JSON document — `team config list --json`, `team change status <id> --json`,
`team paths`, and the console's one-frame `team monitor --json` / `team __panel-data` exits — SHALL emit exactly
one parseable JSON document for every contract shape the correctness gate exercises, including a seat whose
override carries an empty value. A field MUST NOT be serialized with no value (`"name":`); a string field with
nothing to report SHALL be the JSON string `""`; a boolean field SHALL be `true` or `false`; and `null` SHALL NOT
stand for "empty". The correctness gate SHALL run those exits against a fixture carrying the empty-override shape
and parse each output with the JSON parser its config fixtures already require (`python3 -m json.tool`), and a
document that does not parse MUST fail the gate naming the command and the parser's reported position.

#### Scenario: The empty-override shape parses on every machine exit

- **GIVEN** a fixture contract with `TEAM_AGENT_MODELS="dev="`
- **WHEN** `team config list --json`, `team change status <id> --json`, `team paths` and, with a JS runtime
  present, `team monitor --json` run
- **THEN** each exits 0 and `python3 -m json.tool` parses its output; with no JS runtime the console exit is a
  visible SKIP and not a red

#### Scenario: A valueless field is a gate failure

- **GIVEN** a scratch tree whose `team config list --json` emits a valueless field for a seat (`"override":,`)
- **WHEN** the gate's parse walk runs against that tree
- **THEN** it exits non-zero naming the command and the parser's error position, and restoring the tree's own
  serializer makes it green — the gate, not a silent tolerance, keeps the exits valid

### Requirement: The shell the CLI runs on is a checked dependency, not an assumption

The npm entry point SHALL verify its shell before it runs any part of the CLI: when `bash` cannot be resolved,
or the bash it resolves is older than major version 4, the wrapper SHALL print the concrete fix — naming the
missing or too-old shell, the found version where there is one, the `bash >= 4` minimum and where the
prerequisite is written down — and SHALL exit non-zero without running the CLI. The check SHALL resolve `bash`
the same way the CLI itself would (`bash` on `PATH`), so the message names the shell that would actually run the
tool, and it SHALL NOT introduce a `TEAM_*` knob or a degraded mode (a missing shell has no fallback). When the
shell resolves and is at least 4, the wrapper SHALL run the CLI unchanged — same argv, same stdio, same exit
status.

#### Scenario: No bash at all fails with the fix

- **GIVEN** a `PATH` with no `bash` on it, and the wrapper invoked through an absolute `node` so only the shell
  lookup can fail
- **WHEN** the wrapper runs `version`
- **THEN** it exits non-zero, names `bash`, names the `4` minimum and prints the fix line, and its output does
  not contain a `teamsmith` version line

#### Scenario: An old bash is named with its version

- **GIVEN** a `bash` earlier on `PATH` that answers the wrapper's version probe with `3` and otherwise delegates
  to the real bash
- **WHEN** the wrapper runs `version`
- **THEN** it exits non-zero and its message names the found major version `3` and the required `4`
- **AND** the CLI itself never ran (the output carries no `teamsmith` version line)

#### Scenario: A working shell runs the CLI unchanged

- **GIVEN** a `PATH` whose `bash` is the machine's own
- **WHEN** the wrapper runs `version` and `help`
- **THEN** both exit 0, the `version` output is the same `teamsmith <version>` line the bash CLI prints, and the
  `help` output is byte-identical to the bash CLI's

