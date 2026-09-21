# Design: `watch-degradation` — the fast-wake channel's failure becomes visible, proven and distinguishable

## 1. Context

Read-only against this checkout (branch point `f9aa4d5`), plus the M50b probe package and today's live measurements
on this host.

- **The channel.** Senders write the durable inbox line and then append one pointer line to
  `state/inbox-watch/<key>.wake` (`scripts/lib/outbox.sh:1017–1035`). The extension
  `extension/team-inbox-watch.ts` watches that directory: `session_start` registers `<key>.reg`, records the
  baseline, then `watcher = watch(dir, …)` at `:781`, with the poll timer at `:788`
  (`TEAM_INBOX_WATCH_POLL_MS`, default 5000, `:57–62`).
- **The failure path today.** `:782–786`: `try { watcher = watch(…) } catch { appendLedger(root, 'watch unavailable:
  falling back to polling only') }` — the errno is swallowed, the quota is never read, and nothing durable is
  written. The poll timer is still installed, so delivery continues; nothing *reports* it.
- **What the CLI surfaces know.** `team_inbox_watch_route` (`outbox.sh:858`) resolves a target from `.reg`
  alone; `team_inbox_watch_skip_*` / `team_inbox_watch_degraded_text` (`:924–984`) model exactly two states —
  "registered" and "never registered (a `.skip` reason, or a running Pi with no record)". `team doctor`
  (`cmd-project.sh:517–523`) prints `✓ PM 会话已注册（通知走收件箱唤醒，不碰输入框）` on the first state, and
  `team status` reuses the same reader. The panel's PM block carries `delivery_warning`
  (`cmd-watch.sh:588`), rendered at `layout.ts:393–396` from `strings/zh.ts:18`, whose tail hard-codes
  `通知退回输入框粘贴慢路径（重启进程才加载扩展）`.
- **The gate.** `tests/team-inbox-watch-harness.mjs:60` sets `TEAM_INBOX_WATCH_POLL_MS='3600000'` before S2, so
  for S2–S13 the watcher is the only wake source on purpose. smoke's 12b-pi then asserts named `TEAM-IW-CASE PASS`
  lines from that run.
- **Today's live measurements (2026-09-21, this host).**
  - `cat /proc/sys/fs/inotify/max_user_watches` → `65536`; the M50b host scan → `65312` used, `Syncthing` 64737.
  - `node -e 'require("fs").watch("/tmp/x",()=>{})'` → `ENOSPC` (bun: `ENOSPC` too, different wording).
  - the harness on this tree → **34 s, 81 PASS / 31 FAIL, exit 1**, first line
    `S2 a new spool line wakes the session (fs.watch, polling disabled) :: messages=0`; smoke turns 6 of those
    PASS assertions red (M50b §4 lists the six; the full 31 are reproducible with
    `$HOME/.bun/bin/bun skills/teamsmith/tests/team-inbox-watch-harness.mjs skills/teamsmith/extension/team-inbox-watch.ts`).
  - `team doctor` on this tree → `投递通道 inbox-watch ✓ PM 会话已注册（通知走收件箱唤醒，不碰输入框）` — a
    false green about the exact channel that is degraded, and **no** inotify line anywhere.
  - **Why a count is not enough from here:** `/proc` inside this container is a private PID namespace (165
    processes, 16 watches visible); the host has 1015 processes and the same-uid `fdinfo` of a host process
    (Syncthing) answers `Permission denied`. A counter that trusts this view reports `16/65536` and a comfortable
    margin while `fs.watch` is failing. `distrobox-host-exec` can reach the host, but doctor must not depend on the
    container tooling of one development environment.

## 2. Root cause

1. **The cause is discarded.** The `catch {}` at `:784` records "unavailable" but not *why* — no errno, no quota —
   so neither a human nor a machine can tell a kernel limit from a code defect.
2. **The durable surfaces have no word for "registered, but not watching".** `.reg` means the fast path is live to
   every reader (`route`, doctor, status, panel); `.skip` means "no registration" and carries the paste-path story.
   A degraded-but-registered session therefore *must* be read as healthy by the current logic. The false green is
   structural, not a missing branch.
3. **The gate reads an environment premise as a code property.** With polling disabled, every wake-dependent case
   fails as `messages=0` on a dry host, and that signature is identical to a real regression — M50b had to run the
   probe on `main` and on the branch to tell them apart (`docs/team/reports/M50b-dev2.md` §4).
4. **The headroom is not reported anywhere**, and the one number a container can count is silently partial.

## 3. Goals / Non-Goals

**Goals.** (1) A registration failure leaves errno + quota + poll interval in the ledger *and* in a durable record
the CLI already knows how to read. (2) The polling fallback is a proven guarantee, not a happy accident, and the
sender-facing route does not change. (3) `team doctor`/`team status`/the panel stop claiming a healthy fast path
while the watcher is degraded, and the quota exhaustion becomes an operator-readable number with a fix. (4) The gate
distinguishes "this user cannot register a watch" from "the code broke", visibly, without ever becoming
unconditionally green.

**Non-Goals.** The default poll interval and the fallback cadence; the wake message shape, spool format and dedup
semantics (M43/P28 own them); the outbox, delivery guard and draft safety; `standby` and the pulse's "pending"
definition; re-arming `fs.watch` after a failure (follow-up F1); raising the host quota — an operator action, only
documented.

## 4. Decisions

### D1. Spec homes: three in `notify-and-inbox`, two in `watchdog`, one in `panel`

| # | Promise | Capability | Delta |
|---|---|---|---|
| R1 | the failure is recorded with errno + quota + poll interval, durably | `notify-and-inbox` | ADDED |
| R2 | the polling fallback still delivers, and the route survives | `notify-and-inbox` | ADDED |
| R3 | `team doctor`/`team status` report a live degraded record | `watchdog` | ADDED |
| R4 | `team doctor` reports the inotify headroom (with the probe) | `watchdog` | ADDED |
| R5 | the panel's delivery warning covers the degraded class, with the right consequence | `panel` | ADDED |
| R6 | the inbox-watch harness prints a visible unavailable premise; strict mode still fails | `notify-and-inbox` | ADDED |

`notify-and-inbox` owns R1/R2 and R6 because R6 is the observable contract of this channel's own harness: its
preflight, case verdicts and fixture controls. The existing `verification` capability specifies `team review`; using
it for a particular extension harness would widen that capability and violate this brief's three-delta grant.
`watchdog` owns the two read-only operational reports (R3/R4), while `panel` owns its rendered field (R5). The
`delivery-guard` capability is deliberately unchanged: `.reg` remains the routing proof, the degraded record is
read-only reporting state, and neither the paste path nor any guard/outbox behavior changes. The reader happens to
live in `outbox.sh`, but that implementation location does not make the new reporting promise a delivery-guard delta.

Cross-change check: open `gate-hygiene` MODIFIES panel frame assembly and adds a review-queue rule in
`verification`; M52 touches neither requirement. **P28/M46 relation:** `inbox-spool-resilience` still owns
reader offset/shrink/dedup/stale accounting, and M46's `.skip` record still means no registration. M52 adds the
separate state "registered, but not watching"; it neither repeats nor changes those contracts.

### D2. A `<key>.degraded` record — not `.skip`, not a ledger parse

`state/inbox-watch/<key>.degraded`, the same KEY=VALUE family as `.reg`/`.skip`:

```
version=1
target=<session>:<window>
key=<key>
reason=watch-unavailable
errno=ENOSPC
watches=<used>/<max>          # used = unknown unless the observer can establish a complete same-UID scope
poll_ms=<n>
forced=0|1
since=<ISO 8601>
pid=<pid>
cwd=<project root>
heartbeat=<epoch seconds>
```

Why not `.skip`: `.skip` means "no registration" to every reader — `team_inbox_watch_skip_text` prints the
"session mismatch / no tmux target" reasons, `team_inbox_watch_degraded_line` adds the paste-path remedy
(`重启进程`), the M46 harness counts exactly one `.skip` in S14, and smoke's 12b-pi2 hand-writes `.skip` fixtures.
Overloading it would make the sender-facing story wrong (the sender keeps the spool route — `.reg` is still there)
and collide with M46's assertions. Why not parsing the ledger: the ledger is append-only history and cannot answer
"is this target degraded now"; every other durable state in this family is pid/cwd-scoped and live-checked, and the
readers already implement exactly that rule.

Lifecycle: written once on failure; removed only after a later `fs.watch` registration succeeds for the same target,
or on clean shutdown (alongside `.reg`). It is read only by reporting surfaces — the routing decision
(`team_inbox_watch_route`) must never consult it, so a degraded watcher cannot push a sender back to the paste path.
(Pinned by the R2 scenario asserting `.reg` still routes, and by smoke's reading of the sender's `pi 监视通道` line.)

### D3. The ledger line keeps one canonical shape

`watch unavailable: errno=<E> watches=<used>/<max> poll_ms=<n> fallback=polling [forced=1]`

- `errno` comes from the caught error. `watches` is a same-UID count only when the observer can establish a
  complete scope; an unreadable or namespace-limited `/proc` emits `watches=unknown/<max>`, never a partial count
  presented as the user's total.
- `forced=1` is appended only for the fixture knob, so a test run cannot be mistaken for an incident.
- The line's prefix stays `watch unavailable:` — operators and the M50b probe already grep that token.

### D4. The fallback is proven with a forced failure, and the fixture knob is explicit

The poll timer is already installed unconditionally after the watch attempt (`:788`), so R2 needs no new machinery —
it needs a deterministic fault. `TEAM_INBOX_WATCH_FORCE_FAIL=<errno>` makes `session_start` skip `watch()` and take
the same failure path with that errno, recorded as `forced=1`. The harness snapshots that control before clearing
all inherited `TEAM_*`/tmux identity, then restores only its documented controls; otherwise its own isolation would
silently discard the requested fault. The same control forces the harness preflight premise, so
`TEAM_IW_ONLY=S2,S22,S23` deterministically gives S2 the unavailable premise while S22/S23 prove fallback delivery.
A knob is necessary because the extension imports `watch` at module load, so a harness cannot reliably replace it
across bun/node. `N` is three intervals: one to observe the write, one for the tick, one slack; the fixture uses
200 ms and asserts 600 ms. The default remains 5000 ms.

### D5. Doctor's headroom line is decided by a probe, not by a count

The brief asks for quota + current usage. Measured, a count alone is not honest here (§1): inside a container the
PID namespace hides the processes that hold the quota, so the count can read `16/65536` while registration fails.
So the line carries three pieces and warns on the right one:

```
check "inotify 额度"
  quota  = /proc/sys/fs/inotify/max_user_watches        # unreadable → named as unreadable
  usage  = same-UID descriptors only when the view is provably complete; otherwise unknown
  probe  = ok | errno=<E> | unavailable                  # one watch on a private temp dir, removed again
  warn when probe ≠ ok, or when free = quota − usage < TEAM_INOTIFY_MIN_FREE (default 1024)
  remedy: fs.inotify.max_user_watches=524288（宿主 /etc/sysctl.d/；Syncthing 与 VSCode 是常见占用者）
```

The probe reuses the runtime the project already resolves (`team_js_runner`, `common.sh:948`) and is bounded by a
timeout; it is a verdict about *this user's ability to register a watch now*, which is the fact the user cares
about, and prevents a namespace's deceptively small count from becoming a false green. The check is a warning, never
a `fail`: exhaustion is an environment fact, not a defect of this project, and doctor's exit code is consumed by the
panel's health block. The remedy names the operator action; no command of this tool may execute it.

### D6. The gate's premise is measured, printed, skippable and strict

- **Preflight.** Before the first selected case the harness snapshots its four documented test controls, clears
  inherited `TEAM_*`/tmux identity, and restores only those controls. Without the force control it attempts one
  `fs.watch` on a private temp directory; with `TEAM_INBOX_WATCH_FORCE_FAIL=<E>` it takes the same unavailable
  premise without a real registration and marks it `forced=1`. It prints `TEAM-IW-PREREQ watch=ok` or
  `TEAM-IW-PREREQ watch=errno=<E> watches=<used|unknown>/<max> forced=0|1 strict=0|1 skipped=<n> case(s)`.
- **Which cases.** The harness holds a literal, case-block-level set for assertions whose only wake source is the
  watcher (the current dry-host signature derives it from S2–S6, S9, S10–S13 and dependent S21 setup). Polling
  fallback cases S22/S23 and CLI-side cases remain runnable; no heuristic decides what gets skipped.
- **SKIP is a third verdict.** An unavailable marked case prints
  `TEAM-IW-CASE SKIP <case> :: watch unavailable (errno=<E>, watches <used>/<max>)`, increments a skip counter
  rather than `failures`, and the harness ends `TEAM-IW-HARNESS OK (skipped=<n>)`.
- **Strict.** `TEAM_IW_REQUIRE_WATCH=1` turns the same unavailable marked case into `FAIL` and a non-zero exit.
  Strict is never inferred from `CI`; CI that needs real watcher coverage exports the knob explicitly.
- **Never unconditionally green.** Smoke runs `TEAM_IW_ONLY=S2,S22,S23` with forced ENOSPC and requires
  `SKIP S2` plus `PASS S22/S23` and exit 0; the identical S2 fixture with strict requires FAIL and non-zero exit.
  Thus the fault-injection guard runs on every host, while a dry host makes its lost real-path coverage visible.
- **The smoke section reports the gap.** Today's 12b-pi named PASS assertions branch only on the prerequisite:
  failed premise means visible skipped assertions with the measurement; every unrelated assertion remains unchanged.

### D7. One reader, two consequences

`team_inbox_watch_degraded_text` (`outbox.sh:963`) gains the degraded class ahead of its existing logic: a live
`.degraded` record for the target returns the degraded sentence; otherwise the current "no live registration"
logic is unchanged. Doctor (`cmd-project.sh`), status (`cmd-status.sh`) and the panel's `delivery_warning`
(`cmd-watch.sh`) all call it, so the condition has one story. The panel's rendered line must not reuse the paste-path
tail for this class: `strings/zh.ts` / `en.ts` gain the class-specific tail ("唤醒退化为轮询，投递不中断" vs the existing
paste-path sentence for no registration). No plumbing change: the field and the status line already exist.

### D8. Docs and knobs

`references/troubleshooting.md` gains the ordered checklist (extension log `watch unavailable` → doctor's inotify
line → only then the code path) as a new section next to the existing watcher-registration section;
`references/config.md` documents `TEAM_INBOX_WATCH_FORCE_FAIL` as a fixture-only runtime fault and
`TEAM_IW_REQUIRE_WATCH` / `TEAM_IW_ONLY` / `TEAM_IW_KEEP` as harness controls. `references/**` is PM-owned: the
apply brief must grant it explicitly or the PM writes those files. No requirement is invented for documentation.

### D9. Rejected alternatives

- **Count the watches only** (the literal reading of the brief's headroom line): measured false green in a
  container (§1, §D5). The count stays as context; the probe decides.
- **Overload `.skip` or `.reg`**: breaks the sender story and M46's fixtures (D2).
- **Make doctor exit non-zero on exhaustion**: doctor's rc drives the panel health block and the user's toolchain
  check; exhaustion is an operator warning. The *gate* is where the premise must not be read as a defect — R6.
- **Auto-strict on `CI`**: contradicts `gates.yml`'s deliberate no-`CI` rule.
- **Retry `fs.watch` on every poll tick**: new behavior, not asked for; the session keeps polling and the record +
  probe make it visible (follow-up F1). A session that starts degraded stays degraded until restarted — the
  documented remedy covers it.
- **Change the default poll interval** so the degraded case looks faster: out of scope by the brief, and it would
  move a machine-wide resource knob to hide a condition.
- **A second watcher process / daemon**: forbidden shape (one backend, no new daemons).

## 5. Verification plan

### 5.1 New harness cases (the existing fake-Pi harness, `tests/team-inbox-watch-harness.mjs`)

- **S22 (R1).** Start with `TEAM_INBOX_WATCH_FORCE_FAIL=ENOSPC`: assert the ledger line contains
  `errno=ENOSPC`, a `watches=<used|unknown>/<max>` field, `poll_ms=`, `fallback=polling` and `forced=1`; assert the
  record's fields (`reason`, `errno`, `watches`, `poll_ms`, `forced`, `pid` = this process, `cwd` = the fixture
  root) and that `.reg` still resolves the target through the real CLI's route helper. Negative control: a healthy
  session writes no record.
- **S23 (R2).** The same forced failure with `TEAM_INBOX_WATCH_POLL_MS=200`: append one spool line, assert exactly
  one wake within 600 ms, the wake's shape (custom type, `triggerTurn`, `followUp`, inbox path, preview only) and
  the ledger's `wake n=1`; assert `.reg` is present.
- **S24 (R1 cleanup).** A stale record plus a successful session → the record is gone; a clean shutdown removes it.
- **Premise mechanics (R6)** are asserted by the smoke's two extra runs (D6), not by a case in the default run.

### 5.2 New smoke section (`12b-pi3`)

CLI-side fixtures with hand-written records (the 12b-pi2 pattern): a live `.degraded` → `team doctor`,
`team status`, `team __panel-data --block pm` and `team monitor --print` carry the degraded tokens and none of them
says `没有 inbox-watch 注册` or the paste-path tail; a dead-pid record → no degradation line; a healthy fixture →
no line; doctor's headroom: the default shape, `TEAM_INOTIFY_MIN_FREE` above the free margin → the 524288 remedy,
a stub `TEAM_JS_BIN` that reports `errno=ENOSPC` → the ENOSPC warning and rc 0, and no runtime → `unavailable`.
Plus the two filtered harness runs of D6.

### 5.3 Assertions that must stay green

Harness S1–S21 (names unchanged; on a healthy host every case still runs), the fallback assertions of S22–S24 in
every mode, 12b-pi's non-watcher assertions and its watcher assertions under the skip-aware branch, 12b-pi2's M46
fixtures, `flip-p25.sh`, `flip-m43.sh`, `flip-m46.sh`, and the existing doctor/status/panel assertions.

### 5.4 Flip matrix (the apply report must show each pair)

| Flip | Break | Goes red at |
|---|---|---|
| F-A (R1) | drop errno/quota from the ledger line | S22's line assertion |
| F-B (R2) | don't install the poll timer on the failure path | S23 (no wake) |
| F-C (R3) | return "healthy" for the degraded record in the reader | 12b-pi3's doctor/status false-green guard |
| F-D (R4) | make the probe always report `ok` | 12b-pi3's stub-ENOSPC warning |
| F-E (R6) | make the premise always `ok`; then make strict skip too | the skip fixture; the strict fixture |

### 5.5 Coverage map

| Requirement | Cases | Fixture |
|---|---|---|
| R1 failure recorded | D2/D3 | harness S22, S24 |
| R2 fallback delivers | D4 | harness S23 + the forced smoke run |
| R3 degraded channel reported | D7 | 12b-pi3 doctor/status |
| R4 inotify headroom | D5 | 12b-pi3 doctor (default / threshold / stub / no-runtime) |
| R5 panel warning | D7 | 12b-pi3 `__panel-data` + `monitor --print` |
| R6 premise SKIP + strict | D6 | 12b-pi3's two filtered harness runs |
| docs | D8 | troubleshooting/config sections exist and name the knobs |

### 5.6 Real-path evidence (not a gate)

This host is currently dry. The apply report should paste: the harness without forcing → the `TEAM-IW-PREREQ`
line, the SKIP lines and `TEAM-IW-HARNESS OK (skipped=n)` with exit 0; `team doctor` → the degraded warning and the
inotify line instead of today's false green. When the host quota recovers, the same run goes green — which is why
these are evidence, not assertions.

## 6. Risks, trade-offs, open questions

- **The probe adds a runtime spawn to `team doctor`** (the panel's health block calls doctor with a 600 s TTL and a
  30 s timeout). Bounded by a timeout; the JS runtime is already a required dependency and doctor already probes it.
- **`TEAM_INBOX_WATCH_FORCE_FAIL` reaches production code.** Mitigated: it only forces the failure path, both
  traces carry `forced=1`, it lives in the existing knob namespace, and `config.md` documents it as a fixture knob.
- **A skip can hide coverage.** Mitigated: the premise line and the skip lines are printed, the smoke section names
  the skipped assertions, strict mode turns the same premise into red, and R1/R2's guard runs in every mode.
- **The `.degraded` record can outlive its process** (crash, `kill -9`): readers apply the same live-pid/cwd rule as
  `.reg`/`.skip`, and the smoke has a dead-pid negative fixture.
- **A container can make a partial count look complete.** The implementation treats an observer that cannot establish
  its same-UID scope as `unknown`; the registration probe, not the count, carries the operational verdict.
- **F1 (follow-up, not built):** a session that starts degraded never re-arms the watcher, so it keeps the poll
  cadence for its whole life even if the quota recovers; the documented remedy is "fix the quota, restart the
  process". A later change can retry on tick and clear the record on success.
- **F2:** whether CI should export `TEAM_IW_REQUIRE_WATCH=1` in `.github/workflows/gates.yml` (PM-owned infra): the
  knob makes it possible; the decision is the PM's, and the gate image's quota is not controlled by this repo.
