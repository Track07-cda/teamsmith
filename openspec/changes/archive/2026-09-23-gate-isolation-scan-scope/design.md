# Design: `gate-isolation-scan-scope`

See `proposal.md` for motivation. This document records the two rulings the brief asks for — what the scan may
read, and how the audit log stays hygienic without losing forensic value — with the measured evidence, the
alternatives that were rejected, and the plan that makes both falsifiable.

## Context

- **The scan**: `real_ledger_hits()` (`skills/teamsmith/tests/smoke.sh:214`) greps `docs/team/inbox` and
  `.pi/team/state` of the invoking project root (and of its main worktree) and returns the matching paths. It is
  shared by every isolation assertion: `12b-j` (`smoke.sh:6967`), P10's `26-l` (`:8492`), M16's double control
  (`:10196-10207`), M98's evidence (`:8381`). The only exclusion today is `--exclude-dir=bg` — `state/bg/` holds
  `team_bg_run` job stdout, i.e. "what a background job printed", and was excluded in M30 because the gate's own
  output collected there read as a leak. The function's comment already says the criterion is "fixture traces in
  the real ledger", not "the state directory is byte-stable".
- **The audit log**: the M36/M67 tmux gate (`skills/teamsmith/scripts/shim/tmux`) appends one line per gated call
  to `$TEAM_TMUX_CALLS_LOG`, pinned at window launch to `<project>/.pi/team/state/tmux-calls.log`; the line
  carries the caller's full argv, the resolved socket, the cwd and the action. Bound: past 2000 lines the oldest
  go and the newest 1000 stay (`shim/tmux:299-303`), an existing requirement of
  `boundary#The gate's actions are logged, and no window carries a destructive-call grant`
  (`openspec/specs/boundary/spec.md:169`) with the fixture `smoke.sh:10573-10577`.
- **Measured today (this worktree, 2026-09-22 17:51)**:
  - the live audit log is **1780 lines / 589 KB** — i.e. the log is bounded and has not yet rotated; the brief's
    "append-only, unbounded" premise does not match the current tree (the bound came with the shim in M36 and is
    part of the boundary requirement);
  - planting a fixture trace into a scratch root's `state/tmux-calls.log` and running the real `real_ledger_hits`
    returns that file — the self-poisoning red is reproduced without touching any real state;
  - the same scan returns `docs/team/inbox/leak.md`, `state/phantom.log`, `state/nested/tmux-calls.log` and
    `state/tmux-calls.log.1` (in scope), and not `state/bg/gate.log` (out of scope);
  - rotation probe: seed 2100 lines → one gated call → **1000 lines**, first line `seed 1102`, oldest gone,
    newest call last, and nothing in the file says a rotation happened.

## Goals / Non-Goals

**Goals:**

- A red isolation assertion means "a fixture wrote into the caller's ledger" — never "a gated call was recorded".
- The exclusions are deliberate, exactly two, and cannot widen by accident (no name globs).
- The audit log stays a bounded record whose newest lines always survive, and a truncated log can never be read
  as a complete one.
- Every leg — the two exclusions and the still-red positive control — is pinned by a fixture that can fail.

**Non-Goals:**

- What the log records. The full argv, the socket table and the four-value `act=` vocabulary stay exactly as
  they are: the argv *is* the forensic value.
- A per-line byte cap (a huge `send-keys` payload makes one long line). Capping it would delete the detail the
  log exists for; the line-count bound already caps total growth, and an oversized single call is bounded by the
  caller's own argv.
- `ob_hash_real()`'s fingerprint (`smoke.sh:5541`), which also covers the log and therefore prints the
  informational "real team had activity" hint when anyone called tmux. That line never fails and changing it is
  not needed for correctness.
- Time-based rotation, per-session/per-caller sharding, log compression, any new `TEAM_*` key.
- Cleaning today's log: the PM already removed the two poisoning lines by hand; the live file is the green side.

## Decisions

### D1 — The audit log is a traffic record, not ledger state: exclude exactly `.pi/team/state/tmux-calls.log`

The scan exists to prove that a fixture did not *write into the project's ledger*. The audit log is written by
the gate itself on behalf of the caller, and its content is the caller's own argv; a fixture's session name there
is the file doing its job. Treating it as pollution inverts the evidence: the gate's own record becomes the
"leak". So the exclusion is right, and it must be stated in the spec (not just the code comment) so it can be
reviewed.

Alternatives considered:

- *Ignore calls that match the shim's line format* (i.e. keep the file in scope and filter lines): rejected — it
  couples the leak scan to a format that changes, and a shim-written line with a fixture name would still be
  ignored, which is the same outcome with more machinery; a fabricated line could be caught, but a fabricated
  line in a record nothing reads for decisions is not the threat this scan guards.
- *Sanitize what the log records* (e.g. hash session names): rejected — destroys the forensic value (M62's leak
  chain was diagnosed by reading the argv) and does not remove fixture payloads from the file.
- *Leave the file in scope and let the gate stay red* / delete lines by hand: rejected — the PM already had to
  hand-edit a production log to un-red the gate; a gate that requires manual log surgery is not a gate.
- *Exclude by basename* (`--exclude=tmux-calls.log`): rejected — it would also silence a `tmux-calls.log` inside
  a fixture-created subdirectory, which **is** a leak. Exact paths, pinned by a scenario.

### D2 — Keep the 2000 → newest 1000 line bound; no time rotation, no sharding

The forensic question after a default-server death is chronological: "who called what in the calls before it".
One file in one order answers it directly. Sharding by session or caller multiplies the places to look and
destroys the total order; time-based rotation needs a scheduler (the pulse) and leaves a hole exactly when no
agent is running, while the line bound lives in the write path and cannot be skipped. Size is a non-issue: 1000
lines ≈ 0.3 MB (331 B/line measured today). The property that matters — the newest calls always survive — the
bound already guarantees. The
brief's premise ("append-only, unbounded") is therefore recorded as corrected rather than implemented: the bound
exists, and this change keeps it.

### D3 — Truncation must be self-describing: one cumulative `dropped=` marker as the file's first line

Today a rotated log is indistinguishable from a complete one, so "not in the log" can mean "never happened" when
it really means "rotated away" — the one real forensic risk the bound creates. When the bound is enforced, the
surviving file starts with a rotation marker: ISO-8601 timestamp · `rotation` · `dropped=<N>`, where `N` is the
**cumulative** number of call lines no longer in the file (previous marker's `N` plus this rotation's removals).
Cumulative, not per-rotation, because the file forgets earlier markers — a reader needs the total to know how
much history is gone. The marker is not a call line: it carries no `act=` value, so the closed four-value action
vocabulary and every parser of call lines are untouched. The newest 1000 call lines are kept, in order.

Rejected: no marker (the status quo — silent loss); writing the count to a sibling file (a second file to keep
bounded, and a reader may miss it); a fifth `act=rotation` value (would enter the closed vocabulary every call
line parser reads).

### D4 — Exact-path exclusions only, and the negative control stays honest

The requirement names the two excluded paths (`.pi/team/state/bg/**`, `.pi/team/state/tmux-calls.log`) and says
everything else under the two roots stays in scope. Fixtures pin both directions: a trace in the audit log is
silent; a trace in the inbox, in another state file, in `tmux-calls.log.1`, or in `state/nested/tmux-calls.log`
is named; a trace in `state/bg/` stays silent (the M30 rule). The existing `12b-j` and M16 positive controls are
part of the requirement, so "green" can never come from a scan that stopped scanning.

## Falsifiability plan (red → green, for the apply report)

- **R1 audit-log leg**: red — plant `P73SCAN` in a scratch root's `state/tmux-calls.log`; the current
  `real_ledger_hits` returns the file (probe in this propose). Green — after the change the same plant returns
  nothing, and the 12b-j section stays green with it in place.
- **R2 exact-path legs**: plant the same trace at `docs/team/inbox/leak.md`, `state/phantom.log`,
  `state/tmux-calls.log.1`, `state/nested/tmux-calls.log` → each named; `state/bg/gate.log` → not named. After
  the change the scan's output is exactly the ledger files, no more and no fewer.
- **R3 rotation marker**: red — seed 2100 lines, one gated call, first line `seed 1102`, `grep -c rotation` = 0.
  Green — first line matches `<ISO> · rotation · dropped=1101`, exactly 1000 call lines follow, the newest call
  line is last; a second rotation cumulates (`dropped=2201` in the fixture's numbers).
- **R4 guard still bites**: re-plant the inbox trace with the change in place → the scan (and the section's
  negative control) turns red again; a scratch tree where the exclusion is widened to a basename glob makes the
  `.log.1`/nested legs red, which the fixture catches.

## Risks / Trade-offs

- *The audit log could be forged directly* (a fixture writes a fake call line) → accepted: the file is a record,
  not project state; a forged line changes no `team` behaviour, and its own content assertions (fields, bound,
  action vocabulary) still run against it. The scan's promise is about ledger pollution.
- *The marker changes the line count the 31c ⑤ fixture asserts* → the apply updates that fixture in the same
  commit; the spec scenario is written as "1000 call lines + one marker" so the number is unambiguous.
- *A rotation racing two concurrent calls* can lose one marker write and keep the previous one → the surviving
  marker still says the log is incomplete; no call line newer than the last rotation is lost, which is the
  guarantee that matters.
- *The cumulative count needs the previous marker parsed at rotation time* → it runs only when the bound trips
  (never on the under-bound path), and a missing/unparsable marker falls back to counting this rotation only,
  which is still a truthful "history was dropped".

## Migration Plan

No deployed state to migrate: the change is a scan scope plus one line shape, and no reader depends on the log's
exact line count. Rollback is reverting the branch; the log needs no repair either way (old lines remain valid
under both shapes).
