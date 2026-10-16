// teamsmith /team extension
/**
 * teamsmith · `/team` 斜杠命令（change: slash-team）
 *
 * 用户坐在 Pi 会话里，用 `/team …` 跑项目自己的 `team` CLI：一条命令都不重新实现，把用户打的 token
 * 原样交给子进程（cwd = 项目根），把 stdout/stderr/退出码如实带回对话。这是「前门」，不是第二套 CLI。
 *
 * 结构（design §3.8 的两层）：
 *   - **纯逻辑**（本文件里不碰任何 Pi API 的部分）：白名单表、分词、匹配、菜单、项目根/CLI 解析、
 *     `runTeamCommand(deps, argv)`。夹具用假 pi 直接驱动它们。
 *   - **Pi 粘合**：文件末尾的默认导出 —— 只 `registerCommand("team", …)` 一次，**从不**注册任何
 *     模型可调用的工具（模型不能自己触发这条命令）
 *
 * 加载方式（design §3.1）：`team init`/`bootstrap` 把它装到 `<main worktree>/.pi/extensions/team.ts`
 * （默认软链），Pi 从工作目录自动发现、`/reload` 即生效；**不**用 `pi -e` 注入（那要重启进程）。
 *
 * 零运行时依赖：只有 `node:*` 内建与 `import type`（被擦除），所以 `bun -e "await import(...)"` 能加载。
 */
import type { ExtensionAPI } from '@earendil-works/pi-coding-agent'
import { existsSync } from 'node:fs'
import { dirname, join, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

// ---------------------------------------------------------------- 文案表（design §3.7）
// 一行一条、语言是一列：今天只有 zh 一份；P260 若落地 TEAM_LANG，这里加一列而不是改写调用点。
type StringRow = { key: string; zh: string }
const STRINGS: StringRow[] = [
  { key: 'menu.title', zh: 'teamsmith /team · 在对话里跑项目自己的 team 命令（输出进对话，退出码照实报）' },
  { key: 'menu.group.read', zh: '读取' },
  { key: 'menu.group.action', zh: '你自己动手' },
  { key: 'menu.footer', zh: '不在上面的命令是 PM / 席位的工具，请到终端跑。' },
  { key: 'refuse.outside', zh: '✗ /team 不认这条命令：{{name}} —— 这是 PM / 席位的命令，请到终端执行（输入 /team 看能用什么）' },
  { key: 'refuse.shape', zh: '✗ /team 不认这个形状：team {{argv}} —— {{path}} 只认自己的形状（{{forms}}）；{{extra}}要跑别的形状（那是 PM / 席位的工具）请到终端。' },
  { key: 'refuse.pm-restart', zh: '✗ /team 不跑 up：这个会话就是 PM 会话，从这里重启会把当前对话一起带走 —— 要重启请到终端跑 team up。' },
  { key: 'refuse.no-project', zh: '✗ /team 找不到项目：当前目录 {{cwd}} 向上没有 .pi/team/config.sh —— 到 teamsmith 项目里再用，或先跑 team init。' },
  { key: 'refuse.no-cli', zh: '✗ /team 找不到 team CLI：{{root}} 下既没有 .pi/skills/teamsmith/scripts/team，也没有可用的 TEAM_CLI —— 跑 team init 装项目本地 skill。' },
  { key: 'refuse.quote', zh: '✗ /team 参数里的引号没有闭合：{{raw}} —— 不猜，什么都不跑（补上引号再来）。' },
  { key: 'refuse.escape', zh: '✗ /team 参数以反斜杠结尾：{{raw}} —— 不猜，什么都不跑。' },
  { key: 'run.header', zh: '$ team {{argv}}' },
  { key: 'run.exit', zh: 'exit {{code}}' },
  { key: 'run.killed', zh: 'killed：超时 {{sec}}s' },
  { key: 'run.stdout', zh: '--- stdout ---' },
  { key: 'run.stderr', zh: '--- stderr ---' },
  { key: 'run.elided', zh: '…（省略 {{lines}} 行 / {{bytes}} 字节；完整输出：在终端跑 team {{argv}}）' },
  { key: 'fail.exit', zh: '命令失败：team {{argv}}（exit {{code}}）' },
  { key: 'fail.killed', zh: '命令超时被杀：team {{argv}}（{{sec}}s 上限）' },
  { key: 'command.description', zh: '跑项目自己的 team 命令（白名单：读取 + 你自己动手的操作）' },
]
const STRING_INDEX: Record<string, string> = (() => {
  const m: Record<string, string> = {}
  for (const row of STRINGS) m[row.key] = row.zh
  return m
})()
/** 取文案（今天只有 zh；P260 的 TEAM_LANG 落地后在这里选列）。 */
export function t(key: string, vars?: Record<string, string>): string {
  let s = STRING_INDEX[key]
  if (s === undefined) return key
  if (vars) for (const k of Object.keys(vars)) s = s.split(`{{${k}}}`).join(vars[k])
  return s
}

// ---------------------------------------------------------------- 白名单：一张表，两种行（design §3.2）
/** 读行形状里的「一个自由 token」占位符（`<ID>` / `<n>` / `<slug>`）。 */
export const ARG = '<arg>'
export type Group = 'read' | 'action'
export type Row = {
  group: Group
  /** 命令路径（菜单/补全/探针都用它；一行可以有多条路径，例如 pulse 的三个动词）。 */
  paths: string[][]
  /** 读行专有：逐字接受的 token 形状（`ARG` = 恰好一个自由 token）。动行没有它 = 路径 + 自由尾巴。 */
  forms?: string[][]
  /** 菜单里那一句用途。 */
  purpose: string
}

export const TEAM_ROWS: Row[] = [
  { group: 'read', paths: [['status']], forms: [['status'], ['status', ARG]], purpose: '名册 + 任务/report 状态' },
  { group: 'read', paths: [['digest']], forms: [['digest']], purpose: '给 PM 的待办摘要' },
  { group: 'read', paths: [['ps']], forms: [['ps']], purpose: '容量：RAM/swap/还能再跑几个 agent' },
  { group: 'read', paths: [['board']], forms: [['board'], ['board', 'ls']], purpose: '看板（BOARD.md）' },
  { group: 'read', paths: [['reply', 'list']], forms: [['reply', 'list']], purpose: '关键回复列表（JSON）' },
  { group: 'read', paths: [['reply', 'show']], forms: [['reply', 'show', ARG]], purpose: '读第 n 条关键回复' },
  { group: 'read', paths: [['config', 'list']], forms: [['config', 'list']], purpose: '项目契约的每个键与当前值' },
  { group: 'read', paths: [['version']], forms: [['version']], purpose: '磁盘版本 / 本会话加载版本' },
  { group: 'read', paths: [['doctor']], forms: [['doctor']], purpose: '环境自检' },
  { group: 'read', paths: [['meeting', 'inbox']], forms: [['meeting', 'inbox']], purpose: '待回应的会议' },
  { group: 'read', paths: [['meeting', 'read']], forms: [['meeting', 'read', ARG]], purpose: '读一场会议' },
  { group: 'action', paths: [['pulse', 'up'], ['pulse', 'down'], ['pulse', 'status']], purpose: '巡检窗口（起/停/看）' },
  { group: 'action', paths: [['config', 'upgrade-models']], purpose: '模型策略升级（写盘要 --yes）' },
  { group: 'action', paths: [['meeting', 'say']], purpose: '给对面 PM 发言（--intent 必填）' },
  { group: 'action', paths: [['meeting', 'close']], purpose: '结束一场会议' },
]

/** 表外命令的**具名**前缀（拒绝文案要点名 `dispatch` / `config set` 这样的命令，而不是只报第一个词）。 */
export const REFUSED_PATHS: string[][] = [
  ['up'], ['dispatch'], ['say'], ['notify'], ['close'], ['teardown'],
  ['config', 'set'], ['smoke'], ['gate'], ['perf'], ['review'], ['change'],
  ['archive'], ['bg'], ['add-agent'], ['init'], ['bootstrap'], ['draft'],
  ['outbox'], ['inbox'], ['thread'], ['monitor'], ['pr'], ['gh'],
]

// ---------------------------------------------------------------- 分词（design §3.3）
export type TokenizeResult = { ok: true; tokens: string[] } | { ok: false; error: string }

/** 空白分隔；单/双引号；引号外反斜杠转义；未闭合引号（或结尾反斜杠）⇒ 拒绝，什么都不跑。 */
export function tokenize(raw: string): TokenizeResult {
  const tokens: string[] = []
  let cur = ''
  let started = false
  let i = 0
  while (i < raw.length) {
    const ch = raw[i]
    if (ch === ' ' || ch === '\t' || ch === '\n' || ch === '\r') {
      if (started) { tokens.push(cur); cur = ''; started = false }
      i++
      continue
    }
    started = true
    if (ch === "'") {
      const j = raw.indexOf("'", i + 1)
      if (j < 0) return { ok: false, error: t('refuse.quote', { raw }) }
      cur += raw.slice(i + 1, j)
      i = j + 1
      continue
    }
    if (ch === '"') {
      i++
      let closed = false
      while (i < raw.length) {
        const c = raw[i]
        if (c === '"') { closed = true; i++; break }
        if (c === '\\' && i + 1 < raw.length && (raw[i + 1] === '"' || raw[i + 1] === '\\')) {
          cur += raw[i + 1]; i += 2; continue
        }
        cur += c; i++
      }
      if (!closed) return { ok: false, error: t('refuse.quote', { raw }) }
      continue
    }
    if (ch === '\\') {
      if (i + 1 >= raw.length) return { ok: false, error: t('refuse.escape', { raw }) }
      cur += raw[i + 1]; i += 2; continue
    }
    cur += ch; i++
  }
  if (started) tokens.push(cur)
  return { ok: true, tokens }
}

// ---------------------------------------------------------------- 匹配（design §3.2 / §3.3）
export type Match =
  | { kind: 'menu' }
  | { kind: 'run'; row: Row; tokens: string[] }
  | { kind: 'refuse'; message: string }

function formMatches(form: string[], tokens: string[]): boolean {
  if (form.length !== tokens.length) return false
  for (let i = 0; i < form.length; i++) if (form[i] !== ARG && form[i] !== tokens[i]) return false
  return true
}

function startsWithPath(tokens: string[], path: string[]): boolean {
  if (tokens.length < path.length) return false
  for (let i = 0; i < path.length; i++) if (tokens[i] !== path[i]) return false
  return true
}

function formsText(row: Row): string {
  return (row.forms ?? []).map((f) => 'team ' + f.join(' ')).join(' / ')
}

/** 表外命令的具名前缀：最长匹配（`config set` 优先于 `config`）。 */
export function refusedName(tokens: string[]): string {
  let best: string[] | null = null
  for (const p of REFUSED_PATHS) {
    if (!startsWithPath(tokens, p)) continue
    if (best === null || p.length > best.length) best = p
  }
  if (best) return best.join(' ')
  return tokens[0] ?? ''
}

export function matchInvocation(tokens: string[]): Match {
  if (tokens.length === 0) return { kind: 'menu' }
  if (tokens.length === 1 && tokens[0] === 'help') return { kind: 'menu' }
  // design §3.2 坑 1：会重启/新建 PM 会话的调用一律拒绝（up 与任何带 --fresh-pm 的调用）。
  if (tokens[0] === 'up' || tokens.indexOf('--fresh-pm') >= 0) {
    return { kind: 'refuse', message: t('refuse.pm-restart') }
  }
  // ① 读行：严格形状，整个 argv 吃完才算命中。
  for (const row of TEAM_ROWS) {
    if (!row.forms) continue
    for (const form of row.forms) if (formMatches(form, tokens)) return { kind: 'run', row, tokens }
  }
  // ② 读行的形状不符（多/少 token）：点名那一行与多出来的 token，零副作用。
  for (const row of TEAM_ROWS) {
    if (!row.forms) continue
    if (!startsWithPath(tokens, row.paths[0])) continue
    const extra = tokens.slice(row.paths[0].length).join(' ')
    return {
      kind: 'refuse',
      message: t('refuse.shape', {
        argv: tokens.join(' '),
        path: row.paths[0].join(' '),
        forms: formsText(row),
        extra: extra ? `多出来的 token ${extra} 不原样透传；` : '',
      }),
    }
  }
  // ③ 动行：命令路径 + 用户自己的尾巴（原样透传，由 CLI 校验）。
  for (const row of TEAM_ROWS) {
    if (row.forms) continue
    for (const path of row.paths) if (startsWithPath(tokens, path)) return { kind: 'run', row, tokens }
  }
  // ④ 表外：一个进程都不起。
  return { kind: 'refuse', message: t('refuse.outside', { name: refusedName(tokens) }) }
}

// ---------------------------------------------------------------- 菜单与补全（design §3.2，单真源）
function rowName(row: Row): string {
  return row.paths.map((p) => p.join(' ')).join(' / ')
}

export function renderMenu(): string {
  const lines: string[] = [t('menu.title')]
  let width = 0
  for (const row of TEAM_ROWS) width = Math.max(width, rowName(row).length)
  for (const group of ['read', 'action'] as Group[]) {
    lines.push('')
    lines.push(t(group === 'read' ? 'menu.group.read' : 'menu.group.action'))
    for (const row of TEAM_ROWS) {
      if (row.group !== group) continue
      const name = rowName(row)
      lines.push('  ' + name + ' '.repeat(width - name.length + 2) + row.purpose)
    }
  }
  lines.push('')
  lines.push(t('menu.footer'))
  return lines.join('\n')
}

export type CompletionItem = { value: string; label: string; description?: string }

export function completions(prefix: string): CompletionItem[] {
  const raw = prefix.replace(/^\s+/, '')
  const pt = raw.split(/\s+/).filter((s) => s !== '')
  const items: CompletionItem[] = []
  for (const row of TEAM_ROWS) {
    for (const path of row.paths) {
      let hit = true
      if (pt.length > path.length) hit = false
      for (let i = 0; hit && i < pt.length; i++) {
        if (i === pt.length - 1) { if (!path[i].startsWith(pt[i])) hit = false }
        else if (path[i] !== pt[i]) hit = false
      }
      if (hit) items.push({ value: path.join(' '), label: path.join(' '), description: row.purpose })
    }
  }
  return items
}

// ---------------------------------------------------------------- 项目根与 CLI 解析（design §3.5）
/** 从 `cwd` 向上找第一个含 `.pi/team/config.sh` 的目录；找不到 = null（不是 teamsmith 项目）。 */
export function findProjectRoot(cwd: string): string | null {
  let d = resolve(cwd)
  for (;;) {
    if (existsSync(join(d, '.pi', 'team', 'config.sh'))) return d
    const up = dirname(d)
    if (up === d) return null
    d = up
  }
}

/**
 * CLI 路径（顺序有意，design §3.5）：项目本地安装永远赢 → `${TEAM_CLI}`（测试/非默认安装旋钮）
 * → 扩展自己的兄弟目录 `<ext-dir>/../scripts/team`（`-e` 或 realpath 解析过的软链形态）→ null。
 */
export function resolveCli(root: string, env: Record<string, string | undefined>, extDir?: string): string | null {
  const local = join(root, '.pi', 'skills', 'teamsmith', 'scripts', 'team')
  if (existsSync(local)) return local
  const envCli = env['TEAM_CLI']
  if (envCli !== undefined && envCli !== '') return envCli
  if (extDir !== undefined && extDir !== '') {
    const sibling = resolve(extDir, '..', 'scripts', 'team')
    if (existsSync(sibling)) return sibling
  }
  return null
}

// ---------------------------------------------------------------- 执行与输出（design §3.4 / §3.5）
export const CUSTOM_TYPE = 'teamsmith-team'
export const WAIT_MS = 60000
export const SHORT_LINE_MAX = 200
export const FUSE_LINES = 500
export const FUSE_BYTES = 64 * 1024
export const FUSE_HEAD_LINES = 200
export const FUSE_TAIL_LINES = 100
/** 唯一一处收紧：剥掉「替用户说 yes」的三个变量（用户自己打的 --yes 照旧到达）。 */
export const UNSET_VARS = ['TEAM_ASSUME_YES', 'TEAM_UPGRADE_CONFIRMED', 'TEAM_ALLOW_FOREIGN_SESSION']

export type ExecOptions = { cwd?: string; timeout?: number }
export type ExecResult = { stdout: string; stderr: string; code: number; killed: boolean }
export type ExecFn = (command: string, args: string[], options?: ExecOptions) => Promise<ExecResult>
export type CustomMessage = { customType: string; content: string; display?: boolean }
export type Deps = {
  cwd: string
  exec: ExecFn
  sendMessage: (message: CustomMessage) => void
  notify: (message: string, type?: 'info' | 'warning' | 'error') => void
  env?: Record<string, string | undefined>
  extDir?: string
}
export type Outcome =
  | { kind: 'menu'; text: string }
  | { kind: 'refused'; message: string }
  | { kind: 'ran'; argv: string[]; code: number; killed: boolean; content: string; short: boolean }

/** 剥离包装：`bash -c 'unset …; exec "$0" "$@"' <cli> <tokens…>` —— 只转交，不做二次解析。 */
export function wrapScript(): string {
  const unset = UNSET_VARS.length > 0 ? `unset ${UNSET_VARS.join(' ')}; ` : ''
  return `${unset}exec "$0" "$@"`
}

function utf8Bytes(s: string): number {
  let n = 0
  for (let i = 0; i < s.length; i++) {
    const c = s.charCodeAt(i)
    if (c < 0x80) n += 1
    else if (c < 0x800) n += 2
    else if (c >= 0xd800 && c <= 0xdbff) { n += 4; i++ }
    else n += 3
  }
  return n
}

/** 保险丝：超过 500 行或 64 KiB（先到先算）时保留前 200 + 后 100 行，中间显式说明去哪看全文。 */
export function fuseOutput(text: string, argv: string[]): string {
  const lines = text.split('\n')
  const bytes = utf8Bytes(text)
  if (lines.length <= FUSE_LINES && bytes <= FUSE_BYTES) return text
  const head = lines.slice(0, FUSE_HEAD_LINES)
  const tail = lines.slice(lines.length - FUSE_TAIL_LINES)
  const dropped = lines.length - head.length - tail.length
  const droppedBytes = Math.max(0, bytes - utf8Bytes(head.join('\n')) - utf8Bytes(tail.join('\n')))
  const notice = t('run.elided', { lines: String(dropped), bytes: String(droppedBytes), argv: argv.join(' ') })
  return head.concat([notice], tail).join('\n')
}

/** 单行且 ≤ 200 字符（按码点）的成功结果 ⇒ 通知，不进对话。 */
export function isShortSuccess(res: ExecResult): boolean {
  if (res.killed || res.code !== 0) return false
  const text = (res.stdout ?? '').replace(/^\s+/, '').replace(/\s+$/, '')
  if (text === '' || text.indexOf('\n') >= 0) return false
  return Array.from(text).length <= SHORT_LINE_MAX
}

export function shortText(res: ExecResult): string {
  return (res.stdout ?? '').replace(/^\s+/, '').replace(/\s+$/, '')
}

/** 正文条目：命令行 + 退出码（或被杀原因）+ stdout（+ stderr）。 */
export function formatEntry(argv: string[], res: ExecResult): string {
  const header = t('run.header', { argv: argv.join(' ') })
  const status = res.killed ? t('run.killed', { sec: String(WAIT_MS / 1000) }) : t('run.exit', { code: String(res.code) })
  let body = t('run.stdout') + '\n' + (res.stdout ?? '')
  if ((res.stderr ?? '') !== '') body += '\n' + t('run.stderr') + '\n' + res.stderr
  return header + '\n' + status + '\n' + fuseOutput(body, argv)
}

export function failureNotice(argv: string[], res: ExecResult): string {
  if (res.killed) return t('fail.killed', { argv: argv.join(' '), sec: String(WAIT_MS / 1000) })
  return t('fail.exit', { argv: argv.join(' '), code: String(res.code) })
}

function refuse(deps: Deps, message: string): Outcome {
  deps.sendMessage({ customType: CUSTOM_TYPE, content: message, display: true })
  return { kind: 'refused', message }
}

/**
 * 纯逻辑入口：拒绝/菜单/执行与落点都在这里。`deps` 是全部外部接触面（exec / sendMessage / notify），
 * 所以假 pi 可以直接驱动它，而它自己不认识任何 Pi API。
 */
export async function runTeamCommand(deps: Deps, argv: string[]): Promise<Outcome> {
  const m = matchInvocation(argv)
  if (m.kind === 'menu') {
    const text = renderMenu()
    deps.sendMessage({ customType: CUSTOM_TYPE, content: text, display: true })
    return { kind: 'menu', text }
  }
  if (m.kind === 'refuse') return refuse(deps, m.message)

  const root = findProjectRoot(deps.cwd)
  if (root === null) return refuse(deps, t('refuse.no-project', { cwd: deps.cwd }))
  const cli = resolveCli(root, deps.env ?? {}, deps.extDir)
  if (cli === null) return refuse(deps, t('refuse.no-cli', { root }))

  const res = await deps.exec('bash', ['-c', wrapScript(), cli, ...m.tokens], { cwd: root, timeout: WAIT_MS })

  if (isShortSuccess(res)) {
    const text = shortText(res)
    deps.notify(text, 'info')
    return { kind: 'ran', argv: m.tokens, code: res.code, killed: res.killed, content: text, short: true }
  }
  const content = formatEntry(m.tokens, res)
  deps.sendMessage({ customType: CUSTOM_TYPE, content, display: true })
  if (res.killed || res.code !== 0) deps.notify(failureNotice(m.tokens, res), 'error')
  return { kind: 'ran', argv: m.tokens, code: res.code, killed: res.killed, content, short: false }
}

// ---------------------------------------------------------------- Pi 粘合（唯一使用 Pi API 的地方）
const HERE = (() => {
  try { return dirname(fileURLToPath(import.meta.url)) } catch { return undefined }
})()

/**
 * 默认导出：**只**注册 `/team` 一条命令。不注册任何模型可调用的工具 —— 模型不能自己触发它；
 * 不弹任何自己的确认框 —— 前门不给用户加第二道自己的政策（CLI 的守卫原样生效）。
 */
export default function teamExtension(pi: ExtensionAPI): void {
  pi.registerCommand('team', {
    description: t('command.description'),
    getArgumentCompletions: (prefix: string) => completions(prefix),
    handler: async (args: string, ctx) => {
      const deps: Deps = {
        cwd: ctx.cwd,
        exec: (command, argv, options) => pi.exec(command, argv, options),
        sendMessage: (message) => pi.sendMessage(message),
        notify: (message, type) => ctx.ui.notify(message, type),
        env: process.env as Record<string, string | undefined>,
        extDir: HERE,
      }
      const parsed = tokenize(args)
      if (!parsed.ok) { refuse(deps, parsed.error); return }
      await runTeamCommand(deps, parsed.tokens)
    },
  })
}
