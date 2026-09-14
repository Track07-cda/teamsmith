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
8. **The turn never ended**: a notification means exactly one thing — *this agent's turn ended and it is waiting for
   the PM*. A settle triggered by an internal lifecycle event (compaction, session restart, reload) while the agent
   is still working on the same task is **not** emitted at all (it is only written to `TEAM_NOTIFY_LOG`), and a run
   that was interrupted (Esc, provider error) is emitted with an explicit `interrupted` tag and **never** carries the
   unfinished turn's text as its summary. So a line without a summary is deliberate: there was no completed turn to
   quote, and the old behaviour (reporting the turn's opening line as if it were a conclusion) is what made a busy
   agent look stopped.

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
| the session does not fit the model window | the resume guard: session size (JSONL bytes ÷ 4) exceeds the selected model's window, or the conservative `TEAM_SESSION_WARN_TOKENS` when the window cannot be resolved | `--fresh` for a new session, or `--allow-overflow` if you really mean to reuse it (it warns loudly) |
| the launch could not be confirmed | the pane never wrote the per-attempt launch proof, so tmux/the pane swallowed the command | see 4b below |

### 4a. An agent loops on `Context full` / connection errors right after a resume

Symptom: the dispatch succeeds, the pane immediately prints `Context full — /ctx-flush or /clear to continue.` and
then a stream of `Connection error.` with `↑0 ↓0` tokens, while `team roster` still reports the agent as running —
the process is alive, it just cannot do anything.

Cause: the session was resumed with a model whose context window is smaller than the history it carries. Observed
live: ~361k tokens of history (a 1.6 MB session JSONL) resumed with a 272k-window model.

What the tool does now: dispatch estimates the session size (JSONL bytes ÷ 4 — crude on purpose) and refuses when it
exceeds the window it resolved for the selected model, naming both ways out. `team roster`/`team ps` show the same
numbers next to the model, so the mismatch is visible before dispatching.

What to do:

- usual case: `team dispatch <agent> <ID> <brief> --fresh` (new session; the old history stays in its own file);
- you really want the history (e.g. you also moved to a bigger-window model): add `--allow-overflow`;
- already wedged: kill the window (`tmux kill-window -t <session>:<agent>`) and dispatch again with `--fresh`; the
  pane is the truth, `roster`'s "running" only proves the process exists.

### 4b. `team dispatch` says the launch could not be confirmed

A dispatch no longer reports success just because tmux accepted the command. The pane harness writes a per-attempt
nonce immediately before it execs the agent, and only that proof counts. Without it the tool kills the window,
retries once, and — if the retry also fails — reports the failure, kills the window again and says what to check.
The window is left in a known state: it does not exist (`roster` shows "no window").

Observed shape (live incident): a dispatch into a wedged pane printed "window exists → replacing" and reported
success, but the command only landed in the stuck process's input buffer — the new session id never appeared and
nothing ever ran.

What to do:

- reproduce it by hand: `team dispatch … --print` prints the exact command; run it in the pane and read the output;
- usual causes: the binary, provider or model is unavailable, the old session is wedged (`--fresh`), the machine is
  out of memory or disk;
- with a custom `TEAM_PI_BIN`: make sure it is an absolute path and executable from the pane;
- if the launch proof arrives but the agent has **already exited** (the dispatch prints a warning and `roster` shows
  "pi exited"), that is the honest `pi exited` state: `team resume --agent <a>` continues the task.

### 4c. `digest` says a report is "not committed yet"

The report exists only in the agent's working tree, and the reviewer reads the report from a checkout of the task
branch — so the signal would arrive before it is actionable. The tool therefore lists it as "report not committed
(spelling out that review is not the next step)" instead of pointing at `team review <ID>`; nothing is dropped. Ask
the agent to commit it, and the normal "awaiting review" line plus the review command come back.

## 5. git worktree errors

- `fatal: '<branch>' is already checked out`: that branch lives in another worktree. Find it with `git worktree list`,
  or use a detached checkout for verification (which is what `team review` does).
- A stale worktree lock: `git worktree prune`.
- Cannot remove it (dirty): run `git -C <wt> status` first, and only use `team teardown --purge --force` once you are
  sure nothing is worth keeping.

## 6. Merging and deciding "is it merged?"

- After `git merge --squash` the task branch is **not** an ancestor of the protected branch, so `git branch --merged`
  cannot tell you anything. Trust the `BOARD.md` status plus the `reviews/<ID>.md` record, not ancestry. `roster` and
  `digest` go one step further for the **usual** squash case: when the branch tip's tree equals the tree of one of the
  last `TEAM_SQUASH_LOOKBACK` commits on the protected branch, they report "already merged (squash, same content)"
  and stop suggesting a push. It is a heuristic — an older squash, or one that also changed something else, shows up
  as `ahead N` again (the safe direction: the signal comes back, it is never suppressed silently).
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

- **How "the PM is running" is decided**: only a **proof** counts (M6.5). The PM is running when either
  ① this tool started it and `state/pm.pid` still points at a live process whose cwd is inside the project, or
  ② the process in the PM window is the configured agent binary (resolved the same way `dispatch` resolves it:
  `TEAM_AGENT_BIN` > first word of `TEAM_AGENT_CMD` > `TEAM_PI_BIN`) and its cwd is in the project.
  Everything else is reported as `foreign:<cmd>` (the occupant's cwd is not this project: `team up` refuses to
  overwrite it unless `TEAM_REPLACE_FOREIGN_PM=1`) or `unknown:<cmd>` (cwd is inside the project but it is not the
  agent: a just-created pane, a `sleep`, an editor). `unknown` is **not** a PM, so it never suppresses starting one —
  `team up` replaces it and says so. `watchdog-status`, `ps`, `digest` and the monitor panel use the same proof, so
  no surface prints "the PM is running" without it.
  Why this is strict: the old rule ("the window exists and its foreground process is not a shell") reported a
  *just-created* pane — where `pane_current_command` is still `tmux` — as `running:tmux`. `team up` then printed
  "PM is running" without starting anything, `watchdog-status` repeated it, and the project's own smoke suite went
  from green to 7 failures after the machine restarted. Status is a promise: a liveness signal that is inferred
  instead of proven hides the exact failure the tool exists to surface.
- **A shell wrapper still counts as the PM**: `team_pm_state` looks at the pane's own process *and* its direct
  children and matches any word of the command line against the agent binary, so `bash /path/to/pi …`
  (or a Pi started through a login shell) is recognised as the agent. A child that is *not* the agent does not make
  the window a PM.
- **team up respawns the PM window's pane**: only when no PM is running there — an empty prompt (`idle`) or a
  non-PM process whose cwd is inside the project (`unknown`). Do not treat the PM window as a normal terminal; to
  start working manually, re-run the agent in that window or simply let the watchdog bring it up.
  Note: the agent is the pane's own process (we `exec` it), so when it exits the pane closes and the window
  disappears — exactly the `missing` case the watchdog reports (corresponding to the `TEAM_WATCH_REBUILD_TMUX`
  switch). After a successful start the pid is written to `state/pm.pid`, which is what makes a later
  "is it still alive?" question a fact rather than a guess (the read-only commands only read it).
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
