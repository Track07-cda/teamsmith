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
editor visibly falls back to free text and says why; an unset key never shows a blank box. (4) The write path is
the command's: validation, CAS fingerprint, audit and `team config set` as the only writer; the editor that feeds
it chooses itself by the schema's choice set, and — M65 — a value chosen from the choice editor goes down that
path directly, while only the free-text entry keeps the manual editor with its confirmation (D10/D11, §5).
(5) The console's interaction never waits on a read the view did not already do (D11). The schema, not the bundle,
decides what can be chosen: a key or a value added to the command appears without a rebuild.

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
| R4 | the write is the command's unchanged path; the picker's value entries feed it directly (M65) | `panel` | MODIFIED |

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
- **Open kinds** (`model`, numerics, `path`) end with a free-text entry — the **only** entry that opens the
  compose editor — seeded with the current value; M65's rework gives that entry the editor's validation and
  confirmation and gives every value entry the direct write of D10.
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
- A **set** key offers its default as an ordinary value entry (a real write with the class's timing), and its
  receipt says it is a write (M65: accepting a value entry writes on that accept — D10). The view never claims to
  remove the key. A true unset is a hand edit of `.pi/team/config.sh`, and the row's hint can say so — the same
  honesty rule as the `refuse` rows.

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

### D6. The writer does not move; the interaction that feeds it does (M65 rework: D10/D11)

*(Revised by M65. The writer keeps every rule below. What changed: a **chosen** value now goes to it in one
accept, and only a **typed** value passes through the confirmation frame — see D10 and §5.4.)* A picked value and
a typed value both end in the same writer: `team config set … --dry-run` (validation) and then
`team config set … --yes --fingerprint`. For a value accepted from the choice editor both calls happen on that
accept (D10); for a typed value the first `enter` is the validation and the confirmation line carries key, old
value, new value and the class's timing, with the second `enter` performing the write. Conflicts reload the view,
the audit tail is re-read, and the wrapper's argv log remains the evidence that the console never opens the
contract. Danger is still the command's verdict: an option can be dangerous (e.g. `TEAM_REVIEW_ALLOW_DIRTY=1`)
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

*(The rework's own flips are §5.6; the ones below keep their red sides.)*

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

### D10. The picker's value entries write; the free-text entry is the only typed path (M65 rework)

Accepting a value entry (`current`, `default`, a `choices.values` entry, `clear`) SHALL validate and write in one
interaction — `team config set <KEY> <VALUE> --dry-run`, then on acceptance `team config set <KEY> <VALUE> --yes
--fingerprint <the fingerprint of the read the picker was built from>` — with no confirmation frame, the audit
line and CAS kept by the command. A value the command reports dangerous (exit 7) keeps the one confirmation the
danger rule owns; the free-text entry (and `winlist`/`pattern`'s seed) opens the compose editor and keeps that
editor's validation **and** confirmation; `keep-unset` cancels; `pairlist` still routes to the seats block; the
receipt vocabulary (written / refused / invalid / conflict / write error) is the existing one, now also on the
direct path. This is the user's decision of 2026-09-21 (②③④) written as a contract; §5.4 is its prose version.

### D11. Responsiveness is a behavior, not a budget: no read on the interaction path (M65 rework)

Measured (§5.2): the console's felt latency is the read — `team config list --json` costs ~3.3 s per call
(~600 processes for the per-key/per-line fan-out), and the console used to call it synchronously on view entry,
on every row open and on every pick. Two decisions follow, and neither is a wall-clock number (D33):

1. **The console side.** The picker and the free-text editor are built from the `settings` block already on
   screen; opening a row, moving in the picker, accepting an entry and opening the editor MUST NOT wait on a read
   (`config list` / `__panel-data`), and the fixture proves it through the wrapper's argv log instead of a timer.
   The fingerprint the direct write carries is the one that read produced; a file changed under the picker is the
   command's conflict verdict and the view reloads. After a write the console re-reads the `settings` block (only
   that block) in the background; the receipt frame comes from the write's own settle and is never held by it.
2. **The command side.** The read itself gets its fan-out removed (M2, §5.5): one pass over the contract instead
   of a per-key `grep|head`+`awk` and a per-line `sed`. The prototype produced identical records at ~0.19 s versus
   ~3.3 s, which is what remains on the view's own entry and on every background refresh. Any wall-clock guard for
   it lives in `tests/perf.sh` (visible SKIP, own premise, 0/2/3/4), never in the correctness gate.

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

**F2 (follow-up, not in scope): a structural guard for the read.** The rework makes the read cheap again; nothing
in the correctness gate can fail a future fan-out creeping back in without a wall-clock number (D33). If we want
one, it belongs in `tests/perf.sh` (visible SKIP, its own premises), not in smoke.

## 5. The rework (M65): measure first, then fix the interaction

The user rejected the applied interaction: choosing a value must write it, not open another editor. Before any
contract change, the felt latency was measured on the merged implementation (M55 `78fc880`) with a pty probe that
drives the committed bundle and stamps each keypress against the frame it produces.

### 5.1 Method (reproducible)

- `docs/team/reports/M65-dev2/measure/measure.py` runs `panel.js` on a **raw pty** (160×40, node 24, `--no-pulse`,
  zh) with a minimal VT screen model: every output chunk updates the screen and a stamp is the moment the chunk
  that completed the expected frame arrived; keys go in one at a time. Segments: `view` (Enter on the overlay's
  settings row → the view's first frame with rows), `open` (Enter on the `TEAM_MONITOR_UI` enum row → the picker's
  first complete frame), `move` (Down → cursor on the next entry settles), `pick` (Enter accepting an entry → the
  write editor's first frame), `dry` (Enter in the editor → the confirmation line), `write` (Enter confirming → the
  receipt frame).
- `docs/team/reports/M65-dev2/measure/run.sh` builds a throwaway fixture (`team init`, 108-key schema), puts a
  **logging wrapper** in front of the CLI (`--team-cli`, EPOCHREALTIME start/end per invocation), and records: 5
  runs of each CLI command, a bash-xtrace census of the read path, the pty segments (7 samples) and the child-
  inside-segment attribution. All artifacts: `results-cli.txt`, `results-spawns.txt`, `results-pty.json`,
  `results-pty.txt`, `results-attr.txt`, `results-prototype.txt`.

### 5.2 Raw numbers (fixture: 108 schema keys, 59 set; host, no container)

| segment | median | samples | owning-command child inside it |
|---|---|---|---|
| `view` (first frame with rows) | **3446 ms** | 1 | `__panel-data --block settings` 3379 ms |
| `open` (picker first frame) | **3303 ms** | 3284 3333 3314 3270 3303 3545 3252 | `--block settings` 3252–3545 ms |
| `move` (Down → settled) | **6.2 ms** | 7 6 5 6 6 6 5 | — |
| `pick` (acceptance → editor frame) | **3393 ms** | 3262 3342 3339 3442 3460 3393 3487 | `--block settings` ~99.5 % of the segment |
| `dry` (validation → confirmation) | **88.9 ms** | 90 90 86 87 86 89 91 | `config set … --dry-run` ~74 ms |
| `write` (confirm → receipt) | **176.1 ms** | 175 167 165 176 182 176 187 | `config set … --yes` ~115 ms |

CLI cost, 5 raw runs each (ms): `team config list --json` 3227 3268 3388 3251 3164 · `team config list` (human)
979 972 958 948 969 · `team __panel-data --block settings` 3266 3229 3304 3300 3248 · `config set … --dry-run`
72 76 74 74 76 · `config set … --yes` 115 113 114 117 115.

Read path, bash xtrace census of one `team config list --json`: 26 509 traced commands, **623 external spawns**
(`grep` 170, `head` 170, `awk` 119, `sed` 109, `tr` 45, …), **largest single gap 6.4 ms, gaps > 20 ms: 0** — the
cost is not one slow command, it is the per-key/per-line fan-out. Micro-bench: `grep|head` per key ≈ 2.2 ms; the
unknown-key scan spawns one `sed` per *file line* (109).

Single-pass prototype (`measure/read-prototype.sh`, one awk pass + pure bash): **semantic match — 111 records
byte-for-byte equal to the real read's `name/value/comment/class/set`** on the same fixture, 5 runs 931 ms →
**≈ 186 ms per read** versus ≈ 3 300 ms. The prototype is evidence for the cost class, not a patch.

### 5.3 Bottleneck location (against the brief's four candidates)

1. **View construction (108 keys once)** — ruled out: the picker's frame follows its data by ~12 ms and the
   view's own first frame is ~67 ms of console time on top of its read; building the row list is not where seconds go.
2. **Full re-render per keypress** — ruled out: `move` is 6.2 ms median with no child process at all.
3. **Synchronous subprocess per write** — real but small on its own: every `team` invocation costs 72–117 ms,
   which the `dry`/`write` segments carry (89/176 ms total); it does not explain seconds.
4. **其他 — the read path**: `team config list --json` costs 3.2–3.4 s per call because it spawns ~600 processes
   for 108 keys and 109 file lines, and the console calls it **synchronously on every row open and every pick**
   (`openSettingsRow`/`chooseChoiceOption` force `refreshSettings()`), and once more when the view opens. That is
   what the user felt as "打开有延迟" (3.4 s before the picker/editor) and "确认也有延迟" (3.4 s before the
   editor the confirmation lives in). The two are the same read.

### 5.4 The rework: what the interaction must become (the user's decisions, made precise)

- **A chosen value writes.** Accepting a value entry (`current`, `default`, a `choices.values` entry, `clear`)
  runs the command's validation and then the write in one interaction: `team config set <KEY> <VALUE> --dry-run`
  and, when it accepts, `team config set <KEY> <VALUE> --yes --fingerprint <the read that built the editor>`.
  No second confirmation frame. Validation, CAS fingerprint and the audit line stay the command's.
- **One exception for danger.** A value the command reports as dangerous (exit 7) is not written by the first
  accept: the confirmation line carries the warning and one more accept writes it with `--allow-danger` (the
  existing rule, unchanged).
- **"Other" is the only typed path.** The free-text entry opens the compose editor seeded with the current value,
  and that path keeps validation **and** confirmation exactly as it is today (two `enter`s). `winlist`/`pattern`
  seed the same editor; `path`'s clear entry is a value (direct) and its free entry is typed; `pairlist` still
  routes to the seats block; `keep-unset` still cancels.
- **Receipts name what happened.** Written (with the class's timing), refused, invalid (naming the accepted
  domain), conflict (file changed under the picker: nothing written, view reloads), write error — the existing
  exit-code mapping, now also on the direct path.
- **No read on the interaction path.** The picker is built from the `settings` block already on screen; opening
  a row, moving in the picker, accepting an entry and opening the free-text editor never wait on a new
  `team config list`/`__panel-data` read. Freshness is the view's own read plus the write's CAS: a file changed
  under the picker is caught by the fingerprint and reported as a conflict, not by re-reading before every action.
- **A settle refreshes in the background.** After a write the console re-reads the `settings` block (only that
  block) and adopts it when it lands; the receipt frame is drawn from the write's own result and is never held by
  that re-read.

### 5.5 The fix, chosen from the data

| # | Fix | Where | Why the data points here |
|---|---|---|---|
| M1 | take the read off the interaction path: picker opens from the on-screen block, the direct write replaces the editor step, the free-text entry is the only editor, the settle refreshes only `settings` in the background, the receipt is drawn on the command's own settle | `scripts/panel/src/{App,main}.tsx` | kills the 3.4 s `open`/`pick` segments (the child accounted for 99.5 % of each) and the second 3.4 s the user reads as "confirmation latency" |
| M2 | make the read itself cheap: one pass over the contract (values, inline comments, unknown keys) instead of a per-key `grep|head`+`awk` fan-out and a per-line `sed` | `scripts/lib/cmd-config.sh` | the prototype produces **identical** records at ~0.19 s vs ~3.3 s; this is what is left of `view` (3.4 s) and of every background settle refresh; it also removes ~600 processes per read |

Rejected, with the measurement that rejects them:

- **Cache / incremental view construction** (candidate 1): `move` is 6.2 ms and the render share of `open` is
  ~12 ms — there is nothing to gain; the seconds are inside the child.
- **Renderer-side only (open the picker optimistically, keep the per-open read)**: hides the 3.4 s behind the
  frame but the editor still waits for it (the `pick` segment) and `view` entry stays at 3.4 s; the numbers say the
  call must leave the path, not be moved later.
- **Async write without validation** (candidate 3 taken to the end): violates the user's "校验 + CAS + 审计行保留"
  and the writer's contract; the validation is also what surfaces the danger verdict the exception depends on.
- **Widening the read's TTL instead of re-reading**: `settings` already has a 15 s TTL, yet every row open forces
  a read; the fix is to delete the force, not to lengthen the TTL.

### 5.6 What flips for the rework (each needs its red side in the apply report)

- **Direct write**: the wrapper's argv log on a picker accept carries exactly `config set … --dry-run` then
  `config set … --yes --fingerprint …`, no confirmation line ever renders, the contract changed once and the audit
  grew one line. Red side: dropping the direct write (the pre-rework bundle) leaves the log at `--dry-run` only and
  opens an editor frame.
- **No read on the path**: between the accept keystroke and the `config set` line there is **no** `config list` /
  `__panel-data` child; the same window for `open` and for opening the free-text editor. Red side: re-adding
  `refreshSettings()` to the open path makes the log show a `--block settings` child inside the window the fixture
  asserts empty.
- **"Other" keeps the two-step**: the free-text entry shows the editor, `enter` shows the confirmation, the second
  `enter` writes — the existing `write` scenario unchanged.
- **Danger keeps its one confirmation**: choosing `0` for `TEAM_MIN_FREE_SWAP_MB` from the numeric picker shows the
  warning, leaves sha256 and audit unchanged, and the second accept writes with `--allow-danger`.
- **Keep-unset still cancels** and a refused/invalid pick writes nothing and keeps the receipt's reason.
- **The read's cheap path is equal**: the prototype's equality check is the red for a fan-out rewrite that changes
  bytes (`measure/read-prototype.sh` output diffed against `team config list --json`), and `tests/panel-choices.sh`'
  per-kind walk plus the consistency walk stay green on the rewritten read.

