// `state/panel.conf` and `state/panel-page`: the console's own preferences (runtime state).
//
// Boundaries (design §6): this file is NOT the project contract (`.pi/team/config.sh`); it is read
// by the TUI only — `--print`/`--json` never look at it, which is what keeps the machine exits
// byte-stable under any preference. A missing, unreadable or corrupt file falls back to the
// defaults; a partial or unknown-key file keeps the keys it does declare. `theme` is a preference
// but not an overlay item (the overlay has exactly five). The page file is separate and trivial:
// the last page the human looked at, restored on the next start.

import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs'
import { dirname } from 'node:path'
import { BOARD_LANES } from './types.js'
import type { Density, PageId, ThemeChoice } from './types.js'
import { isLang, type Lang } from './strings/index.js'

export const PANEL_CONF_FILE = 'panel.conf'
export const PANEL_PAGE_FILE = 'panel-page'

export interface Settings {
  lang: Lang
  defaultPage: PageId
  activity: boolean
  mouse: boolean
  density: Density
  theme: ThemeChoice
  /** Board lanes folded explicitly (P123), in the lane legend's order. */
  boardFold: string[]
  /** Board lanes kept unfolded explicitly (P123): they stay unfolded even while empty. */
  boardShow: string[]
  /** Empty lanes fold by default (P123); `false` renders them boxed with the dim empty marker. */
  boardEmptyFold: boolean
}

export const DEFAULT_SETTINGS: Settings = {
  lang: 'zh',
  defaultPage: 1,
  activity: true,
  mouse: true,
  density: 'comfortable',
  theme: 'auto',
  boardFold: [],
  boardShow: [],
  boardEmptyFold: true,
}

function boolOf(value: string): boolean | null {
  const v = value.trim().toLowerCase()
  if (v === '1' || v === 'true' || v === 'on' || v === 'yes') return true
  if (v === '0' || v === 'false' || v === 'off' || v === 'no') return false
  return null
}

function pageOf(value: string): PageId | null {
  const v = value.trim()
  if (v === '1' || v === '2' || v === '3' || v === '4') return Number(v) as PageId
  return null
}

/**
 * A `boardFold`/`boardShow` value (P123): comma list of lane names. Unknown names are dropped,
 * duplicates dedupe, and the survivors come out in the lane legend's order — the same order
 * `serializePanelConf` writes, so a hand-edited list normalises on the first save.
 */
function lanesOf(value: string): string[] {
  const named = new Set(value.split(',').map((v) => v.trim()))
  return BOARD_LANES.filter((lane) => named.has(lane))
}

/** Parse a `panel.conf` body; unknown keys and unusable values are ignored (defaults survive). */
export function parsePanelConf(text: string): Settings {
  const out: Settings = { ...DEFAULT_SETTINGS }
  if (/[\u0000-\u0008\u000e-\u001f]/.test(text)) return out // binary garbage → defaults
  for (const raw of String(text).split('\n')) {
    const line = raw.trim()
    if (!line || line.startsWith('#')) continue
    const eq = line.indexOf('=')
    if (eq <= 0) continue
    const key = line.slice(0, eq).trim()
    const value = line.slice(eq + 1).trim()
    if (key === 'lang' && isLang(value)) out.lang = value
    else if (key === 'page') {
      const p = pageOf(value)
      if (p) out.defaultPage = p
    } else if (key === 'activity' || key === 'mouse') {
      const b = boolOf(value)
      if (b !== null) out[key] = b
    } else if (key === 'density' && (value === 'comfortable' || value === 'compact')) out.density = value
    else if (key === 'theme' && (value === 'dark' || value === 'light' || value === 'auto')) out.theme = value
    else if (key === 'boardFold') out.boardFold = lanesOf(value)
    else if (key === 'boardShow') out.boardShow = lanesOf(value)
    else if (key === 'boardEmptyFold') {
      const b = boolOf(value)
      if (b !== null) out.boardEmptyFold = b
    }
  }
  // A lane named by both lists folds: the explicit hide is the stronger statement.
  out.boardShow = out.boardShow.filter((lane) => !out.boardFold.includes(lane))
  return out
}

export function serializePanelConf(s: Settings): string {
  return [
    `lang=${s.lang}`,
    `page=${s.defaultPage}`,
    `activity=${s.activity ? 1 : 0}`,
    `mouse=${s.mouse ? 1 : 0}`,
    `density=${s.density}`,
    `theme=${s.theme}`,
    `boardFold=${BOARD_LANES.filter((lane) => s.boardFold.includes(lane)).join(',')}`,
    `boardShow=${BOARD_LANES.filter((lane) => s.boardShow.includes(lane)).join(',')}`,
    `boardEmptyFold=${s.boardEmptyFold ? 1 : 0}`,
    '',
  ].join('\n')
}

/** The settings the TUI runs with: the file when readable, the defaults otherwise. */
export function readSettings(file: string): Settings {
  try {
    if (!existsSync(file)) return { ...DEFAULT_SETTINGS }
    return parsePanelConf(readFileSync(file, 'utf8'))
  } catch {
    return { ...DEFAULT_SETTINGS }
  }
}

export function writeSettings(file: string, s: Settings): boolean {
  try {
    mkdirSync(dirname(file), { recursive: true })
    writeFileSync(file, serializePanelConf(s))
    return true
  } catch {
    return false // a state directory the console cannot write must not kill the panel
  }
}

/** The page remembered from the last run, or the fallback when there is none/its content is junk. */
export function readPage(file: string, fallback: PageId): PageId {
  try {
    if (!existsSync(file)) return fallback
    return pageOf(readFileSync(file, 'utf8')) ?? fallback
  } catch {
    return fallback
  }
}

export function writePage(file: string, page: PageId): boolean {
  try {
    mkdirSync(dirname(file), { recursive: true })
    writeFileSync(file, `${page}\n`)
    return true
  } catch {
    return false
  }
}
