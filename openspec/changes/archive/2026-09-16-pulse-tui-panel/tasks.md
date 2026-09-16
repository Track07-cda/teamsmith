# Tasks: `pulse-tui-panel`

Two apply briefs: **A1** moves the behavior and the tests, **A2** moves the docs and the release. Items are in
dependency order; each names the `panel` requirement it moves and the command that can fail. The verify phase is a
third agent (E4 §7's unverified list and §8.2's migration list are its attack surface).

Path grants the apply briefs must state (OWNERSHIP): `skills/teamsmith/scripts/**`, `skills/teamsmith/SKILL.md`,
`skills/teamsmith/references/**`, `skills/teamsmith/templates/**`, `skills/teamsmith/CHANGELOG.md` are PM-owned and
granted explicitly; `skills/teamsmith/tests/**` is agent:dev. `openspec/specs/**`, `docs/team/**` and `.pi/**` stay
PM-owned.

**Real-process items** are marked `[real]` — they need a tmux window; each also has a headless fixture, so no single
real-process run is the only evidence for a requirement.

## A1 — behavior and tests (apply brief 1)

### 0. The measured "before" (the flip the report must carry; defect: a pipe gets control bytes)

- [ ] 0.1 On the pre-change tree (the review revision), record: `team monitor --once > out.txt` writes 3 ESC bytes
  starting `ESC[H ESC[2J ESC[3J`; `team monitor --print` and `--json` exit 2 with `monitor: 未知参数`;
  `team doctor` has no JS-runtime entry; `team paths` has no `js_runner`/`require_js`.
  Verify: the captured file has a non-zero `trx -cd '\033' | wc -c`; on the branch the same commands give 0 ESC
  bytes, `--print`/`--json` exit 0, and doctor/paths carry the runtime lines (`panel` requirement 1;
  `memory-and-deps`).

### 1. The bundle and the build (`panel`: "ships as one committed bundle")

- [ ] 1.1 `scripts/panel/package.json` + `bun.lock` + `build.sh` + `src/**` — pinned build-time dependencies and the
  one build command; the build writes `scripts/panel/panel.js` and nothing else consumes the sources.
  Verify: `bash skills/teamsmith/scripts/panel/build.sh` exits 0 and the header of `panel.js` names the pinned
  framework versions and the build command; `node skills/teamsmith/scripts/panel/panel.js --version` prints the same
  versions.
- [ ] 1.2 Commit the bundle; record its size and sha256 in the report.
  Verify: `test ! -e node_modules` and `env -u NODE_PATH node skills/teamsmith/scripts/panel/panel.js --once --print
  --root <fixture>` (run from a directory outside the repository) exits 0 and prints the first band.
- [ ] 1.3 Reproducibility `[real, network]`: `bun install --frozen-lockfile && bash build.sh` in a scratch checkout,
  then `cmp` against the committed file.
  Verify: `cmp` exits 0; the log is in the report.

### 2. Modes, renderer selection and the data path (`panel`: requirements 1, 2)

- [ ] 2.1 `lib/cmd-watch.sh` (`team_cmd_monitor`) + `panel.js` CLI — `--print`, `--json`, `--width N`, `--height N`,
  `TEAM_MONITOR_UI=auto|tui|text`; stdout not a TTY selects the plain-text path; `--once` keeps the tick it has
  today; `--print`/`--json` write nothing into `TEAM_STATE_DIR`.
  Verify: `team monitor --once --print > out.txt` has 0 ESC bytes and its first line names the project and the
  interval; `team monitor --once > redirected.txt` equals it apart from the timestamp; with `TEAM_STATE_DIR=<temp>`
  neither `--print` nor `--json` creates `capacity.log`/`watchdog.tick.log`.
- [ ] 2.2 The data adapter — the panel asks `monitor.mjs --json` for the activity and the existing bash readers for
  the panel fields; `monitor.mjs`, its flags and its JSON keys are untouched.
  Verify: `git diff --stat` shows no change under `scripts/monitor.mjs`, and the ~25 `monitor.mjs --json` assertions
  in `tests/smoke.sh:820-910` stay green.
- [ ] 2.3 `--json` composition — one object with `panel` (project, timestamp, interval, standby, pm, pending,
  outbox, capacity, agents, recent) and `activity`.
  Verify: `team monitor --json | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["panel"]["agents"] and "activity" in d'`
  exits 0; the activity entries carry `source`/`available`/`truncated`/`tail_limit`/`count`/`events`.

### 3. Layout, bands and degradation (`panel`: requirements 3, 4, 5)

- [ ] 3.1 The four bands in order (A status, B agent table + activity column, C reserved placeholder, D key band) and
  the degradation order (C first, capacity into the PM line below 11 rows).
  Verify: `--print --width 120 --height 29` puts the PM/pending line before the first agent row, the reserved label
  before the last line, and the key line last; `--height 16` has no reserved label; `--height 10` has neither the
  reserved label nor a separate capacity line.
- [ ] 3.2 Band A fields — PM state vocabulary, pending counts, standby `{on, reason}`, queue counts, capacity
  (RAM MB, swap MB, agent estimate, sparkline from `capacity.log`), no zram physical MB.
  Verify: on a fixture with no PM window, 1 unread line, 2 reports awaiting review, 1 blocked row, 3 queue entries
  and 40 capacity samples, `--json` reports `pm.state=absent`, pending `1/2/1/4`, `outbox.queued=3`,
  `capacity.ram_avail_mb` equal to the last sample and `spark` with ≥2 values, and no zram-physical key.
- [ ] 3.3 Band B fields — the branch/dirty/ahead/session-size columns from `team_git_cols` and
  `team_session_tokens_est`, uptime only in `--json`, one row per agent, an `absent` agent still named with its task.
  Verify: the fixture with a dirty branch 3 commits ahead reports `dirty=true`, `ahead=3`, a non-empty
  `session_tokens`, `elapsed` in JSON but not in the printed table, and the stopped agent's task id in its row.
- [ ] 3.4 Activity column default on (`TEAM_MONITOR_ACTIVITY=0` restores today's layout), `--activity`/`--no-activity`
  override both ways, bounded read preserved (64 KiB default, 1 MiB cap, `truncated`/`tail_limit` reported), only
  this session's windows, and the last six lines of the patrol log as the recent-actions column.
  Verify: the default frame shows a fixture event; `--no-activity` shows neither the event nor the heading and its
  `--json` `activity` is empty; a 12 MiB fixture log reports `truncated=true`/`tail_limit=65536`; the recent column
  has ≤6 lines. `[real]` for the session-scope half (one agent window + one foreign window).

### 4. Display safety (`panel`: requirement 6)

- [ ] 4.1 Sanitize every string the panel reads itself (branch names, task ids, state files, queue names) with the
  same sanitizer, on top of the data layer's existing pass; keep the visible text.
  Verify: a fixture log holding `safe ESC]52;c;aGVsbG8=BEL MORE ESC[2J END` gives 0 ESC bytes and contains `safe`,
  `MORE` and `END`; a fixture branch name containing `ESC[2J` renders as text; the TUI frame over the same fixture
  captures with 0 ESC bytes. `[real]` for the frame half.

### 5. Tick ownership (`panel`: requirement 7)

- [ ] 5.1 The long-running panel owns the tick loop (`team_watch_once` per `TEAM_WATCH_INTERVAL`, `watchdog.tick.log`
  trimmed at 200 lines); `--no-watchdog` keeps the panel and stops the ticks; `--print`/`--json` never tick.
  Verify `[real]`: `team monitor --no-watchdog` for two intervals leaves `capacity.log` unchanged and
  `tmux list-windows` unchanged; the default run adds one line per interval; the window and process count changes by
  the panel's own only. Headless half: with `TEAM_STATE_DIR=<temp>`, `--print`/`--json` create no `capacity.log`.
- [ ] 5.2 `TEAM_MONITOR_REFRESH` drives the redraw and one frame reads the data once (no busy loop).
  Verify `[real]`: with `TEAM_MONITOR_REFRESH=1` two captures 1.5 s apart differ in the timestamp line; with a
  runtime shim that logs its invocations, one `--once` frame leaves at most two lines (the panel and one data read).

### 6. Runtime failure (`panel`: requirement 8; `memory-and-deps`)

- [ ] 6.1 `lib/common.sh` — `team_js_runner()` honours `TEAM_JS_BIN` first, then `node`/`bun`/`tsx`, and reports the
  resolved path + version; `team_paths_json` gains `js_runner` and `require_js`.
  Verify: `TEAM_JS_BIN=/usr/bin/node team paths | grep -o '"[^"]*node[^"]*"'` finds the path and `"require_js": "1"`;
  `TEAM_REQUIRE_JS=0 team paths` reports `"0"`.
- [ ] 6.2 `lib/cmd-project.sh` doctor — the JS runtime as a required check with the path/version evidence, the
  minimum (`node` 20 / `bun` 1.3), the fix line and the `TEAM_REQUIRE_JS=0` warning path.
  Verify: with a `PATH` without node/bun/tsx and `TEAM_JS_BIN` unset, `team doctor` exits non-zero naming node and
  bun and their fix, and `TEAM_REQUIRE_JS=0 team doctor` exits 0 with a warning; `TEAM_JS_BIN=/nonexistent` names
  that path; a shim printing `v18.0.0` is rejected naming 18 and the minimum. (The stripped `PATH` fixture keeps the
  other required dependencies resolvable — a stub OpenSpec CLI and `TEAM_REQUIRE_MAGIC_CONTEXT=0` — otherwise the
  OpenSpec check fails first and the fixture proves nothing about JS.)
- [ ] 6.3 `team monitor` in every mode fails loudly without a runtime (non-zero, one line, no panel) and
  `TEAM_REQUIRE_JS=0` does not change it; `team watchdog up` refuses before creating the window.
  Verify: with the stripped `PATH`, `team monitor --once` and `--print` exit non-zero without the panel title;
  `TEAM_REQUIRE_JS=0 team monitor --print` still exits non-zero; `[real]` `team watchdog up` exits non-zero and
  leaves no `watchdog` window.

### 7. The queue field (`panel`: requirement 9; interface owned by `delivery-guard`)

- [ ] 7.1 Read `state/outbox/`, `outbox/held/`, `forced.log` and `HOLDING.log` read-only; missing directory = 0; never
  create, enqueue, claim, move or drain.
  Verify: a fixture without `outbox/` reports `queued=0` and still has no directory; three entries + one held entry
  give `queued=3`/`held=1` and an `oldest_age_s` within two seconds of the oldest name's epoch; after `--print`,
  `--json` and one TUI frame both entry hashes are unchanged, nothing was added and `forced.log`/`HOLDING.log` did not
  grow.

### 8. Tests, isolation and the gate

- [ ] 8.1 New smoke section for §2–§7's headless fixtures (plain-text contract, JSON shape, band order/degradation,
  hostile payload, queue read-only, runtime failure, bundle runs with an empty `NODE_PATH`).
  Verify: `bash skills/teamsmith/tests/smoke.sh` green; the section goes red when the sanitizer call is removed from
  the panel's own strings and when `--print` is wired to the TUI path (break → red → restore → green).
- [ ] 8.2 Migrate the existing assertions E4 §8.2 lists (`smoke.sh:2358-2363`, `2370`, `1017-1019`) to the new
  title, the new prose and the activity default; keep the `monitor.mjs --json` block untouched.
  Verify: the full smoke suite is green, and `grep -c 'teamsmith monitor' tests/smoke.sh` shows no stale assertion
  left behind.
- [ ] 8.3 **Isolation (own item, M7.2 lesson)**: every new fixture runs in a sandbox repository with inherited
  `TEAM_*` cleared, asserts `team paths` resolves to the sandbox before any writing command, and compares a hash of
  the real `docs/team/inbox/**` and `.pi/team/state/**` before/after (any change fails with a diff).
  Verify: the fixture prints the `team paths` fragment and "real inbox/state unchanged"; a deliberately mis-pointed
  `TEAM_STATE_DIR` turns it red (negative control).
- [ ] 8.4 Gate: `openspec validate --all --strict && bash skills/teamsmith/tests/spec-lint.sh &&
  bash skills/teamsmith/tests/smoke.sh` (`TEAM_GATES`).
  Verify: exit 0 and the three summary lines in the report.

### 9. Long-run sample (`panel`: requirement 3's "not overrun", risk §15)

- [ ] 9.1 `[real]` Run the TUI for ~15 minutes at `TEAM_MONITOR_REFRESH=1` in a fixture pane, sampling
  `ps -o rss= -p <panel pid>` every 30 s, and capture two frames at the end.
  Verify: the frame is still well-formed, the RSS samples are within ±20% of the second sample, and the numbers are
  in the report (a leak is a finding, not a silent footnote).

## A2 — docs and release (apply brief 2)

- [ ] 10.1 `references/config.md` — the four `TEAM_MONITOR_*` keys with their defaults (including the changed
  `ACTIVITY` default), `TEAM_JS_BIN`, `TEAM_REQUIRE_JS`, and the `--print`/`--json`/`--width`/`--height` flags.
  Verify: `grep -c 'TEAM_MONITOR_UI\|TEAM_REQUIRE_JS\|TEAM_JS_BIN' references/config.md` is ≥3 and
  `grep -P '[\x{4e00}-\x{9fff}]' skills/teamsmith/references` is empty.
- [ ] 10.2 `references/troubleshooting.md` §3 — the panel's degradation story: no runtime is a hard failure, the
  activity default flip, `TEAM_MONITOR_UI=text` for a plain terminal, and the rebuild (`build.sh`, network) for
  maintainers.
  Verify: the section names all four and the English-only check stays empty.
- [ ] 10.3 `SKILL.md` command table + `team help` — `monitor` gains `--print|--json|--width|--height`; the panel is
  described as the patrol window's process, not a second backend.
  Verify: `team help | grep -c 'monitor'` ≥1 and the SKILL command table names the new flags.
- [ ] 10.4 `scripts/panel/README.md` — how to rebuild the bundle, why it is committed, the pinned versions and the
  size/sha256 of the committed artifact.
  Verify: the file names `build.sh`, the network requirement and the sha256.
- [ ] 10.5 CHANGELOG entry + `TEAM_VERSION` (the PM assigns the number at apply dispatch, since
  `rename-watchdog-to-pulse` may land first) + `team version --check`.
  Verify: `team version --check` exits 0 and the CHANGELOG entry names the panel rewrite, the required runtime and
  the activity default change.

## Evidence (A1 runs it; verify re-runs it independently)

- [ ] E1 Flip log: item 0.1's red (pre-change tree) and green (branch), with the ESC-byte counts and the doctor/paths
  tails, committed in the report.
- [ ] E2 Requirement → scenario → falsifier table: every scenario in `specs/panel/spec.md` and
  `specs/memory-and-deps/spec.md` names the fixture or capture that fails when the behaviour is removed; `[real]`
  items are marked.
- [ ] E3 Verify phase (a different agent): E4 §7's unverified list (a real 203×50 window, the long-run sample, the
  locale/terminal caveat, the reserved band) and E4 §8.2's migration list; plus the false-green attacks — a
  `--print` sample that hides an ANSI-writing TUI path, a panel that writes to the queue, a panel that ticks twice.
- [ ] E4 Archive (PM, phase 5, after independent verification and the user's confirmation):
  `openspec archive -y pulse-tui-panel`, then re-run the gate.
