# destructive-call-forensics · design

## Context

The gate (`skills/teamsmith/scripts/shim/tmux`) wraps every `tmux` call a PM/worker window makes and appends one
line to `$TEAM_TMUX_CALLS_LOG` (the project's `state/tmux-calls.log`): ISO timestamp, resolved socket,
`TMUX`/`TMUX_TMPDIR`, full argv, pid/ppid, cwd, and one of four actions — `pass`, `refused`, `allowed-owned`,
`explicit-flag`. The log is bounded at 2000 lines → newest 1000, with a `rotation · dropped=<N>` marker; a FIFO
target is skipped and any write error is swallowed, because logging must never block a call or change a verdict
(M36/M67/P77/P87).

The 8th default-server death (2026-09-29) was investigated in a window whose log held only later `pass` traffic:
the destructive verdicts had rotated away. The `dropped=N` marker kept “no record” apart from “never happened”,
but the records themselves were gone. The fixture-trace scan (`verification`) also treats anything under
`.pi/team/state/` as ledger state except exactly two traffic records, so any new gate-written file must be added
to that exclusion set by exact path or the gate reds its own isolation assertions (the P77 incident shape).

## Goals / Non-Goals

**Goals**

- A call whose action is not `pass` stays readable after the call log has rotated its own line away.
- The retained copy is the call log's own line, byte for byte, so the two files can be cross-checked.
- Retention is bounded and self-describing; a failed retention is visible immediately (stderr) and durably (the
  call's own line).
- Nothing the gate already decides changes: verdicts, exit codes, socket resolution, the log's bound/marker and
  the launch command's pinned environment stay as they are.

**Non-Goals**

- Retaining `pass` traffic, or any “keep everything” mode.
- Time-based rotation, per-session/per-caller sharding, compression, or a reader/UI for the file (it is forensic
  evidence read by a human or an agent, like the call log).
- Reconstructing history that the call log already rotated away — the past cannot be backfilled.

## Decisions

### D1 · The file is the call log's derived sibling: `$TEAM_TMUX_CALLS_LOG.forensics`

Alternatives: a new `TEAM_TMUX_FORENSICS_LOG` pinned by the launch command, or a fixed
`state/tmux-calls-forensics.log` name. Both were rejected. A new env pin changes the launch string that smoke
pins byte-for-byte (the M8.1 invariance reference) and, worse, an unset key would silently disable the promise —
a silent hole in exactly the kind of guard this change exists to fix. A fixed name does not follow a custom or
fixture `TEAM_TMUX_CALLS_LOG` and re-hardcodes a layout the variable already abstracts. The derivation is total
(any log path gets one sibling), needs no new key, and gives the retention exactly the call log's directory and
lifetime. The fixture-trace scan therefore excludes the derived path exactly:
`.pi/team/state/tmux-calls.log.forensics`.

### D2 · Only `act≠pass`, and byte-identical to the call log's line

A retained record is the same formatted line (same field order, same timestamp/pid/argv), so `grep -F` of the
log's line finds its copy while both exist, and the four-value action vocabulary stays closed. A distinct record
format (`kept=1`, JSON, a summary) was rejected: it carries no extra information and destroys the cheap
cross-check. `pass` is never copied (the ruling's negative): copying it would spend the bound on traffic that is
plentiful in the call log, and “keep everything” is the unbounded thing the ruling forbids. This includes a
destructive subcommand the gate passed on a private socket — the verdict decides, never the subcommand's name.

### D3 · The bound and rotation are the call log's own rule

Past 2000 lines the oldest go and the newest 1000 stay, with the same `rotation · dropped=<N>` marker, the same
cumulative counting and the same unreadable-count restart (P77/P87). Reusing the routine and its vocabulary keeps
one hardened code path and one fixture idiom instead of two subtly different ones; the destructive-only stream
makes 1000 records a very long tail while still bounding a flood. Time-based rotation was rejected as unnecessary
surface (P77 already ruled it out), and an unbounded file is the ruling's explicit non-goal.

### D4 · Failure visibility: `retention=failed` on the call's own line, plus stderr

Ordering: the verdict is computed first and never touched; retention is attempted before the call log's line is
written, so the line can state its outcome; then the call log appends (and rotates) as today. Failures covered:
a directory/unwritable target, an I/O error, and a FIFO target (skipped, never blocked on).

Alternatives rejected: a separate `retention-failed` marker line in the call log breaks “exactly one line per
call” and would need a bound-counting exception — a failure loop could then grow the log without limit; a sidecar
`.error` file is a third traffic record with a third exclusion that can fail for the same reason; stderr alone is
missable because a window's stderr is not guaranteed to be read. The suffix is appended last, carries no `act=`
token and no existing assertion anchors a call line's end, so the log's parsers keep working. When the call log
itself is unwritable (its FIFO case), the stderr diagnostic is the unconditional channel — there is no other
medium left, and the requirement says so.

### D5 · The scan exclusion is exact, with decoys

The retention file's content is the caller's own argv by construction, so it joins the fixture-trace scan's
out-of-scope set as a third **exact path** — not a glob, not a basename rule. `.pi/team/state/tmux-calls.log`
being exact is what keeps `tmux-calls.log.1` red; the same must hold for `tmux-calls.log.forensics.1` and for a
`nested/` copy.

## Risks / Trade-offs

- [A caller loops destructive calls and floods the retention file] → the 2000/1000 bound drops the oldest and the
  marker says how many; the same caller floods the call log just the same.
- [The `retention=failed` field surprises a parser] → it is appended last and adds no action token; smoke pins the
  exact shape, and no assertion matches a full call line.
- [The retention failure repeats on every call] → accepted; visibility is the point, and the call log still
  appends exactly one line per call.
- [Concurrent windows rotate the same file] → the call log's existing best-effort `tmp` + `mv` rule is reused; a
  lost race costs at most a few old lines and never blocks a call.
- [The new file surprises a reader or a future scan] → `references/troubleshooting.md` §18 states the path and its
  contract; the scan's exclusion set is the one place that knows about it.

## Migration Plan

No backfill: lines the call log already rotated away cannot be reconstructed. The file appears with the first
non-pass call after the change. Rollback is reverting the shim's logging block; the sibling file is inert then.
