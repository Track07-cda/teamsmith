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

import { sanitize } from '../../text-sanitize.mjs'
export { sanitize }

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
