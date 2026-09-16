# Tasks: rename-watchdog-to-pulse

Two apply briefs (checklist #8: one cannot finish this). **A1** moves behavior and tests, **A2** moves docs and the
release. Items are in dependency order; each names the capability it moves and the command that can fail.

Path grants the apply briefs must state (OWNERSHIP): `skills/teamsmith/scripts/**`, `skills/teamsmith/SKILL.md`,
`skills/teamsmith/references/**`, `skills/teamsmith/templates/**`, `skills/teamsmith/CHANGELOG.md` are PM-owned —
the brief grants them explicitly; `skills/teamsmith/tests/**` is agent:dev. `.pi/team/config.sh`, `AGENTS.md` and
`docs/team/**` stay PM-owned: the PM migrates them after the merge (or grants them in A2's brief explicitly).

**Real-process items** are marked `[real]` — they need tmux; each also has a headless fixture (env resolution,
dispatch text, `paths` JSON), so no single real-process run is the only evidence for a requirement.

## A1 — behavior (apply brief 1)

### 1. Command group and aliases (`watchdog`: "The old command names keep working during the alias period"; "One backend …")

- [x] 1.1 `scripts/team` + `lib/cmd-watch.sh` — rename the implementation to `team_cmd_pulse` (keeping `--print`
  and the `--container` refusal), add `pulse` dispatch, and make `watchdog`, `watchdog-status`,
  `install-watchdog`, `uninstall-watchdog` wrappers that print exactly
  `[deprecated] team watchdog 已改名 team pulse（别名保留到 v2.0.0）` as stdout's first line and then call the pulse
  implementation. Internal callers (`lib/cmd-bootstrap.sh:129`, `lib/cmd-update.sh`, `lib/common.sh`) must call the
  pulse functions so they print nothing.
  Verify: `team pulse status` exits 0 and its first line is not the deprecation line; `team watchdog status` exits
  0 with that exact first line and the pulse status body after it; `git grep -n 'team_cmd_watchdog'` shows only the
  alias wrapper.
- [x] 1.2 `lib/cmd-watch.sh` window resolution — `team_pulse_window()` = `TEAM_PULSE_WINDOW` → `TEAM_WATCH_WINDOW`
  → `pulse`; the legacy probe (resolved window absent, `watchdog` window present) backs `status`/`logs`/state,
  makes `up` create nothing and name `team pulse restart`, makes `down`/`restart` end both names, and `restart`
  leaves exactly one window named by `TEAM_PULSE_WINDOW`.
  Verify `[real]`: in a sandbox session (isolated tmux server + temp repo, smoke §14 style): `pulse up` creates
  one `pulse` window and no `watchdog` window; with a `watchdog` window present `pulse up` creates no `pulse`
  window and its output names `watchdog` and `team pulse restart`; `pulse restart` leaves exactly one window named
  `pulse`. Headless part: `team pulse up --print` names the resolved window.

### 2. Environment resolution, state files, nudges (`watchdog`: ADDED "Legacy environment variable names …", R2/R3/R4/R5)

- [x] 2.1 `lib/common.sh` (or `lib/cmd-watch.sh`) — one resolver `team_pulse_var NAME default` implementing
  `TEAM_PULSE_<NAME>` > `TEAM_WATCH_<NAME>` > default for the six names in `design.md` §3.2; route every reader
  through it; `team pulse status` names each legacy variable it fell back to.
  Verify: `TEAM_PULSE_INTERVAL= TEAM_WATCH_INTERVAL=17 team pulse status` reports `17s` **and** names
  `TEAM_WATCH_INTERVAL`; `TEAM_PULSE_INTERVAL=11 TEAM_WATCH_INTERVAL=17 team pulse status` reports `11s` and names
  no legacy variable; `team pulse status --print`/`up --print` respect the same precedence.
- [x] 2.2 `lib/common.sh:1747-1755` + `lib/cmd-status.sh` — the nudge text becomes `[pulse] 待办：…`, the panel
  header `teamsmith pulse · …` and the panel/footer hints name `team pulse …`.
  Verify `[real]`: a sandbox tick with one unread inbox line types one `[pulse] 待办：` line into the PM pane and
  `state/nudges.log` gains one line; `team monitor --once` (or `panel`) shows `teamsmith pulse`.
- [x] 2.3 state files — the patrol keeps `state/watchdog.log|pid|last|nudge|tick.log` and creates no
  `state/pulse.*` (`design.md` §3.4).
  Verify: `team watch --once` in a temp repo updates `state/watchdog.last`, appends `state/capacity.log`, and
  `find "$TEAM_STATE_DIR" -name 'pulse.*'` is empty; two concurrent `watch` loops still refuse via the one
  `watchdog.pid`.

### 3. Reporting surface (`watchdog`: ADDED "The read-only commands report the pulse surface")

- [x] 3.1 `lib/common.sh:282-290` (`team_paths_json`) — add `"pulse_window"` (resolved) and `"pulse_interval"`
  (effective seconds); keep every existing key.
  Verify: `team paths | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["pulse_window"] and d["pulse_interval"]; print(d["pulse_window"], d["pulse_interval"])'`
  prints the resolved values; with `TEAM_WATCH_INTERVAL=17` it prints `17`.
- [x] 3.2 `lib/cmd-project.sh:366-368` — the doctor check names the backend `pulse` and, under a legacy source,
  names the variable (e.g. `pulse 在跑（legacy: TEAM_WATCH_INTERVAL=17）`).
  Verify: `TEAM_WATCH_INTERVAL=17 team doctor` output names `pulse` and `TEAM_WATCH_INTERVAL`; with only
  `TEAM_PULSE_INTERVAL=11` it names neither legacy variable.
- [x] 3.3 `lib/cmd-project.sh:40-48` and `lib/cmd-bootstrap.sh:35,42,80,88,127-141` — help/plan/next-steps text
  uses the `pulse` group and `--no-pulse`; `--no-watchdog` stays accepted.
  Verify: `team help` lists `pulse up|down|restart|status|logs`; `TEAM bootstrap --no-pulse --print` and
  `TEAM bootstrap --no-watchdog --print` both skip the window and print the pulse wording.

### 4. Tests and gates (`watchdog`: every requirement above)

- [x] 4.1 `skills/teamsmith/tests/smoke.sh` — update the 84 watchdog/watch references and the window-name
  assertions to the pulse surface; add: alias first-line + body equality (1.1), env precedence (2.1), the legacy
  window migration sandbox (1.2), `state/watchdog.*` untouched/no `pulse.*` (2.3), `paths`/`doctor` (3.1/3.2),
  bootstrap flag (3.3). Mark the tmux ones `[real]`.
  Verify: `bash skills/teamsmith/tests/smoke.sh` exits 0 and prints no FAIL; `TEAM_SMOKE_FAST=1 bash …` exits 0;
  the new sections fail when the deprecation line (or the precedence) is broken — flip that by hand once and
  record it in the report.
- [x] 4.2 `openspec validate --all --strict` and `bash skills/teamsmith/tests/spec-lint.sh` stay green with the
  code changed (the delta describes the shipped surface).
  Verify: both exit 0 on the branch tip.

## A2 — docs, templates, release (apply brief 2)

- [x] 5.1 `references/config.md`, `references/protocol.md`, `references/workflows.md`,
  `references/troubleshooting.md`, `references/bootstrap.md`, `references/migration.md` — pulse surface, the
  precedence table, the migration steps of `design.md` §4, and the "state file names stay `watchdog.*` until
  v2.0.0" note.
  Verify: `grep -rn 'team watchdog' skills/teamsmith/references/` returns only lines that explicitly document the
  alias/migration (each line contains `alias`, `deprecated` or `改名`); `references/config.md` names all six
  `TEAM_PULSE_*` variables and the fallback rule.
- [x] 5.2 `references/philosophy.md`, `references/memory.md`, `references/agent-adapters.md`, `SKILL.md`
  (description + command table + patrol section + troubleshooting pointer) — same sweep; the SKILL command table
  row becomes `Pulse | team pulse up|down|restart|status|logs …`.
  Verify: `grep -c 'pulse' skills/teamsmith/SKILL.md` ≥ 13 and `grep -n 'team watchdog' skills/teamsmith/SKILL.md`
  shows only alias-deprecation lines.
- [x] 5.3 `templates/**` — `AGENTS.section.md.tmpl`, `PROTOCOL.md.tmpl`, `pm-prompt.md.tmpl`,
  `config.sh.tmpl` (write `TEAM_PULSE_*` with the legacy names in a comment), `memory-seed.md.tmpl`,
  `bootstrap-prompt.md.tmpl`.
  Verify: `bash skills/teamsmith/tests/smoke.sh` bootstrap section asserts the rendered plan contains `pulse up`
  and the generated config contains `TEAM_PULSE_INTERVAL`; `grep -rn 'TEAM_WATCH_' skills/teamsmith/templates/`
  returns only the legacy comment.
- [x] 5.4 `CHANGELOG.md` — new entry "watchdog 改名为 pulse（v1.32.0）：命令组 `team pulse`、窗口
  `teamsmith:pulse`、`TEAM_PULSE_*`；旧名/旧变量保留到 v2.0.0" + the alias/state-file decisions; older entries
  untouched. Bump `TEAM_VERSION` (`lib/common.sh:6`) and SKILL.md `metadata.version` to 1.32.0.
  Verify: `bash skills/teamsmith/scripts/team version --check` reports disk == SKILL.md (and names the new
  version); `git diff --stat` shows the CHANGELOG adds one entry and changes no older line.
- [x] 5.5 Final gate on the branch tip: `openspec validate --all --strict` && `bash
  skills/teamsmith/tests/spec-lint.sh` && `bash skills/teamsmith/tests/smoke.sh`.
  Verify: three exit codes 0, with the output tails in the report.
