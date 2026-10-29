# V116 · Independently verify P393 immediate-by-default `team say`

task: V116
agent: dev2
phase: verify
category: verify
change: say-immediate-default
specs: delivery-guard#Protected automated senders keep a human draft intact, or queue durably
anchor: openspec/changes/say-immediate-default/specs/delivery-guard/spec.md#Protected automated senders keep a human draft intact, or queue durably
deltas: -
branch: task/V116-team-say
deps: exact P393 candidate e67246871e0d; accepted proposal eb8250a26102 and V114 ACCEPT; P393 implementer dev is not this verifier

Launch note: use the PM-authorized one-launch `openai/gpt-6.1-sol:xhigh` because the configured verify provider `cline-pass` is unavailable. This does not change project config or the independent-verification requirement.

## Verdict and evidence

You did not implement P393. Start `docs/team/reports/V116-dev2.md` with PASS, PARTIAL or FAIL, name exact candidate **`e67246871e0d`**, and independently inspect a clean clone outside the author's worktree. Treat the author's 85-key closure, 125/0 delivery-truth and real-Pi A/B as claims until you reproduce the decisive evidence. Do not change implementation or mark OpenSpec tasks independently verified.

Read the accepted change/design/deltas, P393 report and the product/test diff from proposal base `eb8250a26102`. The candidate includes a main-merge ledger commit; distinguish product changes from ledger history. No live-team say/notify/pulse/outbox experiment, merge, push, archive or release.

## Required independent review

1. **Route and parser:** default say chooses a valid live watcher first with durable inbox+spool and zero keys; otherwise it uses the old forced action once after recipient/offline/dead-pane/empty-shell/foreign checks. Retired `say --now` rejects in both positions with rc=2 and zero inbox/spool/queue/forced/tmux effects; draft/outbox `--now`, `--any` and `--no-verify` remain.
2. **Failure honesty:** a selected watch route that disappears or fails to persist cannot fall back to typing; initial enqueue failure is nonzero and is not offline success; direct tmux failure remains best-effort/attempted, not confirmed receipt or automatic queueing. Exactly one existing-format forced audit line per actual direct attempt, none for watched/offline/rejected calls.
3. **No protection regression:** guard coverage moved to actual protected senders rather than being deleted. Check ordinary outbox/draft/notify paths, held/draft durability, geometry/race/terminal cases and normal later drains. No persistent default-direct flag, second queue, new daemon or broad Outbox rewrite.
4. **Real Pi:** independently rerun the pinned Pi 0.99.2 dirty-editor A/B with a genuinely typed draft and loopback controlled model. Baseline default queues without a model request; baseline `--now` and candidate default each produce one request containing the exact draft+correction, one forced line and the same attempt semantics. Include the second-say/no-duplicate case and clean+dirty live-watcher zero-key evidence. Current host Pi 1.4.0 is observation only, not the judged A/B contract. Use host-bind-mounted logs and private tmux/state, no real credentials.
5. **Mutations:** in your own scratch copies, prove removing default-direct, forcing direct ahead of watch, and restoring retired `--now` each turns a named check red; restoration turns green. Also run the delivery-truth mutation suite. Do not accept a mutation that did not actually land or red caused only by a missing file.
6. **Tests:** on the final candidate run the accepted relevant closure in non-FAST mode, at minimum the 17-key set from change task 6.2 plus the complete 12b family after the author's final `de01d811` correction, `delivery-truth.sh --section all --mutations`, and the say help-surface slice. Record exact keys/counts/SKIPs. If a required selection is impractical, report PARTIAL rather than substituting FAST or prose. PM will own the later full merge gate; you need not repeat the author's entire 85-key closure if your selected evidence is complete for the changed behavior.

Run OpenSpec change/all strict validation, spec-refs, selector self-check, real-project ledger-ban and `git diff --check`. The actual project names file must exist and resolve; missing/SKIP is not a pass.

## Boundaries

Only versioned write: `docs/team/reports/V116-dev2.md`; scratch/evidence under `$HOME/.cache/V116/` or other host-bind-mounted paths. No full-suite claim, public CI, live-team state, product/spec/change edits or self-verification checkbox. Preserve the author's disclosed best-effort and partial-watch persistence boundaries; they are not defects to hide.

Commit with Conventional Commits + V116 + `Agent: dev2`, leave the branch clean and notify PM with the verdict, exact commands/output and any remaining failure. PM will independently review the diff/evidence before requesting merge authorization.
