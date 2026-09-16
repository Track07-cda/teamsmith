// The wire contract between the bash data command (`team __panel-data`) and this renderer.
//
// The panel never reads state files, git or the queue itself: `monitor.mjs` stays the data layer
// for the activity stream, and the existing bash readers stay the source of the team fields. This
// file is the one place that names the fields; `layout.ts` is the only consumer.

export type PmState = 'running' | 'starting' | 'absent' | 'foreign' | 'unknown'
export type AgentState = 'running' | 'exited' | 'absent'

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
  project: string
  timestamp: string
  interval: number
  standby: PanelStandby
  pm: PanelPm
  pending: PanelPending
  outbox: PanelOutbox
  capacity: PanelCapacity
  agents: PanelAgent[]
  recent: string[]
  /** TEAM_AGENT_LOG_GLOB when it is set (the activity column's source hint). */
  activity_source?: string
}

export interface FrameInput {
  panel: PanelData
  /** The data layer's blocks (`monitor.mjs --json`), already sanitized. */
  activityBlocks: ActivityBlock[]
  width: number
  height: number
  /** Whether the activity column is on for this frame. */
  activity: boolean
  /** ↑/↓ scroll offset inside the activity block. */
  scroll?: number
}
