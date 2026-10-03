# spec-rationale-self-contained · proposal

## Why

The public tree ships `openspec/specs/**` and none of `docs/team/**` (the ledger: briefs, reports, reviews,
decisions — `docs/team/tools/publish-public.sh`'s whitelist). Four references in the shipped contract cannot be
opened by the reader who holds it: `verification/spec.md:611`, `:632` and `:672` cite
`docs/team/reports/P52-dev2.md` (§C, findings F2/F4) for the numbers they quote, and
`notify-and-inbox/spec.md:105` cites the captured frame
`docs/team/reports/P61-dev3/logs/15b-one-line-draft-frame.log`. Beside them, 135 tokens of the maintainers' record
ids (`P/M/D/V/E/F`) stand in six spec files (`V9-B5`, `D37`, `M49`), where a fixture row (`M39`) and a real
milestone are indistinguishable.

Neither is a leak and no scenario is un-runnable: the rationale is what does not hold up. The other 83
`docs/team/` references are the skill's own vocabulary; the counts are in `recon.log` and `design.md`.

## What Changes

- **ADDED — `boundary#Specs are the contract`** (this task's delta): evidence belongs in the spec's text, a
  `docs/team/…` reference must be declared (one row with its basis in
  `skills/teamsmith/tests/spec-ledger-refs.tsv`, and a slot row never allows a concrete path), and the record ids
  stay only under an `Id families:` line naming every family the text uses. The gate judges the text the archive
  will write: a citation a pending change retires is reported by name, one nothing retires is red.
- **The apply** (another agent; grants in `tasks.md`): the four citations become self-contained sentences with
  their numbers kept, `spec-refs.sh` implements the walk with two-directional flips, a gate section runs it, and
  `references/openspec.md` states the authoring rule.

## Capabilities

### Modified Capabilities
- `boundary` — the new promise. `verification`, `notify-and-inbox` — the apply retires the citations in three
  requirements; each MODIFIED block keeps every baseline scenario (drafted and proven in
  `docs/team/reports/P145-dev2/deltas/`).

## Impact

`openspec/specs/{boundary,verification,notify-and-inbox}`; new `skills/teamsmith/tests/spec-refs.sh` and
`spec-ledger-refs.tsv`, one gate section with its budget/paths rows, one paragraph in `references/openspec.md`.
Untouched: the scenarios and the commands they run, `scripts/**`, the panel, tmux.

## What flips

- **The walk sees the defect**: `--root` a copy whose `openspec/changes/` is empty exits non-zero naming the cited
  path and its line; this tree exits 0 with the citations reported as retired. A permissive matcher must not pass
  them by matching `docs/team/reports/<ID>-*.md` — the dry run's first matcher did (`dryrun.log`).
- **The table is calibrated**: 41 rows cover 83 of the 87 triples; the 4 undeclared are line-for-line the citations
  this change retires; after the rewrites, 0 remain. Deleting the `Id families:` line, or dropping `F<n>` while the
  text uses `F2`, exits non-zero naming the family.
- **The retirements are proven** (`trial.log`): the drafted MODIFIED blocks keep every baseline scenario (4/4,
  2/2, 3/3), validate is green, a dropped scenario reddens it, and a scratch `archive -y` applies `+1, ~3` with the
  citations gone.

## Acceptance

```sh
# runs now (propose)
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict

# the apply commit must additionally pass these
bash skills/teamsmith/tests/spec-refs.sh --check
bash skills/teamsmith/tests/spec-refs.sh --flips
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
bash skills/teamsmith/tests/smoke.sh </dev/null
```

## Boundaries

Planning only for everything but this task's delta: this task writes
`openspec/changes/spec-rationale-self-contained/**` and its report. The apply needs the brief's grant for
`openspec/changes/spec-rationale-self-contained/specs/{verification,notify-and-inbox}/spec.md`,
`skills/teamsmith/tests/**` and `skills/teamsmith/references/openspec.md`; it must not weaken a scenario, rename a
reference the declared table allows, touch `skills/teamsmith/scripts/**`, or widen the walk past
`openspec/specs/**`.

**Anchor finding**: the brief names `boundary#Specs are the contract`, but no such requirement exists today
(`grep -rn 'Specs are the contract' openspec/` matches only the brief), so this change adds it; nothing in the
baseline is modified by this task's delta and no baseline scenario can be lost.

## Evidence the report must contain

Propose: the validate tail, the delta→requirement map, the inventory counts (`recon.log`), the dry run and the
trial (`dryrun.log`, `trial.log`). Apply: the walk's red and green tails, the `--flips` output, both gate tails.
