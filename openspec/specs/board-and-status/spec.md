# board-and-status Specification

## Purpose

The ledger the PM runs on: what the board statuses mean, when a task may become `done`, and how `digest`/`status`
surface work that was delivered but not verified or not wrapped up. Why status is a promise:
`references/philosophy.md` (principle 2) and `references/protocol.md`.

## Requirements

### Requirement: The board status vocabulary is closed

`team board set <ID> <status>` SHALL accept only `todo`, `wip`, `review`, `done`, `blocked` and `dropped`; any other
word MUST be rejected with the allowed set and MUST leave the row unchanged.

#### Scenario: A typo cannot invent a status

- **GIVEN** a board row `| T1.1 | first task | dev | - | - | todo |`
- **WHEN** `team board set T1.1 shipped` runs
- **THEN** the command exits non-zero, prints the allowed statuses, and `team board row T1.1` still reports `todo`

#### Scenario: A legal status is written to the row

- **WHEN** `team board set T1.1 review` runs
- **THEN** `team board row T1.1` reports `review` and the rest of the columns are unchanged

### Requirement: `done` means landed and pushed

A task SHALL be marked `done` only after the review record says `PASS` **and** the task branch is an ancestor of the
protected branch **and** the protected branch is pushed. The PM verifies this with git (`git merge-base
--is-ancestor <branch> <protected>` must exit 0; `git status -sb` must not be ahead of the upstream) — status is not
evidence by itself.

#### Scenario: An unmerged branch cannot be done

- **GIVEN** task branch `task/T1.1-*` whose commits are not in the protected branch
- **WHEN** `git merge-base --is-ancestor task/T1.1-* <protected-branch>` runs
- **THEN** it exits 1, so the task must stay `review` (or `wip`) and must not be closed as `done`

#### Scenario: A merged and pushed branch may be done

- **GIVEN** the same branch after `merge --squash` + commit + push to the protected branch, and a review record with
  `PASS`
- **WHEN** `git merge-base --is-ancestor <the squash commit> <protected-branch>` runs and the branch is pushed
- **THEN** it exits 0 and `team board set <ID> done` may be used

### Requirement: Delivered-but-unverified work is detected

`team digest` SHALL list real task reports that have no review record as pending verification, and it MUST NOT list
non-task reports (milestone or closure notes) as pending work.

#### Scenario: A task report without a review is pending

- **GIVEN** `docs/team/reports/T1.1-dev.md` exists and `docs/team/reviews/T1.1.md` does not
- **WHEN** `team digest` runs
- **THEN** the pending-verification section names `T1.1`

#### Scenario: A milestone note is not pending work

- **GIVEN** `docs/team/reports/P2-closure.md` exists with no matching review record and no board row
- **WHEN** `team digest` runs
- **THEN** it is not counted as pending verification

### Requirement: Unfinished work is visible as pending wrap-up

`team status` (and the same data in `team digest`) SHALL report an agent's work that is not wrapped up — a dirty
worktree, commits not pushed, or a task whose report is missing — instead of reporting the agent as idle and done.

#### Scenario: A dirty worktree is pending wrap-up

- **GIVEN** an agent worktree with uncommitted changes and a recorded task
- **WHEN** `team status` runs
- **THEN** the agent appears in the pending-wrap-up section naming the worktree state

### Requirement: A failed step does not leave a false status

A dispatch that is refused (guards, capacity, model limit, template contract) MUST NOT set the task to `wip`, and a
review whose verdict is not `PASS` MUST NOT lead to `done`; the status a task had before the failed step MUST remain
observable on the board.

#### Scenario: A refused dispatch leaves the board alone

- **GIVEN** board row `| T1.1 | … | todo |` and a dispatch that the model-concurrency guard refuses
- **WHEN** `team board row T1.1` runs afterwards
- **THEN** the status is still `todo`

#### Scenario: A failing review is not a pass

- **GIVEN** a review whose gate output exits non-zero
- **WHEN** `team review T1.1 --dir <checkout>` has finished
- **THEN** the record's verdict is `FAIL`, the command exited non-zero, and the board row is not `done`

### Requirement: Closing a task hands the git step back to the PM

`team close <ID> [--status <s>] [--keep-window]` SHALL close the agent's window (unless `--keep-window`), clear the
recorded task for that id, write the requested status through the same closed vocabulary, and, when the worktree is
still on a task branch, MUST print the exact `git switch --detach <protected>` command for the PM instead of
touching git itself.

#### Scenario: Close releases the window and keeps the evidence

- **GIVEN** a dispatched agent window `dev` and `docs/team/reviews/T1.1.md`
- **WHEN** `team close T1.1` runs
- **THEN** the window `dev` is gone, the review record still exists, and the board row is `done`

#### Scenario: The leftover branch is reported, not switched

- **GIVEN** the agent worktree is still on `task/T1.1-*`
- **WHEN** `team close T1.1` runs
- **THEN** the output contains a `git ... switch --detach <protected-branch>` command to run, and the worktree's
  branch is unchanged by the command
