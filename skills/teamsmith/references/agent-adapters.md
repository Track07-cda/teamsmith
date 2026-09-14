# Agent adapters · run workers with any TUI agent

teamsmith's default worker is **Pi**, but the workflow never depends on Pi: the PM owns *windows,
worktrees, task briefs, reports, gates and the inbox contract*, and "how do I start this agent CLI"
is pluggable. Four config keys make that explicit — **all of them empty by default, which keeps the
Pi behaviour byte-for-byte identical**.

| Key | Meaning | Empty (default) |
|---|---|---|
| `TEAM_AGENT_CMD` | launch template for the agent CLI | built-in Pi command: `TEAM_PI_BIN --provider P --model M -e <notify ext> --skill <skill dir> --session-id <sid>` |
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
the worker notifies the PM at turn end.

## 2. Launch: `TEAM_AGENT_CMD`

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

## 3. Notify: `TEAM_AGENT_NOTIFY_CMD`

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

## 4. Logs / activity: `TEAM_AGENT_LOG_GLOB`

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
  block forever and freeze the watchdog window). A glob that matches nothing, or one that matches a plain
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

## 5. Worked example: codex

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

## 6. Worked example: opencode

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

## 7. Verifying a new adapter (checklist)

1. `team doctor` → the `agent adapter` line resolves the binary; `team paths` shows `agent_adapter`.
2. `team dispatch <agent> <ID> <task> --print` → read the rendered command: no leftover `{`, and the
   `prompt file` path it prints exists.
3. Run that command by hand inside the worktree (auth, flags, cwd) before trusting tmux to do it.
4. Real dispatch, then check: the window shows the CLI; the worker's writes land in the worktree; the
   worker writes its summary file and the notify command lands in `docs/team/inbox/pm.md` (or the PM
   window) with the summary byte-exact (`TEAM_AGENT_NOTIFY_CMD` with `{summary_file}`).
5. `team monitor --once --activity` → the agent's block shows its Pi session or the configured log tail.
6. Only then rely on it — gates, reports and `team review` work the same for every adapter.

## 8. Intentionally unsupported

- **Emulating an agent's internal turn events.** teamsmith does not parse a vendor's private protocol to
  guess "the agent finished thinking". Turn-end notification is the adapter's job
  (`TEAM_AGENT_NOTIFY_CMD`), plus the PM side (`team say`, `inbox`, `roster`).
- **Interpolating worker text into a shell line.** A summary is data: it arrives through a file
  (`{summary_file}` / `team notify --from-file`). `{summary}` is rendered as a quoted file read for
  compatibility, but nothing a worker writes is ever re-interpreted by a shell — there is no supported way
  to make a summary part of a command's text.
- **Multiplexing per-agent streams out of one shared log.** `{agent}` is a filename placeholder, not a
  stream splitter; point the glob at per-agent files (or accept one shared tail).
- **Replacing the PM's own agent.** The PM (and the watchdog's `pi -c` restart, the PM prompt files, the
  notify extension) is still Pi; adapters are for worker agents.
- **CLIs that cannot accept a prompt non-interactively** (prompt only via a human TUI). Use
  `{prompt_file}` if the CLI can read a file or stdin; otherwise the agent cannot be dispatched by
  teamsmith.
- **New runtime dependencies.** Everything here is bash plus the CLI you install yourself.
