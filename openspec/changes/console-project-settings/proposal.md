# Propose: `console-project-settings` — edit the project contract (`.pi/team/config.sh`) from the console

## Why

The console is where the PM and the human watch the project, but its 47 keys (58 in the template) can only be
changed by hand, and the console's overlay edits `state/panel.conf`, which the `panel` spec keeps free of
`TEAM_*` meanings. The one existing writer, `team_config_set_in_file`, is measurably unsafe (the report has the
transcript): it drops the rewritten line's comment, joins the last line on a newline-less file, writes a contract
that fails `bash -n`, changes the meaning of a value containing `"`, and double-quotes values so
`'$(touch PWNED)'` executes when the contract is sourced.

## What Changes

- **ADDED** (`panel`) — the project-settings view: from the settings overlay it lists every key the contract can
  carry with its effect class (apply-now / needs-restart / read-only) and value, filters, edits a value through
  the compose line's editor, and writes only through `team config set`.
- **MODIFIED** (`panel`) — the settings overlay gains one navigation row; `state/panel.conf` still carries no
  `TEAM_*` meaning.
- **REMOVED + ADDED** (`panel`) — "…except through **three** commands" is superseded by "…through **its owning
  commands**", enumerating four exceptions (a rename is remove-plus-add; a count-free title stops the churn).
- **ADDED** (`memory-and-deps`) — one validated writer, `team config list|set|log`: a `sha256` fingerprint
  compare-and-swap, a writer-derived single-quote form (so a sourced value is data), a per-key kind/range/enum
  validator with a danger list, an atomic `bash -n`-verified write, and one audit line per attempt in
  `state/config.log`.
- **ADDED** (`panel` + `memory-and-deps`) — the **model seats**: a per-seat block with the CLI's own source
  tri-state (`配置` / `显式` / `历史记录`) and a picker writing through `team config set-agent-model <seat>
  <model|->`. The three model keys are `needs-restart` (a running seat keeps its model until its next
  `dispatch`/`resume`), and the console restarts no seat — it prints the route.
## Capabilities

### Modified Capabilities

- `panel`: the settings overlay, the project-settings view, the seat-model block, the read-only exceptions.
- `memory-and-deps`: the write contract of `.pi/team/config.sh` (writer, CAS, validation, audit, seat write).

## Impact

`scripts/lib/cmd-config.sh` (new) plus `team`, `cmd-bootstrap.sh`, `cmd-watch.sh`, the panel sources and the
committed `panel.js`, `references/config.md`, `SKILL.md`, the template and the tests. No new `TEAM_*` key,
dependency, or change to dispatch, the gate or the `--print`/`--json` bytes.

## Acceptance (verbatim)

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
PATH="$HOME/.bun/bin:$PATH" openspec show console-project-settings --json | head -40
```

## Boundaries

- This phase writes only `openspec/changes/console-project-settings/**` and `docs/team/reports/P21-dev-bob.md`.
- Out of scope: renaming or redefining a `TEAM_*` key, a second config source, a settings UI outside the
  console, an in-panel "restart the pulse" or "restart a seat" action, key-line deletion, editing `state/`
  files, the PM's `docs/team/**` prose, and any version bump or CHANGELOG entry.
- `skills/teamsmith/scripts/**`, `references/**`, `templates/**` and `SKILL.md` are PM-owned (an apply brief
  grants them); `skills/teamsmith/tests/**` is `agent:dev`'s.

## Evidence the report must contain

Both acceptance tails; the observed `team_config_set_in_file` defects; the requirement → task map; and, per
scenario, the observable that is red today.
