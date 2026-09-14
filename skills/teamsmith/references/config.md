# Configuration and on-disk layout

## 1. Config discovery order

The `team` CLI:

1. `--config <file>` / the environment variable `TEAM_CONFIG_FILE`
2. `.pi/team/config.sh` under `--root <dir>` / `TEAM_ROOT`
3. Walk up from the current directory looking for `.pi/team/config.sh`

The notify extension (inside the agent process, **it never sources the config and never runs project code**):
walks up the same way and only parses the few flat `KEY=VALUE` entries it needs; when it finds none it falls back to
the git main worktree. `$VAR` / `${VAR}` inside values are expanded from `process.env`.

## 2. Config keys (`.pi/team/config.sh`)

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

### agent adapter (workers may be any TUI agent; leave all four empty for the built-in Pi behaviour)

| Key | Default | Purpose |
|---|---|---|
| `TEAM_AGENT_CMD` | empty | launch template for the agent CLI; empty = the built-in Pi command. Placeholders: `{cwd}` `{session_id}` `{model}` `{provider}` `{prompt_file}` `{prompt}` `{skill_dir}` `{notify_ext}` `{extra_args}`; an unknown **or malformed** placeholder (`{ cwd }`/`{{cwd}}`…) makes `dispatch` fail with the supported list; a whitespace-only or multi-line template is refused as well (the first word must be a bare executable name) |
| `TEAM_AGENT_NOTIFY_CMD` | empty | template for the worker's end-of-turn notification to the PM (`{summary_file}` `{summary}` `{agent}` `{cwd}` `{session_id}` `{model}` `{provider}` `{skill_dir}`); empty = the Pi notify extension. **The summary is data**: the worker writes it into `{summary_file}` and then runs the rendered fixed command unchanged (recommended: `… notify pm --from-file {summary_file}`); `{summary}` is kept for compatibility only and renders as "a read of that file", never as interpolated text. An unusable template only warns, and the prompt section is replaced by "put it in the report" |
| `TEAM_AGENT_LOG_GLOB` | empty | activity source for `team monitor --activity`: the **tail** of the newest matching file (`*` `?` `**`, a leading `~`, `{agent}` = agent name); empty = Pi session files; when nothing matches it degrades to "no session" and says why |
| `TEAM_AGENT_LOG_TAIL_BYTES` | empty (=64KiB) | how many bytes of the log tail to read at most (a positive integer, hard cap 1MiB; above the cap it is clamped, a bad value falls back to the default and warns on stderr). **Note**: `team monitor` only forwards `TEAM_AGENT_LOG_GLOB` explicitly to monitor.mjs, so to use this key you must write `export TEAM_AGENT_LOG_TAIL_BYTES=…` in `.pi/team/config.sh` (or export it in the shell / pass `--log-tail-bytes` to monitor.mjs) — a plain assignment never reaches the child process |
| `TEAM_AGENT_BIN` | empty | executable used for the window PATH readiness wait / existence checks / `doctor`; empty = the first word of `TEAM_AGENT_CMD`, otherwise `TEAM_PI_BIN` |

> The contract (what teamsmith owns vs. what the adapter owns), the placeholder semantics, the worked codex and
> opencode examples, a verification checklist and the intentionally unsupported list:
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
| the watchdog only "counts pending work + wakes the PM" (it only wakes when there is work); starting, stopping and resuming agents is the PM's job (`team resume`) |
| `TEAM_REQUIRE_MAGIC_CONTEXT` | `1` | `1` = magic-context (PM memory) is a hard dependency: `team doctor` fails without it, `dispatch` warns (never blocks). `0` downgrades it to a warning |
| `TEAM_PI_SETTINGS_FILE` | `~/.pi/agent/settings.json` | where Pi extensions (magic-context) are detected, and where the package is resolved from (`<settings dir>/npm/node_modules/…`); overridable for tests/multi-user setups |
| `TEAM_REQUIRE_OPENSPEC` | `1` | `1` = OpenSpec (the spec layer) is a hard dependency: `doctor` fails when the CLI or the spec dir is missing, `dispatch` warns. `0` downgrades it to a warning |
| `TEAM_OPENSPEC_BIN` | `openspec` | the OpenSpec CLI to resolve (an absolute path is allowed, same pattern as `TEAM_PI_BIN`) |
| `TEAM_SPEC_DIR` | `openspec` | the project's OpenSpec root; a relative path is resolved against the main worktree |
| `TEAM_WATCH_INTERVAL` | `900` | patrol period (seconds): 15 minutes by default, 300~3600 recommended. This is the beat of "look for work on a timer", not a heartbeat |
| `TEAM_WATCH_NUDGE_GAP` | `900` | the shortest interval before the same batch of pending work is reminded again (seconds) |
| `TEAM_WATCH_REBUILD_TMUX` | `0` | `0` = leave tmux alone (a missing session/window is only reported); `1` = allow rebuilding the session/PM window (self-recovery after a reboot) |
| `TEAM_WATCH_MAX_RESTARTS` | `5` | maximum automatic PM restarts per hour (guards against a crash loop) |
| `TEAM_WATCH_WINDOW` | `watchdog` | window name for the tmux backend |
| `TEAM_MONITOR_REFRESH` | `5` | monitor refresh interval (seconds) |
| `TEAM_MONITOR_ACTIVITY` | `0` | `1` = append each agent's session activity stream below the panel (only windows running in this session); off by default |
| `TEAM_MONITOR_EVENTS` | `4` | how many recent session events are shown per agent |

| `TEAM_PM_MODEL` | empty | the PM's own model; empty = `TEAM_DEFAULT_MODEL` |
| `TEAM_PM_SESSION_ID` | empty | empty = `pi -c` (continue the previous session in this directory, keeping the PM's history) |
| `TEAM_PM_EXTRA_PI_ARGS` | empty | extra pi arguments for the PM |
| `TEAM_PM_START_WAIT` | `6` | seconds to wait for the PM to come up after starting it — the pid is recorded in `state/pm.pid` only once the configured agent binary is really running in that window |
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
│                          #   {prompt_file} points at it), watchdog/capacity logs
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
stays, and the read-only commands (`roster`, `status`, `ps`, `digest`, `inbox`, `paths`, `watchdog-status`) write
nothing at all. This is a tested invariant (smoke: state hash before/after), not a convention: an earlier version
had the model counter call `team_state_clear` for dead windows, so a single `team ps` deleted a crashed agent's
`task`/`branch` — after which `digest` reported "nothing to do" and `team resume` had nothing to resume.

The PM is the one exception, and only because a guess about it was proven to lie (M6.5): the start path
(`team up` / the watchdog) records the pid of the agent process it launched in `state/pm.pid`, and liveness means
"that pid is alive **and** its cwd is inside this project". The file is written by the start path only
(`team_pm_start`); the read-only commands read it and never remove a stale entry (a dead pid simply fails the
check). Without it, a freshly created, still-empty pane was reported as `running:tmux`.

## 4. Environment variables (usable without writing them into the config)

| Variable | Purpose |
|---|---|
| `TEAM_ROOT` | explicitly name the project root |
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
