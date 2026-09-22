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

#### Scenario: An empty model is still a value

- **GIVEN** a contract whose `TEAM_DEFAULT_MODEL` is empty and whose `TEAM_AGENT_MODELS` carries `dev=`
- **WHEN** `team config list --json` runs
- **THEN** the `dev` row exists with `"model":""` and `"override":true`, and the document parses as JSON

## ADDED Requirements

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
