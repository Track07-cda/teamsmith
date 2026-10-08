# E14 · Task-model routing proposal

agent: verify   status: REVISED (proposal only; PM re-review pending)   time: 2026-10-08
branch: `task/E14-task-model-routing-propose`   PR/MR: - (local mode)

Current revision receipt is **R1–R4 below**. The original receipt/209-scenario inventory is retained as the historical delivery at `357c88c`; it was sent back by PM and is not proposal acceptance. The revised inventory has 45 requirements, 216 scenarios and 27 unchecked tasks.

## Deliverables

| Path | What |
|---|---|
| `openspec/changes/task-model-routing/.openspec.yaml` | CLI-generated spec-driven metadata |
| `openspec/changes/task-model-routing/proposal.md` | Accepted direction, breaking changes and authorization boundary |
| `openspec/changes/task-model-routing/design.md` | Category/model/SID resolution table, atomic config/assignment transactions, original PM launcher, reader identity, serial ownership and future commands |
| `openspec/changes/task-model-routing/tasks.md` | 27 unchecked implementation/verification/adoption tasks; 45 requirement links, all scenarios mapped to task owners and future test front doors; scratch flip controls |
| `openspec/changes/task-model-routing/specs/{dispatch,memory-and-deps,panel,agent-adapters,pm-lifecycle,init-skill,watchdog}/spec.md` | Seven self-contained deltas: 11 ADDED, 32 MODIFIED, two REMOVED requirements; 209 scenario headings including inherited regression cases |
| `docs/team/reports/E14-verify.md` | This planning delivery, actual evidence and limitations |

External evidence is `pm-skills-ledger/team/reports/E14-verify/`, resolved from git's common directory's project parent, not from another project. `commands.json` contains actual argv/cwd/rc; matching `.stdout`/`.stderr` files retain complete outputs. Final scratch tree is `trial-archive-final/`; earlier draft acceptance/trial evidence is retained separately. Source/formatting helpers there are artifact assembly, not a parallel validator.

## Verification evidence (must have actually been run)

The actual Bun/OpenSpec CLI was used without installation. Context before `new change` resolved to the allocated verify worktree, source `nearest`. Instructions were obtained in dependency order proposal → specs/design → tasks, and dependency artifacts re-read from disk. See `context.json`, `new-change.log`, `instructions-{proposal,specs,design,tasks}.json`. No apply instructions/action followed planning readiness.

Final acceptance ran through `run-planning-checks.py` as a harvested background job; its subprocess front doors below all returned **0**. CLI processes for real-tree checks used the allocated worktree as cwd. Trial-only CLI children used the explicit authorized scratch cwd, after checking the CLI context JSON equals that path.

```text
$ "$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" status --change task-model-routing --json
isPlanningComplete: true
isComplete: true
artifacts: proposal done; specs done; design done; tasks done
root: allocated verify worktree, source nearest
```

`isComplete` here is CLI planning readiness, **not** completed implementation. All 27 implementation boxes remain unchecked.

```text
$ "$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate task-model-routing --strict
Change 'task-model-routing' is valid

$ "$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
Totals: 14 passed, 0 failed (14 items)

$ bash skills/teamsmith/tests/spec-refs.sh --check
spec-refs: judged 104 reference(s) (49 distinct) in 10054 effective line(s);
retired 0; undeclared 0; id families used [D,E,F,M,P,V] named [D,E,F,M,P,V]

$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: scope=published files=1303 hits=0 names=ok user=resolved

$ git diff --check
(no output; rc=0)
```

### Trial archive and projected base

The runner copied the OpenSpec tree into its authorized external evidence directory. It copied top-level team ledger markdown to preserve the ledger-present premise without copying 208 MB of unrelated report/log packages. Reference checking did not report SKIP. No real base spec or real change directory was archived or replaced.

```text
# Each CLI subprocess cwd = <evidence>/trial-archive-final
$ "$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" context --json
root.path: <evidence>/trial-archive-final
root.source: nearest
CLI context explicitly matches authorized scratch root

$ "$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" archive task-model-routing -y
Proposal warnings in proposal.md (non-blocking):
  Consider splitting changes with more than 10 deltas
Task status: 0/27 tasks
Warning: 27 incomplete task(s) found. Continuing due to --yes flag.
Totals: + 11, ~ 32, - 2, → 0
Specs updated successfully.
Change 'task-model-routing' archived as '2026-10-08-task-model-routing'.

$ "$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
Totals: 13 passed, 0 failed (13 items)

# Invoked from the allocated worktree using the existing script
$ bash skills/teamsmith/tests/spec-refs.sh --check --root <evidence>/trial-archive-final
spec-refs: judged 104 reference(s) (49 distinct) in 10055 effective line(s);
retired 0; undeclared 0; id families used [D,E,F,M,P,V] named [D,E,F,M,P,V]
```

No `--skip-specs`, `--no-validate`, modified validator/registry or ticked tasks made this pass. The incomplete checklist warning is expected planning-only state, not a semantic delta failure. The size advice is retained: this is one coherent routing change across seven existing capabilities, implemented through three serialized slices rather than separate contradictory feature changes.

### Scope and branch audit

```text
$ git status --porcelain=v1 --untracked-files=all
(no output before report creation)

$ git diff --name-status cbe5615 HEAD
11 A entries, all under openspec/changes/task-model-routing/

runner: PASS: real tree hashes unchanged; implementation boxes remain unchecked; no real archive
```

`scope-before.json` and `scope-after.json` match for all real OpenSpec files plus project config/AGENTS. Product code/tests/templates/base specs/root config, runtime config, board/decisions/reviews/ownership, shared installation and historical E13 material are not in the task diff. The report is the sole additional versioned path. Final report-inclusive names/ledger/diff/status and full HEAD are retained in `final-identity.log`, generated after committing this report. No push/PR/MR/merge in local mode.

Planning commits (all have `Agent: verify`):

- `44c5b14` — proposal and CLI metadata.
- `ac34043` — seven delta contracts and explicit retirement.
- `3625851` — transaction design, serial ownership and coverage checklist.
- `7a9dfbb` — align inherited init/custom-continuation/window fixtures with explicit model inputs and complete identity.

Report commit identity is the final local HEAD in `final-identity.log` (a report cannot embed its own content-dependent commit hash). It is also resolvable with `git log -1 --format='%H' -- docs/team/reports/E14-verify.md` on this task branch. Final local status must be empty.

- Verdict: **PASS — planning structure, delta applicability, references and scope only.**
- Not run: product smoke/full suite, config/panel/death/routing implementation tests, TUI demonstration, live migration/restart/install, real provider/model quality comparisons. Future commands and new interfaces/tests are explicitly marked planned/not implemented in design/tasks. Stub evidence from E13 proves Teamsmith arguments/state, not Pi inference quality. No claim that automatic category routing exists today.

## Flip evidence (required for defect-fix tasks)

Not applicable: this is `phase: propose`, not a defect-fix implementation. No code guard or live configuration was broken. `tasks.md` supplies independently falsifiable future scratch flips for policy fallback, CAS/quoting, model/SID drift, partial publication, model limits, A/B readers, PM/extra-arg bypass, UI false actual-model display and legacy bootstrap. These controls are **not run** and are not replaced by the successful trial archive.

## Decisions and deviations

- Category lives only in one brief `category:` header; `[a-z][a-z0-9-]*`, project-defined vocabulary. No dispatch category override, classifier or automatic phase/seat inference. Initial mapping matches D101/D102 but is only a future explicitly entered example.
- New-task model is explicit override or category policy; same-task resumes the full committed assignment. Selection origin `selected_via` survives and recovery `launch_via=assignment` is separate. Same-model fresh retains assignment model; changed full model/suffix requires fresh. Unusable identity requires explicit fresh re-declaration, not guessing.
- Versioned flat assignment is published atomically after current nonce proof. Target-seat decision and cross-seat final worker admission serialize; read-side values use committed identity. Failure/interruption/board failure/preview have distinct observable contracts. Live byte size remains a live file stat, not sid_bytes snapshot.
- Minimal `config upgrade-models` handles exactly new mapping/PM and retired model keys, through the existing checked writer. CAS/quoting/atomicity/audit remain. Unsupported dynamic/export/multiline/duplicate relevant assignments get a no-write manual normalization route. Legacy diagnostics/writer remain reachable, but legacy routing cannot launch.
- PM policy/metadata stays in the existing starter and proof/liveness path. No second PM recovery system, worker fallback, Pi reasoning/history inspection/conversion or promise of detecting later Pi-internal model switches. Concurrency still counts workers, not a shared subscription budget.
- Core → UI → init/guidance, with explicit handoff of common scripts/fixtures; one delta writer each. This is a recommendation for PM briefs, not actual apply dispatch. Independent verifier is not an apply author.
- Read-through found inherited examples that would otherwise contradict the new missing-input/identity guards; their bodies now provide explicit inputs and complete metadata. Existing Scenario titles are kept where OpenSpec requires them, while body behavior supersedes the old seat semantics. No old routing compatibility added.
- CLI `new change` automatically created `openspec/config.yaml`. This was not adopted or edited: the generated bytes were retained externally as `cli-generated-config.yaml` and the file removed. Final real root has no config.yaml and retains default/spec-driven schema. This transient CLI side effect is disclosed; no lasting root config change exists.
- Planning checks are not product value evidence. Source rollout, local config transaction, PM/worker fresh launches, shared install and other-project adoption remain separate permission decisions. No runtime action was taken.

## Suggested next steps

- PM independently review `openspec/changes/task-model-routing/` and record the verdict in `docs/team/reviews/task-model-routing-proposal.md`; user sees artifacts before apply.
- Only after ACCEPTED plus explicit execution authorization, issue serial S1/S2/S3 briefs with the file/delta ownership and front doors in design/tasks. Do not use this DONE planning report as implementation acceptance or authorization to migrate this project's config.
- No current hard blocker. Leave the real change open and all implementation boxes unchecked; real archive belongs to PM after implementation, independent verification and user confirmation.

## Revision receipt · R1–R4 · 2026-10-08T09:06Z

Read the latest PM thread, the original brief/ownership, current status/log and PM's read-only main-checkout `docs/team/reviews/task-model-routing-proposal.md` before editing. Preserved the clean original delivery and PM's review/evidence. Revised only eight existing planning files and this own report; no apply instructions, implementation/tests, runtime config, links, PM review or other agent's files were changed.

| Send-back | Revision delivered | Future verification linkage |
|---|---|---|
| R1 recovery versus future membership | dispatch distinguishes complete matching assignment recovery from new selection. Legal removal of routine from a still-valid map retains original category/model/SID/provenance for ordinary recovery; new routine refuses. Invalid overall config, altered identity and changed full model retain their guards. memory/JSON/UI distinguish absent future policy from intact committed identity; design/table agree. Explicit same-model selection is explicitly sourced, not policy-induced relabelling; no-override fresh retains origin. | dispatch's two new recovery scenarios, memory removed-category read scenario; tasks 1.2, 3.4–3.5, 6.3 and resume flip |
| R2 live peer with unjudgeable model | limited admission refuses on another proven-live worker in this project with missing/legacy/incomplete/malformed complete model record, including preview/force. Diagnostic separates known occupancy from unknown peer identity, names rule/limit/defect and gives local explicit fresh/stop route; it cannot guess or report zero/pass. Dead/exited/absent/PM and actual unlimited targets are separate controls; replacement target counts once. | dispatch's two new live/unknown versus non-live scenarios; tasks 3.3–3.5 and limits flip |
| R3 inherited historical absolutes | agent-adapters no longer promises model/SID continuity is documentation-only/never behavioral or that tests remain unedited. init permits legitimate fixture input changes while retaining Pi version/plugin/placeholder safety assertions. Other inherited memory/panel byte promises are bounded to unaffected metadata/console-only effects rather than freezing specified model/SID replacement. Scenario titles required for MODIFIED matching remain; bodies carry the updated contracts. | tasks 1.2, 5.3, 7.4 plus existing unchanged-safety regression front doors; no test assertion deleted or skipped |
| R4 shared source adoption | proposal/design/init-skill/tasks explicitly recognize both real global links to main. S1→S2→S3 uses an unlinked private non-deployed integration tree, frozen paths and exact input commits; private acceptance does not mark apply/board done or put partial S1 on shared main. Full independent verification precedes separately approved stable-source isolation or identified shared-impact adoption and protected landing; config/fresh/shared re-adoption/other projects remain separate approvals. Unknown consumers are not promised unaffected; no automatic scan/deploy mechanism added. | init-skill's two new private/shared-source scenarios; tasks 1.1, 5.3, 6.1, 7.1–7.4, 8.1–8.4 and coverage/rollout flip |

Revisions are commits `7073628` and `02d0da3`, both with `Agent: verify`. The second read-through clarified explicit same-model provenance and separated future evidence-backed OpenSpec checkboxes from protected-branch board delivery; all current 27 boxes still remain unchecked.

### Actual rerun evidence

External evidence: `pm-skills-ledger/team/reports/E14-verify/revision-r1-r4-final/`. `commands.json` retains **17 actual subprocess argv/cwd/rc**, each **0**; matching stdout/stderr and scope-before/after snapshots are preserved. Earlier `revision-r1-r4/`, original report and original acceptance logs are not overwritten. The wrapper calls existing CLI checks and records hashes/context; it is not a new semantic validator.

Actual background front door, harvested exit **0**:

```bash
python3 "$HOME/Documents/syncthing/Work/Projects/pm-skills-ledger/team/reports/E14-verify/run-revision-checks.py"
```

Actual existing CLI subprocesses (real cwd remains the verify worktree):

```text
$ bun openspec context --json
root.path: allocated verify worktree; source: nearest
$ readlink ~/.agents/skills/teamsmith
<main-checkout>/skills/teamsmith
$ readlink ~/.agents/skills/teamsmith-init
<main-checkout>/skills/teamsmith-init
$ bun openspec status --change task-model-routing --json
isPlanningComplete=true; isComplete=true (planning only)
$ bun openspec validate task-model-routing --strict
Change 'task-model-routing' is valid
$ bun openspec validate --all --strict
Totals: 14 passed, 0 failed (14 items)
$ bash skills/teamsmith/tests/spec-refs.sh --check
104 references (49 distinct); retired 0; undeclared 0
$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --git-common-dir)/../.pi/team/forbidden-names.txt"
scope=published files=1304 hits=0 names=ok user=resolved
$ git diff --check
$ git diff 357c88c HEAD --check
(no output; rc=0 each)
```

`bun openspec` above abbreviates the actual argv `"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec"`, fully recorded in commands.json. The real context was read-only. CLI children for trial operations used the distinct cwd `revision-r1-r4-final/trial-archive/`, **only after context JSON explicitly matched that authorized scratch root with source nearest**:

```text
$ bun openspec archive task-model-routing -y
warning: Consider splitting changes with more than 10 deltas
Task status: 0/27 tasks
Warning: 27 incomplete task(s) found. Continuing due to --yes flag.
Totals: +11, ~32, -2, rename 0
Specs updated successfully; archived as 2026-10-08-task-model-routing in scratch only
$ bun openspec validate --all --strict
Totals: 13 passed, 0 failed (13 items)
$ bash <verify-tree>/skills/teamsmith/tests/spec-refs.sh --check --root <scratch-tree>
104 references (49 distinct); retired 0; undeclared 0
```

Warnings retained, not suppressed by checking implementation tasks. Both positive archives were scratch copies, not the real change. The real change remains open. Real OpenSpec/AGENTS/report hashes, present main runtime config and verify worker-record hashes, **243 shared-source file hashes**, and both global-link target/mtime values matched before/after the final checks. No root config.yaml appeared. Scope logs contain only the eight changed planning paths versus `357c88c`, and the original permitted change/report paths versus `cbe5615`. The runner ended:

```text
PASS: real tree/shared sources/config/worker record/links unchanged; tasks unchecked; scratch archive only
```

Report-inclusive ledger-ban/diff/status and final HEAD are recorded separately in `revision-r1-r4-final/final-identity.log` after report submission. No push/merge/PR/MR in local mode.

### Current verdict and limits

**PASS for rerun planning structure, delta applicability, references and inspected scope; SUBMITTED for PM semantic re-review, not ACCEPTED.** Product smoke, new routing/unknown-peer/future-category-removal controls, fixture flips, UI demonstrations and real provider calls were **not run** because implementation remains out of scope. New scenario text/future task mapping is not empirical proof of implemented behavior or product value.

PM must independently re-review all four revisions and their shared-source implication. Apply still awaits recorded ACCEPTED plus user execution authorization. Any future shared isolation/adoption, protected landing, config update, fresh launch, installation or other-project operation retains its explicit permission gate. No such operation occurred in this revision.
