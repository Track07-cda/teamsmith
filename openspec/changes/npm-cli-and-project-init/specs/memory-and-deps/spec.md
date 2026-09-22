## ADDED Requirements

### Requirement: The shell the CLI runs on is a checked dependency, not an assumption

The npm entry point SHALL verify its shell before it runs any part of the CLI: when `bash` cannot be resolved,
or the bash it resolves is older than major version 4, the wrapper SHALL print the concrete fix — naming the
missing or too-old shell, the found version where there is one, the `bash >= 4` minimum and where the
prerequisite is written down — and SHALL exit non-zero without running the CLI. The check SHALL resolve `bash`
the same way the CLI itself would (`bash` on `PATH`), so the message names the shell that would actually run the
tool, and it SHALL NOT introduce a `TEAM_*` knob or a degraded mode (a missing shell has no fallback). When the
shell resolves and is at least 4, the wrapper SHALL run the CLI unchanged — same argv, same stdio, same exit
status.

#### Scenario: No bash at all fails with the fix

- **GIVEN** a `PATH` with no `bash` on it, and the wrapper invoked through an absolute `node` so only the shell
  lookup can fail
- **WHEN** the wrapper runs `version`
- **THEN** it exits non-zero, names `bash`, names the `4` minimum and prints the fix line, and its output does
  not contain a `teamsmith` version line

#### Scenario: An old bash is named with its version

- **GIVEN** a `bash` earlier on `PATH` that answers the wrapper's version probe with `3` and otherwise delegates
  to the real bash
- **WHEN** the wrapper runs `version`
- **THEN** it exits non-zero and its message names the found major version `3` and the required `4`
- **AND** the CLI itself never ran (the output carries no `teamsmith` version line)

#### Scenario: A working shell runs the CLI unchanged

- **GIVEN** a `PATH` whose `bash` is the machine's own
- **WHEN** the wrapper runs `version` and `help`
- **THEN** both exit 0, the `version` output is the same `teamsmith <version>` line the bash CLI prints, and the
  `help` output is byte-identical to the bash CLI's
