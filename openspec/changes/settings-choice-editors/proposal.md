## Why

`team_config_schema()` already types every project setting — measured on this tree, 108 keys: `bool` 22, `path` 18,
`text` 17, `int` 13, `seconds` 11, `cmd` 5, `mb` 5, `bytes` 4, `tpl` 3, `enum` 3, `model` 2, and
`list`/`pattern`/`winlist`/`pairlist`/`pct` one each — but the console opens the **same blank text box** for every
editable key and then runs `team config set <KEY> <VALUE>`. The human must know that `TEAM_NOTIFY_TMUX` wants
`1`/`0`, that `TEAM_MONITOR_UI` accepts exactly `auto,tui,text`, and which models this project uses. The command
knows and shows none of it: `team config list --json` reports `kind` but no choice set and not even `constraints`
(`cmd-config.sh:489–524`).

The machine's Pi model catalogue is not a safe substitute: it carried `sub2api` (`http://<internal>/v1`, a
refused endpoint; removed from `models.json` on 2026-09-21, surviving only in `models.json.bak-20260921-031641`).
Offering a dead endpoint as a "choice" digs the user a pit.

## What Changes

- **ADDED — `memory-and-deps`**: `team config list --json` reports a `choices` object per key
  (`{source, values, min, max, empty, note}`), derived from the same schema row the validator uses; the schema gains
  an optional `suggest` column for numeric kinds; `models.known` gains the `pm` seat's resolved model. A
  consistency fixture proves every option/suggestion the read reports is a value its key's validator accepts.
- **ADDED — `panel`**: a choice editor wherever the schema defines choices — `bool` (two canonical values,
  labelled, default marked), `enum` (exactly the `constraints`, rendered verbatim so a new value needs no rebuild),
  `model` (this project's known models only), numeric kinds (suggested values plus the visible accepted interval
  plus free text), `path` (current/default/clear plus an existence mark), `winlist`/`pattern` (a model palette
  seeding the token), `pairlist` (routes to the seats block, never hand-composed). No choice set means a visible
  free-text fallback naming the reason; an unset key shows `未设 → 默认 X` and an explicit keep-unset entry, never
  an empty box.
- **MODIFIED — `panel`**: the write requirement keeps its two-step confirmation, CAS fingerprint, audit and
  `team config set` writer; only the editor feeding it is chosen by the schema's choice set.
- **MODIFIED — `memory-and-deps`**: `models.known` is every seat's displayed model, the `pm` seat included.

## Capabilities

### Modified Capabilities

- `memory-and-deps`: the machine read exposes the schema's choice set; the known-model set is the project's.
- `panel`: the row editor is a choice editor where the schema defines choices and a visibly degraded free-input
  editor where it does not.

## Impact

`scripts/lib/cmd-config.sh` (optional 9th schema column, `--json` field); `scripts/panel/src/{types,data,App,layout}.ts(x)`
and `strings/{zh,en}.ts` plus the rebuilt `panel.js`; `tests/config-cli.sh`, `panel-p21.sh` and one flip script;
`references/config.md`. Untouched: writer validation, CAS, audit and danger list; `team config list`'s human table;
`team monitor --print/--json`; `refuse` keys; seat-model semantics.

## Acceptance

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
git status --porcelain
```

## What flips

Adding an `enum` key to the schema makes the unchanged committed bundle offer its values; removing that key's
`constraints` makes the same bundle visibly fall back to free text. Dropping the `choices` field, hardcoding an
option list in the bundle, leaking the Pi model catalogue, or shipping a suggestion its validator refuses each
makes its named fixture red.

## Boundaries

Planning only: this task writes `openspec/changes/settings-choice-editors/**` and its report. Apply must not touch
the writer's accept/reject semantics or the danger list, must not add an unset operation, must not read the machine's
Pi model catalogue, and must not change `team config list`'s human output or any machine exit except the additive
`--json` field. Implementation paths (`scripts/**`, `panel/**`, `tests/**`, `references/**`) need the apply brief's
explicit grant (OWNERSHIP).

## Evidence the report must contain

Baseline and post-change `openspec validate --all --strict` tails; the fast-smoke tail; the delta-to-requirement
map for both capabilities; requirement-to-item and scenario-to-fixture maps; the recon commands with outputs
(`team config list --json` field list, kind/class counters, the `sub2api` entry without its credential).
