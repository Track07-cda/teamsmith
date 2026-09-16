#!/usr/bin/env node
// Palette contrast gate for the two console themes (pulse-console B3, tasks.md 5.3).
//
//   node skills/teamsmith/tests/panel-contrast.mjs [panel.js]
//   node skills/teamsmith/tests/panel-contrast.mjs --palette-file bad.json   # the flip
//
// Reads the declared palettes from the bundle (`--palette`) and computes the WCAG 2.x contrast
// ratio of every declared tone against its declared background **independently of the panel's own
// arithmetic**. Every pair must reach 4.5:1; a failure names the theme, the tone and the ratio.
//
// Exit: 0 every pair ≥ 4.5:1, 1 at least one below (or the palette could not be read), 2 usage/IO.

import { execFileSync } from 'node:child_process'
import { readFileSync } from 'node:fs'
import { dirname, join, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const here = dirname(fileURLToPath(import.meta.url))
const BAR = 4.5

const args = process.argv.slice(2)
const fileIndex = args.indexOf('--palette-file')
let palettes
try {
  if (fileIndex !== -1) {
    palettes = JSON.parse(readFileSync(args[fileIndex + 1], 'utf8'))
    if (palettes.palettes) palettes = palettes.palettes
  } else {
    const panel = resolve(args[0] || join(here, '..', 'scripts', 'panel', 'panel.js'))
    const raw = execFileSync(process.execPath, [panel, '--palette'], { encoding: 'utf8' })
    palettes = JSON.parse(raw).palettes
  }
} catch (e) {
  console.error(`✗ panel-contrast: cannot read the palettes: ${e.message}`)
  process.exit(2)
}

const rgb = (hex) => {
  const m = /^#?([0-9a-fA-F]{6})$/.exec(String(hex).trim())
  if (!m) throw new Error(`not a hex color: ${hex}`)
  const n = Number.parseInt(m[1], 16)
  return [(n >> 16) & 0xff, (n >> 8) & 0xff, n & 0xff]
}
const luminance = (hex) => {
  const [r, g, b] = rgb(hex).map((v) => {
    const c = v / 255
    return c <= 0.04045 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4
  })
  return 0.2126 * r + 0.7152 * g + 0.0722 * b
}
const ratio = (a, b) => {
  const la = luminance(a)
  const lb = luminance(b)
  return (Math.max(la, lb) + 0.05) / (Math.min(la, lb) + 0.05)
}

let bad = 0
for (const [theme, palette] of Object.entries(palettes)) {
  const bg = palette.bg
  if (!bg) {
    console.error(`✗ ${theme}: no declared background`)
    bad++
    continue
  }
  let themeBad = 0
  for (const [tone, fg] of Object.entries(palette.tones ?? {})) {
    const r = ratio(fg, bg)
    if (r < BAR) {
      console.error(`✗ ${theme}.${tone}: ${fg} on ${bg} = ${r.toFixed(2)}:1 (below ${BAR}:1)`)
      bad++
      themeBad++
    }
  }
  if (themeBad === 0) console.log(`ok: ${theme} palette checked (${Object.keys(palette.tones ?? {}).length} pairs)`)
}

if (bad > 0) {
  console.error(`✗ panel-contrast: ${bad} pair(s) below ${BAR}:1`)
  process.exit(1)
}
console.log(`panel-contrast: ok (every declared pair ≥ ${BAR}:1)`)
