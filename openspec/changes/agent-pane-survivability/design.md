# agent-pane-survivability · design

## Context

See `proposal.md` — Why (the 2026-09-22 deaths and the evidence that died with them). The current
state that shapes every decision below:

- An agent window is created by `team_cmd_dispatch` as
  `tmux new-window -t <session> -n <agent> -d -- bash -lc "$inner" "$prompt"` (cmd-agents.sh:793), and
  that harness ends in `exec bash`, so a normal agent exit leaves a shell in the pane. `dispatch` and
  `resume` reach the same code path (`resume` calls `team_cmd_dispatch`).
- The harness already captures a bounded tail of the pane at the moment the agent returns
  (`state/dispatch-<agent>-tail.txt`, `capture-pane -S -200`, cmd-agents.sh:374/790), so the agent's
  own exit is not the blind spot. The blind spot is the pane dying after that: with tmux's default
  `remain-on-exit off` the window closes with the pane and every trace of it goes too.
- The draft window already uses the mechanism this change needs, including the ordering trap it
  solves: a placeholder command holds the pane, then `set-window-option remain-on-exit on`, then
  `respawn-pane -k` starts the real harness (cmd-draft.sh:59-63). If the option is set after the pane
  can already exit, a fast command wins the race and the window is gone.
- Seat conditions are derived in two places: `team roster` (`team_agent_live` /
  `team_agent_window_exists`, cmd-status.sh:359-361) and the machine agents block that feeds both
  `team __panel-data --block agents` and `team monitor --json` (cmd-watch.sh:560-571). Both treat
  "window exists, no agent inside" as one condition, so a retained corpse and a seat waiting for
  `team resume` are indistinguishable today.
- PM liveness is proof-based: `team_pm_state` (common.sh:1718) requires a recorded pid that is alive
  with a project cwd, or a window process whose command line matches the configured PM executable
  with a project cwd; anything else it cannot prove is `idle`/`unknown`/`foreign`, and
  `team_pm_start` (common.sh:2223) replaces `idle`/`unknown` by `respawn-pane`.
- Facts measured for this design on the reference host (tmux 3.7b, private socket with `TMUX_TMPDIR`
  and `-L p49probe-$$`, never the team's server). The reproducible probe and its full log are
  committed at `docs/team/reports/P49/probe-pane-survivability.sh` / `.log` (checks P1–P10):
  `remain-on-exit off` → the window disappears with its pane (the incident's shape); `remain-on-exit
  on` (set while a placeholder holds the pane) → the window stays with `pane_dead=1`,
  `pane_dead_status=3` for a clean exit and `pane_dead_signal=9` for SIGKILL, `pane_dead_time`
  carrying the moment; the scene survives the kill once it has been painted, and reading it needs
  `capture-pane -S -` — the visible-screen capture drops the last line on a short pane (P10);
  `respawn-pane -k` and `kill-window` both work on the dead pane's window; `send-keys` into a dead
  pane returns 0 while the pane's content stays byte-identical (P5); setting the option after the pane
  has died cannot bring the window back; `history-limit` is session-wide (writing it with
  `set-option -w` makes every window read the new value — P9), its effective default here is 100000
  via `~/.tmux.conf` (tmux's compiled default is 2000), and a window that never set `remain-on-exit`
  carries no window-level value at all — its effective value is tmux's default, `off` (P7); a death in
  the first fraction of a second can leave a nearly empty screen apart from tmux's own
  remain-on-exit line (P8).

## Goals / Non-Goals

**Goals**
- A seat's pane death leaves a window, the pane's last screen and tmux's exit evidence behind, and the
  evidence survives the seat's own recovery.
- The condition "the pane is dead" is distinguishable from "the agent exited, the window waits" and
  from "no window", on the human surfaces and in the machine block.
- A dead pane is never treated as a live seat or a delivery target.
- Deliberate window retention (`close --keep-window`, `teardown`) is not turned into an alarm.

**Non-Goals**
- Explaining the 2026-09-22 deaths; the change makes the next one diagnosable, it does not solve the
  historical one.
- A new PM state, a fourth rendered panel state, a cleanup daemon, a session-wide tmux default, or a
  pulse-tick writer (see Non-Goals in Decisions D2/D4/D5).
- Any change to `verify`/`review`/the gates, the skill's capacity guards, or the OpenSpec workflow.

## Decisions

### D1 — `remain-on-exit` per agent window, set before the command can exit

`dispatch`/`resume` create the agent window with the draft window's proven ordering: `new-window` with
a placeholder, set and read back `remain-on-exit on`, then `respawn-pane -k` with the existing harness.
The launch-proof mechanism is unaffected: the harness writes this round's nonce to
`state/dispatch-<agent>.spawn` after the respawn, and the nonce, not the pane's state, is what counts.

*Alternatives rejected.* (a) A session-wide `set-option remain-on-exit on` also catches the PM window,
the pulse window and the draft window; it would then need explicit `off` overrides for the PM/pulse
windows — a rule that silently regresses the moment someone adds a window. (b) Relying on the
harness's trailing `exec bash` covers the agent exiting but not the pane dying — exactly the incident's
shape. (c) A watcher outside tmux adds a second backend and still dies with the tmux server it depends
on, which is precisely the failure mode that erased the incident's evidence.

### D2 — the PM window (and the pulse window) keep `off`; the proof route is left alone

The PM window is **not** given `remain-on-exit` in this change. Reasons: (1) the brief's own warning —
`running` must stay a proof, and a retained corpse inside the PM window would need a state shape
taught to every consumer (`team ps`, digest, `up`, the pulse, the panel's `PmState`), a widening policy
B does not plan; (2) the two cases are not symmetric — a worker's uncommitted work has no second copy,
while the PM's context is durable in the ledger (`BOARD.md`, `DECISIONS.md`, threads, reports, inbox)
and the pulse's `team up` already rebuilds a missing PM; (3) the proof model is in fact already safe
against a dead pane: a dead pane's pid has no `/proc` entry, so `team_pm_spawn_pid` and
`team_proc_cwd` both fail, `team_proc_is_pm_bin` gets empty `ps` output, and `team_pm_state` falls
through to `idle`/`unknown`, which `team_pm_start` respawns. The pulse window keeps its behaviour for
the same reason plus one more: `team pulse status` reads window existence, so a retained dead pulse
pane would be reported as a running pulse — a new false green, out of scope here.

The change therefore states the boundary as an observable promise ("MUST NOT be added to the PM window
or to the pulse window") instead of leaving it implicit, and a fixture pins the two windows' option
values. *Follow-up condition:* if a future change gives the PM window the option, it must modify
`pm-lifecycle`'s liveness requirement and its consumers — it cannot be smuggled in as a window knob.

### D3 — bounds: one retained pane per seat, tmux's own scrollback bound, one bounded copy

At most one retained pane exists per seat window: the only way to create a second is the seat's next
`dispatch`/`resume`, which replaces the first (after capturing it). Retention adds no scrollback the
seat's live window did not already hold — the number of windows is unchanged — and that scrollback is
bounded by the host's session-wide `history-limit`, which this change neither raises nor narrows:
a per-window bound is not available (P9: `set-option -w history-limit 7` on one window makes every
window and the session itself read 7), and narrowing it would also shrink the live seat the PM
attaches to. The copy the tool captures into `state/dispatch-<agent>-pane-dead.txt` or prints in
`team status` is bounded by `TEAM_AGENT_SCENE_LINES` (default 40, non-numeric falls back), and the
file is one per seat, overwritten at each capture. No timer, no cleanup job: the reuse path is the
cleanup.

### D4 — the scene is layered, and only writers write

Three layers, in order of recency: the retained pane read with its scrollback (`capture-pane -S -`,
which is what keeps the last line the visible screen can drop — P10) plus tmux's exit evidence (live,
best effort — a death in the first fraction of a second can leave the screen nearly empty, P8);
`state/dispatch-<agent>-pane-dead.txt`, captured by `dispatch`/`resume` immediately before they
replace a dead pane (durable across the
window being killed, and the moment the PM's own recovery used to destroy the evidence); and the
harness's `state/dispatch-<agent>-tail.txt` from the agent's own exit (existing, 200 lines). The
readers only read — `team roster`/`status`/`digest`/`doctor` and the panel blocks must not touch
`.pi/team/state/` (the M6.1 F28 rule the base specs already pin, restated in the watchdog delta so it
cannot regress here). The pulse tick does not capture scenes: it lives in the same tmux server as the
panes, so it cannot outlive the failure mode that removes them, and adding a writer would widen the
patrol's contract for no durability.

### D5 — visibility: four conditions, one readable tuple in the machine block

Human surfaces use four conditions (`running`/`exited`/`dead`/`absent`), with `running` unchanged as a
proof. The machine block keeps its `state` vocabulary (`running`/`exited`/`absent`) and adds `pane`
(`live`/`dead`) and `pane_exit` (`status=<n>`/`signal=<n>`); the pair is what a machine consumer reads
as "dead pane with this evidence". A fourth `state` value was rejected: `panel/src/layout.ts` maps an
unknown value to the "no window" label, so a `dead` state would be rendered as `· 无窗口` — a false
statement in the PM's own console — and making the panel render it pulls in a third delta
(`panel`, its string tables and its snapshots) beyond policy B's two-delta budget. The panel's
existing `已退出` label stays true for a dead pane's seat; the distinction lives on the CLI and in the
extra fields.

### D6 — a dead pane is not a delivery target

Measured: `tmux send-keys` into a dead pane returns 0 while the text reaches nothing, so any
key-sending path that trusts the return code can report a delivery that never happened. The delivery
guards therefore consult `pane_dead` (not only the foreground command name) and fall back to the
durable inbox, with the output naming the seat as dead and its exit evidence.

### D7 — the anomaly criterion keeps deliberate windows quiet

A retained window is an anomaly only while the seat's recorded task is unfinished (the state file's
`task` is non-empty). `close --keep-window` clears it and `teardown` removes the window, so neither
can produce an "abnormal exit" line — the reverse fixture in the watchdog delta pins both, and the
pulse's stopped-agent count (which already keys on the recorded task) stays as it is.

### D8 — delta placement: `watchdog` + `dispatch`

The brief's policy B allows `pm-lifecycle` **or** `dispatch` for the launch/rebuild semantics; this
change takes `dispatch`, because every semantic change is on the agent window's launch and reuse path
(window creation, reuse message, delivery target) and the PM side is deliberately unchanged — its
liveness requirement would have no honest delta here (an ADDED restatement would duplicate
`pm-lifecycle`, and a MODIFIED would need a behavior change this design refuses). The visibility and
state vocabulary changes land in `watchdog`.

## Per-requirement review method (what the PM or the verifier re-runs)

| Requirement | How it is re-checked, and what a red looks like |
|---|---|
| `dispatch` · An agent window outlives its pane and keeps a bounded scene | Kill a dispatched fixture seat's pane group, then `tmux list-panes -t <session>:<agent> -F '#{pane_dead} #{pane_dead_signal}'` → `1 9`, `tmux capture-pane -p -S -` → the fixture marker, window still listed; `show-options -w -v -t <session>:<agent> remain-on-exit` → `on` while the PM window shows no setting. Red before: the window is gone and the marker is unreadable (probe P1). Mutation: force the creation site back to `remain-on-exit off` → the retention assertion must fail (`tests/flip-p49.sh`), restore → green. |
| `dispatch` · A dead pane is never a live seat, and reuse keeps its evidence | `team say <agent> "…"` against the corpse: the output must not contain the delivered confirmation, the inbox line must exist, and the pane's `capture-pane` must be byte-identical before/after; `TEAM_AGENT_SCENE_LINES=3 team dispatch …` must leave `state/dispatch-<agent>-pane-dead.txt` with ≤3 scene lines + the exit evidence, one window, and the message that the previous pane was dead. Mutations: (a) drop the `pane_dead` check → the `say` assertion must fail (the measured `send-keys` rc=0 makes it a false green otherwise); (b) skip the capture → the file assertion must fail. |
| `watchdog` · A dead pane is a seat condition with a readable scene, and never a running seat | The four-condition fixture read through `team roster`, `team __panel-data --block agents`, `team status <ID>`, `team digest` and `team doctor`; the state fingerprint before/after the reads must be identical; the closed-seat fixture must produce no anomaly and `team __panel-data --block pending`'s `stopped` must stay 0 for it while the unfinished-task seat is counted. Mutations: (a) let a corpse report `running` → the roster/machine assertion fails; (b) print a scene for a seat with no record → the “no scene block” assertion fails; (c) count a closed seat's retained window as an anomaly → the reverse-fixture assertion fails. |

## Risks / Trade-offs

- *Retained panes hold memory until reuse* → bounded by (seats × tmux `history-limit`), the reuse path
  is the existing dispatch flow, and `history-limit` is not raised.
- *`team_tmux_has_window` now returns true for a corpse* → every consumer that equates "window exists"
  with "seat is usable" must be audited (delivery guards, `resume`, dispatch's reuse message,
  `close`/`teardown`, the panel block); the change's task list carries that audit as its own item and
  the specs pin the outcomes.
- *A stale scene file could be read as the current death* → the reader orders the live dead pane first
  (a seat can only have one current death), and every printed scene names its source and that record's
  time.
- *A fast exit leaves almost nothing on the screen* → the exit evidence (`status`/`signal`/`time`) is
  the reliable part and the agent's own exit keeps its separate 200-line tail; the specs promise the
  scene, not a full transcript.
- *The option could hide a real "seat is gone" signal from scripts that count windows* → the machine
  block exposes `pane=dead`, and the roster condition keeps the corpse distinguishable from a live
  seat; the two surfaces are asserted in the same scenario.

## Migration Plan

No data migration. The behaviour applies to windows created after the skill upgrade; a window created
before it stays `off` until its seat is dispatched or resumed again (both reuse paths re-create the
window). Rollback is removing the option at the creation site; retained panes from before the rollback
are ordinary windows and are killed by the same `kill-window` path. The scene file and the machine
fields are additive: an older panel bundle ignores them, and `TEAM_AGENT_SCENE_LINES` unset means the
default 40.
