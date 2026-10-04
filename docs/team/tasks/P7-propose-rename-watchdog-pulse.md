# P7 · Propose: `rename-watchdog-to-pulse` (D22)

```
task:   P7
agent:  dev2
phase:  propose
change: rename-watchdog-to-pulse
deps:   D22 (user picked `pulse`), v1.31.0
```

> Phase 2. The decision is made (D22: the name is `pulse`); your job is the migration design as change artifacts.
> **Planning only** — no code, no `openspec/specs/**`. PM reviews before apply.

## What must be designed

1. **Surface inventory** (with commands, not from memory): every place the old name appears — `team watchdog`
   subcommands, `team watch`, the `teamsmith:watchdog` tmux window, `TEAM_WATCH_*` env vars, `state/` file names
   (`watchdog.log`, `watchdog.nudge`, …), `references/**`, `templates/**`, `SKILL.md`, `openspec/specs/watchdog/**`
   requirement texts, smoke assertions, and the CHANGELOG convention (history keeps the old name).
2. **The new surface**: `team pulse up|down|restart|status|logs` + `team pulse` as the command group, window
   `teamsmith:pulse`, `TEAM_PULSE_*` vars. Backwards compatibility: `team watchdog …` and the old window name keep
   working as aliases for one major version (printed deprecation line), old `TEAM_WATCH_*` vars still read
   (env precedence documented), old `state/` file names kept or migrated on first run (choose one, say why).
3. **The spec question to decide with evidence**: the capability directory `openspec/specs/watchdog/` — does this
   change (a) keep the capability name `watchdog` and use MODIFIED deltas to rename only the user-facing surface
   inside requirement texts, or (b) create `pulse` as a new capability and retire `watchdog`? OpenSpec has no
   capability-rename delta operation; if (b), state exactly how the old spec directory is retired at archive time
   (what archive does, what the PM does manually, and what proves nothing was lost). Pick one and justify.
4. **The migration story**: what an existing project (a running `teamsmith:watchdog` window, cron-like habits,
   scripts calling `team watchdog`) experiences across the upgrade — the rename lands *ahead* of D19's TUI rewrite
   so that rewrite starts from the new names (D22). The alias period's end condition (which major version drops it).
5. **Falsifiable scenarios** for the delta: alias still works, deprecated line printed, new window name used by
   `team pulse up`, old `TEAM_WATCH_INTERVAL` still honoured, `team doctor`/`paths` report the new surface, and the
   migration of an existing project (fixture: an old config + a running old-named window in a sandbox session).

## Evidence for the PM review

- `openspec change show`, `openspec validate --all --strict`, `spec-lint.sh` green with the change present; a scratch
  `openspec archive -y` showing exactly the promised operations (and, if you chose (b), what remains for the PM).
- `docs/team/reports/P7-dev2.md`: the inventory (with grep evidence), the (a)/(b) decision with reasons, the alias
  design, and the migration narrative.

## Boundaries

Only `openspec/changes/rename-watchdog-to-pulse/**` + your report. Never `openspec/specs/**`, no code. Do not
dispatch, do not archive.

## Acceptance

```sh
openspec validate --all --strict
bash skills/teamsmith/tests/spec-lint.sh
git status --porcelain   # only the change dir + your report
```
