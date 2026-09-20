# Design: `console-project-settings` — the console edits the project contract through one safe writer

## Context

What this design works with. Everything below was read on the branch point of `task/P21-propose` (main `51c51f3`)
or measured in a scratch copy; the measurements are the report's raw material.

- **The contract and its readers.** `.pi/team/config.sh` is a flat `TEAM_KEY="value"` file (47 keys here, 58 in
  `templates/config.sh.tmpl`, 89 documented in `references/config.md`) that the CLI sources on every invocation
  (`common.sh: team_load_config`) and that `extension/team-notify.ts` parses without sourcing
  (`readCfg` → `stripComment` `/^(.*?)\s+#.*$/`, `unquote` strips one quote pair, `expand` maps `$VAR` from the
  environment). `references/config.md` is the doc of record for every key and its default.
- **Who holds a value.** Long-running processes do not re-read the contract: the pulse window is launched with the
  values baked into argv (`cmd-watch.sh team_cmd_monitor`: `--refresh "$TEAM_MONITOR_REFRESH"`, `--tick-every
  "$TEAM_PULSE_INTERVAL"`, `--events "$TEAM_MONITOR_EVENTS"`), and a few keys are read from the *environment*
  rather than from the file by the panel (`panel/src/main.tsx: process.env.TEAM_MONITOR_ACTIVITY`) or by an
  extension (`team-inbox-watch.ts`, `team-bg.ts`: `process.env.TEAM_INBOX_WATCH_*`, `TEAM_BG_LOG_MAX_BYTES`).
  Everything else — the tick (`team watch --once`), `team monitor --print/--json`, dispatch, review, close — is a
  fresh process that sources the file again.
- **Measured** (scratch fixture, `/tmp/p21-mon`): a plain `TEAM_MONITOR_ACTIVITY=0` in the contract is **inert**
  (`team monitor --print` still renders the activity column) while `export TEAM_MONITOR_ACTIVITY=0` in the same
  file, `TEAM_MONITOR_ACTIVITY=0` in the environment, or `--no-activity` all turn it off; by contrast a plain
  `TEAM_MONITOR_REFRESH=7` **is** honoured (`team monitor --json` reports `"refresh_s":7`) because the CLI
  forwards that one itself.
- **The only writer today** is `cmd-bootstrap.sh: team_config_set_in_file`. Measured behaviour, in full in the
  report: it replaces exactly the matched line with `sed -i`, so comments/order/blank lines elsewhere survive but
  **the inline comment on the changed line is destroyed**; a key the file lacks is appended, and **on a file whose
  last line has no trailing newline the append joins that line**; the value goes into a **double-quoted**
  assignment verbatim, so `team_config_set_in_file` with `$(touch PWNED)` **executes when the file is sourced**
  (verified), a value containing `"` silently changes meaning (`say "hi" now` → `say hi now`), and a value ending
  in `\` produces a file where **`bash -n` fails while the function still exits 0**; only a newline in the value
  makes it fail loudly (sed error, exit 1, file untouched). No call site checks the exit code for syntax.
- **The console.** `panel/src/App.tsx` has one overlay (`,`) with exactly five preference rows
  (`PREFS = ['lang','defaultPage','activity','mouse','density']`) persisted through `src/settings.ts` to
  `state/panel.conf`; the page's blocks come from `team __panel-data --block <name>` children spawned per block
  (`src/data.ts`), and the only state-changing actions are `runAction`/`send` spawning `team` subprocesses
  (`src/main.tsx`). The detail view (`console-board-page`) is the precedent for a full-view console-only block
  built on demand. Console-only blocks never reach `--print`/`--json`.

## Goals / Non-Goals

**Goals.**

- One place, in the console, to see every key the contract can carry, what it is worth, and whether changing it
  takes effect now or after a restart — with the keys the console must not touch shown as read-only and pointed at
  their route.
- One writer with a contract of its own: comment/order-preserving, fingerprint-guarded, value-validating,
  atomic, audited, and impossible to make execute code by sourcing the file.
- No new source of truth: the class table lives in the command (one home), the labels in the string tables, the
  values in the contract.

**Non-Goals (design level).**

- Renaming or redefining any `TEAM_*` key; a second config file, format or overlay; editing `state/` files
  through this view; deleting a key line or a "restore the default" action (writing an empty value is the
  documented way back to a default); an in-panel pulse restart action; any version bump, CHANGELOG heading or tag;
  the PM-owned `docs/team/**` prose.

## Decisions

### 1. The class rule, and the table it produces (brief question 1)

Three classes, decided by **who reads the value and when**, not by how important the key feels:

- **`apply`** — the next process that reads the contract sees the new value. True for every key whose readers are
  fresh invocations or fresh children: the tick (`team watch --once` is spawned per tick by the console), the
  `__panel-data` children (fresh process per block), dispatch, review, close, notify's extension (it re-reads the
  file per event).
- **`restart`** — a *running* process holds the value it started with: the pulse console (argv/`process.env`), the
  PM session (its own model/session/CLI arguments), a live agent/PM session (extension environment). The badge
  names the target and the exact command.
- **`refuse`** — the console must not change it: the key determines the project's identity, the roster, where the
  ledger/worktrees/specs live, the shape of branches and the forge, the dependency policy, the machine paths Pi's
  own state is read from, or a guard that widens the tool's authority. Rule of thumb: **the console may not widen
  its own authority** (the `TEAM_ALLOW_FOREIGN_*`/`TEAM_REPLACE_FOREIGN_PM`/`TEAM_ALLOW_DESTRUCTIVE_TMUX`/
  `TEAM_CONFIRM_WRITES` family) **and may not move the ledger** it is reading.

The table is the schema's content (`scripts/lib/cmd-config.sh`), one row per key with `class | kind | form |
default | danger`. `form` is `plain` or `export`: **a value read from the process environment by a child must be
written as `export KEY='…'`**, or it is inert — the measured `TEAM_MONITOR_ACTIVITY` case above, and the same
mechanism for the inbox-watch/bg knobs and `TEAM_AGENT_LOG_TAIL_BYTES`. Completeness is a test, not a promise:
every key in `templates/config.sh.tmpl` and every backticked `TEAM_*` in `references/config.md` must be in the
schema or in an explicit "not a contract key" allowlist, and every schema key must be documented in
`references/config.md`.

| Group | Keys (class, form, notes) |
|---|---|
| **Identity & layout — refuse** | `TEAM_PROJECT`, `TEAM_SESSION`, `TEAM_PM_WINDOW` (identity; directory/`team init` owns them), `TEAM_AGENTS` (roster; route `team add-agent` / `team teardown`), `TEAM_DOCS_DIR`, `TEAM_WORKTREES_DIR`, `TEAM_STATE_DIR`, `TEAM_MEETINGS_DIR`, `TEAM_SPEC_DIR` (the ledger's layout; changing one while the tool reads it is how windows and worktrees stop matching), `TEAM_ROOT`, `TEAM_MAIN_ROOT`, `TEAM_CONFIG_FILE` (environment locators; the directory wins, `boundary`) |
| **Branches & forge — refuse** | `TEAM_BRANCH_MODE`, `TEAM_TASK_BRANCH_PREFIX`, `TEAM_AGENT_BRANCH_PREFIX`, `TEAM_PROTECTED_BRANCH`, `TEAM_REMOTE`, `TEAM_VCS`, `TEAM_TOKEN_FILE`, `TEAM_GITLAB_HOST`, `TEAM_GITLAB_PROJECT`, `TEAM_GITLAB_TOKEN_FILE` (they define what "landed" means and where credentials live) |
| **Authority & dependency policy — refuse** | `TEAM_CONFIRM_WRITES`, `TEAM_ALLOW_FOREIGN_IDENTITY`, `TEAM_ALLOW_FOREIGN_SESSION`, `TEAM_GUARD_FOREIGN_TARGET`, `TEAM_REPLACE_FOREIGN_PM`, `TEAM_ALLOW_DESTRUCTIVE_TMUX`, `TEAM_ASSUME_YES`, `TEAM_REQUIRE_JS`, `TEAM_REQUIRE_OPENSPEC`, `TEAM_REQUIRE_MAGIC_CONTEXT`, `TEAM_PI_AGENT_DIR`, `TEAM_PI_SETTINGS_FILE`, `TEAM_MEMINFO_FILE`, `TEAM_SMOKE_FAST` |
| **Roster, models & adapters — apply** | `TEAM_MODEL_LIMITS`, `TEAM_MODEL_WINDOWS`, `TEAM_SESSION_WARN_TOKENS`, `TEAM_EXTRA_PI_ARGS`, `TEAM_AGENT_CMD`, `TEAM_AGENT_NOTIFY_CMD` (placeholder validation reused), `TEAM_PI_BIN`, `TEAM_AGENT_BIN` (path check), `TEAM_OPENSPEC_BIN`, `TEAM_JS_BIN`, `TEAM_AGENT_LOG_GLOB` (a fresh `__panel-data` child reads it per block) |
| **Models, per seat — restart (the seat's window / the PM process)** | `TEAM_DEFAULT_MODEL` (the fallback every seat resolves to), `TEAM_AGENT_MODELS` (the per-seat overrides), `TEAM_PM_MODEL` (the PM's own seat): all three are read when a window is spawned (`dispatch` / `resume` / `team up`), so a **running seat keeps its model** until it is spawned again; the display carries the source tri-state (`配置` / `显式` / `历史记录`, `team_agent_model_src`) and the per-seat editor writes through `team config set-agent-model` (§11) |
| **Workflow & gates — apply** | `TEAM_GATES`, `TEAM_INSTALL_CMD`, `TEAM_TASK_BRANCH_RESET`, `TEAM_DISPATCH_VERIFY_SEC`, `TEAM_DISPATCH_ALIVE_SEC`, `TEAM_SQUASH_LOOKBACK` (⚠ `0`), `TEAM_REVIEW_TIMEOUT` (⚠ `<60`), `TEAM_REVIEW_TIMEOUT_GRACE`, `TEAM_REVIEW_ALLOW_DIRTY`/`_IGNORED`/`_UNRESOLVED_BRANCH`/`TEAM_REVIEW_ANY_DIR` (⚠ `1`), `TEAM_BOARD_DONE_FORCE` (⚠ `1`), `TEAM_BOARD_DONE_REASON` |
| **Capacity & notifications — apply** | `TEAM_MIN_FREE_SWAP_MB`, `TEAM_MIN_TOTAL_MB`, `TEAM_MIN_AVAIL_MB` (⚠ `0`: the floor is off), `TEAM_WARN_AVAIL_MB`, `TEAM_ZRAM_WARN_PCT`, `TEAM_AGENT_MEM_MB`, `TEAM_NOTIFY_TMUX`, `TEAM_NOTIFY_DEDUP_SEC`, `TEAM_INBOX_MAX_CHARS`, `TEAM_NOTIFY_LOG`, `TEAM_DEFER_TTL` (⚠ `0`), `TEAM_OUTBOX_MAX` (⚠ `0`), `TEAM_PANEL_DETAIL_CAP` |
| **Patrol & console — restart** | `TEAM_PULSE_INTERVAL` (⚠ `<60`; baked into `--tick-every`), `TEAM_MONITOR_REFRESH` (baked into `--refresh`), `TEAM_MONITOR_EVENTS` (`--events`), `TEAM_MONITOR_UI` (the console's own mode), `TEAM_MONITOR_ACTIVITY` (export form), `TEAM_AGENT_LOG_TAIL_BYTES` (export form), `TEAM_PULSE_WINDOW` (⚠ changing the backend's name while a backend runs under the old one; the route is `team pulse down` (old name) → write → `team pulse up`) |
| **Patrol policy — apply** | `TEAM_PULSE_NUDGE_GAP`, `TEAM_PULSE_PENDING_BOARD`, `TEAM_PULSE_REBUILD_TMUX`, `TEAM_PULSE_MAX_RESTARTS` (⚠ `0`: no auto-recovery) — each read by the tick's fresh `team watch --once` child |
| **PM lifecycle — restart (PM)** | `TEAM_PM_SESSION_ID`, `TEAM_PM_CMD`, `TEAM_PM_BIN`, `TEAM_PM_EXTRA_PI_ARGS`, `TEAM_PM_RESUME_ARGS` (a running PM keeps them; `team up` uses the new ones), `TEAM_PM_START_WAIT` (fresh per start → apply) |
| **Live sessions — restart (session), export** | `TEAM_INBOX_WATCH_MAX_BYTES`, `_PREVIEW`, `_REPLAY_MAX`, `_SEEN_MAX`, `_STALE`, `_POLL_MS`, `_HEARTBEAT_MS`, `_TARGET`, `TEAM_BG_LOG_MAX_BYTES` — read from the environment by extensions inside a running session |
| **Meetings — apply** | `TEAM_MEETING_TTL_HOURS`, `TEAM_MEETING_MAX_TURNS`, `TEAM_MEETING_KNOCK`, `TEAM_MEETING_ALLOW_USER_ID` (⚠ non-empty: it widens who may knock) |
| **Not contract keys — refuse** | every key in the file the schema does not know (the `TEAM_WATCH_*` aliases, `TEAM_DEBUG`/`TEAM_*_DEBUG`, `TEAM_PANEL_EDITOR`, …): shown read-only, "not a known project setting", with `references/config.md` as the pointer |

Alternatives considered: a two-class split (editable/read-only) — rejected, the user's question is precisely
"which ones take effect when"; a per-key prose hint in the schema — rejected (it would be a second copy of
`references/config.md`; the view shows the line's own inline comment instead, which is the file's own
documentation); deriving the class from a grep at runtime — rejected (the reader analysis is a decision, not a
derivation, and a wrong grep silently mislabels a key).

### 2. One writer, hardened in place (brief question 2, first bullet)

`team_config_set_in_file` stays the only low-level writer (bootstrap/`team init` keep calling it) and is rewritten
to: read the file, locate the key's line **as a whole line** (`^KEY=` with optional surrounding whitespace),
replace only that line, and keep the rest byte-identical. The inline comment is preserved by scanning the old
line's value with a quote-aware state machine (the first `#` outside quotes starts the comment) and re-appending
it verbatim; a line whose value has no closing quote is treated as having no comment (never truncated). New keys
are appended after a final newline that the writer adds if the file lacks one. `team config set` wraps this
function with the checks below; `team init`/`team bootstrap` inherit them, and their call sites gain the
`|| fail` they lack today (a refused gate/install value must fail the init, not vanish).

### 3. The fingerprint is a compare-and-swap (brief question 2, second bullet)

`fingerprint = sha256(contract bytes)`. `team config list --json` reports it; `team config set … --fingerprint X`
re-reads the file, recomputes, and refuses with exit 3 when it differs (nothing written, one `result=conflict`
audit line naming expected vs actual); a write without the flag is a human's explicit "use the file as it is now",
documented as such. The console pins the fingerprint **when the editor opens** (not when the view opened) and
re-reads on every settle, so the window a lost update could slip through is one edit. Any byte change counts,
including a comment elsewhere — simpler to explain than a partial comparison, and the recovery is one keypress.
A `flock` was rejected: `flock` is not on macOS, and the tool does not take a lock anywhere else; the temp-file
rename keeps every write atomic, and the residual window (two writers *without* fingerprints) is documented.

### 4. The value's form is derived by the writer (brief question 2, third bullet)

The writer emits `KEY='value'` (single quotes; `export KEY='value'` for the `export`-form keys). A `'` inside the
value is written as `'\''` (bash-correct) except on the keys `extension/team-notify.ts` parses through its flat
reader (`TEAM_SESSION`, `TEAM_PM_WINDOW`, `TEAM_WORKTREES_DIR`, `TEAM_DOCS_DIR`, `TEAM_NOTIFY_TMUX`,
`TEAM_NOTIFY_DEDUP_SEC`, `TEAM_INBOX_MAX_CHARS`, `TEAM_NOTIFY_LOG`), where a `'` is refused (that reader has no
escape; the class is `refuse` for the first four anyway). A line break or a `#` in a value is refused — the
extension's `stripComment` cuts at ` #` and its doc already states "no `#` in values". The caller's quoting is
never reused: this is the flip that turns the measured command-injection into data.

### 5. Validation and the danger list live in the command (brief question 2, fourth bullet)

Each schema row carries `kind` (`bool | int | seconds | mb | pct | enum | text | path | list | cmd`) plus
`min`/`max`/`enum`/`token` rules; `team config set` is the only validator, and the console never re-implements it
(it asks with `--dry-run`). Exit codes are the machine contract: `0` written/valid, `3` fingerprint conflict,
`4` invalid value, `5` key not editable, `6` write error (file unchanged), `7` dangerous (dry-run/without
`--allow-danger`). **Danger** = a *valid* value that disables a shipped guard, makes a shipped loop spin or a
queue stop draining, or changes a name that a running process resolves (the ⚠ marks in §1). `--allow-danger` is
the explicit second consent; it never makes an invalid value legal. Path kinds check existence and executability
(empty allowed where empty has a meaning, e.g. `TEAM_AGENT_BIN`). The **`pairlist`** kind — `TEAM_AGENT_MODELS`,
written either as the whole value or through `set-agent-model` — validates every `seat=provider/model` token: the
seat MUST be a roster seat or `pm` (the pair form exits 5, the whole-value form exits 4, both naming the roster)
and the right-hand side MUST have the `provider/model` shape (exit 4); a token whose seat the roster does not name
and that is already in the file is reported by `team config list --json` as a warning, never silently ignored.
`TEAM_MODEL_LIMITS` keeps its own `pattern=N` rule (`N` a non-negative integer, `*` allowed in the pattern).

### 6. Atomicity, mode and symlinks

`team config set` copies the contract to `<dir>/.config.sh.tmp.$$` preserving mode, rewrites the temp file,
runs `bash -n` on it, and only then `mv -f`s it over the contract (same directory → one rename). Any failure
removes the temp file and leaves the original bytes. When the contract is a symlink, the writer resolves it and
writes the target (it never replaces the link with a regular file). No `state/` write happens before the contract
write.

### 7. Interaction: the overlay keeps its five preferences, and one row opens the view (brief question 3)

Rejected: a sixth *preference* in the overlay — 40+ rows of key/value pairs with grouping, filtering and a
windowed list are a view, not an overlay row; and a fifth page — the four-page composition and
`state/panel-page` are existing contract, the view is a *view* like the detail view (it replaces the blocks, the
title band/tabs/key band stay, `esc` returns to its origin). The overlay gains exactly one navigation row
("project settings"), clickable like its other rows; the view is the contract's listing.

- **Rows**: group heading (not focusable) → `cursor key … value · class badge`, with the key's own inline comment
  dimmed when the line has one and `<unset> · default <d>` for a key the file does not carry.
- **Keys**: `↑`/`↓` move the focus and drag the window (hidden-row counts at both edges); `/` opens the filter
  line (the compose editor, mode `filter`; matches key or value, case-insensitive; `esc` clears without closing);
  `enter` edits (or, on a `refuse` row, surfaces the command's refusal and its route); `esc` returns to the
  overlay; `q` keeps its global meaning. Mouse: rows are targets (focus, second click = edit), and the filter key
  carries a chip like every other shown affordance.
- **Value editor**: the compose line's editor, mode `setting` (P20's key map, insertion point, kill ring, undo,
  windowing) — one more mode of one implementation, not a second editor. It opens holding the file's value or the
  schema's default. A typed or pasted newline is *not* silently rewritten: the value goes to the command, the
  command refuses it with `4` and names the reason, and the editor keeps the draft (a silent rewrite would be the
  kind of "helpful" mutation the users cannot audit).
- **Confirm and receipts**: the confirmation line shows `key: old → new · class timing` (and for `restart` the
  exact command, e.g. `team pulse restart`); the second `enter` writes. The receipt maps exit codes to the four
  honest states (written / refused-read-only / rejected-invalid / conflict / write-error) plus the danger
  two-step; the view then re-reads the list and the audit tail.
- **The bundle carries no key table**: rows and classes come from the command's JSON at render time (the fixture
  proves a schema key added to a scratch CLI shows up without rebuilding `panel.js`).
- **Read path**: a console-only `settings` block in `team __panel-data` (the detail view's on-demand pattern),
  whose payload is exactly `team config list --json`; it is fetched when the view opens and after every settle —
  never on the frame cadence, so the performance contract is untouched. A missing contract renders the command's
  error line, like every other block failure (`—` plus the reason), and never breaks the frame.
- **Strings**: every label is a table key in both languages; the *command's* messages (validation, refusal,
  conflict) are shown verbatim as the command's output, the same rule the existing receipts follow.

### 8. Effect is shown, not executed: no in-panel restart (brief question 4)

The class badge is the answer to "when does it take effect": `apply` = "the next read uses it"; `restart` = "a
running process holds the old value — restart the pulse / the PM / the session", printed with the command. The
receipt must not claim success it cannot observe (the `TEAM_MONITOR_REFRESH` scenario: the running console still
reports 3, the next `--print` reports 7). A "restart the pulse" action was rejected: the console *is* the pulse
window's process, so the action would kill the process drawing the receipt (and the `pulse` spec's "one backend,
one window" rule makes a self-replaced backend a race); the restart command is printed instead. A "restart this
seat now" action is rejected for the same class of reason (§11). That keeps the read-only exception list at exactly
one new entry.

### 9. Audit: one line per attempt, readable from both ends (brief question 5)

`<state>/config.log`, one line per attempt that passed argument parsing:
`<UTC ISO-8601> result=<ok|refused|invalid|conflict|danger-refused|write-error> actor=<name> key=<KEY>
old='…' new='…' [expected=<sha> actual=<sha>]`. Values are single-quoted in the line (the writer's own escaping),
so the line stays one line; `--actor` defaults to `cli` and the console passes `panel`; `--dry-run` writes
nothing. `team config log [N]` (default 10) prints the newest lines, and `team config list --json` carries the
same tail — the reader is bounded to the file's last 16 KiB, no rotation in v1 (a settings change is a rare
event). The view renders at most three of those lines in its footer, so "who changed what, when" is answerable
where the change happened. If the audit write itself fails, the command reports the write's real outcome and
warns — an audit failure must not read as a failed write.

### 10. Coordination: the archive order with `panel-ergonomics`

`panel-ergonomics` (P20, merged, not archived) modifies five `panel` requirements — the write, mouse, read-only,
string-table and detail requirements — one of them the read-only requirement this change replaces (`REMOVED` +
`ADDED` under a count-free title); the settings overlay is untouched by P20 and modified only here. This delta is
written so that **`panel-ergonomics` must be archived first**: its `C-v` clause and its
"paste writes outside the project" scenario are carried forward into the ADDED read-only requirement, so
archiving P20 first loses nothing. Archived second, this change's `MODIFIED`/`REMOVED` blocks still match the
base. The reverse order fails loudly (P20's `MODIFIED` would name a requirement the base no longer carries,
which OpenSpec's trial archive refuses) — the PM owns that order.

### 11. The model family: per-seat editing, the source tri-state, and the seat-restart ruling (the brief's follow-up)

`TEAM_DEFAULT_MODEL` → `TEAM_AGENT_MODELS="dev=provider/model …"` → `--model` on dispatch/resume is one resolution
order (`team_agent_model`), and the seat's `state/<agent>.env` record is **not** an input to it — it is the
"what ran last time" display value, which is exactly why `team_agent_model_src` labels it `配置` / `显式` /
`历史记录` (`common.sh:700`: no record → `配置`; `model_src=explicit` → `显式`; record ≠ the config resolution →
`历史记录`, and `team ps` prints `model·source` with that legend). The console must show the same three states:
a bare model name would tell the PM a lie about what the next dispatch will use.

- **Class**: all three keys are `restart`, with the target named per seat — `dev` uses the new model on its next
  `dispatch`/`resume`, the seat's running window keeps the old one, and `pm` needs the PM process rebuilt
  (`team up`). `TEAM_AGENT_MODELS`'s raw line stays editable (it is the fallback editor for people who prefer the
  syntax), but it is no longer the only entry.
- **The per-seat entry**: the view carries a **seats** block — one row per roster seat plus `pm` — showing the
  displayed model, its source badge and whether the seat carries an override; `enter` opens a picker
  (the seat's known models, then free text) and writes through **`team config set-agent-model <seat> <model|->`**,
  which parses and re-serializes the pair list itself (one implementation, no TS parser), validates that the seat
  is in `TEAM_AGENTS` (or is `pm`) and that the model has the `provider/model` shape, and takes `-` to remove the
  override and fall back to `TEAM_DEFAULT_MODEL`. The read side is `team config list --json`'s `models` block:
  `{default, seats:[{agent, model, source, override}]}` — the source from the same function `team ps` uses, so the
  panel cannot invent a fourth state. An unknown seat in the value (a typo `dev4=…`) is refused by the token
  validator instead of silently never matching (the roster is the allowlist).
- **Seat restart: not in v1** (the brief left it to this design). Rejected reasons: (a) spawning a seat is
  `dispatch`/`resume`, the PM's authority — they carry a brief, guards (unfinished task, dirty worktree, capacity)
  and a session-continuity decision (`--fresh` vs continue) the console cannot make; (b) the console would have to
  kill a window that may hold an agent's only copy of a draft, and the guards the brief suggests (dirty worktree /
  running task) are exactly the decisions `dispatch` already makes with more information; (c) `--fresh` vs
  `--allow-overflow` are not alternatives but independent flags (session continuity vs capacity floor), so
  "one of the two" would not even be a coherent UI. The row prints the route instead: *the seat keeps its model
  until you re-spawn it — `team resume --agent <a>` for the stopped case, the PM's `dispatch` for the rest*.
  If it is ever added, it is a fifth action and must be listed in the read-only requirement like the other four.

## Risks / Trade-offs

- [A value with a `'` on one of the notify extension's eight keys] → refused with the reason; those keys are
  `refuse`/int/`bool` in practice, and the alternative (write it and let the extension mis-parse it) is a silent
  misconfiguration.
- [The schema drifts from `references/config.md`] → the completeness test runs both directions and fails naming
  the key; a new documented key forces a schema decision.
- [A `restart` key is written and the user expects it to work] → the badge, the confirmation line and the receipt
  all name the restart and the command, and the running console keeps showing the old value (the honest signal).
- [The `TEAM_MONITOR_ACTIVITY` class looks surprising (needs `export`)] → measured and stated in the badge's
  tooltip/description line and in `references/config.md`; the writer emits the `export` form for that key.
- [A write races a hand-edit] → the fingerprint refuses it, the other writer's bytes survive, the view reloads;
  the residual no-fingerprint window is documented.
- [The view's read path grows the console] → it is an on-demand console-only block (the detail-view pattern) and
  never enters the 3-second cadence; the CPU/first-frame contract is re-measured in the batch that adds it.
- [Refusing too much makes the feature thin] → the table deliberately keeps ≈70 editable keys of the 89
documented (the gates, models/adapters, capacity floors, notification/delivery knobs, patrol policy, PM
  lifecycle, meetings, review escape hatches) and refuses only identity/ledger/authority/dependency-policy keys;
  each refusal names the route.
- [A user wants to change `TEAM_PROTECTED_BRANCH` from the console] → refused by design (it redefines "landed"
  while the tool is running); the file is one editor away, which is the honest boundary.
- [The seat row's model misleads (it shows what ran last, not what will run)] → the source badge is mandatory and
  uses the CLI's own three labels, the seat editor says it writes the **config** (next spawn), and the receipt for
  a seat-model write names the seat and the next-spawn rule; a seat with a differing record shows `历史记录`.
- [The per-seat write drifts from the raw line] → both write the same key through the same writer; the pair
  command is a value transform in front of it, covered by the same CAS/audit/validation tests plus its own
  seat-allowlist cases.

## Migration Plan

Five apply batches, verified one by one (tasks.md): **B1** the command — schema, `list`/`log` plus the model
seats and `set-agent-model`, the hardened writer, the CAS, validation and the audit (all of `memory-and-deps`'s new
requirements, headless fixtures); **B2** the view read-only — the `settings` block, the row set/classes/filter/
focus/mouse, the strings (the first `panel` requirement); **B3** editing and writing — the editor mode, the
dry-run, the confirmation, the danger two-step, the receipts, the audit footer, the reload-on-conflict (the second
`panel` requirement); **B4** the model seats — the seats block, the tri-state badges, the per-seat picker and the
`set-agent-model` wiring (the third `panel` requirement); **B5** the read-only requirement's replacement,
`references/config.md`/`SKILL.md`/`team help`, the final `panel.js` rebuild and the full gate. Each batch rebuilds `panel.js` so the pty fixtures exercise what the branch ships. Rollback is
`git revert` per batch: the command is additive, the contract's format is unchanged, and the view's block is
console-only (the machine exits never read it).

## Open Questions

None. Every open choice the brief leaves — the class rule and the table, the writer's home, the fingerprint
semantics, the value form and the refusal list, the danger list and its flag, atomicity/symlink handling, the
overlay row vs a fifth page, the editor mode, the no-self-restart ruling (pulse and seat), the model tri-state and
the per-seat entry point, the audit format and its reader — is decided above.
