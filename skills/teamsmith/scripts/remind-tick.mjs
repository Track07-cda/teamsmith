#!/usr/bin/env node
// remind-tick.mjs — Pulse's lightweight Reminder due tick (change: agent-self-reminder 4.1 · P423).
//
// Both Pulse shapes run this same entry roughly every ten seconds, independently of the full patrol's
// cadence: the console spawns it from its own timer, the headless loop calls it between patrols. It is not
// a second daemon and it never scans the project or calls a model — it reads one bounded snapshot and, if
// something is due, commits the queue entries under the authority lock.
//
// The unlocked `peek` in front is only a wake-up test: with nothing due it exits after one file read and
// no lock (a project without reminders costs one small read per tick). Every decision that changes state
// happens inside `request()`, the same flock transaction the CLI and the PM watcher use.
//
// Usage: remind-tick.mjs --root <project-root> --state-dir <state-root>
//                       [--pulse-started <ISO instant>] [--quiet] [--json]
// Exit: 0 = tick done (nothing due, or admitted); 1 = an explicit state/lock/identity error (stderr says
// which; the pulse records it and keeps its own cadence); 2 = bad usage.

import { appendFileSync, readFileSync, statSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { peek, request } from './state-authority.mjs';

const LOG_MAX_BYTES = 256 * 1024;

function usage() {
  process.stderr.write('usage: remind-tick.mjs --root <project-root> --state-dir <state-root> ' +
    '[--pulse-started <ISO instant>] [--quiet] [--json]\n');
}

function parse(argv) {
  const opts = { root: '', stateDir: '', pulseStarted: '', quiet: false, json: false };
  for (let i = 0; i < argv.length; i++) {
    const token = argv[i];
    const value = () => {
      const v = argv[++i];
      if (v === undefined) throw new Error(`${token} needs a value`);
      return v;
    };
    switch (token) {
      case '--root': opts.root = value(); break;
      case '--state-dir': opts.stateDir = value(); break;
      case '--pulse-started': opts.pulseStarted = value(); break;
      case '--quiet': opts.quiet = true; break;
      case '--json': opts.json = true; break;
      case '-h': case '--help': usage(); process.exit(0); break;
      default: throw new Error(`unknown argument ${token}`);
    }
  }
  if (!opts.root) throw new Error('--root is required');
  if (!opts.stateDir) throw new Error('--state-dir is required');
  return opts;
}

// A durable, bounded line per tick that actually committed something: "why did the PM wake up" has to be
// answerable from the disk, not from a process that has already exited.
function log(stateRoot, line) {
  const file = path.join(stateRoot, 'reminders.log');
  try {
    appendFileSync(file, `${new Date().toISOString()} ${line}\n`);
    if (statSync(file).size > LOG_MAX_BYTES) {
      const kept = readFileSync(file, 'utf8').split('\n').slice(-400).join('\n');
      writeFileSync(file, kept);
    }
  } catch (e) {
    process.stderr.write(`remind-tick: could not append ${file} (${e.code ?? e.message}); the admission is committed, only the log line is missing\n`);
  }
}

async function main() {
  const opts = parse(process.argv.slice(2));
  const context = { cwd: opts.root, mainRoot: opts.root, stateRoot: opts.stateDir };
  const seen = await peek(context);
  if (!seen.pinned) {
    if (opts.json) process.stdout.write(`${JSON.stringify({ ok: true, pinned: false, admitted: [] })}\n`);
    return;
  }
  const due = seen.reminders.due.length;
  const stale = seen.reminders.staleIntent.length;
  if (!due && !stale) {
    if (opts.json) process.stdout.write(`${JSON.stringify({ ok: true, pinned: true, admitted: [], swept: [] })}\n`);
    return;
  }
  const result = await request({ ...context, stateRoot: seen.stateRoot }, {
    op: 'remind-admit',
    pulseStartedAt: opts.pulseStarted || new Date().toISOString(),
  });
  const admitted = result.admitted ?? [];
  const swept = result.swept ?? [];
  if (admitted.length || swept.length) {
    log(seen.stateRoot, `admit n=${admitted.length} overdue=${(result.overdue ?? []).length} ` +
      `ids=${admitted.join('|') || '-'} unknown=${swept.join('|') || '-'} queue=${result.queue}`);
  }
  if (opts.json) process.stdout.write(`${JSON.stringify(result)}\n`);
  else if (!opts.quiet && admitted.length) {
    process.stdout.write(`remind: 到点入队 ${admitted.length} 条（${admitted.join(' ')}）\n`);
  }
}

main().catch(e => {
  const message = String((e && e.message) || e);
  process.stderr.write(/^remind-tick:/.test(message) ? `${message}\n` : `remind-tick: ${message}\n`);
  process.exitCode = 1;
});
