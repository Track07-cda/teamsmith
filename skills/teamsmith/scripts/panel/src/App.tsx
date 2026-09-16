// The Ink frame: Ink owns the terminal (raw keys, redraw, cursor), the layout module owns the
// lines. Rendering pre-computed lines — rather than nested flex boxes — is what makes the TUI and
// `--print` show the same bands, and it keeps the pane capture free of content the sanitizer has
// not seen: every line is built from sanitized fields by construction.
//
// `lines` is derived (useMemo) from three pieces of state — the latest data, the live terminal size
// and the scroll offset — so a redraw can never show a stale frame: there is exactly one place that
// lays the frame out, and it always sees the newest data with the current geometry.
//
// B2 adds the compose entry: `m` opens a bottom input line rendered from a **ref** (the draft is
// never a render-time copy, so a refresh landing mid-typing cannot drop a keystroke), Esc keeps it
// in `state/draft.md`, Enter sends it through the guarded command and the receipt is one of three
// honest states. While composing, the input area is the last thing rendered and the rest of the
// frame keeps refreshing.

import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { Box, Text, useApp, useInput } from 'ink'
import { buildFrame } from './layout.js'
import {
  backspace,
  inputLines,
  intake,
  receiptLine,
  type ComposeMode,
  type Receipt,
} from './compose.js'
import type { FrameInput } from './types.js'

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
}

interface Size {
  columns: number
  rows: number
}

function liveSize(fallback: FrameInput): Size {
  return {
    columns: process.stdout.columns || fallback.width,
    rows: process.stdout.rows || fallback.height,
  }
}

export function App({ frame, refresh, reload, once, api }: AppProps) {
  const [data, setData] = useState<FrameInput>(frame)
  const [size, setSize] = useState<Size>(() => liveSize(frame))
  const [scroll, setScroll] = useState(0)
  const [composing, setComposing] = useState(false)
  const [mode, setMode] = useState<ComposeMode>('message')
  const [draft, setDraft] = useState('')
  const [receipt, setReceipt] = useState<Receipt | null>(null)
  const [status, setStatus] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)
  /** True while `$EDITOR` owns the terminal: Ink must not read the keystrokes meant for it. */
  const [editorOpen, setEditorOpen] = useState(false)
  const { exit } = useApp()
  const scrollRef = useRef(0)
  const dataRef = useRef(frame)
  const draftRef = useRef('')
  const pasteOpenRef = useRef(false)

  // The parent owns the assembly (it is asynchronous now): a fresh frame arrives as a prop and is
  // adopted here, while `reload()` still answers synchronously with the current cache snapshot.
  useEffect(() => {
    dataRef.current = frame
    setData(frame)
  }, [frame])

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

  const lines = useMemo(() => {
    const bottom: string[] = []
    if (!composing) {
      const notice = receipt ? receiptLine(receipt) : status
      if (notice) bottom.push(notice)
    }
    const input = composing ? inputLines(mode, draft, size.columns) : []
    const frameRows = size.rows > 0 ? Math.max(3, size.rows - input.length - bottom.length) : data.height
    const frameLines = buildFrame({ ...data, width: size.columns, height: frameRows, scroll })
    const pad =
      size.rows > 0 ? Math.max(0, size.rows - input.length - bottom.length - frameLines.length) : 0
    return [...frameLines, ...Array.from({ length: pad }, () => ''), ...input, ...bottom]
  }, [data, size, scroll, composing, mode, draft, receipt, status])

  const refreshData = useCallback(
    (nextScroll = scrollRef.current) => {
      const fresh = reload()
      dataRef.current = fresh
      scrollRef.current = nextScroll
      setData(fresh)
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
  // let `lines` rebuild from the latest data.
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

  useInput(
    (input, key) => {
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

      if (input === 'q' || (key.ctrl && input === 'c')) {
        exit()
        return
      }
      if (busy) return
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
        setReceipt(null)
        setStatus(null)
        refreshData(scrollRef.current)
        return
      }
      if (key.upArrow || key.downArrow) {
        const evCount = (data.activityBlocks ?? []).reduce(
          (n, b) => n + (Array.isArray(b.events) ? b.events.length : 0),
          0,
        )
        const max = Math.max(0, evCount - 1)
        const next = key.upArrow ? Math.min(max, scrollRef.current + 1) : Math.max(0, scrollRef.current - 1)
        refreshData(next)
      }
    },
    { isActive: !editorOpen && Boolean(process.stdin.isTTY) },
  )

  return (
    <Box flexDirection="column" width={size.columns}>
      {lines.map((line, i) => (
        <Text key={i} wrap="truncate">
          {line.length ? line : ' '}
        </Text>
      ))}
    </Box>
  )
}
