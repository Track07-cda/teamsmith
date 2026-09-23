# Tasks: `test-tmp-hygiene`

Planning only — nothing in this file is executed by the propose task (P50). The plan is **two apply briefs** (B1
then B2, landed in order) plus **one independent verify brief** (a different agent, the `opsx-verify` phase). The
change touches two capabilities: `verification` (five ADDED requirements) and `watchdog` (one ADDED requirement).

Coverage map (requirement → items): **verification#A fixture's temp root resolves TMPDIR, carries an owned name,
and is reclaimed** → 1.1, 1.2, 2.1; **verification#Killed-run residue is identifiable and reclaimable through one
entry** → 1.3, 1.4, 1.6; **verification#The sweep proves occupancy and touches this project's own roots only** →
1.4, 1.5; **verification#The gate reports its own temp-root usage and asserts nothing it created outlives it** →
1.6; **verification#The fixtures' temp-root ownership rule is enforced by a static check** → 1.3, 2.1, 2.2;
**watchdog#`team doctor` reports the temp root's headroom** → 1.7. Every item names the capability it moves; no
item is an orphan.

Order matters twice: **1.1 before everything else** (every other item uses the helper), and **2.2 after 2.1** (the
lint can only be wired into the gate once no fixture fails it — a hardcoded root renamed in 1.2 and 2.1 is the
whole point). B1 leaves the tree green with the lint *available but not yet gating*; B2 turns it into a gate
assertion and finishes the migration.

How each requirement is re-checked (run what → read which part → expected value):

| Req | Run | Read | Expected |
|---|---|---|---|
| temp root / reclamation | `TMPDIR=D bash skills/teamsmith/tests/config-cli.sh`; then `TMPDIR=D TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null` | the fixtures' output and `TMPDIR=D bash skills/teamsmith/tests/tmp-hygiene.sh --status` | green; the root existed under `D`; no `D` root survives; the start/end lines name the run's root with size and file count |
| killed-run residue | kill a fixture with `KILL` mid-run, then `TMPDIR=D bash skills/teamsmith/tests/tmp-hygiene.sh --status` and `--sweep --age 0` | the inventory line (path, size, files, owner) and the reclaimed total | the root is listed as not occupied, then removed; exit 0 |
| occupancy and ownership | `bash skills/teamsmith/tests/tmp-hygiene.sh --self-test` and `--sweep --age 0` while a fixture holds a root | the `skip:`/`refuse:` lines and the exit status | occupied → skipped (exit 0); unknown mechanism or a foreign candidate → exit 3 with nothing deleted; the gate lock untouched |
| review checkout rules | the scratch-repo fixture of the self-test (registered worktree, then committed / uncommitted record) | the printed `git -C … worktree remove --force …` line and the refusal message | never removed by the sweep; refusal names `docs/team/reviews/<ID>.md` and its state |
| gate residue assertion | `TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null`, then the same with the leak knob | the residue assertion's line (`ok` / `✗`) and the summary | knob off → the assertion's `ok` line; knob on → `✗` naming the surviving path and its size |
| lint | `bash skills/teamsmith/tests/tmp-hygiene.sh --lint`, then the same with a rewritten `/tmp/…` template in a fixture copy | the exit code, the `<file>:<line>` finding, the counted templates | clean tree → 0; rewritten template → 1 naming file and line |
| doctor row | `bash skills/teamsmith/scripts/team doctor` and the same with `TEAM_TMP_MIN_FREE_MB=999999999` / a missing `TMPDIR` | the one temp-root line and the doctor's exit code | healthy → `ok` with free/total bytes and inodes; low → warning naming the figures, the threshold and the remedy, exit 0; unreadable → says so, never `ok` |
| change | `PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict`, then the two gate commands | their exit codes | 0 |

Path grants the apply brief must state (OWNERSHIP): `skills/teamsmith/tests/**` is agent-owned (the helper
`tests/lib/tmp-root.sh`, `tests/tmp-hygiene.sh`, every fixture, `tests/smoke.sh`); `skills/teamsmith/scripts/lib/cmd-project.sh`
(one doctor row) and `skills/teamsmith/references/{troubleshooting,protocol,workflows}.md`, `skills/teamsmith/SKILL.md`
and `skills/teamsmith/references/config.md` are **PM-owned** and need an explicit grant in the B1/B2 briefs for
exactly those rows; `openspec/changes/test-tmp-hygiene/**` belongs to the phase's owner; `docs/team/**` stays
PM-owned. Nothing else is touched: no `scripts/lib/*` other than the doctor row, no `panel/**`, no
`.github/workflows/**` (the CI mount stays as it is; see design §D10).

Fixture notes: every migrated fixture keeps clearing inherited team identity first, and its private tmux
`TMUX_TMPDIR` stays inside its own root (`$TMP/tmux`) so the root's removal still takes the socket with it — except
the socket directory of a *live private server*, whose server is killed before the root is removed (the existing
`cleanup` order). Fixtures whose root name changes (`config-cli.*` → `teamsmith-config-cli.*`, `panel-*` →
`teamsmith-panel-*`, `flip-p22`/`m62flip`/`pc`/`p26premise`/`p12-keyprobe`/`task-header-model`/`load-experiment.*` →
`teamsmith-<kind>.*`) keep their `# KEEP`/`--keep` knob and print the new path; no assertion of theirs may key off
the literal old name (the lint would not catch that, the grep in 2.1 does).

Documented residual (design §D6, not fixed here): the sweep is an explicit operator action, so the gate does not
delete anything itself except roots it created in this run (1.6); a residue left by a *concurrently running*
fixture is reported by `--status` and reclaimed only by a later sweep. Items below must **not** widen the sweep
into an automatic cleanup of the shared temp filesystem.

## 1. B1 — one owned family, one helper, one entry point (`verification` ADDED ×4, `watchdog` ADDED ×1)

- [x] 1.1 `tests/lib/tmp-root.sh` — the only root creator: `tmp_root_create <kind>` under `${TMPDIR:-/tmp}` with a
  base name in the owned family, the owner marker inside the root (`pid`, process start time, `kind`, run id), the
  run-ledger append, the `EXIT`/`INT`/`TERM` reclaim honoring `TEAM_TMP_KEEP=1` (path printed), and
  `tmp_root_track_pid <pid>` for processes that outlive a step (signals only recorded pids). Verify:
  `bash skills/teamsmith/tests/lib/tmp-root.sh --self-test` exits 0 and its `--break=` stages are red — `nokill`
  (an untracked caller `sleep` must survive a cleanup that tries to match it by command line), `nokeeep` (a kept
  root must be printed, not silently kept), `notmpdir` (a hardcoded `/tmp` root must be reported).
- [x] 1.2 migrate every fixture the gate runs transitively to the helper and the owned family — `tests/smoke.sh:215`
  (`/tmp/teamsmith-smoke.XXXXXX` → `${TMPDIR:-/tmp}/teamsmith-smoke.XXXXXX`), `tests/config-cli.sh`,
  `tests/install-shape.sh`, `tests/panel-{b2,b3,choices,p21,snapshots,flip-m54,cpu-premise,keyprobe}.sh`,
  `tests/task-header-model.sh` — including the dead `TEAM_CONFIG_KEEP` read (the identity strip unsets `TEAM_*`
  before the knob is read: design §D3). Verify: `TMPDIR=D TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh
  </dev/null` green, `TMPDIR=D bash skills/teamsmith/tests/config-cli.sh` green, and `TMPDIR=D bash
  skills/teamsmith/tests/tmp-hygiene.sh --status` shows no surviving root under `D` afterwards.
- [x] 1.3 `tests/tmp-hygiene.sh --status` and `--lint` — the read-only inventory (path, size, file count, age,
  recorded owner, occupancy, the family's non-directory entries listed as not-a-root, plus the resolved temp root's
  free/total bytes and inodes), and the static check over every `mktemp -d` root template in `tests/**`. Verify:
  `bash skills/teamsmith/tests/tmp-hygiene.sh --status` on a tree holding one stale and one live root prints both
  with their state and exits 0; `--lint` on the tree as of 1.2 exits 1 **naming the fixtures of 2.1 that are not yet
  migrated** (a diagnostic, not yet a gate: it is wired in 2.2), and on a copy with one template rewritten to
  `/tmp/x.XXXXXX` names that file and line.
- [x] 1.4 `tests/tmp-hygiene.sh --sweep` — the candidate rule (directories named `teamsmith-*`/`review-*` only,
  dot-prefixed names never), the age threshold (`--age`, default 30, `TEAM_TMP_SWEEP_AGE`), the occupancy proof
  (a scan of live processes' current directory, open files and executables; `/proc` first, `lsof` as a cross-check),
  the printed inventory before the first deletion, `--dry-run`, and exit `0`/`3` as specified. Verify:
  `bash skills/teamsmith/tests/tmp-hygiene.sh --self-test` green with its red sides — `occupied` (a live holder is
  skipped, exit 0), `orphan` (a live process inside a root whose recorded owner is dead is skipped as occupied),
  `unknown` (no scan mechanism → exit 3, nothing deleted), `foreign` (a `pc.*`/`m62flip.*` style path and a
  dot-prefixed diag file are not candidates), `lock` (the lock file and `.holder` survive and are reported).
- [x] 1.5 `tests/tmp-hygiene.sh --sweep` — the review-checkout rules: a registered worktree is never `rm -rf`'d
  (the `git -C <root> worktree remove --force <path>` line is printed instead; `git -C <root> worktree prune` for a
  registration whose directory is gone), and a `review-<ID>` root is refused (exit 3, nothing deleted) unless
  `docs/team/reviews/<ID>.md` is present and committed in the main worktree, with the record path and its state
  printed either way. Verify: the self-test's scratch-repo stages (measured shape in design §D5:
  `fatal: … missing but already registered worktree`), each with its red side (`--break=rmworktree` must make the
  checker red).
- [x] 1.6 `tests/smoke.sh` — the run ledger wiring, the start and end usage lines (path, size, file count; the end
  line printed with the summary even on failure), and the residue assertion that every root this run created is
  gone unless declared kept (`TEAM_TMP_KEEP=1` prints it and is never reported as reclaimed). Verify:
  `TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null` green with both lines present, and the same
  run with the fixture-mode leak knob (`TEAM_SMOKE_FIXTURE=1 TEAM_TMP_HYGIENE_FLIP=leak`) red, naming the
  surviving root and its size.
- [x] 1.7 `scripts/lib/cmd-project.sh` — the `team doctor` temp-root row of `watchdog#…headroom`: resolved path,
  free/total bytes and inodes (`df -P` form), `TEAM_TMP_MIN_FREE_MB` (default 1024) and
  `TEAM_TMP_MIN_FREE_INODES` (default 100000, non-numeric falls back), warning-only, naming the figures, the
  crossed threshold and the remedy; unreadable figures are stated, never `ok`. Verify: `bash
  skills/teamsmith/scripts/team doctor` in a fixture project prints one such line and its exit status is unchanged;
  `TEAM_TMP_MIN_FREE_MB=999999999 bash skills/teamsmith/scripts/team doctor` warns and still exits 0;
  `TMPDIR=/nonexistent bash skills/teamsmith/scripts/team doctor` warns and prints no invented number.

## 2. B2 — the rest of the fixtures, the lint in the gate, the docs (`verification` ADDED ×1)

- [x] 2.1 migrate the hand-run fixtures to the helper and the owned family — the `flip-*` packs
  (`flip-glue`, `flip-m6.2`–`flip-m7.2`, `flip-m12*`, `flip-m16`, `flip-m17`, `flip-m33`, `flip-m34`, `flip-m37`,
  `flip-m4.3`, `flip-m43`–`flip-m48`, `flip-p18.1`, `flip-p20`, `flip-p22`, `flip-p23`, `flip-p25`),
  `guard-matrix.sh`, `pm-box-real.sh`, `team-bg-flip.sh`, `team-inbox-watch-flip.sh`, `perf.sh`,
  `load-experiment.sh` — names normalized to `teamsmith-<kind>.*`, their own root-name literals in comments,
  guards and reports-facing output updated, and the same `grep -rn 'mktemp -d /tmp/' skills/teamsmith/tests/*.sh`
  returning nothing. Verify: `bash skills/teamsmith/tests/tmp-hygiene.sh --lint` exits 0 and prints the number of
  templates it checked; the packs that need a private tmux server still pass their own `--self-test`/driest stage
  (`bash skills/teamsmith/tests/flip-m16.sh --self-test`, the `guard-matrix.sh` dry run).
- [x] 2.2 wire `--lint` into the correctness gate (one `smoke.sh` section, FAST included) plus its red side: a
  fixture-mode copy of a fixture with a rewritten literal `/tmp/…` template must make the section red naming file
  and line. Verify: `TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null` green; the same run with
  the `TEAM_TMP_HYGIENE_FLIP=lint` knob red; the `✗` grep of `skills/teamsmith/tests/smoke.sh` unchanged.
- [x] 2.3 docs (PM-granted rows only): `references/troubleshooting.md` gains the temp-root failure entry (the
  measured ENOSPC incident, the sweep entry, the `TMPDIR` rule), `references/protocol.md`'s gate section names the
  fixtures' temp-root discipline and the sweep as an operator action, `references/workflows.md` and `SKILL.md`'s
  review-checkout line keep `/tmp/review-<ID>` and name the sweep as the way to reclaim it, and
  `references/config.md` gains `TEAM_TMP_MIN_FREE_MB`, `TEAM_TMP_MIN_FREE_INODES`, `TEAM_TMP_SWEEP_AGE`,
  `TEAM_TMP_KEEP`. Verify: `grep -n 'tmp-hygiene' skills/teamsmith/{SKILL.md,references/troubleshooting.md,references/protocol.md}`
  finds each file; the `TEAM_TMP_*` keys are named by `team config schema` and by `references/config.md` (the
  existing doc↔engine scanners of smoke §6f/§6i stay green with no test edit).

## 3. B3 — the change's own evidence (gate + independent verification)

- [x] 3.1 run the change's acceptance commands on the final tip and write the report
  `docs/team/reports/P50-<agent>.md` with the real tails: `PATH="$HOME/.bun/bin:$PATH" openspec validate --all
  --strict`; `TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null`; `bash
  skills/teamsmith/tests/smoke.sh </dev/null`; `bash skills/teamsmith/tests/tmp-hygiene.sh --lint`; and each red
  side above with its command and tail.
- [x] 3.2 independent verification (a **different** agent, `opsx-verify`): every scenario of both deltas exercised
  on a clean checkout against the landed branch, with red/green evidence for the occupancy, worktree, record,
  residue and lint guards, and the doctor row's threshold shapes. Verify: the verification record
  `docs/team/reviews/P50.md` names each scenario and its evidence.

> **PM 勾选说明（2026-09-23）**：propose=P50（dev3）· apply=P53（dev3）· verify=P60（verify 席位）。
> P60 当时判 **FAIL**，唯一红是 `container-tmux.sh` 的 fpcheck 临时根——那是 **P64** 修的既有违规
> （P53 的新 lint 逮到 P47 时代的文件）；P64 合并后我在 `reviews/P60.md` 的「收口」一节里
> 重跑了它的两条 acceptance（`--lint` **rc=0 全合规**、`openspec` 26/0、FAST 只余当时那条
> 与本 change 无关的审计日志噪声红，后者已成 P73/P87/P92 并且**通过**）。因此本 change 的
> 三条承诺（拥有者助手 / 回收集 / 可见余量）都已闭环，可以归档。
