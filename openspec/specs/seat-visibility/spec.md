# seat-visibility Specification

## Purpose
TBD - created by archiving change orphan-visibility. Update Purpose after archive.
## Requirements
### Requirement: A seat process is identified from its own environment and executable

The census SHALL enumerate the host's teamsmith seat processes without asking tmux: a process is a seat process
when its own environment carries teamsmith's seat identity — `TEAM_MAIN_ROOT` (the project it belongs to) and
`TEAM_ROOT` (the worktree it was started in) — and its command line names the project's agent executable
(`team_agent_bin_path`: `TEAM_AGENT_BIN`, else the first word of `TEAM_AGENT_CMD`, else `TEAM_PI_BIN`, else `pi`)
or the PM's (`team_pm_bin_path`). The project a process belongs to SHALL be decided by the process's own
`TEAM_MAIN_ROOT`, never by the calling shell's identity or its working directory, and the seat name SHALL be
derived from that process's `TEAM_ROOT` relative to the project's worktrees directory. The task SHALL come from
that project's committed assignment record for the seat (`state/<seat>.env`) and SHALL be printed as the record's
task, never as a claim about what the process is doing now; the reading SHALL name that source. An entry SHALL
carry the pid, the process's resident memory (`VmRSS`) and its start time (the process's own start tick from
`/proc/<pid>/stat` plus the kernel's boot time), and MUST NOT carry a start time or a memory figure it could not
read.

#### Scenario: The census reads the process's identity, not the caller's

- **GIVEN** a seat process of project A running in a worktree of A, and a shell whose runtime identity is project B
- **WHEN** the census runs from B's checkout
- **THEN** the process is classified as A's seat (from B's point of view, a foreign seat), and B's reading never
  presents it as one of B's own seats

#### Scenario: An unreadable environment is skipped, never guessed

- **GIVEN** a process whose environment cannot be read (permission refused), and a process that vanishes between
  the enumeration and the read
- **WHEN** the census runs
- **THEN** neither is named as any project's seat, the census exits 0, and no error line is attributed to it

#### Scenario: The attributed task names its source

- **GIVEN** a seat whose committed assignment record names task T1.1 while the process was started under task T1.0
- **WHEN** the census reports it
- **THEN** the entry carries T1.1 and the reading names the assignment record as the source of that task

#### Scenario: The start time comes from the process

- **GIVEN** a seat process whose start time is known to the fixture
- **WHEN** the census reports it
- **THEN** the entry's start time is that process's own start time, and a process whose start time cannot be read
  carries no start time instead of a fabricated one

### Requirement: An orphan is a seat process with no live pane, judged on the process's own tmux server

A seat process SHALL be reported as an orphan exactly when it has no live pane: its `TMUX_PANE` is empty, or that
pane id is absent from the pane set of the tmux server the process itself names (`TMUX` carries the socket path and
the server pid, and the census queries that socket). The judgment MUST NOT be "not this window's pane", MUST NOT be
"not this project's window", and MUST NOT compare a pane id against another server's pane set, because pane ids are
unique per server. When that server cannot be queried (its socket is gone, tmux is unavailable, or the query
fails), the census SHALL leave the process unjudged and MUST NOT report it as an orphan, and the reading SHALL
state how many processes were left unjudged.

#### Scenario: A running seat in its own window is not an orphan

- **GIVEN** a seat process running in a window of the tmux server it names
- **WHEN** the census runs
- **THEN** it is not reported as an orphan

#### Scenario: A seat in another session's live window is not an orphan

- **GIVEN** a seat process whose pane lives in another session of the same server, so its window is not the window
  the census runs from
- **WHEN** the census runs
- **THEN** it is not reported as an orphan

#### Scenario: A pane id that exists on another server is not a live pane

- **GIVEN** two tmux servers and a seat process of the first whose `TMUX_PANE` id also exists on the second
- **WHEN** the census runs
- **THEN** the process is reported as an orphan, because the pane set of its own server does not carry that id

#### Scenario: A seat whose window is gone is an orphan

- **GIVEN** a seat process whose window was killed while the process survived, on a server whose other panes are
  still alive
- **WHEN** the census runs
- **THEN** it is reported as an orphan carrying its pid

#### Scenario: An unqueryable server is unjudged, not an orphan

- **GIVEN** a seat process whose named tmux socket no longer exists
- **WHEN** the census runs
- **THEN** it is not reported as an orphan, and the reading states that one process was left unjudged

### Requirement: The reading names this project's orphans and only counts the rest

The reading SHALL name every orphan belonging to the project it runs in — pid, resident memory, seat, the
assignment record's task and the start time — and SHALL print, beside each named orphan, one copy-pasteable
cleanup command. Orphans belonging to another project, and seat-shaped processes whose identity cannot be read,
SHALL be reported only as a count and a total memory figure: no pid, no project name, no seat name and no worktree
path may appear for them, because the reading is designed to be copied into the project's ledger. That total SHALL
be presented as a floor (`≥`), because the executable predicate recognises the configured Pi/agent shape and
cannot recognise a foreign project's adapter. When the project has no orphans the reading SHALL say so in one line
and print no cleanup command.

#### Scenario: This project's orphan is named with its cleanup command

- **GIVEN** one orphan of the project the census runs in
- **WHEN** the reading runs
- **THEN** its pid, resident memory, seat, record task and start time are printed, and the printed cleanup command
  names that pid

#### Scenario: Another project's orphan is counted and never named

- **GIVEN** one orphan whose identity resolves to another project's main root
- **WHEN** the reading runs
- **THEN** it appears only in the count and the memory total marked as a floor, and neither its pid nor its
  project, seat or worktree name appears anywhere in the output

#### Scenario: An identity-empty seat-shaped process is counted and never named

- **GIVEN** a pane-less process whose command line names the agent executable while its environment carries no
  teamsmith identity
- **WHEN** the reading runs
- **THEN** it appears only in the count and the memory total, and its pid is not printed

#### Scenario: No orphans reads as one line and no command

- **GIVEN** a host whose seat processes all have live panes and whose project has no orphans
- **WHEN** the reading runs
- **THEN** it prints exactly one line saying so and no cleanup command

### Requirement: The reading is additive, bounded and read-only

`team ps` and `team status` SHALL print the reading, and `team up` SHALL print one line of it after its launch
decision; none of them SHALL signal a process. Every pre-existing line of `team ps` — its capacity line, its
liveness block, its model table, its session block and its window list — SHALL stay byte-identical to its
pre-change text, and the reading SHALL be additional lines. The census SHALL be read-only (no signal, no file
written) and bounded in time; a `/proc` entry that cannot be read or that vanishes mid-scan SHALL be skipped,
never raised as a failure of the calling command, and a read command's exit code SHALL NOT change because the
census found orphans or could not judge a process. With `TEAM_ORPHAN_SCAN=0` the census SHALL read no process's
environment and the reading SHALL be one named skip line. The census MUST NOT be part of the panel's data path:
`team __panel-data` and the panel's output SHALL be unchanged.

#### Scenario: The census is additive on `team ps`

- **GIVEN** one `team ps` run with the census enabled and one with `TEAM_ORPHAN_SCAN=0`
- **WHEN** both outputs are compared line by line
- **THEN** every pre-existing line (capacity, liveness, model table, sessions, windows) is byte-identical between
  the two runs and only the reading lines differ

#### Scenario: A read command never fails because of the census

- **GIVEN** a host where one candidate process cannot be read and another cannot be judged because its server is
  gone
- **WHEN** `team ps`, `team status` and `team up` run
- **THEN** each exits with its normal code and prints the reading with the unjudged count, and no error line is
  attributed to the census

#### Scenario: The panel data path is unchanged

- **GIVEN** a checkout whose `team __panel-data --no-activity` output was captured before the change
- **WHEN** the same command runs after it, with the census enabled and with `TEAM_ORPHAN_SCAN=0`
- **THEN** the outputs are identical apart from their existing live fields (timestamp, capacity)

#### Scenario: The scan can be turned off

- **WHEN** `TEAM_ORPHAN_SCAN=0 team ps` runs
- **THEN** the reading is one line naming the disabled scan and no orphan pid appears

### Requirement: The digest warns on its capacity line above a threshold, without changing its exit code

When the host-wide orphan total — this project's orphans plus the counted buckets — is at or above
`TEAM_ORPHAN_WARN_MB`, `team digest`'s capacity line SHALL carry one additional hint naming the total, this
project's share and the copy-pasteable cleanup command. Below the threshold the capacity line SHALL be unchanged
and the hint SHALL print nothing. The hint SHALL NOT use the error style, SHALL NOT be printed as a separate line,
and SHALL NOT change the command's exit code.

#### Scenario: Below the threshold the digest is unchanged

- **GIVEN** a host whose orphan total is below `TEAM_ORPHAN_WARN_MB`
- **WHEN** `team digest` runs
- **THEN** its capacity line carries no hint and the command exits 0

#### Scenario: At or above the threshold one hint and the same exit code

- **GIVEN** a host whose orphan total is at or above `TEAM_ORPHAN_WARN_MB`
- **WHEN** `team digest` runs with the census enabled, and again with `TEAM_ORPHAN_SCAN=0`
- **THEN** the first capacity line carries the total, this project's share and the cleanup command, the second
  carries none, and both runs exit 0

