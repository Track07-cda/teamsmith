# Design: `capacity-floor-disk` — one floor for the filesystems a worker writes to

## Context

`team_mem_guard` (the dispatch floor) reads `/proc/meminfo` and `/proc/swaps` only; the recon in
`docs/team/reports/P141-dev-bob/recon.log` shows no `df` anywhere in the floor and a capacity line with no disk
figure. D67 measured the consequence: `/tmp` (15 GB tmpfs, shared with other projects) filled to `ENOSPC`, pi died
mid-turn, one seat was lost with its report and evidence. P53 (`test-tmp-hygiene`) already gave `team doctor` one
temp-root headroom row with `TEAM_TMP_MIN_FREE_MB=1024` / `TEAM_TMP_MIN_FREE_INODES=100000` and the two `df` calls
the row needs; the change reuses that measurement instead of inventing a second one. See `proposal.md` — Why.

## Goals / Non-Goals

**Goals.**

1. The dispatch floor judges the filesystems a worker will write to — free bytes **and** free inodes — before a
   window opens (`--print` included), and refuses below the floor with the measured figures and a fix.
2. Every reader of the capacity line (patrol log, `team up`, `team ps`, panel, `team doctor`) shows the measured
   disk readings, not a verdict.
3. An unreadable path, or a filesystem that does not report inodes, is never a refusal and never a guessed number.
4. The floor's knobs are contract rows: the two thresholds are `apply` schema keys whose `0` escape hatch is
   reachable through the audited writer, the fixture seam is a registered `refuse` test knob, and all three carry
   the zh/en labels the console's settings view renders.

**Non-Goals.**

- A filesystem sweep beyond the temp root and the worktrees root; automatic cleanup (tmp-hygiene's job, and its
  ownership proofs stay untouched); refusing or waking the patrol on disk alone; changing the memory/swap floors;
  a disk trend/spark (RAM keeps the spark); widening the config-completeness walk itself (the PM opened a separate
  task for that — this change registers the keys it introduces and pins them).

## Decisions

### D1 — one floor, the existing keys: `TEAM_TMP_MIN_FREE_MB` (1024) and `TEAM_TMP_MIN_FREE_INODES` (100000)

The disk leg is one sentence — "no dispatch when a filesystem a worker will write to is below the disk floor" —
so it reads one threshold pair. That pair already exists: P53 calibrated it for the doctor row, and the doctor
row already prints it. Reusing it buys an invariant instead of a coincidence: **the doctor warns exactly when the
next dispatch will be refused.** The brief's example names (`TEAM_MIN_AVAIL_DISK_MB` / `TEAM_MIN_AVAIL_INODES`)
are marked "such as"; adopting them while keeping the old pair would put two thresholds on the same filesystems
(one warning, one refusal) and let them drift. Renaming the old pair with aliases would grow the config surface
for zero behavior change. The spec promises behavior, not key names; if the PM prefers the example names, the
rename is confined to one implementation row and the doc rows.

Defaults, with the derivation (P53 design F2, re-measured here):

| Figure | Default | Basis |
|---|---|---|
| free bytes | 1024 MB | one gate round's root measured 95 MB / 11,797 files; a killed `config-cli` root 99 MB / 10,954 files → ~10 gate rounds of headroom before the floor |
| free inodes | 100000 | the same 10,954-file roots → ~9 roots of headroom; the tmpfs died with 4,645 of 3,811,434 inodes free |

Both values are far above the zero that killed the seat and far below the idle measurements (recon `3`: temp
root 7.4 GB / 3.0 M inodes free; worktree 289 GB), so a healthy machine never trips them.

### D2 — refuse, and keep the memory floor's escape hatch

Refusal, not warning: the measured failure is a seat killed mid-turn (work, report and evidence lost), and the
floor trips at 1 GiB / 100k — a margin, not the cliff. A warning is the shape already used for advisory resources
(zram, the doctor row) and D67 shows the environment reached zero anyway. The escape is explicit and typed, the
same shape as `TEAM_MIN_AVAIL_MB=0 team dispatch …`: `TEAM_TMP_MIN_FREE_MB=0` / `TEAM_TMP_MIN_FREE_INODES=0`
disable the respective leg. Not `--force`: the memory floor is not `--force`-overridable, and `--force` is
reserved for identity/ledger guards with audit lines.

P140 (`dispatch-friction` apply) is in flight and turns pre-launch refusals into one pass with a `修法：` line per
blocker. This requirement is written to slot in: it names the path, the measured figures, the threshold crossed
and a `修法：` command. It does not depend on P140 landing first; without it the floor keeps today's refusal shape
with the added fix line.

### D3 — one seam: `TEAM_DISK_STATS_FILE` over real `df`

Production reads `df -P -k <path>` and `df -P -i <path>`, row 2 — the same two calls and the same fields the
doctor row already uses (P53 measured 3.7 ms per pair; the panel health path's budget is why it stays two calls).
The fixture seam `TEAM_DISK_STATS_FILE` holds `path<TAB>total_kb<TAB>avail_kb<TAB>itotal<TAB>ifree` rows; the
longest matching path prefix wins, a path with no row is unreadable, `itotal=0` (or `-`) marks the inode leg not
applicable. This is the `TEAM_MEMINFO_FILE` idiom — a fixture replacing one system read — and it is the only way
to express all three required scenarios (full, plenty, unreadable) without a second filesystem.

Rejected alternative: a fake `df` on `PATH` — brittle parsing of human output, PATH-order coupling, and it cannot
express "this path is unreadable" without more shim logic.

Rules the seam and the real path share: unreadable = `df` non-zero **or** a missing/non-numeric column **or** no
fixture row; not-applicable inodes = `itotal` empty/zero. Unreadable and not-applicable are **silent for the
judgement** (no refusal, no warning line from the guard) and render as `无法读取` / `n/a` in the visible reading,
never as a number. Readings carry the resolved device where `df` reports one (the fixture table is per path), so
the same real filesystem reached through both paths is judged and printed once.

### D4 — which paths are judged, per surface

- `team dispatch`: `${TMPDIR:-/tmp}` and the target agent's worktree (`team_agent_worktree <agent>`) — what this
  worker will write to.
- The shared surfaces without a target (patrol tick, `team up`, `team ps`, panel, `team doctor`): the temp root and
  the worktrees root (`TEAM_WORKTREES_DIR`, the directory the dispatches will use) — a stand-in for the family.
- Nothing else is scanned (non-goal).

### D5 — the reading is the same everywhere

`team_capacity_line` becomes:

```
RAM 可用 8000MB ｜ 磁盘 swap 空闲 64511MB ｜ 临时根 /tmp 可用 7.4GB（inode 3017869）｜ 工作树 <path> 可用 289.2GB（inode n/a）｜ 估算可再加 N 个 agent
```

Unreadable renders `无法读取`. The patrol log line embeds this line, so `capacity.log` gains the columns; the
panel's spark parser matches `RAM 可用 NMB` first, so the existing spark keeps working. `team doctor` prints one
row per filesystem with the same figures and floor, its warning says "现在派单会被拒绝" (the swap row's wording),
and its exit code stays 0 (host resource, operator remedy — the P53 contract). The panel band and
`panel.capacity` carry the readings (`panel.capacity.disk[]`: `path`, `avail_mb`, `free_inodes` or null,
`readable`), rendering `—` for unreadable/not applicable.

### D6 — the remedy is attributable (D58)

- Temp root → `bash <skill>/tests/tmp-hygiene.sh --status` (inventory) then `--sweep` (only roots whose ownership
  the tool can prove). Nothing else may be deleted, and the sweep's refusals are not touched.
- Worktree filesystem → the refusal names the path and says to free that filesystem; tmp-hygiene is not its fix.
- The refusal also prints the explicit override command, so the PM can choose to proceed knowingly.

### D7 — the tests and their flips

Smoke section 6b (the memory/swap matrix) gains the disk matrix next to it, all with the fixture table:

| Fixture | Expected |
|---|---|
| temp root 120 MB / 40k inodes free | refused; output names path, figures, thresholds and `修法：…tmp-hygiene.sh --sweep` |
| both paths 5 GB / 2.9M free | allowed; the capacity line prints the figures |
| no row for the path | allowed; no refusal, no invented number |
| `itotal=0`, bytes plenty | allowed; inode leg silent |
| `itotal=0`, bytes low | refused on bytes only (the no-inode filesystem still gets the bytes leg) |
| `TEAM_TMP_MIN_FREE_MB=0 TEAM_TMP_MIN_FREE_INODES=0` | the full fixture is allowed |

The flip: break the implementation (remove the guard call, or swap the `df` columns) → the full/plenty assertions
must go red; restore → green. The recon log's prototype already demonstrates the five fixture outcomes
(`recon.log` 4.1–4.4).

### D8 — the three knobs are schema rows, and the escape goes through the audited writer (R1)

The disk leg makes a **refusal** decision, and its escape is `TEAM_TMP_MIN_FREE_MB=0` /
`TEAM_TMP_MIN_FREE_INODES=0`. Today neither key is a schema row: `cmd-status.sh` reads them from the environment
(`:-1024` / `:-100000`) and `references/config.md` records the P53 ruling that the temp-root knobs are
**deliberately environment-only**. That ruling cannot stand for a refusal floor: `team config set` — the only
writer of `.pi/team/config.sh` — cannot set the keys, the settings view cannot show them, and the escape hatch is
reachable only by hand-editing the contract, which is the path this project keeps closing. So the change registers:

| Key | Schema row | Why |
|---|---|---|
| `TEAM_TMP_MIN_FREE_MB` | `apply` · `mb` · `0,` · default `1024` · danger `0 = 临时根可用空间底线关闭` · suggest `512,1024,2048` · group `delivery` | the bytes floor; the same class, group and danger shape as `TEAM_MIN_AVAIL_MB` |
| `TEAM_TMP_MIN_FREE_INODES` | `apply` · `int` · `0,` · default `100000` · danger `0 = 临时根 inode 底线关闭` · suggest `50000,100000,200000` · group `delivery` | the inode floor; same shape |
| `TEAM_DISK_STATS_FILE` | `refuse` · `path` · `file,opt` · route names the fixture and the hand-edit route · group `policy` | the fixture seam is a test knob, not a settable floor — `refuse` is the class the sibling knobs carry (`TEAM_MEMINFO_FILE`, `TEAM_SMOKE_FAST`) |

`0` is a danger value on the two thresholds exactly as it is on `TEAM_MIN_AVAIL_MB`: the write needs
`--allow-danger`, and even then it leaves its one `result=ok` audit line — the escape is typed, confirmed and
audited instead of silent. The labels (`label_TEAM_TMP_MIN_FREE_MB`, `label_TEAM_TMP_MIN_FREE_INODES`,
`label_TEAM_DISK_STATS_FILE`) are what the settings view renders (`panel`'s contract-view requirement); the
string-table gate asserts them in both directions and within the row's 22-cell label column, so a schema key
without a label is red in the fast gate. `references/config.md`'s "deliberately not part of the config surface"
paragraph is rewritten for these three keys: the two thresholds leave that list because they are floors now, while
`TEAM_TMP_KEEP` and `TEAM_TMP_SWEEP_AGE` stay environment-only — no other temp-root knob is swept in, and the
completeness walk itself is not widened (its docs→schema leg only reads backticked key mentions, a hole the PM
opened a separate task for).

Scenario homes: the audited-writer escape and its dispatch consequence are one scenario in `dispatch`; the three
rows' classes and labels in the view and in `team config list --json` are one scenario in `panel`.

## Risks / Trade-offs

- **[False refusal on a busy shared `/tmp`]** → the floor is 1 GiB/100k, the refusal names the fix and the explicit
  override; fixtures keep the tests machine-independent.
- **[`df` cost on the panel health path and every tick]** → two `df` calls per path, the same calls the doctor row
  already makes; the tick already computes the capacity line, so the patrol adds ≤4 calls, and the panel's health
  TTL is 600 s.
- **[A filesystem that reports no inode table (btrfs here)]** → the inode leg is explicitly not judged; a scenario
  pins it (recon `3`: `df -P -i` prints `0/0` for this worktree).
- **[P140 lands first and changes refusal shape]** → the requirement names the fields, not a layout; the one-pass
  collector can render the disk blocker as one item.
- **[Key names read as TMP-only]** → `references/config.md` and `references/troubleshooting.md` state the widened
  scope (temp root **and** worktrees filesystem); the proposal records the alternative names.
- **[The two thresholds leave the environment-only list]** → only the two floors do; the other temp-root knobs
  stay, `0` keeps its danger confirmation and audit line, and the settings view renders what the schema carries.

## Open Questions

None.
