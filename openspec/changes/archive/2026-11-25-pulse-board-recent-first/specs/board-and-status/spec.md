## MODIFIED Requirements

### Requirement: A duplicate board id is refused by default and visible wherever the board is read

`team board add <ID> <title> …` MUST refuse an id that already names a row: it exits non-zero, names the existing
row's status and title, and names the two ways forward — a different id, or the explicit `--allow-dup` flag — plus
`board assign` as the entry for fixing an existing row's agent. A refused add MUST write nothing: the board file
MUST be byte-identical afterwards. With `--allow-dup` the row SHALL be appended and one audit line naming the id
and the flag SHALL be appended to `state/watchdog.log`.

The existing task table MAY have one dedicated rightmost column named `Teamsmith Updated UTC` (exact
match after trimming the header cell, regardless of locale). Its value uses UTC to whole seconds,
`YYYY-MM-DDTHH:MM:SSZ`, with a valid calendar date and time. Only a row in the identifiable task table
can supply this value. The existing insertion SHALL record it for a new row, including an explicitly
permitted duplicate and a new row created by `team task`, only if the original writer's actual insertion
point and business cells align with that task table. That write may also append the header and separator
cell in the same replacement without rewriting existing rows, reinterpreting undeclared cells, or altering
another table. If the layout is ambiguous or the original write does not align, the original business write
SHALL keep its destination and column positions without recording a time. Time recognition MUST NOT change
the existing duplicate decision, business-field addressing or diagnostics. Missing, blank or invalid cells,
a non-rightmost or non-unique reserved header, dates in other columns or tables, file timestamps, and inferred
history MUST NOT supply a task time. Manual edits do not trigger recording.

Wherever the board is read, a duplicate MUST be visible: `team board ls`, `team digest` and `team doctor` SHALL
name the duplicated id with its row count (`×N`), and `doctor` SHALL keep checking for duplicates (reporting none)
on a board without them. The `init` template's placeholder rows and the risk table are not task rows and MUST NOT
be counted as duplicates.

#### Scenario: The refusal names the existing row and writes nothing

- **GIVEN** a board row `| T1.1 | Smoke task | dev | - | - | todo |`
- **WHEN** `team board add T1.1 "重复的一条" dev -` runs
- **THEN** it exits non-zero, prints the existing status `todo`, its title, `--allow-dup` and `board assign`, and
  the board file's checksum and its number of `T1.1` rows are unchanged

#### Scenario: The explicit flag writes a second row and an audit line

- **GIVEN** the same legacy task table with no dedicated time column
- **WHEN** the same command runs with `--allow-dup`
- **THEN** the board holds two `T1.1` rows, the new task row has the insertion time in the dedicated
  column without assigning a time to the old row, and `state/watchdog.log` gained a line naming
  `T1.1` and `allow-dup`

#### Scenario: All three readers surface the duplicate, and only while it exists

- **GIVEN** a board holding two `T1.1` rows
- **WHEN** `team board ls`, `team digest` and `team doctor` run, and then the duplicate row is removed and they run
  again
- **THEN** the first three outputs name `T1.1 ×2` (doctor in its `BOARD 重复 ID` check), and the second three no
  longer report a duplicate while `doctor` still reports having checked it

#### Scenario: A freshly initialised board is not a duplicate report

- **WHEN** a project is initialised and `team board ls` runs on the empty board
- **THEN** no duplicate line appears (the template's placeholders and the risk table are not task rows)

### Requirement: The board addresses rows by id, and the agent column has its own entry

`team board assign <ID> <agent>` SHALL set only the agent and the applicable update time of each existing
matching row, keep the row count and order and every other column unchanged, and MUST refuse an id that names
no row or a missing agent without writing. `team board set <ID> <status>` keeps addressing by id: every row
carrying that id takes the new status — historical duplicates included — so the two commands agree on what an
id addresses. Any change of status made through the existing board writer, including dispatch's move to `wip`
and close's status write, follows the same rule as `board set`.

For an identifiable task row whose business cell aligns with the original writer's actual destination, the
writer SHALL compare the old cell and the value the original writer would place in that cell, trimming both.
Only a real change records the current time in the same replacement as the business value, including the
header and separator cells when first needed; if only the time cell is absent, it is added only to the row
actually changed. Rows with the same id are compared independently. An unaligned write keeps the original
business write without adding time; a matching row outside the task table does not gain or lend a time.
A repeated effective value does not add the column or change a time and is not a new refusal; a refused
operation or one that merely writes a brief, report, audit or associated data MUST NOT change the row time.

The two existing board write paths, insertion and field change, SHALL serialize the read–modify–replace
of a shared board within the project's writer lock scope, reading the current board under the lock. On
lock or write failure the board writer SHALL return failure and MUST NOT record a successful write audit.
Successful writes SHALL invalidate the original caller's board cache. The existing status checks, success
audits, and dispatch and close handling of the board writer's result remain in place. The lock does not
cover external editors, old writers that do not take it, or writers using a different lock directory.

#### Scenario: Assigning changes the agent column and nothing else

- **GIVEN** an identifiable task table with two `T1.1` rows, one already assigned to `reviewer`, and a
  separate table carrying the same id and its own date column
- **WHEN** `team board assign T1.1 reviewer` runs, and succeeds again later with the same arguments
- **THEN** both task rows carry `reviewer`, but only the task row whose agent changed gets the new time, the
  second operation leaves both times alone, and no time is recorded in or taken from the separate table
- **AND** the row count, row order and every column other than the agent and the dedicated time remain
  byte-identical

#### Scenario: An unknown id or a missing argument writes nothing

- **WHEN** `team board assign NOSUCH dev` and `team board assign T1.1` run
- **THEN** both exit non-zero naming the unknown id (or the missing argument) and the board file is unchanged

#### Scenario: Set still addresses every row with the id

- **GIVEN** the same two-row board
- **WHEN** `team board set T1.1 blocked` runs
- **THEN** both `T1.1` rows report `blocked`, and only those whose status changed record the operation time
