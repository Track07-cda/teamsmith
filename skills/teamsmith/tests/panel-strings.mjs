#!/usr/bin/env node
// String-table gate for the pulse console (pulse-console B3, tasks.md 6.1).
//
//   node skills/teamsmith/tests/panel-strings.mjs [tree]
//
// Checks: non-empty values and matching placeholders; selected-operation key labels and
// displayed settings/source references in both languages. Complete CLI schema/group/fixture
// metadata stays in config-cli.sh; adding an excluded key/group requires no UI label.
// The inherited source-literal walk below is unchanged by this settings-only change.
//
// The tables are plain ESM, so they are copied to a temp dir as `.mjs` and imported with the plain
// JS runtime this script runs on; no TypeScript loader (or bundler) is involved.
//
// Exit: 0 all three checks pass, 1 at least one failed (the message names the key/file).

import { copyFileSync, mkdtempSync, readFileSync, readdirSync, rmSync, statSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join, relative } from 'node:path'
import { pathToFileURL } from 'node:url'

const tree = process.argv[2] || process.cwd()
const srcDir = join(tree, 'skills/teamsmith/scripts/panel/src')
const stringsDir = join(srcDir, 'strings')

const failures = []
const fail = (message) => failures.push(message)
const placeholders = (value) => {
  const set = new Set()
  for (const m of String(value).matchAll(/\{(\w+)\}/g)) set.add(m[1])
  return [...set].sort()
}

const tmp = mkdtempSync(join(tmpdir(), 'panel-strings-'))
try {
  for (const file of ['zh.ts', 'en.ts']) {
    copyFileSync(join(stringsDir, file), join(tmp, file.replace(/\.ts$/, '.mjs')))
  }
  const zh = (await import(pathToFileURL(join(tmp, 'zh.mjs')).href)).zh
  const en = (await import(pathToFileURL(join(tmp, 'en.mjs')).href)).en

  // 1. key declarations (P264: the key-set equality check itself is gone — D170)
  const zhKeys = Object.keys(zh).sort()
  const enKeys = Object.keys(en).sort()

  // 2. value shape + placeholders
  for (const [name, table] of [
    ['zh', zh],
    ['en', en],
  ]) {
    for (const key of Object.keys(table)) {
      const value = table[key]
      if (typeof value !== 'string' || value.length === 0) fail(`${name}.${key} is not a non-empty string`)
    }
  }
  for (const key of zhKeys.filter((k) => enKeys.includes(k))) {
    const a = placeholders(zh[key])
    const b = placeholders(en[key])
    if (a.join(',') !== b.join(',')) fail(`${key}: placeholder mismatch zh={${a.join(',')}} en={${b.join(',')}}`)
  }
  console.log('ok: values are non-empty strings with matching placeholders')

  // 3. no CJK outside the tables (comments stripped: the sources document in prose)
  const CJK = /[\u3400-\u4dbf\u4e00-\u9fff\uf900-\ufaff]/
  const stripComments = (text) =>
    text
      .replace(/\/\*[\s\S]*?\*\//g, '')
      .split('\n')
      .map((line) => line.replace(/\/\/.*$/, ''))
      .join('\n')
  const walk = (dir) => {
    const out = []
    for (const entry of readdirSync(dir)) {
      const full = join(dir, entry)
      if (statSync(full).isDirectory()) {
        if (full === stringsDir) continue
        out.push(...walk(full))
      } else if (/\.(ts|tsx|js|jsx)$/.test(entry)) out.push(full)
    }
    return out
  }
  const hits = []
  for (const file of walk(srcDir)) {
    const lines = stripComments(readFileSync(file, 'utf8')).split('\n')
    lines.forEach((line, i) => {
      if (CJK.test(line)) hits.push(`${relative(tree, file)}:${i + 1}: ${line.trim()}`)
    })
  }
  if (hits.length) {
  }

  // Selected presentation references replace the retired full-schema/group-label bijection.
  const presentation = readFileSync(join(srcDir, 'project-settings.ts'), 'utf8')
  const keys = [...new Set(presentation.match(/TEAM_[A-Z0-9_]+/g))]
  const body = walk(srcDir).map((file) => stripComments(readFileSync(file, 'utf8'))).join('\n')
  const references = [...new Set([...body.matchAll(/\b(?:s|strings|stringsRef\.current|ctx\.s)\.((?:settings|setting|seatSource)[A-Z]\w*)/g)].map((m) => m[1]))]
  for (const [name, table] of [['zh', zh], ['en', en]]) {
    for (const key of keys) {
      if (!table['label_' + key]) fail(`${name}: missing selected-operation label_${key}`)
    }
    for (const ref of references) {
      if (!table[ref]) fail(`${name}: missing displayed reference ${ref}`)
    }
  }
  for (const key of new Set([...zhKeys, ...enKeys])) {
    if (!(key in zh) || !(key in en)) fail(`${key}: language field missing`)
  }
  console.log(`ok: selected settings references — ${keys.length} key labels; ${references.length} displayed references`)

} finally {
  rmSync(tmp, { recursive: true, force: true })
}

if (failures.length) {
  console.error('✗ panel-strings failed:')
  for (const message of failures) console.error(`  ${message}`)
  process.exit(1)
}
console.log('panel-strings: ok')
