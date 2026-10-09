## MODIFIED Requirements

### Requirement: The console composes four pages and remembers the position

The TUI SHALL compose five pages — an overview (the status banner, the project-progress counts, the recent
deliveries, the agent table, the capacity sparkline, the recent events and the latest key-reply metadata), a work
page (the board rows, the active changes with their phases, the spec counts and the recent decisions), a
messages-and-logs page (the deferred queue, the inbox and threads, the patrol log, the capacity trend and the
health block), a board page (the kanban of "The board page is a kanban over the board's states") and a key-replies
page — plus a settings overlay. The first four pages MUST retain their existing numbers and meanings; page 5
SHALL be key replies, never project settings. A block whose source has no data SHALL collapse and yield its
space, except the key-reply summary and fixed key-replies page SHALL retain explicit empty/unavailable states
and the key-replies page SHALL retain its page identity. Tab and the
keys `1`–`5` SHALL switch pages, with Tab wrapping from 5 to 1. The current page SHALL be written to
`state/panel-page` and restored on the next start; a value outside `1`–`5` in that file SHALL fall back to the
default page, never fail the render. Pages are a TUI-only concept: `--print` and `--json` render the overview's
existing machine content, without reading key-reply blocks or exposing key-reply fields.

#### Scenario: Pages switch and the position survives a restart

- **GIVEN** the console running in a fixture pane of a fixture project
- **WHEN** `4` is sent, the console is quit and relaunched, and `1` is sent
- **THEN** the capture after `4` shows the board page's lanes, the relaunch opens on the board page
  (`state/panel-page` holds it), and `1` returns to the overview

#### Scenario: An out-of-range page file falls back

- **GIVEN** a fixture project whose `state/panel-page` holds `9`
- **WHEN** the console starts in a fixture pane
- **THEN** it renders the default page and exits no error

#### Scenario: An empty block collapses

- **GIVEN** a fixture project with no active changes
- **WHEN** the work page renders in a fixture pane
- **THEN** the changes block is absent from the capture and the page's other blocks render fully

#### Scenario: The messages page lists the queue

- **GIVEN** a fixture project with two queued outbox entries
- **WHEN** the messages page renders
- **THEN** both entries are listed with their ages

#### Scenario: Fifth page is fixed and remembered

- **WHEN** `5` selects key replies in an empty fixture, the console restarts, and Tab is pressed
- **THEN** the empty key-replies page remains identifiable, restart restores page 5, and Tab returns to page 1
- **AND** keys `1`–`4` still reach their original pages

#### Scenario: Narrow tabs remain reachable

- **WHEN** a 59-column fixture switches pages by `1`–`5`, Tab and mouse in both languages
- **THEN** the active tab's number and label remain visible and the page band provides reachable targets for all five pages without horizontal overflow

### Requirement: Settings are panel preferences in `state/panel.conf`, never the project contract

The settings overlay (`,`) SHALL edit exactly five preferences — language (`zh`/`en`), the default page (`1`–`5`),
the activity columns, the mouse and the density (`comfortable`/`compact`) — persisted in `state/panel.conf` and
applied immediately. The overlay SHALL additionally carry one navigation row — the project settings — which
opens the project-settings view; selecting it changes no preference, writes no file and leaves `panel.conf` alone,
and it is the only overlay row that is not a preference. A missing or corrupt `panel.conf` SHALL fall back to the
defaults and MUST NOT fail the render. The file is runtime state: it MUST NOT be read by `--print` or `--json`,
MUST NOT be read by any command other than the panel, and MUST NOT carry `TEAM_*` meanings — the overlay's
activity-columns toggle overrides `TEAM_MONITOR_ACTIVITY` for TUI sessions only. A `theme` key
(`dark`/`light`, absent = auto-detect from the terminal) MAY pin the theme; it is not an overlay item.

#### Scenario: A corrupt file falls back to defaults

- **GIVEN** a fixture project whose `state/panel.conf` holds garbage bytes
- **WHEN** `team monitor --once --print` runs and the console renders in a fixture pane
- **THEN** the print exits 0 and equals the no-preferences output apart from the timestamp, and the pane render
  uses the defaults

#### Scenario: A preference applies immediately and persists

- **GIVEN** the console running in a fixture pane with the mouse preference on
- **WHEN** the overlay toggles the mouse off, and the console is later quit and relaunched
- **THEN** the frames after the toggle emit no SGR mouse-enable sequence, and the relaunch still has it off

#### Scenario: Preferences never reach the machine exits

- **GIVEN** a fixture project and two different `state/panel.conf` files
- **WHEN** `team monitor --print` and `team monitor --json` each run under both
- **THEN** the two prints are identical apart from the timestamp and the two JSON outputs are identical

#### Scenario: The navigation row opens the view and writes no preference

- **GIVEN** the overlay open in a fixture pane, `state/panel.conf` recorded
- **WHEN** the navigation row is selected with `enter`, and `esc` returns to the overlay
- **THEN** the project-settings view rendered, `panel.conf` is byte-identical afterwards, and neither it nor the
  overlay's own frame carries a `TEAM_*` key of the contract

#### Scenario: Default-page preference includes key replies

- **WHEN** the default-page preference cycles through page 5 and persists it, and a later start has no page file
- **THEN** page 5 is available in the preference cycle and is restored as the default
- **AND** an invalid preference still falls back without failing the render

### Requirement: The console shows the project contract with its effect class, and refuses what it must not change

The settings overlay's navigation row SHALL open a **project-settings view** that replaces the page's blocks — the
title band, the page tabs and the key band stay, exactly as with the overlay itself, and the view is closed with
`esc` back to the overlay it was opened from without collapsing the console. The view SHALL list the project
contract (`.pi/team/config.sh`, `memory-and-deps`'s single-writer file): one row per key of the owning command's
schema plus one row per key the file itself carries that the schema does not know, and per row the key's **human
label** — from the console's zh/en tables, looked up by the key name the command reported — the current value
(the file's value, else the schema's default marked as unset), the key's **class** from the schema and the key's
own trailing inline comment when its line has one. The bare key name MUST NOT be the row's main text: every key of
the command's schema SHALL have a non-empty label in both tables (a fact the string-table gate asserts in both
directions — a schema key without a label and a label whose schema key is gone both fail it), and the raw key
SHALL appear only where the view aligns with the command line: the editor's prompt and its confirmation, and the
view's own line naming what to run for the focused row — `team config set <KEY> <value>` for a key the command can
set, the file to hand-edit plus the key for a `refuse` key, the category's own command for a category. A key the schema
does not know has no label and none SHALL be invented for it: its row falls back to the raw key name, which is
what the file and the command carry. The class vocabulary SHALL be the owning
command's, closed and rendered from the tables: `apply` (the next read of the file uses it), `restart` (a running
process holds the old value until it is restarted — the badge names the target: the pulse, the PM or a live
session) and `refuse` (the console must not change it). The row set and the classes MUST come from the owning
command's machine-readable read at render time; the bundle MUST NOT carry a second **schema** — no key list with
classes, defaults or a row order — so a key added to the command's schema appears in the view without rebuilding
`panel.js`, with the class, the default and the row that command gives it (and, having no label yet, its raw name
as the row's text). `↑`/`↓` SHALL move a row focus (group
headings are not focusable) and SHALL drag a window that counts the rows it hides at each edge; a click SHALL
focus a row and a click on the focused row SHALL open its editor, the kanban's rule. `/` SHALL open a filter line
that narrows the list to the rows whose **label, raw key or value** contains the filter text (case-insensitively) —
so the user who reads the labels and the user who knows the CLI's keyword both find the row — and `esc` SHALL clear
it without closing the view. A `refuse` row SHALL open no editor and its interaction SHALL surface the
owning command's refusal, which names the right route (hand-editing the file, `team add-agent`, …). The view's
own labels SHALL come from the zh/en tables, the key labels included: no visible text is written into the bundle.
The view is a console-only block: `--print` and `--json` MUST NOT
read or render it or add a project-settings field. Opening/closing the console-only view does not change machine output under identical monitor inputs; the specified model-policy, assignment and SID-reader changes are not frozen to old bytes. The view MUST NOT be a top-level page: the five-page
composition reserves page 5 for key replies and `state/panel-page` records only top-level pages.

#### Scenario: The rows carry the three classes and the unset key its default

- **GIVEN** a fixture contract whose file holds `TEAM_GATES`, `TEAM_PULSE_INTERVAL` and `TEAM_PROJECT`, and a
  schema whose `TEAM_DEFER_TTL` the file does not carry
- **WHEN** the project-settings view renders in a 160-column fixture pane
- **THEN** the three ruled rows carry the `apply`, `restart` and `refuse` badges, the `TEAM_DEFER_TTL` row shows
  the schema's default and the unset marker, every rendered label exists in both tables, and each row's main text
  is that key's label in the active language (no row reads `TEAM_…`)

#### Scenario: The raw key is exactly where the CLI is named

- **GIVEN** the view open with the focus on `TEAM_PULSE_INTERVAL` (an editable `restart` key), then on
  `TEAM_SESSION` (a `refuse` key) and then on the `routine` category
- **WHEN** each row is focused
- **THEN** the view's own command line reads `team config set TEAM_PULSE_INTERVAL <value>` for the first row, names
  the file to hand-edit together with `TEAM_SESSION` for the second and `team config set-task-model routine …` for the
  category, and the editor the first row opens is titled with the raw key

#### Scenario: A search by the raw key still finds the row

- **GIVEN** the view open on a contract with more keys than one frame shows
- **WHEN** `/` is pressed, `TEAM_PULSE_INTERVAL` is typed and applied
- **THEN** that row is listed with its label as the main text and the raw key named by the command line under it,
  and every other row is gone

#### Scenario: A key the schema does not know falls back to the raw name

- **GIVEN** a contract whose file carries `TEAM_HAND_ADDED` while the command's schema does not, and the view open
- **WHEN** the row renders and is focused
- **THEN** the row's main text is the raw key `TEAM_HAND_ADDED`, its badge is the unknown-key badge, and the
  command line says the key is not in the command's schema (no `team config set` is offered for it)

#### Scenario: The string tables cover the command's schema, both directions

- **GIVEN** the console tree with the owning command's schema table and the zh/en tables
- **WHEN** the string-table gate runs
- **THEN** it exits non-zero naming the key when one schema key has no label in either table, and equally when a
  label is left behind for a key the schema no longer carries; restoring the label (or the schema row) makes it
  pass

#### Scenario: The row set and the classes come from the command, not from the bundle

- **GIVEN** a scratch copy of the CLI whose schema carries an extra key `TEAM_ZZZ_TEST` and whose `TEAM_GATES`
  class is `refuse`
- **WHEN** the view renders against that CLI with the committed `panel.js` unchanged
- **THEN** the list carries a `TEAM_ZZZ_TEST` row, whose main text is the raw name (the tables never saw that key),
  and `TEAM_GATES`'s badge reads `refuse`

#### Scenario: A refuse row opens no editor and the route is named

- **GIVEN** the view open with the focus on `TEAM_SESSION`, and then on `TEAM_AGENTS`, the roster key, with the
  contract's sha256 recorded
- **WHEN** `enter` is pressed on each and `x` is typed
- **THEN** neither opens an editor, each receipt names the route (`team add-agent` / `team teardown` for the
  roster, hand-editing the file for an identity key), and the contract's sha256 is unchanged after both

#### Scenario: The filter narrows and clears

- **GIVEN** the view open on a contract with more keys than one frame shows
- **WHEN** `/` is pressed and `pulse` is typed, and then `esc`
- **THEN** the first frame lists only rows whose label, raw key or value contains `pulse` (the raw-key spelling
  finds the rows the CLI names, while their text stays the label), and the frame after `esc` lists every row again
  with the view still open

#### Scenario: The focus window and the clicks

- **GIVEN** a fixture contract of 40 keys in a pane that shows 12 rows, and the mouse preference on
- **WHEN** `↓` moves the focus past the last visible row, and then a click lands on a visible row and a second
  click on the same row
- **THEN** the window scrolls with the focus and counts the hidden rows above and below, the click moves the
  cursor glyph, and the second click opens that row's editor

#### Scenario: The origin is remembered and `q` keeps its meaning

- **GIVEN** the settings overlay open with the focus on the project-settings row
- **WHEN** `enter` opens the view and `esc` is pressed, and then the view is reopened and `q` is pressed
- **THEN** the overlay renders again with that row selected, and the `q` collapses the console (the global
  meaning, not a view-local exception)

#### Scenario: The machine exits stay byte-stable

- **GIVEN** a fixture project with identical monitor-visible configuration and committed routing/SID identity before and after its console-only settings view is opened/closed
- **WHEN** `team monitor --print` and `team monitor --json` run in each state
- **THEN** prints are identical apart from timestamp, JSON objects carry no project-settings field, and the machine paths do not read the settings overlay; separately specified model/SID changes remain observable

## ADDED Requirements

### Requirement: Overview links the latest key reply without reading its body
The TUI overview SHALL show the latest key-reply number, title, declared publisher and publication time, or an
explicit empty/unavailable state. Its visible `5` key hint and a mouse target SHALL lead to page 5's newest list;
opening the entry SHALL use the same body viewer as page 5. Summary reads MUST contain no body. A corrupt latest
slot MUST be labelled unavailable, not replaced with an older title labelled latest. Every static label SHALL
come from the zh/en tables.

#### Scenario: Latest answer is discoverable from the fixed entry
- **WHEN** a reply is published in a fixture and the overview's background summary refresh settles
- **THEN** its safe title and number appear with declared-publisher/time metadata, `5` and the click target reach the newest key-replies list, and Enter on that entry opens its body
- **AND** the overview did not read any body before the open operation

#### Scenario: Empty or corrupt latest source remains explicit
- **WHEN** the summary observes no store or an invalid latest slot
- **THEN** the overview renders empty or unavailable respectively, and page 5 remains reachable

### Requirement: Key replies page supports paged focus and a complete read-only body
Page 5 SHALL list `key-replies` metadata newest first, with at most 50 numbered slots per fetched page. `↑`/`↓`
SHALL move a focus whose row window follows it; the wheel SHALL scroll the list viewport without changing focus
or fetching hidden history. Visible `Older` / `Newer` controls SHALL fetch adjacent cursor pages using `←` / `→`
and mouse targets, with no automatic full-history load. Repeated Older operations MUST reach the oldest committed
slot, including through entirely corrupt pages. Newer SHALL follow the retained page cursor chain; `r` SHALL
refresh to the newest page and reset that chain. Focus MUST use stable numbers, not array positions; refreshing a
retained page MUST preserve a still-present focus and clamp only if that number is no longer on it. Enter or a
second click on the focused row SHALL open that number's complete safely rendered markdown body, showing its
title, declared publisher, publication time and number. A single click on another row SHALL only focus it.
`↑`/`↓`, PgUp/PgDn, Home/End and the wheel in the body SHALL scroll the document to all of its visible content;
`esc` or `q` SHALL return to the same list cursor, focus and viewport, not collapse the console. The viewer MUST
NOT truncate an accepted body, fetch links/images, execute text or offer edit/approve/read-status actions. A
missing/corrupt body SHALL show a local unavailable notice and the same return route. In the list, `q` SHALL
retain its global collapse meaning. Digit page keys and Tab SHALL retain top-level navigation outside composing
and existing settings modal ownership; leaving the reply viewer SHALL cancel its body request. The existing
human-to-PM compose entry SHALL remain available from page 5 and MUST NOT become a reply publisher.

#### Scenario: User reaches an old answer beyond the first page
- **WHEN** 123 replies exist and a user navigates Older twice, focuses number 1 and opens it
- **THEN** the complete first answer is readable, and `esc` returns to the same oldest page, number and viewport
- **AND** Newer twice returns to the original newest page while `r` starts a fresh newest cursor chain

#### Scenario: Long body and local errors have real return routes
- **WHEN** a 131072-byte accepted body with an end marker is opened, scrolled with End/PgUp/PgDn/wheel, and closed with `q`, and then a corrupt body's row is opened
- **THEN** the end marker is reachable, `q` restores the list rather than collapsing Pulse, and the corrupt viewer gives an unavailable notice with the same return behavior

#### Scenario: Keyboard and mouse use the same row and page actions
- **WHEN** a mouse-on fixture first clicks a row, clicks it again, scrolls the body and clicks Back, then clicks Older and Newer
- **THEN** the first click focuses, the second opens, Back restores list context, and paging matches `←`/`→`
- **AND** with mouse off no mouse-enable bytes or hidden mouse actions are added

#### Scenario: A corrupt page still offers continuation
- **WHEN** all 50 slots of a page are corrupt and valid older replies remain
- **THEN** the page displays unavailable numbered rows and an enabled Older route reaching those replies

#### Scenario: Compose and original page keys do not become publication
- **WHEN** the user opens `m` on page 5 or presses `1`–`4`/Tab outside the editor and settings modal
- **THEN** compose retains the existing PM draft/send meaning and navigation retains the original pages plus page 5
- **AND** neither action posts or modifies a key reply

### Requirement: Key reply blocks are async demand reads and absent from machine exits
The key-reply summary, current list page and selected body SHALL be separate asynchronous blocks over the bounded
`key-replies` readers. Only the TUI summary SHALL be scheduled outside page 5; list SHALL be wanted only on page
5, and body only while a reply viewer is open. No rendering or input callback SHALL read files, wait for a writer
lock, spawn synchronous processes, or await these blocks. Each block SHALL have a child timeout and output cap;
a failed/slow source SHALL degrade only its block, not delay keys, the clock, other blocks or patrol. Changing
list cursor/body number or leaving a view SHALL invalidate stale responses; a late response for a previous
request MUST NOT overwrite the new selection. Completed refreshes SHALL expose new publications without implying
that the publication receipt refreshed the screen. `--print`, `--json`, piped monitor and compatibility machine
assembly SHALL not schedule, read, render or export these blocks; publication alone MUST leave their output
unchanged under otherwise identical inputs. Reply reading and navigation SHALL not call post, repair, delivery
or patrol operations; the panel's preexisting tick ownership remains unchanged.

#### Scenario: Slow reader does not block input or a newer selection
- **WHEN** a list/body child is delayed beyond its timeout while the user switches pages or opens another number
- **THEN** keys and the clock remain responsive, only the affected block degrades, the abandoned child is bounded/cancelled, and its late response cannot replace the current page/body

#### Scenario: View demand closes body reads
- **WHEN** the TUI parks on overview, enters page 5, opens a reply, returns to its list and leaves page 5
- **THEN** recorded block argv show summary-only, summary plus one cursor list, an added single-number body, no body after return, and no list/body after leaving

#### Scenario: Machine paths never read key replies
- **WHEN** otherwise identical fixture monitor inputs are printed/JSON-exported before and after publication, with differing TUI preferences and damaged or blocked reply storage
- **THEN** prints are identical apart from timestamp and JSON structures are unchanged with no reply fields
- **AND** recorded reader calls and file accesses show zero reply reads and zero reader writes

### Requirement: Key replies remain legible across pane sizes and languages
The five-page band, latest summary, reply rows, paging/back controls, body metadata and empty/unavailable notices
SHALL use the existing zh/en string tables and display sanitization before layout. Status MUST NOT rely on color
alone. In 160/120/99/59-column bounded panes the layout SHALL retain a visible active-page identity, reachable
paging/back controls, a footer on the last row and scrolling access to all body content without horizontal
escape. Resize SHALL preserve the list cursor/focus and clamp document viewport to its new range. Both dark and
light themes SHALL retain the existing display-safety and contrast contracts.

#### Scenario: Width and language do not hide the return or older route
- **WHEN** fixtures render summary, empty/list/corrupt/list-continuation and long-body views at 160/120/99/59 columns in both languages and themes, then resize an open viewer
- **THEN** the page identity, Older/Newer/Back routes and unavailable markers remain legible, no line exceeds pane width, the footer remains last, and scroll access/list context survive

#### Scenario: Hostile strings are sanitized without losing the answer around them
- **WHEN** title/body/diagnostic inputs include OSC/CSI/BEL/C1/bidi controls and safe text on both sides
- **THEN** all snapshots and real pane captures contain the safe surrounding text but no executable controls or terminal hyperlinks
