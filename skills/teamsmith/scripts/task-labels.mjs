import { spawnSync } from 'node:child_process'
import { randomUUID } from 'node:crypto'
import { closeSync, constants as C, fchmodSync, fstatSync, fsyncSync, lstatSync, openSync, readFileSync, realpathSync, renameSync, unlinkSync, writeFileSync } from 'node:fs'
import { basename, dirname, isAbsolute, join, relative, sep } from 'node:path'
import { sanitize } from './text-sanitize.mjs'

class Usage extends Error {}
const refuse = message => { throw new Error(message) }
const literal = value => JSON.stringify(value)
const fileName = 'task-labels.tsv'

function name(s) {
  if (!s || s.trim() !== s || /[\t\r\n]/.test(s) || sanitize(s) !== s) refuse(`invalid label name: ${literal(s)}`)
  return s
}
function color(s) {
  if (!/^#[0-9a-fA-F]{6}$/.test(s)) refuse(`invalid label color: ${literal(s)}`)
  return s.toLowerCase()
}
function weight(s) {
  if (!/^[+-]?\d+$/.test(s)) refuse(`invalid label weight: ${literal(s)}`)
  return BigInt(s)
}
function idField(s) {
  if (!s || /[\t\r\n\0]/.test(s)) refuse(`invalid task ID: ${literal(s)}`)
  return s
}

function load(dir) {
  const entry = join(dir, fileName)
  const catalog = { target: entry, mode: undefined, labels: new Map(), tasks: new Map() }
  let info
  try { info = lstatSync(entry) } catch (err) {
    if (err.code === 'ENOENT') return catalog // a missing entry, not a failed target lookup
    throw err
  }
  if (info.isSymbolicLink()) {
    const target = realpathSync(entry)
    const path = relative(dir, target)
    if (!path || path === '..' || path.startsWith(`..${sep}`) || isAbsolute(path)) refuse(`label target outside ledger: ${target}`)
    catalog.target = target
    info = lstatSync(target)
  }
  if (!info.isFile()) refuse(`label source is not a regular file: ${catalog.target}`)
  const fd = openSync(catalog.target, C.O_RDONLY | C.O_NOFOLLOW | C.O_NONBLOCK)
  let input
  try {
    info = fstatSync(fd)
    if (!info.isFile()) refuse(`label source is not a regular file: ${catalog.target}`)
    catalog.mode = info.mode & 0o7777
    input = new TextDecoder('utf-8', { fatal: true, ignoreBOM: true }).decode(readFileSync(fd))
  } finally { closeSync(fd) }
  if (input && !input.endsWith('\n')) refuse('unterminated label record')
  const lines = input ? input.slice(0, -1).split('\n') : []
  for (const [i, line] of lines.entries()) {
    const [kind, key, value, w, ...rest] = line.split('\t')
    try {
      if (kind === 'label' && w !== undefined && !rest.length) {
        if (catalog.labels.has(name(key))) refuse(`duplicate definition: ${literal(key)}`)
        catalog.labels.set(key, { name: key, color: color(value), weight: weight(w) })
      } else if (kind === 'task' && value !== undefined && w === undefined) {
        const names = catalog.tasks.get(idField(key)) ?? new Set()
        names.add(name(value)); catalog.tasks.set(key, names)
      } else refuse('invalid label record')
    } catch (err) { refuse(`line ${i + 1}: ${err.message}`) }
  }
  for (const [id, names] of catalog.tasks) {
    for (const n of names) if (!catalog.labels.has(n)) refuse(`undefined label ${literal(n)} for task ${literal(id)}`)
  }
  return catalog
}

function publish({ target, mode, labels, tasks }) {
  const dir = openSync(dirname(target), C.O_RDONLY | C.O_DIRECTORY)
  const at = file => `/proc/self/fd/${dir}/${file}`
  const tmp = at(`.task-labels-${randomUUID()}`)
  let created = false
  try {
    const fd = openSync(tmp, C.O_WRONLY | C.O_CREAT | C.O_EXCL, mode ?? 0o666)
    created = true
    try {
      const lines = []
      for (const d of labels.values()) lines.push(`label\t${d.name}\t${d.color}\t${d.weight}\n`)
      for (const [id, names] of tasks) for (const n of names) lines.push(`task\t${id}\t${n}\n`)
      writeFileSync(fd, lines.join(''))
      if (mode !== undefined) fchmodSync(fd, mode)
      fsyncSync(fd)
    } finally { closeSync(fd) }
    renameSync(tmp, at(basename(target)))
    created = false
    try { fsyncSync(dir) } catch (err) {
      refuse(`${target} may already show the change; could not confirm persistence (${err.message}). Re-read before retrying.`)
    }
  } finally {
    try { if (created) unlinkSync(tmp) } finally { closeSync(dir) }
  }
}

function write(dir, change) {
  const lock = openSync(dir, C.O_RDONLY | C.O_DIRECTORY)
  try {
    const held = spawnSync('flock', ['-x', '3'], { stdio: ['ignore', 'ignore', 'pipe', lock] })
    if (held.error || held.status !== 0) refuse(`could not lock ledger ${dir}: ${held.error?.message ?? (held.stderr.toString().trim() || `flock exit ${held.status ?? held.signal}`)}`)
    const catalog = load(dir)
    if (change(catalog)) publish(catalog)
  } finally { closeSync(lock) }
}

// Each distinct ID is scored once, even when multiple rows share it.
function scores({ labels, tasks }) {
  const byId = new Map()
  for (const [id, names] of tasks) {
    let score = 0n
    for (const n of names) score += labels.get(n).weight
    byId.set(id, { names: [...names], score })
  }
  return id => byId.get(id) ?? { names: [], score: 0n }
}

function parse(args, allowed) {
  const fields = new Map(), values = []
  let options = true
  for (let i = 0; i < args.length; i++) {
    const arg = args[i]
    if (options && arg === '--') { options = false; continue }
    if (options && arg.startsWith('-')) {
      if (!allowed.includes(arg) || fields.has(arg)) throw new Usage(`unexpected or repeated option: ${arg}`)
      if (i + 1 === args.length) throw new Usage(`missing value: ${arg}`)
      fields.set(arg, args[++i])
    } else values.push(arg)
  }
  return [values, fields]
}

function changeFor(command, args, rows) {
  const fields = { define: ['--color', '--weight'], edit: ['--name', '--color', '--weight'], delete: [], add: [], remove: [] }
  if (!Object.hasOwn(fields, command)) throw new Usage('use board label define|ls|edit|delete|add|remove')
  const [values, opts] = parse(args, fields[command])
  const [key, ...more] = values
  if (command === 'add' || command === 'remove') {
    if (!more.length) throw new Usage(`board label ${command} <ID> <name>...`)
    idField(key)
    const wanted = new Set(more.map(name))
    return ({ labels, tasks }) => {
      for (const n of wanted) if (!labels.has(n)) refuse(`unknown label: ${literal(n)}`)
      const current = tasks.get(key)
      if (!rows().some(row => row.id === key) && !(command === 'remove' && current?.size)) refuse(`unknown board task: ${literal(key)}`)
      const next = new Set(current)
      for (const n of wanted) command === 'add' ? next.add(n) : next.delete(n)
      if (next.size === (current?.size ?? 0)) return false
      if (next.size) tasks.set(key, next)
      else tasks.delete(key)
      return true
    }
  }
  if (values.length !== 1 || (command === 'define' && !opts.has('--color')) || (command === 'edit' && !opts.size)) {
    throw new Usage(`board label ${command}: expected one name${command === 'define' ? ' and --color' : command === 'edit' ? ' and at least one change' : ''}`)
  }
  name(key)
  const newName = opts.has('--name') ? name(opts.get('--name')) : key
  const newColor = opts.has('--color') ? color(opts.get('--color')) : undefined
  const newWeight = opts.has('--weight') ? weight(opts.get('--weight')) : undefined
  return ({ labels, tasks }) => {
    const old = labels.get(key)
    if (command === 'define') {
      if (old) refuse(`label already defined: ${literal(key)}`)
      labels.set(key, { name: key, color: newColor, weight: newWeight ?? 0n })
    } else {
      if (!old) refuse(`unknown label: ${literal(key)}`)
      if (command === 'delete') {
        const used = [...tasks].filter(([, names]) => names.has(key)).map(([id]) => id)
        if (used.length) refuse(`detach ${literal(key)} from: ${used.map(literal).join(', ')}`)
        labels.delete(key)
      } else {
        if (newName !== key && labels.has(newName)) refuse(`label already defined: ${literal(newName)}`)
        const next = { name: newName, color: newColor ?? old.color, weight: newWeight ?? old.weight }
        if (newName === key && next.color === old.color && next.weight === old.weight) return false
        if (newName !== key) {
          // Retain catalog and per-task display order during a rename.
          for (const [n, d] of [...labels]) { labels.delete(n); labels.set(n === key ? newName : n, n === key ? next : d) }
          for (const [id, names] of tasks) if (names.has(key)) tasks.set(id, new Set([...names].map(n => n === key ? newName : n)))
        } else labels.set(key, next)
      }
    }
    return true
  }
}

function main([ledger, action, ...args]) {
  const dir = () => realpathSync(ledger)
  // stdin is the board parser's output, not the label catalog.
  const rows = () => JSON.parse(readFileSync(0, 'utf8'))
  if (action === 'panel') {
    const board = rows(), catalog = load(dir()), score = scores(catalog)
    board.labels = { catalog: [...catalog.labels.values()].map(({ name, color }) => ({ name, color })) }
    for (const row of board.rows) {
      if (row.taskTable) {
        const { names, score: sum } = score(row.id)
        row.labels = { names, score: sum.toString() }
      }
    }
    console.log(JSON.stringify(board))
  } else if (action === 'list') {
    const [hasLabel, label, priority] = args
    const filter = hasLabel === '1' ? name(label) : undefined
    const catalog = load(dir())
    if (filter !== undefined && !catalog.labels.has(filter)) refuse(`unknown label: ${literal(filter)}`)
    const score = scores(catalog)
    const list = rows().map(row => ({ ...row, ...score(row.id) })).filter(row => filter === undefined || row.names.includes(filter))
    if (priority === '1') list.sort((a, b) => a.score === b.score ? 0 : a.score > b.score ? -1 : 1)
    for (const row of list) console.log(`${row.id}\t${row.state}\t${row.score}\t${JSON.stringify(row.names)}\t${row.title}`)
  } else {
    const [command, ...rest] = args
    if (command === 'ls') {
      if (rest.length) throw new Usage('board label ls takes no arguments')
      for (const d of load(dir()).labels.values()) console.log(`${d.name}\t${d.color}\t${d.weight}`)
    } else {
      const change = changeFor(command, rest, rows)
      write(dir(), change)
    }
  }
}

try { main(process.argv.slice(2)) } catch (err) {
  console.error(`team board labels (${join(process.argv[2], fileName)}): ${err.message}`)
  process.exitCode = err instanceof Usage ? 2 : 1
}
