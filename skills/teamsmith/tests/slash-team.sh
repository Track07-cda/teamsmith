#!/usr/bin/env bash
# slash-team.sh — `/team` 扩展的**纯逻辑层**夹具（change: slash-team · 实现：P270）
#
#   bash skills/teamsmith/tests/slash-team.sh [--select <g1,g2>] [--flip] [--keep]
#   bash skills/teamsmith/tests/slash-team.sh                     # 全部组（含表↔CLI 探针）
#
# 组：command tokens whitelist menu refuse output env resolve probe
#   command   只注册一条命令、零工具注册、零确认框
#   tokens    用户打的 token 逐字交给子进程（引号/空格/反斜杠/未闭合）
#   whitelist 读行严格形状、动行自由尾巴、表外拒绝
#   menu      菜单与补全从同一张表渲染（夹具独立重算表 → 逐字比对）
#   refuse    拒绝路径零副作用（零 exec）+ 文案点名
#   output    短/长/失败/被杀/超量 五格落点与退出码
#   env       剥离三个「替你说 yes」的变量、不注入 --yes
#   resolve   项目根向上找、CLI 解析顺序（项目本地 → TEAM_CLI → 兄弟目录）
#   probe     表里每行路径喂 `--teamsmith-slash-probe`，不得得到顶层「未知子命令：<命令>」
#
# `--flip`：把实现逐条改坏（scratch 副本），要求**具名组**变红、真实源保持绿 —— 证明这套夹具会咬人。
# 纯逻辑组零进程；只有 probe 组起真 CLI（read-only 的 `--teamsmith-slash-probe` 探针）。
#
# 退出码：0 全绿；1 有失败；2 用法错误；3 setup 失败（缺 bun / 源文件）。
set -uo pipefail

here="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tree="$(cd -P "$here/../../.." && pwd)"
. "$here/lib/tmp-root.sh"

SEL_GROUPS=""
FLIP=0
KEEP=0
argc=$#
while [ $# -gt 0 ]; do
  case "$1" in
    --all)      SEL_GROUPS=""; shift ;;
    --select)   SEL_GROUPS="${2:?--select 需要组名}"; shift 2 ;;
    --select=*) SEL_GROUPS="${1#*=}"; shift ;;
    --flip)     FLIP=1; shift ;;
    --keep)     KEEP=1; export TEAM_TMP_KEEP=1; shift ;;
    -h|--help)  sed -n '2,20p' "$0"; exit 0 ;;
    *) printf 'slash-team: 未知参数 %s（用法见 --help）\n' "$1" >&2; exit 2 ;;
  esac
  # 每个分支都必须 shift：`--keep` 曾经漏了 shift，脚本于是永不退出、零输出地空转
  # （PM 2026-10-16 收掉过一个挂了 1h35m 的 --keep 进程）。这条守卫把同一类缺陷变成
  # 立刻可见的 rc=2，而不是一个静默的死循环。
  [ "$#" -lt "$argc" ] || { printf '%s: 参数循环没有前进（分支缺 shift？）：%s\n' "slash-team" "$1" >&2; exit 2; }
  argc=$#
done

ext="$tree/skills/teamsmith/extension/team.ts"
[ -f "$ext" ] || { printf 'slash-team: 没有扩展源 %s\n' "$ext" >&2; exit 3; }

BUN="${TEAM_SLASH_BUN:-$(command -v bun 2>/dev/null || true)}"
[ -n "$BUN" ] || [ -x "$HOME/.bun/bin/bun" ] && BUN="${BUN:-$HOME/.bun/bin/bun}"
if [ -z "${BUN:-}" ] || [ ! -x "$BUN" ]; then
  printf 'slash-team: 本机没有 bun（设计要求的加载器）—— 装 bun 才能跑这一层\n' >&2
  exit 3
fi

tmp="$(tmp_root_create slash-team)" || exit 3
cleanup() {
  [ "${BASHPID:-$$}" = "$$" ] || return 0
  if [ "$KEEP" = "1" ]; then printf '\n保留夹具目录：%s\n' "$tmp"
  else tmp_root_reap_all; fi
}
trap cleanup EXIT

cat > "$tmp/drive.ts" <<'DRIVER'
// `/team` 纯逻辑夹具的驱动器：假 pi 驱动扩展的处理器，断言记录下来的每一次外部调用。
import { pathToFileURL } from 'node:url'
import { copyFileSync, existsSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { spawnSync } from 'node:child_process'

const argv = process.argv.slice(2)
const opt = (name: string, dflt = ''): string => {
  const i = argv.indexOf(name)
  return i >= 0 && i + 1 < argv.length ? argv[i + 1] : dflt
}
const has = (name: string) => argv.includes(name)
const EXT = opt('--ext')
const TREE = opt('--tree')
const TMP = opt('--tmp')
const GROUPS = opt('--groups') ? opt('--groups').split(',').filter((s) => s !== '') : []
const FLIP = has('--flip')

const ALL_GROUPS = ['command', 'tokens', 'whitelist', 'menu', 'refuse', 'output', 'env', 'resolve', 'probe', 'args']
const want = (g: string) => GROUPS.length === 0 || GROUPS.includes(g)

let PASS = 0
let FAIL = 0
let CUR = ''
const failures: string[] = []
function check(name: string, cond: boolean, detail = ''): void {
  if (!want(CUR)) return
  if (cond) { PASS++; console.log(`  \u2713 ${name}`) }
  else { FAIL++; failures.push(`${CUR}: ${name}`); console.log(`  \u2717 ${name}${detail ? `\uff08${detail}\uff09` : ''}`) }
}
function group(name: string): void { CUR = name; console.log(`\n== ${name} ==`) }

// ---------------------------------------------------------------- 假 pi
type ExecResult = { stdout: string; stderr: string; code: number; killed: boolean }
type Rec = {
  commands: Array<{ name: string; opts: any }>
  tools: number
  confirms: number
  execs: Array<{ command: string; args: string[]; options: any }>
  messages: Array<{ customType: string; content: string; display?: boolean }>
  notifies: Array<{ message: string; type?: string }>
}
let bust = 0
async function loadExt(path: string): Promise<any> {
  return await import(pathToFileURL(path).href + `?bust=${bust++}`)
}
async function harness(extPath: string, opts: { cwd: string; results?: ExecResult[]; execFn?: (a: string[], o: any) => ExecResult }) {
  const mod = await loadExt(extPath)
  const rec: Rec = { commands: [], tools: 0, confirms: 0, execs: [], messages: [], notifies: [] }
  const queue: ExecResult[] = opts.results ? opts.results.slice() : []
  const exec = async (command: string, args: string[], options: any) => {
    rec.execs.push({ command, args, options })
    if (opts.execFn) return opts.execFn(args, options)
    return queue.shift() ?? { stdout: 'ok\n', stderr: '', code: 0, killed: false }
  }
  const ctx = {
    cwd: opts.cwd,
    ui: {
      notify: (message: string, type?: string) => { rec.notifies.push({ message, type }) },
      confirm: () => { rec.confirms++; return Promise.resolve(true) },
    },
  }
  const pi = {
    registerCommand: (name: string, o: any) => { rec.commands.push({ name, opts: o }) },
    registerTool: () => { rec.tools++ },
    exec,
    sendMessage: (m: any) => { rec.messages.push(m) },
  }
  mod.default(pi)
  const cmd = rec.commands[0]
  const run = async (args: string) => { await cmd.opts.handler(args, ctx) }
  return { mod, rec, run, ctx, pi }
}

const okResult = (stdout: string): ExecResult => ({ stdout, stderr: '', code: 0, killed: false })

// ---------------------------------------------------------------- 夹具项目
const proj = join(TMP, 'proj')
const cliDir = join(proj, '.pi', 'skills', 'teamsmith', 'scripts')
mkdirSync(join(proj, '.pi', 'team'), { recursive: true })
writeFileSync(join(proj, '.pi', 'team', 'config.sh'), 'TEAM_SESSION=fixture\n')
mkdirSync(cliDir, { recursive: true })
const cliLocal = join(cliDir, 'team')
writeFileSync(cliLocal, '#!/usr/bin/env bash\nexit 0\n', { mode: 0o755 })

// 夹具自己的「菜单独立重算」：只依赖导出的表与文案，不调用 renderMenu —— 这样把菜单改成硬编码必红。
function expectedMenu(mod: any): string {
  const name = (r: any) => r.paths.map((p: string[]) => p.join(' ')).join(' / ')
  let width = 0
  for (const r of mod.TEAM_ROWS) width = Math.max(width, name(r).length)
  const lines: string[] = [mod.t('menu.title')]
  for (const g of ['read', 'action']) {
    lines.push('')
    lines.push(mod.t(g === 'read' ? 'menu.group.read' : 'menu.group.action'))
    for (const r of mod.TEAM_ROWS) {
      if (r.group !== g) continue
      const n = name(r)
      lines.push('  ' + n + ' '.repeat(width - n.length + 2) + r.purpose)
    }
  }
  lines.push('')
  lines.push(mod.t('menu.footer'))
  return lines.join('\n')
}

async function runGroups(): Promise<void> {
  const savedCli = process.env.TEAM_CLI
  delete process.env.TEAM_CLI

  if (want('command')) {
    group('command')
    const h = await harness(EXT, { cwd: proj })
    check('注册的命令恰好一条且名字是 team', h.rec.commands.length === 1 && h.rec.commands[0].name === 'team',
      `commands=${h.rec.commands.map((c) => c.name).join(',')}`)
    check('命令带 description（补全菜单里可读）', typeof h.rec.commands[0]?.opts?.description === 'string' && h.rec.commands[0].opts.description.length > 0)
    check('零模型可调用的工具注册', h.rec.tools === 0, `registerTool=${h.rec.tools}`)
    check('零自己的确认框', h.rec.confirms === 0, `confirm=${h.rec.confirms}`)
    check('带参数补全函数', typeof h.rec.commands[0]?.opts?.getArgumentCompletions === 'function')
    check('源文件里没有工具注册的调用点', !readFileSync(EXT, 'utf8').includes('registerTool'))
  }

  if (want('tokens')) {
    group('tokens')
    const h = await harness(EXT, { cwd: proj, results: [okResult('a\nb\n'), okResult('a\nb\n'), okResult('a\nb\n'), okResult('a\nb\n')] })
    await h.run('ps')
    check('子进程是 bash -c（剥离包装）', h.rec.execs[0]?.command === 'bash' && h.rec.execs[0]?.args[0] === '-c',
      `command=${h.rec.execs[0]?.command} args0=${h.rec.execs[0]?.args[0]}`)
    check('argv 逐字：/team ps → [ps]', JSON.stringify(h.rec.execs[0]?.args.slice(3)) === '["ps"]',
      JSON.stringify(h.rec.execs[0]?.args.slice(3)))
    check('CLI 是项目本地安装（路径解析先项目本地）', h.rec.execs[0]?.args[2] === cliLocal, `cli=${h.rec.execs[0]?.args[2]}`)
    check('cwd = 项目根', h.rec.execs[0]?.options?.cwd === proj, `cwd=${h.rec.execs[0]?.options?.cwd}`)
    check('有界等待 60000ms', h.rec.execs[0]?.options?.timeout === 60000, `timeout=${h.rec.execs[0]?.options?.timeout}`)
    await h.run('meeting say alpha --intent proposal "two words"')
    check('双引号里的空格是一个 token（argv 逐字）',
      JSON.stringify(h.rec.execs[1]?.args.slice(3)) === '["meeting","say","alpha","--intent","proposal","two words"]',
      JSON.stringify(h.rec.execs[1]?.args.slice(3)))
    await h.run("meeting say 'a b' --intent proposal")
    check('单引号原样（argv 逐字）',
      JSON.stringify(h.rec.execs[2]?.args.slice(3)) === '["meeting","say","a b","--intent","proposal"]',
      JSON.stringify(h.rec.execs[2]?.args.slice(3)))
    await h.run('meeting say a\\ b --intent proposal')
    check('引号外反斜杠转义（argv 逐字）',
      JSON.stringify(h.rec.execs[3]?.args.slice(3)) === '["meeting","say","a b","--intent","proposal"]',
      JSON.stringify(h.rec.execs[3]?.args.slice(3)))
    const h2 = await harness(EXT, { cwd: proj })
    await h2.run('meeting say "unclosed')
    check('未闭合引号 ⇒ 拒绝且不起进程', h2.rec.execs.length === 0 && h2.rec.messages.length === 1,
      `execs=${h2.rec.execs.length} messages=${h2.rec.messages.length}`)
    check('未闭合引号的文案点名它', (h2.rec.messages[0]?.content ?? '').includes('没有闭合'), h2.rec.messages[0]?.content ?? '')
  }

  if (want('whitelist')) {
    group('whitelist')
    const mod = await loadExt(EXT)
    const readRows = mod.TEAM_ROWS.filter((r: any) => r.forms)
    const actionRows = mod.TEAM_ROWS.filter((r: any) => !r.forms)
    check('表恰好 15 行（11 读 + 4 动）', mod.TEAM_ROWS.length === 15 && readRows.length === 11 && actionRows.length === 4,
      `rows=${mod.TEAM_ROWS.length} read=${readRows.length} action=${actionRows.length}`)
    for (const row of readRows) {
      for (const form of row.forms) {
        const tokens = form.map((x: string) => (x === mod.ARG ? 'X' : x))
        const h = await harness(EXT, { cwd: proj, results: [okResult('a\nb\n')] })
        await h.run(tokens.join(' '))
        check(`读行接受自己的形状：team ${tokens.join(' ')}`, h.rec.execs.length === 1 && JSON.stringify(h.rec.execs[0].args.slice(3)) === JSON.stringify(tokens),
          `execs=${h.rec.execs.length}`)
      }
    }
    for (const row of actionRows) {
      for (const path of row.paths) {
        const tokens = [...path, '--flag', 'value']
        const h = await harness(EXT, { cwd: proj, results: [okResult('a\nb\n')] })
        await h.run(tokens.join(' '))
        check(`动行原样透传尾巴：team ${tokens.join(' ')}`, h.rec.execs.length === 1 && JSON.stringify(h.rec.execs[0].args.slice(3)) === JSON.stringify(tokens),
          `execs=${h.rec.execs.length}`)
      }
    }
    const outside = [
      ['dispatch', 'dev', 'P1', 'docs/team/tasks/P1.md'],
      ['config', 'set', 'TEAM_AGENTS', 'x'],
      ['say', 'dev', 'hello'], ['notify', 'dev', 'x'], ['close', 'P1'], ['teardown'],
      ['smoke'], ['review', 'P1'], ['change', 'status', 'x'], ['archive', 'x'], ['bg', 'list'],
      ['add-agent', 'bob'], ['init'], ['bootstrap'], ['draft', 'x'], ['outbox', 'flush'],
      ['inbox', 'x'], ['thread', 'dev'], ['monitor'], ['pr', 'x'], ['gh', 'x'], ['frobnicate'],
    ]
    for (const tokens of outside) {
      const h = await harness(EXT, { cwd: proj })
      await h.run(tokens.join(' '))
      const msg = h.rec.messages[0]?.content ?? ''
      check(`表外拒绝且零进程：team ${tokens.join(' ')}`, h.rec.execs.length === 0 && msg.includes('不认') && msg.includes('PM') && msg.includes('终端'),
        `execs=${h.rec.execs.length} msg=${msg.slice(0, 40)}`)
    }
    const named = await harness(EXT, { cwd: proj })
    await named.run('config set TEAM_AGENTS x')
    check('拒绝文案点名被拒的命令 config set', (named.rec.messages[0]?.content ?? '').includes('config set'), named.rec.messages[0]?.content ?? '')
    for (const tokens of [['config', 'list', '--json'], ['version', '--check']]) {
      const h = await harness(EXT, { cwd: proj })
      await h.run(tokens.join(' '))
      const msg = h.rec.messages[0]?.content ?? ''
      check(`读行多余 token 拒绝且零进程：team ${tokens.join(' ')}`, h.rec.execs.length === 0 && msg.includes('不认') && msg.includes('PM') && msg.includes('终端'),
        `execs=${h.rec.execs.length}`)
      check(`读行多余 token 被点名：${tokens[tokens.length - 1]}`, msg.includes(tokens[tokens.length - 1]), msg.slice(0, 60))
    }
  }

  if (want('menu')) {
    group('menu')
    const h = await harness(EXT, { cwd: proj })
    await h.run('')
    const menu = h.rec.messages[0]?.content ?? ''
    const mod = h.mod
    check('无参 /team 印菜单且进对话正文（display）', h.rec.messages.length === 1 && h.rec.messages[0].display === true && h.rec.execs.length === 0)
    check('菜单与「从同一张表独立重算」逐字相同', menu === expectedMenu(mod),
      menu === expectedMenu(mod) ? '' : '菜单不是从表渲染的')
    for (const row of mod.TEAM_ROWS) {
      for (const p of row.paths) {
        const name = p.join(' ')
        check(`菜单列出表里这一行：${name}`, menu.includes(name), `菜单里没有 ${name}`)
      }
    }
    const rowNames = mod.TEAM_ROWS.map((r: any) => r.paths.map((p: string[]) => p.join(' '))).flat()
    const cmdLines = menu.split('\n').filter((l: string) => l.startsWith('  ') && rowNames.some((n: string) => l.slice(2).startsWith(n)))
    check('菜单的命令行列数 = 表里的行数（不多不少；pulse 一行三路径）', cmdLines.length === mod.TEAM_ROWS.length,
      `lines=${cmdLines.length} rows=${mod.TEAM_ROWS.length}`)
    const h2 = await harness(EXT, { cwd: proj })
    await h2.run('help')
    check('/team help 印同一张菜单', (h2.rec.messages[0]?.content ?? '') === menu)
    const paths = mod.TEAM_ROWS.flatMap((r: any) => r.paths.map((p: string[]) => p.join(' ')))
    const comp = h.rec.commands[0].opts.getArgumentCompletions('')
    check('补全的首词集合来自同一张表', JSON.stringify(comp.map((c: any) => c.value).sort()) === JSON.stringify([...paths].sort()),
      `comp=${comp.map((c: any) => c.value).join(',')}`)
    const compC = h.rec.commands[0].opts.getArgumentCompletions('conf')
    check('补全按前缀过滤（conf → config list / config upgrade-models）',
      JSON.stringify(compC.map((c: any) => c.value).sort()) === JSON.stringify(['config list', 'config upgrade-models']),
      JSON.stringify(compC.map((c: any) => c.value)))
  }

  if (want('refuse')) {
    group('refuse')
    for (const tokens of [['up'], ['up', '--fresh-pm'], ['status', '--fresh-pm']]) {
      const h = await harness(EXT, { cwd: proj })
      await h.run(tokens.join(' '))
      const msg = h.rec.messages[0]?.content ?? ''
      check(`up / --fresh-pm 拒绝且零进程：team ${tokens.join(' ')}`, h.rec.execs.length === 0 && h.rec.messages.length === 1,
        `execs=${h.rec.execs.length}`)
      check(`PM 会话原因 + 终端出路：team ${tokens.join(' ')}`, msg.includes('PM 会话') && msg.includes('终端'), msg.slice(0, 60))
    }
    const h = await harness(EXT, { cwd: proj })
    await h.run('dispatch dev P1 docs/team/tasks/P1.md')
    check('拒绝路径零副作用（无 exec、无窗口、无文件）', h.rec.execs.length === 0 && h.rec.messages.length === 1 && h.rec.notifies.length === 0)
  }

  if (want('output')) {
    group('output')
    {
      const h = await harness(EXT, { cwd: proj, results: [okResult('teamsmith 0.1.0\n')] })
      await h.run('version')
      check('短成功 ⇒ 通知（info）且不进正文', h.rec.notifies.length === 1 && h.rec.notifies[0].type === 'info' && h.rec.messages.length === 0,
        `notify=${h.rec.notifies.length} msg=${h.rec.messages.length}`)
      check('通知内容就是那一行', h.rec.notifies[0]?.message === 'teamsmith 0.1.0', h.rec.notifies[0]?.message ?? '')
    }
    {
      const h = await harness(EXT, { cwd: proj, results: [okResult('a\nb\n')] })
      await h.run('ps')
      const c = h.rec.messages[0]?.content ?? ''
      check('多行成功 ⇒ 进正文且 display', h.rec.messages.length === 1 && h.rec.messages[0].display === true && h.rec.notifies.length === 0)
      check('正文头是命令行与退出码', c.includes('$ team ps') && c.includes('exit 0') && c.includes('--- stdout ---') && c.includes('a') && c.includes('b'), c.slice(0, 40))
      check('多行成功不发失败通知', h.rec.notifies.length === 0)
    }
    {
      const h = await harness(EXT, { cwd: proj, results: [{ stdout: 'out\n', stderr: 'boom\n', code: 3, killed: false }] })
      await h.run('doctor')
      const c = h.rec.messages[0]?.content ?? ''
      check('非 0 ⇒ 失败通知点名退出码 3', h.rec.notifies.length === 1 && h.rec.notifies[0].type === 'error' && h.rec.notifies[0].message.includes('3'),
        JSON.stringify(h.rec.notifies))
      check('非 0 ⇒ 正文带两路流与同一个码', c.includes('exit 3') && c.includes('--- stdout ---') && c.includes('out') && c.includes('--- stderr ---') && c.includes('boom'), c.slice(0, 60))
    }
    {
      const h = await harness(EXT, { cwd: proj, results: [{ stdout: '', stderr: '', code: -1, killed: true }] })
      await h.run('ps')
      const c = h.rec.messages[0]?.content ?? ''
      check('被杀 ⇒ 失败通知点名等待上限', h.rec.notifies.length === 1 && h.rec.notifies[0].type === 'error' && h.rec.notifies[0].message.includes('60'),
        JSON.stringify(h.rec.notifies))
      check('被杀 ⇒ 正文写明被杀原因', c.includes('killed') && c.includes('60'), c.slice(0, 60))
    }
    {
      const big = Array.from({ length: 600 }, (_, i) => `line-${i + 1}`).join('\n')
      const h = await harness(EXT, { cwd: proj, results: [okResult(big)] })
      await h.run('status')
      const c = h.rec.messages[0]?.content ?? ''
      check('超量 ⇒ 保留首行', c.includes('line-1\n'), '')
      check('超量 ⇒ 保留末行', c.includes('line-600'), '')
      check('超量 ⇒ 显式说明省略与去哪看全文', c.includes('省略') && c.includes('team status'), c.slice(c.indexOf('省略') - 10, c.indexOf('省略') + 60))
      check('超量 ⇒ 中间行确实被删（line-300 不在）', !c.includes('line-300\n'), '')
    }
  }

  if (want('env')) {
    group('env')
    const mod = await loadExt(EXT)
    const h = await harness(EXT, { cwd: proj, results: [okResult('a\nb\n')] })
    await h.run('config upgrade-models --task-models routine=vendor/light --pm-model vendor/strong')
    const script: string = h.rec.execs[0]?.args[1] ?? ''
    check('剥离包装点名三个「替你说 yes」的变量',
      script.includes('unset TEAM_ASSUME_YES TEAM_UPGRADE_CONFIRMED TEAM_ALLOW_FOREIGN_SESSION;') && script.endsWith('exec "$0" "$@"'),
      script)
    check('用户没打 --yes 就不注入 --yes', JSON.stringify(h.rec.execs[0]?.args.slice(3)) === JSON.stringify(['config', 'upgrade-models', '--task-models', 'routine=vendor/light', '--pm-model', 'vendor/strong']),
      JSON.stringify(h.rec.execs[0]?.args.slice(3)))
    const h2 = await harness(EXT, { cwd: proj, results: [okResult('a\nb\n')] })
    await h2.run('config upgrade-models --task-models routine=vendor/light --pm-model vendor/strong --yes')
    check('用户自己打的 --yes 原样到达', h2.rec.execs[0]?.args.slice(3).includes('--yes'), JSON.stringify(h2.rec.execs[0]?.args.slice(3)))
    check('UNSET_VARS 就是那三个（单一来源）',
      JSON.stringify(mod.UNSET_VARS) === JSON.stringify(['TEAM_ASSUME_YES', 'TEAM_UPGRADE_CONFIRMED', 'TEAM_ALLOW_FOREIGN_SESSION']),
      JSON.stringify(mod.UNSET_VARS))
  }

  if (want('resolve')) {
    group('resolve')
    const mod = await loadExt(EXT)
    check('项目根：从 cwd 向上找到含 .pi/team/config.sh 的目录', mod.findProjectRoot(join(proj, 'a', 'b')) === proj,
      String(mod.findProjectRoot(join(proj, 'a', 'b'))))
    const noProj = join(TMP, 'noproj')
    mkdirSync(noProj, { recursive: true })
    check('不是 teamsmith 项目 ⇒ null', mod.findProjectRoot(noProj) === null)
    const h = await harness(EXT, { cwd: join(proj, 'a', 'b'), results: [okResult('a\nb\n')] })
    await h.run('ps')
    check('子进程 cwd = 解析出的项目根（不是当前子目录）', h.rec.execs[0]?.options?.cwd === proj, String(h.rec.execs[0]?.options?.cwd))
    check('CLI 解析：项目本地安装永远赢过 TEAM_CLI', mod.resolveCli(proj, { TEAM_CLI: '/nonexistent/cli' }) === cliLocal,
      String(mod.resolveCli(proj, { TEAM_CLI: '/nonexistent/cli' })))
    const bare = join(TMP, 'bareproj')
    mkdirSync(join(bare, '.pi', 'team'), { recursive: true })
    writeFileSync(join(bare, '.pi', 'team', 'config.sh'), 'TEAM_SESSION=bare\n')
    check('CLI 解析：没有项目本地时用 TEAM_CLI', mod.resolveCli(bare, { TEAM_CLI: '/tmp/fake-cli' }) === '/tmp/fake-cli',
      String(mod.resolveCli(bare, { TEAM_CLI: '/tmp/fake-cli' })))
    const extSib = join(TMP, 'sib', 'extension')
    mkdirSync(join(TMP, 'sib', 'scripts'), { recursive: true })
    writeFileSync(join(TMP, 'sib', 'scripts', 'team'), '#!/usr/bin/env bash\nexit 0\n', { mode: 0o755 })
    check('CLI 解析：都没有时用扩展的兄弟目录', mod.resolveCli(bare, {}, extSib) === join(TMP, 'sib', 'scripts', 'team'),
      String(mod.resolveCli(bare, {}, extSib)))
    check('CLI 解析：都找不到 ⇒ null', mod.resolveCli(bare, {}, join(TMP, 'nowhere')) === null)
    const h3 = await harness(EXT, { cwd: noProj })
    await h3.run('ps')
    check('不是项目 ⇒ 拒绝并指名 config.sh，零进程', h3.rec.execs.length === 0 && (h3.rec.messages[0]?.content ?? '').includes('config.sh'),
      h3.rec.messages[0]?.content ?? '')
    const bare2 = join(TMP, 'bare2')
    mkdirSync(join(bare2, '.pi', 'team'), { recursive: true })
    writeFileSync(join(bare2, '.pi', 'team', 'config.sh'), 'TEAM_SESSION=b2\n')
    // 隔离副本：它自己的兄弟目录没有 scripts/team，所以三条解析路线全空 ⇒ 必须拒绝并指名 team init。
    const isoDir = join(TMP, 'isolated', 'extension')
    mkdirSync(isoDir, { recursive: true })
    const isoExt = join(isoDir, 'team.ts')
    writeFileSync(isoExt, readFileSync(EXT, 'utf8'))
    const h4 = await harness(isoExt, { cwd: bare2 })
    await h4.run('ps')
    check('找不到 CLI ⇒ 拒绝并指名 team init，零进程', h4.rec.execs.length === 0 && (h4.rec.messages[0]?.content ?? '').includes('team init'),
      h4.rec.messages[0]?.content ?? '')
  }

  if (want('probe')) {
    group('probe')
    const mod = await loadExt(EXT)
    const cli = join(TREE, 'skills', 'teamsmith', 'scripts', 'team')
    check('探针前提：CLI 在', existsSync(cli), cli)
    // 探针在**最小夹具项目**（git 仓库 + docs/team/）里跑：只问 dispatcher 是否分发这条路径，
    // 不读真仓库的账本、也不受它规模影响（真仓库里 digest 要 12s，这里 60ms）。
    const pp = join(TMP, 'probe-proj')
    rmSync(pp, { recursive: true, force: true })
    mkdirSync(join(pp, '.pi', 'team'), { recursive: true })
    mkdirSync(join(pp, 'docs', 'team'), { recursive: true })
    writeFileSync(join(pp, '.pi', 'team', 'config.sh'), 'TEAM_SESSION=probe\n')
    spawnSync('git', ['init', '-q', '-b', 'main'], { cwd: pp, encoding: 'utf8' })
    spawnSync('git', ['-c', 'user.email=c@teamsmith', '-c', 'user.name=c', 'commit', '-q', '--allow-empty', '-m', 'init'], { cwd: pp, encoding: 'utf8' })
    const cleanEnv: Record<string, string> = {}
    for (const [k, v] of Object.entries(process.env)) {
      if (/^TEAM_/.test(k) || /^TMUX/.test(k)) continue
      cleanEnv[k] = v as string
    }
    const runCli = (tokens: string[]) => {
      const r = spawnSync('bash', [cli, ...tokens, '--teamsmith-slash-probe'], { cwd: pp, encoding: 'utf8', timeout: 60000, env: cleanEnv })
      return `${r.stdout ?? ''}${r.stderr ?? ''}`
    }
    let ownRefusals = 0
    for (const row of mod.TEAM_ROWS) {
      for (const p of row.paths) {
        const out = runCli(p)
        const top = `未知子命令：${p[0]}`
        if (out.includes('未知参数') || out.includes('未知子命令')) ownRefusals++
        check(`表里这一行 CLI 真的分发：team ${p.join(' ')}`, !out.includes(top), out.split('\n')[0].slice(0, 60))
      }
    }
    check('探针非空洞：至少 5 行得到 CLI 自己的参数/子命令拒绝（真的分发了）', ownRefusals >= 5, `ownRefusals=${ownRefusals}`)
    const bad = runCli(['frobnicate'])
    check('红侧样本：表外命令得到顶层「未知子命令：frobnicate」', bad.includes('未知子命令：frobnicate'), bad.split('\n')[0].slice(0, 60))
  }

  if (savedCli === undefined) delete process.env.TEAM_CLI
  else process.env.TEAM_CLI = savedCli
}

// ---------------------------------------------------------------- 翻转变异（scratch 副本）
type Mutation = { name: string; groups: string[]; apply: (src: string) => string | null }
const MUTATIONS: Mutation[] = [
  {
    name: 'menu-decoupled', groups: ['menu'],
    apply: (s) => {
      const from = 'export function renderMenu(): string {'
      if (!s.includes(from)) return null
      return s.replace(from, `${from} return '硬编码菜单：team status';`)
    },
  },
  {
    name: 'unset-empty', groups: ['env'],
    apply: (s) => {
      const from = "export const UNSET_VARS = ['TEAM_ASSUME_YES', 'TEAM_UPGRADE_CONFIRMED', 'TEAM_ALLOW_FOREIGN_SESSION']"
      if (!s.includes(from)) return null
      return s.replace(from, 'export const UNSET_VARS: string[] = []')
    },
  },
  {
    name: 'refuse-short-circuit', groups: ['refuse', 'whitelist'],
    apply: (s) => {
      const from = 'export function matchInvocation(tokens: string[]): Match {\n  if (tokens.length === 0) return { kind: \'menu\' }'
      if (!s.includes(from)) return null
      return s.replace(from, "export function matchInvocation(tokens: string[]): Match {\n  if (true) return { kind: 'run', row: TEAM_ROWS[0], tokens }\n  if (tokens.length === 0) return { kind: 'menu' }")
    },
  },
  {
    name: 'no-failure-notify', groups: ['output'],
    apply: (s) => {
      const from = "  if (res.killed || res.code !== 0) deps.notify(failureNotice(m.tokens, res), 'error')\n"
      if (!s.includes(from)) return null
      return s.replace(from, '')
    },
  },
  {
    name: 'entry-to-notify', groups: ['output'],
    apply: (s) => {
      const from = '  const content = formatEntry(m.tokens, res)\n  deps.sendMessage({ customType: CUSTOM_TYPE, content, display: true })'
      if (!s.includes(from)) return null
      return s.replace(from, "  const content = formatEntry(m.tokens, res)\n  deps.notify(content, 'info')")
    },
  },
  {
    name: 'no-fuse', groups: ['output'],
    apply: (s) => {
      const from = '  if (lines.length <= FUSE_LINES && bytes <= FUSE_BYTES) return text'
      if (!s.includes(from)) return null
      return s.replace(from, '  if (true) return text')
    },
  },
  {
    name: 'table-frobnicate', groups: ['probe'],
    apply: (s) => {
      const from = 'export const TEAM_ROWS: Row[] = ['
      if (!s.includes(from)) return null
      return s.replace(from, `${from}\n  { group: 'read', paths: [['frobnicate']], forms: [['frobnicate']], purpose: '红侧样本' },`)
    },
  },
]

function runChild(extPath: string, groups: string[]): { pass: number; fail: number; out: string } {
  const r = spawnSync(process.execPath, [process.argv[1], '--ext', extPath, '--tree', TREE, '--tmp', TMP, '--groups', groups.join(',')],
    { encoding: 'utf8', timeout: 600000, env: { ...process.env, SLASH_TEAM_CHILD: '1' } })
  const out = `${r.stdout ?? ''}${r.stderr ?? ''}`
  const pass = Number((out.match(/RESULT pass=(\d+)/) ?? [])[1] ?? -1)
  const fail = Number((out.match(/RESULT pass=\d+ fail=(\d+)/) ?? [])[1] ?? -1)
  return { pass, fail, out }
}

async function runFlips(): Promise<void> {
  console.log('\n== flip ==')
  for (const m of MUTATIONS) {
    const src = readFileSync(EXT, 'utf8')
    const mutated = m.apply(src)
    if (mutated === null || mutated === src) {
      FAIL++
      console.log(`  \u2717 flip ${m.name}：变异没落地（夹具没生效）`)
      continue
    }
    const dir = join(TMP, `flip-${m.name}`)
    mkdirSync(dir, { recursive: true })
    const file = join(dir, 'team.ts')
    writeFileSync(file, mutated)
    const control = runChild(EXT, m.groups)
    const red = runChild(file, m.groups)
    const controlGreen = control.fail === 0 && control.pass > 0
    const redHit = red.fail > 0
    if (controlGreen && redHit) {
      PASS++
      console.log(`  \u2713 flip ${m.name}：对照绿（pass=${control.pass} fail=0）→ 变异红（pass=${red.pass} fail=${red.fail}）`)
      const named = red.out.split('\n').filter((l) => l.includes('\u2717')).slice(0, 2)
      for (const l of named) console.log(`      ${l.trim()}`)
    } else {
      FAIL++
      console.log(`  \u2717 flip ${m.name}：${controlGreen ? '' : '对照没有全绿 '}${redHit ? '' : '变异后判据还绿（没钉住）'}`)
      console.log(`      control pass=${control.pass} fail=${control.fail} / red pass=${red.pass} fail=${red.fail}`)
    }
    if (existsSync(file)) rmSync(dir, { recursive: true, force: true })
  }
}

  if (want('args')) {
    group('args')
    // 缺陷类：参数分支漏 shift ⇒ 脚本永不退出、零输出地空转（PM 2026-10-16 收掉过一个挂了 1h35m 的
    // `--keep` 进程）。这里把红侧钉在 e2e 的**前进守卫**上：拿掉 shift 的变异副本必须在秒级 rc=2、
    // 并点名缺 shift —— 同类缺陷从此不许再静默转下去。
    const e2ePath = join(TREE, 'skills', 'teamsmith', 'tests', 'slash-team-e2e.sh')
    const dir = join(TMP, 'arg-guard')
    mkdirSync(join(dir, 'lib'), { recursive: true })
    const src = readFileSync(e2ePath, 'utf8')
    const mutated = src.replace('--keep)    KEEP=1; export TEAM_TMP_KEEP=1; shift ;;',
                               '--keep)    KEEP=1; export TEAM_TMP_KEEP=1 ;;')
    check('变异落地：e2e 的 --keep 分支被拿掉 shift', mutated !== src)
    writeFileSync(join(dir, 'slash-team-e2e.sh'), mutated)
    copyFileSync(join(TREE, 'skills', 'teamsmith', 'tests', 'lib', 'tmp-root.sh'), join(dir, 'lib', 'tmp-root.sh'))
    const t0 = Date.now()
    const r = spawnSync('timeout', ['10', 'bash', join(dir, 'slash-team-e2e.sh'), '--keep'], { encoding: 'utf8', timeout: 20000 })
    const dt = Date.now() - t0
    const out = `${r.stdout ?? ''}${r.stderr ?? ''}`
    check('漏 shift 的副本：前进守卫立刻 rc=2（不是空转）', r.status === 2, `status=${String(r.status)} ${dt}ms`)
    check('守卫点名「参数循环没有前进」', out.includes('参数循环没有前进'), out.split('\n').slice(-2).join(' | ').slice(0, 120))
    check('守卫秒级返回（原始缺陷会转 1h35m）', dt < 8000, `${dt}ms`)
    // 正面：真脚本的 --keep 与 --flip 都必须被解析到位（argv 存档是 re-exec 的前提）
    const realE2e = readFileSync(e2ePath, 'utf8')
    check('e2e 存了原始 argv 再交守卫（re-exec 不丢 --flip）',
      realE2e.includes('ORIG_ARGS=("$@")') && realE2e.includes('e2e_guard "${ORIG_ARGS[@]}"'))
    rmSync(dir, { recursive: true, force: true })
  }

if (process.env.SLASH_TEAM_CHILD === '1') {
  await runGroups()
  console.log(`\nRESULT pass=${PASS} fail=${FAIL}`)
  process.exitCode = FAIL === 0 ? 0 : 1
} else {
  await runGroups()
  if (FLIP) await runFlips()
  console.log(`\nRESULT pass=${PASS} fail=${FAIL}`)
  if (FAIL > 0) {
    console.log(`FAILED:\n${failures.slice(0, 20).map((f) => `  - ${f}`).join('\n')}`)
  }
  process.exitCode = FAIL === 0 ? 0 : 1
}
DRIVER

args=(--ext "$ext" --tree "$tree" --tmp "$tmp")
[ -n "$SEL_GROUPS" ] && args+=(--groups "$SEL_GROUPS")
[ "$FLIP" = "1" ] && args+=(--flip)

"$BUN" "$tmp/drive.ts" "${args[@]}"
rc=$?
exit "$rc"
