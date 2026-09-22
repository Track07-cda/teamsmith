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

**The rework (2026-09-21, after the first apply M55).** The user rejected the applied interaction — picking an
option opened yet another editor and a second confirmation — and decided: measure the felt latency first, then
(②) a chosen value writes immediately (validation + CAS fingerprint + audit line kept), (③) only "other" (free
text) keeps the manual editor with its validation and confirmation, (④) a dangerous value keeps one confirmation
even when it comes from the options. The measurement (design §5, `docs/team/reports/M65-dev2/measure/`) puts the
felt seconds in the **read path**, not in the view: `team config list --json` costs ~3.3 s **per call** because it
spawns ~600 processes (per-key `grep|head`+`awk`, per-line `sed`), and the console called it synchronously on view
entry, on every row open and on every pick — while the console's own share of a keystroke-to-frame segment is
~6–20 ms (`move` 6.2 ms median, `open` child 99.5 % of the segment). Both fixes follow from that: take the read off
the interaction path, and remove the read's fan-out (a single-pass prototype produced identical records at
~0.19 s versus ~3.3 s).

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
  an empty box. **A value entry writes in one accept** — validation, then `team config set … --yes --fingerprint`,
  no second confirmation frame — while the free-text entry is the only path that opens the compose editor and keeps
  its validation and confirmation; a dangerous value keeps one confirmation (M65 rework). The editor is built from
  the `settings` block already on screen: **no read on the interaction path**, and a settle refreshes that block in
  the background without holding the receipt frame (M65 rework).
- **MODIFIED — `panel`**: the write requirement is the command's path — validation (`--dry-run`), CAS fingerprint,
  audit, danger verdict and `team config set`/`set-agent-model` as the only writers — and the editor feeding it is
  chosen by the schema's choice set; a **chosen** value goes down that path on the accept itself, and only a
  **typed** value passes through the confirmation frame (M65 rework of the two-step interaction).
- **MODIFIED — `memory-and-deps`**: `models.known` is every seat's displayed model, the `pm` seat included.

## Capabilities

### Modified Capabilities

- `memory-and-deps`: the machine read exposes the schema's choice set; the known-model set is the project's.
- `panel`: the row editor is a choice editor where the schema defines choices and a visibly degraded free-input
  editor where it does not.

## Impact

`scripts/lib/cmd-config.sh` (optional 9th schema column, `--json` field, and — M65 — the read path's per-key
fan-out collapsed to one pass over the contract); `scripts/panel/src/{types,data,App,layout}.ts(x)`
and `strings/{zh,en}.ts` plus the rebuilt `panel.js`; `tests/config-cli.sh`, `panel-p21.sh` and one flip script;
`tests/perf.sh` (the read's wall-clock guard, D33: visible SKIP, own premise, exits 0/2/3/4);
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

**The rework's flips (M65, design §5.6):** accepting a value entry yields exactly `config set … --dry-run` then
`config set … --yes --fingerprint …` with no confirmation frame and one new audit line (red: the pre-rework bundle
stops at `--dry-run` and opens an editor); the interaction path spawns **no** read child in the accept/open/
free-text windows (red: re-adding `refreshSettings()` on the open path puts a `--block settings` child inside the
window the fixture asserts empty); the free-text entry still shows the confirmation before writing; choosing a
dangerous value shows the warning, leaves sha256 and audit unchanged, and the second accept writes; keep-unset and
`esc` still write nothing. The read's rewrite is pinned by the prototype's byte-equality check plus the existing
per-kind/consistency walks, and its wall-clock budget by `tests/perf.sh` (never a correctness red).

## Boundaries

Planning only: this task writes `openspec/changes/settings-choice-editors/**` and its report. Apply must not touch
the writer's accept/reject semantics or the danger list, must not add an unset operation, must not read the machine's
Pi model catalogue, and must not change `team config list`'s human output or any machine exit except the additive
`--json` field. The M65 rework keeps the same **two** deltas: `specs/panel/spec.md` carries the interaction and
responsiveness contract, and `specs/memory-and-deps/spec.md` is **not touched by M65** (the schema read's shape —
the `choices` field — does not change; the read's fan-out removal is an implementation means of the panel's
responsiveness requirement, not a read-contract change). Implementation paths (`scripts/**`, `panel/**`,
`tests/**`, `references/**`) need the apply brief's explicit grant (OWNERSHIP).

## Evidence the report must contain

Baseline and post-change `openspec validate --all --strict` tails; the fast-smoke tail; the delta-to-requirement
map for both capabilities; requirement-to-item and scenario-to-fixture maps; the recon commands with outputs
(`team config list --json` field list, kind/class counters, the `sub2api` entry without its credential). **For the
M65 rework**: the three (plus three) segment medians with their raw samples and the child-inside-segment
attribution, the read path's spawn census, and the single-pass prototype's equality + timing — all reproduced by
`docs/team/reports/M65-dev2/measure/run.sh`, which is the evidence's one command.
