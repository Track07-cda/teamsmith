# Propose: `panel-ergonomics` — a pi-style compose line, clipboard images, work-page detail entry, and `线程` → `往来记录`

## Why

The compose line is append-only (P19): a draft can be typed and truncated, never edited in the middle.
Follow-ups widened the ask: the keys must be **pi's** key map with real multi-line editing (`ctrl+j`), and the
**work page's** board rows must open the same detail view the kanban opens. Separately the Chinese UI calls the
PM↔agent correspondence `线程`, which reads as an OS thread, not as `docs/team/threads/<agent>.md`.

## What Changes

- **ADDED** — the compose line edits at an insertion point: a codepoint cursor (CJK/emoji safe) with `←`/`→`,
  visual-row `↑`/`↓`, logical-line `Home`/`End`/`ctrl+a`/`ctrl+e`, the terminal cursor placed on the point, the
  draft windowed to half the pane.
- **ADDED** — pi's key map: word moves (`alt`/`ctrl`+arrows, `alt+b`/`alt+f`), deletions (`ctrl+w`/`alt+backspace`,
  `alt+d`, `ctrl+u`, `ctrl+k`, `delete`/`ctrl+d`), a kill ring and undo, in both encodings; an unbound `ctrl`/`alt`
  key inserts nothing.
- **ADDED** — multi-line editing: `ctrl+j` inserts a break, **`enter` still submits** (`\n` is `ctrl+j`, `\r` is
  `enter`), `shift+enter` inserts one when the terminal reports it and otherwise behaves as `enter`; paste newlines
  and the standby reason keep their rules.
- **ADDED** — `C-v` pastes a clipboard image as `${TMPDIR:-/tmp}/teamsmith-paste-<uuid>.<ext>` at the cursor
  (`wl-paste` → `xclip`, bounded); no image → text paste; nothing available → nothing changes.
- **ADDED** — the work page's rows are focusable (`↑`/`↓`) and open the **same** detail view; `esc`/`q` returns to
  the page it was opened from; an empty or degraded block has no focusable item.
- **MODIFIED** — `C-e` becomes line-end and the editor relay moves to **`C-o`** (the PM's ruling) with the hint
  updated, plus the mouse map, the read-only clause, the detail requirement and the zh table as the delta specifies.
- Rebuild the committed `panel.js`.

## Capabilities

### Modified Capabilities

- `panel`: the compose editor, the clipboard paste, the work page's detail entry, the migrated editor key, the
  mouse map, the zh strings.
- `memory-and-deps`: the ledger directory's Chinese label.

## Impact

`panel/src/{compose,App,main,layout,strings}` plus new clipboard/keymap modules; the committed `panel.js`;
`scripts/lib/{cmd-docs,cmd-project}.sh`; `templates/threads-README.md`; `skills/teamsmith/tests/**`. No new runtime
dependency, no new `TEAM_*` key, no change to the send path or the performance contract (<1% of one core, uncached
frame ≤2 s).

## Acceptance (verbatim)

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
PATH="$HOME/.bun/bin:$PATH" openspec show panel-ergonomics --json | head -40
```

The brief's two lines name the old id `panel-compose-ergonomics`; the PM's follow-up renamed the change.

## Boundaries

- This phase writes only `openspec/changes/panel-ergonomics/**` and `docs/team/reports/P19-dev-bob.md`.
- Out of scope: the WSL/PowerShell and macOS clipboard paths, the native clipboard module, image conversion, cursor
  persistence, pi's editor history browsing, the PM-owned `docs/team/**` prose that still says `线程`, and any
  version bump, CHANGELOG heading or tag.
- `skills/teamsmith/scripts/**` is PM-owned (an apply brief must grant it); `skills/teamsmith/tests/**` is
  `agent:dev`'s.

## Evidence the report must contain

Both acceptance tails; the delta checked against `openspec/specs/`; the requirement → task map; and the observable
that is red on the current tree for every scenario.
