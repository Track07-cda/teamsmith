# Troubleshooting (hard-won lessons)

Run `team doctor` first; then look at the extension log with `tail -f $(grep TEAM_NOTIFY_LOG .pi/team/config.sh)`.

---

## 1. The PM never receives an agent's "turn ended" notification
> On a real TUI, delivery is confirmed by the payload leaving the input box **and** appearing as an echo bubble in the conversation area (V10-F1): a cleared-but-unsent draft never counts as delivered, and an unconfirmed entry is never deleted (it moves to `held/` with a durable copy).


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

## 3. Notification text used to get glued to what the PM is typing

**There are two delivery channels (M30), and only one of them can touch a box.** A **built-in Pi session**
(worker or PM) that loaded `extension/team-inbox-watch.ts` receives team messages through the **inbox-watch
channel**: the sender writes the durable inbox line and appends one pointer line to
`state/inbox-watch/<key>.wake`; the session's own extension reads it and calls
`pi.sendMessage({customType:'team-inbox'}, …, {triggerTurn:true, deliverAs:'followUp'})`, which enters the
conversation like a queued follow-up. The input box is never read and never typed into. Every other target —
a custom adapter, a Pi session started without the extension, a registration whose pid is dead or whose cwd
is another project — takes the **delivery guard** below, which is the only code allowed to type into a pane.

The Pi channel exists because five draft-race incidents (2026-09, all on real Pi 0.85.1) showed that the box
heuristic cannot be made reliable enough: D20 is where the guard came from (an automated message glued onto a
human's draft); in M17 a payload was judged to have raced a draft while the PM had in fact just finished a long
gate and its box was empty; in M24 a knock sat in an idle PM's box overnight while the 28 pulse nudges that
followed were held behind it; and the same class of failure came back after each fix — the fifth incident, with
a plain 460-code-point payload, is what triggered the channel change (M30). The user's call was to stop patching
the detector for the Pi path and change the channel instead. The guard stays for every target that has no
extension API to watch a file.

Readiness is **evidence, not configuration**: the extension writes `state/inbox-watch/<key>.reg`
(`target=<session>:<window>`, `inbox=<name>`, `pid`, `cwd`, `heartbeat`). A sender routes to the watch channel
only when a registration matches that exact target, its pid is alive and its `cwd` is inside this project — a
fresh `heartbeat` is only the fallback when `cwd` is missing (bounded by `TEAM_INBOX_WATCH_STALE`, default
300 s), because a heartbeat is not an identity. So "this is a Pi session with a watcher" is proven by the
session itself instead of guessed from `TEAM_AGENT_CMD`.

Honest edges of the Pi channel (visible, never silent):

- **A wake is not "read".** The wake is queued into the session; if the session dies before it reaches the
  model, nobody is woken — the durable inbox line and its unread count are what the pulse picks up on its next
  tick, exactly as before. The channel never claims a delivery it cannot see: `team say` reports
  `pi 监视通道` (`watched`), never `已确认送达`.
- **A session restart re-baselines the wake spool.** Lines written *before* `session_start` never wake anybody
  (otherwise every restart would replay history), and a line written during a reload gap is not woken either;
  both fall back to the pulse.
- **The wake carries a pointer, not the payload**: kind, sender, inbox file and a truncated preview
  (`TEAM_INBOX_WATCH_PREVIEW`, default 160 chars). The full text stays in the inbox; a burst merges into one
  message and at most five lines are listed (`… and N more`).
- **The follow-up is delivered at a safe point.** `deliverAs:'followUp'` waits until the agent has no pending
  tool calls, so a wake never interrupts a running tool call; that is pi's own queue, not a new polling loop.
  The extension's ledger (`state/inbox-watch.log`) records `started` / `wake n=…` / `stopped` lines.

**The delivery guard** (the paste path) locates the target pane's input box before typing and reads **every content row
of the box** — including rows below the cursor, because a draft typed after a leading newline or recalled with `Up`
sits below the cursor row. If the box already holds text, the sender writes **no key at all**: the message goes
into `state/outbox/` as one immutable entry and is delivered when the box is free (`team outbox list` shows what is
waiting, `team outbox flush` drains it, and every watchdog tick drives one drain as well). A message that was held
is reported as **`queued`**, never as delivered.

What this means for you:

- On a built-in Pi session the box question does not arise: messages land in the inbox and wake the session.
  The queue below is what a non-Pi target, a Pi session without the watcher, or the explicit escape hatch uses.
- Keep typing. Your draft stays in the box; the notice waits outside it.
- If the queue bothers you: `team outbox drop <n|all>` discards entries, and `team status` / `team digest` print one
  `outbox …` line as long as anything is waiting (nothing when it is empty).
- `team say <agent> "…" --now` (and `team outbox flush --now`) deliberately types into a non-empty box — that is
the old behaviour on purpose, and it appends one line to `state/outbox/forced.log`. Use it only when you really
  want the text glued.
- The human entry point is `team draft pm`: an editor window on `state/draft-pm.md` (nothing automated ever types
  into it); saving and quitting enqueues the file through the same guarded path and prints the acknowledgement in
  that window. `team draft send <file>` is the headless form of the same thing.

Honest edges (documented, not hidden):

- **A whitespace-only draft is one known miss, and it is not the only one.** The guard reads the pane, and
  `tmux capture-pane` trims trailing blanks, so a box holding only spaces looks empty and the message is
  delivered (i.e. glued to your spaces). The same class of hole — a dirty box read as empty — has these members,
  so this list, not any absolute claim, is the boundary: equal-width draft rule rows (a pasted separator clipped
  to the pane width, or a table border) and spinner-shaped draft rows are **fixed** (the top border is the
  highest qualifying row, so such a row is content and the box reads busy; V9-A4/A5/A8), a cursor resting on the
  draft's own equal-width rule row is **fixed** (the bottom border is searched strictly below the cursor row;
  V9-A10), and **still open** are the whitespace-only draft and a single-line draft sitting exactly on the hint
  slot (V9-C3, see that bullet).
- **Confirmation means the payload left the box AND the conversation shows a new copy of it (V9-B5).** After the
  `Enter` the drain reads the box back AND counts the payload's signature in the conversation area above the box
  (first non-blank line, whitespace-stripped, compared byte-wise, or a `[paste #N +K lines]` bubble whose `+K`
  matches the payload's line count): more copies than before typing = delivered. **An empty box alone is not
  proof** — a TUI can swallow the `Enter` (overlay, escape handling, redraw), clearing the box while the message
  never reaches the conversation; an older version of this guard reported exactly that shape as delivered and
  deleted the entry (zero submissions, no inbox row — the message was silently lost). Now such a send is
  reported **unconfirmed** and the entry goes to `held/` **immediately** (not after the TTL) and is **terminal** —
  never pasted a second time, `flush --now` included. A TUI that never echoes submissions (static footer)
  degrades honestly the same way: the `Enter` did land once, the tool just cannot prove it — the held entry and
  its durable inbox copy are there for you to verify and `team outbox drop`.
- **The hint row is excluded by slot, and that slot is a known miss.** The row immediately above the bottom
  border is assumed to be the package's chrome (the ` k3  Kimi Coding  max` hint) and is never read as content.
  Two honest consequences (V9-C1/C3): (a) if the hint row is bumped OFF that slot (e.g. a blank row appears
  beneath it), the box reads **busy** — a conservative false-busy that holds the message, never a glue; (b) a
  **single-line draft sitting exactly on that slot is invisible** — the box can read empty and a send may glue
  onto it. Any draft of two lines or more, or a single line on any other row, is caught. This is geometrically
  forced without matching the hint's text, which varies across Pi versions.
- **Giving up the `Enter` never leaves our text in your box (M17).** When the pre-`Enter` re-check cannot
  confirm that the box holds only our payload, the drain first asks one more question: does the box hold *only*
  what we typed? Verbatim, a single `[paste #N +K lines]` placeholder whose `+K` matches, the prefix/suffix
  display window, an empty box, or the whole box being our own half-rendered placeholder frame all count as
  ours — then the drain clears it with Pi's own editor keys (`ctrl+a` line start + `ctrl+k` delete-to-line-end /
  join-next-line, repeated; independent of where the cursor sits, and an idempotent no-op on an empty box) and
  verifies the box ended up empty before holding the entry. The outcome is recorded in the hold reason:
  `draft-raced-retracted` means nothing of ours is left in the box. If anything else is in the box — your draft,
  a second folded paste, an unreadable box — **not one key is sent** (leave it, never delete it) and the hold reason is
  `draft-raced-left`: our payload may sit in the box next to your text, exactly as before, and the log line says
  `框里已有人的内容，未动`. Both are **terminal**: the payload reached the box once and may have ridden your own
  `Enter` to the agent, so no automatic path, `flush --now` included, ever pastes it again; the entry stays in
  `held/` until you drop it or re-send the content yourself. `team status` / `team digest` show the split on their
  `outbox …` line (`held N：已收回 X · 留在框里 Y`), and `team outbox list` plus the panel's queue page show the
  per-entry reason.
- **The retraction keys are Pi's bindings, and the retraction is verified.** The clear uses the editor's own
  `ctrl+a`/`ctrl+k` semantics (Pi 0.85.1). On a TUI that binds them differently the clear may not take effect;
  the drain reads the box back and, if anything is still there, reports the hold as `draft-raced-left` (residue
  in the box) rather than claiming a retraction it cannot see. The window between the “box holds only ours”
  read and the clear keys is one command wide — same class of residual window as check → type, documented here
  rather than hidden.
- **Rule-looking rows inside your own draft are not borders.** A pasted markdown separator or table border is a
  `─` row; the guard pairs the bottom border with the **highest** qualifying row above it (a full-rule row of
  equal width, or the E3-era spinner shape), so a short draft rule row — and also an equal-width or wider one
  (V9-A4/A5/A8/A10) — counts as box content and the box reads busy. Two documented costs: on a TUI that **clips**
  long lines to the pane width, an over-long draft line can read as an equal-width rule row and enlarge the located
  box (the verdict errs to busy, never to gluing; real Pi 0.85.1 wraps one column short of the border width, so
  the shape is unreachable there); and the `── ␣…`-plus-long-trailing-rule shape is accepted as a top-border
  candidate on purpose (it was measured on the E3 Pi), so a draft line with that exact shape reads as box content
  and the box reads busy — never as a border. The working row of Pi 0.85.1 is a different shape altogether
  (` ⠋ Blanching… · 0s`, braille glyph plus text, drawn on its own row **above** the box, top border still a full
  rule): it is not a border candidate, tier1 keeps locating the box, and if a future TUI ever moved that row into
  the border position the pairing would find no box and the pane would be typed as today with one warning
  (V9-D2) — never a silent hold.
- **Folded pastes are checked by shape, not by stripping.** The box counts as "only ours" when it holds exactly
  ONE `[paste #N +K lines]` placeholder whose `+K` equals the payload's line count. Two folded pastes (yours and
  ours) always count as a race (V8-N4). Residue: if your own paste folded with the same line count as ours, the
  two are geometrically indistinguishable — but then your payload is visible in the box, and you are holding the
  pane.
- **Half-rendered frames are waited out.** While the TUI is still drawing a folded paste (`[paste #N +1` without
  the completed placeholder, occupying a whole line), the guard neither settles nor calls it a race — it waits
  (about a second, bounded) for the render to finish (V8-N3). The test matches a whole line, never a substring,
  and the payload itself is checked verbatim first — so a message whose own text contains `[paste #` delivers
  normally (V8-N2/V9-B1). If the wait is exhausted while the frame is still half-drawn, the payload is
  **retracted** (the whole box is our own half-frame, so the clear keys are safe) and the entry is held as
  `draft-raced-retracted`; if anything else appeared in the box by then, not one key is sent and the hold is
  `draft-raced-left`.
- **Two narrow acceptance windows, on purpose.** (a) When the visible box holds only a prefix/suffix of the
  payload, the re-check accepts it (scrolling and truncated display windows look exactly like that; V8-N6). If
  an `Enter` lands in that window while the paste is still arriving — yours or the drain's own — a partial paste
  can be submitted; the submission is not credited as confirmed (no new conversation copy), so the entry is held
  as `unconfirmed` and never re-pasted, with the full payload in its durable inbox copy — nothing is silently
  deleted, the affected entry is visible and can be re-sent (V8-N6/V9-B3; V9-C5 measured the drain's-own-`Enter`
  branch: the entry is held, not deleted).
  (b) Notification-shaped text inside the conversation transcript could in principle be misread as
  box content if the borders were mis-paired (V8-N5) — measured: when a spinner-shaped row stands in as the top
  border, conversation text below it IS read as box content and the verdict is **busy** (a conservative hold,
  not `UNKNOWN`; V9-C2), while a transcript without any rule-looking row simply pairs no box and fails safe to
  `UNKNOWN`.
- **A pane whose input box cannot be located** (a non-Pi TUI, a theme that breaks the geometry) is treated as
  "deliver as today" plus one warning line — never as a permanent hold, and nothing is queued for it. Because no
  box can be read there, no submission proof can be collected either: such a delivery is reported as
  **unknown-shape, unconfirmed** (`输入框形状未知：按旧行为投递`), never as `已确认送达` (V9-C3).
- **Check → type is not atomic.** The guard re-checks immediately before typing and again (by fingerprint) before
  pressing Enter, and holds the message when a draft appeared in between; the residual window is one command wide
  (no retry loop).
- **A stalled render is retracted, not left in the box (M17; this supersedes the V9-B6 recovery).** When the TUI
  draws a folded paste slower than the bounded wait, the drain sends no `Enter`, clears our half-drawn placeholder
  back out of the box, and holds the entry with reason `draft-raced-retracted` — terminal, because the payload was
  in the box once and any later automatic paste could double-send. An entry an **older** teamsmith already held
  with reason `stall-timeout` (the payload still in the box as a completed `[paste #N +K lines]` placeholder) is
  still finished by the next drain: it presses the single missing `Enter` while the box holds only that payload
  and never pastes it again; if the box no longer holds only the payload, the entry stays in `held/` for you to
  verify and drop or re-send.
- **Expiry holds, it never types:** after `TEAM_DEFER_TTL` (default 300 s) an undeliverable entry moves to
  `state/outbox/held/` with a line in `state/outbox/HOLDING.log`, and a later drain still delivers it once the box
  clears (unless its reason is `draft-raced-left`, `draft-raced-retracted` or `unconfirmed`, which are terminal). The payload is always already durable in the
  recipient's inbox (or `state/nudges.log` for a wake) by the time the hold completes, so an expired hold can
  never lose a message — and a delivery the drain confirmed never appears in the inbox at all.

If a notification really did get glued (e.g. the whitespace-only case), the mitigations from before still apply:
answer with a short sentence right after reading it, lower the volume with `TEAM_INBOX_MAX_CHARS`, or set
`TEAM_NOTIFY_TMUX=0` and read `team digest` yourself — or run that session on a built-in Pi launch path, where
the box is not part of the delivery channel at all.

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
| the agent still carries another unfinished task | the stacking guard: `state/<agent>.env` records task X, X has no non-`FAIL` review record, its branch tip is not in the protected branch and the board is not `done`/`closed`/`dropped`, while the worktree sits on a task branch | finish X first (`team resume --agent <a>`, then verify/merge) — or take the window over on purpose with `--force`; see 4e below |
| the task id matches more than one brief | two files `docs/team/tasks/<ID>-*.md` (a title change created a second slug); the branch name would come from the stale one | rename/remove the stale brief or give it its own id: dispatch refuses instead of picking one by glob order |
| the launch could not be confirmed | the pane never wrote the per-attempt launch proof, so tmux/the pane swallowed the command | see 4b below |
| the harness started but the agent exited immediately (`exit=…`) | a **custom adapter** CLI that could not start (missing binary/flag/auth, or a first word the window's login shell cannot resolve) | the CLI's own output, the rendered command and the resolved binary are in `state/dispatch-<agent>-launch-failed.log`; see 4d below |

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
- if the launch proof arrives but the agent has **already exited** (the dispatch prints a warning carrying the
  agent's exit code, and `roster` shows "pi exited"), that is the honest `pi exited` state: `team resume --agent <a>`
  continues the task. That exit code is written by the window harness itself when the agent process returns, so the
  warning does not depend on how long the pane takes to come back to a shell (and `TEAM_DISPATCH_ALIVE_SEC` is the
  time the dispatch waits for that record, not a sleep before a single look at the pane).

### 4c. `digest` says a report is "not committed yet"

The report exists only in the agent's working tree, and the reviewer reads the report from a checkout of the task
branch — so the signal would arrive before it is actionable. The tool therefore lists it as "report not committed
(spelling out that review is not the next step)" instead of pointing at `team review <ID>`; nothing is dropped. Ask
the agent to commit it, and the normal "awaiting review" line plus the review command come back.

### 4d. A worker adapter's CLI never started (`exit=…`)

A dispatch proves two different things, and it now reports them separately: the **harness** started (the per-attempt
spawn proof) and the **agent** started (the exit event `state/dispatch-<agent>.exit`). With `TEAM_AGENT_CMD` set, an
immediate **non-zero** exit is a failed dispatch — it prints `派单失败：harness 起来了，但 agent 立刻退出了（exit=<code>）`,
leaves the window in place (the CLI's own error stays on screen) and writes
`state/dispatch-<agent>-launch-failed.log`: the rendered command, the resolved executable, the exit code and the
window's last non-blank lines (captured by the harness the moment the CLI exited, so a shell that clears the screen
does not erase it). Nothing is recorded against the task — `roster` will not show it as running the task.

Common causes: the template's first word is a bare name that does not resolve on the caller's `PATH` either (dispatch
refuses that earlier), `TEAM_AGENT_BIN` names a different binary than the template runs, the CLI's flags/auth are
wrong, or a wrapper script is missing. Reproduce by hand with the `render :` line in the diagnostic. `exit=127`
means "command not found" *inside the window's login shell*; `exit=1`/`exit=2` are usually the CLI rejecting its
arguments. An adapter that exits **0** right away is not a failure: script-style CLIs finish and exit, and dispatch
says so.

### 4e. `team dispatch` refuses because the agent still has an unfinished task

This is the guard for the D16 accident shape: one agent carried M9.2 while the PM dispatched P2 to the same agent,
which replaced the window/session and forced a hand-over. The tool knew the agent's task and branch the whole time.
Now, before starting anything, dispatch reads `state/<agent>.env` (the task the agent was dispatched for), the board
row for that task and the branch the worktree is on. If that task is another id and it is not finished — no non-`FAIL`
review record, its branch tip is not an ancestor of the protected branch, and the board is not `done`/`closed`/
`dropped` — the dispatch is refused (before any window is touched) and the refusal prints the task, its board status,
the branch the worktree is on, why the task still counts as unfinished, and the two ways forward:

```bash
bash <skill>/scripts/team resume --agent dev            # finish what is already there (then review/merge)
bash <skill>/scripts/team dispatch dev T2.1 <brief> --force   # take the window over on purpose
```

`--force` is the explicit override: the dispatch output states what it covers (which task gives way) and
`state/watchdog.log` gets an audit line, so an intentional takeover is never silent. It covers **only** this refusal —
a worktree still parked on the old task's branch is refused by the branch-identity guard (F16), which is a different
problem: move the worktree to the new task's branch with git first. Two paths are deliberately not refused:
re-dispatching the agent's **own** task (that is `resume`, not stacking) and any previous task that is reviewed,
merged or decided by the board. When the state cannot be determined — no `state/<agent>.env`, an empty `task=`, no
worktree, a detached/unreadable branch — dispatch proceeds and prints one line naming the missing signal; it does not
guess. A dispatch whose id matches two briefs is refused for the same reason (`docs/team/tasks/<ID>-*.md`), with both
paths listed: clean up the briefs instead of letting glob order choose the scope.

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
- **A live fixture sleeps instead of waiting for the state it asserts**: the same class has now cost M7.2, M7.5 and
  M9.7. A fixed `sleep` followed by one sample of `team_pm_state` (or of a log file) turns a nondeterministic
  transition into a fake red: §11b3's `attempts 行带决策证据` failed because a freshly recreated window was still
  `unknown:zsh` when the watch sampled it (the old `make_pm_idle` polled `pane_current_command` and then slept
  0.5 s), and §11i-D's squash heuristic lost one run in ~8. `tests/smoke.sh` waits with a deadline for the real
  condition instead (`pm_state_until`, `pm_state_until_not`, `wait_session_gone`, `wait_window_gone`,
  `d43_digest_until`) and names the last state seen on timeout. Two rules: when the condition involves a freshly
  created tmux pane, require it to **hold** (two samples ~0.5 s apart) — the instant right after `new-window` can
  report a false `idle:*` before the pane has exec'd its command; and never let the wait replace the assertion's
  failure path — a persistent regression must still be red, just later and with better evidence.

## 11. Keep-alive and liveness decisions

- **How "the PM is running" is decided**: only a **proof** counts (M6.5). The PM is running when either
  ① this tool started it and `state/pm.pid` still points at a live process whose cwd is inside the project, or
  ② the process in the PM window is the configured agent binary (resolved the same way `dispatch` resolves it:
  `TEAM_AGENT_BIN` > first word of `TEAM_AGENT_CMD` > `TEAM_PI_BIN`) and its cwd is in the project.
  Everything else is reported as `foreign:<cmd>` (the occupant's cwd is not this project: `team up` refuses to
  overwrite it unless `TEAM_REPLACE_FOREIGN_PM=1`) or `unknown:<cmd>` (cwd is inside the project but it is not the
  agent: a just-created pane, a `sleep`, an editor). `unknown` is **not** a PM, so it never suppresses starting one —
  `team up` replaces it and says so. `pulse status`, `ps`, `digest` and the monitor panel use the same proof, so
  no surface prints "the PM is running" without it.
  Why this is strict: the old rule ("the window exists and its foreground process is not a shell") reported a
  *just-created* pane — where `pane_current_command` is still `tmux` — as `running:tmux`. `team up` then printed
  "PM is running" without starting anything, `pulse status` repeated it, and the project's own smoke suite went
  from green to 7 failures after the machine restarted. Status is a promise: a liveness signal that is inferred
  instead of proven hides the exact failure the tool exists to surface.
- **A shell wrapper still counts as the PM**: `team_pm_state` looks at the pane's own process *and* its direct
  children and matches any word of the command line against the agent binary, so `bash /path/to/pi …`
  (or a Pi started through a login shell) is recognised as the agent. A child that is *not* the agent does not make
  the window a PM.
- **team up respawns the PM window's pane**: only when no PM is running there — an empty prompt (`idle`) or a
  non-PM process whose cwd is inside the project (`unknown`). Do not treat the PM window as a normal terminal; to
  start working manually, re-run the agent in that window or simply let the pulse bring it up.
  Note: the agent is the pane's own process (we `exec` it), so when it exits the pane closes and the window
  disappears — exactly the `missing` case the pulse reports (corresponding to the `TEAM_PULSE_REBUILD_TMUX`
  switch). After a successful start the pid is written to `state/pm.pid`, which is what makes a later
  "is it still alive?" question a fact rather than a guess (the read-only commands only read it).
- **Typing only happens when something is really running**: `say`/`notify`/the extension refuse when the target window
  sits at an empty prompt (otherwise the text would be executed by the shell as a command) and only write the inbox
  for the PM to read later.
- **What the pulse actually manages**: it recomputes the pending work on a timer (unread notifications / reports
  awaiting verification / board todo·wip / blocked / agents with an unfinished task that stopped), and **only wakes the
  PM when there is pending work** (nudge it while running; `pi -c` when it is not). With nothing pending it does
  nothing at all.
  It will not resume agents for you, does not create tmux sessions/windows (unless `TEAM_PULSE_REBUILD_TMUX=1`), and
  does not merge code.
- **The PM keeps being woken / does not want to be woken**: `team standby on --reason "…"` deliberately stands the PM
  down (both "there really is nothing to do without a human" and "stuck waiting for someone" qualify); `team standby
  off` resumes. While on standby the backlog is still recorded in `state/watchdog.log`.
- **Wake-up frequency**: every 15 minutes by default (`TEAM_PULSE_INTERVAL=900`, 300~3600 recommended); repeated
  reminders for the same pending work are limited by `TEAM_PULSE_NUDGE_GAP`. To go slower or faster, change these two
  values.
- **The PM was "woken twice"**: the instant notification at the end of an agent's turn (the notify extension) and the
  pulse's timed reminder are two different things — the latter is a fallback for unprocessed pending work. Handle
  or ack the pending work and it stops.
- **The pulse says "PM not found (missing) … run team up manually"**: the tmux session/window is gone (you closed
  the window, the machine rebooted) and by default it does not touch tmux. Fix it with `team up`; to have it handle
  this itself, set `TEAM_PULSE_REBUILD_TMUX=1`.
- **A stopped agent is not resumed automatically** (by design): the PM looks with `team resume --dry-run` and then
  resumes with `team resume`; a human can also do `team up --agents` to bring them along in one go.
- **The PM was starting and the pulse stayed quiet**: that is deliberate (M7.2). Between `respawn-pane` and the
  start's evidence, the PM pane is a shell running the start command, not a PM. `state/pm.pid.starting` marks that
  attempt and every surface reports `starting:<age>`; a tick that sees it logs `PM 正在启动 → 不重复拉起` and neither
  starts a second PM nor counts a restart (a second `respawn-pane` would kill the PM that was coming up, and the
  quota would count one start twice). If the window stays in `starting` for longer than `TEAM_PM_START_WAIT + 5s` the
  marker has expired — run `team up` again; `team pulse status` names the evidence (`pm.pid.starting` age and
  starter, or the recorded pid with its `proof`). The same applies to manual starts: `team up` refuses to respawn
  over a start that is still in flight and says so.
- **"PM restarted N times" but I only saw one restart**: `state/pm-restarts.log` has one line per **real** start
  (epoch, timestamp, evidence). Every attempt (successful or not) is recorded in `state/pm-start-attempts.log`; a
  failed or timed-out attempt is also logged in `state/watchdog.log` with `未计入配额` and consumes no *restart*
  quota, so the restart count is a fact and not a count of attempts. The hourly limit (`TEAM_PULSE_MAX_RESTARTS`)
  applies to the attempts file too — a loop that keeps respawning without ever confirming is refused, and the warning
  names both numbers. Read `watchdog.log` for the decisions and `state/pm.pid.starting` for an attempt that is still
  in flight.
- **The PM keeps crashing**: the automatic-restart quota (`TEAM_PULSE_MAX_RESTARTS`, default 5/hour) stops it and
  warns, so a crash loop cannot drag the machine down; look in `state/watchdog.log` and the PM window output for the
  cause first (common: model quota exhausted, a config typo, a missing dependency).
- **The pulse window of the tmux backend was closed**: reopen it with `team pulse up`; `team pulse logs`
  shows a screen snapshot; when the lower half of the monitor says "no node/bun/tsx on this machine: skipping the agent
  activity stream" → install node or bun (the team status part is unaffected).
- **The pulse itself stopped**: `team pulse status` shows whether the window is still there; `team pulse up`
  rebuilds it (there is only one backend, so there is no container to inspect).
- **Everything is silent after a machine reboot**: the tmux server and its windows are gone → `team up` restores both
  (PM window + pulse window) in one shot; `team pulse up` can start the pulse alone as well.
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

## 14. The PM does not come up with my CLI

`team up` — and the pulse's restart path — starts the PM with `TEAM_PM_CMD`, or with the built-in Pi command
when that key is empty. A custom PM CLI that refuses to start almost always fails in one of these places:

| Symptom | Cause / fix |
|---|---|
| `TEAM_PM_CMD` is rejected with an unknown-placeholder error *before* anything is started | the template uses a token that is not a PM placeholder, or a near-miss such as `{ cwd }`. The PM set is `{cwd}` `{session_id}` `{model}` `{provider}` `{prompt_file}` `{prompt}` `{skill_dir}` `{extra_args}` `{resume_args}`; `{notify_ext}` and `{summary}` are **worker** placeholders and are rejected here |
| the error says the template is blank or multi-line | an adapter template is exactly one non-blank line — the second line would be executed as its own command by the window shell |
| `找不到 PM 可执行文件：<word>` ("cannot find the PM executable") | `TEAM_PM_BIN`, or the template's **first word**, does not resolve on *this* shell's `PATH`. The first word must be a bare executable name: no quotes, no `VAR=…` prefix, no `cd … &&`. A bare name that *does* resolve is fine — teamsmith renders the absolute path into the window command (see the next row) |
| `team up` says `PM 已启动` but the window shows the CLI's own error and `state/pm.pid` stays empty / dies | the CLI started and exited (unknown flag, missing auth, model not available). Read `state/pm-launch-failed.log`: the tool writes the window's last output, the rendered command, the resolved executable and the CLI's exit code (e.g. `exit : 7`) on the failure path, and `team up` then exits non-zero. The window is **not** killed any more, so the CLI's own error stays visible in `tmux attach -t <session>`; the briefing that was passed is `state/pm-prompt.md`. Reproduce the command by hand: `bash -c '. <skill>/scripts/lib/common.sh; team_load_config; team_pm_launch_cmd <main>/.pi/team/state/pm-prompt.md <main>/.pi/team/state/pm.pid.spawn'` in the project root, then run it in a shell |
| `team pulse status` reports `unknown:<cmd>` for the PM window right after a manual start | the foreground process is neither a shell nor the PM binary. Check that `TEAM_PM_BIN` names the CLI you actually ran; a wrapper that starts the CLI as a **child** (no `exec`) is reported this way — see the wrapper caveat in `references/agent-adapters.md` §2. A wrapper that `exec`s the CLI is fine: `team up` then reports `proof=spawn` |
| `team up` cannot find the CLI even though it works in your shell | it is a bare name that resolves on **your** `PATH`, so the tool renders the absolute path it resolved to and the window uses that — nothing to do. If it renders nothing absolute (the name is unresolvable here), set `TEAM_PM_BIN` to an absolute path |
| `team up` exits non-zero and `state/pm-launch-failed.log` says the CLI exited immediately | that is the honest report of a failed start (the window's login shell `PATH` is not your interactive `PATH`; an unknown flag/auth error is the CLI's own). The file also holds the first non-blank lines of the window, so `state/pm-launch-tail.txt` and the pane stay readable |

## 15. A restart lost the PM's context

The PM only continues its previous conversation if its CLI is told to; teamsmith never guesses on the PM's behalf.

| Case | What happens | Fix |
|---|---|---|
| built-in Pi, `TEAM_PM_SESSION_ID` empty | `pi -c` continues the previous session in the main worktree — history kept | nothing (this is the default) |
| built-in Pi, `TEAM_PM_SESSION_ID=<id>` | that session id is continued (`--session-id <id>`) | keep the id stable per project |
| custom `TEAM_PM_CMD`, `TEAM_PM_RESUME_ARGS` empty | the restart is a **fresh** session; `team up` says `这次启动**不延续** PM 的历史上下文` and points at `docs/team/**` + `team inbox` | accept it — the durable record *is* the handoff, and the briefing starts with `team digest` — or configure the resume arguments (next row) |
| custom `TEAM_PM_CMD`, `TEAM_PM_RESUME_ARGS` set but the template has no `{resume_args}` | the arguments are **not** passed; `team up` reports `lost:… 没有 {resume_args}` | reference the placeholder where the CLI expects it, e.g. `TEAM_PM_CMD='codex {resume_args} {prompt}'` (for codex: `TEAM_PM_RESUME_ARGS='resume --last'`) |
| the CLI has its own session store and you restored that instead | teamsmith's `{session_id}` is *teamsmith's* dispatch id, not the vendor's session id | keep using the vendor's own resume flag as above; `team thread <agent> "…"` and `docs/team/**` stay the portable handoff |

## 16. The panel (`team monitor`) does not start, or looks wrong

The panel is a committed Ink bundle (`scripts/panel/panel.js`) run by a JavaScript runtime. Four things explain
almost every report:

| Symptom | Cause / fix |
|---|---|
| `team monitor` exits non-zero with `缺少 JS 运行时` / `JS 运行时版本过低`, and `team pulse up` refuses to create a window | **No runtime is a hard failure, not a degraded panel** (an empty panel reported as success is the false green this project refuses). Install `node` ≥ 20 or `bun` ≥ 1.3, or point `TEAM_JS_BIN` at an absolute path. `TEAM_REQUIRE_JS=0` only downgrades the `team doctor` row — the panel still needs a runtime in every mode |
| `team doctor` fails with `JS 运行时` but `node --version` works in your shell | the window/shell `PATH` is not your interactive one (a runtime installed under `~/.bun/bin` is the usual case). Set `TEAM_JS_BIN=/absolute/path/to/node` (or to bun); `team paths` prints the resolved `js_runner` |
| the activity column appeared and the layout looks more crowded than before | this is the one deliberate default change of the panel rewrite (v1.38.0): `TEAM_MONITOR_ACTIVITY` now defaults to `1`. `team monitor --no-activity` switches it off for one run, `TEAM_MONITOR_ACTIVITY=0` for the project — that restores the pre-v1.38.0 layout exactly |
| the panel renders nothing useful in a plain terminal, a pipe or a `less` session | `TEAM_MONITOR_UI=text` forces the plain-text frame (no escape sequences, no screen clear); stdout not being a TTY already selects it automatically. `team monitor --print` is the same frame as a one-shot observer, and `team monitor --json` is the machine-readable form |
| you edited something under `scripts/panel/src/` and the panel did not change | the sources are never on the runtime path — `panel.js` is what runs. A maintainer rebuilds it with `bun install --frozen-lockfile && bash skills/teamsmith/scripts/panel/build.sh` (needs the network and Bun ≥ 1.3), then commits the regenerated bundle. `node skills/teamsmith/scripts/panel/panel.js --version` and the bundle header name the pinned versions and the build command, so a stale artifact is visible without rebuilding |

## 17. A long task (a gate, a build) has nobody to tell when it finishes

`TEAM_GATES` on a real project can take tens of minutes. Run it inside the agent's turn and the turn is occupied;
walk away and nobody knows it finished.

**Lane 0 · the team's own lane (default on the built-in Pi paths, nothing to install).** Both the worker and the PM
Pi commands load `extension/team-bg.ts`, which gives the session `team_bg_run` / `team_bg_wait`: a detached job
with a bounded `state/bg/<id>.log`, exactly one merged wake-up per batch of finished jobs, silence for harvested
jobs, and one `settled-with-unharvested=<n>` line per turn end in `state/bg.log`. Runbook:
[workflows.md](workflows.md) §E2. There are two lanes, and both ship with teamsmith — the skill never asks anyone to install a third-party plugin.
When the team lane is not available (a custom adapter without `{bg_ext}`), use the tmux-window lane:

| | Lane A · the team's own background lane (`team-bg`) | Lane B · a background tmux window |
|---|---|---|
| What runs | the **agent** starts the job, ends its turn, and is woken when the job exits | the PM starts the command in a dedicated tmux window and reads the tail — or the runner writes one inbox line (`team notify pm --from-file <file>`) when it is done |
| Who gets woken | the bundled extension wakes the agent session that started the job | the PM looks at the window / reads the inbox |
| Cost | none — the extension ships with the skill | one window, no dependency |
| Watch out | the four rules below are what the extension enforces | a stray window is easy to lose: name it, and make it print a one-line verdict at the end (`echo "GATES rc=$? <ID>"`) |

`team doctor` reports which harness this project runs (`harness`) and which plugins the project already carries —
that second row is labelled `已装插件 packages` and is **information, never a recommendation**. The only package
teamsmith asks for is magic-context, and `doctor` checks it on its own row.

Four rules the background lane has to enforce. They come from the failure modes the ecosystem's background-job
extensions wrote down in their issue trackers:

1. **The agent must start the job.** A job a human starts directly does not wake a model turn when it finishes; only
   an agent-side start wakes the agent that is waiting for the result.
2. **Merge the notifications.** Several jobs finishing together must arrive as one notice; one notice per job means
   one extra turn per job.
3. **Deliver when idle.** The completion notice must land when the agent has no tool call in flight (a
   `followUp`-style delivery), not in the middle of one.
4. **Already harvested → say nothing.** If the agent waited for the job, it already has the result; notifying again
   spends a turn on information it has.

That is why the lane is implemented in-house (no third-party package on the team’s critical path), with an
explicit harvest ledger under `state/` (`state/bg.log` + `state/bg/<id>.log`): the rules have to be enforced by the
code that owns the jobs, not by convention.

## 18. tmux isolation: the gate, the "fake isolation" shapes, and the container rule

Every PM/worker window puts `scripts/shim/tmux` first on `PATH` (M36; the grant model was rebuilt in M67). The
shim logs every call to `state/tmux-calls.log` (time, resolved socket, `TMUX`/`TMUX_TMPDIR`, argv, pid/ppid/cwd,
action) and **decides a destructive call by the object it targets**: on the **default socket**
(`/tmp/tmux-<uid>/default` — the server every project on the machine shares) `kill-server` and `kill-session -a`
are always refused (exit 64), and `kill-session`/`kill-window`/`kill-pane` run only when the effective `-t` (last
one wins; `-t x` and `-tx`) names a session that is literally the caller's own `TEAM_SESSION` **and** that identity
is bound to the caller (`TEAM_ROOT` or `TEAM_MAIN_ROOT` resolves to the caller's cwd or an ancestor of it).
Everything unprovable is refused. **No environment variable grants anything**: `TEAM_ALLOW_DESTRUCTIVE_TMUX` is
retired — the shim does not read it, the CLI no longer exports it, it stays in the settings schema as a
non-writable tombstone, and `team doctor` names the residue when a running server's global environment still
carries it. The single in-band escape is the argv token `--teamsmith-allow-destructive`, placed **before** the
subcommand: it is consumed and stripped before the exec, never exported, and logged `act=explicit-flag` (after the
subcommand the same word is data, e.g. a `send-keys` payload). The actions are exactly `pass`, `allowed-owned`,
`refused` and `explicit-flag`. Read-only commands are never refused.

The gate models tmux's **real** resolution, fallbacks included (tmux 3.7: the socket template is the path list
`$TMUX_TMPDIR:/tmp/`, each item env-expanded and `realpath()`-ed, the first usable item wins — M41 measured the
whole matrix). So "I set `TMUX_TMPDIR`" is *not* isolation by itself:

| what the command says | what tmux really does | verdict |
|---|---|---|
| `TMUX_TMPDIR=<dir that does not exist>` with `kill-server` | silently falls back to `/tmp/tmux-<uid>/default` | **fake isolation** — this kills the shared server; the gate refuses (`exit 64`) and names the reason (6th death, 2026-09-19) |
| `TMUX_TMPDIR=<a regular file>` (or a dir with no room to `mkdir`) | errors out before creating a server (never falls back) | no private server either; the gate conservatively refuses — `mkdir -p` the directory |
| `TMUX_TMPDIR=<existing directory>` | `<dir>/tmux-<uid>/default` | real private server; the gate passes it (`act=pass`) |

The safe incantation for destructive tmux work on the host is exactly:

```sh
env -u TMUX -u TMUX_PANE TMUX_TMPDIR=<a directory you already mkdir -p'ed> tmux …
```

Two hard rules follow (2026-09-19: the 6th and the 8th default-server deaths):

1. **Destructive fixtures and probes go into the container**:
   `bash skills/teamsmith/tests/container-tmux.sh -- <cmd>`. The host socket directory is not mounted inside, so an
   unisolated `kill-server` cannot reach the host by construction. On the host only the "private directory already
   `mkdir -p`ed" shape above is allowed, and it must go through the shim's `PATH`; a fixture that probes a
   **refusal or an allowed-owned verdict** against the default socket pins `TEAM_TMUX_REAL` to an argv-recording
   stub, so a wrong verdict executes a shell script and never a server (M67).
2. **Never call tmux by absolute path for anything destructive.** The gate is a `PATH` executable: `/usr/bin/tmux
   kill-server` bypasses both the log and the refusal (the 8th death was exactly that, with an uncreated
   `TMUX_TMPDIR`). `tests/tmux-lint.pl` reds any literal absolute-path mutating call, even when it carries `-L/-S`
   evidence. `command tmux` / `env tmux` are **not** bypasses (they still resolve through `PATH`); a variable holding
   the resolved real binary (`"$REAL_TMUX"`, `${TMUX_BIN}`) is the intended exception and is judged by the normal
   isolation rules.

## 19. A command refuses because of an inherited identity ("the directory owns the identity")

`team` derives the project from the directory it runs in (`--root <dir>` if given, otherwise the cwd): root = the git
worktree, main worktree = its git common dir, project name/session = that project's config. Inherited `TEAM_*`
identity variables (`TEAM_ROOT`, `TEAM_MAIN_ROOT`, `TEAM_PROJECT`, `TEAM_SESSION`) never win over that silently.

Two real incidents on 2026-09-19, same shape: a shell carried **this** project's identity while sitting in another
project's directory. `team up` was refused after resolving the wrong project (the guard held, but the user had to
clean their environment), and a pulse started that way rendered **this** project's board inside the other project —
no guard, no warning, silently the wrong project.

What you see today, and what to do:

| Symptom | Cause / fix |
|---|---|
| `身份冲突被拒：当前目录属于 'X'，而继承的环境指向别的项目` and a refusal to run | the inherited identity names another project. `env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_PROJECT -u TEAM_SESSION team <cmd>` — or `cd` to the project you actually mean. Read-only forms (`team paths`, `--print`, `--dry-run`, `status`, `inbox`, …) always resolve by the directory and print the mismatch instead of refusing; `TEAM_ALLOW_FOREIGN_IDENTITY=1 team <cmd>` runs anyway and records it in `state/watchdog.log` |
| an agent inside its worktree was refused, or `team notify` stopped working in a worker window | it should not: a **sibling worktree of the same project** (the PM's main-worktree `TEAM_ROOT` with a cwd inside `.worktrees/<agent>`) is not a mismatch — the check compares projects (git common dir), not paths |
| a panel/pulse renders another project's board, or `team pulse up` puts the window in the wrong session | fixed by the same rule: windows started by the CLI carry the **destination** directory's identity, and the panel strips inherited identity variables from every child it spawns. If you still see a foreign board, read the panel's own one-line warning (stderr of the pulse window, plus `state/panel.log`) — it names the ignored value |

## 20. The same inbox wake arrives twice (replayed messages)

**Symptom**: an agent (usually the PM) gets the same “N new team message(s)” wake more than once within
seconds, and `state/inbox-watch.log` shows consecutive `wake n=42 …` lines with identical `kinds=` while
`total=` jumps by the whole batch each time.

**What happened**: the watcher's spool (`state/inbox-watch/<key>.wake`) **shrank** underneath it — something
outside the repo truncated/rewrote/replaced the file (an editor save, a sync tool, a manual cleanup). Every
in-repo writer appends (`>>`), so a smaller file is always external. Before M43 the watcher answered a shrink
with a silent `offset = 0` and re-read the whole file: one external rewrite = one full replay.

**Since M43** this is bounded and auditable, and repeats are impossible: the shrink itself gets a ledger
line, a rescan from 0 drops anything already delivered (dedup memory persisted in `<key>.seen`, surviving
restarts), genuinely-new lines are capped to the last `TEAM_INBOX_WATCH_REPLAY_MAX` (default 20) with the
skip counts stated in the wake text, and an all-duplicates rescan sends **no wake** at all. `total=` counts
real deliveries only. Semantics and ledger formats: `references/agent-adapters.md` §4a.1.

**If you still see duplicates**: check the ledger for `spool shrink` / `rescan` / `dedup` lines — they tell
you exactly what was re-read, suppressed, and delivered. No such lines + duplicates = a second watcher is
registered for the same target (look for two `started target=…` lines without an intervening `stopped`,
i.e. a zombie session that never logged its shutdown).

**A repeated shrink with nothing delivered is a defect, not a busy spool.** When the ledger shows
`spool shrink …` again and again while `rescan … deliver=0`, the offset is not converging — that is the
2026-09-19 shape (a byte-wise preview cut writing an invalid line, plus a decode→re-encode offset that
overshot the file size by one byte). The invariants that make it impossible are in
`references/agent-adapters.md` §4a.1b; if you see the pattern again, treat it as a bug in the watcher's offset
arithmetic, not as "the spool is being rewritten".

**Lines that are too old do not wake you.** The durable inbox file keeps them; the wake is skipped
(`classify stale=<n> …`). `TEAM_INBOX_WATCH_STALE_SEC` (default 900) sets that horizon.

## 21. pi announces a new version → the input box reads as BUSY

**Symptom**: a PM/worker Pi pane is idle with an empty box, yet `team say` / `team notify` report **`queued`**
(the message lands in `state/outbox/` instead of the box), and the real-pi fixture says so:

```
✗ M28 容器里跑真 pi 体检：输入框判据 + 收回在真实现场成立（找不到 [RETRACT=ok]）
✗ M28 容器里跑真 pi 体检：空闲空框被判 EMPTY（没被误判成忙）（找不到 [verdict=EMPTY]）
```

The fixture's frame shows why — three lines of chat chrome sit **above** the box:

```
────────────────────────────────────────────────────────────   ← banner DynamicBorder
 Update Available
 New version 0.86.0 is available. Run pi update
 Changelog: https://pi.dev/changelog
────────────────────────────────────────────────────────────   ← banner DynamicBorder
────────────────────────────────────────────────────────────   ← the real box top border
 deepseek-flash  Deepseek  max                                  ← hint row (inside the box)
────────────────────────────────────────────────────────────   ← box bottom border
```

**Cause** (real, not a fixture flake): pi's update banner is drawn into the chat container with
`DynamicBorder`, which renders **the same thing as the box borders: one full-width row of `─`, equal in
width to the pane**. The reader anchors the box by taking the **highest** equal-width `─` row above the
cursor (deliberately conservative: a draft may draw an equal-width rule *inside* the box, and treating that
as the top border would exclude the draft → empty → paste into a non-empty box). With a banner present the
highest row is the banner's opening border, so the box becomes everything down to the bottom border: its
content is the banner text plus the box's own top border → `BUSY` → queued.

**Since M45** the two measured banners are recognized and excluded from the geometry (and from the transcript
the delivery confirmation searches): the block is only accepted when the opening `─` row is followed by the
paired header lines (`Update Available` + `New version … is available. Run pi update`, or
`Package Updates Available` + `Package updates are available. Run pi update --extensions`), the row directly
above the closing equal-width `─` row is the matching tail (`Changelog: …` / a `- <package>` item preceded by
`Packages:`), and the block lies entirely above the cursor. The release note inside the block is arbitrary
markdown and is never matched by content. If skipping the marked rows leaves **no box at all**, the geometry
falls back to the unmarked (conservative) behaviour — never to `NONE`, because `NONE` means the guard is off
and the next paste would land in a human's draft.

**What to do** (none of this is required for the guard to work — since M45 it tolerates the banner):

- Nothing. The banner is cosmetic: the box reader skips the recognized banner blocks, so an idle box keeps
  reading as `EMPTY` while the notice is on screen. The real-pi fixture proves it on the live thing:
  `bash tests/pm-box-real.sh` runs pi **with its update checks on** (the user's call: never suppress the
  notice) and prints `banner=present|absent`, `banner_rows=[…]` (which block rows were recognized) and
  `M45 idle-read=EMPTY`; it exits non-zero when the idle box is not read as empty. `M45_REQUIRE_BANNER=1`
  additionally demands that this run really had a banner, so an evidence run cannot silently degrade into a
  banner-free frame.
- `pi update` if you simply want the notice gone (it is only shown while a newer release exists).
- If you *choose* to silence the checks (nothing in the gate does): **`PI_SKIP_VERSION_CHECK=1`** disables the
  Pi version check (`docs/settings.md`); `--offline` / `PI_OFFLINE=1` additionally disables the extension
  **package** update check (`Package Updates Available`), which `PI_SKIP_VERSION_CHECK` does not cover.
  Neither is used by the fixture — the banner shape is part of what is being tested.

**Honest edge (not covered)**: only these two banner shapes are recognized. Other chrome built from the same
`DynamicBorder` primitive — pi's own post-update **`What's New`** block (a rule, the header, arbitrary
changelog markdown, a rule), extension "custom message" boxes — still enlarges the box and therefore still
reads as `BUSY` (queued, never glued). It cannot be resolved by shape alone: a rule pair with text in between
is indistinguishable from a draft that draws rule lines itself, and the conservative direction is to treat it
as content. The failure mode is a **bounded queue**, not a glued message: messages wait in `state/outbox/`
(`team status` / `team digest` show the line) and go out once the block leaves the frame (it is chat history,
so it scrolls away as the session talks; `What's New` only appears on the first start after an update).
Report such a frame (`bash skills/teamsmith/tests/pm-box-real.sh --keep`) so the shape can be added as a
measured case next to these two.

## 22. Messages are not sent automatically: check the watcher registration first

**Symptom**: `team say`, a web knock or a worker's turn-end notification never reaches the PM (the PM
"looks alive"), and messages pile up in the PM's box or in `state/outbox/`.

**Why this shape exists**: a Pi session receives automated messages through the inbox-watch extension
(`extension/team-inbox-watch.ts`; §3 and `references/agent-adapters.md` §4a). At `session_start` the
extension writes a readiness registration (`state/inbox-watch/<key>.reg`); senders route through the watch
channel only while that registration is alive. Without it, delivery silently falls back to the paste path —
which defers while the box holds a draft and can end in a `draft-raced-left` hold. The fallback itself is by
design; a **silent** fallback is not (M46).

**First three commands**:

| Command | What to look for |
|---|---|
| `team doctor` | the `投递通道 inbox-watch` line — `pass` means the PM's registration is alive, a `!` line names the reason and the restart |
| `team status` / `team digest` | one `投递通道降级: …` line, same reason |
| `team outbox list` | what is waiting; held entries whose target window no longer exists are marked `target=gone` |

The pulse panel shows the same warning as a line under the status band (the `delivery_warning` field).

**Where the reason is recorded**: when the extension skips setup it writes `state/inbox-watch/<key>.skip`
(`target`, `session`, `window`, `expect`, `reason`, `detail`, `pid`, `cwd`, `heartbeat`) and a
`skip setup: …` line in `state/inbox-watch.log`. A record is believed only while the process that wrote it
is alive and its `cwd` is inside this project (cwd missing → fresh heartbeat); a leftover from a dead
process is ignored, and a successful registration deletes the records for its target.

**The two reasons you will actually see**:

- `会话名不符`: the project's `TEAM_SESSION` does not match the real tmux session name (the project was
  copied/renamed, or the PM was started inside a differently named session). The extension refuses to serve
  a session this project does not own; fix the name (rename the session or correct `TEAM_SESSION`) and the
  registration appears on the next `team up` / `team resume`.
- `PM 进程在跑但没有注册（扩展未加载 / 进程启动早于扩展安装）`: the PM's pi process never loaded the
  extension (started without `-e <skill>/extension/team-inbox-watch.ts`, or with an older skill). Restart
  the process (`team up` for the PM, `team resume <agent>` for a worker).

This is not `/reload` work. Pi hot-reloads extensions from its auto-discovery locations
(`~/.pi/agent/extensions/`, `.pi/extensions/`); `pi -e` is a startup argument ("used for quick tests" in
Pi's own extension docs). The teamsmith launch paths pass all extensions with `-e`, so after an extension is
added — or after its startup-time behaviour changes — the session must be restarted. `/reload` still
refreshes the *skill text* (`SKILL.md` / `references/**`); it does not make a missing `-e` extension appear.
An earlier revision of this skill told the reader to wait for `/reload`, which is what kept an ai_interview
PM waiting while its messages silently took the paste path.

**The watcher never treats another project's state as home**: its state directory is anchored to the
project derived from the process's cwd (the git main worktree). An inherited `TEAM_STATE_DIR` that points at
another teamsmith project's state is refused, and the refusal is recorded in the derived project's ledger
(`TEAM_IDENTITY_CONFLICT inherited TEAM_STATE_DIR=…`).

**The slow path is not a dead end**: while no watcher is registered, queued entries are retried by the next
drain (every guarded send, every pulse tick, and `team outbox flush`), so a busy box delays messages instead
of stranding them. Two cleanup exits exist for the leftovers: a held entry whose payload is no longer in the
target box is recorded as `residue-clear … why=box-clear|target-gone` in `outbox/HOLDING.log` by the next
drain (the status line stops claiming a residue that is gone), and held entries whose target window no
longer exists are dropped by the explicit `team outbox drop gone` (it names every file it drops). Nothing
ever re-pastes a `draft-raced`/`unconfirmed` entry — that is terminal by spec; if its payload is still
sitting in a human's box, the human submits or clears it, or drops the entry.

---

### 22b. The watcher registered *unsuccessfully*: the degraded record and the inotify quota (M53)

Registration can fail for a reason outside the project: the host's per-user inotify watch budget is
exhausted (on this box Syncthing and `codium` hold most of `fs.inotify.max_user_watches`), so a **new**
process's `fs.watch` throws `ENOSPC` while already-registered processes keep working. That asymmetry is what
"some sessions receive, some do not" looks like.

**What the failure now leaves behind** (all of it auditable):

| Trace | Where | Fields |
|---|---|---|
| ledger line | `state/inbox-watch.log` | `errno=…`, `watches=<used|unknown>/<max>`, `poll_ms=…`, `fallback=polling`, and `forced=1` when a fixture produced it |
| durable record | `state/inbox-watch/<key>.degraded` | `reason=watch-unavailable`, `errno`, `watches`, `poll_ms`, `forced`, `since`, `pid`, `cwd`, `heartbeat` |

A record is believed only while the writing process is alive and its `cwd` is inside this project — **a stale
record is not evidence**, and a successful registration (or a clean exit) deletes it.

**Delivery continues**: the poll timer stays installed on the failure path, so a new spool line still wakes
the session once per poll interval, with the **same message shape** as the watch path. The fallback is a
proven guarantee, not an accident — the harness forces the failure and asserts the wake within one interval
(S22/S23), and removing the poll timer in a throwaway copy turns that assertion red.

**Where to look, and what to do**:

| Command | What you get |
|---|---|
| `team doctor` | the degraded-channel warning (only for a *live* record) **and** the `inotify 额度` headroom line: quota, used, and a probe verdict |
| `team status` / `team digest` | the same sentence, one line |
| fix | raise the budget — `sudo sysctl -w fs.inotify.max_user_watches=524288` (persist it), or stop the watcher that holds tens of thousands of watches (e.g. Syncthing's "Watch for Changes" on large trees) |

Without a runtime the doctor line says `unavailable` and **never** `ok`. The gate follows the same rule: an
unavailable watcher premise prints a **visible SKIP** with the measured quota, and
`TEAM_IW_REQUIRE_WATCH=1` turns that same premise into a red — so CI can be strict while a developer's box
stays honest.

## 23. Two BOARD.md rows share one id (or the kanban cursor froze on one of them)

**What you see**: the console's board page (and the work page's board block) highlights two rows at once and
`↑`/`↓` stops on the first of them; `board ls`, `digest` and `doctor` print
`BOARD 有重复 ID：M4.3 ×2、M6.3 ×2、V1.1 ×2`; `team board add <ID> …` refuses with
`BOARD 里已经有 <ID>（状态 todo · 「…」）：没有改动`.

**Why it happens**: the places that matter address a BOARD.md row by its **id** — the pending-report
heuristic, `reviews/<ID>.md`, `team board set <ID> <status>` — and historical boards really do share ids
(different tasks under one milestone id: this project's own board carries `M4.3`, `M6.3` and `V1.1` twice).
The console used to key its focus by the bare id too, so two such rows lit up together and the walk never
left the first one (M48; the brief that built the board row could also be created and then `board add`ed a
second time).

**What the tool does now** (nothing to do to keep working):

- the console's focus is a `{lane, id, nth}` **row** reference: `↑`/`↓` walks every drawn row — two rows
  with one id are two stops — only the focused row carries the `›` cursor, and a row that left the board
  falls back to the first row with that id, then its lane's first card, then the first lane;
- `team board add <ID> …` refuses a second row for an existing id, names that row's status and title, and
  leaves the file byte-identical (the same "a refusal writes nothing" rule as `board set` with an unknown id);
  its refusal names the right entry for the common intent — `team board assign <ID> <agent>` gives a row an agent
  **in place** (no second row, no other column touched; the old way to "assign" was to add a row, which is how
  these duplicates appeared);
- `--allow-dup` is the explicit escape hatch: the row is written and `state/watchdog.log` gets an audit line;
- `board ls`, `team digest` and `team doctor` report the duplicates they find (doctor warns, it does not fail).

**How to handle a duplicate**:

- **one task, two rows** → fix the id (rename the row, or fold the duplicate into one): `board add` refuses the
  next attempt, and both `board set <ID> <status>` and `board assign <ID> <agent>` address by id — they write
  **every** row carrying that id, so a status or an agent you set lands on both rows;
- **a row needs an agent** → `team board assign <ID> <agent>` (not another `board add`; that one is refused);
- **two tasks that genuinely share a milestone id** → leave the data alone (that is what this project does) and
  pass `--allow-dup` for new rows; remember that `reviews/<ID>.md` and the pending-report heuristic are keyed by
  the id too, so both rows share one review namespace, and the detail view opens the same document for both.

The fixtures that pin this are `tests/panel-b3.sh board` (two rows with one id: one cursor, both reachable,
both walks) and `tests/smoke.sh` §4c (refusal, `--allow-dup`, the three visible reports); `tests/flip-m48.sh`
proves both go red when the row identity / the check is removed.

## 24. The performance suite refuses to call itself the "reference environment" — the trust boundary (M66 → M69 → M73)

`bash skills/teamsmith/tests/perf.sh --in-container` records its verdicts under the name "reference
environment" only when the pinned image itself proves that is where it runs. Three pieces of evidence, all
baked into the `ci/Containerfile` image and required by `perf.sh`, each named when missing or wrong (exit 3,
before the lock or any measurement — a host mistake never even touches the lock):

1. the env signal `TEAM_PERF_PINNED_CONTAINER=1` (the image's `ENV`) — necessary but never sufficient: an
   exported variable is forgeable from the host (M64 F2, verified: the host exported the signal and the
   suite described the host's node as the "reference environment");
2. the marker file `/etc/teamsmith-gate-image`, byte-for-byte equal to the closed token (the image's `RUN`
   drops it in the rootfs; `/run/.containerenv` cannot play this role — the dev host is itself a distrobox
   and carries that file too);
3. the marker file must **not be a mount point** (`perf.sh` parses `/proc/self/mounts`): the token is
   public — it sits in `ci/Containerfile`, and `perf.sh` can only trust content that arrived with the image,
   so anyone can `-v`-mount a byte-identical file and matching content proves the file, not the rootfs
   (M64 F2 round three: foreign image + mounted token + ENV=1 ran the whole suite green under the reference
   name). In the real image the marker lives on the overlayfs root and has no mounts-table entry; the
   suite's own wrapper mounts only `/work` (and the main repo for worktree `.git` resolution), never the
   marker.

**In scope (visibly refused)** — every *accidental* shape: a bare host run (M66), host-exported variables
(M69), a stale image without the marker (M69, told to rebuild), tampered marker content (M69), and a mounted
marker (M73).

**Out of scope (cannot and need not be defended)** — a caller who *controls the container runtime and
deliberately* bakes the public token into a self-built image (or forges the mounts table to hide one). An
in-container self-check has a hard ceiling: this is "self-describing, trustworthy against accidents", not a
proof against someone who owns the runtime. Every verdict still carries the full environment
self-description (mode, cores, quota, load, JS/tmux versions, revision), so a suspicious conclusion can
always be re-checked against the source it came from.

Seeing exit 3 with one of these named → rebuild the image
(`<engine> build -f ci/Containerfile -t teamsmith-gate:local .`, the command `perf.sh` itself prints) or
re-run `perf.sh --host` instead (non-reference: the verdict is not acceptance evidence). Host numbers are
never recorded under the reference name.
