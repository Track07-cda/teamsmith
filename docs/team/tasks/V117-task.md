# V117 · Independently review the marker-based key-reply proposal

task: V117
agent: dev3
phase: propose
category: verify
change: pi-marker-key-replies
deltas: -
branch: task/V117-v117
deps: exact proposal candidate 8734bd93c1c8; P395 author dev2; D213–D215; P394/V115 exploration reviews

Launch note: use one-launch `openai/gpt-6.1-sol:xhigh` because the configured verify provider is unavailable; no config change.

## Verdict and scope

You did not author P395. Independently review exact candidate **`8734bd93c1c8`** in a clean clone, including all proposal/design/tasks and four delta specs. Start `docs/team/reports/V117-dev3.md` with **ACCEPT**, **NEEDS-CHANGES** or **REJECT-APPROACH**, name the candidate and whether any new OpenSpec delta is required. This is an independent substantive proposal review, not implementation verification. The P395 delivery report was initially missing; if it arrives while you work you may read it as a claim, but the frozen design candidate above is what you must judge. PM will separately require the final report before acceptance.

Read D213/D214/D215, P394's final report at `683d591a3e91`, V115's third review at `ebeaba36`, the current canonical specs and the relevant existing Pi/writer/source. Do not rely only on the proposal's internal consistency or validation green. Only versioned write: your V117 report; scratch under `$HOME/.cache/V117/`. No product/spec/change/live-team edits, full gate, merge, push, archive or release.

## Required adversarial checks

1. **Parser and escaped suffix:** verify the mandated rule outside code consumes backslash escapes before forming maximal opener runs; an escaped first tick leaves an unescaped suffix eligible, even/odd parity and in-span closers are correct. Check V115's exact inline-only and inline+real counterexample, paired multi-line/cross-block spans, unmatched openers, code fences, original-offset deletion and title derivation. The design/spec/tasks must all carry the same behavior and a real mutation red side, not just prose or a full Markdown framework.
2. **Lifecycle and recovery:** end staging before entry ID, turn_end binding, final settled eligibility, latest-assistant supersession, first-activity null leaf, branch/session scoping, one source/attempt, eligible-only recovery and uncertain outcomes. Look for crash/interleaving cases that could publish an unmarked/aborted earlier answer or auto-retry an uncertain writer result. Identical bodies must remain distinct; no hash/current-page reconciliation.
3. **Cleanup versus publication:** all assistant terminal states remove complete control lines without blocking the normal answer; partial prefixes stay literal; non-final/error/aborted/tool messages do not publish. Check whether identity/journal/owner failures could accidentally skip cleanup or throw back to the original marked message. No fixed flash or real-model-compliance claim.
4. **PM-only integration:** directed built-in PM injection once, no worker/ordinary-Pi/`/team`/custom-adapter expansion, actual project/state/session/tmux/PID evidence, duplicate-copy owner/generation, first-injection restart versus already-loaded reload, loaded dependency fingerprints and doctor's honest disk/runtime distinction. Challenge whether this is the smallest safe implementation and whether any check is impossible with the existing public Pi/tmux surfaces. No live PM reload/restart.
5. **Specs:** exactly the three real key-replies requirements are MODIFIED, not a nonexistent title or ADDED-only bypass; unchanged manual duplicate-post/no-history-import/no-panel-session-read behavior remains. The Purpose cannot be merged by delta and must have an explicit authorized canonical edit + private trial landed-text check. Other deltas must match actual startup/update/verification changes; extension-slash remains untouched.
6. **Tasks and evidence:** real product parser/writer, private real Pi+controlled model, actual writer busy/unconfirmed, crash/receipt/journal faults, duplicate loads, same bodies, old saved beyond page, foreign cwd+inherited root, branch/fork and private no-side-effect snapshots. FAST/fake-host/stub receipts cannot stand in for required real behavior. P393 SKILL serialization and P391 dependency must be respected. No Apply brief before formal PM ACCEPTED.

Run at minimum strict change/all validation, spec-refs, real-project ledger-ban, diff check and a disposable trial archive with the proposed canonical Purpose edit and resulting-text inspection. Record actual commands/output and candidate cleanliness. Structural green is not a design verdict.

Finish with the smallest remaining correction set, or a clear acceptance for PM formal review. Commit with Conventional Commits + V117 + `Agent: dev3`, leave the branch clean and notify PM.
