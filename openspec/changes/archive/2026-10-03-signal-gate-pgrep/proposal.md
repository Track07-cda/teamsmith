## Why

P159 blocks `pkill`/`killall`, but an interactive `kill $(pgrep -f …)` still selects by pattern. Two of the three incidents cited in P164 used `pgrep`; the isolated observation reproduces a selector matching its own shell without sending a signal.

**Flip:** break the selector gate into unconditional pass-through → new refusal assertions must fail → restore it. The P164 baseline witness already fails the proposed refusal assertions; it substitutes a recording `kill`, never a real signal.

## What Changes

- **BREAKING:** extend the existing signal gate to `pgrep` and `pidof`; reject PID-producing name/pattern/user selection with exit 64 before resolving or executing a real selector.
- Recommend **A, with a count-only exception**: allow canonical positive-ID `pgrep -g N` and `pgrep -P N`, and full-command pattern counts (`-fc PATTERN`, or separate `-f`/`-c`). Preserve the four single help/version tokens. Refuse other selector shapes, including zero IDs, inversion and added predicates. `pidof` selects by name, so only its single help/version tokens pass.
- Preserve P159's recorded-PID signal route, refusal explanation, audit/retention behavior and unprivileged environment. Add no override.
- Resolve the new tools by their own names, never through a `TEAM_SIGNAL_REAL` pin pointing to `pkill`.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `boundary`: modify **Signals go to a recorded pid, never to a name or a pattern**, retaining all five P159 scenarios. Its effective baseline is currently P159's unarchived delta, not yet the main specification. P159 must be synchronized by the PM before this delta can be archived.

## Impact

Four live call sites across three files remain compatible on their valid path: `common.sh` group liveness, two `panel-cpu.sh` parent queries, and `smoke.sh`'s count-only FAST assertion. The panel's missing-PID fallback to zero is deliberately rejected; it remains a visible startup error. No caller rewrite is needed. Design lists each site and compares A/B/C, including false-positive costs and residual bypasses.

One apply brief can cover the signal shim, two symlinks, focused fixture, launch-resolution smoke assertions and protocol explanation. Do not edit product process selection, the lint policy, configuration schema, other gate families, protected branches or team ledgers. Do not intercept `kill`, `ps` or `fuser`. No sandbox or shell-dataflow guarantee is claimed.

## Acceptance

Planning:

```sh
bash docs/team/reports/P164-verify/pkg/ct.sh openspec validate --all --strict
```

After implementation is committed (runner checks committed HEAD):

```sh
bash docs/team/reports/P164-verify/pkg/ct.sh --checkout bash skills/teamsmith/tests/signal-gate.sh
bash docs/team/reports/P164-verify/pkg/ct.sh --checkout bash -c 'rc=0; bash skills/teamsmith/tests/signal-gate.sh --break=pass >/tmp/p164-red.log 2>&1 || rc=$?; tail -50 /tmp/p164-red.log; test "$rc" = 1 && grep -E "✗.*P164" /tmp/p164-red.log'
bash docs/team/reports/P164-verify/pkg/ct.sh --checkout bash skills/teamsmith/tests/smoke.sh
```

Reports must contain exact commands and output tails, baseline and mutation red sides for the new assertions, restored green, argv/exit-status compatibility witnesses, selector-specific log/retention evidence, and the trial-archive dependency result. Planning evidence is not implementation acceptance.
