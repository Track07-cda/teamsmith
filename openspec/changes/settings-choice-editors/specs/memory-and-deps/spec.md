## ADDED Requirements

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

## MODIFIED Requirements

### Requirement: A seat's model is read and written as a seat, never by composing the pair list in the caller

`team config list --json` SHALL report a `models` block — `{default, known[], seats: [{agent, model, source,
override}]}` — where `seats` covers every roster seat (`TEAM_AGENTS`) plus `pm`, `model` is the model the CLI
displays for that seat, `source` is one of `config` / `explicit` / `record` with exactly the semantics of
`team_agent_model_src` (`common.sh`: no record → `config`; the record's `model_src=explicit` → `explicit`; a record
differing from the seat's configuration resolution → `record`), and `override` says whether the seat carries a
token in `TEAM_AGENT_MODELS` (for `pm`: whether `TEAM_PM_MODEL` is set). `known[]` SHALL be the union of the configured
and the recorded models — every seat's displayed model, the `pm` seat's resolution (`TEAM_PM_MODEL` when set, else
`TEAM_DEFAULT_MODEL`) included — deduplicated in
first-seen order; the same set is the vocabulary `choices.values` reports for a `model`-kind key. `team config set-agent-model <seat> <model|->` SHALL write the pair list (or
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

#### Scenario: The known set carries the PM seat's model

- **GIVEN** a fixture contract whose `TEAM_AGENT_MODELS` does not name the PM's model and whose `TEAM_PM_MODEL` is
  `kimi-coding/k3-256k`, plus a roster seat whose `state/<seat>.env` records a model differing from its
  configuration resolution
- **WHEN** `team config list --json` runs
- **THEN** `models.known` carries `kimi-coding/k3-256k` exactly once, `models.seats`' `pm` row shows it with
  `override` true, and `TEAM_PM_MODEL`'s `choices.values` contains it
- **AND** with `TEAM_PM_MODEL` removed the `pm` row falls back to the default while the roster seat's recorded
  model stays in `known`, each model appearing once
