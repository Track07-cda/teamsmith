# Tasks: `dispatch-verify-seat-guard`

Planning only — the propose task (P38) executes none of this. One apply brief implements both deltas: the seat
boundary and its enforcement are one decision, and a half-applied change leaves either an unenforced rule or a
refusal with no stated boundary. Order: the readers, then the guard, then the config surface, then the fixtures,
then the documents, then the gates and the report.

Coverage map (requirement → items): **dispatch R1** (`A verification seat is never dispatched implementation
work`) → 1.1–1.4, 2.1–2.5, 3.1–3.3, 4.1–4.3; **verification R1** (`The verification seat does not implement`) →
1.1, 1.3, 1.4, 2.2–2.3, 3.3, 4.1–4.3. The documentation obligations the proposal names (`protocol.md` §5b, the
AGENTS/PROTOCOL paragraphs, the template's `grant:` line) → 2.5, 3.1–3.3; item 1.4 carries the same premise into a
new project's rendered contract. Every scenario of both deltas is exercised by 2.1–2.3 and by the gate items
4.1–4.2. Reverse coverage: 2.4 proves the fixtures can fail (guard broken → red), 2.5 that the guard-enumerating
docs cannot go stale.

Path grants the apply brief must state (OWNERSHIP): `skills/teamsmith/scripts/**`, `skills/teamsmith/references/**`,
`skills/teamsmith/templates/**`, `AGENTS.md` and `docs/team/OWNERSHIP.md` are **PM-owned** and need the brief's
explicit grant; `skills/teamsmith/tests/**` belongs to `agent:dev`. The apply brief must not touch
`.pi/team/config.sh` of this project, `skills/teamsmith/SKILL.md`, `team review`, the four existing guards'
semantics, or another change's delta files.

Fixture note: every fixture reuses the smoke suite's P24 family (`p24_project`, `p24_brief`, `p24_team`,
`p24_read`, `p24_dispatch` with the record-only tmux shim, `p24_shim_windows`, `p24_unchanged`) and extends the
brief builder with a `grant:` parameter (today it writes no `grant:` line). "No window" is asserted by the shim log
staying empty, "board unchanged" by the row, and every fixture works only inside its scratch project (identity
variables cleared as the P24 family already does). The guard is pure logic, so the new section runs in fast and
slow mode alike; the `--force` audit item needs the dispatch flow with the shim.

## 1. Readers and the guard (dispatch, verification)

- [ ] 1.1 `skills/teamsmith/scripts/lib/common.sh`: resolve the verification seat (`TEAM_VERIFY_SEAT`, default
  `verify`, unset or empty → `verify`; the schema row arrives in 1.3) and add
  `team_task_grant_impl_paths <brief>` — read every `grant:` line with `team_brief_field_raw`, split entries on
  `·` and whitespace, and print one line per entry that is an implementation path, i.e. **not** `docs/team`,
  `openspec`, or under `docs/team/` or `openspec/`. `-`, an empty value and an absent line print nothing and exit 0.
  Verify: a headless reader fixture (in the family of `tests/task-header-model.sh`) drives skill-relative and
  repo-relative entries, the two allowed trees, `-` and the absent line, and exits 0 naming any failing case.
- [ ] 1.2 `skills/teamsmith/scripts/lib/cmd-agents.sh`: add `team_dispatch_seat_guard <agent> <ID> <brief> <force>`
  and call it next to `team_dispatch_change_guard` before the worktree/branch actions and before any window. It
  refuses only when `agent` is the resolved verification seat **and** (`phase:` is `apply`, or the phase is
  undeclared and 1.1 returns at least one implementation entry). The refusal prints the seat, the signal (the
  `apply` phase, or "the phase was undeclared and these `grant:` entries are implementation paths" with the
  entries), the `docs/team/OWNERSHIP.md` verification row and both ways out (another seat; keep the seat and make
  the task `phase: verify`); `--force` prints the override warning and appends exactly one line to
  `TEAM_DISPATCH_AUDIT_LINES` naming the task, the seat and the signal. `--print` passes through the guard and
  writes no state; a refusal writes nothing and does not touch the board. Verify: 2.1–2.3.
- [ ] 1.3 `skills/teamsmith/scripts/lib/cmd-config.sh` + `skills/teamsmith/references/config.md`: one schema row for
  `TEAM_VERIFY_SEAT` (class `apply`, kind `text`, default `verify`, section `roster`, route text naming the seat
  guard) and its documentation row. Verify: `team config list --json` in a fixture project reports the key with
  class `apply` and default `verify`; `team config set TEAM_VERIFY_SEAT checker --yes` exits 0 and the next
  dispatch applies the guard to `checker` (fixture config restored afterwards).
- [ ] 1.4 `skills/teamsmith/templates/config.sh.tmpl`: the roster block declares `TEAM_VERIFY_SEAT="verify"` with a
  one-line comment naming the guard, so a freshly initialised project carries the premise. Verify: a fixture
  project's rendered `.pi/team/config.sh` contains the key and the rendered `team doctor`/`team config` reads it.

## 2. Fixtures (`skills/teamsmith/tests/smoke.sh`, new section `12l · verify 席位守卫（P38/D36）`)

- [ ] 2.1 Refusal shapes (`dispatch` R1, scenarios 1–3): `phase: apply` with `agent: verify`; an undeclared phase
  with skill-relative and repo-relative implementation grants; the same brief under `--print`. Each asserts a
  non-zero exit, the `docs/team/OWNERSHIP.md` path, both ways out, the implementation entries named, no window
  (`p24_shim_windows` = 0) and the board row unchanged (`p24_unchanged`).
- [ ] 2.2 Allow shapes (`dispatch` R1 scenarios 4–5; `verification` R1 scenarios 2–3): `phase: verify` with a
  ledger grant; an undeclared phase with a ledger-only grant; an undeclared phase with no `grant:` line; a
  non-verify seat with an `apply` brief; a `TEAM_VERIFY_SEAT=checker` fixture (roster `dev checker verify`) where
  `checker` is refused and `verify` proceeds; the default-seat case (`verify` refused with the fixture config's
  `verify` value, and with a blank `TEAM_VERIFY_SEAT=` env entry, which the loader's env-over-config rule lets win).
  Allow cases assert the record-only shim's exact `new-window` call.
- [ ] 2.3 `--force` audit (`dispatch` R1 scenario 6): a fixture dispatch with `--force` proceeds with the warning
  and `grep -c` on the new line in `state/watchdog.log` equals 1 (naming task and seat); `--print --force` writes
  no line and changes no state.
- [ ] 2.4 Red side, in the report: neuter the guard (drop the `team_dispatch_seat_guard` call, or its
  `phase: apply` check) → 2.1's apply case goes red (a window is requested where none is expected) while 2.2's
  verify-phase case stays green; restore → whole section green. Paste both tails.
- [ ] 2.5 Template/docs invariants: extend 12k's field loop to `grant:`; assert the repo `AGENTS.md` paragraph and
  `skills/teamsmith/templates/AGENTS.section.md.tmpl`'s stay byte-identical (the existing 7.4 check) while both list
  the fifth refusal and "the last four" overrides.

## 3. Documents (dispatch, verification)

- [ ] 3.1 `skills/teamsmith/references/protocol.md` §5b: the heading says **five** dispatch guards and rule 5
  states the seat condition, the phase rule, the conservative `grant:` classification, the message contents and the
  `--print`/`--force` handling; the cross-reference to `references/philosophy.md` / D36 motivates it.
- [ ] 3.2 `skills/teamsmith/templates/task.md.tmpl`: the `grant:` header line with an inline comment (the fields
  the guards read); `templates/AGENTS.section.md.tmpl`, `templates/PROTOCOL.md.tmpl` and the repo `AGENTS.md`
  paragraph gain the fifth refusal and the unchanged rule that the change-id guard has no override.
- [ ] 3.3 `docs/team/OWNERSHIP.md`: the verification seat row states the boundary ("does not implement, whatever
  the brief says") and points at the guard (`team dispatch` refuses; `references/protocol.md` §5b). PM-owned — the
  apply brief must grant it, or the PM writes this sentence itself.

## 4. Gates and report

- [ ] 4.1 `PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict` green with the implementation on disk,
  and the delta set proven archive-able in a throwaway copy:
  `cp -r openspec /tmp/dvsg-trial && (cd /tmp/dvsg-trial && PATH="$HOME/.bun/bin:$PATH" openspec archive -y dispatch-verify-seat-guard)`
  merges both capabilities without an error (an ADDED-only delta must not touch the pending
  `change-centric-discipline`).
- [ ] 4.2 `TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null` in batch, then the full gate
  `PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh </dev/null`
  once before delivery; report the section 12l result line and the total `✓/✗`.
- [ ] 4.3 `docs/team/reports/<apply task>.md`: both acceptance tails; the delta→requirement and
  requirement→item/scenario maps; the flip tails of 2.4–2.5; the fixture census (refuse / allow / force); the
  config spot-checks of 1.3–1.4; and the paths the diff touched.
