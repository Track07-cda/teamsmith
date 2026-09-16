// Keystroke probe (tasks.md 1.4): the tree's own panel data layer plus a minimal compose line,
// typed into over a pty while a five-second reader refresh is in flight.
//
// Why a probe and not the shipped console: in batch B1 the console has no compose line yet
// (batch B2 owns it), so "the draft holds exactly `hello`" needs an input line; the property under
// test is the data layer's, and this probe drives the tree's real `loadPanelData` exactly the way
// `src/main.tsx` does and reports every input event it sees.
//
// The input model matches Ink's `useInput` on the pinned version (E6 §2.3): one read from the
// terminal is one input event, and an event that is exactly `m` opens the compose line. Escape
// prefixes are tolerated the way Ink strips them.
//
// Usage: bun build panel-keyprobe.tsx --target=node --format=esm --outfile keyprobe.js
//        node keyprobe.js --root DIR --team-cli STUB --log FILE [--timeout MS]
//
// Log lines (one JSON object each, plus the two plain markers):
//   {"kind":"start"|"assembly"|"input"|"submit"|"timeout", ...}
//   SUBMITTED draft=<draft>     — printed when the compose line submits
// Exit: 0 = submitted, 2 = timed out, 3 = assembly failed before any input.

import { appendFileSync, writeFileSync } from 'node:fs'
import { loadPanelData } from '../scripts/panel/src/data.js'

function argOf(name: string): string | undefined {
  const i = process.argv.indexOf(`--${name}`)
  if (i === -1) return undefined
  const v = process.argv[i + 1]
  return v && !v.startsWith('--') ? v : undefined
}

const root = argOf('root') || process.cwd()
const teamCli = argOf('team-cli')
const logFile = argOf('log') || `${root}/.pi/team/state/keyprobe.log`
const timeoutMs = Number(argOf('timeout') ?? 15000) || 15000

writeFileSync(logFile, '')
const log = (obj: Record<string, unknown>): void => appendFileSync(logFile, `${JSON.stringify(obj)}\n`)
const logLine = (line: string): void => appendFileSync(logFile, `${line}\n`)
const now = (): number => Date.now()

// ---- the input line (the console's `m` / typing / Enter, batch B2's shape) --------------------
let composing = false
let draft = ''
let submitted = false

function handleEvent(input: string): void {
  log({ kind: 'input', t: now(), input, composing, draft })
  if (!composing) {
    if (input === 'm') {
      composing = true
      log({ kind: 'compose-open', t: now() })
    }
    return
  }
  for (const ch of input) {
    if (ch === '\r' || ch === '\n') {
      submitted = true
      log({ kind: 'submit', t: now(), draft })
      logLine(`SUBMITTED draft=${draft}`)
      finish(0)
      return
    }
    if (ch === '\x7f' || ch === '\b') {
      draft = [...draft].slice(0, -1).join('')
      continue
    }
    if (ch < ' ' && ch !== '\t') continue
    draft += ch
  }
}

let done = false
function finish(code: number): void {
  if (done) return
  done = true
  try {
    process.stdin.setRawMode?.(false)
  } catch {
    /* the pty may already be gone */
  }
  process.exit(code)
}

// ---- the data layer (the thing under test) ----------------------------------------------------
const startedAt = now()
log({ kind: 'start', t: startedAt, root, teamCli })

// Ink enables raw mode before effects run, which is why the terminal is raw while the first
// refresh is still in flight on the blocking revision.
try {
  process.stdin.setRawMode?.(true)
} catch {
  /* not a tty: the driver always gives us one */
}
process.stdin.resume()
process.stdin.on('data', (chunk: Buffer) => {
  // One read = one input event (Ink's useInput contract); strip a leading escape prefix like Ink.
  let input = chunk.toString('utf8')
  if (input.startsWith('\x1b')) input = input.slice(1)
  handleEvent(input)
})

// `await` works on both revisions: before the change `loadPanelData` returns a value synchronously
// (and blocks the loop doing it), after it returns a promise and never blocks.
void (async () => {
  const res = await loadPanelData({ root, teamCli, activity: false, events: 4 })
  log({ kind: 'assembly', t: now(), ms: now() - startedAt, ok: res.ok, error: res.error ?? '' })
  if (!res.ok && !submitted) finish(3)
})()

setTimeout(() => {
  if (submitted) return
  log({ kind: 'timeout', t: now(), composing, draft })
  logLine('TIMEOUT')
  finish(2)
}, timeoutMs)
