#!/usr/bin/env node
// String-table gate for the pulse console (pulse-console B3, tasks.md 6.1).
//
//   node skills/teamsmith/tests/panel-strings.mjs [tree]
//
// Checks, in order:
//   1. `src/strings/zh.ts` and `src/strings/en.ts` hold identical key sets;
//   2. every value is a non-empty string and the `{placeholder}` sets match per key;
//   3. no CJK ideograph survives in the panel sources outside `src/strings/**` (comments are
//      stripped first) — visible text comes from the tables, not from literals;
//   4. the contract-key labels (M49): every key of the owning command's schema
//      (`skills/teamsmith/scripts/lib/cmd-config.sh`) has a non-empty `label_<KEY>` in **both**
//      tables, no label names a key the schema does not carry (no stale half), the label is not
//      the key spelled differently, and it fits the row's label column.
//
// The tables are plain ESM, so they are copied to a temp dir as `.mjs` and imported with the plain
// JS runtime this script runs on; no TypeScript loader (or bundler) is involved.
//
// Exit: 0 all three checks pass, 1 at least one failed (the message names the key/file).

import { copyFileSync, existsSync, mkdtempSync, readFileSync, readdirSync, rmSync, statSync } from 'node:fs'
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

  // 4. The contract-key labels: the schema is the single source of the row set (the view reads it
  // at render time), the labels are the row's human identity — so the two must line up exactly,
  // in both directions. The assertion is falsifiable by deleting one label (a missing key) or by
  // leaving one behind after the schema drops a key (a stale label).
  const schemaFile = join(tree, 'skills/teamsmith/scripts/lib/cmd-config.sh')
  if (!existsSync(schemaFile)) {
    console.log(`skip: ${relative(tree, schemaFile)} is not in this tree (schema-label check not run)`)
  } else {
    const schemaBody = /^team_config_schema\(\)\s*\{[\s\S]*?\nEOF\n/m.exec(readFileSync(schemaFile, 'utf8'))
    const schemaKeys = schemaBody ? [...schemaBody[0].matchAll(/^(TEAM_[A-Z0-9_]+)\|/gm)].map((m) => m[1]) : []
    if (!schemaKeys.length) fail(`${relative(tree, schemaFile)}: no schema key parsed from team_config_schema()`)
    const LABEL_PREFIX = 'label_'
    const labelled = (table) => Object.keys(table).filter((k) => k.startsWith(LABEL_PREFIX)).map((k) => k.slice(LABEL_PREFIX.length))
    // The row's label column (`layout.ts` SETTINGS_LABEL_W); a longer label is cut mid-word there.
    const LABEL_CELLS = 22
    const cells = (value) => [...String(value)].reduce((n, ch) => n + (/[\u3400-\u4dbf\u4e00-\u9fff\uf900-\ufaff\uff00-\uffef]/.test(ch) ? 2 : 1), 0)
    for (const [name, table] of [
      ['zh', zh],
      ['en', en],
    ]) {
      const have = new Set(labelled(table))
      const missing = schemaKeys.filter((k) => !have.has(k))
      if (missing.length) fail(`${name}: no label for schema key(s) [ ${missing.join(', ')} ]`)
    }
    for (const [name, table] of [
      ['zh', zh],
      ['en', en],
    ]) {
      for (const key of labelled(table)) {
        const label = table[LABEL_PREFIX + key]
        if (!schemaKeys.includes(key)) fail(`${name}.${LABEL_PREFIX}${key} names no schema key (stale label)`)
        if (label === key || String(label) === key.replace(/_/g, ' ') || String(label).includes('TEAM_')) {
          fail(`${name}.${LABEL_PREFIX}${key} (${JSON.stringify(label)}) is the key name, not a human label`)
        }
        if (cells(label) > LABEL_CELLS) {
          fail(`${name}.${LABEL_PREFIX}${key} is ${cells(label)} cells wide (> ${LABEL_CELLS}: the row's label column would cut it)`)
        }
      }
    }
    if (schemaKeys.length) console.log(`ok: contract-key labels — ${schemaKeys.length} schema keys covered in zh and en`)
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
