// The compose entry (pulse-console B2): the pure model behind the bottom input line.
//
// Everything here is a function of its arguments — no I/O, no timers — so the Ink frame, the
// send bridge's receipt mapping and the pty fixtures all read the same rules. The three things
// that are contractual rather than cosmetic:
//
//   * one read from the terminal is one input event (E6 §2.3): text is appended char by char,
//     Backspace removes one **codepoint** (not one UTF-16 unit), and a wide glyph counts two
//     columns of cursor — the cursor column is what `tmux display -p '#{cursor_x}'` measures;
//   * a paste is not a submit: a `\r` (or CRLF) inside a chunk becomes a line break (E6 §2.2),
//     only a lone Enter submits, and bracketed-paste markers are swallowed;
//   * the receipt maps the send command's rc + machine tokens to exactly three honest states
//     (delivered / queued / held) — never from the human prose the CLI prints alongside them.

import { dispWidth } from './width.js'
import { fill, type Strings } from './strings/index.js'

/** The console's own draft file, inside the project's state directory (E6 §3.7). */
export const DRAFT_FILE = 'draft.md'

/** `> ` — two columns, so `中文ab` puts the real terminal cursor at column 8 (E6 §1.2). */
export const PROMPT = '> '
export const CONTINUATION = '  '

export type ComposeMode = 'message' | 'reason' | 'filter' | 'setting'

export interface Receipt {
  state: 'delivered' | 'queued' | 'held' | 'error'
  /** The machine token(s) the state was mapped from (rc / outcome / result). */
  token: string
  /** One human line for the input area; already sanitized by the caller. */
  detail: string
}

export interface Intake {
  /** Text to append to the draft (line breaks normalized to `\n`). */
  append: string
  /** True only for a lone Enter. */
  submit: boolean
}

/** Split a chunk into its bracketed-paste body, if the markers are present. */
function pasteBody(chunk: string): { body: string | null; open: boolean; close: boolean } {
  // Ink may strip the leading ESC from an escape sequence (E6 §1.1c), so both forms are
  // accepted: `\x1b[200~…` and the bare `[200~…` Ink hands over after consuming the ESC.
  const open = /(?:\u001b)?\[200~/.exec(chunk)
  const close = /(?:\u001b)?\[201~/.exec(chunk)
  if (!open && !close) return { body: null, open: false, close: false }
  let body = ''
  if (open) {
    const after = chunk.slice((open.index ?? 0) + open[0].length)
    const end = close ? after.indexOf(close[0]) : -1
    body = end >= 0 ? after.slice(0, end) : after
    return { body, open: true, close: close !== null || end >= 0 }
  }
  const end = close ? chunk.indexOf(close[0]) : -1
  body = end >= 0 ? chunk.slice(0, end) : chunk
  return { body, open: false, close: close !== null }
}

/** CRLF/CR → LF; nothing else is touched. */
export function normalizeNewlines(text: string): string {
  return String(text ?? '').replace(/\r\n/g, '\n').replace(/\r/g, '\n')
}

/** Drop control characters a paste may carry (a tab is kept as a space). */
function stripControls(text: string): string {
  let out = ''
  for (const ch of text) {
    const cp = ch.codePointAt(0) ?? 0
    if (ch === '\n' || ch === '\t') {
      out += ch === '\t' ? ' ' : '\n'
      continue
    }
    if (cp < 0x20 || cp === 0x7f) continue
    out += ch
  }
  return out
}

/**
 * One input event → what it does to the draft.
 *
 * `pasteOpen` is the caller's carry-over flag: a bracketed paste may arrive split across reads,
 * so `[200~` without a closing marker keeps every following chunk in paste mode until `[201~`.
 */
export function intake(chunk: string, pasteOpen = false): Intake & { pasteOpen: boolean } {
  const raw = String(chunk ?? '')
  if (pasteOpen) {
    const { body, close } = pasteBody(raw)
    const text = body === null ? raw : body
    const nextOpen = !close && body === null
    return { append: stripControls(normalizeNewlines(text)), submit: false, pasteOpen: nextOpen }
  }
  const { body, open, close } = pasteBody(raw)
  if (open || body !== null) {
    const text = body ?? ''
    return { append: stripControls(normalizeNewlines(text)), submit: false, pasteOpen: open && !close }
  }
  // A lone newline is the Enter key; newlines inside a longer chunk are a paste's line breaks.
  if (raw === '\r' || raw === '\n' || raw === '\r\n') return { append: '', submit: true, pasteOpen: false }
  return { append: stripControls(normalizeNewlines(raw)), submit: false, pasteOpen: false }
}

/** Backspace: remove one codepoint, never half of a surrogate pair (CJK/emoji safe). */
export function backspace(draft: string): string {
  const cps = [...String(draft ?? '')]
  cps.pop()
  return cps.join('')
}

/** Append text produced by the editor relay (or any non-terminal source), normalized. */
export function appendText(draft: string, text: string): string {
  return String(draft ?? '') + normalizeNewlines(stripControls(text))
}

/** The prompt for the mode: the reason prompt names why standby is being switched on. */
export function promptOf(mode: ComposeMode): string {
  return PROMPT
}

/**
 * The visible lines of the input area; the last one ends where the cursor belongs.
 *
 * A long logical line wraps by **display width** (CJK counts two columns) and every wrapped or
 * pasted line gets the continuation prefix, so the input area never writes a row wider than the
 * pane and the cursor column is always the width of the last rendered line.
 */
/**
 * The draft as drawn rows: the one map `inputLines`, the cursor placement and the window share.
 *
 * `room` is what one drawn row has after the prompt/continuation prefix (both are two columns).
 * Every row but the text's first carries the continuation prefix, so a uniform room is exactly
 * the old per-line greedy wrap; the difference is that each row now knows the codepoint span it
 * draws — which is what lets the insertion point and the window agree with the pixels.
 */
export interface ComposeRow {
  /** The row's first codepoint index (inclusive) into `[...draft]`. */
  start: number
  /** One past the row's last codepoint index (exclusive). */
  end: number
  /** The logical (`\n`-separated) line this row belongs to. */
  line: number
  /** The row's text, without the prompt/continuation prefix. */
  text: string
}

/** Wrap `text` into display rows of at most `room` columns (a wide glyph is one codepoint). */
export function wrapRows(text: string, room: number): ComposeRow[] {
  const cps = [...String(text ?? '')]
  const cap = Math.max(1, Math.floor(room) || 1)
  const rows: ComposeRow[] = []
  let line = 0
  let start = 0
  let cur = ''
  let i = 0
  while (i <= cps.length) {
    if (i === cps.length || cps[i] === '\n') {
      rows.push({ start, end: i, line, text: cur })
      line += 1
      start = i + 1
      cur = ''
      i += 1
      continue
    }
    const ch = cps[i]
    if (cur && dispWidth(cur + ch) > cap) {
      rows.push({ start, end: i, line, text: cur })
      start = i
      cur = ch
    } else {
      cur += ch
    }
    i += 1
  }
  return rows.length ? rows : [{ start: 0, end: 0, line: 0, text: '' }]
}

/** The visible lines of the input area; the last one ends where the cursor belongs. */
export function inputLines(mode: ComposeMode, draft: string, width: number): string[] {
  void mode
  const room = Math.max(1, (Math.floor(width) || 1) - dispWidth(PROMPT))
  return wrapRows(draft, room).map((row, i) => `${i === 0 ? promptOf(mode) : CONTINUATION}${row.text}`)
}

/** Cursor column (0-based) for the input area's last line. */
export function cursorColumn(lines: string[]): number {
  const last = lines[lines.length - 1] ?? ''
  return dispWidth(last)
}

// ------------------------------------------------------------ the insertion-point model

/** The draft and the insertion point, as codepoint indices (a wide glyph is one step). */
export interface ComposeState {
  text: string
  cursor: number
}

export type ComposeMotion =
  | 'left'
  | 'right'
  | 'wordLeft'
  | 'wordRight'
  | 'lineStart'
  | 'lineEnd'
  | 'up'
  | 'down'
  | 'pageUp'
  | 'pageDown'

/** Codepoints in, codepoints out: never a UTF-16 unit, so a surrogate pair is never split. */
export function cpLength(text: string): number {
  return [...String(text ?? '')].length
}

/** Insert `chunk` at the insertion point. */
export function insertAt(text: string, cursor: number, chunk: string): ComposeState {
  const cps = [...String(text ?? '')]
  const at = Math.max(0, Math.min(cps.length, Math.floor(cursor) || 0))
  const add = [...normalizeNewlines(chunk)]
  return { text: [...cps.slice(0, at), ...add, ...cps.slice(at)].join(''), cursor: at + add.length }
}

/** Backspace: remove the codepoint before the point, never half of a wide glyph. */
export function backspaceAt(text: string, cursor: number): ComposeState {
  const cps = [...String(text ?? '')]
  const at = Math.max(0, Math.min(cps.length, Math.floor(cursor) || 0))
  if (at === 0) return { text: cps.join(''), cursor: 0 }
  cps.splice(at - 1, 1)
  return { text: cps.join(''), cursor: at - 1 }
}

/** Delete: remove the codepoint after the point. */
export function deleteAt(text: string, cursor: number): ComposeState {
  const cps = [...String(text ?? '')]
  const at = Math.max(0, Math.min(cps.length, Math.floor(cursor) || 0))
  if (at >= cps.length) return { text: cps.join(''), cursor: at }
  cps.splice(at, 1)
  return { text: cps.join(''), cursor: at }
}

/** The first codepoint index of the logical (`\n`-separated) line containing `cursor`. */
export function lineStartOf(cps: string[], cursor: number): number {
  let i = Math.max(0, Math.min(cps.length, cursor))
  while (i > 0 && cps[i - 1] !== '\n') i -= 1
  return i
}

/** One past the last codepoint of the logical line containing `cursor`. */
export function lineEndOf(cps: string[], cursor: number): number {
  let i = Math.max(0, Math.min(cps.length, cursor))
  while (i < cps.length && cps[i] !== '\n') i += 1
  return i
}

/** The row index the insertion point is drawn on (a boundary belongs to the next row). */
export function rowOfCursor(rows: ComposeRow[], cursor: number): number {
  const inside = rows.findIndex((r) => cursor >= r.start && cursor < r.end)
  if (inside >= 0) return inside
  // The cursor sits exactly at a row's end: a wrapped row's end belongs to the row it starts, an
  // explicit break's end belongs to the row before the `\n` — both are that row.
  const atEnd = rows.findIndex((r) => cursor === r.end)
  return atEnd >= 0 ? atEnd : rows.length - 1
}

/** Map a display column inside `row` to the codepoint index closest to it (from the left). */
function indexAtColumn(cps: string[], row: ComposeRow, column: number): number {
  let w = 0
  for (let i = row.start; i < row.end; i += 1) {
    if (w + dispWidth(cps[i]) > column) return i
    w += dispWidth(cps[i])
  }
  return row.end
}

/**
 * pi's word segmenter and punctuation rule, ported (`@earendil-works/pi-coding-agent`'s
 * `findWordBackward`/`findWordForward` with `granularity: 'word'`): words come from
 * `Intl.Segmenter`, and a punctuation run inside a word-like segment is a separate stop. A runtime
 * without full ICU throws here instead of silently drifting — the model fixture pins CJK, ASCII and
 * punctuation cases.
 */
const PUNCTUATION = /[(){}[\]<>.,;:'"!?+\-=*/\\|&%^$#@~`]/
let wordSegmenter: Intl.Segmenter | null = null
function segmentsOf(text: string): { segment: string; isWordLike: boolean }[] {
  if (!wordSegmenter) wordSegmenter = new Intl.Segmenter(undefined, { granularity: 'word' })
  const out: { segment: string; isWordLike: boolean }[] = []
  for (const s of wordSegmenter.segment(text)) out.push({ segment: s.segment, isWordLike: s.isWordLike === true })
  return out
}
const isSpace = (s: string): boolean => /^\s+$/.test(s) && s.length > 0

/** pi's `findWordBackward`: the start of the word before `cursor` inside one logical line. */
export function findWordBackward(text: string, cursor: number): number {
  if (cursor <= 0) return 0
  const segs = segmentsOf(text.slice(0, cursor))
  let at = cursor
  while (segs.length > 0 && isSpace(segs[segs.length - 1].segment)) at -= segs.pop()!.segment.length
  if (segs.length === 0) return at
  const last = segs[segs.length - 1]
  if (last.isWordLike) {
    const matches = [...last.segment.matchAll(new RegExp(PUNCTUATION.source, 'g'))]
    if (matches.length === 0) at -= last.segment.length
    else {
      const m = matches[matches.length - 1]
      at -= last.segment.length - ((m.index ?? 0) + m[0].length)
    }
  } else {
    while (segs.length > 0) {
      const prev = segs[segs.length - 1]
      if (prev.isWordLike || isSpace(prev.segment)) break
      at -= segs.pop()!.segment.length
    }
  }
  return Math.max(0, at)
}

/** pi's `findWordForward`: the end of the word after `cursor` inside one logical line. */
export function findWordForward(text: string, cursor: number): number {
  if (cursor >= text.length) return text.length
  const segs = segmentsOf(text.slice(cursor))
  let i = 0
  let at = cursor
  while (i < segs.length && isSpace(segs[i].segment)) {
    at += segs[i].segment.length
    i += 1
  }
  if (i >= segs.length) return at
  const next = segs[i]
  if (next.isWordLike) {
    const m = PUNCTUATION.exec(next.segment)
    at += m && m.index !== undefined ? m.index : next.segment.length
  } else {
    while (i < segs.length && !segs[i].isWordLike && !isSpace(segs[i].segment)) {
      at += segs[i].segment.length
      i += 1
    }
  }
  return Math.min(text.length, at)
}

/** The logical (`\n`-separated) line's bounds around `cursor`. */
export function lineBounds(text: string, cursor: number): { start: number; end: number } {
  const cps = [...String(text ?? '')]
  const at = Math.max(0, Math.min(cps.length, Math.floor(cursor) || 0))
  return { start: lineStartOf(cps, at), end: lineEndOf(cps, at) }
}

/** pi's word rules within the logical line that holds `cursor` (the movement's parity target). */
export function wordBackwardInLine(text: string, cursor: number): number {
  const cps = [...String(text ?? '')]
  const at = Math.max(0, Math.min(cps.length, Math.floor(cursor) || 0))
  const line = lineStartOf(cps, at)
  return line + findWordBackward(cps.slice(line, lineEndOf(cps, at)).join(''), at - line)
}

export function wordForwardInLine(text: string, cursor: number): number {
  const cps = [...String(text ?? '')]
  const at = Math.max(0, Math.min(cps.length, Math.floor(cursor) || 0))
  const line = lineStartOf(cps, at)
  return line + findWordForward(cps.slice(line, lineEndOf(cps, at)).join(''), at - line)
}

/**
 * The start of the word before the point, with the whitespace run in front of it: pi deletes
 * `beta ` when the point sits right after it, and ` gamma` when the point is at the line's end —
 * the requirement's `ctrl+w` ("the word `gamma` and the space before it are cut").
 */
export function wordBeforeStart(text: string, cursor: number): number {
  const cps = [...String(text ?? '')]
  const at = Math.max(0, Math.min(cps.length, Math.floor(cursor) || 0))
  const line = lineStartOf(cps, at)
  let from = wordBackwardInLine(cps.join(''), at)
  while (from > line && /\s/.test(cps[from - 1])) from -= 1
  return from
}

/** The end of the word after the point (pi's forward rule skips the cursor-side whitespace). */
export function wordAfterEnd(text: string, cursor: number): number {
  return wordForwardInLine(text, cursor)
}

/**
 * Move the insertion point. `left`/`right` step one codepoint, the word motions stop at pi's word
 * boundaries, `lineStart`/`lineEnd` are the **logical** line's bounds (pi's `cursorLineStart/End`),
 * `up`/`down` walk the **visual** rows at the same display column clamped to the shorter row (pi's
 * `moveCursor(±1, 0)`), and the page motions walk a page of visual rows. `width` is the input
 * area's drawn width (the row map's room is derived from it), `pageRows` the window's capacity.
 */
export function moveCursor(
  text: string,
  cursor: number,
  motion: ComposeMotion,
  opts: { width: number; pageRows?: number },
): number {
  const cps = [...String(text ?? '')]
  const at = Math.max(0, Math.min(cps.length, Math.floor(cursor) || 0))
  switch (motion) {
    case 'left':
      return Math.max(0, at - 1)
    case 'right':
      return Math.min(cps.length, at + 1)
    case 'lineStart':
      return lineStartOf(cps, at)
    case 'lineEnd':
      return lineEndOf(cps, at)
    case 'wordLeft':
      return wordBackwardInLine(cps.join(''), at)
    case 'wordRight':
      return wordForwardInLine(cps.join(''), at)
    default:
      break
  }
  const room = Math.max(1, (Math.floor(opts.width) || 1) - dispWidth(PROMPT))
  const rows = wrapRows(cps.join(''), room)
  const cur = rowOfCursor(rows, at)
  const page = Math.max(1, Math.floor(opts.pageRows ?? 1) || 1)
  const delta = motion === 'up' ? -1 : motion === 'down' ? 1 : motion === 'pageUp' ? -page : page
  const target = rows[Math.max(0, Math.min(rows.length - 1, cur + delta))]
  if (!target || target === rows[cur]) return at
  const column = dispWidth(cps.slice(rows[cur].start, at).join(''))
  return indexAtColumn(cps, target, column)
}

/** The windowed view of the draft: what is drawn, where the point is drawn, what is hidden. */
export interface ComposeView {
  /** The drawn rows, prefixes included (an optional hidden-rows marker first). */
  lines: string[]
  /** The index into `lines` of the row holding the insertion point. */
  cursorLine: number
  /** The insertion point's display column within that drawn row (prefix included). */
  cursorColumn: number
  /** The full-draft row index the window starts at. */
  start: number
  /** Full-draft rows hidden above the window. */
  hiddenAbove: number
}

/**
 * Build the windowed input area. The window shows at most `maxRows` rows (half the pane, per the
 * requirement), always contains the insertion point's row, and counts the rows it hides above on
 * its own top edge (a marker row, so at most `maxRows - 1` draft rows then). The draft's first row
 * keeps the `> ` prompt; every following row (and the continuation of a wrapped line) the
 * continuation prefix.
 */
export function cursorView(
  mode: ComposeMode,
  draft: string,
  cursor: number,
  width: number,
  maxRows: number,
  hiddenAboveText: string,
): ComposeView {
  const room = Math.max(1, (Math.floor(width) || 1) - dispWidth(PROMPT))
  const rows = wrapRows(draft, room)
  const cap = Math.max(1, Math.floor(maxRows) || 1)
  const at = Math.max(0, Math.min(cpLength(draft), Math.floor(cursor) || 0))
  const cur = rowOfCursor(rows, at)
  const clamp = (v: number, lo: number, hi: number): number => Math.max(lo, Math.min(hi, v))
  let visible = cap
  let start = clamp(cur - visible + 1, 0, Math.max(0, rows.length - visible))
  if (start > 0 && cap > 1) {
    visible = cap - 1
    start = clamp(cur - visible + 1, 0, Math.max(0, rows.length - visible))
  }
  const marker = start > 0 && cap > 1
  const lines: string[] = marker ? [fill(hiddenAboveText, { n: start })] : []
  for (let i = start; i < Math.min(rows.length, start + visible); i += 1) {
    lines.push(`${i === 0 ? promptOf(mode) : CONTINUATION}${rows[i].text}`)
  }
  const row = rows[cur] ?? rows[0]
  const prefix = `${cur === 0 ? promptOf(mode) : CONTINUATION}`
  return {
    lines,
    cursorLine: (marker ? 1 : 0) + (cur - start),
    cursorColumn: dispWidth(prefix) + dispWidth([...String(draft ?? '')].slice(row.start, at).join('')),
    start,
    hiddenAbove: start,
  }
}

// ------------------------------------------------------------ the kill ring, undo and the key map

/** Newest entry first; `lastDirection` is what makes consecutive kills accumulate (pi's rule). */
export interface KillRing {
  entries: string[]
  lastDirection: 'backward' | 'forward' | null
}

export const KILL_RING_MAX = 10
/** What a deletion cut, its side, and where it landed: the App needs the text to push and the edges
 * to apply the edit. */
export interface KillSpan {
  from: number
  to: number
  text: string
  direction: 'backward' | 'forward'
}

/** The kill span for one deletion intent, clamped to what the draft actually has. */
export function killSpan(
  text: string,
  cursor: number,
  unit: 'charBefore' | 'charAfter' | 'wordBefore' | 'wordAfter' | 'lineBefore' | 'lineAfter',
): KillSpan | null {
  const cps = [...String(text ?? '')]
  const at = Math.max(0, Math.min(cps.length, Math.floor(cursor) || 0))
  const line = lineBounds(cps.join(''), at)
  let from = at
  let to = at
  switch (unit) {
    case 'charBefore':
      from = Math.max(0, at - 1)
      break
    case 'charAfter':
      to = Math.min(cps.length, at + 1)
      break
    case 'wordBefore':
      from = wordBeforeStart(cps.join(''), at)
      break
    case 'wordAfter':
      to = wordAfterEnd(cps.join(''), at)
      break
    case 'lineBefore':
      from = line.start
      break
    case 'lineAfter':
      to = line.end
      break
  }
  if (from === to) return null
  const direction: 'backward' | 'forward' = from < at ? 'backward' : 'forward'
  return { from, to, text: cps.slice(from, to).join(''), direction }
}

/** Push one deletion onto the ring: same-side consecutive kills accumulate into the head entry. */
export function pushKill(ring: KillRing, text: string, direction: 'backward' | 'forward'): KillRing {
  if (!text) return ring
  if (ring.lastDirection === direction && ring.entries.length > 0) {
    const head = direction === 'backward' ? text + ring.entries[0] : ring.entries[0] + text
    return { entries: [head, ...ring.entries.slice(1)], lastDirection: direction }
  }
  return { entries: [text, ...ring.entries].slice(0, KILL_RING_MAX), lastDirection: direction }
}

/** Any non-kill action breaks the accumulation chain (pi resets `lastAction`). */
export function resetKillDirection(ring: KillRing): KillRing {
  return ring.lastDirection === null ? ring : { ...ring, lastDirection: null }
}

/** The yank target for `popIndex` pops after a yank (0 = the newest entry). */
export function ringEntry(ring: KillRing, popIndex: number): string | null {
  if (ring.entries.length === 0) return null
  return ring.entries[popIndex % ring.entries.length] ?? null
}

/** A bounded undo history of `{text, cursor}` snapshots, newest last. */
export const UNDO_MAX = 100
export interface UndoSnapshot {
  text: string
  cursor: number
}

/** Snapshot the draft before a mutation; the oldest entries fall off at the bound. */
export function pushUndo(stack: UndoSnapshot[], text: string, cursor: number): void {
  stack.push({ text: String(text ?? ''), cursor: Math.max(0, Math.floor(cursor) || 0) })
  if (stack.length > UNDO_MAX) stack.splice(0, stack.length - UNDO_MAX)
}

/** Pop the last snapshot, or null when the history is empty. */
export function popUndo(stack: UndoSnapshot[]): UndoSnapshot | null {
  return stack.pop() ?? null
}

/** The subset of Ink's `Key` the compose key map reads (kept structural so the model stays pure). */
export interface ComposeKeyFlags {
  ctrl?: boolean
  meta?: boolean
  shift?: boolean
  return?: boolean
  escape?: boolean
  upArrow?: boolean
  downArrow?: boolean
  leftArrow?: boolean
  rightArrow?: boolean
  pageUp?: boolean
  pageDown?: boolean
  backspace?: boolean
  delete?: boolean
  home?: boolean
  end?: boolean
}

export type ComposeIntent =
  | { kind: 'insert'; text: string }
  | { kind: 'newline' }
  | { kind: 'submit' }
  | { kind: 'cancel' }
  | { kind: 'move'; motion: ComposeMotion }
  | { kind: 'kill'; unit: 'charBefore' | 'charAfter' | 'wordBefore' | 'wordAfter' | 'lineBefore' | 'lineAfter' }
  | { kind: 'yank' }
  | { kind: 'yankPop' }
  | { kind: 'undo' }
  | { kind: 'none' }

/**
 * One terminal event → one compose intent (design §4). Both encodings reach this through the
 * *pairs* Ink's parser produces (`ctrl+j` is `('\n', {})` legacy and `('j', {ctrl: true})` from
 * `CSI 106;5u`; `shift+enter` is `('\r', {return: true, shift: true})`), which is exactly why the
 * pty fixtures can send the Kitty bytes and assert the effect. A `ctrl`/`alt`-modified key with no
 * binding is consumed (`none`) and never inserts its letter.
 */
export function composeKey(input: string, key: ComposeKeyFlags): ComposeIntent {
  const ch = String(input ?? '')
  const mod = Boolean(key.ctrl || key.meta)
  if (key.escape) return { kind: 'cancel' }
  // `\r` submits, a lone `\n` (and `ctrl+j`, which is the same byte in the legacy encoding and a
  // `CSI 106;5u` under the Kitty protocol) inserts a break. `shift+enter` inserts one only when the
  // terminal reports it; an unsupporting terminal sends plain `\r` and it submits like Enter.
  if (key.return) return key.shift ? { kind: 'newline' } : { kind: 'submit' }
  if (key.ctrl && ch === 'j') return { kind: 'newline' }
  if (key.leftArrow) return { kind: 'move', motion: key.meta || key.ctrl ? 'wordLeft' : 'left' }
  if (key.rightArrow) return { kind: 'move', motion: key.meta || key.ctrl ? 'wordRight' : 'right' }
  if (key.upArrow) return { kind: 'move', motion: 'up' }
  if (key.downArrow) return { kind: 'move', motion: 'down' }
  if (key.pageUp) return { kind: 'move', motion: 'pageUp' }
  if (key.pageDown) return { kind: 'move', motion: 'pageDown' }
  if (key.home || (key.ctrl && ch === 'a')) return { kind: 'move', motion: 'lineStart' }
  if (key.end || (key.ctrl && ch === 'e')) return { kind: 'move', motion: 'lineEnd' }
  if (key.backspace) return { kind: 'kill', unit: key.meta ? 'wordBefore' : 'charBefore' }
  if (key.delete) return { kind: 'kill', unit: key.meta ? 'wordAfter' : 'charAfter' }
  if (key.ctrl && ch === 'w') return { kind: 'kill', unit: 'wordBefore' }
  if (key.ctrl && ch === 'd') return { kind: 'kill', unit: 'charAfter' }
  if (key.ctrl && ch === 'u') return { kind: 'kill', unit: 'lineBefore' }
  if (key.ctrl && ch === 'k') return { kind: 'kill', unit: 'lineAfter' }
  if (key.meta && ch === 'b') return { kind: 'move', motion: 'wordLeft' }
  if (key.meta && ch === 'f') return { kind: 'move', motion: 'wordRight' }
  if (key.meta && ch === 'd') return { kind: 'kill', unit: 'wordAfter' }
  if (key.ctrl && ch === 'b') return { kind: 'move', motion: 'left' }
  if (key.ctrl && ch === 'f') return { kind: 'move', motion: 'right' }
  if (key.ctrl && ch === 'y') return { kind: 'yank' }
  if (key.meta && ch === 'y') return { kind: 'yankPop' }
  // `ctrl+-` exists only through the Kitty protocol (the legacy byte is not reported); the parser
  // hands it over as `('-', {ctrl: true})`.
  if (key.ctrl && ch === '-') return { kind: 'undo' }
  if (mod) return { kind: 'none' }
  // A lone LF is the legacy `ctrl+j` byte.
  if (ch === '\n') return { kind: 'newline' }
  if (!ch || ch.startsWith('\u001b')) return { kind: 'none' }
  return { kind: 'insert', text: ch }
}

/**
 * The send command's machine result → one of the three honest receipt states.
 *
 * `rc` is the bridge's exit code, `outcome` is `TEAM_SEND_OUTCOME` and `result` is the finer
 * `TEAM_OUTBOX_RESULT` (delivered | held | busy | queued | offline | terminal | skip) — the CLI's
 * own tokens, read from the bridge that runs the guarded send in its own shell. Human prose is
 * never consulted.
 */
export function mapReceipt(rc: number, outcome: string, result: string, detail = ''): Receipt {
  const token = `rc=${rc} outcome=${outcome || '-'} result=${result || '-'}`
  if (rc !== 0) return { state: 'error', token, detail: detail || 'send failed (target undeliverable)' }
  if (result === 'held' || result === 'terminal') return { state: 'held', token, detail }
  if (outcome === 'delivered' || outcome === 'forced' || outcome === 'unknown-sent' || outcome === 'duplicate') {
    return { state: 'delivered', token, detail }
  }
  return { state: 'queued', token, detail }
}

/** Parse the bridge's one machine line: `rc=<n> outcome=<token> result=<token>`. */
export function parseSendResult(stdout: string): { rc: number; outcome: string; result: string } | null {
  const m = /(?:^|\n)\s*rc=(-?\d+)\s+outcome=(\S*)\s+result=(\S*)\s*(?:\n|$)/.exec(String(stdout ?? ''))
  if (!m) return null
  return { rc: Number(m[1]), outcome: m[2] === '-' ? '' : m[2], result: m[3] === '-' ? '' : m[3] }
}

/** The one-line receipt shown under the frame, in the active language's voice. */
export function receiptLine(receipt: Receipt, s: Strings): string {
  switch (receipt.state) {
    case 'delivered':
      return s.receiptDelivered
    case 'queued':
      return s.receiptQueued
    case 'held':
      return s.receiptHeld
    default:
      return fill(s.receiptError, { detail: receipt.detail || s.sendUnconfirmed })
  }
}
