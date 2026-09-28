# Tasks: `agent-death-reason`

Planning only — nothing in this file is executed by the propose task (P101). **One apply brief + one
independent `opsx-verify` brief** (a different agent from the applier). One apply is recommended because
the mechanism is a single reader with thin callers, and three callers live in the same two bash files;
splitting it would put two writers on `cmd-watch.sh`. The PM sequences the apply normally; the verify
runs on its own worktree after the apply's report.

Coverage map (requirement → items):

- **R1** *A seat death has a classified cause from a closed set, and an unknown death is never given one*
  (`watchdog`) → 1.1–1.4
- **R2** *A cause belongs to the current launch of a seat, never to a previous one* (`watchdog`) → 1.5,
  3.3
- **R3** *The seat surfaces name the cause, its source and the raw evidence line* (`watchdog`) → 2.1–2.4
- **R4** *The patrol reports each abnormal death exactly once, and never a normal one* (`watchdog`) →
  3.1–3.5
- **R5** *A seat-death knock carries the seat, the cause and the raw evidence line, and never invents a
  cause* (`notify-and-inbox`) → 3.2–3.3
- **R6** *The agents block carries each seat's death cause* (`panel`) → 2.5–2.6
- gate evidence → 4.1–4.2; the independent verify phase → 5.1–5.5.

How each requirement is re-checked (run what → read which part → expected value):

| Req | Run | Read | Expected |
|---|---|---|---|
| R1 | `bash skills/teamsmith/tests/death-cause.sh` | the matrix lines | each of the five categories classified from its fixture frame with the raw line; the two counter-examples (`quota` prose, `rate limit` prose) are `unknown`; an unreadable seat is `unknown`; a `0`-exit seat is `normal` with no cause line |
| R1 | the same script with a fixture frame beyond `TEAM_DEATH_SCAN_LINES` | the classification line | `unknown` (the bounded tail is real, not decorative) |
| R2 | the script's restart block | `team status`, the digest [1] line, the agents block | after a new launch (`started`/nonce moved) no previous cause is shown; the stale saved corpse does not resurrect it |
| R2 | the script's dedupe block | `state/deaths.log` + the queue | one record line per identity across three ticks; a new launch's same-shaped death is a new identity |
| R3 | the script's surface block | `team status <ID>`, `team digest`, `team digest` [1] | the `原因：quota（来源：pane · …）· 原文：…` line; `停了的 agent 1（dev=quota）`; a closed/running seat shows no cause |
| R3 | a fingerprint of `.pi/team/state/**` before/after the reads | the fingerprints | identical (contents and mtimes) |
| R4 | the script's tick block (fixture patrol) | `state/deaths.log`, `state/outbox/`, `state/watchdog.log` | exactly one record and one knock for one death in three ticks; `normal` → zero; standby tick → zero, then after `standby off` exactly one |
| R5 | the script's knock block | the queued payload | seat + category + source + raw line + `team status <ID>`; an unknown death's payload names `unknown` and none of the other categories; a busy PM box queues instead of gluing |
| R6 | `team __panel-data --block agents` on the quota corpse fixture | the JSON entry | `cause=quota`, `cause_source=pane`, `cause_line` with the frame; `state`/`pane`/`pane_exit` unchanged; a running seat has no cause keys |
| R6 | `team monitor --print` (full layout) and `26-a`'s rebuild | the agent row; `cmp` | the state cell carries ` · quota`; the rebuilt `panel.js` is byte-identical to the committed one |
| all | `PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict`; `bash skills/teamsmith/tests/smoke.sh </dev/null` | the verdict lines | validate green; the full suite green (the updated exact `team_pending_text` assertion included, never deleted) |

Path grants the apply brief must state (OWNERSHIP): `skills/teamsmith/scripts/lib/**` (the reader and
its callers), `skills/teamsmith/scripts/panel/src/**` + `skills/teamsmith/scripts/panel/panel.js`
(rebuilt, never hand-edited), `skills/teamsmith/tests/**` (the new `death-cause.sh` + the smoke section +
the assertions the feature's contract changes), and the change's own `tasks.md` checkboxes. Everything
else stays PM-owned: `openspec/specs/**`, `docs/team/{tasks,BOARD,ROADMAP,DECISIONS,OWNERSHIP}.md`,
`extension/**`, `skills/teamsmith/references/**`. A need there is a `BLOCKED:` report, not an edit.

Fixture notes: every fixture clears inherited team identity (`env -u TEAM_ROOT -u TEAM_MAIN_ROOT
-u TEAM_PROJECT -u TEAM_SESSION -u TMUX -u TMUX_PANE`) and writes only inside its own scratch tree; the
pure-logic half needs no tmux (it writes `state/dispatch-<agent>-pane-dead.txt`,
`state/dispatch-<agent>.spawn`/`.exit`, `state/<agent>.env`, session JSONL files) and belongs in FAST;
the live half (one real dead pane holding the quota frame) renders visibly as `SKIP` without tmux, like
the P55 section; no fixture kills the shared tmux server or a foreign session (P55's pgid-checked kill
pattern is the model); nested suite runs use `TEAM_SMOKE_FAST=1`, a private lock and their own temp root.

## 1. The reader: classification, sources, current launch (watchdog R1, R2)

- [ ] 1.1 `lib/common.sh` (or `cmd-agents.sh`, next to the pane census): the classification core —
  `team_death_classify_line` with the D3 frame test and the precedence table, and
  `team_seat_death_fields <agent>` returning `category⇥source⇥time⇥raw`, empty when the seat has no
  abnormal death. Verify: the fixture matrix (five category frames → five categories; the D46 frame →
  `quota` and not `auth`; the two prose counter-examples → `unknown`; an empty/unreadable scene →
  `unknown`; a `0`-exit seat → no cause/`normal`) and the empty result for a running or task-less seat.
- [ ] 1.2 The pane-side reader reuses the existing scene recency order (live corpse → saved corpse file
  → tail file → the current launch's nonce-matched exit evidence) with the `TEAM_DEATH_SCAN_LINES` bound
  (default 40, non-numeric → 40), takes the **last category-matching line** in that tail, and keeps its
  record time (`pane_dead_time`, the saved corpse's `dead_time`, the tail file's mtime, or the exit
  evidence's nonce). Verify: fixtures for all four sources; a frame older than the bound → `unknown`; a
  trailing unrelated error does not mask an earlier matching frame.
- [ ] 1.3 The session-side reader: `team_agent_session_latest` finds the newest JSONL for the seat's
  worktree including the `--fresh` naming, and `team_session_error_line` extracts the last assistant
  entry with `"stopReason":"error"` + `"errorMessage"` from a bounded 64 KiB tail (entry `timestamp` as
  the record time); an unparsable line yields no session evidence. Verify: fixtures for a quota
  `errorMessage`, a `--fresh`-named file, a torn/truncated tail (no evidence, no mangled line), and a
  seat with both sources where the newer one wins (session newer → `source=session`, pane newer →
  `source=pane`).
- [ ] 1.4 The `normal` and unknown rules are positive evidence only: exit evidence (`state/dispatch-
  <agent>.exit`, nonce matched to `.spawn`) status `0` or `pane_dead_status=0` ⇒ `normal` (no cause, no
  record, no knock); a non-zero/signal exit without a recognized frame ⇒ `unknown`; a completed session
  turn alone is **not** clean-exit evidence. Verify: the pause fixtures in `death-cause.sh` pin each
  direction, including a killed pane (`signal=9`) with no frame → `unknown`.
- [ ] 1.5 Current-launch scoping and the records: evidence older than `state/<agent>.env:started` (or
  with a foreign exit nonce) is ignored; identity `(seat, category, anchor)` and the append-only
  `state/deaths.log` line per D5, bounded to the last 500 lines. Verify: the restart block (a classified
  death, then a new launch → no cause anywhere; a stale saved corpse with an old `dead_time` → no
  cause), and the identity block (one line per identity; a second launch's same-shaped death → a new
  line).

## 2. The visible surfaces (watchdog R3, panel R6)

- [ ] 2.1 `team status <ID>`: append the D7 cause line to the existing seat section, only when a cause
  exists, keeping the existing condition/scene output byte-stable otherwise. Verify: the quota corpse
  fixture shows `原因：quota（来源：pane · …）· 原文：<frame>`; a seat with no abnormal death prints no
  cause line; a running/closed seat prints none.
- [ ] 2.2 `team digest` [1]: the `停了的 agent N` fragment carries the `dev=quota, dev2=unknown` list
  (bare count when unreadable). Verify: the two-seat fixture; and update the smoke suite's exact
  `team_pending_text` equality to the new expected text **with the cause list present**, never by
  deleting the assertion (the `sig` stays count-based, so the batch rate limit does not re-arm).
- [ ] 2.3 The recorded fallback: when the live read is empty/unknown and the newest current-launch record
  exists, surfaces report it with source `recorded`; no record → no cause. Verify: delete the corpse
  scene after a recorded quota death → `team status` shows `recorded` + the raw line; restart the launch
  → no cause (R2's guard still applies to the record path).
- [ ] 2.4 Read-only stays true: fingerprint `.pi/team/state/**` (contents + mtimes) across all the read
  surfaces and assert it is unchanged. Verify: the fingerprint comparison in `death-cause.sh`.
- [ ] 2.5 The agents block (bash): add `cause`/`cause_source`/`cause_line`/`cause_time` for abnormal
  deaths only, leaving `state`/`pane`/`pane_exit` byte-stable. Verify: JSON assertions for the quota
  corpse, a running seat (no keys), and a `pane=dead` seat whose `state` stays `exited`.
- [ ] 2.6 The printed row and the bundle: `panel/src/types.ts` gains the optional fields and
  `panel/src/layout.ts`'s state cell appends ` · <cause>` (the minimal layout drops it with the state
  text); rebuild with `bun install --frozen-lockfile && bash skills/teamsmith/scripts/panel/build.sh` and
  commit the bundle. Verify: the printed row on the fixture; `26-a`'s sandbox rebuild is byte-identical;
  a hand-edited bundle fails that check.

## 3. The patrol and the knock (watchdog R4, notify-and-inbox R5)

- [ ] 3.1 The tick step in `team_watch_once`, placed **before** the existing outbox drain so a knock
  leaves in the same tick: walk the stopped population (`task=` non-empty, `team_agent_live` false),
  classify, and for an unrecorded abnormal death **with a readable source** append the record before the
  knock (D6). Verify: the three-tick fixture → one record line + one queue entry; a fourth tick →
  nothing new; `normal` → zero; a stopped seat with no readable source → the pending line names
  `unknown`, with no record and no dedicated knock; the reader failing (e.g. an unreadable state dir)
  leaves the patrol's existing outputs and exit status unchanged with the bare count.
- [ ] 3.2 The knock: one `knock` outbox entry per identity, `--from pulse`, `--dedup death:<identity>`,
  payload per D7 (seat + category + source + time + raw line + `team status <ID>`; `unknown` names no
  cause); goes through the delivery guard (a draft in the PM box → queued, not glued). Verify: the
  payload assertions and the busy-box fixture (the draft is byte-stable, the queue holds the entry).
- [ ] 3.3 Standby and dedupe semantics: under `team standby on` the record is **not** written and no
  knock is enqueued; after `standby off` the next tick records and knocks exactly once; a crash-shaped
  case (record present, queue entry absent) sends nothing more. Verify: the standby fixture and the
  dedupe fixture in `death-cause.sh`; the knock's identity equals the record's identity (asserted, not
  assumed).
- [ ] 3.4 `state/deaths.log` hygiene: one line per identity, the last 500 kept, appended only by the
  patrol (never by a read path), and the raw line on it matches the knock's. Verify: the file's line
  count/rotation fixture and the read-only fingerprint of 2.4.
- [ ] 3.5 Blast-radius inventory: the suite has 33 `watch --once` invocations, and the death record and
  knock are new observable state in every fixture with a stopped seat. Verify: `TEAM_SMOKE_FAST=1 bash
  skills/teamsmith/tests/smoke.sh </dev/null` is green after the change; every assertion the new state
  moves is updated to the new expected text (the cause visible), and any fixture that should not be a
  death is given `normal`/unreadable evidence — the death behavior itself is never gated off or
  weakened to keep a fixture green. The moved assertions are listed in the report.

## 4. Gate and evidence (the apply's own report)

- [ ] 4.1 `bash skills/teamsmith/tests/death-cause.sh` (the whole matrix, pure + live), `TEAM_SMOKE_FAST=1
  bash skills/teamsmith/tests/smoke.sh </dev/null` during the work, and once at delivery the full `bash
  skills/teamsmith/tests/smoke.sh </dev/null`, plus `PATH="$HOME/.bun/bin:$PATH" openspec validate --all
  --strict` and `git status --porcelain`. Verify: the tails in the report, the full-suite verdict line,
  and the changed-file list matching the grant.
- [ ] 4.2 Flip evidence in the report: the before (`停了的 agent 1`, no cause anywhere) and after
  (quiet → `quota` with the raw line, one knock per death) outputs on the same fixture; and the
  break-it direction — disable the frame test (or the record-before-knock order) → the guard fixture goes
  red → restore it. Verify: the red/green tails are in the report, not a description of them.

## 5. Independent verification (the `opsx-verify` brief)

- [ ] 5.1 A different agent re-runs the full gate on the delivered tip and reproduces the R1 matrix with
  **its own** fixtures (not the apply's script): a provider frame per category, the two counter-examples,
  an unreadable seat, a clean exit.
- [ ] 5.2 Adversarial: a frame placed beyond `TEAM_DEATH_SCAN_LINES`; a stale saved corpse predating
  `started`; a `--fresh` session file; a torn JSONL tail; a `403 permission_error` **without** quota
  wording (must be `auth`, not `quota`).
- [ ] 5.3 Dedupe/at-most-once: three ticks → exactly one record and one knock; a simulated crash between
  the record and the enqueue → no duplicate after further ticks; standby defers and then reports once.
- [ ] 5.4 Surfaces and read-only: the status/digest/panel shapes on its own fixture; the state-fingerprint
  invariance; the panel row token and the block keys with `state`/`pane`/`pane_exit` unchanged; `26-a`'s
  byte-identical rebuild.
- [ ] 5.5 The existing exact-equality assertion (`team_pending_text`) still exists in the suite and matches
  the new output; no assertion was deleted or weakened; `git diff` touches only the granted paths.
