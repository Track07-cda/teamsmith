# P395 · Propose marker-based Pi key replies

task: P395
agent: dev2
phase: propose
category: analysis
change: pi-marker-key-replies
deltas: key-replies, pm-lifecycle, memory-and-deps, verification
branch: task/P395-openspec
deps: accepted exploration P394 683d591a3e91; V115 third review ebeaba36; D213/D214; one mandated escaped-backtick clarification below

Launch note: use the PM-authorized one-launch `openai/gpt-6.1-sol:xhigh` because the configured provider for this category is unavailable. No project config change.

## Phase and inputs

This is **planning-only Propose**; you explored this capability but will not implement this proposal. Read AGENTS, your thread, this brief, OWNERSHIP, `references/openspec.md`, the generated propose workflow, P394's report at `683d591a3e91`, V115's third review at `ebeaba36` (especially §16), D213/D214, `docs/team/reviews/P394.md`, `docs/team/reviews/V115.md`, and every existing capability spec you delta.

Write only `openspec/changes/pi-marker-key-replies/{proposal.md,design.md,tasks.md}`, its declared delta specs, and `docs/team/reports/P395-dev2.md`. Do not edit canonical specs, product code, tests, config, live state, other changes or P391's artifacts. No Apply tasks, live-team marker test, merge, push, archive or release. A formal PM proposal review plus independent substantive review must accept the exact proposal before a different author Applies.

## Settled product behavior — do not reopen

1. A normal PM answer may opt into key-reply publication with a final control line, default `[[team-reply]]` or `[[team-reply:标题]]`. Ordinary unmarked answers are not published. A Teamsmith PM-only Pi extension captures the complete assistant response and writes it through the **existing** reply store/writer; Pulse keeps reading that same store. `team reply post` remains manual/backfill only, not the default daily step.
2. D214 selects A: transient streamed marker visibility is accepted. Complete control lines are removed from finalized Pi transcript/stdout/subsequent model history, Pulse current/history and stored body. Do not claim zero stream flash or fixed latency. An abort in the middle of a control prefix may leave literal text; do not guess-delete it. Complete control lines are cleaned on every assistant terminal state, independently of publication eligibility.
3. Cleanup is not publication. Only the latest eligible assistant message in the current activity may publish; later ordinary/tool/error/aborted messages supersede earlier marked candidates. `message_end` stages sanitized intent, `turn_end.messageEntryId` binds identity, final settled processing alone grants durable eligibility. Startup/reload restores only explicitly eligible, never-attempting records on the current project/session/branch; unbound/pending/history guesses never publish.
4. One stable source tuple `(canonical project root, canonical state dir, Pi session UUID, canonical session file, messageEntryId)` has one record and one automatic attempt. Persist attempting before spawning the existing `team reply post` writer. Saved stores its real number; unconfirmed stores candidate_no; process/receipt/journal uncertainty never auto-republishes. Identical bodies on distinct entries are legal; no hash/current-page reconciliation. This is not exactly-once or guaranteed eventual delivery.
5. One directed PM-only extension, narrow parser/offset mapping and operational journal, no second user-facing reply store, provider rewrite framework, daemon, worker capture, new scheduler, new config knobs or automatic model retry. No arbitrary historical import or Pulse/session-journal reads. Manual duplicate posts remain two distinct entries. Writer failures never block or alter the user's normal answer.

## Mandatory third-review R1 clarification — must be explicit in design/spec/tests

Outside fenced/inline code, **consume Markdown backslash escapes before forming opener runs**. An odd-length run of backslashes before a backtick escapes only that first backtick; any unescaped suffix can still form a maximal opener run. An even number of backslashes does not escape the following opener. Do not discard an entire physical backtick run merely because its first tick is escaped, and do not split an unescaped run. Inside a code span backslashes are ordinary content and an exact-length closer still closes.

V115's concrete counterexample is:

```text
示例：\``
[[team-reply]]
`
```

The first tick is escaped, the second opens a code span with the final single tick; the marker-looking line is literal code and must remain unchanged with no intent/writer. Appending `答复。\n[[team-reply]]` must delete/publish only the real final control line. Include these two product-parser cases, adjacent odd/even-backslash and in-span-closer controls, and a mutation that ignores the whole physical run because its first tick is escaped; that mutation must fail. Preserve the already accepted exact-length pairing, cross-line/cross-block, differing-run-length, unmatched-opener and offset/CRLF/UTF-8 rules. No full Markdown AST.

## Design requirements to turn into concrete artifacts

1. **Parser and body/title fidelity:** exact final control-line syntax, optional title, duplicate/misplaced/invalid/empty outcomes, small fence plus paired-inline-code scanner, protected examples, original-offset deletion into multiple text blocks without merging/reordering, non-text fields preserved, title derivation that skips Magic Context numbering only in the title view. No silent truncation; existing writer limits remain explicit failures.
2. **Lifecycle/journal:** define activity/latest-assistant supersession, source identity, end/turn_end/settled state machine, settled witness and branch checks, crash boundaries before/after each stage, one-attempt CAS/lock protocol, owner death and stale/uncertain recovery. Journal is operational evidence only; no second numbering/page or automatic reminders.
3. **PM-only loading and identity:** built-in PM Pi argument injection once; no worker/ordinary-Pi enablement, `/team` duplication or new adapter placeholder. Bind actual main worktree, resolved state/config, tmux session/window, PID/starttime/cwd/spawn evidence, not cwd alone. Duplicate loaded copies have one owner/generation plus cross-process source CAS. Cover first-injection restart versus already-loaded extension reload, loaded-module fingerprint and doctor's disk-versus-running distinction. Custom adapters are not automatically supported.
4. **Instruction migration:** PM template, protocol §4b and SKILL/guide change together to “marked normal answer; extension publishes; CLI manual/backfill”. No temp-file/heredoc/post-then-repeat default. Do not enable instructions before the capture path exists. P391 stays blocked until this proposal is accepted and can integrate its shared instruction edits; P393's accepted say changes are independent and its SKILL.md edit is serialized first.
5. **Verification:** real product parser and real writer for syntax, identical bodies, busy/unconfirmed/receipt/journal faults and exact raw bodies; private real Pi + controlled model for end/turn/settled ordering, final rendering/history, reload, duplicate loads and crash/fault injection. Use actual marker-specific raw-pty selectors. Include foreign cwd+inherited root, branch/session switch/fork, repeated settled, old saved entries beyond the current page, and private live-state no-side-effect checks. No real-model compliance claim, full gate at Propose, or live-team test.

## Exact spec deltas and Purpose handling

At minimum MODIFY these three **real** key-replies requirements, preserving every scenario not intentionally replaced:

- `Key replies are explicitly published from bounded stdin`: retain manual stdin/full-text/duplicate-post behavior; add only directed live-marker/eligible-source exception, no history import or body dedup.
- `Publication does not gate the normal answer or create work`: replace the old default post-then-repeat duty with marked normal answer + extension publication, retaining reader criteria, complete sanitized body, failure non-blocking and no task/inbox/outbox/wake/approval lifecycle.
- `The key-conclusion duty is shipped on its instruction surfaces and held by the gate`: align the three instruction surfaces and product-matcher/CLI/real-Pi tests; do not claim models always comply.

Also delta only the capabilities actually changed by PM startup/identity and update evidence (`pm-lifecycle`, `memory-and-deps`) and verification. `/team`'s no-other-tool/single-command contract remains unchanged; no meaningless extension-slash delta.

The canonical key-replies Purpose's absolute “separate from any Pi session reader” wording must become the narrow directed-current-activity exception while retaining no historical import and no panel session reads. OpenSpec archive ignores a delta Purpose for an existing capability. Therefore the proposal must include an **authorized archive-time canonical Purpose edit**, and your disposable trial archive must rehearse that edit and inspect the actual resulting text; validate alone is insufficient. Do not edit canonical Purpose now.

`tasks.md` must be small ordered slices with named files, observable evidence and independent verification, including the R1 escaped-suffix cases. Do not create Apply briefs or mark verification done. Keep P391 integration as a dependent later step, not a second parallel proposal.

## Acceptance and delivery

Run and record on the exact final tip:

```bash
openspec status --change pi-marker-key-replies --json
openspec validate pi-marker-key-replies --strict
openspec validate --all --strict
openspec instructions apply --change pi-marker-key-replies --json   # read-only planning review
bash skills/teamsmith/tests/spec-refs.sh --check
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check
```

In a disposable copy outside the repository, run `openspec archive -y pi-marker-key-replies`, apply the proposed canonical Purpose edit in that copy, validate all specs, and inspect the three modified requirements/Purpose plus unchanged scenarios. Wrong requirement names, missing default-duty replacement, missing Purpose alignment or ADDED-only bypass must be reported, not hidden by a green archive. Real change remains unarchived and candidate clean.

The report leads with the chosen minimal architecture, exact artifact paths, how every V115 finding (including the escaped-suffix opener) is closed, validation/trial results and unverified boundaries. Commit with Conventional Commits + P395 + `Agent: dev2`, leave the branch clean and notify PM for formal proposal review.
