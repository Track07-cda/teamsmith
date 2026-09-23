# gate-runtime-budget · design

Status: propose phase (planning only — no `skills/**` change in this task). Every number below was measured in
this task's block; the raw artifacts are committed next to the report
(`docs/team/reports/P97/{probe-section-paths.sh,probe-section-paths.tsv,measure-fast.sh,per-section-times.pl,
fast-run-r1.log,fast-run-r2.log,fast-section-times-r*.tsv}`) so the apply and the verify can repeat the shapes.

## 0. The problem, stated precisely

See `proposal.md` — Why. Two facts frame every decision below:

- The machine, not the work, is the bottleneck: one gate lock, one full run at a time, 13–20 minutes a run.
  `references/protocol.md` §9b-2 (the 2026-09-23 user directive) already tells a task to run the full suite
  **once at delivery** and to "prefer FAST plus the affected sections" in a batch — but nothing says which
  sections a diff affects, so the only mechanical answer today is "all 104 of them".
- The suite is **one linear script** (14 152 lines, 104 `section` calls: 103 at column 0 and `14c` indented):
  sections share shell state (`$TMP`, `$REPO`, `$SESSION`, fixtures built by earlier sections — the suite's own
  comment says `17` reuses the fake settings/spec tree `15b` built), every section in FAST prints its header,
  and FAST replaces 33 whole sections or sub-segments with a printed `SKIP` line (its `14c` section asserts that
  all of them are skipped visibly).

## 1. What was measured in this block

### 1.1 The path→section derivation, run over the real suite (probe)

`docs/team/reports/P97/probe-section-paths.sh` normalizes the suite's own path variables
(`$SKILL_DIR` → `skills/teamsmith`, `$SKILL_INIT_DIR` → `skills/teamsmith-init`, `$SRC_ROOT`/`$OS_ROOT`/
`$V94_ROOT` → the repo root) and extracts repo-relative literal paths per section, splitting the file at
`section "…"`:

| measurement | value |
|---|---|
| path tokens found | **406** |
| sections naming at least one real-tree path | **67 of 104** |
| sections naming none (`skills/teamsmith/scripts/**` driven only through the `$TEAM` CLI, or fixture-only) | **37** |
| real-tree `docs/` paths named anywhere in the suite | **0** |
| sections naming real `openspec/` paths | **10** (`6j`, `7b`, `12e`, `12g`, `12h`, `20`, `25`, `26`, `28`, `33`, `35`) |
| `skills/teamsmith/scripts/lib/outbox.sh` named directly | **4** (`12b-h0b`, `12b-h0d`, `42`, `46`) |
| sections whose text mentions `outbox` in any form | **13** (`12b` ×76 hits, `12b-h0`…`12b-h0d`, `12b-pi`, `12b-pi2`, `26`, `27`, `42`, `44`, `46`, `47`) |

Two consequences are designed in below: the extractor is a **lower bound** (37 sections name no path at all, so
the claim must be authored, not derived), and the *exemption* for `docs/**` is measurable rather than asserted
(0 hits, and section 14b's scanner deliberately excludes `docs/**`).

### 1.2 Two timestamped FAST runs (the accounting prototype and its noise)

`TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null`, every output line timestamped
(`perl -MTime::HiRes=time`) → `fast-run-r1.log` / `fast-run-r2.log`, parsed by
`per-section-times.pl` into `fast-section-times-r1.tsv` / `-r2.tsv`:

| run | wall | sections started | ✓ / ✗ / SKIP | loadavg before → after |
|---|---|---|---|---|
| r1 | 641 s | 104 | 2759 / 5 / 33 | 12.34 → 13.39 |
| r2 | 627 s | 104 | 2759 / 5 / 33 | 14.08 → 8.31 |

The slowest sections in r1 (seconds): `12b-pi` 76.2, `38` 60.4, `34` 47.4, `26` 36.3, `33` 34.5, `39` 34.1,
`15c` 22.8, `12b-pi3` 22.0, `12b` 19.9, `17` 19.6, `15b` 17.3, `28` 15.8, `6f` 14.8 — and **446 s of the 641 s sit
in those 15 sections** (24 of the 104 sections are 80 % of the wall time), i.e. a handful of sections dominate a
run that nominally targets "< 60 s". The two runs
agree closely on the same sections: across the 103 sections whose interval both runs measured (the last
section's interval is not observable by this prototype), the relative difference is a
median **2.9 %** (mean 4.0 %, max 14.4 %) for the 60 sections that took ≥ 1 s, the largest absolute moves are
`12b-pi3` 22.0→19.3 s and `38` 60.4→58.8 s, and the wall differs by 2.2 % (641 vs 627 s) — with `loadavg`
8–14 and several full gates queued on the machine lock in both runs, so the load is part of every reading and
the timings are reproducible enough to be *data*.

Two facts about the prototype matter for the implementation:

1. **The counts must come from the run's own counters, not from post-parsing.** A first parse of the same log
   treated an *indented* fixture result line (`      == 结果 ==  ✓ 149 …`) as a section boundary and stopped
   early; the fixed parser reproduces the run's own totals exactly (2759/5/33) — but that equivalence was
   achieved only by re-deriving the suite's line format. Instrumented counter deltas are the honest source.
2. **The elapsed time is a header-to-header interval** in a prototype, and every section prints a header, so
the attribution is well defined for the started sections; the implemented accounting must still use the suite's
own clock (the section's start/close) and must count each section's `SKIP` attributions (FAST's 33 lines belong
*inside* the section that printed them, as `SKIP_N` deltas do).

Red state of the tree during this block (recorded because it shapes the acceptance): **main is red in FAST** —
5 ✗ in sections `14b`/`18` naming `skills/teamsmith/references/troubleshooting.md` (CJK prose and a
`team review … --post-merge` teaching line), a tracked file at HEAD == `main` == `61af37d1` (commit `f534ec4b`,
2026-09-23T01:01:54Z). Nothing in this task's diff touches `skills/**`; the finding is in the report.

### 1.3 The trial archive (the delta's integration with the other open changes)

`mkdir -p /tmp/p97-trial-$$ && cp -r openspec /tmp/p97-trial-$$/openspec && (cd /tmp/p97-trial-$$ && openspec
archive -y gate-runtime-budget)` → **`+ 3 added, ~ 0 modified, - 0`** into
`openspec/specs/verification/spec.md`, and `openspec validate --all --strict` in that scratch tree:
**31 passed / 0 failed before, 30 passed / 0 failed after**. So this change archives in any order, and it
rewrites no other change's promise — unlike `gate-section-accounting` (P70), whose delta *modifies* a
requirement another open change already modified. The remaining coordination with it is in the **code**, not
in the delta (D8).

## 2. Goals / Non-Goals

**Goals**
- A per-section accounting that makes a run's cost and outcome *readable* (seconds, ✓/✗/SKIP per section, a
  slowest-N summary) — as data.
- A committed, checkable path→section map and a pure-logic selector with a **conservative fallback**.
- A selection that can be run inside a batch, that cannot be mistaken for a full run, and whose report names
  what it did not run.
- Every check falsifiable in FAST, with no new process and no new dependency.

**Non-Goals** (the brief's item 5, stated as design boundaries)
- **No assertion, threshold, skip rule or fixture premise is relaxed to gain speed.** The selection chooses
  *which* sections run; it never changes a section's body. The accounting adds no threshold. The delivery
  evidence for that is a measured comparison: the full-run/FAST totals (✓/✗/SKIP) must be identical before and
  after the change on the same tree (the apply records them; the r1/r2 tables above are the pre-change side).
- No gate re-architecture: no function-per-section refactor, no process-group signalling, no change to the gate
  lock/queue, no change to the performance suite or D33's split.
- No change of default: an invocation without the new flags runs every section, exactly as today.
- No `team gate` subcommand and no `.github/workflows/**` change (D1, D6).
- Not a claim that a selected run finds every red: the map is a lower bound; the full suite stays the
  delivery/review/archive gate (protocol §9b-2).

## 3. Decisions

### D1 — The selector is a pure-logic script under `tests/`, consumed by `smoke.sh`; no `team gate` subcommand

`skills/teamsmith/tests/section-select.sh` owns the map's semantics (`--paths`, `--select`, `--check`,
`--list`), and `smoke.sh --paths`/`--select` consumes its answer. Rejected alternatives:

- **`team gate --paths …`** — a second gate entry point whose flags must be kept in sync with `TEAM_GATES`
  (which `team review` runs), plus lock/queue negotiation, plus a `scripts/**` grant; and teamsmith's rule is
  that the protocol's command runs the gate, not a wrapper (memories #982/#964).
- **Map logic inlined in `smoke.sh`** — the check must run without the suite (and the suite is the file every
  other task edits); a separate script keeps the check testable in isolation and lets the apply's fixture drive
  it directly.

### D2 — The map is one data file with a recorded basis, not in-source annotations

`skills/teamsmith/tests/section-paths.tsv`: comment header (exempt class, prologue keys, matcher semantics)
then one row per section — `key`, `id`, `patterns`, `needs`, `basis`. The `basis` names the evidence the claim
rests on (the fixture the section drives, the file it sources), so a reviewer can check the row without
re-deriving the map; §1.1's probe output is the seed. Rejected: **in-source `@covers` directives** (104 edit
sites in the one file with the most churn, and the section id is already the key the suite prints) and
**deriving the map entirely from the extractor** (it is a lower bound: 37/104 sections name no path).

### D3 — One matcher, documented semantics: repo-root-relative `case` globs, where `*` crosses `/`

Both the selector and `--check` use the same matcher (one function), so a claim cannot mean two things. Bash
`case` semantics are used deliberately: no dependency, the suite's own idiom, and the failure direction is
conservative (`skills/teamsmith/*` matches deeper paths too ⇒ more sections run, never fewer). Rejected:
`**`-aware globbing (a parser or pathspec engine for no safety gain) and exact-path rows only (a 400-entry
table that rots).

### D4 — Decision semantics: `RUN` / `NONE` / `FULL`, with the fallback for anything unclaimed

- `NONE` — every given path is in the declared **exempt class** (`docs/**`, the team ledger; basis: §1.1's zero
  hits plus 14b's documented exclusion) and no row claims it. The answer says no section needs to run.
- `RUN` — every given path is claimed: the keys whose patterns match, **plus the prologue and the transitive
  `needs` closure**, each with the path that selected it.
- `FULL` — at least one path is claimed by no row and is not exempt: the output names those paths. Running more
  is always safe; running too little is not. Rejected: an `--assume-ok`/`--force` flag (the conservative
  fallback must not be bypassable), "any `.md` is docs" (sections `14b`/`18`/`19` assert on
  `skills/teamsmith/references/**` — exemption is by path, not extension), and treating `openspec/**` as
  exempt (10 sections name real `openspec/` paths, §1.1).
- An unknown key, a path outside the repository, or a malformed row is a hard error (exit 2, nothing runs) —
  never a silent `FULL`/`NONE`.

### D5 — Prerequisites are declared per row and validated by the counts, because state is shared

The prologue always runs; each row declares the keys it needs; the selection is their closure in source order.
Because the suite is linear, a missing prerequisite can produce a **vacuous pass** (fewer ✓, still green), so
the apply must validate each shipped selection set by comparing the section's per-section counts against a
full run of the same tree (the `17`/`15b` coupling the suite documents is the fixture that pins it). Rejected:
trusting the declarations (silent vacuity) and refactoring the linear suite into independent sections (a
Non-Goal: it would touch every section's body).

### D6 — The default and the milestone rules do not move

No flags ⇒ every section runs exactly as today. A selection is a batch filter: delivery, `team review` and the
archive milestone keep the full suite (protocol §9b-2), and a `NONE` selection runs no section and prints no
result line (so it cannot be recorded as a gate run). A selected run takes the machine gate lock exactly like a
full run (it may execute real-process sections); a FAST-mode selection keeps FAST's private lock, as today.

### D7 — A selected run cannot be mistaken for a full one

Distinct result token (`== 选段结果 ==`, never `== 结果 ==`), never the full-run token `smoke 全绿`, a header
naming the decision and the unselected keys, and the **not-run list inside the last lines of the output** — so
the tail `team review` records carries it without touching `cmd-review.sh` (whose verdict token is pinned
`PASS|FAIL|TIMEOUT|SKIPPED|UNKNOWN`). Rejected: a new review verdict token (needs `scripts/**`, breaks the
pinned parser) and silent skipping (the "never claim a run you did not do" rule).

### D8 — The accounting rides the section line the in-flight change already promised; the counts are plain text

`gate-section-accounting` (P56 propose merged, P70 apply brief `todo`) owns the per-section start/close lines,
the hard budget, the scene and the timing record. This change's promise is **additive**: the counts and the
slowest-N summary, `✓`/`✗`/`SKIP` printed as plain text that does **not** carry the red marker
`  \033[31m✗\033[0m` (which `flip-m33.sh` counts with `grep -cF`), **no** duration compared to a threshold
anywhere in this change (P56/P70's design puts the one allowed comparison in `tests/lib/section-guard.sh` and
adds the `gate-guard.sh` direction for it — today the guard's closed comparison set only catches the 2000 ms
perf forms, so this change's obligation is simply not to add one), and the internal consistency rule (the
per-section sums equal the run's own totals). Whichever of the two lands first, the other's line/record is
extended rather than replaced; §1.3 measures that the deltas do not collide, so the coordination is a
code-level integration the apply briefs must sequence (P70 first: it owns the line, the budget lookup and the
record).

### D9 — The checks run in the gate (FAST) *and* standalone

`section-select.sh --check` is the standalone check; a pure-logic FAST section in the gate calls it (the
`gate-guard.sh` pattern), so table rot is caught by the gate itself rather than by a human. Rejected: a
`team doctor` direction (doctor reports environment readiness, not the gate's data, and it needs `scripts/**`).

### D10 — The summary's N and the report's basis come from measurement

The slowest-N default is 5 (`SMOKE_SLOWEST_N`, fixture-only, like the existing knobs), chosen because §1.2's r1
shows 614 s of 641 s inside the 15 slowest sections: five rows name the run's shape without a wall of lines.
The apply re-measures its own tree (the counts comparison in the Non-Goals) instead of inheriting these
numbers, and records the load beside them (§1.2's r1/r2 spread is why the load is part of the evidence).

## 4. The shapes the apply must implement (contract for the implementer)

| Element | Shape |
|---|---|
| map | `skills/teamsmith/tests/section-paths.tsv` — `#`-comment header (`exempt:` `docs/**`, `prologue:` keys, the matcher's semantics) + a column header + rows `key \t id \t patterns \t needs \t basis` |
| selector | `skills/teamsmith/tests/section-select.sh` (`--paths <p…>`, `--select <key…>`, `--check`, `--list`) — pure logic, no git, no process |
| decision output | first line `decision=FULL\|NONE\|RUN`; `reason=` lines naming the paths (and, for `RUN`, `key<TAB>why` with the matching path); exit 0 for a decision, 2 for a usage/table error |
| suite flags | `smoke.sh --paths <p…>` / `--select <key…>`; unknown key ⇒ exit 2 with nothing run; `--paths` with a `FULL`/`NONE` decision prints that and either runs everything or nothing |
| prologue | the keys declared `prologue:` (the sections that build `$TMP`/`$REPO`/`$FAKE` and run the static checks) always run in a selection |
| accounting | per-section close line: existing `#<N>`/id + `<S>s · ✓n ✗m SKIPk` (plain text); the last started section closes before the result line; sums equal the run's totals |
| summary | before the run ends, one block naming the slowest N sections (N=5) with id, seconds, counts |
| selected run | header with `decision`, `n/M` sections and the unselected keys; result token `== 选段结果 ==`; no `smoke 全绿`; not-run list within the last lines |
| lock order | the selection decision is computed before the gate lock is taken, so a `NONE` decision never queues and a selected run takes the lock exactly like a full run (FAST keeps its private lock) |
| selection-aware self-checks | the whole-run self-checks — `14c`'s "every listed FAST segment was skipped" assertion, the tmp-root guard's per-run invariants and the result-line accounting — must not turn a selected run red because a section it never selected also never skipped anything; they stay whole-run checks (a full run runs them) and are either skipped with a notice or made selection-aware |
| checks | `section-select.sh --check` (both directions, the exempt class, `needs` closure, literal patterns exist, no named path uncovered) + a pure-logic FAST section calling it |
| knobs | `SMOKE_SLOWEST_N` (and any selection knob) honoured only under `TEAM_SMOKE_FIXTURE=1`, printed as ignored otherwise |

## 5. Coverage

| Requirement (delta) | Decisions | Apply items |
|---|---|---|
| `verification#The run reports each section's outcome counts and its slowest sections` | D8, D10 | 1.1–1.5 |
| `verification#A changed-path list selects the sections to run, or the full suite` | D1–D6, D9 | 2.1–2.5 |
| `verification#A selected run says what it did not run` | D6, D7 | 3.1–3.3 |

## 6. Risks / Trade-offs

1. **[Under-declaration: a section that a changed path affects does not claim it, so a selected run misses a
   red]** → the `FULL` fallback covers unclaimed *paths*; `--check` reds when a section's own text names a
   real-tree path its row does not cover; 37/104 sections name no path at all, which is stated rather than
   hidden, and a selection is batch feedback only — the full suite is the delivery gate and a report resting on
   a selection names what it did not run.
2. **[A selected run is vacuous because a prerequisite did not run: the section asserts less and still reads
   green]** → the `needs` closure, the always-run prologue, and the counts comparison against a full run (D5);
   the fixture pins the `17`/`15b` case. Residual: a coupling nobody declared and nobody's counts exposed.
3. **[Table rot: sections renamed/split, patterns stale]** → `--check` in both directions (a section without a
   row, a row without a section, a literal pattern that no longer exists, a named path not covered) runs inside
   the gate; the FAST section fails on drift.
4. **[False precision from `case` globs where `*` crosses `/`]** → documented in the data file's header and in
   the check's output, one matcher for selector and check, and the conservative direction is the safe one.
5. **[The accounting becomes a performance red line by accident]** → plain-text counts (no red marker,
   `flip-m33.sh` pinned by a scenario), no duration comparison added by this change (`gate-guard.sh`'s closed
   comparison set stays green today; P70's own guard direction covers the budget module), and the D33 flip (the
   assembly-delay fixture) stays green.
6. **[Selector overhead in a batch]** → pure logic (no process, no git): the acceptance records its wall time
   beside the sections it selects; the map is read from one small TSV.

## 7. Migration plan

Two apply briefs, ordered: (1) the accounting alone (no behaviour change to any section, the totals comparison
as its evidence); (2) the map + selector + checks + the `--paths`/`--select` path in the suite. Rollback is
`git revert` of either commit — no data migration, no configuration, and an invocation without the new flags
behaves exactly as today (D6). If `gate-section-accounting` (P70) has landed first, apply #1 extends its close
line and record instead of adding its own (D8); if not, apply #1 lands the close line itself and P70's later
apply extends it.

## 8. Open questions

None that change the spec, the approach or the item breakdown. The per-row `needs` values are data the apply
derives and validates by the counts comparison (D5); §1.1's numbers are the seed, not the promise.
