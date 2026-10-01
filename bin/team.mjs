#!/usr/bin/env node
// teamsmith 的 npm bin 入口（package.json 的 bin.team）。**透明包装器**：它不实现、不包装、不改写
// 任何子命令，只做两件事：
//   ① 先检查自己依赖的 shell（bash >= 5，README.md 的 Requirements 表；实测 4.0 下 help/init 退出 2）—— 缺 shell 或 shell 太旧时
//      印出确切的修法并非 0 退出，**不跑 CLI**；
//   ② 否则原样把 argv / stdio / env 交给 bash CLI（skills/teamsmith/scripts/team），退出码逐字透传
//      （被信号打断 → 128 + signo）。
// 因此 `team help` / `team version` / 失败子命令与直接跑 bash 入口逐字节、逐退出码一致。
//
// 为什么是包装器而不是直接 `bin: {"team": ".../scripts/team"}`：npm 在 Windows 上生成的
// `team.cmd` / `team.ps1` 跑不了 `.sh` 目标（CreateProcess 报错且没有任何提示）；包装器能在同一个
// 代码路径上把「装 bash 5+ / 用 Git Bash 或 WSL」说清楚 —— 这正是 `team doctor` 已经做出的承诺。
import { spawnSync } from 'node:child_process'
import { existsSync, realpathSync } from 'node:fs'
import { constants as osConstants } from 'node:os'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const BASH_MIN_MAJOR = 5
const REQUIREMENTS = 'README.md 的 Requirements 表'
const SELF = realpathSync(fileURLToPath(import.meta.url))
const CLI = resolve(dirname(SELF), '..', 'skills', 'teamsmith', 'scripts', 'team')

function die(message) {
  process.stderr.write(`teamsmith: ${message}\n`)
  process.exit(3)
}

if (!existsSync(CLI)) {
  die(`这份安装不完整：找不到 CLI 入口 ${CLI}（重新安装 teamsmith 后重试）`)
}

/** bash 在本机解析到哪、是第几个大版本：`bash -c` 探针（与 CLI 自己的解析方式一致 —— PATH）。 */
function bashMajor() {
  const probe = spawnSync('bash', ['-c', 'printf %s "${BASH_VERSINFO[0]:-0}"'], { encoding: 'utf8' })
  if (probe.error) return { error: probe.error.code || probe.error.message }
  return { raw: String(probe.stdout).trim(), major: Number.parseInt(String(probe.stdout).trim(), 10) }
}

const found = bashMajor()
if (found.error) {
  die(`找不到可用的 bash（bash: ${found.error}）：CLI 是 bash 脚本，需要 bash >= ${BASH_MIN_MAJOR}。` +
      `装一个 bash ${BASH_MIN_MAJOR}+（Windows 用 Git Bash 或 WSL，或把 Pi 的 shellPath 指到它）并确保它在 PATH 里；` +
      `前置条件见 ${REQUIREMENTS}`)
}
if (!Number.isInteger(found.major) || found.major < BASH_MIN_MAJOR) {
  die(`bash 版本太旧：解析到的 bash 报了版本 ${found.raw || '未知'}，需要 bash >= ${BASH_MIN_MAJOR}。` +
      `升级 bash 后重试；前置条件见 ${REQUIREMENTS}`)
}

// 透明透传：同一个 argv、同一套 stdio（inherit）、同一个环境；不解析、不改写任何参数。
const child = spawnSync('bash', [CLI, ...process.argv.slice(2)], { stdio: 'inherit' })
if (child.error) {
  die(`bash 无法启动（bash: ${child.error.code || child.error.message}）：需要 bash >= ${BASH_MIN_MAJOR}；前置条件见 ${REQUIREMENTS}`)
}
if (child.signal) {
  process.exit(128 + (osConstants.signals[child.signal] ?? 0))
}
process.exit(child.status ?? 1)
