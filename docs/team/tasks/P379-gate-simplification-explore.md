# P379 · Explore which gate work can be removed, deferred or parallelized

task: P379
agent: dev2
phase: explore
category: analysis
change: -
specs: verification#The gate judges behaviour only, and never reports a skip as a pass
anchor: none (infra) — read-only analysis and a measured simplification proposal, no implementation
deltas: -
branch: task/P379-gate-simplification-explore

## User request and non-negotiables

The user asks to simplify and remove unnecessary gate work. This is not permission to delete necessary coverage. Use the existing rule: keep contract behavior, named incident regressions, silent-failure detection and installation-after-packaging behavior; remove duplicated branch restatements, gate-of-gates work, stale text/pixel assertions and repeated setup that does not add a new behavioral observation. Performance numbers are reference only, never the reason by themselves for deletion.

## Measured baseline (use the real log, do not rerun the full suite)

Frozen full gate log: `$HOME/.cache/release034/full.log`, 134 sections closed, 5058 pass / 1 fail, 14363.7s total. Section durations extracted from that log:

- `61b` routing mutation matrix: **6719s** (48% of all section time)
- `51` usage/help route honesty: **1190s**
- `36` selector/ledger self-checks: **1122s**
- `38` settings/panel choices: **820s**
- `62` key-reply storage/CLI: **710s**
- `61` model-routing front door: **655s**
- `40` temporary-root discipline: **320s**
- `63` key-reply panel page 5: **279s**
- `51b` orphan census: **164s**
- `33` config contract: **152s**
- `39` npm install shape: **100s** in that run; ~155–177s in later runs

The full section table is `skills/teamsmith/tests/section-paths.tsv`. Public CI already supports independent per-shard jobs in `.github/workflows/gates.yml`. Previous same-machine parallel shard attempts produced shared-state failures; do not recommend same-machine parallel tmux/process fixtures without proof of isolation.

## Questions to answer with code/log evidence

1. **61b**: inspect the flip harness and arm list. Which arms are independent enough to run in separate CI jobs (own scratch, HOME, TMPDIR, tmux socket, evidence and process names)? Which arms use machine-global process/tmux state and must stay serial? Propose a small always-on arm subset for high-risk contracts and a nightly/release full matrix; do not call the whole matrix unnecessary without classifying arms.
2. **36**: how much time is nested gate/selector self-checks versus direct behavior assertions? Identify exact commands/fixtures that can be removed or replaced by small non-nested fixtures. Only-on-selector-change scheduling is a valid alternative, but say what coverage moves where.
3. **51**, **38**, **62**, **63**: identify repeated initialization/build/server startup and text/pixel or duplicate assertions that can be removed without losing the behavioral contract. Distinguish pure storage/logic tests from live terminal tests.
4. Which sections can safely be parallelized in **independent CI jobs/containers**, and which must remain serial on one machine? Use the actual needs and shared resources (tmux server, process view, machine lock, real ledger, real HOME, network/port).
5. Propose two concrete profiles with estimated wall time and what runs in each:
   - normal push/PR: target **≤30 minutes** on CI, preserving changed-path selection and high-risk smoke checks;
   - nightly/merge/release: complete behavioral coverage, including the full mutation matrix and expensive live fixtures.
   Give arithmetic from the measured section times, not a guess.

## Deliverable

A concise report `docs/team/reports/P379-dev2.md` with:

- per-section action table: **keep / make conditional / remove duplicate work / parallelize**;
- exact files/commands behind each recommendation and the behavior that still covers it;
- what must NOT be removed and why (named incidents/contracts);
- estimated PR and full-run wall time, and the top three changes by measured savings;
- any recommendation that would reduce coverage must be marked explicitly as a trade-off, not presented as free.

No code or spec changes, no new guard framework, no full gate rerun. The PM will review this exploration before any proposal or implementation.

## PM review: report-only rework required (2026-10-27)

Review: `docs/team/reviews/P379.md` (REWORK REQUIRED). Preserve the delivered report and measurements, then append a revision that closes all four findings below. Do not change product, tests, specs, workflow or the CI schedule.

1. **Changed-path counterexample:** public run `40433391806` selected §61b into shard 3 even though it is outside the floor; that shard was still in §61b after 2341s and hit the 60-minute ceiling. A profile that leaves changed paths unchanged and budgets only 1–6 small additions is not a worst-case ≤30-minute push profile. Add a selection/cost matrix for docs-only, ordinary product, routing-fixture and selector-self-check changes, covering both floor and path-selected §61b/§36, and recompute the worst shard. Raw logs: `$HOME/.cache/release034/run-40433391806-job-121956221892.log` and `run-40433391806-job-121975547545.log`.
2. **Nightly arithmetic:** the report's 24 cheaper arms cost ≈2518s; across two jobs that is ≥1259s = 21.0 minutes, not 15. Show job count, green baseline/setup and wall time. If named-assertion filtering is assumed, distinguish that incidental-coverage trade-off from the current complete matrix and label any unmeasured saving as an estimate.
3. **Isolation:** distinguish separate GitHub runners from two same-host containers. `--pid=host` still shares `/proc`; temp roots alone do not make process-view, lock, fingerprint or shared-tree sections concurrent-safe. Correct the blanket statement that separate `--pid=host` containers are fine.
4. **Provisional numbers and real red:** keep §38/§63 projections provisional until one pinned-container composition measurement exists. The independently reproduced §63 `mouse` red needs a separate defect task and root cause; moving the leg to nightly is not a fix and no assertion may be weakened.

The PM's answers to the three questions are: cost-aware slicing is the leading later proposal but is not authorized yet; section splitting waits for the revised exploration and an OpenSpec proposal; the §63 red will be owned separately from this exploration. A second PM review is required before any proposal or apply brief.
