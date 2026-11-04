## MODIFIED Requirements

### Requirement: The help rewrite changes no command, flag, exit code or machine output

Except for the explicitly retired `team say --now`, command names and flag names SHALL stay unchanged and the
help surface SHALL print, for every command, at least the flags the pre-change surface printed for it.
Say's `--now` SHALL be absent from both English and Chinese menus, group/command help, usage and command baselines;
there is no alias. The old invocation SHALL exit 2 through the existing unknown-flag path, including a flag before
the recipient and after the message, with no keys, inbox/spool writes, forced audit or active/held Outbox changes.
This exception retires only say's flag: `outbox flush --now` and `draft send --now` remain visible and functional. The literal expectations other requirements place on help lines
SHALL keep holding: the `init` line names `.pi/skills`, `--copy` and `--no-skills`; the `add-agent` line prints
`--register`, `--create`, `--no-install` and `--print` and not `--model`; the `teardown` line prints
`--register`; the `dispatch` line prints `--branch <name>`.

Apart from the retired say invocation's defined unknown-flag refusal, every existing command's exit codes SHALL be unchanged, and `--print` and `--json` outputs SHALL be
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

#### Scenario: Only say loses its immediate flag in both languages

- **GIVEN** the command manifest, usage, English/Chinese help and pre-change baseline with say's retired flag explicitly removed
- **WHEN** menu, communication group, say, outbox flush and draft send help render in both languages
- **THEN** no say synopsis/option exposes `--now`, no printed flag is rejected by its command's parser, and outbox/draft still expose and execute their own `--now`
- **AND** hierarchy, locale/width behavior and all other flags remain covered by the existing help checks

#### Scenario: The retired say invocation is unknown before delivery

- **GIVEN** unchanged key, inbox, spool, forced and active/held queue fingerprints in an isolated fixture
- **WHEN** `team say --now dev "correction"` and `team say dev "correction" --now` run separately
- **THEN** each exits 2 naming the unknown flag and every delivery fingerprint is unchanged
