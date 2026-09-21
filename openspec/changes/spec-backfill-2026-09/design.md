# spec-backfill-2026-09 · design

## Context

The user approved **spec policy B** (2026-09-20): a cross-task rule — silent failure, destructive action,
authority, identity, gate, performance contract — must hold as a requirement with a scenario. Six rules landed in
the last week (M28/M36/M41 tmux isolation, M44 conflict markers, M45 update banner, M48 duplicate ids, M50 read
budget, M53/M56 watch degradation) but only in tests, fixtures and `references/`; `openspec/specs/` has no home
for them, so the tests became the only source of truth. See `proposal.md` for the motivation.

This is a **backfill**: every requirement states behavior that already exists on the protected branch. The only
artifact this change produces is the delta set; `apply` is a verification pass over the cited evidence, and
`archive` merges the deltas into `openspec/specs/`.

Constraints that shape the artifacts:

- `openspec validate --all --strict` checks the delta syntax, not its relationship to the base spec; a MODIFIED
  delta naming a requirement the base lacks, or an ADDED collision, only surfaces at the **trial archive**
  (`references/openspec.md` §5). MODIFIED therefore copies the base requirement in full and keeps every base
  scenario.
- Two other changes were pending when the brief was written: `watch-degradation` (adds to `notify-and-inbox`,
  `watchdog`, `panel`) and `perf-suite-split` (modifies `verification`, `panel`). Main archived
  `watch-degradation` while this task ran (`829dc19 docs(openspec): archive watch-degradation and
  inbox-spool-resilience`); its requirements are now land specs. This change's deltas must not overlap either
  change's deltas or those specs.
- The evidence layer is the test suite: each scenario below names the section/fixture that can fail today.

## Goals / Non-Goals

**Goals:**

- Give each of the six audited rules one falsifiable home, anchored to named evidence: rules 2–5 here (D1
  below), rule 6 in the archived `watch-degradation`, and rule 1 in `tmux-gate-grant-redesign` (moved out by
  M70/M71).
- Keep the set small: 7 requirements and 20 new scenarios — down from 10/32 by the 3 requirements and 12 scenarios
  the M70/M71 boundary removal took out; the brief's 6–10 requirement bound still holds.
- Keep item 6 out of this change: `watch-degradation` already owns it.
- Correct the one base statement that is now wrong (panel focus by bare entry id) via MODIFIED.

**Non-Goals:**

- No code, test, extension or reference change; no behavior change of any kind.
- No new capability (hard requirement 4) and no `## REMOVED` requirement.
- No restatement of the watch-degradation requirements (the brief's item 6 note) or of the tmux runtime gate
  (`tmux-gate-grant-redesign`, M70/M71).
- Not deciding M48's open product question (`board set`/`board assign` by row instead of by id); the delta states
  today's id-addressing contract.

## Decisions

### D1 — Homes: four delta files, no new capability

| Rule (brief) | Delta file | Requirements |
|---|---|---|
| 2 conflict-marker guard | `verification` | 1 added |
| 3 update-banner tolerance | `delivery-guard` | 1 added |
| 4 duplicate ids | `board-and-status` (2 added) + `panel` (2 modified) | see D3 |
| 5 read budget | `board-and-status` | 1 added |
| 6 watch degradation | **none** | covered by `watch-degradation` — see D2 |

Rule 1 (the tmux isolation gate) is not written here: its home is `tmux-gate-grant-redesign`, whose boundary
delta carries three requirements and fourteen scenarios in the post-M67 target-decided model (the refusal itself,
the log + no-grant contract, and the fixture discipline that also covers the container rule) — the same "do not
write a second copy" treatment as item 6, per the M70 ruling (revision M71). This change's former rows 1a/1b/1c
are removed from the evidence map; their evidence stays valid for that change. Verification already owns the gate
contract (a review runs `$TEAM_GATES`); a marker check that turns the gate red belongs there. The read budget is
about `board row`/`digest`/`status` and their cache, so `board-and-status` is its home. **Alternative considered
and rejected:** a new `read-path` capability for item 5 — it would create a capability for a single requirement,
contradict hard requirement 4, and split one contract (the ledger read) across two specs while `perf-suite-split`
is already touching the gate side of it.

### D2 — Item 6 is already covered: no `notify-and-inbox` delta (brief's `deltas:` line differs)

The brief's `deltas:` line lists `notify-and-inbox`, but the brief's own item 6 says: check first, and "if already
covered, do not write it again". It is covered, in the pending change:

- `openspec/changes/watch-degradation/specs/notify-and-inbox/spec.md#A watcher registration failure is recorded
  with its cause` (line 3) — durable `<key>.degraded` record + ledger line with `errno`, `watches=<used>/<max>`,
  `poll_ms`, `forced`.
- `…#Delivery continues on the polling fallback while watching is unavailable` (line 53) — one wake within the
  poll cadence and the unchanged wake shape (`team-inbox`, `triggerTurn`, `deliverAs: followUp`).
- `…#The inbox-watch gate measures an unavailable watcher visibly and has a strict path` (line 77) — visible
  `TEAM-IW-CASE SKIP …`, strict mode red; no assertion weakened.
- `openspec/changes/watch-degradation/specs/watchdog/spec.md#A live degraded channel is reported by team doctor
  and team status` (line 3) and `#team doctor reports the inotify headroom of the wake channel` (line 35) — only a
  live record counts, quota and `524288` remedy named.

Writing ADDED requirements for any of these would collide with `watch-degradation` at archive time (two changes
adding the same requirement); writing a pointer requirement would promise nothing new. So **this change writes
four delta files, not six**, and the report records the finding with the check above as its evidence.

Main has since archived that change (`829dc19`, `docs(openspec): archive watch-degradation and
inbox-spool-resilience`), so on main the same four requirements are land specs: `openspec/specs/notify-and-inbox`
(the failure record at line 124, the polling fallback at line 176, the visible-skip/strict harness at line 198)
and `openspec/specs/watchdog` (the live-degraded reporting and the inotify headroom). Verified read-only with
`git show main:openspec/specs/notify-and-inbox/spec.md` — the archive does not change this change's
verdict, and M61 still adds nothing there.

### D3 — The panel requirements are MODIFIED, and only their focus sentence changes

The base `panel#The board page is a kanban over the board's states` says the focus "SHALL be tracked by entry id".
After M48 that sentence is wrong where ids repeat: two rows with one id both highlighted and the cursor froze —
the user-reported defect. M48's report explicitly asks the PM for the spec follow-up
(`docs/team/reports/M48-dev3.md` lines 212–216: "焦点是行身份 `(lane, id, nth)`"). The correct treatment is
MODIFIED (review checklist 7: a supersession must not become a parallel statement): the board-page requirement's
tracking sentence becomes row identity and one scenario is added; the work-page requirement's "report the row ids"
becomes "the drawn rows (id plus occurrence)" plus one scenario. **Every base scenario of both requirements is
copied verbatim** (5 + 4). Alternative considered: an ADDED requirement in `board-and-status` "the panel focuses
by row identity" — rejected because the wrong sentence would stay in the panel spec, and because the promise is a
panel behavior, not a ledger one.

### D4 — Requirements pin only what is already a closed token

The scenarios use the values the tool already defines and the suite already asserts: `EMPTY` / `HOLDS_ONLY=yes` /
`RETRACT=ok` / `banner=present|absent`; `BOARD 重复 ID` and `×N`; `--allow-dup`; `board assign`;
`TEAM_SCAN_CACHE=0`; ≤1 and ≤50 git calls. No message is quoted verbatim beyond the tokens the suite greps, so the
spec does not freeze implementation prose.

### D5 — The read budget is a call count, not a wall-clock threshold

The requirement states the counting fixture and the counts, and says so; it deliberately does not add a time
budget, consistent with the correctness/performance split (`perf-suite-split` keeps §37's call counts in the
correctness gate exactly because they are time-independent).

### D6 — The banner tolerance is ADDED, not MODIFIED

`delivery-guard#An automated send never types into a non-empty input box` is the longest requirement in the
library; the banner promise is a new, self-contained judgement of the same box reader. ADDED keeps the base
requirement untouched and keeps the "must not disable pi's update check" promise in one place.

## Evidence map (rule → requirement → evidence → review method)

| # | Requirement | Evidence (file:line, protected branch) | Independent review method |
|---|---|---|---|
| 2 | `verification#The gate refuses tracked files that still hold conflict markers` | `smoke.sh` §0d L561–664 (guard + positive/negative fixtures + index-side case + exclusions) | FAST smoke → §0d green; `bash skills/teamsmith/tests/flip-m44.sh` → all nine expected probes hold (incident red, resolved green, three mutations red) |
| 3 | `delivery-guard#The input-box verdict tolerates pi's update banner` | `tests/frames/pi-0.85.1-update-banner.txt`; `scripts/lib/outbox.sh` L75–76, L126–151, L184–215, L273; `smoke.sh` §12b-h0b L5619–5715 (real frame, synthetic frames, two adversarial frames, control), §12b-h ⑳ L6088–6110 (real pane: empty box delivers once, drafted box queues with zero submits); `tests/pm-box-real.sh` L16–19, L89–105 (banner reported, update check on), L190–196 (`HOLDS_ONLY`/`RETRACT`) | FAST smoke → §12b-h0b green; non-FAST `TEAM_SMOKE_REAL_PI=1 bash skills/teamsmith/tests/smoke.sh </dev/null` → §12b-h ⑳ and the real-pi fixture; `M45_REQUIRE_BANNER=1 bash skills/teamsmith/tests/pm-box-real.sh --idle-secs 20` for a frame that really holds the banner; `bash skills/teamsmith/tests/flip-m45.sh` for red→green→mutation |
| 4a | `board-and-status#A duplicate board id is refused by default and visible wherever the board is read` | `smoke.sh` §4c L1030–1110 (refusal/no-write, `--allow-dup` + audit, ls/digest/doctor visibility, negative controls, placeholder exclusion); `scripts/lib/common.sh` L2927–2960, L3701–3760; `scripts/lib/cmd-docs.sh` L47–66; `scripts/lib/cmd-project.sh` L325–331 | FAST smoke → §4c green; `bash skills/teamsmith/tests/flip-m48.sh add` → the copy without the check turns §4c red, the real tree green |
| 4b | `board-and-status#The board addresses rows by id, and the agent column has its own entry` | `smoke.sh` §4c (assign only agent column, row count unchanged, unknown id/missing arg no write, set addresses both rows); `common.sh` L3660–3700; `cmd-docs.sh` L67–71 | FAST smoke → §4c green; `bash skills/teamsmith/tests/flip-m48.sh assign` → the "assign = add another row" copy turns §4c red |
| 4c | `panel#The board page is a kanban over the board's states` (MODIFIED) | `tests/panel-b3.sh` L163 (`focused_row`, `AMBIGUOUS-CURSOR`), L698–745 (duplicate board walk, refresh, detail, return); `scripts/panel/src/{layout.ts L698–716, L744, L771–780, App.tsx L755, L766–782, L814, L844, L1230, L1802, types.ts L466–474}` | `bash skills/teamsmith/tests/panel-b3.sh board` → green on the committed bundle; `bash skills/teamsmith/tests/flip-m48.sh focus` → the bare-id copy rebuilds the bundle and turns 10 duplicate assertions red |
| 4d | `panel#The work page's board rows are focusable and open the same detail view` (MODIFIED) | `panel-b3.sh` L746–762 (work-page duplicate walk) | `bash skills/teamsmith/tests/panel-b3.sh workdetail` → green; `flip-m48.sh focus` covers the same walk |
| 5 | `board-and-status#The ledger read path stays inside a git-call budget and its cache is an equivalence-checked view` | `smoke.sh` §37 L11426–11563 (L11515 `board row ≤1`, L11520 subdir, L11523 cache-off row equality, L11528 `digest ≤50`, L11540 cache-off >50, L11544/L11553/L11561 output equality); `common.sh` L74–77 (`TEAM_SCAN_CACHE=0` = direct implementation); `cmd-status.sh` L216–226 | FAST smoke → §37 green; mutation: make `team_scan_cache_on` return false unconditionally → the cached run's count rises past the budget → §37 red |
| 6 | **none — covered by `watch-degradation`** | on this branch's base: `openspec/changes/watch-degradation/specs/notify-and-inbox/spec.md` lines 3, 53, 77 and `.../watchdog/spec.md` lines 3, 35; on main after the archive commit: `openspec/specs/notify-and-inbox/spec.md` lines 124, 176, 198 and `openspec/specs/watchdog/spec.md`; fixture evidence `smoke.sh` §12b-pi3 L6552, §12b-pi2 L6433; `docs/team/reviews/M56.md` | `grep -n '^### Requirement' openspec/changes/watch-degradation/specs/notify-and-inbox/spec.md openspec/changes/watch-degradation/specs/watchdog/spec.md` (branch base) and `git show main:openspec/specs/notify-and-inbox/spec.md | grep -n '^### Requirement'` (main) → the four claims are each a requirement with scenarios; confirm this change has no `specs/notify-and-inbox/` file |

Requirement-to-tasks coverage and scenario-to-fixture mapping live in `tasks.md` and in the apply report.

## Risks / Trade-offs

- **The item 6 cross-reference depends on another change** → `watch-degradation` is archived on main while this
  branch's base still carries its delta files. Mitigation: this change promises nothing about it and touches no
  file under its delta set or its land specs; the report records the revision it checked in both states.
- **MODIFIED against a moving base** → another pending change could touch the two panel requirements before
  archive. Mitigation: `perf-suite-split` modifies `panel#Frame assembly is asynchronous…`, a different
  requirement; the trial archive catches any mismatch, and a task item re-reads the base text at the branch tip.
- **Over-specification** → a scenario could freeze an implementation detail (a message string, a file layout).
  Mitigation: D4 — only closed tokens and exit codes are pinned; prose is allowed to change.
- **Environment-dependent evidence** (banner) → a green could come from an empty run. Mitigation: the requirement
  makes the fixture report `present|absent` and fail when asked to require a banner that is absent.
- **Scope creep into the archive** → the four deltas merge into four existing specs. Mitigation: ADDED only, no
  REMOVED; archive only after independent verification and the user's confirmation.

## Migration Plan

1. **apply** (dev): verify each row of the evidence map on the branch tip; where the code contradicts a
   requirement, do not "fix" the code — write `BLOCKED:` in the report and hand it to the PM. The only edits
   allowed in apply are corrections to the delta text itself.
2. **verify** (different agent): re-run the named sections and the flip packages on an independent checkout; every
   scenario must be exercised or explicitly marked as not exercisable (with the reason).
3. **archive** (PM): trial-archive first (`cp -r openspec /tmp/trial && (cd /tmp/trial && openspec archive -y
   spec-backfill-2026-09)`) to let OpenSpec check MODIFIED/ADDED against the base; then archive for real after the
   user's confirmation. No collision with the other changes: `watch-degradation` is already archived (its ADDED
   requirements are land specs, none of which M61 adds), and M61's ADDED set shares no requirement with
   `perf-suite-split` (which touches `verification`'s gate split and `panel`'s frame requirement, not the ones
  here). Rule 1 now has exactly one pending statement — `tmux-gate-grant-redesign`'s — because this change no
  longer carries a boundary delta (M70/M71).

## Open Questions

None. M48's product question (row-addressable `board set`/`board assign`) is explicitly out of scope; the delta
states the current id-addressing semantics, and changing them would be its own change.
