// The panel's only data path.
//
// Two subprocesses, both re-run per frame:
//   * `team __panel-data` — the bash readers (`team_pm_state`, `team_pending_*`, the queue
//     directory, `team_git_cols`, `team_session_tokens_est`, the capacity log) composed into one
//     JSON object. The panel never reads a state file or runs git itself.
//   * the tick (`team watch --once`) — owned by the run, one child per due tick.
//
// `monitor.mjs` is spawned by the data command, not here: it stays the data layer, its `--json`
// contract untouched, and the panel consumes its result as a value inside the same object.

import { spawnSync } from 'node:child_process'
import { appendFileSync, existsSync, readFileSync, writeFileSync } from 'node:fs'
import { dirname, join, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import { sanitizeDeep } from './sanitize.js'
import type { ActivityBlock, PanelData } from './types.js'

export interface DataOptions {
  root: string
  /** Explicit path to the teamsmith CLI; resolved from panel.js's own location when omitted. */
  teamCli?: string
  activity: boolean
  events: number
  timeoutMs?: number
}

export interface DataResult {
  ok: boolean
  data?: PanelData
  activity?: ActivityBlock[]
  error?: string
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

function spawnTeam(args: string[], cwd: string, timeoutMs: number) {
  return spawnSync('bash', args, {
    cwd,
    encoding: 'utf8',
    timeout: timeoutMs,
    maxBuffer: 32 * 1024 * 1024,
    env: { ...process.env },
  })
}

/**
 * Read the panel fields plus (optionally) the activity blocks. Every string is sanitized here,
 * before anything is laid out or printed: this is the panel's own pass, on top of the data
 * layer's.
 */
export function loadPanelData(opts: DataOptions): DataResult {
  const cli = opts.teamCli || findTeamCli(panelDirOf(import.meta.url))
  if (!cli) {
    return { ok: false, error: 'panel: cannot locate the teamsmith CLI next to the bundle (scripts/team)' }
  }
  const timeout = opts.timeoutMs ?? 20000
  const args = [cli, '--root', opts.root, '__panel-data', '--events', String(opts.events)]
  if (!opts.activity) args.push('--no-activity')
  const r = spawnTeam(args, opts.root, timeout)
  if (r.error) {
    const e = r.error as NodeJS.ErrnoException
    return { ok: false, error: `panel: data read failed: ${e.message}` }
  }
  if (r.status !== 0) {
    const tail = String(r.stderr || r.stdout || '')
      .trim()
      .split('\n')
      .filter(Boolean)
      .slice(-2)
      .join(' · ')
    return { ok: false, error: `panel: data read failed (rc=${r.status ?? '?'})${tail ? `: ${tail}` : ''}` }
  }
  const raw = String(r.stdout ?? '').trim()
  if (!raw) return { ok: false, error: 'panel: data read returned nothing' }
  let parsed: { panel?: PanelData; activity?: ActivityBlock[] }
  try {
    parsed = JSON.parse(raw)
  } catch (e) {
    return { ok: false, error: `panel: data read returned invalid JSON: ${(e as Error).message}` }
  }
  if (!parsed || typeof parsed !== 'object' || !parsed.panel) {
    return { ok: false, error: 'panel: data read returned no panel object' }
  }
  const data = sanitizeDeep(parsed.panel)
  const activity = sanitizeDeep(Array.isArray(parsed.activity) ? parsed.activity : [])
  mergeActivity(data, activity)
  return { ok: true, data, activity }
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

/**
 * One patrol tick: `team watch --once`, output appended to the tick log and the log trimmed at
 * 200 lines — the same tick (and the same trim) the bash loop performed, now owned by the run
 * that draws the panel.
 */
export function runTick(cli: string, root: string, tickLog: string, timeoutMs = 180000): { ok: boolean; output: string } {
  const r = spawnTeam([cli, '--root', root, 'watch', '--once'], root, timeoutMs)
  const output = `${r.stdout ?? ''}${r.stderr ?? ''}`
  try {
    appendFileSync(tickLog, output)
    const lines = readFileSync(tickLog, 'utf8').split('\n')
    if (lines.length > 200) {
      writeFileSync(tickLog, `${lines.slice(-201).join('\n')}`)
    }
  } catch {
    // A tick that cannot write its log must not kill the panel; the tick's own state writes are
    // what the contract pins.
  }
  return { ok: r.status === 0, output }
}
