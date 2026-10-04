# P191 · Independent re-verification of strict spec-reference declarations

agent: verify   status: PARTIAL   verdict: scope PASS / delivery BLOCKED   time: 2026-10-03T00:58Z
branch: `task/P191-verify`   PR/MR: - (local mode)
change: `spec-rationale-self-contained`
source examined: `61aa78590b33a2c37e88911ba994c79a8a36138e`

## Deliverables

| Path | What |
|---|---|
| `docs/team/reports/P191-verify/pkg/check.py`, `run.py` | Independent table mutations and two actual source-shadow assertion failures; no product `--break`/`--flips` seam used for this evidence |
| `docs/team/reports/P191-verify/pkg/counts.sh` | Historical exports explain 99 versus 101 references |
| `docs/team/reports/P191-verify/pkg/gates.sh` | Serial container validation, selected 18c and FAST against a standalone clone |
| `docs/team/reports/P191-verify/pkg/logs/` | Original commands, outputs, exit codes, source hashes and recovered historical P184 report |

No implementation/spec/task edits, branch switch, remote operation, merge, real archive or host tmux probe. Local branch retained. Rebuildable `.checkout/` and `.scratch/` are ignored.

## Summary

| Dimension | Assessment |
|---|---|
| Completeness | Change artifacts list 22/22 completed tasks. This brief rechecks P185's F1/F2, not every historical apply claim. All required independent mutations and both shadows executed. |
| Correctness | 16 original assertions pass. Invalid table rows fail at load with filename, exact physical line 79 and full row text; the one-character concrete near-miss is undeclared. Both independent shadow assertion processes fail, then pass against the restored original. |
| Coherence | Implementation `spec-refs.sh:86–126` enforces the amended table contract; `:133–143` uses character equality for concrete ledger/example references. Legitimate slots and literal rows remain green. |

**F1 and F2 are closed by independent evidence.** No new in-scope finding. Overall acceptance is not PASS: the dispatch baseline already has two failing OpenSpec changes outside this grant.

## Verification evidence

Actually run from this worktree:

```sh
python3 docs/team/reports/P191-verify/pkg/run.py
bash docs/team/reports/P191-verify/pkg/counts.sh
bash docs/team/reports/P191-verify/pkg/gates.sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
PATH="$HOME/.bun/bin:$PATH" openspec validate delivery-truth --type change
PATH="$HOME/.bun/bin:$PATH" openspec validate pulse-nudge-key --type change
```

### Independent mutations

The package invokes the real `bash skills/teamsmith/tests/spec-refs.sh --check --root <own-tree> --table <own-copy>` each time. It asserts both the exit code and diagnostic content, and requires no `judged` line for load failures.

| Case | Actual checker result | Evidence under `pkg/logs/original/` |
|---|---|---|
| Undeclared control `docs/team/reports/P191-adversary.md` | exit 1; exact `undeclared` file:line:path | `01-wildcard-control.log` |
| Append `docs/team/reports/P191*.md`, kind `ledger` | exit 2; `declarations.tsv:79`, full row; no walk | `02-wildcard-ledger.log` |
| Append `docs/team/reports/P191-<agent>.md`, kind `example` | exit 2; same load-time diagnostic contract | `03-placeholder-example.log` |
| One column / two columns | each exit 2; exact table/line/row | `04-missing-columns.log`, `05-missing-basis-column.log` |
| Empty / whitespace-only basis | each exit 2; exact table/line/row | `06-empty-basis.log`, `07-whitespace-basis.log` |
| Invalid uppercase kind `LEDGER` | exit 2; exact table/line/row | `08-illegal-kind.log` |
| Extra fourth column | exit 2; full row including surplus column | `09-extra-column.log` |
| Literal ledger `docs/team/reports/P191-exact.md` | exit 0 | `10-exact-ledger.log` |
| One-character difference `docs/team/reports/P191-exactXmd` | exit 1; exact undeclared path (only `.` became `X`) | `11-one-character-near-miss.log` |
| Literal example, placeholder slot, ledger root/fixed file, existing example | all exit 0 | `12` through `15` logs |

Output tail:

```text
== Independent original assertions == PASS=16 FAIL=0
original: assertion-process-exit=0; expected=0
== P191 verification harness == failed=0
```

The live-tree check (`00-live-tree.log`) is green:

```text
spec-refs: judged 101 reference(s) (49 distinct) in 9915 effective line(s); retired 4; undeclared 0;
id families used [D,E,F,M,P,V] named [D,E,F,M,P,V]
checker-exit=0
assertion=PASS
```

**The brief's 99 is historical, not today's count.** Exporting OpenSpec from P185's own branch tip `e079ea56` and running today's checker/table yields **99 / undeclared 0**; exporting P185's merged commit `b5703606` already yields **101 / undeclared 0**. Thus this discrepancy predates P191. The checker/table diff from `b5703606` to the dispatch tree is empty (`checker-table-since-P185.diff`). Raw counts and branch-to-merged spec diff are retained; I did not falsify the count to match the brief.

### Container gates

Source and clone revisions both `61aa78590b33a2c37e88911ba994c79a8a36138e`; image ID `1d723525ee58a8b177862746bc92cde2307a7d5f8a76045f5641703d8ac1a50b` (`gate-meta.log`). Only an independent standalone clone `/work` and log directory `/evidence` are mounted. No main worktree, host HOME or host tmux socket is exposed. Subsequent branch commits are report/evidence-only.

Commands actually executed serially inside the container:

```sh
openspec validate --all --strict
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh --select 18c </dev/null
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
```

```text
validate: Totals: 16 passed, 2 failed (18 items); exit=1
select 18c: section 18c ✓22 ✗0 SKIP0; aggregate ✓43 ✗0; exit=0
FAST: 123 sections; ✓3792 ✗0 SKIP36; exit=0
```

`select-18c.log` explicitly lists **118 omitted section keys**; the selected run is not a full suite. The separate FAST run is green with 36 visible process-scenario skips (full list in `fast.log`). It does not cover true dispatch/PM/worker startup, pulse/close/resume, live-pane guarded delivery, private-server destructive probes, live panel scenarios or meeting tmux. Both background jobs were harvested. The container wrapper exits 1 solely because global OpenSpec validation failed; selected 18c and FAST both exit 0. The longest FAST section was §36, 581 seconds, within its 1400-second budget.

## Flip evidence

Only owned checker copies were changed (`shadow-mutations.txt`). The independent assertions run as subprocesses and really return nonzero; a printed expected-red label alone is not the oracle.

1. **Wildcard shadow:** disable the sole `ledger`/`example` wildcard/placeholder rejection branch. Table loading proceeds, although unchanged exact matching still rejects the planted concrete citation. This is not enough: the oracle requires **load refusal** plus the exact diagnostic, so both cases fail.
2. **Malformed shadow:** replace column-count, kind and basis refusals with `continue`. All six malformed-row checker invocations return 0, and all six independent assertions fail.
3. **Restore:** re-run the same groups against the untouched original checker. All eight assertions pass. Source checker/table SHA256 values before/after are identical (`source-integrity.txt`).

```text
== Independent shadow-wildcard assertions == PASS=0 FAIL=2
shadow-wildcard: assertion-process-exit=1; expected=1
== Independent restored-wildcard assertions == PASS=2 FAIL=0
restored-wildcard: assertion-process-exit=0; expected=0
== Independent shadow-malformed assertions == PASS=0 FAIL=6
shadow-malformed: assertion-process-exit=1; expected=1
== Independent restored-malformed assertions == PASS=6 FAIL=0
restored-malformed: assertion-process-exit=0; expected=0
```

## Blockers and deviations

**BLOCKED: PM/change owners must repair or disposition the unrelated delta/base mismatches and rerun the protected-tree global gate before archive.** Host validation independently reproduces the container's two failures. `spec-rationale-self-contained` itself is marked valid by both runs.

- `delivery-truth`: `delivery-guard/spec.md` MODIFIED requirement `An automated send never types into a non-empty input box` omits current scenario **A meeting knock never lands on a draft** (`validate-delivery-truth-details.log`). Hand back to the delivery-truth owner/PM; P197 is already the active rework task, but I did not assume its scope covers this new base-alignment error.
- `pulse-nudge-key`: `panel/spec.md` MODIFIED requirement `The status band answers "who is in charge" and "is there work"` omits **The disk readings reach the band and the JSON**, **A filesystem that cannot be read is not assigned a number**, and **The band carries unread meeting turns** (`validate-pulse-nudge-key-details.log`). P192 already owns this delta rewrite.
- Historical P184 report is absent at the dispatch revision; recovered read-only using `git show eb2ace3b:docs/team/reports/P184-verify.md`. It supplies context, not current success evidence.
- The thread's P194 cleanup request has no corresponding directory in this dispatch tree (`git status` initially clean; `ls docs/team/reports/P194-verify` absent). No other worktree was accessed to search for it.

## Unmeasured behavior and next steps

No non-FAST suite, performance measurement, live panel/notify scenario, publication, real archive, or new frame identity comparison was run. The selected section invokes product flips, but independent F1/F2 evidence comes from the separate package. No arbitrary new id-family protection, overlay cycle/transitive dependency proof, or semantic assessment of every human-written basis is claimed.

PM should accept the F1/F2 re-verification evidence, close the unrelated gate blockers, then rerun final protected-branch gates. This report does not authorize archive. The blocked notification was sent with `TEAM_NOTIFY_TMUX=0` (durable inbox only, no host tmux interaction). Rebuildable package-owned clone/scratch directories were removed after harvesting; scripts and original logs remain committed.
