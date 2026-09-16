// The language tables, selected by the `lang` preference, and the one substitution helper.
//
// `TABLES` is the single lookup point: the layout takes a `Strings` object as an argument and never
// imports a concrete table, which is what makes the language switch a repaint rather than a reload.
// The tables themselves are plain ESM (JSDoc-typed) so `tests/panel-strings.mjs` can import them
// with any JS runtime — including one without a TypeScript loader.

import { en } from './en.js'
import { zh } from './zh.js'
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

/** `{name}` substitution; a missing key yields the key itself so a gap is visible, not silent. */
export function fill(template: string, vars: Record<string, string | number>): string {
  return String(template).replace(/\{(\w+)\}/g, (whole, name: string) =>
    Object.prototype.hasOwnProperty.call(vars, name) ? String(vars[name]) : whole,
  )
}
