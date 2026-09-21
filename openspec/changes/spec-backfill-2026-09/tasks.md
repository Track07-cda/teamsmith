# spec-backfill-2026-09 · tasks (apply plan)

This change is a backfill: the behavior on the protected branch already exists, so every item below verifies the
delta against the named evidence (or corrects the delta). No item may change `scripts/**`, `tests/**`,
`extension/**` or `references/**`; a contradiction is a `BLOCKED:` report, not a fix.

## 1. Preconditions

- [ ] 1.1 Confirm the two MODIFIED panel requirements still match the base text at the branch tip:
  `grep -n '^### Requirement: The board page is a kanban' openspec/specs/panel/spec.md` and
  `grep -n '^### Requirement: The work page' openspec/specs/panel/spec.md`; diff the base bodies against the
  delta bodies — the only differences must be the focus/row-identity sentences and the added scenarios
  (`panel`)
- [ ] 1.2 Confirm the item-6 coverage revision: on this branch's base,
  `grep -n '^### Requirement' openspec/changes/watch-degradation/specs/notify-and-inbox/spec.md openspec/changes/watch-degradation/specs/watchdog/spec.md`; on main after its archive commit,
  `git show main:openspec/specs/notify-and-inbox/spec.md | grep -n '^### Requirement'` — either state must list
  the four degradation requirements, and `test ! -e openspec/changes/spec-backfill-2026-09/specs/notify-and-inbox`
  proves no duplicate delta is written (`notify-and-inbox`, `watchdog` stay untouched)

## 2. boundary — not written here (PM ruling, M70 → M71)

> **PM ruling (2026-09-21, M70 review · revision task M71)**: the three boundary requirements (1a/1b/1c) are
> removed from this change — they are owned by `tmux-gate-grant-redesign`, whose boundary delta carries three
> requirements / fourteen scenarios in the post-M67 target-decided model (the refusal, the log + no-grant
> contract, the fixture discipline) and is the updated, user-approved statement of the same rules; this is the
> same "do not write a second copy" treatment as item 6. M70's two BLOCKED findings (this delta still described
> the pre-M67 `TEAM_ALLOW_DESTRUCTIVE_TMUX` override model) are closed by the removal. The former items 2.1–2.5
> and their evidence (§31/§31c refusals, the §31c fake-isolation mutation, the log/injection checks, the
> container `--selftest`, the no-runtime SKIP) stay valid for that change; nothing from this section is this
> task's work.

## 3. verification — the conflict-marker guard

- [ ] 3.1 `TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null` → §0d green: clean tree green,
  tracked-worktree marker block red with `file:line`, index-only marker red, untracked/`.worktrees`/binary
  exclusions green (`verification`)
- [ ] 3.2 `bash skills/teamsmith/tests/flip-m44.sh` → exit 0 with all nine probes: the incident fixture red, the
  resolved fixture green, and the three mutations (never-match pattern, `--untracked`, no `--cached`) each red on
  the expected fixture (`verification`)

## 4. delivery-guard — the update banner

- [ ] 4.1 `TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null` → §12b-h0b green: the real captured
  frame (banner present) reads an empty box, the synthetic banner+draft frame reads the draft with
  `HOLDS_ONLY=yes`, both adversarial frames stay busy, and the no-banner control is unchanged (`delivery-guard`)
- [ ] 4.2 (real process) `M45_REQUIRE_BANNER=1 bash skills/teamsmith/tests/pm-box-real.sh --idle-secs 20` → the
  fixture prints `banner=present` on a frame pi really drew and `verdict=EMPTY` / `RETRACT=ok`; if no banner
  appears it fails instead of claiming the evidence — the check runs with the update check on (`delivery-guard`)
- [ ] 4.3 (real process) `TEAM_SMOKE_REAL_PI=1 bash skills/teamsmith/tests/smoke.sh </dev/null` → §12b-h ⑳ green:
  a banner over an empty box receives exactly one submit, a banner over a draft queues with zero submits, and the
  assertions confirm the banner really was in the inspected frame (`delivery-guard`)
- [ ] 4.4 `bash skills/teamsmith/tests/flip-m45.sh` → red (pre-fix tree reads the banner as content) → green
  (this tree) → mutation red, with the tree's own real-pane sends in each leg (`delivery-guard`)

## 5. board-and-status

- [ ] 5.1 `TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null` → §4c green: the duplicate refusal
  with status/title/two ways out and a byte-identical board, `--allow-dup` plus its audit line, the three readers
  naming `T1.1 ×2`, the negative controls, `board assign` changing only the agent column, unknown-id and
  missing-argument writes refused, and `board set` addressing both rows (`board-and-status`)
- [ ] 5.2 `bash skills/teamsmith/tests/flip-m48.sh add` and `bash skills/teamsmith/tests/flip-m48.sh assign` →
  each prints the mutant red on §4c and the real tree green (`board-and-status`)
- [ ] 5.3 `TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null` → §37 green: `board row` ≤ 1 git
  call from the root and from a subdirectory, `digest` ≤ 50 with a worktree-only report really listed, the
  cache-off run > 50 (non-vacuous fixture), and the cache on/off outputs identical for `digest`, `status` and
  `__panel-data` after filtering live fields (`board-and-status`)
- [ ] 5.4 Mutation check for 5.3 (no code edit; run once, restore): make `team_scan_cache_on` return 1 in a
  temporary copy of the skill tree and re-run §37's counting probe — the cached run must exceed the budget and
  §37 must go red, proving the budget assertion is live (`board-and-status`)

## 6. panel — row-identity focus

- [ ] 6.1 (real process: builds and drives the committed bundle) `bash skills/teamsmith/tests/panel-b3.sh board workdetail`
  → green, including the duplicate-id walk on both pages: one cursor at a time, the second same-id row reachable,
  the cursor not frozen, the focus kept across `r`, `enter`/`esc` and the work page's walk (`panel`)
- [ ] 6.2 (real process) `bash skills/teamsmith/tests/flip-m48.sh focus` → the bare-id mutant bundle turns the
  duplicate assertions red (10) and the committed bundle stays green (`panel`)

## 7. Acceptance, report, hand-off

- [ ] 7.1 Run the change's acceptance on the branch tip:
  `PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh </dev/null`
  → both exit 0, and `git status --porcelain` shows only the change's own files (`verification`,
  `delivery-guard`, `board-and-status`, `panel`)
- [ ] 7.2 Trial-archive the change on a copy (no repository change):
  `rm -rf /tmp/trial-M61 && cp -r openspec /tmp/trial-M61 && (cd /tmp/trial-M61 && PATH="$HOME/.bun/bin:$PATH" openspec archive -y spec-backfill-2026-09)` → exit 0, the four capabilities' specs in the copy carry the
  new requirements, and the two MODIFIED panel requirements replaced their base blocks with every base scenario
  retained
- [ ] 7.3 Write `docs/team/reports/M61-dev-bob.md` with the real command tails, the per-requirement
  evidence map, the item-6 coverage check and the `git status --porcelain` tail; commit every step with the task
  id and the `Agent: dev-bob` trailer (`verification`, `delivery-guard`, `board-and-status`, `panel`)
- [ ] 7.4 Hand the branch to the PM for a `verify` brief owned by a different agent; do not archive and do not
  merge (`verification`, `delivery-guard`, `board-and-status`, `panel`)
