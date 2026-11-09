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
  this project's agent tool (`openspec init --tools pi`; §6 states exactly which of the five phases the installed
  OpenSpec actually generates). That is what an agent actually follows. They describe the
  *mechanics* of a phase (how to explore, how to write the artifacts); **who may invoke a phase, and behind which
  gate, is teamsmith's rule, not theirs** — see §1, §2 and §4.
- **The artifact instructions** — `openspec instructions <artifact>` (proposal / specs / design / tasks / apply /
  archive) and `openspec context` (the project context and rules an AI sees).
- **The workflow schema** — `openspec/config.yaml` (`schema: spec-driven` plus the project's per-artifact rules).

One teamsmith-side fact frames everything below: OpenSpec is a **required dependency** (`team doctor` and
`team paths` resolve `TEAM_OPENSPEC_BIN` / `TEAM_SPEC_DIR`) and it **owns spec management** — the spec gate is
`openspec validate --all --strict`, and a defect validate cannot see surfaces at the trial archive (§5), where
OpenSpec's own machinery speaks.

The writing convention survives as **convention, not gate**: every requirement still carries testable scenarios —
a scenario that cannot fail is worthless, and the PM's proposal review (§4) still rejects such a delta by
judgement. What is gone is the separate checker; no project script re-judges OpenSpec's files.

## 1. The pipeline: five phases, five owners, five gates

In Pi the commands are `/opsx-explore`, `/opsx-propose`, `/opsx-apply`, `/opsx-verify`, `/opsx-archive`; in another
CLI they are the equivalent prompt/skill files (§0).

| # | Phase (command) | Owner | Hand-in | Hand-out (artifact) | Gate before the next phase |
|---|---|---|---|---|---|
| 1 | `opsx-explore` | an **explorer** worker — never the eventual implementer (the verify agent, or a dedicated explorer) | the user's request / problem statement, existing specs and code | exploration report: options, risks, recommended approach, effort — written as the task's report | **PM**: accepts the approach, records the decision in `docs/team/DECISIONS.md`, and writes the propose brief |
| 2 | `opsx-propose` | the **explorer** (the same agent — it holds the context) | the accepted approach | `openspec/changes/<id>/` (proposal, delta specs, design, tasks) — **planning only, no code** (the workflow itself states this boundary) | **PM proposal review — a recorded gate, same standing as `team review`**: `openspec validate --all --strict` green **and** the verdict written to `docs/team/reviews/<change>-proposal.md` as ACCEPTED (§4). **No apply brief may be dispatched before that.** |
| 3 | `opsx-apply` | a **dev** agent, different from 1 and 4 | the change + the brief | code committed on its task branch + report | **independent verification** is dispatched to a different agent |
| 4 | `opsx-verify` | an **independent verify** agent (never the implementer) | the change, the landed code, the report | implementation-ID execution record + verifier assessment; candidate and merged SHAs, every applicable scenario and red/green evidence | after the PM merges, the **same verifier** resumes on a clean checkout pinned to the merged SHA and runs the applicable gates + OpenSpec assessment; the PM accepts passing evidence before `done` or archive authorization; inspection-only `team review --post-merge` is not that run |
| 5 | `opsx-archive` | a **non-implementer worker** (possibly that verifier), on its own worktree/task branch | the accepted merged change, completed assessment and valid confirmation | `openspec/changes/archive/<date>-<id>/` + updated capability specs + worker report | completed merged-revision verification, zero unresolved CRITICAL findings, disclosed WARNING/unverified checks, reconciled sibling/checklist evidence; `team change status <id>` may have only the exact archive-task-ID + literal `phase=archive` self blocker; **the user** confirms, or the PM explicitly records a proxy confirmation only for a small, reversible change already covered by the approved approach |

An exploration whose conclusion is "not worth doing", and a verification that fails twice, do not advance: see §7.

## 2. One phase = one task = one owner

- The phases are **never merged into a single brief**: explore, propose, apply, verify and archive are five briefs,
  each with its own `task:` id, `agent:`, `deps:` and `phase:` header line. An archive brief declares the literal
  `phase: archive`, not the command name `opsx-archive` or `-`.
- **No agent verifies its own work** — the `team review` rule applied to the OpenSpec phases. The verify phase is
  owned by an agent that did not implement, and the apply phase by an agent that did not propose. Explore and
  propose may be the same agent (it holds the context) — but neither may apply its own proposal.
- A phase is not a formality: its hand-out is the **artifact on disk**, and the PM checks the artifact, not the
  agent's account of it. Reports and reviews stay the evidence; nothing here replaces `reports/` + `reviews/`.
- **1 change : N tasks, 1 task : 0..1 change.** The change is the dispatch unit (proposal, design, delta,
  tasks, archive); a task is one batch or one phase inside it, and several agents or several apply batches may
  share a change. The brief's header is the foreign key: `change:` (exactly one id, or `-`), `specs:`/`anchor:`
  (a change-less brief must resolve `openspec/specs/<capability>/spec.md#<requirement>` or declare
  `anchor: none (infra) — <reason>`) and `deltas:` (the change's delta files this task writes; absent = the whole
  set). `team dispatch` enforces the mapping before it opens a window; `team change status <id>` shows it. The
  grammar and the template live in `templates/task.md.tmpl`, the rules in the skill's `references/protocol.md` §5b.
- A spec stands on its own: evidence belongs in the spec's own text, and a `docs/team/…` reference is allowed
  only when `skills/teamsmith/tests/spec-ledger-refs.tsv` declares it with its kind and its basis — a slot
  pattern never lets a concrete record through. Record ids stay defined by the one `Id families:` line of
  `boundary#Specs are the contract`. Before hand-off run `bash skills/teamsmith/tests/spec-refs.sh --check`:
  it judges the text the archive will write, names what a pending change retires, and is red on anything
  undeclared or on a family the key line does not name.

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

### The PM's proposal review checklist (ten points, followed literally)

1. **Matches the approved exploration** — no silent widening or narrowing of scope; call out scope creep *and*
   scope cuts.
2. **Observable** — the delta specs describe only externally observable behavior (commands, exit codes, files on
   disk), and every scenario can fail.
3. **Closed coverage, both ways** — every affected requirement has at least one task item, and every task item
   points at a requirement or scenario (no orphan tasks).
4. **Explicit boundaries** — the proposal states what is out of scope, and who may not touch which paths.
5. **Acceptance commands** — copy-pasteable and existing: the PM runs `openspec validate --all --strict`,
   then spot-checks the commands the proposal itself promises.
6. **Defect fixes state the flip** — red → green, or "break the implementation → the guard must fail → restore it".
7. **No conflict with existing specs** — grep `openspec/specs/` before accepting a statement: a duplicate or a
   supersession must be a MODIFIED/REMOVED delta, not a parallel statement in a new requirement.
8. **Granularity** — can one apply brief finish it? If not, the split and its order are named (several briefs
   under the same change, applied and verified one by one).
9. **One change per task** — every brief the change's plan will dispatch declares exactly one `change:` id (or `-`
   with an anchor). Judgement: `grep -n '^change:' docs/team/tasks/*.md` and, once the briefs exist,
   `team change status <id>` must list them under this change and no other. A brief with two ids, a second
   `change:` line or a typo is a NEEDS-CHANGES item naming the brief and the line (dispatch refuses it anyway —
   there is no override for this rule).
10. **The anchor exists** — each dispatched brief either points at this change, or names a `specs:` requirement
    that resolves in `openspec/specs/<capability>/spec.md`, or declares `anchor: none (infra) — <reason>` with a
    reason from the allowed classes (environment/CI/toolchain, pure internal refactor, docs and fixtures).
    Judgement: `grep -n '^anchor:\|^specs:' <brief>` and, for the infra form, is the reason honest — a rule that
    must hold across tasks (silent failure, destructive action, authority, identity, gate, performance contract)
    is **not** infrastructure, whatever the brief says; the correct verdict is NEEDS-CHANGES with the capability
    named.

## 5. What the PM does at each gate

| Phase | Read | Must be true | Write |
|---|---|---|---|
| explore | the exploration report, the specs and code it cites | the recommendation is one option with its risks and effort, and the scope is the user's request — not a wish list | the decision in `docs/team/DECISIONS.md` + the propose brief |
| propose | `openspec/changes/<id>/` end to end | `openspec validate --all --strict` green and all eight checklist points pass | `docs/team/reviews/<change>-proposal.md` = ACCEPTED (or NEEDS-CHANGES + per-item findings) |
| apply | the brief, the change, the branch, the report | the branch carries exactly the change's scenarios; the acceptance commands really ran; nothing outside the boundaries was touched | the verify brief (a different agent) |
| verify | the change, landed code, implementation-ID execution record, verifier report and diff | the assigned non-implementer verifier ran every applicable scenario on the PM-prepared clean checkout; after merge the **same verifier** resumed on the pinned merged SHA and completed the applicable gates + OpenSpec assessment | PM accepts the merged-SHA evidence, then `team board set <ID> done`; when IDs differ the PM writes `reviews/<verify-task>.md` explicitly as **PM acceptance**, linking the implementation-ID execution record, verifier report and verified merged SHA |
| archive | the accepted merged baseline, linked execution record + completed assessment, and valid confirmation | zero unresolved CRITICAL findings; WARNING/SUGGESTION and every unverified applicable check/reason disclosed before confirmation; sibling/checklist evidence reconciled; `team change status <id>` need not exit zero while this archive task is active; the tool excludes only the row whose task ID equals this brief's ID, and the brief must declare literal `phase: archive` so that row reads as `archive` (`opsx-archive` and `-` do not satisfy the header) — the tool does not match self by phase text, and every other task/archive/checklist/unreadable blocker stops archive; user confirmation, or PM proxy only for a small, reversible change already covered by the approved approach with confirmer/reason recorded | the assigned worker trials and runs `openspec archive -y <id>` on its own authorized branch; PM inspects/integrates and closes the task after acceptance |

The archive worker trials native archive on a private disk-backed copy before using its own branch:

```sh
trial_root="$(mktemp -d -p /var/tmp teamsmith-archive.XXXXXX)"   # substitute the project's declared disk root
mkdir "$trial_root/project"
cp -a openspec "$trial_root/project/openspec"
(cd "$trial_root/project" && openspec archive -y <id>)
# Inspect complete output and resulting specs; failure returns for correction, never a real archive.
rm -rf -- "$trial_root"
```

The archive grant covers only the selected change/native dated destination, enumerated capability specs and the
worker's report in its own worktree/task branch. Native synchronization preserves existing capability Purpose text.
The stale verification Purpose is updated only afterwards in a separate, explicitly authorized Purpose-only
documentation commit with its before/after diff. For dependent archives, the predecessor archive is accepted and
merged first; the successor starts from that baseline and reconciles every complete MODIFIED block/scenario. A stale
block or missing merged predecessor returns for authorized correction and independent re-verification.

The checklist half of readiness is the apply phase's own ledger: three changes reached archive with 23/24/16
items unticked (P151 F3, P175 F3, P206 F1), each caught by a human instead of by the gate. The check counts
**empty boxes only** — an item ticked with its reason (`- [x] 2.3 … 引用 P206`) is complete, and a box ticked to
clear the gate is no evidence: the ledger is reconciled on the apply side (tick what was really done, say in the
item what was not). Since `openspec archive` does not consult teamsmith, the gate that still catches a skipped
checklist afterwards is the archive task's `team board set <ID> done`: it reads the change's `tasks.md` in the
archive copy once the live directory is gone.

`team board set <ID> done` reads those same phases from the brief: `explore` is done on the PM's recorded
acceptance (a `DECISIONS.md` entry whose heading names the task, or `reviews/<ID>.md`), `propose` only on an `ACCEPTED`
`reviews/<change>-proposal.md` (a `NEEDS-CHANGES` record refuses and says so), `verify` on the task's review
record, and `archive` once the change id appears under `openspec/changes/archive/`; `apply` keeps the code-task rule
(non-`FAIL` review record, or a merged branch tip **whose commits carry the task's report** `<docs>/reports/<ID>-*.md`
— a branch created a minute ago is an ancestor of the protected branch too, so the committed report is what tells
"merged with content" apart from "created and never touched"). A brief with no `phase:` line (or `-`, or an unknown value) keeps
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

- Generate what the installed OpenSpec can generate: `openspec init --tools pi` writes command and skill files for
  the active profile (use the tool's own id for a non-Pi CLI), and `openspec update` refreshes configured tools.
  Inspect the **actually generated** `.pi/prompts/opsx-verify.md` and
  `.pi/skills/openspec-verify-change/SKILL.md`: when present, the verifier follows that workflow's completeness,
  correctness and coherence assessment and its CRITICAL/WARNING/SUGGESTION/Final assessment definitions. Do not infer
  availability from an OpenSpec release number or prescribe `openspec instructions verify`, which is not an artifact
  command for the `spec-driven` profile.
- **A missing generated verify workflow is a disclosed limitation, not a skipped phase.** The assigned different agent
  performs the documented equivalent review of completeness, requirement/scenario correctness and design coherence,
  using this guide's phase ownership plus the same findings/readiness structure; structural `openspec validate` alone
  is not verification. The hand-out remains the implementation-ID execution record plus the verifier's completed
  assessment report. What teamsmith gates on is the **artifact** (the review record and assessment); generated command
  files are checked only where the checkout carries them (a checkout without the machine-generated surface gets a
  named skip, never a red — P222).
- Whether the generated files are committed follows the project's own ignore rules. This repository ignores `.pi/**`
  (`.gitignore`): the files are per-machine, every clone and every CI checkout starts without them, and the gate
  reports the `.pi/prompts` / `.pi/skills` checks as named skips there. A project that does commit them gets those
  checks on every checkout, which is strictly more coverage.
- Resolve the CLI and the spec root: `team paths` (and `team doctor`) print `TEAM_OPENSPEC_BIN` / `TEAM_SPEC_DIR`;
  with `TEAM_REQUIRE_OPENSPEC=1` (the default) a missing CLI or spec directory fails the doctor. The gate needs the
  CLI on `PATH` (or an absolute path in `TEAM_OPENSPEC_BIN`).

## 7. Escalation: stopping a change

- **Exploration says "not worth doing"** → the PM records the decision in `DECISIONS.md`, does not dispatch
  propose, and says so in the ledger. Nothing is archived, nothing is left half-planned.
- **Verification fails twice** → the PM **stops the change**: leave it in `openspec/changes/<id>/` with a note
  naming the blocker (and the failed findings), rather than pushing it through. The next PM can see it.
- **The user is not available for the archive decision** → the change stays open unless the PM explicitly records
  the limited proxy case: small, reversible, already covered by the approved approach, with confirmer and reason.
  PM evidence acceptance alone is not confirmation; WARNING findings and unverified checks/reasons are disclosed first.
- Never archive to make a red thing disappear: `openspec archive` merges the deltas into `specs/` — after it, the
  spec set claims the change is real. Archive only after the gate passed and the user confirmed.
