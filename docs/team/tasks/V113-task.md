# V113 · Independent substantive review of the instruction-slimming proposal

task: V113
agent: verify
phase: verify
category: verify
change: instruction-context-slimming
deltas: -
branch: task/V113-instruction-slimming
deps: exact proposal/report tip 00f7d50e2879; P391 author dev3 must not verify this proposal

## Verdict and scope

You did not author P389/P391. Independently review exact candidate **`00f7d50e2879`** (proposal artifacts `b3a48b35`, report `00f7d50e`). Read the user's slimming request, P389/P391 reports, `docs/team/reviews/P389.md`, D208, all four change artifacts and the existing capabilities the design cites. Give **ACCEPT**, **NEEDS-CHANGES** or **REJECT** first in `docs/team/reports/V113-verify.md`. This is proposal review, not implementation verification or authorization to run live init.

PM independently reproduced in a clean clone: OpenSpec change strict valid, all 20/20, apply instructions ready with 24 unchecked tasks, spec-refs and real-names ledger clean, disposable archive valid at 19/19, real change remains. PM logs are `$HOME/.cache/pm-skills-reviews/P391-00f7d50e/`. Structural green is not your substantive verdict.

## Review questions

1. **Rule preservation:** compare the proposed edit map against actual AGENTS, PM prompt, worker prompt, SKILL/references and the active specs. Find any required local duty that would become a bare link or disappear: ownership/BLOCKED, three endings/background conditions, testing truth, small commits/report/flip, writing/publication duties, independent verification, category/model/SID, authorization, disk handover, OpenSpec gates. The plan intentionally keeps some duplicates; do not demand a single-source-only design or a new rule generator.
2. **Behavioral drift:** check corrections against current specs/code rather than the shorter wording. Selected versus full gates, performance readings, local/remote delivery, actual report template, pulse not auto-resuming workers, category/seat, real capacity floor and pinned OpenSpec verify-command gap must remain accurate. The only declared delta is init-skill; if the proposal actually changes another capability's obligation, that is a blocking scope mismatch.
3. **Existing-project refresh:** verify `team_write_section`, init/bootstrap and defaults against the proposal. One well-formed current/legacy block, outside custom text, no-marker/missing/idempotence/no-skills, non-default parameters, config/ledger bytes, other writes, late failure/non-transactionality, main-root target and force/bootstrap boundaries must be accurate. Existing-config bootstrap does not refresh AGENTS. The template already contains markers; fresh AGENTS is about 167 lines.
4. **Live custom content:** current pm-skills has 28 lines / 1,988 bytes of custom discipline at `AGENTS.md:49–76` inside the managed block. Ensure the plan does not run live init or copy those project rules into the generic template, and requires a separate future outside-marker preservation diff and exact user-authorized preview/adoption/reload.
5. **Test sufficiency:** determine whether the proposed reuse of install-shape, smoke §6/§13c/§17, task-model-routing and red/green mutations can actually prove shrinking/replacement/preservation and prompt applicability. It must not add a migration framework, prose score, keyword-count or performance gate, and must not delete old assertions to make the rewrite pass. Structural/archive validation is not enough.
6. **Scope and feasibility:** check that the seven instruction source groups plus fixtures can be implemented without runtime lifecycle/model/provider changes, new CLI modes, config keys or a second rule system. Identify any contradiction, missing owner handoff or acceptance that cannot be executed independently.

Finish with the smallest required changes, or a clear ACCEPT if none. Include any nonblocking boundaries that Apply/independent Verify must retain. Do not create a parallel spec or rewrite the proposal yourself.

## Boundaries and acceptance

Only versioned write: `docs/team/reports/V113-verify.md`; scratch/evidence under `$HOME/.cache/V113/`. No product/spec/change/AGENTS edits, no live init/bootstrap or PM/worker restart, no full gate, merge, push or release.

Run in the available real environment (state any container/image boundary):

```bash
openspec status --change instruction-context-slimming --json
openspec validate instruction-context-slimming --strict
openspec validate --all --strict
openspec instructions apply --change instruction-context-slimming --json
bash skills/teamsmith/tests/spec-refs.sh --check
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check
```

Trial-archive only in a disposable copy. Commit with Conventional Commits + V113 + `Agent: verify`, leave the branch clean and notify PM. PM will reconcile this review with `docs/team/reviews/instruction-context-slimming-proposal.md`; no Apply until formal ACCEPTED.
