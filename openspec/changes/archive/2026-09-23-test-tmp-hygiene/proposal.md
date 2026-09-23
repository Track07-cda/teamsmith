# test-tmp-hygiene · proposal

## Why

In 2026-09-22 09:50 `/tmp` — the 15 GB tmpfs every gate shares — was **100 % full: 0 bytes and 4,645 of
3,811,434 inodes free**, and dev3's `panel-p21 choices` printed an **ENOSPC false red** (PM): a verdict about the
code, a cause in the filesystem. The PM measured 607 leaked `config-cli.*` roots / 3,204 MB, 127 `review-*` checkouts
/ ≈6.0 GB and orphan fixture processes; the hand-sweep that followed freed ≈7 GB — a rescue, not a mechanism.

Measured here: all 43 root-creating fixtures already carry a cleanup trap, but **`KILL` cannot run it** — a killed
`config-cli.sh` left a root of **99 MB / 10,954 files** nothing reclaimed (≈349 such roots exhaust the inode table).
`smoke.sh:215` hardcodes `/tmp`, the documented `TEAM_CONFIG_KEEP=1` cannot work, four `teamsmith-flip-*` roots from
09-18/09-19 still sit in `/tmp`, and the `review-*` hand-sweep left **59 stale worktree registrations** of 68 —
re-adding a checkout there fails today.

## What Changes

Added requirements only — `verification` ×5, `watchdog` ×1; nothing modified or removed.

- **`verification`**: fixture roots resolve `${TMPDIR:-/tmp}` in one owned family (`teamsmith-<kind>.XXXXXX`,
  `review-<ID>`) and come from one helper — owner marker, run ledger, reclaim on exit and on `INT`/`TERM` — that
  signals spawned processes only by recorded pid (D37); killed-run residue becomes reclaimable via
  `tests/tmp-hygiene.sh --status | --lint | --sweep` (age plus a proven occupancy scan; exit 3, nothing deleted, if
  the proof fails); the sweep touches only the owned family, prints the `git worktree remove --force` line instead of
  deleting a registered worktree, and refuses a `review-<ID>` root whose record is missing or uncommitted; the gate
  prints its own root's usage and asserts nothing it created outlives it; a lint keeps the rule enforced.
- **`watchdog`**: `team doctor` gains one temp-root headroom line — path, free/total bytes and inodes — warning below
  `TEAM_TMP_MIN_FREE_MB`/`TEAM_TMP_MIN_FREE_INODES`, remedy named, never a deletion.

## What flips

- **Residue**: today a `KILL`ed root is nameless and unreclaimable; after the change `--status` names it and
  `--sweep --age 0` reclaims it, while a live holder is skipped.
- **Guard**: a nested fixture skipping its cleanup leaves the gate green today; after the change the gate fails naming
  that path and the lint reddens on a `/tmp/…` template.
- **Safety**: a hand `rm -rf` of a registered review checkout breaks the next `worktree add`; the sweep prints the git
  line instead.

## Acceptance

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
bash skills/teamsmith/tests/tmp-hygiene.sh --lint
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
bash skills/teamsmith/tests/smoke.sh </dev/null
```

The first line runs now; the rest need the apply commit.

## Boundaries

Out of scope: the CI workflow, the panel, the flip packs' semantics, a `team` fronting, automatic reclamation of
today's legacy-named roots, the smoke's private-tmux design. The apply touches `skills/teamsmith/tests/**` and,
granted by the brief, one doctor row in `scripts/lib/cmd-project.sh` plus doc rows in `references/**` and
`SKILL.md`.

## Evidence the report must contain

The residue reproduction and the sweep of the same root; the occupied-root and registered-worktree refusals; the
gate's usage lines and leak-knob red; the lint's clean and flipped outputs; the doctor row's three shapes; both gate
tails.
