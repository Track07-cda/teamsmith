# test-tmp-hygiene · design

Status: propose phase (planning only — no code in this change's proposal). Every number below was measured while
writing this proposal, on this host, on 2026-09-22 between 10:45 and 10:58 UTC; the commands are in the report
`docs/team/reports/P50-dev3.md`. The PM's own incident measurements (09:50, same day) are marked **PM**.

## 0. The problem, stated precisely

`/tmp` here is a 15 GB tmpfs shared by every process on the machine, including every agent's gate run. At **09:50 it
was 100 % full — 0 bytes free and the inode table full (3,811,434 inodes, 4,645 free) — and dev3's `panel-p21
choices` produced an ENOSPC false red** (PM). A gate that cannot say "the machine ran out of a shared resource" is
the "false green / false red" failure this project treats as worse than nothing: the verdict it printed was about
the code, the cause was the filesystem.

The composition, measured by the PM before the cleanup and re-measured here after it:

| What | PM (09:50) | Here (10:45–10:58) |
|---|---|---|
| `/tmp` | 100 %, 0 B free, inodes 4,645/3,811,434 free | 34 % used (5,127,268 of 15,245,736 KiB), inodes 571,125 used / 3,240,309 free |
| `config-cli.*` roots | **607 directories / 3,204 MB**, still being created by new runs | 0 (all were swept by hand) |
| `review-*` checkouts | **127 items / ≈ 6.0 GB** (M4.7r, M5.1, M5.2, M6.2–M6.5 …) | 0 on disk — **but 59 stale worktree registrations remain** (§D5) |
| `teamsmith-smoke.*` | 3 roots / 134 MB (one of them the running gate) | 0 after the PM's cleanup; **4 `teamsmith-flip-*` roots from 09-18/09-19 (896 KB–1.2 MB) are still sitting there**, unoccupied, 3–4 days old |
| orphan fixture processes | M58's `teamsmith-smoke-anchor` + `sleep 100000` (23 h), M39's three `-zsh` + `bash` groups (69 h) | 2 processes with a **deleted** cwd inside `teamsmith-smoke.*` (`sleep 3600` each) and one live gate root with a private tmux server and 11,797 files |
| `.teamsmith-smoke-diag.*` | — | 6 leftover tripwire files, oldest 09-19, kept by design (incident evidence) |

Three facts shape everything else:

- **F1 — the traps are already there; only `KILL` (and a dead machine) leaks.** 43 of 43 root-creating fixtures
  already carry a `trap … EXIT|INT|TERM` (measured: `grep -lE 'mktemp -d' tests/*.sh` → 43, all with a trap).
  Measured directly on bash 5.3.9: an untrapped fatal `TERM` **does** still run the `EXIT` trap (root removed), a
  `KILL` cannot be caught (root stays). So the requirement is not "add traps"; it is "the roots are uniform and
  attributable, and what a `KILL` leaves can be reclaimed and is visible".
- **F2 — a killed run leaves tens of MB and thousands of inodes, and one run can leave more than one root.** A real
  `tests/config-cli.sh` run (`TMPDIR=/tmp/p50probe/kill3`, full-run log 10,248 bytes, this run at 9,697) was sent
  `KILL` at t+20 s: its root survived at **99 MB / 10,954 files** and was still there 27 s later; nothing reclaimed
  it. The root count is not one-per-run: the `flip`/`groups-flip` sections run the fixture **again against a copied
  tree**, so two roots existed at the same moment and the nested run kept going after its parent died.
  The inode arithmetic of the incident follows: 3,811,434 inodes / 10,954 files ≈ **349** roots of that shape, and
  607 of the PM's leftovers at ≈6,300 files each ≈ 3.8 M — the whole table. `/tmp` filled up arithmetically, not by
  bad luck.
- **F3 — `smoke.sh` cannot be pointed away from `/tmp`, and `TEAM_CONFIG_KEEP` is dead.** `skills/teamsmith/tests/smoke.sh:215`
  is `TMP="$(mktemp -d /tmp/teamsmith-smoke.XXXXXX)"`; an explicit template makes `mktemp` ignore `TMPDIR`
  (measured: `TMPDIR=/tmp/p50probe/fake bash -c 'mktemp -d /tmp/teamsmith-smoke.XXXXXX'` → `/tmp/teamsmith-smoke.GrDZfz`).
  `tests/config-cli.sh:19–21` unsets every inherited `TEAM_*` variable (saving only `TEAM_CONFIG_TREE`) and reads
  `keep="${TEAM_CONFIG_KEEP:-0}"` at line 33, **after** that strip, so `TEAM_CONFIG_KEEP=1` is silently dropped: a measured run
  with `TEAM_CONFIG_KEEP=1 TMPDIR=D` left **no** root under `D` and exited 0 (✓125 ✗0, 25.2 s). 24 of the 43
  root-creating fixtures hardcode `/tmp` in at least one template; 19 use `${TMPDIR:-/tmp}`. The CI workflow works
  around the hardcoding by mounting the host's artifact directory *onto the container's `/tmp`*
  (`.github/workflows/gates.yml:66–73` — its own comment says the scene directory hardcodes `/tmp` and does not read
  `TMPDIR`, and that this is on P50's cleanup list).

## D1 — the temp root is `${TMPDIR:-/tmp}`, and no new knob

`TMPDIR` is the standard, it is what CI can set (`-e TMPDIR=/artifacts`), it is already the convention of 19
fixtures and of the gate's own lock (`${TEAM_SMOKE_LOCK:-${TMPDIR:-/tmp}/teamsmith-smoke.lock}`). A new
`TEAM_TMP_ROOT` would be a second way to say the same thing and a second thing to keep in sync. Rejected:
hardcoding `/tmp` (F3, and it makes a CI artifact upload require a mount), and a per-fixture knob (more knobs, no
uniformity).

## D2 — one owned family: `teamsmith-<kind>.XXXXXX`, plus `review-<ID>`

The sweep's safety rests on being able to *prove* a path is ours by name. The names in use today are a mixed bag
(`config-cli.*`, `install-shape.*`, `panel-*`, `teamsmith-flip-*`, `flip-p22.*`, `m62flip.*`, `pc.*`,
`p26premise.*`, `p12-keyprobe.*`, `task-header-model.*`, `load-experiment.*`). `pc.*` and `flip-p22.*` are generic
enough that a foreign tool could own them: a hand-maintained nine-prefix list would make the sweep's candidate set
exactly as trustworthy as the person who last edited it. The decided rule is therefore one family —
`teamsmith-<kind>.XXXXXX` for a fixture's own root — plus `review-<ID>` for the PM's checkouts (that name is
documented in `SKILL.md`, `references/workflows.md` and `references/migration.md` and is what the sweep's record
rule keys on), and the migration renames the outliers (tasks 1.2, 2.1). Cost: one literal per fixture plus any
comment that quotes it; benefit: the candidate predicate is two prefixes and a "is a directory, not dot-prefixed"
test, which the lint enforces (D4).

Today's legacy-named leftovers (`teamsmith-flip-p18.1/p20` ×2, `pc.*`, `m62flip.*`, …) are therefore **out of the
sweep's reach by design** — the four `teamsmith-flip-*` ones from 09-18/09-19 are in the family and become
sweepable; the others the PM removes by hand as before. This is a deliberate scope cut, not an oversight.

## D3 — one creator, an owner marker, a run ledger, and a real keep knob

`tests/lib/tmp-root.sh` is the only creator. It (a) creates the root under `${TMPDIR:-/tmp}` with a name in the
owned family, (b) writes `<root>/.teamsmith-tmp` — `kind`, the creating `pid`, that process's **start time**, the
`boot` id where available, and a run id —, (c) appends `<root>\t<pid>\t<started>` to the run ledger
(`$TEAM_TMP_LEDGER`, defaulting to a dot-prefixed file next to the roots so it survives them), (d) reaps the root
on `EXIT`/`INT`/`TERM`, and (e) exposes `tmp_root_track_pid` for processes that outlive a step. Rationale:

- the marker makes ownership *attributable* after the owner is gone, and makes "the owner is dead" **pid-reuse
  safe** (a live pid whose start time differs is a different process);
- the ledger is what lets the gate assert over exactly the roots *this run* created, without pattern-matching the
  shared filesystem;
- the keep knob is uniformly real: the current `TEAM_CONFIG_KEEP` path is dead (F3), which matters twice — an
  operator cannot inspect a fixture's state, and the residue guard's red side would have no way to leak on purpose.

Nested roots created inside an existing root (`$TMP/login-home.XXXXXX`) stay exempt: the parent's trap takes them.

## D4 — the entry point: `tests/tmp-hygiene.sh --status | --lint | --sweep | --self-test`

One script, one grammar, four verbs, exit codes `0` (clean / every candidate reclaimed or skipped by a printed
rule) and `3` (refused: a safety precondition could not be established, nothing deleted), `1` for `--lint`
findings. `--dry-run` prints the same inventory and deletes nothing. `--status` is read-only and always exits 0, so
it can be printed by anything (including the doctor's remedy line). `--self-test` carries the red sides: occupied,
orphan, unknown-mechanism, foreign-path, lock-file, registered-worktree, uncommitted-record, lint-flip.

Rejected: a `team …` subcommand (the skill deliberately wraps no git/forge operations and the sweep needs none of
the CLI's identity resolution; `team perf` is the precedent that a `tests/` suite can be fronted later, and that is
out of scope here), and a sweep flag on `team review` (the review must not delete anything in the shared `/tmp`).

## D5 — occupancy is proven by a process scan, and a registered worktree is never `rm -rf`'d

The sweep deletes only after proving no process holds the root: a scan of live processes whose current directory, an
open file descriptor or their executable lies inside the root — `/proc` on Linux (measured: a full cwd+fd scan over
228 processes takes 2.2 s), `lsof +D` as an optional cross-check, and **refusal with nothing deleted** when no
mechanism can answer. Measured extremes: a full cwd+fd scan over 228 processes 2.2 s, `du -s` over an 11 k-file root
19 ms, `find -type f | wc -l` 11 ms.

Age is a secondary guard, not the proof, for two measured reasons: `du`-style "newest file" does **not** track
activity in these roots (`cp -a` copies the source's mtimes: 914 of the killed root's 10,954 files were newer than a
30-minute reference, the rest carried the source tree's old timestamps), and a live owner's cwd is the thing that
actually matters. The default age is 30 minutes — the same rule the PM applied by hand at 09:52 ("no process
holding it, and nothing touched for 30 minutes") — overridable with `--age` / `TEAM_TMP_SWEEP_AGE`.

`review-*` needs one more rule, and it is measured: the PM's hand-sweep removed the directories, and
`git -C <main> worktree list --porcelain` still registers **68 worktrees under `/tmp`, 59 of them with no
directory**. Re-adding a checkout at such a path fails (`fatal: '/tmp/…' is a missing but already registered
worktree; use 'add -f' to override, or 'prune' or 'remove' to clear`, measured in a scratch repo; `git worktree
prune --dry-run` names it). So the sweep prints the exact `git -C <root> worktree remove --force <path>` line
instead of deleting a registered worktree — the skill runs no git write operations (`references/protocol.md`) — and
for a registration whose directory is already gone it prints the `git worktree prune` remedy. And because a
`review-*` root is a **checkout, not evidence** (the evidence is `docs/team/reviews/<ID>.md`), a `review-<ID>`
candidate is refused outright (exit 3, nothing deleted) unless its record exists and is committed in the main
worktree — the record path and state are printed either way.

## D6 — the gate never sweeps; it prints and asserts

Two tempting designs are rejected:

- **auto-sweep before a gate run** — the gate lock serializes *gates*, not fixtures; a `config-cli.sh` another
  agent started by hand (or a review checkout the PM is about to use) is not in the lock. Deleting by pattern in a
  shared filesystem while others run is the D37 family.
- **"delete anything that looks like a fixture root"** — the same reason, with the extra failure mode that a
  *foreign* process with the same name shape (`pc.*` today) gets deleted by mistake.

So the gate only does what it can prove: it prints its own root's path/size/file count at the start and with the
summary (also on failure), records every root its fixtures created in the run ledger, and **asserts that none of
them survives the run** unless the run declared it kept (`TEAM_TMP_KEEP=1`). Reclaiming an older residue stays an
explicit operator action (`--sweep`), whose inventory is printed before the first deletion and whose refusals name
the reason.

## D7 — a full temp filesystem is visible where the PM already looks: `team doctor`

The `watchdog` capability already owns the sibling host-resource row — `team doctor`'s inotify-headroom line:
read a global resource, print the numbers, warn below a threshold, name an *operator* remedy, never fail the doctor.
The temp-root row follows it exactly: one line with the resolved path, free/total bytes and free/total inodes
(`df -P -k` + `df -P -i`, measured 3.7 ms per pair — the doctor sits on the panel's health path, `panel/src/data.ts`
ttl 600 s / timeout 30 s, so it must stay two `df` calls and nothing else), a warning below
`TEAM_TMP_MIN_FREE_MB=1024` or `TEAM_TMP_MIN_FREE_INODES=100000`, the remedy, and no deletion, ever.

The defaults are calibrated from F2: one gate round's root measured 95 MB / 11,797 files (a second one 9 MB / 1,246),
a killed `config-cli` root 99 MB / 10,954 files — so the floors leave roughly ten rounds of bytes and nine rounds of
inodes before the warning, which is the room needed to act *before* a gate turns red rather than after. A
non-numeric override falls back to the default (the `TEAM_INOTIFY_MIN_FREE` precedent), and an unreadable path is
reported as unreadable, never as healthy.

Alternative placed and rejected: the same row in `verification` (where the gate's own doctor lines live — "the two
gates are discoverable"). Subject-wise it is a gate-environment fact, but as a *statement shape* it is a sibling of
the inotify row, and a future reader looking for "which spec owns doctor's host-resource rows" should find both in
one place; `verification` keeps the gate-side promises (roots, reclamation, sweep, residue assertion, lint).

## D8 — signals only to processes we started (D37, applied to the temp dimension)

The measured orphan specimens (two `sleep 3600` processes whose cwd is a *deleted* `teamsmith-smoke.*` directory,
plus the 23-hour M58 anchor and the 69-hour M39 groups) show that a fixture's residue is not only directories.
Cleanup therefore tracks pids at spawn time and signals only tracked pids; the occupancy scan treats a live process
inside a root as occupancy even when the recorded owner is dead; and no rule in this change matches a process by
name or command line. The self-test's `nokill` stage is the falsifiable half: a caller's unrelated `sleep` with an
identical argument must survive a cleanup that would have matched it.

## D9 — what the doctor's row and the sweep deliberately do not do

- no automatic deletion anywhere (D6), and no reading inside the temp root by the doctor (D7);
- no `rm -rf` of a registered worktree, and no git write from the skill (D5);
- no deletion of dot-prefixed diagnostics: `.teamsmith-smoke-diag.*` is the only pointer a killed run left, so
  `--status` lists it with its age and `--sweep` never touches it;
- no change to what a fixture *tests*: this change moves roots, adds reaping and visibility, and never relaxes an
  assertion.

## D10 — adjacent residue found while measuring (reported, not fixed here)

Three families of stale entries sit in `/tmp` right now, none of them occupied, none of them mine to delete:

- **fixture roots under a legacy name**: `panel-b3.*` ×14 (6.7 MB, 09-18…09-20) — `tests/panel-b3.sh:34` honors
  `${TMPDIR:-/tmp}` and has a trap with `TEAM_B3_KEEP`, so these are the same killed-run residue, and the owned
  family of this change (D2) does not reach them by name; the migration of tasks 2.1 does.
- **the product's own leftovers**: `teamsmith-inotify-probe.*.js` ×10 (09-21…09-22) and `teamsmith-review-queue.*`
  ×8 (09-20…09-22), both `rm -f`'d on the normal path (`common.sh:1090`, `cmd-review.sh:824`) and therefore left by
  killed runs. They are *files*, so the sweep's directory rule never makes them candidates; the new `--status`
  listing (requirement 2) makes them visible instead of invisible.
- **the gate's incident diagnostics**: `.teamsmith-smoke-diag.*` ×6 — evidence by design, listed and never deleted.

Widening the sweep to delete files is a deliberate non-goal here (a file has no occupancy to prove, and a
`teamsmith-review-queue.*` name is also what a *live* queue writes); if the PM wants them reclaimed, that is a
follow-up change with its own rule, not a clause smuggled into this one.

## D11 — boundaries of the change

The apply brief must grant: `skills/teamsmith/tests/**` (agent-owned) and, for the two PM-owned surfaces this change
needs — the one `team doctor` row in `scripts/lib/cmd-project.sh` and the doc rows in
`references/{troubleshooting,protocol,workflows,config}.md` + `SKILL.md` — an explicit grant (tasks.md, "Path
grants"). Out of scope: `.github/workflows/gates.yml` (its `.ci-artifacts:/tmp` mount keeps working; once the
fixtures honor `TMPDIR`, a `-e TMPDIR=/artifacts` variant becomes possible — the PM's call, not this change's), the
panel, the `flip-*` packs' semantics, a `team` fronting for the sweep, automatic reclamation of today's legacy-named
roots (D2), reclaiming files rather than directories (D10), and the smoke's private tmux server design (unchanged;
its socket already lives inside the run's root).
