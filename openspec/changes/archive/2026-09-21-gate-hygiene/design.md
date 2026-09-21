# Design: `gate-hygiene` — measure the gate, not the queue; measure the panel, not the machine

## Context

Measured on this branch (`task/P26-propose`, main `a65ee71`) unless a line says otherwise.

- **The false TIMEOUT (M49, 2026-09-20 07:49).** `team review` ran `timeout --signal=TERM --kill-after=60 1800`
  around `bash -c "$TEAM_GATES"` (`cmd-review.sh:479-497`) and measured one interval from before the call
  (`gate_elapsed`, `:499`). The gate command is `openspec validate … && bash skills/teamsmith/tests/smoke.sh`,
  and the full smoke queues on `/tmp/teamsmith-smoke.lock` **inside** the gate (`smoke.sh:94-127`: `exec flock
  --close -w "$SMOKE_LOCK_WAIT" "$SMOKE_LOCK"`). That round waited ~930 s for the lock and was killed at 28-i
  with 870 s of run budget spent; the same tree, same HEAD passed after the machine quieted
  (`docs/team/reviews/M49.md`, "PM 收口"). Nothing in `cmd-review.sh` knows a queue exists.
- **The false red (27-d, same tick).** The assembly assertion takes 5 samples of
  `team monitor --print --no-activity` and judges the **median** against 2000 ms (`smoke.sh:8755-8791`), already
  hardened once against single-sample spikes (V16/F-V16-10). Under loadavg 26–32 (four agents) the medians were
  4942/6335/4436/5339/2880 ms — a real contention signal, not a panel regression; the assertion printed the
  load in its message but judged red anyway.
- **The lock's own design (M23).** The suite serializes full runs because two suites fight for the same tmux
  server, node/bun and login shells; `flock --close` exists because fixture background processes inherited the
  lock fd and every later suite queued forever. `SMOKE_LOCK_WRAPPED=1` is the existing "the lock is already
  held by this process or an ancestor" marker, exported before the re-exec; FAST mode never touches the lock.
  The holder is recorded in `<lock>.holder` (`smoke.sh:124-128`).
- **The machine.** 32 logical cores, `cpu.max = max 100000` (no cgroup quota); loadavg 5.10 at recon time. The
  M49 load of 26–32 was therefore ≈0.81–1.0 × cores.
- **The verdict vocabulary is parsed, not read by humans.** `team_review_verdict` greps
  `判定: \*\*[A-Za-z]+\*\*` (`common.sh:2365`); `team_done_evidence` and the digest classify on that token
  (`common.sh:2482-2564`), and `team_cmd_review` returns 1 for `FAIL|TIMEOUT` (`cmd-review.sh:632`).
- **The panel red lines have two code paths.** 27-d inside the gate (median, 2000 ms) and
  `tests/panel-cpu.sh` — interactive first frame ≤ 2000 ms and steady-state pane CPU < 1 % of one core, exit
  0 pass / 2 red / 3 setup failure (`panel-cpu.sh:14-22, 220-233`). Both are invoked by humans and pasted into
  reports; neither has a premise.
- **The suite's result block** prints `✓ N ✗ N` and, in FAST mode, the skip count (`smoke.sh:10299-10302`);
  the review record keeps only the log tail (`tail -25`), so a skip that matters must reach that block.

## Goals / Non-Goals

**Goals.**

- The review's hard timeout measures the gate's **run**; the queue is a separate, bounded, accounted phase that
  can never produce `TIMEOUT`.
- A queue that exceeds its cap or a gate that is killed is told apart in the record, with the holder named.
- Timing red lines are judged only when the machine is below a stated load premise; otherwise they skip
  **visibly**, with the measured value and the load, and the run's summary/exit status cannot mistake the skip
  for a pass.
- The premise and the thresholds are stated in the specs; the resource discipline (FAST vs full, why the lock
  exists) is stated in the docs.

**Non-Goals.**

- No queue-jumping, no priority for verification (user decision), no change to the lock's default path.
- No change to any red-line threshold, no change to the median rule, no new `TEAM_*` product key.
- No new verdict token, no change to `team_review_verdict`'s grammar.
- No digest work (M50's read-path change owns that surface).

## Decisions

### 1. The queue is a review-level phase on the shared gate lock

The queue currently lives *inside* the gate command, so only the caller can keep it out of the clock. `team
review` therefore acquires the same lock **before** starting the timeout:

```
flock --close -w "$TEAM_SMOKE_LOCK_WAIT" "$lock" bash -c '
    date +%s > "$marker"; printf "%s pid=%s cmd=team review %s\n" "$(date -Is)" "$$" "$id" > "$lock.holder"
    exec "${runner[@]}" env "${gate_env[@]}" bash -c "$TEAM_GATES"'
```

- `queued = marker_epoch − review_start_epoch`, `ran = end_epoch − marker_epoch`; the record writes both against
  the limit. No marker file means `flock` never acquired (cap exceeded) → the queue-cap failure path.
- `--close` keeps the M23 lesson: the gate's descendants (fixture `sleep 3600` processes) must not inherit the
  lock fd.
- The lock path and cap reuse the existing keys (`TEAM_SMOKE_LOCK`, `TEAM_SMOKE_LOCK_WAIT`), so no new key and
  no second notion of "the machine's gate resource"; the default path stays `/tmp/teamsmith-smoke.lock`.
- Alternatives considered and rejected: letting the gate report its own queue time (the `timeout` deadline
  cannot be extended after the kill, so the number arrives too late); extending the timeout by the queue (two
  things in one budget — the shape that produced the false red); a separate review-only lock (two locks for one
  resource; the smoke would still queue inside the gate).

### 2. Nested runs: the wrapped marker, and fixtures get a private lock

- A review whose environment already carries `SMOKE_LOCK_WRAPPED=1` MUST NOT queue again: an ancestor holds the
  lock, so the subtree is already serialized. This is the same marker the suite exports today.
- When the review takes the lock itself, it exports `SMOKE_LOCK_WRAPPED=1` (and the resolved lock path) into the
  gate's environment, so a gate that *is* the smoke suite does not queue behind its own parent — otherwise every
  `team review` in this project would deadlock against itself.
- The suite must keep its fixtures off the machine lock: full mode inherits the marker; **FAST mode exports a
  private `TEAM_SMOKE_LOCK`** (and the marker) for its subtree, so a nested `team review` fixture in a FAST run
  can never contend with a concurrent full run elsewhere.
- Kept as-is: `SMOKE_LOCK_WRAPPED` is already the protocol (M23); renaming it (`TEAM_GATE_LOCK_HELD`) would buy
  clarity at the price of touching the working lock path for one change.

### 3. The record vocabulary stays closed

- The record's gate line becomes `门禁命令：…（硬超时 1800s；排队 930s；实际运行 870s）`; a `TIMEOUT` adds
  `ran=870s`; a queue-cap failure writes `判定: **FAIL**`, states that **the gate did not run**, names the holder
  and the cap.
- Why `FAIL` and not a new token: `FAIL|TIMEOUT` are already "not evidence" everywhere (board gate, digest,
  pending list); a new token would need every consumer updated for one error path, and the record itself states
  "the gate did not run" unambiguously.
- Why `ran=…` sits outside the bold token: `team_review_verdict`'s regex requires `**TOKEN**`; writing
  `**TIMEOUT(ran=870s)**` would make it return `none` — a record that *looks* verdict-less. The brief's
  `TIMEOUT(ran=…)` is therefore realised as `判定: **TIMEOUT**` plus the accounting fields, and the spec states
  exactly that (the parser result is a scenario assertion).

### 4. The load premise: `loadavg_1m ≤ 0.75 × logical cores`

- The threshold is calibrated from the recorded incidents, not invented: M49's false red happened at load
  26–32 on a 32-core machine (0.81–1.0 × cores) — the brief's illustrative `≤ cores` would have judged that
  round red and reproduced the false red. V16's single-sample reds at load 7–8 (0.22–0.25 × cores) are handled
  by the existing 5-sample median. `0.75 × cores` (24 on this machine) skips the M49 shape and judges a quiet
  machine.
- The premise is evaluated once per assertion from `/proc/loadavg` field 1; the core count comes from `nproc`,
  falling back to `getconf _NPROCESSORS_ONLN`. Fixtures substitute the load reading through test-only knobs
  (`TEAM_SMOKE_LOADAVG`, `TEAM_PANEL_CPU_LOADAVG`) — the same family as the existing
  `TEAM_SMOKE_FRAME_DELAY_MS` injection used for the median flip; product configuration is untouched.
- Thresholds do not move: on a machine below the premise a >2 s frame is red, in the gate and in
  `panel-cpu.sh`.

### 5. Skip visibility: the evidence path matters

- Inside `smoke.sh`: the assertion prints `SKIP（负载前提不成立：loadavg 26.0 > 0.75 × 32）` with the measured
  samples, increments a **timing-skip** counter (kept separate from `SKIP_N`, which 14c audits against the FAST
  segmentation), and the **result block** gains a line naming the skipped timing assertions and the load — the
  review record keeps only the last 25 lines, so the result block is the only place that reaches the record.
- In `panel-cpu.sh`: exit code **4** for a load SKIP (0 pass / 2 red / 3 setup failure), so a wrapper cannot
  read a skip as a pass; the summary line prints both measured numbers and the load either way.
- A skip is never silent: its printed line is the acceptance evidence that the red line was not judged, and the
  PM's review record therefore shows *why* the record is green without a performance verdict that round.

### 6. MODIFIED, not a parallel requirement, in `panel`

The user's inclination (brief B) is followed: the red line and its measurement premise are one contract. A new
"premise" requirement would leave the existing red-line statement unqualified; a reader would have to join two
requirements to learn when the number applies, and a future editor could change one without the other. The
MODIFIED block restates the base requirement and keeps all three of its scenarios (the archive refuses a
modified block that drops a scenario — the 2026-09-16 `drop-spec-lint` precedent, and the trial archive is in
the acceptance path).

### 7. The FAST/full resource rule stays in the docs (brief C)

The user decided it is not a new spec statement. What the specs own is the review's queue behavior; what the
docs own is the discipline — `TEAM_SMOKE_FAST=1` for in-batch self-tests, the full suite for delivery and
review, and why the lock and its cap exist. `references/protocol.md` §9b (the existing "tests and gates must
have a timeout" section) is the home; the AGENTS template and `SKILL.md` get the operational half.

## Risks / Trade-offs

- **[A permanently loaded machine never judges the performance red line]** → the skip prints the measured value
  and the load, and the flow keeps a fixture that judges it (`TEAM_SMOKE_FRAME_DELAY_MS`) and
  `panel-cpu.sh` for a quiet-machine run; the alternative is the false red this change removes.
- **[A nested review deadlocks against its own suite]** → the wrapped marker plus the private fixture lock;
  pinned by a fixture that runs a review inside a held lock and asserts it returns immediately.
- **[`flock` is missing]** → the review prints that the queue is not enforced and runs (today's behavior),
  recorded as no-queue; never a silent skip.
- **[`panel-cpu.sh` exit 4 surprises a caller]** → the fixture is human-run evidence, the code table is
  documented in its header and in protocol.md, and no automated gate calls it.
- **[The lock keeps its "smoke" name while the review uses it]** → the boundary forbids moving the path; the
  docs state one gate lock, and the key names are the mechanism's public interface.
- **[Bigger `cmd-review.sh` surface]** → the queue block is inert when `--no-gates`/`TEAM_GATES` empty and when
  the wrapped marker is present; all existing review fixtures (which set tiny `TEAM_GATES`) are the regression
  net.

## Testability

| Scenario (delta) | Observable red on the current tree | Fixture | Flip (apply phase) |
|---|---|---|---|
| queue 3 s + run 3 s, limit 5 s → PASS | today's record has no `queued` field; a queue inside the clock would TIMEOUT | held lock + `sleep 3` gate | move the lock acquisition inside the timed region → TIMEOUT; restore → PASS |
| queue cap exceeded → FAIL + holder | today's run never names the holder and never queues at this level | held lock + `TEAM_SMOKE_LOCK_WAIT=2` | remove the cap check → the run hangs/queues (red); restore → FAIL in ~2 s |
| real run over the limit → `TIMEOUT`, `ran=2s`, parser returns `TIMEOUT` | `ran=` absent today; `**TIMEOUT(ran=…)**` would make the parser return `none` | `TEAM_GATES='sleep 60'`, timeout 2 | write the parenthetical inside the bold → parser scenario goes red; restore → green |
| ancestor holds the lock → no second queue | today there is no queue at this level at all | nested review with the wrapped marker | make the wrapped check a no-op → the nested run queues to its cap (red); restore → immediate |
| no `flock` → printed notice | nothing is printed today | `PATH` without flock | delete the notice → assertion red; restore → green |
| loaded machine → visible SKIP + values + load | 27-d reports `bad` today under the same injection | `TEAM_SMOKE_LOADAVG` above / below the premise + `TEAM_SMOKE_FRAME_DELAY_MS` | remove the premise → the skip case goes red (red reported); restore → skip |
| quiet machine + slow frame → red | the injection is red today (that stays) | load reading below premise + injection | ship the premise as "always skip" → this scenario goes red; restore → red on a slow frame |
| CPU line carries the premise | `panel-cpu.sh` has no premise and exits 2 | load reading above/below | remove the skip → the above-premise case reports red; restore → exit 4 |

## Migration Plan

Nothing to migrate: the record grows additive fields, the lock protocol is backward compatible (a gate that
does not know the marker simply queues inside — the review only sets it while it holds the lock), and the
suite's fixture isolation is internal. Land in five batches (G1–G5 in `tasks.md`), gates green after each;
the full suite is required for the apply acceptance because the review fixtures are the regression net for the
nested-lock rules.

## Open Questions

None that would change the specs, the approach or the batch split. (The smoke section number for the new P26
evidence section is the apply batch's choice; it is evidence, not a promise.)
