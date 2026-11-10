# Delegate OpenSpec verification and archive

## Why

The user has decided that verification and archive are delegated work, not work the PM performs. Shipped instructions still tell the PM to re-run gates and archive. The proposal changes those executors, not the existing limited authority for PM-proxy confirmation. The PM's recorded proposal review (`docs/team/reviews/delegate-openspec-archive-proposal.md`, five rulings and two linked corrections) settles the return from independent review V138.

## What Changes

- Keep the five phases and existing task/report/review records. Non-implementer workers execute verify and archive; one verifier may also archive. The PM dispatches, reads the evidence and diff, accepts and merges, but does not run their gates, including in PM-owned background jobs.
- The PM prepares the independent detached checkout; the verifier runs `team review`. Explicitly authorize that command's named review record and companion gate log in the main checkout as a narrow ledger exception. Change the generated implementation-task record to identify the actual executor, not a hard-coded PM. PM writes the verify task's separate done-evidence record as PM acceptance, linking that execution record rather than claiming to have verified.
- The same verifier resumes after PM merges and verifies the merged revision. Only after that evidence passes may the PM mark the work done or proceed to archive. Revise each of the three existing merged-tree instructions rather than deleting verification at that point.
- Use the existing `openspec-verify-change` severity definitions and report structure, adding `CRITICAL`, `WARNING`, `SUGGESTION` and `Final assessment` sections to the report template. Resolve CRITICAL findings; disclose WARNING findings and unverified checks before confirmation. Do not equate a shell-gate PASS with a completed OpenSpec assessment.
- Preserve user confirmation and the existing limited PM-proxy rule: only a small, reversible change already covered by the approved approach, with the proxy identity and reason recorded. Delegating execution does not expand or withdraw confirmation authority.
- Archive on the assigned worker's own worktree/branch with an enumerated temporary write grant. Trial archive uses a private disk-backed directory. The archive brief explicitly declares the literal `phase: archive`, not `opsx-archive` or `-`. Read readiness blockers instead of requiring exit zero before the archive task itself finishes; only its exact task-ID/phase row is the self entry.
- Serialize dependent archives after the predecessor's archive is merged; reconcile complete `MODIFIED` blocks against that baseline. Preserve existing capability Purpose text during native archive, then update the stale verification Purpose in a separate, explicit documentation commit with its before/after diff.
- Correct all contrary instructions in the thirteen guidance files (56 inventoried hits) in `design.md`, including installed memory/runbook entry points and public README/init guidance. Replace weak checks within existing smoke sections; do not add a workflow engine or gate section.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `verification`: delegated execution, truthful review identity and narrow ledger authority, post-merge verification, archive evidence/confirmation, worktree boundaries and ordered archive. Existing independent-checkout requirements, author-verifier dispatch rules and documented overrides remain unchanged.

## Impact

- Guidance (13 files): `skills/teamsmith/templates/{AGENTS.section.md,pm-prompt.md,PROTOCOL.md,OWNERSHIP.md,DECISIONS.md,memory-seed.md}.tmpl`, `skills/teamsmith/SKILL.md`, `skills/teamsmith/references/{workflows,openspec,protocol,troubleshooting}.md`, `README.md`, `skills/teamsmith-init/SKILL.md`.
- Evidence output: `skills/teamsmith/scripts/lib/cmd-review.sh` (actual executor instead of the three hard-coded PM attributions), `skills/teamsmith/templates/report.md.tmpl` (fixed findings/assessment sections). No new review command, flag or verdict vocabulary.
- Existing tests: `skills/teamsmith/tests/smoke.sh` (`19`, `12j`, review identity/evidence in `10`/`10b`) and `skills/teamsmith/tests/section-paths.tsv` (rows for files actually read by those sections).
- Later authorized archive: `openspec/specs/verification/spec.md` Purpose only in a separate documentation commit after native synchronization preserves it; proposal/apply do not edit the canonical Purpose. The old/new text and sequencing are in design §5.
- No configuration/schema/dependency change, new runtime refusal, readiness switch, done-evidence parser, automatic project refresh or change to merge/push authority. Existing limited PM-proxy confirmation is retained.
- P435 edits only its four planning artifacts and report. Apply requires accepted non-author/PM review and a separate brief granting the enumerated paths. Current V136 and the two already authorized changes continue under their existing instructions: no retrospective post-merge rerun or new archive hold is introduced for them.
