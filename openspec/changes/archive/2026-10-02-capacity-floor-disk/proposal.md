# capacity-floor-disk · proposal

## Why

2026-09-30: the shared 15 GB `/tmp` tmpfs filled and pi died mid-turn with `ENOSPC` (D67).
The dispatch floor reads only RAM and swap (recon `1`: no `df`), so the worker started with its filesystem at
the wall: the memory floor's failure mode, one filesystem over.

## What Changes

- **MODIFIED — `dispatch#The capacity floor protects the host`**: before any launch (`--print` included) the floor
  judges the free bytes **and** inodes of the filesystems a worker writes to — the temp root
  (`${TMPDIR:-/tmp}`) and the worktree filesystem — refusing below `TEAM_TMP_MIN_FREE_MB` (1024) or
  `TEAM_TMP_MIN_FREE_INODES` (100000), naming path, figures, threshold and a `修法：` command (temp
  root: the ownership-proven `tmp-hygiene.sh --status|--sweep`; worktree: free that path). The existing key pair
  becomes this one floor, not a second threshold on the same filesystems (design D1); `=0` disables a leg through
  the audited writer (`team config set <KEY> 0 --allow-danger`, design D8). An unreadable figure, or a filesystem
  without an inode table, is never judged: silence, no refusal, no invented number; a passing floor prints its
  readings.
- **MODIFIED — `watchdog#Restart quota and capacity logging`**: the per-tick `capacity.log` line carries the
  disk/inode readings beside RAM/swap, so the trend covers the filesystem that killed a seat.
- **MODIFIED — `watchdog#\`team doctor\` reports the temp root's headroom`**: one row per filesystem with the same
  figures and floor, warning "现在派单会被拒绝"; unreadable is never reported as fine.
- **MODIFIED — `panel#The status band answers "who is in charge" and "is there work"`**: the band and
  `panel.capacity.disk` carry the readings (`—` when unreadable or not applicable).
- **ADDED — `panel#The disk floor's keys are contract rows the console carries`**: the two thresholds are `apply`
  schema rows (defaults 1024/100000, group `delivery`, `0` behind the same danger confirmation and audit line as
  the memory floor) and `TEAM_DISK_STATS_FILE` a `refuse` test-knob row; the settings view carries all three with
  their zh/en labels and `team config list --json` reports the same classes, defaults and group (design D8).

## Capabilities

### Modified Capabilities
- `dispatch`, `watchdog`, `panel`: the disk/inode leg and its readings.

## Impact

`skills/teamsmith/scripts/lib/{common,cmd-agents,cmd-config,cmd-watch,cmd-status,cmd-project}.sh`,
`skills/teamsmith/scripts/panel/**` (including `src/strings/{zh,en}.ts`) plus the rebuilt bundle,
`skills/teamsmith/tests/**`, `skills/teamsmith/references/{config,troubleshooting}.md`. Untouched: the memory/swap
floors, the model guards, tmp-hygiene's ownership proofs, tmux, any auto-cleanup, the config-completeness walk
itself.

## What flips

- **Blindness**: a full temp root cannot refuse today (`team_mem_guard` has no `df`; recon `1`) → refused with the
  measured figures and the sweep fix, red→green on one fixture.
- **Reverse**: unreadable figures, and a filesystem without an inode table (measured: this worktree's `df -P -i`
  prints `0/0`), must allow — both are scenarios.
- **Visibility**: `RAM 可用 8000MB ｜ 磁盘 swap 空闲 64511MB ｜ 估算可再加 11 个 agent` (recon `2`) gains both
  filesystems' figures here, in `capacity.log`, in the doctor rows and in the band.
- **The escape is not a hand-edit**: the two thresholds are environment-only today (documented as deliberately
  outside the config surface, no schema row), so `team config set TEAM_TMP_MIN_FREE_MB 0` exits 5 while the
  refusal needs it — after the change the same write goes through the audited writer and the settings view shows
  both keys with their labels; `TEAM_DISK_STATS_FILE` is registered as a `refuse` test knob instead of an
  undocumented hole.

## Acceptance

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
bash skills/teamsmith/tests/smoke.sh </dev/null
```

The first line runs now; the other two need the apply commit.

## Boundaries

Planning only: this task writes `openspec/changes/capacity-floor-disk/**` and its report. The apply needs the
brief's grant for `skills/**`; it must not weaken the memory/swap floors or tmp-hygiene's ownership proofs, scan
filesystems beyond the temp root and the worktrees, auto-clean, wake the patrol on disk alone, or touch
`default` tmux.

## Evidence the report must contain

Propose: the validate tail, the delta→requirement map, the scenario inventory and the recon
(`recon.sh`/`recon.log`): the three fixture outcomes and the controls, raw. Apply: each scenario's red→green,
the capacity-log/doctor/`panel.capacity` tails, and both gate tails.
