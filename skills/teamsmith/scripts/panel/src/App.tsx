// The Ink frame: Ink owns the terminal (raw keys, redraw, cursor), the layout module owns the
// lines. Rendering pre-computed lines — rather than nested flex boxes — is what makes the TUI and
// `--print` show the same bands, and it keeps the pane capture free of content the sanitizer has
// not seen: every line is built from sanitized fields by construction.
//
// `lines` is derived (useMemo) from three pieces of state — the latest data, the live terminal size
// and the scroll offset — so a redraw can never show a stale frame: there is exactly one place that
// lays the frame out, and it always sees the newest data with the current geometry.

import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { Box, Text, useApp, useInput } from 'ink'
import { buildFrame } from './layout.js'
import type { FrameInput } from './types.js'

export interface AppProps {
  frame: FrameInput
  /** Redraw period in seconds (`TEAM_MONITOR_REFRESH`). */
  refresh: number
  /** Called once per redraw; returns the fresh frame (and runs a tick when one is due). */
  reload: () => FrameInput
  /** Render one frame and exit. */
  once: boolean
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

export function App({ frame, refresh, reload, once }: AppProps) {
  const [data, setData] = useState<FrameInput>(frame)
  const [size, setSize] = useState<Size>(() => liveSize(frame))
  const [scroll, setScroll] = useState(0)
  const { exit } = useApp()
  const scrollRef = useRef(0)
  const dataRef = useRef(frame)

  // The parent owns the assembly (it is asynchronous now): a fresh frame arrives as a prop and is
  // adopted here, while `reload()` still answers synchronously with the current cache snapshot.
  useEffect(() => {
    dataRef.current = frame
    setData(frame)
  }, [frame])

  const lines = useMemo(
    () => buildFrame({ ...data, width: size.columns, height: size.rows, scroll }),
    [data, size, scroll],
  )

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
    const id = setInterval(() => refreshData(scrollRef.current), Math.max(1, refresh) * 1000)
    return () => clearInterval(id)
  }, [once, refresh, refreshData, exit])

  // A shrinking pane must never keep the padding of the old height (Ink would write the taller box
  // and tmux would scroll the frame out of the visible rows — measured). Re-read the geometry and
  // let `lines` rebuild from the latest data.
  useEffect(() => {
    const onResize = () => setSize(liveSize(dataRef.current))
    if (typeof process.stdout.on !== 'function') return undefined
    process.stdout.on('resize', onResize)
    return () => {
      process.stdout.off('resize', onResize)
    }
  }, [])

  useInput(
    (input, key) => {
      if (input === 'q' || (key.ctrl && input === 'c')) {
        exit()
        return
      }
      if (input === 'r') {
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
    { isActive: Boolean(process.stdin.isTTY) },
  )

  return (
    <Box flexDirection="column" width={size.columns} height={size.rows > 0 ? size.rows : undefined}>
      {lines.map((line, i) => (
        <Text key={i} wrap="truncate">
          {line.length ? line : ' '}
        </Text>
      ))}
    </Box>
  )
}
