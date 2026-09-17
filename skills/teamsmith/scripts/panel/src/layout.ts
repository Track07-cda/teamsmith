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

/**
 * Truncate a line and clip its hit spans to the *rendered* coordinates (V15/F4): when the line
 * is cut, the ellipsis owns the last column and every target reaching into it is invisible — a
 * click on the `…` must fire nothing. Targets are therefore generated from the line as rendered,
 * never from the untruncated text.
 */
function placedWithHits(line: Line, hits: Hit[] | undefined, width: number): PlacedLine {
  const rendered = truncLine(line, width)
  if (!hits?.length) return { line: rendered }
  const cut = widthOf(line) > width
  const room = cut ? Math.max(0, width - 1) : width
  const clipped: Hit[] = []
  for (const h of hits) {
    const start = Math.min(h.start, room)
    const end = Math.min(h.end, room)
    if (end > start) clipped.push({ ...h, start, end })
  }
  return clipped.length ? { line: rendered, hits: clipped } : { line: rendered }
}

function isFramed(ctx: Ctx): boolean {
  return ctx.view.tui && ctx.view.density === 'comfortable'
}

function cardTop(title: string, width: number): Line {
  if (width <= 1) return ln(seg(BOX_TL, 'dim'))
  if (width === 2) return ln(seg(BOX_TL + BOX_TR, 'dim'))
  const inner = width - 2
  if (!title) return ln(seg(BOX_TL + BOX_H.repeat(inner) + BOX_TR, 'dim'))
  // ╭─ title ──…──╮  (title in heading, border dim). Inner = ─ + ' ' + title + ' ' + ─…
  const labelW = dispWidth(title)
  if (1 + 1 + labelW + 1 > inner) {
    const room = Math.max(0, inner - 1)
    return ln(seg(BOX_TL + BOX_H, 'dim'), ...truncLine(ln(seg(title, 'heading')), room), seg(BOX_TR, 'dim'))
  }
  const fill = inner - (1 + 1 + labelW + 1) // ─ space title space ─…
  return ln(
    seg(BOX_TL + BOX_H + ' ', 'dim'),
    seg(title, 'heading'),
    seg(' ' + BOX_H.repeat(Math.max(0, fill)), 'dim'),
    seg(BOX_TR, 'dim'),
  )
}

function cardBottom(width: number): Line {
  if (width <= 1) return ln(seg(BOX_BL, 'dim'))
  if (width === 2) return ln(seg(BOX_BL + BOX_BR, 'dim'))
  return ln(seg(BOX_BL + BOX_H.repeat(width - 2) + BOX_BR, 'dim'))
}

function cardBody(placed: PlacedLine, width: number): PlacedLine {
  const inner = Math.max(0, width - 4) // │␠ content ␠│
  const rendered = truncLine(placed.line, inner)
  const pad = Math.max(0, inner - widthOf(rendered))
  const hits: Hit[] = []
  for (const h of placed.hits ?? []) {
    const start = Math.min(h.start + 2, 2 + inner)
    const end = Math.min(h.end + 2, 2 + inner)
    if (end > start) hits.push({ ...h, start, end })
  }
  const line = ln(seg(`${BOX_V} `, 'dim'), ...rendered, pad > 0 ? seg(' '.repeat(pad), 'text') : null, seg(` ${BOX_V}`, 'dim'))
  return hits.length ? { line, hits } : { line }
}

function ruleTitle(title: string, width: number): Line {
  if (width <= 0) return []
  if (!title) return ln(seg(rule(width, BOX_H), 'dim'))
  const labelW = dispWidth(title)
  if (labelW + 4 >= width) return truncLine(ln(seg(BOX_H + BOX_H + ' ', 'dim'), seg(title, 'heading')), width)
  const left = 2
  const right = width - left - 1 - labelW // ── title ─…
  return ln(seg(rule(left, BOX_H) + ' ', 'dim'), seg(title, 'heading'), seg(' ' + rule(Math.max(0, right - 1), BOX_H), 'dim'))
}

function wrapBlock(block: Block, width: number, chrome: Chrome): PlacedLine[] {
  const title = block.title
  if (!title || chrome === 'plain') {
    if (title && chrome === 'plain' && block.id !== 'agents') {
      return [{ line: truncLine(ln(seg(` ${title}`, 'heading')), width) }, ...block.lines]
    }
    return block.lines
  }
  if (chrome === 'rule') {
    return [{ line: ruleTitle(title, width) }, ...block.lines.map((l) => ({ line: truncLine(l.line, width), hits: l.hits }))]
  }
  return [{ line: cardTop(title, width) }, ...block.lines.map((l) => cardBody(l, width)), { line: cardBottom(width) }]
}

function pickChrome(block: Block, remaining: number, framed: boolean): Chrome | 'summary' | null {
  const n = block.lines.length
  if (!framed || !block.title) {
    if (remaining >= n) return 'plain'
    if ((block.summary || block.title) && remaining >= 1) return 'summary'
    return null
  }
  if (remaining >= n + 2) return 'card'
  if (remaining >= n + 1) return 'rule'
  if (remaining >= 1) return 'summary'
  return null
}

function summaryLine(block: Block, width: number): PlacedLine {
  if (block.summary) return { line: truncLine(block.summary.line, width), hits: block.summary.hits }
  return { line: truncLine(ln(seg(` ${block.title ?? ''}`, 'heading')), width) }
}

interface Block {
  id: string
  full?: boolean
  right?: boolean
  priority: number
  lines: PlacedLine[]
  /** Card / rule / title-line chrome; omitted on chrome rows (title band, tabs, keys). */
  title?: string
  /** The one-line degradation used when the height budget is tight. */
  summary?: PlacedLine
  /** A separator is inserted before the block under the comfortable density. */
  separator?: 'rule' | 'blank' | 'none'
}

const BOX_TL = '╭'
const BOX_TR = '╮'
const BOX_BL = '╰'
const BOX_BR = '╯'
const BOX_H = '─'
const BOX_V = '│'

type Chrome = 'card' | 'rule' | 'plain'

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

/** One column of the agents table. Header and data share this plan (display-width aligned). */
interface AgentCol {
  id: 'name' | 'state' | 'task' | 'branch' | 'session'
  header: string
  width: number
}

function stateCellText(a: PanelAgent, s: Strings, minimal: boolean): string {
  if (minimal) {
    const stateText = a.state === 'running' ? s.agentRunning : a.state === 'exited' ? s.agentExited : s.agentAbsent
    return `${GLYPH[a.state] ?? '?'}${[...stateText][0] ?? ''}`
  }
  return agentStateText(a, s)
}

/**
 * Single source for the agents table: header and every data row use this plan.
 * Session column width is the max display width of the header and every `session_text` — the
 * value is never truncated. When the table cannot fit, columns drop in order: branch → task
 * → session last (a time-format column is not part of this table; clocks live on other blocks).
 */
function agentColumnPlan(width: number, minimal: boolean, agents: PanelAgent[], s: Strings): AgentCol[] {
  const nameW = Math.max(10, dispWidth(s.agentsHeader))
  let stateW = dispWidth(s.tableState)
  for (const a of agents) stateW = Math.max(stateW, dispWidth(stateCellText(a, s, minimal)))
  let sessionW = dispWidth(s.tableSession)
  for (const a of agents) sessionW = Math.max(sessionW, dispWidth(String(a.session_text || s.dash)))
  const taskW = Math.max(7, dispWidth(s.tableTask))
  const name: AgentCol = { id: 'name', header: s.agentsHeader, width: nameW }
  const state: AgentCol = { id: 'state', header: s.tableState, width: stateW }
  const session: AgentCol = { id: 'session', header: s.tableSession, width: sessionW }
  const reserved = nameW + stateW + sessionW
  const rest = width - reserved
  if (minimal || rest < 7) return [name, state, session]
  const task: AgentCol = { id: 'task', header: s.tableTask, width: taskW }
  if (rest >= taskW + 8) {
    return [name, state, task, { id: 'branch', header: s.tableBranch, width: rest - taskW }, session]
  }
  if (rest >= taskW) return [name, state, task, session]
  return [name, state, session]
}

function agentLine(plan: AgentCol[], cells: { text: string; tone: Tone }[]): Line {
  return ln(...plan.map((c, i) => seg(cell(cells[i]?.text ?? '', c.width), cells[i]?.tone ?? 'text')))
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
    return { id: 'capacity', title: s.capacityLabel, full: true, priority: 2, lines: [{ line: ln(seg(` ${s.dash}`, 'dim')) }] }
  }
  const spark = sparkline(c.spark, Math.min(18, Math.max(0, ctx.width - 60)))
  const line = ln(
    seg(fill(s.capacityRam, { mb: fmtMB(c.ram_avail_mb) })),
    seg(' ｜ ', 'dim'),
    seg(fill(s.capacitySwap, { mb: fmtMB(c.swap_free_mb) })),
    seg(' ｜ ', 'dim'),
    seg(fill(s.capacityAgents, { n: c.agents })),
    spark ? seg(`  ${spark}`, 'accent') : null,
  )
  return { id: 'capacity', title: s.capacityLabel, full: true, priority: 2, lines: [{ line: truncLine(line, ctx.width) }] }
}

function progressBlock(ctx: Ctx): Block {
  const { s, panel, deg, blocks } = ctx
  const board = blocks.board
  const parts: Part[] = []
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
    title: s.progressLabel,
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
    return { id: 'deliveries', title: s.deliveriesLabel, full: true, priority: 6, lines: [{ line: ln(seg(` ${s.deliveriesEmpty}`, 'dim')) }] }
  }
  const lines: PlacedLine[] = [
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
    title: s.deliveriesLabel,
    full: true,
    priority: 6,
    lines,
    summary: { line: truncLine(ln(seg(` ${s.deliveriesLabel}`, 'heading')), ctx.width) },
  }
}

// ------------------------------------------------------------------ body blocks (page 1)

function agentsBlock(ctx: Ctx): Block | null {
  const { s, panel, deg, width, minimal } = ctx
  const agents = !panel.agents || deg.has('agents') ? [] : (panel.agents ?? [])
  const framed = isFramed(ctx)
  const tableW = framed && width > 8 ? width - 4 : width
  const plan = agentColumnPlan(tableW, minimal, agents, s)
  if (!panel.agents || deg.has('agents')) {
    return {
      id: 'agents',
      title: s.agentsHeader,
      priority: 10,
      lines: [{ line: ln(seg(` ${s.dash}`, 'dim')) }],
      summary: { line: truncLine(ln(seg(` ${s.agentsHeader} ${s.dash}`, 'heading')), width) },
    }
  }
  const header = plan.map((c) => ({ text: c.header, tone: 'heading' as Tone }))
  const lines: PlacedLine[] = [{ line: agentLine(plan, header) }]
  if (!agents.length) lines.push({ line: ln(seg(` ${s.agentEmpty}`, 'dim')) })
  for (const a of agents) {
    const cells = plan.map((c) => {
      switch (c.id) {
        case 'name':
          return { text: String(a.name ?? '?'), tone: 'text' as Tone }
        case 'state':
          return { text: stateCellText(a, s, minimal), tone: stateTone(a.state) }
        case 'task':
          return { text: String(a.task || s.dash), tone: 'text' as Tone }
        case 'branch': {
          const flags = `${a.dirty ? ' *' : ''}${a.ahead ? ` +${a.ahead}` : ''}`
          return { text: `${shortBranch(String(a.branch ?? ''), Math.max(1, c.width - dispWidth(flags)))}${flags}`, tone: 'text' as Tone }
        }
        case 'session':
          return { text: String(a.session_text || s.dash), tone: 'text' as Tone }
      }
    })
    lines.push({ line: agentLine(plan, cells) })
  }
  return {
    id: 'agents',
    title: s.agentsHeader,
    priority: 10,
    lines,
    summary: { line: truncLine(ln(seg(` ${s.agentsHeader} (${agents.length})`, 'heading')), width) },
  }
}

function stateTone(state: string): Tone {
  return state === 'running' ? 'ok' : state === 'exited' ? 'warn' : 'dim'
}

function eventsBlock(ctx: Ctx): Block | null {
  const { s, panel, deg, activity, width, view } = ctx
  if (!ctx.input.activity) return null
  const lines: PlacedLine[] = []
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
  return { id: 'events', title: s.activityHeading, right: true, priority: 11, lines, summary: { line: truncLine(ln(seg(` ${s.activityHeading}`, 'heading')), width) } }
}

function recentBlock(ctx: Ctx): Block | null {
  const { s, panel, deg, width } = ctx
  const recent = panel.recent ?? []
  if (deg.has('recent') || !panel.recent) {
    return { id: 'recent', title: s.recentHeading, right: true, priority: 12, lines: [{ line: ln(seg(` ${s.dash}`, 'dim')) }] }
  }
  const lines: PlacedLine[] = []
  const tail = recent.slice(-6)
  if (!tail.length) lines.push({ line: ln(seg(`  ${s.recentEmpty}`, 'dim')) })
  for (const r of tail) lines.push({ line: truncLine(ln(seg(` ${r}`, 'dim')), width) })
  return { id: 'recent', title: s.recentHeading, right: true, priority: 12, lines, summary: { line: truncLine(ln(seg(` ${s.recentHeading}`, 'heading')), width) } }
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
    return { id: 'board', title: s.boardHeading, priority: 10, lines: [{ line: ln(seg(` ${s.dash}`, 'dim')) }] }
  }
  const rows = board.rows ?? []
  if (!rows.length) {
    return { id: 'board', title: s.boardHeading, priority: 10, lines: [{ line: ln(seg(` ${s.boardEmpty}`, 'dim')) }] }
  }
  const counts = board.counts ?? {}
  const lines: PlacedLine[] = [
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
  return { id: 'board', title: fill(s.boardHeadingCount, { n: board.total ?? rows.length }), priority: 10, lines, summary: { line: truncLine(ln(seg(` ${fill(s.boardHeadingCount, { n: board.total ?? rows.length })}`, 'heading')), width) } }
}

function changesBlock(ctx: Ctx): Block | null {
  const { s, blocks, deg, width } = ctx
  const c = blocks.changes
  if (!c) return null
  if (deg.has('changes') || !c.available) {
    return { id: 'changes', title: s.changesHeading, right: true, priority: 11, lines: [{ line: ln(seg(` ${s.dash}`, 'dim')) }] }
  }
  if (!c.changes.length) return null // an empty block collapses and yields its space
  const lines: PlacedLine[] = []
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
  return { id: 'changes', title: fill(s.changesHeadingCount, { n: c.count }), right: true, priority: 11, lines, summary: { line: truncLine(ln(seg(` ${fill(s.changesHeadingCount, { n: c.count })}`, 'heading')), width) } }
}

function specsBlock(ctx: Ctx): Block | null {
  const { s, blocks, deg, width } = ctx
  const sp = blocks.specs
  if (!sp) return null
  if (deg.has('specs') || !sp.available) {
    return { id: 'specs', title: s.specsHeading, right: true, priority: 13, lines: [{ line: ln(seg(` ${s.dash}`, 'dim')) }] }
  }
  const lines: PlacedLine[] = [
    { line: truncLine(ln(seg(fill(s.specsCount, { specs: sp.count, reqs: sp.requirements }), 'dim')), width) },
  ]
  for (const row of (sp.specs ?? []).slice(0, 6)) {
    lines.push({ line: truncLine(ln(seg('  '), seg(cell(row.name, Math.max(8, width - 10)), 'text'), seg(` ${row.requirements}`, 'dim')), width) })
  }
  return { id: 'specs', title: s.specsHeading, right: true, priority: 13, lines, summary: { line: truncLine(ln(seg(` ${s.specsHeading}`, 'heading')), width) } }
}

function decisionsBlock(ctx: Ctx): Block | null {
  const { s, blocks, deg, width } = ctx
  const d = blocks.decisions
  if (!d) return null
  if (deg.has('decisions')) {
    return { id: 'decisions', title: s.decisionsHeading, right: true, priority: 14, lines: [{ line: ln(seg(` ${s.dash}`, 'dim')) }] }
  }
  const lines: PlacedLine[] = [
    { line: truncLine(ln(seg(fill(s.decisionsCountSuffix, { n: d.count }), 'dim')), width) },
  ]
  if (!d.recent.length) lines.push({ line: ln(seg(`  ${s.decisionsEmpty}`, 'dim')) })
  for (const r of d.recent.slice(0, 3)) lines.push({ line: truncLine(ln(seg(`  ${r}`, 'dim')), width) })
  return { id: 'decisions', title: s.decisionsHeading, right: true, priority: 14, lines, summary: { line: truncLine(ln(seg(` ${s.decisionsHeading}`, 'heading')), width) } }
}

// ------------------------------------------------------------------ body blocks (page 3)

function queueBlock(ctx: Ctx): Block | null {
  const { s, blocks, deg, width, view } = ctx
  const q = blocks.outbox_list
  if (!q && !deg.has('outbox_list')) return null
  if (deg.has('outbox_list') || !q) {
    return { id: 'queue', title: s.queueHeading, priority: 10, lines: [{ line: ln(seg(` ${s.dash}`, 'dim')) }] }
  }
  if (view.viewEntry != null && q.entries[view.viewEntry]) {
    const e = q.entries[view.viewEntry]
    const lines: PlacedLine[] = [
      { line: truncLine(ln(seg(`  ${fill(s.queueMeta, { kind: e.kind, target: e.target, from: e.from })}`, 'dim')), width) },
      { line: ln(seg('  ')) },
    ]
    for (const text of String(e.text ?? '').split('\n')) {
      for (const chunk of wrapText(text, Math.max(4, width - 2))) lines.push({ line: truncLine(ln(seg(`  ${chunk}`)), width) })
    }
    lines.push({ line: ln(seg(''), seg(`  ${s.queueBackHint}`, 'dim')) })
    return { id: 'queue', title: fill(s.queueFullHeading, { name: e.name }), priority: 10, lines, summary: { line: truncLine(ln(seg(` ${fill(s.queueFullHeading, { name: e.name })}`, 'heading')), width) } }
  }
  if (!q.entries.length) {
    return { id: 'queue', title: s.queueHeading, priority: 10, lines: [{ line: ln(seg(` ${s.queueEmpty}`, 'dim')) }] }
  }
  const lines: PlacedLine[] = []
  q.entries.slice(0, 20).forEach((e: QueueEntry, i: number) => {
    const state = e.state === 'held' ? s.queueStateHeld : s.queueStateQueued
    const row = ln(
      seg('  '),
      seg(fill(s.queueLine, { index: i + 1, state, name: e.name, age: fmtAge(e.age_s) }), e.state === 'held' ? 'warn' : 'text'),
      e.reason && e.reason !== '-' ? seg(`  ${fill(s.queueHeldReason, { reason: e.reason })}`, 'dim') : null,
    )
    const placed: PlacedLine = placedWithHits(
      row,
      view.tui ? [{ start: 2, end: 2 + dispWidth(textOf(row)), action: { kind: 'view-entry', index: i } }] : undefined,
      width,
    )
    lines.push(placed)
  })
  if (ctx.view.tui) lines.push({ line: ln(seg(`  ${s.queueViewHint}`, 'dim')) })
  return { id: 'queue', title: fill(s.queueHeadingCount, { queued: q.queued, held: q.held }), priority: 10, lines, summary: { line: truncLine(ln(seg(` ${fill(s.queueHeadingCount, { queued: q.queued, held: q.held })}`, 'heading')), width) } }
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
    return { id: 'inbox', title: s.inboxHeading, right: true, priority: 11, lines: [{ line: ln(seg(` ${s.dash}`, 'dim')) }] }
  }
  if (!inbox.agents.length) return null
  const lines: PlacedLine[] = []
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
  return { id: 'inbox', title: s.inboxHeading, right: true, priority: 11, lines, summary: { line: truncLine(ln(seg(` ${s.inboxHeading}`, 'heading')), width) } }
}

function patrolBlock(ctx: Ctx): Block | null {
  const { s, blocks, deg, width, view } = ctx
  const p = blocks.patrol
  if (!p) return null
  if (deg.has('patrol')) {
    return { id: 'patrol', title: s.patrolHeading, right: true, priority: 12, lines: [{ line: ln(seg(` ${s.dash}`, 'dim')) }] }
  }
  if (!p.lines.length) return null
  const lines: PlacedLine[] = []
  for (const l of p.lines.slice(-12).slice(Math.max(0, view.scroll))) lines.push({ line: truncLine(ln(seg(` ${l}`, 'dim')), width) })
  return { id: 'patrol', title: s.patrolHeading, right: true, priority: 12, lines, summary: { line: truncLine(ln(seg(` ${s.patrolHeading}`, 'heading')), width) } }
}

function trendBlock(ctx: Ctx): Block | null {
  const { s, panel, deg, width } = ctx
  const c = panel.capacity
  if (!c || deg.has('capacity')) return null
  const spark = sparkline(c.spark, Math.max(8, width - 8))
  if (!spark) return null
  return {
    id: 'trend',
    title: s.trendHeading,
    right: true,
    priority: 13,
    lines: [
      { line: ln(seg(fill(s.trendLine, { mb: fmtMB(c.ram_avail_mb), swap: fmtMB(c.swap_free_mb) }), 'dim')) },
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
    return { id: 'health', title: s.healthHeading, right: true, priority: 14, lines: [{ line: ln(seg(` ${s.dash}`, 'dim')) }] }
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
    title: s.healthHeading,
    right: true,
    priority: 14,
    lines: [
      {
        line: truncLine(
          ln(seg(fill(s.healthLine, { version: h.version || s.dash, doctor, gates: h.gates || s.dash }), h.doctor === 'ok' ? 'text' : tone)),
          width,
        ),
      },
    ],
  }
}

// ------------------------------------------------------------------ footer and overlay

function keyBandBlock(ctx: Ctx): Block {
  const { s, width } = ctx
  const actions: { text: string; action: Action }[] = [
    { text: s.keyCompose, action: { kind: 'compose' } },
    { text: s.keyFlush, action: { kind: 'flush' } },
    { text: s.keyStandby, action: { kind: 'standby' } },
    { text: s.keySettings, action: { kind: 'settings' } },
  ]
  const nav: { text: string; action: Action }[] = [
    { text: s.keyPages, action: { kind: 'page-cycle' } },
    { text: s.keyScroll, action: { kind: 'scroll', delta: 1 } },
    { text: s.keyQuit, action: { kind: 'quit' } },
  ]
  const line: Line = []
  const hits: Hit[] = []
  let x = 1
  const chip = isFramed(ctx)
  const push = (text: string, action: Action, asChip: boolean, dim: boolean): void => {
    if (asChip) {
      const inner = ` ${text} `
      const start = x
      line.push(seg('(', 'dim'), seg(inner, 'accent'), seg(')', 'dim'))
      x += dispWidth(`(${inner})`)
      if (ctx.view.tui) hits.push({ start, end: x, action })
    } else {
      const start = x
      line.push(seg(text, dim ? 'dim' : 'accent'))
      x += dispWidth(text)
      if (ctx.view.tui) hits.push({ start, end: x, action })
    }
  }
  actions.forEach((item, i) => {
    if (i > 0) {
      if (chip) {
        line.push(seg(' ', 'dim'))
        x += 1
      } else {
        line.push(seg(' · ', 'dim'))
        x += 3
      }
    }
    push(item.text, item.action, chip, false)
  })
  nav.forEach((item) => {
    line.push(seg(' · ', 'dim'))
    x += 3
    push(item.text, item.action, false, chip)
  })
  return { id: 'keys', full: true, priority: 99, lines: [placedWithHits(ln(seg(' '), ...line), hits, width)], separator: 'none' }
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
  const boxed = isFramed(ctx)
  for (const tab of tabs) {
    const active = ctx.view.page === tab.page
    const text = active
      ? boxed
        ? `[${tab.text}]`
        : fill(s.pageTabActive, { name: tab.text })
      : fill(s.pageTab, { name: tab.text })
    const start = x
    line.push(seg(text, active ? 'accent' : 'dim'))
    x += dispWidth(text)
    hits.push({ start, end: x, action: { kind: 'page', page: tab.page } })
    line.push(seg(' '))
    x += 1
  }
  return { id: 'tabs', full: true, priority: 0.5, lines: [placedWithHits(ln(seg(' '), ...line), hits, ctx.width)], separator: 'none' }
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
  const lines: PlacedLine[] = []
  prefs.forEach((p, i) => {
    const row = ln(
      seg(`  ${i === ctx.view.overlayIndex ? s.settingsCursor : ' '} `, 'accent'),
      seg(cell(p.label, 12), 'heading'),
      seg(p.value),
    )
    lines.push(
      placedWithHits(row, ctx.view.tui ? [{ start: 2, end: 2 + dispWidth(textOf(row)), action: { kind: 'toggle', pref: p.pref as PrefName } }] : undefined, width),
    )
  })
  lines.push({ line: ln(seg('')) })
  lines.push({ line: truncLine(ln(seg(` ${s.settingsHint}`, 'dim')), width) })
  return { id: 'overlay', title: s.settingsTitle, full: true, priority: 0, lines, separator: 'none' }
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

  const framed = isFramed(ctx)
  const place = (block: Block, remaining: number, colWidth: number): PlacedLine[] => {
    const kind = pickChrome(block, remaining, framed)
    if (kind === null) return []
    if (kind === 'summary') return [summaryLine(block, colWidth)]
    return wrapBlock(block, colWidth, kind)
  }

  const fullRows: PlacedLine[] = []
  for (const b of fullBlocks) {
    const chunk = place(b, budget - fullRows.length, width)
    for (const l of chunk) fullRows.push(l)
  }
  add(fullRows)

  const bodyBudget = budget === Number.POSITIVE_INFINITY ? Number.POSITIVE_INFINITY : Math.max(0, budget - fullRows.length)
  if (bodyBudget > 0) {
    if (twoColumn) {
      const leftW = leftWidth
      const rightW = rightWidth
      const columns: [PlacedLine[], PlacedLine[]] = [[], []]
      const ordered = [...leftBlocks.map((b) => ({ b, slot: 0 as 0 | 1 })), ...rightBlocks.map((b) => ({ b, slot: 1 as 0 | 1 }))].sort(
        (x, y) => x.b.priority - y.b.priority,
      )
      for (const { b, slot } of ordered) {
        const colW = slot === 0 ? leftW : rightW
        const used = Math.max(columns[0].length, columns[1].length)
        const chunk = place(b, bodyBudget - used, colW)
        for (const l of chunk) columns[slot].push(l)
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
        const chunk = place(b, bodyBudget - used, columnW)
        for (const l of chunk) rows.push({ line: truncLine(l.line, columnW), hits: l.hits })
        used += chunk.length
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
  const renderedRows = trimmed.map((l, i) => {
    if (l.hits?.length) {
      // The same clipping as placedWithHits, for rows only this final pass cuts (merged
      // two-column rows and builder lines that were never truncated): a target that reaches the
      // rendered ellipsis is invisible and must not fire (V15/F4).
      const room = widthOf(l.line) > width ? Math.max(0, width - 1) : width
      for (const h of l.hits) {
        const start = Math.min(h.start, room)
        const end = Math.min(h.end, room)
        if (end > start) targets.push({ row: i, hit: { ...h, start, end } })
      }
    }
    return truncLine(l.line, width)
  })
  return { rows: renderedRows, targets }
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
