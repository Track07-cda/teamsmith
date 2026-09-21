## Why

The inbox fast-wake channel uses `fs.watch`. On 2026-09-21 the host exhausted its inotify quota (`65536` maximum; Syncthing held `64737`), so `fs.watch` raised `ENOSPC`; the harness emitted 31 failures and 12b-pi emitted six reds that initially looked like an M50 regression (`docs/team/reports/M50b-dev2.md` §4). The extension silently loses the errno and quota, while `.reg` makes `team doctor` report a healthy channel although only its 5-second poll fallback remains.

## What Changes

- **ADDED — `notify-and-inbox`**: record watcher-registration failure (`errno`, quota observation, poll interval) in the ledger and a live `<key>.degraded` record; retain `.reg` and prove that polling delivers once. The inbox-watch harness measures its `fs.watch` premise, visibly skips only watcher-dependent cases when unavailable, and has strict mode that still fails them.
- **ADDED — `watchdog`**: `team doctor`/`team status` name a live degraded channel instead of a false healthy fast path; doctor reports quota, trustworthy usage or `unknown`, a registration probe, warning threshold and operator remedy.
- **ADDED — `panel`**: a degraded watcher produces `delivery_warning` without claiming the paste-path fallback.
- Docs: add the ordered wake-up troubleshooting path and document the fixture controls. No tool changes the host quota.

## Capabilities

### Modified Capabilities

- `notify-and-inbox`: failure record, polling fallback, and falsifiable watcher-premise behavior of its harness.
- `watchdog`: operational reporting of the degraded channel and inotify headroom.
- `panel`: correct degraded-channel delivery warning.

## Impact

`extension/team-inbox-watch.ts`, the inbox-watch harness and smoke section; `scripts/lib/{outbox,cmd-project,common}.sh`, `cmd-watch.sh`, panel strings/bundle, and troubleshooting/config references. Routing, message shape, default poll interval, outbox/delivery-guard behavior and `standby` are unchanged.

## Acceptance

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh
TEAM_INBOX_WATCH_FORCE_FAIL=ENOSPC TEAM_IW_ONLY=S2,S22,S23 "$HOME/.bun/bin/bun" skills/teamsmith/tests/team-inbox-watch-harness.mjs skills/teamsmith/extension/team-inbox-watch.ts
TEAM_INBOX_WATCH_FORCE_FAIL=ENOSPC TEAM_IW_REQUIRE_WATCH=1 TEAM_IW_ONLY=S2 "$HOME/.bun/bin/bun" skills/teamsmith/tests/team-inbox-watch-harness.mjs skills/teamsmith/extension/team-inbox-watch.ts
```

The final command is expected to fail: strict mode proves that a visible SKIP is not an unconditional green.

## What flips

Before: `watch unavailable: falling back to polling only`; doctor falsely says the PM session is registered; a dry host produces 31 harness failures. After: the ledger/record name `errno`, `watches` and `fallback=polling`; reporting names polling degradation and the 524288 remedy; a dry premise visibly SKIPs while strict mode fails. Dropping the recorded fields, polling timer, degraded reader, probe result, or strict failure makes its named guard red.

## Boundaries

Planning only. This task writes `openspec/changes/watch-degradation/**` and its report; it does not edit implementation. Apply must not change the default poll interval, wake message format, outbox/delivery-guard/draft safety, `standby`, or retry `fs.watch`; privileged quota changes remain operator documentation. PM-owned implementation/reference paths require an explicit apply-brief grant; tests remain `agent:dev`-owned.

## Evidence the report must contain

Acceptance and trial-archive tails; requirement-to-task and scenario-to-fixture maps; dry-host prerequisite/SKIP output, false-green-before/degraded-after doctor output, and every red/restore flip tail.
