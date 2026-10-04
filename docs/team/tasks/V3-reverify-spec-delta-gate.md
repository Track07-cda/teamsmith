# V3 · Re-verify: `spec-delta-gate` after the symlink rework (P2.2 + P2.3)

```
task:   V3
agent:  verify
phase:  verify
change: spec-delta-gate
deps:   V2 (round two), P2.3 (tip 9ad284c on task/P2.3-apply-rework-3-escaping-syml)
note:   focused third round. The PM's probes (escape file link / escape root link / in-tree legit link) are recorded
        in DECISIONS "D17 勘误" — your job includes judging that dispute independently.
```

## Charge

1. **Confirm closure of V2's F-V2-1** with your own original shape (in-tree symlinked `spec.md`): gate rc=1 with the
   right code; archive aborts.
2. **The escape family, both shapes**: (a) a `spec.md` symlink resolving outside the change's `specs/` tree → the gate
   must refuse with `delta-symlink-escape` (rc=1); (b) a `specs/` root link resolving outside the change directory →
   same. Green controls: in-tree legit symlink rc=0; broken link stays ignored (archiver's behaviour is the
   reference — state what it does).
3. **Judge the dispute independently.** The PM claimed (D17 再补记, now corrected) that validate is green for escaping
   file links; the implementer (P2.3 report §3.3) measured validate red for that shape and green only for the
   root-link shape. Run both shapes through all three arbiters yourself (`validate`, gate, `archive`) and state which
   account your measurements support. This matters: the change's requirement text must describe reality.
4. **Regression net**: re-run your own 44-shape matrix plus P2.2's 14-shape symlink harness against the delivered
   revision; report the disagreement count, and diff against your V2 tables (rows that moved, rows that still
   disagree, and for each whether the tree is validate-red first).
5. **New-surface sweep**: the touched code is link discovery (`find -H`, `-xtype`, `readlink -f`). Attack it: relative
   escapes (`../../..`), links to directories, link loops, a link whose target changes between discovery and read
   (state whether that's practically testable), a `spec.md` that is a hard link (not a symlink) to an outside file —
   does either arbiter see it?, and a nested-capability path under a symlinked root.
6. **Record**: `team review V3 --dir <checkout> --strong` on the delivered revision (`9ad284c`) +
   `docs/team/reports/V3-verify.md`.

## Boundaries

- Read-only against the delivered branch; probes in scratch copies only. Never modify `openspec/**` or the verifiers'
  evidence dirs; do not push `main`.

## Acceptance

```sh
openspec validate --all --strict
bash skills/teamsmith/tests/spec-lint.sh
bash skills/teamsmith/tests/smoke.sh
```
