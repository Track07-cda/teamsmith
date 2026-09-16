## Context

A backfill: nine shipped behaviours (`D1–D4`, `A1–A2`, `W1–W3`) get written down after the fact. The tool does not
change, no test is added, and the project's whole test suite is green before and after — so smoke cannot fail for
anything this change does. Everything worth checking here is a document and its tie to a runnable red.

The gate this change meets is `openspec validate --all --strict` plus `bash skills/teamsmith/tests/spec-lint.sh`.
C0 (`spec-delta-gate`) adds six delta-applicability rules to that second step and is still in flight on this branch's
base; the report runs that lint from the C0 branch as extra evidence, but the artifacts are written to be valid under
both the pre-C0 and post-C0 checker (E2 §4, D18).

## Goals / Non-Goals

- **Goal**: every row has a requirement in the capability that owns it, and every scenario names a falsifier that
  exists today (E1 §3.1 / E2 §5).
- **Goal**: the move of the adapter engine is reviewable as one atomic artifact, so a verifier can prove nothing was
  dropped while moving.
- **Non-goal**: a general `team up` / `team resume` contract. C1 pins liveness and the `starting` state, not the
  command surface.
- **Non-goal**: a `watchdog` delta. Its cross-reference to the PM's calls stays true.
- **Non-goal**: any code, test or `references/` change. A row whose only honest fix would be new test code belongs to
  another change (E1 §5.3.3).

## Decisions

### D1 — the engine moves as `REMOVED` + `ADDED`, and the moved block is byte-identical

`RENAMED` cannot cross a capability boundary, and a delta against a capability with no base spec may only add
(probed in E2 §4.3; the C0 rule `delta-operation-on-new-capability` is what makes the wrong shape red at gate time).
So the requirement is removed from `dispatch` with `Reason`/`Migration` and added to `agent-adapters` **unchanged** —
same name, same four scenarios, no rewording. The report's migration diff (`diff` of the base block against the
archived one) is empty, which is the strongest thing a verifier can say about a move: there is nothing to review
except the declared additions around it.

### D2 — `MODIFIED` requirements are restated mechanically, never retyped

`openspec archive` replaces the whole requirement block with the delta's block, so a partial restatement silently
deletes text. Both `MODIFIED` blocks here were extracted from the base spec by script and the new scenario appended;
the report diffs the archived blocks against the base ones and shows the only hunks are the appended scenarios. The
C0 rule `delta-dropped-scenario` is the gate-time net; the diff is the human-checkable one.

**One declared exception (P4 finding F3, applied 2026-09-15):** the base scenario "The branch identity is visible”
olaimed that `team status <ID>` shows the *worktree* recorded for the task. It does not — `team status` prints the
roster row (whose branch column is the worktree's HEAD branch), the BOARD row, the report path and the review
record, and no view prints the recorded worktree (`scripts/lib/cmd-status.sh`). The scenario is therefore rewritten
in this delta to the two things that really are observable — the roster row carries the worktree's branch next to
the recorded task, and `team status <ID>` prints that row plus the board row and the report path — and the smoke
suite pins both halves (`F3：roster 的 dev 行显示工作树当前的分支` …). This is the backfill's core value: a spec
sentence that no command could observe. It is a *declared* rewrite, not a restatement: the restatement rule above
still holds for every other line, and `pkg/40-migration.sh` now fails on any deletion outside this one scenario.

### D3 — one apply brief, three sequential sub-tasks, in dependency order

`dispatch` → `agent-adapters` → `pm-lifecycle`: the move must be reviewable before the capability it lands in is
extended, and the PM's lifecycle last because it reuses the spawn-proof vocabulary the first file introduces. The
order of sections *inside* a delta file is irrelevant to the CLI (E2 §4.2 probed it); the order of the tasks matters
because one change directory has one writer (D18).

### D4 — the A2 default-path promise uses an observable surface

`references/agent-adapters.md` says the empty keys keep the Pi path *byte-for-byte*, and the existing fast assertion
is a library-level render comparison (`smoke.sh:1282`) — an internal function against a hardcoded string. The spec
must not name either. The scenario therefore pins the observable end: `team up` in a fixture project, then the argv
of the process recorded in `state/pm.pid`. Its falsifier already exists (`smoke.sh` §11b2 `①b`/`③` asserts `-c` +
`@pm-prompt.md` for the built-in path); if the PM rejects the surface, the requirement keeps the custom-CLI half and
the byte-identical promise stays prose in the reference doc.

### D5 — the `W2` vocabulary is `running/starting/idle/unknown/foreign/missing`

E1 §3.1 C listed `busy`; the shipped code has no such value (`team_pm_state()` prints exactly those six, and the
pane-busy probe only separates `idle` from `unknown` — `references/protocol.md:164`). A scenario asserting `busy`
would be unfalsifiable *and false*, so the requirement names the six and says the vocabulary is closed. D18 binds
this correction into the proposal.

### D6 — both new capabilities carry a `## Purpose`

Without it, archive writes `TBD - created by archiving …` into the new spec while both gates stay green (E2 §4.4);
the report greps the archived specs for `TBD` as evidence.

## Risks / Trade-offs

- **[A move is indistinguishable from a deletion to every gate]** `REMOVED` checks nothing, `ADDED` needs one
  scenario, archive concatenates. → The migration diff is the only check that can catch a dropped scenario, and the
  verify package owns it (E2 §6.2); `tasks.md` 4.4 makes it an explicit item.
- **[One migrated scenario has no runnable falsifier — known limitation]** `A long prompt does not enter the command
  line` (GIVEN a brief larger than 100 KB / 100KB …) is **not** falsified by anything in the suite today: the byte-for-byte
  `argv[0]` comparison exists only on the PM side (`smoke.sh` §6i), no test anywhere uses a brief over 100 KB, and
  no worker-side comparison of the delivered prompt against its file exists. The block is migrated byte-identical
  (D1) and a backfill may not add test code, so the limitation is recorded here instead of being papered over — the
  scenario is **not** deleted and no unrunnable checker was invented for it. Follow-up queued in `ROADMAP.md`
  ("falsifier for the migrated 100 KB long-prompt scenario"). Reported as P4 finding F1.

- **[The gate in this tree predates C0]** the delta rules that catch a typo'd `MODIFIED` name are not in `main` yet —
  and they never will be: C0 was dropped (D23), so the delta-name class is caught by the trial archive of `tasks.md`
  4.3 instead; the artifacts were additionally run through the C0 lint from the P2.2 branch (green) and through two
  negative controls that fire (`delta-modified-requirement-missing`, `delta-dropped-scenario`), both in P3's report.
- **[A scenario that cannot fail]** A backfill is exactly where "wrote it down" can be mistaken for "verified it".
  → No scenario ships without a named existing assertion; the verify phase's third layer mutates each behaviour in a
  scratch copy and watches the named assertion go red (E2 §6.3).

## Migration Plan

None: no command, config key, layout or behaviour changes. The change directory is the artifact; rolling it back is
deleting it, and `openspec/specs/**` is only written by archive, after verification and the user's confirmation.
