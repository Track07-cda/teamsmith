# Troubleshooting (hard-won lessons)

Run `team doctor` first; then look at the extension log with `tail -f $(grep TEAM_NOTIFY_LOG .pi/team/config.sh)`.

---

## 1. The PM never receives an agent's "turn ended" notification

Check in order of likelihood:

1. **The extension is not loaded**: in a linked worktree Pi does **not** auto-discover the project-local
   `.pi/extensions/`. `team dispatch` must pass `-e <skill>/extension/team-notify.ts`. When you start an agent by
   hand you have to add it yourself.
2. **cwd is not under the worktree**: the extension only fires inside `<root>/<TEAM_WORKTREES_DIR>/...`. If you change
   `TEAM_WORKTREES_DIR` you must update the configuration too (the extension reads the same `config.sh`).
3. **The window name equals the PM window name**: it is skipped (to prevent self-triggering loops). An agent window
   must be named after the agent — `team dispatch` already guarantees that.
4. **tmux session mismatch**: the extension compares `#{session_name}` with `TEAM_SESSION`. The PM session must live
   in the session of the same name.
5. **Deduplication**: an identical briefing within `TEAM_NOTIFY_DEDUP_SEC` (default 20s) is only sent once. Set it to
   0 while debugging.
6. **The PM window does not exist**: the message only lands in the inbox, nothing is typed into a window.
   `team doctor` warns about this.
7. **Not inside tmux**: `TMUX_PANE` is empty → the extension cannot determine the window name and skips. Either run
   inside tmux, or set `TEAM_NOTIFY_TMUX=0` and set the window name for the agent explicitly (not supported today,
   a known limitation).

## 2. An agent session "cannot be found again" / its memory broke

A Pi session belongs to a **cwd**: `--session-id` can only be reused under the same project path.

- Never move or rename an agent's worktree; never `rm -rf .worktrees/<agent>` and recreate it at a different path.
- If you already did, use `team dispatch <agent> ... --fresh` (a new session) and note in the agent's thread why it
  had to start over.
- Session id rule: `<TEAM_SESSION>-<agent>` (`--fresh` appends a timestamp).

## 3. Notification text gets glued to what the PM is typing

`tmux send-keys` literally "types" the text into the PM session's input line, as if you had typed it. A known side
effect. Mitigations:

- Answer with a short sentence right after reading a notification (which clears the input line).
- Lower the information volume: `TEAM_INBOX_MAX_CHARS`; or `TEAM_NOTIFY_TMUX=0` and read `team digest` yourself.
- Do not leave half a sentence hanging in the PM's input box for a long time.

## 4. `team dispatch` refuses to dispatch

| Error | Cause | What to do |
|---|---|---|
| only X MB of swap left | the `TEAM_MIN_FREE_SWAP_MB` floor (default 1024) | wait for an agent to finish; if slowness is acceptable, `TEAM_MIN_FREE_SWAP_MB=0 team dispatch …` |
| available memory X MB < 2048 | a warning only (RAM is tight) | you may continue; lower concurrency if it feels sluggish. To silence it completely: `TEAM_WARN_AVAIL_MB=0` |
| available memory + free swap only X MB | the hard `TEAM_MIN_TOTAL_MB` floor | the machine really is out of resources: stop an agent first |
| model X concurrency limit N | `TEAM_MODEL_LIMITS` | wait, or temporarily `TEAM_MODEL_LIMITS="" team dispatch ...` |
| unknown agent | not in the roster | edit `TEAM_AGENTS` |
| worktree does not exist | `add-agent` was never run | dispatch creates it automatically, but an explicit `team add-agent <a>` is preferable |
| window exists → replacing | the previous turn is still running | dispatch only after checking: replacing interrupts it (ask for progress with `team say` first) |

## 5. git worktree errors

- `fatal: '<branch>' is already checked out`: that branch lives in another worktree. Find it with `git worktree list`,
  or use a detached checkout for verification (which is what `team review` does).
- A stale worktree lock: `git worktree prune`.
- Cannot remove it (dirty): run `git -C <wt> status` first, and only use `team teardown --purge --force` once you are
  sure nothing is worth keeping.

## 6. Merging and deciding "is it merged?"

- After `git merge --squash` the task branch is **not** an ancestor of the protected branch, so `git branch --merged`
  cannot tell you anything. Trust the `BOARD.md` status plus the `reviews/<ID>.md` record, not ancestry.
- Conflicts: `git merge --squash` leaves the conflict state behind; inspect it with
  `git status --porcelain | grep '^U'`, then either `git add -A && git commit` or `git merge --abort` to start over.
- Before merging, the main worktree must be clean and on the protected branch — deliberately so: it stops an agent's
  dirty state from slipping into the merge commit.

## 7. forge (github / gitlab)

- `gh` 401/403: the PAT file path/permissions/scope. Merging needs `pull-requests: write`, which many PATs do not
  have → fall back to a local squash + a comment + closing the PR (see `workflows.md` F).
- GitLab 403: the token needs the `api` scope and at least the Developer role; if the MR target branch is protected,
  the Developer role may be unable to merge.
- When using a real tool, inject on demand (`GH_TOKEN="$(< .gh-pat)" gh …`); do not `export GH_TOKEN` permanently and
  do not `cat` a token onto the screen or into a log.

## 8. A report does not match reality

- Symptom: the report says "tests pass", verification fails.
- Action: paste the failing output into the thread → send it back → add "you must reproduce the failing test first" to
  the brief.
- At the process level: `team review` must actually run the gates (do not fall into always passing `--no-gates`).
- The same agent making the same kind of mistake repeatedly: switch to a different model family for the independent
  verification, or make the acceptance commands copy-pasteable.

## 9. An agent crossed the boundary and edited someone else's directory

- Immediately `team say <agent> "stop: <path> is not yours, roll your change back (git checkout -- <path>)"`.
- Add an explicit ownership line to `OWNERSHIP.md`/the brief — most crossings come from a brief that did not say.
- If the crossing was already committed: reject it during verification and have the agent `git revert` it, or redo the
  branch.

## 11. Other known traps

- **The skill was not injected into the system prompt**: pi only writes skills into the system prompt when a tool that
  can read files (`read` or `bash`) is available. Running with `--no-tools` means not seeing the skill is normal, not
  a failed installation. How to verify: `bash tests/smoke.sh` or `bun tests/skill-load.mjs` (loads this skill through
  pi's own parser, zero model calls).
- **Where the inbox is really written**: the notify extension prefers the git main worktree (an agent's worktree has
  its own copy of `config.sh`), so inboxes always end up in the main worktree's `<docs>/inbox/`; if a log shows the
  root pointing at a worktree path, the extension is too old.
- **Suspect paths or a mismatched config**: run `team paths` first (it prints main_root / worktree / docs / session /
  pm_window).
- **`TEAM_PI_BIN`**: point it at an absolute path when pi is not on PATH (or when you want a fake pi for self-tests).

## 11. Keep-alive and liveness decisions

- **How "the PM is not running" is decided**: `pane_current_command` not being a shell → running; being a shell whose
  command line carries a non-option argument or a foreground subcommand → also treated as running (`busy`).
  This is to accommodate pi started through a shell wrapper (where the foreground name shows bash) and user rc hooks
  that keep a child alive (so "it has a child process" cannot be taken as busy).
- **team up respawns the PM window's pane**: only when no pi is running there (an empty prompt).
  So do not treat the PM window as a normal terminal; to start working manually, re-run `pi` in that window or simply
  let the watchdog bring it up.
  Note: `pi` is the pane's own process (we `exec` it), so when pi exits the pane closes and the window disappears —
  exactly the `missing` case the watchdog reports (corresponding to the `TEAM_WATCH_REBUILD_TMUX` switch).
- **Typing only happens when something is really running**: `say`/`notify`/the extension refuse when the target window
  sits at an empty prompt (otherwise the text would be executed by the shell as a command) and only write the inbox
  for the PM to read later.
- **What the watchdog actually manages**: it recomputes the pending work on a timer (unread notifications / reports
  awaiting verification / board todo·wip / blocked / agents with an unfinished task that stopped), and **only wakes the
  PM when there is pending work** (nudge it while running; `pi -c` when it is not). With nothing pending it does
  nothing at all.
  It will not resume agents for you, does not create tmux sessions/windows (unless `TEAM_WATCH_REBUILD_TMUX=1`), and
  does not merge code.
- **The PM keeps being woken / does not want to be woken**: `team standby on --reason "…"` deliberately stands the PM
  down (both "there really is nothing to do without a human" and "stuck waiting for someone" qualify); `team standby
  off` resumes. While on standby the backlog is still recorded in `state/watchdog.log`.
- **Wake-up frequency**: every 15 minutes by default (`TEAM_WATCH_INTERVAL=900`, 300~3600 recommended); repeated
  reminders for the same pending work are limited by `TEAM_WATCH_NUDGE_GAP`. To go slower or faster, change these two
  values.
- **The PM was "woken twice"**: the instant notification at the end of an agent's turn (the notify extension) and the
  watchdog's timed reminder are two different things — the latter is a fallback for unprocessed pending work. Handle
  or ack the pending work and it stops.
- **The watchdog says "PM not found (missing) … run team up manually"**: the tmux session/window is gone (you closed
  the window, the machine rebooted) and by default it does not touch tmux. Fix it with `team up`; to have it handle
  this itself, set `TEAM_WATCH_REBUILD_TMUX=1`.
- **A stopped agent is not resumed automatically** (by design): the PM looks with `team resume --dry-run` and then
  resumes with `team resume`; a human can also do `team up --agents` to bring them along in one go.
- **The PM keeps crashing**: the automatic-restart quota (`TEAM_WATCH_MAX_RESTARTS`, default 5/hour) stops it and
  warns, so a crash loop cannot drag the machine down; look in `state/watchdog.log` and the PM window output for the
  cause first (common: model quota exhausted, a config typo, a missing dependency).
- **The watchdog window of the tmux backend was closed**: reopen it with `team watchdog up`; `team watchdog logs`
  shows a screen snapshot; when the lower half of the monitor says "no node/bun/tsx on this machine: skipping the agent
  activity stream" → install node or bun (the team status part is unaffected).
- **The watchdog itself stopped**: `team watchdog status` shows whether the window is still there; `team watchdog up`
  rebuilds it (there is only one backend, so there is no container to inspect).
- **Everything is silent after a machine reboot**: the tmux server and its windows are gone → `team up` restores both
  (PM window + watchdog window) in one shot; `team watchdog up` can start the watchdog alone as well.
- **`ExecStart`/script permissions**: this skill is always invoked as `bash <path>` and does not depend on the
  executable bit (but `scripts/team` is still +x, and `team smoke` checks it).

## 12. General Pi traps

- **A test conclusion must come from a real run of this round**: put the command and the tail of its output into the
  report, and the PM re-runs it.
- Type-only imports (`import type`) are mandatory in projects with `verbatimModuleSyntax` and the like — such project
  rules belong in `AGENTS.md`, otherwise weaker models trip over them again and again.
- Screen scraping is unreliable (TUI refreshes/line wraps), so never treat tmux scrollback as evidence; reports and
  logs are.
- A long task with no progress: have the agent drop a status line into the report every 30 minutes, or ask for
  progress with `team say`.
- Strong models are slow and quota-limited: run one at a time (`TEAM_MODEL_LIMITS`), and do not dispatch two at once.

## 13. team doctor fails on a required dependency

Both magic-context and OpenSpec are required dependencies (D10): `doctor` fails when one is missing, `dispatch`
warns one line without blocking the worker.

| Symptom (check label) | Fix |
|---|---|
| the PM memory check reports that magic-context is not detected | install the Pi package `@cortexkit/pi-magic-context`; if the settings file lives somewhere unusual, point `TEAM_PI_SETTINGS_FILE` at it; for an environment that genuinely cannot have it, set `TEAM_REQUIRE_MAGIC_CONTEXT=0` (doctor then warns instead of failing) |
| the OpenSpec CLI check cannot resolve the binary | install the OpenSpec CLI and put it on `PATH`, or set `TEAM_OPENSPEC_BIN` to its absolute path; `TEAM_REQUIRE_OPENSPEC=0` downgrades it to a warning |
| the OpenSpec spec-directory check reports a missing `openspec/` | run `openspec init --tools none` in the project (the spec root is `TEAM_SPEC_DIR`, relative to the main worktree) |
