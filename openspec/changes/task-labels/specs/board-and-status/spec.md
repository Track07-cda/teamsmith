## ADDED Requirements

### Requirement: Project labels are managed by name beside the board

`team board label` SHALL manage definitions by name, with name, RGB color and integer weight (zero by default). Definitions and associations MUST live in one `task-labels.tsv` beside the configured project's board, replaced as one change. Reads, unsuccessful pre-publication operations and no-ops MUST NOT create or rewrite it. A missing file is an empty catalog; a broken file is not.

#### Scenario: A project starts with no labels and defines its first by name

- **GIVEN** an existing board project with no label file and a normally writable ledger
- **WHEN** `team board label ls` and `team board ls --sort priority` run, then `team board label define '用户反馈' --color '#0969da'` runs
- **THEN** the initial reads list no definitions and create no file; the write creates only `task-labels.tsv`; `label ls` lists the new name, RGB color and zero weight; board and configuration bytes do not change

#### Scenario: Names are literal and a signed weight is allowed

- **WHEN** two names differing only in case, or names with internal spaces or non-ASCII text, are defined using `team board label define <name> --color <#RRGGBB> [--weight <n>]`, one with a negative decimal weight
- **THEN** `label ls` shows the exact distinct names and supplied weights, and `--label` uses the full exact name, not its case-folded, split or shortened form; no predefined name or weight level is present

#### Scenario: Invalid definitions and rename collisions do not replace the catalog

- **GIVEN** a ledger with a 664 label file in a 775 directory, containing two distinct names
- **WHEN** `team board label edit <name> --color '#1a7f37'` runs, then a duplicate `define`, a rename to the other name, a blank name or a name with surrounding whitespace, tabs, line breaks or characters removed by the panel's terminal sanitization (for example `Bug` with U+200B between `B` and `u`), a color not in `#RRGGBB` form and a non-integer decimal weight are tried individually
- **THEN** the color edit succeeds without changing associations; each rejected command exits nonzero naming the problem and its before/after file bytes are identical

#### Scenario: Rename moves associations and deletion requires explicit detach

- **GIVEN** a label applied to a task with two board rows and to an ID whose last row was removed by hand
- **WHEN** `team board label edit <name> --name <new>` renames the label, `team board label delete <new>` is attempted, both IDs are detached by the new name and deletion is tried again
- **THEN** both board rows list only the new name after the rename, with their previous score; the first deletion fails naming each of the two IDs once and writes nothing; detaching the absent ID is possible and the final deletion succeeds without editing the board

#### Scenario: A second writer or an interrupted write cannot lose the catalog

- **GIVEN** an existing valid catalog and two commands writing unrelated names
- **WHEN** they overlap, and on a separate attempt writing the replacement fails before publication
- **THEN** readers see only complete catalogs, successful writes are not lost and any refused writer reports its failure; the pre-publication failure leaves exactly the previously published bytes

#### Scenario: A failure after replacement is not claimed as a rollback

- **WHEN** replacement succeeds but persistence cannot be confirmed
- **THEN** the writer reports a nonzero result, says which new file may already be visible and does not claim success or that the old bytes were restored

### Requirement: Board tasks share labels by id and priority is the distinct weight sum

`team board label add|remove <ID> <name>...` SHALL edit the set of defined labels attached to one task ID as one operation, regardless of whether a brief exists. Task-table rows sharing an ID SHALL share labels and score, but stay separate. Priority MUST be the exact sum of the distinct labels' weights, zero if none; color has no effect. Explicit CLI and Pulse views SHALL use the same score. No operation changes task status, dependencies, dispatch, patrol or remote records.

#### Scenario: Two labels add up without counting an attachment twice

- **GIVEN** board task `T2` with no task brief and project labels `Bug` at 3 and `Urgent` at 5
- **WHEN** both labels are attached in one command and `Bug` is attached again
- **THEN** updated listing and task detail show each name once and score 8, and the last attachment does not rewrite the file
- **AND** editing `Bug` with `--weight 6` gives both readers 11 without changing any association or board row
- **AND** removing an already detached, defined name for a real task is also a successful no-op

#### Scenario: Historical or explicitly duplicated IDs are not new identities

- **GIVEN** a task with labels whose last board row was removed by hand
- **WHEN** both views are read, then that ID is reused and an explicit duplicate row is appended
- **THEN** the initial views show no phantom row; afterwards there are two separate rows with the original labels and score
- **AND** if the rows are removed again, `label remove` can still detach saved associations, but adding to an absent ID or removing from one with no saved associations is refused

#### Scenario: Only real tasks and wholly valid batches can be labeled

- **GIVEN** a board whose task columns use recognized English headings in changed order, a placeholder and a separate risk table, plus an existing definition `Bug`
- **WHEN** `Bug` is added to a real row without a task brief, then a missing ID, a risk row, the placeholder and a batch containing an undefined name are tried
- **THEN** only the first operation writes, names resolve by the actual task columns, every refusal exits nonzero with its cause, and the board and the last valid label bytes remain unchanged after each refusal

### Requirement: Filtering and sorting a board list are explicit read-only views

`team board` and `team board ls` with no options SHALL retain their Markdown, order, warnings and exit behavior without reading labels. `team board ls --label <name>` SHALL match the exact label name; `--sort priority` SHALL order task rows across states by descending score and then file order. These options can combine. Opted-in lists MUST show ID, state, title, score and label names, preserve the duplicate-ID warning and write nothing.

#### Scenario: The old inspection and writing paths do not depend on labels

- **GIVEN** a board with an extra `Issue` column, a placeholder, a separate risk table and a historical duplicate ID, and the pre-label outputs for plain `board ls` and `board row`
- **WHEN** the same reads run with no label file, then with a label file that is invalid, and the ordinary task, status and assignment writes run on the old supported layout
- **THEN** the reads still produce their prior rows and warnings; the added row follows the existing column count, each edit changes only its owning column, and none of the commands writes the label file

#### Scenario: Files provide the tie-break, not id or selected label order

- **GIVEN** file order `T9:Bug(3), T8:Security(8), T5:Docs(0), T2:Bug+Urgent(8), T1:unlabeled(0), T6:Urgent(5)`
- **WHEN** the list runs by priority, then with just `--label Bug`, then with both options, and finally priority alone after raising `Bug` to 6
- **THEN** the respective ID sequences are `T8 T2 T6 T9 T5 T1`, `T9 T2`, `T2 T9`, and `T2 T8 T9 T6 T5 T1`; the first list explicitly prints score 8 for `T2`, and the Markdown row sequence is unchanged throughout

#### Scenario: A separate table with the same ID cannot match a task label

- **GIVEN** two real task-table rows sharing ID `T2` and its `Bug` label, and a later table with a distinct-titled `T2` in the same column position and a valid `todo` state
- **WHEN** plain `team board ls` and `team board ls --label Bug` run
- **THEN** the plain inspection still shows the unrelated row, while the filtered listing shows both real rows with their shared label and score and does not show the unrelated title

#### Scenario: No matches and broken input are distinct

- **GIVEN** a defined but unused name, an unknown name, and a second project with malformed or unreadable label records
- **WHEN** those inputs are used in explicit label listing or filtering, and `board ls --sort title` is tried
- **THEN** the unused filter succeeds with no matching rows; the unknown name, label read failure or invalid sort each return nonzero naming the cause; no invocation changes any file
