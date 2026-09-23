# Tasks: `change-centric-discipline`

Eight apply batches, dispatched and verified one by one, in this order: **B1** the strict header reader, the change
read-model and `team change status` (board-and-status: "`team change status <id>` reports a change's readiness"),
**B2** the digest section and the panel's task tokens (board-and-status: "A change's tasks are grouped in the digest
and the panel"), **B3** rules 1 and B in `dispatch` (dispatch: "A brief names at most one change id" + "A
change-less brief declares its spec anchor"), **B4** the delta single writer (dispatch: "Two unfinished tasks of one
change do not write the same delta file"), **B5** no self-verification per change (verification: "The verifier of a
change is not one of its authors"), **B6** the archive precondition (board-and-status: "An archive waits for every
task of the change"), **B7** the template and the documents (the fields and the checklist the requirements name),
**B8** the gates and the evidence. The read-only batches come first on purpose: B1's read-model is what B3–B6's
guards call, and its refusal messages are what the guards reuse.

Coverage map (requirement → items): change status → 1.1–1.6; grouping → 2.1–2.4; one change id → 3.1, 3.2, 3.5, 3.7;
anchor → 3.3, 3.4, 3.5, 3.7; delta single writer → 4.1–4.6; verifier independence → 5.1–5.5; archive readiness →
6.1–6.4; the header fields and the PM checklist the requirements read → 7.1–7.5; every requirement is also
exercised by the final gate item 8.1 and by the flip package 8.2.

Path grants an apply brief must state (OWNERSHIP): `skills/teamsmith/scripts/**` (the CLI, the libs, the panel's
committed bundle), `skills/teamsmith/references/**`, `skills/teamsmith/templates/**`, `skills/teamsmith/SKILL.md`
and `AGENTS.md` are **PM-owned** and must be granted explicitly; `skills/teamsmith/tests/**` belongs to `agent:dev`;
`openspec/changes/change-centric-discipline/**` belongs to the phase's owner; `openspec/specs/**`, `docs/team/**`
and the ledger stay PM-owned. `[real]` items need a real tmux window or pty; each has a headless sibling, and a real
run is never the only evidence for a requirement.

Fixture note: every guard batch builds its fixture the same way — a scratch project (`team init`, one fixture
`BOARD.md`, fixture briefs under `docs/team/tasks/`) plus the **record-only tmux shim** the smoke suite already uses
(`smoke.sh:869`, `smoke.sh:1102`): a `tmux` on a private `PATH` that appends its argv to a log and exits 0. "No
window was opened" is asserted by that log staying empty (or, for the allow cases, by the exact `new-window` call
appearing once). Every refusal assertion also asserts that the board row is unchanged.

## 1. B1 — the strict header reader, the change read-model, `team change status` (board-and-status, ADDED)

- [ ] 1.1 `scripts/lib/common.sh`: `team_brief_field_raw` (all matching lines, comments stripped) plus strict readers
  `team_task_change_value` (one token or `-`, else a non-zero exit with the offending line), `team_task_deltas`
  (`-` | a comma list of capability tokens | *unknown* when the line is absent) and `team_task_anchor` (the
  `anchor:`/`specs:` pair with the accepted-form check and the capability/requirement resolution described in
  design §1/§3). Existing callers (`team_task_change`, `team_task_phase`) keep their current output for valid
  briefs — the whole smoke suite is the regression net. Verify: a new fixture
  `skills/teamsmith/tests/task-header-model.mjs` (or a shell sibling in the family of the existing header fixtures)
  drives the readers over the accepted and malformed values and exits 0, naming the failing case.
- [ ] 1.2 `scripts/lib/common.sh`: `team_change_tasks <id>` — **one pass** over `docs/team/tasks/*.md` (a single
  `awk`, no per-file subprocess) producing `id  phase  agent  brief-path` rows for the briefs whose strict
  `change:` value equals the id; and `team_change_finished <id>` / `team_change_ready <id>` on top of
  `team_task_open_reason` (design §6). Verify: the same fixture asserts the row set for a fixture project with
  three briefs mapped to `alpha`, one mapped to `beta`, and one change-less; and that the scan spawns no `team`
  child (a `PATH` wrapper counts invocations → 0).
- [ ] 1.3 `scripts/lib/cmd-status.sh`: `team_cmd_change` + the `change` verb in `scripts/team` (dispatch + help
  line) — the human listing of design §7 (tasks with phase/agent/board/evidence, the delta files with declared and
  touched owners, the blockers, the readiness line), exit 0/1 per readiness, `--json` with
  `id`/`ready`/`tasks`/`deltas`/`blockers`. The "touched" column uses one `git diff --name-only <base>..<tip> --
  openspec/changes/<id>/specs` per task with a resolvable branch, and prints `—` when there is none. Verify: the
  fixture cases of 1.5.
- [ ] 1.4 `scripts/lib/cmd-status.sh`: the `self-verify: <agent>` mark on a verify task whose agent authored an apply
  task of the same change (design §5), and the unknown-id message naming both the missing briefs and the missing
  change directory. Verify: 1.5's `self-verify` and unknown-id cases.
- [ ] 1.5 A new smoke section `12e · change 视图（P23/B1）`: the ready fixture (`pending/` project with an archived
  change dir, two mapped tasks both finished) → exit 0 and the readiness line; the not-ready fixture (a third task
  at `wip`) → exit 1 and the blocker naming that task, its status and its missing evidence; `--json` parses and
  carries `ready: false` with the same blocker; `team change status no-such-change` → non-zero naming both facts;
  the `self-verify` mark; and the read-only proof (`git status --porcelain` in the fixture unchanged, board bytes
  unchanged). Verify: `bash skills/teamsmith/tests/smoke.sh 12e` exists as a section and exits 0 (the suite's
  section selector or a `TEAM_SMOKE_ONLY`-style run used by the neighbouring sections).
- [ ] 1.6 Flip: on a scratch copy, make `team_change_ready` ignore unfinished siblings (return ready when any task
  is finished) → the not-ready assertions and the blocker case go red; restore → green. Verify: both tails in the
  report.

## 2. B2 — the digest section and the panel's task tokens (board-and-status, ADDED)

- [ ] 2.1 `scripts/lib/cmd-status.sh`: digest section `[6] change 归组` (design §7) — one bounded line per
  non-archived change with task tokens and the readiness mark, the two "no task points at it"/"no change dir"
  markers, one dim empty line when there is nothing, and **no renumbering** of `[1]`–`[5]`. Verify: 2.3's digest
  assertions plus a grep assertion that the section headers `[1]`–`[5]` are byte-identical to the pre-change run.
- [ ] 2.2 `scripts/lib/cmd-watch.sh`: `team_panel_changes_json` gains a `tasks` array per change entry (id, phase,
  board, verdict; bounded to 8 tokens) built from `team_change_tasks`/`team_board_status`/`team_review_verdict` in
  the same process; the console layout renders the token line under the change row and drops it (rather than
  reflowing the block) when the width tier cannot hold it. Verify: 2.3's `--json`/snapshot assertions.
- [ ] 2.3 A new smoke section `12f · change 归组（P23/B2）`: the fixture project's `team digest` carries the `[6]`
  line naming `alpha` with `M1 done · M2 wip` and the not-ready mark, matching `team change status alpha`'s tokens;
  a change dir with no task prints `（没有任务指向它）`; a task pointing at a missing dir prints its marker; the
  bounded case prints `+N`; `team monitor --print` and `team monitor --json` are byte-identical to a pre-change
  capture (the console-only block) while `team __panel-data --block changes` carries the tokens; and `team digest`'s
  `git` call count stays within the suite's existing budget (the `PATH` wrapper counter used by the M50 fixtures).
  Verify: the section's tail in the report.
- [ ] 2.4 Flip: on a scratch copy, drop the grouping from the panel reader while keeping it in the digest → the
  `__panel-data` token assertion goes red and the byte-stability assertions stay green (proving the two surfaces
  are asserted separately); restore → green. Verify: both tails.

## 3. B3 — rules 1 and B in `dispatch` (dispatch, ADDED ×2)

- [ ] 3.1 `scripts/lib/cmd-agents.sh`: the pre-window guard block in `team_cmd_dispatch` (before the stack guard,
  after the brief-path checks) calling the strict reader for `change:`; refusal text names the offending line, the
  accepted forms and the fix for each of the three shapes (comma list, two tokens, two lines); no `--force` path for
  this rule. Verify: 3.5's rule-1 cases.
- [ ] 3.2 `scripts/lib/cmd-agents.sh`: the same block refuses on a malformed value even when the brief is otherwise
  valid, and the refusal happens for `--print` too (design §3). Verify: 3.5's `--print` case.
- [ ] 3.3 `scripts/lib/cmd-agents.sh`: the anchor guard for change-less briefs — `specs:` resolution (capability
  file, and a `#<requirement>` name when given) and the `anchor: none (infra) — <reason>` form; the refusal names
  both accepted forms and the `openspec/specs/…` path it looked for; `--force` prints the warning and calls
  `team_wlog` exactly once. Verify: 3.5's anchor cases.
- [ ] 3.4 `scripts/lib/cmd-agents.sh`: no board write and no window request on any of these refusals (the guard runs
  before `team_board_*`/tmux), and the already-anchored briefs of a fixture project keep dispatching unchanged
  (regression). Verify: 3.5's board-unchanged and shim-empty assertions.
- [ ] 3.5 A new smoke section `12g · 派单锚点（P23/B3）`: the fixture briefs of design §11 — two-id (comma), two-id
  (space), two `change:` lines, `change: alpha` (allowed), `change: -` + `specs: panel#<existing requirement>`
  (allowed), `change: -` + `anchor: none (infra) — reason` (allowed), `change: -` + `specs: -` + no anchor
  (refused), `anchor: none (infra)` without a reason (refused), `specs: no-such-capability#x` (refused),
  `specs: panel#Not A Requirement` (refused), and the `--force` override with its one `state/watchdog.log` line.
  Every refusal asserts the record-only shim log is empty and the board row is unchanged. Verify: the section's
  tail.
- [ ] 3.6 Real-path check `[real]`: a refusal in a real dispatch attempt (no shim) is refused before any window
  exists (`tmux ls` in the fixture session shows nothing new) and `--print` prints nothing. Verify: the run's tail.
- [ ] 3.7 Flips: (a) make the strict reader accept the first `change:` token (the old behaviour) → the two-id cases
  go red; (b) make the anchor guard a no-op → the anchor-less cases go red; restore both → green. Verify: both
  tails.

## 4. B4 — the delta single-writer guard (dispatch, ADDED)

- [ ] 4.1 `scripts/lib/common.sh`: `team_change_delta_files <id>` — the change's `specs/*/spec.md` files, and
  `team_task_delta_targets <brief>` — the declared targets, `-` → empty, absent → every file of the change; both
  in-process, no `git`. Verify: 4.4's declaration cases.
- [ ] 4.2 `scripts/lib/cmd-agents.sh`: the guard: collect the change's unfinished tasks (one `team_change_tasks`
  scan + `team_task_open_reason` per task, the dispatched task excluded), intersect the target sets, refuse naming
  the sibling, its board status, the shared file(s) and both declarations; `--force` warns and appends exactly one
  `team_wlog` line naming both tasks and the file. Verify: 4.4's cases.
- [ ] 4.3 `scripts/lib/cmd-agents.sh`: the guard is keyed on the change id, so tasks of different changes are never
  compared, and a finished sibling (done/closed or with evidence) never blocks. Verify: 4.4's cross-change and
  finished-sibling cases.
- [ ] 4.4 A new smoke section `12h · delta 单写者（P23/B4）`: sibling `M1` (unfinished, `deltas: panel`) + new
  `M2` (`deltas: panel`) → refused naming `M1`, `wip`, `openspec/changes/<change>/specs/panel/spec.md` and both
  declarations, shim log empty, board unchanged; `M2` with `deltas: -` → allowed (the output states what was
  compared); the sibling's brief without a `deltas:` line + a new declaration → refused with the
  "read as every delta file" sentence; `beta` vs `alpha` with identical declarations → allowed; sibling `done` →
  allowed; `--force` on the first case → proceeds with exactly one audit line. Verify: the section's tail.
- [ ] 4.5 Real-path check `[real]`: the `--force` run appends the audit line to the real `state/watchdog.log` of a
  fixture project and `team monitor`'s events column shows it on the next frame. Verify: the captured tail.
- [ ] 4.6 Flips: (a) make the absent-`deltas:` case read as "empty" instead of "unknown" → the missing-declaration
  case goes red; (b) make the intersection compare only the agent's own recorded task → the cross-agent case goes
  red; restore both → green. Verify: both tails.

## 5. B5 — no self-verification per change (verification, ADDED)

- [ ] 5.1 `scripts/lib/common.sh`: `team_change_apply_authors <id>` — the `agent:` values of the change's apply
  (or phase-less) tasks, `dropped` ones excluded, with the per-task author trail for the message; a task with no
  resolvable brief or no `agent:` returns a "missing signal" list instead of an empty author set. Verify: 5.4's
  cases.
- [ ] 5.2 `scripts/lib/cmd-agents.sh`: the guard for `phase: verify` dispatches — refuse when the dispatched
  `agent:` is in the author set, naming the change, the agent and the authored tasks; `--force` warns, calls
  `team_wlog` once and names the loss of independence; the missing-signal case prints what is missing and proceeds.
  Verify: 5.4.
- [ ] 5.3 `scripts/lib/cmd-status.sh`: the `self-verify: <agent>` mark from 1.4 shares this function (one
  predicate), so the view and the guard cannot drift. Verify: 5.4's agreement assertion.
- [ ] 5.4 A new smoke section `12i · 按 change 判独立性（P23/B5）`: change `alpha` with apply `M1` by `dev` and a
  verify brief `V1` by `dev` → refused naming `alpha`/`dev`/`M1`, shim empty, board unchanged; `V1` by `verify` →
  allowed; `M1` dropped → allowed and named as excluded; apply task with no `agent:` → proceeds with the
  missing-signal line; `--force` → one audit line; and `team change status alpha` printing `self-verify: dev`
  while the guard would refuse. Verify: the section's tail.
- [ ] 5.5 Flips: (a) make the author set include only the dispatched agent's own recorded task → the cross-agent
  refusal case goes red; (b) make the missing-signal case a silent pass → its assertion goes red; restore both →
  green. Verify: both tails.

## 6. B6 — the archive precondition (board-and-status, ADDED)

- [ ] 6.1 `scripts/lib/common.sh`: the `phase: archive` route of `team_done_phase_evidence` additionally requires
  `team_change_ready <change>` — the archived directory stays necessary and is no longer sufficient; the refusal
  names the unfinished siblings with their status and missing evidence (one message, reused verbatim by `team change
  status`). Verify: 6.3's cases.
- [ ] 6.2 `scripts/lib/common.sh`: the existing override stays intact — `TEAM_BOARD_DONE_FORCE=1` with
  `TEAM_BOARD_DONE_REASON` still prints `FORCED` and appends the audit line to `reviews/<ID>-done.md`; a task whose
  `change:` is `-` keeps the old phase route byte-for-byte. Verify: 6.3.
- [ ] 6.3 A new smoke section `12j · 归档前提（P23/B6）`: the archive task `A1` with a `wip` sibling → `team board
  set A1 done` exits non-zero naming the sibling, and `team board row A1` is unchanged; all tasks finished →
  allowed with the evidence line in `reviews/A1-done.md`; the forced form records `FORCED` and the reason; the
  agreement case (the same sibling named by `team change status` and by the gate, both flipping together once its
  record lands); and the change-less regression (a `change: -` archive task keeps its old behaviour). Verify: the
  section's tail.
- [ ] 6.4 Flip: on a scratch copy, drop the readiness requirement from the archive route → the blocked case and the
  agreement case go red; restore → green. Verify: both tails.

## 7. B7 — the template and the documents (the fields and the checklist the requirements read)

- [ ] 7.1 `skills/teamsmith/templates/task.md.tmpl`: `anchor:` and `deltas:` join the header with `-` defaults, and
  the comments of `change:`/`specs:`/`phase:` carry their grammar (design §1), so a generated brief declares its
  state. Verify: `team task T9.9 --title "probe" --agent dev` in a scratch project renders all five change-related
  lines; the rendered file parses under the strict reader without a refusal for the values the rules allow (`-`).
- [ ] 7.2 `skills/teamsmith/references/openspec.md`: §2 gains the `1 change : N tasks` paragraph, §4 gains checklist
  points 9 and 10 (design §8) and §5's archive row gains `team change status <id>` (ready, exit 0) before the trial
  archive. Verify: `grep -n 'One change per task\|The anchor exists\|team change status' references/openspec.md`
  returns the three locations and the existing eight points are unchanged.
- [ ] 7.3 `skills/teamsmith/references/protocol.md` + `skills/teamsmith/SKILL.md` (command table, the PM loop): the
  guards' *why* and the new verb. Verify: `team help` lists `change status`; the SKILL command table carries it;
  the doc lines naming the four refusal classes match the implemented messages.
- [ ] 7.4 `AGENTS.md` + `skills/teamsmith/templates/AGENTS.section.md.tmpl` +
  `skills/teamsmith/templates/PROTOCOL.md.tmpl`: one paragraph stating the model, the header fields, the two hard
  rules at dispatch (one change id; the verifier is not an author) and the archive readiness. Verify: the rendered
  template in a scratch `team init` project contains the paragraph; `AGENTS.md` and the template agree (the
  template is the source).
- [ ] 7.5 Flip: delete checklist point 10 from `references/openspec.md` → 7.2's grep assertion goes red; restore →
  green. Verify: both tails.

## 8. Gates and evidence

- [ ] 8.1 The gate of every batch and of the final branch:
  `PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh` exits 0
  (during development `TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh` is the same suite with the slow
  sections skipped; the final run is the full one). Verify: the final run's tail in the report.
- [ ] 8.2 The flip package `skills/teamsmith/tests/flip-p23.sh` runs every flip of §1.6, §2.4, §3.7, §4.6, §5.5,
  §6.4 and §7.5 in one shot (red on the mutant, green on the restored tree) and exits 0 only when every pair holds.
  Verify: the script's tail.
- [ ] 8.3 The report carries, per requirement: the item that moves it, the fixture that can fail on it, the flip
  evidence, and the coverage map above with every item accounted for; plus the regression evidence that the
  existing header callers (`team_task_change`/`team_task_phase`), the `--print`/`--json` byte-stability and the
  dispatch fixtures of the previous guards are unchanged.
