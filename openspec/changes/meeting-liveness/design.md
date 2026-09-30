# meeting-liveness · design

## Context

The pieces that change are all readers of one shared area and one queue:

- `team_pending_counts` (`common.sh`) is the single definition of "pending work": `team watch --once` hashes it for
  the nudge rate limit, `team_pending_text` renders it and `team_panel_pending_counts_fast` (`cmd-watch.sh`) is an
  equivalence-checked copy for the panel. The tuple currently ends in `stopped`.
- A meeting's shared area is `state.env` (participants, `PEER_SESSIONS`, one `PM_WINDOW`, TTL, `MAX_TURNS`,
  `STATUS`), `transcript/` (the only truth), `read/<project>.seq` (per-side read position) and `agreements/`.
  `team_meeting_is_expired` already computes expiry from `OPENED_EPOCH` + `TTL_HOURS`; `team_meeting_require_open`
  makes an expired meeting read-only, which also refuses `close` (the deadlock).
- The knock is the only cross-session sender: `team_meeting_knock` resolves `<peer-session>:PM_WINDOW` and calls
  `team_tmux_send_text` (`send-keys -l` + `Enter`) after `team_foreign_target_ok`. The internal senders already go
  through `team_send_guarded` and the `state/outbox/` queue (`delivery-guard`).
- The panel band renders `panel.pending.text` verbatim (`scripts/panel/src/layout.ts`), so a pipeline change is a
  data change, not a UI change.

## Goals / Non-Goals

**Goals:** make peer speech wake the PM; make expiry visible and closable; make the knock use the guarded sender;
make the PM window per participant; make membership survive a project's name spellings; make a late notice
decidable from its identifier; write down the read-position rule the discovery rests on.

**Non-Goals:** any change to the shared area's layout beyond the two new state fields and the participant
repository record; any write into the peer project; intents/agreements/`--as-user`; a meetings screen in the panel;
auto-detecting a peer's pi pane; making expiry itself wake the PM (only peer speech does; expiry is shown on
`status`/`digest`); N-party meetings (D66 defers that), so the membership and window rules stay two-sided.

## Decisions

**D1 · `expired` is derived, never written.** `STATUS` stays `open|closed`; a meeting is expired when
`STATUS=open` and `now - OPENED_EPOCH > TTL_HOURS*3600`. Readers (`list`, `read`, `status`, `digest`) must not
mutate the shared area, a stored `expired` would need a reaper and would race `open --force`, and the state is
monotonic until close. Consequence: `team_meeting_require_open` treats `expired` as read-only for everything except
`read` and `close`; the deadlock is fixed by letting `close` through.

**D2 · One shared unread count feeds both pending readers.** A single helper (`team_meetings_unread_count`) sums,
over the meetings this project participates in whose `STATUS` is not `closed`, `max(0, turns - read/<project>.seq)`
(it skips the root when `TEAM_MEETINGS_DIR` does not exist). `team_pending_counts` and
`team_panel_pending_counts_fast` append it as a new last field, `team_pending_text` renders `未读会议 N`, and
`team_panel_pending_json` carries `"meetings"` and includes it in `total`. Appending is not free: bash `read` folds
the tail into the last variable, so every reader of the tuple is updated in the same commit. Alternatives rejected:
computing it only in `team_pending_text` (the wake path hashes the counts and the panel needs the field) and a
second scan inside the fast reader (that is how the two readers drift apart).

**D3 · Unread is defined by the read position, not by the knock.** `transcript/NNN_*.md` count minus
`read/<project>.seq`; `say` already advances the writer's own position and `read --peek` does not advance. A meeting
that is expired but not closed still counts (its transcript is readable); a closed one does not. This is the
`meeting` *A per-project read position defines unread turns* requirement; the watch requirement only names the
number.

**D4 · One meeting line, printed by `status` and `digest`.** A helper prints at most one line: first the meetings
with unread turns (`<slug> N 条新 → team meeting read <slug>`), then the expired-unclosed ones (`<slug> 已过期未关闭
→ team meeting close --stale`). Nothing to report → no line at all (`board-and-status` already keeps the empty-queue
style: silence, not an empty heading). The pending line stays a count (`未读会议 N`) so the nudge and the panel need
no second source. Alternative rejected: a new digest section — one line per surface is what the change promises.

**D5 · The knock goes through `team_send_guarded`.** `team_meeting_knock` keeps its preconditions (switch, session
registration, `team_foreign_target_ok`) and then submits the one-line notice with kind `meeting-knock` to
`<peer-session>:<peer-window>`; the outcome is mapped for the human: `delivered` → knocked, `queued` → the notice is
in the sender's `state/outbox/` and will go out when the peer box clears, `offline` (empty prompt / no pane) → the
transcript-only path with the existing diagnostic. The queue entry is immutable and targets the registered window;
the drain re-checks the peer box before typing, so the whole `delivery-guard` contract (verdict, pre-`Enter`
re-check, held entries) applies unchanged. Alternative rejected: calling `team_input_box_text` before the raw send —
that re-implements half the guard, skips the pre-`Enter` re-check and has nowhere to hold the message.

**D6 · `PM_WINDOWS` is per participant; `PM_WINDOW` is kept for older peers.** `state.env` gains
`PM_WINDOWS=<project>=<window>;…` (the `PEER_SESSIONS` serialization). `open` records the opener's own row from
`TEAM_PM_WINDOW` (default `pm`) and still writes the legacy `PM_WINDOW` with the same value, so a peer running an
older skill can still knock us. `team meeting peer <slug> <project>:<session> [--window <name>]` writes a row; the
caller's own project resolves a missing `--window` from `TEAM_PM_WINDOW`, else the current tmux window
(`tmux display-message -p '#W'`) when running inside one, else `pm`. A knock resolves the peer's window as its own
row, else legacy `PM_WINDOW`, else `pm`, and prints the resolved target (and the registration command on failure),
which is what turns today's silent failure into a named one. Alternative rejected: auto-detecting a pi pane in the
peer session — several windows may run agents, it reads a foreign session's panes, and the explicit row is auditable.

**D7 · `close --stale` is the batch form of an allowed close.** It iterates this project's meetings, closes exactly
the ones that are `open` and expired, prints each outcome, and exits non-zero without touching anything when none
qualifies. It never touches a non-expired meeting (they are in use); expired ones are read-only for both sides, so
closing them decides nothing for the peer. The single-meeting `close` gains the same expired permission.

**D8 · No panel bundle change.** The band renders `pending.text`; the JSON key is additive and the panel's data
reader tolerates it. If a change to `panel/src/**` becomes necessary, it must follow the committed-bundle rule
(rebuild with the pinned bun, byte-identical).

**D9 · Participant identity is any recorded name, not one spelling.** The membership test accepts the caller's
declared project name (`TEAM_PROJECT`), the basename of its main worktree, or its `TEAM_SESSION` equal to the
session recorded for a participant. `state.env` gains `PARTICIPANT_REPOS=<project>=<basename>;…`; `open` writes the
opener's own repository name and `meeting peer --repo` (defaulting the caller's own project to its basename) writes
a row. The session axis is what makes the D66 shape self-healing: the meeting recorded the peer under its session
slug, so without it the peer can never be recognized to register its repository name (the chicken-and-egg that
forced a hand-edited `state.env`). Alternatives rejected: names+basenames only (the live D66 meeting stays broken
until someone edits shared state); a separate alias file (more state to keep in sync, no gain); accepting any
project that asks (that is the third-party leak scenario ② pins).

**D10 · Notices carry the revision and the turn.** A turn-end notification is stamped `task=<ID> tip=<7-hex>` —
the extension already resolves the branch, so it reads `git rev-parse --short HEAD` beside it; the CLI resolves the
sender's worktree the same way. A meeting knock is stamped `[meeting:<slug>#<N>]` from the transcript turn name.
Staleness is then a comparison against the receiver's own ledger: board `done`/`closed`, or
`reviews/<ID>.md`'s HEAD equal to the stamp, or `read/<project>.seq` ≥ `N`. Why the tip hash rather than a
timestamp or a notification UUID: only `(task, tip)` names the object version, and a timestamp cannot separate a
resend of old work from new work. Why the rule uses the ledger: the receiving peer PM cannot open our repository,
and even the internal PM does not need a checkout to know whether the revision was already reviewed. Alternatives
rejected: a notification registry with server-side state (a second spec system to keep honest); marking notices
stale from the current tip alone (needs git access the peer does not have).

## Risks / Trade-offs

- **Pending tuple drift** (two readers, many `read` sites) → one helper computes the number; the smoke's existing
  equivalence check keeps the two tuples identical; the flip test removes the field from the fast reader and
  requires red.
- **Patrol cost** → the scan is one `ls` per meeting plus two small file reads, skipped when `TEAM_MEETINGS_DIR`
  does not exist; the patrol already reads the inbox directory and the board every tick.
- **A queued knock is later than the message** → `team status`/`digest` already print the outbox line
  (`delivery-guard`), so the sender sees it; the transcript was written before the knock either way.
- **Cross-version peers** → legacy `PM_WINDOW` keeps the reverse direction working; resolution falls back to it.
- **`offline` knocks create no queue entry** (the peer PM is not running) — that matches today's behaviour and the
  peer's patrol finds the turn; only a busy box queues, which is the case the brief names.
- **`close --stale` closes the peer's view of a meeting too** → only expired (read-only) meetings qualify, and the
  closure is recorded in `agenda.md`; a live meeting is never touched.
- **A broadened identity could accept a foreign project** → the check still requires a recorded match (name,
  repository or the session the meeting was opened with); the third-party scenario pins the refusal, and the
  shared area is not a security boundary against someone who can already read it.
- **A stamp can itself stale (rebase, amended tip)** → the receiver's rule only declares stale for revisions its
  ledger already covers; it never declares unevaluated work fresh, and the stamp names a revision, not a promise.

## Migration Plan

No data migration: new fields are additive, old files are read through the documented fallbacks, and both meetings
in the wild keep working. Rollback is `git revert`; the specs are archived by the PM after verification.
