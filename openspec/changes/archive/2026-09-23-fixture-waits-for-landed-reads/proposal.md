# fixture-waits-for-landed-reads · proposal

## Why

Two gate fixtures hand a code verdict to a data state that has not landed yet, and one measures whichever
worktree it was called from.

- `panel-p21.sh` (settings view, the hand-edited-bool scenario) waits only for the **group-heading skeleton**,
  sleeps a fixed `0.5 s`, presses Enter and asserts the picker's entry — but the view's entry read is
  asynchronous and the picker is a one-shot snapshot, so a slow read becomes a *code* verdict: **5/5 red under a
  2-CPU quota** (`✓ 108 ✗ 3`), injection 0 s → `✓ 110 ✗ 0` / 6 s → `rc=1`, and **a 5× horizon does not help**
  (P52 §C; D43).
- `panel-b3.sh`'s `collapse` scene samples the console **once** after `sleep 5` (and once after `sleep 6` for the
  restore): **4 of 6 runs red** on a loaded host (P52 F2).
- `panel-cpu.sh` measures the **caller's worktree**: 3683 ms here against 391 ms from a fresh project, one past
  its ~3 s polling budget → `rc=2` (P52 F4) — the same command, two conclusions, same machine, same code.

## What Changes

Added requirements only — two `verification` requirements; nothing modified or removed, so no collision with the
open changes that modify `verification#The correctness gate judges correctness only` (design §4).

- **A data-derived assertion observes the state it asserts**: before a fixture asserts a state the console
  derives from an asynchronous read, it must observe **that state** on a settled frame with a bounded wait (the
  row already showing the hand-edited value), never a skeleton marker and never `sleep N` + one sample. The wait
  is counted and attributed at its cap, and it must not become a wall-clock/CPU-share red line (D33): a read that
  lands slowly inside the bound stays green.
- **A measuring fixture measures a fixed tree**: a fixture whose number is a verdict measures a neutral
  reference project it fixes itself and names the measured root and the revision under test, so two checkouts
  reach the same conclusion.

Coverage: `panel-p21.sh`'s settings scenarios (the hand-edited-value family), `panel-b3.sh`'s `collapse` scene,
and `panel-cpu.sh` with the premise fixture and the performance suite that drive it.

## Flip

Red before: with the settings read delayed by a scratch wrapper the current fixture is `✓ 108 ✗ 3` and the
`collapse` scene is 4/6 red after a fixed single sample; the measurement fixture measures the caller's tree
(3683 ms vs 391 ms). Green after: the same delayed read is **observed** (the fixture waits for the row to carry
the new value before it opens the picker) and the scene green; the collapsed console is awaited by polling inside
a bound; and the measurement names one fixed root and reaches one conclusion from either worktree. Break-it: put
the fixed `sleep` + single capture back and the delay injection reds again.

## Boundaries

Propose only: no `skills/**` change in this task. Out of scope: the picker's snapshot semantics (D43 keeps them),
any console-side "read landed" signal, the read-latency/cgroup-quota topic (D43 item 3), the gate's section
budgets and the wait inventory (`gate-section-accounting` owns them), the pty premise/extension engine
(`pty-fixture-load-premise`), the perf thresholds (unchanged), and the CI workflow. The apply touches
`skills/teamsmith/tests/**` only, with the files named in the tasks file; `openspec/**` and `docs/team/**` stay
with the phase's owner.

## Acceptance

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
bash skills/teamsmith/tests/panel-p21.sh choices
bash skills/teamsmith/tests/panel-b3.sh collapse
bash skills/teamsmith/tests/panel-cpu.sh
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
bash skills/teamsmith/tests/smoke.sh </dev/null
```

The first line runs now; the rest are the change's own proof and need the apply commit (the pre-change numbers
above are their red side).

## Evidence the report must contain

The delayed-read injection with its raw tails (old shape red, new shape green after the read lands); the
never-lands run naming the wait at its cap; the collapse scene's delayed-console run (pre/post); the two-worktree
measurement with both printed roots and verdicts; and the gate tails with `git status --porcelain` clean.
