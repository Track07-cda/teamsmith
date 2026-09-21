# Tasks: `watch-degradation`

Planning only — nothing in this file is executed by the propose task. Five batches can become **two apply briefs**:
**A1 = B1 + B4** (the `notify-and-inbox` failure/fallback and its measurable harness premise) and **A2 = B2 + B3 +
B5** (the `watchdog`/`panel` readers, docs and gates). A1 first: A2's smoke fixtures reuse its record, controls and
prerequisite line. Every guard needs a red → restore-green flip in its apply report. B5's 5.2–5.6 are process items,
not requirement items.

Coverage map (requirement → items): `notify-and-inbox` failure record → 1.1, 1.3, 1.5; polling fallback → 1.2,
1.4, 1.5; visible/strict watcher premise → 4.1–4.3; `watchdog` degraded-channel report → 2.1, 2.2, 2.4; inotify
headroom → 3.1, 3.2; `panel` delivery warning → 2.3, 2.4. Docs (no requirement) → 5.1.

Path grants an apply brief must state (OWNERSHIP): `skills/teamsmith/tests/**` is `agent:dev`'s;
`skills/teamsmith/extension/**`, `skills/teamsmith/scripts/**`, `skills/teamsmith/references/**` are **PM-owned**
and need an explicit grant per brief; `openspec/changes/watch-degradation/**` belongs to the phase's owner;
`openspec/specs/**`, `docs/team/**` and `ci/**`/`.github/**` stay PM-owned.

Fixture notes: every harness/smoke fixture clears inherited team identity (`TEAM_*`, `TMUX`, `TMUX_PANE`) and writes
only inside its scratch repo. The inbox-watch harness snapshots then restores only its documented fixture controls
(`TEAM_INBOX_WATCH_FORCE_FAIL`, `TEAM_IW_REQUIRE_WATCH`, `TEAM_IW_ONLY`, `TEAM_IW_KEEP`), so an intentional fault is
not silently discarded as inherited identity. The panel bundle may only be rebuilt with pinned bun and must reproduce
byte-for-byte.

## 1. B1 — the failure is recorded, and the fallback still delivers (`notify-and-inbox` ADDED)

- [ ] 1.1 `extension/team-inbox-watch.ts`: the failure path records `errno`, `watches=<used|unknown>/<max>`,
  `poll_ms` and `fallback=polling` in its ledger and writes `<key>.degraded` with the specified identity fields.
  Count usage only when the observer can establish a complete same-UID scope; unreadable or namespace-limited views
  report `unknown`, never a partial total. `TEAM_INBOX_WATCH_FORCE_FAIL=<errno>` takes this path with `forced=1`.
  A later successful `fs.watch` registration and shutdown remove the record; `.reg` survives failure. Verify: S22/S24
  and `grep -c 'watch unavailable: errno='` on the harness ledger.
- [ ] 1.2 `extension/team-inbox-watch.ts`: the poll timer stays installed on the failure path and keeps its interval
  semantics (default 5000 ms, `TEAM_INBOX_WATCH_POLL_MS`). Verify: S23; flip F-B removes the timer and S23 goes red.
- [ ] 1.3 `tests/team-inbox-watch-harness.mjs` (dev): **S22** — forced failure → the ledger line carries
  `errno=ENOSPC`, a `watches=` field, `poll_ms=`, `fallback=polling` and `forced=1`; the record carries the fields of
  1.1 with `pid` = this process and `cwd` = the fixture root; the real CLI's route helper still resolves the target
  from `.reg`. **S24** — a healthy session writes no record, and a successful session removes a stale one. Verify:
  `$HOME/.bun/bin/bun skills/teamsmith/tests/team-inbox-watch-harness.mjs skills/teamsmith/extension/team-inbox-watch.ts`
  prints `TEAM-IW-CASE PASS S22 …` / `S24 …`; on the pre-change extension the cases do not exist (red by absence).
- [ ] 1.4 `tests/team-inbox-watch-harness.mjs` (dev): **S23** — forced failure + `TEAM_INBOX_WATCH_POLL_MS=200`,
  one appended spool line → exactly one wake within 600 ms with the unchanged wake shape (custom type,
  `triggerTurn`, `deliverAs: followUp`, inbox path, truncated preview only), ledger `wake n=1 …`, `.reg` present.
  Verify: the same harness run prints the S23 PASS lines; with the watcher healthy the case still passes (it forces
  its own failure).
- [ ] 1.5 Flips: F-A (drop `errno`/`watches` from the ledger line → S22 red) and F-B (do not install the poll timer
  on the failure path → S23 red); restore both → green. Verify: both pairs of tails in the report.

## 2. B2 — the degraded channel is reported, and the panel tells the right story (`watchdog` + `panel` ADDED)

- [ ] 2.1 `scripts/lib/outbox.sh`: the reader for the degraded class —
  `team_inbox_watch_degraded_files` / `_live` / `_text` (live rule: pid alive + cwd inside the project, the
  `.reg`/`.skip` rule), consulted **before** the existing route/registration logic in
  `team_inbox_watch_degraded_text`; the degraded sentence names `投递通道降级`, the errno, `watches <used>/<max>`,
  `轮询` and `fs.inotify.max_user_watches=524288`. The no-registration path (skip reasons, running-Pi-without-a-record,
  the 12b-pi2 wording) stays byte-for-byte. Verify: 2.4's fixtures plus the existing 12b-pi2 section unchanged.
- [ ] 2.2 `scripts/lib/cmd-project.sh`: doctor prints the shared degraded sentence as a **warning**, never
  `✓ PM 会话已注册`, while the healthy branch keeps today's pass line; the existing `cmd-status.sh` shared-reader call
  gives `team status` the same sentence without a second classifier. Verify: 2.4's live/dead/healthy fixtures and
  unchanged doctor rc.
- [ ] 2.3 `scripts/panel/src/strings/{zh,en}.ts` (+ `scripts/lib/cmd-watch.sh` if the reader needs a second field):
  the delivery warning keeps the paste-path tail only for the no-registration class; the degraded class gets its own
  tail (`唤醒退化为轮询，投递不中断` / the English equivalent). Then `bash skills/teamsmith/scripts/panel/build.sh`
  and commit the rebuilt `panel.js`. Verify: `git diff --exit-code skills/teamsmith/scripts/panel/panel.js` after a
  second rebuild (deterministic bundle) and smoke's bundle assertions (26-a/26-b) green.
- [ ] 2.4 `tests/smoke.sh` (dev): new section `12b-pi3` — hand-written fixtures (the 12b-pi2 pattern): a live
  `.degraded` record + live `.reg` → `team doctor`, `team status`, `team __panel-data --block pm`,
  `team monitor --print` carry the degraded tokens and none of them says `没有 inbox-watch 注册` or the paste-path
  tail (`assert_not`); a dead-pid record → no degradation line; a healthy fixture → no line and
  `"delivery_warning": ""`; a `.skip`-only fixture → the M46 wording still appears. Verify: the section's tail.

## 3. B3 — `team doctor` reports the inotify headroom (`watchdog` ADDED)

- [ ] 3.1 `scripts/lib/common.sh` + `scripts/lib/cmd-project.sh`: the headroom helper (quota from
  `/proc/sys/fs/inotify/max_user_watches`; count only a provably complete same-UID view, else `unknown`;
  `TEAM_INOTIFY_MIN_FREE`, default 1024, non-numeric → default) and the one-shot registration probe through
  `team_js_runner` (`mkdtemp`, one `watch`, remove; bounded by a timeout; verdict `ok` / `errno=<E>` /
  `unavailable`); one doctor check line that warns —
  never fails (`fails` counter untouched) — when the probe is not `ok` or the known headroom is below the threshold,
  with the remedy `fs.inotify.max_user_watches=524288（宿主 /etc/sysctl.d/；Syncthing 与 VSCode 是常见占用者）`.
  Verify: 3.2's four fixtures.
- [ ] 3.2 `tests/smoke.sh` (dev): the four shapes — default (line names `max_user_watches` and `ok`), threshold above
  the free margin (warning names `524288`, `Syncthing`, `VSCode`; rc stays whatever it was), a stub `TEAM_JS_BIN`
  whose probe verdict is `errno=ENOSPC` (warning names `ENOSPC`), and no resolvable runtime (`unavailable`, never
  `ok`). Verify: the section's tail; flip F-D (probe hard-coded to `ok` → the stub fixture red).

## 4. B4 — the gate measures its inbox-watch premise (`notify-and-inbox` ADDED)

- [ ] 4.1 `tests/team-inbox-watch-harness.mjs` (dev): before clearing inherited identity, snapshot only
  `TEAM_INBOX_WATCH_FORCE_FAIL`, `TEAM_IW_REQUIRE_WATCH`, `TEAM_IW_ONLY`, `TEAM_IW_KEEP`; clear `TEAM_*`, `TMUX`,
  `TMUX_PANE`, then restore only that allowlist. Before selected cases, preflight a private-dir `fs.watch`, except
  the explicit force control must exercise the same unavailable premise without a real registration and add
  `forced=1`. Print `TEAM-IW-PREREQ watch=ok` or `watch=errno=<E> watches=<used|unknown>/<max> forced=0|1
  strict=0|1 skipped=<n> case(s)`. Maintain a literal watcher-dependent case set; unavailable cases use third verdict
  `TEAM-IW-CASE SKIP <name> :: watch unavailable …`, neither pass nor failure, with
  `TEAM-IW-HARNESS OK (skipped=<n>)`. Strict turns the same case into FAIL/non-zero; `TEAM_IW_ONLY` filters cases.
  Verify: 4.2's four runs.
- [ ] 4.2 `tests/smoke.sh` (dev): branch the existing named PASS assertions only on the prerequisite: unavailable
  watcher cases are visibly suite-skipped with their measured reason, unrelated assertions stay unchanged. Add
  `TEAM_INBOX_WATCH_FORCE_FAIL=ENOSPC TEAM_IW_ONLY=S2,S22,S23` → `SKIP S2`, `PASS S22/S23`, exit 0; the strict S2
  equivalent → premise-naming FAIL and non-zero. Verify the output and both exit codes.
- [ ] 4.3 Flip (F-E): falsely report the forced/unavailable premise as `ok` → the SKIP guard goes red; restore, then
  make strict skip → strict exits 0 (red); restore → green. Verify both red/green tails.

## 5. B5 — docs, gates, real evidence

- [ ] 5.1 PM-owned grant needed: `references/troubleshooting.md` gains the ordered checklist (extension log
  `watch unavailable` → doctor's inotify line → only then code), cross-linked from §22. `references/config.md`
  documents `TEAM_INBOX_WATCH_FORCE_FAIL` as fixture-only and `TEAM_IW_REQUIRE_WATCH`/`TEAM_IW_ONLY`/`TEAM_IW_KEEP`
  as harness controls in an appropriate test-controls section. Verify grep finds the keys and the checklist names all
  steps.
- [ ] 5.2 Full gate: `PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh`
  — green on the full suite; paste the tail. Verify: exit 0.
- [ ] 5.3 Run the flip matrix F-A…F-E in sequence (1.5, 3.2, 4.3 and F-C in 2.4), each with its red and green
  tails. Verify: all five pairs.
- [ ] 5.4 `[real]` dry-host evidence, pasted: the harness without forcing → the `TEAM-IW-PREREQ` line, the `SKIP`
  lines and `TEAM-IW-HARNESS OK (skipped=n)` with exit 0; `team doctor` → the degraded warning and the inotify line
  instead of today's `✓ PM 会话已注册`; the delivery fallback proven by S23 in the same run. Verify: the tails (when
  the host quota recovers this run goes green — evidence, not an assertion).
- [ ] 5.5 Trial archive on a scratch copy (`cp -r openspec /tmp/trial && (cd /tmp/trial && openspec archive -y
  watch-degradation)`) — proves all six ADDED requirements are valid and that nothing in the deltas collides with
  the open `gate-hygiene` / `inbox-spool-resilience` changes. Verify: the trial output.
- [ ] 5.6 FAST during development: `TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null` — the new
  section's fast behavior is explicit (a visible skip, never a silent omission). Verify: exit 0 and the skip table.
