# teamsmith pulse panel (`team monitor`)

The panel is the process that owns the pulse window: an [Ink](https://github.com/vadimdemedes/ink) + React
front end that draws one frame per data-refresh cadence (3s by default), runs one patrol tick per
`TEAM_PULSE_INTERVAL`, and consumes the existing data layer unchanged (`scripts/monitor.mjs --json` for the
activity stream, the bash readers for the team fields). `team monitor` never reads state files itself.

The team fields arrive **per block**: `data.ts` spawns one `team __panel-data --block <name>` child per block,
asynchronously and with its own timeout, and the renderer only ever reads the in-memory cache. A source that is
missing, unreadable, too slow or failing renders its own block as `—` and never delays the rest of the frame or a
keystroke (see `openspec/changes/pulse-console`).

```
team monitor                    # TUI in a terminal; plain text when stdout is not a TTY
team monitor --once             # one frame through the same renderer selection, plus the due tick
team monitor --print            # exactly one plain-text frame (no escape bytes, no state writes, no tick)
team monitor --json             # {"panel": {...}, "activity": [...]} (same guarantees as --print)
team monitor --headless         # the tick loop with no renderer — the shape `q` collapses the console into
team monitor --width N --height N
```

## The console surface (pulse-console B3; four pages, board page and detail view from `console-board-page`)

Four pages, switched by `Tab` or `1`–`4`, remembered in `state/panel-page` and restored on the next start:

| Page | Blocks |
|---|---|
| 1 overview | banner (PM/pending/queue/standby), capacity, project progress (board counts, changes, spec counts, decisions), recent deliveries, agent table, session activity, recent actions |
| 2 work | board rows (`done`/`dropped` collapse to the newest five), active changes with their phase, spec counts, recent decisions |
| 3 messages & logs | the deferred queue (list + read-only full text), inbox/threads, the patrol log, the capacity trend, health (skill version, `doctor`, last gates `—`) |
| 4 board | the board block as a kanban over the board's states, plus the entry's read-only markdown detail view while one is open |

**The board page** renders six lanes in `BOARD.md` legend order — every lane always present. A card's line is
its state glyph, id and title (the focused card's `agent · phase` pair rides the key band's free width), and an
empty lane folds by default; `c` or a click on a lane's header toggles any lane. At ≥100 columns the lanes sit
side by side and the unfolded lanes share the width: a folded lane takes a three-column frame (`╭─╮` over
`│…│`/`│⋮│` over `╰─╯`) in its fixed lane position, so the columns it does not use go to the unfolded lanes.
Below 100 columns they stack as one state-grouped column, where a folded lane stays its one labelled line
(`▸ 完成 8（已折叠）`) because folding there saves rows, and below 60 a card folds to one line (id + title, no
agent). `←`/`→` moves the focus between lanes and `↑`/`↓` between cards; a lane taller than the pane scrolls (the
wheel scrolls the lane under the cursor, other lanes keep their position) and its edge shows how many cards are
hidden above/below, the `done`/`dropped` windows anchored on the newest cards. The focused card carries `›` and
is tracked by entry **id**, so a reordering board never moves the focus; the entry disappearing lands it on that
lane's first card. While the focused card lives in a folded lane the frame carries the cursor and the band names
the lane (its label and card count).

**The detail view** is the focused card's read-only markdown: `Enter` (or a click on the already focused card)
opens the files discovered for that entry id — its task brief, delivery reports and review records — one per tab,
with `←`/`→` switching tabs and `↑`/`↓`/the wheel scrolling the document. The renderer is a self-contained
markdown subset (ATX headings, verbatim fences, display-width-aligned pipe tables, lists, blockquotes,
bold/code/link spans, `---` rules; anything else stays source text), the reader caps every file at 128 KiB and
marks the cut, and opening it writes nothing. `Esc` or `q` returns to the board page **without collapsing the
console** — the documented exception to `q` — and the `detail` block is spawned only while the view is open.

A block whose source has no data collapses and yields its space. `,` opens the **settings overlay** with exactly
five preferences — language (`zh`/`en`), default page, activity column, mouse, density — applied immediately and
persisted to `state/panel.conf`. A sixth key, `theme` (`dark`/`light`/`auto`), pins the palette and is not an
overlay item; `state/panel.conf` is read **by the TUI only**, so `--print`/`--json` stay byte-stable under any
preference. A missing, unreadable or corrupt file falls back to the defaults.

Every visible string comes from `src/strings/{zh,en}.ts`; the two tables' key sets, placeholders and non-empty
values are asserted in the gate (`tests/panel-strings.mjs`, wired into `tests/smoke.sh` §28), which also refuses a
CJK literal outside `src/strings/**`.

**Mouse** follows the preference: on enables SGR reporting (`ESC[?1000h` `ESC[?1006h`) for the console's lifetime
and disables it on exit; off emits no sequence at all. Every documented key — `m`, `f`, `s`, `,`, Tab, `1`–`4`,
`↑`/`↓`, `q`, and on the board page `←`/`→`, `c` and Enter — is a click target (Ink strips the leading ESC from
the SGR sequence; the parser tolerates both
spellings) and the wheel scrolls the page's list. On the board page the wheel scrolls the lane under the cursor
while the other lanes and the focus stay put, a click focuses a card and a click on the focused card opens its
detail view, and a click on a lane's header — or on a folded lane's three-column frame — toggles that lane's fold; in the detail view the tabs and both nav chips are targets and the replacement leaves no card target
behind (a replaced block is dead). The fixtures drive real SGR bytes through a pty (`tests/panel-b3-pty-mouse.py`)
and through a real terminal→tmux→pane chain (`tests/panel-b3-pty-tmux-mouse.py`), because `tmux send-keys` cannot inject `0x1b`.

**Collapse.** `q` rebuilds the patrol window in place as the headless tick loop (`team monitor --headless`): one
window, one process, the tick keeps logging. `team pulse up` restores the console in the same window and
`team pulse status` reports which shape the window is in. `Ctrl-C` still exits.

## The project-settings view (P22)

The settings overlay (`,`) carries one navigation row — `项目设置` / `Project settings` — which opens the
project-settings view. It replaces the page's blocks (title band, tabs and key band stay) and lists the project
contract from `team __panel-data --block settings`, whose payload is exactly `team config list --json`: one row
per schema key plus one per key the file carries that the schema does not know, grouped by the **effect class the
command reports** (`apply` / `restart` / `refuse`), with the file's value, the schema's default for an unset key,
the line's own inline comment and the command's warning/route text. `↑`/`↓` walk the row window (a click focuses a
row, a second click opens it), `/` opens the compose editor in `filter` mode (matches key or value; `esc` clears),
and `esc` returns to the overlay row it was opened from (`q` keeps its global collapse meaning). A `refuse` row
opens no editor — the command's route is shown. An editable row opens the compose line's `setting` mode holding the
file's value (or the schema default): the first `enter` runs `team config set … --dry-run` and renders the
confirmation (the class's timing; a danger reply needs one more `enter`), the second `enter` runs
`team config set … --yes` with the fingerprint pinned when the editor opened; the exit code maps to the receipt
and every settle re-reads the list and the audit footer. The seats block (one row per roster seat plus `pm`) shows
the model the CLI displays with its source badge (`配置` / `显式` / `历史记录`) and `enter` opens a picker (the
command's `known[]`, the removal, a free-text line) writing through `team config set-agent-model …`; the console
never restarts a seat — a running window keeps its model until its next `dispatch`/`resume`.

The view is console-only: `--print`/`--json` never read it, a parked console spawns no `settings` child (the
`detail` block's on-demand rule), and the reader rides the open view, never the frame cadence.

The pty fixtures for it are `tests/panel-p21.sh` (scenarios `settings write conflict seats readonly`, driven
through the real CLI behind an argv-logging wrapper).

## Compose and the three actions (pulse-console B2)

`m` opens a bottom input line **on any page**; the draft is edited at an insertion point (arrow keys, Home/End,
pi's word/line keys, kill ring and undo) and `C-j` inserts a line break while Enter sends through the guarded
delivery path. The receipt is one of three honest states — **delivered**, **queued** (the PM's box is busy) or
**held** (the payload is in `state/outbox/held/`). Esc keeps the draft in `state/draft.md` and the next `m`
brings it back; `C-o` hands the draft to `$EDITOR` with rendering suspended for the whole handoff (`C-e` is the
line-end key). `f` runs `team outbox flush` and `s`
toggles standby (switching it on asks for a one-line reason in the same input line). The console itself never
types into the PM's pane — every delivery is the owning command's, and the input line keeps refreshing the
rest of the frame while it is open.

The receipt is mapped from the send command's machine tokens, never from its human prose:
`draft-send.sh` runs the same guarded `team draft send` function in one shell (the CLI's
`TEAM_SEND_OUTCOME` / `TEAM_OUTBOX_RESULT` cannot cross a process boundary) and prints
`rc=<n> outcome=<token> result=<token>` for the console to parse. It lives under `scripts/panel/**` and
changes nothing in the CLI's own files.

The console's own files live in the project's state directory (`--state-dir`, passed by `team monitor`):
`state/draft.md` (the compose draft), `state/panel.conf` (the preferences) and `state/panel-page` (the last
page). They are registered in `references/config.md` §3.

## Layout

`layout.ts` is a pure function of (data, width, height, view state): the same inputs produce the same frame byte
for byte. Four width tiers — ≥160 columns two columns, 100–159 two compact columns, <100 one column, <60 the
minimal form (table columns dropped, times to the clock, states abbreviated) — with the documented degradation
order: side-by-side blocks become one column, a block folds into one summary line as the height runs out, then
blocks collapse. A terminal resize re-lays out the next frame live. The four tiers × both themes are pinned as
byte-exact snapshots in `tests/snapshots/` (`tests/panel-snapshots.sh`) — the overview page, plus the board page
and the detail view (the latter at 120 and 59 columns) — which also checks that a 60×8 pane is never overrun.

## What is committed, and why

| Path | What it is |
|---|---|
| `panel.js` | **the committed bundle** — the only file the runtime path uses. It runs with no `node_modules` and no network, so installing the skill needs no package manager |
| `src/*.tsx`, `src/*.ts` | the sources (layout, Ink app, width table, sanitizer, the bash data adapter, the CLI) |
| `src/strings/{zh,en}.ts` | the language tables (plain ESM + JSDoc, so the gate script can import them with any JS runtime) |
| `package.json`, `bun.lock` | the pinned build-time dependencies (`bun install --frozen-lockfile` is part of the build) |
| `build.sh` | the one build command; it writes `panel.js` |
| `draft-send.sh` | the send bridge: the guarded `team draft send` run in one shell, printing one machine line (rc + outcome tokens) for the receipt |
| `tsconfig.json` | types only (`bunx tsc --noEmit` is a development check, not a gate) |

Four extra machine exits exist for the fixtures (they are not part of the user-facing contract):
`--snapshot` prints one themed frame with its SGR bytes (the snapshot suite's input) — with `--overlay` it opens
the settings overlay in that frame, which is how the overlay's column plan is checked at every width — with
`--targets` it prints **only** the frame's click-target map (the fixtures' input for the "every key affordance is
also a mouse target" requirement), `--detail <ID>` renders that entry's detail view in the snapshot, and
`--palette` prints the declared palettes with their contrast pairs (`tests/panel-contrast.mjs` recomputes every
pair independently and refuses anything below 4.5:1).

## Rebuilding it

```sh
bun install --frozen-lockfile
bash skills/teamsmith/scripts/panel/build.sh
```

The build needs the network (it resolves the pinned dependencies) and Bun ≥ 1.3; it is a maintainer action, not
something a user of the skill ever runs. The result is deterministic: the same lockfile, sources and Bun version
produce the same bytes, so `cmp` against the committed `panel.js` is the release-time check (the smoke suite runs
the same comparison when Bun is available).

The committed artifact at the time of writing:

```
file:   skills/teamsmith/scripts/panel/panel.js
size and sha256: printed by build.sh (the smoke suite compares a fresh rebuild byte for byte)
pins:   ink 7.1.1 · react 19.3.0 · runtime floor: node >= 20 | bun >= 1.3
```

The bundle's header (first lines of `panel.js`) names the same pins and the build command; `node panel.js
--version` prints them too, so a stale bundle is visible without a rebuild.

## Notes for maintainers

- `package.json` is only read by the build and by a consistency check; nothing installs it at runtime. The
  repository stays free of `node_modules` (it is `.gitignore`d here).
- Ink imports `react-devtools-core` statically; it is pinned as a dependency so the bundle resolves it offline.
  `--external react-devtools-core` is *not* an option: it moves the failure to the runtime.
- `TEAM_MONITOR_UI=tui` forces the TUI renderer even when stdout is redirected. Ink writes no control bytes when
  stdout is not a TTY, so a piped sample cannot tell the two renderers apart — the real-pane capture is what
  pins the renderer.
- The panel's own sanitizer (`src/sanitize.ts`) runs on every string before layout; the bash data command also
  strips control bytes before JSON-encoding, because a raw control byte makes the JSON unparseable.
- The machine exits assemble the original eight blocks plus the overview's four (`board`, `changes`, `specs`,
  `decisions`); the page-2/3 readers (`outbox_list`, `inbox`, `patrol`, `health`) are console-only, so `--json`
  keeps its cost and its keys and a `doctor` run never sits on a machine exit's path.
