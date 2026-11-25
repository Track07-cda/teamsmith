# Task labels — paused after two independent verification failures

P497 and V196 are blocked. Neither candidate was merged or accepted. `tasks.md` §3.1 remains incomplete; the approved requirements and the current Pulse are unchanged.

- `6ce75ccf`: 636 passed, 3 failed, 3 skipped. The public CLI misread a valid dash-prefixed label; the narrow-frame selector missed a rendered row; the isolated panel rebuild omitted the shared sanitizer and was incorrectly reported as skipped. The last two issues were in the checks.
- `4cbc5bc7`: targeted checks closed all three findings; a deliberately incorrect score produced 5 rather than the recorded 8. The first live board run passed 16 checks and failed 1. Sending three consecutive Up keys moved focus only one card, from `M39 Outside` to `M51 Other`, not to `M39 Second`. The saved output does not establish whether inputs reached the panel separately or were examined against the same focus. The rest of the live board checks did not run.

See `docs/team/reviews/V196.md` and `docs/team/reports/V196-verify.md` (verifier's `19f9023c`). Before resuming implementation or acceptance, isolate the keyboard behavior on the frozen candidate and compare with the pre-label implementation if attributable to code; compare successive single keys with the same three-key burst. Do not lengthen waits or replace the burst and call the failure fixed. Reuse the valid CLI, build, scoring, and live frames. No third automatic verification run, merge, or archive.
