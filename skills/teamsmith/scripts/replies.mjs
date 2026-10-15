#!/usr/bin/env node
/**
 * teamsmith · 关键回复（key replies）的存储与只读查询 helper。
 *
 *   node replies.mjs post   --main-root <项目根> --state-dir <state> --from <label> --title <t> [--stdin]
 *   node replies.mjs summary --main-root <项目根> --state-dir <state>
 *   node replies.mjs list   --main-root <项目根> --state-dir <state> [--before <no>] [--format json|text]
 *   node replies.mjs show   --main-root <项目根> --state-dir <state> --no <no> [--format json|text|raw]
 *
 * 存储布局（change: pulse-key-replies · design §2/§3）：
 *   <state>/key-replies/writer.lock         正规文件，只供 OS advisory lock（flock）
 *   <state>/key-replies/index.v1            追加的固定 4096 字节提交槽位
 *   <state>/key-replies/bodies/<32hex>.md   不可变原文字节；文件名不来自标题/标签
 *   <state>/key-replies/.tmp-<32hex>        本次 publisher 的临时原文；读者永不枚举
 *
 * 每个槽位：前 4064 字节 = uint32BE(json_length) + UTF-8 JSON + 零填充，末 32 字节 = 前 4064 字节的 SHA-256。
 * `no = slot_offset / 4096 + 1`；show 用算术直接定位。list 每次最多读 50 槽。summary 只读最后一个完整槽。
 *
 * 退出码（delta「key-replies」的合同）：
 *   0 成功（post 只有 durable 之后才 print saved 回执）
 *   2 用法/输入失败       4 存储不可用/损坏       5 锁竞争（≤2000ms 等待）      6 已可见但持久性未确认
 *
 * 本文件只做存储；命令分发、身份分类与 JS 运行时解析在 scripts/lib/cmd-reply.sh。
 * 只读面（summary/list/show）绝不 mkdir、绝不写盘、绝不等待 writer 锁。
 */

import {
  closeSync,
  constants as C,
  fsyncSync,
  fstatSync,
  ftruncateSync,
  linkSync,
  mkdirSync,
  openSync,
  readSync,
  unlinkSync,
  writeSync,
} from 'node:fs'
import { spawnSync } from 'node:child_process'
import { createHash, randomBytes } from 'node:crypto'
import { isAbsolute, join, relative, resolve, sep } from 'node:path'
import { pathToFileURL } from 'node:url'

// ---------------------------------------------------------------- 常量
const SLOT_SIZE = 4096
const PAYLOAD_SIZE = SLOT_SIZE - 32
const VERSION = 1
const MAX_NO = 999999999999
const MAX_BODY_BYTES = 131072
const MAX_TITLE_CODEPOINTS = 160
const MAX_LABEL = 48
const LOCK_WAIT_SEC = 2
const STORE_NAME = 'key-replies'
const INDEX_NAME = 'index.v1'
const LOCK_NAME = 'writer.lock'
const BODIES_NAME = 'bodies'
const LIST_PAGE = 50
const HEX32 = /^[0-9a-f]{32}$/
const HEX64 = /^[0-9a-f]{64}$/
const LABEL_RE = /^[A-Za-z0-9._-]+$/

// ---------------------------------------------------------------- 错误与退出码
class ReplyError extends Error {
  constructor(code, message) {
    super(message)
    this.code = code
  }
}
const input = (m) => new ReplyError(2, m)
const unavailable = (m) => new ReplyError(4, m)
const busy = (m) => new ReplyError(5, m)
const unconfirmed = (m) => new ReplyError(6, m)

function fail(code, message) {
  process.stderr.write(`reply: ${message}\n`)
  process.exit(code)
}

function main(fn) {
  try {
    fn()
  } catch (e) {
    if (e instanceof ReplyError) fail(e.code, e.message)
    // 未预期的异常也绝不能打印正文：只说类型。
    fail(4, `内部错误（${e && e.constructor ? e.constructor.name : 'Error'}）`)
  }
}

// ---------------------------------------------------------------- 显示净化（与 panel/src/sanitize.ts 同一规则）
// 「共享同一规则并由双向测试防漂移」：本段的正则集与 panel/src/sanitize.ts 逐字相同，
// tests/key-replies.sh --select paths 用同一组敌意载荷对两边做双向断言（任何一边漂移都红）。
const OSC_RE = /\u001B\][^\u0007\u001B]*(?:\u0007|\u001B\\)/g
const CSI_RE = /\u001B\[[0-?]*[ -/]*[@-~]/g
const C1_CSI_RE = /\u009B[0-?]*[ -/]*[@-~]/g
const ESC2_RE = /\u001B[@-Z\\-_]/g
const CTRL_RE =
  /[\u0000-\u0008\u000B-\u001F\u007F-\u009F\u200B\u200E\u200F\u202A-\u202E\u2060\u2066-\u2069\uFEFF]/g

export function sanitize(value) {
  return String(value ?? '')
    .replace(OSC_RE, '')
    .replace(CSI_RE, '')
    .replace(C1_CSI_RE, '')
    .replace(ESC2_RE, '')
    .replace(CTRL_RE, '')
}

// 标题的输入校验比显示净化更严：终端控制与双向/不可见格式控制一律拒绝（不是删掉）。
const TITLE_FORBIDDEN_RE = new RegExp(
  `[\\u0000-\\u001F\\u007F-\\u009F\\u00AD\\u061C\\u200B-\\u200F\\u2028-\\u202E\\u2060-\\u206F\\uFEFF]`,
)

// ---------------------------------------------------------------- 小工具
const sleepMs = (ms) => Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, ms)

// O_PATH（Linux x86-64；Node 的 fs.constants 不一定导出它）：只做**锚点**的目录句柄，
// 不附读权限、不能 getdents —— 只读面用它打开 bodies/，于是一个「列举正文目录」的实现在
// 无读权限的目录上必然 EACCES，而按名直开仍然可用（夹具据此证明不枚举）。
const O_PATH = typeof C.O_PATH === 'number' ? C.O_PATH : 0o10000000

/**
 * 故障注入旋钮（只在隔离夹具里用；不是产品配置键，也不改变任何默认路径）：
 *   TEAM_REPLY_FAULT=kill:<point>  → 在精确落点 SIGKILL 自己（模拟中断）
 *   TEAM_REPLY_FAULT=fail:<point>  → 在该点抛出「存储不可用」
 * points: body-write / body-fsync / body-staged / body-link / body-published /
 *         index-write / index-written / index-fsync / index-durable
 */
function faultPoint(point, mode) {
  if (process.env.TEAM_REPLY_FAULT !== `${mode}:${point}`) return false
  if (mode === 'kill') {
    process.kill(process.pid, 'SIGKILL')
    sleepMs(5000)
  }
  throw unavailable(`故障注入：${point}`)
}

const hit = (point) => faultPoint(point, String(process.env.TEAM_REPLY_FAULT || '').split(':')[0])

function fdPath(fd, name) {
  // /proc/self/fd/<fd> 是**已打开目录**的锚：目录中途被替换也解析到原来那个 inode（TOCTOU 防线）。
  return `/proc/self/fd/${fd}/${name}`
}

function closeQuiet(fd) {
  if (typeof fd === 'number' && fd >= 0) {
    try {
      closeSync(fd)
    } catch {
      /* 已经关了 */
    }
  }
}

function errnoOf(e) {
  return e && typeof e === 'object' && 'code' in e ? String(e.code) : ''
}

/**
 * 打开一个目录（相对已锚定的父 fd，O_NOFOLLOW|O_DIRECTORY）。结果：
 *   {ok:true, fd} | {ok:false, kind:'missing'|'unsafe'|'error', detail}
 * `create` 只在 post 的存储创建路径上给：缺目录就 mkdir（模式 0700）。
 * `oPath`（只读面给 bodies/ 用）：只要锚点不要读权限 —— 不能 getdents，也不能配合写。
 */
function openDirAt(parentFd, name, { create = false, oPath = false } = {}) {
  const open = () => {
    const flags = oPath ? O_PATH | C.O_DIRECTORY | C.O_NOFOLLOW : C.O_RDONLY | C.O_DIRECTORY | C.O_NOFOLLOW
    const fd = openSync(fdPath(parentFd, name), flags)
    const st = fstatSync(fd)
    if (!st.isDirectory()) {
      closeQuiet(fd)
      const e = new Error('not a directory')
      e.code = 'ENOTDIR'
      throw e
    }
    return fd
  }
  try {
    return { ok: true, fd: open() }
  } catch (e) {
    const code = errnoOf(e)
    if (code === 'ENOENT') {
      if (!create) return { ok: false, kind: 'missing', detail: name }
      try {
        mkdirSync(fdPath(parentFd, name), { mode: 0o700 })
      } catch (e2) {
        const c2 = errnoOf(e2)
        if (c2 !== 'EEXIST') return { ok: false, kind: 'error', detail: `${name}: ${c2 || e2.message}` }
      }
      try {
        return { ok: true, fd: open(), created: true }
      } catch (e2) {
        return { ok: false, kind: 'unsafe', detail: `${name}: ${errnoOf(e2) || e2.message}` }
      }
    }
    if (code === 'ELOOP') return { ok: false, kind: 'unsafe', detail: `${name}: symlink` }
    if (code === 'ENOTDIR') return { ok: false, kind: 'unsafe', detail: `${name}: not a directory` }
    return { ok: false, kind: 'error', detail: `${name}: ${code || e.message}` }
  }
}

/**
 * 打开一个正规文件（相对已锚定的父 fd，O_NOFOLLOW|O_NONBLOCK）+ 类型校验。
 *
 * `O_NONBLOCK` 是**读路径的安全前提**：不带它时，`open(2)` 一个 FIFO 会**一直等到有写者**——读命令
 * 会永久挂住（V27 实测 `reply list`/`show` 对 FIFO 索引/正文 rc 124），而规格要求「拒绝且不读目标、
 * 不阻塞在 FIFO 上」。带上它之后 FIFO 立刻打开成功，紧接着的 `fstat` 判定为非正规文件并拒绝。
 * 对正规文件 `O_NONBLOCK` 无任何作用（POSIX：对 regular file 的 read/write 不受影响），因此这里
 * 没有「检查后清位」这一步——Node 没有 fcntl 绑定，且对本用例而言它本就不需要清。
 */
function openFileAt(parentFd, name, flags, mode) {
  let fd
  try {
    fd = openSync(fdPath(parentFd, name), flags | C.O_NOFOLLOW | C.O_NONBLOCK, mode)
  } catch (e) {
    const code = errnoOf(e)
    if (code === 'ENOENT') return { ok: false, kind: 'missing', detail: name }
    if (code === 'ELOOP') return { ok: false, kind: 'unsafe', detail: `${name}: symlink` }
    return { ok: false, kind: 'error', detail: `${name}: ${code || e.message}` }
  }
  const st = fstatSync(fd)
  if (!st.isFile()) {
    closeQuiet(fd)
    return { ok: false, kind: 'unsafe', detail: `${name}: not a regular file` }
  }
  return { ok: true, fd }
}

/** 创建一个正规文件；已存在则按 `openFileAt` 打开（不跟随软链）。 */
function openOrCreateFileAt(parentFd, name, mode) {
  try {
    const fd = openSync(fdPath(parentFd, name), C.O_RDWR | C.O_CREAT | C.O_EXCL | C.O_NOFOLLOW, mode)
    return { ok: true, fd, created: true }
  } catch (e) {
    if (errnoOf(e) !== 'EEXIST') return openFileAtResult(e, name)
  }
  return openFileAt(parentFd, name, C.O_RDWR)
}

function openFileAtResult(e, name) {
  const code = errnoOf(e)
  if (code === 'ELOOP') return { ok: false, kind: 'unsafe', detail: `${name}: symlink` }
  return { ok: false, kind: 'error', detail: `${name}: ${code || e.message}` }
}

// ---------------------------------------------------------------- 路径解析（main-root → state → key-replies）
function parseMainRoot(value) {
  if (!value || !isAbsolute(value)) throw input('--main-root 需要绝对路径')
  return value
}

/**
 * 从 main_root 逐段锚定走到 state 目录。`out.fd` = state 目录 fd（调用方负责 close）。
 * 缺失/不安全/不可用分别返回 kind。只读路径绝不创建。
 */
export function openStateDir(mainRoot, stateDir, { create }) {
  let rootFd
  try {
    rootFd = openSync(mainRoot, C.O_RDONLY | C.O_DIRECTORY)
  } catch (e) {
    return { ok: false, kind: 'error', detail: `main-root 打不开（${errnoOf(e) || e.message}）` }
  }
  const rel = relative(resolve(mainRoot), resolve(stateDir))
  if (rel === '') return { ok: true, fd: rootFd }
  if (rel.startsWith('..') || isAbsolute(rel)) {
    closeQuiet(rootFd)
    return { ok: false, kind: 'unsafe', detail: 'state 目录逃出了 main_root（reply 存储必须落在项目内）' }
  }
  let fd = rootFd
  for (const part of rel.split(sep).filter((p) => p && p !== '.')) {
    const r = openDirAt(fd, part, { create })
    closeQuiet(fd)
    if (!r.ok) return r
    fd = r.fd
  }
  return { ok: true, fd }
}

const kindReason = (r) =>
  r.kind === 'unsafe' ? `存储路径不安全（${r.detail}）` : `存储不可用（${r.detail}）`

/**
 * 打开 store。返回 {ok, kind, stateFd, krFd, indexFd, lockFd, bodiesFd?, created?}。
 *   mode='read'  → 只读；缺失 = kind:'missing'（空 store）
 *   mode='write' → 创建缺失的目录/文件（state/key-replies/bodies/index/lock）
 */
export function openStore(mainRoot, stateDir, mode) {
  const create = mode === 'write'
  const st = openStateDir(mainRoot, stateDir, { create })
  if (!st.ok) return st
  const stateFd = st.fd
  const out = { ok: true, stateFd }

  const kr = openDirAt(stateFd, STORE_NAME, { create })
  if (!kr.ok) {
    closeQuiet(stateFd)
    if (kr.kind === 'missing') return { ok: false, kind: 'missing', detail: 'store' }
    return { ...kr, stateFd: null }
  }
  out.krFd = kr.fd
  out.created = Boolean(kr.created)

  const idx = create
    ? openOrCreateFileAt(out.krFd, INDEX_NAME, 0o600)
    : openFileAt(out.krFd, INDEX_NAME, C.O_RDONLY)
  if (!idx.ok) {
    closeQuiet(out.krFd)
    closeQuiet(stateFd)
    if (idx.kind === 'missing') return { ok: false, kind: 'missing', detail: 'index' }
    return { ...idx, stateFd: null }
  }
  out.indexFd = idx.fd

  const bodies = openDirAt(out.krFd, BODIES_NAME, { create, oPath: !create })
  out.bodiesCreated = Boolean(bodies.created)
  if (!bodies.ok) {
    if (bodies.kind === 'missing' && !create) {
      // 只读面不要求 bodies/ 存在：list/summary 不读正文；show 会自己报不可用。
      out.bodiesFd = null
    } else {
      closeQuiet(out.indexFd)
      closeQuiet(out.krFd)
      closeQuiet(stateFd)
      if (bodies.kind === 'missing') return { ok: false, kind: 'missing', detail: 'bodies' }
      return { ...bodies, stateFd: null }
    }
  } else {
    out.bodiesFd = bodies.fd
  }

  if (create) {
    const lock = openOrCreateFileAt(out.krFd, LOCK_NAME, 0o600)
    if (!lock.ok) {
      closeQuiet(out.bodiesFd)
      closeQuiet(out.indexFd)
      closeQuiet(out.krFd)
      closeQuiet(stateFd)
      return { ...lock, stateFd: null }
    }
    out.lockFd = lock.fd
    // 新建的目录/文件按需 fsync（持久化布局本身；失败不致命，交给后面的内容 fsync 判定）。
    try {
      if (out.created || out.bodiesCreated || lock.created) fsyncSync(out.krFd)
    } catch {
      /* 后面的 fsync 会给出结论 */
    }
  }
  return out
}

export function closeStore(store) {
  if (!store) return
  closeQuiet(store.lockFd)
  closeQuiet(store.bodiesFd)
  closeQuiet(store.indexFd)
  closeQuiet(store.krFd)
  closeQuiet(store.stateFd)
}

// ---------------------------------------------------------------- 槽位编解码
function encodeSlot(meta) {
  const json = Buffer.from(JSON.stringify(meta), 'utf8')
  if (4 + json.length > PAYLOAD_SIZE) throw unavailable('元数据超过一个槽位的容量')
  const head = Buffer.alloc(PAYLOAD_SIZE)
  head.writeUInt32BE(json.length, 0)
  json.copy(head, 4)
  const sum = createHash('sha256').update(head).digest()
  return Buffer.concat([head, sum])
}

/** 读一个整槽（offset 起 4096 字节）。读不满 → null。 */
function readSlotBytes(fd, offset) {
  const buf = Buffer.alloc(SLOT_SIZE)
  let got = 0
  while (got < SLOT_SIZE) {
    const n = readSync(fd, buf, got, SLOT_SIZE - got, offset + got)
    if (n <= 0) break
    got += n
  }
  return got === SLOT_SIZE ? buf : null
}

/** → {ok:true, meta} | {ok:false, reason}。expectedNo 必须与槽位自述一致。 */
export function decodeSlot(buf, expectedNo) {
  if (buf.length !== SLOT_SIZE) return { ok: false, reason: 'incomplete slot' }
  const head = buf.subarray(0, PAYLOAD_SIZE)
  const sum = buf.subarray(PAYLOAD_SIZE)
  const got = createHash('sha256').update(head).digest()
  if (!got.equals(sum)) return { ok: false, reason: 'checksum mismatch' }
  const len = head.readUInt32BE(0)
  if (len < 2 || 4 + len > PAYLOAD_SIZE) return { ok: false, reason: 'invalid metadata length' }
  for (let i = 4 + len; i < PAYLOAD_SIZE; i++) {
    if (head[i] !== 0) return { ok: false, reason: 'padding is not zero' }
  }
  let meta
  try {
    meta = JSON.parse(head.subarray(4, 4 + len).toString('utf8'))
  } catch {
    return { ok: false, reason: 'invalid metadata JSON' }
  }
  if (!meta || typeof meta !== 'object') return { ok: false, reason: 'metadata is not an object' }
  if (meta.version !== VERSION) return { ok: false, reason: `unsupported version ${meta.version}` }
  if (meta.no !== expectedNo) return { ok: false, reason: 'number mismatch' }
  if (typeof meta.body_id !== 'string' || !HEX32.test(meta.body_id)) return { ok: false, reason: 'invalid body id' }
  if (typeof meta.sha256 !== 'string' || !HEX64.test(meta.sha256)) return { ok: false, reason: 'invalid body hash' }
  if (!Number.isSafeInteger(meta.bytes) || meta.bytes < 1 || meta.bytes > MAX_BODY_BYTES)
    return { ok: false, reason: 'invalid body length' }
  if (typeof meta.title !== 'string' || meta.title.length === 0) return { ok: false, reason: 'invalid title' }
  if (typeof meta.from !== 'string' || !LABEL_RE.test(meta.from)) return { ok: false, reason: 'invalid publisher' }
  if (typeof meta.at !== 'string' || !/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?Z$/.test(meta.at))
    return { ok: false, reason: 'invalid time' }
  return { ok: true, meta }
}

function slotAt(fd, offset, no) {
  const buf = readSlotBytes(fd, offset)
  if (!buf) return { ok: false, reason: 'incomplete slot' }
  return decodeSlot(buf, no)
}

// ---------------------------------------------------------------- 输入校验
function validateLabel(from) {
  if (!from) throw input('缺少 --from <label>')
  if (from.length > MAX_LABEL || !LABEL_RE.test(from))
    throw input(`--from 必须是 1–${MAX_LABEL} 个 ASCII 字母/数字/点/下划线/连字符的平坦标识符`)
}

function validateTitle(title) {
  if (typeof title !== 'string' || title.length === 0) throw input('缺少 --title <title>')
  const points = Array.from(title).length
  if (points > MAX_TITLE_CODEPOINTS) throw input(`--title 超过 ${MAX_TITLE_CODEPOINTS} 个码点`)
  if (!/\S/.test(title)) throw input('--title 不能只有空白')
  if (/\r|\n/.test(title)) throw input('--title 必须是单行')
  if (TITLE_FORBIDDEN_RE.test(title)) throw input('--title 含终端控制或双向/不可见格式控制字符')
  if ([...title].some((ch) => ch.codePointAt(0) >= 0xd800 && ch.codePointAt(0) <= 0xdfff))
    throw input('--title 不是合法 UTF-8 文本')
}

/** 有界读 stdin：读满上界+1 字节即拒；不做无界缓冲。 */
function readStdinBounded() {
  const chunks = []
  let total = 0
  const buf = Buffer.alloc(65536)
  for (;;) {
    let n
    try {
      n = readSync(0, buf, 0, buf.length, null)
    } catch (e) {
      if (errnoOf(e) === 'EAGAIN') {
        sleepMs(5)
        continue
      }
      if (errnoOf(e) === 'EINTR') continue
      throw input(`读 stdin 失败（${errnoOf(e) || e.message}）`)
    }
    if (n === 0) break
    total += n
    if (total > MAX_BODY_BYTES) throw input(`正文超过上界 ${MAX_BODY_BYTES} 字节（不截断）`)
    chunks.push(Buffer.from(buf.subarray(0, n)))
  }
  const body = Buffer.concat(chunks, total)
  if (body.length === 0) throw input('正文不能为空')
  if (body.includes(0)) throw input('正文里不许有 NUL 字节')
  try {
    new TextDecoder('utf-8', { fatal: true }).decode(body)
  } catch {
    throw input('正文不是合法 UTF-8')
  }
  return body
}

// ---------------------------------------------------------------- 锁
function acquireLock(lockFd) {
  // `stdio` 的第 4 项让子进程在 fd 3 上拿到**同一个** open-file description；flock 的参数
  // 因此是子进程的 fd 号 3（不是父进程的 lockFd —— 子进程的 fd 表是重映射过的）。锁挂在那个
  // OFD 上：flock 退出后父进程仍持有 fd 3，锁不释放；本进程退出/被 kill 时内核释放。
  const r = spawnSync('flock', ['-w', String(LOCK_WAIT_SEC), '3'], {
    stdio: ['ignore', 'ignore', 'ignore', lockFd],
  })
  if (r.error) {
    if (errnoOf(r.error) === 'ENOENT') throw unavailable('本机没有 flock：无锁发布不可用')
    throw unavailable(`flock 起不来（${errnoOf(r.error) || r.error.message}）`)
  }
  if (r.status === 0) return
  if (r.status === 1) throw busy(`写锁被占用超过 ${LOCK_WAIT_SEC * 1000}ms`)
  throw unavailable(`flock 返回 ${r.status}`)
}

// ---------------------------------------------------------------- post
/** next number for `slots` committed slots; 越界一律 unavailable（不环绕、不覆盖）。 */
export function nextNumber(slots) {
  const no = slots + 1
  if (!Number.isSafeInteger(no) || no > MAX_NO) {
    throw unavailable(`编号已达上界 ${MAX_NO}（不环绕、不覆盖）`)
  }
  return no
}

function cmdPost(args) {
  const from = args.from
  const title = args.title
  validateLabel(from)
  validateTitle(title)
  if (!args.stdin) throw input('post 只从 stdin 取正文：必须显式给 --stdin')
  const body = readStdinBounded()
  const sha256 = createHash('sha256').update(body).digest('hex')

  const store = openStore(args.mainRoot, args.stateDir, 'write')
  if (!store.ok) throw storageError(store)
  let tmpPath = null
  try {
    acquireLock(store.lockFd)
    // ① 恢复：明确不足 4096 字节的尾部截到完整槽边界；完整坏槽不许当未提交尾巴处理。
    let size = fstatSync(store.indexFd).size
    let slots = Math.floor(size / SLOT_SIZE)
    if (size % SLOT_SIZE !== 0) {
      ftruncateSync(store.indexFd, slots * SLOT_SIZE)
      fsyncSync(store.indexFd)
    }
    if (slots > 0) {
      const last = slotAt(store.indexFd, (slots - 1) * SLOT_SIZE, slots)
      if (!last.ok)
        throw unavailable(`索引最后一个完整槽位不可用（no=${slots}：${last.reason}）——不覆盖已提交槽位`)
    }
    const no = nextNumber(slots)
    const at = new Date().toISOString().replace(/\.\d{3}Z$/, 'Z')

    // ② 原文先 durable：独占创建的临时文件 → fsync → 无覆盖地发布到 bodies/ → fsync 目录。
    const bodyId = randomBytes(16).toString('hex')
    const tmpName = `.tmp-${bodyId}`
    tmpPath = fdPath(store.krFd, tmpName)
    const tmpFd = openSync(tmpPath, C.O_WRONLY | C.O_CREAT | C.O_EXCL | C.O_NOFOLLOW | C.O_NONBLOCK, 0o600)
    try {
      let off = 0
      while (off < body.length) {
        const n = writeSync(tmpFd, body, off, body.length - off)
        off += n
        hit('body-write')
      }
      hit('body-fsync')
      fsyncSync(tmpFd)
    } finally {
      closeQuiet(tmpFd)
    }
    hit('body-staged')
    hit('body-link')
    linkSync(tmpPath, fdPath(store.bodiesFd, `${bodyId}.md`))
    unlinkSync(tmpPath)
    tmpPath = null
    fsyncSync(store.bodiesFd)
    hit('body-published')

    // ③ 完整槽位 + fsync 之后才有可读条目。
    const meta = { version: VERSION, no, body_id: bodyId, title, from, at, bytes: body.length, sha256 }
    const slot = encodeSlot(meta)
    let wrote = 0
    if (process.env.TEAM_REPLY_FAULT === 'fail:index-write') {
      writeSync(store.indexFd, slot, 0, Math.floor(SLOT_SIZE / 2), slots * SLOT_SIZE)
      throw unavailable('故障注入：index-write')
    }
    while (wrote < SLOT_SIZE) wrote += writeSync(store.indexFd, slot, wrote, SLOT_SIZE - wrote, slots * SLOT_SIZE + wrote)
    hit('index-written')
    let durable = true
    try {
      // fail:index-fsync = 模拟**真的 fsync 失败**（普通错误 → durable=false → unconfirmed 路径）。
      if (process.env.TEAM_REPLY_FAULT === 'fail:index-fsync') throw new Error('injected fsync failure')
      fsyncSync(store.indexFd)
    } catch (e) {
      if (e instanceof ReplyError) throw e
      durable = false
    }
    if (!durable) {
      // append 已可见但最终 fsync 失败：unconfirmed + candidate_no，绝不自动重发。
      process.stdout.write(
        `${JSON.stringify({ outcome: 'unconfirmed', candidate_no: no, title, from, at, bytes: body.length, sha256 })}\n`,
      )
      process.exit(6)
    }
    hit('index-durable')
    process.stdout.write(
      `${JSON.stringify({ outcome: 'saved', no, title, from, at, bytes: body.length, sha256 })}\n`,
    )
  } finally {
    if (tmpPath) {
      try {
        unlinkSync(tmpPath)
      } catch {
        /* kill 造成的孤立 blob 保留而不引入后台 GC */
      }
    }
    closeStore(store)
  }
}

function storageError(r) {
  if (r.kind === 'missing') return unavailable('关键回复存储不可用（缺目录；post 需要能创建它）')
  if (r.kind === 'unsafe') return unavailable(kindReason(r))
  if (r.kind === 'error') return unavailable(kindReason(r))
  return unavailable('关键回复存储不可用')
}

// ---------------------------------------------------------------- 只读面
/** 读者的 store 打开：缺失 = 空 store（返回 {empty:true}）；损坏/权限 = unavailable。 */
function openReadStore(args) {
  const store = openStore(args.mainRoot, args.stateDir, 'read')
  if (store.ok) return store
  if (store.kind === 'missing') return { ok: true, empty: true }
  throw unavailable(kindReason(store))
}

function indexWarnings(size) {
  const w = []
  if (size % SLOT_SIZE !== 0) w.push({ kind: 'partial-tail', bytes: size % SLOT_SIZE })
  return w
}

function listEntry(meta) {
  return {
    no: meta.no,
    available: true,
    title: sanitize(meta.title),
    from: sanitize(meta.from),
    at: meta.at,
    bytes: meta.bytes,
    sha256: meta.sha256,
  }
}

function cmdSummary(args) {
  const store = openReadStore(args)
  if (store.empty) {
    process.stdout.write(`${JSON.stringify({ available: true, state: 'empty', total_slots: 0, warnings: [] })}\n`)
    return
  }
  try {
    const size = fstatSync(store.indexFd).size
    const slots = Math.floor(size / SLOT_SIZE)
    const warnings = indexWarnings(size)
    if (slots === 0) {
      process.stdout.write(
        `${JSON.stringify({ available: true, state: 'empty', total_slots: 0, warnings })}\n`,
      )
      return
    }
    const last = slotAt(store.indexFd, (slots - 1) * SLOT_SIZE, slots)
    if (!last.ok) {
      process.stdout.write(
        `${JSON.stringify({ available: true, state: 'unavailable', total_slots: slots, warnings, reason: last.reason })}\n`,
      )
      return
    }
    process.stdout.write(
      `${JSON.stringify({ available: true, state: 'ok', total_slots: slots, warnings, entry: listEntry(last.meta) })}\n`,
    )
  } finally {
    closeStore(store)
  }
}

function parseCursor(raw) {
  if (raw === undefined || raw === null) return null
  const s = String(raw)
  if (!/^[0-9]+$/.test(s)) throw input('--before 必须是正整数')
  const n = Number(s)
  if (!Number.isSafeInteger(n) || n < 1 || n > MAX_NO) throw input(`--before 超出编号域（1–${MAX_NO}）`)
  return n
}

function parseNo(raw) {
  if (raw === undefined || raw === null) throw input('show 需要 --no <编号>')
  const s = String(raw)
  if (!/^[0-9]+$/.test(s)) throw input('--no 必须是正整数')
  const n = Number(s)
  if (!Number.isSafeInteger(n) || n < 1 || n > MAX_NO) throw input(`--no 超出编号域（1–${MAX_NO}）`)
  return n
}

function cmdList(args) {
  const before = parseCursor(args.before)
  const format = args.format || 'json'
  const store = openReadStore(args)
  if (store.empty) {
    if (format === 'json')
      process.stdout.write(
        `${JSON.stringify({ available: true, state: 'empty', total_slots: 0, entries: [], next_before: null, warnings: [] })}\n`,
      )
    else process.stdout.write('(没有关键回复)\n')
    return
  }
  try {
    const size = fstatSync(store.indexFd).size
    const slots = Math.floor(size / SLOT_SIZE)
    const warnings = indexWarnings(size)
    const newest = slots === 0 ? 0 : before === null ? slots : Math.min(before - 1, slots)
    let hi = newest
    const entries = []
    while (hi >= 1 && entries.length < LIST_PAGE) {
      const r = slotAt(store.indexFd, (hi - 1) * SLOT_SIZE, hi)
      if (r.ok) entries.push(listEntry(r.meta))
      else entries.push({ no: hi, available: false, reason: r.reason })
      hi--
    }
    const oldest = entries.length ? entries[entries.length - 1].no : 0
    const nextBefore = oldest > 1 ? oldest : null
    if (format === 'json') {
      process.stdout.write(
        `${JSON.stringify({
          available: true,
          state: slots === 0 ? 'empty' : 'ok',
          total_slots: slots,
          entries,
          next_before: nextBefore,
          warnings,
        })}\n`,
      )
      return
    }
    if (entries.length === 0) {
      process.stdout.write('(没有关键回复)\n')
      return
    }
    for (const e of entries) {
      if (e.available) process.stdout.write(`#${e.no}\t${e.at}\t${e.from}\t${e.title}\n`)
      else process.stdout.write(`#${e.no}\t不可用（${sanitize(e.reason)}）\n`)
    }
    if (nextBefore) process.stdout.write(`older: team reply list --before ${nextBefore}\n`)
  } finally {
    closeStore(store)
  }
}

function readBody(store, meta) {
  if (typeof store.bodiesFd !== 'number') throw unavailable(`正文目录缺失（no=${meta.no}）`)
  const r = openFileAt(store.bodiesFd, `${meta.body_id}.md`, C.O_RDONLY)
  if (!r.ok) {
    if (r.kind === 'missing') throw unavailable(`正文文件缺失（no=${meta.no}）`)
    throw unavailable(kindReason(r))
  }
  try {
    const st = fstatSync(r.fd)
    if (st.size !== meta.bytes) throw unavailable(`正文长度与提交记录不一致（no=${meta.no}）`)
    if (st.size > MAX_BODY_BYTES) throw unavailable(`正文超过上界（no=${meta.no}）`)
    const buf = Buffer.alloc(st.size + 1)
    let got = 0
    while (got < st.size) {
      const n = readSync(r.fd, buf, got, st.size - got, got)
      if (n <= 0) break
      got += n
    }
    const extra = readSync(r.fd, buf, st.size, 1, st.size)
    if (got !== st.size || extra !== 0) throw unavailable(`正文读取不完整（no=${meta.no}）`)
    const body = buf.subarray(0, st.size)
    const digest = createHash('sha256').update(body).digest('hex')
    if (digest !== meta.sha256) throw unavailable(`正文哈希与提交记录不一致（no=${meta.no}）`)
    return body
  } finally {
    closeQuiet(r.fd)
  }
}

function cmdShow(args) {
  const no = parseNo(args.no)
  const format = args.format || 'text'
  const store = openReadStore(args)
  if (store.empty) throw unavailable(`没有编号 ${no} 的关键回复（存储为空）`)
  try {
    const size = fstatSync(store.indexFd).size
    const slots = Math.floor(size / SLOT_SIZE)
    if (no > slots) throw unavailable(`没有编号 ${no} 的关键回复（已提交 ${slots} 个编号）`)
    const r = slotAt(store.indexFd, (no - 1) * SLOT_SIZE, no)
    if (!r.ok) throw unavailable(`编号 ${no} 不可用（${r.reason}）`)
    const meta = r.meta
    const body = readBody(store, meta)
    if (format === 'raw') {
      process.stdout.write(body)
      return
    }
    let display
    try {
      display = new TextDecoder('utf-8', { fatal: true }).decode(body)
    } catch {
      throw unavailable(`编号 ${no} 的正文不是合法 UTF-8`)
    }
    if (format === 'json') {
      process.stdout.write(
        `${JSON.stringify({
          no: meta.no,
          available: true,
          title: sanitize(meta.title),
          from: sanitize(meta.from),
          at: meta.at,
          bytes: meta.bytes,
          sha256: meta.sha256,
          text_kind: 'safe-display',
          display_text: sanitize(display),
        })}\n`,
      )
      return
    }
    process.stdout.write(`#${meta.no} ${sanitize(meta.title)}\n`)
    process.stdout.write(
      // P266: the human header shows the label exactly as the record carries it, with no qualifier
      // beside it. "The tool authenticates nothing" belongs in the docs and the key-replies
      // requirement, not in a suffix on every display (machine outputs keep the label verbatim).
      `来自 ${sanitize(meta.from)} · ${meta.at} · ${meta.bytes} 字节 · sha256 ${meta.sha256.slice(0, 16)}…\n\n`,
    )
    process.stdout.write(sanitize(display))
    if (!display.endsWith('\n')) process.stdout.write('\n')
  } finally {
    closeStore(store)
  }
}

// ---------------------------------------------------------------- 入口
function parseArgs(argv) {
  const out = { _: [] }
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i]
    switch (a) {
      case '--main-root':
      case '--state-dir':
      case '--from':
      case '--title':
      case '--before':
      case '--no':
      case '--format': {
        const key = a.slice(2).replace(/-([a-z])/g, (_, c) => c.toUpperCase())
        if (i + 1 >= argv.length) throw input(`${a} 缺少值`)
        out[key] = argv[++i]
        break
      }
      case '--stdin':
        out.stdin = true
        break
      case '-h':
      case '--help':
        out.help = true
        break
      default:
        throw input(`未知参数 ${a}`)
    }
  }
  return out
}

function usage() {
  process.stdout.write(
    [
      '用法（内部 helper；人用的入口是 team reply）：',
      '  replies.mjs post   --main-root <dir> --state-dir <dir> --from <label> --title <t> --stdin',
      '  replies.mjs summary --main-root <dir> --state-dir <dir>',
      '  replies.mjs list   --main-root <dir> --state-dir <dir> [--before <no>] [--format json|text]',
      '  replies.mjs show   --main-root <dir> --state-dir <dir> --no <no> [--format json|text|raw]',
      '',
    ].join('\n'),
  )
}

const IS_ENTRY =
  typeof process.argv[1] === 'string' && import.meta.url === pathToFileURL(process.argv[1]).href

if (IS_ENTRY) {
  const cmd = process.argv[2]
  const rest = process.argv.slice(3)
  main(() => {
    const args = parseArgs(rest)
    if (args.help || !cmd) {
      usage()
      return
    }
    args.mainRoot = parseMainRoot(args.mainRoot)
    if (!args.stateDir) throw input('缺少 --state-dir')
    args.stateDir = resolve(args.mainRoot, args.stateDir)
    switch (cmd) {
      case 'post':
        cmdPost(args)
        return
      case 'summary':
        cmdSummary(args)
        return
      case 'list':
        if (args.format && args.format !== 'json' && args.format !== 'text') throw input('--format 只接受 json|text')
        cmdList(args)
        return
      case 'show':
        if (args.format && !['json', 'text', 'raw'].includes(args.format))
          throw input('--format 只接受 json|text|raw')
        cmdShow(args)
        return
      default:
        throw input(`未知子命令 ${cmd}`)
    }
  })
}

export { cmdList as _cmdList, cmdShow as _cmdShow, cmdSummary as _cmdSummary, cmdPost as _cmdPost }
