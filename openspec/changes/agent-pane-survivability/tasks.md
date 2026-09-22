## 1. Retention: an agent window outlives its pane (capability `dispatch`)

- [ ] 1.1 Create agent windows with the option already on: replace the single `tmux new-window` in
  `team_cmd_dispatch` (cmd-agents.sh, the site that also serves `resume`) with the draft window's
  proven ordering — placeholder command holds the pane, `set-window-option remain-on-exit on`, read
  the value back, then `respawn-pane -k` starts the existing harness; leave the PM, pulse and draft
  windows untouched. Verify: `tmux show-options -w -v -t <session>:<agent> remain-on-exit` prints
  `on`, the same read for the fixture's PM window prints nothing (no window-level setting; the
  effective value is tmux's default `off`), and the existing dispatch sections
  (§6h, §6i, §6j) stay green — `bash skills/teamsmith/tests/smoke.sh </dev/null`.
- [ ] 1.2 Prove a killed pane leaves a corpse: fixture that dispatches with a fake agent which prints a
  marker line and stays alive, waits until the marker has appeared in the pane, then SIGKILLs the
  pane's process group; assert the window still exists, `#{pane_dead}` is 1, `#{pane_dead_signal}` is
  9, `capture-pane -p -S -` still contains the marker line (the visible screen alone can drop it),
  and `kill-window` still removes the window. Verify: the new section in
  `skills/teamsmith/tests/smoke.sh`, run as `bash skills/teamsmith/tests/smoke.sh </dev/null`.
- [ ] 1.3 Keep a live seat exactly as it was: assert a normal agent exit (fake agent exits 0) leaves
  `#{pane_dead}` 0, that `team roster` reports the exited condition rather than the dead one, and
  that `team resume --agent <agent>` starts the recorded task again with exactly one window for that
  seat. Verify: same smoke section as 1.2 plus the existing §12 roster assertions.

## 2. Reuse and delivery: a dead pane is never a live seat (capability `dispatch`)

- [ ] 2.1 Capture before reuse: in the `dispatch`/`resume` path, when the seat's window exists with
  `#{pane_dead}` 1, write `state/dispatch-<agent>-pane-dead.txt` (seat, window, timestamp, exit
  evidence, and the last `TEAM_AGENT_SCENE_LINES` scene lines, default 40) **before** the window is
  replaced, and change the reuse message so a corpse is reported as "the previous pane is dead" while
  a live round keeps the interruption wording. Verify: fixture with five marker lines on the corpse and
  `TEAM_AGENT_SCENE_LINES=3` — the file exists and holds exactly three scene lines plus the exit
  evidence; `wc -l` and `cat` of the file in the smoke output.
- [ ] 2.2 Refuse delivery to a corpse: gate the key-sending path on `#{pane_dead}` (not only on the
  foreground command name), so `team say` to a dead-pane seat leaves the message in
  `docs/team/inbox/<agent>.md`, names the seat as dead with its exit evidence, and never prints a
  delivery claim (`send-keys` returns 0 into a dead pane — measured). Verify: fixture asserting the
  output contains no delivered confirmation, the inbox line exists, and `capture-pane` of the corpse
  is byte-identical before and after the `say`.
- [ ] 2.3 Keep the three replacement paths one-window and evidence-honest: assert `dispatch`,
  `dispatch --fresh` and `resume` over a dead-pane seat each leave exactly one window whose
  `remain-on-exit` is `on`, that this round's launch proof decides (a stale
  `state/dispatch-<agent>.exit` from the killed round is not reported as this round's exit), and that
  `team teardown --agent` removes the retained window. Verify: assertions per command in the same
  smoke section; the teardown assertion reads back `team roster`.
- [ ] 2.4 Enumerate the call sites that used to equate "window exists" with "seat is usable" and state
  in the report, for each, whether a retained corpse changes its decision and which test pins it —
  `rg -n 'team_tmux_has_window|team_agent_window_exists' skills/teamsmith/scripts/` written to
  `docs/team/reports/<ID>-<agent>/tmux-window-sites.txt` with the per-site verdict next to it.

## 3. Visibility: the corpse is a condition with a scene (capability `watchdog`)

- [ ] 3.1 One seat-condition reader: a single implementation that returns
  `running`/`exited`/`dead`/`absent` plus the exit evidence from `#{pane_dead}`,
  `#{pane_dead_status}`, `#{pane_dead_signal}`, with `running` still requiring the M6.5/M37 proof;
  `team roster` prints the dead condition distinguishably (with `status=`/`signal=`) and its legend
  names the four conditions. Verify: three-state fixture (`alive`, `exited`, `dead`, `absent`) in the
  smoke section and the existing §12 output assertions.
- [ ] 3.2 `team status <ID>` prints the seat condition, exit evidence, and the most recent death/exit
  record's last `TEAM_AGENT_SCENE_LINES` lines with its source and time (live dead pane read with its
  scrollback first, then `state/dispatch-<agent>-pane-dead.txt`, then
  `state/dispatch-<agent>-tail.txt`), and prints no scene block for a seat with no such record. Verify: fixture asserting the source label, `signal=9`, and
  that `TEAM_AGENT_SCENE_LINES=2` yields exactly two scene lines; a second assertion for a live seat
  with no record printing no scene.
- [ ] 3.3 Machine block: add `pane` (`live`/`dead`) and `pane_exit` (`status=<n>`/`signal=<n>`) to the
  agents block of `team __panel-data --block agents` / `team monitor --json` **without** changing the
  `state` vocabulary, and leave the panel bundle's rendering untouched. Verify: parse the block as
  JSON in the fixture and assert the fields (`pane=dead`, `pane_exit=signal=9`) while the panel
  sections (§26–§28) stay green — a dead pane must not be reported as `running`.
- [ ] 3.4 `team digest` names a dead-pane seat with its recorded task, and `team doctor` prints one
  warning line naming the seat, its exit evidence and `team status <ID>`, staying silent (exit status
  unchanged) when no pane is dead. Verify: fixture asserting the digest line, the doctor line, and the
  absence of both in the all-alive fixture.
- [ ] 3.5 Read-only discipline: extend the existing state-fingerprint assertion (M6.1 F28) to
  `team roster`, `team status <ID>`, `team digest`, `team doctor` and `team __panel-data --block
  agents` — every file under `.pi/team/state/` byte-identical after the reads. Verify: the fingerprint
  comparison in the smoke section fails loudly on any state write.
- [ ] 3.6 Noise criterion: a retained window is an anomaly only while the seat's recorded task is
  unfinished; pin the reverse fixture — after `team close <ID> --keep-window` the dead seat appears in
  no `stopped` count and no "abnormal exit" line of digest/doctor, while a seat with an unfinished
  task and a dead pane is named with its evidence and task. Verify: fixture reading
  `team __panel-data --block pending`, `team digest`, `team doctor`, then `team teardown --agent` and
  re-reading `team roster`.

## 4. Evidence, docs and the flip

- [ ] 4.1 Flip harness `skills/teamsmith/tests/flip-p49.sh` in the style of the existing `flip-*.sh`
  scripts: red before (the retention assertion fails against a tree whose creation site sets
  `remain-on-exit off`) → green after (against the tree under test), and the restoration proves the
  guard is not tautological. Verify: `bash skills/teamsmith/tests/flip-p49.sh` prints the red and the
  green sides and exits 0 only when both are as expected.
- [ ] 4.2 Explain the mechanism where the diagnosis lives: add the "a seat window is a corpse" section
  to `skills/teamsmith/references/troubleshooting.md` (what the four conditions mean, where the scene
  comes from, what `status=`/`signal=` mean, why the PM window has no retained pane), and point the
  delta requirements at it. Verify: `rg -n 'pane-dead|remain-on-exit' skills/teamsmith/references/`
  finds the section and the delta's cross-reference resolves.
- [ ] 4.3 Acceptance on the branch tip: `PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict`
  and `bash skills/teamsmith/tests/smoke.sh </dev/null` both exit 0, and `git status --porcelain` is
  empty. Verify: the three commands' tails pasted into the report.
