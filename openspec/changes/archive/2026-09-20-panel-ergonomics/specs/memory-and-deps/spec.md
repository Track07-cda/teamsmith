## MODIFIED Requirements

### Requirement: The disk is the source of truth, memory is a convenience

Project memory (magic-context) SHALL only accelerate recall: every decision, piece of evidence and piece of pending
work MUST be reconstructible from files on disk (BOARD, ROADMAP, DECISIONS, reports, reviews, threads, state) after
a restart or a compaction, without reading any memory store. The Chinese name the tool and its console use for the
correspondence records in `docs/team/threads/` SHALL be `往来记录` — `线程` reads as an operating-system thread —
while the directory path, the command `team thread` and the English term `thread` stay unchanged.

#### Scenario: Pending work survives a memory-less start

- **GIVEN** a project with one unread notification and one report awaiting review, and no memory store available
- **WHEN** a fresh shell runs `team digest`
- **THEN** both items are listed as pending work

#### Scenario: Decisions are on disk, not only in memory

- **WHEN** a key decision was made in a task
- **THEN** its rationale and impact are written in `docs/team/DECISIONS.md` (or the task's review record) and are
  readable without any memory tooling

#### Scenario: The renamed label keeps the path and the command

- **GIVEN** a fixture project with an initialized docs skeleton and no `docs/team/threads/dev.md`
- **WHEN** `team thread dev` runs, and then `team thread dev "note" --from pm --re X1` runs
- **THEN** the first output names `往来记录` and the path `<docs>/threads/dev.md`, and the second appends one entry
  to that same file — the directory and the command name did not change with the label

#### Scenario: The rendered threads README carries the new label

- **GIVEN** a scratch project
- **WHEN** `team init --agents "dev verify" --force` renders the docs skeleton
- **THEN** `docs/team/threads/README.md` contains `往来记录`, contains no `线程`, and its path is unchanged
