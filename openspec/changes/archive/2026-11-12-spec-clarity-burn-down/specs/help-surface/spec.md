## MODIFIED Requirements

### Requirement: The help surface is a level-0 menu, a page per group and a page per command
The help surface SHALL provide a level-0 menu, group pages and command pages rendered from `scripts/strings/commands.tsv` and its group table. Every non-internal dispatcher command SHALL be reachable; declared `__`-prefixed internal entries SHALL be excluded. Unknown help tokens SHALL exit 2 without running commands or writing state. Help SHALL work without a project and MUST NOT execute the documented command.

#### Scenario: The three levels are reachable, and each level answers its own question

- **GIVEN** the dispatcher's own command table (the case labels of `scripts/team` that dispatch a command) and the
  manifest's group table
- **WHEN** the menu, every group page and every command page are rendered
- **THEN** every label outside the declared internal set has a page whose title names that command and whose usage
  block begins with its path (an alias label instead carries an alias line on its primary's page), the menu's
  group list is exactly the manifest's group table, every group id resolves to a group page that lists its
  commands, and no page prints another page's body

#### Scenario: A group without an entry point names its commands

- **GIVEN** a scratch copy whose manifest no longer declares one group the commands still name, and a second
  scratch copy whose menu renderer skips one declared group
- **WHEN** the surface's coverage check runs in each copy
- **THEN** each exits non-zero naming that group and the commands that became unreachable, and the unmodified tree
  stays green

#### Scenario: An internal entry outside the declared set is a defect

- **GIVEN** a scratch copy whose dispatcher carries one more `__`-prefixed label than the declared internal set
  names
- **WHEN** the surface's coverage check runs there
- **THEN** it exits non-zero naming that label, and the unmodified tree stays green

#### Scenario: `team help <command>` is the same page as `team <command> --help`

- **WHEN** `team help dispatch` and `team dispatch --help` run
- **THEN** their outputs are byte-identical and both exit 0, and neither falls back to the menu

#### Scenario: An unknown token is refused, not answered with a page or the menu

- **GIVEN** a scratch project whose state directory is fingerprinted before the call
- **WHEN** `team frobnicate --help`, `team help frobnicate` and `team help not-a-group` run
- **THEN** each exits 2, its output names the token and points at `team help`, no command ran, no process was
  started (the fixture's recording launchers stayed empty) and the state fingerprint is unchanged

#### Scenario: The help paths need no project and run nothing

- **GIVEN** a scratch directory that is not a git worktree and carries no `.pi/team/config.sh`, with the fixture's
  recording `tmux` shim first on `PATH`
- **WHEN** `team`, `team help`, `team help dispatch` and `team dispatch --help` run there
- **THEN** all four exit 0 and print the menu or the dispatch page, and the directory gained no file

#### Scenario: Entry forms and manifest fields retain their exact shapes
- **WHEN** `team`, `team help`, `team help <group>`, `team help <command>`, `team <command> --help` and `team <command> -h` are exercised
- **THEN** the first two print the level-0 menu, the group form prints level 1, and each command form prints the same level-2 page rather than the menu
- **AND** a page explains its own command's subcommands and starts every usage line with the top-level command path
- **AND** the manifest carries each accepted command's group, usage fragment, flags, subcommands, aliases, examples, effect, authorization, touched faces and reversibility, and `dispatch#The printed route is a route that works` takes its working set from that manifest
- **AND** every level-1 group id resolves without colliding with a command name

#### Scenario: Internal entries and aliases follow the declared manifest contract
- **GIVEN** the dispatcher labels, the single declared set of internal entries and the manifest
- **WHEN** their coverage is checked
- **THEN** the declared set equals the dispatcher's `__`-prefixed labels, with either an undeclared label or a stale declaration failing by name
- **AND** no internal name appears in the manifest or on a rendered page
- **AND** reachability is judged from the manifest, whose menu names exactly its groups, whose group pages list their commands and whose commands all have pages, with an unreachable command failing by name
- **AND** an alias prints its primary's page plus a line naming both the alias and primary

#### Scenario: Unknown help never rejects an accepted command or executes a refusal
- **WHEN** `team help <unknown>`, `team <unknown> --help` and `team <unknown> -h` run
- **THEN** each uses the non-help unknown-subcommand status 2, names the token and points at `team help`, without executing a command or writing state
- **AND** every name the dispatcher accepts remains reachable rather than receiving this refusal

#### Scenario: Help never resolves or runs the project it documents
- **WHEN** any help page is requested inside or outside a project
- **THEN** rendering neither loads, requires nor writes `.pi/team/config.sh`, runs the documented command, nor starts any process

### Requirement: The help surface is English by default and switches language through `TEAM_LANG`
Help prose SHALL default to English when `TEAM_LANG` is unset, empty or `en`, use Chinese for `zh`, and warn once in English for other values without changing exit status. Language SHALL come only from environment. It SHALL change prose, never command paths, flags, usage, part order, command behavior or machine-readable output. Missing keys SHALL be visibly named and fall back to the other language rather than print blank.

#### Scenario: The default is English and the switch is complete

- **GIVEN** a fixture with `TEAM_LANG` unset, and the same fixture with `TEAM_LANG=zh`
- **WHEN** `team help`, `team help dispatch` and `team dispatch --help` run in both
- **THEN** the unset run's prose is English and the `zh` run's prose is Chinese, while the command paths, flag
  names, usage fragments and part order are byte-identical between the two runs

#### Scenario: An unknown language value is visible, not silent

- **WHEN** `TEAM_LANG=fr team help` runs
- **THEN** one warning line names `fr`, the surface is the English one, and the exit status is 0

#### Scenario: A missing key is named and falls back readably

- **GIVEN** a scratch copy of the tree whose Chinese table is missing one key
- **WHEN** `TEAM_LANG=zh team help` runs in that copy
- **THEN** the printed page names that key in its marker and prints the English value rather than an empty line,
  and the command still exits 0

#### Scenario: The language never reaches a machine exit

- **GIVEN** the same fixture in `en` and in `zh`, and a scratch copy whose help tables were mutated
- **WHEN** the declared machine exits (`team paths --json`, `team config list --json`, `team monitor --print`
  where the fixture can render it) run in each
- **THEN** every output is byte-identical across the three runs — the help surface changes prose, never a
  program's input

#### Scenario: Table completeness stays a review question while gaps stay visible
- **GIVEN** a selected prose table that lacks a key present in the other language
- **WHEN** a page needing that key is rendered
- **THEN** its marker contains the missing key id, the other language's value is printed, and neither an empty value nor a crash occurs
- **AND** the gate checks that visible behavior while the reviewer, not the gate, judges whether both tables are complete

### Requirement: Every behaviour a help page states is declared and probed
Help prose SHALL come from manifest rows and parallel language tables; behavioral statements SHALL use the row's closed-vocabulary effect, authorization, touched-face and reversibility fields. Placeholders SHALL come from one declared closed set, with unknown or stale declarations failing by name. Every vocabulary value SHALL have a fixture probe of its claimed effect. Usage fragments SHALL render unchanged and remain probed by `dispatch#The printed route is a route that works`.

#### Scenario: A claim with no probe is a defect

- **GIVEN** a scratch copy whose manifest declares an effect value outside the probed vocabulary for one command
- **WHEN** the surface's claim check runs there
- **THEN** it exits non-zero naming that command and that value, and the unmodified tree stays green

#### Scenario: A wrong declaration is caught by its probe

- **GIVEN** a scratch copy that declares a command `read-only` whose run writes a state file, and a second that
  declares `needs-yes` for a command that proceeds without `--yes`
- **WHEN** the claim check runs in each copy
- **THEN** each exits non-zero naming the command and the field, and the unmodified tree stays green

#### Scenario: One manifest row, one rendering of its usage line

- **GIVEN** a command that appears in the menu, on its group page and on its own page
- **WHEN** the three renderings' usage lines are compared
- **THEN** all three carry the same command path and the same flag set as the manifest row, and a scratch copy
  whose page prints a flag the row does not carry fails the check naming the page and the flag

#### Scenario: An undeclared placeholder fails instead of printing

- **GIVEN** a scratch copy whose prose table carries a `{…}` token the declared set does not name
- **WHEN** a page that prints that value is rendered
- **THEN** the renderer exits non-zero naming the token and the table it came from, and the unmodified tree stays
  green

#### Scenario: Vocabulary values demonstrate effects rather than exit codes alone
- **WHEN** the declared values are probed in scratch fixtures
- **THEN** `read-only` compares state fingerprints, `writes-<face>` shows that face changed and `starts-<process>` shows the fixture's recorded launch
- **AND** `needs-yes` proves refusal without `--yes`, names `--yes`, writes nothing and proceeds with it; `idempotent` proves a second run byte-identical; and `undo-by-<cmd>` proves that command restores the fingerprint
- **AND** wording, counts and ordering of prose about those fields remain review questions while declarations and probes stay executable

#### Scenario: A stale placeholder declaration fails in the opposite direction
- **GIVEN** a scratch copy whose declared placeholder set names a token no prose value or manifest field uses
- **WHEN** the placeholder check runs
- **THEN** it fails by naming the stale declaration, keeping the declared set and used tokens equal in both directions

#### Scenario: An unknown placeholder identifies its source instead of printing
- **GIVEN** a prose value or manifest field containing a `{…}` token outside the declared set
- **WHEN** a page that would print it renders
- **THEN** rendering fails by naming the token and its source table or field rather than printing the token literally

### Requirement: The help rewrite changes no command, flag, exit code or machine output
Except for retiring `team say --now`, the help rewrite SHALL preserve command and flag names, existing exit codes, and byte-identical `--print`/`--json` outputs. Say's retired flag SHALL be absent from both languages and exit 2 before delivery; `outbox flush --now` and `draft send --now` SHALL remain. Reachable help SHALL exit 0 and unknown-token help SHALL exit 2. Named literal help expectations SHALL remain.

#### Scenario: The rewritten surface keeps the flags other requirements name

- **WHEN** the menu, the group pages and the command pages are rendered
- **THEN** each of the named lines prints the flags its requirement names, no printed flag is one the command's
  parser refuses, and the walk that probes them stays green in both languages

#### Scenario: The rewrite leaves the machine exits alone

- **GIVEN** the pre-change tree and the rewritten tree in the same fixture, and a scratch copy whose help tables
  were mutated
- **WHEN** the declared machine exits run in each tree
- **THEN** their bytes are identical across all three runs, and no output differs by language

#### Scenario: The help statuses are the only ones this change defines

- **WHEN** `team dispatch --help` and `team frobnicate --help` run
- **THEN** the first exits 0 and the second exits 2, and the exit statuses every other command reports are
  untouched by this change

#### Scenario: Only say loses its immediate flag in both languages

- **GIVEN** the command manifest, usage, English/Chinese help and pre-change baseline with say's retired flag explicitly removed
- **WHEN** menu, communication group, say, outbox flush and draft send help render in both languages
- **THEN** no say synopsis/option exposes `--now`, no printed flag is rejected by its command's parser, and outbox/draft still expose and execute their own `--now`
- **AND** hierarchy, locale/width behavior and all other flags remain covered by the existing help checks

#### Scenario: The retired say invocation is unknown before delivery

- **GIVEN** unchanged key, inbox, spool, forced and active/held queue fingerprints in an isolated fixture
- **WHEN** `team say --now dev "correction"` and `team say dev "correction" --now` run separately
- **THEN** each exits 2 naming the unknown flag and every delivery fingerprint is unchanged

#### Scenario: The literal flag expectations remain intact
- **WHEN** the `init`, `add-agent`, `teardown` and `dispatch` help lines render
- **THEN** `init` names `.pi/skills`, `--copy` and `--no-skills`; `add-agent` prints `--register`, `--create`, `--no-install` and `--print` but not `--model`; `teardown` prints `--register`; and `dispatch` prints `--branch <name>`
- **AND** the pre-change surface's remaining command and flag names stay present, apart from the explicitly retired `team say --now`

#### Scenario: Machine output never routes through help rendering
- **WHEN** `--print` and `--json` outputs are compared before and after the rewrite
- **THEN** their bytes remain identical because those paths read neither the manifest nor the language tables
- **AND** the only newly defined refusal is the retired say invocation's exit 2; all other existing command statuses remain unchanged

### Requirement: The surface's layout is the same in every locale, and never exceeds its width
For fixed tree, `TEAM_LANG` and `TEAM_HELP_WIDTH`, help output SHALL be byte-identical and valid UTF-8 under non-UTF-8 and UTF-8 locales. A locale-independent code-point counter SHALL measure wide characters as two cells without locale width functions, and no line SHALL exceed `TEAM_HELP_WIDTH`. The environment-only width setting SHALL warn once and fall back when invalid; project configuration SHALL NOT supply it.

#### Scenario: The same page renders the same bytes in a non-UTF-8 locale

- **GIVEN** one fixture tree with `TEAM_LANG` and `TEAM_HELP_WIDTH` held equal
- **WHEN** the menu, every group page and every command page are rendered under `LC_ALL=C` and under
  `LC_ALL=C.UTF-8`
- **THEN** each page's two runs are byte-identical, and every page is valid UTF-8

#### Scenario: No line exceeds the width the surface wraps to

- **GIVEN** the same fixture with the default `TEAM_HELP_WIDTH` and with a non-default one
- **WHEN** the menu, every group page and every command page are rendered
- **THEN** no line exceeds that width in display cells as counted by the fixture's own locale-independent
  counter, and a scratch copy whose renderer measures width through the locale fails naming the page and the line

#### Scenario: Width measurement and review boundaries remain explicit
- **WHEN** the width renderer and environment-only `TEAM_HELP_WIDTH` handling are inspected
- **THEN** width classification uses code points rather than `wcwidth`, `wc -L`, locale multibyte handling or expansion at character indices
- **AND** an invalid width prints one visible warning and falls back without consulting the project contract
- **AND** wording, indentation, page depth and section order remain review questions; locale-independent bytes and the declared width bound remain the behavioral checks
