#!/usr/bin/env node
/**
 * teamsmith 监视器（可由 node/bun 运行）：把每个 agent 的活动渲染成一段流。
 * 灵感来自 <peer-project> 的 scripts/pm-watch.py，但这里做成项目无关：
 *   - agent 列表来自 <root>/.worktrees/<agent>/（外加 PM 自己的会话）
 *   - **Pi（默认）**：会话文件按 Pi 的目录规则推出（--<cwd 去前导 / 并把 / 换成 -->--）
 *   - **其它 TUI agent**：配了 --log-glob / TEAM_AGENT_LOG_GLOB 时，显示最新匹配文件的尾部
 *     （支持 `~`、绝对/相对路径、`*` `?` `**`，以及 `{agent}` = agent 名）
 *   - 两者都没有时只显示「无会话」，不影响上面的团队状态面板
 *   - 每段显示：状态 emoji + 名字 + 分支(+脏标记) + 已运行/空闲/事件数 + 最近几条事件
 *
 *   node scripts/monitor.mjs --root <proj> [--events 4] [--only dev,verify] [--log-glob '<glob>'] [--json]
 */
import { readdirSync, readFileSync, statSync, existsSync } from 'node:fs'
import { execFileSync } from 'node:child_process'
import { homedir } from 'node:os'
import { join } from 'node:path'

const MAX_TEXT = 150
const STALE_SECONDS = 3600
const ACTIVE_SECONDS = 120

function arg(name, fallback) {
  const i = process.argv.indexOf(`--${name}`)
  if (i === -1) return fallback
  const v = process.argv[i + 1]
  return v && !v.startsWith('--') ? v : true
}

const root = String(arg('root', process.cwd()))
const eventsPerAgent = Number(arg('events', 4)) || 4
const only = String(arg('only', '') || '').split(',').filter(Boolean)
const asJson = arg('json', false) === true
// 非 Pi 的 agent：显示配置的日志/会话文件的尾部（空 = 不启用，只跟 Pi 会话）
const logGlob = String(arg('log-glob', process.env.TEAM_AGENT_LOG_GLOB || '') || '')
const sessionsRoot = join(homedir(), '.pi', 'agent', 'sessions')

function run(cmd, args, cwd) {
  try {
    return execFileSync(cmd, args, { cwd, encoding: 'utf8', timeout: 5000 }).trim()
  } catch {
    return ''
  }
}

function sessionDirFor(cwd) {
  if (!cwd) return ''
  return join(sessionsRoot, `--${cwd.replace(/^\//, '').replace(/\//g, '-')}--`)
}

function newestSession(dir, match) {
  try {
    const files = readdirSync(dir)
      .filter(f => f.endsWith('.jsonl') && (!match || f.includes(match)))
      .map(f => ({ f, m: statSync(join(dir, f)).mtimeMs }))
      .sort((a, b) => b.m - a.m)
    return files.length ? { path: join(dir, files[0].f), mtime: files[0].m / 1000 } : null
  } catch {
    return null
  }
}

const icons = { say: '💬', run: '🔧', out: '  ↳', think: '🤔', user: '👤' }

function readSession(path) {
  const events = []
  let cwd = ''
  let started = null
  let text
  try {
    text = readFileSync(path, 'utf8')
  } catch {
    return { events, cwd, started }
  }
  for (const line of text.split('\n')) {
    if (!line.trim()) continue
    let entry
    try {
      entry = JSON.parse(line)
    } catch {
      continue
    }
    if (entry.type === 'session' && !started) {
      cwd = String(entry.cwd || '')
      started = entry.timestamp ? new Date(entry.timestamp) : null
    }
    if (entry.type !== 'message') continue
    const message = entry.message || {}
    const role = message.role
    const ts = String(entry.timestamp || '')
    const push = (kind, detail) => {
      const d = String(detail ?? '').replace(/\s+/g, ' ').trim().slice(0, MAX_TEXT)
      if (d) events.push({ ts, kind, text: d })
    }
    if (role === 'user') {
      for (const part of message.content || []) {
        if (part && typeof part === 'object' && part.type === 'text') push('user', part.text)
      }
      continue
    }
    for (const part of message.content || []) {
      if (!part || typeof part !== 'object') continue
      if (part.type === 'text') push('say', part.text)
      else if (part.type === 'thinking') push('think', part.thinking)
      else if (part.type === 'toolCall') {
        const a = part.args || {}
        const key = a.command || a.path || a.pattern || a.query || ''
        push('run', `${part.name || '?'} ${key}`)
      } else if (part.type === 'toolResult' || part.type === 'tool') {
        push('out', typeof part.text === 'string' ? part.text : JSON.stringify(part).slice(0, 100))
      }
    }
  }
  return { events, cwd, started }
}

// ---------------------------------------------------------------- 日志通配（非 Pi agent）
// 不引入依赖：自己展开 `*` `?` `**` 就够用（monitor 只做展示，不需要精确的 glob 语义）。
function readdirSafe(dir) {
  try {
    return readdirSync(dir, { withFileTypes: true })
  } catch {
    return []
  }
}

function walkGlob(dir, segs, out) {
  if (!segs.length) return
  const [head, ...rest] = segs
  if (head === '**') {
    walkGlob(dir, rest, out)
    for (const e of readdirSafe(dir)) {
      if (e.isDirectory()) walkGlob(join(dir, e.name), segs, out)
    }
    return
  }
  if (/[*?]/.test(head)) {
    const re = new RegExp(
      '^' + head.replace(/[.+^${}()|[\]\\]/g, '\\$&').replace(/\*/g, '[^/]*').replace(/\?/g, '[^/]') + '$',
    )
    for (const e of readdirSafe(dir)) {
      if (!re.test(e.name)) continue
      const next = join(dir, e.name)
      if (!rest.length) {
        if (e.isFile()) out.push(next)
      } else if (e.isDirectory()) {
        walkGlob(next, rest, out)
      }
    }
    return
  }
  const next = join(dir, head)
  let st = null
  try {
    st = statSync(next)
  } catch {
    return
  }
  if (!rest.length) {
    if (st.isFile()) out.push(next)
    return
  }
  if (st.isDirectory()) walkGlob(next, rest, out)
}

function expandGlob(pattern, vars) {
  if (!pattern) return []
  let p = String(pattern).replace(/\{agent\}/g, (vars && vars.agent) || '')
  if (p.startsWith('~')) p = join(homedir(), p.slice(1))
  if (!p.startsWith('/')) p = join(process.cwd(), p)
  const out = []
  walkGlob('/', p.split('/').filter(Boolean), out)
  return out
}

// 用最新匹配文件的尾部当这个 agent 的“活动流”（读不到就返回 null，调用方退回「无会话」）
function logActivity(name, cwd) {
  const files = expandGlob(logGlob, { agent: name === 'pm (PM)' ? 'pm' : name })
  const stamped = files
    .map(f => {
      try {
        return { f, m: statSync(f).mtimeMs }
      } catch {
        return null
      }
    })
    .filter(Boolean)
    .sort((a, b) => b.m - a.m)
  if (!stamped.length) return null
  const newest = stamped[0]
  const age = Date.now() / 1000 - newest.m / 1000
  let lines = []
  try {
    lines = readFileSync(newest.f, 'utf8').split('\n').filter(l => l.trim())
  } catch {
    lines = []
  }
  const events = lines.slice(-eventsPerAgent).map(l => ({
    ts: '',
    kind: 'out',
    text: String(l).replace(/\s+/g, ' ').trim().slice(0, MAX_TEXT),
  }))
  const status = age > STALE_SECONDS ? '⚫ 陈旧' : age < ACTIVE_SECONDS ? '🟢 活跃' : '🟡 静默'
  return {
    source: 'log',
    logPath: newest.f,
    status,
    events: age > STALE_SECONDS ? [] : events,
    idle: fmtDur(age),
    count: lines.length,
    branch: branchOf(cwd || root),
    meta: age > STALE_SECONDS ? `最后活动 ${fmtDur(age)} 前（日志 ${newest.f}）` : '',
  }
}

function fmtDur(seconds) {
  const s = Math.max(0, Math.floor(seconds))
  if (s < 60) return `${s}s`
  if (s < 3600) return `${Math.floor(s / 60)}m${String(s % 60).padStart(2, '0')}s`
  return `${Math.floor(s / 3600)}h${String(Math.floor((s % 3600) / 60)).padStart(2, '0')}m`
}

function branchOf(cwd) {
  if (!cwd) return '?'
  const b = run('git', ['-C', cwd, 'rev-parse', '--abbrev-ref', 'HEAD'])
  const dirty = run('git', ['-C', cwd, 'status', '--porcelain'])
  return b ? `${b}${dirty ? '*' : ''}` : '?'
}

function targets() {
  const list = []
  if (!only.length || only.includes('pm')) list.push({ name: 'pm (PM)', cwd: root })
  let dirs = []
  try {
    dirs = readdirSync(join(root, '.worktrees'), { withFileTypes: true })
      .filter(d => d.isDirectory() && !d.name.startsWith('review-'))
      .map(d => d.name)
      .sort()
  } catch {
    /* 没有 worktrees */
  }
  for (const name of dirs) {
    if (only.length && !only.includes(name)) continue
    list.push({ name, cwd: join(root, '.worktrees', name) })
  }
  return list
}

const now = Date.now()
const blocks = []
for (const t of targets()) {
  // ① 显式配了日志通配就先看它（非 Pi adapter 的意图很明确）
  // ② 否则找 Pi 会话：先找“agent 在自己 worktree 里跑”的，再退一步找主仓库目录下 session id 形如 <session>-<agent> 的
  const logBlock = logGlob ? logActivity(t.name, t.cwd) : null
  if (logBlock) {
    blocks.push({ ...t, ...logBlock })
    continue
  }
  const dir = sessionDirFor(t.cwd)
  const found = newestSession(dir) || newestSession(sessionDirFor(root), `-${t.name}.jsonl`) || null
  if (!found) {
    const hint = logGlob
      ? `（无 pi 会话；TEAM_AGENT_LOG_GLOB 未匹配到文件：${logGlob}）`
      : '（无 pi 会话）'
    blocks.push({ ...t, status: '⚫ 无会话', source: 'none', events: [], meta: hint })
    continue
  }
  const age = now / 1000 - found.mtime
  if (age > STALE_SECONDS) {
    blocks.push({ ...t, status: '⚫ 陈旧', source: 'pi', events: [], meta: `最后活动 ${fmtDur(age)} 前` })
    continue
  }
  const { events, cwd, started } = readSession(found.path)
  const last = events.length ? new Date(events[events.length - 1].ts) : started
  const elapsed = started ? fmtDur((now - started.getTime()) / 1000) : '?'
  const idle = last ? fmtDur((now - last.getTime()) / 1000) : '?'
  const status = age < ACTIVE_SECONDS ? '🟢 活跃' : '🟡 静默'
  blocks.push({
    ...t,
    source: 'pi',
    status,
    elapsed,
    idle,
    count: events.length,
    branch: branchOf(cwd || t.cwd),
    events: events.slice(-eventsPerAgent),
  })
}

if (asJson) {
  console.log(JSON.stringify(blocks, null, 2))
} else {
  const width = 112
  if (!blocks.length) {
    console.log('（没有可监视的 agent：先 team add-agent <名字>）')
  }
  for (const b of blocks) {
    if (b.meta !== undefined && b.count === undefined) {
      console.log(`${b.status} ${b.name}`.padEnd(40) + (b.meta ? `  ${b.meta}` : ''))
      console.log('-'.repeat(width))
      continue
    }
    if (b.source === 'log') {
      console.log(
        `${b.status} ${b.name.padEnd(20)} [${b.branch}]  日志尾部 ${b.logPath} · 空闲 ${b.idle} · 行 ${b.count}`,
      )
    } else {
      console.log(
        `${b.status} ${b.name.padEnd(20)} [${b.branch}]  已运行 ${b.elapsed} · 空闲 ${b.idle} · 事件 ${b.count}`,
      )
    }
    for (const e of b.events) {
      const clock = e.ts.length >= 19 ? e.ts.slice(11, 19) : e.ts
      console.log(`     ${clock} ${icons[e.kind] || '·'} ${e.text}`)
    }
    console.log('-'.repeat(width))
  }
  if (!logGlob && blocks.length && blocks.every(b => b.source === 'none')) {
    console.log(
      '  （没有 Pi 会话文件；换用其它 TUI agent 时可设 TEAM_AGENT_LOG_GLOB，让活动流显示日志尾部）',
    )
  }
}
