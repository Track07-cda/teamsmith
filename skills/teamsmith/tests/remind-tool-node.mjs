#!/usr/bin/env node
// P442: invalid PM contexts stop before Reminder state; full authority input survives unchanged.
// Real Pi/tmux evidence lives in remind-tool-real.mjs. This file supplies the fast zero-I/O and flip arms.
import assert from 'node:assert/strict'
import { cpSync, existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs'
import { dirname, join, resolve } from 'node:path'
import { fileURLToPath, pathToFileURL } from 'node:url'
import { spawnSync } from 'node:child_process'

const tests = dirname(fileURLToPath(import.meta.url)), skill = dirname(tests)
const root = mkdtempSync('/var/tmp/p442-tool-node-')
const repo = join(root, 'repo'), state = join(repo, '.pi/team/state'), config = join(repo, '.pi/team/config.sh')
const snapshot = join(state, 'reminders/state.json')
const env = { ...process.env, HOME: join(root, 'home'), TMPDIR: root,
  TEAM_ROOT: repo, TEAM_MAIN_ROOT: repo, TEAM_STATE_DIR: state, TEAM_CONFIG_FILE: config,
  TEAM_PM_WINDOW: 'pm', TEAM_SESSION: 'p442-node' }
let passed = 0
const pass = name => { passed++; console.log(`PASS ${name}`) }
const command = (bin, args, cwd = repo) => {
  const result = spawnSync(bin, args, { cwd, env, encoding: 'utf8' })
  assert.equal(result.status, 0, `${bin} ${args.join(' ')}: ${result.stderr}`)
}
const context = cwd => ({ cwd, sessionManager: { getSessionId: () => 'ordinary-session', getSessionFile: () => join(root, 'ordinary.jsonl') } })
async function loadExtension(base) {
  const tools = [], handlers = {}
  let activeTools = ['read', 'team_remind']
  const pi = {
    registerTool: definition => { tools.push(definition); if (definition.exposure === 'direct' && !activeTools.includes(definition.name)) activeTools.push(definition.name) },
    getActiveTools: () => activeTools.slice(),
    setActiveTools: names => { activeTools = names.slice() },
    on: (name, fn) => { (handlers[name] ||= []).push(fn) },
  }
  const factory = (await import(pathToFileURL(join(base, 'extension/team-remind.ts')).href)).default
  await factory(pi)
  return { tools, handlers, active: () => activeTools.slice() }
}
const actionInput = action => action === 'add' ? { action, after: '1h', message: 'must not be written' }
  : action === 'list' ? { action } : { action, id: 'rem-00000000-0000-0000-0000-000000000000-1' }

try {
  for (const path of [state, dirname(config), join(root, 'home')]) mkdirSync(path, { recursive: true })
  writeFileSync(config, "TEAM_PROJECT='p442-node'\nTEAM_SESSION='p442-node'\nTEAM_PM_WINDOW='pm'\nTEAM_PM_MODEL='p442/controlled'\nTEAM_TASK_MODELS='code=p442/controlled'\n")
  command('git', ['init', '-q', '-b', 'main'])
  const worker = join(root, 'worker')
  writeFileSync(join(repo, 'README'), 'fixture')
  command('git', ['add', 'README'])
  command('git', ['-c', 'user.name=fixture', '-c', 'user.email=fixture@example.invalid', 'commit', '-qm', 'fixture'])
  command('git', ['worktree', 'add', '-q', '--detach', worker, 'HEAD'])

  const host = await loadExtension(skill)
  assert.equal(host.tools.at(-1).exposure, 'hidden')
  for (const [name, cwd, reason] of [['ordinary', repo, 'startup'], ['worker', worker, 'startup'], ['forged', repo, 'reload']]) {
    if (reason === 'reload') await host.handlers.session_start[0]({ reason: 'reload' }, context(cwd))
    else await host.handlers.session_start[0]({ reason: 'startup' }, context(cwd))
    assert.equal(host.tools.at(-1).exposure, 'hidden', `${name}: tool must be hidden`)
    assert(!host.active().includes('team_remind'), `${name}: active tool list withdrew team_remind`)
    for (const action of ['add', 'list', 'show', 'cancel']) {
      await assert.rejects(host.tools.at(-1).execute('call', actionInput(action), undefined, undefined, context(cwd)), /refused|not a verified/, `${name}/${action}`)
      assert(!existsSync(snapshot), `${name}/${action}: no Reminder snapshot may be read or created`)
    }
    pass(`${name}: hidden and all four actions refuse with zero Reminder state`)
  }
  const schema = host.tools.at(-1).parameters
  for (const forbidden of ['project', 'owner', 'state', 'statePath', 'recipient', 'source']) assert(!Object.hasOwn(schema.properties, forbidden))
  pass('tool schema has no caller-selected project/owner/state/recipient/source')

  // Deliberate defect: bypass only execute's PM check. The same invalid context now writes, proving the
  // zero-state assertions above have teeth. The scratch copy contains only the modules this extension loads.
  const flipped = join(root, 'flipped-skill')
  for (const relative of ['extension/team-remind.ts', 'scripts/remind-capability.mjs', 'scripts/reply-capture.mjs',
    'scripts/replies.mjs', 'scripts/state-authority.mjs', 'scripts/remind-store.mjs']) {
    mkdirSync(dirname(join(flipped, relative)), { recursive: true }); cpSync(join(skill, relative), join(flipped, relative))
  }
  const extensionPath = join(flipped, 'extension/team-remind.ts')
  const original = readFileSync(extensionPath, 'utf8'), anchor = 'const identity = verify(ctx)'
  assert.equal(original.split(anchor).length, 2)
  writeFileSync(extensionPath, original.replace(anchor,
    "const identity = { root: ctx.cwd, state: join(ctx.cwd, '.pi/team/state'), config: join(ctx.cwd, '.pi/team/config.sh') }"))
  const badHost = await loadExtension(flipped)
  await badHost.handlers.session_start[0]({ reason: 'startup' }, context(repo))
  const badResult = await badHost.tools.at(-1).execute('call', actionInput('add'), undefined, undefined, context(repo))
  assert.equal(badResult.details.ok, true)
  assert(existsSync(snapshot), 'the identity-check mutation must really write in the invalid context')
  pass('flip: removing execute identity proof turns the same invalid add into a write')

  // Direct authority presentation: no key means independent IDs; a 64 KiB body and its final newline survive.
  rmSync(snapshot, { force: true })
  const capability = await import(pathToFileURL(join(skill, 'scripts/remind-capability.mjs')).href)
  const assertConfigValues = module => {
    const parse = (value, key = 'TEAM_SESSION') => module.configValue(`${key}=${value}\n`, key)
    assert.equal(parse('"p442-node"    # tmux session name'), 'p442-node', 'default generated quoted value with trailing comment')
    assert.equal(parse('"p442#node" # hash inside quotes'), 'p442#node', 'quoted # belongs to the value')
    assert.equal(parse("'p442#node'\t# hash inside quotes"), 'p442#node', 'single-quoted # belongs to the value')
    assert.equal(parse('p442-node    # tmux session name'), 'p442-node', 'unquoted value loses its whitespace-delimited comment')
    assert.equal(parse('p442#node'), 'p442#node', 'unquoted # without preceding whitespace belongs to the value')
  }
  assertConfigValues(capability)
  pass('config: default comments, quoted hashes and unquoted values parse by behavior')

  const legacyParser = `export function configValue(text, key) {
  const match = new RegExp(\`^\\\\s*(?:export\\\\s+)?\${key}=(.*)\\\\s*$\`, 'm').exec(text)
  if (!match) return null
  const raw = match[1].trim()
  if ((raw.startsWith("'") && raw.endsWith("'")) || (raw.startsWith('"') && raw.endsWith('"'))) return raw.slice(1, -1)
  return raw
}`
  const currentParser = readFileSync(join(skill, 'scripts/remind-capability.mjs'), 'utf8').match(/export function configValue\(text, key\) \{[\s\S]*?\n\}/)?.[0]
  assert(currentParser, 'locate the current configValue for the legacy flip')
  const legacyPath = join(root, 'legacy-config.mjs')
  writeFileSync(legacyPath, readFileSync(join(skill, 'scripts/remind-capability.mjs'), 'utf8')
    .replace(currentParser, () => legacyParser)
    .replace("'./reply-capture.mjs'", JSON.stringify(pathToFileURL(join(skill, 'scripts/reply-capture.mjs')).href)))
  const legacy = await import(pathToFileURL(legacyPath).href)
  let legacyFailure
  try { assertConfigValues(legacy) } catch (e) { legacyFailure = e }
  assert.match(legacyFailure?.message ?? '', /default generated quoted value with trailing comment/,
    'restoring the old parser must turn the named default-config assertion red')
  console.log(`EXPECTED RED configValue: ${legacyFailure.message.split('\n')[0]}`)
  pass('flip: restoring old configValue turns the named default-config assertion red')

  const identity = { root: repo, state, config }
  const capabilityRecord = generation => ({ generation, extensionVersion: 'fixture', status: 'registered', exposure: 'direct' })
  capability.publishRemindCapability(identity, capabilityRecord('before-remove'))
  capability.removeRemindCapability(identity, 'before-remove')
  assert(!existsSync(join(state, 'remind-tool/current.json')), 'matching shutdown removes capability evidence')
  capability.publishRemindCapability(identity, capabilityRecord('after-remove'))
  assert.equal(JSON.parse(readFileSync(join(state, 'remind-tool/current.json'), 'utf8')).generation, 'after-remove',
    'a new session can immediately publish after removal without inheriting a held lock')
  const large = `${'x'.repeat(64 * 1024)}\n`
  const first = await capability.runReminderAuthority({ identity, skill, action: 'add', params: { after: '1h', message: large } })
  const second = await capability.runReminderAuthority({ identity, skill, action: 'add', params: { after: '1h', message: large } })
  assert(first.reminder.id !== second.reminder.id)
  assert.equal(first.reminder.source, 'pm-tool')
  assert.equal(first.reminder.message, large)
  const listed = await capability.runReminderAuthority({ identity, skill, action: 'list', params: {} })
  assert.equal(listed.active.find(item => item.id === first.reminder.id).message, large)
  const shown = await capability.runReminderAuthority({ identity, skill, action: 'show', params: { id: first.reminder.id } })
  assert.equal(shown.reminder.message, large)
  const cancelled = await capability.runReminderAuthority({ identity, skill, action: 'cancel', params: { id: first.reminder.id } })
  assert.equal(cancelled.outcome, 'cancelled')
  pass('authority: full text and capability removal followed immediately by a new registration')

  const truncating = join(root, 'truncating.mjs')
  const capabilitySource = readFileSync(join(skill, 'scripts/remind-capability.mjs'), 'utf8')
    .replace("'./reply-capture.mjs'", JSON.stringify(pathToFileURL(join(skill, 'scripts/reply-capture.mjs')).href))
  const truncateAnchor = "input = Buffer.from(params.message, 'utf8')"
  assert.equal(capabilitySource.split(truncateAnchor).length, 2)
  writeFileSync(truncating, capabilitySource.replace(truncateAnchor,
    "params = { ...params, message: params.message.slice(0, 65536) };\n    input = Buffer.from(params.message, 'utf8')"))
  const badCapability = await import(pathToFileURL(truncating).href)
  const truncated = await badCapability.runReminderAuthority({ identity, skill, action: 'add', params: { after: '1h', message: large } })
  assert.equal(truncated.reminder.message.length, 65536)
  assert(!truncated.reminder.message.endsWith('\n'))
  pass('flip: truncating the tool input loses the final newline and is caught by the full-text assertions')

  console.log(`remind-tool-node: passed=${passed} failed=0`)
} finally {
  rmSync(root, { recursive: true, force: true })
}
