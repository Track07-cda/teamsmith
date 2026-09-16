// The frame: three pages, a settings overlay, four width tiers — and nothing else.
//
// This module is pure (no I/O, no timers, no clock): the same width, height, data and view state
// produce the same `Frame` byte for byte. The Ink renderer, the plain-text `--print` path and the
// snapshot suite all consume the same `layout()` result; `renderPlain` and `renderAnsi` only turn
// the tone-carrying segments into text (with or without SGR).
//
// Layout model (design `docs/team/designs/pulse-console.md`, spec "The layout is a pure function of
// geometry with four width tiers"):
//
//   ≥160 columns      two columns
//   100–159 columns   two compact columns (the right one narrowed, long text truncated)
//   <100 columns      one column, blocks stacked
//   <60 columns       the minimal form: table columns dropped, times to the clock, states shortened
//
// The documented degradation order is: side-by-side blocks become one column → a block folds into
// one summary line when the height runs out → blocks collapse entirely, and the minimal tier drops
// table columns / abbreviates states. Blocks whose source has no data collapse and yield the space.

import { fmtAge, fmtMB, GLYPH, clockOf, shortBranch, sparkline } from './format.js'
import { fill } from './strings/index.js'
import type { Strings } from './strings/index.js'
import type {
  Action,
  ActivityBlock,
  ChangeRow,
  Density,
  Frame,
  FrameInput,
  Hit,
  Line,
  PageId,
  PanelAgent,
  PanelBlocks,
  PanelData,
  PlacedLine,
  PrefName,
  QueueEntry,
  Segment,
  Tone,
  ViewState,
} from './types.js'
import { toneSgr, type Palette } from './theme.js'
import { cell, dispWidth, rule, truncateW, truncateWStart } from './width.js'

export const WIDTH_TWO_WIDE = 160
export const WIDTH_TWO_COMPACT = 100
export const WIDTH_MINIMAL = 60

/** Column ratios per two-column tier (left share of the usable track). */
const LEFT_SHARE_WIDE = 0.56
const LEFT_SHARE_COMPACT = 0.64
const COLUMN_GAP = 3

type Part = Segment | string | null | undefined

const seg = (text: string, tone: Tone = 'text'): Segment => ({ text: String(text), tone })

/** Adjacent segments with the same tone become one: Ink renders one node per segment, and frame
 * reconciliation is a real cost at a 3s cadence (the red line is <1% of one core). */
function mergeSegments(line: Segment[]): Line {
  const out: Segment[] = []
  for (const s of line) {
    const prev = out[out.length - 1]
    if (prev && prev.tone === s.tone && !prev.clock && !s.clock) prev.text += s.text
    else out.push({ ...s })
  }
  return out
}

const ln = (...parts: Part[]): Line =>
  mergeSegments(
    parts
      .filter((p): p is Segment | string => p !== null && p !== undefined && p !== '')
      .map((p) => (typeof p === 'string' ? seg(p) : p)),
  )

const textOf = (line: Line): string => line.map((s) => s.text).join('')
const widthOf = (line: Line): number => dispWidth(textOf(line))

/** Cut a segment line to `width` display columns (never wider, ellipsis when cut). */
function truncLine(line: Line, width: number): Line {
  if (width <= 0) return []
  if (widthOf(line) <= width) return line
  const room = width - 1
  const out: Line = []
  let used = 0
  for (const s of line) {
    if (used >= room) break
    let text = ''
    for (const ch of s.text) {
      const w = dispWidth(ch)
      if (used + w > room) break
      text += ch
      used += w
    }
    if (text) out.push({ text, tone: s.tone })
  }
  out.push(seg('…', out[out.length - 1]?.tone ?? 'text'))
  return out
}

/** Append spaces so the line occupies exactly `width` columns (used for the left column). */
function padLine(line: Line, width: number): Line {
  const d = width - widthOf(line)
  return d > 0 ? [...line, seg(' '.repeat(d), 'text')] : line
}

interface Block {
  id: string
  full?: boolean
  right?: boolean
  priority: number
  lines: PlacedLine[]
  /** The one-line degradation used when the height budget is tight. */
  summary?: PlacedLine
  /** A separator is inserted before the block under the comfortable density. */
  separator?: 'rule' | 'blank' | 'none'
}

interface Ctx {
  s: Strings
  input: LayoutInput
  width: number
  minimal: boolean
  compact: boolean
  twoColumn: boolean
  leftWidth: number
  rightWidth: number
  deg: Set<string>
  panel: PanelData
  blocks: PanelBlocks
  view: ViewState
  activity: ActivityBlock[]
}

export interface LayoutInput extends FrameInput {
  strings: Strings
  view: ViewState
}

// ------------------------------------------------------------------ small renderers

interface TableCols {
  name: number
  state: number
  task: number
  branch: number
  session: number
  showBranch: boolean
  showSession: boolean
}

function agentColumns(width: number, minimal: boolean): TableCols {
  const fixed = { name: 10, state: 8, task: 7, session: 7 }
  const cols: TableCols = { ...fixed, branch: 0, showBranch: true, showSession: true }
  if (minimal) {
    cols.state = 4
    cols.task = 0
    cols.showBranch = false
    cols.showSession = false
    return cols
  }
  let branch = width - (fixed.name + fixed.state + fixed.task + fixed.session + 4)
  if (branch < 8) {
    cols.showSession = false
    branch = width - (fixed.name + fixed.state + fixed.task + 3)
    if (branch < 8) {
      cols.showBranch = false
      branch = 0
    }
  }
  cols.branch = Math.max(0, branch)
  return cols
}

function agentStateText(a: PanelAgent, s: Strings): string {
  const glyph = GLYPH[a.state] ?? '?'
  const text = a.state === 'running' ? s.agentRunning : a.state === 'exited' ? s.agentExited : s.agentAbsent
  return `${glyph} ${text}`
}

function pmStateText(pm: PanelData['pm'], s: Strings): string {
  switch (pm?.state) {
    case 'running':
      return s.pmRunning
    case 'starting':
      return s.pmStarting
    case 'foreign':
      return s.pmForeign
    case 'unknown':
      return s.pmUnknown
    default:
      return s.pmAbsent
  }
}

// ------------------------------------------------------------------ header / banner blocks

function titleBlock(ctx: Ctx): Block {
  const { s, panel } = ctx
  const project = panel.project || s.dash
  const left = `${s.appTitle} · ${project}`
  const standby = !panel.standby
    ? s.standbyDash
    : fill(panel.standby.on ? s.standbyOn : s.standbyOff, { reason: panel.standby.reason || '-' })
  const stamp = panel.timestamp ? clockOf(panel.timestamp) : s.dash
  const right = `  ${fill(s.patrolSeconds, { n: panel.interval || '—' })} · ${standby}`
  const room = ctx.width - dispWidth(left) - 2
  const line =
    room >= dispWidth(`${stamp}${right}`)
      ? ln(seg(left, 'title'), seg('  '), { text: stamp, tone: 'dim', clock: true }, seg(right, 'dim'))
      : ln(seg(`${left}  ${stamp}${right}`, 'title'))
  return { id: 'title', full: true, priority: 0, lines: [{ line: truncLine(line, ctx.width) }], separator: 'none' }
}

function statusBlock(ctx: Ctx): Block {
  const { s, panel, deg } = ctx
  const pmText = !panel.pm || deg.has('pm')
    ? `${s.pmLabel} ${s.dash}`
    : `${s.pmLabel} ${panel.pm.state}${panel.pm.detail ? `（${panel.pm.detail}）` : ''} · ${pmStateText(panel.pm, s)}`
  const pend = !panel.pending || deg.has('pending') ? `${s.pendingLabel} ${s.dash}` : `${s.pendingLabel} ${panel.pending.text || s.pendingNone}`
  const ob = panel.outbox
  const queue =
    !ob || deg.has('outbox')
      ? `${s.outboxLabel} ${s.dash}`
      : `${s.outboxLabel} ${ob.queued}${ob.held > 0 ? fill(s.outboxHeldSuffix, { n: ob.held }) : ''}`
  return {
    id: 'status',
    full: true,
    priority: 1,
    lines: [{ line: truncLine(ln(seg(' '), seg(pmText), seg('    '), seg(pend), seg('    '), seg(queue, 'accent')), ctx.width) }],
    separator: 'none',
  }
}

function capacityBlock(ctx: Ctx): Block {
  const { s, panel, deg } = ctx
  const c = panel.capacity
  if (!c || deg.has('capacity')) {
    return { id: 'capacity', full: true, priority: 2, lines: [{ line: ln(seg(` ${s.capacityLabel} ${s.dash}`, 'dim')) }] }
  }
  const spark = sparkline(c.spark, Math.min(18, Math.max(0, ctx.width - 60)))
  const line = ln(
    seg(` ${s.capacityLabel} `, 'dim'),
    seg(fill(s.capacityRam, { mb: fmtMB(c.ram_avail_mb) })),
    seg(' ｜ ', 'dim'),
    seg(fill(s.capacitySwap, { mb: fmtMB(c.swap_free_mb) })),
    seg(' ｜ ', 'dim'),
    seg(fill(s.capacityAgents, { n: c.agents })),
    spark ? seg(`  ${spark}`, 'accent') : null,
  )
  return { id: 'capacity', full: true, priority: 2, lines: [{ line: truncLine(line, ctx.width) }] }
}

function progressBlock(ctx: Ctx): Block {
  const { s, panel, deg, blocks } = ctx
  const board = blocks.board
  const parts: Part[] = [seg(` ${s.progressLabel}  `, 'heading')]
  if (board && !deg.has('board')) {
    const c = board.counts ?? {}
    const counts = [
      [s.taskTodo, c.todo ?? 0],
      [s.taskWip, c.wip ?? 0],
      [s.taskReview, c.review ?? 0],
      [s.taskBlocked, c.blocked ?? 0],
      [s.taskDone, c.done ?? 0],
    ]
      .map(([label, n]) => fill(s.countPair, { label, n }))
      .join(' · ')
    parts.push(seg(fill(s.progressTasks, { parts: counts })))
  } else {
    parts.push(seg(fill(s.progressTasks, { parts: s.dash }), 'dim'))
  }
  const sep = seg(' ｜ ', 'dim')
  parts.push(sep)
  if (blocks.changes && !deg.has('changes')) parts.push(seg(fill(s.progressChanges, { n: blocks.changes.count })))
  else parts.push(seg(`${s.progressChanges.replace('{n}', s.dash)}`, 'dim'))
  parts.push(sep)
  if (blocks.specs && !deg.has('specs')) {
    parts.push(seg(fill(s.progressSpecs, { specs: blocks.specs.count, reqs: blocks.specs.requirements })))
  } else parts.push(seg(`${s.specsHeading} ${s.dash}`, 'dim'))
  parts.push(sep)
  if (blocks.decisions && !deg.has('decisions')) parts.push(seg(fill(s.progressDecisions, { n: blocks.decisions.count })))
  else parts.push(seg(`${s.progressDecisions.replace('{n}', s.dash)}`, 'dim'))
  return {
    id: 'progress',
    full: true,
    priority: 5,
    lines: [{ line: truncLine(ln(...parts), ctx.width) }],
    summary: { line: truncLine(ln(seg(` ${s.progressLabel}`, 'heading')), ctx.width) },
  }
}

function deliveriesBlock(ctx: Ctx): Block | null {
  const { s, deg, blocks } = ctx
  const board = blocks.board
  if (!board || deg.has('board')) return null
  const rows = board.deliveries ?? []
  if (!rows.length) {
    return { id: 'deliveries', full: true, priority: 6, lines: [{ line: ln(seg(` ${s.deliveriesLabel}  ${s.deliveriesEmpty}`, 'dim')) }] }
  }
  const lines: PlacedLine[] = [
    { line: ln(seg(` ${s.deliveriesLabel}`, 'heading')) },
    ...rows.slice(0, 3).map((d) => ({
      line: truncLine(
        ln(
          seg('  '),
          seg(fill(s.deliveryLine, { id: d.id, agent: d.agent, time: d.at ? clockOf(d.at) : s.dash })),
        ),
        ctx.width,
      ),
    })),
  ]
  return {
    id: 'deliveries',
    full: true,
    priority: 6,
    lines,
    summary: { line: truncLine(ln(seg(` ${s.deliveriesLabel}`, 'heading')), ctx.width) },
  }
}

// ------------------------------------------------------------------ body blocks (page 1)

function agentsBlock(ctx: Ctx): Block | null {
  const { s, panel, deg, width, minimal } = ctx
  if (!panel.agents || deg.has('agents')) {
    return { id: 'agents', priority: 10, lines: [{ line: ln(seg(` ${s.agentsHeader} ${s.dash}`, 'dim')) }] }
  }
  const agents = panel.agents ?? []
  const cols = agentColumns(width, minimal)
  const header: Part[] = [
    cell(s.agentsHeader, cols.name),
    cell(s.tableState, cols.state),
    cols.showBranch ? cell(s.tableBranch, cols.branch) : null,
    cols.showSession ? cell(s.tableSession, cols.session) : null,
  ]
  const lines: PlacedLine[] = [{ line: truncLine(ln(...header.filter((p) => p !== null).map((p) => seg(String(p), 'heading'))), width) }]
  if (!agents.length) {
    lines.push({ line: ln(seg(` ${s.agentEmpty}`, 'dim')) })
  }
  for (const a of agents) {
    if (minimal) {
      // The minimal tier abbreviates the state to glyph + first character (`●在` = running).
      const stateText = a.state === 'running' ? s.agentRunning : a.state === 'exited' ? s.agentExited : s.agentAbsent
      const st = `${GLYPH[a.state] ?? '?'}${[...stateText][0] ?? ''}`
      lines.push({ line: truncLine(ln(seg(cell(String(a.name ?? '?'), cols.name)), seg(cell(st, cols.state), stateTone(a.state))), width) })
      continue
    }
    const b = shortBranch(String(a.branch ?? ''), cols.branch)
    const flags = `${a.dirty ? ' *' : ''}${a.ahead ? ` +${a.ahead}` : ''}`
    const row: Part[] = [
      cell(String(a.name ?? '?'), cols.name),
      cell(agentStateText(a, s), cols.state),
      cols.task ? cell(String(a.task || s.dash), cols.task) : null,
      cols.showBranch ? cell(`${b}${flags}`, cols.branch) : null,
      cols.showSession ? cell(String(a.session_text || s.dash), cols.session) : null,
    ]
    lines.push({ line: truncLine(ln(...row.filter((p) => p !== null).map((p) => seg(String(p)))), width) })
  }
  return { id: 'agents', priority: 10, lines, summary: { line: truncLine(ln(seg(` ${s.agentsHeader} (${agents.length})`, 'heading')), width) } }
}

function stateTone(state: string): Tone {
  return state === 'running' ? 'ok' : state === 'exited' ? 'warn' : 'dim'
}

function eventsBlock(ctx: Ctx): Block | null {
  const { s, panel, deg, activity, width, view } = ctx
  if (!ctx.input.activity) return null
  const lines: PlacedLine[] = [{ line: truncLine(ln(seg(` ${s.activityHeading}`, 'heading')), width) }]
  if (deg.has('activity') || !panel.activity_source) {
    lines.push({ line: ln(seg(`  ${s.dash}`, 'dim')) })
  } else {
    const label = `${s.activitySource.replace('{path}', '')}`.trim()
    const path = truncateWStart(panel.activity_source, width - dispWidth(label) - 3)
    lines.push({ line: truncLine(ln(seg('  '), seg(label, 'dim'), seg(' '), seg(path, 'dim')), width) })
    const evs = activityLines(activity).slice(Math.max(0, view.scroll))
    if (!evs.length) lines.push({ line: ln(seg(`  ${s.activityEmpty}`, 'dim')) })
    for (const e of evs) lines.push({ line: truncLine(ln(seg(`  ${e}`)), width) })
  }
  return { id: 'events', right: true, priority: 11, lines, summary: { line: truncLine(ln(seg(` ${s.activityHeading}`, 'heading')), width) } }
}

function recentBlock(ctx: Ctx): Block | null {
  const { s, panel, deg, width } = ctx
  const recent = panel.recent ?? []
  if (deg.has('recent') || !panel.recent) {
    return { id: 'recent', right: true, priority: 12, lines: [{ line: ln(seg(` ${s.recentHeading} ${s.dash}`, 'dim')) }] }
  }
  const lines: PlacedLine[] = [{ line: ln(seg(` ${s.recentHeading}`, 'heading')) }]
  const tail = recent.slice(-6)
  if (!tail.length) lines.push({ line: ln(seg(`  ${s.recentEmpty}`, 'dim')) })
  for (const r of tail) lines.push({ line: truncLine(ln(seg(` ${r}`, 'dim')), width) })
  return { id: 'recent', right: true, priority: 12, lines, summary: { line: truncLine(ln(seg(` ${s.recentHeading}`, 'heading')), width) } }
}

export function activityLines(activity: ActivityBlock[]): string[] {
  const out: string[] = []
  for (const block of activity ?? []) {
    const name = String(block?.name ?? '?')
    const events = Array.isArray(block?.events) ? block.events : []
    if (!events.length) continue
    for (const ev of events) {
      const ts = ev?.ts ? String(ev.ts) : ''
      const clock = ts && ts.includes('T') ? ts.slice(11, 19) : ts
      const text = String(ev?.text ?? '')
      out.push(` ${name}${clock ? ` ${clock}` : ''} ${text}`.trimEnd())
    }
  }
  return out
}

// ------------------------------------------------------------------ body blocks (page 2)

const BOARD_STATE_TONE: Record<string, Tone> = {
  todo: 'dim',
  wip: 'accent',
  review: 'warn',
  blocked: 'err',
  done: 'ok',
  dropped: 'dim',
}

function boardStateText(state: string, s: Strings): string {
  switch (state) {
    case 'done':
      return s.taskDone
    case 'wip':
      return s.taskWip
    case 'review':
      return s.taskReview
    case 'blocked':
      return s.taskBlocked
    case 'todo':
      return s.taskTodo
    default:
      return state
  }
}

function changePhaseText(phase: string, s: Strings): string {
  switch (phase) {
    case 'explore':
      return s.changePhaseExplore
    case 'propose':
      return s.changePhasePropose
    case 'verify':
      return s.changePhaseVerify
    case 'archive':
      return s.changePhaseArchive
    default:
      return s.changePhaseApply
  }
}

function boardBlock(ctx: Ctx): Block | null {
  const { s, blocks, deg, width } = ctx
  const board = blocks.board
  if (!board) return null
  if (deg.has('board')) {
    return { id: 'board', priority: 10, lines: [{ line: ln(seg(` ${s.boardHeading} ${s.dash}`, 'dim')) }] }
  }
  const rows = board.rows ?? []
  if (!rows.length) {
    return { id: 'board', priority: 10, lines: [{ line: ln(seg(` ${s.boardHeading}  ${s.boardEmpty}`, 'dim')) }] }
  }
  const counts = board.counts ?? {}
  const lines: PlacedLine[] = [
    { line: truncLine(ln(seg(` ${fill(s.boardHeadingCount, { n: board.total ?? rows.length })}`, 'heading')), width) },
    {
      line: truncLine(
        ln(
          seg(
            `  ${fill(s.boardCounts, {
              todo: counts.todo ?? 0,
              wip: counts.wip ?? 0,
              review: counts.review ?? 0,
              blocked: counts.blocked ?? 0,
              done: counts.done ?? 0,
            })}`,
            'dim',
          ),
        ),
        width,
      ),
    },
  ]
  // `done` and `dropped` rows are history: only their newest five render, the rest fold into one
  // counted line (the design's done-collapse, extended to dropped rows so the live board stays small).
  const doneRows = rows.filter((r) => r.state === 'done' || r.state === 'dropped')
  const keepDone = new Set(doneRows.slice(-5).map((r) => r.id))
  const folded = doneRows.filter((r) => !keepDone.has(r.id)).length
  for (const r of rows) {
    if ((r.state === 'done' || r.state === 'dropped') && !keepDone.has(r.id)) continue
    lines.push({
      line: truncLine(
        ln(
          seg(`  ${GLYPH[r.state] ?? '·'} `, BOARD_STATE_TONE[r.state] ?? 'text'),
          seg(cell(r.id, 10), 'accent'),
          seg(cell(r.agent, 8), 'dim'),
          seg(cell(boardStateText(r.state, s), 8), BOARD_STATE_TONE[r.state] ?? 'text'),
          seg(r.title),
        ),
        width,
      ),
    })
  }
  if (folded > 0) lines.push({ line: truncLine(ln(seg(`  ${fill(s.boardDoneCollapsed, { n: folded })}`, 'dim')), width) })
  return { id: 'board', priority: 10, lines, summary: lines.slice(0, 1) }
}

function changesBlock(ctx: Ctx): Block | null {
  const { s, blocks, deg, width } = ctx
  const c = blocks.changes
  if (!c) return null
  if (deg.has('changes') || !c.available) {
    return { id: 'changes', right: true, priority: 11, lines: [{ line: ln(seg(` ${s.changesHeading} ${s.dash}`, 'dim')) }] }
  }
  if (!c.changes.length) return null // an empty block collapses and yields its space
  const lines: PlacedLine[] = [
    { line: truncLine(ln(seg(` ${fill(s.changesHeadingCount, { n: c.count })}`, 'heading')), width) },
  ]
  for (const ch of c.changes as ChangeRow[]) {
    lines.push({
      line: truncLine(
        ln(
          seg('  '),
          seg(cell(ch.id, 18), 'accent'),
          seg(fill(s.changeLine, { done: ch.done, total: ch.total, phase: changePhaseText(ch.phase, s) })),
        ),
        width,
      ),
    })
  }
  return { id: 'changes', right: true, priority: 11, lines, summary: lines.slice(0, 1) }
}

function specsBlock(ctx: Ctx): Block | null {
  const { s, blocks, deg, width } = ctx
  const sp = blocks.specs
  if (!sp) return null
  if (deg.has('specs') || !sp.available) {
    return { id: 'specs', right: true, priority: 13, lines: [{ line: ln(seg(` ${s.specsHeading} ${s.dash}`, 'dim')) }] }
  }
  const lines: PlacedLine[] = [
    { line: truncLine(ln(seg(` ${s.specsHeading}`, 'heading'), seg('  '), seg(fill(s.specsCount, { specs: sp.count, reqs: sp.requirements }), 'dim')), width) },
  ]
  for (const row of (sp.specs ?? []).slice(0, 6)) {
    lines.push({ line: truncLine(ln(seg('  '), seg(cell(row.name, Math.max(8, width - 10)), 'text'), seg(` ${row.requirements}`, 'dim')), width) })
  }
  return { id: 'specs', right: true, priority: 13, lines, summary: lines.slice(0, 1) }
}

function decisionsBlock(ctx: Ctx): Block | null {
  const { s, blocks, deg, width } = ctx
  const d = blocks.decisions
  if (!d) return null
  if (deg.has('decisions')) {
    return { id: 'decisions', right: true, priority: 14, lines: [{ line: ln(seg(` ${s.decisionsHeading} ${s.dash}`, 'dim')) }] }
  }
  const lines: PlacedLine[] = [
    {
      line: truncLine(
        ln(seg(` ${s.decisionsHeading}`, 'heading'), seg('  '), seg(fill(s.decisionsCountSuffix, { n: d.count }), 'dim')),
        width,
      ),
    },
  ]
  if (!d.recent.length) lines.push({ line: ln(seg(`  ${s.decisionsEmpty}`, 'dim')) })
  for (const r of d.recent.slice(0, 3)) lines.push({ line: truncLine(ln(seg(`  ${r}`, 'dim')), width) })
  return { id: 'decisions', right: true, priority: 14, lines, summary: lines.slice(0, 1) }
}

// ------------------------------------------------------------------ body blocks (page 3)

function queueBlock(ctx: Ctx): Block | null {
  const { s, blocks, deg, width, view } = ctx
  const q = blocks.outbox_list
  if (!q && !deg.has('outbox_list')) return null
  if (deg.has('outbox_list') || !q) {
    return { id: 'queue', priority: 10, lines: [{ line: ln(seg(` ${s.queueHeading} ${s.dash}`, 'dim')) }] }
  }
  if (view.viewEntry != null && q.entries[view.viewEntry]) {
    const e = q.entries[view.viewEntry]
    const lines: PlacedLine[] = [
      { line: truncLine(ln(seg(` ${fill(s.queueFullHeading, { name: e.name })}`, 'heading')), width) },
      { line: truncLine(ln(seg(`  ${fill(s.queueMeta, { kind: e.kind, target: e.target, from: e.from })}`, 'dim')), width) },
      { line: ln(seg('  ')) },
    ]
    for (const text of String(e.text ?? '').split('\n')) {
      for (const chunk of wrapText(text, Math.max(4, width - 2))) lines.push({ line: truncLine(ln(seg(`  ${chunk}`)), width) })
    }
    lines.push({ line: ln(seg(''), seg(`  ${s.queueBackHint}`, 'dim')) })
    return { id: 'queue', priority: 10, lines, summary: lines.slice(0, 1) }
  }
  if (!q.entries.length) {
    return { id: 'queue', priority: 10, lines: [{ line: ln(seg(` ${fill(s.queueHeadingCount, { queued: 0, held: 0 })}  ${s.queueEmpty}`, 'dim')) }] }
  }
  const lines: PlacedLine[] = [
    { line: truncLine(ln(seg(` ${fill(s.queueHeadingCount, { queued: q.queued, held: q.held })}`, 'heading')), width) },
  ]
  q.entries.slice(0, 20).forEach((e: QueueEntry, i: number) => {
    const state = e.state === 'held' ? s.queueStateHeld : s.queueStateQueued
    const row = ln(
      seg('  '),
      seg(fill(s.queueLine, { index: i + 1, state, name: e.name, age: fmtAge(e.age_s) }), e.state === 'held' ? 'warn' : 'text'),
      e.reason && e.reason !== '-' ? seg(`  ${fill(s.queueHeldReason, { reason: e.reason })}`, 'dim') : null,
    )
    const placed: PlacedLine = { line: truncLine(row, width) }
    if (view.tui) placed.hits = [{ start: 2, end: Math.min(width, 2 + dispWidth(textOf(row))), action: { kind: 'view-entry', index: i } }]
    lines.push(placed)
  })
  if (ctx.view.tui) lines.push({ line: ln(seg(`  ${s.queueViewHint}`, 'dim')) })
  return { id: 'queue', priority: 10, lines, summary: lines.slice(0, 1) }
}

function wrapText(text: string, width: number): string[] {
  if (!text) return ['']
  const out: string[] = []
  let cur = ''
  for (const ch of String(text)) {
    if (cur && dispWidth(cur + ch) > width) {
      out.push(cur)
      cur = ch
    } else cur += ch
  }
  out.push(cur)
  return out
}

function inboxBlock(ctx: Ctx): Block | null {
  const { s, blocks, deg, width } = ctx
  const inbox = blocks.inbox
  if (!inbox) return null
  if (deg.has('inbox')) {
    return { id: 'inbox', right: true, priority: 11, lines: [{ line: ln(seg(` ${s.inboxHeading} ${s.dash}`, 'dim')) }] }
  }
  if (!inbox.agents.length) return null
  const lines: PlacedLine[] = [{ line: ln(seg(` ${s.inboxHeading}`, 'heading')) }]
  for (const a of inbox.agents.slice(0, 8)) {
    lines.push({
      line: truncLine(
        ln(
          seg('  '),
          seg(cell(a.agent, 10), 'accent'),
          seg(fill(s.inboxLine, { inbox: a.inbox_lines, thread: a.thread_lines, age: fmtAge(a.inbox_age_s) }), 'dim'),
        ),
        width,
      ),
    })
  }
  return { id: 'inbox', right: true, priority: 11, lines, summary: lines.slice(0, 1) }
}

function patrolBlock(ctx: Ctx): Block | null {
  const { s, blocks, deg, width, view } = ctx
  const p = blocks.patrol
  if (!p) return null
  if (deg.has('patrol')) {
    return { id: 'patrol', right: true, priority: 12, lines: [{ line: ln(seg(` ${s.patrolHeading} ${s.dash}`, 'dim')) }] }
  }
  if (!p.lines.length) return null
  const lines: PlacedLine[] = [{ line: ln(seg(` ${s.patrolHeading}`, 'heading')) }]
  for (const l of p.lines.slice(-12).slice(Math.max(0, view.scroll))) lines.push({ line: truncLine(ln(seg(` ${l}`, 'dim')), width) })
  return { id: 'patrol', right: true, priority: 12, lines, summary: lines.slice(0, 1) }
}

function trendBlock(ctx: Ctx): Block | null {
  const { s, panel, deg, width } = ctx
  const c = panel.capacity
  if (!c || deg.has('capacity')) return null
  const spark = sparkline(c.spark, Math.max(8, width - 8))
  if (!spark) return null
  return {
    id: 'trend',
    right: true,
    priority: 13,
    lines: [
      { line: ln(seg(` ${s.trendHeading}`, 'heading'), seg('  '), seg(fill(s.trendLine, { mb: fmtMB(c.ram_avail_mb), swap: fmtMB(c.swap_free_mb) }), 'dim')) },
      { line: truncLine(ln(seg('  '), seg(spark, 'accent')), width) },
    ],
    summary: { line: truncLine(ln(seg(` ${s.trendHeading}`, 'heading')), width) },
  }
}

function healthBlock(ctx: Ctx): Block | null {
  const { s, blocks, deg, width } = ctx
  const h = blocks.health
  if (!h) return null
  if (deg.has('health')) {
    return { id: 'health', right: true, priority: 14, lines: [{ line: ln(seg(` ${s.healthHeading} ${s.dash}`, 'dim')) }] }
  }
  const doctor =
    h.doctor === 'ok'
      ? s.healthDoctorOk
      : h.doctor === 'warn'
        ? s.healthDoctorWarn
        : h.doctor === 'fail'
          ? s.healthDoctorFail
          : s.healthDoctorNA
  const tone: Tone = h.doctor === 'ok' ? 'ok' : h.doctor === 'fail' ? 'err' : 'warn'
  return {
    id: 'health',
    right: true,
    priority: 14,
    lines: [
      {
        line: truncLine(
          ln(
            seg(` ${s.healthHeading} `, 'heading'),
            seg(fill(s.healthLine, { version: h.version || s.dash, doctor, gates: h.gates || s.dash }), h.doctor === 'ok' ? 'text' : tone),
          ),
          width,
        ),
      },
    ],
  }
}

// ------------------------------------------------------------------ footer and overlay

function keyBandBlock(ctx: Ctx): Block {
  const { s, width } = ctx
  const items: { text: string; action: Action }[] = [
    { text: s.keyCompose, action: { kind: 'compose' } },
    { text: s.keyFlush, action: { kind: 'flush' } },
    { text: s.keyStandby, action: { kind: 'standby' } },
    { text: s.keySettings, action: { kind: 'settings' } },
    { text: s.keyPages, action: { kind: 'page-cycle' } },
    { text: s.keyScroll, action: { kind: 'scroll', delta: 1 } },
    { text: s.keyQuit, action: { kind: 'quit' } },
  ]
  const line: Line = []
  const hits: Hit[] = []
  let x = 1
  items.forEach((item, i) => {
    if (i > 0) {
      line.push(seg(' · ', 'dim'))
      x += 3
    }
    const start = x
    line.push(seg(item.text, 'accent'))
    x += dispWidth(item.text)
    if (ctx.view.tui) hits.push({ start, end: x, action: item.action })
  })
  return { id: 'keys', full: true, priority: 99, lines: [{ line: truncLine(ln(seg(' '), ...line), width), hits }], separator: 'none' }
}

function pageTabsBlock(ctx: Ctx): Block | null {
  if (!ctx.view.tui) return null
  const { s } = ctx
  const line: Line = []
  const hits: Hit[] = []
  let x = 1
  const tabs: { page: PageId; text: string }[] = [
    { page: 1, text: s.pageOverview },
    { page: 2, text: s.pageWork },
    { page: 3, text: s.pageMessages },
  ]
  for (const tab of tabs) {
    const active = ctx.view.page === tab.page
    const text = active ? fill(s.pageTabActive, { name: tab.text }) : fill(s.pageTab, { name: tab.text })
    const start = x
    line.push(seg(text, active ? 'accent' : 'dim'))
    x += dispWidth(text)
    hits.push({ start, end: x, action: { kind: 'page', page: tab.page } })
    line.push(seg(' '))
    x += 1
  }
  return { id: 'tabs', full: true, priority: 0.5, lines: [{ line: truncLine(ln(seg(' '), ...line), ctx.width), hits }], separator: 'none' }
}

function overlayPrefs(ctx: Ctx): { pref: string; label: string; value: string }[] {
  const { s, input } = ctx
  const st = input.view
  return [
    { pref: 'lang', label: s.prefLang, value: st.lang === 'zh' ? s.langNameZh : s.langNameEn },
    { pref: 'defaultPage', label: s.prefDefaultPage, value: pageName(st.page, s) },
    { pref: 'activity', label: s.prefActivity, value: input.activity ? s.toggleOn : s.toggleOff },
    { pref: 'mouse', label: s.prefMouse, value: st.mouseOn ? s.toggleOn : s.toggleOff },
    { pref: 'density', label: s.prefDensity, value: st.density === 'compact' ? s.densityCompact : s.densityComfortable },
  ]
}

function pageName(page: PageId, s: Strings): string {
  return page === 1 ? s.pageOverview : page === 2 ? s.pageWork : s.pageMessages
}

function overlayBlock(ctx: Ctx): Block {
  const { s, width } = ctx
  const prefs = overlayPrefs(ctx)
  const lines: PlacedLine[] = [{ line: ln(seg(` ${s.settingsTitle}`, 'title')) }, { line: ln(seg('')) }]
  prefs.forEach((p, i) => {
    const row = ln(
      seg(`  ${i === ctx.view.overlayIndex ? s.settingsCursor : ' '} `, 'accent'),
      seg(cell(p.label, 12), 'heading'),
      seg(p.value),
    )
    const placed: PlacedLine = { line: truncLine(row, width) }
    if (ctx.view.tui) placed.hits = [{ start: 2, end: Math.min(width, 2 + dispWidth(textOf(row))), action: { kind: 'toggle', pref: p.pref as PrefName } }]
    lines.push(placed)
  })
  lines.push({ line: ln(seg('')) })
  lines.push({ line: truncLine(ln(seg(` ${s.settingsHint}`, 'dim')), width) })
  return { id: 'overlay', full: true, priority: 0, lines, separator: 'none' }
}

// ------------------------------------------------------------------ assembly

function pageDefinitions(ctx: Ctx): Block[] {
  const left = (): Ctx => (ctx.twoColumn ? { ...ctx, width: ctx.leftWidth } : ctx)
  const right = (): Ctx => (ctx.twoColumn ? { ...ctx, width: ctx.rightWidth } : ctx)
  const blocks: (Block | null)[] = [titleBlock(ctx), pageTabsBlock(ctx)]
  if (ctx.view.overlay) return [...blocks.filter((b): b is Block => b !== null), overlayBlock(ctx), keyBandBlock(ctx)]
  switch (ctx.view.page) {
    case 1:
      blocks.push(
        statusBlock(ctx),
        capacityBlock(ctx),
        progressBlock(ctx),
        deliveriesBlock(ctx),
        agentsBlock(left()),
        eventsBlock(right()),
        recentBlock(right()),
      )
      break
    case 2:
      blocks.push(boardBlock(left()), changesBlock(right()), specsBlock(right()), decisionsBlock(right()))
      break
    default:
      blocks.push(queueBlock(left()), inboxBlock(right()), patrolBlock(right()), trendBlock(right()), healthBlock(right()))
      break
  }
  blocks.push(keyBandBlock(ctx))
  return blocks.filter((b): b is Block => b !== null)
}

function separatorFor(block: Block, density: Density): PlacedLine[] {
  if (!block.separator || block.separator === 'none') return []
  if (block.separator === 'blank') return density === 'comfortable' ? [{ line: [] }] : []
  return []
}

/**
 * Build the frame. `height <= 0` means "no cap" (the `--print` path without geometry overrides).
 * Every row is ≤ `width` columns, the array is ≤ `height` rows, and the footer (the key band) is
 * always the last row unless even one row does not fit.
 */
export function layout(input: LayoutInput): Frame {
  const width = Math.max(1, Math.floor(input.width) || 1)
  const height = Math.floor(input.height) || 0
  const minimal = width < WIDTH_MINIMAL
  const twoColumn = width >= WIDTH_TWO_COMPACT
  const wide = width >= WIDTH_TWO_WIDE
  const leftWidth = twoColumn ? Math.max(16, Math.floor((width - COLUMN_GAP) * (wide ? LEFT_SHARE_WIDE : LEFT_SHARE_COMPACT))) : width
  const rightWidth = twoColumn ? Math.max(8, width - leftWidth - COLUMN_GAP) : width
  const ctx: Ctx = {
    s: input.strings,
    input,
    width,
    minimal,
    compact: input.view.density === 'compact',
    twoColumn,
    leftWidth,
    rightWidth,
    deg: new Set(input.degraded ?? []),
    panel: input.panel,
    blocks: input.blocks ?? {},
    view: input.view,
    activity: input.activityBlocks ?? [],
  }

  const blocks = pageDefinitions(ctx)
  const title = blocks.find((b) => b.id === 'title') ?? blocks[0]
  const footer = blocks[blocks.length - 1]
  const middle = blocks.slice(1, -1)

  const rows: PlacedLine[] = []
  const add = (lines: PlacedLine[]): void => {
    for (const l of lines) rows.push(l)
  }

  add(title.lines)

  const budget = height > 0 ? Math.max(0, height - title.lines.length - footer.lines.length) : Number.POSITIVE_INFINITY

  const fullBlocks = middle.filter((b) => b.full)
  const leftBlocks = middle.filter((b) => !b.full && !b.right)
  const rightBlocks = middle.filter((b) => !b.full && b.right)

  const fullRows: PlacedLine[] = []
  for (const b of fullBlocks) {
    const sep = separatorFor(b, input.view.density)
    if (fullRows.length + sep.length + b.lines.length <= budget) add2(fullRows, sep, b.lines)
    else if (b.summary && fullRows.length + sep.length + 1 <= budget) add2(fullRows, sep, [b.summary])
  }
  add(fullRows)

  const bodyBudget = budget === Number.POSITIVE_INFINITY ? Number.POSITIVE_INFINITY : Math.max(0, budget - fullRows.length)
  if (bodyBudget > 0) {
    if (twoColumn) {
      const leftW = leftWidth
      const rightW = rightWidth
      const columns: [PlacedLine[], PlacedLine[]] = [[], []]
      const ordered = [...leftBlocks.map((b) => ({ b, slot: 0 })), ...rightBlocks.map((b) => ({ b, slot: 1 }))].sort(
        (x, y) => x.b.priority - y.b.priority,
      )
      for (const { b, slot } of ordered) {
        const sep = separatorFor(b, input.view.density).length
        const used = Math.max(columns[0].length, columns[1].length)
        if (used + sep + b.lines.length <= bodyBudget) {
          for (const l of separatorFor(b, input.view.density)) columns[slot].push(l)
          for (const l of b.lines) columns[slot].push(l)
        } else if (b.summary && used + sep + 1 <= bodyBudget) {
          for (const l of separatorFor(b, input.view.density)) columns[slot].push(l)
          columns[slot].push(b.summary)
        }
      }
      const bodyRows = Math.min(bodyBudget, Math.max(columns[0].length, columns[1].length))
      for (let i = 0; i < bodyRows; i++) {
        const l = columns[0][i]
        const r = columns[1][i]
        if (l && r) {
          const merged: PlacedLine = {
            line: [...padLine(l.line, leftW), seg('   '), ...r.line].map((sg) => ({ ...sg })),
            hits: [
              ...(l.hits ?? []),
              ...(r.hits ?? []).map((h) => ({ ...h, start: h.start + leftW + COLUMN_GAP, end: h.end + leftW + COLUMN_GAP })),
            ],
          }
          rows.push(merged)
        } else if (l) rows.push(l)
        else if (r) rows.push({ line: [seg(' '.repeat(leftW + COLUMN_GAP)), ...r.line], hits: (r.hits ?? []).map((h) => ({ ...h, start: h.start + leftW + COLUMN_GAP, end: h.end + leftW + COLUMN_GAP })) })
      }
    } else {
      const columnW = width
      let used = 0
      const ordered = [...leftBlocks, ...rightBlocks].sort((x, y) => x.priority - y.priority)
      for (const b of ordered) {
        const sep = separatorFor(b, input.view.density).length
        if (used + sep + b.lines.length <= bodyBudget) {
          for (const l of separatorFor(b, input.view.density)) rows.push(l)
          for (const l of b.lines) rows.push({ line: truncLine(l.line, columnW), hits: l.hits })
          used += sep + b.lines.length
        } else if (b.summary && used + sep + 1 <= bodyBudget) {
          for (const l of separatorFor(b, input.view.density)) rows.push(l)
          rows.push({ line: truncLine(b.summary.line, columnW), hits: b.summary.hits })
          used += sep + 1
        }
      }
    }
  }

  // The footer is the last row; when the height cannot even hold it, it is the only row kept.
  if (height > 0 && rows.length + footer.lines.length > height) {
    const room = Math.max(0, height - footer.lines.length)
    rows.length = Math.min(rows.length, room)
  }
  add(footer.lines)

  const trimmed = rows.slice(0, height > 0 ? height : rows.length)
  const targets: { row: number; hit: Hit }[] = []
  trimmed.forEach((l, i) => {
    for (const h of l.hits ?? []) targets.push({ row: i, hit: h })
  })
  return { rows: trimmed.map((l) => truncLine(l.line, width)), targets }
}

function add2(into: PlacedLine[], a: PlacedLine[], b: PlacedLine[]): void {
  for (const l of a) into.push(l)
  for (const l of b) into.push(l)
}

/** One plain-text frame (the `--print` contract: no escape sequence, no color). */
/** The row's content key: identical keys mean the row would render identically. */
export function rowKey(line: Line): string {
  let key = ''
  for (const s of line) key += `${s.tone}\u0000${s.text}\u0001`
  return key
}

export function renderPlain(frame: Frame): string[] {
  return frame.rows.map((line) => textOf(line).replace(/\s+$/, ''))
}

/** One frame with the theme's SGR sequences; deterministic, so the snapshot suite can pin it. */
export function renderAnsi(frame: Frame, palette: Palette, opts: { color?: boolean; truecolor?: boolean } = {}): string[] {
  const color = opts.color !== false
  const truecolor = opts.truecolor !== false
  if (!color) return renderPlain(frame)
  return frame.rows.map((line) =>
    line
      .map((s) => {
        if (!s.text) return s.text
        return `\u001b[${toneSgr(s.tone, palette, truecolor)}m${s.text}\u001b[0m`
      })
      .join(''),
  )
}

/** One JSON object with the panel fields plus the untouched activity blocks. */
export function buildJson(input: FrameInput, refreshS: number): Record<string, unknown> {
  return { panel: { ...input.panel, refresh_s: refreshS }, activity: input.activity ? input.activityBlocks : [] }
}
