// The clipboard probe's headless sibling (P20/B4, tasks.md 4.2): the pure probe order, the MIME
// rules and the temporary-file write, driven through an injected runner — plus the real bounded
// runner against a fake that never exits (the 1 s/3 s bound is part of the contract, not a hope).
//
//   bun build panel-clipboard-model.ts --target=node --format=esm --outfile /tmp/panel-clipboard-model.js
//   node /tmp/panel-clipboard-model.js
//
// Every case names itself; the first failing case prints its expectation and the exit code is 1.
// `panel-b2.sh clipboard` builds and runs this beside the pty scenarios.

import { chmodSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import {
  CLIPBOARD_LIST_TIMEOUT_MS,
  CLIPBOARD_MAX_BYTES,
  CLIPBOARD_READ_TIMEOUT_MS,
  createClipboardRunner,
  imageExt,
  pasteFilePath,
  pickImageMime,
  readClipboard,
  writePasteFile,
  type ClipboardRunner,
} from '../scripts/panel/src/clipboard.js'

type Case = { name: string; run: () => Promise<string | null> | string | null }

const cases: Case[] = []
const check = (name: string, run: Case['run']): void => {
  cases.push({ name, run })
}

const eq = (what: string, got: unknown, want: unknown): string | null =>
  JSON.stringify(got) === JSON.stringify(want) ? null : `${what}: got ${JSON.stringify(got)}, want ${JSON.stringify(want)}`

const BYTES = 'PNGDATA8'

/** A runner over a per-command script: null = the executable does not exist. */
function fakeRunner(script: Record<string, (args: string[]) => { stdout: string; rc: number } | null>): {
  run: ClipboardRunner
  calls: string[]
} {
  const calls: string[] = []
  const run: ClipboardRunner = async (cmd, args) => {
    calls.push(`${cmd} ${args.join(' ')}`)
    const handler = script[cmd]
    if (!handler) return null
    const out = handler(args)
    return out === null ? null : { stdout: Buffer.from(out.stdout), rc: out.rc }
  }
  return { run, calls }
}

check('wayland: the image read comes from wl-paste and xclip is never called', async () => {
  const { run, calls } = fakeRunner({
    'wl-paste': (args) => {
      if (args[0] === '--list-types') return { stdout: 'text/plain;charset=utf-8\nimage/png\n', rc: 0 }
      if (args[0] === '--type' && args[1] === 'image/png') return { stdout: BYTES, rc: 0 }
      return { stdout: '', rc: 1 }
    },
  })
  const read = await readClipboard(run)
  if (!read || read.kind !== 'image') return `read: ${JSON.stringify(read)}`
  return (
    eq('mime', read.mime, 'image/png') ??
    eq('bytes', read.bytes.toString(), BYTES) ??
    eq('calls', calls, ['wl-paste --list-types', 'wl-paste --type image/png --no-newline'])
  )
})

check('mime: the offered list order picks the type, and only the four are accepted', () => {
  return (
    eq('first accepted in list order', pickImageMime('image/gif\nimage/png\n'), 'image/gif') ??
    eq('png after text', pickImageMime('text/plain\nimage/png'), 'image/png') ??
    eq('parameters are stripped', pickImageMime('image/jpeg;charset=binary'), 'image/jpeg') ??
    eq('svg is outside the four', pickImageMime('image/svg+xml'), null) ??
    eq('empty', pickImageMime(''), null)
  )
})

check('mime: the four extensions, and nothing for anything else', () => {
  return (
    eq('png', imageExt('image/png'), 'png') ??
    eq('jpeg', imageExt('image/jpeg'), 'jpg') ??
    eq('webp', imageExt('image/webp'), 'webp') ??
    eq('gif', imageExt('image/gif'), 'gif') ??
    eq('svg', imageExt('image/svg+xml'), null)
  )
})

check('temp file: ${TMPDIR}/teamsmith-paste-<uuid>.<ext> with the image bytes', () => {
  const dir = mkdtempSync(join(tmpdir(), 'panel-clipboard-'))
  try {
    const path = writePasteFile(Buffer.from(BYTES), 'image/jpeg', dir, 'fixed-uuid')
    if (!path) return 'writePasteFile returned null'
    if (!path.endsWith('teamsmith-paste-fixed-uuid.jpg')) return `path: ${path}`
    return (
      eq('promised path', pasteFilePath('image/jpeg', dir, 'fixed-uuid'), path) ??
      eq('bytes on disk', readFileSync(path, 'utf8'), BYTES) ??
      eq('an unaccepted MIME writes nothing', writePasteFile(Buffer.from(BYTES), 'image/svg+xml', dir, 'x'), null)
    )
  } finally {
    rmSync(dir, { recursive: true, force: true })
  }
})

check('text fallback: no image offered means the clipboard text, still no xclip', async () => {
  const { run, calls } = fakeRunner({
    'wl-paste': (args) => {
      if (args[0] === '--list-types') return { stdout: 'text/plain;charset=utf-8\n', rc: 0 }
      if (args[0] === '--no-newline') return { stdout: 'from the clipboard', rc: 0 }
      return { stdout: '', rc: 1 }
    },
    xclip: () => ({ stdout: 'should not be called', rc: 0 }),
  })
  const read = await readClipboard(run)
  return (
    eq('read', read, { kind: 'text', text: 'from the clipboard' }) ??
    (calls.some((c) => c.startsWith('xclip')) ? `xclip was called: ${calls.join(' | ')}` : null)
  )
})

check('x11 fallback: a failing wl-paste falls through to xclip, in that order', async () => {
  const { run, calls } = fakeRunner({
    'wl-paste': () => ({ stdout: '', rc: 1 }),
    xclip: (args) => {
      if (args.includes('TARGETS')) return { stdout: 'image/png\n', rc: 0 }
      if (args.includes('image/png')) return { stdout: 'XCLIPDATA', rc: 0 }
      return { stdout: '', rc: 1 }
    },
  })
  const read = await readClipboard(run)
  const wlIndex = calls.findIndex((c) => c.startsWith('wl-paste'))
  const xIndex = calls.findIndex((c) => c.startsWith('xclip'))
  return (
    eq('image bytes', read && read.kind === 'image' ? read.bytes.toString() : read, 'XCLIPDATA') ??
    (wlIndex >= 0 && xIndex > wlIndex ? null : `order: ${calls.join(' | ')}`)
  )
})

check('no tool: every probe missing means null and no write', async () => {
  const { run } = fakeRunner({})
  return eq('read', await readClipboard(run), null)
})

check('bound: a never-exiting wl-paste resolves null within the contract', async () => {
  const dir = mkdtempSync(join(tmpdir(), 'panel-clipboard-hang-'))
  const oldPath = process.env.PATH
  try {
    writeFileSync(join(dir, 'wl-paste'), '#!/usr/bin/env bash\nexec /bin/sleep 60\n')
    chmodSync(join(dir, 'wl-paste'), 0o755)
    writeFileSync(join(dir, 'xclip'), '#!/usr/bin/env bash\nexit 1\n')
    chmodSync(join(dir, 'xclip'), 0o755)
    process.env.PATH = `${dir}:${oldPath ?? ''}`
    const started = Date.now()
    const read = await readClipboard(createClipboardRunner())
    const elapsed = Date.now() - started
    const budget = CLIPBOARD_LIST_TIMEOUT_MS + CLIPBOARD_READ_TIMEOUT_MS + 1500
    if (read !== null) return `read: ${JSON.stringify(read)}`
    return elapsed <= budget ? null : `took ${elapsed}ms (> ${budget}ms)`
  } finally {
    process.env.PATH = oldPath
    rmSync(dir, { recursive: true, force: true })
  }
})

check('bound: the byte cap is 50 MiB and the timeouts are the contract s', () => {
  return (
    eq('max bytes', CLIPBOARD_MAX_BYTES, 50 * 1024 * 1024) ??
    eq('list timeout', CLIPBOARD_LIST_TIMEOUT_MS, 1000) ??
    eq('read timeout', CLIPBOARD_READ_TIMEOUT_MS, 3000)
  )
})

let failed = 0
for (const c of cases) {
  const detail = await c.run()
  if (detail === null) {
    console.log(`ok   ${c.name}`)
  } else {
    console.log(`FAIL ${c.name}\n       ${detail}`)
    failed += 1
  }
}
console.log(`panel-clipboard-model: ${cases.length - failed}/${cases.length} passed`)
process.exit(failed === 0 ? 0 : 1)
