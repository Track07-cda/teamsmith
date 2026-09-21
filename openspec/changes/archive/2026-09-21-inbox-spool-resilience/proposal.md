# Propose: `inbox-spool-resilience` — the wake reader counts bytes, and stale lines never wake

## Why

On 2026-09-20 06:42:39 the PM's inbox watcher recorded `baseline=19635` on a 19634-byte spool, re-detected
"external shrink" every 5 s for 90 s, and woke the PM about 66 lines that were 1–2 days old
(`.pi/team/state/inbox-watch.log:179–205`). Cause (design §2): a spool preview cut mid-character by
`LC_ALL=C cut -c1-700` (`scripts/lib/outbox.sh:1017`) is not valid UTF-8, and `readNewLines()`
(`extension/team-inbox-watch.ts:351`) derives its new offset from `Buffer.byteLength` of the *decoded* slice — each
invalid byte becomes U+FFFD and measures 3 bytes, so the offset lands past the file end; `size < offset` then looks
like a rewrite on every tick, and the rescan path treats "not in `.seen`" as fresh. The same arithmetic, not an
external truncate, explains the 2026-09-19T16:59 replay M43 was diagnosed from (design §2.4).

## What Changes

- **ADDED** `notify-and-inbox`: the offset MUST advance by the bytes actually read (raw-buffer newlines,
  `readSync`'s return honoured) and MUST never exceed the file size.
- **ADDED** `notify-and-inbox`: a size regression is acted on only with evidence — same head + regression ≤
  `TEAM_INBOX_WATCH_CLAMP_BYTES` (default 64) is clamped, a changed head or larger regression is one bounded
  rescan, and the same (size, head) is never rescanned twice.
- **ADDED** `notify-and-inbox`: lines older than `TEAM_INBOX_WATCH_STALE_SEC` (default 900 s) never wake, on any
  path; they are counted and stay readable in the durable inbox / the sender's log.
- **ADDED** `notify-and-inbox`: the ledger separates traffic from recovery — `total` counts woken lines only; the
  rescan line carries `lines=/dup=/skipped=/stale=/deliver=`; clamps and repeats get their own lines.
- **ADDED** `notify-and-inbox` (B6, the PM's decision of 2026-09-20): the **sender's** preview clip cuts on a
  character boundary and is valid UTF-8 under `LC_ALL=C` too — the writer-side trigger of the incident is fixed
  in the same change (`scripts/lib/outbox.sh`, the clip only).

## Capabilities

### Modified Capabilities

- `notify-and-inbox` — four ADDED requirements; the watch/spool channel has none today (`grep -rn 'spool\|wake'
  openspec/specs/` matches nothing), and nothing existing is restated, so P27's later delta to the same file stays
  composable.

## Impact

`skills/teamsmith/extension/team-inbox-watch.ts`; `tests/team-inbox-watch-harness.mjs`, `tests/smoke.sh` (12b-pi),
new `tests/flip-p25.sh`; `references/{agent-adapters,troubleshooting}.md`. No `scripts/**` change: the writer-side
byte cut is a PM-owned follow-up (design §7); the reader must be byte-safe for arbitrary content anyway. `.seen`
keeps its format (not the trigger).

## Acceptance

This propose (run now):

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
git status --porcelain
```

The apply's acceptance (planned, not runnable yet):

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
bash skills/teamsmith/tests/flip-p25.sh
```

## The flip

Red before: harness S18 fails on today's tree (`baseline` = size + 1; a `spool shrink` per tick); green after: S18
passes and three idle ticks leave the ledger still. Breaking the clamp reintroduces the loop; breaking the rescan
fails S19's rewrite case (design §6).

## Boundaries

- This phase writes `openspec/changes/inbox-spool-resilience/**` and the report only. Apply needs explicit grants
  for `skills/teamsmith/extension/**`, `skills/teamsmith/tests/**`, `skills/teamsmith/references/**` (PM-owned).
- Out of scope: the wake channel, the outbox write path, `.seen`'s format, the writer-side `cut`, other specs.

## Evidence the report must contain

The root-cause chain with ledger/`.seen` bytes; both acceptance tails; per requirement the harness case and its
flip; and the M43/M46 assertions that stay green (S11–S17).
