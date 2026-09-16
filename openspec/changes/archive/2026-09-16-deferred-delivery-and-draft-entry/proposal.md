## Why

D20 (user report, 2026-09-15): automated messages are typed with `send-keys` + `Enter`, so a notice arriving while
a human types is appended to the draft and the combined text is sent at once — the draft leaves the box and the agent
answers a message nobody wrote. E3 reproduced it on a real Pi pane (§1.1(e)); D21 accepted option B (guard + outbox
+ draft entry now, channel C later).

## Flip

- **Red before** (E3 §1.1(e), real Pi pane): the box holds `半截草稿 half a sentence`; `send-keys -l` + `Enter` of
  `[watchdog] 待办：验 V9.9` yields one glued submission `第二段草稿 half a sentence[watchdog] 待办：验 V9.9` —
  draft gone.
- **Green after**: the same send types nothing, the box keeps the draft, `state/outbox/` holds one entry, and the
  drain delivers it once the box is free.

## What Changes

- **new capability `delivery-guard`**: one guard in front of every automated send (cursor-anchored; the
  whitespace-only draft is the documented miss); `state/outbox/` as one immutable atomic entry per message (header +
  verbatim payload — the interface); one drain with three callers (sender retry, watchdog tick, `team outbox flush`),
  claiming an entry before typing and confirming delivery by pane fingerprint; `TEAM_DEFER_TTL` expiry →
  `outbox/held/` + `HOLDING.log`, never typed; dedup carries the extension's key; the held count shows in
  `status`/`digest`; `team draft pm` opens `$EDITOR` on `state/draft-pm.md` in a non-focusing `draft` window;
  `team draft send <file>` is the headless form (multi-line via `paste-buffer -p` + one `Enter`).
- **`notify-and-inbox`** (2 requirements restated in full): `team say` reports a dirty target as *queued*; the
  turn-end knock goes through the guard.
- **`watchdog`** (1 requirement restated in full): a dirty PM box holds the wake line; the tick still records the
  batch and `state/nudges.log` line.
- No code, test, reference or ledger file changes in this phase; the apply brief follows the PM's proposal review.

## Capabilities

### New Capabilities

- `delivery-guard`: guard, outbox format, drain, TTL/hold, dedup, visibility, draft entry, and which senders defer
  (`--now` the audited override).

### Modified Capabilities

- `notify-and-inbox`: `team say` and the turn-end knock defer instead of typing into a busy box.
- `watchdog`: the wake line is held instead of glued.

## Impact

At archive time `delivery-guard` is created and the two modified capabilities each gain one sentence and one scenario
inside restated requirements; the code changes land in the apply phase.

## Acceptance (verbatim)

```sh
openspec validate --all --strict
bash skills/teamsmith/tests/spec-lint.sh
```

## Boundaries

- Only `openspec/changes/deferred-delivery-and-draft-entry/**` and `docs/team/reports/P5-dev2.md` may be written;
  `openspec/specs/**` is archive's job and no code, test, reference or ledger file is touched.
- Out of scope: C (the PM-side channel), the D19 dashboard, the meeting knock (cross-project), and the
  `say`/notify/extension rewiring (apply phase).
- The report carries: the `openspec change show` transcript, both gates' tails, the scratch-archive summary, the
  created `delivery-guard` spec (no `TBD`), a `MODIFIED`-block diff against the base specs, and the requirement →
  scenario → falsifier map.
