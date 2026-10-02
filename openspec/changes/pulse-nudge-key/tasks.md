## 1. Lock the baseline (watchdog and panel)

All items below are future apply/verify work, not work completed during propose. One apply brief declares
`change: pulse-nudge-key`; it may start only after the PM records ACCEPTED proposal review. The focused fixture
path below is created in 1.2. Commands invoking it run **inside the disposable gate container**, never against
the host tmux socket; it uses stubs, not a real model. Full-gate commands use the existing clone/container wrapper.

- [ ] 1.1 Preserve both watchdog rate-limit scenarios and both panel status-band scenarios; verify `bash docs/team/reports/P172-verify/pkg/check-baseline.sh` exits 0 and prints all four verbatim comparisons.
- [ ] 1.2 Create `skills/teamsmith/tests/pulse-nudge-key.sh`, with focused keys/policy/transitions/observers/migration modes, and port the deterministic P172 red cases without candidate code; verify the untouched baseline using `bash docs/team/reports/P172-verify/pkg/run.sh --expect-current-red` (F1–F4 must be the only failures).

## 2. Separate wake identity and rearm the batch (watchdog)

- [ ] 2.1 Add the canonical positive-category key beside the count signature, leaving policy and text unchanged; verify `bash skills/teamsmith/tests/pulse-nudge-key.sh --keys` checks magnitude-independence for all eight positions, distinct sets, seven-field compatibility and exclusion of stopped-seat prose.
- [ ] 2.2 Use the category key for the existing running-PM reminder decision and reuse that snapshot for `watchdog.nudge`; verify `bash skills/teamsmith/tests/pulse-nudge-key.sh --transitions` covers count-only suppression, immediate category addition/removal, exact submitted text, matching recorded key, and gap-1/gap boundaries without advancing time on suppressed ticks.
- [ ] 2.3 Clear reminder history on an observed empty tick before standby returns; verify `bash docs/team/reports/P172-verify/pkg/run.sh --assert-fixed` closes F1–F4 and keeps G1–G12 green, including ordinary and standby empty-return sequences, no-work silence and standby backlog logging.
- [ ] 2.4 Verify policy-filtered membership using the actual ordinary/fast pending readers with pending-board off/on (todo/wip/review gated, blocked always eligible, meetings/stopped retained); `bash skills/teamsmith/tests/pulse-nudge-key.sh --policy` must reject a policy mismatch. Keep PM absent/starting/foreign, quota and guarded-delivery control assertions in this fixture or the existing gate, without rewriting their logic.
- [ ] 2.5 Verify old numeric signatures and recent epochs migrate to one fresh category reminder, later unchanged ticks are quiet, and `TEAM_WATCH_NUDGE_GAP` fallback/`TEAM_PULSE_NUDGE_GAP` precedence/default remain effective; `bash skills/teamsmith/tests/pulse-nudge-key.sh --migration` must exit 0. Clarify the existing gap documentation if needed; do not change the configured/default values.

## 3. Protect the current-count observers (panel)

- [ ] 3.1 Exercise `team monitor --print`, `team monitor --json` and `team __panel-data --block pending` against the same private four-unread fixture after a suppressed tick; verify `bash skills/teamsmith/tests/pulse-nudge-key.sh --observers` asserts actual counts, total/text, both baseline status-band scenarios, and byte/mtime-identical state across reads. Do not change the TSX sources or committed bundle.
- [ ] 3.2 Verify the anti-overcorrection controls: `bash docs/team/reports/P172-verify/pkg/run.sh --mutations` must reject a constant wake key at G1 and a frozen panel at G9; restore in-memory overrides automatically and leave all repository implementation files untouched.

## 4. Gate and independent verification (watchdog and panel)

- [ ] 4.1 Hook the focused fixture into the correctness smoke suite, commit the implementation and run `bash docs/team/reports/P172-verify/pkg/gate.sh`; require strict OpenSpec validation and full smoke exit 0. **Real process:** the complete suite may create private tmux panes, but only inside its disposable container. This is integration evidence in addition to the deterministic policy probe, not the only evidence.
- [ ] 4.2 A different agent replays `bash docs/team/reports/P172-verify/pkg/run.sh --assert-fixed` and the committed-clone gate on the developer tip; the report must retain pre-fix F1–F4, post-fix zero failures, mutation failures, observer/policy/migration outputs, baseline comparison and exact gate exits. The PM reruns final protected-branch gates before confirming delivery.
