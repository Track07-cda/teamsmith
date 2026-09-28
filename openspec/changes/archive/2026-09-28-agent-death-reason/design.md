# agent-death-reason · design

Status: **propose phase** (planning only — no `skills/**` change in this task). Every statement about
today's code was read in this task's worktree at `011119a2`; the commands and their output tails are in
`docs/team/reports/P101-verify.md`. The brief (`docs/team/tasks/P101-agent-death-reason.md`) is the
scope; this file is the *how* and the falsifiable contract the apply and the verify work against.

## 0. The problem, stated precisely

A worker seat can stop in four observable ways (`running` / `exited` / `dead` / `absent`, P55's seat
condition) and the system says "a seat stopped" three ways (the pulse's `停了的 agent N`, the extension's
`[auto·interrupted]`, the digest [7] dead-pane line) — none of which says **why**. D46 recorded the cost:
the only scene is the pane, and the PM read three panes by hand before finding
`Error: 403 permission_error: reached your weekly (7-day) usage limit`. The 2026-09-28 user report is the
same shape on kimi's 5-hour quota: the worker died, the pulse named no cause, and the screenshot's
`403 permission_error … usage limit … quota` was the only evidence anywhere.

The flip (what the apply must make observable): the same corpse yields `quota`, with the raw line, on
`team status <ID>` and the panel's agents block; `team digest` [1] names each stopped seat's category;
the patrol knocks once per death and never for a clean exit. Two hard requirements from the brief frame
everything below: **never invent a cause** (an unreadable or shape-less scene is `unknown`, still
reported, but reported as unknown) and **a restart never inherits the old cause**.

## 1. What exists today (the recon this design builds on)

| Piece | Where | What it gives us (and what it does not) |
|---|---|---|
| Pane census | `lib/cmd-agents.sh` · `team_pane_dead_fields` (485-500) | `pane_dead`, `pane_dead_status`, `pane_dead_signal`, `pane_dead_time`; the only hard exit evidence |
| Corpse retention | `lib/cmd-agents.sh` · `team_agent_capture_corpse` (560) | on dispatch replacing a corpse: header (`seat/window/captured/exit/dead_time`) + `--- scene ---` + the scrollback tail → `state/dispatch-<agent>-pane-dead.txt` |
| Harness evidence | `lib/cmd-agents.sh` (373-422, 908-955) | `state/dispatch-<agent>.spawn` = `<launch-nonce> <pid>`; `state/dispatch-<agent>.exit` = `<launch-nonce> <exit-code>`, written by the harness after the agent returns; `state/dispatch-<agent>-tail.txt` = the tail captured at that moment. The launch nonce identifies one generation exactly |
| Seat condition + scene | `lib/cmd-status.sh` · `team_seat_condition` (1099), `team_seat_scene_print` (1196) | the four conditions; the scene reader's recency order: live corpse (`capture-pane -S -`) → saved corpse file → tail file |
| "Stopped" count | `lib/cmd-watch.sh` · `team_panel_pending_counts_fast` (668) | `task=…` non-empty and `team_agent_live` false ⇒ `stopped` — a **count**, with no seat list and no cause |
| Surfaces | `lib/cmd-status.sh` (digest 634, seat section 1240, digest [7] 1270); `lib/cmd-watch.sh`·`team_panel_agents_json` (560) | digest [1] `待办 … 停了的 agent N`; status's seat block (condition + scene); the agents block (`state`, `pane`, `pane_exit`) |
| Session files | `lib/common.sh`·`team_pi_session_dir`/`team_session_file` (2440-2480); `scripts/monitor.mjs`·`readSession` | Pi's dir encoding for a worktree and the `*_<sid>.jsonl` lookup (misses `--fresh` ids); `monitor.mjs` parses message text but **drops errors** (`entry.message.errorMessage` is not read) |
| Extension | `extension/team-notify.ts:339` | the turn-end tag `[auto]` / `[auto·interrupted]` and the knock enqueue with a turn-level dedup key; it never classifies a cause and cannot (the process is usually gone) |
| Classification | — | **nothing**: grep for `usage limit`, `insufficient_balance`, `permission_error` outside unrelated config/inotify text → zero hits |

Two consequences are designed in: the seat's **current generation is already identifiable without new
state** (the launch nonce in `.spawn`/`.exit`, plus `state/<agent>.env:started` written at every
`dispatch`/`resume`), and the **pane side already has a three-source recency order** the classifier must
reuse rather than reinvent (one scene reader, one story).

Blast radius (the assertions the apply must keep honest, not weaken): the exact `team_pending_text`
equality in the smoke suite (`assert_eq … "未读通知 1 · 待复验 1 · blocked 1 · 需 PM 处理 · 停了的
agent 1"`), the P55 section's status/digest/pending assertions, the `26-g` agents-block JSON fixture, and
`26-a`'s byte-identical panel rebuild.

## 2. Goals / Non-Goals

**Goals**
- One derived, read-only reader that answers "why did this seat's current launch die?" for the four seat
  conditions, in the closed set `quota | balance | rate_limit | window | auth | normal | unknown`.
- The cause visible where the PM already looks (`team status <ID>`, `team digest` [1], the agents block)
  and announced once per death by the patrol.
- Every promise falsifiable from fixtures: the five provider categories, the two counter-examples, the
  clean exit, the identity/dedupe, the restart guard, the surfaces.
- No new dependency, no daemon, no new state writers except the patrol's record file.

**Non-Goals** (the brief's list, made concrete)
- **M6.5's liveness proof is untouched**: `running` still requires the pane process tree proof;
  `dead`/`exited`/`absent` keep their exact vocabulary and rules. This change only adds *why* beside a
  condition that already exists.
- **No automatic fallback** (switching provider/model off a death) — a different change with its own
  spending-authority question.
- No change to the `[auto·interrupted]` tag or the extension's knock path; no `team roster` change; no
  `team doctor` requirement (the dead-pane warning line stays as it is); no cross-project behavior.
- No repair of `team_session_file`'s `--fresh` blindness for existing surfaces (the classifier uses its
  own lookup; the roster's session-size column keeps its current semantics).
- No assertion, threshold or fixture premise is relaxed to make the new tests pass.

## 3. Decisions

### D1 — One reader, derived on demand, read-only; no new record of state except the patrol's log

A single reader (`team_seat_death_fields <agent>`) answers `category ⇥ source ⇥ record-time ⇥ raw line`
(or nothing when the seat has no abnormal death). `team status`, `team digest`, the agents block, and
the patrol all call it; none of them writes anything (the P55 read-only rule stands — no file under
`.pi/team/state/` may change contents or timestamps because of a read). The only new writer is the patrol
tick's record file (D5), which is why the classifier cannot be "remember the last answer in a state
file": a derived answer cannot go stale, and a reader that writes is not a reader.

### D2 — Two source classes; the pane side reuses the one existing recency order

- **Pane side** (source `pane`): the same order `team_seat_scene_print` already uses — a retained dead
  pane's `capture-pane -p -S -` scrollback (the newest and richest), then
  `state/dispatch-<agent>-pane-dead.txt` (saved before a corpse was replaced), then
  `state/dispatch-<agent>-tail.txt` (captured by the harness at agent exit), then the current launch's
  exit evidence (`state/dispatch-<agent>.exit`, nonce-matched) when none of the three yields a category.
  One reader, so the scene a PM sees and the scene classified cannot be two different stories. A death
  whose only readable evidence is a non-zero exit status is `unknown` with `exit status=<n>` as its raw
  line (status `0` is clean-exit evidence, D4).
- **Session side** (source `session`): the newest pi session JSONL for the seat's worktree
  (`team_pi_session_dir`), matching `*_$TEAM_SESSION-<agent>.jsonl` or `*_$TEAM_SESSION-<agent>-<digits>.jsonl`
  (the `--fresh` shape `team_session_file` misses). Read as a bounded tail (64 KiB), scan **from the
  end** for the last assistant entry with `"stopReason":"error"` carrying a string `"errorMessage"`; that
  message is the raw line and its entry `"timestamp"` is the record time. A line that does not parse, or
  an extraction that would need a JSON parser, yields **no session evidence** (never a mangled guess).
- When both sources yield a cause: a category other than `unknown` beats `unknown`; among equals the
  **newer record time** wins; if times tie or are unavailable the session source wins (structured
  evidence over a screen scrape). The reported source names which one was read.
- Neither source readable, or no shape matched ⇒ `unknown` — with no category words anywhere
  (`unknown` is reported, not hidden, and never dressed up as a cause).

### D3 — Shape before category: a frame is required, and the last matching line in the bounded tail wins

An evidence line is classified only when it carries **both** an error frame and the category's wording.
The frame (case-insensitive) is one of: a line starting `Error:`/`error:`; an HTTP status token
(`401|402|403|429|5xx`) beside a provider error code (`*_error`); a JSON error object (`{"error"…` /
`"error": … "message"`); or a provider `*_error` token. `window` additionally accepts Pi's own unframed
phrasings (`Context full`, `context overflow`, `context length exceeded`) because Pi prints those
without an `Error:` prefix. Then the **first match in this precedence order** names the category:

| Order | Category | Wording (frame + one of) | Falsifying fixture |
|---|---|---|---|
| 1 | `balance` | `insufficient balance`, `insufficient_balance`, `balance insufficient`, `余额不足`, `欠费`, `payment required` | `Error: 402 payment required: insufficient balance` |
| 2 | `quota` | `usage limit`, `quota`, `insufficient_quota`, `exceeded your current quota`, `额度`, `用量上限`, `weekly limit`, `5-hour limit` | `Error: 403 permission_error: reached your weekly (7-day) usage limit` (the D46/user frame) |
| 3 | `rate_limit` | `rate limit`, `rate_limit`, `too many requests`, `429` | `Error: 429 rate_limit_error: too many requests` |
| 4 | `window` | `context window`, `context length`, `Context full`, `too many tokens`, `maximum context` | `Error: Context full: 272000 tokens` |
| 5 | `auth` | `401`, `unauthorized`, `authentication`, `invalid api key`, `permission_error`, `forbidden`, `permission denied` | `Error: 401 unauthorized: invalid api key` |

Precedence is what keeps the D46 frame `quota` and not `auth` (it carries `403 permission_error` **and**
`usage limit`); `balance` is checked first on purpose because `insufficient balance` is the more specific
money statement. Within the bounded tail (`TEAM_DEATH_SCAN_LINES` lines, default 40, non-numeric → 40)
the classifier takes the **last line that matches any category**, so a trailing unrelated error
(`Error: getaddrinfo ENOTFOUND`) does not mask the real cause above it. Two counter-examples are pinned
by fixtures: `Reading the docs: the weekly quota is five hours` (frame-less prose) and `I will check the
rate limit of the vendor` must **not** classify — a death with such a last line is `unknown`.

The raw line is the matching line, control-character-sanitized and truncated to one line (≤ 300 chars,
`…` when cut); it travels with the category everywhere (D5/D7) because the category is a clue, not the
verdict. When a readable source yields no category match, the raw line kept for `unknown` is that
source's last non-empty line (usually the scene's tail, so `team status` shows what was on screen); with
no readable source at all there is no raw line.

### D4 — `normal` requires positive clean-exit evidence, and is not a death

The brief's "正常退出 → 无通报、无分类" is applied as: a clean exit is **recognized** (so it cannot be
mistaken for `unknown`) and is not treated as an abnormal death — no cause line, no record, no knock.
Positive clean-exit evidence is the current launch's exit evidence (`state/dispatch-<agent>.exit`, nonce
== the current `.spawn` nonce) with status `0`, or a retained pane dead with `pane_dead_status=0`.
A non-zero or signal exit **without** a recognized frame is `unknown`, not `normal`. A recognized
specific category wins even if the exit code was 0 (the frame is the real story). A completed last turn
in the session file alone is **not** clean-exit evidence: it proves a finished turn, not a finished
launch, and would turn a mid-next-turn SIGKILL into a false silence.

### D5 — Current-launch scoping and the identity `(seat, category, anchor)`

The current launch is identified by the launch nonce (`state/dispatch-<agent>.spawn` field 1) plus
`state/<agent>.env:started`. Evidence is attributed to the current launch only when its record time is
≥ `started` (pane `pane_dead_time`, saved-corpse `dead_time`, tail-file mtime, session entry timestamp)
or its exit nonce is the current one. This is what stops the saved corpse file and a resumed pane's stale
scrollback from re-reporting the previous death; after `team dispatch`/`team resume` the surfaces show no
cause until the new launch dies with its own evidence.

The anchor for the identity is, in order: `nonce:<current-launch-nonce>` (always when the death belongs
to the current launch), else `pane:<pane_dead_time>`, else `pid:<pane-id>`, else `line:<hash of the raw
line>`. Identity = hash of `seat|category|anchor`. The patrol writes one line per **identity** to
`state/deaths.log`:

```
<iso-8601>\t<seat>\t<category>\t<source>\t<anchor>\t<identity>\t<raw line>
```

This file is the raw-line retention (the PM can check the classification after the scene is gone) and
the knock dedupe (record before the knock, D6). It is bounded like `capacity.log` (keep the last 500
lines) and is **never** deleted on a restart — the restart guard is the anchor/`started` comparison, not
file cleanup.

The surfaces fall back to this file only when the live read yields nothing or `unknown`: the newest
record for the seat whose anchor belongs to the current launch (nonce equal, or record time ≥ `started`)
is reported with source `recorded`. Without such a record the surface prints no cause rather than a
guess.

### D6 — The patrol: detect, record, knock once — with standby deferring, not losing

Inside `team_watch_once`, **before** the existing outbox drain (so a knock leaves in the same tick when
the PM window is free) and before the standby/PM branch, the tick walks the seats with `task=` non-empty
and `team_agent_live` false (the exact `stopped` population) and calls the reader. For an abnormal cause
(`≠ normal`) with **at least one readable source** whose identity is not in `state/deaths.log`: **append
the record first**, then (unless `team standby on`) enqueue exactly one knock through the delivery guard
(`team outbox enqueue --kind knock --from pulse --dedup death:<identity>`, payload from D7). A tick that
finds the identity already recorded sends nothing. This is the project's at-most-once discipline
(record-before-send, as notify-and-inbox's wake rule states): a crash between the two loses the knock
(visible in `watchdog.log`) rather than duplicating it. Under standby the record is **not** written, so
the death is still unreported and a later tick reports it exactly once — deferral, not loss. `normal`
never records and never knocks.

The readable-source condition is a deliberate boundary (for the PM's review): a stopped seat with **no
readable evidence at all** is still classified and surfaced as `unknown`, and the pending summary names
it (`停了的 agent N（dev=unknown）`), but it produces no dedicated second knock — the specific knock's
value is the cause and the raw line, and with no source there is nothing to carry beyond what the
standing wake line already says. This also keeps the change from firing a new knock on every fixture (or
half-dispatched seat) that merely has a task and no window.

The pending summary keeps working: `team_pending_text` gains the `dev=quota, dev2=unknown` list from the
same reader for the stopped population, so the existing `[pulse] 待办：…` line (and the digest [1] 待办
line) carries the reason, and the existing PM-start path still fires on a death alone (the `stopped`
count is unchanged). Reader failure degrades to today's bare `停了的 agent N` — a cause must never break
the patrol.

### D7 — The visible surfaces, and exactly what each carries

| Surface | Shape | Why |
|---|---|---|
| `team status <ID>` | after the existing seat condition/scene block, one `原因：<category>（来源：<pane|session|recorded> · <time>）· 原文：<raw line>` line; no block when no abnormal death | the PM's diagnostic surface; carries the raw line and the source |
| `team digest` [1] | `待办 … 停了的 agent N（<seat>=<category>, …）`; bare count when no cause is readable | the wake-reason surface the user's screenshot showed as cause-less |
| agents block (`team __panel-data --block agents`, `team monitor --json`) | `cause`, `cause_source`, `cause_line`, `cause_time` keys on an abnormal death only; `state`/`pane`/`pane_exit` unchanged | machine-readable without a human render (P55's pattern) |
| printed panel agent table | the state cell appends ` · <category>` (`▲ 已死 signal=9 · quota`); the minimal layout may drop it with the state text | "能塞就塞"; the JSON and `team status` keep the full line |
| death knock | `[pulse] 席位 <seat> 死了：<category>（来源：<source> · <time>）· 原文：<raw line> ｜ 现场：team status <ID>`; for unknown the category is `unknown` and no cause is named | one report per death (D6), raw line included, nothing invented |

`team roster` and `team doctor` are deliberately not in the table: their existing lines and assertions
stay byte-stable (roster's `^p55w +▲ 已死 signal=9` regex is the pinned shape), and the brief names only
status/digest/panel.

### D8 — The panel's JSON is the contract; the bundle is rebuilt, not hand-edited

The agents block is produced in `lib/cmd-watch.sh` (`team_panel_agents_json`), so the four keys are a
bash change. The printed token is `panel/src/layout.ts`'s `agentStateText` (the state cell) plus the
`PanelAgent` type; `panel.js` is committed and the gate's `26-a` rebuilds it byte-identically, so the
apply must run `bun install --frozen-lockfile && bash skills/teamsmith/scripts/panel/build.sh` and
commit the rebuilt bundle (or the gate's `cmp` goes red). The minimal layout's degradation rule stays
exactly as it is; the cause follows the state text.

### D9 — Knobs, bounds and dependencies

`TEAM_DEATH_SCAN_LINES` (default 40, non-numeric → 40) bounds the pane-side tail; the session tail is
64 KiB like the activity read; the raw line is capped at 300 chars. No `jq`/python/node requirement in
the CLI path (awk/sed only — the repo's rule); no new file under `.pi/team/` other than
`state/deaths.log`.

### D10 — What must not move

M6.5's liveness proof, D7's "a retained window is an anomaly only while its task is unfinished" rule,
the exact `stopped` count semantics, the roster/doctor lines, the `[auto·interrupted]` tag, and the
`team_pending_text` sig (cause changes do not re-arm the batch rate limit; the knock is the carrier).
The one existing exact-equality assertion that must change (`停了的 agent 1` → `停了的 agent 1（…）`) is
updated in the same commit as the feature, with the new expected text — never by deleting the assertion.

## 4. Shapes the apply must implement (contract for the implementer)

| Element | Shape |
|---|---|
| reader | `team_seat_death_fields <agent>` → `category⇥source⇥record-time⇥raw-line`, or empty (no abnormal death). Read-only, bounded, degrades to empty on any internal failure |
| classification core | `team_death_classify_line <line>` → category or empty; the frame test and the D3 precedence table live here alone |
| session reader | `team_agent_session_latest <agent>` (newest JSONL, sid-aware incl. `--fresh`), `team_session_error_line <file>` → errorMessage + timestamp or empty |
| display helpers | `team_seat_death_text <agent>` (the status fragment), `team_stopped_deaths_text` (`dev=quota, dev2=unknown`), `team_death_knock_text <agent>` (the knock payload) |
| patrol helpers | `team_death_record_seen <identity>`, `team_death_record_add <seat> <category> <source> <anchor> <identity> <raw>`; `state/deaths.log` per D5 |
| digest [1] | `待办 … 停了的 agent N（dev=quota, dev2=unknown）`; the parenthetical is omitted when no cause is readable; exact-string assertions updated, not removed |
| status seat block | the D7 line, appended to the existing `座位 <agent>：…` block; printed only when a cause exists |
| agents block | the four keys per D7/D8; absent on seats without an abnormal death; `state`/`pane`/`pane_exit` untouched |
| panel row | `agentStateText` appends ` · <cause>` when the cause is non-empty; the type gains the optional fields; `panel.js` rebuilt |
| knock | outbox `knock` entry, `--from pulse`, `--dedup death:<identity>`; payload per D7; enqueued only after the record (D6) |
| records | one line per identity, append-only, last-500 bound; never read by a writer; never deleted by a restart |
| knobs | `TEAM_DEATH_SCAN_LINES` (default 40); fixture switches, if any, are `TEAM_SMOKE_FIXTURE`-gated like the existing ones |

## 5. Coverage

| Requirement (delta) | Decisions | Apply items |
|---|---|---|
| `watchdog#A seat death has a classified cause from a closed set, and an unknown death is never given one` | D1–D4, D9 | 1.1–1.4 |
| `watchdog#A cause belongs to the current launch of a seat, never to a previous one` | D5 | 1.5, 3.3 |
| `watchdog#The seat surfaces name the cause, its source and the raw evidence line` | D7, D5 | 2.1–2.4 |
| `watchdog#The patrol reports each abnormal death exactly once, and never a normal one` | D6 | 3.1–3.5 |
| `notify-and-inbox#A seat-death knock carries the seat, the cause and the raw evidence line, and never invents a cause` | D6, D7 | 3.2–3.3 |
| `panel#The agents block carries each seat's death cause` | D7, D8 | 2.5–2.6 |

## 6. Risks / trade-offs

1. **[A false `unknown` knock for a readable but unrecognized death]** — e.g. a non-Pi adapter that
   exits non-zero with its own wording. `unknown` is the honest answer and the knock fires (the death is
   real); the trade-off is noise, not a lie. A stopped seat with no readable evidence gets no dedicated
   knock at all (D6), and the clean-exit rules (D4) remove the common fallback case.
2. **[A lost knock when the record lands and the enqueue does not]** — the at-most-once discipline's
   deliberate direction (a duplicate wake is worse than a missing one, and `watchdog.log` + the pending
   line still carry the death). Stated, not hidden.
3. **[Pattern rot: a provider rewords its error]** — the category goes `unknown` (visible, reportable)
   rather than wrong; the D3 table is one function and the fixtures pin each row, so adding a wording is
   a one-line fixture-verified change.
4. **[The reader's cost on a hot surface]** — only stopped seats are classified, the pane capture is the
   same one the scene reader already performs, and the session read is a bounded 64 KiB tail; the digest
   and panel call it for the stopped population only.
5. **[The `--fresh` session lookup is a second implementation]** — the classifier's
   `team_agent_session_latest` duplicates part of `team_session_file`'s intent; D2 keeps it separate on
   purpose (fixing the shared function would silently change roster/ps numbers). A later change may
   unify them.
6. **[The panel bundle rebuild needs bun and the lockfile]** — `26-a` already rebuilds and byte-compares
   in a sandbox; if the environment cannot build, that is a hard blocker in the apply's report
   (`BLOCKED:`), never a hand-edited bundle.

## 7. Apply boundaries, grants and sequencing

- One apply brief is recommended: the mechanism is one reader plus thin callers, and three of the
  callers live in the same two bash files (`cmd-watch.sh`, `cmd-status.sh`); splitting it would put two
  writers on one file. One independent `opsx-verify` brief follows (a different agent).
- Grant (OWNERSHIP): `skills/teamsmith/scripts/lib/**`, `skills/teamsmith/scripts/panel/src/**` +
  `skills/teamsmith/scripts/panel/panel.js` (rebuilt), `skills/teamsmith/tests/**`, and the change
  directory's `tasks.md` checkboxes. Everything else — `openspec/specs/**`, `docs/team/{tasks,BOARD,
  ROADMAP,DECISIONS,OWNERSHIP}.md`, `extension/**`, `references/**` — stays PM-owned; a need there is a
  `BLOCKED:` report, not an edit.
- The fixture lives in `skills/teamsmith/tests/death-cause.sh` (standalone, like `gate-guard.sh`), with a
  FAST pure-logic portion (saved-corpse files, session JSONL files, `state/deaths.log`, the surfaces) and
  a live-tmux portion (one real corpse frame) that skips visibly without tmux; the smoke suite gains a
  section that calls it.
