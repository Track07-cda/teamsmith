## MODIFIED Requirements

### Requirement: The disk is the source of truth, memory is a convenience

Project memory (magic-context) SHALL only accelerate recall: every decision, piece of evidence and piece of pending
work MUST be reconstructible from files on disk (BOARD, ROADMAP, DECISIONS, reports, reviews, threads, state) after
a restart or a compaction, without reading any memory store. Same-task recovery SHALL read the committed complete launch assignment from disk rather than re-resolve current model policy; legacy, malformed or identity-mismatched records SHALL refuse with a fresh takeover and disk handover route. Historical files SHALL NOT be rewritten to invent category provenance. The Chinese name the tool and its console use for the
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
- **WHEN** `team init --agents "dev verify" --force --task-models 'routine=vendor/light' --pm-model vendor/strong` renders the docs skeleton
- **THEN** `docs/team/threads/README.md` contains `往来记录`, contains no `线程`, and its path is unchanged

### Requirement: The project contract has exactly one writer, and it preserves what it does not change

`.pi/team/config.sh` (the project contract) SHALL be written only by `team config set`, `team config set-task-model`, `team config upgrade-models` and the roster's two
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
- **THEN** both exit non-zero naming the reason, the contract's sha256 is unchanged, and `team init --gates 'a # b' --task-models 'routine=vendor/light' --pm-model vendor/strong`
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
them. `team config set … --fingerprint <sha256>` (and category/upgrade entries with the same flag) SHALL compare the current sha256 and, when it differs, refuse
with exit 3, one message naming that the file changed since it was read, nothing written and one audit line with
`result=conflict`; any byte change counts, including a change in a comment elsewhere. A single-key write without
`--fingerprint` is the caller's explicit "use the file as it is now" and proceeds (documented). Read-modify-write category/upgrade entries SHALL also pin their own read fingerprint and compare again under writer serialization immediately before replacement. `--dry-run` SHALL
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
  `TEAM_TASK_MODELS='routine'` (no `=`) are set
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

Every `team config set`, `set-task-model` or `upgrade-models` attempt that passes argument parsing SHALL append exactly one line to
`<state>/config.log`: a UTC ISO-8601 timestamp, the result (`ok`, `refused`, `invalid`, `conflict`,
`danger-refused`, `write-error`), the actor (`--actor`, default `cli`; the console passes `panel`), the key (or upgrade transaction with all changed keys), the
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

### Requirement: The machine read reports each key's choice set, and the schema is its only source

`team config list --json` SHALL report, for every key record (a key the file carries but the schema does not
included), a `choices` field derived from the same `team_config_schema()` row the validator reads:
`{source, values[], min, max, empty, note}`.

- `source` SHALL be `schema` when the vocabulary comes from the row itself (`bool`'s two canonical values, an
  `enum`'s `constraints`, a numeric kind's suggestion column), `known` when it is this project's model vocabulary
  (the `models` block's `known`, for the `model`, `task-model-map`, `winlist` and `pattern` kinds), and `none` when the
  kind has no vocabulary.
- `values[]` SHALL be the ordered vocabulary: for `bool`/`enum` the key's **closed** accepted domain, for the
  other kinds the offered vocabulary (free text stays valid), and `[]` when there is none.
- `min`/`max` SHALL carry the numeric kinds' accepted bounds as strings (`''` = unbounded) and be empty for other
  kinds, so a reader can name the accepted interval without re-parsing the schema.
- `empty` SHALL be true exactly when the writer accepts the empty value for this key (a `path`/`model` spec ending
  in `,opt`, or a kind that accepts `''`).
- `note` SHALL be the command's optional explanation and empty when there is nothing to say.

The field SHALL be derived from the row the validator uses — the command MUST NOT carry a second option table —
and every value the read reports (a `values` entry or a suggestion-column entry) SHALL be accepted by the corresponding value or token route. For structured `task-model-map`, `winlist` and `pattern` kinds, choices are model-token vocabulary, not complete pairlist values: the fixture SHALL validate category choices through `set-task-model` and window/limit tokens after inserting a valid `=number`, not send a naked model to the whole-map validator. A schema row whose offered value its corresponding validator refuses SHALL fail the project's fixture gate rather than be filtered silently. Retired seat/default fields are removed by the task-policy contract; apart from that explicit supersession the field is additive: `team config list`'s human table, every existing
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
  and a project contract naming one PM model plus one category model
- **WHEN** `team config list --json` runs with that `HOME`
- **THEN** `models.known` and every `model`/`task-model-map`/`winlist`/`pattern` key's `choices.values` carry only the
  project's configured and recorded models, and no catalogue-only provider appears in either
- **AND** the command's read of the contract is otherwise unchanged (same fingerprint, same records)

#### Scenario: The field is additive and nothing else moves

- **GIVEN** a fixture project and two contracts whose values differ
- **WHEN** `team config list`, `team config list --json`, `team monitor --print` and `team monitor --json` run
  under each
- **THEN** the human table keeps its `KEY CLASS KIND VALUE` header and carries no choices column, the `--json`
  record keeps every existing field name and type next to the new `choices`, and neither machine exit carries a
  `choices` field

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
- The read is the only carrier: the human `team config list` table SHALL keep its columns, existing JSON key-record metadata SHALL keep its names/types, and no machine exit other than `team config list --json` SHALL carry the group field. This does not freeze the retired model-policy object or model/SID-linked values: their specified routing/assignment replacement applies; unrelated machine fields and behavior remain unchanged.

#### Scenario: The group is the row's tenth column, per section

- **GIVEN** a fixture project initialised from this tree
- **WHEN** `team config list --json` runs
- **THEN** `TEAM_PROJECT` reports `group` `identity`, `TEAM_PULSE_INTERVAL` reports `panel`, `TEAM_TASK_MODELS`
  reports `task-model` and `TEAM_GATES` reports `workflow`, and the records' `group` values are exactly the tokens
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
one parseable JSON document for every contract shape the correctness gate exercises, including an unassigned seat with empty model/source/SID fields and a legacy configuration diagnostic. A field MUST NOT be serialized with no value (`"name":`); a string field with
nothing to report SHALL be the JSON string `""`; a boolean field SHALL be `true` or `false`; and `null` SHALL NOT
stand for "empty". The correctness gate SHALL run those exits against a fixture carrying the empty-assignment shape
and parse each output with the JSON parser its config fixtures already require (`python3 -m json.tool`), and a
document that does not parse MUST fail the gate naming the command and the parser's reported position.

#### Scenario: The empty-override shape parses on every machine exit

- **GIVEN** a fixture contract with valid task mapping and no worker assignment
- **WHEN** `team config list --json`, `team change status <id> --json`, `team paths` and, with a JS runtime
  present, `team monitor --json` run
- **THEN** each exits 0 and `python3 -m json.tool` parses its output; with no JS runtime the console exit is a
  visible SKIP and not a red

#### Scenario: A valueless field is a gate failure

- **GIVEN** a scratch tree whose `team config list --json` emits a valueless field for a seat (`"model":,`)
- **WHEN** the gate's parse walk runs against that tree
- **THEN** it exits non-zero naming the command and the parser's error position, and restoring the tree's own
  serializer makes it green — the gate, not a silent tolerance, keeps the exits valid

### Requirement: A model id is a single-segment provider plus a model that may contain `/`

Every supported route that accepts a model id SHALL judge one shape through one implementation: the required `TEAM_PM_MODEL`, the whole `TEAM_TASK_MODELS` mapping, `team config set-task-model`, `team config upgrade-models`, and dispatch's explicit `--model`. Retired seat/default routes do not write models.

The shape SHALL be: the token contains at least one `/`; the text before the first `/` (the provider) is
non-empty and carries no `:` (it carries no `/` by construction); the text after the first `/` (the model),
after removing an optional thinking suffix (the first `:` of that text and everything after it), is non-empty
and every one of its `/`-separated segments is non-empty; and the token carries no whitespace (space, tab or
newline). The suffix is removed **before** the model is judged, its vocabulary is not validated (the thinking
levels belong to Pi, not to this contract), and the token is written and read back verbatim with it:
`provider/model`, `provider/model:high`, `provider/vendor/model` and `provider/vendor/model:high` are all
accepted. A `:` before the first `/` is refused — the suffix attaches to the model segment only.

A refused token SHALL exit 4 (the invalid-value exit code; dispatch's `--model` refuses it with the same
code before any write) and the message SHALL name the rejected segment — `provider` or `model` — and the
reason (a missing `/`, an empty segment, whitespace), never the removed "exactly one `/`" wording. Nothing
SHALL be written and the contract's bytes SHALL be unchanged.

A token the shape accepts SHALL be read back verbatim by `team config list --json` (`models.policy`,
`models.known`, the assignment rows) and by `team ps`/`team roster`. Every reader that splits a token into a provider
and a model part SHALL take the provider as the text before the first `/` and the model as everything after it:
the worker launch renderer's `--provider`/`--model` pair, the PM launch renderer's pair, the `{model}` launch
template placeholder, and Pi-catalogue window resolution.

#### Scenario: A three-segment model is accepted by every write route

- **WHEN** `openrouter/amazon/nova-lite-v1` is submitted through PM set, category set, whole mapping set and explicit upgrade
- **THEN** each exits 0 on a valid fixture and reads back the whole id; dispatch override also renders that full model

#### Scenario: The thinking suffix is removed before the shape judgement and kept in the value

- **WHEN** PM and category models are set to `kimi-coding/kimi-for-coding:high` and `openrouter/amazon/nova-lite-v1:high`
- **THEN** writes and readback retain `:high` verbatim; the suffix vocabulary is not judged

#### Scenario: The shape stays closed, and the message names the rejected segment

- **WHEN** `a`, `/a`, `a/`, `a//b`, `a/b/`, `a/:high`, `a:q/b` and a whitespace-bearing id are tried through PM/category/whole-map/upgrade/dispatch override routes
- **THEN** every value attempt exits 4 naming provider or model and the reason; no contract or assignment changes and no ok audit appears

#### Scenario: One judgement, not one copy per write route

- **GIVEN** a scratch tree whose shared shape validator is widened to accept any token containing `/`
- **WHEN** `TEAM_CONFIG_TREE=<scratch> bash skills/teamsmith/tests/config-cli.sh shape` runs
- **THEN** it exits non-zero naming `a//b` on PM, category, whole-map and upgrade routes; restoring the shared validator makes it green

#### Scenario: The launch renderers split at the first `/`, not the last

- **GIVEN** a fixture contract whose routine mapping and PM model are `openrouter/amazon/nova-lite-v1`
- **WHEN** `team dispatch dev <id> <brief> --print` and `team up --print` run, and the `{model}` placeholder is
  expanded for a launch template
- **THEN** the rendered worker and PM commands carry `--provider openrouter --model amazon/nova-lite-v1`, and
  the placeholder reads `amazon/nova-lite-v1` — the last-segment extraction (`nova-lite-v1`) is the red side

#### Scenario: A multi-segment model's window resolves from both sources

- **GIVEN** a fixture `HOME` whose `models.json` lists provider `openrouter` with the model id
  `stealth/union-alpha` and `contextWindow` `131072`, and a contract whose routine category model is
  `openrouter/stealth/union-alpha`, with a complete current worker assignment to that same model
- **WHEN** `team ps` runs with `TEAM_MODEL_WINDOWS` empty
- **THEN** the WINDOW row for that model reads `131k`, not `?`
- **AND** with `TEAM_MODEL_WINDOWS='openrouter/stealth/union-alpha=300000'` the same row reads `300k` — the
  explicit override's syntax and matching are unchanged

#### Scenario: The read surfaces and the seat picker carry the whole id

- **GIVEN** policy models `openrouter/amazon/nova-lite-v1` and `openrouter/stealth/union-alpha`
- **WHEN** JSON and the replacement category picker are read and the second id chosen
- **THEN** known/choices and the picker retain both complete ids; the write uses `set-task-model` and reads back the whole id, never a seat override


## REMOVED Requirements

### Requirement: A seat's model is read and written as a seat, never by composing the pair list in the caller

**Reason**: Seat/default policy is retired; task category policy and persisted assignments replace it.

**Migration**: Explicitly upgrade the model keys with `team config upgrade-models`; edit categories through `team config set-task-model` and PM through `team config set TEAM_PM_MODEL`. No seat override or worker fallback remains.

## ADDED Requirements

### Requirement: Project task-model policy replaces seat and worker-default routing

The sole policy file remains `.pi/team/config.sh`. `TEAM_TASK_MODELS` SHALL be a nonempty single-line whitespace-separated mapping of unique lowercase category tokens `[a-z][a-z0-9-]*` to nonempty valid complete provider/model ids. A token has exactly one `=`; duplicate categories, empty values, malformed category/model, linebreaks or non-representable writer values refuse with exit 4. Initial routine/analysis/verify are examples, not mandatory engine categories. `TEAM_PM_MODEL` SHALL be an explicit nonempty valid model and SHALL NOT fall back to any worker value. Retired `TEAM_DEFAULT_MODEL`/`TEAM_AGENT_MODELS` assignments, even empty or mixed with new keys, and retired environment variables SHALL never supply routing semantics. Model-dependent operations (dispatch/resume/up, real init/bootstrap before their effects) refuse legacy/incomplete policy before effects and show exact file/key plus upgrade or unset routes. `--force` is not a routing migration.

Loading config SHALL keep paths, help, doctor, config list/log/set/upgrade usable under retired or invalid model keys. Supported key repairs use the canonical writer without activating legacy routing. `config set` for retired keys exits 5; `set-agent-model` is removed and refuses with replacement routes without writing. `models.default`/editable seat overrides and seat-model group retire; task map is kind `task-model-map`, group `task-model`, class apply (next new task), required PM is model kind in the same group with class restart (new PM startup subject to fresh guard). Limits/windows remain independent. Diagnostics SHALL name migration_required, retired keys, missing/invalid keys and never present invalid policy as runnable.

#### Scenario: Legacy and mixed policy refuse but repair commands remain reachable
- **WHEN** an old-only, empty-retired, mixed-new/old, invalid-map or empty-PM configuration is used
- **THEN** launch/bootstrap refuse before prompt/install/ledger/window effects; doctor and list explain all issues, paths/log/help still work, and new-key set or explicit upgrade can repair it

#### Scenario: Category map has one domain rule
- **WHEN** maintenance=vendor/model is set, then duplicate categories, UpperCase, routine=, routine, extra equals, missing provider/model and newline maps are submitted
- **THEN** maintenance is accepted; invalid values exit 4 without contract changes; list warnings and write refusals name the same violations

#### Scenario: Old routes cannot recreate seat policy
- **WHEN** config set targets either retired key or set-agent-model is invoked
- **THEN** they refuse without contract/state changes, name set-task-model/PM-set/upgrade routes, and help advertises no writable seat override

#### Scenario: PM is independent from task policy
- **WHEN** worker category mapping changes with a valid PM key and PM preview is rendered
- **THEN** PM model stays unchanged; empty PM refuses rather than selecting any category or retired default

### Requirement: Category editing and explicit upgrade share the one checked writer

`team config set-task-model <category> <model>` SHALL update or add exactly that category token in the whole mapping through the canonical writer, pinning the read fingerprint and retaining other tokens in order. Whole-map `config set TEAM_TASK_MODELS` uses the same validation. `-`/empty models are invalid, not deletion/fallback. Removing a category is an explicit whole-map edit with resulting nonempty valid mapping; complete assignments, including stopped tasks' recoverable category/model/SID/provenance, are not changed or invalidated by policy edits. New selections must use a currently mapped category, while complete unchanged same-task recovery follows its committed identity under an otherwise valid overall routing configuration. PM uses `config set TEAM_PM_MODEL`. These routes inherit dry-run, quoting, CAS, actor/audit and exit codes (0 success, 3 conflict, 4 invalid, 5 refused, 6 write-error, 7 danger-refused; usage 2).

`team config upgrade-models --task-models '<complete map>' --pm-model '<model>' [--dry-run] [--fingerprint <sha256>] [--actor <actor>] --yes` SHALL explicitly preview all removed/changed keys, never infer mapping or PM from retired values. It SHALL replace both model policy fields and remove retired direct assignments in a single serialized CAS/temporary-file/bash-n/atomic-rename transaction, preserving mode, unrelated bytes and inline comments of surviving fields. Retired inline comments SHALL remain standalone at the same location; new missing fields append on their own lines. It SHALL refuse ambiguous relevant source assignments (duplicates, multiline/dynamic/export/conditional/indirect constructs) with line/path and actionable manual normalization; it is not a general bash parser. No config/assignment/ledger/install/process effect occurs on dry-run, failure or cancellation except the prescribed single real-attempt refusal audit. Every real transaction has exactly one audit line covering all changed keys and before/after fingerprints; an audit failure warns without lying about the actual config replacement. Same-directory temporary files are cleaned on normal failure; abandoned temporary files are never loaded as config. No upgrade clears historical assignments or session files.

#### Scenario: One category write changes only its token
- **WHEN** routine is updated through set-task-model and maintenance is added
- **THEN** other tokens/order/comments remain, values are writer-quoted, each real write has one ok audit; dry-run/cancel has none and an invalid '-' leaves bytes intact

#### Scenario: Explicit upgrade preserves unrelated bytes and has no partial result
- **GIVEN** old direct assignments and unrelated roster/limits/comments/ledger
- **WHEN** explicit upgrade is previewed then authorized
- **THEN** preview writes nothing; real result has only new policy and retained standalone old comments, one transaction audit, valid bash syntax, unchanged roster/limits/governance/history and no process/installation calls

#### Scenario: Stale fingerprint and failure injection protect the whole file
- **WHEN** a comment changes after read, or second-field rendering/bash-n/rename fails during upgrade
- **THEN** conflict is exit 3 or write error exit 6, original/current-other-writer bytes remain, no half-new policy appears, temp cleanup and one honest audit result are visible

#### Scenario: Ambiguous source is refused with a usable correction
- **WHEN** relevant keys are duplicate, multiline, dynamically derived, exported or conditionally assigned
- **THEN** upgrade refuses before replacement naming the lines and direct-literal normalization; after that explicit manual correction the identical upgrade command succeeds without inferring values

#### Scenario: Quoting and concurrent readers do not execute or observe partial policy
- **WHEN** hostile shell text is passed as a model value and concurrent writers/readers exercise valid upgrades
- **THEN** invalid models refuse without executing text, every observed config parses and is wholly old or new, and current-file CAS prevents a lost update

### Requirement: Machine reads separate future policy from committed assignments

`config list --json` SHALL expose `models.policy` with ordered categories `{category,model}` and independent PM model, `models.assignments` with one roster row (assigned boolean plus task/category/model/selected_via/launch_via/SID when complete), PM selected launch identity separately, and `models.known` as ordered deduplicated project policy plus committed selected models. Unassigned/malformed rows use assigned false, empty string fields and a diagnostic, never guessed seat defaults or null/valueless fields. Original selection provenance is not re-labelled by current policy equality. A valid complete unchanged assignment remains assigned even when its recorded category was removed from the valid future mapping; no invalid-brief or fresh-required diagnostic may be invented solely from that deletion. Schema/model choices use only this project data, no machine provider catalogue. `ps`, `roster`, status and panel SHALL display last selected assignment and original/current launch source separately from next-new-task policy; records never prove later Pi-internal model changes. Read surfaces SHALL not mutate assignment/config/timestamps.

#### Scenario: Policy edit does not rewrite current provenance
- **GIVEN** an explicitly launched routine assignment and a later mapping edit
- **WHEN** config JSON, ps, roster and panel are read
- **THEN** policy shows the new mapping but assignment retains its original full model, explicit origin and assignment recovery source; no file changes

#### Scenario: Removed future category remains a complete actual assignment
- **GIVEN** an explicit routine assignment with full model/SID A and unchanged identity, then valid policy containing only analysis/verify
- **WHEN** config JSON, ps, roster and panel are read
- **THEN** policy omits routine, assignment retains assigned true plus routine/full model/SID A and original provenance, known models retains the committed model, and the displays distinguish absent future policy from intact recovery without changing files

#### Scenario: Empty and legacy records remain valid JSON without fictitious defaults
- **WHEN** reads run with missing, legacy and malformed assignments and migration-required config
- **THEN** every machine exit parses; missing actual model/category/SID are empty strings and assigned false with diagnosis, no writable worker-seat model appears

#### Scenario: Known models are only project-owned model data
- **GIVEN** fixture HOME with extra catalogue-only models
- **WHEN** policy, records and choice vocabulary are read
- **THEN** known/choices contain only configured and committed models once, including PM and complete suffix/multi-slash ids, never a source label or catalogue-only entry
