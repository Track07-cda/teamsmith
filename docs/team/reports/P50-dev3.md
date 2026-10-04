# P50 · test-tmp-hygiene — the fixtures' temp roots: reclaimable, attributable, visible (propose)

agent: dev3   status: DONE (propose phase; apply/verify not started — planning only)
time: 2026-09-22T11:20:00Z
branch: `task/P50-tmp-propose`   PR/MR: `-` (local mode: no push, branch left for the PM)

## Deliverables

| Path | What |
|---|---|
| `openspec/changes/test-tmp-hygiene/proposal.md` | Why / What Changes / flips / acceptance / boundaries (< 500 words: 497) |
| `openspec/changes/test-tmp-hygiene/design.md` | The measured evidence, decisions D1–D11 with the alternatives that were rejected, the adjacent residue found (D10) and the boundaries |
| `openspec/changes/test-tmp-hygiene/tasks.md` | Coverage map (requirement → items), the re-check table, path grants, 2 apply batches + the verify batch, 14 verifiable items |
| `openspec/changes/test-tmp-hygiene/specs/verification/spec.md` | 5 ADDED requirements, 17 scenarios |
| `openspec/changes/test-tmp-hygiene/specs/watchdog/spec.md` | 1 ADDED requirement (the doctor row), 3 scenarios |

No `MODIFIED`/`REMOVED` delta: nothing in the base specs is superseded, and no base scenario is touched. Nothing
outside `openspec/changes/test-tmp-hygiene/**` was changed by this task (verified: `git diff --stat 764ccfc..HEAD`
= those five files, 588 insertions).

## Verification evidence (actually run)

Baseline of the tree this proposal sits on (the gate reads `skills/**`; this task changed no file under it — the
branch's only change is `openspec/changes/test-tmp-hygiene/**` and this report):

```
$ git status --porcelain                     # → empty
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
Totals: 21 passed, 0 failed (21 items)       # includes ✓ change/test-tmp-hygiene

$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
== 结果 ==  ✓ 2329  ✗ 0
FAST 模式：跳过 29 个真进程段落（…）
smoke 全绿                                    # rc=0, 533 s wall
```

**Not run: the full gate** (`bash skills/teamsmith/tests/smoke.sh </dev/null`, no `TEAM_SMOKE_FAST`) — this is a
propose task with no code change, the full suite is the machine's single shared resource
(`docs/team/threads/dev3.md`, 2026-09-20), and the PM runs it on the apply/verify tip.

The current state the proposal argues from (every number is a measured command output; the PM's own incident
numbers are marked **PM**):

```
$ df -Ph /tmp ; df -Pi /tmp
tmpfs            15G  5.4G  9.3G  37% /tmp
tmpfs          3811434 636370 3175064   17% /tmp      # **PM at 09:50**: 100 % used,
                                                      # 0 B free, inodes 4,645/3,811,434 free
$ grep -lE 'mktemp -d' skills/teamsmith/tests/*.sh | wc -l            # 43 root-creating fixtures
$ … | while read f; do grep -qE '^[[:space:]]*trap .*(EXIT|INT|TERM)' "$f"; done | wc -l   # 43/43 carry a trap
$ grep -lE 'mktemp -d /tmp/' skills/teamsmith/tests/*.sh | wc -l      # 24 hardcode /tmp
$ grep -lE 'mktemp -d "\$\{TMPDIR' skills/teamsmith/tests/*.sh | wc -l # 19 already use ${TMPDIR:-/tmp}
$ sed -n '215p' skills/teamsmith/tests/smoke.sh
TMP="$(mktemp -d /tmp/teamsmith-smoke.XXXXXX)"
$ TMPDIR=/tmp/p50probe/fake bash -c 'mktemp -d /tmp/teamsmith-smoke.XXXXXX'
created: /tmp/teamsmith-smoke.GrDZfz          # TMPDIR was /tmp/p50probe/fake — the template wins
$ grep -n 'keep="' skills/teamsmith/tests/config-cli.sh
33:  keep="${TEAM_CONFIG_KEEP:-0}"              # read *after* the TEAM_* strip at 19–21 → the knob is dead
$ TEAM_CONFIG_KEEP=1 TMPDIR=/tmp/p50probe/cfg bash skills/teamsmith/tests/config-cli.sh
== 结果 ==  ✓ 125  ✗ 0  SKIP 0                 # real 0m25.172s; NO root kept under $TMPDIR — the knob did nothing
$ grep -n 'kill-after' skills/teamsmith/scripts/lib/cmd-review.sh
567:      runner=(timeout --verbose --signal=TERM --kill-after=60 "$gate_timeout")   # the KILL path
$ grep -n 'ci-artifacts\|-v "\$PWD' .github/workflows/gates.yml
66-73: the GATES step mounts the host's .ci-artifacts onto the container's /tmp, with the comment
       "夹具现场目录是 /tmp/teamsmith-smoke.XXXXXX（写死 /tmp，不看 TMPDIR——已记在 P50 的清理项里）"
$ grep -rlE '\bdf +-[a-zA-Z]' skills/teamsmith/scripts/ | wc -l        # 0 — nothing reads disk space today
```

Why the residue outlives the traps, measured on bash 5.3.9 with the same shape the fixtures use:

```
$ <script with trap cleanup EXIT + sleep 30> &
$ kill -TERM $!   → shell_exit=143  log: CLEANUP            # an untrapped TERM still runs the EXIT trap
$ kill -KILL $!   → shell_exit=137  log: (empty)            # KILL cannot be caught
```

The residue a real fixture leaves (this is the incident's mechanism, reproduced end to end):

```
$ TMPDIR=/tmp/p50probe/kill3 bash skills/teamsmith/tests/config-cli.sh &   # a full run logs 10,248 bytes
    … at t+20 s (log 9,697 bytes) kill -KILL <fixture pid>
$ ls -d /tmp/p50probe/kill3/config-cli.*
/tmp/p50probe/kill3/config-cli.Zgc6yb
$ du -s --block-size=1M … → 99        ; find … -type f | wc -l → 10954
$ (27 s later) ls -d /tmp/p50probe/kill3/config-cli.* → still there      # nothing reclaims it
```

Two roots existed at the same moment during that run (the `flip`/`groups-flip` sections run the fixture again
against a copied tree), so one killed run can leave more than one root and the nested run keeps going after its
parent dies. The inode arithmetic of the incident follows: 3,811,434 / 10,954 ≈ **349** roots of that shape exhaust
the tmpfs inode table, and the PM's 607 leftovers at ≈6,300 files each ≈ 3.8 M — the whole table.

The sweep's cost basis and the reason "newest file" cannot be the occupancy proof:

```
$ time (50 × (df -P -k /tmp + df -P -i /tmp))              → real 0m0.185s   (3.7 ms per pair)
$ time du -s --block-size=1M <11 k-file root>              → real 0m0.019s
$ time find <root> -type f | wc -l                         → real 0m0.011s
$ time <full /proc cwd+fd scan, 228 processes>             → real 0m2.218s
$ find <the killed root> -newer <reference 30 min old> | wc -l
914        # of 10,954 files — cp -a preserved the source tree's mtimes, so mtime is not an activity signal
```

Residue and orphan processes present on this machine while writing (I deleted nothing of it — not mine):

```
$ ls -d /tmp/teamsmith-flip-p18.1.* /tmp/teamsmith-flip-p20.*
4 roots, 2026-09-18 17:38–17:48 and 2026-09-19 16:43–17:26, 896 KB–1.2 MB, no process holding them
$ ls -d /tmp/panel-b3.* | wc -l ; du -sh --total /tmp/panel-b3.* | tail -1
14 ; 6.7M      # 09-18…09-20, same killed-run shape: panel-b3.sh:34 honors ${TMPDIR:-/tmp} and has a trap
$ ls /tmp/teamsmith-inotify-probe.*.js | wc -l ; ls /tmp/teamsmith-review-queue.* | wc -l
10 ; 8         # the product's own 09-20…09-22 leftovers (rm -f'd on the normal path: common.sh:1090,
               # cmd-review.sh:824) — files, so the sweep's directory rule leaves them to the PM
$ ps: two `sleep 3600` with cwd `/tmp/teamsmith-smoke.KioN0K/p8-env-repo (deleted)` / `…RzEjGe… (deleted)`
$ live gate roots at that moment: /tmp/teamsmith-smoke.VOcqYG 95 MB / 11,797 files, XEdf3w 9 MB / 1,246 files
$ ls /tmp/.teamsmith-smoke-diag.* → 6 leftover tripwire files, oldest 09-19
$ git -C <main worktree> worktree list --porcelain | grep -c '^worktree /tmp/'
68         # 59 of those directories no longer exist (the review-* hand-sweep left the registrations)
```

The registration trap, reproduced in a scratch repository (never in the project's own repository):

```
$ git worktree add --detach /tmp/p50probe/scratch/wt HEAD ; rm -rf /tmp/p50probe/scratch/wt
$ git worktree add --detach /tmp/p50probe/scratch/wt HEAD
fatal: '/tmp/p50probe/scratch/wt' is a missing but already registered worktree;
use 'add -f' to override, or 'prune' or 'remove' to clear
$ git worktree prune --dry-run
Removing worktrees/wt: gitdir file points to non-existent location
```

My own probe directory `/tmp/p50probe` (the fixtures I killed and the roots they left) was removed at the end; the
only processes I signalled were ones my probes had started, identified by my private path — no pattern matching,
and nothing of another agent's was touched.

## Flip evidence (the red sides measured here; the apply turns them green)

This task is `phase: propose` — there is no implementation to break yet, so the flip is stated as *measured red →
the delta that must make it green*, and the apply's report owes the green side. Every red below is a real command
output above, not a description:

| Red today (measured) | The delta that must turn it green (apply/verify owe the green run) |
|---|---|
| `kill -KILL` leaves a root of 99 MB / 10,954 files and nothing can name or reclaim it | `verification#Killed-run residue is identifiable and reclaimable through one entry` → `--status` lists it, `--sweep --age 0` reclaims it |
| `TMPDIR=D` cannot move the gate's scene (`smoke.sh:215`) and `TEAM_CONFIG_KEEP=1` keeps nothing | `verification#A fixture's temp root resolves TMPDIR…` → the root lands under `D`, and the keep path prints what it keeps |
| a hand `rm -rf` of a registered review checkout leaves a registration that makes the next `worktree add` fatal | `verification#The sweep proves occupancy and touches this project's own roots only` → the git line is printed instead |
| a surviving nested root leaves the gate green (nothing asserts over it), and a literal `/tmp/…` template is invisible | `verification#The gate … asserts nothing it created outlives it` + `#…enforced by a static check` → the leak knob and the rewritten template both fail |

The guards' own red sides are part of the spec's observable surface (`tmp-hygiene.sh --self-test`: occupied,
orphan, unknown-mechanism, foreign-path, lock-file, registered-worktree, uncommitted-record, lint flip), so the
verify phase can exercise them without touching the real `/tmp`.

## Decisions and deviations

1. **All deltas are ADDED, none MODIFIED** — the brief allowed this ("每条可证伪、MODIFIED 不删 base scenario"); the
   base specs contain no statement this change supersedes (checked: `grep -rn 'tmp\|temp' openspec/specs/*/spec.md`
   finds no temp-root promise, and `grep -rlE '\bdf +-[a-zA-Z]' scripts/` is empty — nothing reads disk space
   today).
2. **The doctor row is in `watchdog`** (the brief's `deltas:` line), following the shape of its sibling
   `watchdog#team doctor reports the inotify headroom of the wake channel`: a global host resource, printed
   numbers, a threshold, an operator remedy, never a failed doctor. `verification` was the alternative (its doctor
   requirement is about the gate's presence/discoverability) and is recorded in design §D7.
3. **Two items beyond the brief's literal list**: (a) the static lint requirement — without it the "no `/tmp`, one
   owned family" rule rots the first time a fixture is added by hand (the same reasoning as the existing perf-marker
   guard and `tests/tmux-lint.pl`); (b) the worktree-registration and record-committed rules for `review-*` — item 5
   of the brief asked for "复验记录已提交" as a precondition; the registration part is *new evidence* found while
   measuring (59 stale registrations), not in the brief.
4. **One owned family instead of a hand-kept prefix list** (`teamsmith-<kind>.*`; `review-<ID>` stays). The brief's
   list was "`config-cli.*`/`teamsmith-smoke.*`/`review-*` 等"; `pc.*`/`flip-p22.*`/`m62flip.*` are generic enough
   that a foreign tool could own them, and a nine-prefix list is only as trustworthy as its last editor. Cost: a
   rename of ~11 fixture roots (tasks 1.2/2.1). **Today's legacy-named leftovers are therefore deliberately out of
   the sweep's reach** — the PM should confirm or widen that (design D2).
5. **The gate does not auto-sweep** (design D6): the gate lock serializes gates, not hand-run fixtures; deleting by
   pattern in a shared filesystem while another agent runs is the D37 family. Reclaiming older residue stays an
   explicit operator action.
6. **No new knob for the root path** — `${TMPDIR:-/tmp}` (design D1) — and **no `team` fronting** for the sweep
   (`tests/tmp-hygiene.sh`, the `team perf`-fronts-`tests/perf.sh` precedent can come later).
7. **`.github/workflows/gates.yml` untouched** (its `.ci-artifacts:/tmp` mount keeps working); once the fixtures
   honor `TMPDIR`, a `-e TMPDIR=/artifacts` variant becomes possible — the PM's call.
8. **The brief was not modified** (it is the PM's read-only file).

## Suggested next steps

- PM: proposal review of `test-tmp-hygiene` (`openspec validate --all --strict` is green on this tip; the
  checklist's item 7 has nothing to flag — no MODIFIED delta, no parallel statement).
- The B1/B2 apply briefs must grant the two PM-owned surfaces: one `team doctor` row in
  `skills/teamsmith/scripts/lib/cmd-project.sh` and the doc rows in `references/{troubleshooting,protocol,workflows,config}.md`
  + `SKILL.md` (listed under "Path grants" in `tasks.md`).
- Nothing is `BLOCKED:` for this task. Two housekeeping facts for the PM, both outside my authority: the residue
  named above (`teamsmith-flip-*` ×4, `panel-b3.*` ×14, and the product's `teamsmith-inotify-probe.*` ×10 /
  `teamsmith-review-queue.*` ×8 files), and the **59 stale `/tmp` worktree registrations** — the latter is fixed by
  `git -C <main> worktree prune`, which is a git write and therefore the PM's call. The sweep this change adds will
  reach the `teamsmith-*` family and the migrated `panel-*` roots (design D2/D10); widening it to *files* (the
  product's two families) is deliberately a separate decision for the PM.
- If the PM wants CI to keep uploading the failure scene without the mount, that is a separate (infra) brief after
  the apply.
