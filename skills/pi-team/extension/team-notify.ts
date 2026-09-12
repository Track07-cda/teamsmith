/**
 * pi-team · notify 扩展
 *
 * 作用：worker agent 每结束一个回合（`agent_settled`，Pi 不会再自动继续的那个点），
 * 自动把一条简报写进 PM 的收件箱，并（可选）在 PM 的 tmux 窗口里敲一行把它唤醒。
 *
 * 为什么必须显式 `-e` 加载：linked worktree 里 Pi 不会自动发现项目本地的
 * `.pi/extensions/`（CEP 已验证过），所以 `team dispatch` 用 `-e <skill>/extension/team-notify.ts`
 * 显式传入。
 *
 * 守卫（全部失败都静默，通知绝不能影响 agent 会话）：
 *   - cwd 必须位于 <项目根>/<worktrees>/ 之下（主工作树/PM 会话不触发）
 *   - 窗口名不能等于 PM 窗口名（避免 PM 自触发循环）
 *   - tmux session 必须是配置里的那个
 *   - 同样的简报在 TEAM_NOTIFY_DEDUP_SEC 秒内只发一次（Pi 可能连续 settle）
 *
 * 配置来自 <项目根>/.pi/team/config.sh，仅解析需要的少量扁平 KEY=VALUE，
 * 不 source（不在 agent 的 Node 进程里执行项目代码）。
 */
import type { ExtensionAPI } from '@earendil-works/pi-coding-agent'
import { execFileSync } from 'node:child_process'
import { appendFileSync, existsSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs'
import { basename, dirname, join, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

type Cfg = {
  session: string
  pmWindow: string
  worktreesDir: string
  docsDir: string
  notifyTmux: boolean
  dedupSec: number
  maxChars: number
  log: string
}

const DEFAULTS: Cfg = {
  session: 'team',
  pmWindow: 'pm',
  worktreesDir: '.worktrees',
  docsDir: 'docs/team',
  notifyTmux: true,
  dedupSec: 20,
  maxChars: 150,
  log: '/tmp/pi-team-notify.log',
}

/** 本扩展所在 skill 的目录（<skill>/extension/team-notify.ts） */
function skillDir(): string {
  try {
    return resolve(dirname(fileURLToPath(import.meta.url)), '..')
  } catch {
    return ''
  }
}

/** 从 <skill>/scripts/lib/common.sh 读 TEAM_VERSION */
function skillVersion(): string {
  try {
    const f = join(skillDir(), 'scripts/lib/common.sh')
    return /^TEAM_VERSION="([^"]+)"/m.exec(readFileSync(f, 'utf8'))?.[1] ?? ''
  } catch {
    return ''
  }
}

function run(cmd: string, args: string[], cwd?: string): string {
  try {
    return execFileSync(cmd, args, { cwd, encoding: 'utf8', timeout: 5000 }).trim()
  } catch {
    return ''
  }
}

function expand(value: string): string {
  return value
    .replace(/\$\{([A-Za-z_][A-Za-z0-9_]*)\}/g, (_, name: string) => process.env[name] ?? '')
    .replace(/\$([A-Za-z_][A-Za-z0-9_]*)/g, (_, name: string) => process.env[name] ?? '')
}

function unquote(raw: string): string {
  const v = raw.trim()
  if ((v.startsWith('"') && v.endsWith('"')) || (v.startsWith("'") && v.endsWith("'"))) return v.slice(1, -1)
  return v
}

/** 去掉行尾注释：「值 + 空白 + #...」。配置约定：值里不要写 # */
function stripComment(raw: string): string {
  const m = /^(.*?)\s+#.*$/.exec(raw)
  return m ? m[1] : raw
}

/** 定位团队根目录（期望是主工作树）。
 *  注意：agent 的 worktree 里也有 config.sh 的副本，但收件箱必须写主工作树，
 *  所以 git 主工作树优先，向上查找只作为非 git 场景的兜底。 */
function findRoot(cwd: string): string {
  const envRoot = process.env.TEAM_ROOT
  if (envRoot && existsSync(join(envRoot, '.pi/team/config.sh'))) return resolve(envRoot)
  const common = run('git', ['-C', cwd, 'rev-parse', '--path-format=absolute', '--git-common-dir'])
  if (common) {
    const main = dirname(common)
    if (existsSync(join(main, '.pi/team/config.sh'))) return main
  }
  let dir = resolve(cwd)
  for (;;) {
    if (existsSync(join(dir, '.pi/team/config.sh'))) return dir
    const parent = dirname(dir)
    if (parent === dir) break
    dir = parent
  }
  return ''
}

function readCfg(root: string): Cfg {
  const file = process.env.TEAM_CONFIG_FILE || join(root, '.pi/team/config.sh')
  const cfg: Cfg = { ...DEFAULTS }
  let text = ''
  try {
    text = readFileSync(file, 'utf8')
  } catch {
    return cfg
  }
  const values: Record<string, string> = {}
  for (const line of text.split(/\r?\n/)) {
    const m = /^\s*(TEAM_[A-Z0-9_]+)\s*=\s*(.*?)\s*$/.exec(line)
    if (!m) continue
    const raw = m[2]
    values[m[1]] = expand(unquote(stripComment(raw)))
  }
  const pick = (key: string): string | undefined => values[key]?.trim() || undefined
  cfg.session = pick('TEAM_SESSION') ?? cfg.session
  cfg.pmWindow = pick('TEAM_PM_WINDOW') ?? cfg.pmWindow
  cfg.worktreesDir = pick('TEAM_WORKTREES_DIR') ?? cfg.worktreesDir
  cfg.docsDir = pick('TEAM_DOCS_DIR') ?? cfg.docsDir
  if (pick('TEAM_NOTIFY_TMUX')) cfg.notifyTmux = values.TEAM_NOTIFY_TMUX !== '0' && values.TEAM_NOTIFY_TMUX !== 'false'
  const dedup = Number(pick('TEAM_NOTIFY_DEDUP_SEC') ?? NaN)
  if (Number.isFinite(dedup) && dedup >= 0) cfg.dedupSec = dedup
  const max = Number(pick('TEAM_INBOX_MAX_CHARS') ?? NaN)
  if (Number.isFinite(max) && max > 0) cfg.maxChars = max
  cfg.log = pick('TEAM_NOTIFY_LOG') ?? cfg.log
  return cfg
}

function tail(line: string, max: number): string {
  const flat = line.replace(/\s+/g, ' ').trim()
  return flat.length > max ? `${flat.slice(0, max - 1)}…` : flat
}

function log(line: string, cfg: Cfg): void {
  try {
    appendFileSync(cfg.log, `${new Date().toISOString()} ${line}\n`)
  } catch {
    /* ignore */
  }
}

/** 同一条简报在 dedupSec 秒内只发一次 */
function isDuplicate(key: string, sec: number, stateDir: string): boolean {
  if (sec <= 0) return false
  const file = join(stateDir, 'notify-dedup')
  const now = Date.now()
  const rows: Array<[string, number]> = []
  try {
    for (const line of readFileSync(file, 'utf8').split('\n')) {
      const idx = line.indexOf(' ')
      if (idx <= 0) continue
      const t = Number(line.slice(0, idx))
      if (Number.isFinite(t) && now - t < sec * 1000) rows.push([line.slice(idx + 1), t])
    }
  } catch {
    /* first run */
  }
  if (rows.some(([k]) => k === key)) return true
  rows.push([key, now])
  try {
    writeFileSync(file, rows.map(([k, t]) => `${t} ${k}`).join('\n') + '\n')
  } catch {
    /* ignore */
  }
  return false
}

export default function (pi: ExtensionAPI) {
  let count = 0

  pi.on('agent_settled', async (_event, ctx) => {
    const cwd = ctx.cwd ?? process.cwd()
    const root = findRoot(cwd)
    if (!root) return
    const cfg = readCfg(root)

    const wtPrefix = `${resolve(root, cfg.worktreesDir)}/`
    if (!`${resolve(cwd)}`.startsWith(wtPrefix)) {
      log(`skip settle (not in worktrees): cwd=${cwd} root=${root} prefix=${wtPrefix}`, cfg)
      return
    }

    const pane = process.env.TMUX_PANE
    const window = pane ? run('tmux', ['display-message', '-p', '-t', pane, '#{window_name}']) : ''
    const session = pane ? run('tmux', ['display-message', '-p', '-t', pane, '#{session_name}']) : ''
    if (window && window === cfg.pmWindow) {
      log(`skip settle (pm window): window=${window}`, cfg)
      return
    }
    if (window && session && session !== cfg.session) {
      log(`skip settle (session ${session} != ${cfg.session})`, cfg)
      return
    }

    // agent 名：tmux 窗口名优先；无 tmux（headless/脚本）时用 worktree 目录名（约定 .worktrees/<agent>）
    const agent = window || basename(resolve(cwd))
    const branch = run('git', ['-C', cwd, 'rev-parse', '--abbrev-ref', 'HEAD'])
    const task = /^(?:task|agent)\/([^/]+)/.exec(branch)?.[1] ?? ''
    const id = task.split('-')[0] || 'unknown'
    const dirty = run('git', ['-C', cwd, 'status', '--porcelain']).split('\n').filter(Boolean).length
    // 未提交 = 没交付干净：让 PM 一眼看出来（CEP 实测：这种状态和"干净交付"在通知里长得一样）
    const dirtyFlag = dirty > 0 ? `⚠ 未提交 ${dirty} 个文件 · ` : '' 
    const upstream = run('git', ['-C', cwd, 'rev-parse', '--abbrev-ref', '--symbolic-full-name', '@{upstream}'])
    const unpushed = upstream
      ? run('git', ['-C', cwd, 'rev-list', '--count', '@{upstream}..HEAD']) || '?'
      : run('git', ['-C', cwd, 'rev-list', '--count', 'HEAD', '--not', '--remotes']) || '?'

    let last = ''
    try {
      const entries = ctx.sessionManager.getEntries() as Array<{ message?: { role?: string; content?: unknown } }>
      for (let i = entries.length - 1; i >= 0; i--) {
        const message = entries[i]?.message
        if (message?.role !== 'assistant') continue
        const content = message.content
        const text = typeof content === 'string'
          ? content
          : Array.isArray(content)
            ? content
                .map(part => (part && typeof part === 'object' && 'text' in part ? String((part as { text?: unknown }).text ?? '') : ''))
                .join(' ')
            : ''
        if (text.trim()) {
          last = tail(text, cfg.maxChars)
          break
        }
      }
    } catch {
      /* 通知绝不能打断会话 */
    }

    count++
    const summary = [
      `[auto] agent:${agent}`,
      id,
      `branch=${branch || '-'}`,
      `uncommitted=${dirty}`,
      `unpushed=${unpushed}${upstream ? '' : '(no-upstream)'}`,
    ].join(' · ')
    const key = `${agent}|${summary}|${last.slice(0, 60)}`

    const stateDir = join(root, '.pi/team/state')
    try {
      mkdirSync(stateDir, { recursive: true })
    } catch {
      /* ignore */
    }
    if (isDuplicate(key, cfg.dedupSec, stateDir)) {
      log(`dedup settle #${count} ${summary}`, cfg)
      return
    }

    const line = `${new Date().toISOString()} ${dirtyFlag}${summary}${last ? ` :: ${last}` : ''}`
    try {
      const dir = join(root, cfg.docsDir, 'inbox')
      mkdirSync(dir, { recursive: true })
      appendFileSync(join(dir, `${agent}.md`), `- ${line}\n`)
      log(`inbox ${summary}`, cfg)
    } catch (error) {
      log(`inbox write failed: ${String(error)}`, cfg)
    }

    if (!cfg.notifyTmux || !window) return
    try {
      // 安全：只有当 PM 窗口里真的在跑 pi 时才敲键盘。
      // 否则（PM 已退出、窗口停在 shell）send-keys 会被 shell 当命令执行。
      const target = `${cfg.session}:${cfg.pmWindow}`
      const paneCmd = run('tmux', ['display-message', '-p', '-t', target, '#{pane_current_command}'])
      if (!paneCmd || /^(bash|sh|zsh|fish|dash|ash|ksh|nu)$/.test(paneCmd)) {
        log(`skip tmux notify (pm not running: pane=${paneCmd || 'missing'}) inbox only`, cfg)
        return
      }
      const notice = `${dirtyFlag}${summary}${last ? `\n> ${last}` : ''}`
      execFileSync('tmux', ['send-keys', '-t', target, '-l', notice], { timeout: 5000 })
      execFileSync('tmux', ['send-keys', '-t', target, 'Enter'], { timeout: 5000 })
    } catch {
      /* PM 窗口不在：只留收件箱 */
    }
  })

  // ---------------------------------------------------------------------------
  // skill 热重载：/pi-team-reload（/reload 的别名，语义更直白）
  //
  // 为什么需要：skill 更新后，`scripts/**` 立刻生效，但 SKILL.md 的清单/描述
  // 只在下一次资源加载时才刷新。Pi 的 /reload 会重新发现 skills 并重建 system prompt，
  // 所以 PM 发现版本落后时跑这个命令即可，不必重启会话。
  // 工具 reload_skills 让模型也能自助触发：Pi 的工具跑在 ExtensionContext 里，
  // 不能直接调 ctx.reload()，得把命令作为 follow-up 消息排队（官方推荐做法）。
  if (typeof (pi as any).registerCommand === 'function') pi.registerCommand('pi-team-reload', {
    description: '重新加载 skills/扩展（等同于 /reload）——skill 更新后用它生效',
    handler: async (_args: string, ctx: any) => {
      try {
        log('pi-team-reload: reloading resources', readCfg(findRoot(ctx?.cwd ?? process.cwd()) ?? process.cwd()))
      } catch {
        /* ignore */
      }
      await ctx.reload()
      return
    },
  })

  // ---------------------------------------------------------------------------
  // /reload 之后：历史里已经读过的 SKILL.md 是旧文本（Pi 不会改写历史消息），
  // 所以这里主动提醒 agent 重新 read 一遍 skill —— 否则"重载"只刷新了清单/描述，
  // 正文仍是旧的。顺带清掉 team reload 留下的请求标记。
  pi.on('session_start', async (event: any, ctx: any) => {
    try {
      if (event?.reason !== 'reload') return
      const cwd = ctx?.cwd ?? process.cwd()
      const root = findRoot(cwd)
      if (!root) return
      const v = skillVersion()
      const dir = skillDir()
      // 重载已完成 → 清掉请求标记
      try {
        const marker = join(root, '.pi/team/state/reload-requested')
        if (existsSync(marker)) rmSync(marker, { force: true })
      } catch {
        /* ignore */
      }
      const text =
        `[pi-team] skill 已重载${v ? `（v${v}）` : ''}：**历史里读过的 SKILL.md 是旧版**，` +
        `当前会话不会自动更新那段文本。请现在重新 read ${dir}/SKILL.md` +
        `（需要时再读 references/ 或 templates/），然后跑 \`team version --check\` 记录新版本。`
      ;(pi as any).sendMessage(
        { customType: 'pi-team-reloaded', content: text, display: true },
        { deliverAs: 'followUp', triggerTurn: true },
      )
    } catch {
      /* 重载提示绝不能影响会话 */
    }
  })

  if (typeof (pi as any).registerTool === 'function') pi.registerTool({
    name: 'reload_skills',
    description:
      '重新加载 skill/扩展定义（等同于 /reload）。当 team version --check 提示 skill 已更新时调用它。',
    parameters: { type: 'object', properties: {}, additionalProperties: false } as any,
    async execute(_toolCallId: string, _params: any, _signal: any, _onUpdate: any, ctx: any) {
      const prompt = '/pi-team-reload'
      if (typeof ctx?.queueFollowUp === 'function') {
        await ctx.queueFollowUp(prompt)
      } else if (typeof ctx?.pi?.queueFollowUp === 'function') {
        await ctx.pi.queueFollowUp(prompt)
      } else if (typeof ctx?.sendMessage === 'function') {
        await ctx.sendMessage(prompt)
      } else {
        return {
          content: [
            { type: 'text', text: `请手动运行 ${prompt}（当前上下文不支持排队 follow-up 消息）` },
          ],
        }
      }
      return { content: [{ type: 'text', text: `已排队 ${prompt}：本回合结束后会自动重新加载 skill。` }] }
    },
  } as any)
}
