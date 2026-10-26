# behavior-focused-ci · design

Status: propose phase, revision 2 — planning only. No product, test, workflow, spec-base or document file was
changed by this phase; the only files written are this change's four artifacts and the report. Every number is
marked **measured** (a run whose log exists, in this session or in the ledger), **recorded** (a ledger record: a
review or report that states it) or **projection** (arithmetic on those, never a promise). Nothing was re-measured
for this revision: the brief forbids restarting the probe, running FAST or the full suite, or buying new timing
experiments.

## 0 · What revision 1 got wrong (the PM's finding, and it is correct)

Revision 1 excluded six sections from CI's per-push burden and then assumed the rest was affordable. It was not:

* **§61b** (routing flip matrix) is a *fixture meta-mutation* — 22 arms, **recorded 4946 s ≈ 82 min** (V28's own
  run; the table's row 61 basis records the same number; P243 repeats it), re-verified complete in V62 (31 arms,
  baseline `pass=3141 fail=0`). Revision 1's floor included it, so the "floor" it proposed could not have finished
  inside the 60-minute job — the same unexecutable-entry defect the PM rejected in P322's option A.
* Revision 1's acceptance plan asked for 44 per-scenario flips plus repeated full-baseline runs, which is a second
  version of the same mistake (paying the whole cost to prove the cost went down).
* Revision 1's path hand-in added a per-line `--paths-from` file, which loses a path containing a newline and reads
  git's C-escaped listing for anything with a quote or a backslash.
* Revision 1 renamed three requirement titles and left two references pointing at the retired titles, rewrote the
  scene's temp-root and collection mechanics as they were two changes ago, and left the load-laboratory requirement
  (whose fixture P316 deleted) as a "tail" instead of retiring it in the same delta.

This revision fixes all four and keeps everything the PM kept: one declaration, "a section nobody declared is in
CI", reuse of the selector, merging same-tree runs, no new guard, and an honest full/selection/FAST disclosure.

## 1 · Facts this plan stands on

| Fact | Value | Source |
|---|---|---|
| Last public CI run | run 39354787618 · image build 59 s, gate container 3550 s, cancelled at section #110 of 135 | recorded (public log) |
| Sections that closed | 109 of 135, summing **3544 s**; #110–#135 never ran | recorded |
| Gate self-check block | §0e 65 s + §0f 5 s + §0g 1 s + §0h 10 s + §0i 36 s + §36 **1314 s** = **1431 s** = 40 % of 3544 s | recorded |
| §36's two halves | ①–⑦ 250 s + ⑧ the checkout-shape probe **1064 s** | recorded |
| **§61b (flip matrix)** | **4946 s ≈ 82 min**, 22 arms; one complete run in V62 (31 arms, baseline `pass=3141 fail=0`) | recorded (V28, P243, V62) |
| §61b's position in the run | section **#128** of the suite; the last public run died at **#110** (its log's last section line), so the matrix never started in that run — its 4946 s is a standalone measurement, not a slice of the 3544 s | **measured** this session (source order vs. the run's own headers) |
| §61 (routing front gate) | FAST tier (12 groups) **121 s measured in the container** (P243), live tier 495 s with 13 groups (V28), three extra groups 9.5 s (P261) | recorded |
| §38-b (pty fixture) | skipped visibly under FAST, "慢段 ~2.5 分钟" in the full tier | recorded (`smoke.sh` 38-b line) |
| Nested runs in the probe | **29** `nest()` calls over 19 scratch trees → 4 prologue sections each (116) + 87 body-section executions = **203** | recorded (P322 static count + selector expansion) |
| `--select 58` expands to | 13 keys: prologue `0,0b,0c,0d` + closure `2,4,5,3b,6,6f,6i,13c` + `58` | **measured** in this session (selector, twice) |
| One `--select 58` nested run | 55.9 s / 55.0 s: body 10 s / 10 s, closure 42 s (§6f 17 s, §13c 11 s, §3b 7 s) | recorded (P322) |
| Nested-run overhead | 15 runs took 173.7 s against 126 s of section bodies → ≈3.2 s each | recorded |
| Scratch-tree copies | 10 trees at 0.3–0.4 s each (~47 MB real copy + git init/add/commit) | recorded |
| The probe's own comparison work | **151 s** of its 328.6 s (≈150 `case`/`sed` comparisons, `--check` on ten table variants, the static coverage inventory, two real-tree fingerprints) | recorded |
| Nested suite runs inside §36 | **45** = 16 `p98_nest` runs (①–⑦) + 29 probe runs | **measured** in this session (`grep -c 'p98_nest '` = 16) |

## 2 · What the plan does not do

No scheduler, no budget table, no path-scanning platform, no product test hook, no generic test framework, no new
gate section. The probe keeps all 29 cases (five are merged into a sibling's run, none deleted). No wall-clock
threshold returns, the CI job's 60-minute cap is not raised, the load laboratory is not restored, and the full gate
(§61b included) stays where D147 put it: the merge / milestone / release entry.

## 3 · The product floor: declaration, semantics, entry

### 3.1 Why a floor at all

The path table answers "what changed, so what else should run". It does not answer "which sections judge what the
project delivers", and it is proven incomplete in the safe direction only: an unclaimed path falls back to `FULL`,
so a leak costs extra runs rather than coverage. The risk is the other direction — a path claimed by a row whose
declared range is narrower than the section reads. CI's baseline therefore must not be derived from paths, and it
must not be a second key list in the workflow.

### 3.2 The declaration: one header line, default = floor

`section-paths.tsv` already carries non-row declarations in its header (`# exempt:`, `# prologue:`,
`# ledger-scan: …`), and `--check` ⑦ already validates one. The change adds **one** such line:

```
# gate-self-check: 0e 0f 0g 0h 0i 36 61b
```

* Only sections whose **subject is the gate's own machinery** are named. Everything not named is the product
  floor, so a new section is in CI until someone declares it a self-check: the failure mode is "one extra section
  in CI", never "what the project delivers silently out of CI".
* `--check` gains one pure-logic rule: every key resolves to exactly one row, none repeats, none is a prologue key.

Classification, with the evidence for each borderline case:

| Key | Subject | Class | Why |
|---|---|---|---|
| `0e 0f 0g` | section accounting, progress, scene | self-check | reads `smoke.sh`/`section-guard.sh` only |
| `0h` | tmux isolation preamble | self-check | installs the suite's own guard |
| `0i` | run fingerprint | self-check | judges the suite's own tree discipline |
| `36` | selector, table, copies, probe, coverage ledger | self-check | 1314 s; subject is the gate's machinery |
| `61b` | routing **flip matrix**: breaks the routing implementation arm by arm and requires §61's named assertions to go red | self-check | D147: "§61b 证的是夹具自己的牙齿…不是产品行为"; 4946 s recorded |
| `61` | routing front gate: category/model decisions, refusals, resume reuse | **product** | delivered behaviour; 121 s FAST / ≈505 s live |
| `34 34b 34d 31c` | gate lock, its accounting | **product** | shipped mutex used by every seat |
| `40`, `31`, `39`, `58` | tmp-root/doctor, tmux shim, signal gate/lint | **product** | shipped boundaries (the brief names them) |
| everything else | — | product | conservative default |

Mixed subjects stay `product` (more runs). A section that turns out to be a tool-combination self-check can be
declared later by editing one line — that is the only place the classification lives.

### 3.3 The entry: `--floor`, and the paths as they already exist

`section-select.sh --floor [--paths <path>…]`: keys = prologue ∪ every floor row ∪ closure of their `needs`, plus
the path-claimed keys when paths are given. `--paths` alone keeps today's documented semantics exactly
(`NONE`/`RUN`/`FULL`); `--floor` is a distinct decision whose floor is never empty. `--floor` combined with
`--select` is refused (mixing them muddies "an explicit selection"), and a floor with no product section `die`s
naming the empty floor instead of running the prologue alone.

**No new path interface.** A path may contain a newline, and `git diff --name-only` C-escapes quotes and
backslashes (`core.quotePath` covers non-ASCII only), so a line-oriented file cannot represent the input. The chain
is NUL-separated from git to the argument vector: `git diff --name-only -z <base> <tip>` read with
`while IFS= read -r -d ''` into a bash array, then `--paths "${PATHS[@]}"` — as the container command's own
arguments (`bash -c '… --paths "$@"' _ "${PATHS[@]}"`), which the read-only workspace mount requires anyway.
`smoke.sh --floor [--paths …]` delegates to the same code path as `--paths` and keeps the disclosure contract
unchanged (header with `decision=`, sections run/not run, `== 选段结果 ==`, no `smoke 全绿`, prerequisite skips
counted apart from passes).

### 3.4 Cost: what the floor is, and the one number that is still unknown

| Entry | Sections | Recorded cost |
|---|---|---|
| Ordinary CI push (floor ∪ changed paths) | everything except `0e 0f 0g 0h 0i 36 61b` | ≈2113 s in the 109-section subset (3544 − 1431); **§61b's 4946 s is not in it** |
| A push that changes the gate's own sources | floor + `36` (1314 s) or `61b` (4946 s) | the price of changing what they judge |
| Merge / milestone / release (full run) | all 135 | unchanged from today, §61b included (D147's practice) |
| `team review` (independent verification) | full | unchanged |

Two honest limits: (1) the 2113 s figure is a subset sum, not a measured floor run; (2) CI runs **without** FAST,
so a few product sections (§38-b ≈2.5 min, the routing front gate's extra groups, §38’s pty fixtures) cost more
than the FAST numbers recorded here. Apply therefore measures the floor **once**, in the pinned image, as part of
the run it has to make anyway, and records the number; this proposal does not claim the floor fits 60 minutes.
If it does not, the lever is the one this change already uses — a section whose subject is a tool combination is
declared a self-check by editing the one header line — never raising the cap.

## 4 · The probe: which repetitions go, and who takes them over

### 4.1 The one correction: `58`'s `needs` is provenance, not a prerequisite

`--select 58` today expands to 13 keys (`0,0b,0c,0d` + `2,4,5,3b,6,6f,6i,13c` + `58`) — 55.9 s for a section whose
own body takes 10 s. With the row's `needs` set to `-` the same command answers `keys=5` (`0,0b,0c,0d,58`) and
`--check` stays green (ok 8 / bad 0 / SKIP 1); both **measured** this session on a table copy, in pure logic.

Key counts prove nothing on their own, so the justification is the actual dependency plus a **behavioural
counterexample pair** (apply task C1):

* §58's body (`smoke.sh` 22114–22260) reads only files — `tests/signal-lint.pl`, `tests/signal-lint-legacy.txt`,
  `tests/signal-gate.sh`, `tests/team-bg-stop.sh`, `tests/team-bg-harness.mjs`, `extension/team-bg.ts`,
  `scripts/team` — plus `$TMP` and `$TS_RUNNER`, and the preamble's helpers (`assert_*`, `ok`/`bad`,
  `prereq_skip`, `checkout_*`).
* `$TS_RUNNER` is set in the preamble (1376–1385) before any section runs; §13c (7692→) builds fixtures under its
  own `$TMP` and nothing §58 reads. The harness imports Node built-ins only and runs the `.ts` extension directly.
* The row was born with §58 in P159 (`git log -S'13c'` → `05c6dabc`); its `basis` column lists the files §58
  reads and names no runtime dependency.
* **Counterexample A (the deletion is right)**: on a tree with no `needs` closure, `--select 58` is green and its
  closing line carries the same `✓/✗/SKIP` counts as the same tree with the closure.
* **Counterexample B (the `needs` mechanism still bites)**: a section that really does need its prerequisite —
  §17 requires §15b's fake settings/spec tree (the gate's own comment says so) — goes red when §15b is removed and
  green when it is present. If A and B do not come out that way, the correction is wrong: revert the row and keep
  the merges only.

**Takeover of the 56 executions this removes**: the closure's sections (`2,4,5,3b,6,6f,6i,13c`) are all floor
sections, so they run on every CI push and every full run — on the real tree, not a scratch copy. The probe's
question ("does the signal lint's skip attribution hold in this checkout shape?") is answered by §58's own lines,
which stay asserted in all seven cases.

### 4.2 The merges: same tree, same state, one run

29 nested runs → **24**. Each merge replaces two or three runs on one scratch tree *in one state* with one
`--select a,b,c` run; every assertion keeps reading its own section's lines, so nothing is lost and each verdict
stays separately visible in one log.

| # | Tree (state) | today | after | saves |
|---|---|---|---|---|
| 1 | `hy` (clean mixed shape) | `19`, `31`, `58` | `19,31,58` | 2 starts + 2 prologues |
| 2 | `hyteeth` (planted `pkill`) | `31`, `58` | `31,58` | 1 start + 1 prologue |
| 3 | `in2` + the case-declared evidence file | `31`, `58` | `31,58` | 1 start + 1 prologue |
| 4 | `mix` + ten phase files (surface present) | `19`, and `18` on the same tree | `18,19` | 1 start + 1 prologue |
| — | `s2`, `empty`, `hy` old-rule, `c1` ×3, `teeth10` (clean → shadowed / baseline → mutated → restored) | unchanged | unchanged | — |

24 runs: `po 18,19`, `s1 18`, `s2 19`, `mix 18,19`, `empty 19` ×2, `hy-oldrule 19`, `hy 19,31,58`, `hyteeth 31,58`,
`c1 18` ×3, `po2 12k,31`, `in2 12k`, `in2-ev 31,58`, `s2-shadow 19`, `teeth 31`, `mutant 31`, `shadow 31`,
`prodent 31`, `po10 58`, `teeth10 58` ×2, `plant10 58`.
Section executions: 203 → **127** (116 prologues become 96; the seven §58 runs contribute 7 body sections instead
of 63).

### 4.3 What is deliberately not reduced

* **§36①–⑦** (250 s, 16 nested runs): each is a distinct red side, and ⑦'s 117 s full-key `bash -n` sweep guards
  the copier that path selection depends on *more* than before.
* **The probe's own 151 s**: the comparison work of ~150 assertions; it shrinks only by asserting less.
* **The 19 scratch trees (≈7 s)**: real copies are the discipline that keeps a fixture from writing through a
  symlink into the real tree (§8's fingerprint).

### 4.4 Projection (not a promise)

Nested time 518 s → ≈204 s locally (7 × 42 s of closure, 5 starts and preambles gone); probe total 676 s → ≈350 s
locally, ≈550 s at the 1.57 ratio P322 measured between the local and CI columns, so §36 ≈1314 s → ≈800 s there.
Apply measures the real numbers and records them; no report of this change may quote these as measurements.

## 5 · The spec and the effective documents: what leaves, what replaces it, and why a rename is forced

### 5.1 The tool's own refusal, measured (so this is not an assumption)

The PM asked for the tool's actual error rather than an assumed limitation. A `MODIFIED` block that keeps a
requirement but drops one of its scenarios is refused — reproduced in a scratch copy of `openspec/` (base text
kept verbatim, last scenario removed):

```
$ ~/.bun/bin/openspec validate zz-mod --type change --strict
Change 'zz-mod' has issues
✗ [ERROR] verification/spec.md: MODIFIED "Every gate section accounts for itself, and a stuck section is named"
  omits scenario(s) the current spec still has: "A run that an outer clock kills can still say where it was".
  Copy them into the MODIFIED block (a MODIFIED requirement replaces the whole block, so archive refuses to drop them).
```

So a requirement that has **at least one scenario whose title is a retired commitment** cannot stay `MODIFIED`
unless that scenario stays with a false body. Exactly three requirements are in that position; every other block in
this delta is `MODIFIED` with its original title and all of its base scenarios.
The light trial-archive of the real change (measured, `design.md` §6) reports `+ 3, ~ 6, - 4` with a green
post-archive validate, so the refusal above is the only mechanism at work, not an archive surprise.

### 5.2 The three retirements, and the scenario that forced each

| Retired (`**Reason**`/`**Migration**` in the delta) | Scenario whose title is the retired commitment | Successor (old stem kept) |
|---|---|---|
| `The correctness gate judges correctness only` | "A machine over the premise skips visibly, and the gate is not red"; "The premise's readings stay real on the real path" | `…, and a duration is a reading` |
| `The performance suite is separate, self-describing and non-blocking` | "A slow frame is red with its numbers"; "A busy machine skips visibly instead of passing" | `…, and its numbers are reference-only` |
| `Every gate section accounts for itself, and a stuck section is named` | "The budget table has a measured basis, and a weakened budget is red" | `…, and a section that stops making progress is named` |

The other scenarios of those blocks are **kept and rewritten** to the instruments that exist: the slow-but-correct
console, the duration-marker guard, the knob-integrity line, "a skip is never a pass" (now the checkout-prerequisite
skip), the environment self-description, the suite's lock, "not part of a review", the accounting/progress/scene/
watchdog contract. The `**Migration**` text names, per retired scenario, what now asserts its promise.

### 5.3 The fourth retirement: the load laboratory, with no replacement copy

`verification#A load experiment signals only the processes it started` is retired in this delta. Its fixture
(`skills/teamsmith/tests/load-experiment.sh`) does not exist, the load premise it existed for is retired, and the
user deleted the laboratory itself. The generic rule is an existing contract —
`boundary#Signals go to a recorded pid, never to a name or a pattern`,
`boundary#Scripts select processes by recorded pid, and the lint keeps it that way`,
`boundary#The signal gate's calls are recorded, and its refusals outlive the call log's rotation` — whose guard
tests (`tests/signal-gate.sh`, `tests/team-bg-stop.sh`) still ship and still run in §58. Nothing is restored, and
no "tail task" is left behind.

### 5.4 The effective documents move in the same change

`skills/teamsmith/SKILL.md` and `skills/teamsmith/references/protocol.md` still state the retired red lines
(`SKILL.md`'s Performance row: 2000 ms / 2000 ms / < 1 %, premise factors 0.75 / 0.25, exits `0/2/4/3`; `SKILL.md`
§"panel-cpu-premise … visible SKIP"; `protocol.md` §9b-2's "measurement premise" and its perf paragraph's
thresholds, factors and "skips visibly"). They are in the write set (task B4), because a spec that says "reference
only" while the shipped skill says "red line" leaves the reader with two answers.

### 5.5 What is *not* claimed

`A measuring fixture measures a fixed tree, not the caller's worktree` no longer promises that two runs print the
same numbers (a fixed measurement target does not make a measurement deterministic); it promises the same target
and the same named output. One reference in the accounting block and one in the fixture-observation block were
renamed to the successor titles — no reference in this delta names a retired title (checked with `grep` and by the
post-archive read).

## 6 · Evidence for apply (point evidence, not a matrix), and the one full run

The PM's R2 removed the per-scenario flip quota. What remains:

**C1 — `58`'s row, behaviourally.** Scratch tree with the row at `-`:

```
$ bash skills/teamsmith/tests/section-select.sh --select 58 --root <tree>            # keys=5, decision=RUN
$ bash <tree>/skills/teamsmith/tests/smoke.sh --select 58                            # §58 counts equal to the closure run
$ bash skills/teamsmith/tests/section-select.sh --select 17 --root <no-15b-tree>     # counterexample B: red without 15b
```

**C2 — the declaration, in pure logic.** `--floor` lists every section the line does not name plus the prologue;
removing one key from the line lets exactly that section into the floor (including `61b` when its key is removed);
an unknown key makes `--check` red; `--floor --paths <a gate-selector path>` adds `36`; `--floor --paths
<a gate-self-check's own fixture path>` adds `61b`; `--floor --paths ci/some-new-thing` is `FULL`; an empty floor
`die`s. No suite run.

**C3 — the CI entry, one run.** The workflow's exact command in the pinned image with a paths array built by the
NUL chain: exit 0 on a clean tree, the tail carries `decision=`, the not-run list and `== 选段结果 ==`, no
`smoke 全绿`; a planted product failure in a floor section makes it non-zero. The path-shape case runs the
selector directly (a file with a quote/backslash, and one with a newline in its name) — pure logic.

**C4 — the single fixed-environment run.** `smoke.sh --floor --paths <the paths this change touched> --keep` in the
pinned image, once, at the end: it is simultaneously the floor measurement (§3.4), the combined assertions of the
merged probe runs (§4.2), and the disclosure check. Its wall clock and tail go in the report; §61b and the other
heavy sections are **not** in it, and the report says so.

**Unchanged behaviour is cited, not re-proven**: performance readings and their non-blocking status (P316 + V65 +
V66), the gate lock and queue (`TEAM_SMOKE_LOCK`, unchanged), the waits' caps (`lib/pty-wait.sh`, unchanged).

## 7 · Boundaries

* **Ownership.** `gates.yml` and `smoke.sh` are P324's temporary files (two recovery probes' env prefixes; the
  rest frozen) — task B waits for P324 to freeze and merge. `docs/team/RELEASE-PUBLIC.md` is the PM's (`docs/**`),
  so that one bullet needs an explicit grant or the PM's own edit. `skills/teamsmith/tests/**` and the two
  documents in §5.4 are the dev seat's.
* **D147 is the standing ruling** for `61b`: the full gate and the flip matrix belong to merge/milestone/release.
  This change does not overturn it; it stops the *ordinary CI entry* from paying for it, which is what D147's
  companion practice already asked for.
* **No promise about CI wall clock.** The change removes measured work; whether the ordinary entry fits 60 minutes
  is proven by the run after the change (C3/C4), not by this document.
