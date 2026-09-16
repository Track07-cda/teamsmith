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

export type ComposeMode = 'message' | 'reason'

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
export function inputLines(mode: ComposeMode, draft: string, width: number): string[] {
  const prompt = promptOf(mode)
  const w = Math.max(1, Math.floor(width) || 1)
  const body = String(draft ?? '')
  const out: string[] = []
  for (const line of body.split('\n')) {
    const prefix = out.length === 0 ? prompt : CONTINUATION
    const room = Math.max(1, w - dispWidth(prefix))
    const chunks: string[] = []
    let cur = ''
    for (const ch of line) {
      if (cur && dispWidth(cur + ch) > room) {
        chunks.push(cur)
        cur = ch
      } else {
        cur += ch
      }
    }
    chunks.push(cur)
    chunks.forEach((chunk, i) => {
      const lead = i === 0 ? prefix : CONTINUATION
      out.push(`${lead}${chunk}`)
    })
  }
  return out.length ? out : [prompt]
}

/** Cursor column (0-based) for the input area's last line. */
export function cursorColumn(lines: string[]): number {
  const last = lines[lines.length - 1] ?? ''
  return dispWidth(last)
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
