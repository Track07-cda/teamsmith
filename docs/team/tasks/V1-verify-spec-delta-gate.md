# V1 · Verify: `spec-delta-gate` (C0) — differential verification against `openspec archive`

```
task:   V1
agent:  verify
phase:  verify
change: spec-delta-gate
deps:   P2 (apply, ACCEPTED proposal) — branch tip 524c6a4 on task/P2-apply-spec-delta-gate-c0-che
```

> Pipeline phase 4 (`opsx-verify`). You are the **independent** verifier: you did not explore, propose or implement
> this change. Your job is to try to falsify it, not to confirm it. A record that only re-states the author's report
> is not verification (creed: *a delivery is accepted only when an independently reproducible check supports it*).

## What the change claims

`skills/teamsmith/tests/spec-lint.sh` gains a delta-applicability check that refuses, at **gate time**, the delta shapes
`openspec archive` refuses at **phase 5** (six rule codes:
`delta-modified-requirement-missing`, `delta-dropped-scenario`, `delta-added-requirement-exists`,
`delta-renamed-source-missing`, `delta-renamed-target-exists`, `delta-operation-on-new-capability`), while staying
green for every delta `openspec archive` accepts. Implementation: bash + awk; contract: one
`<file>:<line>: <rule>: <detail>` line per defect, exit 1; exit 2 for an unusable root unchanged.

## The verification charge (do these, in this order)

1. **Gates on an independent checkout.** `team review V1 --dir <checkout> --strong` from a clean checkout of the
   branch tip (the PM prepared one at `/tmp/verify-P2`; create your own if you prefer). Paste the result lines.
2. **Differential test — the heart of it.** Build a matrix of delta shapes and compare the two arbiters
   (`spec-lint` versus `openspec archive`) on each, in a scratch copy of the repository (**never** in the real tree):
   - the six classes the change targets (must fail at the gate, and `archive` must agree);
   - shapes `archive` accepts and the gate must therefore accept: a legitimate `ADDED`, a legitimate `MODIFIED`
     restating all base scenarios plus one, an `ADDED` for a capability with no base spec, a `REMOVED` of an existing
     requirement, a `RENAMED` whose source exists and target does not, this change's own delta while the change is
     active;
   - **adversarial shapes you invent**, aiming to break the checker: a requirement name differing only by trailing
     whitespace or a tab; a name differing by Unicode normalisation (NFC/NFD) or a non-breaking space; a scenario name
     repeated inside the base; a `MODIFIED` that drops one scenario and adds a differently-named one (a rename — is
     that a drop? what does `archive` do?); `## MODIFIED Requirements` appearing inside a fenced code block; a delta
     file with CRLF endings; a delta for a capability that exists but with an empty base; two delta files touching the
     same requirement.
   For every row: the two verdicts (gate, archive) and whether they **agree**. **Disagreements are findings** —
   report them with the exact reproduction, including the case where the gate is *stricter* than archive (that would
   block a legitimate archive and is just as much a defect).
3. **"Guard, not theatre".** Reproduce it yourself: copy `spec-lint.sh`, remove the new rules, and show the red
   fixtures from smoke §16 now fail to fail (i.e. the fixtures are actually testing the new code). Then restore.
4. **Scope honesty.** Confirm `openspec/specs/**` is untouched on the branch (`git diff --name-only` against the
   proposal tip `82bf656`) and that no `TEAM_GATES` change was smuggled in.
5. **The counts fix.** The proposal branch was red on two §16 real-tree count assertions; verify they are green now
   **and** that they were fixed in the honest direction (the expected numbers moved because the change adds a delta,
   not because the assertion was loosened to a substring that matches anything).
6. **Boundaries.** The doc edit was granted for `references/openspec.md` only — confirm nothing else under
   `references/` or the CLI changed beyond the change's stated impact.

## Output

- `docs/team/reports/V1-verify.md`: the matrix (one row per shape, with both verdicts), the findings (each with a
  reproduction and the expected/actual), the guard-not-theatre transcript, and an explicit list of anything you could
  **not** determine.
- The review record via `team review V1 --dir <checkout> --strong` (verdict + evidence).
- If you find a defect: say plainly what must change; do not fix it yourself (you are not the implementer).

## Boundaries

- Do not modify the delivered branch, `openspec/**`, or the ledger; work in scratch copies for the probes.
- Do not push `main`, do not open a PR.

## Acceptance

```sh
openspec validate --all --strict
bash skills/teamsmith/tests/spec-lint.sh
bash skills/teamsmith/tests/smoke.sh
```
