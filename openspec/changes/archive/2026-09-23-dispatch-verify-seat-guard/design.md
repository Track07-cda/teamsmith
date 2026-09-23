# design: dispatch-verify-seat-guard

## Context

See `proposal.md` — Why for the motivation. The facts that shape the approach:

1. **The rule already exists on paper, in the ownership table.** `docs/team/OWNERSHIP.md`'s roster row for the
   verification seat says the seat *does not change implementation* (「verify 席位例外：无论任务书怎么写，都不改实现」),
   and the same file explains why: its value is independence. What is missing is enforcement at the one place the
   mistake is made: `team dispatch`.
2. **The failure happened twice, and the seat caught it by hand.** M53 was first dispatched to `verify`, then P36:
   both briefs carry `phase: apply` (P36), the seat answered `BLOCKED` and did nothing, and the work was re-dispatched.
   D36 (`docs/team/DECISIONS.md`) is the user's decision to turn it into a guard.
3. **A pre-window guard family already exists.** `team_dispatch_change_guard`
   (`skills/teamsmith/scripts/lib/cmd-agents.sh:506`) implements the four change-centric rules, and
   `team_cmd_dispatch` calls it (`:684`) before the worktree/branch checks and before any window — the same place
   the new guard belongs. All four share one contract: refusal before any window, also under `--print`, a warning
   plus exactly one audit line under `--force` (`TEAM_DISPATCH_AUDIT_LINES`, written only after a real dispatch at
   `:855`), and no board write on refusal. The new guard is the fifth rule and inherits that contract unchanged.
4. **The inputs.** `phase:` is already a strict field (`team_task_phase`, one of five; `-`, a missing line or an
   unknown value read as undeclared). `grant:` is not: the brief template
   (`skills/teamsmith/templates/task.md.tmpl`) does not render it, yet real apply briefs use it (M53:
   `grant: extension/team-inbox-watch.ts · scripts/lib/{outbox,common,cmd-project,cmd-watch}.sh · … ·
   tests/smoke.sh`). The guard reads it, so the template must declare it (Decision 6).
5. **The spec base state decides the delta operation.** `openspec/specs/verification/spec.md` lists twelve
   requirements (lines 9–312) and none of them is the author rule —
   `The verifier of a change is not one of its authors` lives in the *unfinished* change
   `openspec/changes/change-centric-discipline/specs/verification/spec.md:3` (applied as B5, not archived).
   `openspec validate --all --strict` does not compare a MODIFIED delta against the base, but OpenSpec's trial
   archive does; a MODIFIED naming a requirement the base lacks would fail there. Both deltas here are therefore
   ADDED (Decision 4).
6. **The fixtures already exist.** Smoke sections 12g–12k (change-centric discipline) build scratch projects with
   `p24_project`/`p24_brief`/`p24_team` and dispatch through `p24_dispatch` on the record-only tmux shim, asserting
   "no window" by an empty call log and "board unchanged" by the row. The new section reuses that family; the guard
   is pure logic, so it runs in fast and slow mode alike.

## Goals / Non-Goals

**Goals:**

- Make "the verification seat does not implement" enforced by `team dispatch` before any window, with the same
  override and audit discipline as the four existing guards.
- Keep the seat's legitimate work — proposal reviews and reconnaissance — allowed without a special case.
- Make the premise explicit and reviewable: which seat counts as the verification seat is named in config, not
  hidden in a code literal.
- Leave every document that enumerates the dispatch guards true (protocol §5b, the AGENTS/PROTOCOL paragraphs).

**Non-Goals:**

- No change to the four existing guards, to `team review`, or to the "verifier is not an author" rule (which stays
  in `change-centric-discipline` and keeps its own `--force` path).
- No roster semantics change: the seat is still just a name in `TEAM_AGENTS`; no new role system.
- No doctor/report surface for the guard (a possible follow-up, Open Questions).
- No attempt to classify *who actually did the work* after the fact: the guard judges the brief it is given.

## Decisions

### 1. The seat is named by `TEAM_VERIFY_SEAT` (default `verify`), not hard-coded

The guard cannot know which roster name is the verifier unless the project says so. `TEAM_VERIFY_SEAT` names it
(a single roster name; class `apply`, kind `text`, default `verify`, section `roster`), and unset or empty resolves
to `verify`. Alternatives considered:

- **Literal `verify` in code** — the project's convention, and it protects *this* project. Rejected: renaming the
  seat (a legitimate choice) would silently drop the guard, which is the failure mode D36 exists to remove; and the
  tool would hide a project decision in a literal.
- **Scan the roster for a seat named `verify`** — same silent failure with extra steps.
- **A list of seats (`TEAM_VERIFY_SEATS`)** — deferred: one seat per project is today's convention (OWNERSHIP's
  roster); a second verification seat is a future change, not this one.

The value is *replace*, not *add*: with `TEAM_VERIFY_SEAT=checker`, `verify` is an ordinary seat again (pinned by
`verification`'s second scenario). Blank cannot switch the boundary off: unset and empty both mean `verify`.

### 2. Trigger: `phase: apply`, or an undeclared phase with an implementation `grant:`

- `phase: apply` → refuse (this is the D36 shape: M53 and P36 both carried apply work).
- No usable phase (missing line, `-`, or a value outside the five) *and* at least one implementation path in
  `grant:` → refuse, and the message names those entries ("you listed implementation paths").
- No usable phase and no implementation grant (or no `grant:` line) → proceed.
- `explore`/`propose`/`verify`/`archive` → proceed: these are the seat's own phases (proposal reviews,
  reconnaissance), and the user's adjudication is explicit that they are allowed.
- Any other seat (`agent: dev`) → proceed: the guard is about the seat, not about `apply`.

Alternatives: refusing *any* `grant:` for the seat (rejected: a verify task legitimately writes
`docs/team/reports/…` and `openspec/changes/…`; that is not implementation); refusing only `phase: apply` (rejected:
misses the adjudicated undeclared-phase case, which is exactly how a mislabeled brief hides).

### 3. `grant:` classification is conservative: implementation unless it is ledger/spec

An entry counts as an implementation path unless it is `docs/team`, `openspec`, or lies under `docs/team/` or
`openspec/`; the refusal prints the entries it read that way. Rejected alternative: a whitelist of implementation
prefixes (`skills/**`, `scripts/**`, `extension/**`) as sketched in the brief. Real briefs write **skill-relative**
paths — M53's grant is `extension/team-inbox-watch.ts · scripts/lib/… · tests/smoke.sh` — and a repo-relative
whitelist silently misses all of them, producing exactly the false green this project forbids. The conservative
direction can only produce extra refusals, and those are visible (the entries are printed) and one audited
`--force` away.

### 4. Both deltas are ADDED; the "next to the author rule" sentence is not a MODIFIED

The verification delta could not be a MODIFIED of the author rule: that requirement is not in the base spec yet
(Context 5), so the delta would survive `validate` and fail the trial archive. The boundary is stated as its own
requirement, "The verification seat does not implement", placed in the verification capability next to the author
rule's subject matter, and the dispatch delta adds the enforcement requirement. When `change-centric-discipline`
archives, the two requirements sit side by side and neither names the other's delta. If that change archives first,
this change's ADDED delta stays valid unchanged.

### 5. The guard is a separate pre-window function

`team_dispatch_seat_guard` sits next to `team_dispatch_change_guard` in the call sequence (`cmd-agents.sh:684`),
before worktrees, branches and windows. It is separate because it shares none of the change read-model: it applies
to change-less briefs too (P36 was one), it reads only the brief header, the roster name and the config key, and
"neutering one call" is the whole red side of the flip. The `--force` audit reuses `TEAM_DISPATCH_AUDIT_LINES`, so
`--print` writes no state and a refusal leaves the board alone, exactly like the four existing rules.

### 6. `grant:` becomes a first-class brief field, and the key is registered in the config schema

The guard reads what the template must therefore declare: `templates/task.md.tmpl` gains the `grant:` header line
with its inline explanation (the same way `deltas:` is declared today). The config key gets a schema row and a
`references/config.md` row so `team config list` shows the premise and `team config set TEAM_VERIFY_SEAT <seat>`
works — an unregistered key would make the documented knob a hidden one.

## Risks / Trade-offs

- **[An undeclared phase with no `grant:` line is not refused]** → There is no signal to judge; inventing one (for
  example refusing every undeclared-phase brief for the seat) would block the seat's reconnaissance and exceed the
  user's adjudication. Mitigation: the brief's `phase:` line is the contract, and the guard's message tells the PM
  which signal was missing whenever a grant exists. Recorded for a possible future tightening.
- **[`phase: verify` with an implementation grant in the same brief proceeds]** → The declared phase wins, per the
  user's adjudication; the contradiction is visible in the header for the PM's proposal review. Tightening this
  (giving `grant:` a veto regardless of phase) is a future decision, deliberately not slipped in here.
- **[A `TEAM_VERIFY_SEAT` value that is not a roster name makes the guard inert]** → The default cannot be blanked,
  the value is visible in `team config list`, and the refusal names the seat it used. Mitigation candidate recorded
  under Open Questions.
- **[A false positive on a non-ledger path]** → The refusal lists the entries it read and `--force` proceeds with one
  audit line, so the cost is a visible explanation, not a dead end.
- **[The verification requirement is ADDED while `change-centric-discipline` is pending]** → No MODIFIED delta
  names anything from an unarchived change, so archive order cannot break either change; the trial archive in the
  apply plan proves it.
- **[The docs that enumerate guards drift]** → The protocol's "four dispatch guards" heading, the AGENTS/PROTOCOL
  paragraphs (byte-identical to the repo `AGENTS.md` per smoke §12k) and the template are explicit items in
  `tasks.md`.

## Migration Plan

None: the change is additive. A project with an unset `TEAM_VERIFY_SEAT` gets `verify` as the seat, which is the
convention the init flow already recommends (`dev` + `verify`); any refusal has the documented `--force` escape and
a verify-phase route. No spec or config migration is needed.

## Open Questions

- Should `team doctor` report a `TEAM_VERIFY_SEAT` whose value is not a roster member (the guard cannot fire then)?
  Deferrable: it changes no requirement, approach or task item; a later change can add the doctor row.
