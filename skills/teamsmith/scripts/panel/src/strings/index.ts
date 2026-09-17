// The language tables, selected by the `lang` preference, and the one substitution helper.
//
// `TABLES` is the single lookup point: the layout takes a `Strings` object as an argument and never
// imports a concrete table, which is what makes the language switch a repaint rather than a reload.
// The tables themselves are plain ESM (JSDoc-typed) so `tests/panel-strings.mjs` can import them
// with any JS runtime — including one without a TypeScript loader.

import { en } from './en.js'
import { zh } from './zh.js'
import { dispWidth } from '../width.js'
import type { Strings } from './types.js'

export type { Strings } from './types.js'

export const TABLES = { zh, en } as const

export type Lang = keyof typeof TABLES

export function isLang(value: string): value is Lang {
  return value === 'zh' || value === 'en'
}

/** The table for a language; unknown values fall back to `zh` (the default UI language). */
export function stringsFor(lang: string): Strings {
  return isLang(lang) ? TABLES[lang] : TABLES.zh
}

/** The five settings-overlay labels — the keys the overlay's column plan has to hold. */
const OVERLAY_LABEL_KEYS = ['prefLang', 'prefDefaultPage', 'prefActivity', 'prefMouse', 'prefDensity'] as const satisfies readonly (keyof Strings)[]

/**
 * The settings overlay's key column, in display cells: the widest of those five labels over *both*
 * tables (`activity column` = 15 beats zh `默认页面` = 8). One width for both languages, so
 * switching the language repaints the same geometry and the value column never migrates; derived
 * from the tables themselves, so a longer label widens the column instead of silently touching the
 * value.
 */
export const OVERLAY_LABEL_W: number = OVERLAY_LABEL_KEYS.reduce(
  (max, key) => Math.max(max, dispWidth(zh[key]), dispWidth(en[key])),
  0,
)

/** `{name}` substitution; a missing key yields the key itself so a gap is visible, not silent. */
export function fill(template: string, vars: Record<string, string | number>): string {
  return String(template).replace(/\{(\w+)\}/g, (whole, name: string) =>
    Object.prototype.hasOwnProperty.call(vars, name) ? String(vars[name]) : whole,
  )
}
