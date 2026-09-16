// The Ink frame: Ink owns the terminal (raw keys, redraw, cursor, mouse bytes), the layout module
// owns the rows. Rendering pre-computed segments — rather than nested flex boxes — is what makes
// the TUI and `--print` show the same frame, and it keeps the pane capture free of content the
// sanitizer has not seen: every segment is built from sanitized fields by construction.
//
// B3 adds the console surface: three pages (Tab / `1`–`3`, `state/panel-page`), the settings
// overlay (`,`) writing `state/panel.conf`, SGR mouse (every documented key is a click target and
// the wheel scrolls), the zh/en string tables and the density preference. The compose entry (B2)
// works on every page; the receipt and the three actions are unchanged.

import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { writeSync } from 'node:fs'
import { Box, Text, useApp, useInput } from 'ink'
import { layout, rowKey } from './layout.js'
import type { LayoutInput } from './layout.js'
import { stringsFor, type Strings } from './strings/index.js'
import { backspace, inputLines, intake, receiptLine, type ComposeMode, type Receipt } from './compose.js'
import type { Settings } from './settings.js'
import type { Action, FrameInput, PageId, PrefName, Segment, ViewState } from './types.js'
import type { Palette } from './theme.js'

/** The console's own actions, owned by main.tsx (file I/O, subprocesses, the editor relay). */
export interface PanelApi {
  readDraft(): string
  writeDraft(text: string): void
  clearDraft(): void
  send(text: string): Promise<Receipt>
  flushQueue(): Promise<{ ok: boolean; line: string }>
  setStandby(on: boolean, reason: string): Promise<{ ok: boolean; line: string }>
  /** Hand the terminal to `$EDITOR`; resolves with the (possibly edited) draft. */
  editDraft(text: string): Promise<string>
  /** Rebuild the cache now (after an action that changed the state the frame reads). */
  refreshNow(): void
  /** True while an external program owns the terminal (the render callback must not run). */
  suspended(): boolean
  /** Persist one preference (`state/panel.conf`). */
  saveSettings(settings: Settings): void
  /** Remember the current page (`state/panel-page`). */
  savePage(page: PageId): void
  /** Tell the cache whether the activity block is wanted (the overlay's TUI-only override). */
  setActivity(on: boolean): void
  /** Rebuild the patrol window as the headless tick loop (`team pulse collapse`). */
  collapse(): Promise<{ ok: boolean; line: string }>
}

export interface AppProps {
  frame: FrameInput
  /** Redraw period in seconds (`TEAM_MONITOR_REFRESH`). */
  refresh: number
  /** Called once per redraw; returns the fresh frame (and runs a tick when one is due). */
  reload: () => FrameInput
  /** Render one frame and exit. */
  once: boolean
  api: PanelApi
  /** The initial preferences (from `state/panel.conf` in the TUI, defaults elsewhere). */
  settings: Settings
  /** The page restored from `state/panel-page` (or the preference's default). */
  page: PageId
  /** The palette resolved from the `theme` preference + the environment. */
  palette: Palette
  /** True when a CLI flag pins the activity column (the overlay cannot override it). */
  activityPinned: boolean
}

interface Size {
  columns: number
  rows: number
}

/**
 * A cheap content signature: identical data renders an identical frame, so a refresh that changed
 * nothing must not repaint (the red line is <1% of one core; an idle console should cost ~0).
 * Exported because main.tsx's `adopt()` guards its Ink `rerender` with the same rule.
 *
 * The panel's `timestamp` is deliberately excluded: the title band's clock is the live `<Clock>`
 * component, so a new assembly time alone is not a visible change (and repainting the whole frame
 * for it is what pushed the console over the red line).
 */
export function frameSignature(frame: FrameInput): string {
  const { timestamp: _stamp, ...panel } = frame.panel ?? {}
  return JSON.stringify([panel, frame.degraded ?? [], frame.activityBlocks ?? [], frame.blocks ?? {}, frame.activity])
}

function liveSize(fallback: FrameInput): Size {
  return {
    columns: process.stdout.columns || fallback.width,
    rows: process.stdout.rows || fallback.height,
  }
}

const MOUSE_ON = '\u001b[?1000h\u001b[?1006h'
const MOUSE_OFF = '\u001b[?1000l\u001b[?1006l'
const SGR_MOUSE = /^(?:\u001b)?\[<(\d+);(\d+);(\d+)([Mm])$/

const PREFS: PrefName[] = ['lang', 'defaultPage', 'activity', 'mouse', 'density']

/**
 * One frame row. Memoized: a repaint that only changed the clock (or one block) must not re-render
 * the other rows — React skips a memoized subtree whose props are referentially equal, and the
 * caller below reuses the previous row object whenever its content key is unchanged.
 */
const Row = React.memo(function Row({ row, palette }: { row: Segment[]; palette: Palette }) {
  return (
    <Text wrap="truncate">
      {row.length
        ? row.map((segment, j) => (
            <Text key={j} color={palette.tones[segment.tone]}>
              {segment.text}
            </Text>
          ))
        : ' '}
    </Text>
  )
})

/** Reuse the previous row objects whose content did not change, so `Row` can skip them. */
function stableRows(prev: { key: string; row: Segment[] }[], rows: Segment[][]): { key: string; row: Segment[] }[] {
  return rows.map((row, i) => {
    const key = rowKey(row)
    const before = prev[i]
    if (before && before.key === key) return before
    return { key, row }
  })
}

export function App({
  frame,
  refresh,
  reload,
  once,
  api,
  settings: settingsProp,
  page: pageProp,
  palette,
  activityPinned,
}: AppProps) {
  const [data, setData] = useState<FrameInput>(frame)
  const [size, setSize] = useState<Size>(() => liveSize(frame))
  const [scroll, setScroll] = useState(0)
  const [composing, setComposing] = useState(false)
  const [mode, setMode] = useState<ComposeMode>('message')
  const [draft, setDraft] = useState('')
  const [receipt, setReceipt] = useState<Receipt | null>(null)
  const [status, setStatus] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)
  const [editorOpen, setEditorOpen] = useState(false)
  const [settings, setSettings] = useState<Settings>(settingsProp)
  const [page, setPage] = useState<PageId>(pageProp)
  const [overlay, setOverlay] = useState(false)
  const [overlayIndex, setOverlayIndex] = useState(0)
  const [viewEntry, setViewEntry] = useState<number | null>(null)
  const { exit } = useApp()
  const scrollRef = useRef(0)
  const dataRef = useRef(frame)
  const draftRef = useRef('')
  const pasteOpenRef = useRef(false)
  const settingsRef = useRef(settings)
  const pageRef = useRef(page)
  const targetsRef = useRef<{ row: number; hit: { start: number; end: number; action: Action } }[]>([])
  const overlayIndexRef = useRef(0)

  const strings: Strings = stringsFor(settings.lang)
  const stringsRef = useRef(strings)
  stringsRef.current = strings
  overlayIndexRef.current = overlayIndex

  useEffect(() => {
    dataRef.current = frame
    setData(frame)
  }, [frame])

  const saveSettings = useCallback(
    (next: Settings) => {
      settingsRef.current = next
      setSettings(next)
      api.saveSettings(next)
    },
    [api],
  )

  const goPage = useCallback(
    (next: PageId) => {
      pageRef.current = next
      setPage(next)
      setViewEntry(null)
      api.savePage(next)
    },
    [api],
  )

  /** The scroll offset lives in a ref as well as in state: the periodic refresh re-renders from
   * `scrollRef.current`, so a wheel that only updated state would be reset by the next cadence. */
  const updateScroll = useCallback((fn: (v: number) => number) => {
    const next = Math.max(0, fn(scrollRef.current))
    scrollRef.current = next
    setScroll(next)
  }, [])

  const updateDraft = useCallback(
    (next: string, persist = true) => {
      draftRef.current = next
      setDraft(next)
      if (persist) api.writeDraft(next)
    },
    [api],
  )

  const openCompose = useCallback(
    (withMode: ComposeMode = 'message') => {
      setReceipt(null)
      setStatus(null)
      setMode(withMode)
      const seed = withMode === 'message' ? api.readDraft() : ''
      draftRef.current = seed
      pasteOpenRef.current = false
      setDraft(seed)
      setComposing(true)
    },
    [api],
  )

  const closeCompose = useCallback(() => {
    // Esc keeps the draft: the ref stays as typed and the file already holds it.
    setComposing(false)
    pasteOpenRef.current = false
  }, [])

  const submit = useCallback(async () => {
    const text = draftRef.current
    if (mode === 'reason') {
      if (!text.trim()) return
      setBusy(true)
      try {
        const r = await api.setStandby(true, text)
        setStatus(r.line)
        setComposing(false)
        updateDraft('', false)
      } finally {
        setBusy(false)
      }
      return
    }
    if (!text.trim()) return
    setBusy(true)
    try {
      const r = await api.send(text)
      setReceipt(r.state === 'error' ? r : { ...r, detail: '' })
      setStatus(null)
      if (r.state !== 'error') {
        updateDraft('', false)
        api.clearDraft()
      }
      setComposing(false)
    } finally {
      setBusy(false)
    }
  }, [api, mode, updateDraft])

  const runAction = useCallback(
    async (kind: 'flush' | 'standby') => {
      if (kind === 'standby') {
        const on = Boolean(dataRef.current.panel?.standby?.on)
        if (!on) {
          openCompose('reason')
          return
        }
        setBusy(true)
        try {
          const r = await api.setStandby(false, '')
          setStatus(r.line)
          setReceipt(null)
        } finally {
          setBusy(false)
        }
        return
      }
      setBusy(true)
      try {
        const r = await api.flushQueue()
        setStatus(r.line)
        setReceipt(null)
      } finally {
        setBusy(false)
      }
    },
    [api, openCompose],
  )

  const collapse = useCallback(async () => {
    setStatus(null)
    const r = await api.collapse()
    if (!r.ok) setStatus(r.line)
  }, [api])

  const relayEditor = useCallback(async () => {
    // The editor relay writes `state/draft.md`; in reason mode that would clobber the message
    // draft, and a long reason is not the flow the design asks for — C-e belongs to the letter.
    if (busy || composing === false || mode !== 'message') return
    setBusy(true)
    // Ink's own input must be deactivated for the handoff: both Ink and `$EDITOR` read the same
    // pty, and whoever reads a keystroke first consumes it (measured: `:wq` never reached vi
    // while Ink's `useInput` stayed active).
    setEditorOpen(true)
    try {
      const next = await api.editDraft(draftRef.current)
      updateDraft(next, mode === 'message')
    } finally {
      setEditorOpen(false)
      setBusy(false)
    }
  }, [api, busy, composing, mode, updateDraft])

  const cyclePref = useCallback(
    (pref: PrefName) => {
      const cur = settingsRef.current
      const next: Settings = { ...cur }
      switch (pref) {
        case 'lang':
          next.lang = cur.lang === 'zh' ? 'en' : 'zh'
          break
        case 'defaultPage':
          next.defaultPage = cur.defaultPage === 3 ? 1 : ((cur.defaultPage + 1) as PageId)
          goPage(next.defaultPage)
          break
        case 'activity':
          next.activity = !cur.activity
          if (!activityPinned) api.setActivity(next.activity)
          break
        case 'mouse':
          next.mouse = !cur.mouse
          break
        case 'density':
          next.density = cur.density === 'compact' ? 'comfortable' : 'compact'
          break
      }
      saveSettings(next)
    },
    [activityPinned, api, goPage, saveSettings],
  )

  const dispatch = useCallback(
    (action: Action) => {
      switch (action.kind) {
        case 'compose':
          openCompose('message')
          return
        case 'flush':
          void runAction('flush')
          return
        case 'standby':
          void runAction('standby')
          return
        case 'settings':
          setOverlay(true)
          setOverlayIndex(0)
          return
        case 'page':
          goPage(action.page)
          return
        case 'page-cycle':
          goPage(pageRef.current === 3 ? 1 : ((pageRef.current + 1) as PageId))
          return
        case 'scroll':
          updateScroll((v) => v + action.delta)
          return
        case 'quit':
          void collapse()
          return
        case 'close-overlay':
          setOverlay(false)
          return
        case 'toggle':
          cyclePref(action.pref as PrefName)
          return
        case 'view-entry':
          setViewEntry(action.index)
          return
        case 'queue-list':
          setViewEntry(null)
          return
      }
    },
    [collapse, cyclePref, goPage, openCompose, runAction, updateScroll],
  )

  const effectiveActivity = activityPinned ? data.activity : settings.activity

  const rowCacheRef = useRef<{ key: string; row: Segment[] }[]>([])

  const lines = useMemo(() => {
    const bottom: string[] = []
    if (!composing) {
      const notice = receipt ? receiptLine(receipt, strings) : status
      if (notice) bottom.push(notice)
    }
    const input = composing ? inputLines(mode, draft, size.columns) : []
    const hint = composing ? [mode === 'message' ? strings.composeHint : strings.composeReasonHint] : []
    const frameRows = size.rows > 0 ? Math.max(3, size.rows - input.length - hint.length - bottom.length) : data.height
    const view: ViewState = {
      page,
      density: settings.density,
      lang: settings.lang,
      mouseOn: settings.mouse,
      tui: true,
      overlay,
      overlayIndex,
      viewEntry,
      scroll,
    }
    // The geometry comes from the live terminal, not from the frame's snapshot of it: a resize must
    // re-lay out the next frame (the spec's "A resize re-lays out live"), and `data.width` is frozen
    // at process start.
    const themed = layout({
      ...data,
      width: Math.max(1, size.columns || data.width),
      activity: effectiveActivity,
      strings,
      height: frameRows,
      view,
    } as LayoutInput)
    const pad = size.rows > 0 ? Math.max(0, size.rows - input.length - hint.length - bottom.length - themed.rows.length) : 0
    targetsRef.current = themed.targets
    return { frame: themed, input, hint, bottom, pad }
  }, [
    data,
    strings,
    page,
    settings.density,
    settings.lang,
    settings.mouse,
    overlay,
    overlayIndex,
    viewEntry,
    scroll,
    size,
    composing,
    mode,
    draft,
    receipt,
    status,
    effectiveActivity,
  ])

  const refreshData = useCallback(
    (nextScroll = scrollRef.current) => {
      const fresh = reload()
      // A refresh that produced the same frame must not repaint: with the block TTLs, most cadences
      // change nothing at all, and an idle console should cost ~0% (the red line is <1% of one core).
      const same = frameSignature(dataRef.current) === frameSignature(fresh)
      dataRef.current = fresh
      scrollRef.current = nextScroll
      if (!same) setData(fresh)
      setScroll(nextScroll)
    },
    [reload],
  )

  useEffect(() => {
    if (once) {
      // One frame and out: Ink needs a tick to flush the frame before unmounting.
      const t = setTimeout(() => exit(), 30)
      return () => clearTimeout(t)
    }
    const id = setInterval(() => {
      // The render callback is explicitly gated while an external program owns the terminal.
      if (api.suspended()) return
      refreshData(scrollRef.current)
    }, Math.max(1, refresh) * 1000)
    return () => clearInterval(id)
  }, [once, refresh, refreshData, exit, api])

  // A shrinking pane must never keep the padding of the old height (Ink would write the taller box
  // and tmux would scroll the frame out of the visible rows — measured). Re-read the geometry and
  // let the layout rebuild from the latest data.
  useEffect(() => {
    const onResize = () => {
      if (api.suspended()) return
      setSize(liveSize(dataRef.current))
    }
    if (typeof process.stdout.on !== 'function') return undefined
    process.stdout.on('resize', onResize)
    return () => {
      process.stdout.off('resize', onResize)
    }
  }, [api])

  // SGR mouse reporting follows the preference: on enables for the console's lifetime, off emits
  // no sequence at all (the spec's "Off means silent"), and unmounting always disables it.
  useEffect(() => {
    if (!process.stdout.isTTY) return undefined
    if (settings.mouse) writeSync(1, MOUSE_ON)
    return () => {
      if (settings.mouse) writeSync(1, MOUSE_OFF)
    }
  }, [settings.mouse])

  useInput(
    (input, key) => {
      // The mouse's SGR sequences arrive as one input event (Ink strips the leading ESC — E6 §1.1c).
      const mouse = SGR_MOUSE.exec(input)
      if (mouse) {
        if (!settingsRef.current.mouse) return
        const button = Number(mouse[1])
        const x = Number(mouse[2])
        const y = Number(mouse[3])
        if (button === 64 || button === 65) {
          // The wheel scrolls the page's list: down reveals later rows, up goes back.
          updateScroll((v) => v + (button === 65 ? 1 : -1))
          return
        }
        if (mouse[4] !== 'M' || (button & 3) !== 0) return
        const row = y - 1
        const col = x - 1
        const hit = targetsRef.current.find((t) => t.row === row && col >= t.hit.start && col < t.hit.end)
        if (hit) dispatch(hit.hit.action)
        return
      }

      if (overlay) {
        if (key.escape || input === ',') {
          setOverlay(false)
          return
        }
        if (key.upArrow) {
          setOverlayIndex((i) => (i + PREFS.length - 1) % PREFS.length)
          return
        }
        if (key.downArrow) {
          setOverlayIndex((i) => (i + 1) % PREFS.length)
          return
        }
        if (key.return || input === ' ') {
          cyclePref(PREFS[overlayIndexRef.current] ?? 'lang')
          return
        }
        return
      }

      if (composing) {
        if (key.ctrl && input === 'e') {
          void relayEditor()
          return
        }
        if (key.escape) {
          closeCompose()
          return
        }
        if (key.return) {
          void submit()
          return
        }
        if (key.backspace || key.delete) {
          updateDraft(backspace(draftRef.current))
          return
        }
        if (busy) return
        // The paste markers and their body can arrive with a leading ESC already consumed by Ink;
        // `intake` accepts both spellings and keeps an unclosed bracket open across reads.
        const next = intake(input, pasteOpenRef.current)
        pasteOpenRef.current = next.pasteOpen
        // The compose draft is persisted (`state/draft.md`); the standby reason is not a message
        // draft and must never overwrite one.
        if (next.append) updateDraft(draftRef.current + next.append, mode === 'message')
        if (next.submit) void submit()
        return
      }

      if (viewEntry != null && key.escape) {
        setViewEntry(null)
        return
      }
      if (input === 'q' || (key.ctrl && input === 'c')) {
        void collapse()
        return
      }
      if (busy) return
      if (key.tab) {
        goPage(pageRef.current === 3 ? 1 : ((pageRef.current + 1) as PageId))
        return
      }
      if (input === '1' || input === '2' || input === '3') {
        goPage(Number(input) as PageId)
        return
      }
      if (input === ',') {
        setOverlay(true)
        setOverlayIndex(0)
        return
      }
      if (input === 'm') {
        openCompose('message')
        return
      }
      if (input === 'f') {
        void runAction('flush')
        return
      }
      if (input === 's') {
        void runAction('standby')
        return
      }
      if (input === 'r') {
        // `r` is the human asking for it: rebuild every block now, not "when its TTL is up".
        setReceipt(null)
        setStatus(null)
        api.refreshNow()
        return
      }
      if (key.upArrow || key.downArrow) {
        updateScroll((v) => (key.upArrow ? v - 1 : v + 1))
        return
      }
      if (key.return && viewEntry == null && page === 3) {
        // Enter on the messages page opens the first queued entry's full text.
        const entries = dataRef.current.blocks?.outbox_list?.entries ?? []
        if (entries.length) setViewEntry(0)
      }
    },
    { isActive: !editorOpen && Boolean(process.stdin.isTTY) },
  )

  const renderRows = stableRows(rowCacheRef.current, lines.frame.rows)
  rowCacheRef.current = renderRows

  return (
    <Box flexDirection="column" width={size.columns}>
      {renderRows.map(({ row }, i) => (
        <Row key={`f${i}`} row={row} palette={palette} />
      ))}
      {Array.from({ length: lines.pad }, (_, i) => (
        <Text key={`p${i}`}> </Text>
      ))}
      {lines.input.map((line, i) => (
        <Text key={`i${i}`} color={i === lines.input.length - 1 ? palette.tones.accent : palette.tones.text}>
          {line || ' '}
        </Text>
      ))}
      {lines.hint.map((line, i) => (
        <Text key={`h${i}`} color={palette.tones.dim}>
          {line}
        </Text>
      ))}
      {lines.bottom.map((line, i) => (
        <Text key={`b${i}`} color={palette.tones.accent}>
          {line}
        </Text>
      ))}
      {busy ? <Text color={palette.tones.warn}>{mode === 'message' ? strings.busySend : strings.busyAction}</Text> : null}
    </Box>
  )
}
