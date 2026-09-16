# Tasks: deferred-delivery-and-draft-entry

One apply brief (D21: apply → a dev who is not the proposer; verify → a third agent). The items are in dependency
order: the flip fixture first (it must be red *before* the fix), then the guard, the queue, the drain, the send
paths, the draft entry, visibility, docs, tests/isolation, and the evidence. Each item names the requirement it
moves and the command that can fail.

Path grants the apply brief must state (OWNERSHIP): `skills/teamsmith/scripts/**`, `skills/teamsmith/SKILL.md`,
`references/**` (PM-owned), `extension/**` (PM-owned), `skills/teamsmith/tests/**` (agent:dev). This propose phase
writes only `openspec/changes/deferred-delivery-and-draft-entry/**`.

**Real-process items** are marked `[real]` — they need a tmux window and a Pi (or fake-TUI) pane, and each of them
also has a headless fixture, so no single real-process run is the only evidence for a requirement.

## 0. Flip fixture first (`delivery-guard` requirement 1; defect-fix evidence)

- [x] 0.1 `skills/teamsmith/tests/smoke.sh` (or `tests/flip-*.sh`) — a fixture pane holding `half a sentence` in its
  input box plus a send of a watchdog-like notice. Run it against the **pre-change tree** (a scratch checkout of the
  review revision) and record the glued pane (`draft[watchdog] …`, draft gone) as red; against the branch it must
  record the untouched draft plus one `state/outbox/` entry as green. `[real]`
  Verify: the fixture exits non-zero on the pre-change tree with the glued text on stdout, and zero on the branch.

## 1. The guard (new capability `delivery-guard`)

- [x] 1.1 `skills/teamsmith/scripts/lib/` — one guard function: locate the box from `#{cursor_y}`, scan down for the
  first full rule, up for the top border, buffer the capture and evaluate rows in `END`; byte regex under
  `LC_ALL=C` (`^(\xe2\x94\x80)+$`), never a literal box-drawing character (E3 §1.7). Verdict v2
  (cursor-relative); v3 also when a fresh baseline exists; no hardcoded empty-box shape.
  Verify: `bash skills/teamsmith/tests/guard-matrix.sh` asserts the 10 measured states of E3 §1.5 — empty with hint
  row → free, single/multi-line draft → busy, cleared → free, working-empty → free, working-draft → busy, queue
  widget + empty box → free, trailing-blank-row draft → busy, whitespace-only → free (documented miss).
  The v3 baseline upgrade (design DG1) is **optional** in this apply: ship it only with its own falsifier, otherwise
  v2 alone satisfies the requirement.
- [x] 1.2 Same file — the UNKNOWN policy: no borders found ⇒ "deliver as today", one warning line, no queue entry.
  Verify: a fixture pane running a borderless busy command reports UNKNOWN and the message is typed once.
- [x] 1.3 Same file — re-check immediately before the `Enter`; when the box became busy, send nothing and hold.
  Verify: a scripted fake TUI that makes the box non-empty between the check and the pre-`Enter` read yields no
  `Enter` and one queue entry.

## 2. The queue (new capability `delivery-guard`)

- [x] 2.1 `skills/teamsmith/scripts/lib/outbox.sh` (new) + `scripts/team` dispatch — `team outbox
  enqueue|list|flush|drop`; entry file `<epoch-ms>-<zero-padded seq>-<target>.msg` under
  `$TEAM_STATE_DIR/outbox/`, header `kind`/`target`/`from`/`created`/`dedup` + `---` + payload verbatim, tmp+rename,
  immutable, FIFO by name, sequence taken under `flock`.
  Verify: enqueue a payload containing `$(touch <sentinel>)`, backticks and a newline; `head` shows the header, the
  payload is byte-identical, `<sentinel>` does not exist, no `*.tmp` remains, and `TEAM_STATE_DIR=<temp>` moves the
  entry while `<repo>/.pi/team/state/outbox/` stays absent.
- [x] 2.2 Same file — enqueue also writes the durable record (`team_inbox_append`, or `state/nudges.log` for a wake)
  before the sender returns.
  Verify: a queued `team notify pm` leaves one inbox line; a queued wake line leaves one `state/nudges.log` line.
- [x] 2.3 Same file — dedup by key inside `TEAM_NOTIFY_DEDUP_SEC` for queued/held/recently delivered entries.
  Verify: two identical `team notify pm --from-file` runs inside the window leave one entry and the second says
  duplicate; two different payloads leave two.
- [x] 2.4 Same file — TTL `TEAM_DEFER_TTL` (default 300): move to `outbox/held/` with hold time/attempts, one
  `outbox/HOLDING.log` line, nothing typed; cap `TEAM_OUTBOX_MAX` (default 200, active + held) escalating the oldest
  entry; `team outbox drop <n|all>` and `flush --now` as the explicit exits.
  Verify: with `TEAM_DEFER_TTL=1` the entry moves to `held/`, `HOLDING.log` grows, the pane is untouched and the
  message is already in the inbox; with `TEAM_OUTBOX_MAX=2` a third enqueue leaves two entries and a hold; `drop`
  removes one.
- [x] 2.5 `templates/config.sh.tmpl` + `references/config.md` — document `TEAM_DEFER_TTL`, `TEAM_OUTBOX_MAX`,
  `TEAM_NOTIFY_DEDUP_SEC` (existing) and the `--now` override.
  Verify: `grep -c 'TEAM_DEFER_TTL' skills/teamsmith/references/config.md` is ≥1 and the English-only reference rule
  stays green (`grep -P '[\x{4e00}-\x{9fff}]' skills/teamsmith/references` is empty).

## 3. The drain (new capability `delivery-guard`)

- [x] 3.1 One drain function: select entries whose target box is free, claim before typing, multi-line via
  `load-buffer` + `paste-buffer -p` + one `Enter`, verify the pane fingerprint after the `Enter`, at most one extra
  `Enter`, then `held/` — never paste the payload twice.
  Verify: `flush` on a cleared box delivers once and empties the queue; a pane whose content never changes leaves the
  entry in `held/` with one paste; a payload with three lines arrives as one user message on a real Pi pane. `[real]`
- [x] 3.2 Callers: the sender's bounded retry, `scripts/lib/cmd-watch.sh` (one drain per tick), and
  `team outbox flush`. No new daemon, no background watcher.
  Verify: two concurrent drains (flush + `team watch --once`) deliver one entry exactly once; the tick leaves no new
  tmux window and no new process (`ps` diff before/after).
- [x] 3.3 `team say`/`team notify` return *before* the pane-fingerprint loop when the message is queued: exit 0, the
  literal token `queued`, never `已确认送达`.
  Verify: dirty-box `team say dev …` prints `queued`, exits 0 and leaves exactly one entry (no resend from the old
  6 × 300 ms loop); clean-box `team say --verify` still confirms delivery and leaves the queue empty.

## 4. Send-path rewiring (`delivery-guard`, `notify-and-inbox`, `watchdog`)

- [x] 4.1 `scripts/lib/cmd-agents.sh` — `team say`: guard before typing, `--now` types into a dirty box and appends
  one `state/outbox/forced.log` line; `team notify`'s pane delivery goes through the same guard.
  Verify: dirty-box `team say dev "m" --now` glues like today and logs `say` + target; without `--now` the same
  command queues; `TEAM_NOTIFY_TMUX=0` writes the inbox line and creates no entry.
- [x] 4.2 `scripts/lib/common.sh` — `team_nudge` sends its wake line through the guard (the durable
  `state/nudges.log` record stays first).
  Verify: a dirty PM box + pending batch: pane unchanged, `nudges.log` grew, one outbox entry. `[real]`
- [x] 4.3 `extension/team-notify.ts` — replace `send-keys` (lines ~343-344) with `team outbox enqueue --dedup <its
  key>` + `team outbox flush`; on command failure log it and keep the inbox line — never fall back to typing.
  Verify: the smoke §13 extension harness (fake module registration) asserts no `tmux send-keys` call and one enqueue
  with the extension's key; `TEAM_NOTIFY_TMUX=0` still short-circuits.
- [x] 4.4 Regression guards: the dispatch prompt path (`pi @file`, argv) is untouched, the meeting knock is
  untouched, the shell-prompt safety of `team_pane_busy` is unchanged.
  Verify: the existing smoke F26/F27/§11g assertions and the dispatch launch-proof assertions stay green.

## 5. The draft entry (new capability `delivery-guard`)

- [x] 5.1 `scripts/lib/cmd-draft.sh` (new) + `scripts/team` dispatch — `team draft pm` creates/reuses the `draft`
  window (`tmux new-window -d`, no focus steal) running `$EDITOR` on `$TEAM_STATE_DIR/draft-pm.md`; on save it
  enqueues through the guarded path, prints the acknowledgement in that window and re-seeds the file.
  Verify: with `EDITOR` set to a script that writes `interrupted once` and exits, the session has a `draft` window,
  the outbox holds one entry with that payload, the file no longer contains it, and the window shows the ack. `[real]`
- [x] 5.2 `team draft send [<file>]` — enqueue the file's content verbatim (the headless interface).
  Verify: a three-line file on a clean Pi pane becomes one user message with the three lines in order. `[real]`
- [x] 5.3 `team draft` targets the draft window only: no send path may ever type into it.
  Verify: with the draft window open, `team say pm`, `team notify pm` and a tick leave its pane byte-identical.
- [x] 5.4 `SKILL.md` command table + `team help` — `draft`, `outbox`, `say --now`.
  Verify: `team help | grep -c 'outbox'` ≥1 and the SKILL command table names all three.

## 6. Visibility (new capability `delivery-guard`)

- [x] 6.1 `scripts/lib/cmd-status.sh` — `team status` and `team digest` print one line containing `outbox` with the
  count and the oldest age when the queue is non-empty; nothing when it is empty.
  Verify: two held entries → each output has the line with `2`; empty queue → `team status | grep -c outbox` is 0.
- [x] 6.2 `scripts/monitor.mjs` — show the same count in the panel (no dashboard design; one line).
  Verify: the monitor panel in a fixture session shows the count after an enqueue. `[real]`

## 7. Tests, isolation and the gate (M7.2 lesson; own item)

- [x] 7.1 New smoke section (fixtures for §1–§6) — headless: guard matrix, queue format/FIFO/TTL/dedup/cap, drain
  claim, queued-vs-delivered output, visibility, draft file contract.
  Verify: `bash skills/teamsmith/tests/smoke.sh` green with the new section, and the new section fails if the guard
  function is stubbed to always report "free" (deliberately break → red → restore → green).
- [x] 7.2 **Isolation (own item)**: every new fixture runs in a sandbox repository with inherited `TEAM_*` cleared
  (`env -u TEAM_ROOT -u TEAM_SESSION -u TEAM_DOCS_DIR …`), asserts `team paths` resolves to the temporary root
  before any command that writes, and compares a hash of the real `docs/team/inbox/**` and `.pi/team/state/**`
  before/after (any change fails with a diff).
  Verify: the fixture prints the `team paths` fragment and "real inbox/state unchanged"; a deliberately mis-pointed
  `TEAM_STATE_DIR` makes the guard fail (negative control).
- [x] 7.3 Gate: `openspec validate --all --strict && bash skills/teamsmith/tests/spec-lint.sh &&
  bash skills/teamsmith/tests/smoke.sh` (`TEAM_GATES`).
  Verify: exit 0 and the three commands' summary lines are pasted into the report.

## 8. Docs (apply phase)

- [x] 8.1 `references/troubleshooting.md` §3 — document the guard, the queue, the `--now` escape, the
  whitespace-only miss and the residual check→paste race (English only).
  Verify: the section names the miss and `grep -P '[\x{4e00}-\x{9fff}]' skills/teamsmith/references` stays empty.
- [x] 8.2 `references/protocol.md:64` — replace the "known side effect" wording with the guard's contract.
  Verify: the sentence no longer says notices are typed into a dirty box; the delivery-guard cross-reference exists.

## 9. Evidence (apply runs; verify re-runs independently)

- [x] 9.1 Flip log: the item-0.1 fixture red (pre-change tree) → green (branch), committed in the report.
- [x] 9.2 Requirement → scenario → falsifier table: every scenario in `specs/delivery-guard/spec.md`,
  `specs/notify-and-inbox/spec.md` and `specs/watchdog/spec.md` names the fixture/assertion that fails when its
  behaviour is removed.
- [ ] 9.3 Verify phase (a different agent): the seven attack surfaces of E3 §5.4 — the bug itself, the detector
  edges (incl. whitespace-only and UNKNOWN), TTL/hold, dedup/ordering, no regression on clean-box `say --verify` and
  `TEAM_NOTIFY_TMUX=0`, isolation, and race honesty (re-check before `Enter`).
- [ ] 9.4 Archive (PM, phase 5, after independent verification and the user's confirmation):
  `openspec archive -y deferred-delivery-and-draft-entry`, then re-run the gate.
