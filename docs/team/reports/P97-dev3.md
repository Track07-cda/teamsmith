# P97 · 门禁分段预算（propose）：提案包

agent: dev3   status: DONE   time: 2026-09-23T02:05:00Z
branch: `task/P97-propose`   PR/MR: -（local 模式，分支留本地）

## Deliverables

| Path | What |
|---|---|
| `openspec/changes/gate-runtime-budget/proposal.md` | Why / What Changes / Flip / Boundaries / Acceptance / Evidence |
| `openspec/changes/gate-runtime-budget/specs/verification/spec.md` | Delta: 3 **ADDED** requirements (accounting, path→section selection, selected run says what it did not run) |
| `openspec/changes/gate-runtime-budget/design.md` | 10 decisions with alternatives, the measured basis, the contract for the implementer, coverage, risks, migration |
| `openspec/changes/gate-runtime-budget/tasks.md` | Two apply briefs + one verify brief, requirement→item map, per-requirement re-check table, path grants, fixture notes |
| `docs/team/reports/P97/probe-section-paths.sh` + `.tsv` | Probe: mechanical path-token extraction over the gate's 104 sections (406 rows) |
| `docs/team/reports/P97/measure-fast.sh`, `fast-run-r1.log`, `fast-run-r2.log`, `per-section-times.pl`, `fast-section-times-r{1,2}.tsv` | Two timestamped FAST runs and their per-section tables (the accounting prototype) |

**Brief's five points → artifacts**: ① per-section timing table → R1 + §1.2's measured table; ② path→section
selection → R2 + §1.1's probe + the seed rows; ③ no coverage cut → R3 + the Non-Goal + the totals invariance
(1.4); ④ falsifiability ①–④ → the scenarios in R1/R2/R3, with ④'s consistency numbers in §1.2; ⑤ no assertion
relaxed → Non-Goals + item 1.4.

## Verification evidence (all commands actually run)

### Acceptance: the gate pair + the proposal's own artifacts

```
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
✓ spec/verification
✓ change/wake-delivery-idempotence
✓ spec/watchdog
Totals: 31 passed, 0 failed (31 items)

$ openspec status --change gate-runtime-budget
Progress: 4/4 artifacts complete
[x] proposal   [x] specs   [x] design   [x] tasks

$ bash skills/teamsmith/tests/gate-guard.sh
ok: smoke.sh 里没有性能判定标记、时长/份额比较，也没有测量夹具的点名
ok: panel-knobs.sh 存在且走 panel-cpu.sh 的 premise-only 模式
ok: panel-knobs.sh 不驱赶测量夹具
ok: perf.sh 带着帧预算 / CPU 份额 / 前提系数的命名单源标记
gate-guard: 三向都过     # rc=0

$ git status --porcelain      # before committing this branch's work
?? docs/team/reports/P97/
?? openspec/changes/gate-runtime-budget/
$ git status --porcelain      # at delivery: the same files, committed
(no output)
```

### FAST twice (the accounting prototype, and the tree's state)

No **full** run: this diff touches no product path (`openspec/changes/**` + `docs/team/reports/**` only), which
protocol §9b-2 explicitly exempts from a suite run; the two FAST runs below stand as this tree's state evidence.

```
$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null   # timestamped, r1/r2
r1: rc=1  wall=641s  loadavg 12.34→13.39  ✓2759 ✗5 SKIP33
r2: rc=1  wall=627s  loadavg 14.08→ 8.31  ✓2759 ✗5 SKIP33
```

**Both runs are red for a reason outside this task's diff** (and outside `skills/**` entirely): 5 ✗ in sections
`14b` and `18`, all one root cause — `skills/teamsmith/references/troubleshooting.md` (a tracked file,
**unmodified** in this worktree; `HEAD == main == 61af37d1`, `git status` clean apart from this task's two new
untracked directories):

```
✗ 文档在教「没有 --dir 的 review」：…/skills/teamsmith/references/troubleshooting.md:1070:$ bash skills/teamsmith/scripts/team review P82 --post-merge
✗ 英文正文不变量被破坏（references/** 或 SCOPE.md 的正文里有 CJK）：
   skills/teamsmith/references/troubleshooting.md:1064: ## 20 ·  报「两边都动过」时先看内容   (+ 1066/1067/1076)
✗ 翻转自测（净）：只有行内代码里有中文 被误报：…:1064
✗ 翻转自测（净）：只有围栏代码块里有中文 被误报：…:1064
✗ 干净副本被误报
```

Cause: `f534ec4b` (2026-09-23T01:01:54Z, +17 lines to that file) is 16 minutes older than this dispatch. The
five reds are stable across both runs (identical totals), and the failing sections read only tracked
`references/**`/`SCOPE.md` files, so this task's untracked additions cannot be their cause.

### The trial archive (delta integration with the open changes)

```
$ mkdir -p /tmp/p97-trial-$$ && cp -r openspec /tmp/p97-trial-$$/openspec
$ (cd /tmp/p97-trial-$$ && openspec archive -y gate-runtime-budget)
  verification: update
  + 3 added, ~ 0, - 0, → 0
$ (cd /tmp/p97-trial-$$ && openspec validate --all --strict)
Totals: 30 passed, 0 failed (30 items)      # before the archive: 31 passed / 0 failed
```

This change only ADDs, so it archives in any order and invalidates no sibling's delta. The remaining
coordination with `gate-section-accounting`/P70 is code-level (design D8), not delta-level.

### The probe (the path→section derivation)

```
$ bash docs/team/reports/P97/probe-section-paths.sh --families
distinct-sections-hit  67      sections-total 104      (406 path tokens)
family skills 341 · README.md 22 · openspec 14 · SCOPE.md 10 · AGENTS.md 9 · extension 4 · panel 2
$ … --path docs               # the exemption's basis: no output at all
$ … --path openspec
6j · worker adapter…  12e · change 视图…  12g · 派单锚点…  12h · delta 单写者…  20 · done 证据…  25 · 唤醒计数…
26 · 面板…  28 · 控制台表面…  33 · 项目契约的读写面…  35 · 门禁只判正确性…      (10 sections)
$ … --path skills/teamsmith/scripts/lib/outbox.sh
12b-h0b…  12b-h0d…  42…  46…           (4 sections name the file directly)
$ … --fixture outbox                   (sections whose text exercises it)
12b (76 hits) · 12b-h0 · 12b-h0b · 12b-h0c (45) · 12b-h0d · 12b-pi · 12b-pi2 (26) · 26 · 27 · 42 · 44 · 46 · 47
```

**Seed rows for `skills/teamsmith/scripts/lib/outbox.sh`** (brief point ② — "which sections and why"): `12b`
(drives `$TEAM outbox enqueue/flush/list`, 5633–5900; `guard-matrix.sh` at 5636), `12b-h0` (`pm-box-real.sh`
5883, sources `lib/outbox.sh` 5889), `12b-h0b` (sources it at 5926 — banner rows), `12b-h0c` (overlay judge,
`pm-box-real.sh` 6188–6233), `12b-h0d` (bottom-border order 6024, 6158–6161), `12b-pi` (`flip-m46.sh` 6842),
`12b-pi2` (skip traces 7025–7036), `12b-pi3` (degraded lane 7133–7158), `26` (panel queue 9117–9141), `27`
(data layer 9585–9675), `42` (13063), `44` (13466), `46` (13639), `47` (notify sender 13841–13902). The
selector's answer must contain these keys and their `needs` closure; the *direct* extractor finds only 4 of
them, which is exactly why the design treats the extractor as a check (lower bound) and the row as the claim.

### Falsifiability of the four demanded cases (the design's evidence, not yet the code's)

| Brief case | Where the falsifiable shape is | This block's measured basis |
|---|---|---|
| ① docs-only → empty selection + "no run needed" | R2 scenario 1, R3 scenario 2 | the exempt class `docs/**` is measurable: 0 real-tree `docs/` tokens in 104 sections, and 14b's scanner documents excluding `docs/**` |
| ② `scripts/lib/outbox.sh` → the delivery sections, with numbers and basis | R2 scenario 2 | the seed rows above (probe lines), 14 of them (vs 4 by the extractor alone) |
| ③ an unclaimed path → the full suite | R2 scenario 4 | the fallback rule; `openspec/**` is *not* exempt (10 sections name real `openspec/` paths) |
| ④ timing table ↔ real elapsed, same section twice within noise | R1 scenarios 1–3 | r1/r2: 103 sections measured twice — median \|Δ\| **2.9 %**, mean 4.0 %, max **14.4 %** (60 sections ≥ 1 s); the largest absolute moves `12b-pi3` 22.0→19.3 s and `38` 60.4→58.8 s; wall 641→627 s (−2.2 %); totals identical (`✓2759 ✗5 SKIP33`); loadavg 8–14 with several gates queued |

### Red/green of the *measurement* itself (the prototype's own flip)

The first post-parse treated an indented fixture result line (`      == 结果 ==  ✓ 149 …`) as a section boundary
and stopped early: 81 of 104 rows, `Σ✓ = 2264` against the run's `✓2759`. After fixing the parser (and keeping
any indentation), it reproduces the run's own totals exactly — 104 rows, `2759 / 5 / 33`. That is the measured
reason the design says the counts must come from the suite's **own counters** (instrumented deltas), not from a
post-parse of the output (design §1.2).

## Flip evidence (required for defect-fix tasks)

P97 is a **propose** task, not a defect fix — the flips below are the ones the *change* promises the apply to
produce, and this block measured their basis (the code does not exist yet by design; the proposal's Flip section
carries the same list):

- Red (today): a green FAST run carries no per-section counts and no summary; nothing can answer "which
  sections does this diff affect?" — this task had to hand-build two probes to get either (641 s per FAST run,
  under load).
- Green (after apply #1/#2): a section's close line carries `<S>s · ✓n ✗m SKIPk`, the run ends with the
  slowest-N summary, `section-select.sh --paths docs/team/BOARD.md` answers `decision=NONE` (无需跑),
  `--paths skills/teamsmith/scripts/lib/outbox.sh` answers `RUN` with the seed keys above, and an unclaimed path
  answers `FULL`.
- Break-it (the apply's guard test): delete the fallback rule → an unclaimed path yields `RUN` with an empty set
  → the selector fixture goes red; restore → green. Also: drop a row from `section-paths.tsv` → `--check` red
  naming the section; restore → green (R2 scenario 5).

## Decisions and deviations

1. **No `team gate` subcommand** (the brief allowed `team gate --paths …` *or* `smoke.sh --select <set>`): the
   selector is `tests/section-select.sh` + `smoke.sh --paths`/`--select`. Reasons (design D1): the data and the
   sections live in `tests/**` (agent-owned, no `scripts/**` grant), a `team gate` would be a second entry point
   beside `TEAM_GATES` that can drift, and teamsmith does not wrap the gate.
2. **Three ADDED requirements, no MODIFIED one** — so the delta cannot collide with `gate-section-accounting`'s
   in-flight MODIFIED block (measured by the trial archive above). The integration with P70 is code-level and
   sequenced in the apply briefs (D8).
3. **`--paths` semantics**: exempt class = `docs/**` only; `openspec/**` stays selectable because 10 sections
   read real `openspec/` paths. A `NONE` run takes no gate lock and prints no result line; a selected run takes
   the lock like a full run (its sections may be real-process ones).
4. **Subset-run traps named for the apply** (not hidden): the prologue + `needs` closure + the counts comparison
   against a full run (vacuity guard), and the whole-run self-checks (`14c`'s "every listed FAST segment was
   skipped", the tmp-root guard, the result accounting) must not fire merely because an unselected section was
   neither run nor skipped (design contract table, tasks 2.4).
5. **Not touched** (brief: propose only): `skills/**` — no code, no fixture, no `references/protocol.md` line
   (the pointer is a PM-owned edit; tasks 4.3). Nothing was pushed (local mode); the branch is local.

## Findings for the PM (not mine to fix)

- **`main` is red in FAST** (5 ✗, sections `14b`/`18`) from `f534ec4b`'s +17 lines in
  `skills/teamsmith/references/troubleshooting.md` (CJK prose; a `team review <ID> --post-merge` line without
  `--dir`). `HEAD == main == 61af37d1`, so this is reproducible on main without my diff. Owner:
  `references/**` is PM-owned (OWNERSHIP).
- **"FAST is seconds, no real processes" did not hold in this block**: 641 s / 627 s wall, 104 sections started,
  loaded by a full gate that ran with this worktree's suite copy from 01:21:19 for ~19 minutes plus 5+ other
  gates queued on `${TMPDIR:-/tmp}/teamsmith-smoke.lock` (P89 waiting 17:49, P94 1 h+). The selection this
  change proposes is the mechanism that makes that load avoidable in a batch; until it exists, FAST is not the
  cheap fallback its own header advertises.
- **The extractor is a lower bound** (37/104 sections name no real-tree path), so the map's soundness rests on
  authored rows plus the `--check` staleness direction, not on derivation alone — stated in the design's risks.

## Suggested next steps

1. PM proposal review → `docs/team/reviews/gate-runtime-budget-proposal.md` (ACCEPTED / NEEDS-CHANGES).
2. Sequence the two apply briefs **after** P70 (it owns the `section()` line and the timing record); if P70's
   delta rewrite is still blocked on `pty-fixture-load-premise`, apply #2 (the map/selector) is independent
   enough to go first except for item 1.5.
3. Grant `skills/teamsmith/references/protocol.md` to the apply (one line in §9b-2) or apply that line as PM.
4. Decide on the `main` FAST red (fix `troubleshooting.md` under the CJK/usage rules or waive it explicitly):
   the next delivery gate on main will show it.
