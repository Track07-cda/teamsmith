// The panel's only data path.
//
// Three subprocesses families, none of them blocking the event loop:
//   * one `team __panel-data --block <name>` child per block — the bash readers
//     (`team_pm_state`, `team_pending_*`, the queue directory, `team_git_cols`,
//     `team_session_tokens_est`, the capacity log) split so a broken or slow source takes only its
//     own block down. Each child has its own timeout; a block that fails, dies or overruns renders
//     as `—` and never delays the rest of the frame.
//   * the tick (`team watch --once`) — owned by the run, one async child per due tick.
//
// The renderer reads a snapshot of an in-memory cache; nothing on the render path waits for a
// child. `monitor.mjs` is spawned by the activity block, not here: it stays the data layer, its
// `--json` contract untouched, and the panel consumes its result as a value inside the same
// object.
//
// The cadence is the design's performance contract: the fast blocks rebuild every tick, the
// expensive ones (the report scan, the per-agent git reads) carry a longer TTL, so idle cost stays
// off the input path.

import { spawn } from 'node:child_process'
import { appendFileSync, existsSync, readFileSync, writeFileSync } from 'node:fs'
import { dirname, join, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import { sanitizeDeep } from './sanitize.js'
import type { ActivityBlock, PanelBlocks, PanelData } from './types.js'

/** The blocks the bash data command serves, one child each. */
export const BLOCK_NAMES = [
  'frame',
  'pm',
  'pending',
  'outbox',
  'capacity',
  'agents',
  'recent',
  'activity',
  // pulse-console B3: the console-only readers (the machine exits never render them).
  'board',
  'changes',
  'specs',
  'decisions',
  'outbox_list',
  'inbox',
  'patrol',
  'health',
] as const
export type BlockName = (typeof BLOCK_NAMES)[number]

/**
 * The blocks the **machine exits** (`--print` / `--json`) assemble: the original eight plus the
 * four the overview renders (progress, changes, specs, decisions). The page-2/3-only readers
 * (`outbox_list`, `inbox`, `patrol`, `health`) are console-only: `--print`/`--json` never render
 * them, so they are not spawned there — `--json`'s cost and keys stay exactly as before, and a
 * `doctor` run never sits on a machine exit's path.
 */
export const MACHINE_BLOCKS = [
  'frame',
  'pm',
  'pending',
  'outbox',
  'capacity',
  'agents',
  'recent',
  'activity',
  'board',
  'changes',
  'specs',
  'decisions',
] as const satisfies readonly BlockName[]

export interface DataOptions {
  root: string
  /** Explicit path to the teamsmith CLI; resolved from panel.js's own location when omitted. */
  teamCli?: string
  activity: boolean
  events: number
  timeoutMs?: number
  /** Which blocks to assemble; default = every block (the console's set). */
  blocks?: readonly BlockName[]
}

export interface DataResult {
  ok: boolean
  data?: PanelData
  activity?: ActivityBlock[]
  /** The console-only readers (`board`, `changes`, …), keyed by block name. */
  blocks?: PanelBlocks
  /** Blocks whose source failed, timed out or is unreadable in this snapshot (rendered as `—`). */
  degraded?: BlockName[]
  /** Why each degraded block is degraded (diagnostics; never rendered as data). */
  errors?: Partial<Record<BlockName, string>>
  error?: string
}

interface BlockSpec {
  /** How long a cached value stays fresh; the panel's tick rebuilds the expired ones. */
  ttlMs: number
  timeoutMs: number
  extraArgs?: (opts: DataOptions) => string[]
}

const BLOCK_SPECS: Record<BlockName, BlockSpec> = {
  // The banner and the queue — the console's "is there work" surface. The three actions invalidate
  // the cache explicitly (`refreshNow`), so the TTL only has to feel live, not be 3s.
  // The banner (project/interval/standby/clock): the cheapest block (~0.04s, one `date`) and the one
  // a human watches for the effect of an action. A TTL below the shortest cadence means every
  // cadence re-assembles it, so an outside change to the banner shows up within one cadence.
  frame: { ttlMs: 500, timeoutMs: 10000 },
  pm: { ttlMs: 9000, timeoutMs: 10000 },
  pending: { ttlMs: 15000, timeoutMs: 10000 },
  outbox: { ttlMs: 9000, timeoutMs: 10000 },
  capacity: { ttlMs: 9000, timeoutMs: 10000 },
  agents: { ttlMs: 15000, timeoutMs: 15000 },
  recent: { ttlMs: 9000, timeoutMs: 10000 },
  // The activity column is the design's 3s live view (the one block that must keep the cadence);
  // everything else trades freshness for the <1%-of-one-core red line. Measured on the reference
  // checkout: rebuilding every block on the 3s cadence put the pane process at ~1.2%, one Ink
  // `rerender` per cadence alone cost ~20ms, and the expensive readers (the report scan, the
  // per-agent git reads, `doctor`) each burn 0.2-0.5s of child CPU per rebuild.
  activity: {
    ttlMs: 3000,
    timeoutMs: 15000,
    extraArgs: (opts) => (opts.activity ? [] : ['--no-activity']),
  },
  // Console-only readers: the board parses every row of BOARD.md (73 rows on the reference
  // checkout), the patrol log grows every 15 minutes, and the OpenSpec-CLI blocks plus `doctor` are
  // the heaviest of all — they are far apart on purpose.
  board: { ttlMs: 15000, timeoutMs: 10000 },
  changes: { ttlMs: 180000, timeoutMs: 20000 },
  specs: { ttlMs: 180000, timeoutMs: 20000 },
  decisions: { ttlMs: 60000, timeoutMs: 10000 },
  outbox_list: { ttlMs: 9000, timeoutMs: 10000 },
  inbox: { ttlMs: 60000, timeoutMs: 10000 },
  patrol: { ttlMs: 15000, timeoutMs: 10000 },
  health: { ttlMs: 600000, timeoutMs: 30000 },
}



/**
 * Find `scripts/team` relative to the bundle. `panel.js` lives at `<skill>/scripts/panel/panel.js`;
 * running from source (`src/main.tsx`) is one directory deeper. `.js` and `.ts` sources share this.
 */
export function findTeamCli(here: string): string | null {
  for (const rel of ['../team', '../../team', '../../../team']) {
    const cand = resolve(join(here, rel))
    if (existsSync(cand)) return cand
  }
  return null
}

export function panelDirOf(importMetaUrl: string): string {
  return dirname(fileURLToPath(importMetaUrl))
}

interface BlockOutcome {
  ok: boolean
  value?: unknown
  error?: string
}

/** One block, one child, one timeout. Never throws and never blocks the loop. */
function runBlock(
  spec: BlockSpec,
  name: BlockName,
  opts: DataOptions,
  cli: string,
  children?: Set<ReturnType<typeof spawn>>,
): Promise<BlockOutcome> {
  const timeoutMs = opts.timeoutMs ?? spec.timeoutMs
  const extra = spec.extraArgs ? spec.extraArgs(opts) : []
  const args = [cli, '--root', opts.root, '__panel-data', '--block', name, '--events', String(opts.events), ...extra]
  return new Promise((resolve) => {
    let child: ReturnType<typeof spawn>
    try {
      child = spawn('bash', args, { cwd: opts.root, env: { ...process.env }, stdio: ['ignore', 'pipe', 'pipe'] })
      children?.add(child)
    } catch (e) {
      resolve({ ok: false, error: (e as Error).message })
      return
    }
    let out = ''
    let err = ''
    let settled = false
    const done = (outcome: BlockOutcome): void => {
      if (settled) return
      settled = true
      clearTimeout(timer)
      children?.delete(child)
      resolve(outcome)
    }
    const timer = setTimeout(() => {
      try {
        child.kill('SIGKILL')
      } catch {
        /* already gone */
      }
      done({ ok: false, error: `timed out after ${timeoutMs}ms` })
    }, timeoutMs)
    child.stdout?.on('data', (d: Buffer) => {
      out += String(d)
      if (out.length > 32 * 1024 * 1024) {
        try {
          child.kill('SIGKILL')
        } catch {
          /* already gone */
        }
        done({ ok: false, error: 'block output exceeded 32MB' })
      }
    })
    child.stderr?.on('data', (d: Buffer) => {
      err += String(d)
    })
    child.on('error', (e) => done({ ok: false, error: e.message }))
    child.on('close', (code) => {
      if (settled) return
      const tail = err.trim().split('\n').filter(Boolean).slice(-2).join(' · ')
      if (code !== 0) {
        done({ ok: false, error: `rc=${code ?? '?'}${tail ? `: ${tail}` : ''}` })
        return
      }
      const raw = out.trim()
      if (!raw) {
        done({ ok: false, error: 'no output' })
        return
      }
      try {
        done({ ok: true, value: sanitizeDeep(JSON.parse(raw)) })
      } catch (e) {
        done({ ok: false, error: `invalid JSON: ${(e as Error).message}` })
      }
    })
  })
}

/** Write one block's value into the panel object it owns. */
function applyBlock(data: PanelData, name: BlockName, value: unknown): void {
  const v = (value ?? {}) as Record<string, unknown>
  switch (name) {
    case 'frame': {
      if (typeof v.project === 'string') data.project = v.project
      if (typeof v.timestamp === 'string') data.timestamp = v.timestamp
      if (typeof v.interval === 'number') data.interval = v.interval
      if (v.standby && typeof v.standby === 'object') data.standby = v.standby as PanelData['standby']
      if (typeof v.activity_source === 'string') data.activity_source = v.activity_source
      return
    }
    case 'pm':
      data.pm = v as unknown as PanelData['pm']
      return
    case 'pending':
      data.pending = v as unknown as PanelData['pending']
      return
    case 'outbox':
      data.outbox = v as unknown as PanelData['outbox']
      return
    case 'capacity':
      data.capacity = v as unknown as PanelData['capacity']
      return
    case 'agents':
      data.agents = Array.isArray(v) ? (v as PanelData['agents']) : []
      return
    case 'recent':
      data.recent = Array.isArray(v) ? (v as string[]) : []
      return
    case 'activity':
      return // merged separately (it is the data layer's blocks, not a panel field)
  }
}

/**
 * `elapsed` / `idle` / the event count come from the data layer's block for the same agent. They
 * are JSON-only fields: the table never shows the uptime token (the requirement pins that), but
 * `team monitor --json` keeps them.
 */
export function mergeActivity(panel: PanelData, activity: ActivityBlock[]): void {
  const byName = new Map(activity.map((b) => [String(b?.name ?? ''), b]))
  for (const a of panel.agents ?? []) {
    const b = byName.get(String(a.name))
    if (!b) continue
    if (typeof b.elapsed === 'string') a.elapsed = b.elapsed
    if (typeof b.idle === 'string') a.idle = b.idle
    if (typeof b.count === 'number') a.events = b.count
  }
}

interface BlockState {
  value?: unknown
  /** Epoch ms of the last successful build (0 = never). */
  at: number
  error?: string
}

const PANEL_BLOCK_NAMES: readonly BlockName[] = ['board', 'changes', 'specs', 'decisions', 'outbox_list', 'inbox', 'patrol', 'health']

function isPanelBlock(name: BlockName): boolean {
  return PANEL_BLOCK_NAMES.includes(name)
}

function emptyPanel(): PanelData {
  return { project: '', timestamp: '', interval: 0 }
}

export interface PanelCache {
  /** The current frame data. Pure: reads memory, never spawns anything. */
  snapshot(): DataResult
  /** Rebuild the expired blocks (or all of them with `force`), in parallel. */
  refresh(refreshOpts?: { force?: boolean }): Promise<DataResult>
  /** Kill anything still in flight (process exit, tests). */
  dispose(): void
}

export function createPanelCache(opts: DataOptions): PanelCache {
  const cli = opts.teamCli || findTeamCli(panelDirOf(import.meta.url))
  const wanted = opts.blocks ?? BLOCK_NAMES
  const state: Record<string, BlockState> = {}
  for (const name of BLOCK_NAMES) state[name] = { at: 0 }
  let inFlight: Partial<Record<BlockName, Promise<void>>> = {}
  const children = new Set<ReturnType<typeof spawn>>()

  function snapshot(): DataResult {
    if (!cli) {
      return { ok: false, error: 'panel: cannot locate the teamsmith CLI next to the bundle (scripts/team)' }
    }
    const data = emptyPanel()
    const blocks: PanelBlocks = {}
    const degraded: BlockName[] = []
    const errors: Partial<Record<BlockName, string>> = {}
    let activity: ActivityBlock[] = []
    for (const name of BLOCK_NAMES) {
      if (!wanted.includes(name)) continue
      const s = state[name]
      const fresh = s.at > 0 && !s.error
      if (!fresh) {
        degraded.push(name)
        if (s.error) errors[name] = s.error
        continue
      }
      if (name === 'activity') {
        activity = Array.isArray(s.value) ? (s.value as ActivityBlock[]) : []
        continue
      }
      if (isPanelBlock(name)) {
        ;(blocks as Record<string, unknown>)[name] = s.value
        continue
      }
      applyBlock(data, name, s.value)
    }
    mergeActivity(data, activity)
    return { ok: true, data, activity, blocks, degraded, errors }
  }

  function build(name: BlockName): Promise<void> {
    return runBlock(BLOCK_SPECS[name], name, opts, cli as string, children).then((outcome) => {
      const s = state[name]
      if (outcome.ok) {
        s.value = outcome.value
        s.at = Date.now()
        s.error = undefined
      } else {
        // A block that failed is not dressed in last week's number: it renders `—` until the
        // next successful build (the design's stale-data trade-off, made explicit).
        s.error = outcome.error || 'failed'
      }
    })
  }

  async function refresh(refreshOpts: { force?: boolean } = {}): Promise<DataResult> {
    if (!cli) return snapshot()
    const now = Date.now()
    for (const name of BLOCK_NAMES) {
      if (!wanted.includes(name)) continue
      const s = state[name]
      const due = refreshOpts.force || s.at === 0 || now - s.at >= BLOCK_SPECS[name].ttlMs
      if (!due) continue
      if (inFlight[name]) continue
      inFlight[name] = build(name).finally(() => {
        delete inFlight[name]
      })
    }
    // Already-running builds count as this refresh's work: the caller wants a settled snapshot.
    await Promise.all(BLOCK_NAMES.map((name) => inFlight[name]).filter(Boolean))
    return snapshot()
  }

  return {
    snapshot,
    refresh,
    dispose(): void {
      for (const child of children) {
        try {
          child.kill('SIGKILL')
        } catch {
          /* already gone */
        }
      }
      children.clear()
    },
  }
}

/**
 * One complete assembly: every block, in parallel, with each block's own timeout. This is the
 * one-shot path (`--print` / `--json` / the first TUI frame) and the entry the fixtures drive.
 */
export async function loadPanelData(opts: DataOptions): Promise<DataResult> {
  const cli = opts.teamCli || findTeamCli(panelDirOf(import.meta.url))
  if (!cli) {
    return { ok: false, error: 'panel: cannot locate the teamsmith CLI next to the bundle (scripts/team)' }
  }
  const cache = createPanelCache({ ...opts, teamCli: cli })
  const res = await cache.refresh({ force: true })
  cache.dispose()
  if (!res.ok) return res
  return res
}

/**
 * One patrol tick: `team watch --once`, output appended to the tick log and the log trimmed at
 * 200 lines — the same tick (and the same trim) the bash loop performed, now owned by the run
 * that draws the panel. Asynchronous for the same reason the readers are: a tick must not freeze
 * the input line.
 */
export function runTick(
  cli: string,
  root: string,
  tickLog: string,
  timeoutMs = 180000,
): Promise<{ ok: boolean; output: string }> {
  return new Promise((resolve) => {
    let child: ReturnType<typeof spawn>
    try {
      child = spawn('bash', [cli, '--root', root, 'watch', '--once'], {
        cwd: root,
        env: { ...process.env },
        stdio: ['ignore', 'pipe', 'pipe'],
      })
    } catch (e) {
      resolve({ ok: false, output: (e as Error).message })
      return
    }
    let out = ''
    let settled = false
    const done = (ok: boolean): void => {
      if (settled) return
      settled = true
      clearTimeout(timer)
      try {
        appendFileSync(tickLog, out)
        const lines = readFileSync(tickLog, 'utf8').split('\n')
        if (lines.length > 200) writeFileSync(tickLog, `${lines.slice(-201).join('\n')}`)
      } catch {
        // A tick that cannot write its log must not kill the panel; the tick's own state writes
        // are what the contract pins.
      }
      resolve({ ok, output: out })
    }
    const timer = setTimeout(() => {
      try {
        child.kill('SIGKILL')
      } catch {
        /* already gone */
      }
      done(false)
    }, timeoutMs)
    child.stdout?.on('data', (d: Buffer) => {
      out += String(d)
    })
    child.stderr?.on('data', (d: Buffer) => {
      out += String(d)
    })
    child.on('error', () => done(false))
    child.on('close', (code) => done(code === 0))
  })
}
