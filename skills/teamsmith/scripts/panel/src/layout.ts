// The frame: four ordered bands, the documented degradation order, and nothing else.
//
// This module is pure (no I/O, no timers) so the same lines serve the text frame, the Ink frame
// and the tests. Band order and degradation are part of the `panel` contract; sizes below are the
// measured thresholds from E4 §3.2 / tasks.md item 3.1:
//   A status (title, PM, pending, queue, capacity)
//   B agent table (left) + activity / recent actions (right)
//   C reserved visualization band (labelled placeholder, reads no data)
//   D key band (last non-empty line)
// C disappears below 17 rows; below 11 rows the capacity figures fold into the PM line.

import { AGENT_TEXT, clockOf, fmtMB, GLYPH, PM_TEXT, shortBranch, sparkline } from './format.js'
import type { ActivityBlock, FrameInput, PanelAgent, PanelData } from './types.js'
import { cell, dispWidth, rule, truncateW, truncateWStart } from './width.js'

export const RESERVED_LABEL = '◇ 预留（第二步）：board 泳道 · reports/OpenSpec 计数 · 每 agent 成本/时长趋势'
export const KEY_BAND = 'q 退出 · ↑/↓ 滚动 · r 刷新 · --print 纯文本 · --no-activity 关活动列'
export const ACTIVITY_HEADING = '活动（仅本 session 在跑的窗口）'
export const RECENT_HEADING = '最近动作'
export const AGENT_HEADER = 'AGENT'
export const TABLE_HEADERS = { state: '状态', task: '任务', branch: '分支', session: '会话' }

/** Thresholds from the degradation order; exported so tests and the TUI use the same numbers. */
export const HEIGHT_RESERVED = 17
export const HEIGHT_CAPACITY_OWN = 11
export const WIDTH_TWO_COLUMNS = 72

function agentStateText(a: PanelAgent): string {
  return `${GLYPH[a.state] ?? '?'} ${AGENT_TEXT[a.state] ?? a.state}`
}

function pmLine(panel: PanelData): string {
  const pm = panel.pm
  const detail = pm.detail ? `（${pm.detail}）` : ''
  const pmText = `PM ${pm.state}${detail} · ${PM_TEXT[pm.state] ?? pm.state}`
  const pend = `待办 ${panel.pending.text || '无'}`
  const ob = panel.outbox
  const queue = `延后投递 ${ob.queued}${ob.held > 0 ? `（扣住 ${ob.held}）` : ''}`
  return ` ${pmText}    ${pend}    ${queue}`
}

function capacityLine(panel: PanelData, sparkW: number): string {
  const c = panel.capacity
  const spark = sparkline(c.spark, sparkW)
  return ` 容量 RAM ${fmtMB(c.ram_avail_mb)} ｜ swap ${fmtMB(c.swap_free_mb)} ｜ 可再加 ${c.agents} 个 agent${spark ? `  ${spark}` : ''}`
}

function titleLine(panel: PanelData, width: number): string {
  const left = `teamsmith pulse · ${panel.project}`
  const standby = panel.standby.on ? `待命 on（原因：${panel.standby.reason || '-'}）` : '待命 off'
  const right = `${clockOf(panel.timestamp)}  巡检 ${panel.interval}s · ${standby}`
  const room = width - dispWidth(left) - 2
  if (room >= dispWidth(right)) return `${left}  ${right}`
  return truncateW(`${left}  ${right}`, width)
}

/** Flatten the data layer's blocks into one display line per event. */
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

function agentTable(panel: PanelData, leftW: number): string[] {
  const agents = panel.agents ?? []
  const fixed = { name: 10, state: 8, task: 7, session: 7 }
  const widths = { ...fixed }
  let showSession = true
  let showBranch = true
  let branchW = leftW - (fixed.name + fixed.state + fixed.task + fixed.session + 4)
  if (branchW < 8) {
    // Degrade by width: drop the session column first, then the branch column.
    showSession = false
    branchW = leftW - (fixed.name + fixed.state + fixed.task + 3)
    if (branchW < 8) {
      showBranch = false
      branchW = 0
    }
  }
  const header = [
    cell(AGENT_HEADER, widths.name),
    cell(TABLE_HEADERS.state, widths.state),
    cell(TABLE_HEADERS.task, widths.task),
    showBranch ? cell(TABLE_HEADERS.branch, branchW) : '',
    showSession ? cell(TABLE_HEADERS.session, widths.session) : '',
  ]
    .filter(Boolean)
    .join(' ')
  const lines = [truncateW(header, leftW)]
  for (const a of agents) {
    const b = shortBranch(String(a.branch ?? ''), branchW)
    const flags = `${a.dirty ? ' *' : ''}${a.ahead ? ` +${a.ahead}` : ''}`
    const row = [
      cell(String(a.name ?? '?'), widths.name),
      cell(agentStateText(a), widths.state),
      cell(String(a.task || '—'), widths.task),
      showBranch ? cell(`${b}${flags}`, branchW) : '',
      showSession ? cell(String(a.session_text || '—'), widths.session) : '',
    ]
      .filter(Boolean)
      .join(' ')
    lines.push(truncateW(row, leftW))
  }
  return lines
}

function rightColumn(input: FrameInput, rightW: number, rows: number): string[] {
  const lines: string[] = []
  if (input.activity) {
    lines.push(truncateW(` ${ACTIVITY_HEADING}`, rightW))
    // The source hint keeps its label and drops the head of the path (a glob reads best from the tail).
    if (input.panel.activity_source) {
      const label = '源 '
      lines.push(truncateW(` ${label}${truncateWStart(input.panel.activity_source, rightW - dispWidth(label) - 1)}`, rightW))
    }
    const evs = activityLines(input.activityBlocks).slice(Math.max(0, input.scroll ?? 0))
    if (!evs.length) lines.push(truncateW('  （没有会话活动）', rightW))
    for (const e of evs) lines.push(truncateW(e, rightW))
  }
  lines.push(truncateW(` ${RECENT_HEADING}`, rightW))
  const recent = (input.panel.recent ?? []).slice(-6)
  if (!recent.length) lines.push(truncateW('  （还没有动作记录）', rightW))
  for (const r of recent) lines.push(truncateW(` ${r}`, rightW))
  return lines.slice(0, Math.max(0, rows))
}

/**
 * Build one frame. `height <= 0` means "no cap" (used by `--print` without geometry overrides).
 * Every returned line is ≤ `width` columns and the array is ≤ `height` rows.
 */
export function buildFrame(input: FrameInput): string[] {
  const panel = input.panel
  const W = Math.max(1, Math.floor(input.width) || 1)
  const H = Math.floor(input.height) || 0

  const withMiddle = H <= 0 || H >= HEIGHT_RESERVED
  // Below 11 rows the capacity figures fold into the PM line and keep no line of their own.
  const capOwn = H <= 0 || H >= HEIGHT_CAPACITY_OWN
  const fixed = (capOwn ? 5 : 4) + 1 + (withMiddle ? 2 : 0)

  const lines: string[] = []
  lines.push(titleLine(panel, W))
  lines.push(rule(W))
  const pm = pmLine(panel)
  if (capOwn) {
    lines.push(pm)
    lines.push(capacityLine(panel, Math.min(18, Math.max(0, W - dispWidth(pm) - 8))))
  } else {
    lines.push(truncateW(`${pm}   ${capacityLine(panel, 12)}`, W))
  }
  lines.push(rule(W))

  const bodyRows = H <= 0 ? 24 : Math.max(0, H - fixed)
  if (bodyRows > 0) {
    const twoCols = W >= WIDTH_TWO_COLUMNS
    const leftW = twoCols ? Math.max(24, Math.floor((W - 3) * 0.56)) : W
    const rightW = twoCols ? Math.max(8, W - leftW - 3) : 0
    const left = agentTable(panel, leftW)
    const right = twoCols ? rightColumn(input, rightW, bodyRows) : []
    if (!twoCols) {
      // Narrow frames stack: the table first, then the activity/recent block.
      for (const l of left.slice(0, bodyRows)) lines.push(truncateW(l, W))
      const rest = bodyRows - Math.min(left.length, bodyRows)
      if (rest > 0) for (const l of rightColumn(input, W, rest)) lines.push(truncateW(l, W))
    } else {
      const rows = Math.min(bodyRows, Math.max(left.length, right.length))
      for (let i = 0; i < rows; i++) {
        const l = left[i] ?? ''
        const r = right[i] ?? ''
        lines.push(truncateW(r ? `${cell(l, leftW)}   ${r}` : l, W))
      }
    }
  }

  if (withMiddle) {
    lines.push(rule(W))
    lines.push(truncateW(RESERVED_LABEL, W))
  }
  lines.push(truncateW(KEY_BAND, W))

  if (H > 0 && lines.length > H) {
    // Only reachable for heights below the fixed band set: the key band still ends the frame and
    // the frame never exceeds the height.
    return [...lines.slice(0, Math.max(0, H - 1)), truncateW(KEY_BAND, W)].slice(-H)
  }
  return lines
}

/** One JSON object with the panel fields plus the untouched activity blocks. */
export function buildJson(input: FrameInput): Record<string, unknown> {
  return { panel: { ...input.panel }, activity: input.activity ? input.activityBlocks : [] }
}
