# instruction-context-slimming · Formal proposal review

Current candidate: `f5945feb52cd` (2026-10-30 R1/R2/R3 reconciliation) · verdict: **NEEDS-CHANGES — no Apply authorized**

Historical first candidate: `00f7d50e2879` (proposal artifacts `b3a48b35`); the first structural checks below refer to that earlier tip.

PM has read the complete proposal, design, tasks and init-skill delta. The proposal follows D208: shared short AGENTS, PM-specific startup, self-contained worker safety/delivery prompt, detailed SKILL/references, no new rule generator, and ordinary init managed-block replacement with explicit boundaries.

## Independently reproduced checks

Clean clone: `$HOME/.cache/pm-skills-reviews/P391-00f7d50e/candidate`.

- change strict valid; all specs 20/20;
- apply instructions ready, 24 tasks all unchecked;
- spec-refs and real-names ledger scan pass; `git diff --check` pass;
- disposable-copy archive applies exactly two init-skill additions and validates 19/19; real candidate change remains and checkout is clean.

Evidence: `$HOME/.cache/pm-skills-reviews/P391-00f7d50e/static-checks.log` and `trial-archive.log`. These establish structural/merge hygiene only.

## Substantive review focus

- Existing specs' required local statements must survive on their named surfaces; no keyword/size/performance substitute for the independent rule-by-rule read.
- Prose corrections must match current behavior, not silently change selected/full gates, local/remote delivery, pulse recovery, category/model routing, capacity or OpenSpec phases. Only init-skill is declared; any actual obligation change elsewhere requires another delta.
- Existing-project refresh must preserve outside text and existing config/ledger bytes under the documented well-formed marker assumptions, disclose other writes/non-transactionality/defaults/main-root target, and distinguish init from bootstrap/force.
- Current pm-skills' 28-line / 1,988-byte custom section at `AGENTS.md:49–76` is not protected inside markers. Live adoption requires a separately authorized outside-marker preservation diff before any exact init preview/execution; product Apply does not include it.
- Reused fixtures must prove behavior and red/green mutations without deleting old assertions or adding a migration/prose-guard framework.

## Independent review outcome — six required corrections

V113's report `f752109bd570` is **NEEDS-CHANGES** and is adopted. The architecture is sound, but Apply cannot start until these are fixed and independently re-reviewed:

1. Replace nonexistent `references/watchdog.md` destinations with `references/protocol.md` §8 and `references/workflows.md` §D/§I.
2. Put existing-project refresh guidance in `references/migration.md` (its existing home), not new-project workflows §A; correct migration §2/§2c's current “init or bootstrap” wording in the same edit, leaving only cross-links in workflows/SKILL.
3. Replace `install-shape.sh --flip` (V113 measured ✓1/✗0 with no flip section) with explicit section arguments: full no-arg run ✓165/✗0 and `install-shape.sh flip` ✓42/✗0. Section names are not flags.
4. Correct `references/protocol.md` §9 itself so the capacity destination includes MemAvailable and temp/worktree disk/inode limits, not just swap/RAM+swap.
5. Add the missing required SKILL surfaces to the preservation worksheet: verification's dual-gate division in SKILL+protocol, and agent-adapters' frontmatter description, `## Agent adapters` section and frozen/deep-read table wording.
6. State that ledger-ban names come from the actual project `.pi/team/forbidden-names.txt`; a clean clone's computed relative path can be missing and rc=3 is not a pass.

Nonblocking boundaries also remain: FAST §6 proves printed prompt assertions but skips real launch; selected green is not full coverage; trial archive proves structure only; supported marker shapes and the 28-line live custom section remain explicit.

P391 must append the proposal correction, then V113 performs a focused second review. The formal verdict stays REWORK REQUIRED until that evidence is accepted. No live init/reload, Apply, protected merge/push or release is authorized.

Additional live evidence (2026-10-29): the user's screenshot shows PM writing a temporary reply file, posting it, then repeating the answer. v0.3.4 and current PM template still show `--stdin < <file>`, while protocol §4b already supports a one-command heredoc. A heredoc alignment was considered, but the user then explicitly chose a different final workflow in D213: marker-based normal Pi replies captured by an extension, with the marker removed from Pulse and Pi display. **That heredoc correction is withdrawn and must not be Applied.** P391's key-reply portion waits for P394; its formal review remains REWORK REQUIRED.

## V113 second round — six corrections accepted, D213 integration still blocking

V113 second-round report `4ae2700d6bee` accepts every first-round correction on P391 candidate `07266efaf617`: valid reference destinations, migration.md ownership and bootstrap correction, real flip section commands, complete capacity destination, all required SKILL preservation surfaces, and real-project ledger names. It independently reproduced change/all validation 20/20, disposable archive 19/19, spec-refs/ledger/diff checks and 0/24 Apply tasks.

PM adopts that result. The overall proposal remains **NEEDS-CHANGES / blocked**, now solely because its PM reply edit points and acceptance still describe the superseded explicit-post workflow. D213/D214 require marker-based Pi capture with final cleanup and an accepted transient stream flash. P391 may not Apply until the P394 replacement proposal is accepted and these instruction/delta tasks are reconciled. No heredoc substitute is allowed.

## 2026-10-30 continuation — updated user scope, launcher blocked

P395 is formally ACCEPTED (`0e557f47`, D216), so the proposal can now reconcile marker-capture instructions without waiting for P396's full gate. The user further requires init to modify only the Teamsmith managed block, preserve all outside sections, and tell PMs in generic AGENTS/PM startup text to place custom rules outside that block. The P391 brief now includes those inputs and permits only a minimal existing-writer correction in the plan if necessary (notably legacy normalization outside examples), replacing the former unconditional text-only limitation. This revised exact proposal still needs independent targeted review before ACCEPTED/Apply; no original six V113 findings are reopened.

PM preserved V117's accepted report/branch, switched dev3's clean worktree back to the original P391 branch, and committed only the updated planning brief/context at `0523cee4`. The actual dispatch followed category policy with no --model override (`selected_via=policy`, `launch_via=policy`) but exited rc=1: `Unknown provider "cline-pass"`. The CLI lists provider `clinepass`, model ID `cline-pass/deepseek-v4.1-flash-1017`; config currently omits the true provider prefix from the combined route. The worker is not running. PM did not change configuration, substitute a model or restart P397's user-adjusted seat. Exact full route is recorded in OPEN-ITEMS for the user's correction/authorization. No new proposal artifacts, product change, live init or full smoke had occurred at that failure point.

### User-authorized route correction and successful launch

The user explicitly requested the config correction. At 07:27Z PM backed up config to `/var/tmp/pm-skills-model-route-fix.2Y29wG/config.sh.before` and used the single audited config writer to update four route prefixes only. Byte comparison proved every other config byte unchanged, including PM/docs values. `bash -lc '"$HOME/.bun/bin/pi" --list-models'` confirms provider `clinepass` and model ID `cline-pass/deepseek-v4.1-flash-1017`.

An initial --fresh-only recovery still selected the failed assignment's old model string (preview and actual launch, rc=1). Source `cmd-agents.sh:1138–1195` confirms a matching assignment retains its complete model when no differing explicit override is supplied, even with --fresh. PM corrected that failed identity with --fresh and the exact now-configured route `clinepass/cline-pass/deepseek-v4.1-flash-1017:max`; this is a route repair, not a different model or blanket override. The exact-model preview was asserted before launching. Actual SID `teamsmith-dev3-1793345358-213772-11806-30271` now runs that route; the live pane shows provider/model and initial git/read tool calls in the preserved P391 branch. P391 is in progress on planning rework, not accepted/Apply. No running P397/other seat was changed. Ordinary new tasks continue to use category policy without --model.

## 2026-10-30 candidate 6bf9ff57 — final input reconciliation needs a narrow correction

PM read all four revised artifacts and the appended author report. Marker reply instructions now consume P395/P396 rather than the old explicit-post flow, and AGENTS/PM both carry the custom-placement duty. The six V113 corrections stay closed. No product source was changed. The author reports structural checks; PM has not claimed a new independent structural pass on this tip.

Three current inconsistencies change the next step (minimal planning rework before independent targeted review):

1. The delta simultaneously says quoted-only marker occurrences are unsupported and says such a file keeps its text and gains a block. The design's input table likewise calls indented/same-line occurrences unsupported while its valid preservation fixture contains them. Only the actual recognized delimiters decide a managed range; ordinary quoted/indented examples must not become failures merely by containing marker text.
2. CRLF and a missing final newline are ordinary text formats, not user-authorized reasons to refuse an update. Fix byte-range preservation rather than force normalization or add format guards. PM independently invoked the real writer only on private `/var/tmp` files: CRLF returned 0 and reported a refresh without installing the new body; an outside custom tail without a final LF gained a byte. Evidence: `$HOME/.cache/pm-skills-reviews/P391-6bf9ff57/writer-probes.json`. These prove the writer needs a correction; they do not justify rejecting these formats.
3. The legacy scenario's “old markers are absent” must refer only to the actual managed pair, not the whole file while its quoted legacy example is expressly preserved. The append/idempotence contract must also address an unclosed fenced example: if it protects through EOF, blindly appending a block there leaves it unrecognized on the next run and can append forever. State the minimal handling without adding a general Markdown parser or guessing repairs.

PM returned only these points (plus the glued GIVEN/WHEN line typo) to dev3 in its thread and a zero-key watch message. No Apply, live init, model/config change, full smoke, new gate section, merge/push or archive is authorized. Independent targeted review follows the corrected frozen tip; it must inspect these two new inputs, not repeat the six already-accepted findings.

### R1/R2/R3 revision delivered — independent V119 now required

Author delivered `f5945feb52cd` with only the four planning artifacts and report changed from `6bf9ff57`. PM read the revised classification, legacy scope, line-ending support and append/idempotence scenarios. The proposed unsupported-format refusals are removed; quoted/indented examples are ordinary content; truly ambiguous boundaries and no-pair/unclosed-fence append fail without changing AGENTS. Marker reply ownership and placement guidance remain present. These are corrected planning statements, not a repaired writer or deployed prompt.

V119 (dev2, not author dev3) independently checks only this final input diff plus non-regression of the already-accepted six V113 corrections. No full suite/long mutation run. PM will independently reproduce final structural/trial-archive checks in parallel. Formal ACCEPTED still requires both substantive reviews and their evidence. P393/P396 source integration, the 28-line live custom preservation, real init and PM reload retain their separate sequencing/authorization boundaries.

PM final frozen-tip structural check is now independently PASS: background `p391-pm-final-proposal-validatio` exit 0; strict validation 20/20, apply metadata ready with 25 unchecked tasks, spec-refs 121/0 undeclared, real-name ledger hits=0/names=ok, disposable archive +2 requirements followed by 19/19, five final boundary/placement scenario headings unique, original change still present and clean. Log and script: `$HOME/.cache/pm-skills-reviews/P391-f5945feb/`. No smoke/install matrix/live init ran. This does not replace V119's substantive verdict.

### V119 delivered: one narrow return, no architecture reopening

V119 `59fd12c00c8d` independently returns NEEDS-CHANGES on frozen `f5945feb52cd`; report available via `git show 59fd12c00c8d:docs/team/reports/V119-dev2.md`. Its prior PM-metadata ledger blocker B1 is closed on the review branch (hits=0); PM main also passed hits=0 after `0ec4c4b7`. The report's remaining reference to old main `baf5850e` is historical, not an outstanding main failure.

PM consolidates S1–S4 into the same minimal proposal correction: (1) scan every eligible delimiter candidate before deciding, require one unambiguous supported pair for refresh and explicitly refuse multiple candidates rather than implying the scanner stops at the first; qualify the append example as a closed fence, leaving the unclosed-fence refusal unchanged; (2) choose the existing begin-delimiter line's LF/CRLF as the replacement body's terminator, including mixed-ending files, preserve both delimiter lines/outside bytes, and strengthen the existing expected-file comparison so an LF-only body inserted in a CRLF block goes red without adding a separate gate; (3) point the existing tasks at the already-specified ambiguity/unclosed-fence baseline fixtures; (4) complete the already-cited narrow backtick-fence rule's info-string condition, without a generic Markdown parser or shared parsing framework.

Dev3 remains P391's proposal author. Only its existing four artifacts/report change; the six V113 corrections, accepted marker lifecycle and live-adoption permissions stay settled. Independent follow-up inspects this diff, not another full proposal/fixture matrix. V119's completed review branch is retained while dev2 returns to P397 rework; no Apply is authorized.
