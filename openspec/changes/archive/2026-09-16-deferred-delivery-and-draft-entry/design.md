## Context

D20 is a user requirement with a reproduced failure: automated messages are typed with `send-keys` + `Enter`, and a
notice arriving while a human is typing is glued to the draft and forces the combined text out as one submission
(E3 §1.1(e), measured on a real Pi pane). E3 explored the how (557 lines, a 10-state detector matrix, tmux and Pi
internals), and D21 accepted option B: the delivery guard + `state/outbox/` + `team draft` now, with the PM-side
extension channel (C) as a later change that plugs into the queue.

This phase writes the contract only: no code, no tests, no `references/**`. The gate is
`openspec validate --all --strict` plus `bash skills/teamsmith/tests/spec-lint.sh`; the promised behaviour is checked
by the apply phase (implementation + fixtures) and by an independent verify phase, which attacks the seven surfaces
named in E3 §5.4.

## Goals / Non-Goals

- **Goal**: one new capability (`delivery-guard`) that states the guard, the queue, the drain, TTL/hold, dedup,
  visibility and the draft entry as falsifiable promises, plus the two base capabilities whose current text would
  otherwise become false (`notify-and-inbox`, `watchdog`).
- **Goal**: keep the queue file format and the enqueue command as the *interface*, so C (PM-side delivery) can
  reuse them without a spec rewrite.
- **Goal**: keep every heuristic honest — the whitespace-only miss and the UNKNOWN-shape policy are written down,
  not discovered later.
- **Non-goal**: C itself (the PM's Pi loads an extension, `pi.sendUserMessage`, exact `ctx.ui.getEditorText()`);
  D21 defers it.
- **Non-goal**: the D19 dashboard and the meeting knock (cross-project, keeps today's behaviour).
- **Non-goal**: any code, test or doc change in this phase. The apply phase owns `scripts/**` (PM directory,
  granted by that brief), `extension/**`, `references/**` and `tests/**` (agent:dev).

## Decisions

### DG1 — the detector is cursor-relative (v2), with v3 only when a fresh baseline exists

E3 §1.5: the naive "any non-blank row inside the box" detector is useless in the PM's real configuration because the
package-provided hint row (` k3  Kimi Coding  max`) is never blank; the cursor-relative rule (the cursor row, or a
content row above it, non-blank) was correct in 9 of 10 measured states. The box is not pinned to the pane bottom,
so the guard anchors on `#{cursor_y}`, scans down to the first full rule (bottom border) and up to the top border,
and buffers the capture before evaluating rows (§1.7: a single-pass awk computes negative offsets; mawk cannot match
a literal `─` regex, only the byte form `^(\xe2\x94\x80)+$` under `LC_ALL=C`).

The one measured miss — a whitespace-only draft — is written into the `delivery-guard` requirement text and must also
be named in `references/troubleshooting.md` §3 in the apply phase. v3 (v2 plus "a border-relative row that the
calibrated empty box had blank is now non-blank") is an upgrade only when a baseline captured after a confirmed
delivery exists; a stale baseline must never turn an empty box into BUSY.

### DG2 — the queue entry file format and `team outbox enqueue` are the interface

`$TEAM_STATE_DIR/outbox/<epoch-ms>-<zero-padded seq>-<target>.msg`, one immutable file per message, header fields
`kind`, `target`, `from`, `created`, optional `dedup`, then `---`, then the payload verbatim; written tmp+rename
(atomic), sorted FIFO by name. `team outbox enqueue --kind … --target … [--from …] [--dedup …] --from-file <path>`
is the single write path (the notify extension calls it instead of `send-keys`), and `team outbox list|flush
[--now]|drop <n|all>` is the inspection/rescue surface. C reads the same entries and drains them in-process; because
the format is the interface, changing it later is a spec change, not an implementation detail.

### DG3 — one drain, three callers, no daemon

The drain is a single code path (D21's binding condition) called by (a) the sender's bounded retry, (b) the watchdog
tick, and (c) `team outbox flush`. It claims an entry before typing (lock or rename to a delivery-in-progress name),
so a sender retry racing a tick cannot deliver twice; it verifies the pane fingerprint *after* the `Enter`, sends at
most one extra `Enter`, and moves the entry to `outbox/held/` when the pane still does not change instead of pasting
the payload again. The watchdog stays a metronome (AGENTS.md patrol section): the tick calls the drain once; it does
not watch the box.

### DG4 — queued is not delivered, and enqueue is already durable

A queued send returns before the pane-fingerprint loop (a queued message provokes no pane change; the old loop would
resend and then report a false "投递未确认", E3 §4.1). The sender prints the literal token `queued`, exits 0, and
never says the message was delivered. At enqueue time the payload is also recorded durably — `team_inbox_append` for
`say`/`notify`, the existing `state/nudges.log` line for a wake, the extension's own inbox line — so an expired hold
can never lose a message (E3 §2.3/§2.5).

### DG5 — `team say` defers for worker targets too, and `--now` is the audited override

The glue damages a worker's draft exactly like the PM's, so the default is to defer for every target whose box is
busy; `team say --now` (and `team outbox flush --now`) types immediately even into a dirty box and appends one line
naming the sender, the target and the entry to `state/outbox/forced.log`. `--now` deliberately re-creates the old
behaviour and is the only documented way to do so. **Decision for the PM** (E3 §7 asked explicitly).

### DG6 — UNKNOWN pane shape delivers as today, with one warning

A pane whose input-box borders cannot be located (a non-Pi TUI, a theme that breaks the geometry) is treated as
"deliver as today" plus one warning; it must never become a permanent hold. The queue still records nothing for that
message, which is the honest reading: the guard has no evidence. **Decision for the PM** — it is a behaviour call
about a pane teamsmith does not control.

### DG7 — expiry holds, the queue is bounded, and both exits are explicit

`TEAM_DEFER_TTL` (default 300 s) moves an undeliverable entry to `outbox/held/` with `held-since`/`attempts` and one
`outbox/HOLDING.log` line; expiry never types anything. `TEAM_OUTBOX_MAX` (default 200, active + held) escalates the
oldest entry when the cap is hit. A held entry is still delivered by a later drain once the box clears;
`team outbox drop <n|all>` is the human's discard, and `flush --now` the deliberate glue.

### DG8 — the draft window is a file contract, not a new delivery channel

`team draft pm` creates or reuses a `draft` window in the team session (`tmux new-window -d`, so focus never moves)
running `$EDITOR` on `$TEAM_STATE_DIR/draft-pm.md`; nothing in teamsmith may ever type into that window, which is
what makes "uninterrupted" constructive rather than heuristic. Saving enqueues the file through the guarded path,
prints the acknowledgement (entry name, queued-or-delivered) in that window, and re-seeds the file.
`team draft send [<file>]` is the headless equivalent and the testable surface. Multi-line content is delivered with
`load-buffer` + `paste-buffer -p` + one `Enter`: E3 §3.2 measured that without `-p` a three-line paste becomes three
submissions (one message plus "Steering:" entries), and that Pi parses the forced bracketed-paste wrapper.

### DG9 — the notify extension stops typing and uses the same enqueue

E3 §4.3 corrected the brief's premise: `extension/team-notify.ts:343-344` does `send-keys -l` + `Enter` into the PM
window today. The extension therefore calls `team outbox enqueue` (carrying its existing dedup key) followed by
`team outbox flush`, and no longer calls `tmux send-keys`. If the queue command fails, it logs the failure and keeps
the inbox line — it must not fall back to typing, which would silently re-create the glue.

### DG10 — held state is visible before the dashboard exists

`team status` and `team digest` print one line containing `outbox` with the combined count and the age of the oldest
entry whenever the queue is non-empty, and print nothing when it is empty. D19 can promote it into a first-class
field later; this change only guarantees the operator can see that messages are waiting.

### DG11 — what must not regress, and what the apply phase must build

The apply phase keeps: `team say`'s pane-fingerprint confirmation on a clean box, `--verify`/`--no-verify`,
`TEAM_NOTIFY_TMUX=0` (inbox only, no knock, no entry), dispatch's argv prompt path (`pi @file`; the guard must not
touch it), the meeting knock, and the existing `team_pane_busy`/shell-prompt safety. It updates the smoke sections
that assert the current send path (E3 §4.5: §11g, §13, F26/F27) and adds new fixtures. Fixture isolation is its own
task item (M7.2 lesson): clear inherited `TEAM_*`, assert `team paths` points at the temporary root before any
writing command, and hash the real `docs/team/inbox/**` and `.pi/team/state/**` before and after.

### DG12 — the flip is a fixture, not a claim

This change fixes a reproduced defect, so the apply phase must demonstrate red-before → green-after: run the fixture
that reproduces E3 §1.1(e) (a fixture pane holding a draft, then a send) against the pre-change tree and record the
glued pane, then against the branch and record the untouched draft + one queue entry.

## Risks / Trade-offs

- **[check → paste is not atomic]** a draft can start between the guard and the keys. → The guard is re-checked
  immediately before the `Enter`; when in doubt the message is held, and the residual window (one command, no loop
  of sends) is documented in `references/troubleshooting.md` instead of hidden.
- **[false BUSY holds messages]** a stale baseline, a theme change or a TTL that fires too early. → v3 only with a
  fresh baseline, TTL escalation to the inbox, a visible count, and two explicit exits (`flush --now`, `drop`).
- **[UNKNOWN panes]** a non-Pi TUI would never be delivered if UNKNOWN meant BUSY. → UNKNOWN delivers as today with
  one warning (DG6).
- **[double delivery]** drain and sender retry can race. → claim before typing; the spec makes "exactly one
  delivery" a scenario with two concurrent drains.
- **[unbounded queue]** a PM with a stale draft for hours. → `TEAM_OUTBOX_MAX` cap with oldest-entry escalation.
- **[mawk/UTF-8 and row order]** E3 §1.7's two traps. → implementation notes are in DG1 and in `tasks.md` so the
  apply phase cannot rediscover them as bugs.
- **[test pollution]** a fixture draining into the real state/inbox (M7.2). → the queue follows `TEAM_STATE_DIR`
  (spec scenario), fixtures assert `team paths` first, and the real inbox/state hashes are compared before/after.
- **[three MODIFIED blocks restated by hand]** archive replaces whole requirements, so a partial restatement
  silently deletes text (C1 D2). → the blocks were extracted from the base specs by script, and the report diffs
  them against `git show HEAD:openspec/specs/...`; once C0's delta rules land they are also gate-time red.

## Migration Plan

None on disk: the queue directory, `held/` and `HOLDING.log` are created lazily under the existing
`TEAM_STATE_DIR`; no existing file changes format. Rolling the apply phase back means reverting its commit — a
leftover `outbox/` directory is inert. The new keys (`TEAM_DEFER_TTL`, `TEAM_OUTBOX_MAX`) get their
`references/config.md` row in the apply phase, since defaults preserve today's timing.
