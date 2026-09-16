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

/** The three console pages (TUI-only; `--print`/`--json` render the overview). */
export type PageId = 1 | 2 | 3
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

export interface ChangeRow {
  id: string
  done: number
  total: number
  /** The `openspec list` age token (`44m ago`), verbatim. */
  age: string
  /** explore | propose | apply | verify — derived from the artifacts on disk. */
  phase: string
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
   * True for the title band's clock: the **live** component owns that text in the TUI (it ticks
   * every second), while `--print`/`--json`/snapshots render `text` verbatim. It must never be
   * merged into a neighbour, and a frame whose only difference is this segment is "unchanged"
   * (`frameSignature`) — that is what keeps the redraw off the CPU red line.
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

export interface PlacedLine {
  line: Line
  hits?: Hit[]
}

/** A rendered frame: the rows plus the click targets resolved to absolute rows. */
export interface Frame {
  rows: Line[]
  targets: { row: number; hit: Hit }[]
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
}
