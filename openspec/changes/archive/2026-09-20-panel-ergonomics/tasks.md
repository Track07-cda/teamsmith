# Tasks: `panel-ergonomics`

Six apply briefs, dispatched and verified one by one, in this order: **B1** the compose cursor, its placement and
the draft window (panel: "The compose line edits at an insertion point, not only at its end"), **B2** pi's key map
with the kill ring and undo (panel: "The compose line's key map is pi's editor key map" and "The compose line has
pi's kill ring and undo"), **B3** multi-line editing and the editor-key migration (panel: "The compose line edits
multiple lines, and `ctrl+j` is the newline key" + the MODIFIED "A human can write to the PM from any page"),
**B4** the clipboard paste (panel: "`C-v` pastes a clipboard image as a temporary file path" + the MODIFIED
read-only requirement), **B5** the work page's board rows and detail entry (panel: "The work page's board rows are
focusable and open the same detail view" + the MODIFIED detail and mouse requirements), **B6** the rename (panel:
MODIFIED string tables + `memory-and-deps`: MODIFIED disk-ledger label) with the final bundle rebuild.

Coverage map (requirement → items): cursor → 1.1–1.8; key map → 2.1, 2.3–2.6; kill ring and undo → 2.2–2.5;
multi-line → 3.1, 3.2, 3.4–3.7; panel write (`C-o`) → 3.3, 3.4, 3.5; paste → 4.1–4.6; panel read-only → 4.3, 4.4;
work page → 5.1–5.5; panel detail → 5.1–5.3, 5.5; panel mouse → 5.2, 5.4; panel strings and `memory-and-deps` →
6.1–6.4; every requirement is also exercised by the gate item 7.1.

Path grants an apply brief must state (OWNERSHIP): `skills/teamsmith/scripts/**` (panel sources, the committed
bundle, `scripts/lib/*.sh`, `templates/**`) is PM-owned and must be granted explicitly; `skills/teamsmith/tests/**`
belongs to `agent:dev`; `openspec/changes/panel-ergonomics/**` belongs to the phase's owner. `openspec/specs/**`,
`docs/team/**` and the ledger stay PM-owned. Every batch ends with a `panel.js` rebuild so the pty fixtures exercise
what the branch would ship. `[real]` items need a real tmux pane/pty; each has a headless sibling.

## 1. B1 — the compose line edits at an insertion point (panel, ADDED: cursor)

- [x] 1.1 `src/compose.ts`: one `wrapRows(text, room)` map shared by `inputLines()`, the cursor placement and the
  window, plus the pure model (`insertAt`, `backspaceAt`, `moveCursor` for left/right/up/down/lineStart/lineEnd/page)
  over a codepoint index. `inputLines`' output for a cursor at the end of the draft must not change. Verify
  (headless sibling): `skills/teamsmith/tests/panel-compose-model.ts`, built from the tree with
  `bun build --target=node` and run with `node`, exits 0 over the CJK/emoji, wrap, clamp and line-bound cases, and
  names the case that fails.
- [x] 1.2 `src/App.tsx`: the compose branch gains the cursor state and the insertion-point edits (`←`/`→`/`↑`/`↓`,
  `Home`/`End`, `Backspace` at the point), the insertion point opens at the end of the restored draft, and the
  draft is persisted through the existing `updateDraft` path. Enter, Esc, the busy gate and the standby-reason rule
  stay as they are. Verify: the model fixture of 1.1 plus 1.5's assertions.
- [x] 1.3 `src/App.tsx`: hand the computed position to Ink's `useCursor().setCursorPosition` — `x` = tray prefix +
  the row's display columns before the insertion point, `y` = the input area's row minus the window's start plus the
  cursor's row — and `undefined` while not composing or while a send is in flight. Verify: 1.5's
  `#{cursor_x}`/`#{cursor_y}` assertions.
- [x] 1.4 `src/App.tsx` (with the row map from 1.1): the draft area is windowed — at most half the pane's rows, at
  least one draft row, always containing the insertion point's row, with the hidden rows above counted on the top
  edge. Verify: the window scenarios of 1.5 plus `--print`/`--json` byte-identity in 1.6.
- [x] 1.5 `skills/teamsmith/tests/panel-b2.sh`: a new `cursor` scenario asserting the requirement's scenarios —
  `ad`→`←`→`中文`→`←`→Backspace (`> a文d`, `state/draft.md` `a文d`, `#{cursor_x}` 5; then `→` → 7 and Backspace
  removes all of `文`); the wrapped 40-`x` draft in a 40-column pane (`Home` + `Z` → `#{cursor_y}` on the first row,
  `#{cursor_x}` 5, draft `Z` + 40 `x`); the `ab\nXXXXXXXX` clamp (`↑` → `#{cursor_y}` on the `ab` row,
  `#{cursor_x}` 6); `alpha\nbeta` (`Home`, `End`, `↑`, `X` → `alphXa\nbeta`, `#{cursor_x}` 9); the 120x20 pane with a
  30-line draft (≤10 draft rows, `L30`'s row present, a hidden-rows marker, `state/draft.md` still 30 lines); and
  the window following the point after 12 `↑` (`L18`'s row visible). Verify `[real]`:
  `bash skills/teamsmith/tests/panel-b2.sh cursor` exits 0; the assertion lines are pasted in the report.
- [x] 1.6 Regression: the `cjk`, `draft`, `editor`, `receipt`, `pause`, `paste`, `actions` and `readonly` scenarios
  stay green byte-unchanged; the stored snapshots (`bash skills/teamsmith/tests/panel-snapshots.sh`) exit 0 with no
  re-pin; `--print` and `--json` stay identical apart from the timestamp. Verify `[real]`: the runs' tails.
- [x] 1.7 Flip: on a scratch copy, force the cursor placement and the window to the draft's end (no window) and
  rebuild the bundle → `panel-b2.sh cursor` fails on the wrapped-row, the clamp and the window assertions; restore →
  exit 0. Verify: both tails in the report.
- [x] 1.8 The performance contract holds with a compose open: `bash skills/teamsmith/tests/panel-cpu.sh` reports
  <1% of one core and the uncached frame stays within 2 s. Verify `[real]`: the log in the report.

## 2. B2 — pi's key map, kill ring and undo (panel, ADDED ×2)

- [x] 2.1 `src/compose.ts`: the pure key decoder (`composeKey(input, key)` → an intent) covering `←`/`→` and
  `ctrl+b`/`ctrl+f`, `alt+←`/`ctrl+←`/`alt+b` and `alt+→`/`ctrl+→`/`alt+f`, `Home`/`ctrl+a` and `End`/`ctrl+e`,
  `pageUp`/`pageDown`, `backspace`, `delete`/`ctrl+d`, `ctrl+w`/`alt+backspace`, `alt+d`/`alt+delete`, `ctrl+u`,
  `ctrl+k`, `enter`, `esc` — in the legacy and the Kitty encodings — with word boundaries from `Intl.Segmenter` over
  the logical line, and with unbound `ctrl`/`alt` keys consumed (they insert nothing). Verify: the model fixture's
  key-decoder cases (1.1's fixture, extended) exit 0.
- [x] 2.2 `src/compose.ts`: the bounded kill ring (10, with same-direction accumulation and `{prepend}` ordering)
  and the bounded undo stack (100 `{text, cursor}` snapshots), plus `yank`, `yankPop` (only right after a yank) and
  `undo`. Verify: the model fixture's ring/undo cases exit 0, including "undo restores the cursor, not just the
  text".
- [x] 2.3 `src/App.tsx`: wire the intents (the ring and the undo stack live with the draft), clear the history when
  the compose opens and when `$EDITOR` hands the draft back. Verify: 2.4's pty assertions.
- [x] 2.4 `skills/teamsmith/tests/panel-b2.sh`: a new `keys` scenario asserting the requirements' scenarios — the
  word/line/forward-delete sequence (`ctrl+w`, `alt+b`, `ctrl+d`, `ctrl+k`, `ctrl+a`, `Z` on `alpha beta gamma` →
  `Zalpha `, `#{cursor_x}` 5, nothing submitted); the logical-line case (a 45-character line + `second`, `↑`,
  `ctrl+a`, `ctrl+k` → `\nsecond`, `#{cursor_x}` 4); the Kitty encoding of `ctrl+b`/`alt+b`
  (`\x1b[98;5u`×3, `\x1b[98;3u`) landing at the same insertion point the legacy bytes reach (`#{cursor_x}` 10); the ring's `ctrl+w`/`ctrl+a`/`ctrl+k`/`ctrl+y`/`alt+y`
  sequence ending on ` gamma`; and undo through `\x1b[45;5u` restoring `ad` with `#{cursor_x}` 5. Verify `[real]`:
  `bash skills/teamsmith/tests/panel-b2.sh keys` exits 0; the tails are pasted.
- [x] 2.5 Flip: on a scratch copy, replace the word rule with "whitespace runs only, no segmenter" and drop the ring
  accumulation, rebuild → the `keys` scenario fails on the word and ring assertions; restore → exit 0. Verify: both
  tails in the report.
- [x] 2.6 Regression: `cjk`, `draft`, `editor`, `receipt`, `pause`, `paste`, `actions`, `readonly` stay green; a
  `ctrl+c` in the compose line inserts no `c` and does not collapse the console (the new assertion); the frame's key
  hint still opens the compose from every page. Verify `[real]`: the run's tail.

## 3. B3 — multi-line editing and the `C-o` migration (panel, ADDED + MODIFIED write)

- [x] 3.1 `src/compose.ts` + `src/App.tsx`: a lone `\r` submits, a lone `\n` inserts a line break (the `intake`
  submit path for `\n` goes away), `ctrl+j` inserts one in both encodings and `shift+enter` only when the terminal
  reports it (`return + shift`), while `\r` inside a chunk stays a paste newline. Verify: 3.5's pty assertions.
- [x] 3.2 Standby-reason mode: a line break, typed or pasted, becomes a space at insertion time, so
  `team standby on --reason` never receives a newline. Verify: the `multiline` scenario's reason case.
- [x] 3.3 `src/main.tsx`: enable Ink's Kitty support (`kittyKeyboard: { mode: 'auto' }`) and write the protocol's
  disable sequence around the editor relay (`CSI < u` before the child, re-enable after), and move the relay from
  `C-e` to `C-o`. Verify: the extended `editor` scenario's byte assertions.
- [x] 3.4 `src/strings/{zh,en}.ts`: the compose and reason hints name the newline key and `C-o`; the key sets stay
  equal. Verify: `node skills/teamsmith/tests/panel-strings.mjs` exits 0 and the hints render in both languages.
- [x] 3.5 `skills/teamsmith/tests/panel-b2.sh`: a new `multiline` scenario (the legacy `\n` byte inserts a break,
  then `b`, then `\r` submits one two-line message; the Kitty `\x1b[106;5u` and `\x1b[13;2u` insert breaks without
  submitting; a pasted three-line payload is still one draft and one message; the reason mode's three-line paste
  reaches the `team` wrapper as one line with no newline) plus the `editor` scenario extended with `C-e` moving to
  the line end without running the editor and `C-o` running it once. Verify `[real]`:
  `bash skills/teamsmith/tests/panel-b2.sh multiline editor` exits 0; the tails are pasted.
- [x] 3.6 Flips: (a) restore the `\n`-submits behaviour → the legacy-`ctrl+j` assertion fails; (b) let the reason
  keep its newline → the reason assertion fails; restore both → green. Verify: both tails in the report.
- [x] 3.7 Regression: `paste`, `receipt`, `draft`, `pause` stay green (a paste is still one draft and one message,
  `\r` still submits) and `--print`/`--json` are unchanged. Verify `[real]`: the run's tail.

## 4. B4 — the clipboard image paste (panel, ADDED + MODIFIED read-only)

- [x] 4.1 A new `src/clipboard.ts` (subprocess runner injected) plus the `C-v` branch in `src/App.tsx`: the fixed
  probe order and forms of design.md §8, the four accepted MIME types, the 1 s/3 s/50 MiB bounds, the
  `${TMPDIR:-/tmp}/teamsmith-paste-<uuid>.<ext>` write, insertion at the live insertion point as one draft edit, the
  text fallback, the silent no-op, the `probing` flag, and no deletion of the file. Verify: 4.2 and 4.3.
- [x] 4.2 Headless sibling: `skills/teamsmith/tests/panel-clipboard-model.ts` (built with `bun`, run with `node`)
  drives the model against fake `wl-paste`/`xclip` scripts on a temporary `PATH`/`TMPDIR` and asserts the probe
  order, the MIME priority, the extension, the bytes landing in the file, the text fallback, the no-tool `null`, and
  the bound for a never-exiting fake. Verify: the fixture exits 0 and one deliberately broken step (4.5) turns it
  red.
- [x] 4.3 `skills/teamsmith/tests/panel-b2.sh`: a new `clipboard` scenario for the requirement's six scenarios (the
  image landing between `a` and `d` with the file's bytes checked; Wayland→X11 with the call log naming `wl-paste`
  first; the text fallback with `xclip` not called; the no-tool and never-exiting no-ops; the standby-reason paste
  leaving `state/draft.md` alone) plus the read-only sweep with the `team` wrapper's call log empty. Verify `[real]`:
  `bash skills/teamsmith/tests/panel-b2.sh clipboard` exits 0; the tails are pasted.
- [x] 4.4 No clipboard tool runs unless `C-v` is pressed: a fake-tool call log stays empty across a five-second idle
  window with the compose closed and open. Verify `[real]`: the log in the report.
- [x] 4.5 Flip: on a scratch copy, make a failed probe clear the draft (and skip the text fallback) and rebuild → the
  `clipboard` scenario's no-tool and text-fallback assertions fail; restore → exit 0. Verify: both tails.
- [x] 4.6 The performance contract again: `bash skills/teamsmith/tests/panel-cpu.sh` (<1% of one core with a compose
  open and one paste) and `--print`/`--json` unchanged from B3. Verify `[real]`: the logs in the report.

## 5. B5 — the work page's board rows and detail entry (panel, ADDED + MODIFIED ×2)

- [x] 5.1 `src/layout.ts`: `boardBlock` draws the focus cursor and the `selected` tone on the focused row and
  registers `focus`/`open-focused` targets; the frame reports `boardOrder` (the drawn row ids); `case 2` renders
  `detailBlock` while a detail is open (as `case 4` already does); the key band names the row keys on page 2. Verify:
  5.3's asserts plus the frame's target map (`--snapshot --targets`).
- [x] 5.2 `src/App.tsx`: `↑`/`↓` on page 2 walk `boardOrder` (the first press with no focus focuses the first drawn
  row; the focus falls back to the first drawn row when it leaves the board), `enter` and the row clicks open the
  detail, `pageUp`/`pageDown` scroll the page, and the mouse handler keeps the kanban's lane logic to page 4 only.
  Verify: 5.3's pty assertions.
- [x] 5.3 `skills/teamsmith/tests/panel-b3.sh`: a new `workdetail` scenario for the requirement's four scenarios —
  `↓` then `enter` opens the first row's detail and stays on page 2 (`state/panel-page` 2); closing returns to the
  page the detail was opened from on both pages (`q` on the work page, `esc` on the board page); a click focuses and
  a second click opens a row; an empty BOARD.md and a 60x10 pane offer no focus cursor, open nothing, and the target
  maps carry no `focus`/`open-focused` on the work page. Verify `[real]`:
  `bash skills/teamsmith/tests/panel-b3.sh workdetail` exits 0; the tails are pasted.
- [x] 5.4 Regression: the board page's `board`, `detail`, `pages`, `layout` and `mouse` scenarios stay green; the
  smoke suite's key/target enumeration gains the work page's keys and `pageUp`/`pageDown` stay out of the target map
  (the keyboard-only exception). Verify `[real]`: the runs' tails.
- [x] 5.5 Flip: on a scratch copy, make the work page's `enter` switch to page 4 before opening the detail (the
  rejected implementation), rebuild → the "closing returns to the page the detail was opened from" assertion fails;
  restore → exit 0. Verify: both tails in the report.

## 6. B6 — the rename and the final bundle (panel MODIFIED strings + `memory-and-deps` MODIFIED)

- [x] 6.1 `src/strings/zh.ts`: `inboxHeading` → `收件箱与往来`, `inboxLine` → `收件箱 {inbox} 条 · 往来 {thread} 条 ·
  {age}`, `inboxEmpty` → `（没有收件箱/往来记录）`; `src/strings/en.ts` keeps its three values. Verify:
  `node skills/teamsmith/tests/panel-strings.mjs` exits 0 and `grep -c '线程' …/strings/zh.ts` prints 0.
- [x] 6.2 The CLI copy and the template: `scripts/lib/cmd-docs.sh`'s empty-thread warning,
  `scripts/lib/cmd-project.sh`'s `thread` help line and `templates/threads-README.md`'s title plus its three
  mentions, while the directory `threads/`, the command `team thread` and the English word `thread` stay. Verify:
  `team thread dev` on a project without `docs/team/threads/dev.md` prints `往来记录` and that path;
  `team init --force` in a scratch project renders a README containing `往来记录` and no `线程`;
  `grep -rn '线程' scripts/lib/cmd-docs.sh scripts/lib/cmd-project.sh templates/threads-README.md` prints nothing.
- [x] 6.3 Final bundle rebuild and gate: `bun install --frozen-lockfile && bash
  skills/teamsmith/scripts/panel/build.sh` writes `skills/teamsmith/scripts/panel/panel.js`; commit it. Verify:
  `grep -c '往来' panel.js` is non-zero, `grep -c '线程' panel.js` prints 0, the smoke section `26-a` (sandbox
  rebuild, byte-identical `cmp`) is green where the sandbox build is available, and the messages-page frame in `zh`
  shows `收件箱与往来` with a counts line naming `往来` and no captured line containing `线程` (the `pages` scenario
  of `panel-b3.sh` plus a `--snapshot --page 3` render through `panel-b3-stub.sh`). Verify `[real]`: the captured
  lines are pasted in the report.
- [x] 6.4 Flip: on a scratch copy, restore `线程` in `src/strings/zh.ts`, rebuild the bundle → the frame assertion
  and the `zh.ts` grep go red; restore the label, rebuild → both green. Verify: both tails in the report.

## 7. Gates and evidence

- [x] 7.1 The gate of each batch and of the final branch:
  `PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh` exits 0
  (during development `TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh` is the same suite with the slow
  sections skipped; the final run is the full one). Verify: the tail of the final run in the report.
- [x] 7.2 The report carries, per requirement: the item that moves it, the fixture that can fail on it, the flip
  evidence, and the coverage map above with every item accounted for.
