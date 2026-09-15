## Purpose

The adapter layer: one template contract for the CLI that runs a worker or the PM, the template's first word
resolved on the caller's `PATH` instead of guessed from the window's login shell, and the PM's own three keys.
It exists so "how do I start this agent CLI" stays a configuration instead of a fork in the tool — and so the
placeholder list lives in exactly one requirement. Why each rule exists: `references/agent-adapters.md`.

## ADDED Requirements

### Requirement: The adapter template contract is enforced, not guessed

A configured `TEAM_AGENT_CMD` SHALL be expanded for `{cwd}`, `{session_id}`, `{model}`, `{provider}`,
`{prompt_file}`, `{prompt}`, `{skill_dir}`, `{notify_ext}`, `{extra_args}`. An unknown or malformed `{...}` token,
a whitespace-only template and a multi-line template MUST fail the dispatch with an actionable message; a rendered
command MUST contain no leftover `{`. The prompt MUST travel out of band (`{prompt}` is the harness' `argv[0]`), so
its size never lands in the window command line.

#### Scenario: An unknown placeholder fails with the supported set

- **WHEN** `TEAM_AGENT_CMD='myagent {sessionid} {prompt}' team dispatch dev T1.1 <brief> --print` runs
- **THEN** the command exits non-zero and names `{sessionid}`, the supported placeholders and the config key

#### Scenario: A malformed placeholder is not silently passed through

- **WHEN** `TEAM_AGENT_CMD='myagent --dir { cwd } {prompt}' team dispatch dev T1.1 <brief> --print` runs
- **THEN** the command exits non-zero instead of rendering `{ cwd }` into the window command

#### Scenario: A multi-line template cannot become a script

- **GIVEN** a template whose second line is `touch <sentinel>`
- **WHEN** `team dispatch dev T1.1 <brief>` runs
- **THEN** it exits non-zero, explains that the second line would be executed as a new command, and the sentinel
  file does not exist

#### Scenario: A long prompt does not enter the command line

- **GIVEN** a brief larger than 100 KB
- **WHEN** a worker is dispatched with an adapter whose template uses `{prompt}`
- **THEN** the process receives the whole prompt as one argument, byte-for-byte identical to the prompt file, and
  the rendered window command stays short

### Requirement: The template's first word is resolved, not guessed

When teamsmith renders a launch template it SHALL resolve the template's first word on the **caller's** `PATH` and
render the resulting absolute path into the window command, because the window executes that command with
`bash -lc`, whose `PATH` comes from `/etc/profile` and `~/.bash_profile` and routinely lacks the directories an
interactive shell adds. The executable used for the readiness wait, the start-time existence check and the liveness
identity check SHALL be `TEAM_AGENT_BIN`, else the template's first word, else `TEAM_PI_BIN`. A first word that is
not a bare executable name (it contains `/`, a quote, `$`, `{` or `}`) MUST be left exactly as written, and the
template MUST also be left untouched when `TEAM_AGENT_BIN` explicitly names a **different** binary — the tool does
not rewrite a command whose executable it is not checking. The PM's own template follows the same rule.

#### Scenario: A bare first word is rendered as the absolute path from the caller's PATH

- **GIVEN** a CLI `worker-bare` that resolves on the caller's `PATH` but not in `bash -lc`'s `PATH` (the fixture
  asserts both facts, so the scenario cannot pass for the wrong reason)
- **WHEN** `TEAM_AGENT_CMD='worker-bare --pf {prompt_file} --ask {prompt}' team dispatch dev T1.1 <brief> --print`
  runs
- **THEN** the printed command starts with the resolved absolute path and contains no bare `worker-bare`
- **AND** a real dispatch of the same template runs that CLI inside the window (its own log proves it started)

#### Scenario: An absolute first word, or one pinned to another binary, is left as written

- **GIVEN** `TEAM_AGENT_CMD='<abs>/worker-bare --pf {prompt_file}'` and `TEAM_AGENT_BIN='<abs>/worker-bare'`
- **WHEN** `team dispatch dev T1.1 <brief> --print` runs
- **THEN** the printed command still starts with `<abs>/worker-bare`, unchanged
- **AND** with `TEAM_AGENT_CMD='myagent run --ask {prompt}' TEAM_AGENT_BIN=bash` the printed command still says
  `myagent run` — a pinned, different binary means the template is the author's to own

### Requirement: The PM is an adapter too

teamsmith SHALL launch the PM through the same template engine, configured by `TEAM_PM_CMD` (the PM placeholder set
plus the PM-only `{resume_args}`), `TEAM_PM_BIN` (the executable for the start-time existence check and the liveness
identity check: `TEAM_PM_BIN` > the first word of `TEAM_PM_CMD` > `TEAM_PI_BIN`) and `TEAM_PM_RESUME_ARGS`. With all
three empty, `team up` MUST keep the built-in Pi launch path unchanged — `TEAM_PI_BIN --provider <p> --model <m>
--skill <skill dir> -c @state/pm-prompt.md`, with the briefing passed as the window harness' `argv[0]` and never on
the command line. A configured template MUST be expanded under the same placeholder rules and fail the same way as
the worker side: a blank, multi-line or unknown-token `TEAM_PM_CMD` (including the worker-only `{notify_ext}` and
`{summary}`) MUST fail before the PM window is respawned, naming `TEAM_PM_CMD` and the supported placeholders; an
unresolvable `TEAM_PM_BIN` MUST fail the same way, naming the key and the `PATH`. When `TEAM_PM_RESUME_ARGS` is
empty on a custom CLI the start MUST state that the session history is **not** continued and name the handover
(`docs/team/**`, `team inbox`, `team digest`); when the key is set but the template does not reference
`{resume_args}`, that too MUST be reported as not continued. A start that fails MUST write
`state/pm-launch-failed.log` (rendered command, resolved binary, exit code, window tail) and exit non-zero. Why the
PM side is deliberately asymmetric (no turn-end notification, no guaranteed continuity):
`references/agent-adapters.md` §2.

#### Scenario: The empty keys keep the built-in Pi launch path

- **GIVEN** a fixture project with `TEAM_PM_CMD`, `TEAM_PM_BIN` and `TEAM_PM_RESUME_ARGS` empty and `TEAM_PI_BIN`
  pointing at a CLI that stays alive
- **WHEN** `team up` starts the PM
- **THEN** the argv of the process recorded in `state/pm.pid` is the built-in one: `<TEAM_PI_BIN> --provider <p>
  --model <m> --skill <skill dir> -c @.pi/team/state/pm-prompt.md`, with no leftover `{` token and no briefing text
- **AND** `team paths` reports the worker adapter as `built-in (Pi)`

#### Scenario: A malformed PM template fails before the window is respawned

- **GIVEN** `TEAM_PM_CMD` is one of `'mycli {sessionid} {prompt}'`, `'mycli { cwd } {prompt}'`, `'   '`, a
  two-line template whose second line is `touch <sentinel>`, or a template using the worker-only `{notify_ext}` /
  `{summary}`
- **WHEN** `team up` runs
- **THEN** it exits non-zero, the message names `TEAM_PM_CMD` and the supported placeholder list (including
  `{resume_args}`), no PM window is respawned, and the sentinel file of the multi-line template does not exist

#### Scenario: An unresolvable PM CLI fails before the start

- **GIVEN** `TEAM_PM_CMD='nosuchcli {prompt}'` and no such executable
- **WHEN** `team up` runs
- **THEN** it exits non-zero naming the resolved binary and `TEAM_PM_BIN`, instead of respawning a window and
  reporting a missing agent afterwards

#### Scenario: A custom PM CLI receives the briefing and runs in the main worktree

- **GIVEN** `TEAM_PM_CMD='fake-pm.sh --pf {prompt_file} --ask {prompt}'` with `TEAM_PM_BIN` pointing at that script
- **WHEN** `team up` starts the PM
- **THEN** the window runs that CLI with its working directory set to the project's main worktree
- **AND** the single argument delivered as `{prompt}` is byte-identical to `state/pm-prompt.md`, and the process
  recorded in `state/pm.pid` is the CLI itself (not the harness shell that outlives it)

#### Scenario: An empty resume setting is reported as not continuing

- **GIVEN** a custom `TEAM_PM_CMD` and empty `TEAM_PM_RESUME_ARGS`
- **WHEN** `team up` starts the PM
- **THEN** the output says the history is not continued and points at `docs/team/**`, `team inbox` and
  `team digest` as the handover
- **AND** with `TEAM_PM_RESUME_ARGS=--continue` and `{resume_args}` in the template, the output reports how the
  session is continued and the arguments really appear in the CLI's argv
- **AND** with the key set but `{resume_args}` missing from the template, the output reports that the arguments
  are not used

#### Scenario: A failed PM start leaves evidence and exits non-zero

- **GIVEN** a custom PM CLI that prints an error and exits 7
- **WHEN** `team up` runs
- **THEN** it exits non-zero and names `state/pm-launch-failed.log`
- **AND** that file holds the rendered command, the resolved binary, `exit   : 7` and the window's last non-blank
  output, and the window is not killed together with the diagnostic
