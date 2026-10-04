# V4 · Final verify: `spec-delta-gate` after P2.4 (symlinked change dir + realpath generalization)

```
task:   V4
agent:  verify
phase:  verify
change: spec-delta-gate
deps:   V3 (round three), P2.4 (tip 0a01735 on task/P2.4-apply-rework-4-close-f-v3-1-)
note:   the exit criterion from D17's addendum is in reach: zero reachable disagreements. You confirm or falsify it.
```

## Charge

1. **F-V3-1 closure** with your own shapes: a symlinked `changes/<id>` (target outside the repo; and, if the archiver
   has a distinct behaviour for an in-repo change-dir link, that spelling too) through all three arbiters. The PM's
   probe: gate rc=1 `delta-change-dir-symlink` naming the archiver's own code, validate green (the gap that was),
   archive refuses. Reproduce or refute.
2. **Attack the realpath generalization** (the code resolves every path it walks once): link loops at the change-dir
   level, a change dir that is a symlink chain (link → link → dir), a relative change-dir link escaping to a sibling
   of `changes/`, a `changes/` root that is itself a symlink (what does archive do? the gate must agree), and a
   change dir link whose target contains a *valid* change (does the gate still refuse? what does archive do?).
3. **The full net one last time**: your 44-shape matrix + the symlink harnesses (V1's `pkg/matrix.sh` as restored,
   P2.2's 14-shape) against `0a01735`; diff against your V3 tables; state the final count: reachable disagreements,
   and for each remaining one whether validate is the earlier arbiter.
4. **Unchanged claims**: contract (one line per defect / exit 1 / exit 2), `openspec/specs/**` untouched, no
   `TEAM_GATES` change, the §16 guard-not-theatre fixtures still red-without-the-rules.
5. **Record**: `team review V4 --dir <checkout> --strong` on `0a01735` + `docs/team/reports/V4-verify.md`.

## Boundaries

Read-only on the delivered branch; probes in scratch copies; never `openspec/**`; do not push `main`.

## Acceptance

```sh
openspec validate --all --strict
bash skills/teamsmith/tests/spec-lint.sh
bash skills/teamsmith/tests/smoke.sh
```
