## MODIFIED Requirements

### Requirement: Reply storage paths and declared identity are untrusted data

Storage SHALL use only this project's resolved state directory and validated flat internal record names. Readers and publishers MUST reject symlink/nonregular index, lock or body artifacts, path traversal, foreign-root substitution and unsafe directory ancestry instead of following them. No read API SHALL accept an arbitrary file path. Publisher labels SHALL be displayed exactly as the record carries them — the label itself, with no qualifier about whether it was verified — and that display rule is the same for the panel and for the human output of `team reply list` / `team reply show`, while every machine output (`--json`, the raw store read) keeps the label byte for byte and the record keeps the label the publisher wrote. Displaying the label as recorded MUST NOT be read as a verification: the tool authenticates nothing, the label is what the caller wrote, and no output may claim a check that did not happen (the sentences that say so belong in the documentation and in this requirement, not as a suffix on the label). Markdown links/images and embedded commands MUST remain inert text; display MUST NOT fetch content, read local linked files, send terminal hyperlinks or execute shell syntax. Safe displays SHALL sanitize every external string, including corruption diagnostics.

#### Scenario: Traversal and nonregular sources are refused
- **WHEN** a selector contains traversal or the store/index/body is replaced by a symlink, FIFO, directory or foreign path
- **THEN** the operation rejects without reading the target or blocking on the FIFO
- **AND** outside-root files and processes remain untouched

#### Scenario: Declared label and hostile markdown remain data
- **WHEN** a reply claims another seat's label and contains shell syntax, local links, remote images and terminal controls
- **THEN** the label is displayed as the record carries it (the label alone, no qualifier beside it) and the body is only safely rendered
- **AND** no shell, network fetch, local-link reader or delivery operation runs

#### Scenario: The recorded label is what the reader sees
- **GIVEN** a reply posted with `--from pm` and a body the publisher wrote
- **WHEN** the panel shows its latest summary, a list row and the open body, and `team reply list` / `team reply show <no>` run
- **THEN** every human output names the label `pm` exactly as the record carries it and adds no qualifier about verification, and the machine outputs still carry `from` with the same bytes
- **AND** a scratch copy of the display that renders a qualifier beside the label makes the display fixture red, while the store, the readers and the refusal rules are untouched by that flip
