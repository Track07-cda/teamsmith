# Gate execution slimming · P397 proposal review

status: IN REVIEW — no Apply authorization
candidate: `4bdcc5b375fb` (`task/P397-gate-slimming-proposal`, author dev2)
change: `gate-execution-slimming`
independent review: V118 / verify (not the author)

## Answer so far

This is a delivered proposal, not an implemented speedup. PM has read all four planning files and the author report. The projected ordinary shard 26.4min / routing shard 49.2min / serial full 155.7min are estimates, not observed post-change results. The 2026-10-30 interrupted gate contributes a closed 61b reading of 5724s, not a complete PASS. PM independently reproduced structural validation and a disposable trial archive in a clean clone: OpenSpec 20/20, spec-refs 121 references clean, real-names ledger clean, 29 unchecked implementation tasks, disposable archive +2/~2 and post-archive strict 19/19, all four target requirement headings unique, and the real candidate still clean/unarchived. Background job `p397-pm-proposal-validation` exited 0 in 81.6s. Its script and full log are under `$HOME/.cache/pm-skills-reviews/P397-4bdcc5b3/`; no smoke or long matrix ran. V118 was launched without --model on the configured verify route; its actual pane shows the correct provider/model and source-reading tool calls. The prior V113 report/branch remains unmerged and preserved; its review status was not forced to done.

## Confirmed PM finding: total projection does not reconcile

`design.md` §6 states frozen serial total 14307s, 61b 6719→2850–3000s, §51 1190→830s and §36 1122→960s; §38 savings are explicitly treated as zero. These yield `14307-(6719-[2850..3000])-(1190-830)-(1122-960) = [9916..10066]s`, approximately 165.3–167.8min, not the stated 9344s/155.7min. The discrepancy is 572–722s. That changes the claimed benefit and must be corrected or reconciled with a named missing subtraction; it is not a measured speed regression or a timing gate. Preserve the candidate until V118 finishes so all required revisions can be returned together. No Apply acceptance follows from structural green.

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
