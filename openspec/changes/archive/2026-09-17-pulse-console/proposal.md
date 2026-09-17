# Propose: `pulse-console` — Pulse becomes the console

## Why

The approved design (`docs/team/designs/pulse-console.md`, user 2026-09-16) makes Pulse the console: the
human's message entry to the PM moves here; the board grows into three pages with settings, mouse, i18n and a
responsive layout. D26 accepted E6's feasibility run (5/5 measured, `docs/team/reports/E6-dev2.md`) with one
precondition: today's frame assembly blocks ≈7.2s (6.3s user CPU) on
`spawnSync` and distorts keystrokes, so data assembly goes async + cached before any input line ships.

## What Changes

In `panel` (merged, not a new capability — the tradeoff is design.md §1):

- **ADDED**: asynchronous cached frame assembly with per-block isolation; three pages + navigation + a remembered
  page; the compose entry (`m`, `C-e`, persisted draft, three-state receipt); the settings overlay on
  `state/panel.conf`; SGR mouse; zh/en string tables with a key-set gate; status never by color alone.
- **MODIFIED**: `--print`/`--json` pinned to the overview frame (pages are TUI-only); the tick loop gains the
  collapse-to-headless shape (`q`); the outbox stays read-only but `f` invokes `team outbox flush`;
  `TEAM_MONITOR_REFRESH` default 5s → 3s.
- **REMOVED**: the four-band layout requirement — superseded by a pure `layout(width, height)` with four tiers.

In `watchdog`: **MODIFIED** — one backend, one window, two shapes (console ⇄ headless ticker).

## Capabilities

### Modified Capabilities

- `panel`: the console is what `team monitor` renders.
- `watchdog`: the one-backend requirement names the patrol window's two shapes.

## Impact

Apply-phase code (not this phase): `scripts/panel/src/**`, `scripts/lib/cmd-watch.sh`, `tests/smoke.sh` (new
subsections; 26-a…26-n untouched), E6's pty fixtures move into `tests/`, `references/config.md` registers the new
state files. At archive the `panel` spec is rewritten; one `watchdog` requirement is modified.

## The five answers (brief)

1. **Batches**: B1 async + cache (the D26 precondition, E6 §0 numbers) → B2 compose entry → B3 pages, overlay,
   mouse, i18n, responsive, collapse — one apply brief per batch, in order.
2. **v1 cut**: plain `[v1.1]` bullets in tasks.md, never checkboxes: Enter drill-down, queue discard, the
   milestone bar/tree (no machine-readable ROADMAP), the gates-record point, `draft send --json`.
3. **Tests**: four widths × two themes snapshots; E6's pty mouse/compose scripts become fixtures; the zh/en
   key-set assertion joins the gate; a compose fixture proves the draft survives a refresh.
4. **Compat**: `--print`/`--json` keep today's invariants (0 ESC, exit 0, no state writes, same JSON keys —
   additive only); smoke 26-a…26-n stay green; `TEAM_MONITOR_UI` values unchanged.
5. **panel.conf vs config.sh**: `panel.conf` holds per-human view prefs (language, default page, activity columns,
   mouse, density) — runtime state, defaults when missing/corrupt, never read by `--print`/`--json`; the `TEAM_*`
   keys stay the project contract.

## Acceptance (verbatim)

```sh
openspec validate --all --strict
openspec change show pulse-console
```

## Boundaries

- This phase writes only `openspec/changes/pulse-console/**` and `docs/team/reports/P11-dev2.md`; no code, no
  `openspec/specs/**`, no ledger.
- v1 excludes the `[v1.1]` list, agent control, page history (use logs) and credential files.

## Evidence the report must contain

Both acceptance tails; the hand-check of every MODIFIED/REMOVED name and scenario heading against
`openspec/specs/**` (the v1.8.0 `validate` hole, D23); the requirement → task coverage map.
