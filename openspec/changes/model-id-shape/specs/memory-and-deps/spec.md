## ADDED Requirements

### Requirement: A model id is a single-segment provider plus a model that may contain `/`

Every route that writes a model id SHALL judge one shape through one implementation: `team config set` for a
`model`-kind key (`TEAM_DEFAULT_MODEL`, `TEAM_PM_MODEL`), the pair list of `TEAM_AGENT_MODELS` (its whole-value
validator and `team config set-agent-model <seat> <model|->`), and `team add-agent <agent> --model <model>`.

The shape SHALL be: the token contains at least one `/`; the text before the first `/` (the provider) is
non-empty and carries no `:` (it carries no `/` by construction); the text after the first `/` (the model),
after removing an optional thinking suffix (the first `:` of that text and everything after it), is non-empty
and every one of its `/`-separated segments is non-empty; and the token carries no whitespace (space, tab or
newline). The suffix is removed **before** the model is judged, its vocabulary is not validated (the thinking
levels belong to Pi, not to this contract), and the token is written and read back verbatim with it:
`provider/model`, `provider/model:high`, `provider/vendor/model` and `provider/vendor/model:high` are all
accepted. A `:` before the first `/` is refused — the suffix attaches to the model segment only.

A refused token SHALL exit 4 (the invalid-value exit code; `team add-agent --model` refuses it with the same
code before any write) and the message SHALL name the rejected segment — `provider` or `model` — and the
reason (a missing `/`, an empty segment, whitespace), never the removed "exactly one `/`" wording. Nothing
SHALL be written and the contract's bytes SHALL be unchanged.

A token the shape accepts SHALL be read back verbatim by `team config list --json` (`models.default`,
`models.known`, the seat rows) and by `team ps`/`team roster`. Every reader that splits a token into a provider
and a model part SHALL take the provider as the text before the first `/` and the model as everything after it:
the worker launch renderer's `--provider`/`--model` pair, the PM launch renderer's pair, the `{model}` launch
template placeholder, and Pi-catalogue window resolution.

#### Scenario: A three-segment model is accepted by every write route

- **GIVEN** a fixture contract whose sha256 is recorded
- **WHEN** `team config set TEAM_DEFAULT_MODEL openrouter/amazon/nova-lite-v1 --yes`, `team config
  set-agent-model dev openrouter/amazon/nova-lite-v1 --yes`, `team config set TEAM_AGENT_MODELS
  'dev=openrouter/amazon/nova-lite-v1' --yes` and `team add-agent api --register --model
  openrouter/amazon/nova-lite-v1 --no-install` run
- **THEN** each exits 0, each written line carries the token verbatim, and `team config list --json` reports the
  id in `models.known` and in the `dev` seat row

#### Scenario: The thinking suffix is removed before the shape judgement and kept in the value

- **GIVEN** a fixture contract
- **WHEN** `team config set TEAM_DEFAULT_MODEL kimi-coding/kimi-for-coding:high --yes` and `team config
  set-agent-model dev openrouter/amazon/nova-lite-v1:high --yes` run
- **THEN** both exit 0 and each written line carries the token verbatim, `:high` included

#### Scenario: The shape stays closed, and the message names the rejected segment

- **GIVEN** a fixture contract whose sha256 is recorded and whose audit log is recorded
- **WHEN** `a`, `/a`, `a/`, `a//b`, `a/b/`, `a/:high`, `a:q/b` and a value carrying a space are each written
  through `team config set TEAM_DEFAULT_MODEL ... --yes`, and `/a`, `a/` and `a//b` through `team config
  set-agent-model dev ... --yes`
- **THEN** every attempt exits 4, the message names `provider` for the provider faults and `model` for the
  model faults, the contract's sha256 is unchanged and the audit log gained no `result=ok` line

#### Scenario: One judgement, not one copy per write route

- **GIVEN** a scratch tree whose single model-shape judgement is widened to accept any token containing `/`
- **WHEN** `TEAM_CONFIG_TREE=<scratch> bash skills/teamsmith/tests/config-cli.sh shape` runs
- **THEN** it exits non-zero and its red lines name `a//b` on the model-kind, pairlist and `set-agent-model`
  routes, and on the unmodified tree the same command is green

#### Scenario: The launch renderers split at the first `/`, not the last

- **GIVEN** a fixture contract whose default model is `openrouter/amazon/nova-lite-v1`
- **WHEN** `team dispatch dev <id> <brief> --print` and `team up --print` run, and the `{model}` placeholder is
  expanded for a launch template
- **THEN** the rendered worker and PM commands carry `--provider openrouter --model amazon/nova-lite-v1`, and
  the placeholder reads `amazon/nova-lite-v1` — the last-segment extraction (`nova-lite-v1`) is the red side

#### Scenario: A multi-segment model's window resolves from both sources

- **GIVEN** a fixture `HOME` whose `models.json` lists provider `openrouter` with the model id
  `stealth/union-alpha` and `contextWindow` `131072`, and a contract whose `TEAM_DEFAULT_MODEL` is
  `openrouter/stealth/union-alpha`
- **WHEN** `team ps` runs with `TEAM_MODEL_WINDOWS` empty
- **THEN** the WINDOW row for that model reads `131k`, not `?`
- **AND** with `TEAM_MODEL_WINDOWS='openrouter/stealth/union-alpha=300000'` the same row reads `300k` — the
  explicit override's syntax and matching are unchanged

#### Scenario: The read surfaces and the seat picker carry the whole id

- **GIVEN** a contract whose default model is `openrouter/amazon/nova-lite-v1` and whose `TEAM_AGENT_MODELS`
  carries `dev=openrouter/stealth/union-alpha`
- **WHEN** `team config list --json` runs and the panel fixture opens the seat picker for `dev`
- **THEN** `models.known` and the `TEAM_DEFAULT_MODEL`/`TEAM_AGENT_MODELS` `choices.values` carry both ids
  verbatim, the picker lists `openrouter/stealth/union-alpha`, and choosing it writes
  `dev=openrouter/stealth/union-alpha` through `team config set-agent-model` (the receipt names the seat and
  the contract line carries the full id)
