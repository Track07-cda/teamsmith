# Agent adapters · run workers (and the PM) with any TUI agent

teamsmith's default CLI is **Pi**, but the workflow never depends on Pi: the PM owns *windows,
worktrees, task briefs, reports, gates and the inbox contract*, and "how do I start this agent CLI"
is pluggable — on the **worker side** (four keys) and on the **PM side** (three keys, §2). **All of them
empty by default, which keeps the Pi behaviour byte-for-byte identical.**

| Key | Meaning | Empty (default) |
|---|---|---|
| `TEAM_AGENT_CMD` | launch template for the agent CLI | built-in Pi command: `TEAM_PI_BIN --provider P --model M -e <notify ext> -e <bg ext> -e <inbox-watch ext> --skill <skill dir> --session-id <sid>` |
| `TEAM_AGENT_NOTIFY_CMD` | how a worker tells the PM its turn ended | the Pi notify extension (`extension/team-notify.ts` → `inbox/<agent>.md` + knock on the PM window) |
| `TEAM_AGENT_LOG_GLOB` | optional log/session files for `team monitor --activity` | Pi session discovery (`~/.pi/agent/sessions/**`) |
| `TEAM_AGENT_BIN` | binary used for the window-readiness wait and existence checks | first word of `TEAM_AGENT_CMD`, else `TEAM_PI_BIN` |

`team doctor` and `team paths` always print the resolved adapter: `built-in (Pi) → <path>` or
`custom: <cmd> → <path>`. `doctor` fails only when a **configured** adapter cannot be resolved; on
the built-in path a missing `pi` still fails exactly as before.

## 1. The contract

teamsmith owns (identical for every adapter):

- the tmux window (`<session>:<agent>`), `cd <worktree>`, a short wait until `TEAM_AGENT_BIN` is
  executable (the window shell's PATH is not ready at `new-window` time), the small banner, and
  `exec bash` once the CLI exits (so the window stays usable for `team say`);
- the prompt: teamsmith composes it, writes it to
  `$TEAM_MAIN_ROOT/.pi/team/state/prompt-<agent>-<ID>.md`, and passes the same text as the harness'
  `argv[0]` — this is why the window command line stays short no matter how big the prompt is;
- the task/report/board/thread/inbox contract and every `team …` subcommand the worker is told to call;
- liveness: "is this agent running" is answered from the pane's foreground process group, not from a
  Pi-specific hook, so it works for any CLI (see `references/troubleshooting.md`).

The adapter owns: how to start its CLI, how that CLI is told which model/prompt/session to use, and how
the worker notifies the PM at turn end. The **team background lane is teamsmith's own** (§3a): the built-in Pi
paths load it with `-e`, a custom Pi-shaped template opts in with `{bg_ext}`, and a CLI without a Pi extension API
simply does not have those two tools.

## 2. The PM side: `TEAM_PM_CMD`

The PM is an adapter too. Workers describe their CLI with `TEAM_AGENT_CMD`; the PM describes its own with
`TEAM_PM_CMD`, and an empty value means "the built-in Pi command", unchanged.

| Key | Meaning | Empty (default) |
|---|---|---|
| `TEAM_PM_CMD` | launch template for the PM | built-in Pi command: `TEAM_PI_BIN --provider P --model M -e <bg ext> -e <inbox-watch ext> --skill <skill dir> -c @<state>/pm-prompt.md` |
| `TEAM_PM_BIN` | binary used for the start-time existence check and for the liveness **identity** check | first word of `TEAM_PM_CMD`, else `TEAM_PI_BIN` |
| `TEAM_PM_RESUME_ARGS` | arguments that continue the PM's previous session | on the Pi path the historical `-c` / `--session-id <id>`; on a custom CLI: **nothing — the restart does not continue the history** |

<!-- pm-side:begin -->
PM placeholders — same engine, same rules as §3 (a blank or multi-line template, an unknown token and a
malformed one such as `{ cwd }` all fail loudly, and the error names `TEAM_PM_CMD`):

- `{cwd}` — the project's **main worktree** (the PM's working directory)
- `{session_id}` — `TEAM_PM_SESSION_ID`, empty by default (only meaningful if your CLI has its own session ids)
- `{model}` — the model-name part of `TEAM_PM_MODEL` (default `TEAM_DEFAULT_MODEL`)
- `{provider}` — the provider part
- `{prompt_file}` — path of `state/pm-prompt.md`, the PM briefing (`team up --print` prints the same text)
- `{prompt}` — `"$0"`: the briefing as a single argv token handed over by the window harness (keep the quotes)
- `{skill_dir}` — the teamsmith skill directory
- `{bg_ext}` — path of the team background-job extension (`extension/team-bg.ts`): the PM's lane for long gates
  (`team_bg_run` / `team_bg_wait`, see §3a). The built-in Pi command already passes it; a custom Pi-shaped PM
  template adds `-e {bg_ext}` to get the same tools.
- `{extra_args}` — `TEAM_PM_EXTRA_PI_ARGS`, the PM's own key, **not** the worker's `TEAM_EXTRA_PI_ARGS`
- `{resume_args}` — `TEAM_PM_RESUME_ARGS` (PM-only; a **worker** template that uses it still fails as unknown)
<!-- pm-side:end -->

The worker placeholders `{notify_ext}` and `{summary}` are not part of the PM set, and asserting them in a PM
template is rejected too. (The placeholder table in §3 is the worker list; this section is the PM list — the smoke
suite keeps both in sync with the engine.)

Launch contract, identical to the worker side: teamsmith writes the briefing to `state/pm-prompt.md`,
`cd`s to the main worktree, records the pid that is about to become the agent in `state/pm.pid.spawn` and
only then `exec`s the template. The briefing itself never lands on the command line: the window harness
passes it as `argv[0]`, which is what `{prompt}` reads — use `{prompt_file}` when your CLI can read a file.

Two details of that harness matter when you write a template or debug one:

- **The first word is resolved, not guessed.** The window command runs under `bash -lc`, whose `PATH` comes from
  `/etc/profile` and `~/.bash_profile` — typically *without* the directories your interactive shell adds
  (`~/.bun/bin`, version-manager shims). teamsmith therefore resolves the template's bare first word on the
  **caller's** `PATH` and renders the absolute path into the command, so `TEAM_PM_CMD='codex exec {prompt}'` works
  even where `bash -lc 'command -v codex'` fails. A first word that already contains `/`, quotes, `$` or `{` is
  left exactly as written (that is more than a bare executable name, so it is your command to own).
- **A failed start leaves evidence and does not take the window with it.** The CLI runs inside a subshell, so when
  it exits the window returns to a prompt instead of vanishing; the launcher then writes
  `state/pm-launch-failed.log` with the CLI's exit code, the rendered command, the resolved executable and the
  window's last non-blank output (the raw capture lives next to it as `state/pm-launch-tail.txt`). `team up` exits
  non-zero in that case — a failed start is never reported as success. The next `team up` or pulse tick treats
  the idle prompt as "no PM" and replaces it.

### What the PM does **not** get

- **No turn-end notification, and no auto-nudge event.** `TEAM_AGENT_NOTIFY_CMD` and the Pi notify extension
  are *worker* features: a worker tells the PM when its turn ended. For the PM that direction is inverted — the
  PM is the recipient. A non-Pi PM is started/restarted by `team up` and by the pulse's pending-work check
  (`watch --once`: unread inbox, reports to verify, blocked or stopped agents) and reads `team inbox` itself.
  The PM **does** get the team background lane (`team-bg.ts`), because that is not notification: it is the PM's
  own long-gate tool (§3a).
- **No guaranteed session continuity.** With `TEAM_PM_RESUME_ARGS` empty, a restart begins a *fresh* session,
  and the tool says so in plain words instead of implying a continuation. The handoff is the durable record —
  `docs/team/**` (BOARD, DECISIONS, threads, reports) plus `team inbox` — and the briefing itself tells the new
  PM to start with `team digest`. If your CLI supports continuing (`--continue`, `resume --last`,
  `--session <id>`, …), put those arguments in `TEAM_PM_RESUME_ARGS` **and** reference `{resume_args}` in
  `TEAM_PM_CMD`; `team up` then reports how the session is continued instead of warning. Putting arguments in
  the key without the placeholder is detected and reported as "the arguments are configured but not used".
- **No model/CLI compatibility guarantee.** `{model}` comes from teamsmith's registry; a CLI that does not know
  that model fails inside the CLI, exactly like a worker adapter would.

### Liveness identity and the wrapper caveat

`state/pm.pid` (the pid teamsmith spawned, or the pid the pane's foreground process had when it was recognised)
plus a cwd inside the project is the strongest evidence; the fallback is "the foreground process in the PM window
is `TEAM_PM_BIN`". Either way the check resolves **the PM's** executable (`TEAM_PM_BIN` > first word of
`TEAM_PM_CMD` > `TEAM_PI_BIN`) — it does not require the name `pi`, and a PM whose CLI is not Pi counts.

- **Wrapper scripts**: if `TEAM_PM_BIN` is a wrapper that `exec`s the real CLI, the process image changes name the
  moment it `exec`s, so argv-based recognition stops matching. The *spawn* proof (`proof=spawn`, the pid written to
  `state/pm.pid.spawn` before `exec`) keeps the PM "running" — this is the same mechanism that covers a wrapped
  `pi` (M6.3 F30).
- Do **not** wrap the PM with something that starts the CLI as a *child* (`sh -c 'codex …'` without `exec`, a
  supervisor, a shell function): the recorded pid is then the wrapper, and liveness is lost as soon as it exits.
  `exec` (or `TEAM_PM_BIN` pointing straight at the CLI) is what the contract expects.
- `team doctor`'s worker-adapter check proves the **worker** CLI; it says nothing about the PM CLI. The PM CLI is
  checked at start time (`team up`, the pulse): a missing or unresolvable executable fails before anything is
  respawned, naming `TEAM_PM_BIN` and the template's first word.

**Verified on this machine** (2026-09-16): `codex` as the PM CLI in a scratch project — `team up` started it,
the briefing was delivered (its first action was `team digest`), it drove `team board ls` / `team dispatch --print`
from that session, a killed window was restarted by `team up` (with the explicit "history is not continued"
notice), and `team watch --once` (with pending work) restarted it the same way. The evidence is in the M8.1
delivery report; the smoke suite repeats the same four scenarios against a fake non-Pi PM (`tests/smoke.sh`, §6i).

## 3. Launch: `TEAM_AGENT_CMD`

One shell command line, run in the worktree. Placeholders (values are `%q`-quoted by teamsmith):

| Placeholder | Expands to |
|---|---|
| `{cwd}` | the agent's worktree (absolute) |
| `{session_id}` | teamsmith's session id `<TEAM_SESSION>-<agent>` (`--fresh` appends a timestamp) |
| `{model}` | the **model-name** part of the agent's model (`provider/model` → `model`) |
| `{provider}` | the provider part |
| `{prompt_file}` | path of the prompt file — the most portable way to pass the prompt (`"$(cat {prompt_file})"`, or the CLI's own file/stdin flag) |
| `{prompt}` | `"$0"`: the prompt as passed by the harness — keep the quotes, the value is inserted verbatim |
| `{skill_dir}` | teamsmith skill directory (for `bash {skill_dir}/scripts/team …`) |
| `{notify_ext}` | path of the Pi notify extension (only useful for Pi-compatible CLIs) |
| `{bg_ext}` | path of the team background-job extension (`extension/team-bg.ts`, §3a; only useful for Pi-compatible CLIs) |
| `{extra_args}` | `TEAM_EXTRA_PI_ARGS`, inserted verbatim |

Rules:

- **Any brace-delimited token that is not exactly a supported placeholder aborts the dispatch** and prints the
  supported list plus the config key. That covers plain typos *and* near-misses that used to slip through
  silently: whitespace inside the braces, a trailing space, doubled braces, stray quotes. JSON bodies
  (`-d '{"a":1}'`), awk programs (`'{print $1}'`), shell variables (`${HOME}`) and brace expansion (`{a,b}`) are
  not placeholders and stay untouched. `team dispatch … --print` renders the command for inspection, and the
  smoke suite asserts a rendered command contains no leftover `{`.
- An adapter template must be **non-blank** and **single-line**: a whitespace-only `TEAM_AGENT_CMD` is rejected
  instead of silently rendering `cd <worktree> &&` (a window that never starts an agent), and a newline is rejected
  because the second line would be executed as its own command by the window shell.
- `{prompt}` and `{extra_args}` are inserted **verbatim** — you own the quoting for those. Everything else is quoted
  for you. Expansion is a **single left-to-right pass**, so a value that happens to contain `{cwd}` (e.g. inside
  `TEAM_EXTRA_PI_ARGS`) is never expanded a second time.
- The template's first word must be a **bare executable name** (no quotes): `TEAM_AGENT_BIN`, `team doctor` and the
  window-readiness wait resolve it with `command -v`, which cannot see `"my agent"`. If your CLI really has a space
  in its name, set `TEAM_AGENT_BIN` to its absolute path.
- `{model}`/`{provider}` come from teamsmith's model registry (`TEAM_DEFAULT_MODEL`,
  `TEAM_AGENT_MODELS`), not from the CLI. For a custom CLI either hardcode the model in the template or
  set `TEAM_AGENT_MODELS="dev=<provider>/<model>"` so `{model}` matches what the CLI really uses — that
  also keeps `TEAM_MODEL_LIMITS` (model concurrency) meaningful.
- The rendered command is executed by `bash -lc` in the window; the usual quoting rules of your shell
  apply, and nothing is `eval`-ed twice.
- **The first word is resolved, not guessed** (the same rule as the PM side, §2): the window shell is
  `bash -lc`, whose `PATH` typically lacks the directories your interactive shell adds, so a bare first word is
  resolved on the **caller's** `PATH` and the absolute path is rendered into the command. `TEAM_AGENT_CMD='codex …'`
  therefore works even where `bash -lc 'command -v codex'` fails. A first word that already contains `/`, quotes,
  `$` or `{` is left exactly as written, and when `TEAM_AGENT_BIN` explicitly names a **different** binary the
  template is not touched.
- **"The harness started" is not "the agent started".** The window harness records the agent's exit code
  (`state/dispatch-<agent>.exit`, same nonce as the spawn proof), and a worker CLI that exits non-zero within
  `TEAM_DISPATCH_ALIVE_SEC` (default 1s) makes the dispatch **fail**: it prints `exit=<code>` and writes
  `state/dispatch-<agent>-launch-failed.log` (rendered command, resolved binary, exit code, window tail). An
  adapter that exits 0 is reported as finished — normal for script-style CLIs — and one that keeps running as
  still running. The built-in Pi path keeps its old contract (a short-lived `TEAM_PI_BIN` is allowed), so an
  immediately exiting `pi` is still a success with a warning.

### 3a. The team's own background lane (built-in Pi: `{bg_ext}`)

A gate or a build that takes tens of minutes must not sit inside a turn. The team ships its own lane — no
third-party package, no extra window, nothing loaded into the user's own Pi sessions:

| Tool | What it does |
|---|---|
| `team_bg_run` | starts the command as a **detached** `bash -c` job, returns a job id + pid at once; combined stdout/stderr goes to `state/bg/<id>.log` — in **the session's own root** (see below) — (bounded: past `TEAM_BG_LOG_MAX_BYTES`, default 512 KB, the head is dropped and the tail is kept behind a truncation marker) |
| `team_bg_wait <id>` | waits for the job (or returns at once with `timeout_ms`), **harvests** it and returns exit code + log tail inline |

Both results name the **command** next to the job id (`  cmd: …`, single-lined and truncated past 100 code
points with `…`, cut on **code-point** boundaries so CJK characters and surrogate pairs never split), so a
session running several jobs can tell which is which; `details.cmd` carries the command verbatim (P33).

Both teamsmith launch paths load it: the built-in Pi worker command and the built-in Pi PM command pass
`-e <skill>/extension/team-bg.ts`. A custom template gets the same tools with `-e {bg_ext}`. A CLI that has no
Pi extension API simply does not have these tools — nothing else changes.

**Where those files live (M30): the session's own root.** The job logs and the ledger are session-local
artifacts, so `state/bg/<id>.log` and `state/bg.log` are resolved against **the session's own worktree**
(`git rev-parse --show-toplevel` of the session's cwd): a dispatched worker's long-gate logs stay inside
`<worktree>/.pi/team/state/`, the PM's stay in the main worktree. They never land in the shared ledger
location — that is where the *interface* state lives (the outbox and the inbox-watch registry/spool, which
senders and sessions must agree on). The old `--git-common-dir` resolution wrote a worktree session's logs
into the main worktree's state; the M30 incident is what that costs: gate stdout (it contains every smoke
fixture's name) then tripped the isolation assertion of the *next* gate in that project. An explicit
`TEAM_STATE_DIR` still wins over all of this.

The rules (from oh-my-pi issue #689, measured in the E8 probes):

1. **Harvest before the turn ends.** An unharvested job that finishes while the agent is idle wakes it **once**,
   with one merged `followUp` message for every job that finished in the same window. That costs a turn; a
   harvested job never wakes anyone (its result was already returned inline).
2. **Several jobs, one message.** Completion notices are merged, and never delivered while the agent is running
   tools (they wait for the next settle).
3. **The ledger is `state/bg.log`.** Every turn end appends one line —
   `<ISO timestamp> settled-with-unharvested=<n>[ jobs=<id>:<running|exit<code>>,…]`, and every delivery appends
   `<ISO timestamp> wake count=<n> ids=<id>,…`. So “this turn ended with unharvested jobs” is a fact on disk
   that the PM (or a verifier) can read after the fact.
4. **A session restart does not kill jobs.** The job table is session-scoped and cleared on `session_start` /
   `session_shutdown`; the processes are detached, the logs and the ledger stay in `state/`. After a restart the
   results are still readable, but the ids are gone and nobody will be woken — treat `state/bg.log` as the record.

What the lane is **not**: it does not watch the user's sessions, it does not subscribe to any package's event
bus, and it only knows the jobs it started itself. It is injected through the same `-e` channel as the notify
extension, which is exactly the boundary: user sessions do not get it.

## 4. Notify: `TEAM_AGENT_NOTIFY_CMD`

**A worker's summary text is data, never code.** The worker writes its one-line summary into a file and runs a
fixed command; nothing the worker types is ever interpolated into a shell line.

Placeholders: `{summary_file}`, `{summary}`, `{agent}`, `{cwd}`, `{session_id}`, `{model}`, `{provider}`, `{skill_dir}`.

- `{summary_file}` — the path teamsmith reserves for the summary (`<state>/summary-<agent>-<ID>.md`, `%q`-quoted).
  Use it with a CLI that reads a file: `… notify pm --from-file {summary_file}`.
- `{summary}` — **kept for compatibility, but never interpolated as text**: for a worker's command it expands to
  a quoted read of the same summary file (`"$(cat '…')"`, and inside `'{summary}'` the single-quote-safe form), so
  existing templates keep working without turning a worker's summary into shell code. Tooling that calls the
  helper with an explicit summary string (the old five-argument call) gets it back `%q`-quoted as a single word —
  still never evaluated.
- `{agent}` `{cwd}` `{session_id}` `{model}` `{provider}` `{skill_dir}` — the same values as in the launch
  template, `%q`-quoted.

The two supported ways to receive the summary:

```sh
# recommended: the CLI reads the file itself (no file read in the shell at all)
TEAM_AGENT_NOTIFY_CMD='bash {skill_dir}/scripts/team notify pm --from-file {summary_file}'
# also fine: teamsmith renders a quoted file read, the command shape stays yours
TEAM_AGENT_NOTIFY_CMD='bash {skill_dir}/scripts/team notify pm --from-file {summary_file}'
```

The rendered prompt section contains only teamsmith-owned paths plus that command, and instructs the worker:
write your one-line summary into the file, then run **exactly this command, with no substitutions, no extra
arguments and no quotes**.

`team notify <agent> --from-file <path>` normalises the file to a single line (CR removed, newlines → spaces,
 trailing blanks stripped) so the inbox keeps one entry per line, and preserves every other byte — quotes,
`$`, backticks and `{agent}`-looking text arrive verbatim. A missing or empty summary file is a real failure
(non-zero exit, nothing appended), so a hop-through-empty-file is never silently reported as “notified”.

Dispatch **warns but never blocks** when `TEAM_AGENT_NOTIFY_CMD` looks unusable (unknown placeholder, newline,
whitespace-only, unexecutable first word) — that is the M3.0 contract. When that happens the prompt section is
replaced by “the notify configuration is unusable; put your summary in the report instead”, so a worker never gets
a half command to copy. If your CLI is the built-in Pi (empty `TEAM_AGENT_CMD`), the section says so: Pi's notify
extension already reports the turn end, and the extra command is only run if the PM asked for it.

### What counts as “the same briefing” (built-in Pi extension)

`extension/team-notify.ts` suppresses an **identical** briefing inside `TEAM_NOTIFY_DEDUP_SEC` (default 20s; `0`
disables it). The dedup key covers the agent, the summary line, and the length plus a fingerprint of the **whole**
last assistant message — not the first 60 characters of it, so two different briefings that only share an opening
are both delivered. Content changes (branch, uncommitted, unpushed) are part of the summary, so a changed state
re-sends; only a byte-identical repeat inside the window is dropped.

## 4a. Delivery to a live session: inbox watch (Pi) vs pasting (everything else)

Automated messages (turn-end briefings, `team say`, drafts, pulse wake lines) reach a window in one of two
ways, and **the channel is chosen by the target, not by the sender**:

| Target | Channel |
|---|---|
| a Pi session that loaded `extension/team-inbox-watch.ts` (both built-in launch paths pass it with `-e`; a custom Pi-shaped template can add `-e {skill_dir}/extension/team-inbox-watch.ts`) | **inbox watch**: a durable inbox line plus one pointer line in `state/inbox-watch/<key>.wake`; the session's own extension calls `pi.sendMessage({customType:'team-inbox'}, {triggerTurn:true, deliverAs:'followUp'})`. **The input box is never read and never typed into.** |
| everything else — a custom adapter, a Pi session without the extension, a dead or foreign registration — and the explicit escape hatch (`--now`) | **paste path**: the delivery guard reads the box, defers while it holds a draft, types, verifies the submission in the conversation above the box, and retracts or leaves residue honestly (`references/troubleshooting.md` §3) |

Readiness is proven by the session itself: the extension writes `state/inbox-watch/<key>.reg`
(`target=<session>:<window>`, `inbox=<name>`, `pid`, `cwd`, `started`, `heartbeat`), and a sender routes to the
watch channel only when a registration matches that exact target, its pid is alive and its `cwd` is inside
this project — a fresh `heartbeat` is only the fallback when `cwd` is absent (bounded by
`TEAM_INBOX_WATCH_STALE`, default 300 s), because a heartbeat is not an identity. Deleting the registry on
`session_shutdown` is part of the contract: a stale file would make senders believe somebody is listening.
Messaging a session that was started without the extension (or whose registration is gone) simply stays on the
paste path.

What the session receives is a **pointer**: `[teamsmith] inbox wake: N new team message(s)`, one line per
message (`[kind] from <who> → <inbox>.md :: <truncated preview>`) and where to read the full text. Bursts merge
into one message, previews are truncated (`TEAM_INBOX_WATCH_PREVIEW`, default 160 chars), and the spool itself
is bounded (`TEAM_INBOX_WATCH_MAX_BYTES`, default 128 KiB: head dropped, tail kept). A session restart
re-baselines the spool, so lines written before it started never wake anybody — the pulse's pending check is
the fallback and its semantics are unchanged.

The durable-inbox contract lives in the outbox entry header (it decides who writes the line):

| Header | Meaning |
|---|---|
| `inbox: <name>` | the channel writes the line when it delivers (the paste path writes it only if the entry ends up held) |
| `inbox: <name>` + `inbox-written: 1` | the sender already wrote it (`--inbox-written`) — the channel must not write a second line |
| `inbox: -` + `inbox-written: 1` | no inbox line on purpose: the wake itself is the message and the sender's own log is the record (pulse wake lines) |

Knocks (`team notify`, the notify extension) are wakes, not messages: on a watcher-registered PM they take the
watch channel **without** tmux or PM-liveness heuristics — the registration (`pid` + `cwd`) is the liveness
evidence — and they never add an inbox line beyond the one their sender already wrote.

The session-side ledger is `state/inbox-watch.log` (`started` / `wake n=… kinds=…` / `stopped` lines); the
sender side records `watch` as the outcome in `state/outbox/delivered.log`.

### 4a.2 When the watch channel is absent: the skip record (M46)

An absent registration is only *evidence of absence*; the **reason** is written by the session that could not
register. On every skip path the extension writes `state/inbox-watch/<key>.skip` (same `KEY=VALUE` shape as
`.reg`: `target`, `session`, `window`, `expect`, `reason`, `detail`, `pid`, `cwd`, `ts`, `heartbeat`) and the
`skip setup: …` ledger line stays as it was. `reason` is a small closed vocabulary today —
`session-mismatch` (the session resolved from tmux, or from `TEAM_INBOX_WATCH_TARGET`, is not the project's
`TEAM_SESSION`; `expect` carries the configured name) and `no-tmux-target` (no `TMUX_PANE` and no override,
ledger only). A record is **believed only while it is live**: the writing pid must be alive and `cwd` inside
this project (cwd absent → `heartbeat` within `TEAM_INBOX_WATCH_STALE`), the same identity rule the registry
uses. A successful registration deletes the records for its target, so the trace cannot outlive the problem.

Consumers: `team doctor` prints one `投递通道 inbox-watch` line (`pass` when a live registration exists for the
PM target, a warning naming the reason otherwise), `team status` and `team digest` print the same warning as
`投递通道降级: …`, and the panel's `panel.pm.delivery_warning` carries the short reason for the status band.
The match for a `session-mismatch` record also accepts the **same window name** rather than the exact target,
because the expected target (`TEAM_SESSION` + `TEAM_PM_WINDOW`) is precisely what is wrong in that shape. The
state directory these records live in is anchored to the project derived from the process's cwd (the git main
worktree): an inherited `TEAM_STATE_DIR` that points at **another teamsmith project's** state is refused with
a `TEAM_IDENTITY_CONFLICT inherited TEAM_STATE_DIR=…` ledger line, so a session can never treat another
project's state as its home.

The paste-path fallback is not a dead end while the channel is missing. Every drain first runs a **read-only**
residue sweep over terminal holds (`draft-raced*`, `unconfirmed`): if the target's box is gone or no longer
holds the payload, `outbox/HOLDING.log` gains a `residue-clear entry=… why=box-clear|target-gone` line and the
status line stops reporting a residue that no longer exists. No keys are ever sent for a terminal entry (the
specification's "a draft-raced entry is never pasted again" also covers later drains). Held entries whose
target window no longer exists are marked `target=gone` by `team outbox list`, counted in the status queue
line, and cleaned only by the explicit `team outbox drop gone` (which names every file it drops).

### 4a.1 Delivery semantics: offset / rescan / caps (M43)

The watcher tracks the spool with an **in-memory byte offset** into `state/inbox-watch/<key>.wake`. The only
in-repo writer appends (`>>`), so a healthy offset never exceeds the file size. The offset is **not** the
delivery contract — these three rules are:

1. **A shrink is always external, and it is always recorded.** If the spool's size falls below the offset (or
   the file vanishes while being tracked), something outside the repo truncated/rewrote/replaced it (the
   2026-09-19 incident: an external actor rewrote the PM's spool in place twice within 6 s; the old code
   silently reset `offset = 0` and re-read the whole file — 42 lines were delivered twice and `total` was
   inflated by 84). Now the watcher writes a `spool shrink: size fell below offset=… → bounded rescan from 0`
   ledger line instead of a silent reset.
2. **No tuple is delivered twice.** Every delivered spool line — the whole `(epoch_ms, kind, from, durable,
   preview)` tuple — goes into a dedup memory (in memory + persisted to `state/inbox-watch/<key>.seen`,
   capped at `TEAM_INBOX_WATCH_SEEN_MAX`, default 512, so it survives session restarts). Lines that come back
   via a rewrite (or overlap after a shrink) are skipped and recorded as `dedup: skipped N …` ledger lines.
3. **Replays are bounded and explained.** A shrink triggers a *rescan*: the file is re-read from 0, but
   already-delivered lines are dropped and genuinely-new lines are capped to the **most recent**
   `TEAM_INBOX_WATCH_REPLAY_MAX` (default 20); anything older is skipped and the wake text says so
   (`(spool rescan after external shrink: delivered the last K unseen line(s); skipped D already-delivered +
   M older …)`). If everything was already delivered there is **no wake at all** — the ledger's
   `rescan lines=… dup=… skipped=… deliver=0` line is the audit trail.

Counter semantics: the ledger's `total=` (and the wake text's `N`) count **real deliveries only** — rescan /
dedup skips never inflate it, and a rescan wake carries a `rescan[dup=D skipped=M]` annotation. The other
caps are unchanged: previews truncate at `TEAM_INBOX_WATCH_PREVIEW` (160 chars), a wake lists at most 5 lines,
and the spool's own ceiling is `TEAM_INBOX_WATCH_MAX_BYTES` (128 KiB, head dropped tail kept, offset snapped
to the new size so the kept tail is not re-announced).

### 4a.1b What a *correct* offset means (P28) — the rule the 2026-09-19 loop violated

The shrink/replay rules above only hold if the offset is computed honestly. Three invariants, all of them
enforced in code and covered by the harness:

1. **The offset advances by the bytes actually read** (`readSync`'s return value), and each line is decoded
   **on its own**. The old code derived the offset as `Buffer.byteLength(decoded.slice(...))` — a
   decode→re-encode round trip. One invalid byte (written by the producer, see 2) became U+FFFD (3 bytes), so
   the offset advanced **past** the file size (`19635 > 19634`). That is what made the shrink rule fire on a
   healthy spool, and because the state never converged it re-fired every few seconds, re-delivering old lines.
   A read that starts mid-line must not deliver a fragment either.
2. **The producer cannot write half a character**: previews are cut with `head -c 700` and passed through
   `iconv -c` so an incomplete multibyte tail is dropped rather than written. (`cut -c1-700` under `LC_ALL=C`
   is byte-wise and was the original source of the invalid line.)
3. **A shrink needs evidence, and recovery must converge**: the watcher keeps the pair `(size, head
   fingerprint)` (FNV-1a over the first bytes). A size below the offset with an **unchanged head** is repaired
   by backing the offset off by one byte (a lost tail byte, not a rewrite); a **changed head** means an
   external rewrite → exactly one bounded rescan. The same `(size, head)` pair is never rescanned twice, so a
   non-converging case cannot turn into a wake loop.

**Only fresh lines wake.** A line older than `TEAM_INBOX_WATCH_STALE_SEC` (default `900`) is classified
`stale`: it is still written to the durable inbox file, but it does not wake a session
(`classify stale=<n> unparsable=<n> inbox=…`). A line whose timestamp cannot be parsed is delivered (never
silently dropped). The ledger separates traffic from recovery: `total=` counts **real deliveries only**, while
`rescan lines=… dup=… skipped=… deliver=0 stale=… unparsable=…` records recovery. **A repeated
`spool shrink` line with `deliver=0` is a defect signal, not noise** — it means the offset is not converging
(see `references/troubleshooting.md` §20).

## 5. Logs / activity: `TEAM_AGENT_LOG_GLOB`

`team monitor --activity` renders Pi session JSONL by default. With `TEAM_AGENT_LOG_GLOB` set, the
**tail of the newest matching file** is rendered as that agent's activity instead (`{agent}` in the
pattern → the agent name). Globbing is dependency-free: `*`, `?`, `**`, a leading `~`, and absolute or
project-relative paths; multiple matches are ordered by mtime.

Verified examples (this machine, 2026-09-14):

```sh
TEAM_AGENT_LOG_GLOB='~/.codex/sessions/**/*.jsonl'          # codex rollout files
TEAM_AGENT_LOG_GLOB='~/.local/share/opencode/log/*.log'     # opencode rolling log
```

Degradation is explicit: if nothing matches, or there are no Pi sessions and no glob, the block stays
`⚫ no session` and says why; the team status panel above it is untouched. `--json` tags every block with
`"source": "pi" | "log" | "none"`.

### Bounded reads and display safety (F2/F3, M3.3)

Activity streams are **untrusted input** (another process writes those files), so the monitor treats them
as data, not as text for your terminal:

- **Only the tail is read, never the whole file.** A log tail is at most
  `--log-tail-bytes` / `TEAM_AGENT_LOG_TAIL_BYTES` bytes — default **64 KiB (65536)**, hard cap **1 MiB
  (1048576)**; a larger value is clamped, a non-numeric/zero value falls back to the default with a
  warning on stderr. Files smaller than the window are read whole (byte-for-byte the old behaviour). A Pi
  session file is read as *head window (`64 KiB`, for the `session` header) + tail window* — the middle is
  skipped. Measured with a 256 MiB log: **~573 MB → 60 MB peak RSS**, and under
  `--max-old-space-size=64` it used to abort with exit 134 and now exits 0.
- `count` in the `log` block means "lines inside the read window" (for `pi` blocks: events inside the
  windows), and every block carries the bounds it used, so a truncated view is visible instead of
  implied. `--json` adds `tail_limit`, `tail_bytes`, `file_bytes`, `truncated`, `available`, `reason` and
  `sessionPath` (existing fields keep their meaning; nothing is removed).
- **Control sequences are stripped before rendering** — in the text panel, in live mode and in `--json`
  alike: `OSC` (`ESC ]`, e.g. window title, `OSC 52` clipboard writes), `CSI` (`ESC [`, clear/colour),
  C1 CSI, bare `ESC`, `BEL`, `BS`, `CR`, other C0/C1 controls (except `\n`/`\t`) and bidi control
  characters. Displayed text must not be able to touch the PM's terminal or lie about it.
- **Unreadable files degrade instead of crashing or silently blanking**: permissions (`EACCES`), FIFOs,
  devices/sockets, a file deleted between glob and read (`ENOENT`), a symlink pointing at a directory, or
  content with NUL bytes (binary) render as `log unreadable` / `session unreadable` + a human-readable `reason`, with
  `"available": false`. FIFOs and devices are never `open`ed for reading (the old whole-file read could
  block forever and freeze the pulse window). A glob that matches nothing, or one that matches a plain
  directory, still degrades to `⚫ no session` exactly as before.

How to change the window:

```sh
# one-off / shell only
TEAM_AGENT_LOG_TAIL_BYTES=262144 team monitor --activity
node scripts/monitor.mjs --root . --log-glob '…' --log-tail-bytes 262144   # direct call

# .pi/team/config.sh — note the export: `team monitor` forwards only TEAM_AGENT_LOG_GLOB explicitly,
# so a plain assignment stays a shell variable and never reaches monitor.mjs
export TEAM_AGENT_LOG_TAIL_BYTES=262144
```

The flag wins over the environment variable; the cap wins over both.

## 6. Worked example: codex

```sh
# .pi/team/config.sh
TEAM_AGENT_CMD='codex exec -C {cwd} -m {model} -s workspace-write "$(cat {prompt_file})"'
TEAM_AGENT_BIN="$HOME/.bun/bin/codex"
TEAM_AGENT_NOTIFY_CMD='bash {skill_dir}/scripts/team notify pm --from-file {summary_file}'
TEAM_AGENT_LOG_GLOB='~/.codex/sessions/**/*.jsonl'
TEAM_AGENT_MODELS="dev=openai/gpt-5.6-terra"   # {model} → gpt-5.6-terra (the model name codex itself knows)
```

Notes:

- `codex exec` is codex's non-interactive mode; `-s workspace-write` (or
  `--dangerously-bypass-approvals-and-sandbox` inside a disposable container) is what lets the worker
  write; `--json` / `-o <file>` give machine-readable output.
- **Verified on this machine** (2026-09-14, `codex-cli 0.146.1`, `~/.bun/bin/codex`): the dispatch
  window ran codex, which created and committed `greeting-codex.txt` and wrote its report; its notify
  call landed in `docs/team/inbox/pm.md`. (The first run notified the *prompt-file path* instead of a
  summary — that was a teamsmith bug in how the prompt rendered the notify example; since M3.2 the prompt
  never contains worker text at all, the summary goes through `--from-file`.)
- codex keeps its own sessions under `~/.codex/sessions/**`; teamsmith's `{session_id}` is *not* a codex
  session id. `team resume` means "dispatch the same task again in the same worktree/window"; resuming a
  codex conversation is a codex concern (`codex exec resume …`) and can be added to the template.
- codex is not on the PATH in this environment (`~/.bun/bin/codex`); pinning `TEAM_AGENT_BIN` to the
  absolute path is exactly what that key is for.

## 7. Worked example: opencode

```sh
TEAM_AGENT_CMD='opencode run --model {provider}/{model} --dir {cwd} "$(cat {prompt_file})"'
TEAM_AGENT_BIN="$HOME/.opencode/bin/opencode"
TEAM_AGENT_NOTIFY_CMD='bash {skill_dir}/scripts/team notify pm --from-file {summary_file}'
TEAM_AGENT_LOG_GLOB='~/.local/share/opencode/log/*.log'
TEAM_AGENT_MODELS="dev=google/gemini-3-flash-preview"
```

**Verified end-to-end on this machine** (no Pi involved): `team dispatch` started opencode in the agent
window, opencode read the task brief, created and committed the file, wrote
`docs/team/reports/T1.1-dev.md`, and ran the notify command — the PM inbox received the line. The M3.0
report keeps the window command, the agent's output tail, the produced report and the inbox line.

`opencode run` starts a fresh session per call; use `--continue` / `--session <id>` if you want it to
continue (opencode's session ids are its own — see the note under codex).

## 8. Verifying a new adapter (checklist)

1. `team doctor` → the `agent adapter` line resolves the binary; `team paths` shows `agent_adapter`.
2. `team dispatch <agent> <ID> <task> --print` → read the rendered command: no leftover `{`, and the
   `prompt file` path it prints exists.
3. Run that command by hand inside the worktree (auth, flags, cwd) before trusting tmux to do it.
4. Real dispatch, then check: the window shows the CLI; the worker's writes land in the worktree; the
   worker writes its summary file and the notify command lands in `docs/team/inbox/pm.md` (or the PM
   window) with the summary byte-exact (`TEAM_AGENT_NOTIFY_CMD` with `{summary_file}`).
5. `team monitor --once --activity` → the agent's block shows its Pi session or the configured log tail.
6. Only then rely on it — gates, reports and `team review` work the same for every adapter.

## 9. Intentionally unsupported

- **Emulating an agent's internal turn events.** teamsmith does not parse a vendor's private protocol to
  guess "the agent finished thinking". Turn-end notification is the adapter's job
  (`TEAM_AGENT_NOTIFY_CMD`), plus the PM side (`team say`, `inbox`, `roster`).
- **A notifying PM.** The PM's own CLI is configurable (`TEAM_PM_CMD`, §2), but the notification direction is not
  symmetric: teamsmith has no "the PM's CLI finished a turn" event. A non-Pi PM is woken by the pulse's
  pending-work check (or by a human running `team up`) and reads `team inbox`; it never pushes a turn-end event of
  its own. The built-in Pi PM receives notifications through the inbox-watch channel (§4a); a non-Pi PM (or a Pi
  PM started without the watcher) is still nudged by typing into its window when it is alive (`team notify pm`,
  the pulse nudge) — that path works for a non-Pi PM too, because it only checks that the pane is busy, not which
  CLI runs.
- **Interpolating worker text into a shell line.** A summary is data: it arrives through a file
  (`{summary_file}` / `team notify --from-file`). `{summary}` is rendered as a quoted file read for
  compatibility, but nothing a worker writes is ever re-interpreted by a shell — there is no supported way
  to make a summary part of a command's text.
- **Multiplexing per-agent streams out of one shared log.** `{agent}` is a filename placeholder, not a
  stream splitter; point the glob at per-agent files (or accept one shared tail).
- **Replacing the PM's own CLI by *guessing* it.** The PM side is adaptable (§2), but teamsmith will not infer a
  launch command for you: without `TEAM_PM_CMD` it uses the built-in Pi command, and a custom CLI needs an explicit
  template (otherwise the same `pi` command is attempted and fails inside `pi`).
- **CLIs that cannot accept a prompt non-interactively** (prompt only via a human TUI). Use
  `{prompt_file}` if the CLI can read a file or stdin; otherwise the agent cannot be dispatched by
  teamsmith.
- **New runtime dependencies.** Everything here is bash plus the CLI you install yourself.
