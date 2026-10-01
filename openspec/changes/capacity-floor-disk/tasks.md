# Tasks: `capacity-floor-disk`

Planning only — nothing here is executed by the propose task (P141). The apply is one dependency-ordered whole:
the measurement and the floor first (the guard must exist before dispatch can print or refuse), then the schema
rows and labels the console carries (section 8) and the surfaces that read the measurement, then the tests that pin
the three required scenarios and their flips. The verify phase is a separate brief owned by a different agent.

Coverage map (requirement → items): **R1** `dispatch#The capacity floor protects the host` → 1.1–1.4, 5.4; **R2**
`watchdog#Restart quota and capacity logging` → 2.1–2.2; **R3** `watchdog#\`team doctor\` reports the temp root's
headroom` → 3.1–3.2; **R4** `panel#The status band answers "who is in charge" and "is there work"` → 4.1–4.3;
**R5** `panel#The disk floor's keys are contract rows the console carries` → 8.1–8.3, 5.5; scenario flips →
5.1–5.5; gates/evidence → 6.1–6.4; docs → 7.1–7.2.

How each requirement is re-checked (run what → read which part → expected value):

| Req | Run | Read | Expected |
|---|---|---|---|
| R1 | `team dispatch dev T1.1 <brief> --print` under the `TEAM_DISK_STATS_FILE` fixtures (full / plenty / no row / `itotal=0` / full bytes) plus `team_mem_guard` directly, and the audited write `team config set TEAM_TMP_MIN_FREE_MB 0 --allow-danger --yes` | exit codes; the refusal's `修法：` line; the passing capacity line's figures; the config audit line | full refuses naming path+figures+threshold+sweep; plenty allows and prints both paths' bytes/inodes; unreadable and no-inode filesystems never refuse and print no invented number; the audited write lands one `result=ok` line and clears the refusal (without `--allow-danger` it exits 7 and writes nothing) |
| R5 | `team config list --json`, `team config set <KEY> 0` (with and without `--allow-danger`), `team config set TEAM_DISK_STATS_FILE …`, `node tests/panel-strings.mjs`, and the settings fixture (`panel-p21.sh settings`) | the three records' class/default/group; the view rows' main text | the two thresholds are `apply` records with defaults 1024/100000 and group `delivery`, the seam is `refuse` (exit 5 on a write), each row's text is its label (no `TEAM_…`), the strings gate covers all three in both tables |
| R2 | `team watch --once` twice with the fixture and a fixture session | the last two `state/capacity.log` lines | each carries the timestamp, RAM/swap and both filesystems' available bytes and free inodes |
| R3 | `team doctor` with the fixture low, unreadable, and no-inode | the two filesystem rows and the exit code | rows carry measured figures; low warns with "派单会被拒绝" and the remedy; unreadable is a warning, never a pass; doctor exits 0 |
| R4 | `team monitor --print` and `team monitor --json` with the fixture | `panel.capacity.disk` and the printed band | one entry per judged filesystem with path/bytes/inodes; unreadable renders `—` and carries no number; no zram physical MB |

Path grants the apply brief must state: `skills/teamsmith/tests/**` is agent-owned. The named hunks of
`skills/teamsmith/scripts/lib/{common,cmd-agents,cmd-config,cmd-watch,cmd-status,cmd-project}.sh`,
`skills/teamsmith/scripts/panel/**` (including `src/strings/{zh,en}.ts`, with the rebuilt committed bundle),
`skills/teamsmith/SKILL.md` and `skills/teamsmith/references/{config,troubleshooting}.md` are **PM-owned** and
need an explicit grant for those hunks only. Untouched: `team_mem_guard`'s thresholds and judgement, the
model/session guards, the tmux launch harness, `tests/tmp-hygiene.sh`'s ownership proofs (only its command name
may be printed), `openspec/specs/**`, and the config-completeness walk itself.

Fixture notes: every fixture clears the inherited team identity (`TEAM_ROOT TEAM_MAIN_ROOT TEAM_PROJECT
TEAM_SESSION TEAM_TMUX_CALLS_LOG TEAM_TMUX_REAL`) and runs in its own scratch git repo with the record-only
`tmux` shim first on `PATH`; nothing may reach a real tmux server (M36/D57). The disk fixtures are
`TEAM_DISK_STATS_FILE` tables under the owned tmp family (`teamsmith-<kind>.XXXXXX`, reclaimed by
`tests/tmp-hygiene.sh`). Any item that needs a real process is marked `[real]` and is never the only evidence for
a requirement. The propose recon (`docs/team/reports/P141-dev-bob/recon.{sh,log}`) is the baseline the flips
compare against.

## 1. R1 · the measurement and the disk/inode leg (`dispatch`)

- [x] 1.1 `common.sh`: add `team_disk_stats <path>` — production path `df -P -k` + `df -P -i` row 2; fixture path
  `TEAM_DISK_STATS_FILE` (rows `path<TAB>total<TAB>avail<TAB>itotal<TAB>ifree`, longest matching prefix wins); a
  missing row, a failing `df` or a missing/non-numeric column yields no figure; `itotal` empty/0 means the inode
  table is not applicable. Verify: a fixture row resolves to its four numbers; a path with no row yields empties;
  the real worktree (`df -P -i` reports `0/0` here) yields an inapplicable inode leg, and `/nonexistent-p141`
  yields nothing.
- [x] 1.2 `common.sh`: add `team_disk_guard <path...>` and the human-size helper — refuse when available bytes <
  `TEAM_TMP_MIN_FREE_MB` (default 1024) or, only for a reporting filesystem, free inodes <
  `TEAM_TMP_MIN_FREE_INODES` (default 100000); non-numeric threshold → default; `0` → leg off; one judgement per
  resolved device; unreadable/not-applicable = silent. Verify: the recon's five fixture outcomes (full → both
  legs refuse; plenty → allow with figures; no row → silent allow; `itotal=0` plenty → allow; `itotal=0` low bytes
  → bytes-only refusal) reproduce with the production functions.
- [x] 1.3 `cmd-agents.sh`: call the guard in the pre-launch phase (before any window, `--print` included, next to
  `team_mem_guard`), print the measured capacity line when it passes, and make the refusal carry the path, the
  figures, the threshold and one `修法：` line (temp root → `tmp-hygiene.sh --status`, then `--sweep`; worktree →
  free that path) plus the `TEAM_TMP_MIN_FREE_MB=0` / `TEAM_TMP_MIN_FREE_INODES=0` override. Verify: R1's five
  `--print` fixtures; the full fixture's refusal names both measured figures and the remedy, and the override
  clears it; no window is requested on any refusal.
- [x] 1.4 `cmd-agents.sh`/`common.sh`: resolve the judged worktree path for a dispatch to the agent's worktree
  (`team_agent_worktree`), not the shared worktrees root. Verify: a fixture whose worktree row is low refuses
  naming that worktree path; the same fixture with only the worktrees root low still judges the temp root.

## 2. R2 · the patrol and the capacity line (`watchdog`)

- [x] 2.1 `common.sh`: extend `team_capacity_line` with the temp root's and the worktrees root's measured
  availability and inode figures (`无法读取` / `n/a` where a leg is not judged), keeping RAM first and the agent
  estimate last. Verify: `team ps` under the fixture names both paths with the fixture's figures; the zram
  assertions of smoke 6b stay green.
- [x] 2.2 `cmd-watch.sh`: make the tick line carry the new figures and keep the 500-line cap working; `[real]`
  the two ticks run in the fixture session with the record-only shim. Verify: two `team watch --once` runs leave
  two `capacity.log` lines with timestamp + RAM/swap + both filesystems' bytes and inodes; the panel spark still
  finds its RAM samples.

## 3. R3 · `team doctor` (`watchdog`)

- [x] 3.1 `cmd-status.sh`: make the temp-root row a per-filesystem row (temp root + worktrees root, one row when
  the device is shared), same floor and figures, warning text says the next dispatch will be refused, unreadable
  and no-inode-table say so instead of a number or a pass. Verify: three doctor shapes — healthy (`pass` rows),
  fixture-low (warn naming path/figures/threshold/remedy, exit 0), unreadable (warn, never pass) — and a
  `df -i`-reports-nothing filesystem (no inode verdict).
- [x] 3.2 `cmd-project.sh`: keep the capacity check's structure but reuse the new row(s) so doctor prints one
  verdict per judged filesystem and the swap warning is unchanged. Verify: `team doctor` output carries both rows
  once and the existing swap-warning assertion still passes.

## 4. R4 · the panel (`panel`)

- [x] 4.1 `cmd-watch.sh` (`team_panel_capacity_json`): add `disk` entries (`path`, `avail_mb`, `free_inodes` or
  `null`, `readable`) sourced from the same measurement. Verify: `team __panel-data --block capacity` carries the
  fixture's paths and figures; the unreadable fixture carries `null`, not a number; the degraded contract (no
  readable `capacity.log` → non-zero) is unchanged.
- [x] 4.2 `scripts/panel/src/**`: render the disk readings in the status band with the `—` fallback and add the
  zh/en strings, then rebuild the committed bundle per the panel bundle requirement. Verify: `team monitor
  --print` shows the readings; `team monitor --json` parses; the string-table and bundle tests stay green.
- [x] 4.3 Confirm no zram physical figure and no disk spark entered the band (the band's existing rule). Verify:
  the `--json` output carries no `zram` key in `panel.capacity` and the spark is still RAM-built.

## 5. Scenarios and flips

- [x] 5.1 `tests/smoke.sh` (section 6b): add the six disk fixtures from R1 (full, plenty, unreadable, `itotal=0`
  plenty, `itotal=0` low, full + both legs zeroed) with the assertions of R1's table, plus the capacity-line and
  doctor reading assertions. Verify: the section is green; each fixture's output tail is pasted in the report.
- [x] 5.2 Flip: break the implementation (remove the guard call, or swap the `df` total/avail columns) → the
  full/plenty assertions must go red; restore → green. Verify: both raw outputs in the report, with the restored
  run green.
- [x] 5.3 FAST behaviour: `TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null` stays green and the
  new section is either run or visibly skipped, never silently absent. Verify: the tail naming section 6b.
- [x] 5.4 R1's escape scenario in the config fixture or smoke: with the full temp-root fixture, `team dispatch …
  --print` refuses; `team config set TEAM_TMP_MIN_FREE_MB 0` exits 7 with the contract byte-identical and a
  `danger-refused` audit line; `team config set TEAM_TMP_MIN_FREE_MB 0 --allow-danger --yes` exits 0, leaves the
  contract parseable with one `result=ok` line, and the same dispatch then exits 0. Verify: the raw before/after
  tails in the report.
- [x] 5.5 R5's scenario: `team config list --json` records (`apply`/`1024`/`100000`/`delivery`, seam `refuse`) and
  the settings fixture's three rows (labels, no `TEAM_…` main text; the seam's row opens no editor). Verify: the
  JSON tail and the fixture's scene in the report.

## 6. Gates and evidence

- [x] 6.1 `PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict` passes with the change's deltas.
- [x] 6.2 `TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null` passes.
- [x] 6.3 `bash skills/teamsmith/tests/smoke.sh </dev/null` passes on an idle-enough machine (if the machine
  premise reddens a timed panel section, record the load and re-run; the section's own premise governs).
- [x] 6.4 Report `docs/team/reports/<ID>-<agent>.md`: the red→green tails of 5.1–5.2, the doctor/panel/
  capacity-log raw outputs, both gate tails, and the delta→requirement map.

## 7. Docs

- [x] 7.1 `references/config.md`: the two keys' widened scope (temp root **and** worktrees filesystem) with the
  defaults' derivation; register both in the backticked key table (the schema→docs completeness direction reads
  it) and move them out of the "deliberately not part of the config surface" paragraph — `TEAM_TMP_KEEP` and
  `TEAM_TMP_SWEEP_AGE` stay there; add the `TEAM_DISK_STATS_FILE` fixture row. Verify: `tests/config-cli.sh`
  completeness green in both directions and the env-only paragraph names only the two remaining knobs.
- [x] 7.2 `references/troubleshooting.md` (and `SKILL.md` only if its command table mentions the floor): the
  ENOSPC row — what refuses, what the refusal prints, the `tmp-hygiene` remedy and the explicit override.
  Verify: `grep` finds the disk leg next to the memory/swap floor in both docs.

## 8. R5 · the three keys are contract rows (schema + labels)

- [x] 8.1 `cmd-config.sh` (PM-owned hunk): register the two thresholds —
  `TEAM_TMP_MIN_FREE_MB|apply|mb|0,|plain|1024|0 = 临时根可用空间底线关闭||512,1024,2048|delivery` and
  `TEAM_TMP_MIN_FREE_INODES|apply|int|0,|plain|100000|0 = 临时根 inode 底线关闭||50000,100000,200000|delivery` —
  and the seam `TEAM_DISK_STATS_FILE|refuse|path|file,opt|plain||-|测试旋钮：磁盘读数夹具（TEAM_MEMINFO_FILE 同族）；只在夹具里用||policy`.
  Verify: `team config list --json` reports class/default/group/known for all three; `team config set
  TEAM_TMP_MIN_FREE_MB 0` exits 7 writing nothing and its `--allow-danger` form validates; `team config set
  TEAM_DISK_STATS_FILE <path>` exits 5; `tests/config-cli.sh` green (groups / choices / completeness walks).
- [x] 8.2 `panel/src/strings/{zh,en}.ts`: `label_TEAM_TMP_MIN_FREE_MB` (planned `临时根空间底线` / `Temp root space
  floor`), `label_TEAM_TMP_MIN_FREE_INODES` (`临时根 inode 底线` / `Temp root inode floor`) and
  `label_TEAM_DISK_STATS_FILE` (`磁盘读数夹具` / `Disk stats fixture`) — non-empty, not a re-spelling of the key,
  ≤22 cells in en (the planned en labels measure 21/21/18) — then rebuild the committed bundle. Verify:
  `node skills/teamsmith/tests/panel-strings.mjs` green.
- [x] 8.3 the fixtures that count schema keys get the new total, never a hardcoded stale number (the config
  fixture's group/choices walks and `panel-p21.sh settings`' row count). Verify: the named fixtures green before
  delivery; a correct row count does not turn one red.
