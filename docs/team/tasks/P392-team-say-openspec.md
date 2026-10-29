# P392 · Propose immediate-by-default `team say` without `--now`

task: P392
agent: dev2
phase: propose
category: analysis
change: say-immediate-default
deltas: delivery-guard, notify-and-inbox, help-surface
branch: task/P392-team-say-openspec
deps: accepted exploration P390 ec78b6c622ad; PM review docs/team/reviews/P390.md; D207/D209

## Phase boundary and product decision

You explored this behavior and now own **planning-only Propose**. Read `AGENTS.md`, your thread (including the user's decision), this brief, OWNERSHIP, `references/openspec.md`, the P390 report (`git show ec78b6c622ad:docs/team/reports/P390-dev2.md`), PM review and D207/D209. Use the generated OpenSpec propose workflow.

Write only `openspec/changes/say-immediate-default/{proposal.md,design.md,tasks.md}`, the three declared delta specs, and `docs/team/reports/P392-dev2.md`. No canonical-spec/product/test/config edits, no live say experiments and no Apply before formal proposal ACCEPTED plus independent substantive review.

The settled behavior is:

- A valid live inbox-watch route remains preferred: durable inbox + spool, zero tmux keys, existing draft safety.
- Without a usable watcher, a running target that has passed the existing offline/dead-pane/empty-shell/recipient/foreign-session checks gets the existing forced direct-send behavior **by default**, even with a draft.
- Public `team say --now` is removed and rejected by the existing unknown-flag path, with no alias. Internal helper force behavior may be reused.
- `notify`, automatic completion knocks, meeting/Pulse, `draft send --now` and `outbox flush --now` retain their existing behavior. Ordinary Outbox and real held/queued failure paths remain.

Do not implement this by merely flipping `now=0` to `1`: the old force branch precedes watch routing. The design must put valid watch routing before the default direct fallback for say without changing other kinds or explicit Outbox overrides.

## Required design/spec work

1. Specify the smallest implementation seam between `cmd-agents.sh` and `outbox.sh`: public parser/usage removal, watch-first default say, existing safety checks before direct send, no duplicated enqueue/tmux logic, and no blind direct fallback when watch persistence/routing fails.
2. Preserve the existing forced audit file/record format and exactly one record for a real direct send. Watched delivery does not create a forced record. Update visible output so “immediate attempt” is not presented as confirmed model receipt and does not mention the retired flag. The old forced path has best-effort tmux failure gaps; do not claim those are confirmed or automatically queued. If you choose to repair a specific say failure, give a bounded scenario and evidence; do not rewrite global failure recovery incidentally.
3. `delivery-guard`: narrow the general no-dirty-box typing language to protected senders and distinguish immediate say attempts from guarded/confirmed delivery. Move old guard demonstrations to actual protected entries (draft/notify/explicit queue) while keeping the geometry/race/held assertions. Preserve other senders' behavior.
4. `notify-and-inbox`: keep offline/dead/shell fallback intact; replace the old default-say draft queue contract with watch-first/direct-fallback scenarios. Clean/dirty watched and unwatched cases must have honest outcome distinctions.
5. `help-surface`: explicitly retire only `say --now` from the old-flag compatibility rule and bilingual command/help baselines. Other flags, machine output, help hierarchy and command behavior remain covered. `outbox flush --now` and `draft send --now` remain visible and functional.
6. Update active instruction/docs surfaces that promise say waits for drafts (`SKILL.md`, config/troubleshooting and command strings as identified in P390). Do not rewrite historical reports/decisions. Coordinate later Apply ordering with P391's instruction-slimming change rather than creating competing long prose.
7. Keep dispatch dead-pane and boundary cross-session protections as regression dependencies, not unnecessary new deltas. No new config key, queue, delivery framework or hidden CLI alias.

## Verification plan

Reuse existing smoke/delivery-truth/real-Pi fixtures and replace, rather than stack, outdated say guard cases. `tasks.md` must include:

- Same genuine dirty no-watch box: baseline default queues, baseline `--now` direct-sends, candidate default produces the old forced behavior without a flush, one audit line and no active queue entry. Evidence includes actual model request/frames, not just rc=0 or text on a pane.
- `say ... --now` in both flag positions is rejected with unknown flag and zero changes to keys/inbox/spool/forced/outbox; en/zh help no longer exposes it while outbox/draft retain theirs.
- Live watcher: default say remains durable+spool, zero-key, draft-safe, one eventual model receipt and no forced record. Invalid/stale/foreign watcher registration cannot be treated as successful delivery or trigger blind direct send.
- Offline/dead-pane/empty-shell, unknown recipient/`--any`, cross-session and `--no-verify` behavior remains. Other senders and explicit Outbox override behavior stay unchanged.
- Scratch mutations: remove default direct intent, move force ahead of watch, and restore the public parser flag; each produces a named red, restoration is green. Existing guard mutations still prove migrated protected-entry tests are falsifiable.
- Run the actual section-select closure and non-FAST relevant sections, delivery-truth with mutations, and real Pi A/B. FAST skips are not passes. The old real runner supports 0.99.2; use that for reproducible A/B and current Pi 1.4.0 for direct evidence without pretending the old judge supports it or cherry-picking P380. Keep host-side full logs and no real credentials/live team messages.

Give concrete implementation files, migration of old tests to protected entries, selected gates and independent-verifier focus. One Apply owner is sufficient; no new scheduler/delivery task family.

## Acceptance and handoff

Run and record in the actual available environment:

```bash
openspec status --change say-immediate-default --json
openspec validate say-immediate-default --strict
openspec validate --all --strict
openspec instructions apply --change say-immediate-default --json   # read-only
bash skills/teamsmith/tests/spec-refs.sh --check
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check
```

Trial-archive only in a disposable copy and validate the resulting all-spec state. No full gate, live team experiment, merge, push or release.

The report leads with the watch-first/default-direct design, all three deltas, honest receipt/failure boundaries, exact validation and verification plan. Commit with Conventional Commits + P392 + `Agent: dev2`, leave the branch clean and notify PM for formal proposal review.
