# P194 · Independent verification of delivery-truth after P163

agent: verify   status: PARTIAL / NEEDS-CHANGES   time: 2026-10-03 UTC
branch: `task/P194-verify`   PR/MR: - (local mode)

## Verdict

**Do not archive.** The scene reset, host-frame safety/visibility and sampled P147 promises pass. Two fail-closed probes required by this brief return false green. Strict validation also fails in two unrelated changes already assigned to P192/P193. No implementation was changed.

**BLOCKED:** PM must assign the fixture owner to repair `skills/teamsmith/tests/fixtures/delivery-truth-real/judge-second.py` (F1/F2 below), and resolve the P192/P193 delta validation blockers before final protected-branch validation. Verification evidence is deliverable; acceptance is not PASS.

Tested product revision: `116a59331dd63447976f6125c48698bfbc0b4710` (contains P163 merge `a22c442f`). The independent gate clone has that exact HEAD. Later commits on this task branch contain only this task's evidence. Dispatch explicitly named agent:verify and this branch; the brief's older `agent: dev-bob` header was not used as authority to switch seats.

| Dimension | Assessment |
|---|---|
| Completeness | OpenSpec reports 13/13 implementation tasks checked; P194 independently ran its assigned probes, not a reimplementation of all P147 verification |
| Correctness | Reset and sampled delivery/notify safeguards pass; fail-closed item 2 has two falsifiable failures |
| Coherence | Closed geometry, immutable sidecars and recipient-vs-PM-knock separation match the sampled behavior; judge's single-run claims are stronger than its checks |

## Deliverables

| Path | What |
|---|---|
| `docs/team/reports/P194-verify.md` | This report and disposition |
| `docs/team/reports/P194-verify/pkg/real-tests.sh` | Independent host driver: two reset runs, positive second correction, no-reset shadow and restoration |
| `docs/team/reports/P194-verify/pkg/judge-probes.py` | Seven independently constructed control/corruption cases derived from our real positive scene |
| `docs/team/reports/P194-verify/pkg/independent.sh` | Own assertions using the fixture's isolated fake-tmux/project plumbing |
| `docs/team/reports/P194-verify/pkg/{gates.sh,summarize-real.py,P194-README.md}` | Gate commands, additional real-scene checks and repeat instructions |
| `docs/team/reports/P194-verify/logs/` | Original stdout/stderr, raw frames/events/requests, own reset snapshots and explicit synthetic corruptions |

`.runtime/` is a gitignored pinned Pi installation; `.checkout/` is a gitignored ordinary clone, never `--shared`. All real tmux work and every gate ran inside disposable full-dependency containers; no probe touched the host default socket. No credentials were mounted or read. The only network operation was npm installation; model requests were to the container's loopback mock. No push, merge or archive.

## Findings requiring rework

### F1 · Missing run-start.txt is accepted (CRITICAL for acceptance)

`judge-second.py:32–79` reads `run.json`, the event markers and runtime version, but never reads `run-start.txt`. Removing only that file from a positive scene still prints `PASS second say delivered` and exits 0; the brief requires refusal (exit 2).

Evidence: `logs/judge-missing-run-start.txt`, `logs/tmux-p163-p194-judge-missing-run-start/`, and `pkg/judge-probes.py`. A control clone with its renamed case stamp intact exits 0, so this is not a broken positive premise. Removing `run.json` instead is correctly refused.

Recommendation: require the assigned scene-start artifact and validate its identity against the manifest, or have PM explicitly reconcile this acceptance contract before claiming closure. Do not substitute a missing `run.json` test for the requested missing `run-start.txt` test.

### F2 · A second identical run_start marker is accepted (CRITICAL for acceptance)

`judge-second.py:61–64` converts marker IDs into a set. Two markers carrying the same run ID therefore collapse to one ID; no cardinality check enforces exactly one marker. Appending the first `run_start` JSON line a second time to **each** judged event file still exits 0 and reports PASS. Appending a different run ID is correctly refused.

Evidence: `logs/judge-two-identical-stamps.txt`, `logs/tmux-p163-p194-judge-two-identical-stamps/`. Both files demonstrably contain two markers while receptions/model submissions remain exactly one. This proves that the judge accepts ambiguous single-run evidence; it does not claim an actual lost product message.

Recommendation: require exactly one `run_start` marker in each file, with matching ID and first-line placement. Keep controls for both identical and different duplicate IDs.

### Separate delivery blocker · strict validation (not a new delivery-truth defect)

Both host and container strict validation return 1: 17 passed, 2 failed. `meeting-liveness` and `pulse-nudge-key` each omit these current panel scenarios from their MODIFIED block:

- `The disk readings reach the band and the JSON`
- `A filesystem that cannot be read is not assigned a number`

Exact diagnostics: `logs/validate-meeting-liveness.json`, `logs/validate-pulse-nudge-key.json`. This is the delta-base rewrite covered by P193/P192, not machine slowness and not a reason to change delivery-truth in this verification task.

## Verification evidence

### 1. Independent real runs (PASS)

Pinned installation, as prescribed by the promoted fixture README:

```sh
E="$PWD/docs/team/reports/P194-verify"
distrobox-host-exec podman run --rm --userns=keep-id -e HOME=/tmp \
  -v "$E/.runtime:/runtime:rw" localhost/teamsmith-gate:local \
  npm install --prefix /runtime --no-audit --no-fund @earendil-works/pi-coding-agent@0.99.2
# exit 0: added 147 packages in 15s
bash docs/team/reports/P194-verify/pkg/real-tests.sh 116a5933
# exit 0
```

The driver runs the promoted `run-case.sh` on the host; that recipe itself enters the isolated container. Reset case runs omit `P138_SECOND`, so seed + first say are exactly two turns, rather than testing for two while deliberately sending three messages. Second-message positivity uses a separate case with `P138_SECOND=1 P143_DRAFT=1`.

Original tails (`logs/real-tests.txt`):

```text
reset 1: run=f264685c5feb dev_turns=2
reset 2: run=62c298d0e634 dev_turns=2
PASS independent consecutive runs: distinct stamps, 2 turns each
tmux-p163-p194-second-dirty: second_received=1 backend=1 backend_requests=1 settled=3 settle_editors_empty=1
PASS second say delivered
```

Every real case records `pi-version.txt=0.99.2`. Both reset runs retained the intentional `?? leftover.txt` dirty working tree; evidence was not accumulated between runs. `reset-snapshot-1/` and `reset-snapshot-2/` preserve the separate raw scenes.

Additional independent checks:

```text
$ python3 docs/team/reports/P194-verify/pkg/summarize-real.py
{
  "first_user_receptions": 1,
  "first_model_requests": 1,
  "draft_frames_identical": true,
  "draft_guard_backend_requests": 0,
  "after_second_entries": 0
}
box/cursor: verdict=EMPTY
box_text=[|]
28
```

Cursor 28 is tmux's zero-based value (row 29). First send and second correction each reached the backend once; no active/held entry remained after the second. The later real human-draft guard left its before/after frame byte-identical and made no matching backend request. This is separate from fake-tmux zero-key assertions.

### 2. Fail-closed corruptions (FAIL: two cases)

```text
$ python3 docs/team/reports/P194-verify/pkg/judge-probes.py
case=control expected=0 actual=0
PASS second say delivered
case=missing-run-start expected=2 actual=0
PASS second say delivered
case=missing-run-json expected=2 actual=2
judge-second: 拒绝出判据 … 现场没有 run.json 运行戳
case=two-distinct-stamps expected=2 actual=2
judge-second: 拒绝出判据 … 单次运行标记 … 不一致（现场跨次累积？）
case=two-identical-stamps expected=2 actual=0
PASS second say delivered
case=old-case expected=2 actual=2
judge-second: 拒绝出判据 … old-case/residual.jsonl（没有清空现场）
case=observation expected=2 actual=2
judge-second: 拒绝出判据 … 是人工观察（host 路线），不作为判据
# script exit 1, intentionally not masked
```

These are labeled **synthetic corruptions of our own real positive scene**, not additional real Pi runs. Re-run the script to reconstruct old-file mtimes: git checkout does not preserve filesystem timestamps. The old-case probe includes an actually old residual event file under a nested case directory.

### 3. Own P147 spot checks and foreign 1.0.0 frame (PASS)

```sh
E="$PWD/docs/team/reports/P194-verify"
distrobox-host-exec podman run --rm --network=none --userns=keep-id -e HOME=/tmp \
  -v "$PWD:/work:ro" -v "$E:/evidence:rw" -w /work localhost/teamsmith-gate:local \
  bash /evidence/pkg/independent.sh
# exit 0: == 1 independent 结果 == ✓ 15 ✗ 0 ==
```

Evidence: `logs/independent.txt`.

- Own mixed-width disjoint-box frame: production geometry `[1 3]`, text ` HUMAN-DRAFT-P194`; disabling admission selects `[5 7]` and empty text on the same bytes.
- Stored real Pi 1.0.0 frame: zero keys; unchanged SHA `c248aed1f1b95496b5254c7b000c06531d263ebdeb3c99cf4c42f24b16a959e0`; full payload exists in queue and `inbox/dev.md`; queued/recovery/path receipt is visible. **At its recorded cursor this is a trusted nonempty read and `queued`/exit 0, not `held/` or a confirmed delivery.** “Held back” is not conflated with the machine state `held`.
- Three no-progress trusted-empty drains return `0/0/1`; third creates `held/queue-stalled`, immutable payload hash and sidecar count 3. List/status/digest name the reason. Fresh trusted recovery submits that never-typed hold once.
- Both `draft-raced` and `unconfirmed` terminal entries survive ordinary and `--now` flush byte-identically, with zero keys.
- Notify: durable file `dev.md`, wake fourth field `dev`, and queued header `inbox: dev`/`inbox-written: 1`; queued target remains `p147:pm`. With a live watcher and an impossible inbox directory, append fails nonzero, with no new wake or queue declaration.

First independent run had one **verification-script error**, preserved in `logs/independent-first-method-error.txt`: my exact text assertion omitted the stored leading space. Geometry and draft were correct. I corrected only my assertion, reran every independent check and obtained 15/0; this was not a product finding.

### 4. Gates

```sh
bash docs/team/reports/P194-verify/pkg/gates.sh
```

The script performs host `openspec validate --all --strict`, then a normal non-shared local clone and a full-dependency container with its own `/tmp` and tmux server. Inside the container it runs, in order:

```sh
openspec validate --all --strict
bash skills/teamsmith/tests/smoke.sh --select 57 </dev/null
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
```

- Host strict: **exit 1**, 17 passed / 2 failed, as detailed above.
- Container strict: **exit 1**, same two errors.
- Container select 57: **exit 0**, selected result 22/0; seven delivery-truth sections end at cumulative 113/0, zero visible skips. The wrapper prints 122 `✓` matches, which includes summary/output lines and is not 122 independent assertions. Selection omits 118 other section keys; full omitted list is in `logs/select57.txt`, not represented as full-suite coverage.
- Container FAST: **exit 0**, 123 section closures, `✓3791 ✗0 SKIP37`. It visibly skips 36 real-process paths because FAST was explicitly requested, plus one conditional skip: **26-a bundle rebuild**, because the isolated offline environment could not resolve pinned `chalk` (`Could not resolve: "chalk"`). No bundle rebuild success is claimed. The complete skip names/reasons are retained in `logs/fast-skips.txt` and original `logs/fast.txt`.

```text
container openspec rc=1
select57 rc=0
FAST rc=0
账本自查：123 段收口 · 增量 ✓3791 ✗0 SKIP37 ｜ 结果行 ✓3791 ✗0 —— 一致
== 结果 == ✓ 3791 ✗ 0
FAST 模式：跳过 36 个真进程段落 …
条件 SKIP（条件不满足）：1 条 …（跳过不是通过）
```

The aggregate gate driver exits 1 because strict validation failed; the successful smoke results do not cancel that failure. All background jobs were harvested. The disposable gate clone was removed after recording its HEAD; the pinned runtime is retained gitignored for a repair rerun.

## Flip evidence

1. **Scene reset, real-process shadow and restoration:** copy the promoted recipe into this task's own package and change only `rm -rf -- "$L"` into reuse. Run the same case twice:

```text
shadow run 1 judge rc=0
PASS second say delivered
shadow run 2 judge rc=2
judge-second: 拒绝出判据 … inbox-after-say/dev.md（没有清空现场）
# Restore/use normal production recipe for the SAME case:
PASS second say delivered
```

No stale file was injected in this shadow. Normal event files are overwritten per run, while the reused cp destinations leave old snapshot files; the freshness check correctly rejects that natural residue. The red original output is retained; the final case directory is the restored scene. See `noreset-run-{1,2}.txt`, `noreset-judge-{1,2}.txt`, `restored-{run,judge}.txt`.

2. **Foreign-frame visible receipt:** a separate minimum CLI copy removes only the queued branch's two report lines. The independent visibility assertion returns 1, while zero keys, same frame and durable queue/inbox text still hold. Restoring the unmodified CLI returns 0:

```text
foreign[green]: rc=0 keys=0 … output=[✓ queued … outbox list … inbox/dev.md]
foreign[shadow]: rc=0 keys=0 … output=[]
foreign[restored]: rc=0 keys=0 … output=[✓ queued … outbox list … inbox/dev.md]
```

3. **Geometry admission:** own mixed-width frame flips from protected `[1 3]`/draft to unsafe `[5 7]`/empty under the admission shadow. No production source file was modified for any shadow.

There is **no green-after-fix claim for F1/F2**: the two missing guards remain unfixed and belong to the fixture owner.

## Decisions, limitations and next steps

- No fresh real Pi 1.0.0 runtime was launched. F2 uses the promoted stored real 1.0.0 frame with production CLI processes and isolated fake tmux; it is frame replay, not live host-version end-to-end evidence.
- No independent rerun of every historical P147 scenario, long payload, every Unicode draft, watcher second-correction route, live panel compose or cold-start/CPU budget. Section 57 covers its registered fixture set; FAST has its own visible skips. The real fallback/dirty/draft route and the narrow independent spot checks above are what I personally measured.
- OpenSpec planning/task checkboxes are claims of implementation completeness, not archive authorization. F1/F2 still require rework and independent rerun.
- PM was notified through inbox-only `TEAM_NOTIFY_TMUX=0 … team notify pm --from verify`; no host tmux knock was attempted.
- PM should assign the judge fix, keep P192/P193 validation failures separately tracked, then rerun these probes plus protected-branch gates. Local task branch remains available; no remote state was changed.
