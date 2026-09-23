# Tasks: `fixture-waits-for-landed-reads`

Planning only — nothing in this file is executed by the propose task (P62). **One apply brief** (three verifiable
batches, landed in order) plus **one independent verify brief** (a different agent). The change touches one
capability, `verification`, with two **ADDED** requirements: *A fixture observes a data-derived state before it
asserts it* and *A measuring fixture measures a fixed tree, not the caller's worktree*.

Coverage map (requirement → items): **verification#A fixture observes a data-derived state before it asserts it**
→ 1.1–1.4, 2.1–2.4, 4.1, 4.3, 4.4, 5.1; **verification#A measuring fixture measures a fixed tree, not the
caller's worktree** → 3.1–3.4, 4.2–4.4, 5.1. Every item names the capability it moves; no item is an orphan.

Both briefs carry the change's foreign key: `change: fixture-waits-for-landed-reads`, `deltas: verification`,
`phase: apply` (dev) and `phase: verify` (a different agent, never the implementer).

Batches: **B1** — the settings-view waits (`panel-p21.sh`, 1.x); **B2** — the collapse scene
(`panel-b3.sh`, 2.x); **B3** — the measurement target (`panel-cpu.sh` and its drivers, 3.x); **B4** — the gates
and the evidence (4.x). B1–B3 are independent of each other; B4 needs all three. 1.2 and 2.2 must land with their
scenario (an unbounded or un-attributed wait is a red in its own right).

Path grants the apply brief must state (OWNERSHIP): `skills/teamsmith/tests/**` is `agent:dev`'s, so
`panel-p21.sh`, `panel-b3.sh`, `panel-cpu.sh`, `panel-cpu-premise.sh`, `perf.sh` and `lib/pty-wait.sh` need no
PM grant. `skills/teamsmith/tests/smoke.sh` is the **gate file**: it is touched only if a FAST-able pin is added,
and then only with the brief's explicit grant. `skills/teamsmith/scripts/**` (the console sources) is **not**
touched — D43 keeps the product side as it is — and `openspec/**` stays with the phase's owner,
`docs/team/**` with the PM.

Fixture notes (unchanged rules): every fixture clears inherited team identity first, keeps its private tmux
server and its `BASHPID`-guarded cleanup, and creates its roots through `tests/lib/tmp-root.sh`; no call may
reach the default tmux server; injection knobs are honoured **only** under `TEAM_SMOKE_FIXTURE=1` and are printed
as ignored otherwise; the gate runs with stdin on `/dev/null`. Items marked **[real process]** need a pane and are
never the only evidence for a requirement.

Documented residual (design §6, not fixed here): a read that lands **after** the cap is not observed — the run
takes the premise decision (failure on a static scene under the premise, visible `SKIP` over it) and must name
the wait it exhausted. The items below must **not** turn that case into a pass, and must not widen any cap
merely to hide it.

## 1. B1 — the settings-view waits (`panel-p21.sh`, `verification` ADDED)

- [x] 1.1 The hand-edited-value scenario (the `TEAM_NOTIFY_TMUX=true` family) waits for the **derived state** —
  the settings row carrying the hand-edited value on a settled frame — before Enter opens the picker; the
  picker's entry is then asserted as today. The group heading and the unconditional `sleep 0.5` stop being the
  evidence. Verify: recipe A of design §3 D2 (a scratch copy whose CLI wrapper sleeps 6 s before
  `__panel-data --block settings`) is **green** on the changed fixture, while the same scratch on the pre-change
  fixture is red with `非规范拼写的手改值原样显示成当前条目` unmet — both tails in the report **[real process]**.
- [x] 1.2 The new wait is counted and attributed: it reuses the pty engine's rounds/cap/attribution (or the same
  discipline where the engine does not fit), prints one line naming the wait and the state it waited for at its
  cap, and leaves the cap and the measured read-latency band it came from in the fixture's header. Verify:
  `bash skills/teamsmith/tests/panel-p21.sh choices` is green with its counts; an over-cap delay prints the
  attribution line and does not exit 0; grepping the fixture's header finds the cap next to the band it was
  derived from **[real process]**.
- [x] 1.3 The census inside this file: every `sleep N` in the settings scenarios that is followed by a single
  sample is classified as input rhythm (kept) or evidence (converted to a bounded wait), with the reasoning; the
  table goes in the report. Verify: the table lists file:line, classification and (for evidence waits) the
  replacing wait; re-grepping those lines in the changed file finds no evidence-shaped one left.
- [x] 1.4 No performance judgement enters the fixture: the wait's bound is a liveness cap with the band of 1.2,
  no assertion compares an elapsed time or a CPU share to a threshold, and a read that lands slowly inside the
  bound stays green. Verify: `TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null` and
  `bash skills/teamsmith/tests/gate-guard.sh` green, plus the injection of 1.1 at a delay inside the band.

## 2. B2 — the collapse scene (`panel-b3.sh`, `verification` ADDED)

- [x] 2.1 `scn_collapse` waits for the console's own title (`teamsmith pulse`) on a settled frame, by polling
  inside a bound, before it captures `console.txt`; the `sleep 5` + single sample goes. The same for the restore
  capture behind `sleep 6`. Verify: the scratch delayed bundle of design §3 D2 recipe B (`TEAM_B3_PANEL=<slow
  first paint>`) reds the pre-change scene with `pulse 窗口里是控制台` / `恢复后同一窗口里又是控制台` and passes
  the changed one; both tails in the report **[real process]**.
- [x] 2.2 The scene's other evidence waits follow the same rule: the `pulse up` log naming the window, the
  `pulse status`/`up2` lines, and `capacity.log`'s row count having grown are observed by bounded conditions
  (rounds + cap + one attribution line) instead of `sleep`-then-sample. The waited-for state is what is
  asserted, not a proxy. Verify: `bash skills/teamsmith/tests/panel-b3.sh collapse` green; a title that never
  appears prints the attribution line and does not report the scenario green **[real process]**.
- [x] 2.3 With the fixture not sourcing `tests/lib/pty-wait.sh` today, the chosen wait carries the same
  discipline (counted rounds, a cap, one attribution line naming the waited-for state) with
  `tests/lib/pty-wait.sh` as the model (the `gate-section-accounting` loop inventory is not part of this
  change: it is not merged, and no name of it is referenced from the delta). Verify: `bash
  skills/teamsmith/tests/gate-guard.sh` and the FAST gate green, and the new wait's rounds/cap are readable at
  its one call site.
- [x] 2.4 The census of 1.3 covers this file too (the fixed delays in this scene included), with the same
  report table. Verify: as 1.3.

## 3. B3 — the measurement target (`panel-cpu.sh`, `verification` ADDED)

- [x] 3.1 `panel-cpu.sh` measures a **fixed neutral project** it creates through `tests/lib/tmp-root.sh` instead
  of the caller's worktree, while the console bundle and the CLI stay the tree under test; the output names the
  measured project root and the bundle it ran. Verify: the two-worktree run of 3.3 prints the same measured root
  from both and prints the bundle path **[real process]**.
- [x] 3.2 The drivers keep working against the fixed root: `panel-cpu-premise.sh`'s four expected exit codes and
  the performance suite's invocation of it (`perf.sh --tree` keeps naming the code under test, never the measured
  project) are unchanged, and the suite's environment self-description still names the revision under test.
  Verify: `bash skills/teamsmith/tests/panel-cpu-premise.sh` green with its four cases; `grep -n 'panel_fixture\|
  --tree' skills/teamsmith/tests/perf.sh` shows the invocation still passing the tree under test; the suite's own
  cheap judgment list runs **[real process]**.
- [x] 3.3 The flip measured: `panel-cpu.sh` (default arguments) from this worktree and from a fresh project name
  the **same** measured root and reach the **same** conclusion, where the pre-change shape measured 3683 ms
  against 391 ms and reddened one of them (P52 F4). Verify: both runs' verdict lines with their roots and
  numbers in the report **[real process]**.
- [x] 3.4 No threshold moves (it keeps the two-worktree verdict identical rather than moving it): the 2000 ms
  first-frame budget, the 1 % pane-CPU line, the 0.25 premise factor and the median rules are untouched, and the
  fixture keeps its exit codes (0/2/3/4). Verify: `git diff` on
  `panel-cpu.sh` shows only the target/print change; the premise fixture's expected codes are as in 3.2.

## 4. B4 — gates and evidence

- [x] 4.1 `PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict`, `TEAM_SMOKE_FAST=1 bash
  skills/teamsmith/tests/smoke.sh </dev/null`, then the **full** gate once — paste the tails; `git status
  --porcelain` clean.
- [x] 4.2 Trial archive on a scratch copy:
  `rm -rf /tmp/p62-trial && mkdir -p /tmp/p62-trial && cp -r openspec /tmp/p62-trial/openspec && (cd
  /tmp/p62-trial && openspec archive -y fixture-waits-for-landed-reads)` — prove the two ADDED requirements
  collide with no base requirement and with no open change's delta, and that `openspec validate --all --strict`
  still passes afterwards (design §3 D4). Note: the copy must land in a directory **named** `openspec` — the CLI
  resolves the nearest ancestor containing `openspec/`, so the shorter form in `references/openspec.md` §5
  (`cp -r openspec /tmp/trial`) only works when `/tmp/trial` already exists (measured in this task; the doc row
  is PM-owned and is reported, not changed).
- [x] 4.3 The report's evidence: the requirement→item map, the scenario→item→evidence map, the census table
  (1.3/2.4), the three injection recipes with their raw tails (pre-change red / post-change green), the
  never-lands attribution tail, and the two-worktree measurement.
- [x] 4.4 The `2-CPU` shape recorded by P52 as the trigger (`✓ 108 ✗ 3`, five of five) is re-checked on the
  changed fixture if the pinned gate image is available locally; otherwise the report says plainly that it was
  not re-run and cites the local delay injection instead (never a claim without the run).

## 5. V — independent verification (a different agent)

- [ ] 5.1 Rerun, out of tree and on the apply's tip: recipes A, B and C of design §3 D2, `openspec validate --all
  --strict` and the full gate; exercise every scenario of the delta with red/green evidence and record it in
  `docs/team/reviews/<ID>.md`. A PASS that still carries findings is rework (`DECISIONS.md`: the PASS is the
  execution's conclusion, the findings are the content's).
