// Display width for the panel's own layout.
//
// The data layer already renders a terminal-oriented view, but the panel lays out its own table:
// CJK and emoji glyphs are double-width in tmux (E4 measured it against tmux's own width table),
// so a naive `.length` padding would drift the columns. This table covers the ranges that matter
// for the names, tasks and states the panel shows; the reserved band reads no data and uses no
// width arithmetic of its own.
//
// Deliberately dependency-free: the bundle must stay self-contained (single file, no install).

type Range = readonly [number, number]

const WIDE: readonly Range[] = [
  [0x1100, 0x115f], // Hangul Jamo
  [0x2e80, 0x303e], // CJK radicals, Kangxi, CJK symbols
  [0x3041, 0x33ff], // Hiragana … CJK compatibility
  [0x3400, 0x4dbf], // CJK ext A
  [0x4e00, 0x9fff], // CJK unified
  [0xa000, 0xa4cf], // Yi
  [0xac00, 0xd7a3], // Hangul syllables
  [0xf900, 0xfaff], // CJK compatibility ideographs
  [0xfe10, 0xfe19], // vertical forms
  [0xfe30, 0xfe6f], // CJK compatibility forms
  [0xff00, 0xff60], // fullwidth forms
  [0xffe0, 0xffe6], // fullwidth signs
  [0x1f300, 0x1f64f], // emoji (pictographs, transport, emoticons)
  [0x1f900, 0x1f9ff], // supplemental symbols and pictographs
  [0x20000, 0x3fffd], // CJK ext B+
]

/** Display width of a string: wide/fullwidth/emoji count 2, zero-width marks count 0. */
export function dispWidth(s: string): number {
  let w = 0
  for (const ch of String(s)) {
    const cp = ch.codePointAt(0) ?? 0
    // Zero-width joiner, variation selector 16 and combining marks add no columns.
    if (cp === 0x200d || cp === 0xfe0f || (cp >= 0x0300 && cp <= 0x036f)) continue
    w += WIDE.some(([a, b]) => cp >= a && cp <= b) ? 2 : 1
  }
  return w
}

export function padEndW(s: string, w: number): string {
  const str = String(s)
  const d = w - dispWidth(str)
  return d > 0 ? str + ' '.repeat(d) : str
}

/** Cut to at most `w` columns; when something was cut the result ends in `…` (still ≤ w). */
export function truncateW(s: string, w: number): string {
  const str = String(s)
  if (w <= 0) return ''
  if (dispWidth(str) <= w) return str
  let out = ''
  for (const ch of str) {
    if (dispWidth(out + ch) > w - 1) break
    out += ch
  }
  return out + '…'
}

/** Cut to at most `w` columns, keeping the *end* of the string (paths/globs read best from the tail). */
export function truncateWStart(s: string, w: number): string {
  const str = String(s)
  if (w <= 0) return ''
  if (dispWidth(str) <= w) return str
  let out = ''
  for (const ch of [...str].reverse()) {
    if (dispWidth(out + ch) > w - 1) break
    out = ch + out
  }
  return `…${out}`
}

export function rule(w: number, ch = '─'): string {
  return ch.repeat(Math.max(0, w))
}

/** Right-pad and then cut: exactly `w` columns when the string is shorter, ≤ w always. */
export function cell(s: string, w: number): string {
  return truncateW(padEndW(s, w), w)
}
