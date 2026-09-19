# Design: `panel-ergonomics` — a pi-style compose line, clipboard images, work-page detail entry, `线程` → `往来记录`

## Context

See proposal.md — Why. The current state the design works with (all under `skills/teamsmith/scripts/panel/`):

- **Compose model.** `src/compose.ts` is pure: `appendText`, a codepoint `backspace`, `intake(chunk, pasteOpen)`
  (bracketed paste split across reads; a lone `\r` **or** `\n` submits) and `inputLines(mode, draft, width)` —
  `\n`-split lines, each greedily wrapped by display width (`dispWidth`), every row but the first carrying the
  2-column continuation prefix. `App.tsx` renders the input area **last** (below the frame, the pad and the hint)
  because Ink leaves the terminal cursor at the end of the output and the IME anchors there (V15/F1; the fixture
  asserts `cursor_x` 10 after `中文ab`).
- **Renderer.** Ink `7.1.1` exports `useCursor()` (`setCursorPosition({x, y})`, 0-based, relative to the Ink output
  origin) with its own cursor-only update path, and its Kitty keyboard support is **opt-in**: `render(node,
  {kittyKeyboard})` queries `CSI ? u`, waits 200 ms, and enables `CSI > <flags> u` only if the terminal answers
  (`kitty.d.ts`/`ink.js`); the panel passes no such option today. Ink's parser already decodes the Kitty encodings
  whatever the terminal does (measured: `\x1b[106;5u` → `name 'j'`, `ctrl`; `\x1b[13;2u` → `name 'return'`, `shift`;
  `\x1b[45;5u` → `name '-'`, `ctrl`; and legacy `\n` → `name 'enter'` with **no** `return` flag, while `\r` is
  `name 'return'`).
- **pi's editor** (the parity target, `@earendil-works/pi-coding-agent` bundle): `tui.editor.cursorLineStart/End`
  call `moveToLineStart()` = `setCursorCol(0)` on `state.lines` (an array of `\n`-split **logical** lines);
  `tui.editor.cursorUp/Down` call `moveCursor(±1, 0)` which walks `buildVisualLineMap(width)` (**visual** rows);
  word moves use `findWordBackward/Forward(..., {segment: text => this.segment(text, "word")})`; deletions push into
  a `killRing` with `{prepend, accumulate}`; every edit calls `pushUndoSnapshot()`; `tui.input.newLine` is
  `shift+enter`, `ctrl+j` and `tui.input.submit` is `enter`; pi enables the Kitty protocol itself with flags 7
  (`DESIRED_KITTY_KEYBOARD_PROTOCOL_FLAGS = 7`).
- **Board page machinery.** `focus: {lane, id}`, `resolveFocus(rows, focus)`, `laneWindow(...)`, `cardLine(...)`,
  `cardAction(card, focused)` (a click focuses, a click on the focused card opens), the frame's `lanes` and
  `targets`, `openDetail(id)` → `detailId`/`detailIndex`/`detailScroll`, and the `detail` data block requested only
  while a view is open. The detail renders in `layout`'s `case 4` (it replaces the kanban); `esc`/`q` clears
  `detailId` and leaves the page alone, so returning to the origin is already the page the user is on.
- **Work page (page 2).** `case 2` pushes `boardBlock(left())` + changes/specs/decisions. `boardBlock` draws one row
  per BOARD.md entry (active rows first, then the kept `done`/`dropped` history, then a folded count) and registers
  no targets; the column budget decides whether the block renders fully or degrades to its **one-line summary**
  (`pickChrome`/`wrapBlock` never truncate a block's rows in the middle).
- **Strings and copy.** `src/strings/{zh,en}.ts` (`composeHint` names `C-e`; the inbox block says `线程`), and the
  same rename in `scripts/lib/cmd-docs.sh`, `scripts/lib/cmd-project.sh`, `templates/threads-README.md`. The
  committed `panel.js` carries the tables, so the rename's frame assertion is also the bundle-freshness check.

Two brief premises the design corrects, with evidence: (1) the panel does **not** probe `client_termfeatures` or
`extended-keys` today — `grep -rn 'termfeatures\|extended-keys\|kitty' skills/teamsmith/scripts/panel/src
skills/teamsmith/scripts/lib` finds nothing, and the only extended-key machinery in the tree is Ink's own opt-in
support; (2) the board rows live on **page 2** (the work page, `pageWork`), not page 1 — page 1 is the overview.

## Goals / Non-Goals

**Goals:**

- A compose line that behaves like pi's editor: an insertion point anywhere in a multi-line draft, pi's keys,
  pi's kill ring and undo, the terminal cursor on the point, and a draft window that keeps the point visible.
- `C-v` turning a clipboard image into a temp-file path at the insertion point, with silent, non-destructive
  fallbacks.
- The work page's board rows focusable and opening the same detail view, closing back onto the page it was opened
  from, with no focusable-but-unopenable item in an empty or degraded layout.
- The same visible Chinese vocabulary (`往来记录`) in the console, the CLI copy and the rendered threads README.

**Non-Goals (design level):**

- pi's editor **history** browsing (`cursorUp` at the top of the draft browses prompts in pi; the panel keeps ↑/↓
  inside the draft and clamps), pi's jump-to-character (`ctrl+]`), pi's copy/selection (`ctrl+c` with a selection),
  and pi's undo-on-Windows/WSL bindings.
- No native clipboard module, no WSL/PowerShell path, no image-format conversion, no cursor or undo persistence
  across restarts, no new `TEAM_*` key, no new console action, no version bump.

## Decisions

### 1. `panel` extended; the CLI copy rides `memory-and-deps`

Unchanged from the first review round: the console surface (compose, keys, mouse, strings, work page) is `panel`'s
contract, so six requirements are ADDED and five MODIFIED there; the only requirement naming the
`docs/team/threads/` ledger is `memory-and-deps`'s "The disk is the source of truth", so the rename's CLI/template
half is pinned there instead of inventing a capability for one word.

### 2. The insertion point is a codepoint index, and the line semantics are pi's — logical for line ops, visual for `↑`/`↓`

`compose.ts` gains a `{ text, cursor }` shape: `cursor` is an index into `[...text]` (codepoints), so a wide glyph is
one step and can never be half-deleted. Edits are pure: `insertAt`, `backspaceAt`, `deleteAt`, and
`moveCursor(text, cursor, motion, width)` for `left/right/wordLeft/wordRight/lineStart/lineEnd/up/down/pageUp/pageDown`.
`lineStart`/`lineEnd` are the **logical** line's bounds (`\n`-separated) because that is what pi's
`cursorLineStart/End` and `deleteToStartOfLine/End` do (`setCursorCol(0)` on a `state.lines` entry);
`up`/`down` move between **visual** rows at the same display column, clamped, because that is what pi's
`moveCursor(±1, 0)` does (`buildVisualLineMap(width)`). The row map is one function, `wrapRows(text, room)`,
returning each row's codepoint span; `inputLines()`, the cursor placement and the window all read it, so the drawn
text and the cursor can never disagree. `inputLines` keeps its output for the cursor-at-the-end case, which is what
the stored snapshots and the `cjk` fixture depend on, and composing keeps opening with the insertion point at the
end of the restored draft (today's behaviour; the cursor is still not persisted).

Alternative considered: browser-textarea semantics (Home/End on the drawn row) for consistency with `↑`/`↓` —
rejected because the user asked for pi's key map, and pi splits the two. Alternative considered: UTF-16 cursor
indices — rejected (they split surrogate pairs, the defect the current code avoids).

### 3. The draft area is windowed, and the real cursor comes from Ink's `useCursor`

The App computes `{x, y}` from the same memo that lays the frame out and hands it to `setCursorPosition`:
`y = (size.rows - inputRows - bottomRows - busyRow) + trayTop + (cursorRow - windowStart)` and
`x = (boxed ? 2 : 0) + cursorColumnInRow`; while not composing (or while a send is in flight) the position is
`undefined`, which hides the cursor. The window is the second half of this decision: today a 30-line draft pushes
the frame to its 3-row minimum and the terminal scrolls the draft's head off-screen, so the feature's own case (edit
anywhere in a long draft) would be unusable. The input area therefore shows at most half the pane's rows (at least
one draft row), always containing the insertion point's row, counting the rows it hides above on the window's top
edge; `pageUp`/`pageDown` move the cursor by a page of visual rows. The uncapped `--print` path is untouched (no
compose there), and the observers' bytes are unchanged.

Alternative considered: keep the input area unbounded (today's behaviour) — rejected: editing the first line of a
40-line draft is then impossible. Alternative considered: a hand-written CUP writer like the clock painter —
rejected: it duplicates Ink's cursor bookkeeping and races Ink's throttled writes.

### 4. One pure key decoder, so both encodings are testable without a Kitty terminal

The compose branch stops testing raw `input` strings and asks one pure function, `composeKey(input, key)`, for an
intent (`insert | newline | submit | cancel | edit | move | kill | yank | undo | …`). Both the legacy and the Kitty
encodings reach it as the *pairs* Ink's parser produces (`ctrl+j` is `('\n', {})` in the legacy encoding and
`('j', {ctrl:true})` from `CSI 106;5u`; `shift+enter` is `('\r', {return:true, shift:true})` from `CSI 13;2u`;
`ctrl+-` is `('-', {ctrl:true})` from `CSI 45;5u`), which is exactly why the pty fixtures can send the Kitty bytes
directly and assert the effect — no Kitty-capable terminal is needed for the proof. A `ctrl`- or `alt`-modified key
with no binding is consumed and inserts nothing; today such a key leaks its letter (`ctrl+c` types `c`), which the
key-map requirement now forbids.

### 5. pi's kill ring and undo are modelled, not imitated loosely

Every deletion pushes its text onto a bounded ring (10 entries); consecutive deletions of the same direction
accumulate into the head entry (`ctrl+w` twice = one entry, newest first) exactly as pi's `killRing.push(text,
{prepend, accumulate})` does. `ctrl+y` inserts the head; `alt+y` pops only immediately after a yank (pi's
`lastAction === 'yank'` guard), replacing the inserted text with the next-older entry. Undo is a bounded stack
(100) of `{text, cursor}` snapshots pushed before every mutation, popped by `ctrl+-`, discarded when the compose
opens and when `$EDITOR` hands the draft back — the editor may replace the whole draft, and an undo that resurrects
pre-editor text would be a lie. Undo is reachable only through the Kitty protocol (see §7), and the requirement says
so.

### 6. The panel enables Ink's Kitty support, and disables it around its own editor relay

`shift+enter` and `ctrl+-` exist only if the terminal reports them: Ink's support is opt-in, so the panel passes
`kittyKeyboard: { mode: 'auto' }` (Ink's default flags = `disambiguateEscapeCodes`) — auto mode is safe by
construction (an unsupported terminal never answers the `CSI ? u` query, and Ink leaves the protocol off) — and the
degradation is pinned: on such a terminal `shift+enter` submits exactly like `enter` (the terminal sends the same
byte) and `ctrl+-` does nothing. pi requests the same protocol with flags 7; the panel takes Ink's default flag set
because `reportEventTypes`/`reportAlternateKeys` are irrelevant here and every extra flag changes what the terminal
sends for ordinary keys. The panel's editor relay spawns `$EDITOR` on the inherited tty **without** Ink's suspend
API, so it must write the protocol's disable sequence (`CSI < u`) before the child and re-enable after it, or the
user's editor receives `CSI u` sequences it never asked for; the existing `editor` fixture is extended to assert
those bytes around the handoff.

### 7. Multi-line: `\r` submits, a lone `\n` inserts, and the LF-as-Enter case is stated out loud

The legacy encodings are `\r` for `enter` and `\n` for `ctrl+j`, and Ink reports `key.return` only for `\r`
(measured) — so the compose line's rule is: `key.return && !key.shift` submits, `key.ctrl && input === 'j'` or a
lone `\n` inserts a line break, `\r` inside a chunk stays a paste newline. The consequence is explicit in the spec
rather than hidden: a terminal whose Enter key reports `\n` now inserts a line break instead of submitting. That is
pi's behaviour too, such terminals are rare, and the Kitty protocol removes the ambiguity; the alternative (keep
`\n` as submit and drop `ctrl+j`) would fail the user's requirement. `shift+enter` is inserted only when the
terminal reports it (`return + shift`), otherwise it is byte-identical to `enter` — never a binding that silently
does nothing. In standby-reason mode a break becomes a space at insertion time, so the reason handed to
`team standby on --reason` is one line (the state file, the panel's status line and `watchdog.log` all assume one);
the message mode's path is untouched (`state/draft.md` holds LF; `draft-send.sh` already delivers a multi-line draft
as one message or as file-plus-pointer).

### 8. Clipboard probing: a small injectable module, `PATH` as the only test hook

Unchanged from the first review round: a new `src/clipboard.ts` returns `{kind:'image',bytes,mime} |
{kind:'text',text} | null`, probes `wl-paste --list-types` (≤1 s) then `wl-paste --type <mime> --no-newline`
(≤3 s, ≤50 MiB), falls back to `xclip -selection clipboard -t TARGETS -o` / `-t <mime> -o`, then to the text read
(`wl-paste --no-newline --type text`, else `xclip -selection clipboard -o`), and to `null` (a no-op). Only
png/jpeg/webp/gif are accepted (no converter in a no-`node_modules` bundle); a success is written to
`${TMPDIR:-/tmp}/teamsmith-paste-<uuid>.<ext>` and never deleted by the panel; the probe only runs on a `C-v` press
(a `probing` flag makes a second press while one is in flight a no-op). The only test seam is the executable name on
`PATH`; the fixtures put fakes first. Alternative considered: a `TEAM_PANEL_CLIPBOARD_CMD` key — rejected as config
surface the `PATH` shim already covers.

### 9. The work page reuses the kanban's focus state, and the frame reports the drawn row order

`boardBlock` gains the focus: the focused row is drawn with the kanban's cursor glyph and `selected` tone, and rows
register the same `focus`/`open-focused` actions the cards do. The App keeps one `focus` state for both pages (an
entry id, so it survives a refresh), and the layout reports `boardOrder` — the ids in the order it drew them — in
the frame, so `↑`/`↓` walk exactly what is on screen without duplicating the block's ordering rule (the same pattern
as the frame's `lanes` for the kanban). The first `↑`/`↓` with no focus focuses the first drawn row. The detail view
renders on the page it was opened from (`layout`'s `case 2` renders `detailBlock` when `view.detail` is set, as
`case 4` already does) and closing it only clears `detailId`, so the user never gets moved between pages. On the work
page `↑`/`↓` no longer scroll the page: the wheel still does, and `pageUp`/`pageDown` are added as the keyboard
route, documented as a second keyboard-only exception beside `r` (they carry no chip because the band is
width-bounded). Degradation needs no new rule: `pickChrome`/`wrapBlock` render a block whole or as its one-line
summary, so a degraded work page has no rows, hence no row targets and no dead item — the existing
"empty block collapses" behavior becomes the guarantee.

### 10. The editor key migration: `C-e` → `C-o`, with the hint as the visible half

pi binds `ctrl+e` to line end, so `C-e` cannot stay the editor relay. The PM ruled for pi's semantics; the migration
is visible in the frame (the compose hint in both languages names the newline key and `C-o`), the old scenario's
`C-e` becomes `C-o`, and a new scenario pins the migration itself (`C-e` moves to the line end and does **not** run
the editor). `C-o` is free in the panel: no page uses it, and the ink/pi convention for "open external editor" is
exactly that.

### 11. The rename ships in four places, and the bundle is rebuilt once at the end

`src/strings/zh.ts` (three values + the hint keys), `scripts/lib/cmd-docs.sh`, `scripts/lib/cmd-project.sh`,
`templates/threads-README.md`; `en.ts`, the directory, the command and the English term stay. Because the console
renders the tables through the committed bundle, the rename's frame assertion doubles as the bundle-freshness check,
and the bundle is rebuilt after the last source batch (each earlier batch rebuilds it too, so the pty fixtures always
exercise what the branch would ship).

## Risks / Trade-offs

- [Kitty protocol enabled on a terminal that answers the query but does not honour it] → Ink's enable is a flag
  write; the fixtures prove the *parser* path independently of the terminal, and the degradation (shift+enter =
  enter, ctrl+- = nothing) is what an unsupporting terminal already gives.
- [The panel's editor relay leaves the protocol on while `$EDITOR` runs] → write `CSI < u` before the child and
  re-enable after; the `editor` fixture asserts the bytes.
- [A terminal whose Enter reports `\n` now inserts a break instead of submitting] → stated in the requirement (not a
  silent change), pi behaves the same, and the Kitty protocol removes the ambiguity; the `paste` and `receipt`
  fixtures keep proving that `\r` submits.
- [The word segmenter is locale/ICU dependent] → `Intl.Segmenter` is used with an explicit granularity and the
  model fixture pins the cases (ASCII words with punctuation, CJK runs, whitespace runs) so a runtime without full
  ICU fails the fixture instead of drifting.
- [`↑`/`↓` on the work page stop scrolling the page] → the wheel keeps scrolling and `pageUp`/`pageDown` are added;
  the key band names the row keys on page 2, and the mouse requirement records the exception.
- [The focus could point at a row the block no longer draws] → the frame reports `boardOrder`; the App resolves the
  focus against it and falls back to the first drawn row (the `resolveFocus` rule, extended to the list).
- [The draft window changes the IME anchor] → the input area stays the frame's last block and the window follows the
  insertion point, so the anchor and the cursor stay on the draft; the `cjk` fixture (a short draft, no window) is
  unchanged.
- [A clipboard tool that hangs or floods] → 1 s/3 s timeouts and a 50 MiB read cap, asserted by a never-exiting
  fake; the panel keeps rendering while a probe is in flight.
- [The rename could break a fixture] → `grep -rn '线程' skills/teamsmith/tests/` finds no assertion on the old label;
  the new frame assertion is the one that must be added, and the smoke suite's key enumeration gains the work page's
  keys.
- [Scope size] → six batches, each independently verifiable; the PM can cut the kill ring/undo (§5) or the draft
  window (§3) as self-contained pieces without touching the rest.

## Migration Plan

Six apply batches, verified one by one (tasks.md): **B1** the cursor model, its placement and the draft window;
**B2** pi's key map, the kill ring and undo; **B3** multi-line editing plus the `C-e`→`C-o` migration; **B4** the
clipboard paste; **B5** the work page's rows and detail entry; **B6** the rename and the final bundle rebuild. Each
batch rebuilds `panel.js` and extends the pty fixtures, so every batch is shippable on its own. Rollback is
`git revert` per batch: no on-disk format, draft-file format or CLI interface changes, and the only cross-batch
state is the bundle (rebuild it from the reverted sources).

## Open Questions

None. The key conflict the brief left to the PM is ruled (`C-e` = line end, editor relay = `C-o`), and every other
open choice — keys, line/word semantics, encodings, kill ring and undo bounds, window size, probe order, temp path
and test seam, renaming scope, page-2 scroll keys — is fixed above.
