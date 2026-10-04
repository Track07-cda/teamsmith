# V2 · Re-verify: `spec-delta-gate` after the F1–F5 rework

```
task:   V2
agent:  verify
phase:  verify
change: spec-delta-gate
deps:   V1 (round one), P2.1 (rework, tip 3987168 on task/P2.1-apply-rework-close-v1-findin)
note:   this is a focused re-verification, not a repeat of V1: you own `pkg/matrix.sh`, so the regression net is yours.
        An independent checkout of the delivered revision is prepared at /tmp/verify-P2.1.
```

## The claim to falsify

The rework says: F1–F5 are closed, and your 44-shape matrix now disagrees with `openspec archive` on **0 rows whose tree
the project gate can reach**. Both halves of that sentence need your own evidence, especially the qualifier — say what
"reachable" excludes and whether the exclusion can hide a real defect.

## Charge

1. **Re-run your own matrix** (`bash docs/team/reports/V1-verify/pkg/matrix.sh`) against the delivered revision and
   diff it against your V1 run (`out/matrix.tsv`). Report: rows that changed, rows where the gate and `archive` still
   disagree, and — for each remaining disagreement — whether `openspec validate` catches the tree first (i.e. the gate
   is never the last line of defence) and what happens at `archive` time if it is.
2. **F1–F5, one by one, with the shape you originally used** (not the author's fixture): does F1 (leading BOM + a name
   the base lacks) now fail at gate time with `delta-modified-requirement-missing`, and does `archive` still abort? Same
   for F2 (a non-delta `.md` under the change's `specs/` tree), F3 (nested capability path), F4 (U+00A0/U+FEFF edge
   characters), F5 (fenced `## MODIFIED`). For F4 state explicitly what `archive` does and that the gate agrees.
3. **New-refusal sweep**: the fix touched parsing paths; try to find *new* cases where the gate refuses what `archive`
   accepts (the dangerous direction for legitimate work). Your V1 matrix plus any shape the F1–F5 fixes suggest (BOM in
   other positions, CRLF + BOM, a BOM'd `## ADDED`, a delta whose first section is not the first line, …).
4. **Unchanged claims**: the six target classes still fail at gate time; the contract (one line per defect, exit 1,
   exit 2 for an unusable root) holds; `openspec/specs/**` is untouched versus the proposal tip; no `TEAM_GATES` change.
5. **Record**: `team review V1.1 --dir /tmp/verify-P2.1 --strong` (the checkout is at the delivered revision) and your
   report `docs/team/reports/V1.1-verify.md`.

## Boundaries

- Do not modify the delivered branch or `openspec/**`; probes belong in scratch copies. Do not push `main`.
- If you find a defect, name it with a reproduction; do not fix it.
