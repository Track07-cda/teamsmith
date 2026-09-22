// The Ink frame: Ink owns the terminal (raw keys, redraw, cursor, mouse bytes), the layout module
// owns the rows. Rendering pre-computed segments — rather than nested flex boxes — is what makes
// the TUI and `--print` show the same frame, and it keeps the pane capture free of content the
// sanitizer has not seen: every segment is built from sanitized fields by construction.
//
// B3 adds the console surface: four pages (Tab / `1`–`4`, `state/panel-page`), the settings
// overlay (`,`) writing `state/panel.conf`, SGR mouse (every documented key is a click target and
// the wheel scrolls), the zh/en string tables and the density preference. `console-board-page` adds
// the board page's kanban and the read-only markdown detail view. The compose entry (B2) works on
// every page; the receipt and the three actions are unchanged.

import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { writeSync } from 'node:fs'
import { Box, Text, useApp, useCursor, useInput } from 'ink'
import { layout, resolveFocus, focusRefOf, focusRow, rowKey, settingsViewRows } from './layout.js'
import type { LayoutInput } from './layout.js'
import { clockOf } from './format.js'
import { fill, stringsFor, type Strings } from './strings/index.js'
import { composeKey, cpLength, cursorView, insertAt, intake, killSpan, moveCursor, popUndo, pushKill, pushUndo, receiptLine, resetKillDirection, ringEntry, type ComposeMode, type ComposeView, type KillRing, type Receipt, type UndoSnapshot } from './compose.js'
import type { Settings } from './settings.js'
import type { Action, DetailWindow, FocusRef, FrameInput, PageId, PrefName, Segment, SettingsChoiceEntry, SettingsChoicePicker, SettingsKey, ViewState } from './types.js'
import type { Palette } from './theme.js'
import { dispWidth } from './width.js'

const TRAY_TL = '╭'
const TRAY_TR = '╮'
const TRAY_H = '─'
const TRAY_V = '│'

/**
 * The kinds whose editor is the choice picker (M55). `enum` joins only when the command reports
 * values (an enum with no constraints has no choice set: R3's visible fallback names the reason),
 * and a key the command reports without a `choices` object falls back to the compose editor — the
 * bundle works against an older command instead of inventing options.
 */
const CHOICE_KINDS = new Set(['bool', 'enum', 'int', 'seconds', 'mb', 'bytes', 'pct', 'path', 'model', 'pairlist', 'winlist', 'pattern'])
const NUMERIC_KINDS = new Set(['int', 'seconds', 'mb', 'bytes', 'pct'])

function hasChoiceEditor(key: SettingsKey): boolean {
  const ch = key.choices
  if (!ch || typeof ch !== 'object' || !Array.isArray(ch.values)) return false
  const kind = String(key.kind ?? '')
  if (!CHOICE_KINDS.has(kind)) return false
  if (kind === 'enum') return ch.values.length > 0
  return true
}

/** Open-bottom compose tray (top edge + left wall). The last text row stays last so the IME cursor stays on the draft. */
function composeTrayTop(title: string, width: number): string {
  const w = Math.max(2, Math.floor(width) || 2)
  const inner = w - 2
  if (!title) return TRAY_TL + TRAY_H.repeat(inner) + TRAY_TR
  const titleW = dispWidth(title)
  if (1 + 1 + titleW + 1 > inner) return TRAY_TL + TRAY_H + title + TRAY_TR
  const fill = inner - (1 + 1 + titleW + 1)
  return `${TRAY_TL}${TRAY_H} ${title} ${TRAY_H.repeat(Math.max(0, fill))}${TRAY_TR}`
}

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
  /**
   * The `C-v` clipboard probe (P20/B4): `path` = a temporary image file to insert, `text` = the
   * clipboard's text, `none` = nothing to paste. Never called from the render/refresh path.
   */
  pasteClipboard(): Promise<{ kind: 'path' | 'text' | 'none'; value: string }>
  /** Rebuild the cache now (after an action that changed the state the frame reads). */
  refreshNow(): void
  /** True while an external program owns the terminal (the render callback must not run). */
  suspended(): boolean
  /** The shared clock ref (0 = no tick yet): row 0 renders this stamp so repaints never revert it. */
  clockNowMs(): number
  /** Register the title band's base row + palette for the out-of-React clock writer (null = off). */
  registerClockRow(row: Segment[] | null, palette: Palette): void
  /**
   * Register the compose insertion point (Ink-output coordinates) for the cursor-aware stdout,
   * which re-asserts it absolutely after every Ink write; null = not composing (cursor hidden).
   */
  setComposeCursor(position: { x: number; y: number } | null): void
  /** Persist one preference (`state/panel.conf`). */
  saveSettings(settings: Settings): void
  /** Remember the current page (`state/panel-page`). */
  savePage(page: PageId): void
  /** Tell the cache whether the activity block is wanted (the overlay's TUI-only override). */
  setActivity(on: boolean): void
  /**
   * Tell the cache which entry's detail view is open (null = closed). While an id is set the
   * `detail` block joins the wanted set; `file` selects the repo-relative path to serve (the first
   * discovered file when omitted). Both are cached options, so an unchanged call rebuilds nothing.
   */
  setDetail(id: string | null, file?: string | null): void
  /** Rebuild the patrol window as the headless tick loop (`team pulse collapse`). */
  collapse(): Promise<{ ok: boolean; line: string }>
  /** Represents one `team config set` result: the exit code (the machine contract) + one line. */
  setSetting(
    key: string,
    value: string,
    opts: { dryRun?: boolean; fingerprint?: string | null; allowDanger?: boolean },
  ): Promise<{ code: number; line: string }>
  /**
   * Re-read the settings block in the background after a write settled (M65/D11). The receipt is
   * drawn from the command's own settle and never waits for this read; it only refreshes what the
   * next interaction sees. Never awaited on the interaction path.
   */
  refreshSettingsSoon(): void
  /** One `team config set-agent-model <seat> <model|->` invocation (P22/B4). */
  setSeatModel(
    seat: string,
    model: string,
    opts: { dryRun?: boolean; fingerprint?: string | null },
  ): Promise<{ code: number; line: string }>
  /**
   * The path kind's existence mark (M55): the value against the rule the command's own `note`
   * carries (`file`/`dir`/`exec`/`any`). A pure read — the command has no existence check, so the
   * mark is an advisory the confirmation repeats, never a refusal.
   */
  pathMark(value: string, rule: string): 'exists' | 'missing' | 'not-exec'
  /**
   * Tell the cache whether the project-settings view is open (P22/B2). While it is, the `settings`
   * block joins the wanted set; closing it drops the block so a parked console spawns no reader.
   */
  setSettingsOpen(open: boolean): void
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
 * The panel's `timestamp` is deliberately excluded: the title band's clock is driven by the App's
 * own 1s ticker (it repaints just that row), so a new assembly time alone is not a visible change
 * (and repainting the whole frame for it is what pushed the console over the red line).
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

/**
 * Patch the title band's clock segment (the segment `titleBlock` marked `clock`) with the shared
 * ticker's UTC time. Called at render time with the ref's ms — App renders are data-gated, so a
 * repaint picks up the latest stamp and never reverts the screen. A degraded frame block has no
 * clock segment and keeps its `—` instead of a clock that would mask the failure.
 */
function clockRow(row: Segment[], now: number): Segment[] {
  if (now <= 0) return row
  const seg = row.find((s) => s.clock)
  if (!seg) return row
  const stamp = clockOf(new Date(now).toISOString())
  if (seg.text === stamp) return row
  return row.map((s) => (s.clock ? { ...s, text: stamp } : s))
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
  // The insertion point, as a codepoint index into the draft (P20/B1). It lives in a ref beside the
  // state because the input handler edits the draft synchronously (two keys in one React batch must
  // see each other's result, the same reason `draftRef` exists).
  const [cursor, setCursor] = useState(0)
  const [receipt, setReceipt] = useState<Receipt | null>(null)
  const [status, setStatus] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)
  const [editorOpen, setEditorOpen] = useState(false)
  const [settings, setSettings] = useState<Settings>(settingsProp)
  const [page, setPage] = useState<PageId>(pageProp)
  const [overlay, setOverlay] = useState(false)
  const [overlayIndex, setOverlayIndex] = useState(0)
  const [viewEntry, setViewEntry] = useState<number | null>(null)
  const [focus, setFocus] = useState<FocusRef | null>(null)
  const [laneOffset, setLaneOffset] = useState<Record<string, number>>({})
  // The open detail view's entry id (the board page's Enter / a click on the focused card), its
  // tab and its document scroll. The view is read-only: no key of its own beyond navigation.
  const [detailId, setDetailId] = useState<string | null>(null)
  const [detailIndex, setDetailIndex] = useState(0)
  const [detailScroll, setDetailScroll] = useState(0)
  // P22/B2: the project-settings view (opened from the overlay's navigation row), its window and
  // its filter. The view is a view, not a page: the four-page composition and `state/panel-page`
  // keep their meaning, and `esc` lands back on the overlay row it was opened from.
  const [settingsView, setSettingsView] = useState(false)
  const [settingsOrigin, setSettingsOrigin] = useState(0)
  const [settingsFocus, setSettingsFocus] = useState(0)
  const [settingsFilter, setSettingsFilter] = useState('')
  /** The pending two-step write confirmation ({danger} = the command answered 7). */
  const [settingConfirm, setSettingConfirm] = useState<{ key: string; next: string; danger: boolean } | null>(null)
  /** The seat picker (P22/B4): the seat, its row and the option list with the selection. */
  const [seatPicker, setSeatPicker] = useState<{ agent: string; row: number; models: string[]; index: number } | null>(null)
  /** The choice picker (M55): the key's schema-derived entries and the selection. */
  const [choicePicker, setChoicePicker] = useState<SettingsChoicePicker | null>(null)
  const { exit } = useApp()
  const scrollRef = useRef(0)
  const dataRef = useRef(frame)
  const draftRef = useRef('')
  const cursorRef = useRef(0)
  // pi's recoverable deletions (P20/B2): the ring, the bounded undo history and the one-step
  // yank-pop state. They are refs, not state, because two keys inside one React batch must see
  // each other's result (the same reason `draftRef` exists).
  const killRingRef = useRef<KillRing>({ entries: [], lastDirection: null })
  const undoRef = useRef<UndoSnapshot[]>([])
  /** How many `alt+y` pops followed the last yank, and how long the text it inserted is. */
  const yankRef = useRef<{ pops: number; length: number } | null>(null)
  /** pi's `lastAction`: `alt+y` only pops right after a yank. */
  const lastActionRef = useRef<'yank' | 'edit' | null>(null)
  /** One clipboard probe at a time: a second `C-v` while one is in flight is a no-op. */
  const probingRef = useRef(false)
  const pasteOpenRef = useRef(false)
  const settingsRef = useRef(settings)
  const pageRef = useRef(page)
  const targetsRef = useRef<{ row: number; hit: { start: number; end: number; action: Action } }[]>([])
  const overlayIndexRef = useRef(0)
  const focusRef = useRef<FocusRef | null>(null)
  const laneOffsetRef = useRef<Record<string, number>>({})
  const lanesRef = useRef<{ lane: string; offset: number; visible: number; count: number }[]>([])
  /** The work page's board rows in the order the last frame drew them (P20/B5). */
  const boardOrderRef = useRef<FocusRef[]>([])
  const detailRef = useRef<DetailWindow | null>(null)
  const detailIdRef = useRef<string | null>(null)
  const detailIndexRef = useRef(0)
  const detailScrollRef = useRef(0)
  const settingsViewRef = useRef(false)
  const settingsFocusRef = useRef(0)
  const settingsFilterRef = useRef('')
  /** The row the open `setting` editor writes (the fingerprint was pinned when it opened). */
  const settingRowRef = useRef<{ row: number; key: string; value: string; cls: string; fingerprint: string; seat?: string; kind?: string; choices?: SettingsKey['choices'] } | null>(null)
  const seatPickerRef = useRef<{ agent: string; row: number; models: string[]; index: number } | null>(null)
  seatPickerRef.current = seatPicker
  const choicePickerRef = useRef<SettingsChoicePicker | null>(null)
  choicePickerRef.current = choicePicker
  const settingConfirmRef = useRef<{ key: string; next: string; danger: boolean } | null>(null)
  /**
   * The value the picker's first accept found dangerous (the command's exit 7): one more accept of
   * that same value writes it with the command's danger allowance, and any other selection clears
   * it so a new value is validated first (M65/D10).
   */
  const choiceDangerRef = useRef<{ key: string; value: string } | null>(null)
  focusRef.current = focus
  laneOffsetRef.current = laneOffset
  detailIdRef.current = detailId
  detailIndexRef.current = detailIndex
  detailScrollRef.current = detailScroll
  settingsViewRef.current = settingsView
  settingsFocusRef.current = settingsFocus
  settingsFilterRef.current = settingsFilter

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
      setDetailId(null)
      setDetailIndex(0)
      setDetailScroll(0)
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

  /** Move the insertion point (clamped by the model's callers, never past the draft's ends). */
  const setPoint = useCallback((next: number) => {
    cursorRef.current = next
    setCursor(next)
  }, [])

  /** One draft edit at the insertion point: text, point and `state/draft.md` move together. */
  const updateCompose = useCallback(
    (next: { text: string; cursor: number }, persist = true) => {
      draftRef.current = next.text
      cursorRef.current = next.cursor
      setDraft(next.text)
      setCursor(next.cursor)
      if (persist) api.writeDraft(next.text)
    },
    [api],
  )

  /**
   * The width one drawn draft row has: the boxed (comfortable) tray eats two columns, the compact
   * style draws the raw rows. This must be the same expression `lines` uses to build the rows, so
   * the cursor's visual-row moves and the drawn wrapping can never disagree.
   */
  const composeWidth = useCallback(
    () => (composing && settings.density === 'comfortable' ? Math.max(1, size.columns - 2) : size.columns),
    [composing, settings.density, size.columns],
  )

  /** The window's draft capacity: at most half the pane, and never so many rows that the input
   * area would push the rendered frame past the pane (an overflow scrolls, which would move the
   * frame's top row away from the coordinate the cursor is placed in). */
  const composeMaxRows = useCallback(() => {
    if (size.rows <= 0) return Number.MAX_SAFE_INTEGER
    const boxed = composing && settings.density === 'comfortable'
    const avail = size.rows - 3 - 1 - (boxed ? 1 : 0) - (busy ? 1 : 0)
    return Math.max(1, Math.min(Math.floor(size.rows / 2), avail))
  }, [busy, composing, settings.density, size.rows])

  const openCompose = useCallback(
    (withMode: ComposeMode = 'message', initial?: string) => {
      setReceipt(null)
      setStatus(null)
      setMode(withMode)
      const seed =
        initial !== undefined
          ? initial
          : withMode === 'message'
            ? api.readDraft()
            : withMode === 'filter'
              ? settingsFilterRef.current
              : ''
      draftRef.current = seed
      pasteOpenRef.current = false
      setDraft(seed)
      // The insertion point opens at the end of the restored draft (the cursor is not persisted).
      cursorRef.current = cpLength(seed)
      setCursor(cpLength(seed))
      // The undo history and the ring start empty at the draft the compose opened on.
      killRingRef.current = { entries: [], lastDirection: null }
      undoRef.current = []
      yankRef.current = null
      lastActionRef.current = null
      setComposing(true)
    },
    [api],
  )

  const closeCompose = useCallback(() => {
    // Esc keeps the draft: the ref stays as typed and the file already holds it.
    setComposing(false)
    pasteOpenRef.current = false
    // A cancelled setting edit writes nothing and leaves no audit line (the two-step rule).
    settingRowRef.current = null
    settingConfirmRef.current = null
    setSettingConfirm(null)
  }, [])

  /**
   * The path kind's existence mark for the value about to be written (M55): an advisory the
   * confirmation repeats. The command has no existence check, so the console never turns this into
   * a refusal — it does not invent a rule the writer would not make.
   */
  const pathMarkNote = useCallback(
    (target: { kind?: string; choices?: SettingsKey['choices'] }, value: string): string => {
      if (String(target.kind ?? '') !== 'path') return ''
      const mark = api.pathMark(value, String(target.choices?.note ?? ''))
      const word =
        mark === 'exists'
          ? stringsRef.current.settingsPathExists
          : mark === 'not-exec'
            ? stringsRef.current.settingsPathNotExec
            : stringsRef.current.settingsPathMissing
      return ` · ${word}`
    },
    [api],
  )

  // V15/F3: one draft = at most one message. The re-entry guard is a ref set *synchronously* at
  // the top of the send, not the `busy` state: a double Enter lands inside the same React batch,
  // before any state update could gate the second call. A failed send releases the guard so the
  // human can retry (the draft is kept on error).
  const sendingRef = useRef(false)
  const submit = useCallback(async () => {
    const text = draftRef.current
    if (mode === 'filter') {
      // The filter is one of the compose editor's modes (P22/B2): Enter applies it and closes the
      // line, Esc clears it (handled with the compose cancel below).
      settingsFilterRef.current = text
      setSettingsFilter(text)
      setSettingsFocus(0)
      closeCompose()
      return
    }
    if (mode === 'setting') {
      // The write is always the owning command's: the first Enter asks for a `--dry-run`
      // validation, the second performs the write with the fingerprint pinned when the editor
      // opened. The console never opens the contract itself.
      const target = settingRowRef.current
      if (!target) {
        closeCompose()
        return
      }
      if (sendingRef.current) return
      sendingRef.current = true
      setBusy(true)
      try {
        const conf = settingConfirmRef.current
        const timing =
          target.cls === 'restart' ? stringsRef.current.settingTimingRestart : stringsRef.current.settingTimingApply
        const isSeat = Boolean(target.seat)
        const seatModel = text.trim() === '' ? '-' : text.trim()
        const call = (dryRun: boolean, allowDanger: boolean): Promise<{ code: number; line: string }> =>
          isSeat
            ? api.setSeatModel(target.seat as string, seatModel, { dryRun, fingerprint: target.fingerprint })
            : api.setSetting(target.key, text, { dryRun, fingerprint: target.fingerprint, allowDanger })
        if (!conf) {
          const r = await call(true, false)
          if (r.code === 0) {
            settingConfirmRef.current = { key: target.key, next: text, danger: false }
            setSettingConfirm(settingConfirmRef.current)
            setReceipt(null)
            setStatus(
              isSeat
                ? fill(stringsRef.current.settingSeatConfirm, {
                    seat: target.seat as string,
                    old: target.value || stringsRef.current.dash,
                    next: seatModel === '-' ? stringsRef.current.dash : seatModel,
                  })
                : fill(stringsRef.current.settingConfirm, {
                    key: target.key,
                    old: target.value || stringsRef.current.dash,
                    next: text,
                    timing,
                  }) + pathMarkNote(target, text),
            )
          } else if (r.code === 7) {
            settingConfirmRef.current = { key: target.key, next: text, danger: true }
            setSettingConfirm(settingConfirmRef.current)
            setReceipt(null)
            setStatus(fill(stringsRef.current.settingDanger, { reason: r.line }))
          } else if (r.code === 3) {
            // The file changed under the editor: name it now, and let the second Enter perform the
            // real write so the command audits the conflict (a --dry-run writes no audit line).
            settingConfirmRef.current = { key: target.key, next: text, danger: false }
            setSettingConfirm(settingConfirmRef.current)
            setReceipt(null)
            setStatus(stringsRef.current.settingConflict)
          } else {
            setReceipt(null)
            setStatus(
              fill(r.code === 5 ? stringsRef.current.settingRefused : stringsRef.current.settingInvalid, { line: r.line }),
            )
          }
          return
        }
        const r = await call(false, conf.danger)
        if (r.code === 0) {
          setReceipt(null)
          const fallback = dataRef.current.blocks?.settings?.models?.default ?? ''
          setStatus(
            isSeat
              ? seatModel === '-'
                ? fill(stringsRef.current.settingSeatRemoved, { seat: target.seat as string, value: fallback || stringsRef.current.dash })
                : fill(stringsRef.current.settingSeatWritten, { seat: target.seat as string, value: seatModel })
              : fill(stringsRef.current.settingWritten, { key: target.key, value: text, timing }),
          )
          settingRowRef.current = null
          settingConfirmRef.current = null
          setSettingConfirm(null)
          closeCompose()
          api.refreshSettingsSoon()
        } else if (r.code === 3) {
          // The other writer's bytes survived; reload so the view shows their value (the settle).
          setReceipt(null)
          setStatus(stringsRef.current.settingConflict)
          settingConfirmRef.current = null
          setSettingConfirm(null)
          api.refreshSettingsSoon()
        } else {
          setReceipt(null)
          setStatus(
            fill(
              r.code === 5
                ? stringsRef.current.settingRefused
                : r.code === 4
                  ? stringsRef.current.settingInvalid
                  : stringsRef.current.settingWriteError,
              { line: r.line },
            ),
          )
        }
      } finally {
        sendingRef.current = false
        setBusy(false)
      }
      void text
      return
    }
    if (mode === 'reason') {
      if (!text.trim()) return
      if (sendingRef.current) return
      sendingRef.current = true
      setBusy(true)
      try {
        const r = await api.setStandby(true, text)
        setStatus(r.line)
        setComposing(false)
        updateDraft('', false)
      } finally {
        sendingRef.current = false
        setBusy(false)
      }
      return
    }
    if (!text.trim()) return
    if (sendingRef.current) return
    sendingRef.current = true
    setBusy(true)
    try {
      const r = await api.send(text)
      setReceipt(r.state === 'error' ? r : { ...r, detail: '' })
      setStatus(null)
      if (r.state !== 'error') {
        updateDraft('', false)
        setPoint(0)
        api.clearDraft()
      }
      setComposing(false)
    } finally {
      sendingRef.current = false
      setBusy(false)
    }
  }, [api, mode, updateDraft, closeCompose, setSettingsFilter, pathMarkNote])

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

  /**
   * `C-v`: paste the clipboard (P20/B4). The probe runs only here — never on the render or refresh
   * path — and one probe at a time; while it runs the frame keeps rendering and typing keeps landing
   * in the draft. An image becomes its temporary file path, a non-image the clipboard's text, and a
   * failed probe changes nothing (no error line, no file).
   */
  const pasteClipboard = useCallback(async () => {
    if (busy || probingRef.current) return
    probingRef.current = true
    try {
      const read = await api.pasteClipboard()
      if (read.kind === 'none' || read.value === '') return
      const text = draftRef.current
      const point = cursorRef.current
      pushUndo(undoRef.current, text, point)
      killRingRef.current = resetKillDirection(killRingRef.current)
      yankRef.current = null
      lastActionRef.current = 'edit'
      const flatten = (value: string): string => (mode === 'reason' ? value.replace(/\n/g, ' ') : value)
      // The insertion point is read *after* the probe settles: a keystroke during the probe lands
      // before the paste, exactly where the point then is.
      updateCompose(insertAt(draftRef.current, cursorRef.current, flatten(read.value)), mode === 'message')
    } finally {
      probingRef.current = false
    }
  }, [api, busy, mode, updateCompose])

  const relayEditor = useCallback(async () => {
    // `C-o` hands the draft to `$EDITOR`. The editor relay writes `state/draft.md`; in reason mode
    // that would clobber the message draft, and a long reason is not the flow the design asks for —
    // `C-o` belongs to the letter.
    if (busy || composing === false || mode !== 'message') return
    // Ink's own input must be deactivated for the handoff: both Ink and `$EDITOR` read the same
    // pty, and whoever reads a keystroke first consumes it (measured: `:wq` never reached vi
    // while Ink's `useInput` stayed active). Do NOT flip `busy` here: a state change that alters
    // the frame forces a repaint, and that repaint races the editor's first output bytes and
    // erases them (the 2.3 "the editor got the terminal" assertion flipped with machine speed).
    // `editorOpen` alone gates the input; the frame stays byte-identical, so Ink writes nothing.
    setEditorOpen(true)
    try {
      const next = await api.editDraft(draftRef.current)
      updateDraft(next, mode === 'message')
      setPoint(cpLength(next))
      // The editor may have replaced the whole draft: an undo that resurrected pre-editor text
      // would be a lie, so the history (and the ring) restarts here (design §5).
      undoRef.current = []
      killRingRef.current = { entries: [], lastDirection: null }
      yankRef.current = null
      lastActionRef.current = null
    } finally {
      setEditorOpen(false)
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
          // Four pages since P18/B2: the cycle covers 1–4 and wraps (the old three-page test let 4
          // fall through to 5, which the next launch rejects as out of range — a silent reset).
          next.defaultPage = cur.defaultPage === 4 ? 1 : ((cur.defaultPage + 1) as PageId)
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

  /** The board's rows as the last assembly saw them (the kanban moves over these). */
  const boardRows = useCallback(() => dataRef.current.blocks?.board?.rows ?? [], [])

  const moveFocus = useCallback(
    (laneDelta: number, cardDelta: number) => {
      const rows = boardRows()
      const current = resolveFocus(rows, focusRef.current)
      if (!current) return
      if (laneDelta !== 0) {
        // ←/→: the neighbouring lane's first card (empty lanes are stepped over). The target lane's
        // window is pushed to show it, so an offset the wheel left behind cannot hide the focus.
        const lanes = ['todo', 'wip', 'review', 'done', 'blocked', 'dropped']
        let i = lanes.indexOf(current.lane)
        for (let step = 0; step < lanes.length; step++) {
          i = (i + laneDelta + lanes.length) % lanes.length
          const card = rows.find((r) => r.state === lanes[i])
          if (card) {
            setFocus(focusRefOf(rows, card))
            setLaneOffset((prev) => ({ ...prev, [lanes[i]]: 0 }))
            return
          }
        }
        return
      }
      // ↑/↓: the next/previous **row** of the current lane. M48: a lookup by id stopped dead on the
      // first of two rows sharing an id, so the second was unreachable — the walk is positional now
      // (the resolved row object), and every drawn card is exactly one step.
      const row = focusRow(rows, current)
      if (!row) return
      const inLane = rows.filter((r) => r.state === current.lane)
      const idx = inLane.indexOf(row)
      const next = idx < 0 ? undefined : inLane[idx + cardDelta]
      if (!next || next === row) return
      setFocus(focusRefOf(rows, next))
      // Scrolling the lane's window is the layout's own follow-the-focus rule; the wheel keeps its
      // own offset, so push that offset along when the focus walks past the window's edge.
      const win = lanesRef.current.find((w) => w.lane === current.lane)
      if (win && win.visible > 0) {
        const target = inLane.indexOf(next)
        const start = Math.max(
          0,
          Math.min(
            Math.max(0, win.count - win.visible),
            win.offset +
              (target < win.offset ? target - win.offset : target >= win.offset + win.visible ? target - win.offset - win.visible + 1 : 0),
          ),
        )
        setLaneOffset((prev) => ({ ...prev, [current.lane]: start }))
      }
    },
    [boardRows],
  )

  /**
   * The work page's `↑`/`↓` (P20/B5): walk the rows in the order the block drew them, so the keys
   * touch exactly what is on screen. The first press with no usable focus lands on the first drawn
   * row, and a focus whose entry left the board re-anchors there too. M48: the drawn order carries
   * the duplicate ordinal, so two rows sharing an id are two steps — not one, and never a freeze.
   */
  const moveBoardFocus = useCallback((delta: number) => {
    const order = boardOrderRef.current
    if (!order.length) return
    const cur = focusRef.current
    let idx = -1
    if (cur) {
      idx = order.findIndex((r) => r.id === cur.id && (r.nth ?? 0) === (cur.nth ?? 0))
      if (idx < 0) idx = order.findIndex((r) => r.id === cur.id)
    }
    if (idx < 0) {
      setFocus(order[0])
      return
    }
    const next = Math.max(0, Math.min(order.length - 1, idx + delta))
    if (next !== idx) setFocus(order[next])
  }, [])

  const scrollLane = useCallback((lane: string, delta: number) => {
    const win = lanesRef.current.find((w) => w.lane === lane)
    const max = win ? Math.max(0, win.count - win.visible) : Number.MAX_SAFE_INTEGER
    setLaneOffset((prev) => ({ ...prev, [lane]: Math.max(0, Math.min(max, (prev[lane] ?? (win?.offset ?? 0)) + delta)) }))
  }, [])

  /** Open an entry's detail view: the first tab, from the top (the board page's Enter / a click). */
  const openDetail = useCallback((id: string) => {
    setDetailIndex(0)
    setDetailScroll(0)
    setDetailId(id)
  }, [])

  /** Enter on the work page: open the focused row (or the first drawn one, when it left the board). */
  const openWorkFocused = useCallback(() => {
    const order = boardOrderRef.current
    if (!order.length) return
    const cur = focusRef.current
    const hit = cur
      ? order.find((r) => r.id === cur.id && (r.nth ?? 0) === (cur.nth ?? 0)) ?? order.find((r) => r.id === cur.id)
      : undefined
    openDetail((hit ?? order[0]).id)
  }, [openDetail])

  // ---- project settings (P22/B2): the view's focus walk, its origin and its row opening.

  /** The view's focusable rows as the last assembly saw them (the walk must match the screen). */
  const settingsRowsNow = useCallback((): ({ kind: 'key'; key: import('./types.js').SettingsKey } | { kind: 'seat'; seat: import('./types.js').SettingsSeat })[] => {
    const rows = settingsViewRows(dataRef.current.blocks?.settings, settingsFilterRef.current, stringsRef.current)
    return rows.filter((r): r is { kind: 'key'; key: import('./types.js').SettingsKey } | { kind: 'seat'; seat: import('./types.js').SettingsSeat } => r.kind === 'key' || r.kind === 'seat')
  }, [])

  const moveSettingsFocus = useCallback(
    (delta: number) => {
      const rows = settingsRowsNow()
      if (!rows.length) return
      setSettingsFocus((i) => Math.max(0, Math.min(rows.length - 1, i + delta)))
    },
    [settingsRowsNow],
  )

  // ---- the choice picker (M55): one entry list per key, built from the command's own read.

  /**
   * The entries R3 fixes the order of: a keep-unset lead for a key the file does not carry, the
   * current value (only when the file carries the key), the schema default (only when non-empty),
   * the command's `choices.values` in their order (deduped), then the kind's own actions. Closed
   * kinds (`bool`, `enum`) get no free-text entry; the open kinds end with one; `path` offers a
   * clear entry exactly when the command accepts the empty value. No option table lives here —
   * pulling a value out of the schema would be the second source the requirement forbids.
   */
  const buildChoiceEntries = useCallback(
    (key: SettingsKey): SettingsChoiceEntry[] => {
      const ch = key.choices
      if (!ch) return []
      const kind = String(key.kind ?? '')
      const rule = String(ch.note ?? '')
      const values = (Array.isArray(ch.values) ? ch.values : []).map((v) => String(v))
      const out: SettingsChoiceEntry[] = []
      const seen = new Set<string>()
      const pushValue = (value: string, entryKind: SettingsChoiceEntry['kind']): void => {
        if (value === '' || seen.has(value)) return
        seen.add(value)
        out.push(kind === 'path' ? { value, kind: entryKind, mark: api.pathMark(value, rule) } : { value, kind: entryKind })
      }
      const base = key.set ? key.value : ''
      if (!key.set) out.push({ value: '', kind: 'keep-unset' })
      pushValue(key.value, 'current')
      pushValue(key.default, 'default')
      for (const v of values) pushValue(v, 'value')
      if (kind === 'bool' || kind === 'enum' || kind === 'pairlist') return out
      if (kind === 'path') {
        if (ch.empty) out.push({ value: '', kind: 'clear' })
        out.push({ value: '', kind: 'free', seed: base })
        return out
      }
      if (kind === 'winlist' || kind === 'pattern') {
        // The token vocabulary: choosing a model seeds the compose editor with `<model>=` at the
        // insertion point (the current value's end); the number to the right stays free text.
        const seeded = out.map((e) => (e.kind === 'value' ? { ...e, seed: `${base}${base !== '' && !/\s$/.test(base) ? ' ' : ''}${e.value}=` } : e))
        return [...seeded, { value: '', kind: 'free', seed: base }]
      }
      out.push({ value: '', kind: 'free', seed: base })
      return out
    },
    [api],
  )

  /**
   * The write target a picker accept acts on (M65/D11): built from the `settings` block the view
   * already read, never from a fresh `config list`/`__panel-data`. The fingerprint is that block's,
   * so a contract changed under the picker is the owning command's conflict verdict — CAS is the
   * freshness check, not a re-read between every keystroke and its frame.
   */
  const choiceTarget = useCallback(
    (picker: SettingsChoicePicker): NonNullable<typeof settingRowRef.current> => {
      const rows = settingsRowsNow()
      // By key name, not by index: the picker's row index is a focus index and the row list can be
      // replaced by a settle re-read while the picker is open.
      const rowNow = rows.find((r) => r.kind === 'key' && r.key.name === picker.key) ?? rows[picker.row]
      const keyNow = rowNow && rowNow.kind === 'key' ? rowNow.key : null
      return {
        row: picker.row,
        key: picker.key,
        value: keyNow?.value ?? '',
        cls: keyNow?.class ?? 'apply',
        fingerprint: dataRef.current.blocks?.settings?.fingerprint ?? '',
        kind: picker.kind,
        choices: keyNow?.choices,
      }
    },
    [settingsRowsNow],
  )

  /**
   * The direct write (M65/D10): accepting a value entry asks the owning command for the validation
   * it already uses (`--dry-run`) and, when it accepts, performs the write on the very same accept
   * (`--yes --fingerprint` of the read the editor was built from) — no confirmation frame and no
   * compose editor on this path. A value the command reports dangerous (exit 7) is not written by
   * that first accept: the warning rides the status line and one more accept of the same value
   * writes it with the command's allowance. The receipt is the existing exit-code mapping; a
   * conflict names the other writer, writes nothing and refreshes the block in the background.
   */
  const writeChoiceValue = useCallback(
    async (target: NonNullable<typeof settingRowRef.current>, value: string): Promise<void> => {
      if (sendingRef.current) return
      sendingRef.current = true
      setBusy(true)
      const timing =
        target.cls === 'restart' ? stringsRef.current.settingTimingRestart : stringsRef.current.settingTimingApply
      try {
        const danger = choiceDangerRef.current
        const dangerAccept = Boolean(danger && danger.key === target.key && danger.value === value)
        if (!dangerAccept) {
          const dry = await api.setSetting(target.key, value, { dryRun: true, fingerprint: target.fingerprint })
          if (dry.code === 7) {
            choiceDangerRef.current = { key: target.key, value }
            setReceipt(null)
            setStatus(fill(stringsRef.current.settingDanger, { reason: dry.line }))
            return
          }
          // 3 = the file changed under the picker: the real write below is what the command audits.
          if (dry.code !== 0 && dry.code !== 3) {
            choiceDangerRef.current = null
            setReceipt(null)
            setStatus(
              fill(
                dry.code === 5
                  ? stringsRef.current.settingRefused
                  : dry.code === 4
                    ? stringsRef.current.settingInvalid
                    : stringsRef.current.settingWriteError,
                { line: dry.line },
              ),
            )
            return
          }
        }
        const r = await api.setSetting(target.key, value, {
          dryRun: false,
          fingerprint: target.fingerprint,
          allowDanger: dangerAccept,
        })
        choiceDangerRef.current = null
        if (r.code === 0) {
          setReceipt(null)
          setStatus(fill(stringsRef.current.settingWritten, { key: target.key, value, timing }))
          settingRowRef.current = null
          setChoicePicker(null)
          choicePickerRef.current = null
          api.refreshSettingsSoon()
        } else if (r.code === 3) {
          // The other writer's bytes survived; reload so the view shows their value (the settle).
          setReceipt(null)
          setStatus(stringsRef.current.settingConflict)
          setChoicePicker(null)
          choicePickerRef.current = null
          api.refreshSettingsSoon()
        } else {
          setReceipt(null)
          setStatus(
            fill(
              r.code === 5
                ? stringsRef.current.settingRefused
                : r.code === 4
                  ? stringsRef.current.settingInvalid
                  : stringsRef.current.settingWriteError,
              { line: r.line },
            ),
          )
        }
      } finally {
        sendingRef.current = false
        setBusy(false)
      }
    },
    [api],
  )

  /**
   * The pairlist row's editor is the seats block (the requirement that owns per-seat editing):
   * `enter` moves the focus there, no compose editor and no option list opens. A filter that hides
   * the seats is dropped, because otherwise "focus the seats block" would name a row that is not
   * on screen.
   */
  const routePairlist = useCallback(() => {
    const rows = settingsRowsNow()
    let seat = rows.findIndex((r) => r.kind === 'seat')
    if (seat < 0) {
      settingsFilterRef.current = ''
      setSettingsFilter('')
      // The focus index counts focusable rows, not the group headings `settingsViewRows` also
      // returns — counting those would land the cursor on the wrong row (or past the end).
      const all = settingsViewRows(dataRef.current.blocks?.settings, '', stringsRef.current).filter(
        (r) => r.kind === 'key' || r.kind === 'seat',
      )
      seat = all.findIndex((r) => r.kind === 'seat')
    }
    setChoicePicker(null)
    choicePickerRef.current = null
    if (seat >= 0) setSettingsFocus(seat)
    setReceipt(null)
    setStatus(stringsRef.current.settingsChoicePairlist)
  }, [settingsRowsNow])

  /**
   * One picker choice (M65/D10): a value entry validates and writes on this accept; a seeded entry
   * (`winlist`/`pattern`'s `<model>=`) and the free-text entry open the compose editor, which keeps
   * its validation and confirmation; keep-unset cancels. A click on an entry that does not carry
   * the cursor only moves it — a click on the cursor's entry accepts it like `enter` does.
   */
  const chooseChoiceOption = useCallback(
    (index: number) => {
      const picker = choicePickerRef.current
      if (!picker) return
      if (index >= 0 && index !== picker.index) {
        const next = { ...picker, index: Math.max(0, Math.min(picker.entries.length - 1, index)) }
        choiceDangerRef.current = null
        choicePickerRef.current = next
        setChoicePicker(next)
        return
      }
      const entry = picker.entries[index < 0 ? picker.index : index]
      if (!entry) return
      // keep-unset cancels: no compose editor, no write, no audit line, no temporary file. The
      // writer has no removal operation, so the view never claims it deleted the line.
      if (entry.kind === 'keep-unset') {
        choiceDangerRef.current = null
        setChoicePicker(null)
        choicePickerRef.current = null
        return
      }
      const target = choiceTarget(picker)
      settingRowRef.current = target
      if (entry.kind === 'free' || entry.seed !== undefined) {
        // The only typed path: the editor's validation and confirmation are unchanged (D10).
        settingConfirmRef.current = null
        setSettingConfirm(null)
        choiceDangerRef.current = null
        setChoicePicker(null)
        choicePickerRef.current = null
        openCompose('setting', entry.seed !== undefined ? entry.seed : entry.value)
        return
      }
      void writeChoiceValue(target, entry.value)
    },
    [choiceTarget, openCompose, writeChoiceValue],
  )

  const moveChoicePicker = useCallback((delta: number) => {
    const picker = choicePickerRef.current
    if (!picker) return
    choiceDangerRef.current = null
    const next = { ...picker, index: Math.max(0, Math.min(picker.entries.length - 1, picker.index + delta)) }
    choicePickerRef.current = next
    setChoicePicker(next)
  }, [])

  const closeChoicePicker = useCallback(() => {
    choiceDangerRef.current = null
    setChoicePicker(null)
    choicePickerRef.current = null
  }, [])

  const openSettingsView = useCallback(
    (origin: number) => {
      setSettingsOrigin(origin)
      setOverlayIndex(origin)
      overlayIndexRef.current = origin
      setSettingsView(true)
      settingsViewRef.current = true
      setSettingsFocus(0)
      setSettingsFilter('')
      settingsFilterRef.current = ''
      api.setSettingsOpen(true)
      api.refreshNow()
    },
    [api],
  )

  const closeSettingsView = useCallback(() => {
    setSettingsView(false)
    settingsViewRef.current = false
    setSeatPicker(null)
    seatPickerRef.current = null
    setChoicePicker(null)
    choicePickerRef.current = null
    api.setSettingsOpen(false)
    // Back to the overlay row it was opened from (the design's origin rule).
    setOverlay(true)
    setOverlayIndex(settingsOrigin)
    overlayIndexRef.current = settingsOrigin
  }, [api, settingsOrigin])

  /**
   * Enter on a view row: a `refuse` row opens no editor and surfaces the owning command's route;
   * an editable row opens the value editor (the compose line's `setting` mode, B3).
   */
  const openSettingsRow = useCallback(
    (index: number) => {
      const rows = settingsRowsNow()
      // `-1` = the focused row: resolve it once here, so the picker/editor carries a real index
      // (the focus walk passes -1 from the Enter handler).
      const at = index < 0 ? settingsFocusRef.current : index
      const row = rows[at]
      if (!row) return
      if (row.kind === 'seat') {
        // The picker: the command's known models, then the removal and the free-text line. The
        // editor opens on the chosen option so the two-step confirmation has a surface.
        const models = [...(dataRef.current.blocks?.settings?.models?.known ?? [])]
        setSeatPicker({ agent: row.seat.agent, row: at, models, index: 0 })
        seatPickerRef.current = { agent: row.seat.agent, row: at, models, index: 0 }
        setReceipt(null)
        setStatus(null)
        return
      }
      const key = row.key
      if (key.class === 'refuse') {
        setReceipt(null)
        setStatus(`${key.name} · ${key.route || key.warning || stringsRef.current.settingsRefusedRoute}`)
        return
      }
      // M65/D11: the editor opens on the `settings` block already on screen — no `config list` or
      // `__panel-data` stands between the keystroke and the frame that answers it. The fingerprint
      // is that block's, so a contract changed underneath is the owning command's conflict verdict
      // (CAS), not a reason to re-read before every action.
      if (hasChoiceEditor(key)) {
        if (String(key.kind ?? '') === 'pairlist') {
          routePairlist()
          return
        }
        const entries = buildChoiceEntries(key)
        if (entries.length) {
          const kind = String(key.kind ?? '')
          const picker: SettingsChoicePicker = {
            row: at,
            key: key.name,
            kind,
            entries,
            index: 0,
            interval: NUMERIC_KINDS.has(kind) ? { min: String(key.choices?.min ?? ''), max: String(key.choices?.max ?? '') } : null,
          }
          choiceDangerRef.current = null
          setChoicePicker(picker)
          choicePickerRef.current = picker
          setReceipt(null)
          setStatus(null)
          return
        }
      }
      settingRowRef.current = {
        row: index,
        key: key.name,
        value: key.value,
        cls: key.class,
        fingerprint: dataRef.current.blocks?.settings?.fingerprint ?? '',
        kind: String(key.kind ?? ''),
        choices: key.choices,
      }
      settingConfirmRef.current = null
      setSettingConfirm(null)
      openCompose('setting', key.set || key.value !== '' ? key.value : key.default)
      if (key.choices && !hasChoiceEditor(key)) {
        // The visible fallback (R3): the kind defines no choice set and the command still validates
        // the write. The line rides the editor's own hint row, so it stays on screen while typing.
        setStatus(fill(stringsRef.current.settingsChoiceNoChoice, { kind: String(key.kind ?? '') }))
      }
    },
    [buildChoiceEntries, openCompose, routePairlist, settingsRowsNow],
  )

  /**
   * One picker choice: a model opens the editor holding it, `-` opens it holding the removal,
   * the free-text row opens it empty. The editor's two Enter presses are the confirmation.
   */
  /** Resolve a picker index (or -1 = the selected one) into the picker + its option. */
  const pickerIndex = useCallback(
    (index: number): { picker: { agent: string; row: number; models: string[]; index: number }; option: string } | null => {
      const p = seatPickerRef.current
      if (!p) return null
      const options = [...p.models, '-', '']
      const i = index < 0 ? p.index : index
      if (i < 0 || i >= options.length) return null
      return { picker: p, option: options[i] }
    },
    [],
  )

  const chooseSeatOption = useCallback(
    (index: number) => {
      const picker = pickerIndex(index)
      if (!picker) return
      const { picker: p, option } = picker
      const seat = p.agent
      // M65/D11: the editor opens from the block already on screen (no read on the interaction
      // path); its fingerprint is that block's, so CAS catches a contract changed underneath.
      const block = dataRef.current.blocks?.settings
      const seatRow = (block?.models?.seats ?? []).find((x) => x.agent === seat)
      const initial = option === '' ? '' : option
      settingRowRef.current = {
        row: p.row,
        key: seat,
        value: seatRow?.model ?? '',
        cls: 'restart',
        fingerprint: block?.fingerprint ?? '',
        seat,
      }
      settingConfirmRef.current = null
      setSettingConfirm(null)
      setSeatPicker(null)
      seatPickerRef.current = null
      openCompose('setting', initial)
    },
    [openCompose, pickerIndex],
  )

  const moveSeatPicker = useCallback((delta: number) => {
    const p = seatPickerRef.current
    if (!p) return
    const count = p.models.length + 2
    const next = { ...p, index: Math.max(0, Math.min(count - 1, p.index + delta)) }
    seatPickerRef.current = next
    setSeatPicker(next)
  }, [])

  /** The detail view's file tabs: `←`/`→` clamp at the ends (no wrap — the row shows the order). */
  const moveDetailTab = useCallback((delta: number) => {
    const files = dataRef.current.blocks?.detail?.files ?? []
    if (!files.length) return
    setDetailIndex((i) => Math.max(0, Math.min(files.length - 1, i + delta)))
    setDetailScroll(0)
  }, [])

  /** The detail document's scroll: clamped against the window the last frame reported. */
  const scrollDetail = useCallback((delta: number) => {
    const win = detailRef.current
    const max = win ? Math.max(0, win.total - win.visible) : 0
    setDetailScroll((v) => Math.max(0, Math.min(max, v + delta)))
  }, [])

  /**
   * The detail block's one data contract (design §8): it is requested only while the view is open,
   * and only for the tab in view. Opening forces the first build; a tab switch forces the newly
   * requested file (`--file`); closing clears the request, which drops `detail` from the wanted set
   * so a parked page 4 spawns no reader at all. The call is idempotent — `setDetail` records an
   * option whose content the cached block already serves without rebuilding it.
   */
  const detailBlockData = data.blocks?.detail
  useEffect(() => {
    if (!detailId) {
      api.setDetail(null)
      return
    }
    const files = detailBlockData?.files ?? []
    api.setDetail(detailId, files[detailIndexRef.current]?.path ?? null)
  }, [api, detailId, detailIndex, detailBlockData])

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
        case 'focus':
          setFocus({ lane: action.lane, id: action.id, nth: action.nth ?? 0 })
          return
        case 'open-focused': {
          // One action kind, two pages: the kanban resolves its lane/card focus, the work page the
          // drawn row order (P20/B5).
          if (pageRef.current === 2) {
            openWorkFocused()
            return
          }
          const current = resolveFocus(boardRows(), focusRef.current)
          if (current) openDetail(current.id)
          return
        }
        case 'lane-move':
          moveFocus(action.delta, 0)
          return
        case 'card-move':
          if (pageRef.current === 2) moveBoardFocus(action.delta)
          else moveFocus(0, action.delta)
          return
        case 'lane-scroll':
          scrollLane(action.lane, action.delta)
          return
        case 'detail-tab':
          setDetailIndex(action.index)
          setDetailScroll(0)
          return
        case 'detail-tab-move':
          moveDetailTab(action.delta)
          return
        case 'detail-scroll':
          scrollDetail(action.delta)
          return
        case 'detail-close':
          setDetailId(null)
          return
        case 'settings-open-view':
          openSettingsView(overlayIndexRef.current)
          return
        case 'settings-close':
          closeSettingsView()
          return
        case 'settings-focus':
          setSettingsFocus(action.index)
          return
        case 'settings-open':
          openSettingsRow(action.index)
          return
        case 'settings-filter':
          openCompose('filter')
          return
        case 'settings-scroll':
          moveSettingsFocus(action.delta)
          return
        case 'choice-pick':
          chooseChoiceOption(action.index)
          return
        case 'choice-move':
          moveChoicePicker(action.delta)
          return
        case 'choice-close':
          closeChoicePicker()
          return
        case 'seat-pick':
          if (action.index < 0) chooseSeatOption(-1)
          else chooseSeatOption(action.index)
          return
        case 'seat-move':
          moveSeatPicker(action.delta)
          return
      }
    },
    [boardRows, chooseChoiceOption, closeChoicePicker, closeSettingsView, collapse, cyclePref, goPage, moveBoardFocus, moveChoicePicker, moveDetailTab, moveFocus, moveSeatPicker, moveSettingsFocus, openCompose, openDetail, openSettingsRow, openSettingsView, openWorkFocused, runAction, scrollDetail, scrollLane, updateScroll],
  )

  const effectiveActivity = activityPinned ? data.activity : settings.activity

  const rowCacheRef = useRef<{ key: string; row: Segment[] }[]>([])

  const lines = useMemo(() => {
    const bottom: string[] = []
    if (!composing) {
      const notice = receipt ? receiptLine(receipt, strings) : status
      if (notice) bottom.push(notice)
    }
    const boxed = composing && settings.density === 'comfortable'
    const inputWidth = boxed ? Math.max(1, size.columns - 2) : size.columns
    // One windowed view for the whole compose surface: the drawn rows, the point's drawn position
    // and the hidden-rows count all come from the same row map (P20/B1).
    const inputView: ComposeView | null = composing
      ? cursorView(mode, draft, cursor, inputWidth, composeMaxRows(), strings.composeHiddenAbove)
      : null
    const rawInput = inputView?.lines ?? []
    const trayTitle =
      mode === 'message'
        ? strings.composeTitle
        : mode === 'reason'
          ? strings.composeStandbyTitle
          : mode === 'filter'
            ? strings.settingFilterTitle
            : settingRowRef.current?.key ?? strings.settingsViewTitle
    const input = boxed
      ? [composeTrayTop(trayTitle, size.columns), ...rawInput.map((line) => `${TRAY_V} ${line}`)]
      : rawInput
    const hint = composing
      ? [
          // The setting/filter editor's own receipt (the confirmation line, the danger warning, the
          // command's refusal) rides the hint row *above* the input so the input line stays last
          // (the IME cursor anchor rule) while the editor stays open with its draft.
          ...(status && (mode === 'setting' || mode === 'filter') ? [status] : []),
          mode === 'message'
            ? strings.composeHint
            : mode === 'reason'
              ? strings.composeReasonHint
              : strings.settingsKeyHint,
        ]
      : []
    // The in-flight-send row is part of the pane too: counting it keeps the rendered output at the
    // pane's height, so the frame never scrolls (the absolute cursor position depends on the frame
    // starting at the pane's first row).
    const busyRow = busy ? 1 : 0
    const frameRows = size.rows > 0 ? Math.max(3, size.rows - input.length - hint.length - bottom.length - busyRow) : data.height
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
      focus,
      laneOffset,
      detail: detailId,
      detailIndex,
      detailScroll,
      settings: settingsView,
      settingsFocus,
      settingsFilter,
      seatPicker,
      choicePicker,
    }
    // The geometry comes from the live terminal, not from the frame's snapshot of it: a resize must
    // re-lay out the next frame (the spec's "A resize re-lays out live"), and `data.width` is frozen
    // at process start. The live clock is NOT fed through here: it patches row 0 after the memo
    // (below), so the per-second tick never re-runs the full layout (measured: routing `now`
    // through layout() pushed an idle console to ~1.1% of one core — over the red line).
    const themed = layout({
      ...data,
      width: Math.max(1, size.columns || data.width),
      activity: effectiveActivity,
      strings,
      height: frameRows,
      view,
    } as LayoutInput)
    const pad = size.rows > 0 ? Math.max(0, size.rows - input.length - hint.length - bottom.length - busyRow - themed.rows.length) : 0
    targetsRef.current = themed.targets
    lanesRef.current = themed.lanes ?? []
    boardOrderRef.current = themed.boardOrder ?? []
    detailRef.current = themed.detail ?? null
    return { frame: themed, input, hint, bottom, pad, boxed, inputView }
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
    focus,
    laneOffset,
    detailId,
    detailIndex,
    detailScroll,
    settingsView,
    settingsFocus,
    settingsFilter,
    seatPicker,
    choicePicker,
    size,
    composing,
    mode,
    draft,
    cursor,
    composeMaxRows,
    receipt,
    status,
    busy,
    effectiveActivity,
  ])

  // The real terminal cursor on the insertion point (P20/B1): the position is relative to the Ink
  // output origin, which is the frame's first row. `y` counts the rows before the draft's row
  // (frame, pad, hint, the boxed tray's top edge); `x` adds the tray wall to the drawn column.
  // `undefined` while not composing or while a send is in flight hides it. Ink's own cursor math
  // is corrected by main.tsx's cursor-aware stdout, which re-asserts this same position after
  // every write; `useCursor` keeps Ink's show/hide bookkeeping in charge.
  const { setCursorPosition } = useCursor()
  const cursorPos =
    composing && !busy && lines.inputView
      ? {
          x: (lines.boxed ? 2 : 0) + lines.inputView.cursorColumn,
          y: lines.frame.rows.length + lines.pad + lines.hint.length + (lines.boxed ? 1 : 0) + lines.inputView.cursorLine,
        }
      : undefined
  setCursorPosition(cursorPos)
  api.setComposeCursor(cursorPos ?? null)

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
          const delta = button === 65 ? 1 : -1
          // With the detail view open the wheel scrolls the document (the one scrollable region),
          // on the page the view was opened from (the work page's rows open it too, P20/B5).
          if (choicePickerRef.current) {
            // The choice picker's entries may outrun the budget: the wheel walks the list like
            // ↑/↓ (the window follows the selection, as the seat picker's does).
            moveChoicePicker(delta)
            return
          }
          if ((pageRef.current === 4 || pageRef.current === 2) && detailIdRef.current) {
            scrollDetail(delta)
            return
          }
          // On the board page the wheel scrolls the lane under the cursor (a card hit carries its
          // lane, the lane's own hover target covers the rest); elsewhere it scrolls the page's list.
          if (pageRef.current === 4) {
            const over = targetsRef.current.find((t) => t.row === y - 1 && x - 1 >= t.hit.start && x - 1 < t.hit.end)
            const lane = over && (over.hit.action.kind === 'lane-scroll' || over.hit.action.kind === 'focus' || over.hit.action.kind === 'open-focused')
              ? over.hit.action.lane
              : ''
            if (lane) {
              scrollLane(lane, delta)
              return
            }
          }
          // The wheel scrolls the page's list: down reveals later rows, up goes back.
          updateScroll((v) => v + delta)
          return
        }
        if (mouse[4] !== 'M' || (button & 3) !== 0) return
        const row = y - 1
        const col = x - 1
        const hit = targetsRef.current.find((t) => t.row === row && col >= t.hit.start && col < t.hit.end)
        if (hit) dispatch(hit.hit.action)
        return
      }

      if (overlay && !settingsViewRef.current) {
        if (key.escape || input === ',') {
          setOverlay(false)
          return
        }
        if (key.upArrow) {
          setOverlayIndex((i) => (i + PREFS.length) % (PREFS.length + 1))
          return
        }
        if (key.downArrow) {
          setOverlayIndex((i) => (i + 1) % (PREFS.length + 1))
          return
        }
        if (key.return || input === ' ') {
          // The sixth row is the one navigation row: it opens the project-settings view instead of
          // toggling a preference (and writes no file).
          if (overlayIndexRef.current >= PREFS.length) openSettingsView(overlayIndexRef.current)
          else cyclePref(PREFS[overlayIndexRef.current] ?? 'lang')
          return
        }
        return
      }

      if (composing) {
        const composeText = draftRef.current
        const point = cursorRef.current
        const persist = mode === 'message'
        // The reason is one line: every line break lands as a space, typed, pasted or yanked.
        const flatten = (value: string): string => (mode === 'reason' ? value.replace(/\n/g, ' ') : value)
        if (key.ctrl && input === 'o') {
          void relayEditor()
          return
        }
        if (key.ctrl && input === 'v') {
          void pasteClipboard()
          return
        }
        // One pure decoder for both encodings (design §4): the App only applies its intent.
        const intent = composeKey(input, key)
        switch (intent.kind) {
          case 'submit':
            void submit()
            return
          case 'cancel':
            // The filter line's esc clears the filter without closing the view (P22/B2).
            if (mode === 'filter') {
              settingsFilterRef.current = ''
              setSettingsFilter('')
              setSettingsFocus(0)
            }
            closeCompose()
            return
          case 'none':
            return
          case 'newline': {
            if (busy) return
            pushUndo(undoRef.current, composeText, point)
            killRingRef.current = resetKillDirection(killRingRef.current)
            yankRef.current = null
            lastActionRef.current = 'edit'
            updateCompose(insertAt(composeText, point, flatten('\n')), persist)
            return
          }
          case 'move':
            setPoint(moveCursor(composeText, point, intent.motion, { width: composeWidth(), pageRows: composeMaxRows() }))
            return
          case 'insert': {
            if (busy) return
            // The typed/pasted text path: `intake` normalizes CR/LF and strips control bytes; the
            // paste markers may arrive with a leading ESC already consumed by Ink, so both
            // spellings are accepted and an unclosed bracket stays open across reads.
            const next = intake(input, pasteOpenRef.current)
            pasteOpenRef.current = next.pasteOpen
            if (!next.append) return
            pushUndo(undoRef.current, composeText, point)
            killRingRef.current = resetKillDirection(killRingRef.current)
            yankRef.current = null
            lastActionRef.current = 'edit'
            updateCompose(insertAt(composeText, point, flatten(next.append)), persist)
            return
          }
          case 'kill': {
            if (busy) return
            const span = killSpan(composeText, point, intent.unit)
            if (!span) return
            pushUndo(undoRef.current, composeText, point)
            killRingRef.current = pushKill(killRingRef.current, span.text, span.direction)
            yankRef.current = null
            lastActionRef.current = 'edit'
            const cps = [...composeText]
            updateCompose({ text: [...cps.slice(0, span.from), ...cps.slice(span.to)].join(''), cursor: span.from }, persist)
            return
          }
          case 'yank': {
            if (busy) return
            const text = ringEntry(killRingRef.current, 0)
            if (!text) return
            pushUndo(undoRef.current, composeText, point)
            killRingRef.current = resetKillDirection(killRingRef.current)
            yankRef.current = { pops: 0, length: cpLength(text) }
            lastActionRef.current = 'yank'
            updateCompose(insertAt(composeText, point, flatten(text)), persist)
            return
          }
          case 'yankPop': {
            if (busy) return
            const yank = yankRef.current
            if (!yank || lastActionRef.current !== 'yank') return
            const text = ringEntry(killRingRef.current, yank.pops + 1)
            if (!text) return
            pushUndo(undoRef.current, composeText, point)
            // Replace what the previous yank inserted: it sits directly before the point.
            const cps = [...composeText]
            const from = Math.max(0, point - yank.length)
            const replaced = [...cps.slice(0, from), ...cps.slice(point)].join('')
            yankRef.current = { pops: yank.pops + 1, length: cpLength(text) }
            lastActionRef.current = 'yank'
            updateCompose(insertAt(replaced, from, flatten(text)), persist)
            return
          }
          case 'undo': {
            if (busy) return
            const snap = popUndo(undoRef.current)
            if (!snap) return
            killRingRef.current = resetKillDirection(killRingRef.current)
            yankRef.current = null
            lastActionRef.current = 'edit'
            updateCompose({ text: snap.text, cursor: snap.cursor }, persist)
            return
          }
        }
        return
      }

      // The project-settings view owns its keys first (it sits above the overlay it was opened
      // from); anything it does not claim (notably `q`) falls through to the global handling.
      if (settingsViewRef.current && !composing) {
        if (choicePickerRef.current) {
          // The choice picker owns the same keys the seat picker does: esc closes it back to the
          // row list with the row focus untouched, and it writes nothing on the way out.
          if (key.escape) {
            closeChoicePicker()
            return
          }
          if (key.upArrow || key.downArrow) {
            moveChoicePicker(key.upArrow ? -1 : 1)
            return
          }
          if (key.return) {
            chooseChoiceOption(-1)
            return
          }
          return
        }
        if (seatPickerRef.current) {
          if (key.escape) {
            setSeatPicker(null)
            seatPickerRef.current = null
            return
          }
          if (key.upArrow || key.downArrow) {
            moveSeatPicker(key.upArrow ? -1 : 1)
            return
          }
          if (key.return) {
            chooseSeatOption(-1)
            return
          }
          return
        }
        if (key.escape) {
          closeSettingsView()
          return
        }
        if (key.upArrow || key.downArrow) {
          moveSettingsFocus(key.upArrow ? -1 : 1)
          return
        }
        if (input === '/') {
          openCompose('filter')
          return
        }
        if (key.return) {
          openSettingsRow(-1)
          return
        }
        if (input !== 'q' && !(key.ctrl && input === 'c')) return
      }

      if (viewEntry != null && key.escape) {
        setViewEntry(null)
        return
      }
      // The detail view is read-only and full-page: Esc or `q` backs out to the board page and never
      // collapses the console (the documented `q` exception); `←`/`→` switch files, `↑`/`↓` scroll.
      if (detailId) {
        if (key.escape || input === 'q') {
          setDetailId(null)
          return
        }
        if (key.leftArrow || key.rightArrow) {
          moveDetailTab(key.leftArrow ? -1 : 1)
          return
        }
        if (key.upArrow || key.downArrow) {
          scrollDetail(key.upArrow ? -1 : 1)
          return
        }
        // Enter adds no action here (no write operation), and the page keys stay live below.
      }
      if (input === 'q' || (key.ctrl && input === 'c')) {
        void collapse()
        return
      }
      if (busy) return
      if (key.tab) {
        goPage(pageRef.current === 4 ? 1 : ((pageRef.current + 1) as PageId))
        return
      }
      if (input === '1' || input === '2' || input === '3' || input === '4') {
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
      if (page === 4 && (key.leftArrow || key.rightArrow)) {
        moveFocus(key.leftArrow ? -1 : 1, 0)
        return
      }
      if (key.upArrow || key.downArrow) {
        // The board page walks its cards and the work page its board rows (the window follows the
        // focus); the other pages scroll.
        if (page === 4) moveFocus(0, key.upArrow ? -1 : 1)
        else if (page === 2) moveBoardFocus(key.upArrow ? -1 : 1)
        else updateScroll((v) => (key.upArrow ? v - 1 : v + 1))
        return
      }
      if (page === 4 && key.return) {
        const current = resolveFocus(boardRows(), focusRef.current)
        if (current) openDetail(current.id)
        return
      }
      if (page === 2 && key.return) {
        // The work page's board rows open the same detail view (P20/B5), on the page it was
        // opened from.
        openWorkFocused()
        return
      }
      if (key.pageUp || key.pageDown) {
        // `↑`/`↓` move the work page's row focus, so the keyboard keeps a page-scroll route (the
        // documented keyboard-only exception beside `r`).
        const step = Math.max(1, (size.rows || 10) - 4)
        updateScroll((v) => v + (key.pageUp ? -step : step))
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

  // The title band's clock is the one visible thing that must advance while the data is
  // byte-identical (V15/F2 — without it an idle console's clock froze at startup, and B2's 2.5
  // lost its "a refresh completed" evidence on screen). It ticks OUTSIDE React: main.tsx paints
  // the clock field directly once a second (a full commit per second costs a whole frame's
  // reconcile + Yoga + rewrite — measured over the <1% red line), and the App registers row 0's
  // segments + palette for that writer. Row 0 itself renders the shared stamp via `clockRow`, so
  // Ink's rare repaints agree with the screen. The data cadence keeps its signature-gated
  // repaint as the only full-frame path.
  const renderRows = stableRows(rowCacheRef.current, lines.frame.rows)
  rowCacheRef.current = renderRows

  const row0 = renderRows.length > 0 ? renderRows[0].row : null
  useEffect(() => {
    api.registerClockRow(row0, palette)
    return () => api.registerClockRow(null, palette)
  }, [api, row0, palette])

  return (
    <Box flexDirection="column" width={size.columns}>
      {renderRows.map(({ row }, i) => (
        <Row key={`f${i}`} row={i === 0 ? clockRow(row, api.clockNowMs()) : row} palette={palette} />
      ))}
      {Array.from({ length: lines.pad }, (_, i) => (
        <Text key={`p${i}`}> </Text>
      ))}
      {/* The hint sits above the input: the input line must be the LAST rendered line while
          composing, because Ink leaves the terminal cursor at the end of the output and the IME
          candidate window anchors there (V15/F1 — with the hint below the input the cursor sat on
          the hint row and B2's CJK cursor acceptance, cursor_x=8, went red). */}
      {lines.hint.map((line, i) => (
        <Text key={`h${i}`} color={palette.tones.dim} wrap="truncate">
          {line}
        </Text>
      ))}
      {lines.input.map((line, i) => (
        <Text
          key={`i${i}`}
          color={
            lines.boxed && i === 0
              ? palette.tones.dim
              : i === lines.input.length - 1
                ? palette.tones.accent
                : palette.tones.text
          }
        >
          {line || ' '}
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
