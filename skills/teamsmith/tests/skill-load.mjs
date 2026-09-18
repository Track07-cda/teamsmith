#!/usr/bin/env bun
/**
 * 用 pi 自己的 skills 解析器验证本 skill 是否合法（frontmatter/name/description/发现规则），
 * 并打印将要注入系统提示的那段 XML。这是确定性检查，不需要跑模型。
 *
 *   bun tests/skill-load.mjs [skill-dir]
 */
import { existsSync } from 'node:fs'
import { basename, dirname, join, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const here = dirname(fileURLToPath(import.meta.url))
const skillDir = resolve(process.argv[2] ?? join(here, '..'))
// P16 拆分后两个 skill 共用这份加载器：期望的 name 就是目录名（teamsmith / teamsmith-init）。
const expectedName = basename(skillDir)

const candidates = [
  process.env.PI_DIST,
  '$HOME/.bun/install/global/node_modules/@earendil-works/pi-coding-agent/dist/core/skills.js',
].filter(Boolean)

let skillsMod = ''
for (const c of candidates) {
  if (c && existsSync(c)) {
    skillsMod = c
    break
  }
}
if (!skillsMod) {
  try {
    skillsMod = new URL(import.meta.resolve('@earendil-works/pi-coding-agent/dist/core/skills.js')).pathname
  } catch {
    console.error('SKIP: 找不到 pi 的 dist/core/skills.js（设置 PI_DIST 指向它）')
    process.exit(2)
  }
}

const { loadSkillsFromDir, formatSkillsForPrompt } = await import(skillsMod)
const result = loadSkillsFromDir({ dir: skillDir, source: 'cli' })

const problems = []
if (result.skills.length !== 1) problems.push(`期望发现 1 个 skill，实际 ${result.skills.length}`)
const skill = result.skills[0]
if (skill) {
  if (skill.name !== expectedName) problems.push(`name 不是 ${expectedName}：${skill.name}`)
  if (!skill.description || skill.description.length > 1024) problems.push(`description 长度非法或缺失`)
  if (!/teamsmith|多 Agent|团队/.test(skill.description)) problems.push('description 缺少触发语境关键词')
  if (!skill.baseDir) problems.push('缺少 baseDir（相对路径无法解析）')
}
if (result.diagnostics.length) problems.push(...result.diagnostics.map(d => `诊断：${JSON.stringify(d)}`))

const prompt = formatSkillsForPrompt(result.skills)
if (!prompt.includes(`<name>${expectedName}</name>`)) problems.push(`注入系统提示的 XML 里没有 ${expectedName}`)
if (!prompt.includes('<location>')) problems.push('注入系统提示的 XML 里没有 location')

if (problems.length) {
  console.error('skill-load 失败：')
  for (const p of problems) console.error(`  - ${p}`)
  process.exit(1)
}

console.log(`✓ pi 解析器加载成功：name=${skill.name} desc=${skill.description.length} 字符 诊断=0`)
console.log(`  baseDir=${skill.baseDir}`)
console.log('  注入系统提示的片段：')
console.log(prompt.split('\n').slice(4, 9).map(l => `    ${l}`).join('\n'))
