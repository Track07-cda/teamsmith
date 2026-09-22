# settings-view-groups · proposal

## Why

The project-settings view groups the contract by **effect class**, a table the bundle owns:
`settingsViewRows` (`scripts/panel/src/layout.ts:1205`) sorts the read's keys into three hardcoded buckets —
`立即生效` / `需要重启` / `只读`. The user, after using the console (2026-09-22), asked for the opposite: group by
**functional domain**, and carry "needs a restart" as a **row-level colour** (never colour alone). The schema
already knows the domains: twelve `# ---- … ----` sections (身份与账本布局 … 跨项目会议) cover all 111 keys
(12/11/16/11/3/14/13/7/4/6/10/4), and the class is nearly — but not exactly — a section property
(`分支与 forge` mixes 1 `apply` with 10 `refuse`), so neither dimension derives from the other.

The same use found the view has **no wheel**: the mouse branch (`App.tsx:1623`) handles the choice picker, the
detail view and the board lanes, and every other wheel event falls to `updateScroll` (`App.tsx:1650`), which
scrolls the **page behind the view** — the view's window is derived from the focus (`layout.ts:1331`), so the
wheel does nothing visible and silently moves a hidden page.

## What Changes

- **ADDED — `memory-and-deps`**: the schema row gains a tenth column, `group` (a closed ASCII token), and
  `team config list --json` reports it per key record — the row's token verbatim for a schema key, `""` for a key
  the file carries and the schema does not. The schema stays the single source (the `suggest` column's
  precedent): no second group table, and a key added to the schema lands under its group with the committed
  bundle. A fixture walk makes a missing or malformed token red.
- **ADDED — `panel`**: the view groups by that token — functional-domain headings in the read's order, headings
  not focusable, schema order kept inside a group; labels from the zh/en tables (`group_<token>`, asserted both
  directions); a row with no token (schema-unknown file keys) renders under a visible trailing fallback group
  instead of disappearing. The effect class stays on the **row** as its text badge with its tone (`restart` warn,
  `apply` plain, `refuse` dim).
- **MODIFIED — `panel`**: the mouse requirement's wheel scope adds the view — one row per notch over its own
  offset, focus unchanged, both edge counts following the window, and the wheel over the view MUST NOT move the
  page it was opened from; the focus keys push the window so the focused row is always visible.

## Capabilities

### Modified Capabilities

- `memory-and-deps`: the read reports each key's functional group.
- `panel`: the view's grouping and per-row class badge; the wheel's scope adds the view.

## Impact

`scripts/lib/cmd-config.sh` (tenth column on 111 rows, one JSON field); `references/config.md`;
`scripts/panel/src/{types,layout,App}.ts(x)` and `strings/{zh,en}.ts` plus the rebuilt `panel.js`;
`tests/config-cli.sh`, `tests/panel-strings.mjs`, `tests/panel-p21.sh` (its `立即生效` heading assertion is what
changes) and the FAST pins. Untouched: the writer (`team config set`'s validation, CAS, audit, danger list,
direct write), the choice editors, the read's existing fields, the human table, the machine exits, `panel.conf`,
and the page/lane/detail wheel.

## Acceptance

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
git status --porcelain
```

## What flips

- Deleting a key's tenth field makes the config walk red naming the key; restoring it is green.
- Moving a key's token (scratch CLI, committed bundle) moves its row under the other heading — no key→group table
  in the bundle.
- A token with no `group_<token>` label, or a label with no token, makes the strings gate red.
- Wheel over the view: before, the frame is identical and the page behind it moved; after, the window shifts one
  row per notch and the page's offset is unchanged. Dropping the badge tone makes the tone assertion red while
  the monochrome capture still carries the three classes as words.

## Boundaries

Planning only: this task writes `openspec/changes/settings-view-groups/**` and its report. Apply must not touch
the writer, the choice editors, the read's existing fields, the human table, the machine exits or `panel.conf`,
and must not group by effect class again. Implementation paths need the apply brief's explicit grant (OWNERSHIP):
`scripts/lib/cmd-config.sh`, `references/config.md` and `scripts/panel/**` are PM-owned; `tests/**` is
`agent:dev`'s.

## Evidence the report must contain

Both acceptance tails; the delta→requirement map for `panel` and `memory-and-deps`; requirement→item and
scenario→fixture maps; every flip's red/green tail (walk, no-hardcode move, label bijection, wheel before/after,
tone); the measured group census (12 tokens, 111 rows, per-token counts); and one line stating the writer's
validation, CAS, audit and danger list were not touched.
