#!/usr/bin/env node
// state-authority.mjs — one durable project-state authority (P406 · change: agent-self-reminder 1.1/1.2).
//
// Every cooperating process (CLI, Pulse, Pi) enters through request(): Bash by running this file with
// --cli, Node by importing { request }. Both spawn the same OS `flock` with this same file as the
// transaction helper, so there is exactly one implementation of the locator, the snapshot and the lock:
//
//   <main>/.pi/team/reminder-locator.json     pinned state root + persistent project identity
//   <main>/.pi/team/reminder-locator.lock     serializes locator establishment (never removed)
//   <state>/reminders/state.json              the versioned snapshot (authority)
//   <state>/reminders/authority.lock          serializes every state transaction (never removed)
//
// Lock order is always locator, then authority. Neither path depends on TMPDIR. A transaction reads and
// validates the snapshot, mutates it, writes a unique same-directory temporary file, fsyncs it, renames
// it over the snapshot and fsyncs the directory before reporting success.
//
// A missing flock, a lock timeout, a corrupt/unsupported snapshot, a torn file or an identity mismatch
// is a visible error. There is no unlocked fallback and an unreadable snapshot is never replaced by an
// empty store. This slice (1.1/1.2) deliberately does NOT import or touch the legacy `standby` marker:
// migration is task 1.3. `init` therefore only ever writes a fresh snapshot with Standby generation 0.

import * as fs from 'node:fs';
import path from 'node:path';
import { randomUUID } from 'node:crypto';
import { spawn, spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const SELF = fileURLToPath(import.meta.url);
const SNAPSHOT_VERSION = 1;
const LOCK_WAIT_SECONDS = 5;
// `flock -E` reports a lock conflict with this code, so "waited the whole window" and "the helper died"
// stop looking alike. A helper of ours never exits 75.
const LOCK_CONFLICT_EXIT = 75;
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
const SEQUENCE_KINDS = new Set(['reminder', 'batch', 'queue']);

const fail = message => { throw new Error(message); };

// The project a working directory belongs to -- the same git rule as common.sh's team_dir_roots, so a
// Node caller (Pulse, Pi) cannot be talked out of its own project by an inherited variable.
function projectOf(cwd) {
  const out = spawnSync('git', ['-C', cwd, 'rev-parse', '--path-format=absolute', '--show-toplevel', '--git-common-dir'],
    { encoding: 'utf8' });
  if (out.error) fail(`cannot resolve the project identity from ${cwd}: ${out.error.message}`);
  if (out.status !== 0) fail(`cannot resolve the project identity from ${cwd}: not a git work tree (${String(out.stderr || '').trim()})`);
  const [top, common] = String(out.stdout).trim().split('\n');
  if (!top || !common) fail(`cannot resolve the project identity from ${cwd}: unexpected git output`);
  return { main: fs.realpathSync(path.dirname(common)) };
}

// Every entry point pins identity the same way: derive the project from the working directory, then
// refuse an inherited root that names a different project (a second authority must never be created).
// The git lookup is cached per working directory (a long-lived Pulse/Pi process must not fork git for
// every transaction); the comparison against the caller's root runs on every call.
const identityByCwd = new Map();
function authorityIdentity(context) {
  const cwd = realDir(context.cwd ?? process.cwd(), 'working directory');
  let derived = identityByCwd.get(cwd);
  if (!derived) { derived = projectOf(cwd); identityByCwd.set(cwd, derived); }
  const main = context.mainRoot ? realDir(context.mainRoot, 'project root') : derived.main;
  if (main !== derived.main) {
    fail(`inherited project root ${main} does not belong to the working directory's project (${derived.main}); ` +
      'refusing to create or use a second authority -- clear the inherited TEAM_* identity or run from the project');
  }
  return main;
}
const exists = file => { try { fs.lstatSync(file); return true; } catch (e) { if (e.code === 'ENOENT') return false; throw e; } };
const regular = file => {
  if (!fs.lstatSync(file).isFile()) fail(`not a regular file: ${file}`);
};

function realDir(dir, what) {
  let real;
  try { real = fs.realpathSync(dir); } catch (e) { fail(`${what} does not exist or is unreadable: ${dir} (${e.code ?? e.message})`); }
  if (!fs.statSync(real).isDirectory()) fail(`${what} is not a directory: ${dir}`);
  return real;
}

// Physical path of a possibly-not-yet-created path: realpath of the deepest existing ancestor plus the
// remaining segments. This is what two processes must agree on before anything is created.
function canonical(pathLike) {
  let current = path.resolve(pathLike);
  const rest = [];
  for (;;) {
    try { return path.join(fs.realpathSync(current), ...rest); }
    catch (e) {
      if (e.code !== 'ENOENT') throw e;
      const parent = path.dirname(current);
      if (parent === current) throw e;
      rest.unshift(path.basename(current));
      current = parent;
    }
  }
}

function fsyncDir(dir) {
  const fd = fs.openSync(dir, 'r');
  try { fs.fsyncSync(fd); } finally { fs.closeSync(fd); }
}

function readJSON(file) {
  regular(file);
  const text = fs.readFileSync(file, 'utf8');
  try { return JSON.parse(text); } catch (e) { fail(`unreadable JSON in ${file}: ${e.message}`); }
}

// fsync the file, rename it into place, fsync the directory. A failed write leaves the old snapshot.
function writeAtomic(file, value) {
  const dir = path.dirname(file);
  const tmp = path.join(dir, `.${path.basename(file)}.${process.pid}.${randomUUID()}.tmp`);
  let fd;
  try {
    fd = fs.openSync(tmp, 'wx', 0o600);
    fs.writeFileSync(fd, JSON.stringify(value) + '\n', 'utf8');
    fs.fsyncSync(fd);
    fs.closeSync(fd);
    fd = undefined;
    fs.renameSync(tmp, file);
    fsyncDir(dir);
  } catch (e) {
    if (fd !== undefined) { try { fs.closeSync(fd); } catch { /* the original error is the one to report */ } }
    try { if (exists(tmp)) fs.unlinkSync(tmp); } catch { /* a leftover temp file is inert; keep the real error */ }
    throw e;
  }
}

const locatorFile = main => path.join(main, '.pi/team/reminder-locator.json');
const locatorLock = main => path.join(main, '.pi/team/reminder-locator.lock');
const remindersDir = state => path.join(state, 'reminders');
const snapshotFile = state => path.join(remindersDir(state), 'state.json');
const authorityLock = state => path.join(remindersDir(state), 'authority.lock');

// The lock files are permanent regular files. Refuse a symlink or special file instead of locking it.
function verifyLockFile(lock) {
  let fd;
  try { fd = fs.openSync(lock, fs.constants.O_CREAT | fs.constants.O_RDWR | fs.constants.O_NOFOLLOW, 0o600); }
  catch (e) { fail(`cannot use lock file ${lock}: ${e.code ?? e.message}`); }
  try { if (!fs.fstatSync(fd).isFile()) fail(`lock path is not a regular file: ${lock}`); }
  finally { fs.closeSync(fd); }
}

function readLocator(main) {
  const file = locatorFile(main);
  if (!regular_exists(file)) return null;
  const locator = readJSON(file);
  if (locator.version !== SNAPSHOT_VERSION) fail(`unsupported state-root locator version: ${locator.version} (${file})`);
  if (typeof locator.projectId !== 'string' || !UUID_RE.test(locator.projectId)) fail(`state-root locator ${file} has no persistent project identity`);
  if (locator.mainRoot !== main) fail(`state-root locator ${file} belongs to another project (${locator.mainRoot})`);
  if (typeof locator.stateRoot !== 'string' || !path.isAbsolute(locator.stateRoot)) fail(`state-root locator ${file} has an invalid state root`);
  return locator;
}
function regular_exists(file) {
  try { return fs.lstatSync(file).isFile(); } catch (e) { if (e.code === 'ENOENT') return false; throw e; }
}

// Absent means never initialized. Present but not a regular file (a symlink, fifo, directory) is a
// corrupt authority: refuse it instead of treating it as absent and renaming a new snapshot over it.
function snapshotPresence(file) {
  let stat;
  try { stat = fs.lstatSync(file); } catch (e) { if (e.code === 'ENOENT') return false; throw e; }
  if (!stat.isFile()) fail(`state snapshot is not a regular file: ${file}`);
  return true;
}

// A pinned locator must name this project and the canonical state root the caller asked for.
function agree(locator, main, want) {
  if (locator.stateRoot !== want) {
    fail(`canonical state-root mismatch: pinned ${locator.stateRoot}, requested ${want}; ` +
      'quiesce the writers and migrate the locator explicitly (never pick a second authority)');
  }
  return { created: false, projectId: locator.projectId, mainRoot: main, stateRoot: locator.stateRoot };
}

// Runs under the locator lock and only ever establishes the first locator: a process that lost the race
// re-reads here and agrees with the winner instead of pinning a second authority.
function locate(main, requested) {
  const want = canonical(requested);
  const pinned = readLocator(main);
  if (pinned) return agree(pinned, main, want);
  // First pin: refuse a state root that lives in another project's .pi/team before creating anything.
  const inside = /^(.*)\/\.pi\/team(?:\/|$)/.exec(want);
  if (inside && inside[1] !== main) {
    fail(`state root ${want} is inside another project's .pi/team (${inside[1]}); pass this project's own state root`);
  }
  fs.mkdirSync(want, { recursive: true });
  const stateRoot = fs.realpathSync(want);
  if (stateRoot !== want) fail(`state root ${want} resolves to ${stateRoot} after creation; refusing a moving authority`);
  const locator = { version: SNAPSHOT_VERSION, projectId: randomUUID(), mainRoot: main, stateRoot };
  writeAtomic(locatorFile(main), locator);
  return { created: true, projectId: locator.projectId, mainRoot: main, stateRoot: locator.stateRoot };
}

function integer(value) {
  return Number.isSafeInteger(value) && value >= 0;
}

function initial(locator) {
  return {
    version: SNAPSHOT_VERSION,
    project: { id: locator.projectId, mainRoot: locator.mainRoot, stateRoot: locator.stateRoot },
    sequences: { reminder: 1, batch: 1, queue: 1 },
    pruned: 0,
    // Present from version 1 so task 1.3 can migrate into the same snapshot. This slice never reads or
    // writes the legacy marker: generation 0 means "no authority-observed Standby yet", not "off".
    standby: { on: false, generation: 0, reason: null, since: null },
    reminders: [],
    batches: [],
    audit: [],
  };
}

function validate(snapshot, main, state) {
  const where = snapshotFile(state);
  if (!snapshot || typeof snapshot !== 'object' || Array.isArray(snapshot)) fail(`invalid state snapshot ${where}: not an object`);
  if (snapshot.version !== SNAPSHOT_VERSION) fail(`unsupported state version: ${snapshot.version} (${where}; expected ${SNAPSHOT_VERSION})`);
  const project = snapshot.project;
  if (!project || typeof project !== 'object') fail(`invalid state snapshot ${where}: missing project identity`);
  if (typeof project.id !== 'string' || !UUID_RE.test(project.id)) fail(`invalid state snapshot ${where}: missing project id`);
  if (project.mainRoot !== main) fail(`state project identity mismatch: snapshot main root ${project.mainRoot}, this project ${main}`);
  if (project.stateRoot !== state) fail(`state project identity mismatch: snapshot state root ${project.stateRoot}, this authority ${state}`);
  if (!snapshot.sequences || typeof snapshot.sequences !== 'object') fail(`invalid state snapshot ${where}: missing sequence identities`);
  for (const kind of SEQUENCE_KINDS) {
    if (!Number.isSafeInteger(snapshot.sequences[kind]) || snapshot.sequences[kind] < 1) fail(`invalid state snapshot ${where}: invalid ${kind} sequence`);
  }
  if (!integer(snapshot.pruned)) fail(`invalid state snapshot ${where}: invalid pruned high-water`);
  const standby = snapshot.standby;
  if (!standby || typeof standby !== 'object' || typeof standby.on !== 'boolean' || !integer(standby.generation)) {
    fail(`invalid state snapshot ${where}: invalid Standby slot`);
  }
  if (standby.reason !== null && typeof standby.reason !== 'string') fail(`invalid state snapshot ${where}: invalid Standby reason`);
  if (standby.since !== null && typeof standby.since !== 'string') fail(`invalid state snapshot ${where}: invalid Standby timestamp`);
  for (const key of ['reminders', 'batches', 'audit']) {
    if (!Array.isArray(snapshot[key])) fail(`invalid state snapshot ${where}: ${key} is not an array`);
  }
  if (!snapshot.reminders.every(record => record && typeof record === 'object' && typeof record.id === 'string')) {
    fail(`invalid state snapshot ${where}: a Reminder record has no id`);
  }
  if (!snapshot.batches.every(record => record && typeof record === 'object' && typeof record.id === 'string')) {
    fail(`invalid state snapshot ${where}: a batch record has no id`);
  }
}

function summary(snapshot, created) {
  return {
    version: snapshot.version,
    created,
    projectId: snapshot.project.id,
    mainRoot: snapshot.project.mainRoot,
    stateRoot: snapshot.project.stateRoot,
    sequences: { ...snapshot.sequences },
    pruned: snapshot.pruned,
    standby: { ...snapshot.standby },
    counts: { reminders: snapshot.reminders.length, batches: snapshot.batches.length, audit: snapshot.audit.length },
    snapshot: snapshotFile(snapshot.project.stateRoot),
  };
}

function apply(snapshot, request) {
  switch (request.op) {
    case 'init':
      return summary(snapshot, true);
    case 'read':
      return summary(snapshot, false);
    case 'allocate': {
      const kind = request.kind;
      if (!SEQUENCE_KINDS.has(kind)) fail(`unknown state sequence kind: ${kind}`);
      const value = snapshot.sequences[kind];
      snapshot.sequences[kind] = value + 1;
      return { kind, value, highWater: snapshot.sequences[kind], projectId: snapshot.project.id, stateRoot: snapshot.project.stateRoot };
    }
    default:
      fail(`unknown state operation: ${request.op}`);
  }
}

// Runs under the authority lock. The locator is re-read here so a snapshot and a locator that were
// swapped between projects cannot both pass validation.
function transaction(main, state, request) {
  const locator = readLocator(main);
  if (!locator) fail(`state-root locator disappeared for ${main}; refusing an unpinned authority`);
  if (locator.stateRoot !== state) fail(`state root ${state} is not the pinned authority (${locator.stateRoot})`);
  verifyLockFile(authorityLock(state));
  const file = snapshotFile(state);
  const hasSnapshot = snapshotPresence(file);
  let snapshot;
  if (hasSnapshot) {
    snapshot = readJSON(file);
    validate(snapshot, main, state);
    if (snapshot.project.id !== locator.projectId) fail(`project identity mismatch: snapshot ${snapshot.project.id}, locator ${locator.projectId}`);
  } else {
    // Absent => never initialized. Corrupt/unsupported is handled above and never becomes an empty store.
    if (request.op === 'read') fail(`state authority is not initialized: ${file}`);
    snapshot = initial(locator);
    validate(snapshot, main, state);
  }
  const before = JSON.stringify(snapshot);
  const result = apply(snapshot, request);
  result.created = !hasSnapshot;
  const changed = JSON.stringify(snapshot) !== before;
  // A first `init` does not mutate the object, but the fresh snapshot must still be published.
  if (changed || !hasSnapshot) writeAtomic(file, snapshot);
  return result;
}

function flock(lock, args, input) {
  return new Promise((resolve, reject) => {
    const startedAt = Date.now();
    const child = spawn('flock', ['-x', '-w', String(LOCK_WAIT_SECONDS), '-E', String(LOCK_CONFLICT_EXIT), lock,
      process.execPath, SELF, ...args],
      { stdio: [input === undefined ? 'ignore' : 'pipe', 'pipe', 'pipe'] });
    const out = [];
    const err = [];
    child.stdout.on('data', chunk => out.push(chunk));
    child.stderr.on('data', chunk => err.push(chunk));
    child.on('error', e => reject(new Error(`flock unavailable: ${e.message}; install a usable OS flock utility (no unlocked fallback)`)));
    if (input !== undefined) child.stdin.on('error', () => { /* the helper may exit before reading; its exit status carries the error */ });
    child.on('close', (code, signal) => {
      const stderr = Buffer.concat(err).toString().trim();
      if (code !== 0) {
        if (stderr) return reject(new Error(stderr));
        // Only a conflict exit that actually used up the window is a timeout. Anything else (a helper
        // killed or crashed mid-transaction) is reported as what it is, with its status.
        const waitedOut = code === LOCK_CONFLICT_EXIT && Date.now() - startedAt >= LOCK_WAIT_SECONDS * 1000 - 500;
        if (waitedOut) return reject(new Error(`lock wait timed out after ${LOCK_WAIT_SECONDS}s at ${lock}; no state was written`));
        return reject(new Error(`transaction helper exited with status ${code}${signal ? ` (${signal})` : ''} at ${lock}; no state was written`));
      }
      try { resolve(JSON.parse(Buffer.concat(out).toString())); }
      catch (e) { reject(new Error(`invalid transaction result from ${lock}: ${e.message}`)); }
    });
    if (input !== undefined) child.stdin.end(input);
  });
}

async function resolveAuthority(context) {
  const main = authorityIdentity(context);
  const want = canonical(context.stateRoot);
  // A pinned locator is replaced by rename, so an unlocked read always sees a whole one. That keeps the
  // common path at zero child processes; the locator lock is taken only to establish the first one.
  const pinned = readLocator(main);
  if (pinned) return agree(pinned, main, want);
  try { fs.mkdirSync(path.join(main, '.pi/team'), { recursive: true }); }
  catch (e) { fail(`cannot create the project-local locator directory under ${main}: ${e.code ?? e.message}`); }
  return flock(locatorLock(main), ['--locator', main, want]);
}

// The single Node-facing entry point (the CLI below is a thin wrapper around it).
export async function request(context, requestData) {
  const located = await resolveAuthority(context);
  const state = located.stateRoot;
  try { fs.mkdirSync(remindersDir(state), { recursive: true, mode: 0o700 }); }
  catch (e) { fail(`cannot create the authority directory under ${state}: ${e.code ?? e.message}`); }
  return flock(authorityLock(state), ['--transaction', located.mainRoot, state], JSON.stringify(requestData));
}

export async function resolve(context) {
  return resolveAuthority(context);
}

function parseCli(argv) {
  const [main, state, op, ...rest] = argv;
  if (!main || !state || !op) fail('usage: state-authority.mjs --cli <project-root> <state-root> <resolve|init|read|allocate <kind>> [--print <field>]');
  let print = null;
  const args = [];
  while (rest.length) {
    const token = rest.shift();
    if (token === '--print') {
      print = rest.shift();
      if (!print) fail('--print needs a field name');
      continue;
    }
    args.push(token);
  }
  const requestData = { op };
  if (op === 'allocate') {
    requestData.kind = args.shift();
    if (!requestData.kind) fail('allocate needs a sequence kind (reminder|batch|queue)');
  }
  if (args.length) fail(`unexpected arguments: ${args.join(' ')}`);
  return { context: { mainRoot: main, stateRoot: state }, requestData, print };
}

async function main(argv) {
  const [mode, ...rest] = argv;
  if (mode === '--locator') {
    const [main, requested] = rest;
    verifyLockFile(locatorLock(main));
    process.stdout.write(JSON.stringify(locate(main, requested)) + '\n');
    return;
  }
  if (mode === '--transaction') {
    const [main, state] = rest;
    const chunks = [];
    for await (const chunk of process.stdin) chunks.push(chunk);
    let requestData;
    try { requestData = JSON.parse(Buffer.concat(chunks).toString()); }
    catch (e) { fail(`invalid transaction request on stdin: ${e.message}`); }
    process.stdout.write(JSON.stringify(transaction(main, state, requestData)) + '\n');
    return;
  }
  if (mode === '--cli') {
    const { context, requestData, print } = parseCli(rest);
    const result = requestData.op === 'resolve' ? await resolve(context) : await request(context, requestData);
    if (print !== null) {
      if (!Object.hasOwn(result, print)) fail(`unknown output field: ${print}`);
      if (result[print] === null || typeof result[print] === 'object') fail(`output field ${print} is not scalar`);
      process.stdout.write(String(result[print]) + '\n');
    } else {
      process.stdout.write(JSON.stringify(result, null, 2) + '\n');
    }
    return;
  }
  fail('usage: state-authority.mjs --cli <project-root> <state-root> <resolve|init|read|allocate <kind>>');
}

if (process.argv[1] && path.resolve(process.argv[1]) === SELF) {
  main(process.argv.slice(2)).catch(e => {
    const message = String((e && e.message) || e);
    process.stderr.write(/^state-authority:/.test(message) ? `${message}\n` : `state-authority: ${message}\n`);
    process.exitCode = 1;
  });
}
