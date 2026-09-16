## Why

The user (2026-09-16, after D23): "不要留，这个应当是由openspec负责管理这些spec" — the project must not maintain a
custom checker for spec content. spec-lint.sh's falsifiability half (scenario presence, WHEN/THEN, placeholder
detection) is a parallel judge of OpenSpec's files; OpenSpec owns spec management. This change removes the checker,
its gate step, its smoke section, and its references. The *writing convention* (requirements carry testable
scenarios) stays as prose guidance in references/openspec.md — guidance, not a gate.

## What Changes

- Delete `skills/teamsmith/tests/spec-lint.sh` and smoke §16 (its dedicated section); remove
  `bash skills/teamsmith/tests/spec-lint.sh` from `TEAM_GATES` in `.pi/team/config.sh`, the bootstrap/init default
  (`{{GATES}}` fill), and every doc that names the three-step gate (SKILL.md, references/openspec.md,
  references/workflows.md, references/migration.md, docs/team/PROTOCOL.md, AGENTS.md team block).
- The project gate becomes: `openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh`.
- memory-and-deps: MODIFIED "Spec management belongs to OpenSpec" — remove the scenario that names the deleted
  script (the requirement's other content, including "no rival requirement tree", is unchanged).

## Boundaries

User-directed removal. No replacement checker, no new tooling. OpenSpec's own `validate` stays in the gate; a spec
mistake that validate cannot see surfaces at the trial archive (D23's procedure), which is where OpenSpec's own
machinery speaks.

## Acceptance

```sh
openspec validate --all --strict
bash skills/teamsmith/tests/smoke.sh
grep -rn "spec-lint" skills/ .pi/team/config.sh AGENTS.md docs/team/PROTOCOL.md   # → no hits (except CHANGELOG history)
```
