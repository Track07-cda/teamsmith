## Why

P481 established that the §51 help test's fake terminal never returns a pane frame. If `team perf --host` reaches the frame wait, it cannot measure there. The help test compares project state but ignores the command's exit status, so a timeout or early return with unchanged state can also pass. V174's 705 seconds cover the whole section and cannot be allocated to either command.

## What Changes

- Replace only the help claim for `team perf --host` that currently attempts a measurement. Run the real CLI against the same scratch project, using a private copy of the entry source whose measurement target is a short recorder. Check actual handoff, arguments, working directory, exit status and the original six project fingerprints.
- Report this as an entry check, not a measurement. It replaces the single existing check and does not add a new skip, guard, performance budget or configuration.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `verification`: under **A gate that cannot judge says so**, name this one replacement and exactly what it does and does not show. The existing separation of performance from correctness remains unchanged.
- `help-surface` remains applicable without a delta: the claim still uses the real CLI and compares the project's fingerprints; text or a source read alone is not proof.

## Impact

A later authorized apply changes only the dedicated `perf` case in `skills/teamsmith/tests/help-surface.sh`; this proposal changes no code. Leave `team smoke --select 0`, all other help checks, the CLI and performance implementation, formal timeouts and the existing independent real measurement unchanged. Do not claim the real measurement leaves the calling project unchanged throughout: the new check does not exercise its setup or execution, and the independent measurement is not evidence of that property. If that property needs new proof, report the gap before proposing separate work. No elapsed saving is promised.
