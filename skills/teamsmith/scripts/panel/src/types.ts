// The wire contract between the bash data command (`team __panel-data`) and this renderer.
//
// `PanelData` is the **machine exits'** contract (`--print` / `--json`): the fields the pre-console
// panel had, unchanged apart from additive fields. The console-only readers (board rows, changes,
// specs, decisions, deliveries, the outbox list, inbox/threads, the patrol log, health) land in
// `PanelBlocks`, which the machine exits never render and `--json` never carries.
//
// Everything here is data; `layout.ts` is the only consumer and it is pure.

export type PmState = 'running' | 'starting' | 'absent' | 'foreign' | 'unknown'
export type AgentState = 'running' | 'exited' | 'absent'

/** The four console pages (TUI-only; `--print`/`--json` render the overview). */
export type PageId = 1 | 2 | 3 | 4
export type Density = 'comfortable' | 'compact'
export type ThemeName = 'dark' | 'light'
export type ThemeChoice = ThemeName | 'auto'

/** The settings overlay's five preferences (plus the pinned `theme`, which is not an overlay item). */
export type PrefName = 'lang' | 'defaultPage' | 'activity' | 'mouse' | 'density'

export interface PanelStandby {
  on: boolean
  reason: string
}

export interface PanelPm {
  state: PmState
  /** Short human detail behind the state (window name, command, "空提示符" …). */
  detail: string
  /** The evidence string the pulse uses for the same state (may be empty). */
  evidence: string
  /** M46: why the PM session has no inbox-watch registration ('' = the watch lane is fine). */
  delivery_warning?: string
}

export interface PanelPending {
  inbox: number
  reports: number
  todo: number
  wip: number
  review: number
  blocked: number
  stopped: number
  total: number
  /** `team_pending_text`'s human summary ('' when there is nothing). */
  text: string
}

export interface PanelOutbox {
  queued: number
  held: number
  oldest_age_s: number | null
  forced: number
}

export interface PanelCapacity {
  ram_avail_mb: number
  swap_free_mb: number
  agents: number
  spark: number[]
  /** `team_capacity_line` verbatim (the one-line fallback when the height folds it). */
  line: string
}

export interface PanelAgent {
  name: string
  state: AgentState
  task: string
  branch: string
  dirty: boolean
  /** Commits ahead of the protected branch; null when it cannot be evaluated. */
  ahead: number | null
  upstream_ahead: string
  model: string
  session_tokens: number
  session_window: number
  session_text: string
  /** agent-death-reason: classified cause of an abnormal death (absent on a healthy seat). */
  cause?: string
  /** Where the cause was read from; absent when there is no readable source. */
  cause_source?: 'pane' | 'session' | 'recorded'
  /** The raw evidence line beside the cause (sanitized, single line). */
  cause_line?: string
  /** The record time of the evidence, when known. */
  cause_time?: string
  /** Filled from the data layer's block for this agent (JSON only, not a table column). */
  elapsed?: string
  idle?: string
  idle_s?: number | null
  events?: number | null
}

export interface ActivityEvent {
  ts?: string
  kind?: string
  text?: string
}

export interface ActivityBlock {
  name?: string
  status?: string
  source?: string
  available?: boolean
  truncated?: boolean
  tail_limit?: number
  count?: number
  events?: ActivityEvent[]
  idle?: string
  elapsed?: string
  branch?: string
  [key: string]: unknown
}

export interface PanelData {
  /** Filled by the `frame` block; absent means that block is degraded (rendered as `—`). */
  project?: string
  timestamp?: string
  interval?: number
  standby?: PanelStandby
  pm?: PanelPm
  pending?: PanelPending
  outbox?: PanelOutbox
  capacity?: PanelCapacity
  agents?: PanelAgent[]
  recent?: string[]
  /** TEAM_AGENT_LOG_GLOB when it is set (the activity column's source hint). */
  activity_source?: string
}

// ------------------------------------------------------------------ console-only readers

/** One BOARD.md row (the raw status token; `done` rows collapse in the layout). */
export interface BoardRow {
  id: string
  title: string
  agent: string
  branch: string
  deps: string
  state: string
  /** The task brief's `phase:` header (`-` when there is no brief or no header) — console-only. */
  phase?: string
}

/** A recent delivery (a report file, newest first) for the overview's delivery block. */
export interface Delivery {
  id: string
  agent: string
  /** The report's mtime as a timestamp (the frame renders its clock — see the bash reader). */
  at: string
}

export interface BoardBlock {
  rows: BoardRow[]
  counts: Record<string, number>
  total: number
  /** Newest report files, already trimmed by the reader. */
  deliveries: Delivery[]
}

/** One task token of a change (P45/B2): the mapping's `<ID> <board-status>` plus its verdict. */
export interface ChangeTaskToken {
  id: string
  phase: string
  /** The BOARD row's status, or `-` when the id has no row. */
  board: string
  /** The review record's verdict (PASS/FAIL/…/none/missing), straight from team_review_verdict. */
  verdict: string
}

export interface ChangeRow {
  id: string
  done: number
  total: number
  /** The `openspec list` age token (`44m ago`), verbatim. */
  age: string
  /** explore | propose | apply | verify — derived from the artifacts on disk. */
  phase: string
  /** The change's mapped tasks (P45/B2). Absent on a reader that predates the field. */
  tasks?: ChangeTaskToken[]
  /** Mapped tasks beyond the token bound (`+N`); 0 when none. */
  tasks_more?: number
}

export interface ChangesBlock {
  /** False when neither the CLI nor the change directory could be read. */
  available: boolean
  source: string
  changes: ChangeRow[]
  count: number
}

export interface SpecRow {
  name: string
  requirements: number
}

export interface SpecsBlock {
  available: boolean
  count: number
  requirements: number
  specs: SpecRow[]
}

export interface DecisionsBlock {
  count: number
  /** The newest decision headings, newest first (`D26 · 2026-09-16 · 决定 — …`). */
  recent: string[]
}

/** One outbox entry for the messages page; `text` is the sanitized payload (read-only). */
export interface QueueEntry {
  name: string
  state: 'queued' | 'held'
  age_s: number | null
  target: string
  kind: string
  from: string
  reason: string
  text: string
}

export interface OutboxListBlock {
  entries: QueueEntry[]
  queued: number
  held: number
}

export interface InboxRow {
  agent: string
  inbox_new: number
  inbox_lines: number
  inbox_age_s: number | null
  inbox_tail: string
  thread_lines: number
  thread_age_s: number | null
  thread_tail: string
}

export interface InboxBlock {
  agents: InboxRow[]
}

export interface PatrolBlock {
  /** watchdog.log tail, oldest first. */
  lines: string[]
  count: number
}

export interface HealthBlock {
  version: string
  doc_version: string
  /** ok | warn | fail | unavailable. */
  doctor: string
  /** Always `—` in v1 (no gate record point; tasks.md 4.2 / design §8). */
  gates: string
}

/** One contract key as `team config list --json` reports it (P22/B2). */
export interface SettingsKey {
  name: string
  /** apply | restart | refuse — the owning command's closed vocabulary. */
  class: 'apply' | 'restart' | 'refuse'
  kind: string
  /** plain | export — the assignment form the writer produces. */
  form: string
  /** The file's value ('' when the file does not carry the key). */
  value: string
  default: string
  /** Whether the file itself carries the key. */
  set: boolean
  /** The line's own inline comment, verbatim (may be empty). */
  comment: string
  /** A command-side warning (an unknown seat token in TEAM_AGENT_MODELS, …). */
  warning: string
  /** The refusal's route for a read-only key (`team add-agent`, hand-edit the file, …). */
  route?: string
  /**
   * The key's schema-derived choice set (M55), verbatim from `team config list --json`. The
   * console reads its options from here and from nowhere else: a key or a value added to the
   * command's schema appears without rebuilding the bundle. Absent against an older command.
   */
  choices?: SettingsChoices
  /**
   * The key's functional domain (P30): the schema row's tenth column, verbatim from `team config
   * list --json` ('' for a key the schema does not know, and for a schema row that declares none).
   * The view's headings are looked up by this token (`group_<token>`); the bundle keeps no
   * key→group table. Absent against an older command.
   */
  group?: string
  /** False for a key in the file the schema does not know (read-only row). */
  known?: boolean
}

/** One key's choice set as the owning command reports it (M55). */
export interface SettingsChoices {
  /** schema | known | none — where the vocabulary came from. */
  source: string
  /** The ordered vocabulary; `[]` when the kind has none. */
  values: string[]
  /** The numeric kinds' accepted lower bound as a string ('' = unbounded). */
  min: string
  /** The numeric kinds' accepted upper bound as a string ('' = unbounded). */
  max: string
  /** True when the writer accepts the empty value for this key (decides a clear entry). */
  empty: boolean
  /** The command's own note; a `path` kind carries its existence rule (file|dir|exec|any). */
  note: string
}

/** One drawn entry of the choice picker (M55). */
export interface SettingsChoiceEntry {
  /** The value the entry carries ('' for keep-unset/clear/free). */
  value: string
  /** What the entry is: a special action or a value from the command's own vocabulary. */
  kind: 'keep-unset' | 'current' | 'default' | 'value' | 'clear' | 'free'
  /** What the compose editor opens with when this entry is accepted (defaults to `value`). */
  seed?: string
  /** The path kind's existence mark (the command's note carries the rule). */
  mark?: 'exists' | 'missing' | 'not-exec'
}

/** The open choice picker: the row it edits, the kind and the command's entries. */
export interface SettingsChoicePicker {
  /** The row index in the filtered settings row list (the focus returns here on `esc`). */
  row: number
  /** The raw key of the row being edited. */
  key: string
  /** The schema kind the entries were built for (drives the labels and the reason line). */
  kind: string
  /** The entries in the order the requirement fixes: keep-unset? current? default? values… then kind actions. */
  entries: SettingsChoiceEntry[]
  /** The selected entry. */
  index: number
  /** The accepted interval the numeric kinds display (null when the kind names none). */
  interval: { min: string; max: string } | null
}

/** One seat's displayed model and its CLI-computed source (P22/B4). */
export interface SettingsSeat {
  agent: string
  model: string
  source: 'config' | 'explicit' | 'record'
  override: boolean
}

/** The `settings` block: exactly `team config list --json` (P22/B2). */
export interface SettingsBlock {
  path: string
  fingerprint: string
  mtime: string
  keys: SettingsKey[]
  models: { default: string; known: string[]; seats: SettingsSeat[] }
  audit: string[]
}

/** One file discovered for an entry's detail view (read-only, P18/B3). */
export interface DetailFile {
  /** The tab label: `brief`, `report:<agent>`, `review` or `review:<suffix>`. */
  tab: string
  /** The file's basename. */
  name: string
  /** The repo-relative path — the only value the reader's `--file` accepts. */
  path: string
  /** Bytes on disk. */
  size: number
  /** True when the file is over the 128 KiB read cap. */
  truncated: boolean
}

/** The on-demand `detail` block: the discovered file list plus the served file's text. */
export interface DetailBlock {
  id: string
  count: number
  /** The repo-relative path whose text this block carries (`''` when the entry has no files). */
  file: string
  /** The served file's text, capped at 128 KiB by the reader. */
  text: string
  /** True when the served file was cut at the cap. */
  truncated: boolean
  files: DetailFile[]
}

/** The console-only readers, keyed by their block name; absent = that source failed. */
export interface PanelBlocks {
  board?: BoardBlock
  changes?: ChangesBlock
  specs?: SpecsBlock
  decisions?: DecisionsBlock
  outbox_list?: OutboxListBlock
  inbox?: InboxBlock
  patrol?: PatrolBlock
  health?: HealthBlock
  /** The project-settings view's on-demand reader (P22/B2); absent while the view is closed. */
  settings?: SettingsBlock
  /** Built only while the detail view is open (design §8); never spawned on a parked page. */
  detail?: DetailBlock
}

// ------------------------------------------------------------------ layout

export type Tone =
  | 'title'
  | 'text'
  | 'dim'
  | 'heading'
  | 'accent'
  | 'ok'
  | 'warn'
  | 'err'
  | 'selected'

export interface Segment {
  text: string
  tone: Tone
  /**
   * True for the title band's clock: the App's own 1s ticker owns that text in the TUI (the `now`
   * state re-feeds `panel.timestamp` every second), while `--print`/`--json`/snapshots render
   * `text` verbatim. It must never be merged into a neighbour, and a frame whose only difference
   * is this segment is "unchanged" (`frameSignature`) — that is what keeps the redraw off the CPU
   * red line.
   */
  clock?: boolean
}

export type Line = Segment[]

/** A clickable span on a rendered row. */
export interface Hit {
  start: number
  end: number
  action: Action
}

export type Action =
  | { kind: 'compose' }
  | { kind: 'flush' }
  | { kind: 'standby' }
  | { kind: 'settings' }
  | { kind: 'page'; page: PageId }
  | { kind: 'page-cycle' }
  | { kind: 'scroll'; delta: number }
  | { kind: 'quit' }
  | { kind: 'close-overlay' }
  | { kind: 'toggle'; pref: PrefName }
  | { kind: 'view-entry'; index: number }
  | { kind: 'queue-list' }
  /** Board page: put the focus on this card (a click on an unfocused card). */
  | { kind: 'focus'; lane: string; id: string; nth?: number }
  /** Board page: open the focused card's detail view (a click on the already focused card). */
  | { kind: 'open-focused'; lane: string }
  /** Board page: move the focus one lane left/right (the key band's `←`/`→` chip). */
  | { kind: 'lane-move'; delta: number }
  /** Board page: move the focus one card up/down inside its lane (the `↑`/`↓` chip). */
  | { kind: 'card-move'; delta: number }
  /** Board page: the wheel's lane hit — scroll this lane's window (never the focus). */
  | { kind: 'lane-scroll'; lane: string; delta: number }
  /** Detail view: switch to the file tab at `index` (a click on the tab row). */
  | { kind: 'detail-tab'; index: number }
  /** Detail view: move the file tab one step (the key band's ←/→ chip). */
  | { kind: 'detail-tab-move'; delta: number }
  /** Detail view: scroll the document (the ↑/↓ chip). */
  | { kind: 'detail-scroll'; delta: number }
  /** Detail view: leave it (Esc/q) without collapsing the console. */
  | { kind: 'detail-close' }
  /** Project-settings view: close it (Esc) back to the overlay it was opened from. */
  | { kind: 'settings-close' }
  /** Project-settings view: focus a row (a click on an unfocused row). */
  | { kind: 'settings-focus'; index: number }
  /** Project-settings view: open the focused row (Enter / a click on the focused row). */
  | { kind: 'settings-open'; index: number }
  /** Project-settings view: open the filter line (the `/` chip). */
  | { kind: 'settings-filter' }
  /** Project-settings view: scroll the row window by the wheel (the focus stays). */
  | { kind: 'settings-scroll'; delta: number }
  /** The choice picker (M55): accept the focused entry (index -1) or the one clicked. */
  | { kind: 'choice-pick'; index: number }
  /** The choice picker: move the selection (↑/↓ and the wheel — the window follows the selection). */
  | { kind: 'choice-move'; delta: number }
  /** The choice picker: close it back to the row list (the row focus is preserved). */
  | { kind: 'choice-close' }
  /** The settings overlay's navigation row: open the project-settings view. */
  | { kind: 'settings-open-view' }
  /** The seat picker: choose option `index` (a click on a picker row). */
  | { kind: 'seat-pick'; index: number }
  /** The seat picker: move the selection (the ↑/↓ chips). */
  | { kind: 'seat-move'; delta: number }

export interface PlacedLine {
  line: Line
  hits?: Hit[]
}

/**
 * The board focus's identity (M48): the entry id **plus which row of that id** — an id may name
 * several BOARD.md rows (the file's history has shared ids), and a bare id makes the cursor freeze
 * on the first of them. `nth` is the 0-based duplicate ordinal in BOARD.md order; absent = 0, so a
 * focus written by an older build (or a hand-made fixture) still resolves.
 */
export interface FocusRef {
  lane: string
  id: string
  nth?: number
}

/** A lane's window as the frame rendered it (the App's arrow keys and wheel clamp against this). */
export interface LaneWindow {
  lane: string
  offset: number
  visible: number
  count: number
}

/** The detail view's document window as the frame rendered it (the App's arrows/wheel clamp). */
export interface DetailWindow {
  /** The rendered tab index. */
  index: number
  /** Document rows at the rendered width. */
  total: number
  /** Rows the window shows. */
  visible: number
  /** The first visible row (clamped by the layout). */
  offset: number
}

/** The project-settings view's row window as the frame rendered it (P22/B2). */
export interface SettingsWindow {
  /** The focused focusable row (an index into the filtered row list). */
  focus: number
  /** The first drawn focusable row. */
  offset: number
  /** Focusable rows the window shows. */
  visible: number
  /** Focusable rows in the filtered list. */
  count: number
}

/** A rendered frame: the rows plus the click targets resolved to absolute rows. */
export interface Frame {
  rows: Line[]
  targets: { row: number; hit: Hit }[]
  /** The board page's lane windows (absent on the other pages). */
  lanes?: LaneWindow[]
  /** The detail view's document window (absent while the view is closed). */
  detail?: DetailWindow
  /** The project-settings view's row window (absent while the view is closed). */
  settings?: SettingsWindow
  /** The work page's board rows in the order they were drawn (the App's `↑`/`↓` walk this). */
  boardOrder?: FocusRef[]
}

export interface FrameInput {
  panel: PanelData
  /** The data layer's blocks (`monitor.mjs --json`), already sanitized. */
  activityBlocks: ActivityBlock[]
  /** The console-only readers. */
  blocks: PanelBlocks
  /** Blocks whose source failed in this assembly; their block renders `—`. */
  degraded?: string[]
  width: number
  height: number
  /** Whether the activity column is on for this frame. */
  activity: boolean
}

/** The console's UI state (TUI-only; the machine exits use the defaults). */
export interface ViewState {
  page: PageId
  density: Density
  /** The active language table's id (`zh` | `en`). */
  lang: string
  /** The mouse preference as the frame is drawn (targets exist regardless; this drives the hint). */
  mouseOn: boolean
  /** True in the TUI renderer — the page tabs, targets and the overlay only exist there. */
  tui: boolean
  overlay: boolean
  /** The selected row inside the settings overlay. */
  overlayIndex: number
  /** The queue entry shown in full on the messages page, or null for the list. */
  viewEntry: number | null
  scroll: number
  /** The kanban's focused card, keyed by entry id + duplicate ordinal (a vanished id falls back). */
  focus?: FocusRef | null
  /** Per-lane window offsets (the board page's wheel); absent lanes anchor on their newest cards. */
  laneOffset?: Record<string, number>
  /** The entry id whose read-only detail view is open (null = the page itself is showing). */
  detail?: string | null
  /** The open detail view's file tab (clamped by the layout; 0 = the first file). */
  detailIndex?: number
  /** The detail document's first visible row. */
  detailScroll?: number
  /** True while the project-settings view replaces the page's blocks (P22/B2). */
  settings?: boolean
  /** The focused row in the filtered project-settings row list. */
  settingsFocus?: number
  /** The filter text (`''` = no filter). */
  settingsFilter?: string
  /**
   * The view's own row-window offset (P30/D5): `undefined`/`null` = unset (the window follows the
   * focus); a number pins the window's first visible focusable row (the wheel's own offset).
   */
  settingsOffset?: number | null
  /** The open setting editor's draft: the row it edits, the text and the insertion point. */
  settingsDraft?: { row: number; text: string; cursor: number } | null
  /** The pending write confirmation (the first Enter of a two-step write). */
  settingsConfirm?: { row: number; key: string; old: string; next: string; danger: boolean } | null
  /** The open seat picker: the seat's agent, its option list and the selection. */
  seatPicker?: { agent: string; row: number; models: string[]; index: number } | null
  /** The open choice picker (M55): the row, its schema-derived entries and the selection. */
  choicePicker?: SettingsChoicePicker | null
}
