// The compose model's headless sibling (P20/B1, tasks.md 1.1): the pure insertion-point model,
// the row map and the window, driven without a terminal.
//
//   bun build panel-compose-model.ts --target=node --format=esm --outfile /tmp/panel-compose-model.js
//   node /tmp/panel-compose-model.js
//
// Every case names itself; the first failing case is printed with its expectation, and the exit
// code is 1. `panel-b2.sh` builds and runs this beside the pty scenarios, so a green bundle with a
// broken model is visible at both levels.

import {
  backspaceAt,
  composeKey,
  cpLength,
  cursorView,
  deleteAt,
  findWordBackward,
  findWordForward,
  inputLines,
  insertAt,
  killSpan,
  moveCursor,
  popUndo,
  pushKill,
  pushUndo,
  resetKillDirection,
  ringEntry,
  wordAfterEnd,
  wordBackwardInLine,
  wordBeforeStart,
  wrapRows,
} from '../scripts/panel/src/compose.js'

type Case = { name: string; run: () => string | null }

const cases: Case[] = []
const check = (name: string, run: () => string | null): void => {
  cases.push({ name, run })
}

const eq = (what: string, got: unknown, want: unknown): string | null =>
  JSON.stringify(got) === JSON.stringify(want) ? null : `${what}: got ${JSON.stringify(got)}, want ${JSON.stringify(want)}`

const draftOf = (rows: { text: string }[]): string => rows.map((r) => r.text).join('|')

check('cjk: insert and backspace move by codepoint, never half a glyph', () => {
  const a = insertAt('ad', 1, '中文')
  if (a.text !== 'a中文d' || a.cursor !== 3) return `insertAt: ${JSON.stringify(a)}`
  const b = backspaceAt(a.text, 2)
  return eq('backspaceAt over a wide glyph', b, { text: 'a文d', cursor: 1 })
})

check('emoji: an astral codepoint is one step and is never half-deleted', () => {
  const a = insertAt('', 0, '🙂')
  if (cpLength(a.text) !== 1 || a.cursor !== 1) return `insertAt astral: ${JSON.stringify(a)}`
  const b = backspaceAt(a.text, 1)
  return eq('backspaceAt astral', b, { text: '', cursor: 0 })
})

check('delete: removes the codepoint after the point', () => {
  return eq('deleteAt', deleteAt('ab', 0), { text: 'b', cursor: 0 })
})

check('wrap: a 40-column room splits 40 x into 36 + 4', () => {
  const rows = wrapRows('x'.repeat(40), 36)
  if (rows.length !== 2) return `row count: ${rows.length}`
  return (
    eq('row 0 span', [rows[0].start, rows[0].end, rows[0].text.length], [0, 36, 36]) ??
    eq('row 1 span', [rows[1].start, rows[1].end, rows[1].text.length], [36, 40, 4])
  )
})

check('wrap: a wide glyph counts two columns in the wrap', () => {
  const rows = wrapRows('中文中文', 4)
  if (rows.length !== 2) return `row count: ${rows.length}`
  return eq('spans', rows.map((r) => [r.start, r.end, r.text]), [[0, 2, '中文'], [2, 4, '中文']])
})

check('wrap: an explicit break starts a new row with its own span', () => {
  const rows = wrapRows('ab\nXXXXXXXX', 36)
  if (rows.length !== 2) return `row count: ${rows.length}`
  return (
    eq('line 0', [rows[0].start, rows[0].end, rows[0].line, rows[0].text], [0, 2, 0, 'ab']) ??
    eq('line 1', [rows[1].start, rows[1].end, rows[1].line, rows[1].text], [3, 11, 1, 'XXXXXXXX'])
  )
})

check('inputLines: the cursor-at-the-end output is unchanged for a short draft', () => {
  return eq('inputLines(10)', inputLines('message', '中文ab', 10), ['> 中文ab'])
})

check('inputLines: a logical break and a wrap keep the prompt/continuation prefixes', () => {
  return eq('inputLines(8)', inputLines('message', 'abcdefgh\nij', 8), ['> abcdef', '  gh', '  ij'])
})

check('move: left/right step codepoints and clamp at the ends', () => {
  return (
    eq('left over a wide glyph', moveCursor('中文ab', 3, 'left', { width: 10 }), 2) ??
    eq('left clamps', moveCursor('中文ab', 0, 'left', { width: 10 }), 0) ??
    eq('right clamps', moveCursor('中文ab', 4, 'right', { width: 10 }), 4)
  )
})

check('move: up/down walk visual rows at the same column, clamped', () => {
  return (
    eq('up clamps to the shorter row', moveCursor('ab\nXXXXXXXX', 11, 'up', { width: 40 }), 2) ??
    eq('down keeps the column', moveCursor('ab\nXXXXXXXX', 2, 'down', { width: 40 }), 5)
  )
})

check('move: up/down walk wrapped rows of one logical line', () => {
  const draft = 'x'.repeat(40)
  return (
    eq('up from the wrapped row lands on the first', moveCursor(draft, 40, 'up', { width: 38 }), 4) ??
    eq('down from the first lands on the wrapped row', moveCursor(draft, 4, 'down', { width: 38 }), 40)
  )
})

check('move: lineStart/lineEnd are the logical line, not the drawn row', () => {
  return (
    eq('lineStart on the second line', moveCursor('alpha\nbeta', 10, 'lineStart', { width: 40 }), 6) ??
    eq('lineEnd on the first line', moveCursor('alpha\nbeta', 2, 'lineEnd', { width: 40 }), 5) ??
    eq('lineEnd clamps at the draft end', moveCursor('alpha\nbeta', 10, 'lineEnd', { width: 40 }), 10)
  )
})

check('view: the point on the first row is drawn there with the tray column', () => {
  const view = cursorView('message', `Z${'x'.repeat(40)}`, 1, 38, 10, '↑{n} 行')
  return (
    eq('lines', view.lines, [`> Z${'x'.repeat(35)}`, `  ${'x'.repeat(5)}`]) ??
    eq('cursorLine', view.cursorLine, 0) ??
    eq('cursorColumn (2 prompt + 1 Z)', view.cursorColumn, 3) ??
    eq('window start', [view.start, view.hiddenAbove], [0, 0])
  )
})

check('view: a 30-row draft in a 10-row window shows the tail plus a counted marker', () => {
  const draft = Array.from({ length: 30 }, (_, i) => `L${String(i + 1).padStart(2, '0')}`).join('\n')
  const view = cursorView('message', draft, cpLength(draft), 120, 10, '↑{n} 行')
  if (view.lines.length > 10) return `window shows ${view.lines.length} rows (> 10)`
  if (!view.lines[view.lines.length - 1].includes('L30')) return `the point's row is not drawn: ${JSON.stringify(view.lines)}`
  return (
    eq('marker counts the hidden rows above', view.lines[0], '↑21 行') ??
    eq('the point is on the last drawn row', view.cursorLine, view.lines.length - 1) ??
    eq('hiddenAbove', view.hiddenAbove, 21)
  )
})

check('view: the window follows the point and counts fewer hidden rows', () => {
  const draft = Array.from({ length: 30 }, (_, i) => `L${String(i + 1).padStart(2, '0')}`).join('\n')
  let point = cpLength(draft)
  for (let i = 0; i < 12; i += 1) point = moveCursor(draft, point, 'up', { width: 120, pageRows: 9 })
  const view = cursorView('message', draft, point, 120, 10, '↑{n} 行')
  const shown = view.lines.join('\n')
  return (
    (shown.includes('L18') ? null : `L18's row is not drawn: ${JSON.stringify(view.lines)}`) ??
    eq('fewer hidden rows above', view.hiddenAbove, 9)
  )
})

// ------------------------------------------------------------------ B2: words, ring, undo, keys

check('word: pi\'s backward rule skips whitespace and stops at the word start', () => {
  return (
    eq('end of a word', findWordBackward('alpha beta gamma', 16), 11) ??
    eq('after the space', findWordBackward('alpha beta ', 11), 6) ??
    eq('mid-word', findWordBackward('alpha beta', 8), 6) ??
    eq('at zero', findWordBackward('alpha beta', 0), 0)
  )
})

check('word: pi\'s forward rule skips whitespace and stops at the first punctuation', () => {
  return (
    eq('from the line start', findWordForward('alpha beta', 0), 5) ??
    eq('from the separator', findWordForward('alpha beta', 5), 10) ??
    eq('from the end', findWordForward('alpha beta', 10), 10) ??
    eq('punctuation stops the word', findWordForward('a-b c', 0), 1)
  )
})

check('word: ctrl+w cuts the preceding whitespace with the word (the requirement\'s ` gamma`)', () => {
  return (
    eq('at the line end', wordBeforeStart('alpha beta gamma', 16), 10) ??
    eq('right after the word', wordBeforeStart('alpha beta', 10), 5) ??
    eq('the movement itself keeps pi\'s boundary (no separator)', wordBackwardInLine('alpha beta', 10), 6) ??
    eq('CJK runs stay whole (plus the separator)', wordBeforeStart('你好 世界', 5), 2) ??
    eq('forward cuts the cursor-side gap', wordAfterEnd('alpha beta', 5), 10)
  )
})

check('kill: every deletion reports the span it cuts and its side', () => {
  return (
    eq('char before', killSpan('ab', 2, 'charBefore'), { from: 1, to: 2, text: 'b', direction: 'backward' }) ??
    eq('char after', killSpan('ab', 1, 'charAfter'), { from: 1, to: 2, text: 'b', direction: 'forward' }) ??
    eq('word before', killSpan('alpha beta gamma', 16, 'wordBefore'), { from: 10, to: 16, text: ' gamma', direction: 'backward' }) ??
    eq('word after', killSpan('alpha beta', 5, 'wordAfter'), { from: 5, to: 10, text: ' beta', direction: 'forward' }) ??
    eq('line before', killSpan('alpha\nbeta', 8, 'lineBefore'), { from: 6, to: 8, text: 'be', direction: 'backward' }) ??
    eq('line after', killSpan('alpha\nbeta', 2, 'lineAfter'), { from: 2, to: 5, text: 'pha', direction: 'forward' }) ??
    eq('nothing to cut', killSpan('ab', 0, 'charBefore'), null)
  )
})

check('ring: the same-side kills accumulate, the tenth entry is the bound', () => {
  let ring = { entries: [] as string[], lastDirection: null as 'backward' | 'forward' | null }
  ring = pushKill(ring, ' gamma', 'backward')
  ring = pushKill(ring, ' beta', 'backward')
  if (ring.entries.length !== 1 || ring.entries[0] !== ' beta gamma') return `accumulated head: ${JSON.stringify(ring.entries)}`
  ring = pushKill(ring, 'alpha ', 'forward')
  if (ring.entries.length !== 2 || ring.entries[0] !== 'alpha ') return `direction change starts an entry: ${JSON.stringify(ring.entries)}`
  for (let i = 0; i < 20; i += 1) {
    ring = resetKillDirection(ring)
    ring = pushKill(ring, `x${i}`, 'forward')
  }
  if (ring.entries.length !== 10) return `ring bound: ${ring.entries.length}`
  return eq('the newest entry is the head', ring.entries[0], 'x19')
})

check('ring: a non-kill action breaks accumulation, and pop walks older entries', () => {
  let ring = pushKill({ entries: [], lastDirection: null }, 'one', 'backward')
  ring = pushKill(ring, 'two', 'backward')
  ring = resetKillDirection(ring)
  ring = pushKill(ring, 'three', 'backward')
  return (
    eq('reset starts a new entry', ring.entries, ['three', 'twoone']) ??
    eq('yank head', ringEntry(ring, 0), 'three') ??
    eq('first pop', ringEntry(ring, 1), 'twoone') ??
    eq('pop wraps', ringEntry(ring, 2), 'three')
  )
})

check('undo: snapshots restore the text and the cursor, and the history is bounded', () => {
  const stack: { text: string; cursor: number }[] = []
  pushUndo(stack, 'ad', 2)
  pushUndo(stack, 'aZd', 2)
  const back = popUndo(stack)
  if (!back || back.text !== 'aZd' || back.cursor !== 2) return `first pop: ${JSON.stringify(back)}`
  const older = popUndo(stack)
  if (!older || older.text !== 'ad' || older.cursor !== 2) return `second pop: ${JSON.stringify(older)}`
  if (popUndo(stack) !== null) return 'an empty history must pop null'
  for (let i = 0; i < 150; i += 1) pushUndo(stack, `t${i}`, i)
  return eq('bound', stack.length, 100)
})

check('keys: the decoder maps both encodings to the same intents', () => {
  const k = (input: string, flags: Record<string, boolean> = {}) => composeKey(input, flags)
  return (
    eq('the legacy lone LF is ctrl+j (newline), not submit', k('\n'), { kind: 'newline' }) ??
    eq('the Kitty ctrl+j byte-pair is the newline key', k('j', { ctrl: true }), { kind: 'newline' }) ??
    eq('kitty shift+enter is a newline', k('\r', { return: true, shift: true }), { kind: 'newline' }) ??
    eq('enter still submits', k('\r', { return: true }), { kind: 'submit' }) ??
    eq('esc', k('', { escape: true }), { kind: 'cancel' }) ??
    eq('kitty ctrl+b', k('b', { ctrl: true }), { kind: 'move', motion: 'left' }) ??
    eq('legacy ctrl+b', k('b', { ctrl: true }), { kind: 'move', motion: 'left' }) ??
    eq('kitty alt+b', k('b', { meta: true }), { kind: 'move', motion: 'wordLeft' }) ??
    eq('ctrl+left is a word move', k('', { ctrl: true, leftArrow: true }), { kind: 'move', motion: 'wordLeft' }) ??
    eq('home', k('', { home: true }), { kind: 'move', motion: 'lineStart' }) ??
    eq('ctrl+a', k('a', { ctrl: true }), { kind: 'move', motion: 'lineStart' }) ??
    eq('ctrl+e is line end (the App still intercepts it until B3)', k('e', { ctrl: true }), { kind: 'move', motion: 'lineEnd' }) ??
    eq('backspace', k('', { backspace: true }), { kind: 'kill', unit: 'charBefore' }) ??
    eq('alt+backspace', k('', { backspace: true, meta: true }), { kind: 'kill', unit: 'wordBefore' }) ??
    eq('delete', k('', { delete: true }), { kind: 'kill', unit: 'charAfter' }) ??
    eq('ctrl+d', k('d', { ctrl: true }), { kind: 'kill', unit: 'charAfter' }) ??
    eq('ctrl+w', k('w', { ctrl: true }), { kind: 'kill', unit: 'wordBefore' }) ??
    eq('ctrl+u', k('u', { ctrl: true }), { kind: 'kill', unit: 'lineBefore' }) ??
    eq('ctrl+k', k('k', { ctrl: true }), { kind: 'kill', unit: 'lineAfter' }) ??
    eq('alt+d', k('d', { meta: true }), { kind: 'kill', unit: 'wordAfter' }) ??
    eq('ctrl+y', k('y', { ctrl: true }), { kind: 'yank' }) ??
    eq('alt+y', k('y', { meta: true }), { kind: 'yankPop' }) ??
    eq('kitty ctrl+-', k('-', { ctrl: true }), { kind: 'undo' }) ??
    eq('an unbound ctrl key is consumed', k('c', { ctrl: true }), { kind: 'none' }) ??
    eq('an unbound alt key is consumed', k('z', { meta: true }), { kind: 'none' }) ??
    eq('typing inserts', k('x'), { kind: 'insert', text: 'x' }) ??
    eq('a paste is one insert', k('a\nb'), { kind: 'insert', text: 'a\nb' })
  )
})

// ------------------------------------------------------------------ runner

let failed = 0
for (const c of cases) {
  const detail = c.run()
  if (detail === null) {
    console.log(`ok   ${c.name}`)
  } else {
    console.log(`FAIL ${c.name}\n       ${detail}`)
    failed += 1
  }
}
console.log(`panel-compose-model: ${cases.length - failed}/${cases.length} passed`)
process.exit(failed === 0 ? 0 : 1)
