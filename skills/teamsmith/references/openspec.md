# OpenSpec: the five-phase pipeline and its gates

OpenSpec owns **what must hold** (requirements with scenarios) and the change artifacts; teamsmith owns the
**evidence** (briefs, reports, reviews, decisions). This document covers the part OpenSpec cannot know: **how the
process is run here** — which phase runs, in whose hands, and what has to be true before the next one starts.

It deliberately does not repeat OpenSpec's own documentation (artifact anatomy, requirement/scenario syntax, the
CLI reference, `validate` output). Those live where they are generated and maintained; §0 says where.

> Scope note (D23): teamsmith **uses** OpenSpec, it does not re-implement its validation. There is no custom
> delta-semantics checker in the gate; delta mistakes surface at the trial archive above. If the same class bites
> twice in real work, the answer is an upstream issue against `@fission-ai/openspec`, not a local mirror.

## 0. Where the authoritative OpenSpec documentation is

- **The phase commands themselves** — `.pi/prompts/opsx-*.md` and `.pi/skills/openspec-*/SKILL.md`, generated for
  this project's agent tool (`openspec init --tools pi`). That is what an agent actually follows. They describe the
  *mechanics* of a phase (how to explore, how to write the artifacts); **who may invoke a phase, and behind which
  gate, is teamsmith's rule, not theirs** — see §1, §2 and §4.
- **The artifact instructions** — `openspec instructions <artifact>` (proposal / specs / design / tasks / apply /
  archive) and `openspec context` (the project context and rules an AI sees).
- **The workflow schema** — `openspec/config.yaml` (`schema: spec-driven` plus the project's per-artifact rules).

Two teamsmith-side facts frame everything below: OpenSpec is a **required dependency** (`team doctor` and
`team paths` resolve `TEAM_OPENSPEC_BIN` / `TEAM_SPEC_DIR`), and `tests/spec-lint.sh` is the falsifiability
companion of `openspec validate` — structure alone can be green on a spec that cannot fail, so the gate runs both.

## 1. The pipeline: five phases, five owners, five gates

In Pi the commands are `/opsx-explore`, `/opsx-propose`, `/opsx-apply`, `/opsx-verify`, `/opsx-archive`; in another
CLI they are the equivalent prompt/skill files (§0).

| # | Phase (command) | Owner | Hand-in | Hand-out (artifact) | Gate before the next phase |
|---|---|---|---|---|---|
| 1 | `opsx-explore` | an **explorer** worker — never the eventual implementer (the verify agent, or a dedicated explorer) | the user's request / problem statement, existing specs and code | exploration report: options, risks, recommended approach, effort — written as the task's report | **PM**: accepts the approach, records the decision in `docs/team/DECISIONS.md`, and writes the propose brief |
| 2 | `opsx-propose` | the **explorer** (the same agent — it holds the context) | the accepted approach | `openspec/changes/<id>/` (proposal, delta specs, design, tasks) — **planning only, no code** (the workflow itself states this boundary) | **PM proposal review — a recorded gate, same standing as `team review`**: `openspec validate --all --strict` + `tests/spec-lint.sh` green **and** the verdict written to `docs/team/reviews/<change>-proposal.md` as ACCEPTED (§4). **No apply brief may be dispatched before that.** |
| 3 | `opsx-apply` | a **dev** agent, different from 1 and 4 | the change + the brief | code committed on its task branch + report | **independent verification** is dispatched to a different agent |
| 4 | `opsx-verify` | an **independent verify** agent (never the implementer) | the change, the landed code, the report | verification record `docs/team/reviews/<ID>.md` + findings; every scenario of the change exercised, with red/green evidence | **PM**: re-runs the gate on the merged tree, decides `done`, and only then proposes archiving |
| 5 | `opsx-archive` | **PM** (it changes the ledger) | the verified change | `openspec/changes/archive/<date>-<id>/` + updated capability specs | **the user** confirms; the PM may confirm as the user's proxy only when it states that plainly and records why (small, reversible, already covered by the approved approach) |

An exploration whose conclusion is "not worth doing", and a verification that fails twice, do not advance: see §7.

## 2. One phase = one task = one owner

- The phases are **never merged into a single brief**: explore, propose, apply, verify and archive are five briefs
  (or five gate decisions for the phases the PM owns), each with its own `task:` id, `agent:`, `deps:` and `phase:`
  header line.
- **No agent verifies its own work** — the `team review` rule applied to the OpenSpec phases. The verify phase is
  owned by an agent that did not implement, and the apply phase by an agent that did not propose. Explore and
  propose may be the same agent (it holds the context) — but neither may apply its own proposal.
- A phase is not a formality: its hand-out is the **artifact on disk**, and the PM checks the artifact, not the
  agent's account of it. Reports and reviews stay the evidence; nothing here replaces `reports/` + `reviews/`.

## 3. How it maps onto teamsmith

| OpenSpec object | teamsmith object |
|---|---|
| change (`openspec/changes/<id>/`) | the requirement-level unit; its id goes in the brief's `change:` line |
| the five phases | the brief's `phase:` line (`explore\|propose\|apply\|verify\|archive`) |
| who runs a phase | the brief's `agent:` line |
| the phase order | `deps:` in the briefs (propose depends on the accepted exploration, apply on the ACCEPTED proposal review, verify on the landed branch) |
| the gates | `docs/team/reviews/**` records, `team board set <ID> done`, `BOARD.md` |
| the artifacts | `openspec/changes/<id>/`, and after archive `openspec/specs/<capability>/spec.md` |

The board carries the tasks, the change carries the requirements, the ledger carries the evidence. There is still
only **one** spec system: a promise that must hold goes into a spec; reasoning and guidance go into `references/`;
an execution slice goes into a brief. Never grow requirement lists or spec copies inside briefs, reports or
`docs/team/**`.

## 4. The PM proposal review: a recorded gate between propose and apply

After `opsx-propose` and **before the first apply brief**, the PM reviews the change artifacts and writes the
verdict down. It is not "the PM glanced at it": it has the same standing as `team review <ID>`, and its record is
`docs/team/reviews/<change>-proposal.md`:

```md
# <change> · PM proposal review

time: 2026-01-01T00:00:00Z · reviewer: pm · verdict: **ACCEPTED**   # or **NEEDS-CHANGES**

## Commands run (real output, not a promise)
$ openspec validate --all --strict        # → … exit 0
$ bash skills/teamsmith/tests/spec-lint.sh # → … 0 violation(s)
$ <a command the proposal itself promises> # → spot-checked: it exists and runs

## Findings (one line per checklist item)
1. matches the approved exploration — PASS
2. observable … — PASS

## Required changes (NEEDS-CHANGES only)
- <item> · <what must change> · <who changes it>
```

- **No apply task may be dispatched before the verdict is ACCEPTED.** A revised proposal is re-reviewed and the
  record updated; a change that was agreed in conversation is still not an accepted proposal.
- A **NEEDS-CHANGES** verdict names the checklist item, the evidence that is missing, and the owner of the fix.
- The review looks at the **planning artifacts**, not at code — proposals are planning only.

### The PM's proposal review checklist (eight points, followed literally)

1. **Matches the approved exploration** — no silent widening or narrowing of scope; call out scope creep *and*
   scope cuts.
2. **Observable** — the delta specs describe only externally observable behavior (commands, exit codes, files on
   disk), and every scenario can fail.
3. **Closed coverage, both ways** — every affected requirement has at least one task item, and every task item
   points at a requirement or scenario (no orphan tasks).
4. **Explicit boundaries** — the proposal states what is out of scope, and who may not touch which paths.
5. **Acceptance commands** — copy-pasteable and existing: the PM runs `openspec validate --all --strict` and
   `tests/spec-lint.sh`, then spot-checks the commands the proposal itself promises.
6. **Defect fixes state the flip** — red → green, or "break the implementation → the guard must fail → restore it".
7. **No conflict with existing specs** — grep `openspec/specs/` before accepting a statement: a duplicate or a
   supersession must be a MODIFIED/REMOVED delta, not a parallel statement in a new requirement.
8. **Granularity** — can one apply brief finish it? If not, the split and its order are named (several briefs
   under the same change, applied and verified one by one).

## 5. What the PM does at each gate

| Phase | Read | Must be true | Write |
|---|---|---|---|
| explore | the exploration report, the specs and code it cites | the recommendation is one option with its risks and effort, and the scope is the user's request — not a wish list | the decision in `docs/team/DECISIONS.md` + the propose brief |
| propose | `openspec/changes/<id>/` end to end | both spec gates green and all eight checklist points pass | `docs/team/reviews/<change>-proposal.md` = ACCEPTED (or NEEDS-CHANGES + per-item findings) |
| apply | the brief, the change, the branch, the report | the branch carries exactly the change's scenarios; the acceptance commands really ran; nothing outside the boundaries was touched | the verify brief (a different agent) |
| verify | the change, the landed code, the verification record, the diff | every scenario was exercised with red/green evidence, on a clean independent checkout | `docs/team/reviews/<ID>.md`; then `team board set <ID> done` after re-running the gate on the merged tree |
| archive | the verified change + the user's confirmation | every task of the change is done and landed; **trial archive first**: `cp -r openspec /tmp/trial && (cd /tmp/trial && openspec archive -y <id>)` — OpenSpec catches some delta defects (a MODIFIED naming a requirement the base lacks, an ADDED collision, …) *only here*; the trial surfaces them while fixing is cheap, and a failure hands the change back to apply with the archiver's message | then `openspec archive -y <id>` for real, and the user's confirmation recorded (who confirmed, or why the PM acted as proxy) |

`team board set <ID> done` reads those same phases from the brief: `explore` is done on the PM's recorded
acceptance (a `DECISIONS.md` entry whose heading names the task, or `reviews/<ID>.md`), `propose` only on an `ACCEPTED`
`reviews/<change>-proposal.md` (a `NEEDS-CHANGES` record refuses and says so), `verify` on the task's review
record, and `archive` once the change id appears under `openspec/changes/archive/`; `apply` keeps the code-task rule
(non-`FAIL` review record or merged branch tip). A brief with no `phase:` line (or `-`, or an unknown value) keeps
exactly the code-task rule — the guard is never widened for tasks that do not declare a phase, and an archived
directory is evidence of the archive, not of the user's confirmation.

The same phase evidence is what clears a phase task from the digest's pending-verification list: a board row the PM
has already moved to `done` is never listed again (the evidence was checked at the transition, so the list does not
second-guess it), and while a phase task is still in progress the digest names the phase's own next step — for
`explore`/`propose`/`archive` the deliverable does not live on a code branch, so a generic `team review <ID>` would
send the PM at the wrong artifact.

Staleness is judged per phase against the revision a record is bound to: for a `verify` task that is the branch named
in the record's header (`分支:`) — the verifier's own branch carries its report commit, so a new commit there does not
expire the record, while a new commit on the reviewed branch does and puts the task back on the pending list — and for
tasks with no `phase:` (including `apply`) it stays the code-task rule, the record against the task branch's current
tip.

## 6. Preconditions

- The phase commands must be generated for the agents' tool: `openspec init --tools pi` writes
  `.pi/prompts/opsx-*.md` and `.pi/skills/openspec-*/SKILL.md` (use the tool's own id for a non-Pi CLI). Once a
  project has them, `openspec update` refreshes them; it finds the configured tools from the generated files and
  answers "No configured tools found" when there are none. Commit the generated files with the project.
- Without them, a phase cannot be invoked **as a command**: an agent can still do the same steps by hand from
  OpenSpec's own docs, but then the PM cannot check that the phase really ran its workflow, the planning-only
  boundary of propose is only a convention, and the numbered phases in a brief point at nothing. Prefer generating
  and committing them.
- Resolve the CLI and the spec root: `team paths` (and `team doctor`) print `TEAM_OPENSPEC_BIN` / `TEAM_SPEC_DIR`;
  with `TEAM_REQUIRE_OPENSPEC=1` (the default) a missing CLI or spec directory fails the doctor. The gate needs the
  CLI on `PATH` (or an absolute path in `TEAM_OPENSPEC_BIN`).

## 7. Escalation: stopping a change

- **Exploration says "not worth doing"** → the PM records the decision in `DECISIONS.md`, does not dispatch
  propose, and says so in the ledger. Nothing is archived, nothing is left half-planned.
- **Verification fails twice** → the PM **stops the change**: leave it in `openspec/changes/<id>/` with a note
  naming the blocker (and the failed findings), rather than pushing it through. The next PM can see it.
- **The user is not available for the archive decision** → the change stays open; the code can already be merged
  and `done` on the board (the ledger proves it), only the archive waits for the user.
- Never archive to make a red thing disappear: `openspec archive` merges the deltas into `specs/` — after it, the
  spec set claims the change is real. Archive only after the gate passed and the user confirmed.
