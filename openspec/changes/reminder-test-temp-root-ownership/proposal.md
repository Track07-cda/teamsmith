## Why

The two Reminder test drivers still create work outside the existing fixture-root lifecycle. With no evidence
directory requested, the real-Pi driver leaves scene logs after ordinary completion; the fault driver uses a
fixed base even when the caller specifies a different temp directory. P484 also found that the smoke suite
and direct callers use explicitly retained `run-*` files to inspect actual test state, so moving those files
would remove evidence that existing reviews use.

## What Changes

- Use the existing fixture-root helper for both drivers' default work. Keep caller-owned evidence and requested
  retained work available on success and failure, including the existing real-Pi `run-*` layout when kept.
- Use the same real-Pi lifetime for shell and direct Node calls; the recovery shell already runs that driver
  and stays unchanged. Use the existing root helper for the fault test as well. Keep both isolation checks,
  the real-Pi test's private tmux and its controlled loopback provider.
- Do not change Reminder product code, scenarios, selectors, regular test results, the smoke suite's three
  explicit evidence paths, or the general root naming and cleanup rules. No historical directory sweep,
  live-team operation, new process manager or additional suite section.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `verification`: describe the work/evidence distinction for these two tests, under the existing fixture-root
  requirement.

## Impact

Apply would touch five files under `skills/teamsmith/tests/`: the two Node drivers and three shell entry
points. `design.md` identifies them; `tasks.md` checks retained evidence and default cleanup, with one
interruption at a live private pane and one during an active fault command. This proposal does not
implement or execute those checks.
