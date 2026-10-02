## ADDED Requirements

### Requirement: Specs are the contract

`openspec/specs/**` ships in the public tree; the maintainers' ledger (`docs/team/**`: briefs, reports, reviews,
decisions — the evidence behind a rationale) does not. A spec SHALL therefore stand on its own: a claim's evidence
SHALL be stated in its text — the conclusion and the numbers it quotes — and MUST NOT be delegated to a record the
reader cannot open. A `docs/team/…` reference in a spec SHALL name a **declared reference**, and every declared
reference SHALL be a row of `skills/teamsmith/tests/spec-ledger-refs.tsv` carrying its kind and its basis. Every
non-comment row of the table SHALL carry exactly its three columns — a `pattern`, a `kind` from the closed set
`slot | ledger | example`, and a non-empty `basis` — and a row that lacks any of them MUST be refused when the
table is read, naming the table, the row's line number and the row's text. A `ledger` or `example` row SHALL hold
a **literal** reference; a row of either kind whose pattern carries `<…>` or `*` MUST be refused the same way,
naming the pattern — those shapes belong to `slot` rows alone. A **slot-shaped** reference (one that carries `<…>`
or `*`) SHALL match a `slot` row — the slots the skill defines in a project's ledger
(`docs/team/tasks/<ID>-<slug>.md`, `docs/team/reports/<ID>-<agent>.md`, `docs/team/inbox/<agent>.md`, …); a
**concrete** reference SHALL equal an exact `ledger`/`example` row character for character — one of the ledger's
own fixed files, or an example record a fixture owns — never merely resemble one. A slot row MUST NOT allow a
concrete reference: a concrete report reference is undeclared even though the slot pattern
`docs/team/reports/<ID>-*.md` matches its shape. The
maintainers' record ids MAY stay in the text — a reason may name the verification pass a ruling came from, and a
scenario must be able to quote what its fixture prints — but the specs' text SHALL carry one line beginning
`Id families:` and a family that line does not name MUST NOT appear in `openspec/specs/**`:

Id families: `P<n>` a task brief, `M<n>` a milestone, `D<n>` a decision record, `V<n>` a verification pass and
`V<n>-<letter><m>` one of its findings, `E<n>` an exploration report, `F<n>` a finding — the records they name live
outside the distributed tree and are not needed to re-run any scenario.

The project gate SHALL judge the contract's text as the archive will write it: the base spec for a capability no
pending change touches and, for a requirement a pending change adds, modifies or removes, that change's own block.
It SHALL read the pending changes in dependency order rather than directory order: when a pending change's
`MODIFIED` or `REMOVED` block names a requirement the base spec does not have and another pending change's `ADDED`
block supplies it, the walk SHALL take that block as the baseline, SHALL name the supplying change and the archive
order that implies, and MUST NOT fail; a block whose title neither the base nor any pending change supplies MUST
fail, naming its file and the title. A reference the pending changes retire MUST be reported once with the file,
the line and the retiring change and
MUST NOT fail the run; a reference no pending change retires MUST fail it, naming the file, the line and the path.
The walk SHALL need no window, process or network — it reads text, so it runs in the fast gate as well.

#### Scenario: The walk passes here, and reddens on a citation nothing retires

- **WHEN** `bash skills/teamsmith/tests/spec-refs.sh --check` runs on this tree
- **THEN** it exits 0, reports every reference the pending changes retire with its file, its line and the retiring
  change's id, names no undeclared reference, and prints how many references it judged
- **AND** with `--root` pointed at a copy of the tree whose `openspec/changes/` holds no change directory, the same
  command exits non-zero and names `openspec/specs/verification/spec.md`, the line the reference sits on and the
  cited path it refused
- **AND** `bash skills/teamsmith/tests/spec-refs.sh --flips` reports one `red` line for a concrete report path
  planted in a copy — the shape a slot pattern would otherwise swallow — so the walk cannot pass a citation by
  matching it against `docs/team/reports/<ID>-*.md`

#### Scenario: A record-id family without its key is red

- **GIVEN** a copy of the tree whose spec text uses `V9-B5` and `F2` under the `Id families:` line
- **WHEN** `bash skills/teamsmith/tests/spec-refs.sh --check` runs on the copy with that line deleted, and again on
  a copy whose line names `V<n>` but not `F<n>`
- **THEN** each run exits non-zero and names the file and the unnamed family, while the untouched copy exits 0
- **AND** `bash skills/teamsmith/tests/spec-refs.sh --flips` prints one `red` line per mutation that must be caught
  and one `clean` line per mutation that must stay green, and exits 0 only when every mutation behaved as required

#### Scenario: A row that cannot mean what it says is refused, not skipped

- **GIVEN** a copy of `skills/teamsmith/tests/spec-ledger-refs.tsv` carrying, one at a time, a `ledger` row whose
  pattern holds a `*`, an `example` row whose pattern holds a `<…>`, a row with a column missing, a row with a
  column too many, a row whose `basis` is empty, and a row whose `kind` is outside `slot | ledger | example`
- **WHEN** `bash skills/teamsmith/tests/spec-refs.sh --check --table <copy>` runs on each copy
- **THEN** every run exits non-zero and names the table, the offending line's number and its text, so no such row
  can be dropped in silence
- **AND** the same command with the table untouched exits 0, still declares the `slot` rows whose patterns carry
  `<…>`, still declares a concrete reference that equals a `ledger` row character for character, and still refuses
  a concrete report path that only resembles the slot pattern

#### Scenario: A requirement another pending change supplies and one nothing supplies

- **GIVEN** a tree where change `zz-provider`'s `ADDED` block introduces a requirement and change `zz-consumer`'s
  `MODIFIED` block rewrites it, and the same tree with `zz-provider`'s change directory removed
- **WHEN** `bash skills/teamsmith/tests/spec-refs.sh --check` runs on each
- **THEN** the first exits 0 and names `zz-provider` as the provider of that baseline and the order that implies,
  while the second exits non-zero and names `zz-consumer`'s file and the title it could not resolve
