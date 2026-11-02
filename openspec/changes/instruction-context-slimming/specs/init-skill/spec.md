## ADDED Requirements

### Requirement: Installed team instructions separate shared rules from role procedures without losing required duties

The generated AGENTS managed section SHALL be a short shared constitution and reading order for PM and workers, rather than a full PM operations runbook. The PM startup prompt SHALL retain the instructions needed to start, inspect pending work and make authorized dispatch/verification decisions without first loading every reference. The worker dispatch prompt SHALL remain self-contained on its assignment identity, worktree/branch, brief and ownership scope, security and cross-project boundaries, legal turn endings, evidence, report and applicable settled-delivery behavior. The daily skill SHALL retain its useful command/reference index; detailed procedures SHALL live in the existing skill references. The generated PROTOCOL summary SHALL point to those homes rather than become another detailed rule system.

This organization SHALL preserve every obligation and surface requirement already specified by dispatch, writing-discipline, key-replies, watchdog, verification, agent-adapters, boundary and this capability. A required short statement on AGENTS, the PM prompt, worker prompt or a reference MUST NOT become a bare link. In particular, role-specific organization is not permission to drop the specified writing duties, the marker-captured reply duty owned by `key-replies`, three-state ending/background contract, independent verification, category/recorded-model recovery, authorization or disk handover. The product SHALL NOT introduce a separate rule registry or prose-quality guard to enforce this organization. Rule preservation SHALL be judged by rule-by-rule reading and independent substantive review, not a keyword total, size budget, runtime benchmark or AI reviewer's score; size measurements SHALL be evidence only. This requirement does not change any dispatch, publication, lifecycle, model selection, capacity or gate-scope behavior.

#### Scenario: Each role can enter through the shipped instructions

- **WHEN** a reviewer reads the generated shared AGENTS section, PM startup prompt, worker dispatch prompt, daily skill index, generated PROTOCOL summary and their referenced procedures
- **THEN** the shared section gives the roles, boundaries and reading order; the PM has its startup commands and decision boundaries; the worker has its assignment and delivery essentials; and the command index resolves detailed procedures to existing references
- **AND** each statement another capability requires on a named surface is still stated there, even where that creates a short intentional duplicate

#### Scenario: Removing a required local statement is not accepted as slimming

- **GIVEN** a candidate diff that replaces a required local writing, publication or background-ending statement with only a reference link
- **WHEN** the rule-coverage read and independent substantive review compare the affected surface with its existing capability requirement
- **THEN** they identify the missing local statement as a preservation failure, irrespective of a smaller byte count or a green structural/behavioral gate
- **AND** the accepted remedy retains the required local statement, or returns the proposed obligation change for separately scoped delta review; it is not accepted under instruction organization alone

#### Scenario: Worker variants retain their applicable contracts

- **WHEN** local and remote worker prompts are rendered on the built-in Pi path and on custom adapter templates with and without the background-lane placeholder
- **THEN** each retains assignment/safety/evidence/report essentials and the three legal ending states, and delivery describes the actual local or PM-directed remote route rather than requiring a remote push or PR in local mode
- **AND** lane-tool instructions appear only on the paths that supply them, retaining the suspend default, normal completion harvest, bounded inline-wait exception and on-disk recovery evidence required by dispatch

### Requirement: Explicit init refreshes a well-formed managed AGENTS block and describes its other effects honestly

For an existing project with valid current model policy, normal `team init` without `--force` SHALL refresh the managed AGENTS block from the current rendered template. The explicit `<!-- teamsmith:begin -->` and `<!-- teamsmith:end -->` delimiter lines are the update boundary: a delimiter is recognized only as an exact standalone full line outside a fenced code block, never by matching the word teamsmith or a heading name in arbitrary content. The writer SHALL scan the whole file and count every eligible delimiter candidate before it decides anything; it MUST NOT act on the first match and stop. From that complete set exactly three outcomes follow: one balanced eligible pair → refresh it; no eligible delimiter line at all → append one block; any other set → refuse (see below). A marker-looking string that is quoted in prose, indented, shares a line with other text or sits inside a fenced example is ordinary content — never a delimiter candidate and never an error. Text within the eligible pair is managed and replaced; both delimiter lines themselves and every other byte of the file — preceding and following sections, ordinary non-Teamsmith headings, project-specific rules, those non-delimiter marker examples, line order, line-ending style and whitespace — SHALL be preserved unchanged. The update SHALL be a byte-range replacement between those two lines, and the replacement body's line terminator SHALL be the existing begin-delimiter line's own terminator (`\n` or `\r\n`), used for every inserted line, including in a file whose endings are mixed. LF, CRLF, mixed line endings and a final line without a newline are supported inputs, and the writer MUST NOT normalize them, add a final newline or otherwise change a byte outside that range. An old `pi-team` pair without a current pair SHALL migrate to the current markers and receive the same replacement, and that conversion SHALL replace only that pair's two delimiter lines: a `pi-team` example outside the pair MUST remain byte-identical. A file with no eligible delimiter line SHALL retain its prior contents and gain one current block, allowing the separating newline; a missing file SHALL be created. Repeating the same init inputs SHALL leave AGENTS bytes stable with one current pair. `--no-skills` SHALL skip skill/extension installation, not AGENTS refresh. Refusal is reserved for genuine ambiguity and for a file where the boundary cannot be placed safely: two or more eligible pairs, an eligible begin without its end, an end without its begin, current and legacy delimiter lines mixed so that one would have to be guessed, or no eligible pair in a file that ends inside an unclosed fenced block (an appended block would land inside that fence and be appended again on every run). In those cases the writer MUST leave the file byte-identical and report a named failure instead of guessing, rewriting, refreshing the first pair or claiming a refresh.

Guidance shipped on the AGENTS managed section and the PM startup prompt SHALL state that project-specific rules belong outside the Teamsmith markers and that the managed block is not a customization surface; the detailed existing-project recipe SHALL stay in `references/migration.md`, including the PM's duty to inventory local rules currently inside the block and preserve them outside under the project's actual authorization before a later refresh. That guidance MUST NOT authorize automatic classification or relocation of arbitrary existing text.

Non-force refresh SHALL retain the bytes of an existing valid config and existing ledger documents that init normally skips. Guidance MUST NOT extend that promise to all other paths or to file metadata: init also creates missing document scaffolding, writes ignore/support files, normalizes config permissions and, unless skipped, handles project-local installation. The sequence SHALL be described as non-transactional: a later failure is not proof that earlier AGENTS/docs/ignore writes did not occur. Guidance SHALL distinguish explicit init refresh from existing-config bootstrap, which does not refresh AGENTS, and from force re-rendering, which can replace config/ledger and is not necessary for AGENTS refresh. Existing legacy-model refusal and install-conflict behavior SHALL remain unchanged.

Refresh guidance SHALL disclose the render parameters and actual main-root write target instead of claiming that preserving config makes bare init safe for non-default projects. It SHALL name the ordinary defaults (main-root basename session, `dev verify` roster, `docs/team` docs, `pm` PM window and the current AGENTS render's `main` protected-branch value), require a private-copy preview with the project's actual inputs before live adoption, and disclose that customization inside markers is not protected. No automatic live adoption or repair of malformed/multiple/mixed marker blocks is promised by this contract.

#### Scenario: Verbose old current block becomes the rendered shorter block without losing outside text

- **GIVEN** a project with valid current config and existing ledger documents, and a normal AGENTS block longer than the replacement with unique complete custom text before and after it, including an ordinary non-Teamsmith heading, Chinese project rules, an indented marker-looking line and a fenced example quoting both delimiter lines
- **WHEN** non-force init runs with matching explicit render inputs
- **THEN** the extracted inclusive managed block equals the independently rendered current template, the old managed-only text is absent, exactly one current pair remains, and the whole AGENTS file is shorter
- **AND** the outside custom text, its line order and whitespace, the fenced example and existing config/ledger document bytes are byte-identical to before

#### Scenario: Legacy markers migrate line-scoped and repeated refresh stabilizes

- **GIVEN** the same file shape using only the `pi-team` marker pair, plus an outside fenced example that also quotes the legacy delimiter lines
- **WHEN** non-force init runs twice with identical inputs
- **THEN** no legacy delimiter line remains at the managed pair's position, one current block equals the rendered template, the outside example still reads `pi-team` byte-for-byte, outside text survives, and the AGENTS bytes after the first and second run are identical

#### Scenario: Quoted and indented marker examples are ordinary content, not a failure

- **WHEN** non-force init runs on a file whose prose quotes the delimiter inline, whose example indents it, or whose **closed** fenced example contains both delimiter lines, while no eligible fence-outside delimiter line exists
- **THEN** the file keeps every existing byte and gains exactly one appended current block, and the command reports an appended block rather than a refresh or a failure
- **AND** repeating the invocation still leaves one pair and rewrites none of those examples

#### Scenario: Genuine ambiguity is refused instead of guessed

- **GIVEN** a file with two or more eligible pairs, an eligible begin without its end, an end without its begin, or current and legacy delimiter lines mixed so that one must be guessed
- **WHEN** non-force init scans every eligible delimiter candidate and finds that set
- **THEN** the file is byte-identical after the run and the command names that file as a failure rather than printing a refresh or an append message; no pair is refreshed in place of the refusal
- **AND** repeating the invocation neither resolves the shape by itself nor adds a block

#### Scenario: Line-ending style and a missing final newline survive the range update

- **GIVEN** a supported pair inside a CRLF file, a file with mixed line endings, and a file whose last line has no terminating newline, each with unique outside text
- **WHEN** non-force init refreshes the pair
- **THEN** only the bytes between the two delimiter lines change, both delimiter lines are byte-identical to before, and every inserted body line uses the begin delimiter line's own terminator — so a CRLF block receives CRLF body lines and a mixed-ending file follows its begin line
- **AND** every outside byte — including other CRLF/LF endings and the absence of a final newline — is identical to before, and none of these inputs is refused as a formatting violation or rewritten into a normalized form

#### Scenario: A block is never appended inside an unclosed fenced example

- **GIVEN** a file with no eligible delimiter line that ends inside an unclosed fenced block quoting the delimiter lines
- **WHEN** non-force init runs twice
- **THEN** each run leaves the file byte-identical and names the unresolved fence as the reason instead of appending a block inside it
- **AND** the file does not grow a new block per run, and the project resolves the fence before refreshing

#### Scenario: Placement guidance reaches the PM without a relocation promise

- **WHEN** the rendered AGENTS managed section, the PM startup prompt and the existing-project recipe in `references/migration.md` are read
- **THEN** the first two carry a short statement that project-specific rules go outside the markers and that the managed block is not a customization surface, and the third owns the detailed preview/preserve/authorize sequence
- **AND** the guidance requires the PM to inventory in-block local rules and preserve them outside under the project's authorization, and does not claim that init moves or classifies any outside text

#### Scenario: No marker appends and a missing file is created

- **WHEN** non-force init runs in one valid project whose AGENTS has custom text but no eligible delimiter line and another whose AGENTS is absent
- **THEN** the first retains its custom contents and appends one rendered current block with the permitted separator, the second receives that block, and repeating each invocation does not add another block

#### Scenario: Skipping skills does not skip refresh

- **GIVEN** a valid project with an old supported AGENTS block and no project-local skills/extensions
- **WHEN** matching non-force init runs with `--no-skills`
- **THEN** AGENTS becomes the rendered current block with outside text preserved, skill/extension installation is reported skipped and neither install directory is created
- **AND** the command is not described as an AGENTS-only or globally write-free operation

#### Scenario: Non-default project parameters are previewed rather than inferred from a skipped config

- **GIVEN** a valid project with a non-default session, roster, docs path and PM window, its existing config bytes recorded, and a main protected branch
- **WHEN** the explicit matching non-force init invocation is previewed in a private copy and then exercised there
- **THEN** the rendered section names those parameters and correct paths, equals the template rendered with those inputs, and preserves the existing config and existing ledger documents
- **AND** guidance names the different bare-init defaults and current hard-coded protected-branch render value rather than promising that all non-default configuration is inferred

#### Scenario: Force, bootstrap and late failure are not mistaken for safe refresh shortcuts

- **WHEN** refresh guidance and the existing force/bootstrap/install-conflict fixtures are reviewed alongside the normal-init refresh results
- **THEN** ordinary init needs no force for AGENTS replacement, existing-config bootstrap leaves AGENTS unrefreshed, force is identified as a broader config/ledger re-render and not a legacy-model migration, and a late install failure is not described as rolling back earlier writes
- **AND** no supported-shape claim is extended to duplicate or mixed marker pairs, to preservation of project customization inside the managed pair, or to a repair heuristic that guesses which delimiter is the real one
