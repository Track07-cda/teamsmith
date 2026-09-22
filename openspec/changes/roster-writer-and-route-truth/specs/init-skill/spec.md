## MODIFIED Requirements

### Requirement: Initialization guidance lives in a dedicated teamsmith-init skill

The repository SHALL contain `skills/teamsmith-init/SKILL.md` (at most 100 lines) whose frontmatter names
`teamsmith-init`, and whose body is the new-project entry point in three beats: an ordered checklist of the
questions the PM must settle with the user (dependencies, session/roster, per-agent models, gates, VCS mode,
install command, ROADMAP/OWNERSHIP/AGENTS.md red lines), the instruction to run
`bash <teamsmith>/scripts/team bootstrap`, and a closing handoff sentence that points day-to-day operation at
the `teamsmith` skill. The init skill SHALL own exactly two files moved from the daily skill —
`references/bootstrap.md` and `templates/bootstrap-prompt.md.tmpl` — moved, not copied, and MUST NOT contain
`scripts/`, `extension/` or `tests/` directories, nor claim ownership of the pulse, dispatch, review or merge.

The checklist's roster bullet SHALL name the route that really changes the roster: `team add-agent <name>
--register` to grow it and `team teardown --agent <name> --register` to shrink it, each write audited. It MUST NOT
promise that a bare `team add-agent <name>` changes the roster — that command refuses a seat the roster does not
carry — and its claim SHALL stay true for the tree that ships it (the command it names is the one the route walk
of `dispatch` proves works in a fixture).

#### Scenario: The init skill exists, parses and stays small

- **WHEN** `test -f skills/teamsmith-init/SKILL.md`, `wc -l < skills/teamsmith-init/SKILL.md` and
  `bun skills/teamsmith/tests/skill-load.mjs skills/teamsmith-init` run
- **THEN** the file exists, the line count is at most 100, and the parser exits 0 with frontmatter
  `name: teamsmith-init`

#### Scenario: The body carries the three beats

- **WHEN** `skills/teamsmith-init/SKILL.md` is searched for the checklist, the bootstrap command and the handoff
- **THEN** it contains an ordered question checklist covering roster/models/gates/VCS, a line invoking
  `scripts/team bootstrap`, and a closing sentence naming `teamsmith` as the skill for day-to-day operation

#### Scenario: The two moved files have exactly one home

- **WHEN** `test -f skills/teamsmith-init/references/bootstrap.md`,
  `test -f skills/teamsmith-init/templates/bootstrap-prompt.md.tmpl`,
  `test ! -e skills/teamsmith/references/bootstrap.md` and
  `test ! -e skills/teamsmith/templates/bootstrap-prompt.md.tmpl` run
- **THEN** all four checks pass (present at the new home, absent at the old)

#### Scenario: The init skill carries no code

- **WHEN** `find skills/teamsmith-init -maxdepth 1 -type d` runs
- **THEN** no `scripts/`, `extension/` or `tests/` directory is listed

#### Scenario: The roster sentence names the register route

- **WHEN** the roster bullet of `skills/teamsmith-init/SKILL.md` is read and searched for `team add-agent` and
  `--register`
- **THEN** the bullet names `team add-agent <name> --register` (and `team teardown --agent <name> --register`),
  says the write is audited, and no sentence in the file promises that a bare `team add-agent <name>` changes the
  roster
- **AND** the pre-change sentence is the red side of this check: it read "`team add-agent <name>` adds more at any
  time", which the measured tool refused with `未知 agent` when the seat was not in the roster
