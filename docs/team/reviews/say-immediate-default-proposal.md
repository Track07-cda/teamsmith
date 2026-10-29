# say-immediate-default · Formal proposal review

Candidate: `eb8250a26102` (proposal artifacts `b1d8e74c`) · verdict: **ACCEPTED**

PM has read the complete proposal, design, tasks and all three delta specs. The design follows D207/D209: watch-first with durable inbox+spool and zero keys; default direct attempt only for an eligible no-watch target; public `say --now` removed without alias; other senders and explicit Outbox/draft overrides unchanged.

## Independently reproduced checks

Clean clone: `$HOME/.cache/pm-skills-reviews/P392-eb8250a2/candidate`.

- change strict valid; all specs 20/20;
- apply instructions ready, 23 tasks all unchecked;
- spec-refs passes with one declared retired historical reference; real-names ledger and diff checks pass;
- disposable-copy archive applies seven modified requirements and validates 19/19; real change remains and checkout is clean.

Logs: `$HOME/.cache/pm-skills-reviews/P392-eb8250a2/static-checks.log` and `trial-archive.log`. Structural green is not behavior verification.

## Substantive review focus

- Default direct intent must not bypass watch or affect later normal drains. Selected-watch route loss/persistence failure must not switch to typing; initial enqueue failure must not be reported as offline success.
- Recipient/offline/dead-pane/empty-shell/foreign-session checks must remain immediately before direct send; `--no-verify` cannot skip them. Direct best-effort remains an attempt, not confirmed model receipt or automatic queueing.
- One forced audit line per actual direct attempt; none for watched/offline/rejected calls. Both retired-flag positions reject with zero side effects. Draft/outbox overrides remain.
- Protected-sender guard coverage must move to actual protected entries without deleting geometry/race/held/terminal assertions. Real Pi evidence requires genuine editor drafts and model requests/frames, not pane echo or rc=0.
- P391 shares SKILL.md and must be serialized during Apply. P380 remains unmerged; pinned 0.99.2 judged A/B and current 1.4.0 observation cannot be mixed. Delivery-guard Purpose needs the separately noted canonical alignment at authorized archive.

## Final PM verdict — ACCEPTED for local Apply

V114's independent substantive review at `6f20747eb2ba` is **ACCEPT**, with no blocking findings. It checked the full modified requirement inventory (7 modified, 33 unchanged), all 44 old scenario anchors, exact sender/source lines, a clean disposable archive and the remaining Purpose boundary. PM reconciles that review with the complete read-through and reproduced checks above and formally accepts this exact proposal.

Apply must retain the disclosed boundaries: default direct is an attempt, not confirmed model receipt or automatic queueing; old best-effort tmux gaps are not claimed fixed; selected-watch failures cannot change transport; initial enqueue failure gets a real nonzero persistence error; one outstanding direct attempt writes one existing-format audit line; protected-entry guard coverage and real model-request evidence are mandatory.

The canonical `delivery-guard` Purpose still contains the old universal draft-protection statement and is not changed by OpenSpec requirement merging. At the separately authorized archive, PM must align that Purpose with protected senders in the same landed change; trial archive does not discharge it.

P393 may implement this proposal on a local task branch based on `eb8250a26102`, with a different author and subsequent independent Verify. P391's Apply must serialize its overlapping SKILL.md edit after P393's candidate is settled. No protected merge/push, live-team say, real archive or release is authorized by this verdict.
