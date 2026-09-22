# trust-prompt-and-fixtures · proposal

## Why

P40 (`team init` installs the project's skills into `.pi/skills/`) created a real UX side effect that surfaced as
a gate red. `skills` is one of the project resources Pi's trust list contains (0.86.0 and 0.87.0), so the first
interactive `pi` run in a freshly provisioned project shows Pi's project-trust prompt (`Trust project folder?` …
`Do not trust`). §31b2 opens real Pi exactly there; the prompt has no input box, and the fixture's `EMPTY`-only
check reports it as a dirty draft. Measured on the real frame: the judgement locates no box below the cursor
(`UNKNOWN`); with the cursor inside the prompt it pairs the prompt's own rule rows and reads the question and
options as box content (`BUSY`) — both print `idle-read=NOT-EMPTY BAD`. P54 ruled this F2 and the PM verified the
attribution matrix. Two things are missing: a fixture that can tell an overlay from a draft, and an install that
tells the user the prompt is coming.

## What Changes

- **ADDED — `verification`** (*A fixture's input-box judgement distinguishes an unexpected overlay*): readiness
  releases only on a locatable empty box, not on any full-rule row; an overlay is named
  (`overlay=trust-prompt`), fails the fixture **without typing into it**, and never prints `idle-read=NOT-EMPTY`.
  The real-pane fixture reaches the empty box in a project `team init` provisioned (`.pi/skills/` stays installed)
  by starting Pi with the single-run trust override, so no interactive decision is required and Pi's trust store
  is not written. A stored real frame plus a predicate-disabled red side make the classification falsifiable in
  FAST.
- **ADDED — `init-skill`** (*The project-local install names Pi's trust consequence*): the install step prints
  one line naming the prompt and its three answers (`pi --approve` for one run, `/trust` to save,
  `team init --no-skills` to skip) through the one implementation both `team init` and `team bootstrap` call —
  silent when nothing is installed. The `teamsmith-init` skill's install beat and `references/bootstrap.md`
  carry the same fact.

## Flip

Red before (frame-level, after the judgement lands): the stored trust-prompt frame under the old `EMPTY`-only
check prints `idle-read=NOT-EMPTY` and exits 1 — `M24_OVERLAY_DETECT=0` reproduces that red. Green after: the
same frame prints `overlay=trust-prompt` and exits 0. Real pane: `pm-box-real.sh --idle-secs 3` goes from rc=1
(`M45 idle-read=NOT-EMPTY BAD`) to rc=0 (`idle-read=EMPTY ok`, `RETRACT=ok`).

## Boundaries

Planning only (policy B: the rules land as deltas). Out of scope: the delivery guard's own overlay behaviour
(`outbox.sh` is not touched — this change fixes the fixture's judgement, not the guard's verdict), Pi's trust UX
itself, `install-shape.sh`'s existing install contracts, and §31b2 itself (not skipped: it keeps running the
real-pane fixture). Apply may touch only `skills/teamsmith/tests/**`, `skills/teamsmith/scripts/lib/cmd-init.sh`
(PM-owned; the brief must grant it), and `skills/teamsmith-init/**`; `openspec/**` stays with the phase owner.

## Acceptance

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh </dev/null
```

(The third line is the full gate, once before delivery.)

## Evidence the report must contain

Both acceptance tails; the stored frame's provenance and its two judgements (predicate on → overlay, off → red);
the real-pane run's `idle-read=EMPTY ok`/`RETRACT=ok` tail and the §31b2 container tail; the init/bootstrap
output lines (fresh, `skip`, `--no-skills`); and the paths the diff touched.
