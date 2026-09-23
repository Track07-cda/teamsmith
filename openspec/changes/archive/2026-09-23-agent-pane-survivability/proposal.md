# agent-pane-survivability · proposal

## Why

On 2026-09-22 two seats went silent — dev-bob at 09:34:03, dev3 at 09:35:57 — and `team roster` then
showed `· 无窗口`: window, process **and the pane's scene** were gone together. No OOM entry since
09:30 and no tmux-shim call in 09:30–09:36, so *why* the panes died is unknown — not because nobody
asked, but because the evidence died with the pane. Both seats held uncommitted work (6 and 4 files)
and the PM could only hand-snapshot it into `wip(...)` commits. Nothing survives the pane dying, and
nothing distinguishes "the agent exited, the window waits for `team resume`" from a corpse.

## What Changes

- **ADDED — `dispatch`**: the windows `dispatch`/`resume` create get tmux `remain-on-exit` **before**
  their command can exit, so a dying pane leaves the window, its last screen and tmux's exit evidence
  (`pane_dead_status`/`pane_dead_signal`/`pane_dead_time`) behind. A dead pane is never a live seat or
  a delivery target — `send-keys` into one returns success while the text reaches nothing — and reuse
  captures the scene to `state/dispatch-<agent>-pane-dead.txt` before replacing the corpse. The PM and
  pulse windows keep the option **off**: PM liveness stays proof-based (`pm-lifecycle`).
- **ADDED — `watchdog`**: the seat condition gains a machine-readable dead-pane case beside
  `running`/`exited`/`absent`, whose proof rule is untouched; `team status <ID>` prints the condition,
  the exit evidence and the last `TEAM_AGENT_SCENE_LINES` (default 40) lines of the newest record
  with its source and time; `team doctor` names a dead seat in one warning and is silent when none is
  dead. A retained window is an anomaly only while its seat has an unfinished recorded task —
  `close --keep-window` and `teardown` stay quiet, pinned by a reverse fixture.
- **Bounds**: one retained pane per seat, its scrollback bounded by tmux's own `history-limit`
  (untouched), the captured/printed copy bounded by one knob; no timer, no new backend.

## Capabilities

### New Capabilities
- (none)

### Modified Capabilities
- `dispatch`: the agent window's life around its pane's death — retention, delivery refusal, reuse.
- `watchdog`: the seat condition vocabulary, its scene, its surfaces and the anomaly criterion.

## Flip

Red before: kill a fixture seat's pane process group → the window is gone, `team roster` says
`· 无窗口`, and nothing says how it died. Green after: the same kill leaves the window with
`pane_dead=1`, the last screen readable, and `signal=9` as exit evidence; and "break the
implementation → the guard must fail": forcing the option to `off` in the fixture makes the retention
assertion red, restoring it makes it green.

## Boundaries

Propose only: no `skills/**` change in this phase, and no edit to the base specs (a delta is not a
merge). Out of scope: `remain-on-exit` for the PM or pulse window, a new PM liveness state, panel
rendering of the new fields, a pulse-tick writer, and explaining the 2026-09-22 deaths. Rejected in
design.md: a session-wide option default, a watcher daemon, relying on the harness's trailing
`exec bash`.

## Acceptance

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
git status --porcelain
```

## Evidence the report must contain

The validate and smoke tails, and the private-socket tmux probe behind this proposal's facts:
`remain-on-exit` set via placeholder → respawn leaves the window with `pane_dead_status`/
`pane_dead_signal` and a readable `capture-pane`; `send-keys` into a dead pane returns 0;
`respawn-pane -k` reuses the corpse; the PM window's option stays off.
