## ADDED Requirements

### Requirement: The compose line edits at an insertion point, not only at its end

`m` on any page SHALL open the compose line with an editing cursor: the draft SHALL be addressed as codepoints with
an insertion point, and every text edit — a typed key, Backspace, a bracketed paste, `C-v` — SHALL apply at that
point, never at the end of the draft; opening a compose SHALL place the insertion point at the end of the draft it
restores from `state/draft.md`. `←` and `→` SHALL step the insertion point by one codepoint across explicit line
breaks and wrapped rows alike, `↑` and `↓` SHALL move it to the previous and next **visual** row at the same display
column, clamped to the shorter row, and `Home`/`End` (and their pi aliases, named by the key-map requirement) SHALL
move it to the start and the end of the **logical** line — the `\n`-separated line, so a wrapped line is one line
for them. A wide glyph (CJK, emoji) SHALL be one step of `←`/`→`, SHALL count as its two columns for the cursor
column and for `↑`/`↓`, and SHALL never be half-deleted. The terminal cursor SHALL be placed on the insertion point
— on the row the draft is drawn on, at that point's display column — so `tmux display -p '#{cursor_x}'` and
`tmux display -p '#{cursor_y}'` name the insertion point of the frame a `capture-pane` shows, for a draft on its
first row, on a wrapped row and after an explicit line break alike. While composing, the input area SHALL stay the
last block of the frame (nothing renders below it but the in-flight-send notice and the hint above the draft) and
SHALL be windowed: it MUST NOT show more than half of the pane's rows, it SHALL always contain the insertion
point's row, and the draft rows the window hides SHALL be counted on the window's edge. Everything the compose line
does today SHALL keep its meaning: Enter sends, Esc keeps the draft in `state/draft.md`, `C-o` relays to `$EDITOR`
(the key-map requirement's migration), a pasted `\r` stays one draft sent as one message, and the send path, the
three receipt states, the draft guard and the standby-reason rule are unchanged.

#### Scenario: Typing and Backspace act at the insertion point, and a wide glyph is one step

- **GIVEN** the console composing in a 120x30 fixture pane at the default (comfortable) density, the draft empty
- **WHEN** `ad` is typed, `←` is pressed, `中文` is typed, `←` is pressed and Backspace is pressed
- **THEN** the capture shows `> a文d` and `state/draft.md` holds `a文d`, and `tmux display -p '#{cursor_x}'` is 5
  (the tray's 2 columns plus the 3 display columns of `> a`)
- **AND** one `→` moves the insertion point by one codepoint over a glyph that is two columns wide
  (`#{cursor_x}` becomes 7), and the next Backspace removes the whole `文` (`state/draft.md` becomes `ad`)

#### Scenario: A wrapped draft keeps the cursor on the row it is drawn on

- **GIVEN** a 40-column fixture pane at the default density, `state/draft.md` holding 40 `x` characters (36 on the
  first drawn row and 4 on the wrapped row), and the console composing — the insertion point at the end of the
  draft, on the wrapped row, `#{cursor_x}` 8
- **WHEN** `Home` is pressed, then `Z` is typed
- **THEN** the capture's row `#{cursor_y}` is the first drawn row of the draft (the row that shows the 36 `x`) and
  `#{cursor_x}` is 5 — the tray, the prompt and the typed `Z` — because `Home` moved the insertion point to the
  logical line's start, which is that row
- **AND** `state/draft.md` is `Z` followed by the 40 `x`: the insertion landed where the cursor was moved, not at
  the end of the draft

#### Scenario: Vertical movement clamps to the shorter row

- **GIVEN** a 40-column fixture pane at the default density, `state/draft.md` holding `ab`, a line break and 8 `X`
  characters, and the console composing (the insertion point at the end of the draft, `#{cursor_x}` 12)
- **WHEN** `↑` is pressed
- **THEN** the capture's row `#{cursor_y}` is the row that shows `ab` and `#{cursor_x}` is 6 (the tray, the prompt
  and `ab`), while the capture still shows all 8 `X` on the other row

#### Scenario: Home, End and `↑` move between the rows of a broken line

- **GIVEN** a fixture project whose `state/draft.md` holds `alpha\nbeta` and the console composing at the default
  density in a 120x30 pane (the insertion point at the end of the draft, on the `beta` row, `#{cursor_x}` 8)
- **WHEN** `Home` is pressed, then `End`, then `↑`, then `X` is typed
- **THEN** the capture's row `#{cursor_y}` is the row that shows `alpha`, `#{cursor_x}` is 9 (the tray, the prompt
  and `alphX`), and `state/draft.md` reads `alphXa\nbeta` — the `↑` moved the insertion point to the other row, so
  the `X` did not land at the end of the draft

#### Scenario: A draft longer than the pane is windowed around the insertion point

- **GIVEN** a 120x20 fixture pane and `state/draft.md` holding 30 lines `L01`…`L30`, and the console composing (the
  insertion point at the end of the draft, on the `L30` row)
- **WHEN** the frame renders
- **THEN** the capture shows at most 10 draft rows, one of them holds `L30` and the insertion point, and a marker
  counts the draft rows the window hides above
- **AND** the overview frame still renders above the input area and `state/draft.md` still holds all 30 lines

#### Scenario: The window follows the insertion point

- **GIVEN** the same fixture with the compose open (the insertion point on the `L30` row)
- **WHEN** `↑` is pressed 12 times
- **THEN** the capture's window still contains the insertion point's row (now `L18`) and the hidden-rows marker
  counts fewer lines above than before

### Requirement: The compose line's key map is pi's editor key map

The compose line SHALL bind pi's editor keys (pi's `tui.editor.*` defaults) so that muscle memory carries over:
`←`/`→` and `ctrl+b`/`ctrl+f` step one codepoint; `alt+←`/`ctrl+←`/`alt+b` and `alt+→`/`ctrl+→`/`alt+f` step one
word; `Home`/`ctrl+a` and `End`/`ctrl+e` move to the logical line's start and end; `pageUp`/`pageDown` move by a
page of the draft's visual rows; `backspace` deletes the codepoint before the insertion point and
`delete`/`ctrl+d` the codepoint after it; `ctrl+w`/`alt+backspace` delete the word before the insertion point and
`alt+d`/`alt+delete` the word after it; `ctrl+u` and `ctrl+k` delete to the logical line's start and end. A word
SHALL be delimited the way pi delimits it — the platform word segmenter over the logical line — so punctuation and
CJK behave as they do in pi. Every one of these bindings SHALL work in both encodings a terminal may use: the legacy
one (`ctrl+a` as `0x01`, `alt+b` as `ESC b`, …) and the Kitty keyboard protocol one (`CSI <codepoint>;<modifiers>u`);
the pty fixtures send the Kitty bytes directly, so the bindings are testable without a Kitty-capable terminal. A
`ctrl`- or `alt`-modified key with no binding (e.g. `ctrl+c`) SHALL change nothing — it MUST NOT insert its letter
into the draft. Only `enter` SHALL submit and only `esc` SHALL cancel: no other key MAY leave the compose line.

#### Scenario: The word, line and forward-delete keys act where the insertion point is

- **GIVEN** a fixture project whose `state/draft.md` holds `alpha beta gamma` and the console composing at the
  default density in a 120x30 pane (the insertion point at the end of the draft, `#{cursor_x}` 18)
- **WHEN** `ctrl+w` is pressed, then `alt+b`, then `ctrl+d`, then `ctrl+k`, then `ctrl+a`, then `Z` is typed
- **THEN** `state/draft.md` reads `Zalpha ` and `#{cursor_x}` is 5 (the tray, the prompt and the `Z`): `ctrl+w`
  deleted `gamma` with its space, `alt+b` stepped one word left, `ctrl+d` deleted one codepoint forward, `ctrl+k`
  deleted to the logical line's end, and `ctrl+a` moved to the line's start where the `Z` landed
- **AND** `esc` is the only way the draft was left (`enter` was never pressed): the fixture's PM pane submitted
  nothing

#### Scenario: Line operations use the logical line, not the drawn row

- **GIVEN** a 40-column fixture pane at the default density and `state/draft.md` holding one 45-character line (two
  drawn rows) followed by a line break and `second`, and the console composing (the insertion point at the end of
  the draft)
- **WHEN** `↑` is pressed, then `ctrl+a`, then `ctrl+k`
- **THEN** `state/draft.md` is `\nsecond` — the whole 45-character logical line went, not just the 36 characters of
  the drawn row `↑` did not land on
- **AND** `tmux display -p '#{cursor_x}'` is 4 (the tray and the prompt) on the first drawn row, now empty

#### Scenario: The Kitty encoding of a bound key behaves like the legacy one

- **GIVEN** a fixture project whose `state/draft.md` holds `alpha beta` and the console composing (the insertion
  point at the end of the draft)
- **WHEN** the Kitty bytes for `ctrl+b` (`\x1b[98;5u`) are sent three times, and then the Kitty bytes for `alt+b`
  (`\x1b[98;3u`) once
- **THEN** `state/draft.md` is unchanged and `#{cursor_x}` is 10 — three codepoints back (`alpha b|eta`) and then one
  word back (`alpha |beta`; `│ > alpha ` is ten columns) — exactly as the same sequence sent as the legacy bytes
  (`0x02` ×3 then `ESC b`) moves it

### Requirement: The compose line has pi's kill ring and undo

Deleting in the compose line SHALL be recoverable the way pi makes it recoverable. Every deletion — `backspace`,
`delete`, `ctrl+w`, `alt+backspace`, `alt+d`, `alt+delete`, `ctrl+u`, `ctrl+k` — SHALL push its text onto a bounded
kill ring, and consecutive deletions of the same kind SHALL accumulate into the newest entry instead of filling the
ring (`ctrl+w` twice in a row is one entry holding both words, in the order they were cut); `ctrl+y` SHALL insert
the newest entry at the insertion point and `alt+y`, pressed immediately after a yank, SHALL replace that inserted
text with the next-older entry. `ctrl+-` SHALL undo the last edit — an insertion, a deletion, a yank or a paste —
restoring both the draft and the insertion point as they were before it; the undo history SHALL be bounded and SHALL
be discarded when the compose opens and when `$EDITOR` hands the draft back. `ctrl+-` is reported only through the
Kitty keyboard protocol (a terminal that does not report it leaves the key unbound, and the compose line produces
no text for it), so that path SHALL be exercised through the protocol's encoding.

#### Scenario: A deletion yanks back, and `alt+y` pops the older one

- **GIVEN** a fixture project whose `state/draft.md` holds `alpha beta gamma` and the console composing at the
  default density in a 120x30 pane (the insertion point at the end of the draft)
- **WHEN** `ctrl+w` is pressed (the word `gamma` and the space before it are cut), then `ctrl+a`, then `ctrl+k`
  (the rest of the line is cut as a newer entry), then `ctrl+y`, then `alt+y`
- **THEN** `state/draft.md` is ` gamma`: the first `ctrl+y` put `alpha beta` back and `alt+y` replaced it with the
  older entry — so both deletions were in the ring and the pop walked it

#### Scenario: Undo restores the draft and the insertion point

- **GIVEN** a fixture project whose `state/draft.md` holds `ad`, the insertion point between the two characters, and
  `#{cursor_x}` 5
- **WHEN** `Z` is typed, then the Kitty bytes for `ctrl+-` (`\x1b[45;5u`) are sent
- **THEN** the capture and `state/draft.md` hold `ad` again and `tmux display -p '#{cursor_x}'` is 5 — both the text
  and the insertion point came back, not just the text
- **AND** the same Kitty bytes sent once more change nothing (the history is empty at the draft it opened on)

### Requirement: The compose line edits multiple lines, and `ctrl+j` is the newline key

The compose line SHALL edit a multi-line draft: `ctrl+j` SHALL insert a line break at the insertion point, and
`enter` SHALL keep submitting the draft exactly as today. A terminal sends `\n` for `ctrl+j` and `\r` for `enter`,
so the compose line SHALL read a lone `\n` as the newline key and a lone `\r` as submit; the consequence SHALL be
explicit and documented rather than silent: a terminal that reports its Enter key as `\n` inserts a line break
instead of submitting (pi's editor behaves the same way, and such terminals are rare). `shift+enter` SHALL insert a
line break when the terminal reports it (`CSI 13;2u`, i.e. the Kitty keyboard protocol — see the key-map
requirement) and SHALL behave as `enter` when it does not, so no terminal shows a binding that silently does
nothing. A newline inside a paste SHALL keep today's meaning: it is part of the pasted text, the draft stays one
draft and it is sent as one message (the bracketed-paste handling is unchanged). In standby-reason mode the draft is
one line — a line break, typed or pasted, SHALL become a single space — so the reason handed to
`team standby on --reason` never contains a newline. The multi-line draft's path out of the console SHALL be the
unchanged one: `state/draft.md` holds LF, `team draft send` delivers a multi-line draft as one message (bracketed
paste) or as a file plus a pointer, and the delivery guard, the three receipts and the standby-reason rule are
untouched.

#### Scenario: The legacy `ctrl+j` byte inserts a line break, and Enter still submits

- **GIVEN** a fixture project with a fake TUI in the PM pane and the console composing `ad`, the insertion point at
  the end of the draft
- **WHEN** the raw `\n` byte is sent, then `b` is typed, then `\r`
- **THEN** the capture shows the draft on two rows and `state/draft.md` held `ad\nb` before the submit, the PM's
  fixture received exactly one message, and that message carried both lines

#### Scenario: The Kitty `ctrl+j` and `shift+enter` bytes insert a line break

- **GIVEN** the same fixture with the compose open and the draft `ad`
- **WHEN** the Kitty bytes for `ctrl+j` (`\x1b[106;5u`) are sent, `b` is typed, the Kitty bytes for `shift+enter`
  (`\x1b[13;2u`) are sent and `c` is typed
- **THEN** `state/draft.md` is `ad\nb\nc` and nothing was submitted

#### Scenario: A pasted newline is still one draft and one message

- **GIVEN** the same fixture with the compose open and the draft empty
- **WHEN** a three-line payload is pasted and `\r` is pressed
- **THEN** the draft held all three lines and the PM's fixture received exactly one message carrying all three —
  the newline key changed nothing about the paste path

#### Scenario: A standby reason is one line

- **GIVEN** a fixture project whose `state/draft.md` holds `half a thought` and a `team` CLI wrapper that logs each
  invocation with its arguments, and the console composing a standby reason (`s`)
- **WHEN** a three-line payload is pasted into the reason and `\r` is pressed
- **THEN** the wrapper's log shows `standby on --reason` with the three parts separated by spaces and no newline in
  the argument, the standby state's reason is that one line, and `state/draft.md` still holds `half a thought`

### Requirement: `C-v` pastes a clipboard image as a temporary file path

While composing, `C-v` SHALL paste the clipboard's image, when the clipboard offers one, as the path of a temporary
file: the image bytes SHALL be written to `${TMPDIR:-/tmp}/teamsmith-paste-<uuid>.<ext>` — `<ext>` from the MIME
type, `png` for `image/png` and `jpg`/`webp`/`gif` for those three — and that path SHALL be inserted at the
insertion point as one draft edit, in message mode and in standby-reason mode alike. The probe SHALL consult
`wl-paste` first and `xclip -selection clipboard` second, SHALL accept only those four MIME types, and SHALL be
bounded (the offered-type list within 1 s, the byte read within 3 s and 50 MiB), so a clipboard tool that never
answers cannot hold the console. The probe MUST NOT run on the render or refresh path: only a `C-v` press starts it,
the frame SHALL keep rendering while it runs, and typing SHALL keep landing in the draft. The panel MUST NOT delete
the file it wrote. When the clipboard holds no image (no image type offered, no bytes, a type outside the four, or
neither `wl-paste` nor `xclip` on `PATH`), `C-v` SHALL fall back to pasting the clipboard's text at the insertion
point; when that too is unavailable, `C-v` SHALL change nothing — draft, `state/draft.md`, the frame and the
console's liveness unaffected, with no error line and no new file. The standby reason SHALL NOT write
`state/draft.md` (the existing rule), whatever a paste into it does.

#### Scenario: An image clipboard becomes a path at the insertion point

- **GIVEN** a fixture whose `TMPDIR` is inside the fixture and whose `PATH` holds a fake `wl-paste` that offers
  `image/png` and returns 8 known bytes for the image read, and a compose holding `ad` with the insertion point
  between the two characters
- **WHEN** `C-v` is pressed and the paste settles
- **THEN** the fixture's `TMPDIR` holds exactly one `teamsmith-paste-*.png` file whose contents are those 8 bytes,
  and `state/draft.md` is `a<that path>d`
- **AND** the capture shows that path and the console is still composing, so the next typed character lands in the
  draft

#### Scenario: The probe is Wayland first, X11 second

- **GIVEN** a fixture `PATH` holding a fake `wl-paste` that exits non-zero and logs its call, and a fake `xclip`
  that logs its call, offers `image/png` for the offered-type list and returns 8 known bytes for the image read
- **WHEN** `C-v` is pressed and the paste settles
- **THEN** a `teamsmith-paste-*.png` file with those 8 bytes exists, its path is in the draft, and the call log
  names `wl-paste` before `xclip`

#### Scenario: No image falls back to the clipboard's text

- **GIVEN** a fixture whose fake `wl-paste` offers only `text/plain;charset=utf-8` and returns
  `from the clipboard` for the text read, and a compose holding `ad` with the insertion point between the two
  characters
- **WHEN** `C-v` is pressed and the paste settles
- **THEN** `state/draft.md` is `afrom the clipboardd`, the fixture's `TMPDIR` holds no `teamsmith-paste-*` file, and
  `xclip` was not called

#### Scenario: No clipboard tool changes nothing

- **GIVEN** a fixture whose `PATH` resolves neither `wl-paste` nor `xclip`, and a compose holding `half a thought`
- **WHEN** `C-v` is pressed
- **THEN** `state/draft.md`, the capture and the fixture's `TMPDIR` are byte-identical to before the press, no error
  line appears, and the console still answers (the next typed character appears and Enter still sends)

#### Scenario: A clipboard tool that never answers changes nothing within the bound

- **GIVEN** a fixture `PATH` whose fake `wl-paste` never exits, and a compose holding `half a thought`
- **WHEN** `C-v` is pressed
- **THEN** within 5 s no `teamsmith-paste-*` file exists, `state/draft.md` is still `half a thought`, and the console
  still answers (the next typed character appears and Esc still closes the compose with the draft kept)

#### Scenario: A paste into the standby reason leaves the message draft alone

- **GIVEN** a fixture project whose `state/draft.md` holds `half a thought` and an image clipboard, and the console
  composing a standby reason (`s`)
- **WHEN** `C-v` is pressed and the paste settles
- **THEN** the reason line holds the pasted image's path and `state/draft.md` still holds `half a thought`

### Requirement: The work page's board rows are focusable and open the same detail view

On the work page (page 2), the board block's rows SHALL be focusable exactly as the kanban page's cards are: the
frame SHALL mark one focused row with a cursor glyph and the `selected` tone (never colour alone), and it SHALL
report the row ids in the order it drew them, so `↑`/`↓` walk the drawn order — the first press with no focus yet
SHALL focus the first drawn row — and the focused row SHALL always be among the rows the block renders. `enter`, or
a click on the already focused row, SHALL open the same read-only detail view the board page opens (the `panel`
detail contract: the same discovery by entry id, the same 128 KiB bound, the same tabs, the same sanitizer); a click
on an unfocused row SHALL focus it. The detail view SHALL render on the page it was opened from, so `esc`/`q`
returns to that page — opening from the work page MUST NOT move the user to the board page, and opening from the
board page MUST NOT move the user to the work page. While a board row is focused the key band SHALL name the row
keys (`↑`/`↓` to move, `enter` to open), and `pageUp`/`pageDown` SHALL keep scrolling the page by keyboard, because
`↑`/`↓` no longer do on this page (they did before this change; the wheel keeps scrolling the page as it does
today). A block that is empty (no board row) or degraded to its summary line SHALL render no row, no cursor and no
row keys, and SHALL register no focus target — there SHALL be no focusable item on the work page that cannot be
opened.

#### Scenario: `↓` focuses a row and `enter` opens its detail without leaving the page

- **GIVEN** a fixture project with three board rows whose first row is a task brief with a report, and the console
  on the work page in a 120x30 fixture pane (`state/panel-page` holds `2`)
- **WHEN** `↓` is pressed, then `enter`
- **THEN** the capture after `↓` carries the focus cursor on the first drawn row (and no other row), and the capture
  after `enter` is the detail view of that entry (its file tabs and its first file's heading), still on page 2
  (`state/panel-page` still holds `2`)

#### Scenario: Closing returns to the page the detail was opened from

- **GIVEN** the same fixture, on the work page with a row's detail open, and then a fresh console on the board page
  with a card's detail open
- **WHEN** `q` is sent in the first console, and `esc` in the second
- **THEN** the first capture is the work page (`state/panel-page` `2`, the board block and its counts line visible)
  and the second is the board page (its lanes visible) — neither reader was dumped on the other page, and in both
  cases the window's process is still the console renderer

#### Scenario: A click focuses a row, a second click opens it

- **GIVEN** the console on the work page in a fixture pane with the mouse preference on
- **WHEN** a click lands on a board row, and a second click lands on the same (now focused) row
- **THEN** the first click moves the focus cursor onto that row and the second opens its detail view, exactly as on
  the board page

#### Scenario: An empty or degraded board has no dead item

- **GIVEN** a fixture project whose BOARD.md has no rows, the console on the work page in a 120x30 pane, and then a
  second fixture with rows in a 60x10 pane where the block degrades to its summary line
- **WHEN** `↓` and `enter` are pressed in each
- **THEN** neither capture carries a focus cursor and no detail view opens, and each frame's click-target map holds
  no `focus` and no `open-focused` action on the work page

## MODIFIED Requirements

### Requirement: A human can write to the PM from any page

`m` on any page SHALL open a bottom input line. Enter SHALL send the draft through the guarded delivery path
(`team draft send`; the `delivery-guard` capability owns the semantics) — the console itself MUST NOT paste or
send keys into the PM's pane. Esc SHALL cancel the compose and keep the draft in `state/draft.md`, restored on
the next compose. `C-o` SHALL hand the draft to `$EDITOR` and return to an intact frame, with rendering
suspended while the editor runs; `C-e` is the line-end key, not the editor relay (the migration to pi's key map,
which the key-map requirement owns), and the compose hint SHALL name both the editor relay's key and the newline
key in the frame, in both languages. The receipt SHALL be exactly one of three honest states — delivered, queued
(the PM's box is busy) or held (a durable copy under `outbox/held/`) — mapped from the send command's
machine-readable outcome and exit code, never parsed from human prose. While composing, the input line SHALL
pause refreshing and every other block SHALL keep refreshing; multi-line input, pasted or typed, SHALL stay one
draft (a `\r` is normalized — E6 §2.2) and SHALL be sent as one message (E6 §2.1).

#### Scenario: A busy box yields an honest queued receipt

- **GIVEN** a fixture PM pane whose input box holds a draft, and the console running in another fixture pane
- **WHEN** the human composes `hello` and presses Enter
- **THEN** the receipt shows queued, exactly one entry lands in `state/outbox/`, and the PM pane's draft is
  byte-identical

#### Scenario: Esc preserves the draft across a restart

- **GIVEN** the console running in a fixture pane
- **WHEN** the human types `half a thought`, presses Esc, quits, relaunches and presses `m`
- **THEN** the input line holds `half a thought` and `state/draft.md` survived the restart

#### Scenario: The editor relay returns to an intact frame

- **GIVEN** a compose holding `raw1`
- **WHEN** `C-o` opens `$EDITOR`, a second line is appended, the editor is saved and closed, and Enter is pressed
- **THEN** the frame is intact after the handoff, the draft holds both lines, and the send enqueues exactly one
  entry holding both lines

#### Scenario: A paste is one message

- **GIVEN** a compose open in a fixture pane
- **WHEN** a three-line payload is pasted and Enter is pressed
- **THEN** the draft held all three lines and exactly one outbox entry was written

#### Scenario: The draft survives a refresh

- **GIVEN** the five-second reader stub and a compose holding `before`
- **WHEN** a refresh completes and the human then types `after`
- **THEN** the draft reads `beforeafter` and another block's timestamp advanced during the compose

#### Scenario: `C-e` moves to the line end while `C-o` is the editor relay

- **GIVEN** a fixture project whose `state/draft.md` holds `ad`, `TEAM_PANEL_EDITOR` naming a script that writes a
  marker file and appends a line to the draft file, and the console composing with the insertion point between the
  two characters
- **WHEN** `C-e` is pressed
- **THEN** the script never ran (its marker file does not exist), the draft still reads `ad` and
  `tmux display -p '#{cursor_x}'` is 6 — the key moved to the line's end
- **AND** a following `C-o` runs the script exactly once, the appended line appears in the draft, and the frame is
  intact afterwards


### Requirement: Every key affordance is also a mouse target

With the mouse preference on, the console SHALL enable SGR mouse reporting for its lifetime and disable it on
exit, and every documented key — `m`, `f`, `s`, `,`, Tab, `1`–`4`, `↑`/`↓`, `q`, on the board page `←`/`→` and
Enter, and on the work page the board rows (a click focuses a row, a click on the focused row opens its detail) —
SHALL have a clickable target that acts identically; the wheel SHALL scroll the current page's scrollable region
(one offset per page, one line per notch on pages 1–3 — V15 F5 ruling; on the work page `↑`/`↓` move the board-row
focus and the wheel keeps scrolling the page; on the board page each lane carries its own offset and the wheel
SHALL scroll the lane under the cursor). A click on a kanban card SHALL focus it, and a click on the already
focused card SHALL open its detail view. Coordinates are 1:1: a click on a target activates that target (E6 §1.1 measured the full path, with
tmux's own mouse option in either state). With the preference off the console SHALL emit no mouse-reporting
sequence and clicks SHALL do nothing. The settings overlay is an in-page overlay, not a modal: it replaces the
page's blocks but keeps the title band, the tabs and the key band, so the footer chips still visible under it
stay clickable and act exactly as they do with the overlay closed, while the replaced blocks keep **no**
targets — a click at a block's former coordinates does nothing (V16 F-V16-4, ruled as the actual behaviour).
The same replacement rule SHALL apply to the detail view: while it is open, the kanban's cards keep no targets,
and so do the work page's board rows. `r` (rebuild the cached blocks on demand) is a named exception, because it is
a keyboard-only key: it has no chip in the key band and MUST NOT appear in the frame's target map, so "every
affordance is clickable" counts only the affordances the console shows (V16 F-V16-5). `pageUp`/`pageDown` are the
second named exception: they exist so the work page stays scrollable by keyboard once `↑`/`↓` move the board-row
focus, they carry no chip (the band is width-bounded), and they MUST NOT appear in the target map either.

#### Scenario: A click acts like the key

- **GIVEN** the console running in a fixture pane with the mouse preference on
- **WHEN** the pty driver injects a left press and release on the `m` hint's coordinates
- **THEN** the compose line opens

#### Scenario: A card click focuses, a second click opens

- **GIVEN** the console on the board page in a fixture pane with the mouse preference on
- **WHEN** a click lands on a card, and a second click lands on the same (now focused) card
- **THEN** the first click moves the focus marker onto that card and the second opens its detail view

#### Scenario: The wheel scrolls the page's scrollable region

- **GIVEN** the same fixture with more events than the events block can show, on one of pages 1–3
- **WHEN** wheel-down and wheel-up sequences are injected over the block
- **THEN** the visible window of events shifts down and back

#### Scenario: The wheel scrolls the lane under the cursor

- **GIVEN** the same fixture on the board page with a `done` lane holding more cards than its window
- **WHEN** wheel-down and wheel-up sequences are injected over that lane
- **THEN** that lane's visible window shifts down and back, the other lanes do not move, and the focus does not
  change

#### Scenario: Off means silent

- **GIVEN** the console running with the mouse preference off
- **WHEN** a frame is captured and a click is injected on the `m` hint
- **THEN** the capture contains no SGR mouse-enable sequence and the compose line stays closed

#### Scenario: The overlay keeps the visible footer live and the page behind it dead

- **GIVEN** the console running in a fixture pane with the mouse preference on and the settings overlay opened
  with `,`
- **WHEN** a click is injected on the still-visible `m` chip in the key band, and then one at the coordinates a
  page block occupied before the overlay opened
- **THEN** the compose line opens — the chip acted like the key, so the overlay does not modalize the footer —
  while the second click changes nothing: the blocks the overlay replaced keep no targets

#### Scenario: The refresh key is deliberately keyboard-only

- **GIVEN** a rendered frame and its click-target map with the mouse preference on
- **WHEN** the documented keys are enumerated against the map
- **THEN** every documented key except `r` has a target and the map carries no entry that refreshes the cached
  blocks, while pressing `r` still rebuilds them — the key has no clickable affordance by design


### Requirement: The console is read-only except through three commands

Every block the console shows SHALL come from read-only reads, and the only state-changing actions the console
offers SHALL be the three global keys, each invoking the owning command as a subprocess: `m`/Enter →
`team draft send`, `f` → `team outbox flush` (both `delivery-guard`), `s` → `team standby on|off` (`watchdog`).
The console process itself MUST NOT write patrol, queue, inbox, board or ledger files, and v1 SHALL NOT grow a
fourth action. The `C-v` clipboard paste is input editing, not an action: it invokes no `team` subcommand and writes
no file inside the project — its one write is the temporary copy of the clipboard image under the system temp
directory, which the console never deletes. This is the design's read-only discipline made falsifiable.

#### Scenario: The three actions invoke their owning commands

- **GIVEN** a fixture project with one queued outbox entry and the console running in a fixture pane
- **WHEN** `f` is pressed, then `s`, then `s` again
- **THEN** `team outbox flush` ran (its own log line is the evidence), standby was on after the first `s` and
  off after the second (`team watchdog status` reports it), and the console wrote nothing under `state/outbox/`
  itself

#### Scenario: Undocumented keys change nothing

- **GIVEN** a fixture project with the hashes of `state/`, `docs/` and the inbox recorded
- **WHEN** the console runs through several undocumented keys and every read-only navigation key
- **THEN** no file outside the console's own three (`state/draft.md`, `state/panel.conf`, `state/panel-page`)
  changed

#### Scenario: The paste writes outside the project and runs no command

- **GIVEN** a fixture project with the hashes of `state/`, `docs/` and the inbox recorded, an image clipboard, and a
  `team` CLI wrapper that logs every invocation
- **WHEN** `C-v` is pressed in the compose line and the paste settles
- **THEN** the temp file exists under `TMPDIR` with the image bytes and the draft holds its path, while no file
  outside the console's own three changed and the wrapper's log gained no line


### Requirement: All visible text comes from external zh/en string tables

Every string the console renders SHALL come from the string tables — one table per language, `zh` and `en` at
minimum — and the two tables SHALL hold identical key sets with the same value shapes and no empty values. A
machine-checkable assertion of the key-set equality SHALL run in the gate (`skills/teamsmith/tests/smoke.sh`).
Switching the language preference SHALL take effect on the next frame. The Chinese table SHALL name the PM↔agent
correspondence records `往来` — `线程` reads as an operating-system thread — so the messages page's block reads
`收件箱与往来`, its per-agent line reads `收件箱 {inbox} 条 · 往来 {thread} 条 · {age}` and its empty state reads
`（没有收件箱/往来记录）`; the `en` values of those three keys, the directory `docs/team/threads/`, the command
`team thread` and the English term `thread` SHALL NOT change. The tables SHALL also carry the migrated compose
hint's keys (the editor relay's and the newline key's) in both languages.

#### Scenario: The key sets are asserted equal

- **GIVEN** the shipped string tables
- **WHEN** the key-set assertion runs, and then runs again with one key deleted from the `en` table
- **THEN** the first run exits 0 and the second exits non-zero naming the missing key

#### Scenario: The language switches live

- **GIVEN** the console running in a fixture pane in `zh`
- **WHEN** the overlay switches the language to `en`
- **THEN** a following frame's static labels are English

#### Scenario: The messages page names the records 往来, not 线程

- **GIVEN** a fixture project whose inbox block has one agent row, the console on the messages page in `zh`, and the
  committed `panel.js` bundle
- **WHEN** the frame renders
- **THEN** the capture contains `收件箱与往来` and its counts line names `往来`, and no captured line contains
  `线程`
- **AND** `grep -c '线程' skills/teamsmith/scripts/panel/src/strings/zh.ts` prints 0 while the `en` table still
  carries `inbox and threads`


### Requirement: A focused card opens a read-only markdown detail view

Enter (or a click on the already focused card, on the board page's kanban or on the work page's board rows) SHALL
open a detail view that replaces the page's blocks — as
with the settings overlay, the title band, the page tabs and the key band stay — and renders the entry's
associated files as terminal markdown. The associated files SHALL be discovered read-only by entry id:
`docs/team/tasks/<ID>-*.md`, `docs/team/reports/<ID>-*.md` (files, not directories) and
`docs/team/reviews/<ID>.md` together with `docs/team/reviews/<ID>-*.md`, where the character after `<ID>` must
be `.` or `-`, so entry `P1` never matches `P17`'s files. Multiple files SHALL be presented as switchable tabs
(`←`/`→`, or a click on the tab), the first tab open by default. The renderer SHALL preserve the document's
structure — ATX headings as heading-tone lines, fenced code blocks verbatim in a dim tone, pipe tables aligned
by display width, lists and blockquotes kept, inline bold/code/links as tone spans — and SHALL render any
construct outside that subset as its source text, never dropped and never an error. File content SHALL be
bounded (a file over 128 KiB is cut and carries a truncation marker), SHALL pass the sanitizer like every other
disk string, and SHALL be assembled off the input path as a console-only data block that builds only while the
view is open; the first detail frame SHALL render within one second of Enter on the reference checkout. The
view SHALL be read-only: it adds no action key. Esc or `q` SHALL return to the page the view was opened from — the
board page from a card, the work page from a board row — and SHALL NOT collapse the console — a documented
exception to the global `q`, in force only while the detail view is open. The reader
MUST NOT serve a path outside the discovered set: a `--file` argument naming any other path SHALL fail.

#### Scenario: The three families are discovered and the id boundary holds

- **GIVEN** a fixture entry `P1` with `docs/team/tasks/P1-a.md`, `docs/team/reports/P1-dev.md`,
  `docs/team/reviews/P1.md` and `docs/team/reviews/P1-done.md`, and a decoy `docs/team/tasks/P17-b.md`
- **WHEN** `P1`'s detail view opens
- **THEN** the tab row names exactly four files (brief, report, review, done-review) and never the decoy

#### Scenario: Markdown structure survives the render

- **GIVEN** a fixture brief holding an ATX heading, a fenced code block, a pipe table, a bullet list and a link
- **WHEN** the detail view renders it
- **THEN** the table's columns are display-width aligned, the fence body appears verbatim, the heading renders
  without its `##` marker, and the link shows its text followed by the URL

#### Scenario: Hostile bytes in a file cannot inject escape sequences

- **GIVEN** a fixture file whose fenced code block embeds `ESC [2J`
- **WHEN** the detail view renders that file in a fixture pane and the pane is captured
- **THEN** the capture contains no `0x1b` byte and still shows the fence's visible text

#### Scenario: A large file is bounded and fast

- **GIVEN** a fixture report of 200 KiB
- **WHEN** `team __panel-data --block detail --id <ID>` runs and the detail view opens on that file
- **THEN** the reader exits 0 within one second, the view carries a truncation marker, and the first frame
  renders within one second of Enter on the reference checkout

#### Scenario: The reader refuses a path outside the discovered set

- **GIVEN** the fixture entry `P1` above
- **WHEN** `team __panel-data --block detail --id P1 --file ../../BOARD.md` runs, and when `--file` names
  `docs/team/tasks/P17-b.md`
- **THEN** both exit non-zero and neither prints the file's content

#### Scenario: Esc and `q` return without collapsing the console

- **GIVEN** the console on the board page in a fixture pane with a detail view open
- **WHEN** `q` is sent, and the detail is reopened and Esc is sent
- **THEN** both times the capture is back on the board page and the window's process is still the console
  renderer, not the headless tick loop

#### Scenario: The detail view writes nothing

- **GIVEN** a fixture project with the hashes of `state/` and `docs/` recorded
- **WHEN** the detail view is opened, its tabs switched, its document scrolled and the view closed
- **THEN** no file outside the console's own three (`state/draft.md`, `state/panel.conf`, `state/panel-page`)
  changed

