// Display safety for the panel's own strings.
//
// `monitor.mjs` sanitizes the data layer's output (its contract, unchanged). The panel reads a
// second set of strings itself — branch names, task ids, state file values, queue entry names —
// and those never pass through the data layer. This is the panel's own pass, applied to every
// string before it is laid out and to every string before it is printed as JSON.
//
// Two properties the contract pins, both measured by the hostile-payload fixture:
//   * no ESC, BEL, CR or C1 byte survives, in the TUI as well as in text;
//   * the visible text survives: control bytes are *removed*, not used as a truncation point
//     (that is the exact reason E4 dropped blessed and OpenTUI and kept Ink).

const OSC_RE = /\u001B\][^\u0007\u001B]*(?:\u0007|\u001B\\)/g
const CSI_RE = /\u001B\[[0-?]*[ -/]*[@-~]/g
const C1_CSI_RE = /\u009B[0-?]*[ -/]*[@-~]/g
const ESC2_RE = /\u001B[@-Z\\-_]/g
const CTRL_RE =
  /[\u0000-\u0008\u000B-\u001F\u007F-\u009F\u200B\u200E\u200F\u202A-\u202E\u2060\u2066-\u2069\uFEFF]/g

/** Strip control sequences but keep the text around them. */
export function sanitize(value: unknown): string {
  return String(value ?? '')
    .replace(OSC_RE, '')
    .replace(CSI_RE, '')
    .replace(C1_CSI_RE, '')
    .replace(ESC2_RE, '')
    .replace(CTRL_RE, '')
}

/** Sanitize every string in a value (keys included), leaving numbers/booleans/null alone. */
export function sanitizeDeep<T>(value: T): T {
  if (typeof value === 'string') return sanitize(value) as unknown as T
  if (Array.isArray(value)) return value.map((v) => sanitizeDeep(v)) as unknown as T
  if (value && typeof value === 'object') {
    const out: Record<string, unknown> = {}
    for (const [k, v] of Object.entries(value as Record<string, unknown>)) {
      out[sanitize(k)] = sanitizeDeep(v)
    }
    return out as unknown as T
  }
  return value
}
