# Design: `watchdog` → `pulse`, one major version of aliases

Change `rename-watchdog-to-pulse` · phase: propose (planning only). The name `pulse` is D22's (user pick); this
document is the migration design the brief asks for. Every count and path below comes from a command run in the
task worktree at `b2ba442` (= v1.31.0); the raw output is `docs/team/reports/P7-dev2/inventory.txt`.

## 1. Surface inventory

### 1.1 Commands and flags

| Surface | Where | What changes |
|---|---|---|
| `team watchdog up\|down\|restart\|status\|logs` | `scripts/team:87`, impl `lib/cmd-watch.sh:516` | canonical group is `team pulse`; old name is an alias that prints one deprecation line |
| `team watchdog-status` | `scripts/team:88`, `lib/cmd-watch.sh:548` | alias of `team pulse status` + line |
| `team install-watchdog` / `team uninstall-watchdog` | `scripts/team:85-86`, `lib/cmd-watch.sh:545-546` | already legacy aliases of up/down; keep, add the line |
| `team watch [--once] [--interval N] [--ui]` | `scripts/team:83`, `lib/cmd-watch.sh:324` | name unchanged (D22 scoped the rename to the group, window and env prefix) |
| `team monitor … --no-watchdog` | `scripts/team:84`, `lib/cmd-watch.sh:386` | `--no-pulse` canonical; old flag still accepted |
| `team bootstrap … --no-watchdog` | `lib/cmd-bootstrap.sh:42` | same flag handling |
| command help | `lib/cmd-project.sh:40-45` | new group; aliases listed as aliases |
| `team doctor` | `lib/cmd-project.sh:366-368` | backend called `pulse`; legacy window/variable named |
| `team paths` JSON | `lib/common.sh:282-290` | adds `pulse_window`, `pulse_interval` |
| `status` / `ps` / `digest` / panel | `lib/cmd-status.sh:280,382,387,393,563-565,595-596` | pulse labels; reads the same state files |

The deprecation line lives in the CLI dispatch/alias wrapper (a new `team_cmd_pulse` holding today's
`team_cmd_watchdog` body; `team_cmd_watchdog` becomes the wrapper), so internal callers (`bootstrap` calls
`team_watch_tmux_up`/`team_cmd_watchdog`) do not print it. Apply must switch those internal callers to the pulse
functions.

### 1.2 Window name and environment variables

- Window: `team_watch_window()` (`lib/cmd-watch.sh:475`) returns `${TEAM_WATCH_WINDOW:-watchdog}`. New default
  `pulse` under `TEAM_PULSE_WINDOW`.
- Variables that a script actually reads (occurrences in the whole repo): `TEAM_WATCH_REBUILD_TMUX` 42,
  `TEAM_WATCH_INTERVAL` 30, `TEAM_WATCH_MAX_RESTARTS` 27, `TEAM_WATCH_PENDING_BOARD` 19, `TEAM_WATCH_NUDGE_GAP` 15,
  `TEAM_WATCH_WINDOW` 7.
- Stale keys with **no reader** under `skills/teamsmith/scripts/**`: `TEAM_WATCH_BACKEND`, `TEAM_WATCH_IMAGE`,
  `TEAM_WATCH_BOX`, `TEAM_WATCH_RETRY_SEC` (the container backend was removed in v1.12.0). They survive only in
  this repo's own tracked `.pi/team/config.sh:57,67-69` and in CHANGELOG history. They are not renamed and not
  part of the contract; the live-config migration step drops them.

### 1.3 State files

| File | Written/read at | Decision |
|---|---|---|
| `state/watchdog.log` | `cmd-watch.sh:11,341`; `cmd-status.sh:595` | keep the name for the alias period |
| `state/watchdog.pid` (patrol lock) | `cmd-watch.sh:26-43,453` | keep — two lock names would let two patrols run |
| `state/watchdog.last` | `cmd-watch.sh:212` | keep |
| `state/watchdog.nudge` (batch signature) | `common.sh:1748` | keep |
| `state/watchdog.tick.log` | `cmd-watch.sh:401` | keep |
| `state/capacity.log`, `nudges.log`, `standby`, `pm.pid`, `pm-start-attempts.log` | | already neutral; unchanged |

### 1.4 Docs, templates, tests, spec

`grep -c 'watchdog\|WATCH\|看门狗'` per file: `SKILL.md` 13, `CHANGELOG.md` 16, `references/troubleshooting.md` 25,
`references/workflows.md` 26, `references/bootstrap.md` 16, `references/protocol.md` 14, `references/config.md` 10,
`references/migration.md` 7, `references/agent-adapters.md` 6, `references/memory.md` 4, `references/philosophy.md` 1,
`templates/pm-prompt.md.tmpl` 9, `templates/AGENTS.section.md.tmpl` 7, `templates/config.sh.tmpl` 6,
`templates/PROTOCOL.md.tmpl` 6, `templates/memory-seed.md.tmpl` 4, `templates/bootstrap-prompt.md.tmpl` 1,
`tests/smoke.sh` 84 matching lines (file is 4563 lines; §11b and §6i are the tmux segments). Spec:
`openspec/specs/watchdog/spec.md` 6 requirements / 10 scenarios, plus `AGENTS.md` (6), `docs/team/PROTOCOL.md` (6)
and `.pi/team/config.sh` (10) as this project's live copies.

### 1.5 History — never renamed

`CHANGELOG.md` version entries, `docs/team/DECISIONS.md`, `docs/alignment-cep-reply.md`, `docs/team/reports/**`
and `docs/team/reviews/**` keep the old name: they record what shipped when. The CHANGELOG entry for this change
says "watchdog 改名为 pulse" in its own words and never rewrites older entries.

## 2. Capability decision: keep `watchdog` as the spec id (option a)

**Decision: (a).** `openspec/specs/watchdog/spec.md` stays the home of these six requirements; this change renames
the user-facing surface with `## MODIFIED` deltas and adds the alias/legacy/migration promises as `## ADDED`
requirements inside the same capability. The capability directory id is an **identifier**, not a user-facing name:
the H1 and Purpose become `pulse Specification` / pulse prose in the archive commit (see §6.3).

The alternative — create capability `pulse`, retire `watchdog` with `retire_capabilities: true` — was tested and
rejected for three measured reasons:

1. **Retirement is refused by this spec's own shape.** OpenSpec 1.8.0 refuses to delete a spec whose requirement
   blocks hold content "the merge cannot name". The base spec has one wrapped continuation line inside the Standby
   scenario, so the probe aborts:

   ```
   $ cp -r openspec /tmp/p7b/openspec && (cd /tmp/p7b && openspec archive -y probe-b)   # probe B
   Validation errors in rebuilt spec for watchdog (will not write changes):
     ✗ Spec must have at least one requirement
     → 'watchdog' declares retire_capabilities, but the spec holds content the merge cannot safely account for and
       deleting the file would take with it: "`team standby status` reports standby on with that reason".
   ```
   Only after unwrapping that line does retirement proceed (probe C: `Retiring openspec/specs/watchdog/spec.md:
   all requirements removed`, watchdog dir gone, gates green). So (b) needs **two changes in sequence** — a
   preparatory MODIFIED that rewrites the wrapped scenario, then the rename — for zero behavioral gain.
2. **No copy check protects the port.** Under (b) the six requirements are re-typed as `ADDED` under `pulse` and
   `REMOVED` under `watchdog`. `openspec validate --all --strict` checks ADDED names for collisions and REMOVED
   existence, but nothing compares the new text with the old: a scenario dropped or a sentence subtly changed in
   the copy is green everywhere (probe C confirms archive accepts it). Under (a) a `MODIFIED` block **must**
   restate the whole requirement, and both `openspec validate --all --strict` (probe F) and `openspec archive`
   (memory-recorded, and the same message) refuse a block that drops a base scenario:

   ```
   ✗ [ERROR] watchdog/spec.md: MODIFIED "…" omits scenario(s) the current spec still has: "The second tick stays quiet".
   ```
3. **It collides with the in-flight P5 change.** `deferred-delivery-and-draft-entry` carries a `MODIFIED` delta
   for the same capability (`Pending work is defined …`). Under (a) the two changes are ordered by the PM and the
   second restates a text that already exists; under (b) P5's text would have to be re-derived into the `pulse`
   copy before the retirement, or the rename silently reverts P5's promise.

Additional facts that shaped the choice (probes D/E): a delta `## Purpose` is **ignored** when the capability
already has one (`archive`: "delta Purpose ignored; watchdog already has one. Edit … directly"), and a
`RENAMED` + `MODIFIED` pair for the same requirement in one delta file applies cleanly (`+ 1 added, ~ 1 modified,
→ 1 renamed`), so the one requirement whose header contains the old name can be renamed in this change.

## 3. Alias and compatibility design

### 3.1 Commands

- Canonical: `team pulse [up|down|restart|status|logs]`; bare `team pulse` = `status` (today's default).
- Aliases (v1.32.0 → v2.0.0): `team watchdog <sub>`, `team watchdog-status`, `team install-watchdog`,
  `team uninstall-watchdog`. Each prints exactly one line before doing the work:

  ```
  [deprecated] team watchdog 已改名 team pulse（别名保留到 v2.0.0）
  ```

  stdout, first line; the rest of the output is the pulse output. The alias keeps the same subcommand set, so
  `team watchdog --container` keeps being refused with the existing explanation.
- Flags: `team monitor --no-pulse` and `team bootstrap --no-pulse` are canonical; `--no-watchdog` stays accepted
  with the same meaning. No printed line for flags (monitor clears its screen; a line there would be erased and
  the promise would be false).

### 3.2 Environment variables (precedence)

Effective value of `NAME` ∈ {`INTERVAL`, `NUDGE_GAP`, `MAX_RESTARTS`, `PENDING_BOARD`, `REBUILD_TMUX`, `WINDOW`}:

```
TEAM_PULSE_<NAME>   (non-empty)      →  used
else TEAM_WATCH_<NAME> (non-empty)   →  used, and named as legacy by `team pulse status`/`team doctor`
else the documented default
```

One helper (`team_pulse_var NAME default`) does the resolution so precedence exists in exactly one place. `team
pulse status` prints `巡检周期 …（legacy: TEAM_WATCH_INTERVAL）` when the fallback was used; `team paths` always
reports the resolved values, so a script never needs to implement the precedence itself.

### 3.3 Window resolution and the legacy window

`team_watch_window()` becomes `team_pulse_window()`:

```
TEAM_PULSE_WINDOW → TEAM_WATCH_WINDOW → "pulse"
```

plus a legacy probe: when the resolved window does not exist but a `watchdog` window does (and the resolved name is
not `watchdog`), the patrol backend **is** that window. Consequences, all in the delta:

- `status` / `logs` / panel state act on it; `status` and `doctor` add the migration hint
  (`旧窗口 teamsmith:watchdog 仍在跑 → team pulse restart 换成 teamsmith:pulse`).
- `team pulse up` never creates a second patrol in that state: it creates no window and prints the hint. This is
  the only safe behavior — the old window's process is running pre-upgrade code and two patrols share neither the
  pid lock nor the nudge signature.
- `team pulse down` removes the resolved window **and** the legacy `watchdog` window (ending the patrol means
  ending both).
- `team pulse restart` = down(both) + up: exactly one window, named by `TEAM_PULSE_WINDOW` (default `pulse`).
- `team pulse up` with the legacy window gone behaves as today.

### 3.4 State files: keep the historical names (chosen)

The pid lock (`state/watchdog.pid`) and the nudge signature (`state/watchdog.nudge`) are shared state. If the new
code renamed them while an old window still runs, the old and the new patrol would hold **different locks** and
different nudge signatures: two patrols, double nudges, and the restart quota counted twice. Keeping the names for
the alias period is the only option that lets pre-upgrade and post-upgrade code coexist; it also makes a rollback
(downgrade) lossless. `state/pulse.*` is not created. The file names are a documented internal (`references/config.md`),
not a user-facing surface, so the mismatch costs nothing; the change that drops the alias (v2.0.0) renames them in
one step, when no old process can be running.

### 3.5 Nudge text

`[watchdog] 待办：…` (`common.sh:1753`) becomes `[pulse] 待办：…`; the spec's scenarios assert the `[pulse]
pending: …` marker. The panel header (`cmd-status.sh:563`) and the footer hints change with it.

## 4. Migration narrative for an existing project

| Step | What the project sees |
|---|---|
| 1. Upgrade the skill (v1.32.0) | scripts re-read on every `team` call → `team pulse` exists immediately; `team watchdog …` still works and prints the deprecation line. `.pi/team/config.sh` still holds `TEAM_WATCH_*` → read as fallbacks; `TEAM_WATCH_WINDOW="watchdog"` keeps that project's window named `watchdog` |
| 2. The old window | a `teamsmith:watchdog` window started before the upgrade keeps running old code (its process loaded the old functions). `team pulse status` recognizes it as the backend and prints the migration hint; `team pulse up` refuses to double it |
| 3. Migrate | `team pulse restart` (or `team pulse down` + `team pulse up`) → the window is now `teamsmith:pulse`, running current code, and the same `state/watchdog.*` files continue (nudge history and quota intact) |
| 4. Config (optional now, expected by v2.0.0) | rename `TEAM_WATCH_*` to `TEAM_PULSE_*` in the project config; every value is optional because of the precedence rule. `team doctor`/`team pulse status` name any legacy variable still in effect, so the migration is self-reporting |
| 5. Habits and scripts | `team watchdog up` in a runbook or cron-like script keeps working for the whole alias period; changing it to `team pulse up` is recommended, not required, until v2.0.0 |
| 6. This dev project | its live copies — `.pi/team/config.sh` (tracked), `AGENTS.md` (the teamsmith section), `docs/team/PROTOCOL.md` — are PM-owned and untracked-by-the-skill; the PM migrates them right after the merge (one commit + `team pulse restart`), or the apply brief may be authorized to do it. Recommendation: migrate them immediately, so the project that ships the rename runs the new names |
| 7. Downgrade | safe during the alias period: old code reads the old state files and the old config; the only loss is the new requirements' behavior (alias hints, `paths` keys) |

## 5. Alias end condition

The aliases (commands, `--no-watchdog` flags, `TEAM_WATCH_*` fallbacks) and the historical state-file names end at
the **first major release after this one — v2.0.0**; v1.32.0 introduces them. The v2.0.0 change removes the alias
wrappers, the legacy window probe, the env fallbacks and renames the `state/watchdog.*` files (a one-time move; no
old process can be running then), and rewrites the ADDED requirements accordingly. Until v2.0.0 a deprecation line
is a permanent, cheap cost; after it, a stale "watchdog" mention in a script fails loudly instead of silently
meaning something else.

## 6. Delta map

### 6.1 MODIFIED (six)

| Requirement | Renames inside | Scenarios |
|---|---|---|
| One backend, inside the team's tmux session | `team watchdog`→`team pulse`, `TEAM_WATCH_WINDOW`→`TEAM_PULSE_WINDOW`, default `pulse`, "the pulse MUST NOT" | both kept verbatim (window name updated) |
| Pending work is defined … | `TEAM_WATCH_PENDING_BOARD`→`TEAM_PULSE_PENDING_BOARD`, `[watchdog] pending:`→`[pulse] pending:` | both kept |
| Repeated reminders … | `TEAM_WATCH_NUDGE_GAP`→`TEAM_PULSE_NUDGE_GAP`, `[pulse] pending:` | kept |
| Standby stops the wake-ups … | adds the state-file policy sentence (names kept for the alias period) | base scenario kept + new "The alias period keeps the historical state file names" |
| Restart quota and capacity logging | `TEAM_WATCH_MAX_RESTARTS`→`TEAM_PULSE_MAX_RESTARTS` | both kept |
| The watchdog never manages tmux layout … | header **RENAMED** to "The pulse never manages …"; `TEAM_WATCH_REBUILD_TMUX`→`TEAM_PULSE_REBUILD_TMUX` | both kept |

### 6.2 ADDED (four)

| Requirement | Observable promise | Scenarios |
|---|---|---|
| The old command names keep working during the alias period | aliases run and print the deprecation line as stdout's first line | alias output = line + same window/interval report |
| Legacy environment variable names are read during the alias period | `TEAM_PULSE_*` > `TEAM_WATCH_*` > default; the legacy source is named | legacy interval honoured and named; new name wins without a legacy notice |
| A running legacy window is migrated explicitly | legacy window is the backend; `up` refuses to double it; `restart` leaves one `pulse` window | not doubled; restart renames |
| The read-only commands report the pulse surface | `team paths` keys `pulse_window`/`pulse_interval`; `team doctor` names `pulse` + legacy var | paths JSON; doctor line |

### 6.3 What archive does, and the PM's one manual edit

`openspec archive -y rename-watchdog-to-pulse` applies `+ 4 added, ~ 6 modified, → 1 renamed` to
`openspec/specs/watchdog/spec.md` (verified in the scratch; see the report). It does **not** touch the file's H1 or
Purpose (a delta Purpose is ignored — probe D), so the PM replaces those two in the archive commit with:

```md
# pulse Specification

## Purpose

Wake the PM only when there is work: one patrol loop (the pulse) in a tmux window of the same session, a precise
definition of "pending", a stand-down switch, and limits so a broken PM cannot be restarted forever. The
capability directory keeps the historical `watchdog` id (D22). Why this shape (and why the pulse is not a
heartbeat): `references/workflows.md` §I and `references/philosophy.md` (govern less).
```

Both edits were probed on the archived scratch: `openspec validate --all --strict` and `spec-lint.sh` stay green
(the capability is resolved by directory, not by H1). Nothing else is manual: the change directory moves to
`openspec/changes/archive/2026-09-15-rename-watchdog-to-pulse/` and the delta remains the record of the rename.

## 7. Apply split, risks, follow-ups

**Two apply briefs** (proposal checklist #8: one brief cannot finish this):

- **A1 — behavior** (capability `watchdog`): `team pulse` group + alias wrappers + deprecation line; the
  `team_pulse_var` resolver and the legacy notices; window resolution + legacy probe + `down`/`restart` + `up`
  refusal; nudge/panel text; help table, bootstrap plan text, config template; `paths`/`doctor`; the alias/legacy/
  migration tests in `smoke.sh`. Gate: `openspec validate --all --strict`, `spec-lint.sh`, `smoke.sh` (§11b/§6i
  exercise real tmux — marked as such in the brief).
- **A2 — docs and release** (capability `watchdog`): references sweep (`bootstrap`, `config`, `protocol`,
  `workflows`, `troubleshooting`, `migration`, `philosophy`, `agent-adapters`, `memory`), `SKILL.md`,
  `templates/**`, CHANGELOG entry, version bump to 1.32.0 (`TEAM_VERSION` + SKILL.md `metadata.version`),
  `team version --check`.

Risks and how they are held down:

- **P5 ordering.** If `deferred-delivery-and-draft-entry` archives first, its extra sentence and scenario in the
  `Pending work is defined …` requirement must be carried into this change's MODIFIED block. The archive scratch
  run is the check: a delta that drops P5's scenario is refused by both `validate` and `archive`.
- **Smoke size.** 84 matching lines; the tmux segments (§11b, §6i) are the expensive ones. A1 runs the full suite
  at least once and the fast sections on every commit.
- **False green on the alias.** The line is asserted as stdout's *first* line, and the scenario also checks the
  remaining output — an alias that prints the line but does nothing else fails.
- **`--no-watchdog` silence** is deliberate and documented; if the PM wants a deprecation notice there too, it
  must be a `pulse status`/`doctor` line, not monitor's screen (which is cleared).
- **Follow-up (not this change):** v2.0.0 drops the aliases and renames `state/watchdog.*`.

Open question for the PM: whether A1 may also migrate this repo's live copies (`.pi/team/config.sh`, `AGENTS.md`,
`docs/team/PROTOCOL.md`) or the PM does it post-merge. The budget of the change is unaffected either way
(`.pi/**` and `AGENTS.md` are PM-owned).
