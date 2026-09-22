## ADDED Requirements

### Requirement: The contract promises Pi; the launch and notify seam is an internal frozen seam

teamsmith SHALL promise exactly one harness: **Pi**, at the version floor `README.md` states and `team doctor`
enforces (Pi ≥ 0.76.0 today — the `--session-id` floor). The four worker keys (`TEAM_AGENT_CMD`,
`TEAM_AGENT_NOTIFY_CMD`, `TEAM_AGENT_LOG_GLOB`, `TEAM_AGENT_BIN`) and the three PM keys (`TEAM_PM_CMD`,
`TEAM_PM_BIN`, `TEAM_PM_RESUME_ARGS`) SHALL be described as an **internal seam (frozen)**: the built-in Pi
paths are rendered by the same engine, the seam is reserved for a possible future non-Pi adapter, and
teamsmith makes no compatibility promise about it — it is not a public extension point and the new-project
questionnaire MUST NOT ask about it or name its keys.

The claimed surface — `README.md`, `skills/teamsmith/SKILL.md` (frontmatter `description`, the
`## Agent adapters` section and the deep-reading table row), `skills/teamsmith-init/SKILL.md`,
`skills/teamsmith/references/agent-adapters.md`, `references/config.md`, `references/migration.md`,
`references/troubleshooting.md`, `templates/config.sh.tmpl` and the degradation message `scripts/monitor.mjs`
prints when no session log matches — MUST NOT advertise another harness as supported: the phrases
`any TUI agent`, `any TUI Agent`, `another TUI agent`, `其它 TUI agent` and `任意 TUI agent` MUST NOT appear
anywhere on it, and
every mention of a non-Pi CLI SHALL carry the frozen wording (reserved for a possible future non-Pi adapter,
no compatibility promise, not a supported extension point). Source comments inside `scripts/**` and the test
suite are outside the claimed surface: this change rewords documentation and one diagnostic message (plus its
comment), never behaviour.

The scoping changes no behaviour: the three existing requirements of this capability (the template contract,
the first-word resolution and the PM-side adapter) stay exactly as they are, a configured seam is
still rendered, validated and reported as `custom: …`, and with every adapter key empty the built-in Pi
commands SHALL remain the same literal strings as before this change — worker: `<TEAM_PI_BIN> --provider <p>
--model <m> -e <skill>/extension/team-notify.ts -e <skill>/extension/team-bg.ts -e
<skill>/extension/team-inbox-watch.ts --skill <skill dir> --session-id <session>-<agent> "$0"`; PM:
`<TEAM_PI_BIN> --provider <p> --model <m> -e <skill>/extension/team-bg.ts -e
<skill>/extension/team-inbox-watch.ts --skill <skill dir> -c @<state>/pm-prompt.md`. No test file MAY need an
edit for this change to pass.

#### Scenario: No claimed file advertises another harness

- **WHEN** the claimed surface is searched for `any TUI agent`, `any TUI Agent`, `another TUI agent`,
  `其它 TUI agent` and `任意 TUI agent`
- **THEN** no hit remains, and the fixture's red side — the same search against a scratch tree with one of the
  phrases appended to `README.md` or `skills/teamsmith/SKILL.md` — prints that file and line and exits
  non-zero

#### Scenario: The seam is documented as frozen and stays usable

- **GIVEN** `TEAM_AGENT_CMD='myagent run --ask {prompt}'` and `TEAM_AGENT_BIN=bash`
- **WHEN** `team dispatch dev T1.1 <brief> --print` runs, and `references/agent-adapters.md` is read from its
  first heading onwards
- **THEN** the dispatch prints `adapter: custom: myagent run` and renders the command — no refusal, no
  "unsupported" error, no doctor failure for the sole reason that the harness is not Pi — and the doc states,
  before its first worked non-Pi example, that the seam is internal and frozen with no compatibility promise

#### Scenario: The worked non-Pi examples are marked as seam documentation

- **GIVEN** `references/agent-adapters.md` and `templates/config.sh.tmpl`
- **WHEN** both are read
- **THEN** the reference doc keeps its worker launch table, its notify table and its
  `<!-- pm-side:begin -->`/`<!-- pm-side:end -->` PM table with every supported placeholder (the smoke
  suite's doc↔engine scanners, §6f and §6i, stay green with no test edit), while the contract template offers
  no ready-to-use example of another CLI: its adapter section states the seam is internal and frozen and
  points at the reference doc

#### Scenario: The built-in Pi commands are byte-for-byte unchanged

- **GIVEN** every adapter key empty (`TEAM_AGENT_CMD`, `TEAM_AGENT_BIN`, `TEAM_PM_CMD`, `TEAM_PM_BIN`,
  `TEAM_PM_RESUME_ARGS`) and the same fixture project on this tree and on the pre-change revision
- **WHEN** `team dispatch dev T1.1 <brief> --print` runs on both trees (adapter keys empty), and §6i's
  PM-launch fixture computes the PM command on both trees
- **THEN** the worker strings from the two trees are byte-identical to each other and carry
  `-e <skill>/extension/team-notify.ts`, `-e <skill>/extension/team-bg.ts`, `-e
  <skill>/extension/team-inbox-watch.ts`, `--skill <skill dir>` and `--session-id <session>-dev`; the PM
  strings from the two trees are byte-identical to each other and equal §6i's recorded literal (`-e
  <skill>/extension/team-bg.ts -e <skill>/extension/team-inbox-watch.ts --skill <skill dir> -c
  @<state>/pm-prompt.md`); and neither rendered command contains a leftover `{`
- **AND** the §6f/§6i render assertions pass unmodified

#### Scenario: The daily description routes Pi and still points at the init skill

- **WHEN** the `description` of `skills/teamsmith/SKILL.md` is extracted
- **THEN** it names Pi as the harness, contains none of the five banned phrases, still contains the
  `teamsmith-init` pointer, and stays within the 1024-character limit the skill-load gate checks
