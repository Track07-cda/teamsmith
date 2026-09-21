# verification delta · 2026-09 回填：the conflict-marker guard (M44)

## ADDED Requirements

### Requirement: The gate refuses tracked files that still hold conflict markers

The gate SHALL search the tree under test for conflict-marker lines — `<<<<<<<` with or without a label,
`=======` (seven or more `=`), and `>>>>>>>` — at the start of a line, in every **tracked** file, in the working
tree **and** in the index, and it MUST turn red when it finds any, naming each hit as `<file>:<line>`. It MUST look
only at tracked line-oriented text: an untracked file, a copy under another worktree (`.worktrees/**`) or a binary
file containing a NUL byte MUST NOT produce a hit, so a documentation example or a third party's worktree cannot
fail the gate. A tree without markers MUST stay green.

#### Scenario: A committed or uncommitted marker block is found

- **GIVEN** a fixture repository whose tracked file carries a `<<<<<<<` / `=======` / `>>>>>>>` block (the shape a
  `git merge --squash` leaves behind when a commit is made without resolving it)
- **WHEN** the gate's marker check runs
- **THEN** it reports red and prints `tracked.txt:2` (the file and the line of the first marker); the same check on
  a clean checkout reports green instead of printing anything

#### Scenario: A staged marker block that the working tree no longer shows is found

- **GIVEN** a file whose marker block was `git add`-ed and whose working tree copy was then rewritten clean
- **WHEN** the gate's marker check runs
- **THEN** it reports red and names that `file:line`, because the next commit would still carry the marker

#### Scenario: Untracked, worktree and binary files are out of scope

- **GIVEN** marker text in an untracked file, in a force-tracked file under `.worktrees/other/`, and after a NUL
  byte in a tracked binary file
- **WHEN** the gate's marker check runs
- **THEN** all three produce no hit and the check stays green
