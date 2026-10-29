# P389 · Explore instruction-context slimming and safe AGENTS upgrades

task: P389
agent: dev3
phase: explore
category: analysis
change: instruction-context-slimming
deltas: -
branch: task/P389-agents
deps: user request 2026-10-29; current main f4314359; P388 remains a separate blocked implementation and is not a base for this work

## User goal and phase boundary

The user asked to **slim the duplicated instruction context**, then use `team init` to slim an existing project's `AGENTS.md`. This is real implementation intent, but the required Explore → Propose → Apply → Verify → Archive workflow applies. This brief is **Explore only**: inspect, decide the minimal rule ownership and migration acceptance, and write `docs/team/reports/P389-dev3.md`. Do not edit prompts, AGENTS, skills, dispatch code, canonical specs, change artifacts or live project configuration yet. A separate Propose and formal review will follow.

Current measured sources on main:

- `templates/AGENTS.section.md.tmpl`: 167 lines / 11,385 bytes; fresh init adds two marker lines (about 169 lines / 11.4 KB).
- `templates/pm-prompt.md.tmpl`: 150 lines / 11,709 bytes.
- `SKILL.md`: 331 lines / 37,203 bytes.
- Worker dispatch prompt is separately written in `scripts/lib/cmd-agents.sh` around lines 128–177.
- The current project's existing `AGENTS.md` is 196 lines / 13,530 bytes, showing that an existing managed block is refreshed only when init is adopted, not when the source template changes.

The sources have semantic rather than exact-line duplication. PM startup can load AGENTS + pm-prompt + SKILL (about 60 KB before references); workers receive AGENTS + dispatch prompt. Do not use an exact-text-only analysis and do not invent a token/performance gate.

## Questions to resolve

1. Build a compact rule-ownership matrix for AGENTS, pm-prompt, worker dispatch prompt, SKILL and `references/{protocol,workflows,openspec}.md`: which rules each audience actually needs at startup, which detailed rules can be pointer-only, and which short safety red lines intentionally remain duplicated for self-contained worker launch.
2. Recommend a smaller structure, not mechanical deletion:
   - AGENTS should be the shared cross-seat constitution/reading order, not both PM and worker manuals.
   - pm-prompt should carry PM-only startup actions, role boundaries and essential handoff/evidence rules, with detail in the skill/references the PM already loads.
   - dispatch prompt must remain self-contained on ownership/BLOCKED, turn-end states, test truth, protected branch, safe background jobs and delivery evidence; do not remove a worker's only copy of a rule merely because AGENTS also has it.
   - SKILL/references should hold detailed procedures without creating a new template-generation or rule-registry system.
   Identify exact sections to remove/merge/point and approximate before/after size as a planning estimate, while preserving necessary coverage and current behavior.
3. Prove the existing-project upgrade path from source: `cmd-project.sh` `team_write_section` and `team_cmd_init`, plus `cmd-bootstrap.sh`. The expected answer is yes: an existing managed block between `teamsmith:begin/end` is replaced with the new rendered template, content outside remains, old `pi-team` markers migrate. Document what happens with no marker, missing file, legacy marker, repeated init, `--force`, `--no-skills`, and what other writes init still performs. `--no-skills` does not mean AGENTS-only and does not skip AGENTS.
4. Define fixtures/acceptance for a later Apply: an existing project with verbose old managed content and unique custom text before/after the markers must become shorter after init while custom text and non-AGENTS config survive; old markers, no markers, idempotence and no-skill mode need explicit cases. Never run init against this live project in exploration.
5. Check for contradictions as well as duplication: startup order, report/evidence requirements, full-versus-selected gates, background-job suspension, model categories, PM/worker boundary, OpenSpec gates, pulse/standby. Preserve the newer authoritative rule where sources differ and name the canonical destination; do not choose whichever wording is shorter.
6. Recommend the smallest change/delta set and independent review focus. No new guard framework, rule database, code generator or mandatory migration command should be introduced just to deduplicate prose.

## Reading

Read `AGENTS.md`, your thread, this brief, OWNERSHIP and `skills/teamsmith/references/openspec.md`. Inspect the actual templates, SKILL, dispatch prompt construction, relevant references and init/write-section tests. Follow the PM and worker loading paths rather than assuming every seat reads every file. Read existing install-shape/init fixtures before proposing acceptance. Do not read credentials or live session files.

## Constraints

- Only versioned write: `docs/team/reports/P389-dev3.md`; scratch under `$HOME/.cache/P389/`.
- No product/prompt/spec/change edits, no `team init`/bootstrap on any real project, no live PM/worker restart, no full gate, merge, push or release.
- This exploration does not authorize Apply or running init on pm-skills. Later adoption is a separate user-authorized action with preview.

## Acceptance and handoff

Run and record:

```bash
openspec validate --all --strict
bash skills/teamsmith/tests/spec-refs.sh --check
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
bash skills/teamsmith/tests/section-select.sh --paths docs/team/reports/P389-dev3.md
git diff --check
git status --short
```

The report leads with the recommended slim structure, the existing-project init answer, concrete source sections and preservation risks. Commit with Conventional Commits + P389 + `Agent: dev3`, leave the branch clean and notify PM. PM will review the exploration and authorize a separate proposal only after the approach is coherent.
