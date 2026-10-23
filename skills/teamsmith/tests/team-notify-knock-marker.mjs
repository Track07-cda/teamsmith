#!/usr/bin/env node
// P370 · 敲门层的标记样品（`smoke.sh` §12b-pi 的三层形状比对之一：TS×2 + bash×1 必须同一种标记）。
//
//   node skills/teamsmith/tests/team-notify-knock-marker.mjs skills/teamsmith/extension/team-notify.ts
//
// 做法：在一个一次性 git 项目 + 工作树里，用**产品扩展本身**跑一次 `agent_settled`（末消息 3000 字），
// 再从它产出的敲门载荷里取出那串 `truncated=preview:<shown>/<total>B full=<path>[:<line>]`，打到 stdout。
// 假 tmux 只在 PATH 里：它让投递走既有的「多行内容落成 draft 文件、只打一行指针」路径，于是载荷落在
// 项目自己的 `state/draft/` 里可读。
//
// 没有载荷 / 载荷没有被剪 / 扩展报错 → stdout 空、退出码 0：判定留给调用方（"缺样品" 在那里是红，
// 不是这里的热闹）。真正的失败信息走 stderr，调用方把它贴进门禁日志。
import { execFileSync } from 'node:child_process'
import { existsSync, mkdirSync, mkdtempSync, readFileSync, readdirSync, rmSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join, resolve } from 'node:path'

const ext = resolve(process.argv[2] ?? '')
if (!existsSync(ext)) {
  console.error(`team-notify-knock-marker: 找不到扩展 ${ext}`)
  process.exit(2)
}

// 身份隔离（M7.2 纪律）：一条继承来的 TEAM_* 都不许把样品指到真实项目/真实账本上。
for (const k of Object.keys(process.env)) if (k.startsWith('TEAM_')) delete process.env[k]
delete process.env.TMUX_PANE
delete process.env.TMUX

const TMP = mkdtempSync(join(tmpdir(), 'p370-knock-'))
process.on('exit', () => { try { rmSync(TMP, { recursive: true, force: true }) } catch { /* ignore */ } })

const ROOT = join(TMP, 'repo')
const WT = join(ROOT, '.worktrees/dev')
const git = (...a) => execFileSync('git', ['-C', ROOT, ...a], { stdio: 'pipe' })
mkdirSync(join(ROOT, 'docs/team/inbox'), { recursive: true })
mkdirSync(join(ROOT, '.pi/team'), { recursive: true })
git('init', '-q', '-b', 'main')
git('config', 'user.email', 'knock-marker@teamsmith')
git('config', 'user.name', 'knock-marker')
writeFileSync(join(ROOT, 'README.md'), '# p370 knock marker\n')
writeFileSync(join(ROOT, '.pi/team/config.sh'), [
  'TEAM_PROJECT="p370-knock"', 'TEAM_SESSION="p370-knock"', 'TEAM_PM_WINDOW="pm"',
  'TEAM_WORKTREES_DIR=".worktrees"', 'TEAM_DOCS_DIR="docs/team"',
  'TEAM_NOTIFY_TMUX="1"', 'TEAM_NOTIFY_DEDUP_SEC="0"', 'TEAM_INBOX_MAX_CHARS="150"',
  `TEAM_NOTIFY_LOG="${join(TMP, 'notify.log')}"`, 'TEAM_AGENTS="dev"', '',
].join('\n'))
git('add', '-A')
git('commit', '-qm', 'init')
git('worktree', 'add', '-q', '-b', 'agent/dev', WT)

const shim = join(TMP, 'shim')
mkdirSync(shim)
writeFileSync(join(shim, 'tmux'), `#!/usr/bin/env bash
case "$*" in
  *pane_current_command*) printf 'pi\\n' ;;
  *window_name*) printf 'dev\\n' ;;
  *session_name*) printf 'p370-knock\\n' ;;
  *) printf '' ;;
esac
exit 0
`, { mode: 0o755 })
process.env.PATH = `${shim}:${process.env.PATH}`
process.env.TMUX_PANE = 'knock-marker-pane'

const mod = await import(`${ext}?t=${Date.now()}`)
let settle = null
mod.default({ on: (n, f) => { if (n === 'agent_settled') settle = f }, registerCommand: () => {}, registerTool: () => {}, sendMessage: () => {} })
if (!settle) {
  console.error('team-notify-knock-marker: 扩展没有注册 agent_settled')
  process.exit(3)
}

// 3000 字 > TEAM_INBOX_MAX_CHARS(150)：载荷必然被剪，于是必然带标记。
const text = 'P370-KNOCK-MARKER-' + 'q'.repeat(2980)
await settle({}, { cwd: WT, sessionManager: { getEntries: () => [{ message: { role: 'assistant', stopReason: 'stop', content: [{ text }] } }] } })

const state = join(ROOT, '.pi/team/state')
const walk = (d) => { try { return readdirSync(d, { withFileTypes: true }).flatMap(e => e.isDirectory() ? walk(join(d, e.name)) : [join(d, e.name)]) } catch { return [] } }
const payloads = [...walk(join(state, 'draft')), ...walk(join(state, 'outbox'))]
  .map(f => { try { return readFileSync(f, 'utf8') } catch { return '' } })
  .filter(t => t.includes('P370-KNOCK-MARKER-'))
if (payloads.length === 0) {
  console.error('team-notify-knock-marker: 一次 settle 之后找不到敲门载荷（state/draft 与 state/outbox 都是空的）')
  process.exit(0)
}
const marker = payloads.map(t => /truncated=preview:[0-9]+\/[0-9]+B full=[^ \n]*/.exec(t)).find(Boolean)
if (!marker) {
  console.error(`team-notify-knock-marker: 载荷被剪了却没有标记（${payloads[0].slice(0, 120)}…）`)
  process.exit(0)
}
console.log(marker[0])
