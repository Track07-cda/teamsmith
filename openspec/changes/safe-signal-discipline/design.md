# Design: `safe-signal-discipline` — a recorded pid is the only identity a signal may use

## Context

The incidents are one shape: an actor selected processes by a name or a command-line pattern. The pattern selects
neighbours belonging to other jobs and projects, and it selects the caller's own shell whenever the pattern sits in
the caller's command line. The recon (`docs/team/reports/P154-dev-bob/recon.log`) shows both halves on this
machine, read-only: a marker pattern matches both decoys, a marker in the caller's own command line matches the
caller, `kill -TERM <recorded pid>` reaches exactly one process — and nothing today prevents the pattern route:
`pkill`/`killall` resolve to `/usr/bin/` inside a gated window (the gate directory holds only `tmux`), `team bg`
is not a subcommand, `state/bg.log` never carries a pid, and the tmux isolation lint is green while the gate's own
M25 fixture cleans up with `pkill -f`.

The tmux gate is the proven shape: `team_tmux_shim_exports` renders a window prefix that puts
`skills/teamsmith/scripts/shim` first on `PATH` and pins the audit log, and the shim records every call, decides by
target, and fails closed. This change builds the signal gate on that shape instead of inventing a second one.

## Goals / Non-Goals

**Goals.**

1. Inside a gated window, a name- or pattern-selecting signal cannot be sent: `pkill` and `killall` refuse, send
   nothing, and point at the safe routes.
2. Every intercepted call is recorded in the same family as the tmux call log, and a refusal survives that log's
   rotation.
3. The background-job lane records the pid (and its identity proof) when it starts a job, and stopping a job by id
   signals exactly that job — never a neighbour, never another project's or session's process.
4. The repository's scripts and fixtures are held to the same rule by a lint with teeth, and the gate's own
   pattern-based cleanups are fixed in the same change.

**Non-Goals.**

- Wrapping `kill`, `pgrep`, `ps` or `pidof` (see D3), or blocking absolute paths (the lint's job, D7).
- An escape hatch for pattern kills (D2), or registering the tmux family's own launch seams (D8).
- Hunting orphans of a finished job, or a cross-project/cross-worktree stop (D6).
- Changing any tmux verdict, the panel's behavior beyond the three new labels, or another project's state.

## Decisions

### D1 — the refusal is total: every `pkill`/`killall` selection is refused

There is no provable selection form, so the gate has none. `-f <pattern>` selects by command line; `-x <name>`
selects by name — and a name is not an identity either (several seats and sessions run the same binary name, and a
`pkill -x bash` reaches the caller's own shell); `-P <pid>`, `-u <user>` and `killall`'s other modes select an
unbounded set that no record of the caller's can enumerate. The safe route is not the same tool with another flag:
it is the recorded pid, which the caller already has (it spawned the job) or can read (`team bg list`). Refusing
the whole tool is the fail-closed reading of "a pattern is not an identity" and keeps the rule one sentence long.

### D2 — no in-band escape token

The tmux gate has `--teamsmith-allow-destructive` because a human occasionally must kill a server or a session and
can name that object in argv. A signal has no object in argv — that is the whole problem — so a token would grant
exactly the flaw. The routes that need no grant (recorded pid, `team bg stop`) are always present, and `kill`
itself stays available (D3).

### D3 — the honest reach: `kill` is not intercepted, and the gate is a `PATH` shim

At exec time the shim sees expanded argv only: `kill $(pgrep -f x)` and `kill $(cat job.pid)` are the same four
bytes of shape. Wrapping `kill` therefore either blocks the safe route or allows the unsafe one, so the gate does
not wrap it; `pgrep`, `ps` and `pidof` stay read-only and available. An absolute path (`/usr/bin/pkill`) and a
shell that does not carry the gate directory first on `PATH` bypass the shim by construction. Those two holes are
covered statically, not silently: the lint reddens both shapes in repository scripts (D7), and the requirement
states the boundary instead of implying coverage.

### D4 — the audit family mirrors the tmux one

`TEAM_SIGNAL_CALLS_LOG` (default `state/signal-calls.log`) gets one line per intercepted call with the family's
field shape — `<ISO-8601> · act=<pass|refused> · tool=<pkill|killall> · argv=<…> · pid=<…> ppid=<…> cwd=<…>` — the
same bound (past 2000 call lines keep the newest 1000, first line the rotation marker
`<ISO> · rotation · dropped=<N>` with the same reading/restart rules), and refusals copied byte for byte into the
sibling `.forensics` file. Pass lines are not retained (retention covers the gate's refusals, not its traffic).
A retention that cannot be written prints a `✗` diagnostic and marks the line `retention=failed`; it never changes
the verdict or blocks the call. `TEAM_SIGNAL_REAL` pins the real executable for fixtures exactly as `TEAM_TMUX_REAL`
does; without it the gate scans `PATH` for the first same-named file that is not itself.

### D5 — installation reuses the one prefix, and the pulse window stays out

The new entry points live in the same gate directory (`scripts/shim/`): one `signal-gate` implementation with
`pkill`/`killall` entry points, so `team_tmux_shim_exports` carries them without a second installation path, and
both the PM window and every worker window get them (the two launch renderers, `team_pm_launch_cmd` and
`team_agent_launch_cmd`). Read-only forms (`--help`, `-h`, `-V`, `--version`) pass through to the resolved real
executable and are recorded `act=pass`; a refusal resolves nothing, so the gate still refuses when the real binary
is missing. The pulse window (`team monitor`) is deliberately not an injection point: it runs no fixture and makes
no signal, and widening the prefix there is a separate policy call (Open Questions). User shells, non-teamsmith
sessions and absolute paths remain outside — stated in the requirement.

### D6 — `team bg stop`: identity is `(pid, start-time)`, and only the recorded job is signalled

The extension writes `state/bg/<id>.job` (key=value lines: `id`, `pid`, `pgid`, `start`, `cwd`, `log`, `cmd`)
before it returns the job id, so an id the caller holds always has a record; `team bg list` reads the records of
the current project's state directory and prints one row per job. `team bg stop <id>` resolves the record through
that state directory only — never another worktree, project or session — and refuses (exit 3 no record, 4
malformed/unreadable, 5 identity mismatch, 6 signalling failed, 2 usage; 0 stopped or already gone) with nothing
signalled on every refusal. Before signalling it re-reads `/proc/<pid>` and requires the start-time fingerprint to
equal the record's: pid reuse is the failure mode that makes a bare pid unsafe, and the fingerprint is the
strongest proof of "the same process". With the identity proven and `pgid == pid` (the detached spawn's group
leader) it signals the group `TERM`, then `KILL` after `TEAM_BG_STOP_GRACE` (default 5 s) if it lives; with a
different group it signals the pid alone and says descendants were not reached. Every signal, the job id and the
command are printed, and one `stop` line (job, signal, result, the stopper's pid and cwd) lands in `state/bg.log`.
A leader that is already gone is a no-op with an explicit "descendants are not hunted" line; the lane never
searches by name or tree.

**P169 (F1/F2) sharpens D6 into a state boundary.** The job id is a **flat name** — non-empty, no path separator,
not `.`/`..`, bounded at 128 characters (the spawner's own slug allows 32) — and the record must be a regular file
that `realpath` still places inside the project's own `bg` directory: a symbolic link, a FIFO, a device, a
directory or a path resolving outside is refused (exit 4) **before the payload is read** (so a FIFO cannot block),
and a non-flat id is a usage error (exit 2). `pid` and `pgid` must both be positive integers, and before any signal
the live process's current process group must equal the recorded `pgid` (mismatch = exit 5). `team bg list` applies
the same shape and skips symlinks with a visible warning.

**P187 (F1') closes the directory layer.** P169 compared the record's real parent with the `bg` directory's real
path — a comparison that stays self-consistent when `state/bg` itself is a symlink to a sibling project's
directory, because both sides resolve there. A redirected `bg` (the non-malicious shape: several worktrees
sharing one state) would therefore accept another project's records and stop its processes. So the `bg` directory
itself must resolve inside the project's own state directory **before any record is resolved**, and `team bg list`
applies the same check — one rule, both sides; a directory that resolves outside is refused (exit 4) with a
diagnostic naming the link's target, and a missing `bg` directory is still "no records" (exit 3 / the empty list),
not a refusal. The fixture pins the shape (the sibling's process stays alive, `state/bg.log` gains no line), the
reverse (a real directory keeps stopping its jobs) and a `--break=no-dir-boundary` shadow that turns the shape red
again.

### D7 — one lexer, two lints; the hidden boundary is the legacy list, not silence

The signal lint needs the command-position parsing the tmux lint already implements (including the substitution
handling), so the lexer moves to `skills/teamsmith/tests/lib/shell-lex.pl` and both lints require it. The
extraction is gated by invariance: the tmux lint's `--list` output on the real tree must be byte-identical before
and after, and its `--selftest` green — if that cannot be shown, the apply stops and reports instead of shipping a
changed isolation gate. The lexer gains one annotation: a word records the command words of its command
substitutions, so `kill $(pgrep -f x)` is distinguishable from `kill $(cat job.pid)`.

`tests/signal-lint.pl` judges the trees the isolation lint judges (`tests/**` and `docs/team/reports/*/pkg/**`),
exits 0 clean / 1 red / 2 usage, names file and line, and carries a two-directional `--selftest`. Red: a
`pkill`/`killall` command word (behind `command`/`env` prefixes, or as a literal absolute path), an `xargs` whose
arguments include `kill`/`pkill`/`killall` (stdin is the selection), and a `kill` whose argument carries a
substitution over `pgrep`/`pidof`/`ps`/`fuser`. Clean: `kill -TERM "$pid"`, `kill -0 "$pid"`, `kill -- -"$pgid"`,
`kill "$pid1" "$pid2"`, `kill "$(cat "$pidfile")"`. `tests/` is never exempt — the gate's own two `pkill -f`
cleanup lines in the M25 fixture are rewritten to kill the control pid the fixture already locates. Historic
evidence packages under `docs/team/reports/*/pkg/**` are frozen by sha256 in `tests/signal-lint-legacy.txt` with
the family's rules (count checked, printed every run, `--no-legacy` reddens them all), because editing a verified
evidence package would be editing the ledger.

### D8 — the new seams are contract rows, and the tmux family stays as it is

The project's rule is that a change registers every knob it introduces: `TEAM_SIGNAL_CALLS_LOG` and
`TEAM_SIGNAL_REAL` are `refuse` · `path` rows (test/pinned seams, the `TEAM_DISK_STATS_FILE` shape) and
`TEAM_BG_STOP_GRACE` a `refuse` · `seconds` row, each with zh/en labels (≤22 cells) in the panel's string tables,
a row in `references/config.md` (the docs→schema completeness walk reads it) and the rebuilt bundle. The tmux
family's two launch seams predate that rule and are deliberately not retrofitted here — a reviewer comparing the
families should see one deliberate exception, named in this change, rather than two silent ones.

### D9 — the tests and their flips

- `tests/signal-gate.sh`: refuses `pkill -f` (both decoys alive, the argv-recording stub's record empty, exit 64,
  the message naming the safe routes), refuses `-x`/`-P`/`-u`/`killall`, ignores
  `TEAM_ALLOW_PATTERN_KILL=1`, passes `--help`/`-V` through to the stub with `act=pass`, leaves
  `kill -TERM <recorded pid>` working, and exercises the log's bound/forensics/failed-retention paths.
  `--break=pass` makes the gate execute the call: the fixture's "stub was not called"/"decoys alive" assertions go
  red — the fixture's own red side, with no real `pkill` ever executed.
- `tests/team-bg-stop.sh`: starts a real job (the existing `team-bg-harness.mjs` spawner path) plus a neighbour,
  stops it by id, and pins the refusals (unknown id, sibling state directory, reused pid, malformed record,
  already-gone leader with a live descendant). `--break=no-identity` skips the fingerprint check and must make the
  reused-pid assertion red.
- `tests/team-bg-harness.mjs` gains the record case: after `team_bg_run`, `state/bg/<id>.job` exists and its
  `pid`/`pgid`/`start` match the returned pid and the live process.
- `smoke.sh` gains one section (the next free number — 57 is taken by delivery-truth as of this merge, so the apply confirms the then-free number) that runs the lint (with the scratch-copy flip), the
  two fixtures and the harness record case; it runs in the fast gate as well (no tmux, no container). The section
  registry (`section-paths.tsv`, `section-budgets.tsv`) gets its row, and `section-select.sh --check` runs before
  the gate (a duplicated section key is the known failure mode).

## Risks / Trade-offs

- **[A legitimate "kill that stray process" workflow breaks inside gated windows]** → the refusal prints both
  safe routes (`team bg list`/`team bg stop`, and `kill` with a pid the caller recorded); `kill` itself is not
  intercepted, and a human can still run the real tool outside the gate. Fail-closed is deliberate.
- **[Extracting the lexer changes the isolation lint]** → the byte-identical `--list` proof, the lint's
  `--selftest`, and the frozen legacy check are all gates; the apply stops and reports if invariance fails.
- **[pid reuse]** → the `(pid, start-time)` pair, refusal on mismatch or unreadable fingerprint, and a scenario
  that pins it.
- **[A descendant escapes the job's own process group]** → it is not hunted; the output says so, and the job log
  remains the place to read what the job spawned.
- **[The job record cannot be written]** → no record means no stop (refused with the reason); this is the
  fail-closed direction and it is visible in `team bg list`.
- **[The lint's default roots include historic evidence packages]** → the sha256-frozen legacy list keeps them out
  of the red count without editing the ledger, and `--no-legacy` is the manual audit.
- **[Registering the signal seams but not the tmux ones looks inconsistent]** → named as a deliberate exception in
  D8 (the tmux seams predate the rule); a follow-up task can register them separately.

## Open Questions

- Should the pulse window carry the gate family too? Today it runs only `team monitor` and makes no signal; the
  default is "leave it out" and the PM can open a task if that changes.
- Should the tmux family's two launch seams be registered as `refuse` rows for symmetry? Out of scope here (D8).
