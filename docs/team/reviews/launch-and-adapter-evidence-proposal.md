# launch-and-adapter-evidence · PM proposal review

```
change:  launch-and-adapter-evidence   phase:  propose        task: P3 (agent: dev2)
reviewer: pm                           verdict: **ACCEPTED**
```

The recorded review of the change artifacts, the gate between `opsx-propose` and the apply task
(`skills/teamsmith/references/openspec.md` §4). No apply task may be dispatched before this verdict is ACCEPTED.

## Commands run (real output, not a promise)

```console
$ openspec validate --all --strict        # on the P3 branch checkout /tmp/rev-P3
Totals: 9 passed, 0 failed (9 items)
$ bash skills/teamsmith/tests/spec-lint.sh
spec-lint: OK — 11 spec file(s), 56 requirement(s), 115 scenario(s) under openspec
  (8 base specs + 3 delta files; 45+11 requirements; 77+38 scenarios — the arithmetic checks out)
$ # scratch copy of the branch, then:
$ openspec archive -y launch-and-adapter-evidence
  Applying changes to openspec/specs/agent-adapters/spec.md: + 3 added
  Applying changes to openspec/specs/dispatch/spec.md:       + 2 added, ~ 2 modified, - 1 removed
  Applying changes to openspec/specs/pm-lifecycle/spec.md:   + 3 added
  Totals: + 8, ~ 2, - 1 — Specs updated successfully.
$ grep -c "adapter template contract" openspec/specs/dispatch/spec.md openspec/specs/agent-adapters/spec.md
  openspec/specs/dispatch/spec.md:0        openspec/specs/agent-adapters/spec.md:1   # the move is clean
```

## Findings, one line per checklist item

1. **Matches the approved exploration (D18)** — three delta files, nine rows, one apply brief; the ordering binding is
   in tasks.md (dispatch → agent-adapters → pm-lifecycle → evidence; verify owns 4.5 and re-runs all).
2. **Observable** — every requirement maps to a runnable falsifier (E2 §5's table carried into the scenarios); the
   MODIFIED blocks are additive (base scenarios restated: "A brief is self-contained…" 2→3, "One task branch per
   task" 2→3, zero dropped — verified by diffing the delta against the base spec myself).
3. **Coverage closed both ways** — tasks 1.1–3.3 map to every requirement; every scenario names its falsifier.
4. **Boundaries explicit** — out-of-scope named (general `team up`/`resume` contract, watchdog delta, C0/C2/C3 rows);
   `openspec/specs/**` untouched.
5. **Acceptance commands** — verbatim, and the archive probe is one I re-ran on a scratch copy (result above).
6. **Flip** — this is a backfill (no defect fix); the proposal states the three verification layers instead
   (applicability, migration diff, falsifier injection), which is the correct substitute per D18.
7. **No conflict with existing specs** — the REMOVED entry names an existing requirement with proper `**Reason**` and
   `**Migration**`; the migration target preserves all four base scenarios (checked: zero missing); the two ADDED
   names do not collide with base.
8. **Granularity** — one apply cycle with ordered sub-tasks, per D18's binding condition.

## Decisions taken at this gate

- **A2's observable surface: accepted.** The "default Pi path is byte-identical" promise is stated over `team up` in a
  fixture project + the argv recorded in `state/pm.pid` (falsifier: smoke §11b2), with the fast render comparison
  (§6i) kept as the net. No internal function names, no test-only strings — as required by `openspec/config.yaml`.
- **W2 correction confirmed applied**: pm-lifecycle's spec states the six real states and says explicitly "in
  particular no `busy`" (line 74) — the correction is present, not just absent.
- **Sequencing recorded**: the apply task (P4) is dispatched only when (a) `dev` is free (D16 — no stacking) and
  (b) C0's checker has merged into main, so C1's deltas ride the delta-applicability gate at apply/verify time.
  C0 is one rework (P2.3) + one verification round (V3) away.

## Next phase

Apply (phase 3), agent `dev`, task P4 — one brief, ordered sub-tasks, conditions above.
