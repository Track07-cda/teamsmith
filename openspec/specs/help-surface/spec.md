# help-surface Specification

## Purpose
TBD - created by archiving change cli-help. Update Purpose after archive.
## Requirements
### Requirement: The help surface is a level-0 menu, a page per group and a page per command

The CLI's help surface SHALL have three levels. `team` with no arguments and `team help` print the entry level (the
level-0 menu). `team help <group>` prints that group's page (level 1). `team help <command>` and
`team <command> --help` / `team <command> -h` print that command's page (level 2); these two entries SHALL be
byte-identical to each other and SHALL NOT fall back to the menu. A page belongs to one command; that command's
subcommands are explained on its page, and a usage line always begins with the top-level command name so that it
names its own command path.

The surface's structure SHALL come from one machine-readable command manifest (`scripts/strings/commands.tsv`)
that carries one row per command the dispatcher accepts — its group, usage fragment, flags, subcommands, aliases,
example commands and its declared effect, authorization, touched-face and reversibility fields — plus the group
table; the menu, the group pages and the command pages SHALL all render from it, and the walk
`dispatch#The printed route is a route that works` SHALL take its working set from it. A group id is the token
level 1 accepts and MUST NOT collide with a command name.

Every command the dispatcher accepts SHALL be reachable through the three levels, and the dispatcher's
**internal entries** SHALL be the only names outside the surface: an internal entry is a dispatcher label whose
name begins with `__`, that set SHALL be closed and declared in one place, and the declared set SHALL equal the
dispatcher's `__`-prefixed labels — a dispatcher label beginning with `__` that the declared set does not name,
and a declared internal name that is no longer a dispatcher label, SHALL each fail the surface's check naming the
name. No internal name SHALL be printed on any page, and the manifest MUST NOT carry one. Reachability SHALL be
judged from the manifest, not from whatever a rendered page happens to yield: the menu SHALL name every group the
manifest declares and no group it does not, each group page SHALL list that group's commands, and every command
SHALL have a page; a command whose group has no entry point in the menu, or whose group page does not list it,
SHALL fail the check naming that command. A name the dispatcher keeps only as an alias is documented on its
primary's page: asking for it prints the primary's page plus an alias line naming the alias and its primary.

A token that is neither a group nor a command SHALL NOT be answered with a page: `team help <unknown>`,
`team <unknown> --help` and `team <unknown> -h` SHALL exit 2 — the status the non-help path already uses for an
unknown subcommand — naming the token and pointing at `team help`. A name the dispatcher accepts MUST NOT be
refused this way, and a refusal MUST NOT execute any command or write any state.

The help paths SHALL resolve without a project: they MUST NOT load, require or write `.pi/team/config.sh`, they
SHALL work in a directory that is not a git worktree, and requesting a page MUST NOT run the command the page
documents nor start any process.

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

### Requirement: The help surface is English by default and switches language through `TEAM_LANG`

The help surface's prose SHALL be English when `TEAM_LANG` is unset, empty or `en`, and Chinese when it is `zh`.
Any other value SHALL print one visible warning line naming the value and then the English surface, with the help
path's exit status unchanged. The language SHALL be resolved from the environment only: the help paths MUST NOT
read the project contract for it, so the default and the switch behave identically outside a project.

The language SHALL select prose only. Command paths, flag names, usage fragments and the page's part order SHALL
be byte-identical between the two languages.

A key the selected table lacks SHALL NOT be silent: the printed line SHALL carry a marker naming the missing key
(the marker contains the key id, so the gap can be searched for), and when the other table carries that key the
other language's value SHALL be printed in its place; an empty value MUST NOT be printed. Whether the two tables
are complete is a review question, not a gate's: the gate checks the behaviour (a missing key is visible, never
blank and never a crash), and the reviewer reads both tables.

`TEAM_LANG` MUST NOT change any command's behaviour or any machine-readable output: for every command whose
output is consumed by a program (`--json`, `--print`), the bytes SHALL be identical under both languages and
SHALL be unaffected by the content of the help tables.

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

### Requirement: Every behaviour a help page states is declared and probed

The surface's prose SHALL come from the manifest's rows and two parallel language tables keyed by the same prose
keys, one per language; a page's statement about behaviour SHALL come from its command's manifest row rather
than from free prose. The row SHALL carry the command's effect, authorization, touched faces and reversibility
as fields whose values come from closed vocabularies. (What the prose may say about those fields — wording,
counts, ordering — is a review question; the gate checks the declarations and their probes.)

Interpolation into that prose SHALL go through a closed placeholder set declared in one place. A prose value or a
manifest field whose text carries a `{…}` token outside that set SHALL NOT be printed literally: rendering a page
that would print it SHALL fail, naming the token and the table or the field it came from. The same check SHALL
fail when the declaration names a placeholder the tree no longer uses, so the declared set and the tokens in the
tree stay equal in both directions.

Every value in those vocabularies SHALL name a probe that makes the claimed effect happen in a scratch fixture:
a value with no probe SHALL fail the surface's check naming the command and the value, and a probe that does not
show the claimed effect SHALL fail naming the command. The probes assert effects, never exit codes alone:
`read-only` runs the command and compares the state fingerprints; `writes-<face>` shows that face changed;
`starts-<process>` shows the launch recorded by the fixture's shims; `needs-yes` shows the command refuses
without `--yes`, names `--yes` and writes nothing, and proceeds with it; `idempotent` shows a second run leaves
the state byte-identical; `undo-by-<cmd>` shows running that command restores the fingerprint.

The usage-line half of the contract lives in `dispatch#The printed route is a route that works`, which judges
every level's usage lines against the real parser and takes its working set from this surface's manifest. A
page's `Usage` block SHALL print its manifest row's usage fragment unchanged, and the menu's and group pages'
lines SHALL print the same fragment, so an argument cannot be printed or explained without the walk that probes
it.

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

### Requirement: The help rewrite changes no command, flag, exit code or machine output

Command names and flag names SHALL stay unchanged and the help surface SHALL print, for every command, at least
the flags the pre-change surface printed for it. The literal expectations other requirements place on help lines
SHALL keep holding: the `init` line names `.pi/skills`, `--copy` and `--no-skills`; the `add-agent` line prints
`--register`, `--create`, `--no-install` and `--print` and not `--model`; the `teardown` line prints
`--register`; the `dispatch` line prints `--branch <name>`.

Every existing command's exit codes SHALL be unchanged, and `--print` and `--json` outputs SHALL be
byte-identical to their pre-change bytes: they are produced by paths that do not read the manifest or the
language tables, and the help rewrite MUST NOT route them through the help surface. The surface's own defined
statuses are: a reachable page exits 0, and an unknown token with a help request exits 2 through the same
refusal the non-help path uses.

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

### Requirement: The surface's layout is the same in every locale, and never exceeds its width

The bytes the help surface prints SHALL NOT depend on the process locale. For one tree, one `TEAM_LANG` and one
`TEAM_HELP_WIDTH`, the menu, every group page and every command page SHALL be byte-identical when rendered under
a non-UTF-8 locale (`LC_ALL=C`) and under a UTF-8 locale (`C.UTF-8` or `en_US.UTF-8`), and every byte the surface
prints SHALL be valid UTF-8 in every locale.

The surface SHALL measure display width with its own locale-independent counter: a character the surface counts
as wide counts two cells, and the classification SHALL come from the character's own code point rather than from
the locale — the renderer MUST NOT take its widths from the locale's multibyte handling (`wcwidth`, `wc -L`, or
expanding the input at character indices). No printed line SHALL exceed `TEAM_HELP_WIDTH` display cells as
counted by that counter.

The width knob's behaviour is unchanged: `TEAM_HELP_WIDTH` is read from the environment only, an invalid value
prints one visible warning and falls back, and the value the surface wraps to never comes from the project
contract. Wording, the indent ladder, the page depth and the section order are review questions, not this
requirement's: what is judged here is the same input producing the same bytes in any locale, and the width the
surface claims to wrap to actually bounding every line.

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

