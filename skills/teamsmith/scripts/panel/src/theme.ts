// The two themes, the contrast rule and the ANSI mapping.
//
// The theme is a palette of *declared* foreground colors over one declared background; the gate
// script (`tests/panel-contrast.mjs`) computes the WCAG contrast ratio of every tone against its
// background and refuses a palette below 4.5:1. The palette is the single source for both the TUI
// (Ink `Text` colors) and the snapshot renderer (`renderAnsi`), so a theme change is one edit.
//
// "State is never carried by color alone" (design discipline): tones decorate text that already
// carries the state as a token/glyph — dropping all color leaves a readable frame.

import type { ThemeChoice, ThemeName, Tone } from './types.js'

export interface Palette {
  name: ThemeName
  /** The declared background the tones are checked against (the terminal's own is untouched). */
  bg: string
  tones: Record<Tone, string>
}

export const DARK: Palette = {
  name: 'dark',
  bg: '#10141a',
  tones: {
    title: '#ffffff',
    text: '#dfe3ea',
    dim: '#98a2b3',
    heading: '#7cc7ff',
    accent: '#9db8ff',
    ok: '#8ee6a1',
    warn: '#f2c66d',
    err: '#ff9d9d',
    selected: '#9db8ff',
  },
}

export const LIGHT: Palette = {
  name: 'light',
  bg: '#fbfbf8',
  tones: {
    title: '#111111',
    text: '#24292f',
    dim: '#57606a',
    heading: '#0b5cad',
    accent: '#1b4fd8',
    ok: '#0f7a37',
    warn: '#8a5a00',
    err: '#c0272d',
    selected: '#1b4fd8',
  },
}

export const PALETTES: Record<ThemeName, Palette> = { dark: DARK, light: LIGHT }

/** A pinned theme wins; `auto` reads the terminal background hint (`COLORFGBG`), dark by default. */
export function resolveTheme(choice: ThemeChoice, env: Record<string, string | undefined> = process.env): ThemeName {
  if (choice === 'dark' || choice === 'light') return choice
  const fgbg = String(env.COLORFGBG ?? '')
  const bg = fgbg.split(';').pop()?.trim() ?? ''
  if (/^\d+$/.test(bg)) return Number(bg) >= 7 && Number(bg) !== 8 ? 'light' : 'dark'
  return 'dark'
}

export function hexRgb(hex: string): [number, number, number] {
  const m = /^#?([0-9a-fA-F]{6})$/.exec(String(hex).trim())
  if (!m) return [0, 0, 0]
  const n = Number.parseInt(m[1], 16)
  return [(n >> 16) & 0xff, (n >> 8) & 0xff, n & 0xff]
}

function channel(v: number): number {
  const c = v / 255
  return c <= 0.04045 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4
}

export function relativeLuminance(hex: string): number {
  const [r, g, b] = hexRgb(hex)
  return 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b)
}

/** WCAG 2.x contrast ratio, 1..21. */
export function contrastRatio(a: string, b: string): number {
  const la = relativeLuminance(a)
  const lb = relativeLuminance(b)
  const hi = Math.max(la, lb)
  const lo = Math.min(la, lb)
  return (hi + 0.05) / (lo + 0.05)
}

/** Every declared tone/background pair, for the gate script and `--palette`. */
export function contrastPairs(palette: Palette = DARK): { tone: Tone; fg: string; bg: string; ratio: number }[] {
  return (Object.keys(palette.tones) as Tone[]).map((tone) => ({
    tone,
    fg: palette.tones[tone],
    bg: palette.bg,
    ratio: contrastRatio(palette.tones[tone], palette.bg),
  }))
}

const BASIC: Record<Tone, string> = {
  title: '97',
  text: '39',
  dim: '90',
  heading: '96',
  accent: '94',
  ok: '92',
  warn: '93',
  err: '91',
  selected: '94',
}

/** The SGR parameters for a tone: truecolor when the terminal claims it, 16-color otherwise. */
export function toneSgr(tone: Tone, palette: Palette, truecolor = true): string {
  if (!truecolor) return BASIC[tone] ?? '39'
  const [r, g, b] = hexRgb(palette.tones[tone] ?? '#ffffff')
  return `38;2;${r};${g};${b}`
}
