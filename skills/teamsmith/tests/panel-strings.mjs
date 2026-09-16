#!/usr/bin/env node
// String-table gate for the pulse console (pulse-console B3, tasks.md 6.1).
//
//   node skills/teamsmith/tests/panel-strings.mjs [tree]
//
// Checks, in order:
//   1. `src/strings/zh.ts` and `src/strings/en.ts` hold identical key sets;
//   2. every value is a non-empty string and the `{placeholder}` sets match per key;
//   3. no CJK ideograph survives in the panel sources outside `src/strings/**` (comments are
//      stripped first) — visible text comes from the tables, not from literals.
//
// The tables are plain ESM, so they are copied to a temp dir as `.mjs` and imported with the plain
// JS runtime this script runs on; no TypeScript loader (or bundler) is involved.
//
// Exit: 0 all three checks pass, 1 at least one failed (the message names the key/file).

import { copyFileSync, mkdtempSync, readFileSync, readdirSync, rmSync, statSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { dirname, join, relative } from 'node:path'
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

  // 1. identical key sets
  const zhKeys = Object.keys(zh).sort()
  const enKeys = Object.keys(en).sort()
  const onlyZh = zhKeys.filter((k) => !enKeys.includes(k))
  const onlyEn = enKeys.filter((k) => !zhKeys.includes(k))
  if (onlyZh.length) fail(`only in zh: [ ${onlyZh.map((k) => `"${k}"`).join(', ')} ]`)
  if (onlyEn.length) fail(`only in en: [ ${onlyEn.map((k) => `"${k}"`).join(', ')} ]`)
  console.log(`ok: zh/en key sets compared (${zhKeys.length} keys)`)

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
    fail(`CJK literals outside src/strings/** (visible text must come from the tables):`)
    for (const hit of hits.slice(0, 8)) fail(`  ${hit}`)
  } else {
    console.log('ok: no CJK literals outside src/strings/**')
  }
} finally {
  rmSync(tmp, { recursive: true, force: true })
}

if (failures.length) {
  console.error('✗ panel-strings failed:')
  for (const message of failures) console.error(`  ${message}`)
  process.exit(1)
}
console.log('panel-strings: ok')
