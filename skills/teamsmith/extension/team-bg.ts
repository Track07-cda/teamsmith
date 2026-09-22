/**
 * teamsmith · team-bg 扩展 — 团队机械的后台任务车道（零第三方依赖，不进用户会话）
 *
 * 解决的问题：一条长门禁/长构建会把整个回合占住。这里给 agent 两个工具：
 *   team_bg_run   起一个**脱离**子进程，立刻返回 job id + pid；输出落 <会话自己的根>/state/bg/<id>.log（有界，留尾段）
 *   team_bg_wait  收割：等到作业结束，把退出码 + 日志尾段内联返回；**收割过的作业完成时静默**
 *
 * 唤醒纪律（照 oh-my-pi issue #689 的两条教训，E8 探针实测过）：
 *   - 已收割 → 静默：结果已经在 agent 手里，再叫它就是白烧一个回合；
 *   - 多条同时完成 → 合并成**一条** followUp 消息（triggerTurn），且只在 agent 空闲时投递。
 *
 * 生命周期（Pi 文档的硬约束）：factory 里不起任何后台资源；日志裁剪定时器在第一次真正跑作业时才建、
 * session_shutdown 里清掉。作业是 detached 的：session 重启/退出**不杀**它们，日志与账本留在 state/。
 *
 * 作用域（M30 修正）：本扩展的产物是**会话本地**的 —— 日志/账本跟着会话自己的工作树走
 * （见 findRoot 的注释）；收件箱/投递那类**接口**状态不归它管（那是 inbox-watch 的活，它待在主工作树）。
 * 只认本扩展自己 job 表里的作业（不订阅任何第三方包的事件总线）；只服务 dispatch/PM 启动链注入 `-e`
 * 的团队会话 —— 用户自己的 pi 会话没有它。
 */
import type { ExtensionAPI } from '@earendil-works/pi-coding-agent'
import { execFileSync, spawn } from 'node:child_process'
import { appendFileSync, closeSync, existsSync, mkdirSync, openSync, readSync, statSync, writeFileSync } from 'node:fs'
import { dirname, join, resolve } from 'node:path'

type Job = {
  id: string
  pid: number
  command: string
  cwd: string
  log: string
  startedAt: number
  done: boolean
  exitCode: number | null
  harvested: boolean // 结果已经交到 agent 手里（或正在等它）
  notified: boolean // 完成通知已经投递过（一条通知最多一次）
  waiters: Array<() => void>
}

const DEFAULT_MAX_BYTES = 512 * 1024 // 每个作业日志的磁盘上限（可被 TEAM_BG_LOG_MAX_BYTES 覆盖）
const TRIM_EVERY_MS = 2000
const MERGE_WINDOW_MS = 250 // 同一拍完成的作业合并成一条通知
const DEFAULT_WAIT_MS = 15 * 60 * 1000
const TAIL_BYTES = 8 * 1024
const TRUNC_MARK = '[team-bg] truncated: output exceeded the log cap, earlier output dropped.'
const CMD_DISPLAY_MAX = 100 // 结果文本里命令的码点上限（超出 → 前 100 码点 + …）
const CMD_ELLIPSIS = '…'

/**
 * 定位**本会话自己的根**：team-bg 的产物（作业日志、账本、合并窗口）都是会话本地的，
 * 必须落在会话自己的工作树里 —— worktree 会话 = 它的 worktree，主工作树会话 = 主工作树。
 *
 * 为什么不用 `--git-common-dir`（M27 的旧写法，M30 修正）：那个路径指向**主工作树**（linked worktree 的
 * .git 是主仓库里的一个文件），于是 worker 在 worktree 里跑的长门禁日志会被写进共享账本所在地
 * `.pi/team/state/bg/`（M30 现场：门禁自己的 stdout 里带着各段夹具的名字，把「把门禁放后台跑」变成了
 * 下一次 M16 隔离断言的假泄漏）。会话本地的产物写进自己的工作树，也符合「只改自己的目录」。
 *
 * 顺序：会话 cwd 的工作树（有 config.sh）> TEAM_ROOT（显式）> 向上查找 > git 主工作树（最后的兜底：
 * 工作树里没有 config.sh 的旧分支/目录在项目外时，宁可写共享根，也不要让工具直接不可用 ——
 * `team_bg_run` 的返回里点明了 log 的真实路径）。TEAM_STATE_DIR 仍然压过这一切。
 */
function findRoot(cwd: string): string {
  try {
    const top = execFileSync('git', ['-C', cwd, 'rev-parse', '--path-format=absolute', '--show-toplevel'],
      { encoding: 'utf8', timeout: 5000 }).trim()
    if (top && existsSync(join(top, '.pi/team/config.sh'))) return resolve(top)
  } catch {
    /* 不是 git 仓库 / 没有 git */
  }
  const envRoot = process.env.TEAM_ROOT
  if (envRoot && existsSync(join(envRoot, '.pi/team/config.sh'))) return resolve(envRoot)
  let dir = resolve(cwd)
  for (;;) {
    if (existsSync(join(dir, '.pi/team/config.sh'))) return dir
    const parent = dirname(dir)
    if (parent === dir) break
    dir = parent
  }
  try {
    const out = execFileSync('git', ['-C', cwd, 'rev-parse', '--path-format=absolute', '--git-common-dir'],
      { encoding: 'utf8', timeout: 5000 })
    const main = dirname(out.trim())
    if (existsSync(join(main, '.pi/team/config.sh'))) return main
  } catch {
    /* ignore */
  }
  return ''
}

function stateDir(root: string): string {
  return process.env.TEAM_STATE_DIR || join(root, '.pi/team/state')
}

function maxBytes(): number {
  const n = Number(process.env.TEAM_BG_LOG_MAX_BYTES ?? NaN)
  return Number.isFinite(n) && n >= 256 ? n : DEFAULT_MAX_BYTES
}

function appendLedger(root: string, line: string): void {
  try {
    mkdirSync(stateDir(root), { recursive: true })
    appendFileSync(join(stateDir(root), 'bg.log'), `${new Date().toISOString()} ${line}\n`)
  } catch {
    /* 账本绝不能影响会话 */
  }
}

/** 读文件尾段（最多 limit 字节）；truncated = 前面还有没读到的内容。 */
function tailOf(file: string, limit: number): { text: string; truncated: boolean } {
  try {
    const size = statSync(file).size
    const start = Math.max(0, size - limit)
    const fd = openSync(file, 'r')
    try {
      const buf = Buffer.alloc(size - start)
      readSync(fd, buf, 0, buf.length, start)
      const text = buf.toString('utf8')
      return { text, truncated: start > 0 || text.includes(TRUNC_MARK) }
    } finally {
      closeSync(fd)
    }
  } catch {
    return { text: '', truncated: false }
  }
}

/** 日志超上限就地截断：保留尾段 + 一行标记（有界，且尾部信号不丢）。 */
function trimLog(file: string): void {
  const cap = maxBytes()
  try {
    if (statSync(file).size <= cap) return
    const { text } = tailOf(file, Math.max(1024, Math.floor(cap / 2)))
    writeFileSync(file, `${TRUNC_MARK} cap=${cap}\n${text}`)
  } catch {
    /* ignore */
  }
}

function slug(raw: string): string {
  const s = raw.replace(/[^A-Za-z0-9._-]+/g, '-').replace(/^-+|-+$/g, '').slice(0, 32)
  return s || 'job'
}

/**
 * 结果文本里的命令行：**单行化**（换行/连串空白 → 一个空格）后**缩略**。
 *
 * 用户反馈（P33）：结果只有 job id/pid/log，看不出「我到底跑的是什么命令」。所以两个工具都点名命令；
 * 多行命令单行化后一眼能读，超过 100 个**码点**截断加 `…`。切法必须是**码点**（`Array.from`）：
 * 按字节切会造出非法 UTF-8（P28 的教训），按 UTF-16 单元切会把代理对（emoji/CJK 扩展区）劈成半个字符。
 * 完整命令始终原样留在 `details.cmd` 里，回收割方/夹具使用。
 */
function displayCmd(raw: string): string {
  const one = raw.replace(/\s+/g, ' ').trim()
  const cps = Array.from(one)
  return cps.length <= CMD_DISPLAY_MAX ? one : `${cps.slice(0, CMD_DISPLAY_MAX).join('')}${CMD_ELLIPSIS}`
}

export default function (pi: ExtensionAPI) {
  const jobs = new Map<string, Job>()
  let active = false // agent 正在跑（工具调用/流式输出）——完成通知要等它闲下来
  let trimTimer: ReturnType<typeof setInterval> | null = null
  let flushTimer: ReturnType<typeof setTimeout> | null = null

  const stopTimers = (): void => {
    if (trimTimer) { clearInterval(trimTimer); trimTimer = null }
    if (flushTimer) { clearTimeout(flushTimer); flushTimer = null }
  }

  /** 把「已完成、未收割、未通知」的作业合并成一条消息投递；没有就什么都不做。 */
  const flushPending = (root: string): void => {
    const ready = [...jobs.values()].filter(j => j.done && !j.harvested && !j.notified)
    if (!ready.length) return
    for (const j of ready) j.notified = true
    const lines = ready.map(j => `- ${j.id} exit=${j.exitCode} log=${j.log}`)
    const text =
      `[team-bg] ${ready.length} background job(s) finished and are not harvested yet:\n${lines.join('\n')}\n` +
      'Run team_bg_wait <id> to harvest one (the result comes back inline; a harvested job never wakes you again).'
    appendLedger(root, `wake count=${ready.length} ids=${ready.map(j => j.id).join(',')}`)
    try {
      pi.sendMessage({ customType: 'teamsmith-bg', content: text, display: true },
        { triggerTurn: true, deliverAs: 'followUp' })
    } catch {
      /* 会话正在退出等场合：账本已经记了，不抛 */
    }
  }

  const scheduleFlush = (root: string): void => {
    if (flushTimer) return
    flushTimer = setTimeout(() => { flushTimer = null; try { flushPending(root) } catch { /* ignore */ } }, MERGE_WINDOW_MS)
  }

  const finishJob = (root: string, job: Job, code: number | null): void => {
    if (job.done) return
    job.done = true
    job.exitCode = code
    trimLog(job.log)
    for (const wake of job.waiters.splice(0)) { try { wake() } catch { /* ignore */ } }
    if (job.harvested) return // #689 第 1 条：已收割 → 静默
    if (!active) scheduleFlush(root) // 空闲：合并窗口结束就唤醒；正在跑则留给 agent_settled 的合并投递
  }

  /** 等作业结束；超时/被中断 → false（收割意图由调用方撤销，完成时照常唤醒）。 */
  const waitForExit = (job: Job, timeout: number, signal: any): Promise<boolean> => {
    if (job.done) return Promise.resolve(true)
    return new Promise<boolean>(resolve => {
      let settled = false
      const waiter = (): void => finish(true)
      const finish = (ok: boolean): void => {
        if (settled) return
        settled = true
        if (timer) clearTimeout(timer)
        try { signal?.removeEventListener?.('abort', onAbort) } catch { /* ignore */ }
        job.waiters = job.waiters.filter(w => w !== waiter)
        resolve(ok)
      }
      const onAbort = (): void => finish(false)
      const timer = timeout > 0 ? setTimeout(() => finish(false), timeout) : null
      job.waiters.push(waiter)
      try { signal?.addEventListener?.('abort', onAbort, { once: true }) } catch { /* ignore */ }
    })
  }

  // ---- 工具 -----------------------------------------------------------------
  pi.registerTool({
    name: 'team_bg_run',
    label: 'Team background job',
    description:
      'Start a long command (a gate, a build) as a detached background job and return immediately with a job id. ' +
      'Output goes to state/bg/<id>.log (bounded). Harvest it with team_bg_wait before you end your turn; ' +
      'otherwise the team wakes you once when it finishes.',
    promptSnippet: 'team_bg_run: start a long command in the background (returns a job id immediately)',
    promptGuidelines: [
      'Use team_bg_run for long gates or builds, and harvest every job with team_bg_wait before ending your turn ' +
      '(a turn must not end with unharvested background jobs).',
    ],
    parameters: {
      type: 'object',
      properties: {
        command: { type: 'string', description: 'Shell command to run (bash -c, with your environment and cwd)' },
        name: { type: 'string', description: 'Short label used in the job id and the log path' },
        cwd: { type: 'string', description: 'Working directory (defaults to the session cwd)' },
      },
      required: ['command'],
      additionalProperties: false,
    } as any,
    async execute(_toolCallId: string, params: any, _signal: any, _onUpdate: any, ctx: any) {
      const root = findRoot(String(ctx?.cwd ?? process.cwd()))
      if (!root) throw new Error('team_bg_run: not a teamsmith project (no .pi/team/config.sh found)')
      const command = String(params?.command ?? '')
      if (!command.trim()) throw new Error('team_bg_run: empty command')
      const cwd = resolve(String(params?.cwd || ctx?.cwd || process.cwd()))
      const dir = join(stateDir(root), 'bg')
      mkdirSync(dir, { recursive: true })
      const base = slug(String(params?.name ?? 'job'))
      let id = base
      for (let i = 2; jobs.has(id); i++) id = `${base}-${i}`
      const log = join(dir, `${id}.log`)
      const fd = openSync(log, 'w')
      let child: ReturnType<typeof spawn>
      try {
        child = spawn('bash', ['-c', command], { cwd, detached: true, stdio: ['ignore', fd, fd], env: process.env })
      } finally {
        closeSync(fd)
      }
      const job: Job = {
        id, pid: child.pid ?? 0, command, cwd, log, startedAt: Date.now(),
        done: false, exitCode: null, harvested: false, notified: false, waiters: [],
      }
      jobs.set(id, job)
      child.on('exit', (code: number | null) => finishJob(root, job, code))
      child.on('error', (error: Error) => {
        appendLedger(root, `spawn-error id=${id} ${String(error?.message ?? error)}`)
        finishJob(root, job, -1)
      })
      child.unref()
      if (!trimTimer) {
        trimTimer = setInterval(() => { for (const j of jobs.values()) if (!j.done) trimLog(j.log) }, TRIM_EVERY_MS)
      }
      return {
        content: [{ type: 'text', text: `job ${id} started (pid ${job.pid}); log: ${log}\n  cmd: ${displayCmd(command)}\nHarvest it with team_bg_wait ${id}.` }],
        details: { id, pid: job.pid, log, cwd, cmd: command },
      }
    },
  } as any)

  pi.registerTool({
    name: 'team_bg_wait',
    label: 'Team background job wait',
    description: 'Wait for a job started by team_bg_run, harvest it and return its exit code plus the log tail inline.',
    promptSnippet: 'team_bg_wait: harvest a team_bg_run job (waits if it is still running)',
    parameters: {
      type: 'object',
      properties: {
        id: { type: 'string', description: 'Job id returned by team_bg_run' },
        timeout_ms: { type: 'number', description: `How long to wait in ms (default ${DEFAULT_WAIT_MS}; 0 = just report status)` },
      },
      required: ['id'],
      additionalProperties: false,
    } as any,
    async execute(_toolCallId: string, params: any, signal: any) {
      const job = jobs.get(String(params?.id ?? ''))
      if (!job) {
        const known = [...jobs.keys()].join(', ') || '(none)'
        throw new Error(`team_bg_wait: unknown job "${String(params?.id ?? '')}" (this session started: ${known})`)
      }
      const timeout = Number.isFinite(Number(params?.timeout_ms))
        ? Math.max(0, Number(params.timeout_ms))
        : DEFAULT_WAIT_MS
      let running = false
      if (!job.done && timeout > 0) {
        job.harvested = true // 收割意图先落地：保证完成时静默（#689 第 1 条）
        const exited = await waitForExit(job, timeout, signal)
        if (!exited && !job.done) {
          job.harvested = false // 没收成 → 撤销意图，完成时照常唤醒
          running = true
        }
      } else if (!job.done) {
        running = true
      }
      if (running) {
        return {
          content: [{ type: 'text', text: `job ${job.id} is still running (pid ${job.pid}); log: ${job.log}\n  cmd: ${displayCmd(job.command)}` }],
          details: { id: job.id, running: true, log: job.log, cmd: job.command },
        }
      }
      job.harvested = true
      const { text, truncated } = tailOf(job.log, TAIL_BYTES)
      const secs = ((Date.now() - job.startedAt) / 1000).toFixed(1)
      const body = truncated ? `${TRUNC_MARK}\n${text}` : text
      return {
        content: [{
          type: 'text',
          text: `job ${job.id} finished exit=${job.exitCode} after ${secs}s; log: ${job.log}\n  cmd: ${displayCmd(job.command)}\n--- tail ---\n${body}`,
        }],
        details: { id: job.id, exitCode: job.exitCode, log: job.log, truncated, cmd: job.command },
      }
    },
  } as any)

  pi.on('session_start', async () => {
    stopTimers()
    jobs.clear()
    active = false
  })

  pi.on('agent_start', async () => { active = true })

  pi.on('agent_settled', async (_event: any, ctx: any) => {
    active = false
    try {
      const root = findRoot(String(ctx?.cwd ?? process.cwd()))
      if (!root) return
      const open = [...jobs.values()].filter(j => !j.harvested)
      const label = (j: Job): string => `${j.id}:${j.done ? `exit${j.exitCode}` : 'running'}`
      appendLedger(root, `settled-with-unharvested=${open.length}${open.length ? ` jobs=${open.map(label).join(',')}` : ''}`)
      flushPending(root)
    } catch {
      /* 账本/投递失败不能打断会话 */
    }
  })

  pi.on('session_shutdown', async () => {
    stopTimers()
    jobs.clear() // 作业本身是 detached 的：不杀；日志与账本留在 state/ 里
  })
}
