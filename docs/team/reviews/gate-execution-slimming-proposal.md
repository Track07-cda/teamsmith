# Gate execution slimming · P397 proposal review

status: IN REVIEW — no Apply authorization
candidate: `4bdcc5b375fb` (`task/P397-gate-slimming-proposal`, author dev2)
change: `gate-execution-slimming`
independent review: V118 / verify (not the author)

## Answer so far

This is a delivered proposal, not an implemented speedup. PM has read all four planning files and the author report. The projected ordinary shard 26.4min / routing shard 49.2min / serial full 155.7min are estimates, not observed post-change results. The 2026-10-30 interrupted gate contributes a closed 61b reading of 5724s, not a complete PASS. The author reports structural validation and a disposable trial archive; PM independent reproduction is pending. Its script and full log are under `$HOME/.cache/pm-skills-reviews/P397-4bdcc5b3/` and do not run smoke or the long matrix. V118 was launched without --model on the configured verify route; its actual pane shows the correct provider/model and source-reading tool calls. The prior V113 report/branch remains unmerged and preserved; its review status was not forced to done.

## Substantive acceptance questions

- Does replacing a final full green behavior run with hashes/status actually cover the state it observed, or only prove unchanged source? Proposal section 3 currently calls the replacement stronger, which requires more than file equality.
- The design narrows every arm in its declaration table but later says it does not rewrite the other 24 inline group bodies. Are the requested implementation, generic spec and cost calculation consistent? Removing one of several declaration ids must not remove both the observation and the expected result unnoticed.
- Multi-table parsing may only be shared for the same source tree/index. Inspect the actual 11 call sites before claiming 11→1. Cross-section scratch sharing must preserve independent selection and restoration; avoid disproportionate cache machinery for second-level savings.
- LPT must define its global or selected universe. Fixed key→shard across pushes, a floor-only cost file, a heavy non-floor matrix, and selected-set packing are not automatically compatible. Recompute actual own+needs+prologue costs, not own-only maxima; show arithmetic behind totals and billed minutes.
- The implementation plan currently starts every slice with a full smoke, adds a separate full old matrix census and new full matrix, then full final gates plus independent repeats. That schedule needs explicit justification against selected-per-change/full-at-final discipline and existing persistent evidence.
- Check exact delta/scenario compatibility, restored/pass-count comparisons, complete rollback write sets and the real subtraction count for any new self-check. The change must reduce execution, not build a second testing control plane.

No issue is declared resolved by this checklist. V118 must independently give its verdict and counterexamples; PM will reconcile them with clean-copy validation before any formal ACCEPTED.

## Boundaries

Only planning review and lightweight static/arithmetic probes now. No full smoke, long matrix, product/test changes, live init, model change, protected merge/push, public CI, archive or release. The existing 60-minute job cap and performance-as-reference rule remain.
