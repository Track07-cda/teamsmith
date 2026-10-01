// The frame: four pages (the board page is a kanban over the board's states; the focused card's
// read-only markdown detail view replaces it while open), a settings overlay, four width tiers —
// and nothing else.
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
import { markdownMemo } from './markdown.js'
import { fill, keyLabel, OVERLAY_LABEL_W } from './strings/index.js'
import type { Strings } from './strings/index.js'
import { BOARD_LANES } from './types.js'
import type {
  Action,
  ActivityBlock,
  BoardRow,
  ChangeRow,
  Density,
  DetailBlock,
  DetailWindow,
  FocusRef,
  Frame,
  FrameInput,
  Hit,
  LaneWindow,
  Line,
  PageId,
  PanelAgent,
  PanelBlocks,
  PanelData,
  PlacedLine,
  PrefName,
  QueueEntry,
  Impediment,
  Segment,
  SettingsBlock,
  SettingsChoiceEntry,
  SettingsKey,
  SettingsSeat,
  SettingsWindow,
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

function ruleTitle(title: string, width: number, tone: Tone = 'heading'): Line {
  if (width <= 0) return []
  if (!title) return ln(seg(rule(width, BOX_H), 'dim'))
  const labelW = dispWidth(title)
  if (labelW + 4 >= width) return truncLine(ln(seg(BOX_H + BOX_H + ' ', 'dim'), seg(title, tone)), width)
  const left = 2
  const right = width - left - 1 - labelW // ── title ─…
  return ln(seg(rule(left, BOX_H) + ' ', 'dim'), seg(title, tone), seg(' ' + rule(Math.max(0, right - 1), BOX_H), 'dim'))
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
  /** The board page's lane windows as rendered (the App clamps its arrows and wheel against them). */
  lanes?: LaneWindow[]
  /** The detail view's document window as rendered (the App clamps its arrows and wheel). */
  detail?: DetailWindow
  /** The project-settings view's row window as rendered (P22/B2). */
  settings?: SettingsWindow
  /** The work page's board rows in the order it drew them (P20/B5: the App's `↑`/`↓` walk this). */
  order?: FocusRef[]
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
  /** History rows the board keeps visible before folding (default `BOARD_DONE_KEEP`; a flush
   * column raises it so the spare height shows real history instead of blank card space). */
  boardDoneKeep?: number
  /** Card rows the board page's lanes may show (the assembly hands over its real budget; the
   * default keeps a standalone layout honest). */
  laneRows?: number
  /** Document rows the detail view may show (the assembly's real budget for the open document). */
  detailRows?: number
  /** Card rows / document lines the project-settings view may draw below its card frame (the
   * assembly's real budget: the view spends it on the row window, its tail and blank fill, so the
   * card fills the pane — P32). */
  settingsRows?: number
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
  // agent-death-reason: the full state cell carries the classified cause (`▲ 已死 signal=9 · quota`);
  // the minimal layout drops it together with the state text (stateCellText's minimal branch).
  const cause = a.cause ? ` · ${a.cause}` : ''
  return `${glyph} ${text}${cause}`
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
      : `${s.outboxLabel} ${ob.queued}${ob.held > 0 ? fill(s.outboxHeldSuffix, { n: ob.held }) : ''}${ob.impeded && ob.impeded > 0 ? ` ${fill(s.outboxImpededSuffix, { n: ob.impeded })}` : ''}`
  const lines: PlacedLine[] = [
    { line: truncLine(ln(seg(' '), seg(pmText), seg('    '), seg(pend), seg('    '), seg(queue, 'accent')), ctx.width) },
  ]
  // M46: a degraded delivery lane gets its own line (text token, not colour alone): the PM card
  // itself cannot carry it, and "messages still go through the paste path" is actionable.
  const delivery = !panel.pm || deg.has('pm') ? '' : (panel.pm.delivery_warning || '')
  if (delivery) {
    lines.push({ line: truncLine(ln(seg(' '), seg(fill(s.pmDeliveryWarning, { reason: delivery }), 'warn')), ctx.width) })
  }
  // delivery-truth D2: the machine reasons ride the status band so the plain-text exit (the
  // overview) names the same count/reasons as the TUI's messages page.
  if (ob && !deg.has('outbox') && ob.impeded && ob.impeded > 0) {
    const reasons = Array.from(new Set((ob.impediments ?? []).map((i) => i.reason))).join(' · ') || s.dash
    lines.push({ line: truncLine(ln(seg(' '), seg(fill(s.queueImpededLine, { n: ob.impeded, reasons }), 'warn')), ctx.width) })
  }
  return {
    id: 'status',
    full: true,
    priority: 1,
    lines,
    separator: 'none',
  }
}

function capacityBlock(ctx: Ctx): Block {
  const { s, panel, deg } = ctx
  const c = panel.capacity
  if (!c || deg.has('capacity')) {
    return { id: 'capacity', title: s.capacityLabel, full: true, priority: 2, lines: [{ line: ln(seg(` ${s.dash}`, 'dim')) }] }
  }
  const spark0 = Math.min(18, Math.max(0, ctx.width - 60))
  // P144: one reading per judged filesystem, the `—` fallback for a figure that cannot be read or
  // an inode table the filesystem does not report. The spark keeps its width rule minus what the
  // readings take (the band is one line: RAM, swap, the estimate, the filesystems, the chart).
  const diskSegs = (c.disk ?? []).flatMap((d) => [
    seg(' ｜ ', 'dim'),
    seg(
      fill(s.capacityDisk, {
        path: d.path,
        mb: d.avail_mb == null ? s.dash : fmtMB(d.avail_mb),
        ino: d.free_inodes == null ? s.dash : String(d.free_inodes),
      }),
    ),
  ])
  const diskW = diskSegs.reduce((n, x) => n + dispWidth(x.text), 0)
  const spark = sparkline(c.spark, Math.max(0, spark0 - diskW))
  const line = ln(
    seg(fill(s.capacityRam, { mb: fmtMB(c.ram_avail_mb) })),
    seg(' ｜ ', 'dim'),
    seg(fill(s.capacitySwap, { mb: fmtMB(c.swap_free_mb) })),
    seg(' ｜ ', 'dim'),
    seg(fill(s.capacityAgents, { n: c.agents })),
    ...diskSegs,
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
    case 'dropped':
      return s.taskDropped
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

/** History rows the board keeps visible before folding the rest into one counted line. */
const BOARD_DONE_KEEP = 5

/** How many done/dropped rows the board folds away at the current history limit. */
function boardFoldedRows(ctx: Ctx): number {
  if (ctx.deg.has('board')) return 0
  const rows = ctx.blocks.board?.rows ?? []
  let history = 0
  for (const r of rows) if (r.state === 'done' || r.state === 'dropped') history++
  return Math.max(0, history - Math.max(1, ctx.boardDoneKeep ?? BOARD_DONE_KEEP))
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
  // `done` and `dropped` rows are history: only the newest `keep` render, the rest fold into one
  // counted line (the design's done-collapse, extended to dropped rows so the live board stays
  // small). `boardDoneKeep` lets the assembly raise that limit when the column has spare height.
  const doneRows = rows.filter((r) => r.state === 'done' || r.state === 'dropped')
  const keep = Math.max(1, ctx.boardDoneKeep ?? BOARD_DONE_KEEP)
  const keepDone = new Set(doneRows.slice(-keep).map((r) => r.id))
  const folded = doneRows.filter((r) => !keepDone.has(r.id)).length
  // M34 (the user's call after a live look at the work page): the card reads active work first.
  // Every todo/wip/review/blocked row keeps its BOARD.md order above the history, and the kept
  // done/dropped rows follow in the same file order the kanban page renders its lanes in (the file
  // lists oldest -> newest, so the newest kept row sits directly under the active rows and the
  // folded count — the older ones — stays last). Only the row order changes: the counts row, the
  // keep window and the fold are untouched.
  const rendered = [
    ...rows.filter((r) => r.state !== 'done' && r.state !== 'dropped'),
    ...rows.filter((r) => (r.state === 'done' || r.state === 'dropped') && keepDone.has(r.id)),
  ]
  // The focus the rows are drawn with (P20/B5): the shared row focus when it is among the drawn
  // rows, otherwise the first drawn row — the requirement's "the focused row is always among
  // the rows the block renders". An empty or degraded board has no drawn row, hence no focus.
  // M48: the focus names a **row**, not a bare id — two rows may share one id, and matching by id
  // highlights both at once and freezes the `↑`/`↓` walk on the first of them.
  const ordinals = dupOrdinals(rows)
  const named = focusRow(rows, ctx.view.focus)
  const focusedRow = named && rendered.includes(named) ? named : (rendered[0] ?? null)
  const order = rendered.map((r) => refFor(r, ordinals))
  for (const r of rendered) {
    const focused = r === focusedRow
    const row = ln(
      seg(focused ? `${FOCUS_CURSOR} ` : '  ', focused ? 'selected' : 'dim'),
      seg(`${GLYPH[r.state] ?? '·'} `, BOARD_STATE_TONE[r.state] ?? 'text'),
      seg(cell(r.id, 10), focused ? 'selected' : 'accent'),
      seg(cell(r.agent, 8), 'dim'),
      seg(cell(boardStateText(r.state, s), 8), BOARD_STATE_TONE[r.state] ?? 'text'),
      seg(r.title),
    )
    const action: Action = focused ? { kind: 'open-focused', lane: r.state } : { kind: 'focus', lane: r.state, id: r.id, nth: ordinals.get(r) ?? 0 }
    lines.push(placedWithHits(row, ctx.view.tui ? [{ start: 0, end: widthOf(row), action }] : undefined, width))
  }
  if (folded > 0) lines.push({ line: truncLine(ln(seg(`  ${fill(s.boardDoneCollapsed, { n: folded })}`, 'dim')), width) })
  return {
    id: 'board',
    title: fill(s.boardHeadingCount, { n: board.total ?? rows.length }),
    priority: 10,
    lines,
    order,
    summary: { line: truncLine(ln(seg(` ${fill(s.boardHeadingCount, { n: board.total ?? rows.length })}`, 'heading')), width) },
  }
}

// ------------------------------------------------------------------ the board page (kanban, P18/B2)

/** The six lanes, in the order BOARD.md's own header legend declares — the file is the contract. */
const LANES: readonly string[] = BOARD_LANES
/** The state glyph a card carries; the state's name lives in the lane header. */
const LANE_GLYPH: Record<string, string> = { todo: '·', wip: '▸', review: '◆', done: '✓', blocked: '✗', dropped: '—' }
/** Columns between two lanes side by side. */
const LANE_GAP = 1
/** Card rows a lane shows when nobody handed the block a height budget (standalone layout). */
const LANE_KEEP_DEFAULT = 4
/** Card slots a lane reserves for its two edge counters (an edge that hides cards shows their count). */
const LANE_MARKER_SLOTS = 2
/** Rows a lane column spends outside its card slots: the header border and the bottom border. */
const LANE_CHROME_ROWS = 2
/** The cursor in front of the focused card: a glyph, never color alone. */
const FOCUS_CURSOR = '›'
/** The folded lane's marker; an unfolded lane's header carries the mirror marker (P123). */
const FOLD_MARKER = '▸'
const UNFOLD_MARKER = '▾'
/** P125: the side-by-side folded lane's three-column frame (border, ellipsis column, border). */
const FOLD_FRAME_W = 3
/** P125: the frame's middle-column glyphs — the horizontal ellipsis, its vertical twin. */
const FOLD_ELLIPSIS = '…'
const FOLD_VERT_ELLIPSIS = '⋮'
/** The grouped form's pseudo-lane key for the single page window (`< 100` columns). */
const GROUPED_WINDOW = '\u0000page'

/** The history lanes anchor their window on the newest cards. */
function laneAnchorsNewest(lane: string): boolean {
  return lane === 'done' || lane === 'dropped'
}

function laneLabel(lane: string, s: Strings): string {
  return boardStateText(lane, s)
}

/** The cards of one lane, in BOARD.md order (the file lists oldest → newest). */
function laneCards(rows: BoardRow[], lane: string): BoardRow[] {
  return rows.filter((r) => r.state === lane)
}

/**
 * The board page's effective fold state for one lane (P123). An explicit fold wins over an explicit
 * show (the explicit hide is the stronger statement); a lane nobody named folds only while it is
 * empty and the empty default is on. The default is recomputed per frame, so an empty lane unfolds
 * by itself as soon as it holds a card, while an explicit state survives emptiness and restarts.
 */
function laneFolded(view: ViewState, lane: string, empty: boolean): boolean {
  if ((view.boardFold ?? []).includes(lane)) return true
  if ((view.boardShow ?? []).includes(lane)) return false
  return empty && (view.boardEmptyFold ?? true)
}

/** The folded lane's marker + label + count; the folded token is the line's dim tail. */
function foldedLaneHead(s: Strings, lane: string, count: number): string {
  return `${FOLD_MARKER} ${laneLabel(lane, s)} ${count}`
}

/**
 * A folded lane renders as exactly this one line: the marker, the label, the count and the folded
 * token, truncated to the width it was given. When the focused card lives in the lane the line
 * carries the cursor glyph and the selected tone. The line owns the lane's click/wheel region
 * (clicking it toggles the fold; the wheel stays this lane's and never reaches the page behind it).
 *
 * P125: this is the grouped tier's form, where folding saves rows. In the side-by-side tier the
 * folded lane takes the three-column frame instead (`foldedLaneFrame`), so the columns the frame
 * does not use go to the unfolded lanes.
 *
 * P128: the in-place line sits in the column its own card lines use — the grouped card rows are
 * `' '` + cursor + glyph, so the folded line takes the same leading indent and the focus cursor's
 * column, its fold marker landing in the cards' state-glyph column. The lane header keeps its own
 * marker column, which is why the old line looked grouped with the header instead of the cards.
 */
function foldedLaneLine(ctx: Ctx, lane: string, count: number, width: number, focused: boolean): PlacedLine {
  const { s } = ctx
  const line = ln(
    seg(' '),
    seg(focused ? `${FOCUS_CURSOR} ` : '  ', focused ? 'selected' : 'dim'),
    seg(foldedLaneHead(s, lane, count), focused ? 'selected' : 'heading'),
    seg(s.laneFolded, 'dim'),
  )
  const hits: Hit[] | undefined = ctx.view.tui ? [{ start: 0, end: Math.max(1, width), action: { kind: 'lane-fold', lane } }] : undefined
  return { line: truncLine(line, width), hits }
}

/**
 * P125: a folded lane in the side-by-side tier is a three-column frame that keeps the lane's
 * position in the fixed lane order — a rounded corner at each of its four corners (the panel's own
 * glyphs), a vertical border on each side and the ellipsis in the middle column, drawn down the
 * lane's height (the vertical ellipsis marks the middle row). The frame alone says which lane it is
 * because the order never moves. When the focused card lives in the lane its first body row carries
 * the focus cursor and the selected tone — exactly one cursor in the frame. Every row owns the
 * lane's click/wheel region: a click toggles the fold and the wheel stays this lane's, never the
 * page behind it.
 */
function foldedLaneFrame(ctx: Ctx, lane: string, focused: boolean, height: number): PlacedLine[] {
  const body = Math.max(1, Math.floor(height) - 2)
  const mid = Math.floor((body - 1) / 2)
  const hit = (): Hit[] | undefined =>
    ctx.view.tui ? [{ start: 0, end: FOLD_FRAME_W, action: { kind: 'lane-fold', lane } }] : undefined
  const out: PlacedLine[] = [{ line: ln(seg(BOX_TL + BOX_H + BOX_TR, 'dim')), hits: hit() }]
  for (let i = 0; i < body; i++) {
    const cursor = focused && i === 0
    const glyph = cursor ? FOCUS_CURSOR : i === mid ? FOLD_VERT_ELLIPSIS : FOLD_ELLIPSIS
    out.push({ line: ln(seg(BOX_V, 'dim'), seg(glyph, cursor ? 'selected' : 'dim'), seg(BOX_V, 'dim')), hits: hit() })
  }
  out.push({ line: ln(seg(BOX_BL + BOX_H + BOX_BR, 'dim')), hits: hit() })
  return out
}

/**
 * Every row's duplicate ordinal: which occurrence of its id it is (0-based, in BOARD.md order).
 * One pass over the rows, so no view pays a full scan per card for the M48 row identity.
 */
function dupOrdinals(rows: BoardRow[]): Map<BoardRow, number> {
  const seen = new Map<string, number>()
  const out = new Map<BoardRow, number>()
  for (const r of rows) {
    const nth = seen.get(r.id) ?? 0
    out.set(r, nth)
    seen.set(r.id, nth + 1)
  }
  return out
}

/** The focus reference naming one row, given the board's duplicate ordinals. */
function refFor(row: BoardRow, ordinals: Map<BoardRow, number>): FocusRef {
  return { lane: row.state, id: row.id, nth: ordinals.get(row) ?? 0 }
}

/**
 * The exact row a focus names (M48): the `nth` occurrence of its id in BOARD.md order. A focus
 * without `nth` names the first occurrence, so an older focus or a hand-made fixture still
 * resolves; an id whose duplicates shrank falls through to null and the caller applies the
 * existing fallback.
 */
export function focusRow(rows: BoardRow[], focus?: { id: string; nth?: number } | null): BoardRow | null {
  if (!focus) return null
  const want = Math.max(0, focus.nth ?? 0)
  let nth = 0
  for (const r of rows) {
    if (r.id !== focus.id) continue
    if (nth === want) return r
    nth++
  }
  return null
}

/** The focus reference for one row (the App sets the focus from a click or a `←`/`→` step). */
export function focusRefOf(rows: BoardRow[], row: BoardRow): FocusRef {
  return refFor(row, dupOrdinals(rows))
}

/**
 * The focused card resolved against the current board. An id that left the board lands on its lane's
 * first card (and a lane that emptied, on the first card of the first non-empty lane); a null focus
 * starts there too. Pure and shared with the App, which owns the focus state — the layout only
 * renders and windows it.
 */
export function resolveFocus(
  rows: BoardRow[],
  focus?: FocusRef | null,
): FocusRef | null {
  return resolveFocusWith(rows, dupOrdinals(rows), focus)
}

/** `resolveFocus` with the board's ordinals already built (the frame path builds them once per frame). */
function resolveFocusWith(
  rows: BoardRow[],
  ordinals: Map<BoardRow, number>,
  focus?: FocusRef | null,
): FocusRef | null {
  if (focus) {
    const named = focusRow(rows, focus)
    if (named) return refFor(named, ordinals)
    // The named duplicate left the board: the id's first row keeps the focus (a reordered board
    // must not lose the entry).
    const first = rows.find((r) => r.id === focus.id)
    if (first) return refFor(first, ordinals)
    const sameLane = laneCards(rows, focus.lane)[0]
    if (sameLane) return refFor(sameLane, ordinals)
  }
  for (const lane of LANES) {
    const card = laneCards(rows, lane)[0]
    if (card) return refFor(card, ordinals)
  }
  return null
}

/**
 * One lane's visible window. `size` is the number of card rows the frame can spend, the offset is
 * clamped to the lane, and the focused card (when it lives in this lane) always stays inside — the
 * window follows the focus, while the wheel's own offset may scroll away from it.
 */
function laneWindow(
  ctx: Ctx,
  lane: string,
  cards: BoardRow[],
  size: number,
  target: BoardRow | null,
  offsetKey = lane,
): { start: number; end: number; above: number; below: number } {
  const span = Math.max(1, Math.floor(size))
  const count = cards.length
  const maxStart = Math.max(0, count - span)
  const explicit = ctx.view.laneOffset?.[offsetKey]
  let start = explicit == null || Number.isNaN(explicit) ? (laneAnchorsNewest(lane) ? maxStart : 0) : explicit
  start = Math.max(0, Math.min(maxStart, Math.floor(start)))
  // The window follows the focus only while the lane has no offset of its own: once the wheel (or a
  // card move) set one, that offset wins — otherwise the wheel could never scroll away from the
  // focus, which is exactly what the mouse requirement asks it to do.
  if (explicit == null && target && target.state === lane) {
    const idx = cards.indexOf(target)
    if (idx >= 0) {
      if (idx < start) start = idx
      else if (idx >= start + span) start = Math.min(maxStart, idx - span + 1)
    }
  }
  return { start, end: Math.min(count, start + span), above: start, below: Math.max(0, count - (start + span)) }
}

/**
 * One card's line: cursor, state glyph, id, title — truncated to the lane's width. P123: the agent
 * and the phase never render here; the focused card's pair rides the key band instead, so the title
 * is the line's last truncation and no width exists at which a card drops its title to keep them.
 */
function cardLine(ctx: Ctx, card: BoardRow, width: number, focused: boolean): Line {
  const { minimal } = ctx
  const glyph = LANE_GLYPH[card.state] ?? '·'
  const tone = BOARD_STATE_TONE[card.state] ?? 'text'
  const cursorTone: Tone = focused ? 'selected' : 'dim'
  const idTone: Tone = focused ? 'selected' : 'accent'
  const cursor = focused ? `${FOCUS_CURSOR} ` : '  '
  if (minimal) {
    // Under 60 columns a card is one line: glyph, id, title (the demoted pair drops first).
    return truncLine(ln(seg(cursor, cursorTone), seg(`${glyph} `, tone), seg(`${cell(card.id, 6)} `, idTone), seg(card.title)), width)
  }
  return truncLine(ln(seg(cursor, cursorTone), seg(`${glyph} `, tone), seg(`${card.id} `, idTone), seg(card.title)), width)
}

/**
 * The click target of a card: the focused card opens, any other card takes the focus. While the
 * detail view is open the cards keep **no** targets (the replaced-blocks rule the settings overlay
 * follows too) — the view renders on top of this page in the detail batch.
 */
function cardAction(card: BoardRow, focused: boolean, nth: number): Action {
  return focused ? { kind: 'open-focused', lane: card.state } : { kind: 'focus', lane: card.state, id: card.id, nth }
}

/** The wheel's lane target: any spot inside a lane that is not a card resolves to this lane. */
function laneHover(lane: string): Action {
  return { kind: 'lane-scroll', lane, delta: 0 }
}

/** One lane as a column of cards; `slots` card rows plus the two borders keep the lanes aligned. */
function laneColumn(
  ctx: Ctx,
  lane: string,
  width: number,
  slots: number,
  target: BoardRow | null,
  ordinals: Map<BoardRow, number>,
  windows: LaneWindow[],
  folded: boolean,
): PlacedLine[] {
  const { s } = ctx
  const cards = laneCards(ctx.blocks.board?.rows ?? [], lane)
  if (folded) {
    // P123: the fold branch returns before the window loop, so not one card line (nor an edge
    // counter, nor the empty marker) is built — the bounded-frame promise can only get cheaper.
    // The window record reports nothing to scroll; the frame keeps the lane body's height so the
    // board keeps its shape when every lane folds.
    // P125: in the side-by-side tier the folded lane is the three-column frame — the columns it
    // does not use are handed to the unfolded lanes by the width algorithm in `kanbanBlock`.
    windows.push({ lane, offset: 0, visible: 0, count: 0 })
    const focused = target != null && target.state === lane
    return foldedLaneFrame(ctx, lane, focused, slots + 2)
  }
  const win = laneWindow(ctx, lane, cards, slots - LANE_MARKER_SLOTS, target)
  windows.push({ lane, offset: win.start, visible: win.end - win.start, count: cards.length })
  // Everything in the lane that is not a card resolves to the lane itself, so the wheel scrolls the
  // lane under the cursor (the card hits win the lookup where a card is — `.find()` takes the first).
  const hover: Hit[] | undefined = ctx.view.tui ? [{ start: 0, end: width, action: laneHover(lane) }] : undefined
  // P123: the lane's header line (this top border) is the `c` key's click target; the wheel over it
  // is this lane's too (the App's wheel branch accepts the same action).
  const headerHit: Hit[] | undefined = ctx.view.tui ? [{ start: 0, end: width, action: { kind: 'lane-fold', lane } }] : undefined
  const out: PlacedLine[] = [{ line: cardTop(`${UNFOLD_MARKER} ${laneLabel(lane, s)} ${cards.length}`, width), hits: headerHit }]
  if (win.above > 0) out.push(cardBody({ line: ln(seg(` ${fill(s.laneHiddenAbove, { n: win.above })}`, 'dim')) }, width))
  if (!cards.length) out.push(cardBody({ line: ln(seg(` ${s.kanbanEmptyLane}`, 'dim')) }, width))
  for (let i = win.start; i < win.end; i++) {
    const card = cards[i]
    const focused = card === target
    const line = cardLine(ctx, card, Math.max(0, width - 4), focused)
    const hits: Hit[] | undefined =
      ctx.view.tui && !ctx.view.detail
        ? [{ start: 0, end: Math.max(1, Math.min(width - 4, widthOf(line))), action: cardAction(card, focused, ordinals.get(card) ?? 0) }]
        : undefined
    out.push(cardBody({ line, hits }, width))
  }
  if (win.below > 0) out.push(cardBody({ line: ln(seg(` ${fill(s.laneHiddenBelow, { n: win.below })}`, 'dim')) }, width))
  while (out.length < slots + 1) out.push(cardBody({ line: [] }, width))
  out.push({ line: cardBottom(width) })
  const placed = out.slice(0, slots + 2)
  if (hover) for (const l of placed) if (!l.hits?.length) l.hits = hover
  return placed
}

/** Merge equally-sized lane columns into rows, carrying each column's hits at its own offset. */
function mergeLaneColumns(cols: PlacedLine[][], widths: number[]): PlacedLine[] {
  const rows: PlacedLine[] = []
  const height = cols.reduce((n, col) => Math.max(n, col.length), 0)
  for (let i = 0; i < height; i++) {
    const line: Line = []
    const hits: Hit[] = []
    let x = 0
    cols.forEach((col, ci) => {
      const cellW = widths[ci]
      if (ci > 0) {
        line.push(seg(' '.repeat(LANE_GAP)))
        x += LANE_GAP
      }
      const placed = col[i]
      if (placed) {
        line.push(...padLine(placed.line, cellW))
        for (const h of placed.hits ?? []) hits.push({ ...h, start: h.start + x, end: h.end + x })
      } else {
        line.push(seg(' '.repeat(cellW)))
      }
      x += cellW
    })
    rows.push(hits.length ? { line, hits } : { line })
  }
  return rows
}

/** Under 100 columns the page is one column grouped by state, one window for the whole page. */
function kanbanGrouped(
  ctx: Ctx,
  rows: BoardRow[],
  target: BoardRow | null,
  ordinals: Map<BoardRow, number>,
): { lines: PlacedLine[]; lanes: LaneWindow[] } {
  const { s } = ctx
  const width = ctx.width
  const all: PlacedLine[] = []
  const focusLine = { i: -1 }
  for (const lane of LANES) {
    const cards = laneCards(rows, lane)
    if (laneFolded(ctx.view, lane, !cards.length)) {
      // P123: a folded lane is its one line here too — no cards, no empty marker, no card rows.
      const focused = target != null && target.state === lane
      if (focused) focusLine.i = all.length
      all.push(foldedLaneLine(ctx, lane, cards.length, width, focused))
      continue
    }
    const head: Hit[] | undefined = ctx.view.tui
      ? [{ start: 0, end: width, action: { kind: 'lane-fold', lane, scroll: GROUPED_WINDOW } }]
      : undefined
    all.push({ line: truncLine(ln(seg(` ${UNFOLD_MARKER} ${laneLabel(lane, s)} ${cards.length}`, 'heading')), width), hits: head })
    if (!cards.length) all.push({ line: truncLine(ln(seg(`  ${s.kanbanEmptyLane}`, 'dim')), width) })
    for (const card of cards) {
      const focused = card === target
      if (focused) focusLine.i = all.length
      const line = cardLine(ctx, card, Math.max(0, width - 2), focused)
      const hits: Hit[] | undefined =
        ctx.view.tui && !ctx.view.detail
          ? [{ start: 1, end: 1 + Math.max(1, widthOf(line)), action: cardAction(card, focused, ordinals.get(card) ?? 0) }]
          : undefined
      all.push({ line: truncLine(ln(seg(' '), ...line.slice(0)), width), hits })
    }
  }
  const span = Math.max(1, (ctx.laneRows ?? LANE_KEEP_DEFAULT) + LANE_MARKER_SLOTS)
  const maxStart = Math.max(0, all.length - span)
  let start = ctx.view.laneOffset?.[GROUPED_WINDOW] ?? 0
  start = Math.max(0, Math.min(maxStart, Math.floor(start) || 0))
  if (focusLine.i >= 0) {
    if (focusLine.i < start) start = focusLine.i
    else if (focusLine.i >= start + span) start = Math.min(maxStart, focusLine.i - span + 1)
  }
  const hover: Hit[] | undefined = ctx.view.tui ? [{ start: 0, end: width, action: laneHover(GROUPED_WINDOW) }] : undefined
  const win: PlacedLine[] = []
  if (start > 0) win.push({ line: truncLine(ln(seg(` ${fill(s.laneHiddenAbove, { n: start })}`, 'dim')), width) })
  for (let i = start; i < Math.min(all.length, start + span); i++) win.push(all[i])
  const below = Math.max(0, all.length - (start + span))
  if (below > 0) win.push({ line: truncLine(ln(seg(` ${fill(s.laneHiddenBelow, { n: below })}`, 'dim')), width) })
  if (hover) for (const l of win) if (!l.hits?.length) l.hits = hover
  return {
    lines: win,
    lanes: [{ lane: GROUPED_WINDOW, offset: start, visible: Math.min(span, Math.max(0, all.length - start)), count: all.length }],
  }
}

/** The board page: six lanes side by side (>= 100 columns) or one grouped column under it. */
function kanbanBlock(ctx: Ctx): Block | null {
  const { s, blocks, deg } = ctx
  const board = blocks.board
  if (!board) return null
  const one = (lines: PlacedLine[]): Block => ({
    id: 'kanban',
    full: true,
    priority: 1,
    separator: 'none',
    lines,
    summary: { line: truncLine(ln(seg(` ${s.boardHeadingCount}`.replace('{n}', String(board.total ?? 0)), 'heading')), ctx.width) },
  })
  if (deg.has('board')) return one([{ line: truncLine(ln(seg(` ${s.dash}`, 'dim')), ctx.width) }])
  const rows = board.rows ?? []
  if (!rows.length) return one([{ line: truncLine(ln(seg(` ${s.boardEmpty}`, 'dim')), ctx.width) }])
  const ordinals = dupOrdinals(rows)
  const focus = resolveFocusWith(rows, ordinals, ctx.view.focus)
  // M48: one row object is the focus; every `card === target` below is O(1) and two rows sharing an
  // id never both light up. The duplicate ordinals are built once per frame and shared by the
  // focus/actions (no per-lane or per-card rescan of the board).
  const target = focusRow(rows, focus)
  if (!ctx.twoColumn) {
    const grouped = kanbanGrouped(ctx, rows, target, ordinals)
    return { ...one(grouped.lines), lanes: grouped.lanes }
  }
  const slots = Math.max(2, Math.floor(ctx.laneRows ?? LANE_KEEP_DEFAULT) + LANE_MARKER_SLOTS)
  const windows: LaneWindow[] = []
  // P125: folding changes the width share, not the lane order. In the side-by-side tier a folded
  // lane is the three-column frame (`foldedLaneFrame`), so it takes exactly `FOLD_FRAME_W` columns
  // and the whole rest goes to the unfolded lanes, each never under the documented lane floor —
  // folding gives columns back and the lane row never renders wider than the usable width. The
  // verdict is computed from the width itself (the layout's own two-column tier), never a
  // hardcoded threshold here.
  const usable = Math.max(0, ctx.width - LANE_GAP * (LANES.length - 1))
  const foldOf = (lane: string): boolean => laneFolded(ctx.view, lane, !laneCards(rows, lane).length)
  const foldedLanes = LANES.filter(foldOf)
  const shownLanes = LANES.filter((lane) => !foldOf(lane))
  const widths = new Map<string, number>()
  if (!foldedLanes.length) {
    // Nobody folded: the historical even share, so an all-unfolded board keeps its exact geometry.
    const laneW = Math.max(8, Math.floor(usable / LANES.length))
    for (const lane of LANES) widths.set(lane, laneW)
  } else if (!shownLanes.length) {
    // Everybody folded: the row is six three-column frames (the free width has no lane to take).
    for (const lane of foldedLanes) widths.set(lane, FOLD_FRAME_W)
  } else {
    for (const lane of foldedLanes) widths.set(lane, FOLD_FRAME_W)
    const eachShown = Math.max(8, Math.floor((usable - FOLD_FRAME_W * foldedLanes.length) / shownLanes.length))
    for (const lane of shownLanes) widths.set(lane, eachShown)
  }
  const cols = LANES.map((lane) => laneColumn(ctx, lane, widths.get(lane) ?? 8, slots, target, ordinals, windows, foldedLanes.includes(lane)))
  return { ...one(mergeLaneColumns(cols, LANES.map((lane) => widths.get(lane) ?? 8))), lanes: windows }
}

// ------------------------------------------------------------------ the detail view (markdown, P18/B3)

/** Document rows a standalone detail layout shows (no assembly budget available). */
const DETAIL_KEEP_DEFAULT = 16

/**
 * The detail view's content width: inside a card the chrome eats four columns (`│ ` + ` │`), so the
 * document is wrapped to what the frame will really show at that density.
 */
function blockInnerW(ctx: Ctx): number {
  return Math.max(1, isFramed(ctx) ? ctx.width - 4 : ctx.width)
}

/** The file tab row of the detail view: the active tab in the accent tone, every tab clickable. */
function detailTabs(ctx: Ctx, files: DetailBlock['files'], active: number, width: number): PlacedLine {
  const line: Line = [seg(' ')]
  const hits: Hit[] = []
  let x = 1
  files.forEach((file, i) => {
    if (i > 0) {
      line.push(seg('  '))
      x += 2
    }
    const text = i === active ? `[${file.tab}]` : file.tab
    const start = x
    line.push(seg(text, i === active ? 'accent' : 'dim'))
    x += dispWidth(text)
    if (ctx.view.tui) hits.push({ start, end: x, action: { kind: 'detail-tab', index: i } })
  })
  return placedWithHits(line, hits, width)
}

/**
 * The detail view: the entry's associated files as tabs plus the open document, read-only. It
 * replaces the kanban on page 4 exactly the way the settings overlay replaces a page's blocks —
 * the title band, the page tabs and the key band stay (V16 F-V16-4's replacement rule). The
 * document rows are windowed against the height the assembly hands over (the bounded-frame rule:
 * more pane means more document, never more blank).
 */
function detailBlock(ctx: Ctx): Block | null {
  const { s, blocks, deg } = ctx
  const id = ctx.view.detail ?? ''
  const width = blockInnerW(ctx)
  const title = fill(s.detailTitle, { id })
  const one = (lines: PlacedLine[], detail?: DetailWindow): Block => ({
    id: 'detail',
    full: true,
    priority: 1,
    separator: 'none',
    title,
    lines,
    detail,
    summary: { line: truncLine(ln(seg(` ${title}`, 'heading')), ctx.width) },
  })
  if (deg.has('detail')) return one([{ line: truncLine(ln(seg(` ${s.dash}`, 'dim')), width) }])
  const data = blocks.detail
  if (!data) {
    // The block has not arrived yet (the open was just requested): say so instead of claiming the
    // entry has no files.
    return one([{ line: truncLine(ln(seg(` ${s.detailLoading}`, 'dim')), width) }], { index: 0, total: 0, visible: 0, offset: 0 })
  }
  const files = data.files ?? []
  if (!files.length) return one([{ line: truncLine(ln(seg(` ${s.detailNoFiles}`, 'dim')), width) }])
  const detail = data as DetailBlock
  const index = Math.max(0, Math.min(files.length - 1, Math.floor(ctx.view.detailIndex ?? 0) || 0))
  const active = files[index]
  const rows: PlacedLine[] = [detailTabs(ctx, files, index, width)]
  if (active.truncated) rows.push({ line: truncLine(ln(seg(` ${s.detailTruncated}`, 'warn')), width) })
  if (detail.file !== active.path) {
    // The tab was switched and its text has not arrived yet: the tabs stay live, the body says why.
    rows.push({ line: truncLine(ln(seg(` ${s.detailLoading}`, 'dim')), width) })
    return one(rows, { index, total: 0, visible: 0, offset: 0 })
  }
  const doc = markdownMemo(active.path, detail.text, width)
  const budget = Math.max(1, ctx.detailRows ?? DETAIL_KEEP_DEFAULT)
  const available = Math.max(1, budget - rows.length)
  const maxStart = Math.max(0, doc.length - available)
  const offset = Math.max(0, Math.min(maxStart, Math.floor(ctx.view.detailScroll ?? 0) || 0))
  for (let i = offset; i < Math.min(doc.length, offset + available); i++) rows.push(doc[i])
  // The bounded-frame rule's last resort: a document shorter than the pane keeps the blank space
  // *inside* the card, so the card fills the height and the key band stays the last row.
  while (rows.length < budget) rows.push({ line: [] })
  return one(rows, { index, total: doc.length, visible: Math.min(available, Math.max(0, doc.length - offset)), offset })
}

// ------------------------------------------------------------------ project settings (P22/B2)
//
// The view is a listing of the contract: one row per schema key plus one per key the file carries
// that the schema does not know, grouped by the functional domain the **command** reports on the
// row's `group` (P30 — the console owns no second table), then the model seats block. Rows, groups
// and classes come from the `settings` block's JSON at render time; a key added to the command's
// schema shows up without rebuilding `panel.js`. The list is windowed against the height the
// assembly hands over (the bounded-frame rule: more pane means more rows, never more blank).

// The row's identity column is a **label** (M49), not the key name: the table's labels are human
// sentences, so the column only has to hold the longest of them (zh is the wide language here;
// a longer en label is cut by `cell()`, the same rule the key names followed).
const SETTINGS_LABEL_W = 22
const SETTINGS_AUDIT_LINES = 3
// The tail the block draws under its row window: the CLI hint, a blank, the audit heading and up to
// `SETTINGS_AUDIT_LINES` audit lines (the heading always has one line under it — a dash when the
// command's log is empty), plus `SETTINGS_COUNT_ROWS`, the pessimistic reservation for the two
// hidden-row counts (`↑n`/`↓n`). Reserving **both** counts is what keeps the block inside the frame
// once the list is longer than the window: with only the tail reserved, a full window plus a full
// audit tail overflowed and the whole view degraded to its one-line summary (measured in M55's
// pairlist route: the seats block the route had just focused disappeared from the frame).
//
// P32 (the user's second report, 2026-09-22): the reservation is a *ceiling*, not a fixed cost. The
// window spends what the tail does not need (a count line is only drawn when the window really
// hides rows at that edge), and the block pads its card to the lines it was handed — so the pane's
// height shows contract rows instead of the page's blank space.
const SETTINGS_COUNT_ROWS = 2

/**
 * The sum M55 calibrated: the two count lines, the CLI hint, a blank, the audit heading and the audit
 * tail. The row list treats it as a ceiling and hands back what it does not draw (P32); the two pickers
 * keep it as the bound of their own *paged* list (title + interval + the two hidden-count lines + blank
 * + hint, then the entries) — a long vocabulary shows a `↑n`/`↓n` window that scrolls instead of
 * flooding the pane, which is what the archived `choices` fixture calibrates its twenty-eight model
 * records against. Their cards still fill (the pad below), so the key band stays the frame's last row.
 */
const SETTINGS_TAIL_ROWS = SETTINGS_COUNT_ROWS + 1 + 1 + 1 + SETTINGS_AUDIT_LINES

/** One drawn row of the project-settings view (group headings are not focusable). */
export type SettingsRow =
  | { kind: 'group'; label: string; tone: Tone }
  | { kind: 'key'; key: SettingsKey }
  | { kind: 'seat-group'; label: string }
  | { kind: 'seat'; seat: SettingsSeat }

export function settingsClassLabel(s: Strings, cls: string): string {
  if (cls === 'restart') return s.settingsBadgeRestart
  if (cls === 'refuse') return s.settingsBadgeRefuse
  return s.settingsBadgeApply
}

/**
 * The effect class's tone (P30/D4): the *badge*'s tone, never the whole row's. `restart` is the one
 * class that warns, `refuse` recedes, and `apply` stays the plain text tone — 48 of 111 rows would
 * shout in green while the user's question is "does this need a restart?". Colour is never the only
 * channel: the badge's word always carries the class (the panel's standing rule).
 */
function settingsClassTone(cls: string): Tone {
  if (cls === 'restart') return 'warn'
  if (cls === 'refuse') return 'dim'
  return 'text'
}

/**
 * A functional group's heading label: `group_<token>` from the tables, falling back to the raw
 * token when the table has none (a schema freshly edited against the committed bundle) — the same
 * visible fallback `keyLabel` uses for an unknown key. Nothing here maps a key to a group.
 */
function groupLabel(s: Strings, token: string): string {
  const label = s[`group_${token}`]
  return typeof label === 'string' && label.length > 0 ? label : token
}

/** The CLI's own three source labels (the console invents no fourth state). */
export function settingsSourceLabel(s: Strings, source: string): string {
  if (source === 'explicit') return s.seatSourceExplicit
  if (source === 'record') return s.seatSourceRecord
  return s.seatSourceConfig
}

/**
 * The view's filtered row list: the contract's keys grouped by the **record's** `group` (P30/D1-D3),
 * in the read's own order, then the seats. Pure and exported: the App walks exactly this list when
 * it moves the focus, so the keys can never disagree with what is on screen.
 *
 * The bundle owns no key→group table and no group list: the walk opens a heading whenever the
 * token changes, so a key (or a whole group) added to the command's schema appears under its
 * reported heading with the committed bundle. Rows whose token is empty — a schema row that
 * declares none, or a key the file carries and the schema does not know — are never dropped: they
 * collect into one visible trailing fallback heading, before the seats block.
 */
export function settingsViewRows(block: SettingsBlock | undefined, filter: string, s: Strings): SettingsRow[] {
  const out: SettingsRow[] = []
  if (!block || !Array.isArray(block.keys)) return out
  const needle = String(filter ?? '').trim().toLowerCase()
  const match = (...parts: string[]): boolean =>
    needle === '' || parts.some((p) => String(p ?? '').toLowerCase().includes(needle))
  // The label first (what the row shows), then the raw key and the value — the three inputs a
  // user may type into `/` (the label's words, `TEAM_…`, or the value on screen).
  const shown = block.keys.filter((k) =>
    match(keyLabel(s, k.name), k.name, k.value, k.default, k.comment, k.warning, k.route ?? ''),
  )
  const ungrouped: SettingsKey[] = []
  let openToken: string | null = null
  for (const k of shown) {
    const token = String(k.group ?? '')
    if (!token) {
      ungrouped.push(k)
      continue
    }
    if (token !== openToken) {
      out.push({ kind: 'group', label: groupLabel(s, token), tone: 'heading' })
      openToken = token
    }
    out.push({ kind: 'key', key: k })
  }
  if (ungrouped.length) {
    out.push({ kind: 'group', label: s.settingsGroupUngrouped, tone: 'heading' })
    for (const k of ungrouped) out.push({ kind: 'key', key: k })
  }
  const seats = (block.models?.seats ?? []).filter((x) =>
    match(x.agent, x.model, settingsSourceLabel(s, x.source)),
  )
  if (seats.length) {
    out.push({ kind: 'seat-group', label: s.settingsGroupSeats })
    for (const x of seats) out.push({ kind: 'seat', seat: x })
  }
  return out
}

/**
 * The badge + value column shared by a key row and a seat row. The class tone covers the **badge
 * only** (P30/D4): the value beside it stays in the plain text tone, because a class meaning is
 * not a property of the value. A row with no badge (the seats) keeps its single-tone right column.
 */
function settingsRight(ctx: Ctx, text: string, badge: string, tone: Tone, innerW: number): Line {
  const shown = truncateW(text, Math.max(6, innerW - SETTINGS_LABEL_W - 14))
  return badge === '' ? ln(seg(` ${shown}`, tone)) : ln(seg(` ${shown} · `, 'text'), seg(badge, tone))
}

function settingsKeyLine(ctx: Ctx, row: SettingsKey, focused: boolean, innerW: number): PlacedLine {
  const { s } = ctx
  const known = row.known !== false
  const valueText =
    row.set || row.value !== ''
      ? row.value === ''
        ? '\"\"'
        : row.value
      : fill(s.settingsUnset, { value: row.default || s.dash })
  const badge = known ? settingsClassLabel(s, row.class) : s.settingsUnknownBadge
  const tone: Tone = known ? settingsClassTone(row.class) : 'dim'
  const line = ln(
    seg(`${focused ? s.settingsCursor : ' '} `, 'accent'),
    // The row's main text is the human label; the raw key is not repeated here (it stays in the
    // editor's title, the confirmation line and the view's CLI hint — the places where the user
    // types the key into `team config set`). An unknown key has no label → its raw name (M49).
    seg(cell(keyLabel(s, row.name), SETTINGS_LABEL_W), focused ? 'selected' : known ? 'heading' : 'dim'),
    ...settingsRight(ctx, valueText, badge, tone, innerW).map((x) => x),
  )
  const note = (row.warning || row.route || row.comment || '').trim()
  if (note) line.push(seg(`  ${truncateW(note, Math.max(8, innerW - dispWidth(textOf(line)) - 2))}`, row.warning ? 'warn' : row.route && !known ? 'warn' : 'dim'))
  return { line }
}

function settingsSeatLine(ctx: Ctx, seat: SettingsSeat, focused: boolean, innerW: number): PlacedLine {
  const { s } = ctx
  const model = seat.model || s.dash
  const policy = seat.override ? s.seatOverride : s.seatFallback
  const line = ln(
    seg(`${focused ? s.settingsCursor : ' '} `, 'accent'),
    seg(cell(seat.agent, SETTINGS_LABEL_W), focused ? 'selected' : 'heading'),
    ...settingsRight(ctx, `${model} · ${settingsSourceLabel(s, seat.source)} · ${policy}`, '', 'dim', innerW).map((x) => x),
  )
  return { line }
}

/**
 * The focused row as the command line names it (M49): the row's label is for reading, the raw key
 * is what the user types — this line is the CLI-alignment half of the pair. A key the command does
 * not know (schema unknown) and a read-only key are said out loud rather than offered as a command
 * that would be refused; a seat gets its own `set-agent-model` route. '' when nothing is focusable.
 */
function settingsCliHint(s: Strings, rows: SettingsRow[], focus: number): string {
  const focusable = rows.filter(
    (r): r is { kind: 'key'; key: SettingsKey } | { kind: 'seat'; seat: SettingsSeat } => r.kind === 'key' || r.kind === 'seat',
  )
  const row = focusable[focus]
  if (!row) return ''
  if (row.kind === 'seat') return fill(s.settingsSeatHint, { seat: row.seat.agent })
  const key = row.key
  if (key.known === false) return fill(s.settingsUnknownHint, { key: key.name })
  if (key.class === 'refuse') return fill(s.settingsRefusedHint, { key: key.name })
  // The pairlist row is not composed here: its editor is the seats block, and the command line the
  // requirement names is the per-seat one (M55).
  if (String(key.kind ?? '') === 'pairlist') return s.settingsPairlistHint
  return fill(s.settingsCliHint, { key: key.name })
}

/**
 * The project-settings block: it replaces the page's blocks exactly as the detail view does (the
 * title band, the page tabs and the key band stay). `ctx.settingsRows` is the lines the block may draw
 * below its own card frame — the assembly hands over what the page's other blocks leave (P32), and the
 * block spends it on the row window, its tail and the blank fill, so the card fills the pane (the
 * frame's own budget still wins: an over-long block degrades by the usual chrome rules).
 */
function settingsBlock(ctx: Ctx): Block | null {
  const { s, blocks, deg } = ctx
  const width = blockInnerW(ctx)
  const one = (lines: PlacedLine[], settings?: SettingsWindow): Block => ({
    id: 'settings',
    full: true,
    priority: 1,
    separator: 'none',
    title: s.settingsViewTitle,
    lines,
    settings,
    summary: { line: truncLine(ln(seg(` ${s.settingsViewTitle}`, 'heading')), ctx.width) },
  })
  const block = blocks.settings
  if (deg.has('settings') || !block || !Array.isArray(block.keys) || !block.keys.length) {
    return one([
      placedWithHits(
        truncLine(ln(seg(` ${s.settingsViewTitle}`, 'heading'), seg('  '), seg(s.dash, 'dim')), width),
        undefined,
        width,
      ),
    ])
  }
  const rows = settingsViewRows(block, ctx.view.settingsFilter ?? '', s)
  let count = 0
  for (const r of rows) if (r.kind === 'key' || r.kind === 'seat') count += 1
  // P32: the block's budget is the **lines** it may draw below the card frame — the assembly hands
  // over everything the page's other blocks leave (`budget - fullRows - the frame's two rows`), and
  // the tail is spent out of that same budget, so what the tail does not need goes to real rows
  // instead of the page's blank space.
  const room = Math.max(3, ctx.settingsRows ?? 12)
  const focus = Math.max(0, Math.min(Math.max(0, count - 1), ctx.view.settingsFocus ?? 0))
  const explicitOffset = ctx.view.settingsOffset
  // The tail under the window: the CLI hint, a blank, the audit heading and its tail (the heading
  // always has one line under it — a dash when the command's log is empty).
  const audit = (block.audit ?? []).slice(-SETTINGS_AUDIT_LINES)
  const tailLines = 1 + 1 + 1 + Math.max(1, audit.length)
  // The row cap: each row costs at least its own line, and the tail is already spoken for.
  const desired = Math.max(1, Math.min(Math.max(1, count), Math.max(1, room - tailLines)))
  const maxOffset = Math.max(0, count - desired)
  // The first fit reserves both count lines (the M55 rule above); the growth below hands the one
  // the window does not draw back to it.
  const windowRoom = Math.max(1, room - tailLines - SETTINGS_COUNT_ROWS)
  // P30/D5 (measured while testing the wheel at the list's tail): the window is bounded by the
  // **lines** it draws, not by the row count. A group heading draws a line of its own, so a
  // heading-rich window used to overflow the space the assembly handed over — and the frame then
  // collapsed the whole block to its one-line rule/summary, leaving the wheel nothing to scroll.
  // The fit measures the rows it can really draw, so the window always fits and both hidden-row
  // counts stay honest.
  //
  // P32 (measured 2026-09-22 on a 111-key contract at 120×45): D5's price list charged a key row
  // with a note **two** lines, but `settingsKeyLine` appends the note to the row's own line — 15 of
  // the window's 17 drawn lines were billed double, which is exactly where 15 of the pane's 16
  // blank rows came from. The unit is one *focusable* row; its price is its own line plus the group
  // heading directly above it, which draws exactly when that row is inside the window.
  const units: { heading: number }[] = []
  let pendingHeading = 0
  for (const r of rows) {
    if (r.kind === 'group' || r.kind === 'seat-group') {
      pendingHeading = 1
      continue
    }
    units.push({ heading: pendingHeading })
    pendingHeading = 0
  }
  const spend = (start: number, n: number): number => {
    let cost = 0
    for (let i = start; i < Math.min(start + n, units.length); i += 1) cost += 1 + units[i].heading
    return cost
  }
  /** The rows a window starting at `start` can really draw inside the reserved window lines. */
  const fitForward = (start: number): number => {
    let visible = 0
    while (visible < desired && start + visible < units.length && spend(start, visible + 1) <= windowRoom) visible += 1
    return visible
  }
  /** The first row of the largest window that ends at the focused row (the focus never hides). */
  const fitBack = (row: number): number => {
    let start = row
    while (start > 0 && row - start + 1 < desired && spend(start - 1, row - start + 2) <= windowRoom) start -= 1
    return start
  }
  let offset: number
  let visible: number
  if (explicitOffset === undefined || explicitOffset === null) {
    // The focus-follow default: centre the focused row, then keep it inside the fitted window.
    offset = Math.max(0, Math.min(maxOffset, focus - Math.floor(desired / 2)))
    visible = fitForward(offset)
    if (focus >= offset + visible) {
      offset = fitBack(focus)
      visible = fitForward(offset)
    }
  } else {
    // The wheel's own offset (P30/D5): it wins — clamped to the row set, so a filter or a re-read
    // that shrinks the list clamps rather than losing the view. The focus is deliberately left
    // where it is; the focus keys push this offset back onto the focused row.
    offset = Math.max(0, Math.min(Math.max(0, count - 1), explicitOffset))
    visible = fitForward(offset)
  }
  if (visible === 0 && count > 0) visible = 1

  // P32: the spare the first fit kept for the count lines goes back to the window as far as it
  // really helps. A count line is drawn only when the window hides rows at that edge — a window at
  // the top hides nothing above it — so a window that ends on the last row gets the line the `↓n`
  // reservation held, and the card fills with contract rows. Growth is **downward only**: growing
  // upward would move the window's first row against the offset the wheel set, and the tests (and
  // the user) read `↑n` as the wheel's own position.
  const drawn = (start: number, n: number): number =>
    spend(start, n) + (start > 0 ? 1 : 0) + (count > start + n ? 1 : 0)
  while (offset + visible < count && visible < desired && drawn(offset, visible + 1) + tailLines <= room) visible += 1

  // The choice picker (M55): the command's own vocabulary, rendered in the view's own line budget
  // exactly like the seat picker below (same window/offset rules, one click action per entry, no
  // overlay, no width tier — the row list the snapshots pin is untouched). The entries are built
  // by the App from the key's `choices` object; this function only labels and windows them. The entry
  // window is the M55 bound (`SETTINGS_TAIL_ROWS`), not the row list's P32 budget: a long vocabulary
  // is *paged* here by design, while the card below still fills the pane.
  const choice = ctx.view.choicePicker
  if (choice) {
    const entries = choice.entries
    const sel = Math.max(0, Math.min(Math.max(0, entries.length - 1), choice.index))
    // title + interval + the two hidden-count lines + blank + hint: the entries get the rest.
    const entryBudget = Math.max(1, room - SETTINGS_TAIL_ROWS - 6)
    const entryVisible = Math.max(1, Math.min(entries.length, entryBudget))
    const entryOffset = Math.max(0, Math.min(Math.max(0, entries.length - entryVisible), sel - Math.floor(entryVisible / 2)))
    const lines: PlacedLine[] = []
    const put = (line: Line): void => {
      lines.push({ line: truncLine(line, width) })
    }
    const entryLabel = (e: SettingsChoiceEntry): string => {
      const base =
        e.kind === 'keep-unset'
          ? s.settingsChoiceKeepUnset
          : e.kind === 'clear'
            ? s.settingsChoiceClear
            : e.kind === 'free'
              ? s.settingsChoiceFree
              : choice.kind === 'bool' && (e.value === '1' || e.value === '0')
                ? e.value === '1'
                  ? s.settingsBoolOn
                  : s.settingsBoolOff
                : e.value
      const marks: string[] = []
      if (e.kind === 'current') marks.push(s.settingsChoiceCurrent)
      if (e.kind === 'default') marks.push(s.settingsChoiceDefault)
      if (e.mark) {
        marks.push(e.mark === 'exists' ? s.settingsPathExists : e.mark === 'not-exec' ? s.settingsPathNotExec : s.settingsPathMissing)
      }
      return marks.length ? `${base} · ${marks.join(' · ')}` : base
    }
    put(ln(seg(` ${fill(s.settingsChoiceTitle, { label: keyLabel(s, choice.key), key: choice.key })}`, 'heading')))
    if (choice.interval) {
      put(
        ln(
          seg(
            ` ${fill(s.settingsChoiceInterval, { min: choice.interval.min || '0', max: choice.interval.max || '∞' })}`,
            'dim',
          ),
        ),
      )
    }
    if (entryOffset > 0) put(ln(seg(`  ${fill(s.laneHiddenAbove, { n: String(entryOffset) })}`, 'dim')))
    entries.forEach((e, i) => {
      if (i < entryOffset || i >= entryOffset + entryVisible) return
      const label = entryLabel(e)
      const line = ln(
        seg(`${i === sel ? s.settingsCursor : ' '} `, 'accent'),
        seg(label, i === sel ? 'selected' : e.kind === 'value' || e.kind === 'current' || e.kind === 'default' ? 'text' : 'dim'),
      )
      const action: Action = { kind: 'choice-pick', index: i }
      const rowW = Math.max(2, Math.min(width, 1 + dispWidth(textOf(line))))
      lines.push(placedWithHits(line, ctx.view.tui ? [{ start: 1, end: rowW, action }] : undefined, width))
    })
    const entryHiddenBelow = Math.max(0, entries.length - (entryOffset + entryVisible))
    if (entryHiddenBelow > 0) put(ln(seg(`  ${fill(s.laneHiddenBelow, { n: String(entryHiddenBelow) })}`, 'dim')))
    put(ln(seg('')))
    put(ln(seg(` ${s.settingsChoiceHint}`, 'dim')))
    // P32: a picker covers the row list, so what its own entries do not use stays inside the card
    // (the fill rule below); a short picker must not leave the pane half blank either.
    while (lines.length < room) put(ln(seg('')))
    return one(lines, { focus: sel, offset: entryOffset, visible: entryVisible, count: entries.length })
  }

  // The seat picker (P22/B4): the models the command reports as known, then the removal and the
  // free-text line — the editor opens on whichever is chosen.
  const picker = ctx.view.seatPicker
  if (picker) {
    const options = [...picker.models, '-', '']
    const sel = Math.max(0, Math.min(options.length - 1, picker.index))
    const lines: PlacedLine[] = []
    const put = (line: Line): void => {
      lines.push({ line: truncLine(line, width) })
    }
    put(ln(seg(` ${fill(s.seatPickerTitle, { seat: picker.agent })}`, 'heading')))
    options.forEach((opt, i) => {
      const label = opt === '-' ? s.seatPickerRemove : opt === '' ? s.seatPickerFree : opt
      const row = ln(
        seg(`${i === sel ? s.settingsCursor : ' '} `, 'accent'),
        seg(label, i === sel ? 'selected' : opt === '' || opt === '-' ? 'dim' : 'text'),
      )
      const action: Action = { kind: 'seat-pick', index: i }
      const rowW = Math.max(2, Math.min(width, 1 + dispWidth(textOf(row))))
      lines.push(placedWithHits(row, ctx.view.tui ? [{ start: 1, end: rowW, action }] : undefined, width))
    })
    put(ln(seg('')))
    put(ln(seg(` ${s.seatPickerHint}`, 'dim')))
    while (lines.length < room) put(ln(seg('')))
    return one(lines, { focus: sel, offset: 0, visible: options.length, count: options.length })
  }

  const lines: PlacedLine[] = []
  const hiddenAbove = offset
  const hiddenBelow = Math.max(0, count - (offset + visible))
  const put = (line: Line): void => {
    lines.push({ line: truncLine(line, width) })
  }
  if (hiddenAbove > 0) put(ln(seg(`  ${fill(s.laneHiddenAbove, { n: String(hiddenAbove) })}`, 'dim')))

  let idx = -1
  for (const r of rows) {
    if (r.kind === 'key' || r.kind === 'seat') {
      idx += 1
      if (idx < offset || idx >= offset + visible) continue
      const focused = idx === focus
      const placed = r.kind === 'key' ? settingsKeyLine(ctx, r.key, focused, width) : settingsSeatLine(ctx, r.seat, focused, width)
      // The whole row is a target: a click on an unfocused row moves the focus, a second click on
      // the focused row opens it (the kanban's rule).
      const action: Action = focused ? { kind: 'settings-open', index: idx } : { kind: 'settings-focus', index: idx }
      const rowW = Math.max(2, Math.min(width, 1 + dispWidth(textOf(placed.line))))
      lines.push(placedWithHits(placed.line, ctx.view.tui ? [{ start: 1, end: rowW, action }] : undefined, width))
      continue
    }
    // A heading draws only when the next focusable row is inside the window.
    const next = idx + 1
    if (next < offset || next >= offset + visible) continue
    if (r.kind === 'group' || r.kind === 'seat-group') {
      // P32 (the user's first report): a heading indented like a row reads as one more row. It is a
      // **section rule** instead — `── 身份与账本布局 ────…`, the shape the non-framed blocks already
      // use — so a heading and a key row cannot be confused in a monochrome capture either, and
      // consecutive groups are separated by their own headings without spending a second line.
      put(ruleTitle(r.label, width, r.kind === 'group' ? r.tone : 'accent'))
    }
  }
  if (hiddenBelow > 0) put(ln(seg(`  ${fill(s.laneHiddenBelow, { n: String(hiddenBelow) })}`, 'dim')))

  // The CLI-alignment line (M49): the row's label is for reading, the raw key is for typing.
  put(ln(seg(` ${settingsCliHint(s, rows, focus)}`, 'dim')))

  // The audit footer: at most three lines, newest last (the CLI's own tail).
  put(ln(seg('')))
  put(ln(seg(` ${s.settingsAuditHeading}`, 'heading')))
  if (!audit.length) put(ln(seg(`   ${s.dash}`, 'dim')))
  for (const a of audit) put(ln(seg(`   ${a}`, 'dim')))

  // P32 (the bounded-frame rule's last resort, the detail view's own): the space the rows did not
  // use stays **inside** the card, so the card fills the pane it was handed and the key band stays
  // the frame's last row. With a full list that is nothing; with a filter, the tail of the list or
  // a short pane it is what the user read as "the view does not use the window's height".
  while (lines.length < room) put(ln(seg('')))

  return one(lines, { focus, offset, visible, count })
}

/**
 * P45/B2: the token line under a change row (`M1 done · M2 wip · V1 PASS · +N`).
 *
 * It is rendered only when the whole line fits the block's width: a token line that would have to be
 * cut is dropped **whole** rather than truncated (`truncLine`) or wrapped — the block must not reflow
 * (a wrapped cell moves every row below it, and a board page that shifts when a task's status
 * changes is worse than a missing summary), and a half-shown token list is worse than none. The
 * reader's `+N` overflow count is part of the text, so the bound stays visible; the tone is the
 * same `dim` as the digest's own change section.
 */
function changeTasksLine(ch: ChangeRow, width: number): PlacedLine | null {
  const tasks = ch.tasks ?? []
  if (!tasks.length) return null
  const parts = tasks.map((t) => `${t.id} ${t.board}`)
  if ((ch.tasks_more ?? 0) > 0) parts.push(`+${ch.tasks_more}`)
  const line = ln(seg(`  ${parts.join(' · ')}`, 'dim'))
  return widthOf(line) <= width ? { line } : null
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
    const toks = changeTasksLine(ch, width)
    if (toks) lines.push(toks)
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
  // delivery-truth D2：阻碍是**测量事实**（原因、观察时刻、诊断可否读），不是「有草稿」的暗示。
  const imps: Impediment[] = q.impediments ?? []
  if (q.impeded && q.impeded > 0) {
    const reasons = Array.from(new Set(imps.map((i) => i.reason))).join(' · ') || s.dash
    lines.push({ line: truncLine(ln(seg(`  ${fill(s.queueImpededLine, { n: q.impeded, reasons })}`, 'warn')), width) })
    for (const im of imps.slice(0, 3)) {
      const when = im.diagnostic === 'available' && im.last_observed ? im.last_observed : s.queueImpededUnavailable
      lines.push({ line: truncLine(ln(seg(fill(s.queueImpededItem, { entry: im.entry, reason: im.reason, when }), 'warn')), width) })
    }
  }
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

/**
 * P123: the focused card's demoted `agent · phase` pair, which the board page's key band renders in
 * the width its chips leave free. Only the card line hides these fields; the pair is built only
 * while the kanban is on screen (the detail view and the settings surfaces replace the page's
 * blocks, so no card is focused on screen there). `null` when the board page has no focused card.
 */
function demotedPair(ctx: Ctx): { full: string; phase: string } | null {
  const { s } = ctx
  if (ctx.view.page !== 4 || ctx.view.detail || ctx.view.overlay || ctx.view.settings) return null
  const rows = ctx.blocks.board?.rows ?? []
  if (!rows.length) return null
  const card = focusRow(rows, resolveFocus(rows, ctx.view.focus))
  if (!card) return null
  // P125: in the side-by-side tier the folded lane is the three-column frame, which cannot carry
  // its label — the band names the lane it holds the focus for (its label and card count) exactly
  // where the demoted pair would render. In the grouped tier the folded line still carries them,
  // so the pair stays as it was.
  if (ctx.twoColumn && laneFolded(ctx.view, card.state, !laneCards(rows, card.state).length)) {
    const text = `${laneLabel(card.state, s)} ${laneCards(rows, card.state).length}`
    return { full: text, phase: text }
  }
  const phase = card.phase && card.phase !== '-' ? card.phase : s.dash
  // No cursor glyph here: the frame carries exactly one `›` (the focused card's), and the pair is
  // data, not a marker — the design's example glyph would have made every board frame carry two.
  return { full: `${card.agent} · ${phase}`, phase }
}

function keyBandBlock(ctx: Ctx, rowsAvailable = true): Block {
  const { s, width } = ctx
  const actions: { text: string; action: Action }[] = [
    { text: s.keyCompose, action: { kind: 'compose' } },
    { text: s.keyFlush, action: { kind: 'flush' } },
    { text: s.keyStandby, action: { kind: 'standby' } },
    { text: s.keySettings, action: { kind: 'settings' } },
  ]
  // The board page's nav chips carry its own keys: the lane/card moves and Enter (every documented
  // key has a target — `r` stays keyboard-only, V16 F-V16-5). While the detail view is open the same
  // chips become its keys — it adds no action, and `q` is the documented back-out, not a collapse.
  const nav: { text: string; action: Action }[] = ctx.view.settings
    ? ctx.view.choicePicker
      ? [
          { text: s.keyRows, action: { kind: 'choice-move', delta: 1 } },
          { text: s.keyOpen, action: { kind: 'choice-pick', index: -1 } },
          { text: s.keyDetailClose, action: { kind: 'choice-close' } },
        ]
      : ctx.view.seatPicker
      ? [
          { text: s.keyRows, action: { kind: 'seat-move', delta: 1 } },
          { text: s.keySeatPick, action: { kind: 'seat-pick', index: -1 } },
          { text: s.keyDetailClose, action: { kind: 'settings-close' } },
        ]
      : [
          { text: s.keyRows, action: { kind: 'settings-scroll', delta: 1 } },
          { text: s.keyOpen, action: { kind: 'settings-open', index: -1 } },
          { text: s.keyFilter, action: { kind: 'settings-filter' } },
          { text: s.keyDetailClose, action: { kind: 'settings-close' } },
        ]
    : ctx.view.detail
    ? [
        { text: s.keyDetailClose, action: { kind: 'detail-close' } },
        { text: s.keyDetailTabs, action: { kind: 'detail-tab-move', delta: 1 } },
        { text: s.keyDetailScroll, action: { kind: 'detail-scroll', delta: 1 } },
        { text: s.keyPages, action: { kind: 'page-cycle' } },
      ]
    : ctx.view.page === 2 && rowsAvailable
      ? [
          { text: s.keyRows, action: { kind: 'card-move', delta: 1 } },
          { text: s.keyOpen, action: { kind: 'open-focused', lane: 'todo' } },
          { text: s.keyPages, action: { kind: 'page-cycle' } },
          { text: s.keyQuit, action: { kind: 'quit' } },
        ]
      : ctx.view.page === 4
      ? [
          { text: s.keyLanes, action: { kind: 'lane-move', delta: 1 } },
          { text: s.keyCards, action: { kind: 'card-move', delta: 1 } },
          {
            text: s.keyFold,
            action: { kind: 'lane-fold', lane: resolveFocus(ctx.blocks.board?.rows ?? [], ctx.view.focus)?.lane ?? '' },
          },
          {
            text: s.keyOpen,
            action: { kind: 'open-focused', lane: resolveFocus(ctx.blocks.board?.rows ?? [], ctx.view.focus)?.lane ?? 'todo' },
          },
          { text: s.keyPages, action: { kind: 'page-cycle' } },
          { text: s.keyQuit, action: { kind: 'quit' } },
        ]
      : [
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
  // P123: the focused card's demoted pair rides the free width the chips leave — right-aligned,
  // dim, no hit target (data, not an affordance). The agent drops before the phase, and the pair
  // disappears before it could push a documented chip out (the chips were laid out first).
  const pair = demotedPair(ctx)
  if (pair) {
    const free = width - x
    const text = dispWidth(pair.full) <= free ? pair.full : dispWidth(pair.phase) <= free ? pair.phase : ''
    if (text) {
      line.push(seg(' '.repeat(free - dispWidth(text)), 'dim'), seg(text, 'dim'))
      x += free
    }
  }
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
    { page: 4, text: s.pageBoard },
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
    // P22/B2: the overlay's one navigation row — not a preference: it opens the project-settings
    // view, changes no preference and writes no file (the MODIFIED settings requirement).
    { pref: '', label: s.prefProjectSettings, value: s.prefNavArrow },
  ]
}

function pageName(page: PageId, s: Strings): string {
  return page === 1 ? s.pageOverview : page === 2 ? s.pageWork : page === 3 ? s.pageMessages : s.pageBoard
}

/** The overlay's cursor column (`  › ` / `    `) and the separator that keeps the two columns apart. */
const OVERLAY_CURSOR_W = 4
const OVERLAY_GAP_W = 2
/** `│ ` + ` │`: the border and padding the comfortable card chrome adds around a block's rows. */
const OVERLAY_CHROME_W = 4

/**
 * The settings overlay's column plan. The key column is `OVERLAY_LABEL_W` — the widest of the five
 * labels in *either* language — so zh and en put their values in the same column, and the two
 * columns are separated by a real gap instead of the key cell ending exactly where the value
 * starts (V16's user report: `default pageoverview` and `activity co…on` came from a hardcoded
 * 12-cell key cell with no separator). Degradation: below the full plan the key column shrinks
 * first — a key that does not fit is cut with `…` and still keeps the gap — while the value keeps
 * at least one column of its own. The plan budgets for the card chrome (the comfortable framed
 * style draws a border and a one-column padding on each side), so the frame's own truncation never
 * eats the value column at narrow widths.
 */
function overlayCols(ctx: Ctx): { keyW: number; valueW: number } {
  const avail = Math.max(1, ctx.width - (isFramed(ctx) ? OVERLAY_CHROME_W : 0))
  const keyW = Math.max(1, Math.min(OVERLAY_LABEL_W, avail - OVERLAY_CURSOR_W - OVERLAY_GAP_W - 1))
  return { keyW, valueW: Math.max(1, avail - OVERLAY_CURSOR_W - keyW - OVERLAY_GAP_W) }
}

function overlayBlock(ctx: Ctx): Block {
  const { s, width } = ctx
  const prefs = overlayPrefs(ctx)
  const { keyW, valueW } = overlayCols(ctx)
  const lines: PlacedLine[] = []
  prefs.forEach((p, i) => {
    const row = ln(
      seg(`  ${i === ctx.view.overlayIndex ? s.settingsCursor : ' '} `, 'accent'),
      seg(cell(p.label, keyW), 'heading'),
      seg(' '.repeat(OVERLAY_GAP_W)),
      seg(truncateW(p.value, valueW)),
    )
    lines.push(
      placedWithHits(
        row,
        ctx.view.tui
          ? [
              {
                start: 2,
                end: 2 + dispWidth(textOf(row)),
                action: p.pref ? { kind: 'toggle', pref: p.pref as PrefName } : { kind: 'settings-open-view' },
              },
            ]
          : undefined,
        width,
      ),
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
  // P22/B2: the project-settings view replaces the page's blocks; the overlay it was opened from
  // stays behind it, so `esc` lands back on that overlay row. Title band, tabs and key band stay.
  if (ctx.view.settings) {
    const settings = settingsBlock(ctx)
    return [...blocks.filter((b): b is Block => b !== null), ...(settings ? [settings] : []), keyBandBlock(ctx)]
  }
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
      // The detail view replaces the work page's blocks exactly as it replaces the kanban's.
      blocks.push(
        ctx.view.detail ? detailBlock(ctx) : boardBlock(left()),
        ...(ctx.view.detail ? [] : [changesBlock(right()), specsBlock(right()), decisionsBlock(right())]),
      )
      break
    case 3:
      blocks.push(queueBlock(left()), inboxBlock(right()), patrolBlock(right()), trendBlock(right()), healthBlock(right()))
      break
    case 4:
      // The detail view replaces the kanban's blocks (the title band, tabs and key band stay).
      blocks.push(ctx.view.detail ? detailBlock(ctx) : kanbanBlock(ctx))
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
  let boardOrder: FocusRef[] | undefined
  const place = (block: Block, remaining: number, colWidth: number): PlacedLine[] => {
    const kind = pickChrome(block, remaining, framed)
    if (kind === null) return []
    if (kind === 'summary') return [summaryLine(block, colWidth)]
    // The order is only reported for a block that really draws its rows: a block degraded to its
    // summary line has no row to focus (P20/B5).
    if (block.order) boardOrder = block.order
    return wrapBlock(block, colWidth, kind)
  }

  const fullRows: PlacedLine[] = []
  let laneWindows: LaneWindow[] | undefined
  let detailWindow: DetailWindow | undefined
  let settingsWindow: SettingsWindow | undefined
  for (const b of fullBlocks) {
    // The board page's lanes are told how many rows they may use (the frame is bounded): the lane
    // windows then grow with the pane instead of showing blank card space (the bounded-frame rule).
    const block =
      // A lane column is `THREE` rows taller than its card slots (title + bottom + marker slots), so
      // the budget handed over is what is left minus that chrome — otherwise the block overflows and
      // degrades to its one-line summary.
      height > 0 && b.id === 'kanban'
        ? (kanbanBlock({ ...ctx, laneRows: Math.max(1, budget - fullRows.length - LANE_MARKER_SLOTS - LANE_CHROME_ROWS) }) ?? b)
        : // The detail view spends the same budget on document rows: more pane = more of the file.
          height > 0 && b.id === 'detail'
          ? (detailBlock({ ...ctx, detailRows: Math.max(2, budget - fullRows.length - (framed ? 2 : 0)) }) ?? b)
          : height > 0 && b.id === 'settings'
          ? (settingsBlock({ ...ctx, settingsRows: Math.max(3, budget - fullRows.length - (framed ? 2 : 0)) }) ?? b)
          : b
    if (block.id === 'kanban' && block.lanes) laneWindows = block.lanes
    if (block.id === 'detail' && block.detail) detailWindow = block.detail
    if (block.id === 'settings' && block.settings) settingsWindow = block.settings
    const chunk = place(block, budget - fullRows.length, width)
    for (const l of chunk) fullRows.push(l)
  }
  add(fullRows)

  const bodyBudget = budget === Number.POSITIVE_INFINITY ? Number.POSITIVE_INFINITY : Math.max(0, budget - fullRows.length)
  if (bodyBudget > 0) {
    if (twoColumn) {
      const leftW = leftWidth
      const rightW = rightWidth
      // One placement pass over the page's body blocks; `cards` is re-derived so pass 2 can carry a
      // board with more history visible.
      const placeColumns = (cards: Block[]): [PlacedLine[], PlacedLine[]] => {
        const columns: [PlacedLine[], PlacedLine[]] = [[], []]
        const ordered = [
          ...cards.filter((b) => !b.right).map((b) => ({ b, slot: 0 as 0 | 1 })),
          ...cards.filter((b) => b.right).map((b) => ({ b, slot: 1 as 0 | 1 })),
        ].sort((x, y) => x.b.priority - y.b.priority)
        for (const { b, slot } of ordered) {
          const colW = slot === 0 ? leftW : rightW
          // The body budget is **per column** (P18.1): the two columns stack side by side, so a tall
          // left card (the board's B1 growth fills the whole body height) used to consume the right
          // column's budget as well — its cards got `remaining = 0` and vanished, although the frame
          // had a full column of empty width. `pickChrome` keeps every column within `bodyBudget`, so
          // the flush below still ends both columns on the same row.
          const used = columns[slot].length
          const chunk = place(b, bodyBudget - used, colW)
          for (const l of chunk) columns[slot].push(l)
        }
        return columns
      }
      let bodyCards: Block[] = [...leftBlocks, ...rightBlocks]
      let columns = placeColumns(bodyCards)
      if (height > 0) {
        // The board's folded history relaxes into the column's allotment (the flush bottom): the
        // spare height shows real rows instead of blank card space. Only when the frame is bounded
        // — the uncapped `--print` path keeps its pre-console shape byte for byte.
        const board = bodyCards.find((b) => b.id === 'board')
        const folded = board ? boardFoldedRows(ctx) : 0
        const boardSlot: 0 | 1 = board?.right ? 1 : 0
        // B1: the relax is bounded by the *available* body height, not by the neighbour column's
        // height — otherwise a taller pane grows nothing and the spare becomes blank card space.
        const target = Math.max(columns[0].length, Math.max(columns[1].length, bodyBudget))
        const extra = Math.min(folded, Math.max(0, target - columns[boardSlot].length))
        if (board && extra > 0) {
          const grown = boardBlock({ ...ctx, width: board.right ? rightW : leftW, boardDoneKeep: Math.max(1, ctx.boardDoneKeep ?? BOARD_DONE_KEEP) + extra })
          if (grown) {
            bodyCards = bodyCards.map((b) => (b === board ? grown : b))
            columns = placeColumns(bodyCards)
          }
        }
        // Flush the two column bottoms: a column shorter than its neighbour grows its *last* card
        // (blank content area), so the body ends on one row instead of trailing blank page. Only
        // cards can be grown; a degraded chrome (`rule`/`summary`) keeps its natural height and the
        // merge below pads it as before.
        const flush = Math.max(columns[0].length, columns[1].length)
        for (const slot of [0, 1] as const) {
          const col = columns[slot]
          const colW = slot === 0 ? leftW : rightW
          const slack = flush - col.length
          const last = col[col.length - 1]
          if (slack <= 0 || !last) continue
          if (textOf(last.line) !== textOf(cardBottom(colW))) continue
          col.pop()
          for (let i = 0; i < slack; i++) col.push(cardBody({ line: [] }, colW))
          col.push(last)
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
        const chunk = place(b, bodyBudget - used, columnW)
        for (const l of chunk) rows.push({ line: truncLine(l.line, columnW), hits: l.hits })
        used += chunk.length
      }
      if (height > 0) {
        // B1: the single-column tiers get the two-column flush bottom too — the spare height grows
        // the *last card's* blank content area, so a single-column page ends on one row instead of
        // trailing blank page. Only a card can grow; any remainder is filled by the assembly below.
        const spare = Math.max(0, height - footer.lines.length - rows.length)
        const last = rows[rows.length - 1]
        if (spare > 0 && last && textOf(last.line) === textOf(cardBottom(columnW))) {
          rows.pop()
          for (let i = 0; i < spare; i++) rows.push(cardBody({ line: [] }, columnW))
          rows.push(last)
        }
      }
    }
  }

  // The work page's row chips are rebuilt after placement: they exist only while the board block
  // really draws rows, so a degraded work page has no clickable row key that cannot open anything
  // (P20/B5). Both variants are one line, so the budget above is unaffected.
  const footerShown =
    ctx.view.page === 2 && !ctx.view.detail && !ctx.view.overlay && !boardOrder ? keyBandBlock(ctx, false) : footer

  // The footer is the last row; when the height cannot even hold it, it is the only row kept.
  if (height > 0 && rows.length + footerShown.lines.length > height) {
    const room = Math.max(0, height - footerShown.lines.length)
    rows.length = Math.min(rows.length, room)
  }
  // B1 (the bounded-frame red line): a bounded frame fills its height. Whatever the content did not
  // naturally use becomes blank *content* rows directly above the footer, so the key band is the
  // frame's last row and no blank row follows it. The uncapped `--print` path (height <= 0) never
  // reaches this branch, so its bytes stay identical.
  if (height > 0 && rows.length + footerShown.lines.length < height) {
    const spare = height - footerShown.lines.length - rows.length
    for (let i = 0; i < spare; i++) rows.push({ line: [] })
  }
  add(footerShown.lines)

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
  return {
    rows: renderedRows,
    targets,
    ...(laneWindows ? { lanes: laneWindows } : {}),
    ...(detailWindow ? { detail: detailWindow } : {}),
    ...(settingsWindow ? { settings: settingsWindow } : {}),
    ...(boardOrder ? { boardOrder } : {}),
  }
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
