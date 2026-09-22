# Design: `settings-view-groups` — the schema carries the domains; the console renders them, and the wheel reaches the view

## 1. Context

Read-only recon against this checkout (branch point `112a3f4`, worktree `.worktrees/dev-bob`), measured
2026-09-22.

- **The schema is the taxonomy.** `team_config_schema()` (`scripts/lib/cmd-config.sh:32`) is a
  `|`-separated table whose twelve `# ---- … ----` section comments organize **111** keys:
  身份与账本布局 12, 分支与 forge 11, 权限与依赖策略 16, 名册、模型解析与适配器 11, 按席位模型 3, 工作流与门禁 14,
  容量与投递通知 13, 巡检与面板 7, 巡检策略 4, PM 生命周期 6, 活着的会话 10, 跨项目会议 4. Classes: `apply` 48,
  `restart` 25, `refuse` 38. The class is *nearly* a section property but not one: 分支与 forge holds 1 `apply`
  (`TEAM_MERGE_PREFER_THEIRS`) and 10 `refuse`; PM 生命周期 holds 1 `apply` (`TEAM_PM_START_WAIT`) and 5
  `restart`. The row format is documented in the function's header comment: `KEY|class|kind|spec|form|default|
  danger|route|suggest` — the 9th column (`suggest`) is optional and is *schema data* (`cmd-config.sh:29–31`).
  Field histogram: 2 rows at 7 fields, 91 at 8, 18 at 9.
- **The read is a single pass and passes the row through.** `team_config_list_json` (`:609`) iterates
  `team_config_schema` in file order and emits one record per row
  (`name/class/kind/form/value/default/set/comment/warning/route/choices/known`, `:691`), then appends the keys
  the file carries and the schema does not — `class:"refuse"`, `kind:"text"`, `known:false` (`:705`). The row
  array's order is therefore the schema's order.
- **The console groups by class, from a table the bundle owns.** `settingsViewRows`
  (`scripts/panel/src/layout.ts:1199`) defines the three buckets inline (`:1205–1209`) and filters the read's
  keys into them; the headings' labels come from the tables (`settingsGroupApply` '立即生效',
  `settingsGroupRestart` '需要重启', `settingsGroupRefuse` '只读'), and the seats block gets its own trailing
  heading (`settingsGroupSeats` '按席位模型', `:1226`). Row order is class-major, not schema order.
- **The class is already on the row — but merged with the value.** `settingsKeyLine` (`:1238`) renders
  `value · badge` through `settingsRight` (`:1233`), which applies the class tone to the **whole** right segment
  (`settingsClassTone`, `:1181`: apply→`ok`, restart→`warn`, refuse→`dim`). The badge words are
  `立即生效`/`需重启`/`只读` (`settingsBadge*`).
- **The view's window follows the focus and nothing else.** `layout.ts:1331`:
  `offset = clamp(count - visible, focus - floor(visible/2))`, and the two hidden-row counts are rendered from
  that offset (`:1428–1429`, `:1458`). The App holds `settingsFocus`/`settingsFilter` but no window state.
- **The wheel never reaches the view.** `App.tsx:1623` dispatches the wheel to the choice picker
  (`moveChoicePicker`), the detail document (`scrollDetail`) and the board lanes
  (`lane-scroll` via the hit map); everything else — the settings view included — falls to
  `updateScroll` (`App.tsx:1650`), which moves the **page's** offset behind the view. The view's own window is
  focus-derived, so a wheel over it changes nothing visible and silently moves a hidden page.
- **The board page already has the pattern the view needs.** `laneOffset` state (`App.tsx:258`),
  `laneWindow` (`layout.ts:849`): an explicit offset wins, else the window follows the focus; the frame returns
  the drawn windows and the App keeps them (`lanesRef`, `App.tsx:300`, filled at `:1507`) so the focus keys push
  the offset exactly enough to keep the focused card inside (`moveFocus`, `:791`). The wheel leaves the focus
  alone by design ("`a wheel that only updated state would be reset by the next cadence`", `:365`).
- **The gates that exist.** `tests/config-cli.sh` (FAST smoke §33) walks the read per key with
  `TEAM_CONFIG_TREE` flips; `tests/panel-strings.mjs` (rule 4) parses the schema keys out of
  `team_config_schema()` and asserts `label_<KEY>` in **both** directions (missing key, stale label, key-as-label,
  the 22-cell row column); `tests/panel-p21.sh` drives the real bundle in a private tmux server with an
  argv-logging wrapper and its `settings` scenario asserts the class **heading** (`assert_has … "立即生效"
  "apply 组标题"`) and clicks a visible `· 立即生效` row; `tests/panel-b3.sh` covers the page and lane wheel and
  the detail document wheel; `tests/panel-snapshots.sh` pins page 4 and the detail view only — the settings view
  has no snapshot.

## 2. The user's three reports against the code

| # | Report | Measured cause |
|---|---|---|
| 1 | the settings page has no mouse wheel | the wheel's fall-through at `App.tsx:1650` scrolls the page behind the view; the view's window is focus-derived (`layout.ts:1331`) so nothing in the view moves |
| 2 | grouping must not be "needs a restart" | `settingsViewRows` groups by `class` — the three class buckets and their labels are the whole grouping |
| 3 | colour the restart class per row, group by something else | the tone exists but covers value+badge together (`settingsRight`), and the class is redundantly carried by the heading — once the heading no longer names the class, the row must carry it alone |

## 3. Goals / Non-Goals

**Goals.** (1) The functional domain of a key is a property of its schema row and reaches the console through the
existing read — no second table in the command or the bundle. (2) The view groups by that domain, in the read's
own order, and a schema-unknown or ungrouped key degrades visibly instead of disappearing. (3) The effect class
lives on the row: a word (never colour alone) plus its tone. (4) The wheel scrolls the view's window, one row per
notch, without moving the focus or the page behind it; the keyboard always keeps the focused row on screen.
(5) A key, a group or a value added to the command's schema shows up in the committed bundle.

**Non-Goals.** The writer (`team config set`'s validation, canonicalization, CAS, audit, danger list, direct
write) and the choice editors (`settings-choice-editors`, archived); the read's existing fields and every
machine exit; `panel.conf`; the `↑/↓` focus keys' semantics; the board/lane/detail wheel (only re-pinned); row
columns, the label column and the snapshots of the other pages; tmux's own wheel capture.

## 4. Decisions

### D0. Spec homes: one in `memory-and-deps`, two in `panel`

| # | Promise | Capability | Delta |
|---|---|---|---|
| R1 | the read reports each key's functional group, from the schema row alone, with a walk that makes a missing or malformed token red | `memory-and-deps` | ADDED |
| R2 | the settings view groups by that group (headings, order, fallback) and carries the effect class on the row as badge + tone | `panel` | ADDED |
| R3 | the wheel's scope adds the settings view's row window (one row per notch, focus unchanged, edge counts, the page behind untouched) | `panel` | MODIFIED (the mouse requirement) |

`memory-and-deps` owns R1 because it is a property of `team config list --json` (the capability already owns the
contract's read, its `choices` field and the schema as the only source). `panel` owns R2/R3 because they are the
console's rendering and input. Nothing in the group or the wheel touches the writer, so no third capability and
no writer requirement is in play.

### D1. The group is the schema row's tenth column — not a parsed comment, not a list in the command

Adopted: every row gains `group` as a 10th `|`-separated field, a closed ASCII token; `team config list --json`
reports `"group":"<token>"` on the record (verbatim) and `"group":""` for a key the schema does not know;
`team_config_field` (`:175`) documents a range of `1..10`.

Why the row and not the section comment (the two properties the brief asks to argue):

- **Single source.** The row already owns `class`, `kind`, `default` and `suggest`; the group is the same kind of
  fact. A row's group is readable without scan state, and the read is a per-row pass. Deriving it from
  `# ---- … ----` would make a *comment* load-bearing: today `team_config_list_json` skips `#` lines and every
  consumer treats them as prose (the file's own header documents rows, not comments). A comment edit that
  normally cannot change behavior would start moving rows between headings, and the banner names
  (`身份与账本布局（refuse：…）`) carry prose that must not become part of an identifier.
- **A new key needs no console change.** Both shapes satisfy this, but only the column satisfies it *for the
  command*: a new key states its domain where every other per-key fact lives, and the read needs no new section
  state machine, no "which header is in scope" rule and no failure mode where a row before the first header has
  no group at all.
- **The alternative that would keep one list.** A `team_config_groups()` function or a header list declaring the
  closed set was rejected: it is a second table next to the rows (the exact shape `choices`' `source:schema`
  discipline forbids), and the closed set is already enforced *observably* by R1/R2's gates — a token no row
  uses has no label (strings gate red) and a label with no token is stale (red).

Trade-offs accepted: a mechanical 111-line schema diff; each row's token can disagree with the prose banner above
it (the banner is documentation and is not read — the design notes it and the review fixtures never assert it);
a `|`-field is positional, so a row that forgets its 10th field is malformed (the walk makes that red, and the
view shows it in the fallback group).

### D2. The token vocabulary: twelve ASCII slugs whose labels are the banners' names; order from the read

| token | zh heading | en heading | keys | classes |
|---|---|---|---|---|
| `identity` | 身份与账本布局 | Identity & ledger layout | 12 | refuse |
| `branch` | 分支与 forge | Branch & forge | 11 | 1 apply, 10 refuse |
| `policy` | 权限与依赖策略 | Permissions & dependencies | 16 | refuse |
| `roster` | 名册、模型解析与适配器 | Roster, models & adapters | 11 | apply |
| `seat-model` | 按席位模型 | Per-seat models | 3 | restart |
| `workflow` | 工作流与门禁 | Workflow & gates | 14 | apply |
| `delivery` | 容量与投递通知 | Capacity & delivery | 13 | apply |
| `panel` | 巡检与面板 | Pulse & panel | 7 | restart |
| `patrol` | 巡检策略 | Patrol policy | 4 | apply |
| `pm-lifecycle` | PM 生命周期 | PM lifecycle | 6 | 1 apply, 5 restart |
| `session` | 活着的会话 | Live sessions | 10 | restart |
| `meeting` | 跨项目会议 | Cross-project meetings | 4 | apply |

- **Shape.** `^[a-z][a-z0-9-]*$` — ASCII, no spaces, no CJK: the token is an identifier in a `|` table and in
  JSON, and the visible words live in the zh/en tables (`group_<token>`), which is where every other visible
  string lives. A CJK token was rejected: it would weld language into the data (the en heading needs a second
  source anyway) and make the shape check unverifiable.
- **The closed set is the bijection.** In both tables, exactly the tokens the schema rows use have a
  `group_<token>` label, and no label names a token no row uses — the same both-directions rule the key labels
  already follow (`panel-strings.mjs` rule 4). A typo therefore cannot create a silent group: it has no label and
  the strings gate is red. This gate reads the schema rows, so no declaration is duplicated.
- **Order.** The group order is the order the read reports the groups' **first** rows; with one token per file
  section that is the file's own section order, and the view's row order becomes *the schema's row order* — the
  same order `team config list` prints. The console owns no ordering table. Rejected: "editable groups first",
  which would make a group's position depend on the classes of rows inside it (a class change would move a whole
  section) and would be a console-owned rule the file cannot express. **Consequence, recorded**: the first three
  groups are the read-only skeleton (39 `refuse` keys), so the view now opens on read-only rows where it used to
  open on `apply` rows; the group headings, the `/` filter and the CLI-order alignment are the mitigations, and
  the PM may rule otherwise at proposal review.
- **Labels beyond the 22-cell column.** Group headings are full-width lines, so `panel-strings.mjs`'s 22-cell
  label rule does not apply to them; the gate checks them for non-emptiness and zh/en key equality only.
- **The three class-group labels are deleted** from both tables (`settingsGroupApply`/`Restart`/`Refuse`), since
  the grouping they name no longer exists; the badge words (`settingsBadgeApply`/`Restart`/`Refuse`) stay — the
  brief's `重启生效` is the *intent* (a word for the class), and renaming `需重启` would churn every fixture for
  no behavior. `settingsGroupSeats` is relabelled (D3).

### D3. The view: functional headings, schema order inside them, and two visible degradations

- `settingsViewRows` stops owning a bucket table: it walks the read's keys in order and opens a new heading
  whenever the token changes, keeping the row order intact (schema order inside a group, and across groups the
  groups' first-appearance order). A heading is emitted only when at least one of its rows passes the filter.
- **Labels** come from the tables via `group_<token>`; a token with no label (a schema freshly edited, the
  bundle committed) renders the raw token — the same fallback the key labels already use for unknown keys. It is
  visible, never silent.
- **Ungrouped and unknown rows** (`group:""`, i.e. a malformed schema row or a key the schema does not know) are
  collected into one trailing fallback group with its own label (`settingsGroupUngrouped`, zh `未分组` / en
  'Ungrouped') instead of being dropped into an existing domain — the row's own badge (`settingsUnknownBadge`,
  zh 未知键) and the unknown-key hint line are untouched, so the two words do not duplicate. A missing token is
  not a licence to hide a row: the walk gate is what makes it red; the view stays usable meanwhile.
- **The seats block keeps its own trailing group**, with a label that no longer collides with the schema's
  `seat-model` heading: zh `席位` / en `Seats` (today both read 按席位模型 / 'Seat models'). Rejected: merging the
  seat rows into the `seat-model` group, which would make the console recognise a specific schema token
  ("append the seats to `seat-model`") — a hardcoded key→group assumption in exactly the change whose point is
  that the bundle owns none — and would also move the seats block to the middle of the list. The pairlist route
  (`enter` on `TEAM_AGENT_MODELS` → the first seat row) is untouched.
- **Focus and clicks** are unchanged: headings are not focus targets, the focus index counts key+seat rows only
  (the current `settingsViewRows(...).filter(...)` walk survives), the whole row is still a click target.

### D4. The class: a word and a tone on the row, never colour alone

- The badge keeps its text (`立即生效` / `需重启` / `只读` / `未知键`) and gets the tone **by itself**; the value
  next to it stays in the plain text tone. Today `settingsRight` tones value+badge together, which colours the
  *value* with a class meaning it does not have.
- Tone mapping: `restart` → `warn`, `refuse` → `dim`, `apply` → `text` (plain). Green-for-apply was rejected as
  noise: 48 of 111 rows would shout, while the user's question is "does this need a restart?" — the one class
  that needs a colour is the one that warns. The mapping lives in the console (`settingsClassTone`) as today.
- The panel's existing red line ("state is never carried by color alone") is what makes the word mandatory; the
  new scenario is its falsifiable instance for this view: a capture with the SGR sequences stripped still shows
  the three classes, and a capture with them kept shows the restart badge in the `warn` tone and the apply badge
  in the text tone.
- Rejected: a per-row background/whole-line tint (the label column is the row's identity; tinting it makes a
  screen of 111 rows illegible and collides with the focus marker) and a class glyph in the cursor column (the
  cursor column already carries focus).

### D5. The wheel: the view gets its own offset, and the event is consumed

Mirroring `laneOffset`/`laneWindow` (`App.tsx:258`, `layout.ts:849`) exactly:

1. The App holds a window offset (`settingsOffset` + ref). The layout uses it when set; when it is not, the
   window keeps today's focus-follow rule. It is clamped to `[0, count - visible]`, and a shrinking row set (a
   filter, a re-read) clamps it rather than losing the view.
2. The wheel over the view (mouse on) moves that offset by one row per notch — down reveals
   later rows, up goes back — and **returns**: the event never reaches `updateScroll`, in any state of the view.
   With a picker open it walks that picker's entries instead, exactly as it walks the choice editor's today
   (`moveChoicePicker`); the seat picker gets the same rule (`moveSeatPicker`) — today its wheel fell through to
   the page, so this is the one small behavior addition D5 makes, justified by the same "a hidden page must not
   move" rule. The keyboard's focus keys and the
   key band's `↑/↓ 行` chip keep their meaning (a click acts like the key): they move the focus, and the window
   is pushed just enough to keep the focused row inside, using the window the frame returns (the board page's
   `moveFocus` rule) — so a wheel that scrolled away from the focus cannot hide the row `enter` would open.
3. The two hidden-row count lines follow the offset (`↑N` above, `↓N` below; absent at the edge), as they do
   today. The focus-centring rule remains the default for keyboard-only use.
4. Reset: opening the view starts at the top; clearing or applying a filter resets the offset with the focus.
5. The page behind the view is untouched — the wheel over the view is consumed, which is also the fix for the
   silent page scroll (the falsifiable half of the user's report #1). The page/lane/detail wheel paths are
   unchanged and re-pinned.

### D6. What must not move

The writer's path (`team config set`'s `--dry-run` validation, CAS fingerprint, audit line, danger list, the
direct write of a chosen value) and every choice-editor behavior; `team config list`'s human table; the read's
existing field names, types and per-record order-independent meaning; `team monitor --print`/`--json` and
`__panel-data`'s other blocks; `panel.conf` and the overlay's preference rows; the layout's row columns, width
tiers and the snapshots (page 4, the detail view); the `↑/↓` keys, the filter, the CLI hint line and the audit
footer.

### D7. Fixtures, gates and flips

| Gate | What it pins | Red side (the flip) |
|---|---|---|
| `tests/config-cli.sh` — new `groups` section (FAST smoke §33) | the record's `group` is the row's 10th field verbatim for the walk's sample keys, `""` for a schema-unknown key, every schema row non-empty and token-shaped, the human table and the machine exits unchanged | `TEAM_CONFIG_TREE` scratch tree whose `TEAM_GATES` row lost its 10th field → red naming the key; restore → green. A `NoPe!` token → red |
| `tests/panel-strings.mjs` (FAST) | `group_<token>` in both tables, both directions, no stale label; the removed class-group labels are gone | delete one `group_<token>` → red naming the token; add a label for a token no row uses → red |
| `tests/panel-p21.sh` — `settings` scenario updated + new `groups` scenario (real bundle, private tmux, slow batch) | the headings are the functional labels (no 立即生效 heading); the schema's order inside a group; a committed bundle against a scratch CLI whose `TEAM_ZZZ_TEST` carries `workflow` and whose `TEAM_GATES` moves to `meeting` renders both under the moved heading (no hardcode); a row whose group is deleted lands in the fallback heading; badge words + tones per class | scratch schema with the token removed → the row appears under the fallback heading (and the walk red); the moved token → the row moves; the tone dropped (all badges one tone) → the tone assertion red |
| `tests/panel-p21.sh` — wheel scenarios (same fixture, direct pty as `panel-b3.sh` does) | 3 notches move the window 3 rows and the focus stays (the CLI hint still names the same key); the `↑N`/`↓N` counts match the window; `esc` back to the page shows the page's offset unchanged (before: the page moved and the view did not); the focus keys push the window; with a picker open the wheel walks its entries | pre-change bundle: the view's frame is identical after the wheel and the page's offset changed |
| `tests/panel-b3.sh` (existing, unchanged) | the page wheel, the lane-under-cursor wheel and the detail document wheel stay as they are | — (regression pin) |
| FAST smoke pins (§38-d pattern) | cheap structural pins that survive the FAST skip of the pty scenarios: the view's grouping comes from the record (no class-bucket table in `layout.ts`) and the mouse branch consumes the wheel in the view | removing the pin's subject → red |

The slow pty scenarios run in the full gate (the brief's acceptance runs FAST); the FAST section keeps the two
gates above plus the structural pins, and every skip stays visible.

### D8. Cross-change check and follow-ups

Open changes: `change-centric-discipline` (dispatch/verification/board — no console surface),
`tmux-gate-grant-redesign` (the tmux gate — no console surface). The archived `settings-choice-editors` baseline
(direct write, no read on the interaction path, the `choices` field) is read-only here: this change adds a field
next to `choices` and touches neither the editors nor the write path. Two delta files, `panel` and
`memory-and-deps`, one writer per delta.

**F1 (follow-up, not in scope): a group order the file can express.** The view's order is now the read's order;
if the user wants editable domains first, the honest shape is an explicit order column (like `suggest`), not a
console rule. Recorded so the decision is revisited with evidence rather than guessed.

**F2 (follow-up, not in scope): a snapshot for the settings view.** The view is pinned by the pty fixture only;
the pages 4/detail snapshots do not cover it, and this change does not add one (the row set is data-driven and a
snapshot would churn on every schema edit).
