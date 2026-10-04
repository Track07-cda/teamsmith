# P9 · Propose: `pulse-tui-panel` (Ink + TSX front end over the panel data layer)

agent: dev2   status: done   time: 2026-09-15T14:45Z
branch: `task/P9-propose-pulse-tui-panel-ink-`   PR/MR: - (local mode: branch left local, PM merges)

phase: propose · change: `pulse-tui-panel` · base: `544efc4` (= v1.33.0, after D24) · tip: `383ca86`

## Deliverables

| Path | What |
|---|---|
| `openspec/changes/pulse-tui-panel/.openspec.yaml` | change marker (schema, created) |
| `openspec/changes/pulse-tui-panel/proposal.md` | 65 lines / 479 words (the 500-word rule): why, the measured before, what changes, capabilities, impact, verbatim acceptance, boundaries, report evidence |
| `openspec/changes/pulse-tui-panel/specs/panel/spec.md` | the new capability: **12 requirements / 33 scenarios** |
| `openspec/changes/pulse-tui-panel/specs/memory-and-deps/spec.md` | **1 ADDED** requirement (a JS runtime is required) + **1 MODIFIED** (`Tool resolution is visible`, restated in full + 1 scenario) |
| `openspec/changes/pulse-tui-panel/design.md` | 328 lines: capability shape, the missing watchdog delta and why, the bundle layout, the four modes, the layout/field tables, safety, tick ownership, runtime, keys, the P5/P7 handoffs, test migration, risks, delta map |
| `openspec/changes/pulse-tui-panel/tasks.md` | 183 lines: two apply briefs (A1 behavior+tests, A2 docs+release), 32 items, `[real]` marks |
| `docs/team/reports/P9-dev2/` | the evidence directory (scripts + raw logs, §4) |

No code, test, reference, `SKILL.md`, `CHANGELOG` or `openspec/specs/**` file was touched.

## 1. The brief's six points, answered

| Brief point | Where | Evidence |
|---|---|---|
| 1. Ink + TSX front end, `monitor.mjs --json` unchanged, `bun build` single file committed, `node panel.js --once` in a clean container | design §3; `panel` requirement 11 | `panel` scenarios "A fresh checkout runs the bundle", "The bundle declares what built it", "The rebuild is byte-identical" (+ E4 §2's container captures) |
| 2. Layout per E4 §3.2, each existing field lands in a scenario, step 2's band reserved | design §5/§6; `panel` requirements 3/4/5 | the field table with one falsifier per row; scenarios "Band order is stable", "The reserved band and the capacity figures fold away first", "A tiny pane is not overrun" |
| 3. `--print`/non-TTY never the TUI renderer; doctor requires Node/Bun with `TEAM_REQUIRE_JS=0`; `TEAM_MONITOR_*` key by key | design §4/§9/§10; `panel` requirements 1/2/9/12; `memory-and-deps` | scenarios "A pipeline receives plain text", "No runtime is a named failure …", "The activity default is a documented contract change" |
| 4. Display safety: sanitize chain, hostile text → not executed, not truncated | design §7; `panel` requirement 7 | scenarios "An OSC 52 payload is stripped, not obeyed and not truncated", "A hostile branch name cannot clear the screen", "The TUI frame is captured clean" |
| 5. Spec shape: new capability vs `watchdog`; old names; the rename handoff in design.md | design §2 and §12 | the interlock analysis + `verify-delta.sh` check 4; the rename-literal table |
| 6. D20 interface: the queued count as a panel field, read-only | design §11; `panel` requirement 10 | scenarios "A missing queue is a zero", "Queued, held and the oldest age come from the entry names", "Three render modes leave the queue byte-identical" |

## 2. Before (measured on the base — the "red" this change removes)

`bash docs/team/reports/P9-dev2/before-measure.sh .` → `before-measure.log` (reproducible; it only writes into
`/tmp`, and its fixture session name does not exist, so no key can reach a real session):

```
monitor --once rc=0
ESC bytes in the piped output: 3
first 20 bytes: ^[[H^[[J^[[3Jteamsmith
state files written by --once: capacity.log watchdog.last watchdog.log watchdog.tick.log _watch.env
monitor --once --no-watchdog rc=0  state files: []
--print rc=2  output: [✗ monitor: 未知参数 --print]
--json  rc=2  output: [✗ monitor: 未知参数 --json]
doctor lines mentioning js/node/bun: [  notify 扩展            ✓ 存在（本机无 node/bun/tsx 可预检）|]
paths keys: [ "openspec_bin": "openspec"  "spec_dir": …  "require_magic_context": "1"  "require_openspec": "1" ]
spec mentions of 'team monitor': [openspec/specs/watchdog/spec.md]
outbox directory present today: [no]
```

Readings: the only non-TTY path today writes cursor/clear control bytes into a pipe; there is no machine-readable
panel; the JS runtime is not a checked dependency; the panel has no queue field; and the panel is mentioned by exactly
one base requirement sentence (the fact design §2 leans on). This is a rewrite, not a defect fix, so there is no
red→green flip in the defect-fix sense; §4 instead proves the gates are falsifiable against these artifacts.

## 3. Shape, and the one deliberate omission

- **New capability `panel`** (design §2 argues the id over `pulse-panel`: `team monitor`/`TEAM_MONITOR_*` are outside
  P7's rename scope, so the id survives before, during and after the alias period; `pulse-panel` would name a surface
  that does not exist yet).
- **No `watchdog` delta.** The one base sentence that mentions the panel stays true
  (`openspec/specs/watchdog/spec.md:14`), and P5 + P7 already carry MODIFIED blocks that restate `watchdog`
  requirements in full — a third restatement would force the other two to be re-derived, and a dropped *sentence* is
  caught by neither gate. `verify-delta.sh` check 4 keeps that claim honest (only `watchdog/spec.md` mentions
  `team monitor`, and no `watchdog` delta exists in the change).
- **`memory-and-deps` is ADDED + MODIFIED, not RENAMED.** The RENAMED alternative was measured on the base: it works
  (`→ 1 renamed, ~ 2 modified`, both gates green afterwards) but `openspec archive` **removes the renamed block from
  its place and re-appends it at the end of the file**, so the capability's first requirement would move below
  "Spec management belongs to OpenSpec". Evidence: `archive-rename-probe.{log,diff}` (54 + 102 lines). The ADDED
  shape costs one extra requirement block and keeps the reading order.

## 4. Verification evidence (all commands actually run)

### 4.1 The acceptance commands (verbatim from the brief) — `acceptance.log`

```
$ openspec validate --all --strict
✓ spec/board-and-status … ✓ change/pulse-tui-panel … ✓ spec/watchdog
Totals: 9 passed, 0 failed (9 items)          rc=0

$ bash skills/teamsmith/tests/spec-lint.sh
spec-lint: OK — 10 spec file(s), 59 requirement(s), 114 scenario(s) under openspec   rc=0

$ git status --porcelain
?? docs/team/reports/P9-dev2/
?? openspec/changes/
```

Only the change directory and the report directory are new — the boundary the brief drew.

### 4.2 `openspec change show pulse-tui-panel` — `change-show.log`

75 lines: the proposal and the delta summary are listed (`openspec change show` is deprecated in 1.8.0 in favour of
`openspec list`/`validate --changes`, which is why `validate --all --strict` above also validates the change).

### 4.3 The scratch archive — `archive-probe.log` + `archive-probe-gates.log`

`cp -r openspec /tmp/p9-archive2/ && cd /tmp/p9-archive2 && openspec archive -y pulse-tui-panel` (never on the
worktree):

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

Afterwards the scratch has `openspec/specs/panel/spec.md` (H1 + Purpose + 12 requirements, no delta headers),
`memory-and-deps` with the new paragraph and the appended requirement, and the change under
`openspec/changes/archive/2026-09-15-pulse-tui-panel/`; `openspec validate --all --strict` (9/9, rc 0) and
`spec-lint.sh` (9 files, 58 requirements, 113 scenarios, rc 0) are green there. Two notes for the PM:

- the archive prints a non-blocking warning ("Consider splitting changes with more than 10 deltas") — answered by the
  two apply briefs in `tasks.md`;
- the archive normalizes blank lines (the blank line after the Purpose block and after `## Requirements` is
  removed) — the same cosmetic behavior recorded for the earlier archive probes, not a defect of this change.

### 4.4 The MODIFIED block is the base text plus one paragraph — `memory-and-deps-block.diff`, `verify-delta.sh`

`bash docs/team/reports/P9-dev2/verify-delta.sh .` (rc 0, `verify-delta.log`):

```
ok   1  block diff written to …/memory-and-deps-block.diff (expected: additions only)
ok   2  every base scenario of the restated requirement is present
ok   2  scenarios: base 1 -> delta 2 (one added)
ok   3  the base requirement name is untouched (the JS dependency is an ADDED requirement)
ok   3  openspec/specs/panel does not exist yet (archive creates it)
ok   4  only watchdog/spec.md mentions `team monitor` (one sentence, still true after the rewrite)
ok   4  the change carries no watchdog delta
ok   5  panel delta: 12 requirements, 33 scenarios
ok   5  memory-and-deps delta: 1 added requirement(s), 1 modified, 1 new scenario(s)
```

`memory-and-deps-block.diff` shows the extracted blocks: the base block plus the `js_runner`/`require_js` paragraph
and the new scenario, and nothing else. `extract-base.sh` regenerates the delta from the base spec, so the
"restated verbatim" claim is reproducible rather than eyeballed.

### 4.5 The gates are falsifiable against these artifacts — `gate-flip.sh`, `gate-flip.log`

```
ok   A  panel scenario without a THEN -> spec-lint red (rc=1)
ok   B  panel requirement with no remaining scenario -> spec-lint red (rc=1)
ok   C  MODIFIED block drops a base scenario -> validate red (rc=1)
ok   D  MODIFIED for an unknown requirement -> validate green (rc=0)
ok   D  MODIFIED for an unknown requirement -> archive red (rc=1)
ok   E  unmodified change -> spec-lint green (rc=0), validate green (rc=0)
result: PASS — the gates are not rubber stamps for this change
```

Probe D is deliberately the *hole*: a MODIFIED header that names nothing in the base is green under both gates and
only `openspec archive` refuses it. That is why the brief's "scratch archive" step is not optional — and probe C
shows the higher-value half is caught earlier (a dropped base scenario is caught by `validate`, which matches what
P7 re-measured).

- **Verdict: pass** for every command the brief asked for.
- **Not run / not verified:** nothing in the apply phase (no code exists yet), the container re-run of the build
  (E4's captures are the evidence; the apply brief re-runs it), and the TUI behaviour itself — the `[real]` scenarios
  are apply/verify work, marked as such in `tasks.md` and in §5 below.

## 5. Requirement → scenario → falsifier map

`[real]` = needs a tmux window (slow suite); every `[real]` scenario also has a headless sibling, so no requirement
rests on a single real-process run.

### `panel` (new capability, 12 requirements / 33 scenarios)

| Requirement | Scenario | Falsifier (apply-phase fixture) |
|---|---|---|
| 1 TUI in a terminal, never on a pipe | A pipeline receives plain text | `--once --print > f`; `tr -cd '\033' <f \| wc -c` = 0 and the first line names project + interval |
| | Redirecting stdout selects the plain-text path | redirected `--once` vs `--print`, timestamp-normalized `diff`, 0 ESC bytes |
| | The TUI still renders in a real pane `[real]` | fixture session 120×29: `capture-pane` shows the title band; `--print` writes no `ESC[H`/`ESC[2J` |
| 2 Three one-frame modes | The observers write no patrol state | `TEAM_STATE_DIR=<temp>`: no `capacity.log`, no `watchdog.tick.log` |
| | JSON carries the panel fields and the untouched data layer | `python3 -c json.load`: `panel.agents` + the `source/available/truncated/tail_limit/count/events` keys |
| | `--once` keeps the tick it has today `[real]` | fixture session: `capacity.log` +1 line (today's semantics, guarded) |
| 3 Four ordered bands + degradation | Band order is stable | `--print --width 120 --height 29`: line positions of title < PM/pending < first agent < reserved < key line |
| | The reserved band and the capacity figures fold away first | `--height 16`: no reserved label; `--height 10`: capacity on the PM line |
| | A tiny pane is not overrun `[real]` | 60×8 capture: ≤8 non-empty rows, ≤60 columns |
| 4 Status band | The band mirrors the measured state | fixture: `pm.state=absent`, pending 1/2/1/4, `outbox.queued=3`, `capacity.ram_avail_mb` = last sample, `spark` ≥2, no zram-physical key |
| | Standby is visible where the wake-ups are decided | `standby on --reason`: `panel.standby.on/reason` + the band |
| 5 Agent table | The added columns are real values | fixture worktree dirty + 3 ahead: `dirty=true`, `ahead=3`, `session_tokens` non-empty, `elapsed` only in JSON |
| | A stopped agent keeps its task visible | fixture without the `verify` window + recorded task `P9`: the row names it |
| 6 Activity column | The column is on by default and off on request | `TEAM_AGENT_LOG_GLOB` fixture: default frame has the event, `--no-activity` has neither it nor the heading, JSON array empty |
| | The bounded read survives | 12 MiB log: `truncated=true`, `tail_limit=65536`, ≤6 recent-action lines |
| | Only this session's windows are watched `[real]` | fixture session + a foreign session: the column names only the fixture's agent |
| 7 Display safety | An OSC 52 payload is stripped, not obeyed and not truncated | fixture event with `ESC]52;c;…BEL MORE ESC[2J END`: 0 ESC bytes, `safe`/`MORE`/`END` present |
| | A hostile branch name cannot clear the screen | fixture branch with `ESC[2J`: 0 ESC bytes, visible text present |
| | The TUI frame is captured clean `[real]` | capture of the hostile fixture frame: 0 ESC bytes, `MORE`/`END` present |
| 8 One tick loop | The tick-off flag leaves the panel alive `[real]` | `--no-watchdog` over two intervals: panel present, no capacity line, no new window |
| | One tick per interval, one process `[real]` | three intervals: capacity lines = intervals, window/`ps` count unchanged |
| 9 No runtime fails loudly | No runtime is a named failure, not an empty panel | stripped PATH: `--once`/`--print` non-zero, no title, fix named |
| | The escape key does not resurrect the panel | stripped PATH + `TEAM_REQUIRE_JS=0`: monitor non-zero, doctor 0 + warning |
| | No patrol window is created without a runtime `[real]` | stripped PATH: `team watchdog up` non-zero, `tmux list-windows` unchanged |
| 10 Queue read-only | A missing queue is a zero | no `outbox/`: `queued=0`, directory still absent |
| | Queued, held and the oldest age come from the entry names | 3 entries + 1 held: `queued=3`, `held=1`, `oldest_age_s` = now − the oldest name's epoch ±2 s |
| | Three render modes leave the queue byte-identical | hashes before/after `--print`, `--json`, one TUI frame `[real]`; `forced.log`/`HOLDING.log` unchanged |
| 11 One committed bundle | A fresh checkout runs the bundle | `env -u NODE_PATH node <file> --once --print --root <fixture>` from outside the repo, no `node_modules` |
| | The bundle declares what built it | header versions = `package.json` pins; `--version` prints them |
| | The rebuild is byte-identical `[real, network]` | `bun install --frozen-lockfile && bash build.sh` then `cmp` |
| 12 Keys | The redraw period is the redraw period `[real]` | `TEAM_MONITOR_REFRESH=1`: two captures 1.5 s apart differ in the timestamp line |
| | The activity default is a documented contract change | default shows the event, `ACTIVITY=0` hides it, `references/config.md` names the new default |
| | The UI key selects the renderer | `TEAM_MONITOR_UI=text` has 0 ESC bytes and equals `--print` apart from the timestamp |

### `memory-and-deps` (ADDED 1 + MODIFIED 1)

| Requirement | Scenario | Falsifier |
|---|---|---|
| A JS runtime is a required dependency (ADDED) | A machine without a JS runtime fails the environment check | stripped PATH (OpenSpec stubbed, `TEAM_REQUIRE_MAGIC_CONTEXT=0`): `team doctor` non-zero + fix; `TEAM_REQUIRE_JS=0 team doctor` 0 + warning |
| | An unusable or too-old runtime is named | `TEAM_JS_BIN=/nonexistent` names the path; a `v18.0.0` shim names 18 and the minimum |
| Tool resolution is visible (MODIFIED) | Paths expose the resolved tools (base, retained) | unchanged base scenario |
| | Paths expose the resolved runtime | `TEAM_JS_BIN=/usr/bin/node team paths` → `js_runner` + `"require_js": "1"`; `TEAM_REQUIRE_JS=0` → `"0"` |

## 6. What the apply phase must not miss

The migration list (E4 §8.2, re-verified on the base by line number) is in design §14 and in `tasks.md` item 8.2:
`smoke.sh:2358-2363` (title/prose/activity default), `2370` (`watchdog logs` capture), `1017-1019` (the
`TEAM_AGENT_LOG_GLOB` path), and the untouched `820-910` block for `monitor.mjs --json`. Design §3's three traps
(module format, bare imports, the package.json that is not a runtime dependency) are implementation notes with a
falsifier each, not prose.

One fixture trap this phase hit while writing the scenarios: on this box the OpenSpec CLI is itself a
Bun-installed script (`~/.bun/bin/openspec`), so a `PATH` stripped of node/bun/tsx breaks the OpenSpec check first
and the "no JS runtime" fixture would prove nothing about JS. Every stripped-`PATH` scenario therefore keeps the
other dependencies resolvable (stub OpenSpec CLI + `TEAM_REQUIRE_MAGIC_CONTEXT=0`), and `tasks.md` item 6.2 says so.

## 7. Deliberately not done (with reasons)

1. **No `watchdog` delta** — design §2: the base sentence stays true, and a third restatement of P5/P7's requirements
   buys nothing while risking a silent sentence loss.
2. **No step-2 implementation** — D19 puts the visualization band in the second change; C is a labelled placeholder
   that reads no data (design §5).
3. **No code, tests, references, `SKILL.md`, `CHANGELOG` or version bump** — the brief's boundary; every one of them
   has an apply item in `tasks.md`, including the two decisions the PM owns (the version number, and whether A2 may
   touch `.pi/**`/`AGENTS.md` — recommended: no, they are PM-owned).
4. **No re-run of E4's prototypes** — E4's committed captures are the measured basis, and this phase must not write
   code; the prototypes live on the E4 branch.
5. **No changes to `monitor.mjs`, `team status`/`team digest` or the meeting knock** — D24 keeps the data layer and
   the panel is `monitor`'s view only (`team_panel` has exactly one caller, `cmd-watch.sh:407`).
6. **No `TEAM_WATCH_*` → `TEAM_PULSE_*` naming** — P7 owns the rename; the panel names only `team monitor`,
   `TEAM_MONITOR_*`, `state/outbox/` and `state/capacity.log`, plus the three literals listed in the rename table
   (design §12).
7. **No choice of the final UI strings** — the spec pins band *order* and *field presence*, not the Chinese labels;
   the apply brief owns the wording, and the smoke assertions are written against ordered tokens (design §5).

## 8. Decisions and deviations

- **Deviations from the brief:** none on scope. Two choices the brief left open were decided here: the capability id
  is `panel` (not `pulse-panel`, design §2) and the delivery is two apply briefs (A1 behavior + tests, A2 docs +
  release) following P7's split, because the bundle, the renderer, the layout and the runtime failure paths cannot be
  one reviewable apply.
- **Recorded for the PM:** the RENAMED+MODIFIED probe (archive re-appends the renamed block at the end) — a measured
  fact about OpenSpec 1.8.0 that the next change with a rename should not have to rediscover.
- **Open items for the PM:** (1) the ordering of P7, P5 and this change's apply — recommendation: archive P7 first
  and give P7's A1 brief the one line about not hardcoding `watchdog` in the panel's key band; this change's apply is
  independent of P5 (the queue field is a zero until `state/outbox/` exists); (2) the version number for A2;
  (3) whether the `TEAM_MONITOR_ACTIVITY` default flip is acceptable as a contract change — it is the only default
  that moves, and `TEAM_MONITOR_ACTIVITY=0` restores today's layout.

## 9. Suggested next steps

1. PM review of the proposal and the delta (phase gate: no apply brief before an ACCEPTED proposal review).
2. If accepted: dispatch A1 (`skills/teamsmith/scripts/**`, `skills/teamsmith/tests/**` granted in the brief) and
   A2 (references, `SKILL.md`, `CHANGELOG`, version) in that order, then an independent verify brief against E4 §7's
   unverified list and E4 §8.2's migration list.
3. Archive last, with `openspec archive -y pulse-tui-panel` in a scratch copy first (probe D above is the reason).
