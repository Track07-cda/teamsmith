## MODIFIED Requirements

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
a contract: the identity keys' note SHALL name editing `.pi/team/config.sh` directly, and when it names `team init` it
SHALL name `team init --force` together with its cost (`--force` re-renders the whole file and overwrites every
other key with the template's value), because a bare `team init` prints `skip` and leaves the contract
byte-identical. The schema's free-text column is the note the console renders under the row, so its prose SHALL
be written for the reader who sees it there: plain user-facing words, no private shorthand and no internal
record ids; whether a phrase is plain enough is judged by design and review, not by a gate (D170). A key that
exists only to drive fixtures and the test suite SHALL carry the declared marker `fixture-only: ` at the start of
that note. The marker is data: `team config list --json` reports the note verbatim, the key keeps its `class`,
`kind`, `default` and its record in the read, the human `team config list` table and the writer (validation,
quoting, CAS, audit, danger and refusal rules) do not change, and the console hides such a row (`panel` owns the
hiding rule).

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
- **THEN** the notes name editing `.pi/team/config.sh` directly in plain words, and the `team init` they name
  (if any) is `team init --force` with its re-render cost stated
- **AND** a hand edit of `TEAM_PROJECT` changes what `team paths` prints, a bare `team init` re-run leaves the
  contract's sha256 unchanged (the measured pre-change note promised exactly this no-op as a route), and
  `team init --force` does change it by restoring the template's `TEAM_GATES` value — the cost the note names

#### Scenario: The fixture marker is data, and the key stays a contract key

- **GIVEN** a fixture project whose contract and schema carry the fixture-only keys
- **WHEN** `team config list --json`, `team config list` and `team config set <key> <value> --yes` run
- **THEN** each key's record still carries its `name`, `class`, `kind`, `default` and a `route` whose text begins
  with the `fixture-only: ` marker, the human table still lists every one of them, and the write still refuses
  with exit 5 and the same note as its reason
- **AND** a scratch tree whose fixture row lost the marker makes the console render that key's row again (the
  `panel` fixture's cross-check) while the read, the human table and the writer are unchanged by the flip

### Requirement: The worker-launch keys are an internal frozen seam, not a supported extension point

The four worker-launch keys (`TEAM_AGENT_CMD`, `TEAM_AGENT_NOTIFY_CMD`, `TEAM_AGENT_LOG_GLOB`,
`TEAM_AGENT_BIN`) SHALL stay in the schema with class `apply` and keep every behaviour they have today. The
schema row and `references/config.md` SHALL describe them as an **internal seam (frozen)** — reserved for a
possible future non-Pi adapter, **no compatibility promise**, and not asked in the new-project questionnaire.
The marking SHALL live in the schema row's free-text column so `team config list --json` reports it verbatim
on each of the four records (the console shows it under the row, the same place a `refuse` key's route is
shown), and the schema's own header comment SHALL document the free-text column as the same route/note field
for `apply` keys. Because that note is what the console renders to a user, it SHALL say the same thing in plain
words — these four keys are reserved for a possible future non-Pi adapter, they are not a supported extension
point and carry no compatibility promise, and a new project is not asked about them — without the shorthand
`内部接缝` / `seam` / `frozen` the requirement's own name uses; `references/config.md` may keep the seam name
(it is not the console's surface). The human table (`KEY CLASS KIND VALUE`), the writer's validation, quoting, CAS, audit and
danger rules, the four keys' validated domains and the value of the keys' `class` SHALL be unchanged; the
questionnaire's silence is the `init-skill` capability's promise, this requirement owns the schema and
documentation marking.

#### Scenario: The marking reaches the machine read, and the walk makes it falsifiable

- **GIVEN** a fixture project initialised from this tree
- **WHEN** `team config list --json` runs
- **THEN** each of the four records reports `"class":"apply"`, its existing `kind`/`form`/`default` fields
  unchanged, and a `"route"` that says, in plain user-facing words, that the key is reserved for a possible
  future non-Pi adapter and carries no compatibility promise (the wording itself is judged by design and review),
  while `team config list`'s human header is still `KEY CLASS KIND VALUE`
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

### Requirement: Machine reads separate future policy from committed assignments

`config list --json` SHALL expose `models.policy` with ordered categories `{category,model}` and independent PM model, `models.assignments` with one roster row (assigned boolean plus task/category/model/selected_via/launch_via/SID when complete), PM selected launch identity separately, and `models.known` as ordered deduplicated project policy plus committed selected models. Unassigned/malformed rows use assigned false, empty string fields and a diagnostic, never guessed seat defaults or null/valueless fields; each row also carries `record_present`, a boolean that answers the one question a reader cannot get from the diagnostic string — **does a record file exist for this seat at all** (true when the seat's state record exists, even if it is unreadable or carries no assignment field, false when there is none) — so a display can say plainly whether the seat was never dispatched or its record could not be read, without parsing the diagnostic. Original selection provenance is not re-labelled by current policy equality. A valid complete unchanged assignment remains assigned even when its recorded category was removed from the valid future mapping; no invalid-brief or fresh-required diagnostic may be invented solely from that deletion. Schema/model choices use only this project data, no machine provider catalogue. `ps`, `roster`, status and panel SHALL display last selected assignment and original/current launch source separately from next-new-task policy; records never prove later Pi-internal model changes. Read surfaces SHALL not mutate assignment/config/timestamps.

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
- **AND** the missing-record row reports `record_present` false while a row whose record exists but cannot be read (legacy version, unreadable bytes, foreign content) reports true — the two are told apart without inspecting the diagnostic text

#### Scenario: Known models are only project-owned model data
- **GIVEN** fixture HOME with extra catalogue-only models
- **WHEN** policy, records and choice vocabulary are read
- **THEN** known/choices contain only configured and committed models once, including PM and complete suffix/multi-slash ids, never a source label or catalogue-only entry
