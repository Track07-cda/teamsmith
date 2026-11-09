# Delegated verify/archive: design

## 1. Source inventory and scope

Normative behavior lives in this change's `specs/verification/spec.md`. This is an executor/evidence correction to the existing five phases, not an archive coordinator. The PM review following V138 selects the narrow main-ledger exception, same-verifier post-merge check and retention of limited PM-proxy confirmation.

The following is the complete line-by-line disposition of `grep -nE 'PM.*(verif|archive|gate)|(verif|archive|gate).*PM'` over the thirteen guidance files (56 hits) at planning baseline `e180fdbf`, supplemented by contrary sentences split across lines or missed by that case-sensitive expression. Paths below are relative to `skills/teamsmith/` unless prefixed by repository root. CHANGE means a future apply edit, not an edit made by P435. KEEP always states why. Apply rechecks the actual sentences if line numbers move.

### `templates/AGENTS.section.md.tmpl`

| Line | Decision | Action/reason |
|---|---|---|
| 17 | CHANGE | PM role becomes evidence acceptance/integration, not execution of independent verification. |
| 34 | CHANGE | Archive executor becomes a non-implementer worker, never PM. |
| 36 | CHANGE | PM authorizes/delegates archive after evidence and valid confirmation; retain the existing confirmation rule. |
| 91 | CHANGE | Replace PM-run independent verification with delegated verification, PM acceptance/merge/close. |
| 60 (supplement) | CHANGE | Non-negotiable promise that PM re-runs tests must name the independent verifier instead. |

### `templates/pm-prompt.md.tmpl`

| Line | Decision | Action/reason |
|---|---|---|
| 163 | KEEP | Roster, gates and PM-window context do not assign gate execution. |
| 33–34 (supplement) | CHANGE | The creed distinguishes worker evidence from PM acceptance; it cannot promise PM's own test execution. |
| 78–80 (supplement) | CHANGE | PM delegates archive after accepted post-merge verification; do not tell PM to run native archive. |
| 87–96 (supplement) | CHANGE | Loop step 4 delegates `team review`; merge/done sequence waits for the same verifier's merged-revision evidence. PM still reads diff. |
| 100–116 (supplement) | CHANGE | PM must not move verification to its own `team_bg_run`. Verifiers use the lane; PM may use it for unrelated authorized work. Keep suspend/wake/harvest rules unchanged. |

### `templates/PROTOCOL.md.tmpl`

| Line | Decision | Action/reason |
|---|---|---|
| 11 | CHANGE | Role table distinguishes PM acceptance from worker execution. |
| 21 | CHANGE | Daily loop delegates gate execution, then PM reads results/diff. |
| 62 | CHANGE | Native archive is performed by the assigned worker, not PM. |
| 67 | CHANGE | Five-phase chain names a non-implementer worker for archive. |
| 69 | CHANGE | PM dispatches/accepts archive; preserve valid confirmation and independence. |
| 70 | KEEP | Pointer to PM proposal review/checklist is still correct. |
| 28 (supplement) | CHANGE | Hard rule promising that PM re-runs independently names the verifier instead. |

### `templates/OWNERSHIP.md.tmpl`

| Line | Decision | Action/reason |
|---|---|---|
| 9 | CHANGE | Keep PM ownership of docs; enumerate the command-written review record/log exception, not unrestricted worker access. |
| 29 | CHANGE | Change-phase owner may archive only in its own authorized worktree/branch. |
| 28 (supplement) | CHANGE | Separate PM-owned config/default specs from archive's enumerated temporary capability-spec grant. |

### `templates/DECISIONS.md.tmpl`

| Line | Decision | Action/reason |
|---|---|---|
| 11, 15 | CHANGE | D1 names the verifier as independent-review executor and PM as evidence/diff acceptor; remove the requirement that PM execute the review. |
| 20 | KEEP | D2 asks PM to review the research evidence chain, not to execute verification gates. |

### `templates/memory-seed.md.tmpl`

| Line | Decision | Action/reason |
|---|---|---|
| 23 | CHANGE | Seed future project memory with verifier-run gates and PM evidence acceptance, not PM-run gates. Do not rewrite historical project memories. |

### `SKILL.md`

| Line | Decision | Action/reason |
|---|---|---|
| 3 | CHANGE | Description assigns independent verification execution to workers and acceptance/merge to PM. |
| 12 | CHANGE | Introduction uses the same executor distinction. |
| 21 | CHANGE | Diagram labels delegated review and PM acceptance rather than a PM-run gate. |
| 46 | KEEP | Key-reply publication duty is unrelated to who executes verification. |
| 49 | KEEP | Collaboration/notification commands do not assign gate execution. |
| 52 | CHANGE | Command table explicitly says verifier invokes `team review` on PM-prepared checkout; record/log use the named exception. |
| 119 | CHANGE | Replace PM-executed archive phrasing with PM dispatch/acceptance; retain confirmation conditions. |
| 123 | KEEP | Structural gate and PM proposal-checklist pointer remain valid; their execution follows the delegated rule. |
| 205 | KEEP | Separate adoption authorizations remain intact. |
| 222 | KEEP | Reference index names phase owners/PM checklist without making PM the executor. |
| 226 | KEEP | Smoke/performance reference describes coverage and cadence, not PM execution; preserve these semantics. |
| 65 (supplement) | KEEP | The project gate command stays the same; changing its executor does not replace the gate. |
| 94–98 (supplement) | CHANGE | PM loop delegates verification and waits for post-merge evidence before done. |
| 183–184 (supplement) | CHANGE | Replace the non-negotiable PM-rerun promise with verifier execution and PM evidence review. |

### `references/workflows.md`

| Line | Decision | Action/reason |
|---|---|---|
| 19 | CHANGE | First of the three merged-tree instructions: same verifier resumes after PM merge; PM sets done only on accepted passing evidence. |
| 20 | CHANGE | Archive worker replaces PM executor; KEEP the existing expressly recorded, limited PM-proxy rule. |
| 30 | KEEP | Proposal acceptance and independent-verification prerequisites still hold. |
| 37 | KEEP | Bootstrap model/category/gate prerequisites do not assign verification execution. |
| 160 | KEEP | PM must read the diff; that is acceptance, not running gates. |
| 174 | CHANGE | Rename §E2 from PM's background gate and label the `team_bg_run team review` example as verifier-owned. Preserve job lifecycle. |
| 297 | CHANGE | Distinguish verifier execution capacity from PM evidence-review bandwidth. |
| 150–154 (supplement) | CHANGE | §E heading and review commands name verifier execution; KEEP the PM-prepared detached-checkout command and clean-checkout requirement. |
| 236–282 (supplement) | CHANGE | Local/forge merge examples wait for same-verifier post-merge acceptance before done/close. Archive block delegates execution and reads exact blockers instead of demanding pre-archive exit zero. |

### `references/openspec.md`

| Line | Decision | Action/reason |
|---|---|---|
| 41 | KEEP | PM accepts exploration and records its decision; it does not execute verification/archive here. |
| 42 | KEEP | PM proposal review remains the planning-to-apply approval. |
| 44 | CHANGE | Second merged-tree instruction: same verifier runs post-merge verification, PM accepts then sets done. |
| 45 | CHANGE | Archive owner is a worker; replace exit-zero demand with exact self-blocker handling. KEEP all limits/reason recording for PM-proxy confirmation. |
| 52 | KEEP | Separate PM gate decisions are acceptance decisions, not ownership of execution. |
| 89 | KEEP | PM proposal-review heading remains accurate. |
| 146 | KEEP | PM's gate-review heading remains accurate; update executor wording within the table, not PM authority. |
| 154 | CHANGE | Worker checks readiness, uses a private disk trial root and archives on its branch. KEEP recorded confirmer/proxy reason; do not require exit zero with an active archive task. |
| 174 | KEEP | PM's done decision remains valid after the required phase evidence. |
| 153 (supplement) | CHANGE | Third merged-tree instruction: same verifier's merged-revision result precedes PM done/archive authorization. |
| 24–37 (supplement) | CHANGE | Replace release-number-based verify availability with actual generated-profile availability; never prescribe invalid `openspec instructions verify`. |

### `references/protocol.md`

| Line | Decision | Action/reason |
|---|---|---|
| 21 | CHANGE | Independent-check evidence comes from the verifier, not gates obtained by PM execution. |
| 32 | CHANGE | Verifier runs the same commands on another checkout; PM independently reads/compares the evidence. |
| 45 | CHANGE | Keep main ownership; distinguish verifier's tool-written named record/log exception from general main-checkout work. |
| 245 | KEEP | Limit on proving live PM publication duties is unrelated to verification execution. |
| 649 | CHANGE | Name verifier as command executor; KEEP PM checkout preparation and the tool's existing no-git behavior. |
| 962 | KEEP | PM checks the evidence chain before a decision; that is evidence acceptance. |
| 832–841 (supplement) | CHANGE | Replace PM execution of protected-branch verification at milestones with worker execution. Preserve selected/full-suite frequency, shared-lock and timeout policy. |

### `references/troubleshooting.md`

| Line | Decision | Action/reason |
|---|---|---|
| 68 | KEEP | Historical inbox/notification incident, not an operative verification instruction. |
| 1288 | KEEP | PM compares content after a merge conflict; that remains acceptance, not gate execution. |
| 1399 | CHANGE | Runbook says verifier runs `team review` on PM-prepared checkout and names the main-ledger exception. Keep PM preparation itself. |

### Repository root `README.md`

| Line | Decision | Action/reason |
|---|---|---|
| 15 | CHANGE | Public default describes verifier-run gates and PM acceptance, not PM-run gates. |
| 120 | KEEP | Bootstrap model/session choices remain unchanged. |

### Repository root `skills/teamsmith-init/SKILL.md`

| Line | Decision | Action/reason |
|---|---|---|
| 3 | KEEP | New-project discovery/model/gate setup description does not assign gate execution. |
| 85 | CHANGE | Handoff explicitly distinguishes delegated verification execution from the PM's orchestration/acceptance loop. |

### Additional evidence surfaces and canonical Purpose

- `scripts/lib/cmd-review.sh:1353,1356,1437`: CHANGE the hard-coded “PM 独立复验”, “PM 提供” and undifferentiated “PM 结论”. Record the actual executor, checkout path and verifier evidence; keep PM's later acceptance separate. `:871` and missing-checkout diagnostics may KEEP factual PM preparation. The PM-prepared-checkout baseline requirement at `openspec/specs/verification/spec.md:11–25` stays unchanged, so no MODIFIED delta is needed for it.
- `templates/report.md.tmpl`: CHANGE by adding the four fixed findings/assessment sections described in §4; existing command/flip evidence remains.
- `openspec/specs/verification/spec.md:5–7`: CHANGE only in the later separate Purpose documentation commit (§5). Native archive must preserve the existing Purpose; P435/apply do not edit it.

The inventory expands the future apply grant, not P435's write scope. No installed entry point or public description is excluded from the new default. Historic reports/archives are not rewritten. Current separately authorized changes are not blocked or retrospectively retested by this proposal.

## 2. Executor, checkout and record ownership

Use existing phase names, briefs, assignments, reports, reviews and PM close. Non-implementer workers perform verify/archive; the verifier may also archive. Do not add a roster role, category, config key, state file, permission engine or workflow coordinator. A project's report-only verifier cannot gain archive write access implicitly: use an eligible non-implementer worker instead.

The PM prepares a clean detached checkout and names the target revision; this retains `verification#Reviewing needs an independent checkout`. The assigned verifier, from its own worktree, runs `team review <ID> --dir <checkout> [--branch <target-sha>]`. The brief names the reviewed task ID, target revision and the exact record/log paths; the reviewed task ID need not be the verifier's own assignment ID. Derive executor identity from the caller's existing runtime-worktree identity, not from the reviewed implementation task's `agent:` or an inherited environment value. Use the existing identity helper rather than another resolver. If unavailable, say unknown rather than claiming PM; incomplete executor evidence is returned for clarification, not silently accepted. No new CLI flag or runtime refusal is introduced.

OWNERSHIP and the verify brief explicitly permit **only the tool** to write `docs/team/reviews/<ID>.md` and `docs/team/reviews/<ID>-verify.log` in the main checkout for this review. This is a narrow centralized-ledger exception, including the tool's existing review runtime bookkeeping; it does not enlarge its runtime-state write set. The worker's own report stays on its task branch. The exception grants no manual main-checkout edits, other review paths, code/spec writes, merge or push authority. Serial pre/post-merge runs use the same record/log; the verifier retains both revisions, command results and output tails in its branch report before the later run replaces the centralized record. The PM commits the named ledger output after inspection; workers do not commit in main.

The generated record uses a neutral independent-review title, an explicit actual-executor field and the checkout path. It does not infer PM execution from checkout preparation or automatically fill a PM approval. Keep verifier findings/results and PM's acceptance checklist distinct. Shell-gate verdict tokens, revision binding, dirty/mismatch refusals, lock/timeout behavior and report extraction remain unchanged.

When the verify assignment ID differs from the reviewed implementation ID, PM writes `docs/team/reviews/<verify-task>.md` as the verify task's own done-evidence **PM acceptance record**, using PM's existing docs authority without running gates. Its title explicitly says PM acceptance, not PM verification. It links the implementation task's tool-generated `docs/team/reviews/<impl-ID>.md`, the verifier's report and verified merged SHA; PASS records acceptance only after the required passing evidence. The implementation-ID tool record carries the actual executor/revision/results. Archive reads that execution record and the completed assessment, not a PM acceptance stub as substitute execution evidence. No additional worker main-write exception or command is introduced.

The separate archive grant covers only the worker's own task branch/worktree: the selected change and native dated archive destination, the enumerated affected capability specs, and `docs/team/reports/<archive-task>-<worker>.md`. Config, unrelated capabilities, main-checkout edits, protected-branch pushes and merges are excluded. The review-tool ledger exception is not an exception for native archive.

PM acceptance remains substantive: compare revisions/diffs, inspect commands, findings and changed files, reject missing/stale evidence, communicate findings and merge. If tests are needed, delegate them; a PM-owned background gate does not satisfy delegation. `team review --pre-merge` / `--post-merge` can remain PM content/ledger inspections because neither runs verification gates. In particular `--post-merge` is **not** the post-merge verification in §3.

## 3. Same verifier after merge, then readiness

The verifier first reviews the candidate and records its revision/results. PM reviews that evidence/diff and merges. The **same verifier resumes the existing verify assignment**, on a PM-prepared clean detached checkout of the merged SHA, and runs the applicable acceptance gates and OpenSpec checks for that merged revision. Use the existing `--branch <merged-sha>` to bind `team review` to that checkout; do not reuse a pre-merge PASS or the inspection-only `--post-merge` result. If the verifier stopped, resume it rather than transfer execution to PM. A failed/incomplete post-merge result keeps the work pending and is returned for authorized correction; no done or archive authorization first.

The verify brief includes both halves and the temporary record/log grant. Its report retains pre-merge and merged SHAs, exact commands/results, findings and unverified checks; the centralized record identifies the latest verified merged SHA. The PM accepts the post-merge result before setting done and preparing the archive brief. Later ledger-only commits are identified by diff; they are not silently represented as having been tested. Any intervening code/spec/delta change or merge-conflict resolution that invalidates evidence returns to the verifier. This assigns the existing merged-tree check; it does not add a second permanent verification task or increase the full-suite cadence. Preserve §12's selected/full/milestone distinction and report the executed scope.

The three explicit old merged-tree instructions are `references/workflows.md:19` and `references/openspec.md:44,153`. All three name this same owner/order. Both local and forge examples put done/close after accepted post-merge evidence. The two currently authorized changes and current V136 are not required to rerun checks retroactively.

Before archive the worker reads completed independent verification for the accepted merged baseline and the recorded confirmation, and reconciles task/checklist evidence. The archive brief explicitly declares the literal header `phase: archive`; `opsx-archive` is the command name, not this header value, and neither it nor `-` makes the row read as archive. `team change status <change>` prints each brief's phase verbatim and may exit nonzero because archive is itself active. The tool excludes only the row whose task ID exactly equals this archive brief's ID; the literal header makes that row readable as archive, but phase text is not the tool's self-match key. No exit-zero prerequisite is imposed before archive: a nonzero result is acceptable only if that exact-ID row is the sole blocker. Any other task row, another archive task, checklist problem or unreadable/ambiguous output still blocks. Update `workflows.md:281` and `openspec.md:45,154` together. Do not add a readiness switch or exclude every archive-phase row. Archive is not an unchecked implementation task that can only be ticked after archive. PM closes the task after accepted merge, with existing evidence/board behavior.

## 4. OpenSpec findings and confirmation

Use the project's generated `/opsx-verify` or `openspec-verify-change` entry. The currently generated `.pi/skills/openspec-verify-change/SKILL.md` (generatedBy `1.16.0`) is the source for classification and final assessment, not a new Teamsmith severity scheme. `openspec instructions verify` is not an artifact command: current `spec-driven` artifacts are proposal/specs/design/tasks. If the pinned profile lacks the generated workflow, perform its documented equivalent review and disclose that limitation; structural validation alone is not verification.

The report template has fixed `CRITICAL`, `WARNING`, `SUGGESTION` and `Final assessment` sections, plus a Completeness/Correctness/Coherence scorecard and explicit unverified checks/reasons. Follow the generated workflow's definitions:

- CRITICAL: incomplete tasks, missing requirement implementations, removed requirements still implemented, or renamed requirements whose behavior no longer exists; each has a concrete recommendation.
- WARNING: spec/design divergence or missing scenario coverage, with a recommendation. Do not automatically promote all contradictions or untested checks to CRITICAL.
- SUGGESTION: pattern inconsistency or minor improvement. Uncertainty follows the workflow's preference for the lower severity, not a new local threshold.
- Final assessment retains that workflow's counts and wording: unresolved CRITICAL means fix before archive; no CRITICAL with warnings/suggestions and all applicable checks completed can be ready with noted improvements; skipped/partially verified applicable checks are named with reasons and prohibit an unqualified readiness claim. Intentionally omitted/not-applicable checks are not fabricated missing work. A report with skipped checks must not say all checks passed.

These sections are authored assessment, not values invented from `team review`'s shell PASS. The verify report is referenced from the review/brief; archive reads both, checks CRITICAL zero, and retains WARNING/SUGGESTION/unverified dispositions. Empty template placeholders are not completed verification. The upstream workflow treats verification as advisory and archive as retaining its own confirmation behavior: unverified checks are disclosed, not a new automatic CLI refusal or universal CRITICAL. No parser, new verdict token or independent severity classifier is added.

Preserve the existing limited confirmation rule in `openspec.md:45,154` and `workflows.md:20`: user confirmation, or explicit PM-proxy confirmation **only** for a small, reversible change already covered by the approved approach, with identity and reason recorded. The archive worker checks who confirmed and why the proxy case meets those limits. PM acceptance alone or an unexplained proxy claim is not confirmation. WARNING findings and unverified checks/reasons are disclosed before confirmation and remain visible afterwards. Unresolved CRITICAL findings stop archive regardless of confirmer.

## 5. Archive, dependent baselines and Purpose

The archive worker first trials native archive on a private disk-backed copy, checks resulting capability specs and validation output, then runs native archive in its own worktree and commits the specs, dated archive and report. The example replacing `openspec.md:154` uses a unique directory, not `/tmp/trial`:

```sh
trial_root="$(mktemp -d -p /var/tmp teamsmith-archive.XXXXXX)"
mkdir "$trial_root/project"
cp -a openspec "$trial_root/project/openspec"
(cd "$trial_root/project" && openspec archive -y <change>)
# Inspect the complete output and resulting specs before removing only this exact directory.
rm -rf -- "$trial_root"
```

This project's disk root is `/var/tmp`; another project substitutes its declared disk-backed root, never an assumed RAM-backed `/tmp`. Failure is recorded and returned for correction, not ignored or used to justify a real archive. Trial success does not waive prerequisites. PM inspects and merges the resulting branch; P435 authorizes neither a trial nor a real archive.

For `alpha → beta`, PM accepts and merges alpha's archive first, then prepares beta's archive branch/brief from that new protected-branch revision. Beta's worker compares every complete `MODIFIED` block and scenario to the accepted post-alpha requirement. A successful native validation on stale text does not prove preservation. If a block loses accepted behavior or a delta correction invalidates verification, return it to its authorized owner and obtain independent re-verification before archive. Reports name predecessor/merged baseline and reconciliation evidence. This uses existing briefs/git, not a dependency graph, new field, lock or state machine.

**Purpose sequencing is explicit.** Native synchronization/archive preserves the existing capability Purpose, including the currently stale text. The native archive result is one commit; only afterwards, on the same authorized archive branch, make a **separate Purpose-only documentation commit**. Its report names both commits and shows this exact editorial before/after; PM reviews it separately and preserves it as a distinct documentation commit when integrating. It does not change requirements, scenarios, unrelated capabilities or the protected archive tree's copies of planning artifacts. Do not change Purpose under cover of native archive, or edit canonical Purpose during propose/apply.

Before (`openspec/specs/verification/spec.md`, existing Purpose, preserved by native archive):

```text
The PM's independent check of an agent's claim: gates run on a checkout the agent never touched, a hard timeout, and
a written record that future readers can audit. Why a report is only a claim and the review is the evidence:
`references/philosophy.md` (principle 1, "a false green is worse than nothing") and `references/protocol.md`.
```

After (only the separate documentation commit):

```text
Independent workers check an implementer's claim on a checkout the implementer never touched, under a hard timeout,
and write evidence the PM reviews before merging. Why a report is only a claim and the review is the evidence:
`references/philosophy.md` (principle 1, "a false green is worse than nothing") and `references/protocol.md`.
```

The later archive brief must explicitly grant and enumerate this Purpose-only follow-up and require its diff. It is not a pre-archive checklist item or authority to rewrite Purpose in other changes.

## 6. Existing tests and acceptance

Replace weak checks in smoke `19`, using existing `os_pipeline_hits`/`os_flip_red` sandboxes: owner-presence/whole-file independent-user-confirm searches become operative owner/precondition checks. Preserve proposal acceptance, phase presence, apply gate, tool pointers, P404 adapter/correctness and unrelated checks. No new section, scanner or test script. Clean/red/restored cases cover a nonempty PM phase/template owner, absent OpenSpec verification, unresolved CRITICAL allowance, missing own-worktree boundary or predecessor baseline. Keep confirmation tests, changing them to the **retained** limited proxy rule rather than forbidding it. Same-verifier merged-tree wording is included in the owner checks; complete inventory review remains a human, independent verification task, not another grep gate.

Section `12j` changes the PM archive example to a worker but keeps sibling/checklist/self-exclusion behavior. In `10`/`10b`, strengthen existing record/evidence assertions to run the real review command as a sandbox verifier distinct from the implementation-task author and assert its real executor, target SHA and the named main record/log; replace the old PM-attribution/checkout-only evidence assertion rather than add an identity gate. A mutation restoring hard-coded PM attribution must fail, then pass on restore. Reuse the existing clean-checkout/no-other-main-writes assertion for the narrow exception; do not grow the write set. Extend the existing report-template evidence case with the fixed assessment sections while retaining flip coverage, funded by retiring section `19`'s broad whole-file-word assertions rather than adding a prose guard or runtime classifier. No new guard section or runtime refusal is needed: the defect is in generated evidence and shipped instructions, which must carry the correct behavior themselves.

`section-paths.tsv` names every real file read by each affected section, including new guidance files where read; sandbox copies must also include root README/init guidance if the checker reads them. Do not claim section `19` tests the review runtime: that belongs to `10`/`10b`.

Future apply acceptance, executed by workers in the project-approved isolated environment:

```sh
export PATH="$HOME/.bun/bin:$PATH"
openspec validate delegate-openspec-archive --type change --strict
openspec validate --all --strict
bash skills/teamsmith/tests/spec-refs.sh
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh --select 19,12j,10,10b
bash skills/teamsmith/tests/section-select.sh --check
```

Record exact commands, exit codes, actual selected/skipped coverage and red/restored evidence. Existing strict-validation failures are named, not silently passed or fixed out of scope. P435 only runs planning structure/reference checks; no mutation, product test, post-merge verification or real team-flow pass is claimed here.

## 7. Adoption and rollback

Future install or explicitly authorized guidance refresh adopts the source default; no automatic project refresh, init, restart, shared-skill upgrade, historical memory rewrite or other-project action is added. Refresh only the Teamsmith AGENTS markers; preserve outside project rules byte for byte. Authorization boundaries and full-suite cadence are unchanged.

A contrary operative instruction, false executor, omitted post-merge check or required mutation staying green returns the change to apply before acceptance. Revert the small source/evidence/test commits for rollback; there is no state/data migration. This change's later verify/archive have separate briefs. Current authorized verify/archive work is not held up by this planning correction.
