#!/usr/bin/env node
/** Product parser/source evidence. All fixtures and mutations stay here, never in product code. */
import assert from 'node:assert/strict'
import { mkdtempSync, mkdirSync, readFileSync, writeFileSync, rmSync, copyFileSync, existsSync, symlinkSync, openSync, closeSync, appendFileSync, chmodSync, lstatSync, realpathSync, constants as C } from 'node:fs'
import { dirname, join, resolve } from 'node:path'
import { fileURLToPath, pathToFileURL } from 'node:url'
import { spawn, spawnSync } from 'node:child_process'

const here = dirname(fileURLToPath(import.meta.url))
const modulePath = process.env.TEST_CAPTURE_MODULE ?? resolve(here, '../scripts/reply-capture.mjs')
const product = await import(pathToFileURL(modulePath).href)
const { parseReply, CaptureJournal, ReplyCapture, runReplyWriter, processIdentity, sourceKey, safeDirectory, inspectRuntime, resolvePMIdentity } = product
const tests = []
const test = (name, run) => tests.push({ name, run })
const message = (text, extra = {}) => ({ role: 'assistant', content: [{ type: 'text', text }], stopReason: 'stop', timestamp: 1, ...extra })
const textOf = m => m.content.filter(b => b.type === 'text').map(b => b.text).join('')
const marker = '[[team-reply]]'
function expect(input, body, candidate, reason) {
  const m = typeof input === 'string' ? message(input) : input
  const parsed = parseReply(m)
  assert.equal(textOf(parsed.message), body)
  assert.equal(parsed.body, body)
  assert.equal(parsed.candidate, candidate)
  if (reason) assert.equal(parsed.reason, reason)
  const original = textOf(m)
  let rebuilt = '', at = 0
  for (const [lo, hi] of parsed.ranges) { rebuilt += original.slice(at, lo); at = hi }
  rebuilt += original.slice(at)
  assert.deepEqual(Buffer.from(parsed.body), Buffer.from(rebuilt), 'original ranges / UTF-8 bytes')
  assert.equal(parsed.message.stopReason, m.stopReason)
  assert.equal(parsed.message.timestamp, m.timestamp)
  return parsed
}

for (const literal of [marker + ' ', ' ' + marker, '\t' + marker, '> ' + marker, '- ' + marker, '\\' + marker,
  '[[Team-reply]]', '[[team-', '[[team-reply:abc]]def]]', '[[team-reply', '[[team-reply:a]]b]]']) {
  test(`literal grammar ${JSON.stringify(literal)}`, () => {
    const m = message(`正文\n${literal}`)
    assert.deepEqual(parseReply(m).message, m)
    assert.equal(parseReply(m).candidate, false)
  })
}
test('exact final marker / own LF only / trailing blanks retained', () => {
  const p = expect(`正文\n${marker}\n \t\n\t`, '正文\n \t\n\t', true)
  assert.deepEqual(p.ranges, [[3, 18]])
  assert.equal(p.title, '正文')
})
test('explicit raw title retained', () => assert.equal(expect('正文\n[[team-reply: 标题 ]]', '正文\n', true).title, ' 标题 '))
for (const title of ['', ' ', 'x'.repeat(161), '\u001b[31m标题', 'a\u202eb', 'a\u200bb', '\ud800']) {
  test(`invalid explicit title ${JSON.stringify(title)}`, () => expect(`正文\n[[team-reply:${title}]]`, '正文\n', false, 'invalid-title'))
}
test('multiple complete lines cleaned / ambiguous', () => expect(`${marker}\n正文\n[[team-reply:标题]]\n`, '正文\n', false, 'ambiguous'))
test('single misplaced complete line cleaned', () => expect(`${marker}\n正文`, '正文', false, 'misplaced'))
test('empty body cleanup', () => expect(` \t\n${marker}`, ' \t\n', false, 'empty-body'))
test('bare CR after marker is not a blank logical line', () => expect(`正文\n${marker}\n\r`, '正文\n\r', false, 'misplaced'))
test('prose introduction does not protect bare reserved line', () => expect(`下面是标记\n${marker}`, '下面是标记\n', true))

const suffix = '示例：\\``\n[[team-reply]]\n`'
test('escaped-first-tick suffix inline-only exact content', () => {
  const m = message(suffix)
  assert.deepEqual(parseReply(m).message, m)
  expect(m, suffix, false, 'unmarked')
})
test('escaped-first-tick suffix inline+real only deletes real final', () => {
  const original = `${suffix}\n答复。\n${marker}`
  const p = expect(original, `${suffix}\n答复。\n`, true)
  assert.equal(p.ranges.length, 1)
})
for (const n of [1, 2, 3, 4]) {
  const input = `${'\\'.repeat(n)}\`\`\n${marker}\n\`\n答复\n${marker}`
  test(`backslash parity ${n} maximal suffix`, () => {
    const odd = n % 2 === 1
    expect(input, odd ? input.slice(0, -marker.length) : input.replace(`${marker}\n`, '').slice(0, -marker.length), odd, odd ? 'candidate' : 'ambiguous')
  })
}
test('in-span backslash does not escape exact closer', () => {
  const input = `\`\`\n${marker}\n\\\`\`\n答复\n${marker}`
  expect(input, input.slice(0, -marker.length), true)
})
test('paired inline spans cross logical lines', () => {
  const input = `\`\`\n${marker}\n\`\`\n正文\n${marker}`
  expect(input, input.slice(0, -marker.length), true)
})
test('maximal runs close only equal lengths not 1 or 3', () => {
  const input = `\`\`\n\`\n${marker}\nx\`\`\`\n${marker}\n\`\`\n正文\n${marker}`
  expect(input, input.slice(0, -marker.length), true)
})
test('unmatched opener literal and later shorter pair still considered', () => {
  const input = `\`\`\n${marker}\n\`\n${marker}\n\`\n正文\n${marker}`
  expect(input, input.replace(`${marker}\n`, '').slice(0, -marker.length), false, 'ambiguous')
})
test('unmatched opener does not swallow real final marker to EOF', () => expect(`\`\` unmatched\n正文\n${marker}`, '`` unmatched\n正文\n', true))
for (const open of ['```js', '~~~text', '   ````']) {
  test(`fence protection ${open}`, () => {
    const close = open.includes('~') ? '~~~~' : '`````'
    const input = `${open}\n${marker}\n${close}\n正文\n${marker}`
    expect(input, input.slice(0, -marker.length), true)
  })
}
test('unclosed fence protects to EOF', () => {
  const input = `~~~\n${marker}\n
tail\n${marker}`
  expect(input, input, false)
})
test('fence closer wrong kind/short/nonblank suffix stays protected', () => {
  const input = `\`\`\`\`\n${marker}\n~~~\n\`\`\`\n\`\`\`\` bad\n${marker}\n\`\`\`\`\n正文\n${marker}`
  expect(input, input.slice(0, -marker.length), true)
})
test('backtick info containing tick is not a fence', () => expect(`\`\`\` info\`\n正文\n${marker}`, '``` info`\n正文\n', true))
test('inline pairs never cross fence boundary', () => {
  const input = `\`\`\n~~~\nexample\n~~~\n${marker}\n\`\`\n正文\n${marker}`
  expect(input, input.replace(`${marker}\n`, '').slice(0, -marker.length), false, 'ambiguous')
})
test('CRLF/Unicode/cross-block offset projection preserves every field', () => {
  const m = message('', { content: [
    { type: 'thinking', thinking: 'hidden [[team-reply]]', signature: 'sig' },
    { type: 'text', text: '😀甲\r\n[[team-', signature: 'a' },
    { type: 'text', text: '', other: { keep: 1 } },
    { type: 'image', data: 'abc', mimeType: 'image/png' },
    { type: 'text', text: 'reply]]\r\n\r\n', signature: 'b' },
    { type: 'toolCall', id: 't1', name: 'read', arguments: { path: 'literal' } },
  ], usage: { output: 12 }, extra: { untouched: true } })
  const p = expect(m, '😀甲\r\n\r\n', true)
  assert.deepEqual(p.ranges, [[5, 21]])
  assert.deepEqual(p.message, { ...m, content: m.content.map((b, i) => i === 1 ? { ...b, text: '😀甲\r\n' } : i === 4 ? { ...b, text: '\r\n' } : b) })
})
test('cross-block inline protection and raw bytes', () => {
  const input = `${suffix}\n答复。\r\n${marker}\r\n\r\n`
  for (let i = 0; i <= input.length; i++) {
    const m = message('', { content: [{ type: 'text', text: input.slice(0, i), signature: '1' }, { type: 'text', text: '' }, { type: 'text', text: input.slice(i), signature: '2' }] })
    expect(m, `${suffix}\n答复。\r\n\r\n`, true)
  }
})
test('derived title ignores Magic Context in title view only', () => {
  const body = '§123§  \n \t§456§  答复😀\n'
  const p = expect(body + marker, body, true)
  assert.equal(p.title, '答复😀')
})
test('derived title removes controls and clips complete codepoints', () => {
  const body = '§7§ \u001b😀'.repeat(200) + '\n'
  const p = expect(body + marker, body, true)
  assert.equal(Array.from(p.title).length, 160)
  assert.ok(!p.title.includes('\u001b'))
})
test('derived title fallback', () => assert.equal(expect(`§7§\n${marker}`, '§7§\n', true).title, '关键回复'))
for (const [name, body, valid] of [['limit exact', 'x'.repeat(131071) + '\n', true], ['limit overflow', 'x'.repeat(131072) + '\n', false], ['NUL', 'x\0\n', false], ['lone surrogate', '\ud800\n', false]]) {
  test(`body ${name}`, () => expect(body + '[[team-reply:标题]]', body, valid, valid ? 'candidate' : 'invalid-body'))
}
for (const stopReason of ['stop', 'toolUse', 'length', 'error', 'aborted']) {
  test(`terminal ${stopReason} always cleans`, () => expect(message(`正文\n${marker}`, { stopReason }), '正文\n', true))
}
for (const role of ['user', 'custom', 'toolResult']) {
  test(`not scanned ${role}`, () => {
    const m = message(`正文\n${marker}`, { role })
    assert.equal(parseReply(m).message, m)
    assert.equal(parseReply(m).candidate, false)
  })
}

async function mutations() {
  const root = mkdtempSync('/var/tmp/p396-parser-flips.')
  const source = readFileSync(modulePath, 'utf8')
  const arms = [
    ['inline-protection', 'ranges.push(...inlineSpans(text, start, text.length))', '// removed inline protection', 'paired inline spans'],
    ['escaped-whole-run', 'const opener = run.start + run.escaped', 'if (run.escaped) continue; const opener = run.start', 'escaped-first-tick suffix inline-only'],
    ['ignore-parity', 'const opener = run.start + run.escaped', 'const opener = run.start', 'backslash parity 1'],
    ['arbitrary-run', 'const closers = byLength.get(length) ?? []', 'const closers = runs.map((_, i) => i)', 'maximal runs close only equal'],
    ['unmatched-EOF', "if (lo === closers.length) continue // Unmatched opener is literal, not protection to EOF.", 'if (lo === closers.length) { ranges.push([opener, end]); break }', 'unmatched opener does not swallow'],
    ['offset-bytes', 'offset += block.text.length', "offset += Buffer.byteLength(block.text, 'utf8')", 'CRLF/Unicode/cross-block offset'],
    ['in-span-escape', 'byLength.get(length).push(index)', 'if (!slashes) byLength.get(length).push(index)', 'in-span backslash'],
  ]
  try {
    const scripts = join(root, 'scripts'); mkdirSync(scripts)
    copyFileSync(resolve(here, '../scripts/replies.mjs'), join(scripts, 'replies.mjs'))
    for (const [name, old, replacement, named] of arms) {
      assert.equal(source.split(old).length, 2, `${name}: unique mutation target`)
      const target = join(scripts, 'reply-capture.mjs')
      writeFileSync(target, source.replace(old, replacement))
      const r = spawnSync(process.execPath, [fileURLToPath(import.meta.url), '--select', 'parser'], { env: { ...process.env, TEST_CAPTURE_MODULE: target }, encoding: 'utf8' })
      const output = `${r.stdout}${r.stderr}`
      if (process.env.TEAM_REPLY_EVIDENCE) {
        mkdirSync(process.env.TEAM_REPLY_EVIDENCE, { recursive: true })
        writeFileSync(join(process.env.TEAM_REPLY_EVIDENCE, `parser-flip-${name}.log`), output)
      }
      assert.equal(r.status, 1, `${name}: product mutation must fail`)
      assert.ok(output.split('\n').some(line => line.startsWith('FAIL ') && line.includes(named)), `${name}: named assertion must fail: ${named}`)
      console.log(`PASS mutation ${name}: named assertion red (${named})`)
    }
    writeFileSync(join(scripts, 'reply-capture.mjs'), source)
    const restored = spawnSync(process.execPath, [fileURLToPath(import.meta.url), '--select', 'parser'], { env: { ...process.env, TEST_CAPTURE_MODULE: join(scripts, 'reply-capture.mjs') }, encoding: 'utf8' })
    assert.equal(restored.status, 0, restored.stdout + restored.stderr)
    console.log('PASS mutation restoration: parser green')
  } finally { rmSync(root, { recursive: true, force: true }) }
}

const sourceTests = []
const state = (name, run) => sourceTests.push({ name, run })
const team = resolve(here, '../scripts/team')
const cleanEnv = Object.fromEntries(Object.entries(process.env).filter(([key]) => !key.startsWith('TEAM_')))
async function fixture(run) {
  const root = mkdtempSync('/var/tmp/p396-source.')
  try {
    const init = spawnSync('git', ['init', '-q', '-b', 'main', root], { encoding: 'utf8' })
    assert.equal(init.status, 0, init.stderr)
    mkdirSync(join(root, '.pi/team/state'), { recursive: true })
    writeFileSync(join(root, '.pi/team/config.sh'), '# private fixture\n')
    writeFileSync(join(root, 'session.jsonl'), '')
    const identity = { root, state: join(root, '.pi/team/state'), config: join(root, '.pi/team/config.sh'), sessionId: 'private-session', sessionFile: join(root, 'session.jsonl') }
    const branch = [], diagnostics = []
    let current = true, verified = true, calls = 0
    const view = () => ({ identity: { ...identity }, leaf: branch.at(-1)?.id ?? null, branch: [...branch], entry: id => branch.find(entry => entry.id === id) })
    const writer = async record => { calls++; return runReplyWriter({ team, identity, env: cleanEnv }, record) }
    const journal = new CaptureJournal(identity)
    const options = { identity, journal, current: () => current, verify: () => verified, writer, owner: { ...processIdentity(process.pid), generation: 'test-owner' }, diagnostic: d => diagnostics.push(d) }
    const engine = new ReplyCapture(options)
    const snapshot = () => JSON.parse(readFileSync(journal.path, 'utf8'))
    const cli = (args, input, env = cleanEnv) => spawnSync('bash', [team, '--root', root, 'reply', ...args], { cwd: root, input, env, encoding: 'utf8' })
    const list = () => { const r = cli(['list', '--json']); assert.equal(r.status, 0, r.stderr); return JSON.parse(r.stdout) }
    const emit = (input, id = `entry-${branch.length + 1}`, { bind = true, settle = true, aborted = false, begin = true } = {}) => {
      if (begin) engine.before(view())
      engine.start(input, view())
      const cleaned = engine.end(input, view())
      branch.push({ type: 'message', id, parentId: branch.at(-1)?.id ?? null, message: cleaned })
      if (bind) engine.turn({ messageEntryId: id, message: cleaned }, view())
      if (settle) engine.settled({ aborted }, view())
      return cleaned
    }
    await run({ root, identity, branch, view, engine, journal, options, emit, snapshot, cli, list, diagnostics,
      calls: () => calls, revoke: () => { current = false }, degrade: () => { verified = false } })
  } finally { rmSync(root, { recursive: true, force: true }) }
}
const records = f => Object.values(f.snapshot().sources)
state('null first leaf stages unbound then actual binding pending then settled saved/raw', () => fixture(async f => {
  f.engine.before(f.view()); assert.equal(f.view().leaf, null)
  const input = message('§123§ 完整😀正文\r\n[[team-reply:真实标题]]\r\n\r\n')
  f.engine.start(input, f.view())
  const cleaned = f.engine.end(input, f.view())
  assert.equal(textOf(cleaned), '§123§ 完整😀正文\r\n\r\n')
  assert.equal(Object.values(f.snapshot().intents)[0].status, 'unbound')
  assert.equal(records(f).length, 0); assert.equal(f.calls(), 0)
  f.branch.push({ type: 'message', id: 'actual-entry', message: cleaned })
  f.engine.turn({ messageEntryId: 'actual-entry', message: cleaned }, f.view())
  assert.equal(records(f)[0].status, 'pending'); assert.equal(f.calls(), 0)
  f.engine.settled({ aborted: false }, f.view()); await f.engine.drain()
  const record = records(f)[0]
  assert.equal(record.status, 'saved'); assert.equal(record.no, 1); assert.equal(f.calls(), 1)
  assert.deepEqual(record.source, [f.identity.root, f.identity.state, f.identity.sessionId, f.identity.sessionFile, 'actual-entry'])
  const raw = f.cli(['show', '1', '--raw']); assert.equal(raw.status, 0, raw.stderr)
  assert.deepEqual(Buffer.from(raw.stdout), Buffer.from(textOf(cleaned)))
}))
state('escaped suffix inline-only no journal and inline+real one real writer/raw', () => fixture(async f => {
  f.emit(message(suffix)); await f.engine.drain()
  assert.equal(f.calls(), 0); assert.ok(!existsSync(f.journal.path))
  const body = `${suffix}\n答复。\n`
  f.emit(message(body + marker)); await f.engine.drain()
  assert.equal(f.calls(), 1); assert.equal(records(f)[0].status, 'saved')
  assert.equal(f.cli(['show', '1', '--raw']).stdout, body)
}))
for (const [name, input] of [['queued ordinary', message('普通最终回答')], ['tool', message(`tool\n${marker}`, { stopReason: 'toolUse', content: [{ type: 'text', text: `tool\n${marker}` }, { type: 'toolCall', id: 'c1', name: 'read', arguments: {} }] })], ['error', message(`error\n${marker}`, { stopReason: 'error' })], ['length', message(`length\n${marker}`, { stopReason: 'length' })], ['aborted', message(`aborted\n${marker}`, { stopReason: 'aborted' })]]) {
  state(`latest supersession ${name} no backward search`, () => fixture(async f => {
    f.emit(message(`earlier\n${marker}`), 'early', { settle: false })
    const cleaned = f.emit(input, 'latest', { begin: false })
    await f.engine.drain()
    assert.ok(!textOf(cleaned).includes(marker)); assert.equal(f.calls(), 0)
    assert.equal(records(f).length, 1); assert.equal(records(f)[0].status, 'pending')
  }))
}
state('retry/before-settle continuation replaces earlier marked stop', () => fixture(async f => {
  f.emit(message(`earlier\n${marker}`), 'early', { settle: false })
  f.emit(message(`final\n${marker}`), 'final', { begin: false })
  await f.engine.drain()
  assert.equal(f.calls(), 1)
  assert.deepEqual(records(f).map(r => r.status), ['pending', 'saved'])
  assert.equal(f.cli(['show', '1', '--raw']).stdout, 'final\n')
}))
state('overall abort after successful stop denies eligibility', () => fixture(async f => {
  f.emit(message(`answer\n${marker}`), 'e1', { aborted: true })
  await f.engine.drain(); assert.equal(f.calls(), 0); assert.equal(records(f)[0].status, 'pending')
  new ReplyCapture(f.options).recover(f.view()); assert.equal(f.calls(), 0)
}))
state('no binding never substitutes current leaf or same body', () => fixture(async f => {
  f.emit(message(`answer\n${marker}`), 'e1', { bind: false })
  await f.engine.drain(); assert.equal(f.calls(), 0); assert.equal(records(f).length, 0)
  new ReplyCapture(f.options).recover(f.view()); assert.equal(f.calls(), 0)
}))
state('mismatched entry binding is invalidated not repaired', () => fixture(async f => {
  f.emit(message(`answer\n${marker}`), 'e1', { bind: false, settle: false })
  const good = f.branch[0].message
  f.engine.turn({ messageEntryId: 'wrong', message: good }, f.view())
  f.engine.turn({ messageEntryId: 'e1', message: good }, f.view())
  f.engine.settled({ aborted: false }, f.view()); await f.engine.drain()
  assert.equal(f.calls(), 0); assert.equal(records(f).length, 0)
}))
state('same-body distinct entries each save while duplicate events do not', () => fixture(async f => {
  const input = message(`identical\n${marker}`)
  for (const id of ['e1', 'e2']) {
    const cleaned = f.emit(input, id, { settle: false })
    f.engine.end(input, f.view())
    f.engine.turn({ messageEntryId: id, message: cleaned }, f.view())
    f.engine.settled({ aborted: false }, f.view()); f.engine.settled({ aborted: false }, f.view())
    await f.engine.drain()
    new ReplyCapture(f.options).recover(f.view())
  }
  await f.engine.drain(); assert.equal(f.calls(), 2)
  assert.deepEqual(records(f).map(r => r.no), [1, 2])
}))
state('source barrier survives saved beyond newest page', () => fixture(async f => {
  f.emit(message(`old\n${marker}`), 'old'); await f.engine.drain()
  for (let n = 0; n < 51; n++) {
    const post = f.cli(['post', '--from', 'manual', '--title', 'newer', '--stdin'], `newer ${n}`)
    assert.equal(post.status, 0, post.stderr)
  }
  const engine = new ReplyCapture(f.options); engine.recover(f.view()); await engine.drain()
  assert.equal(f.calls(), 1); assert.equal(records(f)[0].no, 1)
  const page = f.list(); assert.equal(page.entries.length, 50); assert.ok(page.entries.every(row => row.no > 1))
}))
state('new activity prevents recovery; session/branch witness cannot import', () => fixture(async f => {
  const originalAttempt = f.engine.attempt
  f.engine.attempt = () => {}
  f.emit(message(`eligible\n${marker}`), 'e1')
  assert.equal(records(f)[0].status, 'eligible')
  f.engine.attempt = originalAttempt
  f.engine.before(f.view()); f.engine.recover(f.view()); assert.equal(f.calls(), 0)
  f.engine.reset()
  const other = { ...f.view(), identity: { ...f.identity, sessionId: 'fork' } }
  f.engine.recover(other); assert.equal(f.calls(), 0)
  f.engine.recover({ ...f.view(), branch: [], leaf: null }); await f.engine.drain(); assert.equal(f.calls(), 0)
  f.engine.recover(f.view()); await f.engine.drain(); assert.equal(f.calls(), 1)
}))
state('CAS two engines recover one eligible source once', () => fixture(async f => {
  f.engine.attempt = () => {}
  f.emit(message(`eligible\n${marker}`), 'e1')
  const a = new ReplyCapture(f.options), b = new ReplyCapture(f.options)
  a.recover(f.view()); b.recover(f.view()); await Promise.all([a.drain(), b.drain()])
  assert.equal(f.calls(), 1); assert.equal(records(f)[0].status, 'saved')
}))
state('CAS stale discoveries cannot both attempt the same eligible source', () => fixture(async f => {
  f.engine.attempt = () => {}; f.emit(message(`eligible\n${marker}`), 'e1')
  const discovered = structuredClone(records(f)[0])
  const a = new ReplyCapture(f.options), b = new ReplyCapture(f.options)
  a.attempt(discovered, f.view()); b.attempt(discovered, f.view())
  await Promise.all([a.drain(), b.drain()])
  assert.equal(f.calls(), 1); assert.equal(records(f)[0].status, 'saved')
}))
state('two processes recover one eligible source with one real writer', () => fixture(async f => {
  f.engine.attempt = () => {}; f.emit(message(`eligible\n${marker}`), 'e1')
  writeFileSync(join(f.root, 'crash-identity.json'), JSON.stringify(f.identity))
  writeFileSync(join(f.root, 'crash-branch.json'), JSON.stringify(f.branch))
  const children = [1, 2].map(() => {
    const child = spawn(process.execPath, [fileURLToPath(import.meta.url), '--recover-child', f.root], { env: cleanEnv, stdio: ['pipe', 'pipe', 'pipe'] })
    let stdout = '', stderr = ''
    const ready = new Promise((resolve, reject) => {
      child.stdout.on('data', data => { stdout += data; if (stdout.includes('READY\n')) resolve() })
      child.on('error', reject); child.on('exit', () => { if (!stdout.includes('READY\n')) reject(new Error(`child died before ready: ${stderr}`)) })
    })
    child.stderr.on('data', data => { stderr += data })
    const closed = new Promise(resolve => child.on('close', code => resolve({ code, stderr })))
    return { child, ready, closed }
  })
  try {
    await Promise.all(children.map(c => c.ready))
    for (const c of children) c.child.stdin.end('go')
    for (const c of children) { const result = await c.closed; assert.equal(result.code, 0, result.stderr) }
    assert.equal(readFileSync(join(f.root, 'attempt.log'), 'utf8').trim().split('\n').length, 1)
    assert.equal(records(f)[0].status, 'saved'); assert.equal(f.list().entries.length, 1)
  } finally { for (const c of children) if (c.child.exitCode === null) c.child.kill('SIGKILL') }
}))
state('degraded identity and staging exception still return cleaned message', () => fixture(async f => {
  f.engine.before(f.view()); f.engine.start(message(''), f.view()); f.degrade()
  const clean = f.engine.end(message(`answer\n${marker}`), f.view())
  assert.equal(textOf(clean), 'answer\n'); assert.equal(f.calls(), 0); assert.ok(!existsSync(f.journal.path))
}))
state('staging disk failure never leaves marker or guesses binding', () => fixture(async f => {
  f.journal.transact = () => { throw Object.assign(new Error('disk full'), { code: 'ENOSPC' }) }
  const clean = f.emit(message(`answer\n${marker}`))
  await f.engine.drain(); assert.equal(textOf(clean), 'answer\n'); assert.equal(f.calls(), 0)
  assert.ok(f.diagnostics.some(d => d.reason === 'stage:ENOSPC'))
}))
state('symlink journal/lock/unsafe ancestor refused with normal cleanup', () => fixture(async f => {
  mkdirSync(f.journal.directory)
  writeFileSync(join(f.root, 'outside'), 'do not change')
  symlinkSync(join(f.root, 'outside'), `${f.journal.path}.lock`)
  const clean = f.emit(message(`answer\n${marker}`)); await f.engine.drain()
  assert.equal(textOf(clean), 'answer\n'); assert.equal(f.calls(), 0)
  assert.equal(readFileSync(join(f.root, 'outside'), 'utf8'), 'do not change')
}))
state('old owner callback cannot record result after generation replacement', () => fixture(async f => {
  let release
  const engine = new ReplyCapture({ ...f.options, writer: record => new Promise(resolve => { release = async () => resolve(await f.options.writer(record)) }) })
  engine.before(f.view()); const input = message(`answer\n${marker}`)
  engine.start(input, f.view()); const cleaned = engine.end(input, f.view())
  f.branch.push({ type: 'message', id: 'e1', message: cleaned }); engine.turn({ messageEntryId: 'e1', message: cleaned }, f.view())
  engine.settled({ aborted: false }, f.view()); await Promise.resolve()
  assert.equal(records(f)[0].status, 'attempting'); f.revoke(); await release(); await engine.drain()
  assert.equal(records(f)[0].status, 'attempting'); assert.equal(f.calls(), 1)
}))

state('real writer busy 5 never retries', () => fixture(async f => {
  const directory = join(f.identity.state, 'key-replies'); mkdirSync(directory)
  const lock = openSync(join(directory, 'writer.lock'), C.O_RDWR | C.O_CREAT, 0o600)
  try {
    const acquired = spawnSync('flock', ['-x', '3'], { stdio: ['ignore', 'ignore', 'ignore', lock] }); assert.equal(acquired.status, 0)
    let actual
    const engine = new ReplyCapture({ ...f.options, writer: async record => { actual = await f.options.writer(record); return actual } })
    const input = message(`busy answer\n${marker}`)
    engine.before(f.view()); engine.start(input, f.view()); const clean = engine.end(input, f.view())
    f.branch.push({ type: 'message', id: 'e1', message: clean }); engine.turn({ messageEntryId: 'e1', message: clean }, f.view())
    engine.settled({ aborted: false }, f.view()); await engine.drain()
    assert.equal(actual.status, 5); assert.equal(textOf(clean), 'busy answer\n')
    assert.equal(records(f)[0].status, 'not-written'); assert.equal(records(f)[0].reason, 'busy')
  } finally { closeSync(lock) }
  const resumed = new ReplyCapture(f.options); resumed.recover(f.view()); await resumed.drain()
  assert.equal(f.calls(), 1); assert.equal(f.list().entries.length, 0)
}))
state('real fail:index-fsync unconfirmed 6 candidate never relabelled or retried', () => fixture(async f => {
  let actual
  const engine = new ReplyCapture({ ...f.options, writer: async record => {
    actual = await runReplyWriter({ team, identity: f.identity, env: { ...cleanEnv, TEAM_REPLY_FAULT: 'fail:index-fsync' } }, record)
    return actual
  } })
  const input = message(`unconfirmed answer\n${marker}`)
  engine.before(f.view()); engine.start(input, f.view()); const clean = engine.end(input, f.view())
  f.branch.push({ type: 'message', id: 'e1', message: clean }); engine.turn({ messageEntryId: 'e1', message: clean }, f.view())
  engine.settled({ aborted: false }, f.view()); await engine.drain()
  assert.equal(actual.status, 6); assert.equal(records(f)[0].status, 'unconfirmed')
  assert.equal(records(f)[0].candidate_no, 1); assert.equal(records(f)[0].no, undefined)
  const resumed = new ReplyCapture(f.options); resumed.recover(f.view()); await resumed.drain()
  assert.equal(f.calls(), 0); assert.equal(f.list().entries.length, 1)
  assert.equal(f.cli(['show', '1', '--raw']).stdout, textOf(clean))
}))
for (const fault of ['missing', 'malformed', 'inconsistent', 'result-journal']) {
  state(`real committed writer ${fault} never retries`, () => fixture(async f => {
    const transact = f.journal.transact.bind(f.journal)
    if (fault === 'result-journal') f.journal.transact = (change, opts) => transact(snapshot => {
      const result = change(snapshot)
      if (Object.values(snapshot.sources).some(record => record.status === 'saved')) throw Object.assign(new Error('result disk failure'), { code: 'ENOSPC' })
      return result
    }, opts)
    const engine = new ReplyCapture({ ...f.options, writer: async record => {
      const result = await f.options.writer(record)
      assert.equal(result.status, 0)
      if (fault === 'missing') result.stdout = ''
      if (fault === 'malformed') result.stdout = 'not json'
      if (fault === 'inconsistent') { const receipt = JSON.parse(result.stdout); receipt.sha256 = '0'.repeat(64); result.stdout = JSON.stringify(receipt) }
      return result
    } })
    const input = message(`complete answer ${fault}\n${marker}`)
    engine.before(f.view()); engine.start(input, f.view()); const clean = engine.end(input, f.view())
    f.branch.push({ type: 'message', id: 'e1', message: clean }); engine.turn({ messageEntryId: 'e1', message: clean }, f.view())
    engine.settled({ aborted: false }, f.view()); await engine.drain()
    assert.equal(records(f)[0].status, fault === 'result-journal' ? 'attempting' : 'uncertain')
    const resumed = new ReplyCapture({ ...f.options, journal: new CaptureJournal(f.identity) }); resumed.recover(f.view()); await resumed.drain()
    assert.equal(f.calls(), 1); assert.equal(f.list().entries.length, 1)
    assert.equal(f.cli(['show', '1', '--raw']).stdout, textOf(clean))
  }))
}
state('diagnostic sink failure still cleans terminal answer', () => fixture(async f => {
  const engine = new ReplyCapture({ ...f.options, diagnostic: () => { throw new Error('closed diagnostic sink') }, journal: { path: f.journal.path, transact: () => { throw new Error('disk unavailable') } } })
  engine.before(f.view()); engine.start(message(''), f.view())
  const clean = engine.end(message(`answer\n${marker}`), f.view()); assert.equal(textOf(clean), 'answer\n')
}))

function crashChild(point, root) {
  const identity = JSON.parse(readFileSync(join(root, 'crash-identity.json'), 'utf8'))
  const journal = new CaptureJournal(identity)
  const branch = []
  const view = () => ({ identity, branch, leaf: branch.at(-1)?.id ?? null, entry: id => branch.find(entry => entry.id === id) })
  const engine = new ReplyCapture({ identity, journal, current: () => true, verify: () => true,
    writer: record => runReplyWriter({ team, identity, env: cleanEnv }, record),
    owner: processIdentity(process.pid), diagnostic: d => console.error(d.reason) })
  const exitAt = boundary => { if (point === boundary) process.exit(74) }
  const transact = journal.transact.bind(journal)
  journal.transact = (change, opts) => {
    const result = transact(snapshot => {
      const result = change(snapshot)
      if (Object.values(snapshot.sources).some(r => r.status === 'eligible')) exitAt('during-eligible')
      if (Object.values(snapshot.sources).some(r => r.status === 'attempting')) exitAt('during-attempting')
      return result
    }, opts)
    const snapshot = JSON.parse(readFileSync(journal.path, 'utf8'))
    if (Object.values(snapshot.sources).some(r => r.status === 'attempting')) exitAt('after-attempting')
    return result
  }
  engine.before(view()); const input = message(`crash answer\n${marker}`); engine.start(input, view())
  exitAt('before-stage')
  const cleaned = engine.end(input, view()); exitAt('after-stage'); exitAt('before-append')
  branch.push({ type: 'message', id: 'crash-entry', message: cleaned })
  writeFileSync(join(root, 'crash-branch.json'), JSON.stringify(branch)); exitAt('after-append'); exitAt('before-binding')
  engine.turn({ messageEntryId: 'crash-entry', message: cleaned }, view()); exitAt('after-binding')
  if (point === 'after-eligible') engine.attempt = () => process.exit(74)
  engine.settled({ aborted: false }, view())
  throw new Error(`crash boundary not reached: ${point}`)
}
for (const point of ['before-stage', 'after-stage', 'before-append', 'after-append', 'before-binding', 'after-binding', 'during-eligible', 'after-eligible', 'during-attempting', 'after-attempting']) {
  state(`external process death ${point}: only durable eligible can recover`, () => fixture(async f => {
    writeFileSync(join(f.root, 'crash-identity.json'), JSON.stringify(f.identity))
    const child = spawnSync(process.execPath, [fileURLToPath(import.meta.url), '--crash-child', point, f.root], { env: cleanEnv, encoding: 'utf8' })
    assert.equal(child.status, 74, child.stderr)
    if (existsSync(join(f.root, 'crash-branch.json'))) f.branch.push(...JSON.parse(readFileSync(join(f.root, 'crash-branch.json'), 'utf8')))
    const resumed = new ReplyCapture({ ...f.options, journal: new CaptureJournal(f.identity) })
    resumed.recover(f.view()); await resumed.drain()
    const allowed = ['after-eligible', 'during-attempting'].includes(point)
    assert.equal(f.calls(), allowed ? 1 : 0)
    if (allowed) assert.equal(records(f)[0].status, 'saved')
    if (point === 'after-attempting') assert.equal(records(f)[0].status, 'uncertain')
    resumed.recover(f.view()); await resumed.drain(); assert.equal(f.calls(), allowed ? 1 : 0)
  }))
}
for (const fault of ['kill:body-staged', 'kill:index-written', 'kill:index-durable', 'fail:index-write']) {
  state(`real writer interruption ${fault} remains uncertain/no automatic retry`, () => fixture(async f => {
    let calls = 0, actual
    const engine = new ReplyCapture({ ...f.options, writer: async record => {
      calls++; actual = await runReplyWriter({ team, identity: f.identity, env: { ...cleanEnv, TEAM_REPLY_FAULT: fault } }, record); return actual
    } })
    const input = message(`fault answer\n${marker}`)
    engine.before(f.view()); engine.start(input, f.view()); const clean = engine.end(input, f.view())
    f.branch.push({ type: 'message', id: 'e1', message: clean }); engine.turn({ messageEntryId: 'e1', message: clean }, f.view())
    engine.settled({ aborted: false }, f.view()); await engine.drain()
    assert.notEqual(actual.status, 0); assert.equal(records(f)[0].status, 'uncertain'); assert.equal(textOf(clean), 'fault answer\n')
    const resumed = new ReplyCapture({ ...f.options, journal: new CaptureJournal(f.identity) }); resumed.recover(f.view()); await resumed.drain()
    assert.equal(calls, 1); assert.equal(f.calls(), 0)
  }))
}

// P415 · The ancestry refusal must name what it refuses, and an own-group 775 layout is not a foreign trust
// domain. Both sides run: the acceptance would go red under the stricter pre-P415 rule (see ancestryFlip).
const ancestryTests = []
const ancestry = (name, run) => ancestryTests.push({ name, run })
const ancestryTemp = () => realpathSync(mkdtempSync('/var/tmp/p415-ancestry.'))
const foreignGroups = () => {
  const saved = [process.getgid, process.getegid, process.getgroups]
  process.getgid = () => 0
  process.getegid = () => 0
  process.getgroups = () => [0]
  return () => { [process.getgid, process.getegid, process.getgroups] = saved }
}
const refusal = (run, ...fragments) => {
  try { run() } catch (e) {
    assert.ok(e.message.startsWith('unsafe directory ancestry'), `expected an ancestry refusal, got: ${e.message}`)
    for (const fragment of fragments) assert.ok(e.message.includes(fragment), `${fragment} missing from: ${e.message}`)
    return e
  }
  return assert.fail('expected an ancestry refusal, the directory was accepted')
}
ancestry('0755 ancestry is accepted (baseline)', () => {
  const root = ancestryTemp()
  try { assert.equal(safeDirectory(root), root) } finally { rmSync(root, { recursive: true, force: true }) }
})
ancestry('0775 owned by this process group is accepted (this machine layout)', () => {
  const root = ancestryTemp()
  const dir = join(root, 'own-group')
  try {
    mkdirSync(dir); chmodSync(dir, 0o775)
    assert.equal(lstatSync(dir).gid, process.getgid(), 'fixture premise: the directory belongs to this process group')
    assert.equal(safeDirectory(dir), dir)
  } finally { rmSync(root, { recursive: true, force: true }) }
})
ancestry('1777 sticky temp parent stays accepted', () => {
  const root = ancestryTemp()
  const dir = join(root, 'sticky')
  try {
    mkdirSync(dir); chmodSync(dir, 0o1777)
    assert.equal(safeDirectory(dir), dir)
  } finally { rmSync(root, { recursive: true, force: true }) }
})
ancestry('0777 other-writable ancestor is refused by path', () => {
  const root = ancestryTemp()
  const dir = join(root, 'open')
  try {
    mkdirSync(dir); chmodSync(dir, 0o777)
    refusal(() => safeDirectory(dir), dir, 'is other-writable')
  } finally { rmSync(root, { recursive: true, force: true }) }
})
ancestry('0775 owned by a group outside the process groups is refused by path', () => {
  const root = ancestryTemp()
  const dir = join(root, 'foreign-group')
  try {
    mkdirSync(dir); chmodSync(dir, 0o775)
    const restore = foreignGroups()
    try { refusal(() => safeDirectory(dir), dir, 'is group-writable outside the effective groups') } finally { restore() }
  } finally { rmSync(root, { recursive: true, force: true }) }
})
ancestry('real git project: own-group 0775 resolves, 0777 root and 0777 state are refused', () => {
  const root = ancestryTemp()
  const state = join(root, '.pi/team/state'), config = join(root, '.pi/team/config.sh'), cwd = process.cwd()
  const context = { cwd: root, sessionId: 'p415-fixture', sessionFile: join(root, 'session.jsonl') }
  try {
    assert.equal(spawnSync('git', ['init', '-q', '-b', 'main', root]).status, 0)
    mkdirSync(state, { recursive: true })
    writeFileSync(config, '# fixture\n')
    writeFileSync(join(root, 'session.jsonl'), '')
    chmodSync(root, 0o775)
    process.chdir(root)
    try {
      // Own group: the ancestry passes and the same entry stops at the next fact it actually needs.
      assert.throws(() => resolvePMIdentity(context, {}), e => e.message === 'missing directed PM launch environment')
      chmodSync(root, 0o777)
      refusal(() => resolvePMIdentity(context, {}), root)
      chmodSync(root, 0o775); chmodSync(state, 0o777)
      refusal(() => resolvePMIdentity(context, { TEAM_STATE_DIR: state, TEAM_CONFIG_FILE: config, TEAM_PM_WINDOW: 'pm', TEAM_SESSION: 'p415' }), state)
    } finally { process.chdir(cwd) }
  } finally { rmSync(root, { recursive: true, force: true }) }
})
ancestry('doctor reason names the directory and the rule, not an errno class', () => {
  const root = ancestryTemp()
  const state = join(root, '.pi/team/state'), config = join(root, '.pi/team/config.sh')
  try {
    mkdirSync(state, { recursive: true })
    writeFileSync(config, '# fixture\n')
    chmodSync(root, 0o775)
    const args = { root, state, config, session: 'p415', window: 'pm', skill: resolve(here, '..') }
    assert.equal(inspectRuntime(args).reason, 'registration:ENOENT', 'a missing registration is not a refusal')
    const restore = foreignGroups()
    try {
      const refused = inspectRuntime(args)
      assert.equal(refused.state, 'unknown')
      assert.ok(refused.reason.startsWith('not registered: unsafe directory ancestry: '), `unexpected reason: ${refused.reason}`)
      assert.ok(refused.reason.includes(root), `the refused directory is missing: ${refused.reason}`)
      assert.ok(refused.reason.includes('is group-writable outside the effective groups'), `the rule is missing: ${refused.reason}`)
    } finally { restore() }
  } finally { rmSync(root, { recursive: true, force: true }) }
})
async function ancestryFlip() {
  const root = mkdtempSync('/var/tmp/p415-flip.')
  try {
    const scripts = join(root, 'scripts'); mkdirSync(scripts)
    copyFileSync(resolve(here, '../scripts/replies.mjs'), join(scripts, 'replies.mjs'))
    const source = readFileSync(modulePath, 'utf8')
    const anchor = "  if (mode & 0o1000) return '' // Sticky directories (system temp) protect entries the caller does not own.\n" +
      "  if (mode & 0o002) return 'is other-writable'\n" +
      "  if ((mode & 0o020) && !groups.has(gid)) return 'is group-writable outside the effective groups'\n  return ''"
    assert.equal(source.split(anchor).length, 2, 'flip: unique target for the pre-P415 rule')
    const target = join(scripts, 'reply-capture.mjs')
    writeFileSync(target, source.replace(anchor, "  return (mode & 0o022) && !(mode & 0o1000) ? 'is other-writable or group-writable' : ''"))
    const red = spawnSync(process.execPath, [fileURLToPath(import.meta.url), '--select', 'ancestry'],
      { env: { ...process.env, TEST_CAPTURE_MODULE: target }, encoding: 'utf8' })
    const lines = `${red.stdout}${red.stderr}`.split('\n')
    assert.equal(red.status, 1, `pre-P415 rule must fail the acceptance: ${lines.join(' | ')}`)
    const flipped = lines.find(line => line.startsWith('FAIL ') && line.includes('0775 owned by this process group'))
    assert.ok(flipped, 'the own-group acceptance must be the assertion that goes red')
    for (const kept of ['0777 other-writable ancestor is refused by path', '1777 sticky temp parent stays accepted']) {
      assert.ok(lines.includes(`PASS ${kept}`), `the flip must not change the ${kept} verdict`)
      assert.ok(!lines.some(line => line.startsWith('FAIL ') && line.includes(kept)), `the flip changed the ${kept} verdict`)
    }
    console.log(`PASS flip pre-P415 rule: own-group acceptance red (${flipped})`)
  } finally { rmSync(root, { recursive: true, force: true }) }
}
// The shipped instruction surfaces print a concrete marker example. This group runs that printed text
// through the product parser and the real writer, so the promise "printed example works" is exercised
// rather than asserted about prose. A broken example must fail here (no vacuous pass).
async function shippedExample() {
  const file = process.env.TEST_EXAMPLE_FILE
  assert.ok(file, 'TEST_EXAMPLE_FILE must name the shipped marker example')
  const text = readFileSync(file, 'utf8')
  const parsed = parseReply(message(text))
  assert.equal(parsed.reason, 'candidate', `shipped marker example is not a publishable candidate (${parsed.reason})`)
  assert.equal(parsed.candidate, true)
  const control = /^\[\[team-reply(?::[^\]]*)?\]\]$/m.exec(text)
  assert.ok(control, 'shipped marker example must contain a final control line')
  assert.equal(parsed.body, text.slice(0, control.index), 'published body is the example minus only the control line')
  await fixture(async f => {
    const cleaned = f.emit(message(text))
    await f.engine.drain()
    assert.equal(f.calls(), 1, 'one real writer attempt')
    assert.deepEqual(records(f).map(r => r.status), ['saved'])
    const page = f.list()
    assert.equal(page.total_slots, 1, 'exactly one published reply')
    const raw = f.cli(['show', '1', '--raw'])
    assert.equal(raw.status, 0, raw.stderr)
    assert.deepEqual(Buffer.from(raw.stdout), Buffer.from(textOf(cleaned)))
    assert.deepEqual(Buffer.from(raw.stdout), Buffer.from(parsed.body))
    assert.equal(records(f)[0].title, parsed.title)
  })
  console.log('PASS shipped marker example: product parser candidate, one real writer save, raw body equals the answer minus the control line')
}

async function stateMutations() {
  const source = readFileSync(modulePath, 'utf8'), root = mkdtempSync('/var/tmp/p396-source-flips.')
  try {
    copyFileSync(resolve(here, '../scripts/replies.mjs'), join(root, 'replies.mjs'))
    const arms = [
      ['source-cas', "if (stored?.status !== 'eligible') return false", 'if (!stored) return false', 'CAS stale discoveries'],
      ['durable-attempt', "stored.status = 'attempting'", "stored.status = 'eligible'", 'external process death after-attempting'],
      ['current-branch', 'return (startLeaf === null || start >= 0) && at > start && end >= at && view.leaf === ids.at(-1)', 'return true', 'new activity prevents recovery'],
    ]
    for (const [name, old, replacement, named] of arms) {
      assert.equal(source.split(old).length, 2, `${name}: unique mutation target`)
      const target = join(root, 'reply-capture.mjs'); writeFileSync(target, source.replace(old, replacement))
      const result = spawnSync(process.execPath, [fileURLToPath(import.meta.url), '--select', 'state'], { env: { ...cleanEnv, TEST_CAPTURE_MODULE: target }, encoding: 'utf8' })
      const output = result.stdout + result.stderr
      if (process.env.TEAM_REPLY_EVIDENCE) { mkdirSync(process.env.TEAM_REPLY_EVIDENCE, { recursive: true }); writeFileSync(join(process.env.TEAM_REPLY_EVIDENCE, `source-flip-${name}.log`), output) }
      assert.equal(result.status, 1, `${name}: red`)
      assert(output.split('\n').some(line => line.startsWith('FAIL ') && line.includes(named)), `${name}: named red ${named}`)
      console.log(`PASS mutation ${name}: named assertion red (${named})`)
    }
    const target = join(root, 'reply-capture.mjs'); writeFileSync(target, source)
    const restored = spawnSync(process.execPath, [fileURLToPath(import.meta.url), '--select', 'state'], { env: { ...cleanEnv, TEST_CAPTURE_MODULE: target }, encoding: 'utf8' })
    assert.equal(restored.status, 0, restored.stdout + restored.stderr)
    console.log('PASS mutation restoration: source green')
  } finally { rmSync(root, { recursive: true, force: true }) }
}
async function recoverChild(root) {
  const identity = JSON.parse(readFileSync(join(root, 'crash-identity.json'), 'utf8'))
  const branch = JSON.parse(readFileSync(join(root, 'crash-branch.json'), 'utf8'))
  const view = { identity, branch, leaf: branch.at(-1)?.id ?? null, entry: id => branch.find(e => e.id === id) }
  console.log('READY')
  await new Promise(resolve => process.stdin.once('data', resolve))
  const engine = new ReplyCapture({ identity, current: () => true, verify: () => true, owner: processIdentity(process.pid), writer: record => {
    appendFileSync(join(root, 'attempt.log'), `${process.pid}\n`)
    return runReplyWriter({ team, identity, env: cleanEnv }, record)
  } })
  engine.recover(view); await engine.drain()
}
const args = process.argv.slice(2)
if (args[0] === '--recover-child') { await recoverChild(args[1]); process.exit(0) }
if (args[0] === '--crash-child') crashChild(args[1], args[2])
let groups = ['parser']
if (args.length && args[0] !== '--all') {
  if (args[0] !== '--select' || args.length !== 2) throw new Error('usage: reply-capture.mjs --all | --select parser,state,mutations,state-mutations,ancestry  (or --select example with TEST_EXAMPLE_FILE)')
  groups = args[1].split(',')
} else if (args[0] === '--all') groups = ['parser', 'state', 'mutations', 'state-mutations', 'ancestry']
if (groups.some(g => !['parser', 'state', 'mutations', 'state-mutations', 'ancestry', 'example'].includes(g))) throw new Error('unknown test group')
let passed = 0, failed = 0
if (groups.includes('parser')) for (const { name, run } of tests) {
  try { await run(); passed++; console.log(`PASS ${name}`) }
  catch (e) { failed++; console.log(`FAIL ${name}: ${e.message}`) }
}
if (groups.includes('state')) for (const { name, run } of sourceTests) {
  try { await run(); passed++; console.log(`PASS ${name}`) }
  catch (e) { failed++; console.log(`FAIL ${name}: ${e.stack}`) }
}
if (groups.includes('mutations')) {
  try { await mutations(); passed += 8 }
  catch (e) { failed++; console.log(`FAIL mutations: ${e.stack}`) }
}
if (groups.includes('state-mutations')) {
  try { await stateMutations(); passed += 4 }
  catch (e) { failed++; console.log(`FAIL state mutations: ${e.stack}`) }
}
if (groups.includes('ancestry')) {
  for (const { name, run } of ancestryTests) {
    try { await run(); passed++; console.log(`PASS ${name}`) }
    catch (e) { failed++; console.log(`FAIL ${name}: ${e.stack}`) }
  }
  // The flip mutates the module under test, so it is meaningless again inside its own child run.
  if (!process.env.TEST_CAPTURE_MODULE) {
    try { await ancestryFlip(); passed++ }
    catch (e) { failed++; console.log(`FAIL ancestry flip: ${e.stack}`) }
  }
}
if (groups.includes('example')) {
  try { await shippedExample(); passed += 1 }
  catch (e) { failed++; console.log(`FAIL example: ${e.stack}`) }
}
console.log(`reply-capture: passed=${passed} failed=${failed}`)
process.exitCode = failed ? 1 : 0
