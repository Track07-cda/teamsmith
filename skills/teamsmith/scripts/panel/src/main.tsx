// teamsmith pulse panel — the Ink front end over the data layer.
//
//   panel.js [--root DIR] [--print | --json | --once] [--width N] [--height N]
//            [--activity | --no-activity] [--events N] [--refresh N] [--no-pulse] [--version]
//            [--headless] [--snapshot] [--palette] [--theme dark|light] [--page 1|2|3|4] [--lang zh|en]
//            [--overlay] [--detail ID]
//
// Modes (the `panel` contract):
//   --print      one plain-text frame (the overview), no escape sequence, writes nothing, never ticks
//   --json       {"panel": {...}, "activity": [...]}, writes nothing, never ticks
//   --once       one frame through the renderer selection, keeps today's tick semantics
//   (default)    the TUI in a terminal; stdout not a TTY selects the plain-text path unless
//                TEAM_MONITOR_UI=tui forces the renderer
//   --headless   the tick loop only (no renderer) — the shape the console collapses into
//   --snapshot   one themed frame with SGR bytes (the snapshot suite's deterministic exit);
//                `--overlay` opens the settings overlay in that frame (the overlay's column plan)
//   --palette    the declared palettes + their contrast pairs as JSON (the gate script's input)
//
// Everything on screen comes from `team __panel-data`; the tick is `team watch --once`.
// `--print`/`--json` never read `state/panel.conf` or the page file: the machine exits are frozen.

import React from 'react'
import { writeSync, appendFileSync, existsSync, mkdirSync, readFileSync, statSync, writeFileSync } from 'node:fs'
import { Writable } from 'node:stream'
import { spawn } from 'node:child_process'
import { homedir } from 'node:os'
import { dirname, join } from 'node:path'
import { render } from 'ink'
import chalk from 'chalk'
import { App, frameSignature } from './App.js'
import type { PanelApi } from './App.js'
import { clockOf } from './format.js'
import { dispWidth } from './width.js'
import type { Palette } from './theme.js'
import type { Segment } from './types.js'
import { BLOCK_NAMES, MACHINE_BLOCKS, cleanIdentityEnv, createPanelCache, findTeamCli, loadPanelData, panelDirOf, runTick } from './data.js'
import type { DataOptions, DataResult, PanelCache } from './data.js'
import { normalizeNewlines, parseSendResult, mapReceipt, DRAFT_FILE } from './compose.js'
import type { Receipt } from './compose.js'
import { createClipboardRunner, readClipboard, writePasteFile } from './clipboard.js'
import { buildJson, layout, renderAnsi, renderPlain } from './layout.js'
import type { LayoutInput } from './layout.js'
import { fill, stringsFor } from './strings/index.js'
import { PANEL_CONF_FILE, PANEL_PAGE_FILE, readPage, readSettings, writePage, writeSettings } from './settings.js'
import type { Settings } from './settings.js'
import { contrastPairs, PALETTES, resolveTheme } from './theme.js'
import type { FrameInput, PageId, ViewState } from './types.js'

/** The Kitty keyboard protocol's pop/push pair, written around the editor handoff (design §6). */
const KITTY_POP = '\u001b[<u'
const KITTY_PUSH = '\u001b[>1u'

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

/**
 * Ink's own cursor bookkeeping assumes a frame that ends with a newline, but the console fills the
 * pane (the bounded frame pads to the terminal height), so Ink writes a fullscreen frame with no
 * trailing newline and its `useCursor` lands one row high; its cursor-only path (an arrow key that
 * moves the point without changing the text) then drifts upward a row per move (measured on the
 * pinned ink 7.1.1). This stream forwards every Ink write to the real stdout and re-asserts the
 * insertion point absolutely (CUP is 1-based) in the same write call — the one place that also
 * sees Ink's throttled frames. `null` means "not composing": the cursor is hidden.
 */
function cursorAwareStdout(base: NodeJS.WriteStream, cursorOf: () => { x: number; y: number } | null): NodeJS.WriteStream {
  const out = new Writable({
    write(chunk: Buffer | string, _encoding: BufferEncoding, callback: (error?: Error | null) => void) {
      const pos = cursorOf()
      const suffix = pos ? `\u001b[?25h\u001b[${pos.y + 1};${pos.x + 1}H` : '\u001b[?25l'
      try {
        base.write(typeof chunk === 'string' ? chunk + suffix : Buffer.concat([chunk, Buffer.from(suffix)]))
      } catch {
        /* a closed stdout must not kill the panel */
      }
      callback()
    },
  }) as unknown as NodeJS.WriteStream
  ;(out as { isTTY?: boolean }).isTTY = Boolean(base.isTTY)
  Object.defineProperty(out, 'columns', { get: () => process.stdout.columns })
  Object.defineProperty(out, 'rows', { get: () => process.stdout.rows })
  return out
}

function argOf(name: string): string | undefined {
  const i = process.argv.indexOf(`--${name}`)
  if (i === -1) return undefined
  const v = process.argv[i + 1]
  return v && !v.startsWith('--') ? v : undefined
}

const has = (name: string): boolean => process.argv.includes(`--${name}`)

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
const refresh = Math.max(1, Number(argOf('refresh') ?? 3) || 3)
const tickEvery = Number(argOf('tick-every') ?? 0) || 0
const noPulse = has('no-pulse') || has('no-watchdog')
const once = has('once')
const wantJson = has('json')
const wantPrint = has('print')
const wantSnapshot = has('snapshot')
const wantOverlay = has('overlay')
const wantPalette = has('palette')
const headless = has('headless')
const widthArg = Number(argOf('width') ?? 0)
const heightArg = Number(argOf('height') ?? 0)
const ui = String(process.env.TEAM_MONITOR_UI || argOf('ui') || 'auto')
const noActivity = has('no-activity')
const yesActivity = has('activity')
const activityPinned = yesActivity || noActivity
const activityFlag = yesActivity ? true : noActivity ? false : null
const envActivity = String(process.env.TEAM_MONITOR_ACTIVITY ?? '1') !== '0'
const rawActivityOn = activityFlag ?? envActivity
const themeArg = argOf('theme')
const pageArg = argOf('page')
const langArg = argOf('lang')
/** `--detail <ID>`: render the read-only detail view in a snapshot (the overlay's sibling exit). */
const detailArg = argOf('detail') || ''

if (has('version')) {
  out(`teamsmith panel ${PANEL_VERSION} · ink ${PIN_INK} · react ${PIN_REACT}\nbuilt by: ${BUILD_CMD}\n`)
  process.exit(0)
}
if (has('help')) {
  out(
    'usage: panel.js [--root DIR] [--state-dir DIR] [--print|--json|--once|--headless|--snapshot|--palette]\n' +
      '                [--width N] [--height N] [--activity|--no-activity] [--events N] [--refresh N]\n' +
      '                [--no-pulse] [--theme dark|light] [--page 1|2|3|4] [--lang zh|en] [--overlay] [--detail ID] [--version]\n',
  )
  process.exit(0)
}

// The console's own state files live in the project's state directory. The launcher passes it
// explicitly; the tick log path and the project root are the fallbacks, so a direct `panel.js`
// invocation still finds it.
const tickLogArg = argOf('tick-log') || ''
const stateDir = argOf('state-dir') || (tickLogArg ? dirname(tickLogArg) : join(root, '.pi/team/state'))
const draftFile = join(stateDir, DRAFT_FILE)
const confFile = join(stateDir, PANEL_CONF_FILE)
const pageFile = join(stateDir, PANEL_PAGE_FILE)

// M40 — the panel's identity is its own root (`--root`, else cwd), never an inherited `TEAM_*`.
// An inherited value that names another project is not honoured silently: one line before any frame
// is drawn (stderr = the pulse window, which is this long-running process's log) plus a durable line
// in the project's own state/panel.log. ASCII only: visible text belongs to the i18n tables and the
// CJK-literal gate covers the whole source tree.
const inheritedRoot = process.env.TEAM_ROOT
if (inheritedRoot) {
  const envRoot = inheritedRoot.replace(/\/+$/, '')
  if (envRoot && envRoot !== root.replace(/\/+$/, '')) {
    const line = `! TEAM_IDENTITY_CONFLICT (panel): rendering --root/cwd='${root}', ignoring inherited TEAM_ROOT='${inheritedRoot}'\n`
    try {
      writeSync(2, line)
    } catch {
      /* a stderr that cannot be written must not kill the panel */
    }
    try {
      mkdirSync(stateDir, { recursive: true })
      appendFileSync(join(stateDir, 'panel.log'), `${new Date().toISOString()} ${line}`)
    } catch {
      /* a state directory that cannot be written must not kill the panel either */
    }
  }
}

type Mode = 'text' | 'json' | 'tui'
function pickMode(): Mode {
  if (wantJson) return 'json'
  if (wantPrint) return 'text'
  if (ui === 'text') return 'text'
  if (ui === 'tui') return 'tui'
  return process.stdout.isTTY ? 'tui' : 'text'
}

const mode: Mode | 'snapshot' | 'palette' | 'headless' = wantPalette
  ? 'palette'
  : wantSnapshot
    ? 'snapshot'
    : headless
      ? 'headless'
      : pickMode()
const stdoutColumns = process.stdout.columns || 0
const stdoutRows = process.stdout.rows || 0

// ---------------------------------------------------------------- machine-only exits
if (mode === 'palette') {
  out(
    `${JSON.stringify(
      {
        palettes: PALETTES,
        pairs: { dark: contrastPairs(PALETTES.dark), light: contrastPairs(PALETTES.light) },
      },
      null,
      2,
    )}\n`,
  )
  process.exit(0)
}

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

async function runTickIfDue(): Promise<void> {
  if (!tickDue()) return
  if (!teamCli) return
  await runTick(teamCli, root, tickLog)
}

function frameOf(res: DataResult, activity: boolean, scroll?: number): FrameInput {
  return {
    panel: res.data ?? { project: '', timestamp: '', interval: 0 },
    activityBlocks: activity ? res.activity ?? [] : [],
    blocks: res.blocks ?? {},
    degraded: res.degraded ?? [],
    width: widthArg || stdoutColumns || 100,
    height: heightArg || stdoutRows || 0,
    activity,
  }
}

/** A frame where every block failed is not a frame: fail loudly like the old data path did. */
function frameOrFail(res: DataResult, activity: boolean, wanted: readonly string[] = BLOCK_NAMES): FrameInput {
  const allDown = wanted.every((name) => (res.degraded ?? []).includes(name as never))
  if (!res.ok || !res.data || allDown) {
    const first = res.error || Object.values(res.errors ?? {})[0] || 'panel: data read failed'
    fail(res.error || `panel: every block failed (${first})`)
  }
  return frameOf(res, activity)
}

function defaultView(lang: string, page: PageId): ViewState {
  return {
    page,
    density: 'comfortable',
    lang,
    mouseOn: false,
    tui: false,
    overlay: false,
    overlayIndex: 0,
    viewEntry: null,
    scroll: 0,
    detailIndex: 0,
    detailScroll: 0,
  }
}

/** The compose insertion point main.tsx's cursor-aware stdout re-asserts after every Ink write. */
let composeCursor: { x: number; y: number } | null = null

async function main(): Promise<void> {
  if (mode === 'json') {
    const res = await loadPanelData({ root, teamCli, activity: rawActivityOn, events, blocks: MACHINE_BLOCKS })
    out(`${JSON.stringify(buildJson(frameOrFail(res, rawActivityOn, MACHINE_BLOCKS), refresh))}\n`)
    process.exit(0)
  }

  if (mode === 'snapshot') {
    // One themed frame, deterministic: the snapshot suite pins the tier × theme matrix through this
    // exit. It is not `--print` (which must stay escape-free), so the SGR bytes are expected.
    const settings = readSettings(confFile)
    const themeName = themeArg === 'dark' || themeArg === 'light' ? themeArg : resolveTheme(settings.theme)
    const lang = langArg === 'en' || langArg === 'zh' ? langArg : settings.lang
    const page = pageArg === '1' || pageArg === '2' || pageArg === '3' || pageArg === '4' ? (Number(pageArg) as PageId) : settings.defaultPage
    const res = await loadPanelData({ root, teamCli, activity: rawActivityOn, events, detailId: detailArg || null })
    const frame = frameOrFail(res, rawActivityOn)
    const view: ViewState = {
      ...defaultView(lang, page),
      tui: true,
      mouseOn: settings.mouse,
      density: settings.density,
      overlay: wantOverlay,
      detail: detailArg || null,
      // P123: the snapshot is the TUI's own render path, so it reads the fold keys (the machine exits
      // stay on `defaultView` and never look at them).
      boardFold: settings.boardFold,
      boardShow: settings.boardShow,
      boardEmptyFold: settings.boardEmptyFold,
    }
    const themed = layout({
      ...frame,
      strings: stringsFor(lang),
      height: heightArg || 0,
      view,
    } as LayoutInput)
    if (has('targets')) {
      // The click-target map of the same frame the snapshot renders: one entry per documented key
      // (and per page tab / queue row). The gate asserts the set, so a key without a target fails.
      out(`${JSON.stringify(themed.targets.map((t) => ({ row: t.row, action: t.hit.action })))}\n`)
      process.exit(0)
    }
    out(`${renderAnsi(themed, PALETTES[themeName], { truecolor: true }).join('\n')}\n`)
    process.exit(0)
  }

  if (mode === 'headless') {
    // The tick loop with no renderer. `team monitor --headless` is the bash loop (lock + drift
    // reexec); this branch serves a direct bundle invocation and keeps the same cadence.
    for (;;) {
      await runTickIfDue()
      sleepSync(Math.max(1, tickEvery || refresh) * 1000)
    }
  }

  if (mode === 'text') {
    // `--page` is honoured here too (P123's machine-frame identity fixture renders page 4); absent,
    // the machine frame stays the overview it always was.
    const machinePage: PageId =
      pageArg === '1' || pageArg === '2' || pageArg === '3' || pageArg === '4' ? (Number(pageArg) as PageId) : 1
    if (once || wantPrint) {
      // One frame; `--once` then keeps today's tick semantics, `--print` (the observer) never ticks.
      const frame = frameOrFail(await loadPanelData({ root, teamCli, activity: rawActivityOn, events, blocks: MACHINE_BLOCKS }), rawActivityOn, MACHINE_BLOCKS)
      const themed = layout({ ...frame, strings: stringsFor('zh'), view: defaultView('zh', machinePage) } as LayoutInput)
      out(`${renderPlain(themed).join('\n')}\n`)
      if (once) await runTickIfDue()
      process.exit(0)
    }
    // Plain-text run: the old loop's semantics (a frame per TEAM_MONITOR_REFRESH, a tick per the
    // tick period) with the control bytes removed — a redirected `team monitor` no longer clears the
    // caller's output. One frame per iteration, no clear, never a TUI escape sequence.
    for (;;) {
      const frame = frameOrFail(await loadPanelData({ root, teamCli, activity: rawActivityOn, events, blocks: MACHINE_BLOCKS }), rawActivityOn, MACHINE_BLOCKS)
      const themed = layout({ ...frame, strings: stringsFor('zh'), view: defaultView('zh', machinePage) } as LayoutInput)
      out(`${renderPlain(themed).join('\n')}\n`)
      await runTickIfDue()
      sleepSync(Math.max(1, refresh) * 1000)
    }
  }

  // TUI: the run owns the loop — one frame per TEAM_MONITOR_REFRESH, one tick per the tick period,
  // no second window and no background worker. The data assembly is asynchronous and cached: a
  // refresh in flight never delays a keystroke, and only the blocks whose TTL expired are rebuilt.
  const settings = readSettings(confFile)
  const effectiveLang = settings.lang
  const s = stringsFor(effectiveLang)
  const palette = PALETTES[resolveTheme(settings.theme)]
  // Activity precedence inside the TUI: CLI flag > panel.conf > TEAM_MONITOR_ACTIVITY.
  const activityOn = activityPinned ? rawActivityOn : settings.activity
  const opts: DataOptions = { root, teamCli, activity: activityOn, events }
  const cache: PanelCache = createPanelCache(opts)
  const first = await cache.refresh({ force: true })
  let current = frameOrFail(first, activityOn)
  /** The signature of the frame Ink last drew; an unchanged frame must not repaint. */
  let renderedSig = frameSignature(current)
  let app: ReturnType<typeof render> | undefined
  /** True while an external program (the editor relay) owns the terminal. */
  let editorActive = false
  let mouseEnabled = settings.mouse
  const panelDir = panelDirOf(import.meta.url)
  const clipRunner = createClipboardRunner()
  const bridge = existsSync(join(panelDir, 'draft-send.sh'))
    ? join(panelDir, 'draft-send.sh')
    : join(panelDir, '..', 'draft-send.sh')
  const page = readPage(pageFile, settings.defaultPage)

  const panelElement = (): React.ReactElement =>
    React.createElement(App, {
      frame: current,
      refresh,
      reload,
      once,
      api,
      settings,
      page,
      palette,
      activityPinned,
    })

  const adopt = (res: DataResult): void => {
    if (!res.ok || !res.data || BLOCK_NAMES.every((name) => (res.degraded ?? []).includes(name))) return
    const next = frameOf(res, activityPinned ? rawActivityOn : opts.activity, current.height)
    const sig = frameSignature(next)
    const changed = sig !== renderedSig
    current = next
    renderedSig = sig
    // The render callback is explicitly gated while `$EDITOR` owns the terminal: Ink must not
    // touch the screen between the handoff and the editor's exit. A frame that did not change must
    // not repaint either: Ink reconciles the whole element tree on `rerender`, and at a 3s cadence
    // that alone is several times the console's CPU budget.
    if (editorActive || !changed) return
    try {
      app?.rerender(panelElement())
    } catch {
      /* rerender is best effort; the next refresh redraws anyway */
    }
  }

  const reload = (): FrameInput => {
    void runTickIfDue()
    void cache.refresh().then(adopt)
    return current
  }
  const refreshNow = (): void => {
    void cache.refresh({ force: true }).then(adopt)
  }

  // ---------------------------------------------------------------- the console's actions
  function readDraft(): string {
    try {
      return normalizeNewlines(readFileSync(draftFile, 'utf8'))
    } catch {
      return ''
    }
  }
  function writeDraft(text: string): void {
    try {
      mkdirSync(stateDir, { recursive: true })
      writeFileSync(draftFile, String(text ?? ''))
    } catch {
      /* a state directory the console cannot write must not kill the panel */
    }
  }

  /** Run one subprocess to completion; resolves with rc + combined output. Never throws. */
  function run(
    argv: string[],
    env: NodeJS.ProcessEnv = process.env,
  ): Promise<{ rc: number; out: string; err: string }> {
    return new Promise((resolve) => {
      let child: ReturnType<typeof spawn>
      try {
        child = spawn('bash', argv, { cwd: root, env: cleanIdentityEnv(env), stdio: ['ignore', 'pipe', 'pipe'] })
      } catch (e) {
        resolve({ rc: 127, out: '', err: (e as Error).message })
        return
      }
      let stdout = ''
      let stderr = ''
      let settled = false
      const timer = setTimeout(() => {
        try {
          child.kill('SIGKILL')
        } catch {
          /* already gone */
        }
        finish(124, 'timed out')
      }, 120000)
      const finish = (rc: number, tail: string): void => {
        if (settled) return
        settled = true
        clearTimeout(timer)
        if (tail) stderr = `${stderr}\n${tail}`
        resolve({ rc, out: stdout, err: stderr })
      }
      child.stdout?.on('data', (d: Buffer) => {
        stdout += String(d)
      })
      child.stderr?.on('data', (d: Buffer) => {
        stderr += String(d)
      })
      child.on('error', (e) => finish(127, e.message))
      child.on('close', (code) => finish(code ?? 1, ''))
    })
  }

  /** First useful line of a command's output, for the one-line receipt. */
  function firstLine(text: string): string {
    const line = String(text ?? '')
      .split('\n')
      .map((l) => l.trim())
      .find((l) => l.length > 0)
    return line ?? ''
  }

  async function send(text: string): Promise<Receipt> {
    writeDraft(text)
    const res = await run([bridge, draftFile])
    const parsed = parseSendResult(res.out)
    const detail = firstLine(res.err)
    if (!parsed) {
      return { state: 'error', token: `rc=${res.rc} no-token`, detail: detail || s.sendUnconfirmed }
    }
    const receipt = mapReceipt(parsed.rc, parsed.outcome, parsed.result, detail)
    refreshNow()
    return receipt
  }

  async function flushQueue(): Promise<{ ok: boolean; line: string }> {
    if (!teamCli) return { ok: false, line: `✗ ${s.noTeamCli}` }
    const res = await run([teamCli, '--root', root, 'outbox', 'flush'])
    const line = firstLine(res.err) || firstLine(res.out)
    refreshNow()
    return {
      ok: res.rc === 0,
      line: res.rc === 0 ? fill(s.flushOk, { detail: line }) : fill(s.flushFail, { detail: line }),
    }
  }

  /**
   * One `team config set` invocation (P22/B3): the console never opens the contract itself — it
   * spawns the owning command and maps its exit code to an honest receipt in the App. `--dry-run`
   * writes neither the contract nor an audit line (the validation call is a read).
   */
  async function setSetting(
    key: string,
    value: string,
    o: { dryRun?: boolean; fingerprint?: string | null; allowDanger?: boolean },
  ): Promise<{ code: number; line: string }> {
    if (!teamCli) return { code: 127, line: s.noTeamCli }
    const args = [teamCli, '--root', root, 'config', 'set', key, value, '--actor', 'panel']
    if (o.dryRun) args.push('--dry-run')
    else args.push('--yes')
    if (o.fingerprint) args.push('--fingerprint', o.fingerprint)
    if (o.allowDanger) args.push('--allow-danger')
    const res = await run(args)
    const line = firstLine(res.err) || firstLine(res.out)
    // On a settle the view re-reads the settings block (the list and the audit footer) in the
    // background; a validation changes nothing.
    if (!o.dryRun) refreshSettingsSoon()
    return { code: res.rc, line }
  }

  /** One `team config set-agent-model <seat> <model|->` invocation (P22/B4). */
  async function setSeatModel(
    seat: string,
    model: string,
    o: { dryRun?: boolean; fingerprint?: string | null },
  ): Promise<{ code: number; line: string }> {
    if (!teamCli) return { code: 127, line: s.noTeamCli }
    const args = [teamCli, '--root', root, 'config', 'set-agent-model', seat, model || '-', '--actor', 'panel']
    if (o.dryRun) args.push('--dry-run')
    else args.push('--yes')
    if (o.fingerprint) args.push('--fingerprint', o.fingerprint)
    const res = await run(args)
    const line = firstLine(res.err) || firstLine(res.out)
    if (!o.dryRun) refreshSettingsSoon()
    return { code: res.rc, line }
  }

  /**
   * The background half of a settle (M65/D11): rebuild only the settings block and adopt it when
   * it lands. Nothing on the interaction path awaits this — the receipt was drawn from the
   * command's own result, and this read only refreshes what the next interaction sees.
   */
  function refreshSettingsSoon(): void {
    void cache.refresh({ force: true, only: ['settings'] }).then(adopt)
  }

  async function setStandby(on: boolean, reason: string): Promise<{ ok: boolean; line: string }> {    if (!teamCli) return { ok: false, line: `✗ ${s.noTeamCli}` }
    const args = on
      ? [teamCli, '--root', root, 'standby', 'on', '--reason', reason || '-']
      : [teamCli, '--root', root, 'standby', 'off']
    const res = await run(args)
    const line = firstLine(res.err) || firstLine(res.out)
    refreshNow()
    return {
      ok: res.rc === 0,
      line:
        res.rc === 0
          ? on
            ? fill(s.standbyOkOn, { reason: reason || '-' })
            : s.standbyOkOff
          : fill(s.standbyFail, { detail: line }),
    }
  }

  /**
   * `C-e`: hand the terminal to `$EDITOR` and come back to an intact frame. The draft is written
   * to `state/draft.md` first (the editor edits the real file), the render callback is gated for
   * the whole handoff, and the editor's exit restores raw mode before one fresh frame is drawn.
   */
  async function editDraft(text: string): Promise<string> {
    editorActive = true
    writeDraft(text)
    // The re-render triggered by the relay key commits asynchronously and Ink's throttled write can
    // trail it by up to one render frame (≤34ms): the editor must not start before the panel's last
    // frame is on screen, or that trailing write erases the editor's own first lines (measured: an
    // editor that prints immediately lost `EDITOR-ACTIVE` to the panel's frame). Wait for the
    // commit, then outlive one throttle window.
    try {
      await app?.waitUntilRenderFlush?.()
    } catch {
      /* the flush is best effort; the grace below still covers the trailing write */
    }
    await new Promise((resolve) => setTimeout(resolve, 60))
    return new Promise((resolve) => {
      const editor = process.env.TEAM_PANEL_EDITOR || process.env.EDITOR || process.env.VISUAL || 'vi'
      // The Kitty keyboard protocol is on (design §6): the editor did not ask for it, so pop it
      // before the handoff and push it again after — `CSI < u` / `CSI > 1 u`. The pop is a no-op
      // on a terminal that never answered Ink's query, and the push is the flag Ink itself enables.
      writeSync(1, KITTY_POP)
      try {
        process.stdin.setRawMode?.(false)
      } catch {
        /* not a tty: the fixture always gives us one */
      }
      try {
        process.stdin.pause?.()
      } catch {
        /* ignore */
      }
      let child: ReturnType<typeof spawn>
      try {
        child = spawn('bash', ['-c', 'exec ${TEAM_PANEL_EDITOR:?} "$1"', '_', draftFile], {
          cwd: root,
          env: cleanIdentityEnv({ ...process.env, TEAM_PANEL_EDITOR: editor }),
          stdio: 'inherit',
        })
      } catch {
        editorActive = false
        writeSync(1, KITTY_PUSH)
        resolve(text)
        return
      }
      const done = (): void => {
        editorActive = false
        writeSync(1, KITTY_PUSH)
        try {
          process.stdin.setRawMode?.(true)
        } catch {
          /* ignore */
        }
        try {
          process.stdin.resume?.()
        } catch {
          /* ignore */
        }
        // The editor drew over the panel: wipe the screen and Ink's line bookkeeping, then draw
        // one fresh frame. The frame must be intact when the relay returns.
        try {
          writeSync(1, '\x1b[2J\x1b[3J\x1b[H')
          app?.clear()
          app?.rerender(panelElement())
        } catch {
          /* best effort; the next refresh redraws anyway */
        }
        resolve(readDraft())
      }
      child.on('error', done)
      child.on('close', done)
    })
  }

  /** `q`: rebuild this very window as the headless tick loop (`team pulse collapse`). */
  async function collapse(): Promise<{ ok: boolean; line: string }> {
    if (mouseEnabled) {
      try {
        writeSync(1, '\u001b[?1000l\u001b[?1006l')
      } catch {
        /* ignore */
      }
    }
    if (!teamCli) return { ok: false, line: `✗ ${s.noTeamCli}` }
    if (!process.env.TMUX) {
      // Not inside a tmux window (a direct bundle run): there is nothing to respawn.
      exitSoon()
      return { ok: true, line: '' }
    }
    const res = await run([teamCli, '--root', root, 'pulse', 'collapse'])
    if (res.rc !== 0) return { ok: false, line: fill(s.flushFail, { detail: firstLine(res.err) || firstLine(res.out) }) }
    exitSoon()
    return { ok: true, line: '' }
  }

  let exiting = false
  function exitSoon(): void {
    if (exiting) return
    exiting = true
    setTimeout(() => process.exit(0), 150)
  }

  // The title band's live clock (V15/F2). A full Ink commit per second to advance one row costs a
  // whole frame's reconcile + Yoga layout + rewrite — measured on the real tree: 0.72% → 1.37% of
  // one core, over the <1% red line. So the clock ticks OUTSIDE React: the App registers row 0's
  // segments + palette, this writer paints just the 8-column clock field in place (save cursor →
  // absolute position → colored stamp → restore cursor), and the App renders the same stamp from
  // the shared `clockNow` ref, so Ink's own (rare, signature-gated) repaints never revert it.
  // Coloring goes through the same `chalk.hex` Ink's colorize uses, byte-identical. While the
  // editor owns the terminal not one byte is written (the 2.3 handoff fixture measures that).
  let clockRowState: { row: Segment[]; palette: Palette } | null = null
  const clockNow = { ms: 0 }
  const tickClock = (): void => {
    if (!app || editorActive || !clockRowState) return
    const ms = Date.now()
    const stamp = clockOf(new Date(ms).toISOString())
    if (clockNow.ms > 0 && stamp === clockOf(new Date(clockNow.ms).toISOString())) return
    clockNow.ms = ms
    let col = 1
    let clockSeg: Segment | null = null
    for (const seg of clockRowState.row) {
      if (seg.clock) {
        clockSeg = seg
        break
      }
      col += dispWidth(seg.text)
    }
    if (!clockSeg) return // a degraded frame block keeps its `—`; no clock that would mask it
    writeSync(1, `\x1b7\x1b[1;${col}H${chalk.hex(clockRowState.palette.tones[clockSeg.tone])(stamp)}\x1b8`)
  }

  const api: PanelApi = {
    readDraft,
    writeDraft,
    clearDraft: () => writeDraft(''),
    send,
    flushQueue,
    setStandby,
    editDraft,
    /**
     * `C-v`'s probe (design §8): the bounded runner, the wayland-first order and the temp-file write
     * live in `clipboard.ts`; this only maps the result to the App's three shapes.
     */
    pasteClipboard: async () => {
      const read = await readClipboard(clipRunner)
      if (!read) return { kind: 'none' as const, value: '' }
      if (read.kind === 'text') return { kind: 'text' as const, value: read.text }
      const file = writePasteFile(read.bytes, read.mime)
      if (!file) return { kind: 'none' as const, value: '' }
      return { kind: 'path' as const, value: file }
    },
    refreshNow,
    suspended: () => editorActive,
    clockNowMs: () => clockNow.ms,
    registerClockRow: (row, palette) => {
      clockRowState = row ? { row, palette } : null
    },
    saveSettings: (next: Settings) => {
      mouseEnabled = next.mouse
      writeSettings(confFile, next)
    },
    savePage: (next: PageId) => {
      writePage(pageFile, next)
    },
    setActivity: (on: boolean) => {
      if (activityPinned) return
      opts.activity = on
      refreshNow()
    },
    setDetail: (id: string | null, file?: string | null) => {
      const nextId = id ?? null
      const nextFile = nextId ? file ?? null : null
      if ((opts.detailId ?? null) === nextId && (opts.detailFile ?? null) === nextFile) return
      opts.detailId = nextId
      opts.detailFile = nextFile
      // The detail block is off the tick path: only the view's own open/tab-switch forces a build.
      if (!nextId) return
      // The cached block already serves this file (the open returns the first file without
      // `--file`): record the option and rebuild nothing, so the effect can stay idempotent.
      const cached = cache.snapshot().blocks?.detail
      if (cached?.id === nextId && nextFile && cached.file === nextFile) return
      void cache.refresh({ force: true, only: ['detail'] }).then(adopt)
    },
    collapse,
    setSetting,
    setSeatModel,
    /**
     * The path kind's existence mark (M55): resolved against the project root (`~` honoured), the
     * rule from the command's own note. `not-exec` is only reachable for `exec` — a directory is
     * never a `file`/`exec` target, and a missing path is `missing` whatever the rule says.
     */
    pathMark: (value: string, rule: string) => {
      const raw = String(value ?? '').trim()
      if (raw === '') return 'missing' as const
      const abs = raw.startsWith('~/') ? join(homedir(), raw.slice(2)) : raw.startsWith('/') ? raw : join(root, raw)
      try {
        const st = statSync(abs)
        if (rule === 'dir') return st.isDirectory() ? ('exists' as const) : ('missing' as const)
        if (rule === 'any') return 'exists' as const
        if (!st.isFile()) return 'missing' as const
        if (rule === 'exec' && (st.mode & 0o111) === 0) return 'not-exec' as const
        return 'exists' as const
      } catch {
        return 'missing' as const
      }
    },
    refreshSettingsSoon,
    setSettingsOpen: (open: boolean) => {
      if (Boolean(opts.settingsOpen) === open) return
      opts.settingsOpen = open
      // The settings reader is off the tick path: only the view's own open forces a build.
      if (!open) return
      void cache.refresh({ force: true, only: ['settings'] }).then(adopt)
    },
    setComposeCursor: (position) => {
      composeCursor = position
    },
  }

  /** stdin/stdout are set up by the caller; `resize` is emitted by Node's tty stream. */
  const onResize = (handler: () => void): void => {
    if (typeof process.stdout.on === 'function') process.stdout.on('resize', handler)
  }

  app = render(panelElement(), {
    exitOnCtrlC: false,
    patchConsole: false,
    // M47: Ink 7 treats ANY CI environment (`is-in-ci`) as non-interactive and then silently
    // drops every frame — in that mode only <Static> output is written, so a pulse window on a
    // runner (or in any container that inherits CI) stays blank while the process looks healthy.
    // A tmux pane is a real terminal regardless of CI, and the panel's own contract is TTY-based
    // (`--ui auto`: non-TTY → plain text / `--print`), so pin `interactive` to the TTY fact
    // instead of Ink's CI heuristic. Flip evidence: smoke 26-m's `CI=1` pane case goes red again
    // when this option is removed.
    interactive: Boolean(process.stdout.isTTY),
    // Kitty keyboard support is opt-in: `shift+enter` exists only if the terminal reports it
    // (auto mode never enables the protocol on a terminal that does not answer the query).
    kittyKeyboard: { mode: 'auto' },
    // The cursor-aware stdout re-asserts the compose insertion point after every Ink write
    // (including the throttled ones), which is what makes the placement exact in a full pane.
    stdout: cursorAwareStdout(process.stdout, () => composeCursor),
  })
  if (!once) {
    const clockTimer = setInterval(tickClock, 1000)
    clockTimer.unref?.()
  }

  // A shrinking pane is the one terminal event Ink's relative cursor arithmetic cannot survive on a normal
  // screen: the frame it wrote before the resize is now scrolled out, so the next frame lands off-screen and
  // the pane looks blank (measured: 50x200 → 120x29 left 29 empty rows while the log showed full frames).
  // Reset the screen and Ink's own line bookkeeping, then draw a fresh frame at the top.
  onResize(() => {
    if (editorActive) return
    try {
      writeSync(1, '\x1b[2J\x1b[3J\x1b[H')
      app?.clear()
    } catch {
      /* a terminal that rejects the reset must not kill the panel */
    }
    try {
      app?.rerender(panelElement())
    } catch {
      /* rerender is best effort; the next refresh redraws anyway */
    }
  })

  const restoreTerminal = (): void => {
    if (!mouseEnabled) return
    try {
      writeSync(1, '\u001b[?1000l\u001b[?1006l')
    } catch {
      /* ignore */
    }
  }
  process.on('exit', restoreTerminal)
  process.on('SIGTERM', () => {
    restoreTerminal()
    process.exit(143)
  })
  process.on('SIGHUP', () => {
    restoreTerminal()
    process.exit(129)
  })

  if (once) await runTickIfDue()
  await app.waitUntilExit()
  restoreTerminal()
  cache.dispose()
  process.exit(0)
}


void main()

function sleepSync(ms: number): void {
  // Blocking sleep on the main thread; no child process, no busy loop. Only the plain-text and
  // headless runs (a machine consumer with no input line) use it.
  try {
    Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, ms)
  } catch {
    const end = Date.now() + ms
    while (Date.now() < end) {
      /* fallback if Atomics.wait is unavailable in this runtime */
    }
  }
}
