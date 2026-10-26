# P376 · Do not report PM-window creation as successful when tmux failed

task: P376
agent: dev
phase: apply
category: code
change: -
specs: pm-lifecycle#PM liveness is proven, not inferred
anchor: none (infra) — existing behavior repair, no new spec delta
deltas: -
branch: task/P376-pm-window-create-truth

## Evidence

`skills/teamsmith/scripts/lib/cmd-watch.sh` currently does:

```
team_tmux_new_window "$TEAM_SESSION" "$TEAM_PM_WINDOW" || true
team_ok "创建 PM 窗口 $TEAM_SESSION:$TEAM_PM_WINDOW"
```

V60 independently reproduced the defect (`docs/team/reports/V60-verify.md`, R2): with private `TMUX_TMPDIR` pointing at a regular file, `team_tmux_new_window` returns 1, but the next line still prints `✓ 创建 PM 窗口 …`. The success claim is unconditional, so a failed launch can look successful to the user.

This is a small product defect in the 0.3.4 release path, not a request for a new guard framework.

## Required fix

Use the actual return code:

- on failure, print a named error that PM-window creation failed (include the tmux target and keep the underlying tmux diagnostic), return non-zero, and do not print the success line or continue as though the window exists;
- on success, keep the current success line and launch behavior unchanged;
- do not replace the swallowed error with another generic `|| true`, `2>/dev/null`, or silent fallback.

Keep the change local to this creation branch. Do not redesign `team up`, PM identity, session recovery or adapter selection.

## Verification

1. Reproduce the original failure in an isolated fixture with `TMUX_TMPDIR` pointing at a regular file. Before the fix: window creation returns non-zero but the success line appears. After: non-zero, named failure, no success line. Capture the real command and output.
2. Positive control: a successful private-tmux window creation still prints the success line and proceeds. Use the existing fixture/helpers rather than adding a test framework.
3. Add or update one behavioral assertion in the existing relevant smoke section so the failure cannot again print success. Prove it goes red on the old implementation and green on the fix.
4. Run only affected sections (the section covering `cmd-watch.sh` and `team up`, as selected by the current path map), plus `bash -n`, `section-select.sh --check`, ledger ban and `git diff --check`. Do not run the full suite.

## Delivery

Report `docs/team/reports/P376-dev.md` with the before/after output and the targeted readings. Keep product edits limited to `cmd-watch.sh`; test edits limited to the existing section that covers this behavior. No push, no merge, no release action. Independent verification is a separate task.
