// The read-only markdown renderer for the detail view (P18/B3, design §7).
//
// A narrow, self-written subset — no new dependency, because the bundle must stay a single file
// that runs with no install. The fidelity target is *readable structure*, pinned by the spec's
// "Markdown structure survives the render" scenario; CommonMark conformance is a non-goal.
//
// The subset: ATX headings, fenced code blocks (verbatim, dim), pipe tables (display-width
// aligned), bullet/numbered lists, blockquotes, `---` rules, and inline bold / code / links as
// tone spans. Anything outside the subset renders as its source text — never dropped, never an
// error. The renderer is pure, so `src/**` stays testable without a terminal.

import { dispWidth } from './width.js'
import type { Line, PlacedLine, Segment, Tone } from './types.js'

const seg = (text: string, tone: Tone = 'text'): Segment => ({ text: String(text), tone })
const ln = (...parts: (Segment | null)[]): Line => parts.filter((p): p is Segment => p !== null)

/** A tone-styled word (or a single space) the wrapper lays out. */
interface Word {
  text: string
  tone: Tone
}

/** Code points of `text` that fit in `w` display columns (at least one, always something). */
function takeWidth(text: string, w: number): string {
  let out = ''
  let used = 0
  for (const ch of text) {
    const cw = dispWidth(ch)
    if (used + cw > w) break
    used += cw
    out += ch
  }
  return out || [...text][0] || ''
}

/**
 * Greedy word wrap over tone spans. `first`/`rest` are the line prefixes (a list's bullet on the
 * first line, a quote bar on every line, the hanging indent on continuations); a word that cannot
 * fit on a line of its own is hard-broken, so no row ever overflows the width.
 */
function wrapWords(words: Word[], width: number, first = '', rest = first): Line[] {
  const maxW = Math.max(1, width - Math.max(dispWidth(first), dispWidth(rest)))
  const chunks: Word[] = []
  for (const word of words) {
    if (/^\s+$/.test(word.text)) {
      chunks.push({ text: ' ', tone: word.tone })
      continue
    }
    let text = word.text
    while (dispWidth(text) > maxW) {
      const head = takeWidth(text, maxW)
      chunks.push({ text: head, tone: word.tone })
      text = text.slice(head.length)
    }
    if (text) chunks.push({ text, tone: word.tone })
  }
  const out: Line[] = []
  let line: Line = first ? [seg(first, 'dim')] : []
  let w = dispWidth(first)
  let has = false
  for (const chunk of chunks) {
    if (chunk.text === ' ') continue // spaces are re-inserted between words, never doubled
    const dw = dispWidth(chunk.text)
    if (has && w + 1 + dw > width) {
      out.push(line)
      line = rest ? [seg(rest, 'dim')] : []
      w = dispWidth(rest)
      has = false
    }
    if (has) {
      line.push(seg(' ', chunk.tone))
      w += 1
    }
    line.push(seg(chunk.text, chunk.tone))
    w += dw
    has = true
  }
  out.push(line)
  return out
}

/**
 * Flatten a tone-styled line into words. Adjacent spans with no whitespace between them stay one
 * word (a link's `(url).` keeps its punctuation attached); whitespace collapses to single spaces.
 * A word carries the tone of the span it started in.
 */
function wordsOf(line: Line): Word[] {
  const out: Word[] = []
  let cur: Word | null = null
  const flush = (): void => {
    if (cur && cur.text) out.push(cur)
    cur = null
  }
  for (const span of line) {
    for (const part of String(span.text).split(/(\s+)/)) {
      if (part === '') continue
      if (/^\s+$/.test(part)) {
        flush()
        out.push({ text: ' ', tone: span.tone })
        continue
      }
      if (cur) cur.text += part
      else cur = { text: part, tone: span.tone }
    }
  }
  flush()
  return out
}

/**
 * Inline spans: `**bold**` (heading tone), `` `code` `` (accent), `[text](url)` (accent text
 * followed by a dim parenthesised URL). Everything else is plain text, marker and all.
 */
function inline(text: string, base: Tone = 'text'): Line {
  const out: Line = []
  const re = /(\*\*([^*]+)\*\*)|(`([^`]+)`)|(\[([^\]]+)\]\(([^)\s]+)\))/g
  let last = 0
  for (let m = re.exec(text); m; m = re.exec(text)) {
    if (m.index > last) out.push(seg(text.slice(last, m.index), base))
    if (m[2] !== undefined) out.push(seg(m[2], 'heading'))
    else if (m[4] !== undefined) out.push(seg(m[4], 'accent'))
    else if (m[6] !== undefined) {
      // The URL is one span so its punctuation (`(url).`) stays attached to the link word.
      out.push(seg(m[6], 'accent'), seg(` (${m[7]})`, 'dim'))
    }
    last = m.index + m[0].length
  }
  if (last < text.length) out.push(seg(text.slice(last), base))
  return out.length ? out : [seg(text, base)]
}

/** The plain text of a table cell (inline markers stripped — alignment wins over tone here). */
function cellText(text: string): string {
  return String(text)
    .replace(/\*\*([^*]+)\*\*/g, '$1')
    .replace(/`([^`]+)`/g, '$1')
    .replace(/\[([^\]]+)\]\(([^)\s]+)\)/g, '$1 ($2)')
    .trim()
}

function splitRow(row: string): string[] {
  let text = row.trim()
  if (text.startsWith('|')) text = text.slice(1)
  if (text.endsWith('|')) text = text.slice(0, -1)
  const cells: string[] = []
  let cur = ''
  for (let i = 0; i < text.length; i++) {
    const ch = text[i]
    if (ch === '\\' && text[i + 1] === '|') {
      cur += '|'
      i++
      continue
    }
    if (ch === '|') {
      cells.push(cur)
      cur = ''
      continue
    }
    cur += ch
  }
  cells.push(cur)
  return cells
}

const ALIGN_RE = /^\s*\|?\s*:?-{1,}:?\s*(\|\s*:?-{1,}:?\s*)*\|?\s*$/

function isSeparatorRow(row: string): boolean {
  return row.includes('|') && ALIGN_RE.test(row) && /-/.test(row)
}

type Align = 'left' | 'right' | 'center'

function alignOf(marker: string): Align {
  const t = marker.trim()
  if (t.startsWith(':') && t.endsWith(':')) return 'center'
  if (t.endsWith(':')) return 'right'
  return 'left'
}

/** One pipe table: header + separator + body, columns aligned by display width. */
function tableBlock(rows: string[], width: number): Line[] {
  const header = splitRow(rows[0]).map(cellText)
  const aligns = splitRow(rows[1]).map(alignOf)
  const body = rows.slice(2).map((r) => splitRow(r).map(cellText))
  const cols = Math.max(header.length, ...body.map((r) => r.length), 1)
  const widths: number[] = []
  for (let c = 0; c < cols; c++) {
    let w = dispWidth(header[c] ?? '')
    for (const row of body) w = Math.max(w, dispWidth(row[c] ?? ''))
    widths.push(w)
  }
  const render = (cells: string[], base: Tone): Line => {
    const line: Line = [seg(' ')]
    for (let c = 0; c < cols; c++) {
      if (c > 0) line.push(seg(' │ ', 'dim'))
      const text = cells[c] ?? ''
      const pad = Math.max(0, widths[c] - dispWidth(text))
      const align = aligns[c] ?? 'left'
      const left = align === 'right' ? pad : align === 'center' ? Math.floor(pad / 2) : 0
      const right = pad - left
      line.push(seg(' '.repeat(left)), seg(text, base), seg(' '.repeat(right)))
    }
    return line
  }
  const out: Line[] = [render(header, 'heading')]
  out.push(
    ln(
      seg(' '),
      ...widths.map((w, c) => (c > 0 ? [seg('─┼─', 'dim')] : []).concat([seg('─'.repeat(w), 'dim')])).flat(),
    ),
  )
  for (const row of body) out.push(render(row, 'text'))
  return out.map((l) => (dispWidth(l.map((s) => s.text).join('')) > width ? clip(l, width) : l))
}

/** Hard clip a line to `width` columns (the frame's own truncation, applied early for tables). */
function clip(line: Line, width: number): Line {
  const out: Line = []
  let used = 0
  for (const span of line) {
    if (used >= width) break
    const text = takeWidth(span.text, width - used)
    if (text) out.push({ text, tone: span.tone })
    used += dispWidth(text)
  }
  return out
}

/**
 * Render a markdown document into placed rows at `width`. Pure: same input → same rows (the memo
 * below is an optimisation, never a semantic difference).
 */
export function markdownToLines(source: string, width: number): PlacedLine[] {
  const w = Math.max(4, Math.floor(width) || 4)
  const src = String(source ?? '').replace(/\r\n?/g, '\n').split('\n')
  const out: PlacedLine[] = []
  const push = (lines: Line[]): void => {
    for (const line of lines) out.push({ line: clip(line, w) })
  }
  let i = 0
  while (i < src.length) {
    const raw = src[i]
    // Fenced code: the body verbatim in the dim tone; the fence lines themselves are the syntax.
    const fence = /^\s{0,3}(```|~~~)/.exec(raw)
    if (fence) {
      const mark = fence[1]
      const close = new RegExp(`^\\s{0,3}${mark}\\s*$`)
      i++
      while (i < src.length && !close.test(src[i])) {
        out.push({ line: [{ text: src[i], tone: 'dim' }] })
        i++
      }
      if (i < src.length) i++
      continue
    }
    // Blank line.
    if (!raw.trim()) {
      out.push({ line: [] })
      i++
      continue
    }
    // A pipe table: a header row followed by a separator row.
    if (raw.includes('|') && i + 1 < src.length && isSeparatorRow(src[i + 1])) {
      const rows = [raw, src[i + 1]]
      i += 2
      while (i < src.length && src[i].trim() && src[i].includes('|')) {
        rows.push(src[i])
        i++
      }
      push(tableBlock(rows, w))
      continue
    }
    // ATX heading.
    const heading = /^\s{0,3}(#{1,6})\s+(.*?)\s*#*\s*$/.exec(raw)
    if (heading) {
      push(wrapWords([{ text: heading[2], tone: 'heading' }], w))
      i++
      continue
    }
    // Horizontal rule (`---`, `***`, `___` — at least three markers, nothing else).
    if (/^\s{0,3}([-*_])(\s*\1){2,}\s*$/.test(raw)) {
      out.push({ line: [{ text: '─'.repeat(w), tone: 'dim' }] })
      i++
      continue
    }
    // Blockquote: one line at a time, the bar dim, the body readable.
    const quote = /^\s{0,3}>\s?(.*)$/.exec(raw)
    if (quote) {
      push(wrapWords(wordsOf(inline(quote[1])), w, '│ ', '│ '))
      i++
      continue
    }
    // Bullet or numbered list item (nested items keep their indentation as a hanging indent).
    const item = /^(\s*)([-*+]|\d+[.)])\s+(.*)$/.exec(raw)
    if (item) {
      const indent = ' '.repeat(Math.min(8, item[1].length))
      const marker = /^[-*+]$/.test(item[2]) ? '•' : item[2]
      const prefix = `${indent}${marker} `
      push(wrapWords(wordsOf(inline(item[3])), w, prefix, ' '.repeat(dispWidth(prefix))))
      i++
      continue
    }
    // Anything else is a paragraph (its inline spans are the only parsing).
    push(wrapWords(wordsOf(inline(raw)), w))
    i++
  }
  return out
}

/** FNV-1a over a bounded prefix plus the length: a cheap content fingerprint for the memo. */
function fingerprint(text: string): string {
  let hash = 2166136261
  const head = text.slice(0, 4096)
  for (let i = 0; i < head.length; i++) {
    hash ^= head.charCodeAt(i)
    hash = Math.imul(hash, 16777619)
  }
  return `${head.length}:${text.length}:${hash >>> 0}`
}

const MEMO = new Map<string, PlacedLine[]>()

/**
 * The layout's memo: the same file content at the same width yields the same rows, so a repaint
 * (the data cadence, a tab switch back) does not re-parse the document. Keyed by path + width +
 * content fingerprint; bounded so a long session cannot grow it without limit.
 */
export function markdownMemo(path: string, source: string, width: number): PlacedLine[] {
  const key = `${path}\u0000${width}\u0000${fingerprint(source)}`
  const hit = MEMO.get(key)
  if (hit) return hit
  const rows = markdownToLines(source, width)
  MEMO.set(key, rows)
  if (MEMO.size > 6) {
    const oldest = MEMO.keys().next().value
    if (oldest !== undefined) MEMO.delete(oldest)
  }
  return rows
}
