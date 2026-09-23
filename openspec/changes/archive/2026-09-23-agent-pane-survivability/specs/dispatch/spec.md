## ADDED Requirements

### Requirement: An agent window outlives its pane and keeps a bounded scene

`team dispatch` and `team resume` SHALL create the window they dispatch into with tmux's
`remain-on-exit` enabled **before** that window's command can exit: the window is created holding a
placeholder command, the option is set and read back, and only then does the real harness take the
pane. The option SHALL be enabled for the windows `dispatch`/`resume` create and MUST NOT be added to
the PM window or to the pulse window — their shape is unchanged — while the draft window keeps the
setting it already has. When the pane's process exits for any reason, a signal included, the window
SHALL remain with `pane_dead=1`, its last output SHALL stay readable through `tmux capture-pane` on
that window read **with its scrollback** (`-S -`; the visible screen alone can lose the last line —
measured), and tmux's exit evidence (`pane_dead_status`, `pane_dead_signal`, `pane_dead_time`)
SHALL be readable from it. Retention SHALL be bounded without a timer: at most one retained pane per
seat window (the seat's next `dispatch`/`resume` replaces it, after capturing its scene), the retained
scrollback stays bounded by the host's `history-limit` (a session-wide option this change neither
raises nor narrows), and the copy the tool captures or prints is bounded by `TEAM_AGENT_SCENE_LINES`
(default 40; a non-numeric value falls back to the default). A live seat SHALL be unaffected by the
option: the launch proof, the exit-event file and the recorded-task semantics stay exactly as
`dispatch` defines them. Reading a retained pane — the four seat conditions, where the scene comes
from, what `status=`/`signal=` mean, and why the PM window deliberately has no retention — is
documented in `skills/teamsmith/references/troubleshooting.md` §11b.

#### Scenario: A killed pane leaves a readable corpse instead of an empty window list

- **GIVEN** a dispatched seat `<agent>` whose window was created by `team dispatch`, holding a fixture
  agent that printed a marker line which has appeared in the pane (polled for, not assumed)
- **WHEN** the pane's process group is killed with SIGKILL and then
  `tmux list-panes -t <session>:<agent> -F '#{pane_dead} #{pane_dead_signal}'` and
  `tmux capture-pane -p -S - -t <session>:<agent>` are read
- **THEN** the window still exists, `pane_dead` is `1`, `pane_dead_signal` is `9`, and the capture
  still contains the fixture agent's marker line
- **AND** `tmux kill-window -t <session>:<agent>` still removes it (the retained window is not a
  window that cannot be cleaned up)

#### Scenario: The option is on for agent windows only, and a normal exit keeps its meaning

- **GIVEN** a project whose PM window exists (started with `team up`) and one dispatched seat
- **WHEN** the option is read from both windows and the fixture agent of a second seat exits `0`
- **THEN** the agent window's `remain-on-exit` reads `on`, while the PM window carries no
  window-level setting for it (its effective value stays tmux's default, `off`)
- **AND** the exited agent's window still exists with a live pane (no `pane_dead`), `team roster`
  reports it as the exited condition rather than the dead one, and `team resume --agent <agent>`
  starts the same recorded task again leaving exactly one window for that seat

### Requirement: A dead pane is never a live seat, and reuse keeps its evidence

A pane whose `pane_dead` is `1` MUST NOT be treated as a live seat or as a message delivery target.
The fallback itself is `notify-and-inbox`'s (*Messages to a stopped agent fall back to the inbox*);
what this requirement fixes is the evidence that decides it, because with a retained corpse the
foreground command name can still look like a running CLI and tmux's `send-keys` returns success into
a dead pane while the text reaches nothing. The key-sending paths (`team say`, and a `team notify`
knock against that seat) SHALL therefore decide on the pane being dead, MUST NOT report delivery to
it, and SHALL leave the recipient's message durable in `docs/team/inbox/<agent>.md` while the output
names the seat as dead together with its exit evidence when that evidence is known. Before `dispatch`,
`dispatch --fresh` or `resume` replaces a dead pane's retained window, the tool SHALL capture the pane
into `state/dispatch-<agent>-pane-dead.txt`, holding the seat, the window, the timestamp, the exit
evidence and the last `TEAM_AGENT_SCENE_LINES` lines of the scene, and the dispatch output SHALL say
the previous pane is dead instead of the wording used when a live round is being interrupted. Reuse
SHALL remain a reuse: those three commands over a dead-pane seat leave exactly one window for the
seat, and the ordinary launch-proof rules are unchanged (this round's nonce decides; a record left by
a previous round is not evidence for this round). `teardown --agent` SHALL remove the retained window
like any other.

#### Scenario: A message to a dead seat is queued durably, never reported as delivered

- **GIVEN** a seat with an unfinished recorded task whose pane is dead (`pane_dead=1`,
  `pane_dead_signal=9`) and whose last screen holds a marker line
- **WHEN** `team say <agent> "P49 dead-pane probe"` runs
- **THEN** the output contains no delivered confirmation and names the seat as dead with `signal=9`
- **AND** `docs/team/inbox/<agent>.md` gained the `P49 dead-pane probe` line, and the dead pane's
  screen is byte-identical to what it was before the command

#### Scenario: Reuse captures the scene before it replaces the corpse, and stays one window

- **GIVEN** the dead-pane seat of the previous scenario with at least three marker lines on its
  retained screen and `TEAM_AGENT_SCENE_LINES=3`
- **WHEN** `team dispatch <agent> <ID> <brief>` (and then, in an equivalent fixture,
  `dispatch <ID> --fresh` and `resume --agent <agent>`) runs
- **THEN** `state/dispatch-<agent>-pane-dead.txt` exists before the window is replaced, carries the
  exit evidence and at most three scene lines including the fixture's marker line
- **AND** the output states that the previous pane was dead, exactly one window exists for that seat
  afterwards, its `remain-on-exit` is `on`, and the normal launch proof for the new round holds
- **AND** `team teardown --agent <agent>` removes that window, after which `team roster` reports the
  seat as having no window
