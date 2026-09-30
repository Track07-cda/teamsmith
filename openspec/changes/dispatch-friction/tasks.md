# Tasks: `dispatch-friction`

Planning only — nothing in this file is executed by the propose task (P136). The apply is one dependency-ordered
whole: the declared branch name and the wording changes land first, the pre-launch collector second, and the route
walk last (it exercises the fixes the collector prints). The verify phase is a separate brief owned by a different
agent.

Coverage map (requirement → items): **R1** `dispatch#One task branch per task` → 1.1–1.4; **R2**
`dispatch#A brief names at most one change id` → 2.1, 2.3; **R3** `dispatch#Two unfinished tasks of one change do
not write the same delta file` → 2.2, 2.3; **R4** `dispatch#A dispatch never mixes two tasks in one worktree` →
3.1–3.4; **R5** `dispatch#A refused dispatch hands over every blocker, once, with a fix that runs` → 3.1–3.4,
4.1–4.4; **R6** `dispatch#A dispatch warns before a seat that burned its last round` → 5.1–5.3; **R7**
`dispatch#The printed route is a route that works` → 4.2–4.4; gate/evidence → 6.1–6.3; independent verification →
7.1.

How each requirement is re-checked (run what → read which part → expected value):

| Req | Run | Read | Expected |
|---|---|---|---|
| R1 | the three scratch fixtures (worktree on `task/T8.8-other`; on `task/T1.1-legacy`; `--branch task/T1.1-pm-named` with the worktree on `task/T1.1-legacy`) + `team task` + `team dispatch --print` | the exit codes, the printed `分支：` line and its source, the brief's `branch:` line, `team help`'s dispatch line | other-task refused with its `git switch`; same-task legacy accepted with both names; declared mismatch refused; brief and dispatch name the same branch |
| R2 | `change: panel（说明）`, `change: alpha, beta`, two `change:` lines | the **first** output line | it carries a legal `change: <id>`/`-` example and the specific reason |
| R3 | `deltas: panel · verification`, `deltas: panel,`, `deltas: panel verification`, `deltas: panel, verification` | the first output line of each refusal; the last fixture's exit code | separator/trailing-item named + example; the comma list proceeds |
| R4 | the composite fixture (malformed header + wrong branch + unfinished previous task) | one invocation's whole output and the board row/state after it | both legs are items of the one refusal; worktree/dirty/prev fields present; routes printed; nothing written |
| R5 | the same composite; then the printed `改行：` lines and `修法：` commands applied; `--force` with only overridable blockers | the count line, the `修法：`/`改行：` lines, the re-run's output, `state/watchdog.log` | one refusal lists all; the re-run reports none of them; one audit line per overridden blocker, none for `--print` |
| R6 | `state/deaths.log` with a `quota` record; `state/<agent>.env` with `sid`/`sid_bytes` and a byte-identical session file; the same with one byte appended / file removed / category `window` | the output's `⚠` lines and the exit code | quota named with source+raw; `0 bytes` named; silence on the three negative fixtures; exit code unchanged and the window still requested |
| R7 | `bash skills/teamsmith/tests/routes.sh` + its flips | per-family `ok` lines, the missing-entry control, the mutated-fix flip | green on the committed tree; red naming the family when a printed route stops clearing its blocker or has no entry |

Path grants the apply brief must state: `skills/teamsmith/tests/**` is agent-owned (smoke, routes, tables, fixture
helpers). `skills/teamsmith/scripts/lib/{common.sh,cmd-agents.sh,cmd-docs.sh,cmd-project.sh}`,
`skills/teamsmith/scripts/team`, `skills/teamsmith/templates/task.md.tmpl`, `skills/teamsmith/SKILL.md` and
`skills/teamsmith/references/{protocol,troubleshooting}.md` are **PM-owned** and need an explicit grant for the
named blocks only — the guards' judgement code (D16/M6.3/D24/D36/D40), the death classifier, the tmux shim and the
launch harness stay byte-for-byte outside the granted hunks. `openspec/changes/dispatch-friction/**` belongs to the
phase's owner; `docs/team/reports/<ID>-<agent>.md` and its `pkg/` dir are the agent's own.

Fixture notes: every fixture clears the inherited team identity (`TEAM_ROOT TEAM_MAIN_ROOT TEAM_PROJECT
TEAM_SESSION TEAM_TMUX_CALLS_LOG TEAM_TMUX_REAL`), runs in its own scratch git repo and puts the record-only `tmux`
shim first on `PATH`; nothing may reach a real tmux server (M36/D57). Any leg that needs a real process is marked
`[real]` and is never the only evidence for a requirement. The propose recon (`docs/team/reports/P136-dev2/`) is the
baseline the flips compare against.

## 1. R1 · one declared branch name (MODIFIED `One task branch per task`)

- [ ] 1.1 `templates/task.md.tmpl` + `cmd-docs.sh` (`team_cmd_task`): render a `branch:` header line from the same
  derivation `dispatch` uses (`team_branch_for_agent <agent> <id>`), and print it in the post-create hint. Verify:
  in a scratch project, `team task T1.1 --title "first task" --agent dev` leaves `branch: task/T1.1-first-task` in
  the brief; an ASCII title and a non-ASCII title both yield a non-empty slug.
- [ ] 1.2 `cmd-agents.sh` (`team_cmd_dispatch` argument loop, `team_build_prompt`) + `cmd-project.sh` (help line):
  parse `--branch <name>`; resolve `--branch` > the brief's `branch:` line > the title derivation; validate the
  resolved name with `team_branch_is_for_task`; print `分支：<name>（来源：--branch / 任务书 branch: 行 / 由标题 "…"
  推导）` in the pre-launch output and in `--print`; name it in the prompt too; the help line prints `--branch
  <name>`. Verify: the three resolution fixtures each print the expected name and source; `team help` carries the
  flag; `bash tests/routes.sh walk` stays green on the new help line (its `--branch` claim is probed against the
  dispatch parser, whose missing-value error is not the unknown-parameter refusal).
- [ ] 1.3 `common.sh` (`team_check_worktree_for_task`) + the `--branch` validation path: accept a worktree on
  **this task's** branch when its slug differs (print both names), keep refusing another task's branch with the
  same fields and `git -C … switch` command, require exactly the declared name when `--branch` is given, and keep
  the missing-worktree and dirty-worktree refusals unchanged. Verify: fixtures (a) `task/T8.8-other` → refused
  naming both; (b) `task/T1.1-legacy` with no unfinished record → accepted, both names printed; (c) `--branch
  task/T1.1-pm-named` with the worktree on `task/T1.1-legacy` → refused naming both; (d) dirty from another task →
  refused with count and previous id.
- [ ] 1.4 `tests/smoke.sh` §6 / M6.3 F16 legs (`:1646–:1675`) plus the new legs for 1.2–1.3: extend with the
  same-task acceptance, the source-printing cases, `--branch` accept/refuse and the declared-mismatch refusal;
  flip by reverting 1.3's acceptance condition → the new acceptance leg must fail; restore. Verify: `TEAM_SMOKE_FAST=1
  bash skills/teamsmith/tests/smoke.sh </dev/null` green, flip output in the report.

## 2. R2/R3 · the refusal teaches the syntax on its first line (MODIFIED)

- [ ] 2.1 `common.sh` (`team_task_change_value`) + `cmd-agents.sh` rule 1: make the reason specific (two `change:`
  lines; more than one id for comma/space lists; trailing text with the extra characters quoted) and compose the
  refusal's first line as `拒绝派单：<ID> 的 change: 行不合法 —— <reason>；合法示例：change: <one id>（或 change:
  -）`, with the accepted forms and an exact `改行：change: <leading token>` line following. Verify: the three
  fixtures print the expected first line and a `改行：` line that the field reader accepts.
- [ ] 2.2 `common.sh` (`team_task_deltas`) + `cmd-agents.sh` rule 2: name the separator (`·`, `;`, whitespace) and
  the trailing empty item, report the bad token not the whole value, and compose the first line with the comma
  example; `改行：deltas: <tokens joined by ", ">` when every part is a valid capability, else `改行：deltas: -`.
  Verify: `panel · verification`, `panel,`, `panel verification`, `panel, verification` (accepted) each behave as
  the delta's scenarios say.
- [ ] 2.3 `tests/smoke.sh` §12g/§12h: add the first-line and `改行：` legs (the existing multi-id legs must still
  pass); flip by restoring the old generic first line → the new legs must fail; restore. Verify: FAST smoke green;
  flip output in the report.

## 3. R4/R5 · one pre-launch pass, one refusal (MODIFIED + ADDED)

- [ ] 3.1 `cmd-agents.sh`: introduce the findings collector and turn the pre-launch guards into finding producers
  (header rules, anchor, delta shape/single-writer, verify seat, multiple briefs, unfinished previous task,
  worktree presence, dirty state, branch identity, capacity floor, model concurrency, session-vs-window, agent
  executable); keep each guard's judgement, override flag and message body; a guard whose precondition is absent
  emits a "could not be judged" finding naming what is missing. Verify: each guard still refuses alone with its
  old fields (fixtures from §6/§12g/§12h/§22/§15b/§6h/§29 re-run green).
- [ ] 3.2 `cmd-agents.sh` (`team_cmd_dispatch`): print one refusal — first item first line, items in guard order,
  `修法：`/`改行：` lines, a final count line — and keep `--force` per-guard (warnings + one audit line each, written
  only after a real launch, none for `--print`); ensure no window, state write, branch switch or board change
  happens before the report passes. Verify: composite fixture prints one refusal with three items and count 3; a
  `--force` run with only overridable blockers proceeds and writes exactly one audit line per blocker.
- [ ] 3.3 `cmd-agents.sh` (launch path after the preflight): confirm the runtime path (nonce proof, retry once,
  adapter exit diagnosis, corpse capture) is byte-for-byte the same and reachable after a green preflight. Verify:
  §6h/§41/§6j legs still green; a `--print` run opens no window.
- [ ] 3.4 `tests/smoke.sh`: add the composite legs (three blockers → one refusal, count line, board/state/window
  untouched; applying the printed fixes → the re-run proceeds; `--print` variant) in the dispatch family; flip by
  restoring first-failure abort → the composite legs must fail; restore. Verify: FAST + full smoke tails in the
  report.

## 4. R5/R7 · the printed routes are exercised (MODIFIED `The printed route is a route that works`)

- [ ] 4.1 `cmd-agents.sh` message catalog: one `修法：<command>` or `改行：<exact line>` line per preflight family
  (branch switch, `--force` re-dispatch, `--fresh`, anchor/delta overrides, config knob, `git worktree add`), with
  concrete values and no placeholders. Verify: the composite output's routes all start with the two markers and
  contain the fixture's real worktree/branch/task values.
- [ ] 4.2 `tests/routes.sh`: a new walk over the refusal surface — a declared family table, each entry built in a
  fresh fixture with the recording `tmux` shim, running the refusing command, applying **the printed route**,
  re-running and requiring the blocker gone; one line per family, no silent skip. Verify: `bash
  skills/teamsmith/tests/routes.sh` green; a family the tool prints but the table does not carry fails naming the
  family.
- [ ] 4.3 `tests/routes.sh`: the walk's flips — a scratch tree whose fix-rendering is mutated (wrong switch target)
  must redden the walk; confirm the existing Walk A/B controls stay green. Verify: `bash
  skills/teamsmith/tests/routes.sh` full run with the flip section green and the mutated run red.
- [ ] 4.4 `tests/section-budgets.tsv` + `tests/section-paths.tsv`: register whatever sections the new legs live in
  (new section or extended ones), measure each changed section's band on the host (and container if run) and write
  the row with its provenance; run `bash skills/teamsmith/tests/section-guard.sh --budget-check` and `bash
  skills/teamsmith/tests/section-select.sh --check`. Verify: both exit 0; the measured band table matches the
  recorded values.

## 5. R6 · the quota / zero-output hint (ADDED)

- [ ] 5.1 `cmd-agents.sh` state writes: record the round's session id and the session file's size at launch
  (`sid=`, `sid_bytes=`) in `state/<agent>.env` on a successful dispatch (resume goes through the same path).
  Verify: a fixture dispatch leaves both keys; a re-dispatch of the same task overwrites them with the new round's
  values.
- [ ] 5.2 `cmd-agents.sh` (+ the `agent-death-reason` reader): the hint function — the death leg from
  `team_seat_death_fields` (`quota`/`balance` → category, source, time, raw line) and the zero-output leg from
  `sid`/`sid_bytes` vs the file's current size; print `⚠` lines in the pre-launch phase and `--print`; never
  return non-zero, never open a window, never duplicate as a refusal; silence when a leg cannot be judged. Verify:
  the five R6 fixtures (quota, 0-byte round, appended byte, missing file, `window` record) each print exactly the
  expected lines and nothing else.
- [ ] 5.3 `tests/smoke.sh` §52-adjacent or a new section: the five fixtures plus the non-blocking `[real]` leg
  (record-only `tmux` shim: window requested, exit 0, launch-proof path unchanged); register the section in the
  budget/path tables (4.4). Verify: FAST smoke green; the `[real]` leg log in the report.

## 6. Gate, docs and evidence

- [ ] 6.1 `SKILL.md` (dispatch row), `references/protocol.md` (the refusal report format, `修法：`/`改行：`, the
  declared-branch rule) and `references/troubleshooting.md` (the hint's two legs, the safe reading of the report
  before a re-dispatch): PM-granted sections only. Verify: the sentences match the delta wording;
  `grep -n '修法：' skills/teamsmith/SKILL.md` lands in the dispatch row.
- [ ] 6.2 Run the gate and the stricter commands, paste the tails: `PATH="$HOME/.bun/bin:$PATH" openspec validate
  --all --strict`, `TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null`, `bash
  skills/teamsmith/tests/smoke.sh </dev/null`, `bash skills/teamsmith/tests/routes.sh`; `git status --porcelain`
  clean.
- [ ] 6.3 The report's flip section: for each of R1/R2/R3/R5/R6 the red tail before and the green tail after
  (reproducing `docs/team/reports/P136-dev2/recon.log`), the composite one-pass output, the walk's mutated-fix red
  and green, and the untouched-contract statement for the guards and the launch harness.
- [ ] 6.4 Trial archive on a scratch copy (`rm -rf /tmp/trial-p136 && mkdir -p /tmp/trial-p136 && cp -r openspec
  /tmp/trial-p136/ && (cd /tmp/trial-p136 && openspec archive -y dispatch-friction)`) — proves every MODIFIED
  requirement kept its base scenarios and the deltas merge beside other open changes.

## 7. Independent verification (a different agent — the pipeline's verify phase)

- [ ] 7.1 Re-run, out of tree and on the apply's tip: the R1–R6 fixtures, the composite one-pass, the walk's
  flips and controls, the silence controls, `openspec validate --all --strict`, FAST and full smoke; the record
  goes to `docs/team/reviews/<ID>.md` with a verdict and any findings (a PASS carrying findings is rework, not
  archive).
