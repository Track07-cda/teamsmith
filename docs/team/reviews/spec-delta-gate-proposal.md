# spec-delta-gate · PM proposal review

```
change:  spec-delta-gate        phase:  propose        task: P1 (agent: dev2)
reviewer: pm                    verdict: **ACCEPTED**
```

The PM's recorded review of the change artifacts, the gate between `opsx-propose` and the first `opsx-apply` task
(`skills/teamsmith/references/openspec.md` §4). No apply task may be dispatched before this verdict is ACCEPTED.

## Commands run (real output, not a promise)

```console
$ openspec change show spec-delta-gate
## Why  `openspec validate --all --strict` and `openspec archive` disagree about the same delta …   (read in full)

$ openspec validate --all --strict
✓ spec/watchdog
Totals: 9 passed, 0 failed (9 items)          # the active change is included and validates

$ bash skills/teamsmith/tests/spec-lint.sh
spec-lint: OK — 9 spec file(s), 46 requirement(s), 86 scenario(s) under openspec

$ bash skills/teamsmith/tests/smoke.sh        # on the proposal branch
  ✗ lint 报的 requirement 数与真树一致（45）(… spec-lint.out 中找不到 [45 requirement(s)])
  ✗ lint 报的 scenario 数与真树一致（77）(… 找不到 [77 scenario(s)])
== 结果 ==  ✓ 1157 ✗ 2                            # exactly the two §16 count assertions, as the proposal states

# the PM's own probe of the claim P1 corrected in E1 (dropped-scenario class):
$ # constructed a MODIFIED delta for `dispatch` that omits its last scenario, then:
$ openspec validate --all --strict
Totals: 9 passed, 1 failed (10 items)
Details: openspec validate probe-drop --type change   # ⇒ validate DOES refuse it; E1 §4.2 was wrong, P1 is right
```

## Findings, one line per checklist item

1. **Matches the approved exploration (D15, option D → C0)** — yes, and it goes further: it re-probed E1's claims
   instead of copying them, and corrected one. The scope stays on the *name-typo/rename class* that only `archive`
   catches (MODIFIED naming a missing requirement, ADDED colliding, RENAMED source/target, operation on a capability
   with no base spec). No scope creep; E1's `doctor`/`TEAM_PI_BIN` defect is explicitly left to its own change.
   **The correction is verified by the PM** (probe above) and is now recorded in D15.
2. **Observable** — the delta requirement names six stable rule codes and its scenarios assert
   `exits 1 and prints <delta file>:<line>: <rule>: …`; nothing describes internals. The tolerated cases (absent
   `REMOVED`, already-applied `RENAMED`, fenced code) are stated as behaviour, so the checker cannot drift into being
   stricter than `openspec archive` without a red scenario.
3. **Coverage closed both ways** — every rule has a red fixture (tasks 3.1) and a green control (3.2); no orphan task
   items (2.1 is a no-op confirmation with a stated reason, 2.3 fixes the two count assertions, 4.1 is the doc).
4. **Boundaries explicit** — `## Boundaries` lists what is out of scope (intra-delta contradictions; the unrelated
   doctor defect) and the hard one: **`openspec/specs/**` must not change before archive** ✓ (that is the rule that
   keeps a delta from silently rewriting the base spec).
5. **Acceptance commands** — the three standard commands, verbatim, all runnable today; two are green on this branch,
   and the third's two reds are documented and assigned (see 8).
6. **Flip / red evidence** — present up front: the CLI probe matrix (`docs/team/reports/P1-dev2/pkg/cli-matrix.sh`)
   demonstrates the class the gate is about, and the proposal states the current smoke result and that all three gates
   must be green before apply is done.
7. **No conflict with existing specs** — the new requirement is an `ADDED` sibling of `memory-and-deps`' existing
   "An invalid spec fails the project gate", and the proposal says why not `verification` (that capability owns how a
   review runs, not what a valid delta is). Checked `openspec/specs/**` for a duplicate: none.
8. **Granularity** — one apply cycle: one checker file, one smoke section, one doc paragraph, plus the test-only count
   fix. The proposal branch being red on those two count assertions is **accepted** here: a propose phase may not edit
   tests (its boundary), the failure is documented rather than hidden, and it is an explicit apply task.

## Conditions attached to this ACCEPTED verdict (bind the apply brief)

- The apply brief must **grant the doc edit** for `skills/teamsmith/references/openspec.md` (tasks 4.1 flags it as
  PM-owned and asks for the grant) and must repeat "`openspec/specs/**` unchanged".
- All three gates green on the apply branch, including the §16 count-assertion fix (tasks 2.3).
- The "guard, not theatre" item (3.3: with the rules removed from a copy of the checker, the red fixtures must fail)
  is required, and the **verify phase must reproduce it independently** rather than read it from the report.
- If the checker's behaviour and `openspec archive`'s disagreement changes during apply (e.g. a tolerated case turns
  out not to be tolerated), that is a finding to report, not a silent relaxation.

## Next phase

Apply (phase 3) to a **dev** agent: `P2` — see the brief written from this review.
