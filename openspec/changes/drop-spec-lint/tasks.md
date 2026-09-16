## 1. Removal

- [ ] 1.1 Delete `skills/teamsmith/tests/spec-lint.sh`; remove smoke §16 and every smoke assertion that calls it.
- [ ] 1.2 `TEAM_GATES`: `.pi/team/config.sh`, the `{{GATES}}` default fill in `scripts/lib/`, and
  `templates/config.sh.tmpl`'s comment — the gate is now `openspec validate --all --strict && smoke`.
- [ ] 1.3 Docs: `SKILL.md` (command table/diagnostics row), `references/openspec.md` (gate becomes validate+smoke;
  add the writing-convention note as prose), `references/workflows.md`, `references/migration.md`,
  `docs/team/PROTOCOL.md`, `AGENTS.md` team block.
- [ ] 1.4 The MODIFIED delta in this change (memory-and-deps) must match the removal: the scenario naming the script
  is gone, everything else byte-identical.

## 2. Evidence

- [ ] 2.1 Both acceptance commands green; the grep acceptance line prints nothing outside CHANGELOG/history.
- [ ] 2.2 Report `docs/team/reports/M10-<agent>.md`: before/after of the gate string, the list of touched files, and
  proof that a spec mistake still fails somewhere honest (a broken spec fails `openspec validate --all --strict`
  red, or surfaces at the trial archive — show one).
