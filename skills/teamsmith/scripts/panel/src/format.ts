// Small formatters shared by the text frame and the Ink frame.

export const GLYPH: Record<string, string> = {
  running: '●',
  starting: '…',
  exited: '○',
  absent: '·',
  foreign: '○',
  unknown: '○',
}

export const PM_TEXT: Record<string, string> = {
  running: '在运行',
  starting: '正在启动',
  absent: '未在跑',
  foreign: '别的项目占着',
  unknown: '非 PM 进程',
}

export const AGENT_TEXT: Record<string, string> = {
  running: '在跑',
  exited: '已退出',
  absent: '无窗口',
}

export function fmtMB(mb: number | null | undefined): string {
  if (mb == null || Number.isNaN(mb)) return '?'
  return mb >= 1024 ? `${(mb / 1024).toFixed(1)}G` : `${Math.round(mb)}M`
}

export function fmtAge(s: number | null | undefined): string {
  if (s == null || Number.isNaN(s)) return '-'
  if (s < 60) return `${Math.floor(s)}s`
  if (s < 3600) return `${Math.floor(s / 60)}m`
  return `${Math.floor(s / 3600)}h`
}

const SPARK = '▁▂▃▄▅▆▇█'

/** Mini chart from a series (last `width` samples); '' when there is nothing to draw. */
export function sparkline(values: number[], width: number): string {
  if (!values || !values.length || width <= 0) return ''
  const v = values.slice(-width).filter((n) => typeof n === 'number' && !Number.isNaN(n))
  if (!v.length) return ''
  const lo = Math.min(...v)
  const hi = Math.max(...v)
  const span = hi - lo || 1
  return v
    .map((n) => SPARK[Math.min(SPARK.length - 1, Math.floor(((n - lo) / span) * (SPARK.length - 1)))])
    .join('')
}

/** 'HH:MM:SS' out of the panel's timestamp (`2026-09-16T10:00:00Z`); the raw string when it does not fit. */
export function clockOf(timestamp: string): string {
  const m = /T(\d{2}:\d{2}:\d{2})/.exec(timestamp || '')
  return m ? m[1] : timestamp
}

/** Shorten a branch name for the table (path prefixes are noise; the tail is the identity). */
export function shortBranch(branch: string, max: number): string {
  if (!branch || branch === '-') return '-'
  const b = branch.replace(/^(refs\/heads\/|task\/|agent\/)/, '')
  return b.length > max ? `…${b.slice(b.length - (max - 1))}` : b
}
