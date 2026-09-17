# Design: `pulse-console`

## Context

See proposal.md → Why. The load-bearing facts, all measured in E6 (`docs/team/reports/E6-dev2.md`, accepted as
D26): today's frame assembly is one `spawnSync` of ≈7.2s wall / 6.3s user CPU (one `watchdog-status` trace alone
spawns git×111, grep×331, sed×211), and keystrokes arriving inside that window are distorted (§2.3); the tick
loop is owned by the panel process itself (`scripts/lib/cmd-watch.sh`); the guarded headless send path
(`team draft send`, rc + outcome tokens) already exists (§2.5); mouse, CJK input, the editor relay, string
tables and resize were all verified feasible on the pinned Ink 7.1.1 (§1). The approved UI/interaction design is
`docs/team/designs/pulse-console.md` — it is the source of truth for what the console looks like; this document
only records the decisions the design does not make.

## Goals / Non-Goals

**Goals:** an asynchronous, cached data layer under the red line (3s cadence, <1% CPU, undistorted keystrokes);
the compose entry with an honest receipt; three pages + settings overlay + mouse + i18n + responsive tiers; the
collapse-to-headless shape.

**Non-Goals:** the `[v1.1]` list in tasks.md; agent control of any kind; changes to `delivery-guard` semantics
(no `draft send --json` in v1); a machine-readable ROADMAP format; page history; the PM-side notification
channel.

## Decisions

### §1 Capability placement: merge into `panel`, one MODIFIED on `watchdog`

The console **is** what `team monitor` renders — one surface, one spec. A new `pulse-console` capability would
duplicate the Purpose, force cross-references between two panel-ish specs, and still need MODIFIED deltas on
`panel` for the layout/tick/outbox/keys requirements. MODIFIED keeps the evolution readable. The one exception
is `watchdog`'s "one backend" requirement: its "the window MUST also serve as the status monitor" would
contradict the collapsed (headless) shape, so it gains the two-shape sentence. No other capability changes:
`delivery-guard` keeps owning send/flush semantics, `watchdog` keeps owning standby semantics — the console only
invokes their commands.

### §2 Batches: B1 async → B2 compose → B3 surface, one apply brief each

Order is forced, not aesthetic: an input line on the blocking data layer is unusable (E6 §2.3, both distortion
shapes measured), so B1 lands first; compose must exist on every page, so pages come after it (B3); i18n comes
last so the string tables are extracted from final text, not translated twice. Each batch is one apply brief
with its own independent verification before the next is dispatched (references/openspec.md §1, gate 3).

### §3 Async architecture: spawn + cache + per-block builders, readers trimmed

`data.ts` drops `spawnSync`; per-block builders run as child processes with individual timeouts and write an
in-memory cache; the renderer reads only the cache. The bash reader tree is trimmed (git×111/grep×331/sed×211 is
the cost driver — E6 §2.3) by aggregating reads. Red line (spec): uncached frame ≤2s on the reference checkout,
steady-state CPU <1% of one core. Stale-cache risk is accepted: the cadence is 3s and the three actions
invalidate the cache on completion.

### §4 Compose goes through `team draft send`; the renderer never touches the PM pane

The console writes `state/draft.md` and runs the existing guarded command; the receipt maps its rc + outcome
token to delivered / queued / held (E6 §2.5) — no `--json` addition in v1 (nice-to-have, `[v1.1]`). Draft state
is ref-first (§2.4: render-time state is stale under input storms), `\r` is normalized on intake (§2.2), and the
`C-e` relay explicitly gates the async render callback while `$EDITOR` owns the terminal (§3.8 — the prototype
was serial by accident; the real one is not).

### §5 The machine exits are frozen

`--print` keeps its pre-console frame shape (overview content, key line last); `--json` keeps its keys,
additive-only (`panel.refresh_s` is the one addition). Pages, the overlay and the mouse are TUI-only and never
read `state/panel.conf` — smoke 26-a…26-n stays green unmodified.

### §6 `state/panel.conf` precedence and boundaries

Precedence for the activity columns: CLI flags > `panel.conf` > `TEAM_MONITOR_ACTIVITY` > built-in default —
and only inside the TUI. `panel.conf` is runtime state (uncommitted, lives next to the other state files),
defaults on missing/corrupt, and is registered in `references/config.md` and the state-file docs (E6 §3.7).
Everything in `config.sh` stays the project contract; nothing moves from one file to the other.

### §7 Collapse is a respawn, not a second process

`q` rebuilds the patrol window in place (`tmux respawn-window -k`) running `team monitor --headless` — a new
flag that runs the tick loop with no renderer. `team pulse up` against a headless window respawns it with the
console. One window, one process, no orphan in either shape; `team pulse status` reports the shape. This is the
new mechanism E6 §3.5 flagged as "not wiring" — it is why `watchdog` is in the delta at all.

### §8 E6's open points, resolved

- §3.2 (banner counts gated by `TEAM_PULSE_PENDING_BOARD`): **no change in v1** — the banner keeps showing the
  same counts the patrol acts on; changing the gate's default is a separate decision, not smuggled into a UI
  change.
- §3.3 (blocks with no machine-readable source): board rows, changes+phases, spec counts, decisions, outbox
  list, inbox/threads and the patrol log get read-only cached readers; the milestone bar/tree is `[v1.1]` (needs
  a ROADMAP format decision); the "last gates" cell renders `—` until a record point exists (`[v1.1]`).
- §3.4 (the queue's discard action): **out of v1** — the design's discipline says three actions; discard is a
  fourth and destructive one, so it waits for the user's call (`[v1.1]`). View-full is read-only and stays.
- §3.6 (`--print` shape under pages): frozen to the overview (§5 above) — one sentence, as E6 asked.
- §3.7 (new state files): registered, see §6.
- §3.8 (C-e vs async refresh): the render gate, see §4.

### §9 Mouse, i18n, themes: use E6's evidence, not new inventions

Mouse = two enable/disable sequences + one tolerant regex (Ink strips the leading ESC — E6 §1.1c); tests are
pty-driven because `tmux send-keys` cannot inject `0x1b` (E6's methodology note) — E6's `pty_mouse.py` /
`pty_tmux_mouse.py` move into `tests/`. String tables live in `panel/src/strings/{zh,en}.ts`, compiled into the
single bundle (the bundle requirement is untouched); the key-set assertion (E6 §1.4's `assert-strings.mjs`)
joins `smoke.sh`. Theme auto-detects from the terminal background, pinnable via the `theme` key in
`panel.conf` (not an overlay item — the design's overlay has exactly five); the gate computes WCAG contrast over
the declared palettes, and the snapshot suite pins four widths × two themes.

## Risks / Trade-offs

- [Async cache shows stale data between cadences] → 3s cadence + invalidation after the three actions; a block
  that misses its deadline renders `—` rather than last-week's number dressed as fresh (the age is a design
  detail the apply brief may add if cheap).
- [pty fixtures flake under load] → they follow smoke's existing private-socket isolation (`-L` socket, fixture
  projects), carry the `[real]` mark, and every pty assertion has a headless sibling so no requirement hangs on
  a real pane alone.
- [The v1.8.0 `validate` hole lets a bad MODIFIED through] → the P11 report carries the hand-check table
  (names + scenario headings against `openspec/specs/**`); the PM's phase-5 trial archive is the backstop (D23).
- [`TEAM_MONITOR_REFRESH` 5s→3s surprises existing users] → it is a documented contract change, same mechanism
  as the earlier `TEAM_MONITOR_ACTIVITY` default change; `panel.refresh_s` makes the effective value visible.
- [Scope creep via "while we're in there"] → the `[v1.1]` list is explicit, and the PM's proposal-review
  checklist item 1 (matches the approved exploration) is the gate.

## Open Questions

None that change the specs or the task split. The machine-readable ROADMAP format (prerequisite for the v1.1
milestone bar) belongs to whichever future change wants it.
