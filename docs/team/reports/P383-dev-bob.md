> **Current result:** V110's counted-wait rework is delivered for focused independent review at
> code commit `082e50f33642bb5f9328d6c6bfb410cdbb99ec42`; see the appended **V110 rework**
> section for its tests and limitations. The previous delivery and PARTIAL below are preserved as
> historical evidence: V110 rejected the previous candidate's wait accounting.

# P383 · Key-replies mouse scroll: final candidate

agent: dev-bob   status: DELIVERED FOR INDEPENDENT REVIEW   time: 2026-10-27 UTC

branch: `task/P383-key-replies-mouse-scroll-cla`   PR/MR: - (local mode)

## Answer and scope

The reproduced failure was in the shared test driver, not a demonstrated product clamp bug: it
wrote 40 mouse events without reading its pty; the panel blocked on a full output queue, and the
shared deadline then caused the driver to collect an incomplete frame. The detailed kernel and
frame evidence, including the initially blocked report, is preserved unchanged below under
**Historical PARTIAL**. After PM authorized the driver path, the candidate drains available output
between writes, waits for the actual list frame before scrolling, and waits for an overlay frame
queued after the last wheel event before checking the restored list frame. The latter is an input
processing barrier, including for no-op events at the clamp; it is closed before the viewport is
judged. Frame waits remain bounded by the existing 25-second deadline, with no added fixed sleep.

`key-replies-pty.sh` now treats either driver's nonzero exit, missing/empty output, incomplete
synchronized frame or incomplete UTF-8 as failure. It judges the **last complete** frame rather
than absence from an arbitrary stream. The original `#1` present / `#38` absent assertions remain.
Only the two authorized test files changed; no product source, bundle, CI schedule or OpenSpec
was changed.

## Identity and reproducibility

- Baseline: clean `626e9b2d74aa010b35e25425c791096008d7b7a4`, tree
  `3269127befaced1f4e37479edc97033297a974ce`.
- Final tested code: `c05f6dbc822d9274f0b7dda8449c08abac040586`, tree
  `9714413f676b79293ab1247222eeda742bb655e2`; code commits `63b58d73` and `c05f6dbc`.
  Both final selected gates recorded identical clean-tree fingerprints at start and finish.
- Image: immutable `91fa9dab310641a6f4dca892520a31a3cd9d3699fb34919c468ad22d929df793`,
  created `2026-10-27 01:51:16 UTC`; default gate `cpu.max=max 100000`. Image runtime Node
  `v24.22.1`, Bun `1.3.14`, Python `3.13.5`, tmux `3.7b`; host Node `v24.22.1`,
  Python `3.13.12`, tmux `3.7b`; host Podman `5.8.3`. Both used `COLORTERM=truecolor`.
- Final SHA-256: test shell `0098fe1493a575a6ddf465aa0bc1582c1fdbf4609bf735f9b7ac2d933f374c09`,
  driver `3710017263b917eaa8c929d054c6c67543ba8fd41c40995e2ee307b7263db0ff`;
  unchanged bundle `734cf6f7592050d9beba2fc8947b256f654d44976dfea0a38bc358f32f7d5863`
  and reply command `27070f77cace745318d4df5a92242f8ce0be46bffeea2b9e6fa991cf1179941f`.
- Full logs, raw frames, test roots and the exact shell runners are on the host at
  `~/.cache/p383/` (mounted to `/e` in the image). The final runners are
  `run-host-gates.sh`, `run-container-gates.sh`, `container-gates-inner.sh` and
  `run-mutations.sh`; their results are under `gates-c05f6dbc/` and `flips-c05f6dbc/`.
  The container was launched via `distrobox-host-exec podman run --rm --pid=host
  --cgroups=enabled --userns=keep-id`, with the worktree and git common directory read-only,
  the log directory bind-mounted read/write, and the image identified by the full ID above.

## Red → green and adversarial flips

The exact unmodified host baseline was `✓13 ✗1 SKIP0`, failing the original 40-wheel `#1`
assertion. The same image at the default CPU setting was green on three baseline attempts;
under `--cpus=1` the baseline was `✓11 ✗3 SKIP0`, including that 40-wheel failure, so its
additional three-wheel failures must not be conflated with the single-failure host run. The raw
host and 1-CPU failing streams each ended inside the first frame at `#27` (4,181 bytes, one
frame start and no frame end). See the historical evidence below for the queue, wait channel,
system-call and controlled drain/no-drain comparisons.

The final host and 1-CPU raw after-streams contain complete final frames: 3 wheels show
`#35..#14`, and 40 wheels show `#22..#1`, with `#38` absent. For example, the host 40-wheel
stream has 18,092 bytes and three complete synchronized frames; the 1-CPU stream has the same
size and frame count. They are respectively:

```text
~/.cache/p383/gates-c05f6dbc/host/tmp/teamsmith-p234-reply-pty-pm_skills-deb708fe.XM31gX/m-end-after.bin
~/.cache/p383/gates-c05f6dbc/container/cpu1/tmp/teamsmith-p234-reply-pty-pm_skills-deb708fe.eneqsL/m-end-after.bin
```

`bash ~/.cache/p383/run-mutations.sh` ran real mouse fixtures against isolated scratch copies,
not the committed product bundle, and returned `mutation_assertion_failures=0`. In each red arm,
the 3-wheel control still succeeded. Exact outcomes (`rc` is the fixture exit code):

| Scratch mutation | Result | Evidence |
|---|---:|---|
| Restore no drain during 40 paced writes | 1 | `✓12 ✗1 SKIP0`, driver reports deadline while collecting wheel output |
| Force the 40-wheel driver to exit 41 after writing valid output | 1 | `✓12 ✗1 SKIP0`, explicit `驱动失败（rc=41）` |
| Empty the 40-wheel after-stream | 1 | `✓12 ✗1 SKIP0`, `no complete final frame` |
| Truncate inside a subsequent frame-start marker | 1 | `✓12 ✗1 SKIP0`, `partial frame marker` |
| In scratch `panel.js`, make the 40th wheel reset to the top | 1 | `✓13 ✗2 SKIP0`, the unchanged `#1` and `#38` assertions both fail |
| Restore the candidate files | 0 | `✓15 ✗0 SKIP0` |

The restored no-drain defect is caught at the driver-failure assertion rather than the `#1`
assertion: after a failed driver there is deliberately no valid frame on which to run `#1`.
The separate 40th-event product mutation proves the original behavioural assertions still turn
red on a complete frame and that the barrier did not merely stop at the 16th event. The
mutated bundle exists only in the host scratch copy and is not a delivered generated artifact.

## Final checks, with limits

Commands below ran on the clean final code commit; their complete logs are in
`~/.cache/p383/gates-c05f6dbc/{host,container}/`.

```text
# Host, COLORTERM=truecolor; six existing shared-driver groups
$ bash skills/teamsmith/tests/panel-b3.sh workdetail mouse wheel board detail fold
== 结果 == ✓ 176 ✗ 0                         rc=0
$ bash skills/teamsmith/tests/key-replies-pty.sh --all
== P234 key-replies-pty 结果 == ✓80 ✗0 SKIP0 rc=0
$ bash skills/teamsmith/tests/smoke.sh --select 63
11 段收口 · 增量 ✓434 ✗0 SKIP2             rc=0

# Same commands inside the pinned, unrestricted image
$ openspec validate --all --strict
Totals: 19 passed, 0 failed (19 items)        rc=0
$ bash skills/teamsmith/tests/key-replies-pty.sh --all
== P234 key-replies-pty 结果 == ✓80 ✗0 SKIP0 rc=0
$ bash skills/teamsmith/tests/smoke.sh --select 63
11 段收口 · 增量 ✓434 ✗0 SKIP2             rc=0

# Same image, resource-modified diagnostic only, NOT the default CI shape
$ bash skills/teamsmith/tests/key-replies-pty.sh --select mouse
cpu.max=100000 100000; ✓15 ✗0 SKIP0         rc=0

$ bash -n skills/teamsmith/tests/key-replies-pty.sh skills/teamsmith/tests/smoke.sh
rc=0
$ python3 -c 'import pathlib; p=pathlib.Path("skills/teamsmith/tests/panel-b3-pty-mouse.py"); compile(p.read_bytes(),str(p),"exec")'
rc=0
$ bash skills/teamsmith/tests/section-select.sh --check
== 选段自检 == ok 12 bad 0 SKIP 1           rc=0
$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
scope=published files=2221 hits=0 names=ok user=resolved  rc=0
$ git diff --check && git show --format= --check HEAD
rc=0
```

The selected gate includes dependencies and records two real skips: `38-h` and `38-i` were not
selected directly; they are not passes. The section-map check's one skipped prerequisite is the
absent generated `.pi/skills` path. Section 63's own nested fixture summaries are `✓72 ✗0
SKIP0` for its UI and `✓80 ✗0 SKIP0` for its pty. Its existing banner counts occurrences of
`✓` and `SKIP` in those logs (including the `✓… SKIP0` summary line), and therefore prints
`73 / 1` and `81 / 1`; use the nested summaries, not those misleading banner counts. This
pre-existing label issue is outside the repair and `smoke.sh` was not changed.

A predecessor candidate `63b58d73` had a host selected-gate failure in the unrelated `list` and
`async` tmux startups; their captures were blank while its mouse checks passed. Its earlier
1-CPU diagnostic had two zero-byte startup failures. Those logs remain under
`gates-63b58d73/{host,container}/`; later green runs do not prove those intermittent startup
conditions are fixed. No full smoke suite, public GitHub Actions run, panel source rebuild,
remote push or merge was run. The task brief explicitly asks for selected gates, not full smoke;
124 unselected keys are listed in each selected-gate log. Independent `team review P383 --strong`
remains for the PM.

---

## Historical PARTIAL / BLOCKED report (preserved)

# P383 · Key-replies mouse scroll: shared pty driver blocks its own panel

agent: dev-bob   status: PARTIAL / BLOCKED   time: 2026-10-27 UTC
branch: `task/P383-key-replies-mouse-scroll-cla`   PR/MR: - (local mode)

**BLOCKED:** The smallest supported repair needs `skills/teamsmith/tests/panel-b3-pty-mouse.py`,
which is outside the P383 authorized write set. Its wheel loop writes 40 SGR events without reading
its pty, and its single startup deadline also governs the final read. The panel can block writing
a frame until that deadline has expired; the driver then reads only one chunk and terminates it.
The evidence below shows this happening on the host and the same incomplete frame in the fixed image
under a one-CPU control. No product or fixture file was changed. The PM needs to authorize the
shared driver path before the fix, final gates, and a genuine post-fix mutation can be delivered.

## Evidence and conclusion

The baseline was a clean checkout at commit `626e9b2d74aa010b35e25425c791096008d7b7a4`, tree
`3269127befaced1f4e37479edc97033297a974ce`, equal to `main` when the baseline began. During the
investigation `main` advanced in ledger-only commits; the controlled runs deliberately held the
original tree fixed. `git diff --name-only 626e9b2d main` at the end listed only files under
`docs/team/`. The test file, helper, bundle and reply command were byte-identical to that frozen
tree in all arms. Relevant SHA-256s:

```text
key-replies-pty.sh       83de6b1002e75d0cfcd21d6f282d62e9c9c43428dea486de3dbf3d6a88266518
panel-b3-pty-mouse.py    33a55ed749e7ae5805f6823f9b19def385fdabb62378b06a1bad9f7c461157de
panel.js                 734cf6f7592050d9beba2fc8947b256f654d44976dfea0a38bc358f32f7d5863
cmd-reply.sh             27070f77cace745318d4df5a92242f8ce0be46bffeea2b9e6fa991cf1179941f
```

The pinned image was `91fa9dab310641a6f4dca892520a31a3cd9d3699fb34919c468ad22d929df793`,
created `2026-10-27 01:51:16 UTC`; Podman `5.8.3`, kernel `7.1.3+deb14-amd64`. Container runtime:
Node `v24.22.1`, Bun `1.3.14`, Bash `5.2.37`, Python `3.13.5`, tmux `3.7b`. Host runtime:
Node `v24.22.1`, Bash `5.3.9`, Python `3.13.12`, tmux `3.7b`; host `COLORTERM=truecolor`.
This fixture runs the bundled Node/Ink panel, not Pi. I did not compare the release log to infer
an image regression: the old run's image identity has not been established.

Complete logs, scripts and binary pty streams are on the host under `~/.cache/p383/`, mounted into
the container. `baseline.sh`, `diagnose.sh`, `container-truecolor.sh`, `container-cpu1.sh`, and
`container-cpu.sh` record the commands and environment. `summarize.py` and `frame-summary.log`
reproduce the frame counts from the retained bytes; `host/diag-fd.log` and
`host/diag-syscall.log` contain the event-by-event kernel observations.

### Clean baseline and container boundary

```text
$ bash ~/.cache/p383/baseline.sh
host_rc=1
  ✗ mouse：滚 40 格到底被夹住（最旧的 #1 进入窗口，不换页）
  == P234 key-replies-pty 结果 == ✓13 ✗1 SKIP0
container_rc=0
  == P234 key-replies-pty 结果 == ✓14 ✗0 SKIP0

$ bash ~/.cache/p383/container-cpu1.sh
# same image/tree; --pid=host --cgroups=enabled --cpus=1; COLORTERM=truecolor
cpu.max=100000 100000
container_cpu1_baseline_rc=1
  ✗ mouse：滚 40 格到底被夹住（最旧的 #1 进入窗口，不换页）
  == P234 key-replies-pty 结果 == ✓11 ✗3 SKIP0
```

The one-CPU run also failed both three-notch assertions, so it is **not** an exact reproduction of
the earlier single-failure counts. Its 40-notch raw stream and the host's stream are each 4,181
bytes, start one synchronized frame, end no synchronized frame, stop at the partial `#27` row,
and contain no `#1`. The container's `m-end-after.bin` and the full log are retained under
`container/cpu1/`; the host's are under `host/`.

The unrestricted container run was green on three attempts (two with no `COLORTERM`, one with
`COLORTERM=truecolor`), each `✓14 ✗0 SKIP0`. P379 reported a red in an unrestricted container,
but I did not reproduce that exact environmental shape; the one-CPU control is explicitly a
resource-modified run, not proof that today's default container necessarily fails. A 0.5-CPU
control also failed, but because the panel did not render before startup timeout; it is a
separate failure, not evidence of the same partial scroll frame (`container/cpu05/baseline.log`).

### Controlled A/B and observed pty state

`diagnose.sh` reused the real 38-entry fixture state and the same panel; its two scratch copies of
the driver differ at one line only: the wheel loop either sleeps for its existing 0.35 seconds or
uses the same period to drain the master. Both copies also record the same queue/wchan telemetry;
they are diagnostic files under `~/.cache/p383/`, not a proposed product patch. All 40 wheel
sequences were issued in each arm.

```text
$ diff -u ~/.cache/p383/diag-undrained.py ~/.cache/p383/diag-drained.py
-            time.sleep(0.35)
+            after += drain(master, 0.35, deadline)

host undrained, event 3..40: pending_output=4095 wchan=wait_woken
host drained, event 1..40:   pending_output=0    wchan=do_epoll_wait
host undrained: 4,181 bytes, 1 synchronized frame start / 0 ends, no #1
host drained: 118,408 bytes, 16 frame starts / 16 ends; final complete window #22..#1
container truecolor, drained: 16 complete frames; final complete window #22..#1
```

A separate four-event host trace resolved the waiting Node process's write descriptor to a live
`/dev/pts/` slave (`host/diag-fd.log`, event 3); the unread master had 4,095 bytes queued. In the
40-event trace, 11.327 seconds remained after event 1, the deadline passed during event 34, and
the final drain began 2.333 seconds after it expired; the drain returned 4,181 bytes
(`host/diag-syscall.log`). The driver's deadline check occurs after a read, so this is a single
partial frame, not an observed final viewport. Under the drained arm, the same bundle progresses
one row per frame to `#22..#1` and remains there through the remaining wheel input. This supports
a driver/backpressure/deadline failure for this reproduction; it does not establish that every
other scroll behavior is regression-free.

The current assertion also has a separate diagnostic weakness: at 0.5 CPU the first driver
failed to render and produced no output file, yet `下滚 3 格后最新行不再重绘` passed on an empty
chunk, and the second driver's exit status is not checked. The run itself was red, not a full
false pass. Any authorized repair should make driver failure and missing/incomplete frames fail
rather than treating an empty stream as evidence of absence.

## Flip evidence

The host A/B above demonstrates the same `#1` assertion's red-to-green *diagnostic* result by
changing only pty draining in a scratch driver. It is **not** a committed fix, a full-fixture green,
or the required post-fix break-and-restore mutation. Those are blocked with the driver path.

## Verification and remaining work

- Baseline `--select mouse` was run on host and pinned image as detailed above. The selected image
  was addressed by immutable image ID, and logs and frames were retained on the host bind mount.
- No final candidate exists: pinned-image `key-replies-pty.sh --all`, `smoke.sh --select 63`,
  final red/green/mutation, and independent verification were **not run**. No full smoke gate or
  GitHub Actions run was attempted. No CI schedule, OpenSpec, generated bundle, or product code
  was changed.
- Pending PM action: authorize `skills/teamsmith/tests/panel-b3-pty-mouse.py`, keeping
  `key-replies-pty.sh` in scope, then fix the pty drain and bounded concrete-state wait without
  weakening assertions or increasing a timeout. Rerun the final candidate and required mutation,
  including the driver-failure/empty-chunk case above, before independent review.

### Report-only checks

These were run on this branch; they do not validate a fix, since no candidate exists.

```text
$ bash -n skills/teamsmith/tests/key-replies-pty.sh skills/teamsmith/tests/smoke.sh
rc=0
$ bash skills/teamsmith/tests/section-select.sh --check
== 选段自检 ==  ok 12  bad 0  SKIP 1
rc=0
$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: root=… scope=published files=2219 hits=0 names=ok user=resolved
rc=0
$ git diff --check && git diff --cached --check
rc=0
```

The section check's one skip is the absent locally generated `.pi/skills` path; it was not checked
and is not counted as a pass. Full check output is in `~/.cache/p383/section-check.log`.

---

## V110 rework · counted frame waits and live section progress

**Answer:** the behavior fix remains unchanged; the readiness, barrier-open and barrier-close
waits now use one counted `wait_frame` mechanism. Each names its expected state, records an
actual frame reading on every round, and sends that reading through the existing §63 section
progress channel. At the shared deadline or round cap, the failure names the wait, `n/cap`,
expected state and last frame. The existing overall **25 s** deadline and behavioral assertions
were not relaxed. V110 had independently passed the wheel/frame/product behavior but rejected
candidate `75048792` because its three waits lacked this accounting; this is a new candidate,
not a claim that V110 has already re-reviewed it.

The real pre-fix failure and controlled drain/no-drain causal evidence are preserved above.
Only `panel-b3-pty-mouse.py`, `key-replies-pty.sh` and the directly necessary §63 wiring in
`smoke.sh` changed in the rework; the generated panel bundle, product code, CI schedule and
OpenSpec did not change. The new negative fixtures also verify that a nonexistent readiness
marker does not pass when the real last frame already contains `#38`.

### Identity, bounds and live evidence

- Tested code: `082e50f33642bb5f9328d6c6bfb410cdbb99ec42`, tree
  `ba455043b6820e4b348c13891e56cb036cdea8cc`; rework commits `02d552ff`, `6d4ae69e`,
  `082e50f3`. Candidate was clean before and after the host and container runs.
- Pinned image `91fa9dab310641a6f4dca892520a31a3cd9d3699fb34919c468ad22d929df793`,
  created `2026-10-27 01:51:16 UTC`: Node `v24.22.1`, Bun `1.3.14`, Python `3.13.5`,
  tmux `3.7b`, OpenSpec `1.8.0`, default `cpu.max=max 100000`. Host: Node `v24.22.1`,
  Python `3.13.12`, tmux `3.7b`, kernel `7.1.3+deb14-amd64`; `COLORTERM=truecolor`.
- Production wait cap is **10,000 rounds**, in addition to the unchanged shared 25 s deadline;
  either exhaustion is a failure detector, not a performance assertion. In the initial host
  focused run, successful wait-only latency for 3/40 wheels was **0–71 ms**; that excludes panel
  startup. On the clean final candidate it was 0–66 ms on host and unrestricted image, and
  0–102 ms in the separate 1-CPU diagnostic. These are observations, not pass thresholds.
- Complete logs, raw frames, test roots, scripts and exact invocation environments are under
  `~/.cache/p383-rework/`. Container runs bind-mounted this directory for logs and temporary
  roots; the candidate and its git common directory were mounted read-only. Runners:
  `host.sh`, `container.sh`, `container-inner.sh`, `mutations.sh`, `mutate.py`, and
  `followup-mutations.sh`. Results: `host-082e50f3/`, `container-082e50f3/`,
  `mutations-082e50f3/`, `followup-082e50f3/`; the isolated guard run's roots are under
  `~/.cache/p383-g/` to keep its tmux socket path within the AF_UNIX limit.

The real output from the unrestricted image's `pty-all` (logs retained, excerpts shortened):

```text
✓ P383 wheel-ready 每轮进度递增 — rounds=71
✓ P383 wheel-ready 失败点名期望和最后帧 — rc=2
✓ P383 不存在的就绪标记不能掩盖真列表 #38
✓ P383 wheel-barrier-open 每轮进度递增 — rounds=23
✓ P383 wheel-barrier-open 失败点名期望和最后帧 — rc=2
✓ P383 wheel-barrier-close 每轮进度递增 — rounds=23
✓ P383 wheel-barrier-close 失败点名期望和最后帧 — rc=2
✓ P383 轮数上限 3/3 归因最后读数

panel-b3-pty-mouse: wait=wheel-ready 71/10000 expected=complete frame contains 'NEVER-P383-READY'; last=current complete frame ... › #38 鼠标 38 号 · dev2 ...; process_status=None
panel-b3-pty-mouse: wait=wheel-barrier-open 23/10000 expected=complete frame contains '语言'; last=current complete frame (current_bytes=572): 'teamsmith pulse | #38 鼠标 38 号'; process_status=None
panel-b3-pty-mouse: wait=wheel-barrier-close 23/10000 expected=new complete frame without '语言'; last=current complete frame (current_bytes=451): 'teamsmith pulse | 语言'; process_status=None
```

These are shared-deadline negative probes; barrier probes use a deliberately nonresponsive
fixture. The cap-specific probe forces three rounds, checks exhaustion `3/3`, expected text,
last reading `observed #38` and a still-live process. Its actual live section output shows:

```text
· P383 wait=cap-probe round=1/3 elapsed_ms=0 expected=never arrives last=current complete frame (current_bytes=28): 'observed #38'
· P383 wait=cap-probe round=2/3 elapsed_ms=0 expected=never arrives last=current complete frame (current_bytes=28): 'observed #38'
· P383 wait=cap-probe round=3/3 elapsed_ms=0 expected=never arrives last=current complete frame (current_bytes=28): 'observed #38'
✓ 63 pty 每轮实际读数刷新段落心跳（133 轮）
```

The §63 reader counts the child's readings against actual `section_guard_check` increments,
not merely lines in the redirected child log. The isolated guard-tick mutation below shows that
removing the consumer's refresh fails even while the fixture sends 139 readings.

### Behavioral before / after and mutation flips

The original clean host baseline was `✓13 ✗1 SKIP0`, failing the `#1` assertion with an
incomplete first frame; the pinned one-CPU baseline was `✓11 ✗3 SKIP0`. The pinned default
baseline happened to pass three attempts, so it is not evidence of a default-image failure.
For the reworked clean candidate, raw complete final frames were independently re-read:

| Environment | 3 wheels | 40 wheels |
|---|---|---|
| Host | 2 starts / 2 ends; `#35..#14` | 3 / 3; `#22..#1`, no `#38` |
| Pinned default | 2 / 2; `#35..#14` | 3 / 3; `#22..#1`, no `#38` |
| Pinned 1 CPU diagnostic | 2 / 2; `#35..#14` | 3 / 3; `#22..#1`, no `#38` |

`bash ~/.cache/p383-rework/mutations.sh` used an isolated scratch clone, and
`bash ~/.cache/p383-rework/followup-mutations.sh` reran the two cases described below. No
scratch product mutation was delivered. All behavioral red cases retained a successful 3-wheel
control; `rc` is the fixture/gate exit status. Exact named red checks and counts:

| Scratch change | Observed result |
|---|---|
| Return 41 after valid 40-wheel output | rc=1, `✓20 ✗1 SKIP0`; `mouse：下滚 40 格：驱动失败（rc=41...）` |
| Empty 40-wheel output | rc=1, `✓20 ✗1 SKIP0`; `输出缺失或残缺（pty output has no complete final frame）` |
| Truncate at next frame-start marker | rc=1, `✓20 ✗1 SKIP0`; `输出缺失或残缺（pty output ends in a partial frame marker）` |
| Scratch product: 40th wheel resets viewport to top | rc=1, `✓21 ✗2 SKIP0`; original `#1` present and `#38` absent checks both red on the actual frame |
| Replace counted increment with the cap | rc=1, `✓12 ✗7 SKIP0`; `P383 wheel-ready 每轮进度递增` red (`rounds=1`) |
| Suppress progress writes | rc=1, `✓16 ✗7 SKIP0`; same named progress check red (`rounds=0`) |
| Remove final attribution | rc=1, `✓19 ✗4 SKIP0`; `P383 wheel-ready 失败点名期望和最后帧` red |
| Remove §63 `section_guard_check` consumer refresh | rc=1; §63 `✓2 ✗1 SKIP0`, `63 pty 等待进度未逐轮到达段落心跳（结束=1 轮=139 ticks=0）`; the pty fixture itself remained green |
| Restore candidate driver and bundle | rc=0, `✓23 ✗0 SKIP0` |
| Restore old 40-wheel pacing with no per-event drain, pinned image with `--cpus=1` | rc=1, `✓20 ✗1 SKIP0`; 3-wheel control green, 40-wheel driver fails at `wheel-barrier-close`, reports `2/10000` and last settings frame |

The no-drain mutation is resource-sensitive: the same scratch change on the host was
`✓23 ✗0 SKIP0`, so it is **not** claimed red on the host or default CI. The clean 1-CPU
candidate itself was green, as shown below. The first attempted §63 guard mutation was invalid:
its scratch `TMPDIR` made the tmux socket 109–110 bytes, causing isolation failures before the
fixture ran. The short-path rerun above isolates the intended failure. Consequently the first
combined mutation runner reports `mutation_assertion_failures=1`; the successful targeted rerun
is separate evidence and does not retroactively make that runner green.

### Commands and outputs on the clean candidate

The scripts print each actual command and retain complete logs, not only tails. Invocation:

```text
$ bash ~/.cache/p383-rework/host.sh
$ bash ~/.cache/p383-rework/container.sh
$ bash ~/.cache/p383-rework/mutations.sh                 # first attempt rc=1; see limitations above
$ bash ~/.cache/p383-rework/followup-mutations.sh        # rc=0; separately verifies guard mutation
```

`container.sh` invokes `distrobox-host-exec podman run --rm --pid=host --cgroups=enabled
--userns=keep-id` with the pinned immutable image, read-only candidate and git-common mounts,
and read/write host evidence mount. The second container invocation additionally uses `--cpus=1`
and is a diagnostic, not the default CI resource shape.

```text
# host
$ bash skills/teamsmith/tests/panel-b3.sh workdetail mouse wheel board detail fold
== 结果 == ✓ 176 ✗ 0                                        rc=0
$ bash skills/teamsmith/tests/key-replies-pty.sh --all
== P234 key-replies-pty 结果 == ✓88 ✗0 SKIP0               rc=0
$ "$HOME/.bun/bin/openspec" validate --all --strict
Totals: 19 passed, 0 failed (19 items)                       rc=0
$ bash -n skills/teamsmith/tests/key-replies-pty.sh           rc=0
$ bash -n skills/teamsmith/tests/smoke.sh                    rc=0
$ python3 -c 'import pathlib; p=pathlib.Path("skills/teamsmith/tests/panel-b3-pty-mouse.py"); compile(p.read_bytes(),str(p),"exec")'
                                                              rc=0
$ bash skills/teamsmith/tests/section-select.sh --check
== 选段自检 == ok 12 bad 0 SKIP 1                           rc=0
$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
scope=published files=2221 hits=0 names=ok user=resolved      rc=0
$ git diff --check                                           rc=0

# unrestricted pinned container
$ openspec validate --all --strict
Totals: 19 passed, 0 failed (19 items)                       rc=0
$ bash skills/teamsmith/tests/key-replies-pty.sh --all
== P234 key-replies-pty 结果 == ✓88 ✗0 SKIP0               rc=0
$ bash skills/teamsmith/tests/smoke.sh --select 63
#11 63 ... ✓3 ✗0 SKIP0 · ticks 136
11 段收口 · 增量 ✓435 ✗0 SKIP2 ｜ 结果行 ✓435 ✗0       rc=0

# same image with --cpus=1 (diagnostic only)
$ bash skills/teamsmith/tests/key-replies-pty.sh --select mouse
cpu.max=100000 100000; ✓23 ✗0 SKIP0                       rc=0
```

The two selected-gate skips are §38-h and §38-i, not passes. The map check's one skip is the
absent generated `.pi/skills` path, also not a pass. The §63 pty nested summary itself is
`✓88 ✗0 SKIP0`; its pre-existing banner counts the summary line and misleadingly says
`89 assertions, 1 visible skip`, as explained in the prior report. The selected gate lists the
124 unselected keys in its full log. No full gate, GitHub Actions run, panel rebuild, merge,
push or release was run. The next step is the PM's focused independent V110 re-review.
