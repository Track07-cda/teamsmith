# V106 · Independent review of PM-window creation failure reporting

task: V106
agent: verify
phase: verify
category: verify
change: -
specs: pm-lifecycle#PM liveness is proven, not inferred
anchor: none (infra) — independent verification of an existing behavior repair
deltas: -
branch: task/V106-pm-window-truth-review

## Candidate

`de39538c` on `task/P376-pm-window-create-truth` (implementation `fa691596`, behavioral test `3b563c41`). Report: `docs/team/reports/P376-dev.md`.

The fix is intended to make `team up` return non-zero and name the failed PM-window creation instead of printing `✓ 创建 PM 窗口 …` after `team_tmux_new_window` failed. The success path must remain unchanged.

## Required independent evidence

Use your own clean clone and private temporary directories. Do not modify main or the candidate.

1. Reproduce the failure with `TMUX_TMPDIR` pointing at a regular file, using the same isolated `team up` shape described in the report. On the old implementation, confirm non-zero window creation still prints the success line. On the candidate, confirm non-zero exit, a named failure including the tmux target, preserved underlying tmux diagnostic, and **no** success line. Confirm it does not continue as if the window existed.
2. Positive control: in a private tmux server, successful window creation still prints the same success line and the PM startup proceeds. Do not use the real team session.
3. Run the candidate's `bash skills/teamsmith/tests/smoke.sh --select 11b2` once with private `TMPDIR`; confirm green. Run the old `cmd-watch.sh` with the new assertion in a private copy and confirm the new assertion fails for the intended reason; restore and confirm green.
4. Inspect the product diff: only the creation branch should change. No generic `|| true`, stderr suppression, new adapter behavior or PM identity/session redesign.
5. Run `bash -n skills/teamsmith/scripts/lib/cmd-watch.sh`, `section-select.sh --check`, ledger ban and `git diff --check`. No full suite.

## Delivery

Write `docs/team/reports/V106-verify.md`, starting with PASS, PARTIAL or FAIL. Give exact commands, output tails and exit codes. Do not repair the candidate yourself, do not add guards, do not merge or push.
