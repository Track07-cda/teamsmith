# Tasks: `meeting-liveness`

Planning only — nothing in this file is executed by the propose task (P134); every item is an apply-phase step.
Coverage map (requirement → items): **watchdog** *Pending work…* → 1.1, 1.2, 1.4; **meeting** *Meetings are
bounded* → 2.1–2.4; **meeting** *A per-project read position…* → 1.1, 1.3, 2.1; **meeting** *Each participant
registers its own PM window* → 4.1–4.3; **meeting** *A participant is recognized by its recorded names…* →
4.4–4.5; **meeting** *A knock names the turn it announces* → 3.4, 3.6; **notify-and-inbox** *A turn-end
notification…* → 3.5–3.6; **notify-and-inbox** *A meeting knock…* → 3.1–3.3; **delivery-guard** *An automated
send…* + *Which senders defer…* → 3.1–3.3; **panel** *The status band…* → 5.1; gates → 6.1–6.4; independent
verification → 7.1.

Path grants the apply brief must state (OWNERSHIP): `skills/teamsmith/scripts/lib/**` and
`skills/teamsmith/extension/team-notify.ts` are PM-owned and need an explicit grant per brief;
`skills/teamsmith/tests/**` is `agent:dev`'s; `openspec/changes/meeting-liveness/**`
belongs to the phase's owner; `openspec/specs/**` and `docs/team/**` stay PM-owned (the apply MUST NOT touch them).
The five delta files this change owns: `specs/{meeting,notify-and-inbox,watchdog,delivery-guard,panel}/spec.md`.

Fixture discipline (project rules): every fixture clears inherited team identity (`TEAM_*`, `TMUX`, `TMUX_PANE`)
and writes only inside its scratch repo/state; tmux work stays on the smoke's private session — anything that could
close a window, session or server runs through `bash skills/teamsmith/tests/container-tmux.sh -- <cmd>` and never
against the default socket; no signal is sent by command-line pattern (record the PID at spawn).

## 1. `watchdog` + `meeting`: the unread count and the pending readers

- [x] 1.1 `common.sh`: add `team_meetings_unread_count` — for each `$TEAM_MEETINGS_DIR/*/` where this project is a
  participant and `STATUS` is not `closed`, sum `max(0, transcript turns - read/<project>.seq)`; return 0 when the
  root is absent. Verify: a fixture with three meetings (one unread peer turn, one written only by this project,
  one closed with an unread peer turn) returns `1`. Red: make it count the project's own turn → returns `2`.
- [x] 1.2 `common.sh` + `cmd-watch.sh`: `team_pending_counts` appends the count as the tuple's new last field
  (`… stopped meetings`); `team_panel_pending_counts_fast` computes the same via the helper; `team_pending_text`
  renders `未读会议 N`. Update **every** tuple reader in the same commit (bash folds trailing words into the last
  variable): the `read -r` sites in `team_pending_text`, the panel fast reader/JSON, the watchdog tick and the
  digest; `team_pending_sig` hashes the whole string and needs no change. Verify: a direct assertion that
  `team_pending_counts` and `team_panel_pending_counts_fast` are byte-equal on a fixture with meetings, plus
  `TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null`. Red: drop the meetings field from the fast
  reader → the equivalence assertion fails (and `team_pending_text` shows `未读会议 0`).
- [x] 1.3 `cmd-status.sh` + `cmd-watch.sh`: one helper prints at most one line for `team status` and `team digest`
  — unread meetings first (`<slug> N 条新 → team meeting read <slug>`), then expired-unclosed ones (`<slug>
  已过期未关闭 → team meeting close --stale`); print nothing when there is nothing. Verify: fixture-driven smoke
  asserts both surfaces and the empty case. Red: remove the call from `team status` → the line is absent.
- [x] 1.4 `skills/teamsmith/tests/smoke.sh` (new meeting-discovery section; the `team watch --once` half is a
  **real tmux process**, marked): (a) fixture with one unread peer turn and nothing else → the tick logs the batch
  and nudges with `未读会议 1`; (b) after `team meeting read <slug>` → the next tick is silent; (c) a meeting whose
  only turn is this project's own `say` → silent; (d) `team meeting read --peek` leaves `read/<project>.seq`
  byte-unchanged; (e) the dirty-PM-box baseline still holds the wake in `state/outbox/`. Verify: the section's
  printed result lines. Red for (a): make `team_meetings_unread_count` always return 0 → the tick is silent.

## 2. `meeting`: expiry is visible and closable

- [x] 2.1 `cmd-meeting.sh`: report the derived state — `team_meeting_list`'s row and the `team_meeting_read` header
  say `expired` (never `open(过期)`); `team_meeting_require_open` treats `expired` as read-only but lets `close`
  through. Verify: a fixture whose `OPENED_EPOCH` is older than `TTL_HOURS`: `list` shows `expired`, `read` exits
  0, `say` exits non-zero naming the TTL, `close <slug>` exits 0 and writes `STATUS=closed`. Red: restore the old
  pre-`close` refusal → `close` exits non-zero (the deadlock reproduced).
- [x] 2.2 `cmd-meeting.sh`: `team meeting close --stale` — parse the flag, close exactly this project's `open` and
  expired meetings, print each outcome, exit non-zero and write nothing when none qualifies. Verify: a mixed
  fixture (one expired, one fresh) → the expired one closes, the fresh `state.env` is byte-unchanged; the
  no-expired case exits non-zero with no writes. Red: drop the expiry filter → the fresh meeting's `state.env`
  changes.
- [x] 2.3 `cmd-status.sh` + `cmd-watch.sh`: the expired-unclosed segment of the 1.3 line names the slug and the
  `close --stale` command, and disappears once the meeting is closed. Verify: `team status`/`team digest` on the
  expired fixture and after `close --stale`. Red: remove the segment → the surfaces no longer name the meeting.
- [x] 2.4 `skills/teamsmith/tests/smoke.sh` (§11e additions): `--ttl 99999` clamps to `8760` with a warning; a
  stored non-positive/garbage `TTL_HOURS` falls back to the documented default; the four `close --stale` outcomes
  of 2.2. Verify: the section's result lines.

## 3. `delivery-guard` + `notify-and-inbox`: the knock is a guarded sender

- [x] 3.1 `cmd-meeting.sh`: `team_meeting_knock` keeps its preconditions (switch, registered session,
  `team_foreign_target_ok`) and submits the one-line notice through `team_send_guarded … meeting-knock` to the
  resolved `<peer-session>:<peer-window>`; map `TEAM_SEND_OUTCOME`: `delivered` → knocked, `queued` → queued (name
  `team outbox list`), `offline`/`unknown-failed` → the transcript-only diagnostic. Verify: a **real tmux** fixture
  peer pane with a draft → the pane is byte-identical after the knock, `state/outbox/` holds one `meeting-knock`
  entry whose payload is the notice, and the command says queued; with an empty box → one typed notice and
  `delivered`. Red: substitute the old raw `team_tmux_send_text` call → the notice lands in the peer draft.
- [x] 3.2 `skills/teamsmith/tests/smoke.sh` (knock section; **real tmux**): after 3.1's dirty-box case, clear the
  peer box and run the sender's drain → the notice is typed into the registered `session:window` once and the entry
  leaves the queue; the transcript already held the turn before any typing. Verify: the pane capture, the entry
  list and the transcript.
- [x] 3.3 `cmd-outbox` visibility: the queued knock is listed by `team outbox list` and counted by the
  `outbox` line of `team status`/`team digest` (the existing `delivery-guard` requirement; no new surface). Verify:
  the same fixture's output lines.
- [x] 3.4 `cmd-meeting.sh`: the knock payload and `knocks.log` carry `[meeting:<slug>#<N>]`, `N` taken from the
  transcript turn the knock refers to; `say --knock` and `meeting knock` both stamp. Verify (**real tmux** or the
  header fixture): with turn `0004` newest, the payload contains `[meeting:<slug>#4]` and the `knocks.log` line names
  `4`. Red: drop the turn number → the assertion fails.
- [x] 3.5 `extension/team-notify.ts` + `cmd-agents.sh`: the turn-end notification stamps `task=<ID> tip=<7-hex>`
  (task from the branch, tip from `git rev-parse --short HEAD`) into the durable inbox line **and** the knock
  payload, leaving the summary text byte-identical; `team notify` stamps what it can from the resolved sender's
  worktree and never invents one. Verify: a fixture worktree on `task/P9-parser` at a pinned tip → the line and
  payload each contain `task=P9 tip=<that hash>` and the summary is unchanged; the extension leg reuses the driver
  pattern of `skills/teamsmith/tests/flip-m4.3.sh` (`e_run`) / `flip-m6.3.sh` (tsx driver) rather than a new
  harness. Red: stamp only the knock → the inbox-line assertion fails; invent a stamp without a task → the skip
  case reddens.
- [x] 3.6 `skills/teamsmith/tests/smoke.sh`: the stale/fresh comparisons — `docs/team/reviews/P9.md` HEAD equal to
  the stamp → stale; a different tip → not stale; a `#4` knock against `read/<project>.seq` 3 → fresh and 4 →
  stale. Verify: the section's result lines.

## 4. `meeting` + `notify-and-inbox`: per-participant PM windows

- [x] 4.1 `cmd-meeting.sh`: read/write `PM_WINDOWS=<project>=<window>;…` in `state.env`; `open` writes the opener's
  own row (`TEAM_PM_WINDOW`, default `pm`) and keeps writing the legacy `PM_WINDOW` with the same value;
  `team meeting peer <slug> <project>:<session> [--window <name>]` writes one row, defaulting the caller's own
  project to `TEAM_PM_WINDOW`, else the current tmux window when inside one, else `pm`; a resolution helper returns
  the peer's row, else legacy `PM_WINDOW`, else `pm`. Verify: function-level fixture (no tmux) over four
  `state.env` shapes: map present, legacy only, both (map wins), neither (default); plus `open` writing both fields.
  Red: make resolution ignore the map → the `pi` row case resolves to `pm`.
- [x] 4.2 `cmd-meeting.sh`: the knock success line and the failure diagnostic name the resolved `session:window`
  and, on failure, the `team meeting peer … --window` command. Verify (**real tmux**, private session): a peer
  session with the TUI in `pi` receives the knock; a peer pane that is a bare shell produces the diagnostic naming
  the resolved window. Red: fall back to the single shared field → the target is `pm` and nothing receives it.
- [x] 4.3 `skills/teamsmith/tests/smoke.sh` (window section; **real tmux**): rows `alpha=pm;beta=pi`; alpha
  re-registers its own row `--window new` → the `beta=pi` row is byte-unchanged, beta's knock targets
  `<alpha-session>:new` and alpha's knock still targets `<beta-session>:pi`; a legacy-only `state.env` knocks at
  `PM_WINDOW`. Verify: the two pane captures and the `state.env` diff.
- [x] 4.4 `cmd-meeting.sh`: participant identity — `state.env` gains `PARTICIPANT_REPOS=<project>=<basename>;…`
  (`open` writes the opener's own repository name; `meeting peer <project>:<session> --repo <name>` writes a row,
  defaulting the caller's own project to the basename of its main worktree) and `team_meeting_is_mine` accepts a
  project when its declared name, its repository basename, or its `TEAM_SESSION` equal to a participant's recorded
  session matches. Verify: a function-level fixture over five `state.env`/caller shapes (name match, basename
  match, session match, no match, third party). Red: restore the one-spelling check → the session/basename shapes
  are refused; loosen it to accept any project → the third-party shape passes (the forbidden direction).
- [x] 4.5 `skills/teamsmith/tests/smoke.sh` (identity section): the D66 shape — a meeting recording `<peer>` with
  session `<peer>`, a project whose basename is `<peer-project>` and whose `TEAM_SESSION` is `<peer>` →
  `read`/`say`/`inbox` exit 0 and the transcript gains the turn; a third project (all names unrecorded) → `read` and
  `say` are refused and no transcript entry appears; after `meeting peer … --repo <peer-project>`, `state.env` carries
  the repository name alongside the session. Verify: the section's result lines.

## 5. `panel`: the unread meeting count reaches the band

- [x] 5.1 `cmd-watch.sh`: `team_panel_pending_json` carries `"meetings": N` and includes it in `total`;
  `team_pending_text` already renders the count, so `layout.ts`'s band line shows it with no JS change. Verify:
  `team monitor --print` and `team monitor --json` on a fixture with two unread peer turns → `panel.pending.meetings`
  is 2, `panel.pending.total` is 2, and the print contains `未读会议 2`. Red: drop the JSON key → the assertion
  fails. If any `panel/src/**` file is touched, `scripts/panel/build.sh` must rebuild the bundle byte-identically
  (`git diff --exit-code -- scripts/panel/panel.js`).

## 6. Gates, archive readiness, evidence

- [x] 6.1 `PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict` — paste the tail.
- [x] 6.2 `TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null`, then the **full** smoke once — paste
  both tails; `git status --porcelain` clean.
- [x] 6.3 Trial archive on a scratch copy (`cp -r openspec /tmp/meeting-liveness-trial && (cd
  /tmp/meeting-liveness-trial && PATH="$HOME/.bun/bin:$PATH" openspec archive -y meeting-liveness)`) — proves every
  MODIFIED block merges with all base scenarios and no collision with in-flight changes.
- [x] 6.4 The apply report's evidence: the delta→requirement map, the MODIFIED before/after table (base scenario
  names on both sides), every flip's red and green tail, the queued-knock entry dump and the cleared-box drain
  capture, and the `PM_WINDOWS` before/after `state.env`.

## 7. V — independent verification (a different agent)

- [ ] 7.1 Rerun, out of tree and on the apply's tip: every red/green flip of §§1–5 (including the raw-sender
  re-glue and the resolution fallback), the **real tmux** knock and window scenarios, `openspec validate --all
  --strict` and the **full** smoke; the record goes to `docs/team/reviews/<ID>.md` with a verdict and any findings
  (a PASS carrying findings is rework, not archive).
