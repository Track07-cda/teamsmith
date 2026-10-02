## ADDED Requirements

### Requirement: A gate that cannot judge says so

The correctness gate SHALL distinguish a product-only checkout, which deliberately contains the published product and `openspec/specs/` but none of this development repository's internal surfaces (`docs/team/`, `openspec/changes/`, `AGENTS.md`, `SCOPE.md`, `.pi/prompts/`, `.pi/skills/`), from an internal or partially populated checkout. Classification MUST inspect the checkout under test before creating fixture data; inherited project identity, CI environment, and a fixture-created ledger MUST NOT decide it. An empty, unreadable, malformed or partially populated internal surface MUST NOT be treated as absent. No production environment override SHALL turn a missing product or internal-checkout file into a prerequisite skip.

Only a check whose named prerequisite is one of those deliberately absent internal surfaces SHALL skip on a product-only checkout. Each such attribution MUST print `SKIP（条件不满足）`, the affected check and missing prerequisite, be counted as a skip rather than a pass, and reach the gate's output and per-section/run accounting. Missing product files, unavailable required tools, a failed executed assertion, and corruption of a present internal surface MUST retain their existing failure/degradation rules; the checkout classification MUST NOT swallow them. An executed check's verdict MUST rest on evidence the subject itself carries: when the call's command word is the wrapped command itself (`tmux`), an isolation wrapper defined in one file MUST NOT certify a mutation call made by another file, while a dedicated wrapper name defined alongside the caller MAY keep its directory-level meaning; a check MUST NOT be reported as satisfied on evidence the subject does not have. A run with prerequisite skips and no failures SHALL exit 0, without claiming the skipped checks passed; a real failure alongside skips MUST still exit non-zero.

The same correctness command SHALL run on both shapes, with no second public suite. The product's static checks, skill loading, published-spec validation, container-build checks and every ledger-independent fixture MUST remain eligible exactly as before (including the existing FAST/full and tool-premise rules). A fixture that provisions its own ledger MUST still run in the product-only checkout. For an internal checkout, every pre-existing assertion MUST still execute with its original verdict and at least its pre-change per-section pass count under identical run settings; replacing an existing assertion with a new one MUST NOT satisfy that coverage comparison. CI's correctness step MUST retain its command and blocking failure semantics.

#### Scenario: The release export skips only unavailable internal checks

- **GIVEN** a clean product-only tree exported from committed HEAD by `bash docs/team/tools/publish-public.sh`, with the gate's required tools available
- **WHEN** `openspec validate --all --strict && TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null` runs there
- **THEN** it exits 0 with no failing assertions, missing internal prerequisites are named on counted `SKIP（条件不满足）` lines, and all FAST-eligible product sections execute
- **AND** the section counts sum to the run totals and no skipped prerequisite is counted as a pass

#### Scenario: A public checkout still exercises the product checks and their negative controls

- **GIVEN** the same exported tree, then independent scratch copies with a missing product literal `skills/teamsmith/tests/skill-load.mjs` and with CJK prose injected into `skills/teamsmith/references/protocol.md`
- **WHEN** the first copy runs `bash skills/teamsmith/tests/section-select.sh --check` and the second runs the gate's English-prose check
- **THEN** both fail and name the damaged product path, despite their other internal prerequisites being skipped
- **AND** the unmodified export executes skill loading, reference scanning, installer tests, five-phase product-document contract checks and their sandbox negative controls, rather than skipping §18, §19 or §36 wholesale

#### Scenario: A sibling file's wrapper does not certify a planted product mutation

- **GIVEN** a product-only scratch tree (whose sibling fixture `smoke.sh` defines the same-named `tmux()` wrapper) with a bare `tmux kill-server` appended to a product file (`skills/teamsmith/tests/tmp-hygiene.sh`), a second copy of that tree whose lint has the same-directory rule restored, and a third copy where the same call is instead exempted through the lint's own frozen-hash exemption list
- **WHEN** §31's tmux-isolation lint runs in each tree (the internal-only exemption list attributed as a prerequisite skip in the first)
- **THEN** the first tree is red and names the planted file — a wrapper defined in another file is not evidence of isolation for that call — and the second and third trees are green, so the red judgment is demonstrably attached to §31's lint verdict and to the attribution rule itself rather than to an unrelated failure
- **AND** the unmodified product-only tree keeps the lint's green verdict, so the product check is not made red unconditionally

#### Scenario: The signal lint's frozen ledger is an internal prerequisite, not a product one

- **GIVEN** a product-only scratch tree whose P159 signal lint carries its frozen exemption ledger for `docs/team/reports/**`, a copy whose ledger also names an absent product file (`skills/teamsmith/scripts/p176-no-such-product-file.sh`), and a third copy whose per-entry attribution is relaxed so that any absent ledger entry is skipped
- **WHEN** §58's signal-discipline lint runs in each tree (the internal-only ledger attributed as a prerequisite skip in the first)
- **THEN** the first tree exits 0 with the ledger's absence printed as a counted `SKIP（条件不满足）` naming `docs/team/reports/**` while the lint's own verdict still executes, the second is red and names the missing product path, and the third is green — the skip is attributed to the internal surface, not to absence as such
- **AND** a name-selected signal call planted in a product file still makes the same check red in the product-only tree, so attributing the ledger as a prerequisite does not disarm the lint

#### Scenario: The internal checkout loses no existing coverage

- **GIVEN** pre-change and post-change independent internal checkouts with identical tools and FAST settings
- **WHEN** `TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null` runs in each
- **THEN** every pre-existing assertion is present in the post-change executed assertion inventory, each pre-existing section's pass count is at least its baseline, and no new checkout-prerequisite skip appears
- **AND** a scratch mutation that replaces an existing internal assertion with a prerequisite skip fails the inventory/count comparison, even if new assertions keep the aggregate pass total unchanged

#### Scenario: Partial internal trees and broken installs remain red

- **GIVEN** scratch internal trees with, respectively, `SCOPE.md` removed, one `opsx-apply.md` removed, one phase `SKILL.md` removed, or the archive directory removed while other internal surfaces remain
- **WHEN** their relevant smoke assertions and `section-select.sh --check` run
- **THEN** each damaged tree exits non-zero and names the missing path, not a product-checkout skip
- **AND** creating an empty internal directory in an otherwise product-only scratch checkout cannot turn its missing required files into successful assertions or absence-based skips

#### Scenario: A synthetic ledger does not change the subject's classification

- **GIVEN** a product-only checkout invoked with inherited `TEAM_ROOT`/`TEAM_MAIN_ROOT` pointing at an internal checkout
- **WHEN** its smoke gate runs and `team init` creates ledger and OpenSpec data in the gate's private fixture repository
- **THEN** the source checkout still gets the same prerequisite skips as without those inherited variables, while the fixture's ledger-dependent CLI assertions actually execute

#### Scenario: A real failure is not hidden by prerequisite skips

- **GIVEN** an exported scratch checkout with a failing product assertion and deliberately absent internal prerequisites
- **WHEN** the correctness gate runs
- **THEN** its summary carries both failure and skip counts, the failure names its assertion, and the gate exits non-zero

#### Scenario: Missing tooling is not attributed to the checkout shape

- **GIVEN** a product-only scratch checkout with `perl` unavailable
- **WHEN** its English-prose check runs
- **THEN** it retains the existing missing-perl failure and does not relabel it an internal-file prerequisite skip

#### Scenario: The public workflow remains a blocking correctness check

- **WHEN** `.github/workflows/gates.yml` is read and its correctness container command is run on an independent product-only checkout
- **THEN** the command remains `openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh --keep </dev/null`, without FAST or correctness `continue-on-error`, and succeeds when all applicable checks succeed
- **AND** a failing applicable product assertion makes that same command fail; performance remains a separate non-blocking conclusion

## MODIFIED Requirements

### Requirement: A changed-path list selects the sections to run, or the full suite

`skills/teamsmith/tests/section-paths.tsv` SHALL be the one place a path→section claim lives, with comment
header lines documenting the exempt path class, the prologue keys and the matcher's semantics, and one row
per section carrying the section's key, its id as the sources spell it, the repo-relative patterns it
covers, the keys of the sections that must run before it, and the basis of the claim. `bash
skills/teamsmith/tests/section-select.sh --paths <path>…` SHALL answer with `decision=FULL|NONE|RUN` and
exit 0 without running the suite and without calling git (the caller supplies the paths, for example from
`git diff --name-only <base>...HEAD`):

- **`NONE`** — every given path is in the declared exempt class (`docs/**`, the team ledger) and no row
  claims it: no gate section needs to run, and the output says so.
- **`RUN`** — every given path is claimed: the answer lists the keys whose patterns match, always including
  the prologue keys and the transitive closure of the rows' `needs` keys, and names the paths behind each
  key.
- **`FULL`** — at least one given path is claimed by no row and is not exempt: the answer names those paths
  and prescribes the full suite (running more is always safe; running too little is not).

With `--check` the selector SHALL verify its own basis in pure logic: every section in the gate's sources
has exactly one row and every row's key resolves to exactly one section; a literal pattern (one without a
wildcard) exists in the tree, except for a specifically attributed absent internal prerequisite in a product-only
checkout under `verification#A gate that cannot judge says so`; the exempt class is claimed by no row; every `needs` key exists and
refers to a section that appears earlier in the sources; and a real-tree path token named inside a section's
own text (under the documented normalizer for the suite's path variables) is covered by that row's
patterns — a section that reads a path it does not declare is red and names the token and its line. An
unknown key, a path outside the repository, or a malformed row SHALL exit non-zero with the reason and run
nothing.

A skipped internal literal's existence check MUST print `SKIP（条件不满足）` with its row key and exact path,
and the selector's summary MUST count it separately from `ok` and `bad`. A `--check` with only such skips and
no failed integrity check SHALL exit 0; any missing product literal, unknown or misspelled internal path,
corrupt mapping, or missing internal literal in an internal/partial checkout MUST still fail. The exception MUST
NOT remove mapping rows, narrow their patterns, exempt product paths, skip token coverage or alter
`FULL|NONE|RUN`, the needs closure, coupling, or copy syntax checks. Embedded invocations in smoke MUST relay
the skip attributions and account for them rather than converting their exit 0 into evidence that the missing
files were checked successfully.

`bash skills/teamsmith/tests/smoke.sh --paths <path>…` and `bash skills/teamsmith/tests/smoke.sh --select
<key>[,<key>…]` SHALL run the selection: the prologue, the selected sections and their `needs` closure, in
source order, with the unselected sections not executed; an unknown key exits non-zero and runs nothing. A
run without either flag SHALL behave exactly as before (every section runs) — the full suite stays the
default and the delivery/review/archive gate, and a selection is a batch filter that never changes what a
selected section asserts. Checkout-prerequisite attributions obey the same rules in selected and full runs;
the selected-run disclosure and result-token rules remain unchanged.

#### Scenario: A docs-only diff needs no section, and a run that selects says so

- **WHEN** `bash skills/teamsmith/tests/section-select.sh --paths docs/team/BOARD.md
  docs/team/reports/P97-dev3.md` runs, and then `bash skills/teamsmith/tests/smoke.sh --paths
  docs/team/BOARD.md` runs
- **THEN** the selector prints `decision=NONE` and states that no section needs to run, and the suite run
  prints that no section was affected, starts no section (no `== <id> ==` header appears), prints no result
  line, prints no `smoke 全绿`, and exits 0

#### Scenario: A product path selects the sections that cover it, and their prerequisites

- **WHEN** `bash skills/teamsmith/tests/section-select.sh --paths skills/teamsmith/scripts/lib/outbox.sh`
  runs, and the resulting selection is run with `--select`
- **THEN** the decision is `RUN`, the listed keys include every key whose row declares that path (the data
  file is the authority) plus the prologue and the closure of their `needs` keys, and the selected run's
  output contains their section headers and none of the unselected sections'

#### Scenario: A section's prerequisites run with it instead of being assumed

- **GIVEN** the selector's data declares that section `17` needs `15b` (the gate's own comment says `17`
  reuses the fake settings/spec tree `15b` builds)
- **WHEN** `bash skills/teamsmith/tests/smoke.sh --select 17` runs
- **THEN** the output carries `15b`'s header before `17`'s, and `17`'s closing line reports the same counts
  as in a full run of the same tree (a selection must not turn its assertions into a vacuous pass)

#### Scenario: A path no row claims falls back to the full suite

- **WHEN** `bash skills/teamsmith/tests/section-select.sh --paths ci/some-new-thing` runs
- **THEN** the decision is `FULL`, the output names that path as unclaimed, and the run it prescribes is the
  full suite — the fallback cannot be reached by claiming too little

#### Scenario: A weakened or incomplete table is red, not silently narrow

- **GIVEN** the clean tree, then a scratch tree whose table loses one section's row, then a scratch tree
  whose row for one section no longer covers a path that section's own text names
- **WHEN** `bash skills/teamsmith/tests/section-select.sh --check` runs in each
- **THEN** the clean tree is green, both scratch trees exit non-zero and name the offending section (and, in
  the second, the token and its line), and restoring either makes it green again

#### Scenario: Missing planning literals are visible but product literals still fail

- **GIVEN** a clean product-only export and a scratch copy whose mapping also claims the nonexistent product
  literal `skills/teamsmith/tests/p98-no-such-literal.md`
- **WHEN** `bash skills/teamsmith/tests/section-select.sh --check` runs on each
- **THEN** the export exits 0 with separate skip counts and row/path attributions for `AGENTS.md`, `SCOPE.md`,
  `.pi/skills` and `openspec/changes/archive`, but the mutated copy exits 1 and names the missing product literal
- **AND** an internal checkout missing one of those internal literals exits 1, and a product-only table naming
  the nonexistent `openspec/changes/typo-planning-file.md` exits 1 rather than getting a blanket prefix exemption

#### Scenario: Public selector integrity and selection stay live

- **GIVEN** a product-only export and separate scratch copies with a missing row, narrowed pattern, unknown
  needs key, claimed exempt path, or undeclared product token
- **WHEN** `section-select.sh --check` runs against each copy, and the clean export runs the existing
  `--paths`, `--select` and `--verify-copies` checks
- **THEN** each corruption exits non-zero and names its original reason despite internal-literal skips;
  the clean export retains the same selection decisions/closure as the corresponding internal tree and all
  generated copies pass `bash -n`
