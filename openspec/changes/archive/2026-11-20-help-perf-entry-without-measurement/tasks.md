## 1. Apply only after proposal acceptance

- [x] 1.1 In `skills/teamsmith/tests/help-surface.sh` replace the existing `perf` claim's measurement call with the private-source handoff, expected-status and six-face check in `verification#A gate that cannot judge says so`, scenario **The perf help claim observes a handoff, not a measurement**. Remove only `perf` from the whole-suite branch. Reuse existing scratch setup, selector and outcome accounting; leave the real CLI, real measurement, `smoke` and the rest of the help check untouched.
- [x] 1.2 Provide static evidence of that narrow write set, the replacement of the one old verdict and the unchanged real-measurement entry. Do not run the behavioral samples as the author or create another gate section.

## 2. Independent verification of the same requirement

- [x] 2.1 On a frozen independent checkout, run one healthy sample and exactly the two named fault samples below. Capture the candidate SHA, actual command, exit status and named verdict for each, and show the actual receipt and six-face outcome where applicable. A setup error, timeout or unrelated finding is not an intended red.
- [x] 2.2 Cite unchanged coverage by diff rather than rerunning it. Keep the old claim source-attributed, the new executed verdicts and other checks distinct. After merge, the same verifier checks the relevant files match the verified candidate and checks the narrow integration; don't repeat the three samples or unaffected suites unless an evidence premise changed. Report the unobserved real-measurement write boundary explicitly.

Run from the independent checkout. For the healthy sample set `tree` to the frozen checkout root. For each fault, make a separate disposable directory that contains the candidate's `skills/teamsmith/` at that relative path. Set `tree` to that directory's root, not to `skills/teamsmith/` itself. In each fault copy edit only the `perf` arm in `$tree/skills/teamsmith/scripts/team`. Use the existing keep option to inspect the per-run evidence; clean only the private directories created for these samples after collecting it.

```bash
TEAM_HELP_SURFACE_TREE="$tree" TEAM_HELP_SURFACE_ONLY=perf TEAM_HELP_SURFACE_KEEP=1 \
  bash skills/teamsmith/tests/help-surface.sh --select claims
rc=$?
printf 'claims_rc=%s\n' "$rc"
```

| Sample / scenario in `A gate that cannot judge says so` | Change to the selected tree | Required result |
|---|---|---|
| **The perf help claim observes a handoff, not a measurement** | None | Help fixture exits 0; named handoff and unchanged-project pass, exactly one complete receipt with `--host` and the original scratch project's physical directory, expected recorder status observed at the CLI, six fingerprints unchanged. No measurement. |
| **The perf help claim rejects a success that never hands off** | In that `perf` arm, exit 0 instead of calling `team_cmd_perf`. | Help fixture exits 1 and names the missing `perf` handoff; CLI status 0, no receipt and no project change. |
| **The perf help claim rejects a handoff that changes the calling project** | In that `perf` arm, write a new test file under the scratch caller's `.pi/team/state/` immediately before calling the original `team_cmd_perf "$@"`. Do not change the recorder, assertion or the rest of the route; a failed test-file write invalidates this sample. | Help fixture exits 1 and names the changed `state` face for `perf`; the valid receipt and expected CLI status still prove handoff. |

Neither the complete help group, FAST/full correctness nor the independent performance job is required to accept these three samples. No sample is a timing assertion. These are later verification steps, not P482 execution receipts.
