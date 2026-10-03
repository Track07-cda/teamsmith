## Why

P138 and the PM reproduced an idle, empty real Pi editor stranded behind a false BUSY verdict on the tmux fallback. `say` returns 0 and promises delivery after clearing a draft that does not exist; manual notify also points its wake at a different inbox from the file it wrote.

## What Changes

- Locate supported real Pi editor rectangles from a closed layout shape, excluding transcript separators without switching every pane to nearest-border selection. Retain conservative draft protection outside that shape.
- Make queue impediments evidence-based and bounded. Untrusted geometry cannot justify a draft-clearing promise; repeatedly undrainable entries get a visible diagnostic and durable recovery path.
- Keep manual notify's recipient inbox, outbox inbox declaration and wake full-text path identical. Preserve the existing PM knock destination and explicit sender attribution.
- Expose delivery impediments in CLI, durable diagnostics and read-only panel receipts/counts, without introducing a new intent or daemon.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `delivery-guard`: real-frame geometry, trustworthy queued outcomes, bounded visible obstruction, unchanged no-draft-typing and at-most-once rules.
- `notify-and-inbox`: manual notify's durable recipient and wake pointer agree; PM remains the knock destination.
- `panel`: show evidence-based queue impediments without treating a geometry failure as a human draft.

## Impact

Likely implementation paths: `skills/teamsmith/scripts/lib/{outbox,box-judge,cmd-agents}.sh`, inbox-watch routing, panel sources/bundle, tests/frames and troubleshooting documentation. No new dependency, intent, machine transport or PM-liveness change. Do not modify other projects, credentials, task briefs, protected baseline specs during apply, or the CEP original-incident attribution. This assignment writes planning/evidence only; the PM must accept the proposal before assigning apply to another seat.

**What flips:** the real tmux red case reports `second_received=0 backend=0 settle_editors_empty=1` and `FAIL second say stranded despite idle empty editor`; after apply the same recipe must report one reception, one backend submission and `PASS second say delivered`. The notify red case writes `dev.md` but points to missing `pm.md`; green preserves the PM wake and points to the existing `dev.md`. Draft negative controls must still send no key.

Acceptance (from the proposing worktree; `host` mounts Pi read-only inside the disposable container):

```bash
P138_SECOND=1 bash docs/team/reports/P143-verify/pkg/run-case.sh tmux-delivery-truth-dirty HEAD 0 host
python3 docs/team/reports/P143-verify/pkg/judge-second.py tmux-delivery-truth-dirty
PATH=<home>/.bun/bin:$PATH openspec validate --all --strict
python3 docs/team/reports/P143-verify/pkg/check-deltas.py
```

The apply report must retain real command/output tails, Pi version, raw frame/cursor/editor observations, reception/model counts, first-send confirmation, draft zero-key controls, notify's three path values and existence checks, obstruction diagnostics, and preserved-scenario comparison. Proposal evidence distinguishes its own runs from P138 citations; no implementation-green claim is made here.
