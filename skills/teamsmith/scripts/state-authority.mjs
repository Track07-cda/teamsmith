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
// empty store. Task 1.3 moved every Standby reader/writer here: the snapshot's `standby` slot is the only
// truth, and the legacy `<state>/standby` marker is read once by the migration (see importLegacy) and then
// retired to `<state>/standby.migrated` -- the snapshot is published before the marker is retired, so a
// crash in between replays only the retirement (`migrated` makes the import exactly-once).
//
// Reads are pure: they never publish a snapshot and never take part in the migration (the panel and the
// monitor are display paths and must not write). Until the first write, a read answers from the legacy
// marker exactly as the old readers did, so an upgrading team is never mistaken for "not on standby".

import * as fs from 'node:fs';
import path from 'node:path';
import { randomUUID } from 'node:crypto';
import { spawn, spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { REMIND_OPS, applyReminder, renderRemind, validateReminders } from './remind-store.mjs';

const SELF = fileURLToPath(import.meta.url);
const SNAPSHOT_VERSION = 1;
const LOCK_WAIT_SECONDS = 5;
// `flock -E` reports a lock conflict with this code, so "waited the whole window" and "the helper died"
// stop looking alike. A helper of ours never exits 75.
const LOCK_CONFLICT_EXIT = 75;
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
const SEQUENCE_KINDS = new Set(['reminder', 'batch', 'queue']);
// Standby operations. A read is answered from the snapshot and never publishes one; the other three are
// mutations and run the legacy import first, in the same locked transaction.
const STANDBY_OPS = new Set(['standby-read', 'standby-on', 'standby-off', 'standby-import']);
const STANDBY_READ_OPS = new Set(['read', 'standby-read']);

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
    // `migrated` records that the legacy marker has been imported (or proven absent): an old snapshot
    // without the key is unmigrated, and the next mutation imports the marker before it does anything.
    standby: { on: false, generation: 0, reason: null, since: null, migrated: false },
    reminders: [],
    batches: [],
    audit: [],
  };
}

// ---------------------------------------------------------------- 待命（PM 主动停工）
// The legacy marker is one line: `<timestamp> <reason>` (the old writer printed `-` when it had no reason).
// It is only consulted while the snapshot says `migrated: false`, i.e. before the import has run.
const legacyMarkerFile = state => path.join(state, 'standby');

function legacyMarker(state) {
  const file = legacyMarkerFile(state);
  let stat;
  try { stat = fs.lstatSync(file); } catch (e) { if (e.code === 'ENOENT') return null; throw e; }
  // A symlink or a directory here is not the old format: refuse it instead of importing a guess.
  if (!stat.isFile()) fail(`legacy Standby marker is not a regular file: ${file}; move it aside and retry`);
  const line = fs.readFileSync(file, 'utf8').split('\n', 1)[0];
  const cut = line.indexOf(' ');
  const since = cut === -1 ? line : line.slice(0, cut);
  if (!since) fail(`legacy Standby marker is empty: ${file}; delete it if the team was not on standby`);
  const reason = cut === -1 ? '-' : line.slice(cut + 1);
  return { reason: reason === '' ? '-' : reason, since };
}

// Import once, inside the caller's transaction: the reason and the start time survive, and the generation
// is kept as it is -- the import is not a new on generation (a later `standby on` is). A marker that is
// still there after a completed import is leftover evidence, not truth: it is only retired, never adopted.
function importLegacy(snapshot, state) {
  const marker = legacyMarker(state);
  let imported = false;
  if (!snapshot.standby.migrated) {
    snapshot.standby = {
      on: marker ? true : snapshot.standby.on,
      generation: snapshot.standby.generation,
      reason: marker ? marker.reason : snapshot.standby.reason,
      since: marker ? marker.since : snapshot.standby.since,
      migrated: true,
    };
    imported = Boolean(marker);
  }
  return { imported, marker: Boolean(marker) };
}

// The snapshot is already durable when this runs, so a failure here cannot lose the state: the marker is
// inert from now on. Say so instead of reporting the whole write as failed (the caller would retry, and a
// retried `standby on` is a new generation).
function retireLegacy(state) {
  const file = legacyMarkerFile(state);
  if (!regular_exists(file)) return null;
  let target = path.join(state, 'standby.migrated');
  for (let n = 1; exists(target); n++) target = path.join(state, `standby.migrated.${n}`);
  try {
    fs.renameSync(file, target);
    fsyncDir(state);
    return target;
  } catch (e) {
    process.stderr.write(`state-authority: imported ${file} but could not retire it (${e.code ?? e.message}); ` +
      'it is no longer read, remove it by hand\n');
    return null;
  }
}

// What readers see. While the import has not run, the marker is still the record (an upgrading team must
// not read as "off"); afterwards only the snapshot counts, even if a stale marker is still on disk.
function standbyView(snapshot, state) {
  if (snapshot.standby.migrated) return { ...snapshot.standby, legacy: false };
  const marker = legacyMarker(state);
  if (!marker) return { ...snapshot.standby, legacy: false };
  return { on: true, generation: snapshot.standby.generation, reason: marker.reason, since: marker.since, legacy: true };
}

function standbyResult(snapshot, state, extra) {
  const view = standbyView(snapshot, state);
  return {
    ok: true, on: view.on, generation: view.generation, reason: view.reason, since: view.since,
    migrated: Boolean(snapshot.standby.migrated), legacy: Boolean(view.legacy), ...extra,
  };
}

function isoSeconds(ms) {
  return new Date(ms).toISOString().replace(/\.\d{3}Z$/, 'Z');
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
  // Absent means "not imported yet" (a snapshot written by 1.1/1.2); anything but a boolean is corrupt.
  if (standby.migrated !== undefined && typeof standby.migrated !== 'boolean') fail(`invalid state snapshot ${where}: invalid Standby migration flag`);
  for (const key of ['reminders', 'batches', 'audit']) {
    if (!Array.isArray(snapshot[key])) fail(`invalid state snapshot ${where}: ${key} is not an array`);
  }
  if (!snapshot.reminders.every(record => record && typeof record === 'object' && typeof record.id === 'string')) {
    fail(`invalid state snapshot ${where}: a Reminder record has no id`);
  }
  if (!snapshot.batches.every(record => record && typeof record === 'object' && typeof record.id === 'string')) {
    fail(`invalid state snapshot ${where}: a batch record has no id`);
  }
  // The reminder records carry the delivery truth, so their shape is validated with the same care as the
  // envelope: a record whose id, phase or high-water contradicts the snapshot is refused, never "repaired".
  validateReminders(snapshot, fail);
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
    standby: { ...snapshot.standby, migrated: Boolean(snapshot.standby.migrated) },
    counts: { reminders: snapshot.reminders.length, batches: snapshot.batches.length, audit: snapshot.audit.length },
    snapshot: snapshotFile(snapshot.project.stateRoot),
  };
}

function apply(snapshot, request, nowMs, state) {
  if (REMIND_OPS.has(request.op)) return applyReminder(snapshot, request, nowMs);
  switch (request.op) {
    case 'init':
      return summary(snapshot, true);
    case 'read':
      return summary(snapshot, false);
    case 'standby-read':
      return standbyResult(snapshot, state);
    case 'standby-import':
      return standbyResult(snapshot, state);
    case 'standby-on': {
      // Every `on` is a new, never-reused generation (an already-on team that is told to stand down again
      // gets one too): a wake binds a generation, and reusing one would let a stale binding turn off a
      // newer stand-down.
      snapshot.standby = {
        on: true,
        generation: snapshot.standby.generation + 1,
        reason: typeof request.reason === 'string' ? request.reason : '-',
        since: isoSeconds(nowMs),
        migrated: true,
      };
      return standbyResult(snapshot, state);
    }
    case 'standby-off': {
      // Already off is not an error and not a transition: nothing changes, so nothing is written.
      if (snapshot.standby.on) {
        snapshot.standby = { on: false, generation: snapshot.standby.generation, reason: null, since: isoSeconds(nowMs), migrated: true };
      }
      return standbyResult(snapshot, state);
    }
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
    // A display path (panel banner, monitor, `standby status`) must not create anything: answer from the
    // legacy marker -- or "off" -- and let the first write publish the snapshot.
    if (STANDBY_READ_OPS.has(request.op)) return apply(snapshot, request, Date.now(), state);
  }
  const before = JSON.stringify(snapshot);
  // Every mutation imports the legacy marker first, inside this same transaction, so no write can land on
  // a half-upgraded team. Reads never import: they only *view* the marker (see standbyView).
  const migration = STANDBY_READ_OPS.has(request.op) ? { imported: false, marker: false } : importLegacy(snapshot, state);
  const result = apply(snapshot, request, Date.now(), state);
  // A reminder result reports its own `created` (an idempotent key hit is created:false); every other
  // operation keeps the authority-level meaning: was this the first snapshot?
  if (!REMIND_OPS.has(request.op) && !STANDBY_OPS.has(request.op)) result.created = !hasSnapshot;
  const changed = JSON.stringify(snapshot) !== before;
  // A first `init` does not mutate the object, but the fresh snapshot must still be published. A read
  // (list/show, a refused cancel) never publishes one: reading an empty authority stays a read.
  if (changed || (!hasSnapshot && request.op === 'init')) writeAtomic(file, snapshot);
  // Publish first, retire second: the snapshot already records `migrated`, so a crash in between only
  // replays the retirement instead of importing a second time.
  const retired = migration.marker ? retireLegacy(state) : null;
  if (request.op === 'standby-import') { result.imported = migration.imported; result.retired = retired; }
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
  if (requestData.op === 'standby-read') return readStandby(context);
  const located = await resolveAuthority(context);
  const state = located.stateRoot;
  try { fs.mkdirSync(remindersDir(state), { recursive: true, mode: 0o700 }); }
  catch (e) { fail(`cannot create the authority directory under ${state}: ${e.code ?? e.message}`); }
  return flock(authorityLock(state), ['--transaction', located.mainRoot, state], JSON.stringify(requestData));
}

// A read must establish nothing: it never creates the locator and never publishes a snapshot. Two reasons:
// the panel and the monitor are display paths (they must not write), and a caller that merely names another
// TEAM_STATE_DIR must not capture the project's pin from under it. Which record answers the read is the
// same decision the migration makes: an unpinned project is still described by the legacy marker.
function unfiledStandby(state) {
  const marker = legacyMarker(state);
  return marker
    ? { ok: true, on: true, generation: 0, reason: marker.reason, since: marker.since, migrated: false, legacy: true }
    : { ok: true, on: false, generation: 0, reason: null, since: null, migrated: false, legacy: false };
}

async function readStandby(context) {
  const main = authorityIdentity(context);
  const state = canonical(context.stateRoot);
  const pinned = readLocator(main);
  if (!pinned) {
    if (snapshotPresence(snapshotFile(state))) {
      fail(`state authority is not pinned for ${main} (${locatorFile(main)} is missing) but ${snapshotFile(state)} exists; ` +
        'refusing to answer from an unpinned snapshot');
    }
    return unfiledStandby(state);
  }
  if (pinned.stateRoot !== state) {
    fail(`canonical state-root mismatch: pinned ${pinned.stateRoot}, requested ${state}; ` +
      'quiesce the writers and migrate the locator explicitly (never pick a second authority)');
  }
  return flock(authorityLock(state), ['--transaction', main, state], JSON.stringify({ op: 'standby-read' }));
}

export async function resolve(context) {
  return resolveAuthority(context);
}

function parseCli(argv) {
  const [main, state, op, ...rest] = argv;
  if (!main || !state || !op) {
    fail('usage: state-authority.mjs --cli <project-root> <state-root> ' +
      '<resolve|init|read|allocate <kind>|standby-read|standby-on|standby-off|standby-import|' +
      'remind-add|remind-list|remind-show|remind-cancel> ' +
      '[--print <field>] [--json]');
  }
  let print = null;
  let json = false;
  const args = [];
  const flags = {};
  while (rest.length) {
    const token = rest.shift();
    if (token === '--print') {
      print = rest.shift();
      if (!print) fail('--print needs a field name');
      continue;
    }
    // Reminder flags are parsed here and handed to the transaction as data; the helper never reads them
    // from the environment or from a shell-quoted string.
    if (REMIND_OPS.has(op) && token.startsWith('--')) {
      const name = token.slice(2);
      if (name === 'json') { json = true; continue; }
      if ((REMIND_BOOL_FLAGS[op] ?? new Set()).has(name)) { flags[name] = true; continue; }
      const value = rest.shift();
      if (value === undefined) fail(`${token} needs a value`);
      flags[name] = value;
      continue;
    }
    // Standby takes exactly one flag (`--reason` on `standby-on`); anything else is refused by name, so a
    // typo cannot pass for a successful stand-down.
    if (STANDBY_OPS.has(op) && token.startsWith('--')) {
      const name = token.slice(2);
      if (name === 'json') { json = true; continue; }
      if (op === 'standby-on' && name === 'reason') {
        const value = rest.shift();
        if (value === undefined) fail('--reason needs a value');
        flags.reason = value;
        continue;
      }
      fail(`${op} does not accept --${name}`);
    }
    args.push(token);
  }
  const requestData = REMIND_OPS.has(op) ? parseRemindFlags(op, flags)
    : STANDBY_OPS.has(op) ? (op === 'standby-on' ? { op, reason: flags.reason ?? '-' } : { op })
      : { op };
  if (op === 'allocate') {
    requestData.kind = args.shift();
    if (!requestData.kind) fail('allocate needs a sequence kind (reminder|batch|queue)');
  }
  if (args.length) fail(`unexpected arguments: ${args.join(' ')}`);
  return { context: { mainRoot: main, stateRoot: state }, requestData, print, json };
}

// Boolean reminder flags (everything else takes a value).
const REMIND_BOOL_FLAGS = { 'remind-list': new Set(['all']) };

// Exactly the flags each reminder operation accepts: an unknown flag is refused here rather than silently
// ignored, so a typo cannot look like a successful create.
const REMIND_FLAGS = {
  'remind-add': new Set(['at', 'after', 'key', 'task', 'source']),
  'remind-list': new Set(['all']),
  'remind-show': new Set(['id']),
  'remind-cancel': new Set(['id']),
};

function parseRemindFlags(op, flags) {
  const allowed = REMIND_FLAGS[op];
  const request = { op };
  for (const name of Object.keys(flags)) {
    if (!allowed.has(name)) fail(`${op} does not accept --${name}`);
    request[name] = flags[name];
  }
  if ((op === 'remind-show' || op === 'remind-cancel') && !request.id) fail(`${op} needs --id <reminder-id>`);
  return request;
}

// The message is read from stdin so its bytes never travel through argv: no shell quoting, no length
// limit, no re-encoding. Invalid UTF-8 is refused before a lock is taken.
async function readMessageFromStdin() {
  const chunks = [];
  for await (const chunk of process.stdin) chunks.push(chunk);
  const buffer = Buffer.concat(chunks);
  let text;
  try { text = new TextDecoder('utf-8', { fatal: true }).decode(buffer); }
  catch { return { error: 'message is not valid UTF-8; write the text as UTF-8 and try again' }; }
  if (text.indexOf('\u0000') !== -1) return { error: 'message contains a NUL byte' };
  return { message: text };
}

// Standby is rendered here (not in the shell) so a reason keeps every byte it was given: the shell only
// prints these lines, and `--print <field>` stays the machine interface.
function renderStandby(op, result) {
  const status = result.on
    ? `standby: on（自 ${result.since ?? '-'}，原因：${result.reason ?? '-'}）`
    : 'standby: off';
  if (op !== 'standby-import') {
    // Until the import runs, the marker is still the record: say so once, where a human reads it.
    return result.legacy ? `${status}\n（旧标记还没并入统一状态：跑 team standby migrate 完成迁移）` : status;
  }
  if (result.imported) {
    return `${status}\n迁移：state/standby 已并入统一状态（原因与时间保留，代次仍是 ${result.generation}：迁移不加代）；` +
      `旧标记改名为 ${result.retired ?? '（改名失败，已不再被读取）'}`;
  }
  if (result.retired) return `${status}\n迁移：统一状态早已并入；这次清掉了残留的旧标记（改名为 ${result.retired}）`;
  return `${status}\n迁移：无需迁移（统一状态已记录待命${result.on ? '开启' : '关闭'}）`;
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
    const { context, requestData, print, json } = parseCli(rest);
    if (REMIND_OPS.has(requestData.op)) {
      if (requestData.op === 'remind-add') {
        const message = await readMessageFromStdin();
        if (message.error) {
          process.stdout.write(renderRemind(requestData.op, { ok: false, refusal: 'bad-message', reason: message.error }));
          process.exitCode = 1;
          return;
        }
        requestData.message = message.message;
      }
      const result = await request(context, requestData);
      const text = json ? JSON.stringify(result, null, 2) + '\n' : renderRemind(requestData.op, result);
      process.stdout.write(text.endsWith('\n') ? text : text + '\n');
      // A refusal is not a crash: the reason was printed, and the exit status says nothing was written.
      if (!result.ok) process.exitCode = 1;
      return;
    }
    const result = requestData.op === 'resolve' ? await resolve(context) : await request(context, requestData);
    if (print !== null) {
      if (!Object.hasOwn(result, print)) fail(`unknown output field: ${print}`);
      if (result[print] === null || typeof result[print] === 'object') fail(`output field ${print} is not scalar`);
      process.stdout.write(String(result[print]) + '\n');
    } else if (STANDBY_OPS.has(requestData.op) && !json) {
      process.stdout.write(renderStandby(requestData.op, result) + '\n');
    } else {
      process.stdout.write(JSON.stringify(result, null, 2) + '\n');
    }
    return;
  }
  fail('usage: state-authority.mjs --cli <project-root> <state-root> ' +
    '<resolve|init|read|allocate <kind>|standby-read|standby-on|standby-off|standby-import|' +
    'remind-add|remind-list|remind-show|remind-cancel> [--print <field>] [--json]');
}

if (process.argv[1] && path.resolve(process.argv[1]) === SELF) {
  main(process.argv.slice(2)).catch(e => {
    const message = String((e && e.message) || e);
    process.stderr.write(/^state-authority:/.test(message) ? `${message}\n` : `state-authority: ${message}\n`);
    process.exitCode = 1;
  });
}
