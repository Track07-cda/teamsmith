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
 *   node scripts/monitor.mjs --root <proj> [--events 4] [--only dev,verify] [--log-glob '<glob>']
 *                            [--log-tail-bytes 65536] [--json]
 *
 * 显示安全（日志是**不可信输入**）：
 *   - **只读尾窗**，绝不整读：日志尾部最多读 --log-tail-bytes / TEAM_AGENT_LOG_TAIL_BYTES
 *     字节（默认 64KiB=65536，硬上限 1MiB=1048576，超了夹住并警告）；Pi 会话是
 *     「头部窗口 64KiB（取 session 头）+ 尾窗」（两者都是常量级内存）。
 *     看门狗每轮、每个 agent 都会跑这个，GB 级日志不能把它（和 PM 机器）压垮。
 *   - 渲染前剥掉控制序列（ANSI/CSI/OSC/C1、CR/BEL/BS、双向控制字符），
 *     显示**文本**而不是控制字节：OSC 能改窗口标题、清屏、写剪贴板。
 *   - 读不到的文件（权限/FIFO/设备/已被删/二进制）降级成「不可用 + 原因」，不崩、不挂死、不静默。
 */
import {
  readdirSync,
  statSync,
  lstatSync,
  openSync,
  closeSync,
  readSync,
  fstatSync,
  constants,
} from 'node:fs'
import { execFileSync } from 'node:child_process'
import { homedir } from 'node:os'
import { join } from 'node:path'

const MAX_TEXT = 150
const STALE_SECONDS = 3600
const ACTIVE_SECONDS = 120
// 只读窗口（字节）。默认 64KiB 足够铺满 --events 行；硬上限 1MiB 防止有人配出「借尾部之名整读」。
const TAIL_DEFAULT_BYTES = 64 * 1024
const TAIL_CAP_BYTES = 1024 * 1024
// Pi 会话：头部窗口用来取 session 头（cwd/开始时间），尾部窗口用来取最近消息；中间那段直接跳过。
const SESSION_HEAD_BYTES = 64 * 1024

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

// ---------------------------------------------------------------- 显示安全：剥掉控制序列
// 显示文本，不显示控制字节。日志/会话内容都可能是别人写的：
//   OSC（`ESC ]` … BEL/ST）：改窗口标题、写剪贴板（OSC 52）、超链接；CSI（`ESC [`）：清屏/染色/移动光标；
//   裸 ESC、BEL、BS、CR：覆盖或污染 PM 的终端；双向控制字符（U+202A–202E、U+2066–2069）：文本骗眼睛。
// 只保留 \n 与 \t（渲染时会再折叠成空格），其余控制字符全部剥掉。
const OSC_RE = /\u001B\][^\u0007\u001B]*(?:\u0007|\u001B\\)/g
const CSI_RE = /\u001B\[[0-?]*[ -/]*[@-~]/g
const C1_CSI_RE = /\u009B[0-?]*[ -/]*[@-~]/g
const ESC2_RE = /\u001B[@-Z\\-_]/g
const CTRL_RE = /[\u0000-\u0008\u000B-\u001F\u007F-\u009F\u200B\u200E\u200F\u202A-\u202E\u2060\u2066-\u2069\uFEFF]/g

function sanitize(value) {
  return String(value ?? '')
    .replace(OSC_RE, '')
    .replace(CSI_RE, '')
    .replace(C1_CSI_RE, '')
    .replace(ESC2_RE, '')
    .replace(CTRL_RE, '')
}

// 所有对外输出（文本与 --json 都是）走一遍，字段名也走（防文件名/分支名里夹控制字节）
function sanitizeDeep(value) {
  if (typeof value === 'string') return sanitize(value)
  if (Array.isArray(value)) return value.map(sanitizeDeep)
  if (value && typeof value === 'object') {
    const out = {}
    for (const [k, v] of Object.entries(value)) out[sanitize(k)] = sanitizeDeep(v)
    return out
  }
  return value
}

// ---------------------------------------------------------------- 只读窗口（字节数）
function tailLimitFrom(raw) {
  const def = `${TAIL_DEFAULT_BYTES}`
  if (raw === undefined || raw === null || raw === '' || raw === true) {
    const why = raw === true ? '--log-tail-bytes 需要一个字节数' : ''
    return { bytes: TAIL_DEFAULT_BYTES, note: why ? `${why}，回退到默认 ${def} 字节` : '' }
  }
  const n = Number(raw)
  if (!Number.isFinite(n) || n <= 0) {
    return { bytes: TAIL_DEFAULT_BYTES, note: `--log-tail-bytes / TEAM_AGENT_LOG_TAIL_BYTES 的值 ${JSON.stringify(String(raw))} 不是正整数，回退到默认 ${def} 字节` }
  }
  if (n > TAIL_CAP_BYTES) {
    return { bytes: TAIL_CAP_BYTES, note: `--log-tail-bytes 的值 ${Math.floor(n)} 超过硬上限，夹到 ${TAIL_CAP_BYTES} 字节` }
  }
  return { bytes: Math.floor(n), note: '' }
}

const tailLimitCfg = tailLimitFrom(arg('log-tail-bytes', process.env.TEAM_AGENT_LOG_TAIL_BYTES || ''))
const tailLimit = tailLimitCfg.bytes
if (tailLimitCfg.note) process.stderr.write(`monitor: ${sanitize(tailLimitCfg.note)}\n`)

// ---------------------------------------------------------------- 有界读取
function reasonFor(err) {
  const code = (err && (err.code || err.errno)) || ''
  const map = {
    EACCES: '权限不足（EACCES）',
    EPERM: '权限不足（EPERM）',
    ENOENT: '文件不存在了（ENOENT：读之前被删除或移走）',
    EISDIR: '是一个目录（EISDIR）',
    ELOOP: '符号链接循环（ELOOP）',
    ENXIO: '设备不可读（ENXIO）',
    ENAMETOOLONG: '路径过长（ENAMETOOLONG）',
    EMFILE: '打开的文件太多（EMFILE）',
    ENFILE: '系统打开的文件太多（ENFILE）',
    EIO: 'I/O 错误（EIO）',
  }
  if (code && map[code]) return map[code]
  const msg = err && err.message ? String(err.message) : 'unknown'
  return `读取失败（${code || msg}）`
}

// 只认**普通文件**：FIFO/设备/套接字一律拒绝（对 FIFO 调 readFileSync 会一直阻塞，
// 看门狗窗口就挂死了）。O_NONBLOCK + fstat 双保险，避免 stat 与 open 之间的竞态。
function openRegular(path) {
  let fd
  try {
    fd = openSync(path, constants.O_RDONLY | constants.O_NONBLOCK)
  } catch (err) {
    return { ok: false, reason: reasonFor(err) }
  }
  let st
  try {
    st = fstatSync(fd)
  } catch (err) {
    try { closeSync(fd) } catch { /* 关不掉就算了 */ }
    return { ok: false, reason: reasonFor(err) }
  }
  if (st.isDirectory()) {
    try { closeSync(fd) } catch { /* ignore */ }
    return { ok: false, reason: '是一个目录（不是日志文件）' }
  }
  if (!st.isFile()) {
    try { closeSync(fd) } catch { /* ignore */ }
    return { ok: false, reason: '不是普通文件（FIFO/设备/套接字），拒绝读取以免挂死' }
  }
  return { ok: true, fd, size: st.size }
}

// 读 [start, start+len) 这一段；文件被截断/还在写时允许短读
function readRange(fd, start, len) {
  if (!(len > 0)) return { buf: Buffer.alloc(0), error: null }
  const buf = Buffer.allocUnsafe(len)
  let off = 0
  while (off < len) {
    let n
    try {
      n = readSync(fd, buf, off, len - off, start + off)
    } catch (err) {
      return { buf: buf.subarray(0, off), error: reasonFor(err) }
    }
    if (n <= 0) break
    off += n
  }
  return { buf: buf.subarray(0, off), error: null }
}

function decodeText(buf) {
  return buf.toString('utf8')
}

// 日志尾部：最多读最后 limit 字节。文件比窗口小 → 整读（与历史行为逐字节一致）。
function readTailText(path, limit) {
  const opened = openRegular(path)
  if (!opened.ok) return { ok: false, reason: opened.reason }
  const size = opened.size
  const from = Math.max(0, size - limit)
  const { buf, error } = readRange(opened.fd, from, size - from)
  try { closeSync(opened.fd) } catch { /* ignore */ }
  if (error && !buf.length) return { ok: false, reason: error, size }
  const text = decodeText(buf)
  if (text.includes('\u0000')) return { ok: false, reason: '内容里有 NUL 字节（疑似二进制或空洞文件），不显示', size }
  let lines = text.split('\n')
  if (from > 0 && lines.length > 1) lines.shift()   // 窗口起点那半截行丢掉
  lines = lines.map(l => sanitize(l).replace(/\s+/g, ' ').trim()).filter(Boolean)
  return { ok: true, lines, size, bytes: buf.length, truncated: from > 0, limit }
}

function mtimeMs(path) {
  try {
    return statSync(path).mtimeMs
  } catch { /* 断链等：退回 lstat，至少还能报「不可读 + 原因」 */ }
  try {
    return lstatSync(path).mtimeMs
  } catch {
    return null
  }
}

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
      .map(f => ({ f, m: mtimeMs(join(dir, f)) }))
      .filter(e => e.m !== null)
      .sort((a, b) => b.m - a.m)
    return files.length ? { path: join(dir, files[0].f), mtime: files[0].m / 1000 } : null
  } catch {
    return null
  }
}

const icons = { say: '💬', run: '🔧', out: '  ↳', think: '🤔', user: '👤' }

// Pi 会话：头部窗口（session 头 + 前面几条，够了）+ 尾窗（最近的消息）。
// 以前是 readFileSync 整读：几十 MB 的会话在活动流一开就吃几十 MB 内存，且没有上限。
function readSession(path) {
  const events = []
  let cwd = ''
  let started = null
  const fail = reason => ({ ok: false, reason, events, cwd, started, file_bytes: null, bytes: 0, truncated: false })
  const opened = openRegular(path)
  if (!opened.ok) return fail(opened.reason)
  const size = opened.size
  const headLen = Math.min(SESSION_HEAD_BYTES, size)
  const head = readRange(opened.fd, 0, headLen)
  if (head.error && !head.buf.length) {
    try { closeSync(opened.fd) } catch { /* ignore */ }
    return fail(head.error)
  }
  const headText = decodeText(head.buf)
  if (headText.includes('\u0000')) {
    try { closeSync(opened.fd) } catch { /* ignore */ }
    return fail('内容里有 NUL 字节（疑似二进制），不显示')
  }
  const tailFrom = Math.max(headLen, size - tailLimit)   // 与头部窗口不重叠
  const tail = size > headLen ? readRange(opened.fd, tailFrom, size - tailFrom) : { buf: Buffer.alloc(0) }
  try { closeSync(opened.fd) } catch { /* ignore */ }

  const parseLine = (line, ts) => {
    if (!line.trim()) return
    let entry
    try {
      entry = JSON.parse(line)
    } catch {
      return
    }
    if (entry.type === 'session' && !started) {
      cwd = String(entry.cwd || '')
      started = entry.timestamp ? new Date(entry.timestamp) : null
      return
    }
    if (entry.type !== 'message') return
    const message = entry.message || {}
    const role = message.role
    const stamp = String(entry.timestamp || ts || '')
    const record = (kind, detail) => {
      const d = sanitize(String(detail ?? '')).replace(/\s+/g, ' ').trim().slice(0, MAX_TEXT)
      if (d) events.push({ ts: stamp, kind, text: d })
    }
    if (role === 'user') {
      for (const part of message.content || []) {
        if (part && typeof part === 'object' && part.type === 'text') record('user', part.text)
      }
      return
    }
    for (const part of message.content || []) {
      if (!part || typeof part !== 'object') continue
      if (part.type === 'text') record('say', part.text)
      else if (part.type === 'thinking') record('think', part.thinking)
      else if (part.type === 'toolCall') {
        const a = part.args || {}
        const key = a.command || a.path || a.pattern || a.query || ''
        record('run', `${part.name || '?'} ${key}`)
      } else if (part.type === 'toolResult' || part.type === 'tool') {
        record('out', typeof part.text === 'string' ? part.text : JSON.stringify(part).slice(0, 100))
      }
    }
  }
  // 头部：文件比窗口大时最后一行可能被切断，只吃完整行
  const headLines = headText.split('\n')
  if (size > headLen) headLines.pop()
  for (const line of headLines) parseLine(line)
  // 尾部：窗口起点在文件中间时丢掉半截行（末行没换行也照实显示——文件可能还在写）
  const tailLines = tail.buf.length ? decodeText(tail.buf).split('\n') : []
  if (tailFrom > 0 && tailLines.length > 1) tailLines.shift()
  for (const line of tailLines) parseLine(line)

  return {
    ok: true,
    reason: null,
    events,
    cwd,
    started,
    file_bytes: size,
    bytes: head.buf.length + tail.buf.length,
    truncated: size > head.buf.length + tail.buf.length,
  }
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
        // 目录不算「日志」；其余（普通文件、符号链接、FIFO、设备）都收进来，
        // 由读取端判定并给出原因 —— 静默过滤掉才是历史 bug（FIFO/设备/断链都变成「无会话」）
        if (!e.isDirectory()) out.push(next)
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
    if (!st.isDirectory()) out.push(next)
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

// 用最新匹配文件的尾部当这个 agent 的“活动流”（一个都没匹配到返回 null，调用方退回「无会话」；
// 匹配到了但读不到 → 「不可用 + 原因」）
function logActivity(name, cwd) {
  const files = expandGlob(logGlob, { agent: name === 'pm (PM)' ? 'pm' : name })
  const stamped = files
    .map(f => ({ f, m: mtimeMs(f) }))
    .filter(e => e.m !== null)
    .sort((a, b) => b.m - a.m)
  if (!stamped.length) return null
  const newest = stamped[0]
  const age = Date.now() / 1000 - newest.m / 1000
  const status = age > STALE_SECONDS ? '⚫ 陈旧' : age < ACTIVE_SECONDS ? '🟢 活跃' : '🟡 静默'
  const branch = branchOf(cwd || root)
  const read = readTailText(newest.f, tailLimit)
  if (!read.ok) {
    return {
      source: 'log',
      logPath: newest.f,
      status,
      available: false,
      reason: read.reason || '读取失败',
      events: [],
      idle: fmtDur(age),
      count: 0,
      branch,
      file_bytes: read.size ?? null,
      tail_bytes: 0,
      truncated: true,
      tail_limit: tailLimit,
      meta: `不可读：${read.reason || '读取失败'}`,
    }
  }
  const events = read.lines.slice(-eventsPerAgent).map(l => ({ ts: '', kind: 'out', text: l.slice(0, MAX_TEXT) }))
  return {
    source: 'log',
    logPath: newest.f,
    status,
    available: true,
    reason: null,
    events: age > STALE_SECONDS ? [] : events,
    idle: fmtDur(age),
    count: read.lines.length,
    branch,
    file_bytes: read.size,
    tail_bytes: read.bytes,
    truncated: read.truncated,
    tail_limit: tailLimit,
    meta: age > STALE_SECONDS ? `最后活动 ${fmtDur(age)} 前（日志 ${newest.f}）` : '',
  }
}

// 延后投递队列的一行摘要（delivery-guard）：队列为空返回空字符串。
// 队列文件格式是契约（见 scripts/lib/outbox.sh）：<epoch-ms>-<seq>-<target>.msg，年龄从文件名算。
function outboxSummary(root) {
  const dir = join(root, '.pi/team/state/outbox')
  const list = (p) => {
    try {
      return readdirSync(p).filter((n) => n.endsWith('.msg'))
    } catch {
      return []
    }
  }
  const active = list(dir)
  const held = list(join(dir, 'held'))
  const all = [...active, ...held].sort()
  if (!all.length) return ''
  const ms = Number(String(all[0]).split('-')[0])
  const age = Number.isFinite(ms) && ms > 0 ? fmtDur(Date.now() / 1000 - ms / 1000) : '?'
  return `outbox ${all.length} 条待投递（held ${held.length}）· 最老 ${age} · team outbox list`
}

function fmtDur(seconds) {
  const s = Math.max(0, Math.floor(seconds))
  if (s < 60) return `${s}s`
  if (s < 3600) return `${Math.floor(s / 60)}m${String(s % 60).padStart(2, '0')}s`
  return `${Math.floor(s / 3600)}h${String(Math.floor((s % 3600) / 60)).padStart(2, '0')}m`
}

function fmtBytes(n) {
  const v = Number(n)
  if (!Number.isFinite(v) || v < 0) return '?'
  if (v < 1024) return `${Math.round(v)}B`
  if (v < 1024 * 1024) return `${(v / 1024).toFixed(v < 10240 ? 1 : 0)}K`
  if (v < 1024 * 1024 * 1024) return `${(v / (1024 * 1024)).toFixed(1)}M`
  return `${(v / (1024 * 1024 * 1024)).toFixed(2)}G`
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
    // 一行式渲染（老形状：有 meta、没有 count）：陈旧就不再去读文件了
    blocks.push({ ...t, status: '⚫ 陈旧', source: 'pi', sessionPath: found.path, events: [], meta: `最后活动 ${fmtDur(age)} 前` })
    continue
  }
  const sess = readSession(found.path)
  if (!sess.ok) {
    blocks.push({
      ...t,
      source: 'pi',
      sessionPath: found.path,
      status: '⚫ 会话不可读',
      available: false,
      reason: sess.reason,
      events: [],
      count: 0,
      idle: fmtDur(age),
      branch: branchOf(sess.cwd || t.cwd),
      file_bytes: sess.file_bytes,
      truncated: false,
      meta: `会话不可读：${sess.reason}`,
    })
    continue
  }
  const { events, cwd, started } = sess
  const last = events.length ? new Date(events[events.length - 1].ts) : started
  const elapsed = started ? fmtDur((now - started.getTime()) / 1000) : '?'
  const idle = last ? fmtDur((now - last.getTime()) / 1000) : '?'
  const status = age < ACTIVE_SECONDS ? '🟢 活跃' : '🟡 静默'
  blocks.push({
    ...t,
    source: 'pi',
    sessionPath: found.path,
    status,
    available: true,
    reason: null,
    elapsed,
    idle,
    count: events.length,
    branch: branchOf(cwd || t.cwd),
    file_bytes: sess.file_bytes,
    tail_bytes: sess.bytes,
    truncated: sess.truncated,
    events: events.slice(-eventsPerAgent),
  })
}

// 对外输出统一走净化：文本模式与 --json 都是（JSON 里 \u001b 虽然会被转义，但显示它的是人）
const clean = sanitizeDeep(blocks)

if (asJson) {
  console.log(JSON.stringify(clean, null, 2))
} else {
  const width = 112
  // 延后投递（delivery-guard）：队列非空时补一行（空队列不加任何东西）。
  // 数据源就是队列目录本身：<root>/.pi/team/state/outbox/*.msg（held/ 里的也算）
  const obox = outboxSummary(root)
  if (obox) console.log(obox)
  if (!clean.length) {
    console.log('（没有可监视的 agent：先 team add-agent <名字>）')
  }
  for (const b of clean) {
    if (b.meta !== undefined && b.count === undefined) {
      console.log(`${b.status} ${b.name}`.padEnd(40) + (b.meta ? `  ${b.meta}` : ''))
      console.log('-'.repeat(width))
      continue
    }
    if (b.source === 'log') {
      if (b.available === false) {
        console.log(`${b.status} ${b.name.padEnd(20)} [${b.branch}]  日志不可读 ${b.logPath} · ${b.reason}`)
      } else {
        const bound = b.truncated ? ` · 只读尾部 ${fmtBytes(b.tail_limit)}/${fmtBytes(b.file_bytes)}` : ''
        console.log(
          `${b.status} ${b.name.padEnd(20)} [${b.branch}]  日志尾部 ${b.logPath} · 空闲 ${b.idle} · 行 ${b.count}${bound}`,
        )
      }
    } else if (b.available === false) {
      console.log(
        `${b.status} ${b.name.padEnd(20)} [${b.branch}]  会话不可读 ${b.sessionPath || ''} · ${b.reason}`,
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
  if (!logGlob && clean.length && clean.every(b => b.source === 'none')) {
    console.log(
      '  （没有 Pi 会话文件；换用其它 TUI agent 时可设 TEAM_AGENT_LOG_GLOB，让活动流显示日志尾部）',
    )
  }
}
