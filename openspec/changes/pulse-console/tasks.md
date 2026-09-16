# Tasks: `pulse-console`

Three apply briefs, dispatched and verified one by one, in this order (design.md §2): **B1** the async data
layer, **B2** the compose entry and the three actions, **B3** the console surface. Each item names the
capability requirement it moves and the command that can fail. `[real]` items need a real tmux pane/pty; each
has a headless sibling so no requirement hangs on a real process alone.

Path grants the apply briefs must state (OWNERSHIP): `skills/teamsmith/scripts/**` (panel sources, bundle,
`cmd-watch.sh`) and `skills/teamsmith/references/config.md` are PM-owned and granted explicitly;
`skills/teamsmith/tests/**` belongs to agent:dev. `openspec/specs/**`, `docs/team/**` and the ledger stay
PM-owned.

## B1 — asynchronous cached data assembly (apply brief 1)

This batch is the D26 precondition: the compose entry must not ship on the blocking data layer (E6 §2.3).

### 0. The measured "before" (the flip the report must carry)

- [ ] 0.1 On the review revision record: `time team monitor --once --print` (E6 §0 measured ≈7.0–7.2s wall,
  ≈6.2s user CPU on the reference checkout; one `watchdog-status` trace spawned git×111, grep×331, sed×211), and
  the keystroke-distortion fixture failing red (E6 §2.3: `Escape`+`m` → meta-`m`; `m`+text merged into one
  event). Verify: the timings and the red fixture log are pasted in the batch report.

### 1. The async core (`panel`: "Frame assembly is asynchronous, cached and never blocks input")

- [ ] 1.1 `data.ts`: replace `spawnSync` with spawned per-block builders writing an in-memory cache; the
  renderer reads the cache only. Verify: `grep -n spawnSync skills/teamsmith/scripts/panel/src/data.ts` prints
  nothing, and `team monitor --once --print` on the fixture is unchanged apart from the timestamp.
- [ ] 1.2 Per-block isolation and timeout: a missing, unreadable or failing source renders its block as `—`.
  Verify: with the fixture `BOARD.md` chmod 000 and no capacity log, `team monitor --once --print` exits 0,
  shows `—` for those blocks and renders the rest.
- [ ] 1.3 Reader trim: aggregate the bash reads. Verify: the report pastes the per-assembly process count before
  and after, and `time team monitor --once --print` ≤ 2s on the reference checkout.
- [ ] 1.4 Keystroke fixture `[real]`: a five-second reader stub, pty-driven typing of `m`+`hello`+Enter during
  the refresh. Verify: the fixture exits 0 on the branch (draft is exactly `hello`) and non-zero on the
  pre-change tree — the flip, both logs in the report.
- [ ] 1.5 CPU red line `[real]`: sample the console pane's process over 60s. Verify: the `ps` log in the report
  shows <1% of one core in steady state.
- [ ] 1.6 Regression: `bash skills/teamsmith/tests/smoke.sh` — sections 26-a…26-n green, unmodified. Verify:
  the tail is in the report.

## B2 — the compose entry and the three actions (apply brief 2)

### 2. The input line and the draft (`panel`: "A human can write to the PM from any page")

- [x] 2.1 `m` opens the bottom input line on the (single) page; CJK-wide cursor and codepoint backspace.
  Verify: pty fixture — after typing `中文ab`, `tmux display -p '#{cursor_x}'` reads 8 (E6 §1.2's shape).
- [x] 2.2 Ref-first draft state, `state/draft.md` persistence, `\r` normalization on intake. Verify: Esc → quit
  → relaunch → `m` restores the draft; a pasted payload containing `\r` renders as separate lines.
- [x] 2.3 `C-e` editor relay with the render callback explicitly gated during `$EDITOR`. Verify: the vi fixture
  round-trips a second line and the frame is intact (E6 drive2 T5's shape).
- [x] 2.4 Send runs `team draft send`; the receipt maps rc + outcome token to delivered / queued / held; the
  renderer never pastes into the PM pane. Verify: the busy-box fixture shows queued with one entry in
  `state/outbox/` and the PM pane's draft byte-identical; the clear-box fixture shows delivered.
- [x] 2.5 Compose-pause fixture `[real]`: with the slow reader stub, a refresh completes mid-compose.
  Verify: the draft is intact and another block's timestamp advanced.
- [x] 2.6 Paste-is-one-message fixture: bracketed and plain paste of three lines. Verify: exactly one outbox
  entry holding all three lines in both runs.

### 3. The action layer (`panel`: "The console is read-only except through three commands"; "The
   deferred-delivery queue is read, counted and never touched")

- [x] 3.1 `f` runs `team outbox flush` as a subprocess and shows its outcome; `s` runs `team standby on|off`.
  Verify: the fixture shows flush's own log line and `team watchdog status` reporting standby toggled twice.
- [x] 3.2 Write-sweep guard test: hash `state/`, `docs/`, the inbox; exercise every navigation key and several
  undocumented keys. Verify: no file outside `state/draft.md`, `state/panel.conf`, `state/panel-page` changed.

## B3 — the console surface (apply brief 3)

### 4. Pages and readers (`panel`: "The console composes three pages and remembers the position")

- [ ] 4.1 Three pages with the design's block inventory, empty-block collapse, Tab/`1`–`3`, and
  `state/panel-page` memory; the compose line opens from every page ("A human can write to the PM from any
  page"). Verify: fixture-pane captures of each page; quit on P3 → relaunch opens P3; `m` on P2 and P3 opens
  the input line.
- [ ] 4.2 The new read-only cached readers: board rows, changes with phases (`openspec list`, cached), spec
  counts, recent decisions, the outbox entry list, inbox/threads, the patrol-log tail, health (skill version +
  doctor; the gates cell renders `—`). Verify: each block renders against fixture data, and the queue
  byte-identical scenario still holds.
- [ ] 4.3 Flush list and read-only full view on the messages page (`panel`: the outbox requirement). Verify:
  two queued + one held fixture entries are listed with ages; viewing one shows the sanitized text; every file
  hashes the same afterwards.

### 5. Settings, layout, themes (`panel`: "Settings are panel preferences…"; "The layout is a pure function…";
   "State is never carried by color alone")

- [ ] 5.1 The settings overlay (`,`) with the five preferences, persisted to `state/panel.conf`, applied
  immediately; corrupt/missing file falls back to defaults. Verify: garbage conf → `team monitor --once --print`
  exits 0 and equals the no-conf output apart from the timestamp; the mouse toggle takes effect on the next
  frame and survives a relaunch.
- [ ] 5.2 `layout(width, height)` as a pure function; the four tiers and the documented degradation order;
  resize re-lays out live; `--width`/`--height` keep working. Verify: boundary captures at 160/100/99/60/59
  `[real]`; two `--print` runs byte-identical apart from the timestamp; a 60x8 pane is not overrun.
- [ ] 5.3 The snapshot suite: four widths × both themes pinned in `tests/`, plus the palette contrast script
  (4.5:1). Verify: the snapshots are asserted in the suite; forcing one pair below 4.5:1 makes the script exit
  non-zero (flip).

### 6. i18n and mouse (`panel`: "All visible text comes from external zh/en string tables"; "Every key
   affordance is also a mouse target")

- [ ] 6.1 Extract all visible strings into `src/strings/{zh,en}.ts`; the key-set assertion joins
  `skills/teamsmith/tests/smoke.sh` as a new subsection. Verify: the assertion exits 0 on the shipped tables and
  non-zero naming the key with one `en` key deleted (flip); `bash skills/teamsmith/tests/smoke.sh` is green.
- [ ] 6.2 Language switch applies on the next frame. Verify: a `zh` fixture pane shows English labels after the
  overlay toggle.
- [ ] 6.3 SGR mouse: enable/disable sequences, a click target per documented key, wheel scrolling, silent when
  the preference is off. Verify: E6's `pty_mouse.py`/`pty_tmux_mouse.py` moved into `tests/` — a click on the
  `m` hint opens compose; with the preference off the capture holds no `ESC[?1006h` `[real]`.

### 7. Collapse, keys, registration (`panel`: "The panel process is the patrol's single tick loop"; "The
   `TEAM_MONITOR_*` keys…"; `watchdog`: "One backend, inside the team's tmux session")

- [ ] 7.1 `team monitor --headless` (tick loop, no renderer); `q` respawns the patrol window into it;
  `team pulse up` restores the console; `team pulse status` reports the shape. Verify `[real]`: fixture session
  — after `q`, one window, a headless process, `capacity.log` still gaining; after `pulse up`, the console is
  back in the same window.
- [ ] 7.2 `TEAM_MONITOR_REFRESH` default 5s→3s; `panel.refresh_s` added to `--json`; `references/config.md`
  updated. Verify: `team monitor --json` shows `refresh_s` 3 when unset and 7 when set; `config.md` names the
  new default.
- [ ] 7.3 Register `state/panel.conf`, `state/panel-page` and `state/draft.md` in `references/config.md` / the
  state-file docs (E6 §3.7). Verify: the doc names all three with their fallback semantics.
- [ ] 7.4 Full gate on the batch branch: `openspec validate --all --strict` and
  `bash skills/teamsmith/tests/smoke.sh` both green, tails in the report.

## Deferred to v1.1 — not this change's scope

Plain bullets, deliberately not checkboxes: nothing below may be implemented under this change.

- [v1.1] Enter drill-down into a task detail page (the design's v1 cut line).
- [v1.1] The deferred queue's discard action — a fourth, destructive action; waits for the user's call
  (E6 §3.4).
- [v1.1] The milestone progress bar and milestone tree — no machine-readable ROADMAP source (E6 §3.3).
- [v1.1] The "last gates" record point — no file records gate runs today; until then the cell renders `—`.
- [v1.1] `team draft send --json` (E6 §2.5's nicety; v1 maps rc + outcome tokens).
