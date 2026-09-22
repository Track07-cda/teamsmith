# Configuration and on-disk layout

## 1. Config discovery order

The `team` CLI:

1. `--config <file>` / the environment variable `TEAM_CONFIG_FILE`
2. `.pi/team/config.sh` under `--root <dir>` / `TEAM_ROOT`
3. Walk up from the current directory looking for `.pi/team/config.sh`

**Identity comes from the directory, not from the environment.** The project root is the git worktree the command
runs in (`--root <dir>` when given: that directory's worktree), the main worktree is its git common dir, and the
project name/session come from *that* project's config. Inherited `TEAM_ROOT` / `TEAM_MAIN_ROOT` / `TEAM_PROJECT` /
`TEAM_SESSION` values are never allowed to win silently: when they name **another project**, commands that change
shared state or start long-lived processes refuse to run, and read-only forms (`paths`, `--print`, `--dry-run`,
`status`, …) resolve by the directory and print the mismatch (`TEAM_ALLOW_FOREIGN_IDENTITY=1` runs anyway and
records that in `state/watchdog.log`). Sibling worktrees of the **same** project (an agent worktree with the PM's
`TEAM_ROOT` in the environment) are not a mismatch. Windows the CLI starts (PM, pulse, worker, draft) are stamped
with the *destination* directory's identity, so a long-lived process always belongs to the directory it was started
in — see [troubleshooting.md](troubleshooting.md) §18.

The notify extension (inside the agent process, **it never sources the config and never runs project code**):
walks up the same way and only parses the few flat `KEY=VALUE` entries it needs; when it finds none it falls back to
the git main worktree. `$VAR` / `${VAR}` inside values are expanded from `process.env`.

## 2. Config keys (`.pi/team/config.sh`)

> Keys are added over time and always ship with a default, so an older config file keeps working. What changed
> between versions, and what a project set up earlier has to do about it: [migration.md](migration.md).

The config file is sourced by bash, so `$HOME` and conditional logic are allowed; but the notify extension can only
read **flat single-line assignments**, so the keys it cares about (session/pm-window/worktrees/docs/notify) should stay
literals or simple `$VAR`.

### Identity / roster

| Key | Default | Purpose |
|---|---|---|
| `TEAM_PROJECT` | the main worktree's directory name | display name |
| `TEAM_SESSION` | `$TEAM_PROJECT` | tmux session (shared by the PM and every agent) |
| `TEAM_PM_WINDOW` | `pm` | the window the PM session lives in; notifications are typed there |
| `TEAM_AGENTS` | empty (`init` sets `dev verify`) | roster, space separated |
| `TEAM_AGENT_MODELS` | empty | per-agent model override: `dev=deepseek/deepseek-flash verify=xai/grok-4.6` |
| `TEAM_DEFAULT_MODEL` | `deepseek/deepseek-flash` | default model (`provider/model`) |

Dispatch model resolution order: `--model` > `TEAM_AGENT_MODELS` (per-agent) > `TEAM_DEFAULT_MODEL`. The roster's recorded `model` is display-only ("what ran last time"); `team roster` and `team ps` tag it with its source label (current config / explicit `--model` / stale record whose config changed since — the CLI prints these labels in Chinese). It never feeds resolution, so editing the config takes effect on the very next dispatch. |
| `TEAM_MODEL_LIMITS` | `kimi-coding/k3=2` | concurrency limits, `provider/model=N` space separated; `0` = unlimited |
| `TEAM_EXTRA_PI_ARGS` | empty | extra arguments passed to pi (space separated, values with spaces are unsupported) |

### Workflow

| Key | Default | Purpose |
|---|---|---|
| `TEAM_GATES` | auto-detected by `init` | verification gate command (e.g. `pnpm verify`) |
| `TEAM_PI_BIN` | `pi` | pi executable (give an absolute path when it is not on PATH; often used in self-tests) |
| `TEAM_INSTALL_CMD` | empty | install command run after creating a worktree (e.g. `pnpm install --frozen-lockfile`) |
| `TEAM_DOCS_DIR` | `docs/team` | directory for briefs/reports/reviews/threads/inbox |
| `TEAM_WORKTREES_DIR` | `.worktrees` | long-lived worktree directory (also how "this is an agent session" is recognised) |
| `TEAM_PROTECTED_BRANCH` | `main` | the branch only the PM may advance |
| `TEAM_REMOTE` | `origin` | remote name (present even in local mode, used when pushing branches) |
| `TEAM_PI_AGENT_DIR` | the directory of `TEAM_PI_SETTINGS_FILE` | where Pi keeps `sessions/` and its model catalog — the only place the session-size guard and the model windows are read from (read-only: `stat` of the session file, the catalog files) |
| `TEAM_MODEL_WINDOWS` | empty | explicit context windows, `provider/model=272000` space separated (also accepts a bare model name); wins over Pi's catalog and covers providers Pi does not know |
| `TEAM_SESSION_WARN_TOKENS` | `200000` | conservative threshold used when the selected model's window cannot be resolved (the message says so instead of guessing) |
| `TEAM_DISPATCH_VERIFY_SEC` | `8` | how long a dispatch waits for the pane's launch proof before it kills the window and retries |
| `TEAM_DISPATCH_ALIVE_SEC` | `1` | after the launch proof, how long to observe whether the agent is still in the window (built-in Pi only; `0` = skip the observation). A subsequent exit is reported as a warning, never as a failed dispatch |
| `TEAM_SQUASH_LOOKBACK` | `200` | how many commits on the protected branch are scanned when deciding "this branch was already squash-merged" (one tree comparison per agent row; a heuristic, see workflows.md) |

### agent adapter (the internal seam (frozen); leave all four empty for the built-in Pi behaviour)

The four keys are an **internal seam (frozen)**: the built-in Pi paths are rendered by the same engine, the seam
is reserved for a possible future non-Pi adapter, and teamsmith makes **no compatibility promise** about it — it is
not a public extension point, and the new-project questionnaire never asks about it. The keys stay writable and
validated so the seam can be maintained; the contract, the placeholder semantics and the worked codex/opencode
examples (seam documentation, not a support offer) are in [agent-adapters.md](agent-adapters.md).

| Key | Default | Purpose |
|---|---|---|
| `TEAM_AGENT_CMD` | empty | launch template for the agent CLI; empty = the built-in Pi command. Placeholders: `{cwd}` `{session_id}` `{model}` `{provider}` `{prompt_file}` `{prompt}` `{skill_dir}` `{notify_ext}` `{extra_args}`; an unknown **or malformed** placeholder (`{ cwd }`/`{{cwd}}`…) makes `dispatch` fail with the supported list; a whitespace-only or multi-line template is refused as well (the first word must be a bare executable name) |
| `TEAM_AGENT_NOTIFY_CMD` | empty | template for the worker's end-of-turn notification to the PM (`{summary_file}` `{summary}` `{agent}` `{cwd}` `{session_id}` `{model}` `{provider}` `{skill_dir}`); empty = the Pi notify extension. **The summary is data**: the worker writes it into `{summary_file}` and then runs the rendered fixed command unchanged (recommended: `… notify pm --from-file {summary_file}`); `{summary}` is kept for compatibility only and renders as "a read of that file", never as interpolated text. An unusable template only warns, and the prompt section is replaced by "put it in the report" |
| `TEAM_AGENT_LOG_GLOB` | empty | activity source for `team monitor --activity`: the **tail** of the newest matching file (`*` `?` `**`, a leading `~`, `{agent}` = agent name); empty = Pi session files; when nothing matches it degrades to "no session" and says why |
| `TEAM_AGENT_LOG_TAIL_BYTES` | empty (=64KiB) | how many bytes of the log tail to read at most (a positive integer, hard cap 1MiB; above the cap it is clamped, a bad value falls back to the default and warns on stderr). **Note**: `team monitor` only forwards `TEAM_AGENT_LOG_GLOB` explicitly to monitor.mjs, so to use this key you must write `export TEAM_AGENT_LOG_TAIL_BYTES=…` in `.pi/team/config.sh` (or export it in the shell / pass `--log-tail-bytes` to monitor.mjs) — a plain assignment never reaches the child process |
| `TEAM_AGENT_BIN` | empty | executable used for the window PATH readiness wait / existence checks / `doctor`; empty = the first word of `TEAM_AGENT_CMD`, otherwise `TEAM_PI_BIN` |

> The internal seam (frozen) in full — the contract (what teamsmith owns vs. what the adapter owns), the placeholder
> semantics, the worked codex and opencode examples, a verification checklist and the intentionally unsupported list:
> see [agent-adapters.md](agent-adapters.md).

### forge

| Key | Default | Purpose |
|---|---|---|
| `TEAM_VCS` | auto-detected | `local` / `github` / `gitlab` |
| `TEAM_TOKEN_FILE` | `.gh-pat` | github: PAT file (at the main worktree root, chmod 600, gitignored) |
| `TEAM_GITLAB_HOST` | empty | gitlab: `https://gitlab.example.com[:port]` |
| `TEAM_GITLAB_PROJECT` | empty | gitlab: `group/sub/project` (the script URL-encodes it) |
| `TEAM_GITLAB_TOKEN_FILE` | `$HOME/.gitlab-pa-token` | gitlab: PAT file |
| `TEAM_CONFIRM_WRITES` | `1` | `1` = write operations require `--yes` (**keep it**) |

| Guard | Default | Purpose |
|---|---|---|
| the pulse only "counts pending work + wakes the PM" (it only wakes when there is work); starting, stopping and resuming agents is the PM's job (`team resume`) |
| `TEAM_REQUIRE_MAGIC_CONTEXT` | `1` | `1` = magic-context (PM memory) is a hard dependency: `team doctor` fails without it, `dispatch` warns (never blocks). `0` downgrades it to a warning |
| `TEAM_PI_SETTINGS_FILE` | `~/.pi/agent/settings.json` | where Pi extensions (magic-context) are detected, and where the package is resolved from (`<settings dir>/npm/node_modules/…`); overridable for tests/multi-user setups |
| `TEAM_REQUIRE_OPENSPEC` | `1` | `1` = OpenSpec (the spec layer) is a hard dependency: `doctor` fails when the CLI or the spec dir is missing, `dispatch` warns. `0` downgrades it to a warning |
| `TEAM_OPENSPEC_BIN` | `openspec` | the OpenSpec CLI to resolve (an absolute path is allowed, same pattern as `TEAM_PI_BIN`) |
| `TEAM_SPEC_DIR` | `openspec` | the project's OpenSpec root; a relative path is resolved against the main worktree |
The patrol keys were renamed `TEAM_WATCH_*` → `TEAM_PULSE_*` in v1.36.0. During the alias period (until v2.0.0)
the effective value of each is `TEAM_PULSE_<NAME>` > `TEAM_WATCH_<NAME>` > the default, and `team pulse status` /
`team doctor` name every legacy variable still in effect.

| `TEAM_PULSE_INTERVAL` | `900` | patrol period (seconds): 15 minutes by default, 300~3600 recommended. This is the beat of "look for work on a timer", not a heartbeat |
| `TEAM_PULSE_NUDGE_GAP` | `900` | the shortest interval before the same batch of pending work is reminded again (seconds) |
| `TEAM_PULSE_REBUILD_TMUX` | `0` | `0` = leave tmux alone (a missing session/window is only reported); `1` = allow rebuilding the session/PM window (self-recovery after a reboot) |
| `TEAM_PULSE_MAX_RESTARTS` | `5` | maximum automatic PM starts per hour (guards against a crash loop). Counted from `state/pm-restarts.log` (real restarts) **and** `state/pm-start-attempts.log` (every attempt), so a start loop that never confirms is bounded too |
| `TEAM_PULSE_WINDOW` | `pulse` | window name for the tmux backend. Alias period: a still-running legacy `watchdog` window is recognized as the backend; `team pulse restart` swaps it for the resolved name |
| `TEAM_MONITOR_REFRESH` | `3` | the console's data-refresh cadence (seconds): each cadence rebuilds the cached blocks once — it is a redraw period, not a polling loop, and the effective value is visible as `panel.refresh_s` in `--json`. **The default changed from `5` to `3` with the console (pulse-console B3)** — the 3-second cadence plus the <1%-of-one-core red line is the performance contract. `--print`/`--json` never tick |
| `TEAM_MONITOR_ACTIVITY` | `1` | `1` = the activity column is part of the layout (only windows running in this session, read as a bounded tail); `0` = the pre-v1.38.0 layout without it. **The default changed from `0` to `1` in v1.38.0** — this is the one default the panel rewrite moved. `--activity` / `--no-activity` still override the key in both directions |
| `TEAM_MONITOR_EVENTS` | `4` | how many recent session events the activity column starts with per agent |
| `TEAM_MONITOR_UI` | `auto` | which renderer to use: `auto` = the TUI when stdout is a terminal and plain text otherwise; `tui` forces the TUI renderer even when stdout is redirected; `text` forces the plain-text frame (no escape sequences, no screen clear) |
| `TEAM_JS_BIN` | empty | absolute path to the JavaScript runtime the panel bundle runs on; empty = `node` > `bun` > `tsx` on `PATH`. The runtime is resolved in one place and reported by `team paths` (`js_runner`) |
| `TEAM_REQUIRE_JS` | `1` | `1` = a JS runtime is a hard dependency like magic-context and OpenSpec: `team doctor` fails when none of `node`/`bun`/`tsx` resolves or the version is below the panel bundle's floor (`node` 20 or `bun` 1.3). `0` downgrades that **doctor row only** to a warning — the panel itself still needs a runtime, and `team monitor` fails loudly in every mode without one |

`team monitor` itself has four output modes and two geometry overrides:

```
team monitor                         # TUI in a terminal; plain text when stdout is not a TTY
team monitor --once                  # one frame through the same renderer selection, plus the due tick
team monitor --print                 # exactly one plain-text frame: 0 escape bytes, no state writes, no tick
team monitor --json                  # one JSON object {"panel": …, "activity": …}: same guarantees as --print
team monitor --width N --height N    # override the geometry (the layout/degradation contract is checkable headlessly)
```

`--print` and `--json` are the observers: they never tick and never write into `TEAM_STATE_DIR`. `--once` and the
long-running TUI keep today's tick semantics (one patrol tick per `TEAM_PULSE_INTERVAL`; `--no-pulse`, alias
`--no-watchdog`, keeps the panel and stops the ticks). A missing runtime is a loud failure in every mode, never an
empty panel reported as success.

| `TEAM_PM_MODEL` | empty | the PM's own model; empty = `TEAM_DEFAULT_MODEL` |
| `TEAM_PM_SESSION_ID` | empty | empty = `pi -c` (continue the previous session in this directory, keeping the PM's history). Explicit session id for a CLI whose session concept you control (`{session_id}` in `TEAM_PM_CMD`); on the built-in Pi path it still becomes `--session-id <id>` |
| `TEAM_PM_EXTRA_PI_ARGS` | empty | extra pi arguments for the PM (`{extra_args}` in a `TEAM_PM_CMD` template) |
| `TEAM_PM_CMD` | empty | **launch template for the PM's own CLI** (the PM side of the adapter, M8.1). Placeholders: `{cwd}` `{session_id}` `{model}` `{provider}` `{prompt_file}` `{prompt}` `{skill_dir}` `{extra_args}` `{resume_args}`. Empty = the built-in Pi command, byte-for-byte the pre-M8.1 behaviour; the rules (unknown/malformed placeholder, blank or multi-line template) are shared with `TEAM_AGENT_CMD` and fail loudly. See [agent-adapters.md](agent-adapters.md) §2. A start that fails leaves a diagnosis (window output, the rendered command, the CLI's exit code) in `state/pm-launch-failed.log`, and `team up` exits non-zero |
| `TEAM_PM_BIN` | empty | executable used for the PM's start-time existence check and its liveness identity check; empty = the first word of `TEAM_PM_CMD`, else `TEAM_PI_BIN`. The name does not have to be `pi` (a wrapper that `exec`s the real CLI is covered by the spawn proof). A **bare** first word is resolved on the *caller's* `PATH` and the rendered command uses the absolute path it resolved to — the window runs under `bash -lc`, whose `PATH` does not have your interactive rc-file additions |
| `TEAM_PM_RESUME_ARGS` | empty | arguments that continue the PM's previous session when `team up`/the pulse restarts it (`{resume_args}`). Built-in Pi path: empty = the historical `-c`; a value replaces it. Custom CLI: empty = **no continuity** (the restart starts fresh, and `team up` says so and points at `docs/team/**` + `team inbox`); a value is only used if the template contains `{resume_args}` |
| `TEAM_PM_START_WAIT` | `6` | seconds to wait for the PM to come up after starting it — the pid is recorded in `state/pm.pid` only once the configured agent binary is really running in that window. The start-in-flight marker `state/pm.pid.starting` stays fresh for this value **+ 5s**, and while it is fresh no tick starts a second PM over the one that is coming up |
| `TEAM_REPLACE_FOREIGN_PM` | `0` | `1` = allow `team up` to overwrite a process in the PM window whose cwd is **outside** this project (a non-PM process with an in-project cwd is always replaceable — it is reported as `unknown:<cmd>`) |

### Guards (capacity)

| Key | Default | Purpose |
|---|---|---|
| `TEAM_MIN_FREE_SWAP_MB` | `1024` | **floor**: below this much free swap the dispatch is refused (a full swap gets processes killed by the OOM killer) |
| `TEAM_MIN_TOTAL_MB` | `512` | the absolute RAM+swap floor |
| `TEAM_WARN_AVAIL_MB` | `2048` | below this much available RAM: warn only (slowness is acceptable), never refuse |
| `TEAM_AGENT_MEM_MB` | `6144` | empirical footprint of one agent, used by `team ps` for its "how many more fit" estimate |
| `TEAM_NOTIFY_TMUX` | `1` | `0` = write the inbox only, never type into the PM window |
| `TEAM_NOTIFY_DEDUP_SEC` | `20` | deduplication window (seconds); `0` = no deduplication |
| `TEAM_INBOX_MAX_CHARS` | `150` | truncation length of the agent's last message inside a briefing |
| `TEAM_NOTIFY_LOG` | `/tmp/<project>-teamsmith-notify.log` | extension debug log (look here when notifications misbehave) |
| `TEAM_DEFER_TTL` | `300` | delivery guard: seconds a queued message may wait before it is moved to `state/outbox/held/` (holding never types anything; the payload is already in the recipient's inbox) |
| `TEAM_OUTBOX_MAX` | `200` | delivery guard: maximum active queue entries; beyond it the oldest entry is escalated to `held/` |

### Deferred delivery (`delivery-guard`)

Automatic senders never type into an input box that already holds a draft: the message is queued in
`state/outbox/` (one immutable file per message) and delivered when the box is free. The escape hatches are explicit:
`team say <agent> "…" --now` and `team outbox flush --now` type immediately **even into a non-empty box** and append
one audit line to `state/outbox/forced.log`; `team outbox drop <n|all>` discards entries; `team draft pm`
(`state/draft-pm.md`) is the human entry point. See `references/troubleshooting.md` §3 for the detector's known edges.

### Branch model (D1)

| Key | Default | Purpose |
|---|---|---|
| `TEAM_VCS` | `local` | `local`\|`github`\|`gitlab`\|`other` (`other` = the project's own forge, see the next two lines) |

> The branch-model keys below are only a **naming convention** (the skill never creates or switches branches;
> `dispatch` merely uses them to print hints).

| `TEAM_BRANCH_MODE` | `task` | `task` = one branch per task (`task/<ID>-<slug>`; the unit of verification/merge/rollback is the task) ｜ `agent` = one long-lived branch per agent |
| `TEAM_TASK_BRANCH_PREFIX` | `task` | task branch prefix |
| `TEAM_TASK_BRANCH_RESET` | `1` | `close` prints the exact `git -C <worktree> switch --detach <protected>` command for a worktree still sitting on that task's branch (the CLI never runs git); `0` = say nothing about the reset |
| `TEAM_AGENT_BRANCH_PREFIX` | `agent` | prefix used in `agent` mode |

## 3. On-disk layout inside a project

```
<project root>/
├── .pi/team/
│   ├── config.sh          # configuration (committed, shared by the team)
│   └── state/             # runtime state (gitignored): <agent>.env (the durable record),
│                          #   pm.pid (pid of the PM this tool started: the liveness proof),
│                          #   notify-dedup, prompt-<agent>-<ID>.md (the prompt of this dispatch;
│                          #   {prompt_file} points at it), patrol (watchdog.*)/capacity logs,
│                          #   draft.md (the console's compose draft),
│                          #   panel.conf (the console's preferences) and
│                          #   panel-page (the page it last showed)
├── AGENTS.md              # carries the <!-- teamsmith:begin --> protocol section (written/refreshed by init)
├── .worktrees/
│   ├── <agent>/           # each agent's long-lived worktree (branch agent/<name>)
│   └── review-<ID>/       # detached worktree for PM verification (safe to delete at any time)
└── <docs>/                # docs/team by default
    ├── PROTOCOL.md        # protocol summary (for humans and agents)
    ├── BOARD.md           # task board (the status column is maintained by team board / task / merge / close)
    ├── ROADMAP.md         # milestones and exit criteria
    ├── OWNERSHIP.md       # directory ownership + roster
    ├── DECISIONS.md       # decision log (reasons/impact)
    ├── tasks/<ID>-<slug>.md
    ├── reports/<ID>-<agent>.md
    ├── reviews/<ID>.md  + <ID>-verify.log     # verification records (the log is gitignored)
    ├── reviews/<ID>-done.md                   # append-only audit of every `done` transition
    │                                          #   (which evidence was checked / why it was forced)
    ├── threads/<agent>.md                     # append-only message thread
    └── inbox/<agent>.md                       # automatic briefings (gitignored)
```

`.gitignore` entries appended by `init`:

```
.pi/team/state/
<docs>/inbox/
<docs>/reviews/*.log
.worktrees/
```

### What is durable in `state/` and what is derived (read-only commands never mutate the record)

`state/<agent>.env` is the **durable record** of an agent: `task`, `taskfile`, `branch`, `worktree`, `model`,
`window`, `started`, `inbox_lines`. Only the commands that really change the team write it (`dispatch`, `resume`,
`add-agent`, `close`, `teardown`, `inbox --ack`).

Liveness is **not** stored for agents: whether an agent is running — and therefore which model-concurrency slot it
holds — is derived from tmux (`has-window`) at query time. A crashed window therefore frees its slot while the record
stays, and the read-only commands (`roster`, `status`, `ps`, `digest`, `inbox`, `paths`, `pulse status`) write
nothing at all. This is a tested invariant (smoke: state hash before/after), not a convention: an earlier version
had the model counter call `team_state_clear` for dead windows, so a single `team ps` deleted a crashed agent's
`task`/`branch` — after which `digest` reported "nothing to do" and `team resume` had nothing to resume.

The PM is the one exception, and only because a guess about it was proven to lie (M6.5): the start path
(`team up` / the pulse) records the pid of the agent process it launched in `state/pm.pid`, and liveness means
"that pid is alive **and** its cwd is inside this project". The file is written by the start path only
(`team_pm_start`); the read-only commands read it and never remove a stale entry (a dead pid simply fails the
check). Without it, a freshly created, still-empty pane was reported as `running:tmux`.

`state/draft.md` is the console's compose draft (pulse-console B2): written only by the panel process while a
human types in the input line, restored by the next `m`, and cleared once a send lands (delivered, queued or
held). A missing file means an empty draft — the next compose starts blank. `--print`/`--json` never read it,
and no command other than `team monitor`'s TUI writes it.

`state/panel.conf` and `state/panel-page` are the console's runtime preferences (pulse-console B3). The
overlay (`,`) edits exactly five: `lang` (`zh`/`en`), `page` (the default page, 1–4), `activity` (the activity
column for TUI sessions), `mouse` and `density` (`comfortable`/`compact`); a sixth key, `theme`
(`dark`/`light`/`auto`), pins the palette and is not an overlay item. The file is read **by the TUI only**:
`--print`/`--json` never look at it, so the machine exits stay byte-stable under any preference. A missing,
unreadable or corrupt file falls back to the defaults (zh, page 1, activity and mouse on, comfortable,
auto), and unknown keys are ignored. `panel-page` is one number in `1`–`4` — the page the human last showed,
restored on the next start (the `page` preference is the fallback when it is absent, and a value outside
`1`–`4` falls back to it too, never an error). Neither file is the project
contract — `.pi/team/config.sh` keeps that role, and nothing moves between the two.

### The console's data blocks (`team __panel-data`)

The console reads every screen from one internal, read-only command: `team __panel-data --block <name>`
(one child process per block, each with its own timeout; a failed block renders as `—` and never takes the
others down). The block names are a closed set — `frame`, `pm`, `pending`, `outbox`, `capacity`, `agents`,
`recent`, `activity`, `board`, `changes`, `specs`, `decisions`, `outbox_list`, `inbox`, `patrol`, `health`
and `detail` — and `--events <n>` sizes the activity tail. `--print`/`--json` assemble the machine blocks only
(the console-only readers, including `detail` and `settings`, are never spawned there).

`--block detail --id <ID> [--file <path>]` is the read-only markdown detail view's reader (P18/B3). It
discovers, by entry id with the literal boundary `-`/`.` after the id (`P1` never matches `P17`):
`docs/team/tasks/<ID>-*.md` (tab `brief`), `docs/team/reports/<ID>-*.md` — files only, a report package
directory does not match — (tab `report:<agent>`) and `docs/team/reviews/<ID>.md` plus
`docs/team/reviews/<ID>-*.md` (tabs `review` / `review:<suffix>`), and returns that list plus the text of the
first file. `--file` serves one of those discovered paths only: anything else (a path outside the set, a
`..` traversal, another entry's file) exits non-zero and prints no content, so the console is never an
arbitrary file reader. Text is capped at 128 KiB (`TEAM_PANEL_DETAIL_CAP` overrides the cap) with a
`truncated` marker per file, and the block is requested only while the detail view is open: a parked
console spawns no `detail` child at all.

`--block settings` is the project-settings view's reader (P22/B2): its payload is exactly `team config list
--json` (the contract's schema, its effect classes, each key's functional `group`, the per-seat models and the
audit tail). Like `detail` it is
requested only while the view is open — a parked console spawns no `settings` child and `--print`/`--json` never
see it.

## 4. Environment variables (usable without writing them into the config)

| Variable | Purpose |
|---|---|
| `TEAM_ROOT` | explicitly name the project root (locates the project; the **identity** itself still comes from the runtime directory — an inherited value naming another project is reported and refused, §1) |
| `TEAM_ALLOW_FOREIGN_IDENTITY` | `1` = run anyway when the inherited identity names another project; the run is recorded in `state/watchdog.log` |
| `TEAM_CONFIG_FILE` | explicitly name the config file (same as `team --config`) |
| `TEAM_MIN_AVAIL_MB` | `1024` | **hard line**: the `MemAvailable` floor (the CEP machine sets 4096, the lesson of two OOMs) |
| `TEAM_MIN_FREE_SWAP_MB` | `1024` | **hard line**: the free **disk swap** floor (**zram excluded**) |
| `TEAM_ZRAM_WARN_PCT` | `85` | above this zram usage, warn only |
| `TEAM_MERGE_PREFER_THEIRS` | empty | paths that default to the branch side on a `merge` conflict (comma separated, e.g. `pnpm-lock.yaml`) |
| `TEAM_REVIEW_TIMEOUT` | `1800` | hard timeout for the gates `team review` runs (seconds); a verdict of `TIMEOUT` needs **both** the `timeout` wrapper's exit code (124/137) **and** an elapsed time within `TEAM_REVIEW_TIMEOUT_GRACE` of the deadline — a gate that exits 124 by itself, or one killed by a signal, is recorded as `FAIL` (with the signal named), never as a timeout; log text never decides |
| `TEAM_REVIEW_TIMEOUT_GRACE` | `2` | slack (seconds) around `TEAM_REVIEW_TIMEOUT` when deciding whether the wrapper really hit the deadline |
| `TEAM_REVIEW_ALLOW_DIRTY` | `0` | `1` = review a checkout with uncommitted changes anyway (the only override that works); the verification record then states `checkout dirty: N files (override …)` + the file list |
| `TEAM_REVIEW_ALLOW_IGNORED` | `0` | `1` = review a checkout that contains `.gitignore`d artefacts (invisible to `git status --porcelain`, yet readable by the gates); the record lists them |
| `TEAM_REVIEW_ALLOW_UNRESOLVED_BRANCH` | `0` | `1` = stamp a review for a `--branch`/revision that does not resolve in the main worktree (deleted branch, external commit); the record says `branch-unresolved (override)` |
| `TEAM_REVIEW_ANY_DIR` | `0` | `1` = skip the “checkout HEAD == branch tip” guard when deliberately reviewing a historical revision (pair it with `--branch <sha>`) |
| `TEAM_MIN_FREE_SWAP_MB` | temporarily override the disk swap floor |
| `TEAM_MEMINFO_FILE` | point at another meminfo file (for containers/tests without `/proc/meminfo`) |
| `TEAM_MODEL_LIMITS` | temporarily loosen/tighten concurrency (`""` means unlimited) |
| `TEAM_ASSUME_YES` | `1` = skip `--yes` (only recommended inside automation scripts) |
| `TEAM_BOARD_DONE_FORCE` | `1` = PM override for the `done` gate: write `done` even though neither a usable review record nor a merged branch exists (`close --status done` has the `--force` flag for the same thing) |
| `TEAM_BOARD_DONE_REASON` | the reason recorded in `<docs>/reviews/<ID>-done.md` when `TEAM_BOARD_DONE_FORCE=1`; required, otherwise the override is refused |
| `NO_COLOR` | turn colours off |

## 5. `team config` — the contract's read/write surface

`team config` is the only command that writes `.pi/team/config.sh` (`team init` / `team bootstrap` write through
the same bottom-level function). It exists so a setting can change without hand-editing the file and without a
second source of truth: the value lives in the contract, the class table lives in the command
(`scripts/lib/cmd-config.sh`), the console's labels live in its string tables.

### Effect classes (who reads the value, and when)

| class | meaning | examples |
|---|---|---|
| `apply` | the next process that reads the contract sees the new value | `TEAM_GATES`, the capacity floors, the review escape hatches, the patrol policy |
| `restart` | a running process holds the value it started with; the receipt names the target and the command | the pulse (`TEAM_PULSE_INTERVAL`, `TEAM_MONITOR_REFRESH`), a seat's model (`TEAM_AGENT_MODELS`, `TEAM_PM_MODEL` — a running seat keeps its model until its next `dispatch`/`resume`), a live session (`TEAM_INBOX_WATCH_*`) |
| `refuse` | not the console's to change: the project's identity, the roster, the ledger's layout, the branch/forge definitions, the authority guards, the dependency policy and the machine paths Pi's own state is read from — the console may not widen its own authority and may not move the ledger it is reading | `TEAM_PROJECT`, `TEAM_AGENTS` (route: `team add-agent` / `team teardown`), `TEAM_STATE_DIR`, `TEAM_PROTECTED_BRANCH`, `TEAM_ALLOW_FOREIGN_IDENTITY` … |

A key the schema does not know is listed read-only ("not a known project setting", pointing at this file) and is
never written.

### The schema's tenth column (`group`) — the functional domain

Every schema row carries a **tenth** `|`-separated field, the key's functional domain: a closed ASCII token
matching `^[a-z][a-z0-9-]*$`. It is the row's own data (like `class`, `kind`, `default` and `suggest`) — **not**
parsed from the `# ---- … ----` section comments, which stay documentation: a comment must never be able to move
a row between headings. The fields are positional, so the ninth column (`suggest`) is written empty for a row
that has no suggestions when the group follows; a row whose tenth field is missing or malformed is a schema
defect, and `tests/config-cli.sh`'s `groups` section names the key and fails — the read never invents a default
group or hides the row (the console shows such a row under its visible ungrouped fallback heading,
`settingsGroupUngrouped` in the string tables).

The vocabulary is exactly these twelve tokens; the visible heading is the table entry `group_<token>` in
**both** languages (the zh and en tables are the only place a heading's words live):

| token | domain | example keys |
|---|---|---|
| `identity` | identity and ledger layout | `TEAM_PROJECT`, `TEAM_DOCS_DIR` |
| `branch` | branch semantics and forge | `TEAM_BRANCH_MODE`, `TEAM_GITLAB_HOST` |
| `policy` | permission and dependency policy | `TEAM_ALLOW_FOREIGN_IDENTITY`, `TEAM_REQUIRE_JS` |
| `roster` | roster, model resolution and adapters | `TEAM_AGENT_CMD`, `TEAM_AGENT_BIN`, `TEAM_MODEL_LIMITS` |
| `seat-model` | per-seat models | `TEAM_DEFAULT_MODEL`, `TEAM_AGENT_MODELS`, `TEAM_PM_MODEL` |
| `workflow` | workflow and gates | `TEAM_GATES`, `TEAM_REVIEW_TIMEOUT` |
| `delivery` | capacity and delivery notices | `TEAM_MIN_AVAIL_MB`, `TEAM_DEFER_TTL` |
| `panel` | pulse and console | `TEAM_PULSE_INTERVAL`, `TEAM_MONITOR_REFRESH` |
| `patrol` | patrol policy | `TEAM_PULSE_NUDGE_GAP`, `TEAM_PULSE_MAX_RESTARTS` |
| `pm-lifecycle` | PM lifecycle | `TEAM_PM_CMD`, `TEAM_PM_RESUME_ARGS` |
| `session` | live sessions | the `TEAM_INBOX_WATCH_*` family |
| `meeting` | cross-project meetings | `TEAM_MEETING_TTL_HOURS`, `TEAM_MEETING_KNOCK` |

The token is the **only** declaration of the vocabulary: `team config list --json` reports each key record's
`group` verbatim (empty string for a key the file carries and the schema does not know), the console looks its
heading up by the token (`group_<token>`, falling back to the raw token when the table has none), and
`tests/panel-strings.mjs` asserts the two sets equal **in both directions** — a token no row uses has no label
(stale label) and a row's token without a label is a missing label. A key added to the schema therefore lands
under its domain with the committed console bundle, and no group list exists anywhere else.

### The written form

* `KEY='value'` — a sourced value is data: no expansion, no command substitution, no globbing. Values a child
  process reads from the **environment** are written `export KEY='value'` (`form=export`: `TEAM_MONITOR_ACTIVITY`,
  `TEAM_AGENT_LOG_TAIL_BYTES`, the `TEAM_INBOX_WATCH_*` family, `TEAM_BG_LOG_MAX_BYTES`); a plain assignment
  never reaches a running process (the measured `TEAM_MONITOR_ACTIVITY` case).
* A `'` inside the value is written `'\''`. A line break or a `#` is refused (the notify extension's flat reader
  cuts at ` #`). On the eight keys that reader parses — `TEAM_SESSION`, `TEAM_PM_WINDOW`, `TEAM_WORKTREES_DIR`,
  `TEAM_DOCS_DIR`, `TEAM_NOTIFY_TMUX`, `TEAM_NOTIFY_DEDUP_SEC`, `TEAM_INBOX_MAX_CHARS`, `TEAM_NOTIFY_LOG` — a `'`
  is refused too (that reader has no escape).
* Every byte the write does not change survives: comments, blank lines, the order of the keys and the changed
  line's own inline comment. A key the file lacks is appended on a line of its own (a missing final newline is
  added first). The write is atomic: a temp file in the contract's directory → `bash -n` → a mode-preserving
  `mv`; any failure leaves the original bytes and removes the temp file.

### The danger list

A **valid** value that disables a shipped guard or makes a shipped loop spin needs the explicit
`--allow-danger`: the capacity floors at `0` (`TEAM_MIN_FREE_SWAP_MB`, `TEAM_MIN_TOTAL_MB`, `TEAM_MIN_AVAIL_MB`,
`TEAM_WARN_AVAIL_MB`), `TEAM_PULSE_INTERVAL` below 60, `TEAM_REVIEW_TIMEOUT` below 60,
`TEAM_PULSE_MAX_RESTARTS=0`, `TEAM_DEFER_TTL=0`, `TEAM_OUTBOX_MAX=0`, `TEAM_SQUASH_LOOKBACK=0`, the
`TEAM_REVIEW_ALLOW_*` / `TEAM_REVIEW_ANY_DIR` overrides at `1`, `TEAM_BOARD_DONE_FORCE=1`, a non-empty
`TEAM_MEETING_ALLOW_USER_ID`, and a `TEAM_PULSE_WINDOW` change while a pulse backend still runs under the old
name. Danger never makes an invalid value legal.

### The commands and their exit codes

<!-- config-examples · tests/config-cli.sh executes exactly these lines -->
```sh
team config list --json
team config set TEAM_PULSE_NUDGE_GAP 1200 --dry-run
team config set-agent-model dev deepseek/deepseek-flash --dry-run
team config log 5
```

`0` written/valid · `3` fingerprint conflict (nothing written) · `4` invalid value · `5` key not editable ·
`6` write error (file unchanged) · `7` dangerous (a `--dry-run` reports it too). `team config set … --fingerprint
<sha256>` is a compare-and-swap: any byte change since the read refuses it, and a write without the flag is the
caller's explicit "use the file as it is now". `team config set-agent-model <seat> <model|->` writes the pair
list (`TEAM_AGENT_MODELS`, or `TEAM_PM_MODEL` for the `pm` seat) itself — the caller never composes it — and `-`
removes the seat's override, leaving `TEAM_DEFAULT_MODEL` in force. `--actor <name>` labels the audit line (the
console passes `panel`); `--dry-run` performs every check and writes neither the contract nor an audit line.
Every attempt that passes argument parsing appends one line to `<state>/config.log`
(`<UTC ISO-8601> result=<ok|refused|invalid|conflict|danger-refused|write-error> actor=… key=… old='…' new='…'`,
plus `expected=`/`actual=` on a conflict); `team config log [N]` and `list --json`'s audit tail read at most the
file's last 16 KiB and print at most N lines (default 10).

### Keys the class table above does not describe

| Key | Class | Default | Meaning |
|---|---|---|---|
| `TEAM_MEETINGS_DIR` | refuse | `~/.pi/team/meetings` | the cross-project meeting store (the ledger's layout) |
| `TEAM_MEETING_TTL_HOURS` | apply | `72` | meeting TTL (hours) |
| `TEAM_MEETING_MAX_TURNS` | apply | `20` | turns per side |
| `TEAM_MEETING_KNOCK` | apply | `0` | 1 = allow knocking on the other PM's window |
| `TEAM_MEETING_ALLOW_USER_ID` | apply | empty | non-empty = who may knock (widens permission, hence the danger flag) |
| `TEAM_ALLOW_FOREIGN_SESSION` | refuse | `0` | run anyway on a foreign tmux session (with `--yes`) |
| `TEAM_GUARD_FOREIGN_TARGET` | refuse | `1` | only type into windows of this session |
| `TEAM_ALLOW_DESTRUCTIVE_TMUX` | refuse | `0` | **retired (M67)**: it grants nothing — the gate decides by the object a call targets, and the only in-band escape is the argv token `--teamsmith-allow-destructive`. The key stays as a non-writable tombstone so old configs keep loading; `team doctor` names the residue when a running server still carries it |
| `TEAM_SMOKE_FAST` | refuse | `0` | skip the real-process smoke sections |
| `TEAM_PULSE_PENDING_BOARD` | apply | `0` | 1 = board todo/wip count as a wake-up signal |
| `TEAM_INBOX_WATCH_MAX_BYTES` | restart · export | `131072` | spool cap (bytes) |
| `TEAM_INBOX_WATCH_PREVIEW` | restart · export | `160` | wake-up message preview length |
| `TEAM_INBOX_WATCH_REPLAY_MAX` | restart · export | `20` | lines replayed after a shrink |
| `TEAM_INBOX_WATCH_SEEN_MAX` | restart · export | `512` | dedup memory |
| `TEAM_INBOX_WATCH_STALE` | restart · export | `300` | heartbeat staleness bound (seconds) |
| `TEAM_INBOX_WATCH_STALE_SEC` | restart · export | `900` | **spool line age** above which a line never wakes (it still lands in the durable inbox) — P28 |
| `TEAM_INBOX_WATCH_FORCE_FAIL` | refuse | empty | force the registration failure path (e.g. `ENOSPC`) and mark the record `forced=1` — never set it outside tests (M53) |
| `TEAM_IW_REQUIRE_WATCH` | refuse | empty | `1` = the inbox-watch gate treats an unavailable watcher premise as a **red** instead of a visible SKIP (strict mode) — M53 |
| `TEAM_INBOX_WATCH_POLL_MS` | restart · export | `5000` | `fs.watch` fallback poll (ms) |
| `TEAM_INBOX_WATCH_HEARTBEAT_MS` | restart · export | `5000` | registry heartbeat (ms) |
| `TEAM_INBOX_WATCH_TARGET` | restart · export | empty | explicit knock target |
| `TEAM_BG_LOG_MAX_BYTES` | restart · export | `524288` | background job log cap (bytes) |
