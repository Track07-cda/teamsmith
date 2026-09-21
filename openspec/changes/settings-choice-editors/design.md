# Design: `settings-choice-editors` — the schema already knows the choices; the console shows them

## 1. Context

Read-only recon against this checkout (branch point `5887509`), measured 2026-09-21.

- **The schema is the ledger.** `team_config_schema()` (`scripts/lib/cmd-config.sh:29–151`) is a `|`-separated
  table read by `team_config_field` (`:169`): `name|class|kind|constraints|form|default|comment|route` — field 7
  is the comment, field 8 the refusal route and therefore the last column in use. Measured on this tree: **108
  keys** — class `apply` 48, `restart` 24, `refuse` 36; kind `bool` 22, `path` 18, `text` 17, `int` 13,
  `seconds` 11, `cmd` 5, `mb` 5, `bytes` 4, `tpl` 3, `enum` 3, `model` 2, and `list`/`pattern`/`winlist`/
  `pairlist`/`pct` one each.
- **The validator already encodes every domain.** `team_config_validate_value` (`:254`) accepts, per kind: `bool`
  canonical `1`/`0` (also the seven spellings, canonicalized by `team_config_canonical_value` `:369`); numerics as
  a non-negative integer inside the row's `min,max`; `enum` as exact membership of `constraints` (refusal prints
  `a|b`, `:296`); `path` only "not empty unless the spec ends in `,opt`" (no existence check); `model` as exactly
  one `/` and an `opt` empty allowance; `pairlist`/`winlist`/`pattern` as `token=N` with seat and model rules;
  `text`/`cmd`/`tpl`/`list` as free text. `team_config_danger_reason` (`:383`) names the valid-but-guard-off
  values.
- **The read dead-ends at `kind`.** `team_config_list_json` (`:496`) reports
  `name/class/kind/form/value/default/set/comment/warning/route/known` — no `constraints`, no choice set. Its
  `models` block (`:536–566`) is `{default, known[], seats[]}`: `known` is `TEAM_DEFAULT_MODEL`, the
  `TEAM_AGENT_MODELS` tokens and each roster agent's `state/<a>.env model`; the **`pm` seat is missing** (the
  second loop iterates `team_agents`, and `team_pm_start` never writes a `pm` state record — grep: no
  `team_state_set pm`). `seats` does cover `pm` via `team_config_seat_state` (`:470`).
- **The console's editor is one blank box.** The settings block is the raw `--json` payload
  (`cmd-watch.sh:1001–1003`). Every editable row's `enter` opens the compose editor and `submit()` (`App.tsx`,
  `mode === 'setting'`) calls `team config set … --dry-run`, then `--yes --fingerprint` on the second `enter`
  (`main.tsx:509–530`). The only picker today is the **seat** picker (B4): its options are `models.known`
  (`App.tsx` `openSettingsRow`), rendered in the view's own line budget (`layout.ts:1326–1348`).
- **A machine model catalogue is not a choice set.** `~/.pi/agent/models-store.json` is a live cache that
  measured 200 652 bytes at the start of this recon and 303 800 bytes a few minutes later, over six providers
  (including an `openrouter` catalogue of hundreds); the retired `models.json` backup
  (`~/.pi/agent/models.json.bak-20260921-031641`) still names `sub2api` with `baseUrl
  http://<internal>/v1` — the endpoint the PM measured as refused (the backup also holds a credential;
  nothing here copies it). This project's own model set measured **3** entries: `deepseek/deepseek-flash`,
  `kimi-coding/k3-256k`, `openai-codex/gpt-5.6-terra:xhigh`.
- **The gate.** `config-cli.sh` runs inside FAST smoke (smoke §33) with sections
  `list writer inject cas validate audit models seats completeness docs callers flip`; `panel-p21.sh` drives the
  real bundle in a private tmux server with an argv-logging wrapper (`settings write conflict seats readonly`);
  `flip-p22.sh` is the edit → rebuild → red → restore → green pattern; `panel-strings.mjs` asserts equal zh/en key
  sets, no CJK literals outside the tables and `label_<KEY>` in both directions.
- **Unset is not expressible.** `team_config_set_in_file` only writes a value; the only removal in the whole CLI
  is `team config set-agent-model <seat> -` (a pairlist token). Nothing in this change adds one.

## 2. Root cause

1. **The type information stops at the command's boundary.** `kind` reaches the console; the domain
   (`constraints`, the accepted spellings, the membership list) does not. Any consumer that wanted to offer a
   choice would have to re-implement the schema — exactly the second source the P22 requirement forbids.
2. **"Edit a setting" is defined as "type its value".** Because the only editor is the compose line, a closed
   domain (`bool`, `enum`) and free text are indistinguishable in the UI, so the human supplies knowledge the
   machine already has.
3. **The schema has nowhere to put sensible values.** `constraints` is `min,max` for numerics and the membership
   list for enums; there is no column for "300/900/1800/3600 is the scale this key lives on".
4. **Even the existing picker can display a value outside its own list** when `TEAM_PM_MODEL` names a model the
   agent tokens do not (the `known` gap above).

## 3. Goals / Non-Goals

**Goals.** (1) One additive machine field carries each key's choice set, derived from the same schema row the
validator uses, and it is the only source the console reads. (2) The console opens a choice editor wherever a
choice set exists — `bool`, `enum`, `model`, numeric, `path` — and a composite palette where only a token's
vocabulary exists (`winlist`/`pattern`, and the seats route for `pairlist`). (3) Where there is no choice set the
editor visibly falls back to free text and says why; an unset key never shows a blank box. (4) The write path
(two-step confirmation, CAS fingerprint, audit, `team config set` as the only writer) is untouched. (5) The
schema, not the bundle, decides what can be chosen: a key or a value added to the command appears without a
rebuild.

**Non-Goals.** The writer's validation/canonicalization, CAS, audit and danger list; an unset/removal operation
(recorded as follow-up F1); editors for `refuse` keys (they keep their route-only behavior); the human
`team config list` table; `team monitor --print`/`--json` and every other machine exit; the panel's row layout
(no new row column → no snapshot churn); seat-model semantics and where a model takes effect; the machine's Pi
model catalogue; `TEAM_AGENT_MODELS`' seat rule.

## 4. Decisions

### D0. Spec homes: two in `memory-and-deps`, two in `panel`

| # | Promise | Capability | Delta |
|---|---|---|---|
| R1 | the machine read reports each key's choice set, derived from the schema, with a consistency gate | `memory-and-deps` | ADDED |
| R2 | the known model set is this project's (pm seat included); no machine catalogue | `memory-and-deps` | MODIFIED |
| R3 | the console's editor is a choice editor wherever the schema has one, and a visible free-text fallback where it has none | `panel` | ADDED |
| R4 | the write path is unchanged; only the editor that feeds it is schema-chosen | `panel` | MODIFIED |

`memory-and-deps` owns R1/R2 because they are properties of `team config list --json`, the contract's own read
(the capability already owns "the project contract has exactly one writer" and the seat-model read). `panel` owns
R3/R4 because they are the console's rendering and interaction. No third capability is touched: the writer, the
guards and the seat write path keep their specs, and this change adds no writer behavior to specify.

### D1. The field: `choices`, additive, one object per key, derived from the schema row

`team config list --json` gains one field per key record (unknown file keys included):

```json
"choices": {"source":"schema","values":["1","0"],"min":"","max":"","empty":false,"note":""}
```

- `source` — where the vocabulary came from: `schema` (a `bool`'s two canonical values, an `enum`'s
  `constraints`, a numeric key's `suggest` column), `known` (the project's model vocabulary: `model`,
  `pairlist`, `winlist`, `pattern`), `none` (a kind with no vocabulary).
- `values` — the ordered whole-value vocabulary, `[]` when there is none. For `bool`/`enum` it is the **closed
  domain** (a value outside it cannot be chosen because the command would refuse it); for the other kinds it is
  *offered* vocabulary and free text stays available.
- `min` / `max` — the numeric kinds' accepted bounds as strings, `""` = unbounded, `""` for other kinds. They are
  the same `constraints` the validator reads, so the editor can display the accepted interval without
  re-parsing the schema.
- `empty` — whether the writer accepts the empty value for this key (a `path`/`model` spec ending in `,opt`, or a
  kind that accepts `''`). It decides whether a "clear" entry may be offered.
- `note` — the command's optional explanation (empty when there is nothing to say).

Per kind, verbatim through the console:

| kind | `source` | `values` | `min`/`max` | `empty` | editor |
|---|---|---|---|---|---|
| `bool` | schema | `1`,`0` | — | false | two labelled entries, default marked |
| `enum` | schema | `constraints` in declared order | — | false | the values verbatim |
| `int`/`seconds`/`mb`/`bytes`/`pct` | schema | `suggest` column | from `constraints` | false | suggestions + current + default + free text, interval shown |
| `path` | none | `[]` | — | spec `opt` | current / default / clear (when `empty`) / free text, existence marked |
| `model` | known | `models.known` | — | spec `opt` | known models + current + default + free text |
| `pairlist` | known | `models.known` (token vocabulary) | — | true | `enter` focuses the seats block (D3) |
| `winlist`/`pattern` | known | `models.known` (token vocabulary) | — | true | palette; choosing seeds the compose editor with `<model>=` |
| `text`/`cmd`/`tpl`/`list` | none | `[]` | — | true | compose editor + the visible reason (D3) |

**Compatibility.** The field is additive inside a JSON object: every existing consumer reads named fields, the TS
types are structural, and the panel's own type gains an optional member. `team config list`'s human table, the
`--json` record's existing fields, `team monitor --print`/`--json`, `team __panel-data`'s other blocks and every
other machine exit keep their bytes. The panel bundle is rebuilt in the same commit as the sources (its
byte-identical-rebuild gate already exists).

**Why one object and not a bare array.** The brief asks for string arrays *or* ranges *or* bool labels. A bare
array cannot carry the range, the empty-value rule or the reason, and a per-kind union would make every consumer
switch on `kind` just to find the field. One small object keeps the read self-describing and lets the panel
render the interval and the fallback reason without a second schema parse. Bool's two labels do **not** live in
the JSON: `1`/`0` are the writer's canonical values, the words come from the zh/en tables (`settingsBoolOn`/
`settingsBoolOff`) — the JSON carries data, the tables carry language. `enum` values are rendered **verbatim**,
with no per-value table entry: a value added to `constraints` must appear with no rebuild (R3's flip), which a
per-value table would make impossible.

### D2. Numeric suggestions are schema data: a new optional 9th column `suggest`

Rows that have suggestions end with a comma-separated list; rows without stay at eight fields (the reader tolerates
the missing trailing field):

```
TEAM_PULSE_INTERVAL|restart|seconds|60,|plain|900|低于 60 秒 = 巡检转成忙等||300,900,1800,3600
TEAM_MIN_FREE_SWAP_MB|apply|mb|0,|plain|1024|0 = 磁盘 swap 底线关闭||512,1024,2048
TEAM_INBOX_MAX_CHARS|apply|int|1,|plain|150|-||100,150,300
```

Rejected alternatives, with the reason:

- **A `kind → suggestions` table.** Measured, one scale cannot fit a kind: `seconds` spans `1` (dispatch alive),
  `2` (timeout grace), `3` (monitor refresh), `6` (PM start wait) and `1800` (review timeout); `mb` spans `512`
  (total floor) to `6144` (agent memory). A kind table would offer `1800` for a 2-second grace value — invented
  options are exactly what this change removes. It would also be a second source next to the schema row.
- **Deriving suggestions from `default`, `min`, `max`.** Mechanically defensible but it invents a ladder the
  author never chose, and it cannot express "the pulse cadence lives on the 5/15/30/60-minute scale".
- **A separate suggestions file.** A third source; the schema file's own header already says "表就是真相".

The column is data, so it can be wrong; D8 turns a wrong suggestion into a red gate instead of a silent filter.

### D3. One picker widget, rendered in the view's own line budget

The picker reuses the seat picker's mechanism exactly (`layout.ts:1326–1348`: it replaces the view's row list
inside the same visible-line budget, with `Action` hits per row), so no new overlay, no new width tier and no
change to the row layout the snapshots pin. Entries are built as: the current value (marked current) if the file
carries the key, the default (marked default) when non-empty, each `choices.values` entry (deduped against the
two above), then kind-specific actions.

- **Closed kinds** (`bool`, `enum`) have no free-text entry: the domain is the whole truth. A file value outside
  the domain still renders (as the current entry) — the command remains the judge of the write.
- **Open kinds** (`model`, numerics, `path`) end with a free-text entry that opens the compose editor seeded with
  the current value; the confirmation and write path are the existing ones.
- **`path`** adds a "clear" entry only when `choices.empty` is true, and marks an entry (or the typed value) with
  whether it exists — directory/file/executable per the kind spec. The mark is an **advisory line, never a
  refusal**: the command has no existence check and this change does not add one, so the console must not claim a
  refusal the writer would not make. The confirmation for a missing path names the mark.
- **`pairlist`**: its editor is the seats block — `enter` moves the focus there (the P22 requirement owns per-seat
  editing and `team config set-agent-model` is the only writer of that key). The row's command line names
  `team config set-agent-model <seat> <model|->`. Composing the pair list by hand stays a CLI affair.
- **`winlist`/`pattern`**: the palette lists the known models; choosing one opens the compose editor with
  `<model>=` inserted at the insertion point (seeded with the current value). The numeric right-hand side is
  inherently free.
- **No choice set** (`text`/`cmd`/`tpl`/`list`, or `choices.source = none` with no action set): `enter` opens the
  compose editor directly, and the view shows one line naming the reason — the kind carries no choice set and the
  command still validates the write. No picker over invented values, no silent fallback.
- **Unset keys** (D4) start on the explicit keep-unset entry, so the first thing rendered is a choice, not a blank
  box.
- **`refuse` rows and unknown keys** keep today's behavior (no editor; route/warning line).

### D4. Unset: the writer has no unset, and the console says so instead of pretending

Measured: `team_config_set_in_file` only writes; `team config set` has no remove; the only removal is
`set-agent-model <seat> -`. Therefore:

- An **unset** key already renders as `未设 · 默认 X` (`settingsUnset`), and its editor's first entry is an
  explicit **"keep unset"** entry whose effect is to cancel the edit — nothing written, no audit line (the
  existing `esc`-on-edit path). That is the brief's "restore default (unset)" option for a key that is already
  unset.
- A **set** key offers its default as an ordinary value entry (a real write with the class's timing), and the
  confirmation says it is a write. The view never claims to remove the key. A true unset is a hand edit of
  `.pi/team/config.sh`, and the row's hint can say so — the same honesty rule as the `refuse` rows.

Adding `team config unset` is **out of scope**: it is a new writer operation (validation, CAS, audit, danger and
`references/config.md` all in play), the brief's boundaries freeze the writer, and an unset option is only
meaningful for set keys. Recorded as follow-up F1 in D9; not a requirement of this change.

### D5. Model vocabulary: project data only, `pm` included

`values` for `model`/`pairlist`/`winlist`/`pattern` is `models.known` — extended by R2 to include every seat's
displayed model, the `pm` seat's resolution (`TEAM_PM_MODEL`, else `TEAM_DEFAULT_MODEL`) first among the missing
ones. The command MUST NOT read `~/.pi/agent/models.json` or `models-store.json`: the measurement in §1 shows a
multi-hundred-KiB catalogue that changed size within this recon, with providers this project never uses, and the
retired `sub2api` entry proves a catalogue can name an endpoint that no longer answers. `known` stays what the CLI already means by "configured and recorded
models": the running window's model is the state record dispatch wrote; this change adds no process probing to a
read that must stay cheap. The editor merges the key's current and default values into the entries, so the value
on screen is always selectable.

### D6. The write path does not move

Choosing an option changes only how the draft is produced. `enter` in the picker places the value and the existing
flow takes over: `team config set … --dry-run` (validation), the confirmation line with key, old value, new value
and the class's timing, then a second `enter` performing `team config set … --yes --fingerprint`; conflicts reload
the view, the audit tail is re-read, and the wrapper's argv log remains the evidence that the console never opens
the contract. Danger is still the command's verdict: an option can be dangerous (e.g. `TEAM_REVIEW_ALLOW_DIRTY=1`)
and takes the existing extra confirmation; the picker must not pre-judge danger. An out-of-range typed number is
refused by the command naming the interval (`choices.min`/`max` only *display* it).

### D7. Keyboard and mouse parity

Every entry is a focus target (`↑`/`↓`) and a click target (the existing `placedWithHits` + `Action` mechanism,
as the seat picker and the board rows use); a click on the focused entry accepts it, a click on another moves the
cursor first; the wheel scrolls an option list longer than the budget; the free-text entry is reachable by
keyboard and by click and opens the same compose editor; `esc` closes the picker back to the row list with the
row focus preserved. No key-only affordance is added, so the "Every key affordance is also a mouse target"
requirement keeps holding without a new exception.

### D8. Falsifiability: the consistency fixture and the flips

- **Consistency (R1).** A new `config-cli.sh` section walks every key of the real schema and asserts, against a
  fixture contract, that every `choices.values` token is accepted by `team config set <KEY> <value> --dry-run`
  (exit 0, or exit 7 for a dangerous-but-valid value), that `min`/`max` equal the row's `constraints`, that
  `empty` matches the validator's verdict on `''`, and that every `suggest` token lies inside the range. **F-D**:
  patching a scratch CLI's schema to suggest `30` for `TEAM_PULSE_INTERVAL` (min 60) must make the section red,
  and restoring it green.
- **The enum flip (R3, the brief's most important one).** A scratch CLI whose schema gains
  `TEAM_ZZZ_MODE|apply|enum|red,blue|plain|red` is read by the **committed, unchanged** bundle: the picker offers
  `red`/`blue`. Then the same scratch schema drops the constraints (`enum||plain|`): the same bundle opens the
  compose editor with the "no choice set" reason. On the pre-change bundle both fixtures show the blank editor
  (red by absence) — the report carries both tails.
- **Catalogue leak (R2).** A fixture `HOME` whose Pi model catalogue names `sub2api/gpt-5.6-luna` must not appear
  in any `choices.values` or in `models.known`; adding it to the fixture is the red side.
- **Panel write flip (R4).** Dropping the `choices` reader from the bundle makes the choice scenarios
  (`panel-p21.sh`'s new section) red while the write/conflict/seat scenarios stay green — proving the picker is
  the bundle's only new behavior, not a rewrite of the write path.
- **The existing gates stay green**: wrapper argv evidence (no `config set` on a cancelled edit, exactly
  `--dry-run` + `--yes` on a confirmed one), CAS conflict, audit lines, refuse rows, machine-exit stability.

### D9. Cross-change check and follow-ups

Open changes: `watch-degradation` (panel frame assembly/delivery warning; notify-and-inbox; watchdog),
`gate-hygiene` (panel frame assembly + review queue), `inbox-spool-resilience` (notify/inbox),
`change-centric-discipline` (board/dispatch/verification). None touches the settings view's editor flow or
`team config list --json`'s record shape, and none reads the `choices` field; this change modifies a different
`panel` requirement than either panel-writing change. This change writes exactly two delta files (`panel`,
`memory-and-deps`), one task each, so the one-writer-per-delta rule holds.

**F1 (follow-up, not in scope): a real unset.** `team config unset <KEY>` would make "restore the default"
mean removing the line rather than writing the current default. It is a writer-capability change with its own
CAS/audit/danger story; the design records the gap so no spec here pretends it is closed.
