# Design: `pulse-tui-panel` — the status panel as a TUI front end over the data layer

Change `pulse-tui-panel` · phase: propose (planning only) · base: `544efc4` (= v1.33.0, after D24) · agent: dev2.

This document is the brief's five points plus the choices the brief left open (capability id, distribution layout,
test migration, handoffs). Every count, path and output below comes from a command run in the task worktree or from
E4's committed captures; the raw logs are under `docs/team/reports/P9-dev2/`.

## 1. Context

- **D19** (user): the panel gets a real TUI framework, Node/Bun becomes a required dependency, the new visualizations
  come in a second step. **D24** accepted E4's measured pick: Ink + TSX, one committed bundle, `monitor.mjs`
  unchanged as the data layer.
- **E4** (543 lines, all conclusions measured on private tmux servers and in a clean container): Ink is the only
  candidate that is single-file bundleable, aligns CJK/emoji with tmux's own width table (10/10 rows, spread 0, vs
  blessed-contrib's spread 9), and strips control characters while keeping the text (blessed truncates at the first
  control character; OpenTUI writes `OSC 52` and `ESC[2J` straight to the terminal). One-file bundle: 826 KB, runs
  under plain `node` in `node:24-alpine`. Startup 222 ms against a 5 s refresh. `--print`/non-TTY must not enter the
  TUI renderer because only Ink emits clean text on a pipe.
- **What this phase is**: the contract. No code, no tests, no `references/**`; the apply phase builds the front end
  and the independent verify phase attacks it (E4 §8.2's migration list and §7's unverified list are the attack
  surface).

## 2. Capability shape: a new `panel` capability, and deliberately no `watchdog` delta

**Decision: the new capability is `panel` (option a); `watchdog` gets no delta. `memory-and-deps` gets one ADDED
requirement and one MODIFIED.**

Why `panel` and not `pulse-panel` or `monitor-panel`:

1. **The rename does not reach it.** P7 (accepted) scopes `watchdog` → `pulse` to the command group, the window and
   the `TEAM_WATCH_*` prefix; `team monitor` and `TEAM_MONITOR_*` keep their names (P7 design §1.1). A capability id
   built from a name that is *not* the surface's name would be a second naming layer; `panel` is what the code and
   the operator already call it (`team_panel`, "面板"), and it stays true before, during and after the alias period.
2. **`pulse-panel` would make today's text name a surface that does not exist.** The brief's rule is that this
   change's text uses today's names (`rename-watchdog-to-pulse` is not implemented). A capability whose id promises
   `pulse` while its scenarios run `team monitor` in a `watchdog` window is exactly the drift the rule prevents.

Why no `watchdog` delta:

- The panel appears in exactly one sentence of the base specs — `watchdog` requirement 1: "that window MUST also
  serve as the status monitor (`team monitor`)". Measured:
  `grep -rn "team monitor" openspec/specs/` → one hit, `openspec/specs/watchdog/spec.md:14`. The rewrite keeps that
  sentence true; the panel's behaviour is not described there today, so nothing becomes false.
- **It would create a three-way interlock.** `deferred-delivery-and-draft-entry` (P5) carries a MODIFIED block for
  `watchdog` requirement "Pending work is defined …", and `rename-watchdog-to-pulse` (P7) carries MODIFIED blocks for
  all six `watchdog` requirements. `openspec archive` replaces a MODIFIED requirement whole. A third change restating
  those requirements can only be merged if every other delta is re-derived afterwards, and the failure mode is
  silent: a dropped *sentence* is not refused by `openspec validate --all --strict` or by `spec-lint.sh` (E1 §5.3,
  reproduced in `docs/team/reports/P7-dev2/gate-flip.sh`), and a dropped *scenario* is only caught by
  `openspec archive` at phase 5. Ordering three overlapping deltas by hand buys nothing: the panel's promises fit in
  a capability of their own.
- The one promise that could have lived in `watchdog` — "the window's process is still the tick loop" — is stated in
  `panel` as *the panel process owns the tick* (`panel` requirement 7). It is a promise about the new front end, and
  its falsifiers (no second window, no background process, one capacity line per interval) are panel-side.

`memory-and-deps` is the right home for the runtime requirement because that capability already owns "what teamsmith
requires from its environment" (`team doctor` failing, the requirement switches, `team paths` visibility). The JS
requirement is a new instance of an existing pattern, not a new pattern — so it is an **ADDED** requirement
("A JS runtime is a required dependency") next to the existing one, not a rewrite of it. The alternative was a
`RENAMED` + `MODIFIED` pair on the existing requirement ("magic-context and OpenSpec are required dependencies" →
"magic-context, OpenSpec and a JS runtime are required dependencies"); it was probed on the base and **works** in
1.8.0 (`→ 1 renamed, ~ 2 modified`, both gates green afterwards) but has a measured side effect: the renamed block is
removed from its place and **re-appended at the end of the file**, so the most-read requirement in that capability
moves below "Spec management belongs to OpenSpec"
(`docs/team/reports/P9-dev2/archive-rename-probe.{log,diff}`). The ADDED shape costs one extra requirement block and
keeps the file's reading order; the retired probe is kept as evidence.

## 3. What is committed, and where

```
skills/teamsmith/scripts/panel/
  package.json        the pinned build-time dependencies (ink, react, …) and the `engines` minimum
  bun.lock            the lockfile the build resolves against (`bun install --frozen-lockfile`)
  build.sh            the one build command (`bun build --target=node --format=esm …`), writing dist/panel.js
  src/*.tsx           the sources (components, layout, bands, formatters)
  src/data.ts         the data adapter: spawns `monitor.mjs --json` and the existing bash readers
  panel.js            THE committed artifact `team monitor` runs
  README.md           how to rebuild it and why the artifact is committed
```

`team monitor` runs `panel.js` through `team_js_runner()`'s resolution (node, bun, tsx) with `--root`, the geometry
and the mode flags. The sources are never on the runtime path: `panel.js` is what a user has.

Traps recorded here so the apply phase does not rediscover them:

- **Module format.** `node panel.js` must work from a fresh checkout, so the committed `package.json` declares the
  format the bundle is built in (`"type": "module"` with `--format=esm`), and the build script must not emit the
  other one. A mismatch is a `SyntaxError` on the *first* command a user runs.
- **Bare imports.** The bundle must be self-contained: no `import`/`require` of anything but `node:` builtins. The
  smoke fixture that runs the bundle with an empty `NODE_PATH` from a directory outside the repository is what keeps
  an accidentally-committed unbundled file red.
- **`scripts/panel/package.json` is not a runtime dependency.** It is only read by the build and by the consistency
  check; nothing installs it, and the repository stays free of `node_modules`.
- **Size.** 826 KB next to a ~500 KB skill is a visible cost; D24 accepted it for offline/no-install distribution.
  The apply report must state the committed file's exact size and sha256.
- **Provenance header.** The bundle carries the pinned framework versions and the build command as a header comment;
  `--version` prints the same. A stale bundle is then detectable without a network rebuild.

## 4. The four output modes

| Invocation | Renderer | Writes state | Used by |
|---|---|---|---|
| `team monitor` (TTY, `TEAM_MONITOR_UI=auto`) | TUI, redraw per `TEAM_MONITOR_REFRESH`, keys, one tick per `TEAM_WATCH_INTERVAL` | tick only | the patrol window |
| `team monitor --once` | same selection as above, one frame, then exit | tick when due (today's semantics) | smoke, humans, `team watchdog logs` |
| `team monitor --print` (or stdout not a TTY, or `TEAM_MONITOR_UI=text`) | plain text, no ANSI, no clear | **nothing** | pipes, scripts, `| less` |
| `team monitor --json` | one JSON object | **nothing** | fixtures, the verify phase, step 2 |

The line between `--once` and `--print`/`--json` is deliberate: `--once` is one frame of the *interactive* panel and
keeps the tick it performs today (measured on the base: `team monitor --once` with an empty state directory leaves
`capacity.log`, `watchdog.log`, `watchdog.last`, `watchdog.tick.log`, `_watch.env`), while the two machine-readable
modes are observers that a monitoring script can run every 5 s without nudging the PM. `--once --no-watchdog`
measured on the base writes no state at all, which is the existing proof that the tick is separable.

`--json` composes the panel's own fields with the data layer's result, and does not change
`monitor.mjs --json` (the ~25 smoke assertions on `source`/`available`/`truncated`/`tail_limit`/`count`/`events`
stay pinned to that file, and the panel consumes it as a subprocess).

## 5. Layout and degradation

E4 §3.2's wireframe is the layout; the spec pins band *order* and *degradation*, not pixel positions:

```
A  title (project · time · interval · standby)  +  PM state · pending · queue · capacity + sparkline
B  agent table (left)                         |  activity column / recent patrol actions (right)
C  reserved visualization band (labelled placeholder, reads no data)
D  key band (q / ↑↓ / r / --print / --no-activity)
```

Degradation order (E4 §3.2): C disappears below 17 rows; below 11 rows the capacity figures fold into the PM line;
A keeps the PM state and the pending counts. The reserved band is **not** a promise to implement step 2 — it is a
labelled placeholder, and its only falsifiers are "present at normal height, absent when short, reads no extra data".

`--width`/`--height` exist so the layout contract is checkable headlessly (a fixture runs `--print --width 120
--height 10` and greps band order); the real-tmux scenarios then check that a 60×8 pane is not overrun. Without the
overrides the layout would only be testable through `capture-pane`, which is both slow and locale-dependent.

## 6. Field disposition (each row has a falsifier)

| Field | Disposition | Source | Falsifier |
|---|---|---|---|
| PM state | upgrade → band A | `team_pm_state` | `panel.pm.state` in the closed vocabulary; the band shows it |
| pending (unread/review/blocked) | upgrade → band A | `team_pending_text` | the three counts + total in `--json` and in the band |
| outbox (D20) | **new**, band A | `state/outbox/` (read-only) | queue/held/oldest/forced counts; missing directory = 0 |
| capacity (RAM/swap/agents) | collapse to one line + mini chart | `state/capacity.log` tail | `panel.capacity.spark` has ≥2 samples; RAM = last sample |
| zram physical MB | **drop from the panel** | `team watchdog status` | no zram-physical key in `panel.capacity` |
| agent state / task | keep (table) | `team_agents` + state | `state` in `{running,exited,absent}`, task id shown when set |
| branch / dirty / ahead / session size | upgrade (from `team status`) | `team_git_cols`, `team_session_tokens_est` | real values in the fixture with one dirty, 3-ahead branch |
| uptime (`elapsed`) | fold (JSON only) | `monitor.mjs` | present in `--json`, not a table column |
| idle | keep | state / session | `idle_s` |
| event count | fold (wide widths only) | `monitor.mjs` | present in `--json`; column only when the width allows |
| recent patrol actions (6 lines) | keep (B right, or B bottom) | `state/watchdog.log` tail | at most six lines, ≥1 with a fixture log |
| activity stream | default **on** (was opt-in) | `monitor.mjs` bounded read | default frame has the event; `--no-activity` removes it |
| bottom prose (2 lines) | fold into one key band | — | the key band is the last non-empty line |

## 7. Display safety

The chain keeps two independent layers and one contract:

1. `monitor.mjs`'s `sanitize()`/`sanitizeDeep()` (M3.3/F3) — the data layer's own promise, unchanged.
2. Ink's stripping of control characters — depth, not the contract.
3. **The panel's own contract**: no `ESC`/`BEL`/`CR`/C1 byte in any mode, and the visible text survives. Ink is
   measured to satisfy the second half (`safe ESC]52;c;…BEL MORE ESC[2J END` renders as `safe MORE END`), which is
   exactly why E4 kept Ink and dropped blessed (truncates at the first control character) and OpenTUI (forwards the
   bytes). The panel must still sanitize the strings it reads itself (branch names, task ids, queue file names,
   state files), because those never pass through `monitor.mjs`.

The hostile-payload fixture is the same one E4 used, so the apply evidence is comparable with the exploration.

## 8. Tick ownership

Today `team monitor`'s loop calls `team_watch_once` when `now - last_tick >= TEAM_WATCH_INTERVAL`
(`cmd-watch.sh:419-427`), writes `state/watchdog.tick.log`, trims it at 200 lines, and `--no-watchdog` disables it.
The rewrite keeps exactly that ownership in the new process: one window, one process, one tick loop. The reason to
write it down is the failure this project has already paid for: a panel that spawns its own background watcher would
produce two patrols, two nudges and a second restart quota (P7 design §3.4 keeps one pid lock for the same reason).

## 9. Runtime requirement, and how far the escape key reaches

- `team doctor` (capability `memory-and-deps`): a JS runtime is required like magic-context and OpenSpec. Missing →
  fail with the resolved-path/version evidence and the fix; `TEAM_REQUIRE_JS=0` downgrades that one check to a
  warning. `team paths` exposes `js_runner` and `require_js`.
- `team monitor` (capability `panel`): no runtime → non-zero, one line, no panel. The escape key does **not** apply
  here: D19 removed the no-Node text mode, and an empty panel reported as success is precisely the false green this
  project refuses (`references/philosophy.md`, principle 2).
- `team watchdog up`: refuses before creating a window, because a window whose process cannot render is a dead
  window that `up` would have reported as running.
- **Version minimum**: the build's `engines` (`node` 20, `bun` 1.3) is the panel's floor; doctor fails below it and
  names the version it found. E4 §7.5 records that only linux/glibc and alpine/musl containers were tested; the
  minimum is the honest way to keep untested runtimes out.

## 10. Configuration keys

| Key | Today | After | Contract change |
|---|---|---|---|
| `TEAM_MONITOR_REFRESH` | 5 s, redraw period | same name, same meaning; one data read per frame | no |
| `TEAM_MONITOR_ACTIVITY` | 0 (opt-in) | **1** (part of the layout) | **yes — the only default that moves** |
| `TEAM_MONITOR_EVENTS` | 4 events per agent | same | no |
| `TEAM_MONITOR_UI` | — | `auto` \| `tui` \| `text` (default `auto`) | new key |
| `TEAM_JS_BIN` | — | absolute path to the runtime, first in resolution order | new key |
| `TEAM_REQUIRE_JS` | — | `1` (default); `0` downgrades the doctor check only | new key |

`--activity`/`--no-activity` keep overriding the key in both directions, and `TEAM_MONITOR_ACTIVITY=0` restores
today's layout exactly. The keys stay inside the `watchdog`→`pulse` rename scope as P7 defined it, so no literal in
this table moves with the rename.

## 11. The queue interface (D20/D21), read-only by contract

`deferred-delivery-and-draft-entry` (P5) defines the entry format
`$TEAM_STATE_DIR/outbox/<epoch-ms>-<zero-padded seq>-<target>.msg`, the `held/` directory, `HOLDING.log` and
`forced.log`. The panel reads **names and counts only** at the top level (that is where the count, the target and the
creation time live), and reads a header only when a detail view asks for it. It never creates the directory, never
enqueues, never claims and never drains. Consequence written into the spec: while P5 is not applied, `outbox/` does
not exist and the field is a zero — not an error, not a warning.

## 12. Handoff to `rename-watchdog-to-pulse` (P7)

This change writes today's names, as the brief requires. Literals in `panel` that the rename touches:

| Literal in `panel` | P7's treatment | Consequence |
|---|---|---|
| `--no-watchdog` (tick-off flag) | canonical `--no-pulse`; old flag accepted for the alias period | the requirement says "the flag that turns the tick off today (`--no-watchdog`, renamed by `rename-watchdog-to-pulse`)" — true during the alias period; the alias-drop change must restate that sentence |
| `watchdog.log` (patrol action log) | state file names kept for the alias period, renamed by the alias-drop change | same: the requirement names the file and points at the capability that owns it |
| `team watchdog status`/`logs`/`down` (key band hint) | renamed with aliases | the spec does not quote the hint text; the apply phase writes the hint from the resolved surface |
| `team monitor`, `TEAM_MONITOR_*`, `state/outbox/`, `state/capacity.log` | untouched by P7 | no handoff |

**Ordering (for the PM):** if P7 archives first, this change's apply still runs today's names and everything above
stays true; if this change archives first, P7's A1/A2 sweeps must add the panel's three literals to their
`grep -rn 'watchdog'` list (P7's inventory stop at "84 matching lines in smoke.sh" and the references; the panel adds
a new file). Recommendation: **archive P7 first** (D22's stated order — "let the rewrite start from the new names is
nice, but the rewrite's own text is written against today's names either way"), and give P7's apply brief one line:
"the panel's key band hint and its tick-off flag are written from the resolved surface; do not hardcode `watchdog`".

## 13. Handoff to `deferred-delivery-and-draft-entry` (P5)

No text overlap (different capability), one runtime coupling: the panel's queue field is a zero until P5's apply
creates `state/outbox/`. If P5's applied behaviour renames `forced.log`/`HOLDING.log`, only the panel's `--json`
keys for those two counts survive (they are in this change's spec, so a rename is a spec change — the same rule P5
applied to its own file format).

## 14. Tests: what changes, what is new, what needs a real tmux

Existing assertions that must move (E4 §8.2, re-verified on the base by line number):

| Location | Today | Why it moves |
|---|---|---|
| `tests/smoke.sh:2358-2363` | `team monitor --once` output contains `teamsmith monitor`, `巡检`, `只服务本 session`; default frame has no `agent 活动`; `--activity` has it | title/prose change, and the activity default flips to on |
| `tests/smoke.sh:2370` | `team watchdog logs` contains `teamsmith monitor` | the title band changes; the capture also changes shape |
| `tests/smoke.sh:1017-1019` | the `TEAM_AGENT_LOG_GLOB` activity path | unchanged if the data layer stays; the flag's default flips |
| `tests/smoke.sh:820-910` | `monitor.mjs --json`'s keys, sanitize, FIFO/EACCES degradation | unchanged (that is the point of not touching the data layer) |

New fixtures (in `skills/teamsmith/tests/`, agent:dev's directory):

1. the plain-text contract (`--print`, redirected stdout, `TEAM_MONITOR_UI=text`) with an ESC-byte count;
2. `--json` shape against a fixture root (panel fields + `.activity` keys);
3. band order and degradation through `--width/--height`;
4. hostile payload (OSC 52 / `ESC[2J` / a hostile branch name) with an ESC-byte count and the `MORE`/`END` markers;
5. the queue field (missing directory, counts, no writes — hash guard);
6. the runtime failure paths (PATH without node/bun/tsx, `TEAM_REQUIRE_JS=0`, `team paths` keys);
7. the bundle runs with an empty `NODE_PATH` from outside the repository (no `node_modules`).

Isolation follows M7.2: every new fixture runs in a sandbox repository with inherited `TEAM_*` cleared, asserts
`team paths` resolves to the sandbox before anything writes, and compares a hash of the real
`docs/team/inbox/**` + `.pi/team/state/**` before and after.

**`[real]` (need a tmux window, slow suite, never the only evidence for a requirement):** the TUI frame in a
120×29 pane; the 60×8 pane; `--no-watchdog` over two intervals; one tick per interval and the window/process count;
the tick-off redraw check at `TEAM_MONITOR_REFRESH=1`; `team watchdog up` without a runtime creating no window.

## 15. Risks and trade-offs

- **A false green on the renderer.** A `--print` sample can look right while the TUI path emits ANSI. → the TUI
  scenarios are capture-based with an ESC-byte count, and the plain-text scenarios are gate items.
- **Ink's memory over a long run** (E4 §7.2 left it unmeasured). → the apply adds a long-run sample (the panel for
  ~15 minutes at 1 s refresh with `ps -o rss` sampled) as a `[real]` item; it is not a spec promise because the
  threshold is not established.
- **Terminal differences** (E4 §7.3): the alignment fix is measured against tmux's width table only. → the spec
  promises alignment only where the panel can compute it (its own width table + no wrapping), and the report keeps
  E4's caveat.
- **The activity default flip** changes what `team watchdog logs` shows and what the smoke asserts. → it is written
  as a contract change in the spec and in `references/config.md`, not silently.
- **Reproducibility needs the network** (`bun install --frozen-lockfile`). → the guarantee is split: "runs with no
  install" is a gate item, "rebuilds byte-identically" is a release-time check with the log in the report.
- **The reserved band could read as a promise.** → the spec says it is a labelled placeholder that reads no data,
  and lists it in the delta as such.
- **826 KB in git.** → D24 accepted it; the report records size and sha256 so growth is visible.
- **The three rename literals** (§12). → one table, one recommendation to the PM, no silent drift.

## 16. Migration plan

Nothing on disk changes format. Two observable behavior changes reach an existing project: the activity column is on
by default (one config key restores today's layout: `TEAM_MONITOR_ACTIVITY=0`) and a machine without a JS runtime
fails `team doctor` and the panel (one key downgrades the doctor check: `TEAM_REQUIRE_JS=0`). Both are documented in
`references/config.md` and `references/troubleshooting.md` §3 by the A2 brief. Rolling back means reverting the apply
commit: the abandoned bundle is inert, and no state file changed its name.

## 17. Delta map and what archive does

### 17.1 Delta map

| Capability | Operation | Requirements | Scenarios |
|---|---|---|---|
| `panel` (new) | ADDED | 12 | 33 |
| `memory-and-deps` | ADDED | 1 ("A JS runtime is a required dependency") | 2 |
| `memory-and-deps` | MODIFIED | 1 ("Tool resolution is visible", restated in full, its base scenario kept) | 1 added |

### 17.2 Scratch archive probe

`openspec archive -y pulse-tui-panel` was run on a copy of `openspec/` (never on the worktree), then both gates were
re-run on the archived copy. Measured result (`docs/team/reports/P9-dev2/archive-probe.log`, run at §8 of the report):

```
Specs to update:
  memory-and-deps: update
  panel: create
Applying changes to openspec/specs/memory-and-deps/spec.md:
  + 1 added
  ~ 1 modified
Applying changes to openspec/specs/panel/spec.md:
  + 12 added
Totals: + 13, ~ 1, - 0, → 0
Change 'pulse-tui-panel' archived as '2026-09-15-pulse-tui-panel'.
```

Afterwards the scratch has `openspec/specs/panel/spec.md`, the modified `memory-and-deps`, the change directory under
`openspec/changes/archive/2026-09-15-pulse-tui-panel/`, and `openspec validate --all --strict` + `spec-lint.sh` both
exit 0. The archive's own warning ("Consider splitting changes with more than 10 deltas") is expected for a change of
this size and is answered by the two apply briefs in `tasks.md`.
