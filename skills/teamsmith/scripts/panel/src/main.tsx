// teamsmith pulse panel — the Ink front end over the data layer.
//
//   panel.js [--root DIR] [--print | --json | --once] [--width N] [--height N]
//            [--activity | --no-activity] [--events N] [--refresh N] [--no-pulse] [--version]
//
// Modes (the `panel` contract):
//   --print      one plain-text frame, no escape sequence, writes nothing, never ticks
//   --json       {"panel": {...}, "activity": [...]}, writes nothing, never ticks
//   --once       one frame through the renderer selection, keeps today's tick semantics
//   (default)    the TUI in a terminal; stdout not a TTY selects the plain-text path unless
//                TEAM_MONITOR_UI=tui forces the renderer
//
// Everything on screen comes from `team __panel-data`; the tick is `team watch --once`.

import React from 'react'
import { writeSync } from 'node:fs'
import { render } from 'ink'
import { App } from './App.js'
import { findTeamCli, loadPanelData, panelDirOf, runTick } from './data.js'
import { buildFrame, buildJson } from './layout.js'
import type { FrameInput } from './types.js'

declare const __PIN_INK__: string | undefined
declare const __PIN_REACT__: string | undefined
declare const __BUILD_CMD__: string | undefined

const PANEL_VERSION = '1.0.0'
const PIN_INK = typeof __PIN_INK__ === 'undefined' ? 'dev' : __PIN_INK__
const PIN_REACT = typeof __PIN_REACT__ === 'undefined' ? 'dev' : __PIN_REACT__
const BUILD_CMD =
  typeof __BUILD_CMD__ === 'undefined'
    ? 'bun install --frozen-lockfile && bash skills/teamsmith/scripts/panel/build.sh'
    : __BUILD_CMD__

function argOf(name: string): string | undefined {
  const i = process.argv.indexOf(`--${name}`)
  if (i === -1) return undefined
  const v = process.argv[i + 1]
  return v && !v.startsWith('--') ? v : undefined
}

const has = (name: string) => process.argv.includes(`--${name}`)

/** Machine-readable output must not be lost to an async pipe write. */
function out(text: string): void {
  writeSync(1, text)
}
function fail(message: string): never {
  writeSync(2, `✗ ${message}\n`)
  process.exit(1)
}

const root = argOf('root') || process.cwd()
const teamCli = argOf('team-cli') || findTeamCli(panelDirOf(import.meta.url)) || undefined
const events = Number(argOf('events') ?? 4) || 4
const refresh = Math.max(1, Number(argOf('refresh') ?? 5) || 5)
const tickEvery = Number(argOf('tick-every') ?? 0) || 0
const noPulse = has('no-pulse') || has('no-watchdog')
const once = has('once')
const wantJson = has('json')
const wantPrint = has('print')
const widthArg = Number(argOf('width') ?? 0)
const heightArg = Number(argOf('height') ?? 0)
const ui = String(process.env.TEAM_MONITOR_UI || argOf('ui') || 'auto')
const noActivity = has('no-activity')
const yesActivity = has('activity')
const activityOn = yesActivity || (!noActivity && String(process.env.TEAM_MONITOR_ACTIVITY ?? '1') !== '0')

if (has('version')) {
  out(`teamsmith panel ${PANEL_VERSION} · ink ${PIN_INK} · react ${PIN_REACT}\nbuilt by: ${BUILD_CMD}\n`)
  process.exit(0)
}
if (has('help')) {
  out(
    'usage: panel.js [--root DIR] [--print|--json|--once] [--width N] [--height N] [--activity|--no-activity]\n' +
      '                [--events N] [--refresh N] [--no-pulse] [--version]\n',
  )
  process.exit(0)
}

type Mode = 'text' | 'json' | 'tui'
function pickMode(): Mode {
  if (wantJson) return 'json'
  if (wantPrint) return 'text'
  if (ui === 'text') return 'text'
  if (ui === 'tui') return 'tui'
  return process.stdout.isTTY ? 'tui' : 'text'
}

const mode = pickMode()
const stdoutColumns = process.stdout.columns || 0
const stdoutRows = process.stdout.rows || 0

// ---------------------------------------------------------------- the tick loop (owned here)
let lastTick = 0
const tickLog = argOf('tick-log') || `${root}/.pi/team/state/watchdog.tick.log`

function tickDue(): boolean {
  if (noPulse || tickEvery <= 0) return false
  const now = Date.now()
  if (lastTick === 0 || now - lastTick >= tickEvery * 1000) {
    lastTick = now
    return true
  }
  return false
}
function runTickIfDue(): void {
  if (!tickDue()) return
  if (!teamCli) return
  runTick(teamCli, root, tickLog)
}

function readFrame(): FrameInput {
  const res = loadPanelData({ root, teamCli, activity: activityOn, events })
  if (!res.ok || !res.data) fail(res.error || 'panel: data read failed')
  const data = res.data as Exclude<typeof res.data, undefined>
  const activityBlocks = activityOn ? res.activity ?? [] : []
  return {
    panel: data,
    activityBlocks,
    width: widthArg || stdoutColumns || 100,
    height: heightArg || stdoutRows || 0,
    activity: activityOn,
  }
}

if (mode === 'json') {
  out(`${JSON.stringify(buildJson(readFrame()))}\n`)
  process.exit(0)
}

if (mode === 'text') {
  if (once || wantPrint) {
    // One frame; `--once` then keeps today's tick semantics, `--print` (the observer) never ticks.
    out(`${buildFrame(readFrame()).join('\n')}\n`)
    if (once) runTickIfDue()
    process.exit(0)
  }
  // Plain-text run: the old loop's semantics (a frame per TEAM_MONITOR_REFRESH, a tick per the
  // tick period) with the control bytes removed — a redirected `team monitor` no longer clears the
  // caller's output. One frame per iteration, no clear, never a TUI escape sequence.
  for (;;) {
    out(`${buildFrame(readFrame()).join('\n')}\n`)
    runTickIfDue()
    sleepSync(Math.max(1, refresh) * 1000)
  }
}

function sleepSync(ms: number): void {
  // Blocking sleep on the main thread; no child process, no busy loop.
  try {
    Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, ms)
  } catch {
    const end = Date.now() + ms
    while (Date.now() < end) {
      /* fallback if Atomics.wait is unavailable in this runtime */
    }
  }
}

/** stdin/stdout are set up by the caller; `resize` is emitted by Node's tty stream. */
function onResize(handler: () => void): void {
  if (typeof process.stdout.on === 'function') process.stdout.on('resize', handler)
}

// TUI: the run owns the loop — one frame per TEAM_MONITOR_REFRESH, one tick per the tick period,
// no second window and no background worker.
let current: FrameInput = readFrame()
const reload = (): FrameInput => {
  runTickIfDue()
  const r = loadPanelData({ root, teamCli, activity: activityOn, events })
  if (r.ok && r.data) {
    current = {
      panel: r.data,
      activityBlocks: activityOn ? r.activity ?? [] : [],
      width: widthArg || stdoutColumns || 100,
      height: heightArg || stdoutRows || 0,
      activity: activityOn,
    }
  }
  return current
}

const app = render(React.createElement(App, { frame: current, refresh, reload, once }), {
  exitOnCtrlC: false,
  patchConsole: false,
})

// A shrinking pane is the one terminal event Ink's relative cursor arithmetic cannot survive on a normal
// screen: the frame it wrote before the resize is now scrolled out, so the next frame lands off-screen and
// the pane looks blank (measured: 50x200 → 120x29 left 29 empty rows while the log showed full frames).
// Reset the screen and Ink's own line bookkeeping, then draw a fresh frame at the top.
onResize(() => {
  try {
    writeSync(1, '\x1b[2J\x1b[3J\x1b[H')
    app.clear()
  } catch {
    /* a terminal that rejects the reset must not kill the panel */
  }
  try {
    app.rerender(React.createElement(App, { frame: current, refresh, reload, once }))
  } catch {
    /* rerender is best effort; the next refresh redraws anyway */
  }
})

if (once) runTickIfDue()
app.waitUntilExit().then(() => {
  process.exit(0)
})
