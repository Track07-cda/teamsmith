# Bootstrapping teamsmith in a project

The shortest path for a new project (or a PM taking over a repository for the first time).
**The PM owns the setup, including configuring the watchdog.**

## In one line

```bash
bash <skill>/scripts/team bootstrap              # idempotent; detects the current tmux session/window
bash <skill>/scripts/team bootstrap --agents "dev verify api"   # custom roster
bash <skill>/scripts/team bootstrap --print      # print the plan, change nothing
```

Or hand the contents of `templates/bootstrap-prompt.md.tmpl` (placeholders substituted) to the PM of the new project:
"read this, then execute it".

## What bootstrap actually does

| Step | Result | Idempotence |
|---|---|---|
| Detect tmux | adopts the `session:window` the PM itself runs in and writes it into the config (no manual fill-in) | recomputed every run |
| Write config | `.pi/team/config.sh` (identity/roster/models/gates/install command/forge/guards/watchdog) | if it exists it is kept; only missing entries are filled in |
| Required dependencies | checks magic-context (Pi package `@cortexkit/pi-magic-context`) and OpenSpec (CLI resolvable + the spec dir); a missing one prints its exact fix/downgrade command, and does not block the setup | ✔ |
| Docs skeleton | `docs/team/{ROADMAP,BOARD,OWNERSHIP,DECISIONS,PROTOCOL}.md`, `tasks/`, `reports/`, `reviews/`, `threads/`, `inbox/` | skipped when present |
| Team protocol | injects the `<!-- teamsmith:begin --> … end -->` section into `AGENTS.md` (**refreshes** it instead of appending twice) | ✔ |
| `.gitignore` | `.pi/team/state/`, `docs/team/inbox/`, `docs/team/reviews/*.log`, `.worktrees/` | ✔ |
| Agent worktrees | one long-lived `.worktrees/<agent>` per roster member (branch `agent/<agent>`), installing dependencies when `TEAM_INSTALL_CMD` is set | skipped when present |
| Watchdog | `team watchdog up`: a `watchdog` window in the same session runs the monitor (patrolling every 15 minutes by default) | skipped when already running |
| Checklist | prints "what next" (ROADMAP/OWNERSHIP → first task → dispatch → digest) | — |

## What the PM does afterwards

```bash
openspec init --tools none      # required dependency: create the project's spec root (TEAM_SPEC_DIR)
team watchdog status            # watchdog window / patrol interval / pending work / PM liveness / capacity
team task T1.1 --title "…" --agent dev
team dispatch dev T1.1 docs/team/tasks/T1.1-*.md
team digest                     # pending work: notifications + reports awaiting verification + board
```

## The watchdog is a window, configured by the PM

- `team watchdog up|down|restart|status|logs` (**there is exactly one backend**: a `watchdog` window in the same session).
- **Default (tmux)**: start a `watchdog` window in the same session that runs `team monitor` —
  the top half is team status (PM/pending work/capacity/standby), the bottom half is each agent's Pi session activity
  (who is doing what, how long they have been idle, recent events), and it patrols on `TEAM_WATCH_INTERVAL` at the same
  time. `team watchdog logs` shows a snapshot of the screen.
- Why only one backend (since v1.12.0 there is no podman/container/systemd form): **fewer dependencies are more
  reliable** — one less runtime, one less layer of socket/permission/image problems, and only one place to look when
  something breaks. The watchdog does not need to survive the tmux server: if the server is gone the PM is gone too,
  and rebuilding brings `team up` / `team watchdog up` back together.
- What if the watchdog itself died: `team watchdog status` notices it is not there; `team watchdog up` rebuilds the
  window. Nothing restarts it automatically (that is the price of "managing less", paid for with zero extra runtime).
- Changing the patrol period: edit `TEAM_WATCH_INTERVAL` in `.pi/team/config.sh`, then `team watchdog restart`.
- Do not introduce a second backend (container/systemd): the little bit of extra survivability costs another runtime,
  permission model and socket, which is not worth it.

## Common problems

| Symptom | What to do |
|---|---|
| `container not created` | `team watchdog up` (on first use it builds the image, which needs network access to pull the alpine base image) |
| The window is there but nothing patrols | `team watchdog logs` to read the panel; `team watch --once` runs a single patrol tick to locate the problem |
| Want to shut it down completely | `team watchdog down` (followed by `team standby on` so the PM stops being woken) |
