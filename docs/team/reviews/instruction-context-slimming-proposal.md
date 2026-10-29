# instruction-context-slimming · Formal proposal review

Candidate: `00f7d50e2879` (proposal artifacts `b3a48b35`) · verdict: **REWORK REQUIRED — no Apply authorized**

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
