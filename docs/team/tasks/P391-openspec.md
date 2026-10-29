# P391 · Propose instruction-context slimming with safe AGENTS refresh

task: P391
agent: dev3
phase: propose
category: analysis
change: instruction-context-slimming
deltas: init-skill
branch: task/P391-openspec
deps: accepted exploration P389 3a32f85f8f20; PM review docs/team/reviews/P389.md; D208

## Phase boundary

You explored this change and now own **planning-only Propose**. You will not implement it. Read `AGENTS.md`, your thread, this brief, OWNERSHIP, `references/openspec.md`, the complete P389 report (`git show 3a32f85f8f20:docs/team/reports/P389-dev3.md`), PM review and D208. Use the generated OpenSpec propose workflow.

Write only `openspec/changes/instruction-context-slimming/{proposal.md,design.md,tasks.md}`, the declared delta under `specs/init-skill/spec.md`, and `docs/team/reports/P391-dev3.md`. Do not edit canonical specs, product prompts, AGENTS, SKILL, dispatch code, tests, configuration or live project files. No Apply before formal PM proposal ACCEPTED and independent substantive proposal review.

## Accepted direction

1. AGENTS becomes the short shared cross-seat constitution/reading order; PM prompt keeps PM-only startup and essential evidence/boundary rules; worker dispatch remains self-contained on critical safety/delivery behavior; SKILL/references hold detailed procedures. No new rule registry, generator, database or prose-guard framework.
2. Keep short duplicated rules where a spec or self-contained worker launch requires them. Do not replace mandatory multi-surface duties with a bare link. A human rule-by-rule review and independent verifier, not a keyword/line-count/performance gate, judge preservation.
3. Reuse the existing `team init` managed-block replacement. No new migration command or AGENTS-only mode is needed. A normal existing project with Teamsmith markers can refresh without `--force`; old `pi-team` markers migrate. Existing-config bootstrap does not refresh AGENTS and must not be documented as the adoption path.
4. Live pm-skills adoption is outside this product change. Its 28 lines / 1,988 bytes of custom discipline at current `AGENTS.md:49–76` must later be moved outside markers with a separately previewed/authorized diff. Do not include those rules in the generic template merely to preserve one project's customization.

## Proposal decisions and coverage

- Turn P389's rule-ownership matrix into a concrete source-by-source edit plan: AGENTS, pm-prompt, worker dispatch, SKILL, protocol/workflows, generated PROTOCOL. Identify what is removed, compressed, retained or pointer-only and the canonical detailed destination. Keep the useful command index and role-specific startup self-containment.
- Resolve documented prose contradictions in favor of current authoritative behavior/specs: selected-versus-full gates with disclosed scope, local/remote settled delivery, actual `templates/report.md.tmpl`, pulse reporting but not auto-resuming workers, task category versus seat/model/SID, and real capacity contract rather than swap-only shorthand. Do not turn this into runtime lifecycle/threshold changes.
- The expected only delta is `init-skill`: describe role-specific instruction organization and observable existing-project AGENTS refresh behavior. If the actual wording changes any dispatch/writing-discipline/key-replies/watchdog/verification obligation, stop and report the additional required delta instead of hiding it under init-skill.
- `design.md` must distinguish product-template validation from later live adoption. Document marker shape assumptions, legacy/no-marker/missing/idempotent/no-skills behavior, init's other writes and non-transactional nature, default render parameters, and why `--force` is not used. Do not claim every non-AGENTS file is untouched or that bare init is safe for non-default projects.
- `tasks.md` must reuse existing install-shape/smoke/task-model-routing fixtures, not add a new migration framework or smoke section. Include behavior red/green mutations and independent human rule-coverage review. Measure before/after sizes as evidence, not blocking performance budgets.
- Live adoption steps, if mentioned, are explicitly future separate authorization: preserve the 28-line custom section outside markers, inventory init parameters/writes, private-copy preview, byte backup, exact execution, and separate PM reload. Do not mark them done in this change.

## Required fixture plan

Plan observable tests for: verbose old managed block with unique before/after custom text; preserved config and existing ledger documents; legacy marker; no marker; missing file; repeated init; `--no-skills`; force/bootstrap boundaries; non-default session/roster/docs parameters. Prove the file actually becomes shorter and the new managed block equals the rendered template, not just that a keyword exists. Mutations that stop replacement or overwrite outside custom text must fail. Worker prompt tests must prove local/remote and background/no-background variants retain applicable three-state and delivery rules.

## Acceptance and handoff

Before delivery run and record actual output in the real available environment (if a host CLI is missing, use the existing gate image with a read-only source mount as in P389 and state that boundary; do not install anything):

```bash
openspec status --change instruction-context-slimming --json
openspec validate instruction-context-slimming --strict
openspec validate --all --strict
openspec instructions apply --change instruction-context-slimming --json   # read-only planning inspection
bash skills/teamsmith/tests/spec-refs.sh --check
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check
```

Trial-archive only in a disposable copy outside the repository and validate all specs there; do not archive the real change. No full gate, live init, PM/worker restart, merge, push or release.

The report leads with the chosen structure, exact artifacts, every P389 correction/boundary, validation results and any added-delta concern. Commit with Conventional Commits + P391 + `Agent: dev3`, leave the branch clean and notify PM for formal review.

## V113 first-round rework (2026-10-29)

V113's independent review at `f752109bd570` is NEEDS-CHANGES; PM's formal review is REWORK REQUIRED. Read `git show f752109bd570:docs/team/reports/V113-verify.md` and `docs/team/reviews/V113.md`. The design direction stands, but the exact proposal `00f7d50e2879` must not go to Apply. Preserve the original artifacts/history and make a small proposal-only correction on `task/P391-openspec`; no product/live changes.

Close all six findings in the change artifacts and append the report:

1. Replace every `references/watchdog.md` destination with the real homes: `references/protocol.md` §8 for mechanism/boundaries and `references/workflows.md` §D/§I for executable patrol/startup procedures. Check design and tasks, not just one occurrence.
2. Move existing-project refresh guidance to `references/migration.md` §§1/2/2c/6, its existing home. In the same planned edit, correct migration §2 and §2c's current `team init (or team bootstrap)` / `init/bootstrap` statements: existing-config bootstrap does not run the AGENTS writer. `workflows.md` §A (new-project assembly) and daily SKILL retain only cross-links, not a second detailed home.
3. Replace `bash skills/teamsmith/tests/install-shape.sh --flip` with two explicit valid commands: the full no-arg matrix and `bash skills/teamsmith/tests/install-shape.sh flip` (or `install flip`). V113 measured no-arg ✓165/✗0, `flip` ✓42/✗0, but `--flip` only ✓1/✗0 with no flip section. State that the arguments are section names, not flags.
4. Add correction of `references/protocol.md` §9 to the edit plan: its capacity summary must match dispatch/current resolver, including MemAvailable and selected temp/worktree disk/inode floors in addition to swap/RAM+swap. Do not leave AGENTS pointing at an incomplete destination.
5. Add two required preservation rows to design and the tasks 6.2 worksheet: verification's dual-gate division must remain in both SKILL.md and references/protocol.md; agent-adapters' SKILL frontmatter description, `## Agent adapters` section and deep-read/frozen wording remain declaration surfaces. Task 2.4 must explicitly preserve them while compressing surrounding detail.
6. Clarify that ledger-ban uses the actual project `.pi/team/forbidden-names.txt`, not an assumed file inside a clean clone. V113's clone-relative path returned names=missing rc=3; only the real project names file returned names=ok hits=0 rc=0. Missing/SKIP is not a pass.

Keep the nonblocking boundaries: FAST §6 proves printed prompt assertions but skips real launch; selected green is not full; trial archive is structural only; marker-shape and 28-line live-custom boundaries remain unchanged. No extra delta, runtime change, product edit or live init is authorized by this rework.

Re-run the complete proposal acceptance set (strict change/all, status, read-only apply instructions, spec-refs, real-names ledger, diff check and disposable trial archive) on the new exact tip. Append a V113-rework section to `docs/team/reports/P391-dev3.md` mapping each finding to its correction with evidence. Commit with P391 + `Agent: dev3`, leave the branch clean and notify PM for focused V113 second-round review.

## Live screenshot correction: reply publication must not create a temp file (2026-10-29)

The user supplied `/var/tmp/pi-clipboard-930f0ffc-be50-4238-9542-42cbc94eab43.png`: PM wrote `/tmp/pm-reply-...md`, ran `team reply post ... --stdin < /tmp/...`, then repeated the same answer. This is a real v0.3.4 usability defect in the instruction path, not a CLI limitation.

Root cause: both v0.3.4 and current `templates/pm-prompt.md.tmpl:37` still say `--stdin < <file>`, while `references/protocol.md` §4b already gives the correct one-command form `team reply post ... --stdin <<'EOF' … EOF`. Add this same-class correction to the current proposal rework:

- PM template must use the existing heredoc/stdin pattern and explicitly avoid creating a temporary file solely to publish a reply. Keep the full user-facing body, reader criteria, exclusions and the requirement to send that same body normally in the conversation; publication failure still does not withhold the answer.
- Preserve the reply page and conversation as two distinct destinations; do not claim they are one operation or remove the reply-page duty. The correction removes the temporary-file/write step, not the required second destination.
- Strengthen the existing key-replies/prompt fixture acceptance so the PM template's example uses heredoc stdin and cannot reintroduce `--stdin < <file>` or a publish-only temp-file workflow. Retain reader/parser-negative tests; no new product runtime or test framework.
- Record this as instruction-text alignment with existing protocol behavior, not a new capability delta or reply-tool redesign. Include it in V113 second review.

### Superseded by the user's marker-based reply direction (2026-10-29)

The heredoc correction above is **withdrawn as the target workflow**. The user instead requires ordinary Pi responses with a special key-reply marker, captured by a Teamsmith Pi extension, with the marker removed from both Pulse and Pi display (D213). Do not finalize P391 with the old default `team reply post` duty or spend this rework polishing heredoc instructions. Pause the key-reply portion until P394 supplies the compatible design; the other V113 corrections may remain prepared but P391 must not go to Apply with a superseded reply contract.
