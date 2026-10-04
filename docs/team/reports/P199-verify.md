# P199 · delivery-truth re-verification after P197

agent: verify   status: PARTIAL   time: 2026-10-03T02:36Z
branch: `task/P199-verify`   PR/MR: - (local mode)
change: `delivery-truth`   phase: verify
verdict: **Scope PASS; delivery BLOCKED by unrelated smoke 18c regression.**

## Deliverables

| Path | What |
|---|---|
| `docs/team/reports/P199-verify/checks/` | Independent real-run driver, judge corruptions/shadows, 1.0.0 frame replay, isolated gates, baseline-scenario comparison |
| `docs/team/reports/P199-verify/logs/` | New raw Pi/model/frame/state evidence, rejection outputs, genuinely failing guard outputs, gate logs |
| `docs/team/reports/P199-verify/README.md` | Reproduction commands, provenance and limitations |
| `docs/team/reports/P199-verify/pkg/` | Unmodified recipe files automatically copied by the promoted runner |

Product base: `d491c2f1`, including P197 `f7241906`. Real runs and gate clone used `d2845ea09fbccf87394ecc78367817db1f4def73` (only P199 evidence drivers added). No product, spec, brief, main-worktree or other agent implementation edits. All Pi/tmux operations ran in disposable containers, never on the user's default socket. Independent clone used `--no-hardlinks`, not `--shared`; it had a real `.git`, not a worktree pointer. The installed runtime, clone and mutation scratch are ignored and removed after use.

## Verification evidence (actually run)

### F1/F2 closure and normal-scene negative control

```text
$ python3 docs/team/reports/P199-verify/checks/judge-probes.py
ok normal: judge_rc=0 expected=0
... second_received=1 backend=1 backend_requests=1 settled=3 settle_editors_empty=1
PASS second say delivered
ok no-stamp: judge_rc=2 expected=2
judge-second: 拒绝出判据（tmux-p163-p199-second-dirty）：缺 run-start.txt（run-case.sh 的单次运行戳；判据不猜）
ok dev-same: judge_rc=2 expected=2
judge-second: 拒绝出判据（tmux-p163-p199-second-dirty）：dev-events.jsonl 的 run_start 标记 2 条（要求恰好一条）：['506bca9acd26', '506bca9acd26']
ok requests-different: judge_rc=2 expected=2
judge-second: 拒绝出判据（tmux-p163-p199-second-dirty）：requests.jsonl 的 run_start 标记 2 条（要求恰好一条）：['506bca9acd26', 'P199-OTHER-RUN']
ok requests-not-first: judge_rc=2 expected=2
judge-second: 拒绝出判据（tmux-p163-p199-second-dirty）：requests.jsonl 的 run_start 在第 2 行（要求第一行）
Independent P199 checks: 21/21 passed; original scene unchanged
```

The starting positive scene was **new real Pi 0.99.2/model/tmux evidence**, not an invented success scene. Each corruption copied that scene into this task's ignored scratch and changed one premise. Both judged files were tested separately for same-ID duplicate, different-ID duplicate, second-line marker, wrong run ID and absent marker. Stamp absence, emptiness and wrong ID were independently rejected. Full output: `logs/judge-probes.txt`, individual `logs/probe-*.txt`. Mapping: `judge-second.py:37–51` enforces marker count/location/ID; `:54–70` checks the stamp; `:100–101` calls both checks.

### P163 reset promise and real second correction

```text
$ bash docs/team/reports/P199-verify/checks/real-runs.sh HEAD
reset 1: run=99871260972f dev_turns=2
reset 2: run=30aa27767b61 dev_turns=2
PASS distinct run ids, exactly two turns and one first-line stamp per reset run
... second_received=1 backend=1 backend_requests=1 settled=3 settle_editors_empty=1
PASS second say delivered
```

The driver invokes the **skill-owned** `run-case.sh <case> HEAD 0 0.99.2` on the host; the recipe enters its own container. Reset runs explicitly omit second correction/draft flags, reuse the same case path and each have exactly two turns; snapshots retain both runs. The separate positive run enables `P138_SECOND=1 P143_DRAFT=1`. First and second sends each report `已确认送达`; both subsequent flushes report an empty queue. Three model turns are seed, first correction and second correction, with one matching backend request for the second correction. The later human-draft probe reports queued; its entry is the final **one active, zero held** entry, not a stranded second correction. Raw evidence includes cursor/frame pairs, draft frames, model requests and state snapshots in `logs/tmux-p163-p199-second-dirty/`.

### Stored host-1.0.0 frame protection and visible receipt

```sh
E="$PWD/docs/team/reports/P199-verify"
distrobox-host-exec podman run --rm --network=none --userns=keep-id -e HOME=/tmp \
  -v "$PWD:/work:ro" -w /work localhost/teamsmith-gate:local \
  bash docs/team/reports/P199-verify/checks/foreign.sh
```

```text
foreign[normal]: rc=0 keys=0 before=c248aed1f1b95496b5254c7b000c06531d263ebdeb3c99cf4c42f24b16a959e0 after=c248aed1f1b95496b5254c7b000c06531d263ebdeb3c99cf4c42f24b16a959e0
✓ queued for p147:dev: P199-FOREIGN-PAYLOAD（目标输入框里有草稿：没有写任何键；条目已入 state/outbox/，清空后自动投递）
  原因/条目：team outbox list ｜ 投递未确认的兜底：消息已在 docs/team/inbox/dev.md
P199 foreign replay: pass=3 fail=0
```

Actual team process, fake-tmux argv recorder, stored real 1.0.0 frame; **not a newly launched host 1.0.0 process**. The identical frame stays unchanged and receives zero keys; full text exists in both queue and inbox. A silent-receipt shadow makes the same visibility assertion fail, and restoration passes. Output: `logs/foreign.txt`.

### Gates and spec coherence

```text
$ bash docs/team/reports/P199-verify/checks/gates.sh
gate source=d2845ea09fbccf87394ecc78367817db1f4def73 clone=d2845ea09fbccf87394ecc78367817db1f4def73
validate rc=0
select57 rc=0
fast rc=1
```

Executed serially inside the independent clone/container:

| Command | Actual result |
|---|---|
| `openspec validate --all --strict` | 15 passed, 0 failed |
| `bash skills/teamsmith/tests/smoke.sh --select 57 </dev/null` | exit 0; outer result `✓22 ✗0`; delivery-truth eight sections green, 135 reported assertions, no visible section skips |
| `TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null` | exit 1; **`✓3790 ✗1 SKIP37`**, all 123 sections closed; no timeout |
| `python3 .../checks/delta-preservation.py` | exit 0; **50 current-baseline scenarios retained verbatim**, six modified requirements |

Select 57 runs five prerequisite/target sections and omits 118 other keys; `logs/select57.txt` names them. FAST skips 36 real-process checks (full list in `logs/fast.txt`), plus one conditional skip: **26-a bundle rebuild**, because pinned dependencies cannot resolve `chalk` with the container's network disabled. That skip is not a pass. Raw FAST log retains non-UTF-8 truncated diagnostic bytes and three whitespace-only output lines; decode with replacement when viewing, do not alter the original. `git diff --cached --check` flags those raw lines (3206/3675/3680); the same check excluding raw logs is clean. Evidence was not normalized to hide the output.

OpenSpec context reports 13/13 tasks checked. Completeness of this **re-verification brief**: all five requested checks executed. Correctness: F1/F2 and reverse controls independently passed. Coherence: all current-baseline scenarios preserved; scope behavior agrees with the narrowed pinned-runtime/observation distinction. This is not a new independent rerun of every historical apply scenario.

## Flip evidence

The same independent refusal assertions ran against physically mutated judge copies and the **actual pre-P197 judge** from `f7241906^`:

```text
stamp-disabled: independent guard rc=1 expected=1
BAD no-stamp: judge_rc=0 expected=2
PASS second say delivered
set-equality: independent guard rc=1 expected=1
BAD dev-same: judge_rc=0 expected=2
PASS second say delivered
pre-P197-missing: independent guard rc=1 expected=1
BAD no-stamp: judge_rc=0 expected=2
PASS second say delivered
pre-P197-duplicate: independent guard rc=1 expected=1
BAD dev-same: judge_rc=0 expected=2
PASS second say delivered
ok restored-no-stamp: judge_rc=2 expected=2
... 缺 run-start.txt ...
ok restored-same: judge_rc=2 expected=2
... run_start 标记 2 条（要求恰好一条）...
```

Thus the guard genuinely fails when a stamp check is removed or the count is changed back to set equality; it is not merely a test that prints a red-looking line while passing its assertion. Four exact outputs: `logs/flip-*.txt`. Original implementation files and original real-scene hashes remain unchanged.

## Decisions, deviations and blocker

**BLOCKED: PM must assign the owner of `skills/teamsmith/tests/smoke.sh` to repair the unrelated 18c assumption at line 9156, then rerun FAST.** No implementation repair is authorized to verify.

The sole FAST failure is reproducible, not load/timing-related:

```text
18c --check 绿：spec-refs: judged 101 reference(s) (49 distinct) ...; retired 0; undeclared 0 ...
✗ 18c 被 pending change 退场的引用逐条点名（retired 行） ... 没有匹配 [^retired ]
```

`smoke.sh:9156` unconditionally requires a `retired` output line from the current live tree. Following the preceding PM archive commit `d491c2f1`, the checker correctly reports `retired 0`, so the fixture's assumption is stale. This is outside delivery-truth/P197. A second container run of `bash skills/teamsmith/tests/smoke.sh --select 18c </dev/null` reproduces it: exit 1, outer `✓42 ✗1` (`logs/select18c.txt`). The complete FAST log still has delivery-truth section 57 green. I did not delete, relax or work around the failing check.

PM notification was sent with `env -u TMUX -u TMUX_PANE TEAM_NOTIFY_TMUX=0 bash skills/teamsmith/scripts/team notify verify --from verify ...` (inbox-only, no shared tmux access), naming the exact failure and evidence path.

Not measured this round: full non-FAST correctness suite, performance/release gate, newly launched host-1.0.0 observation, fresh watcher-route end-to-end, or the original <peer-c> incident. Real model evidence uses the local mock backend, not an external provider. No archive, merge, push, board completion or cross-project operation occurred.

## Suggested next steps

- Accept F1/F2 as closed on this independently verified source. No new in-scope defect found.
- Repair and independently rerun 18c/FAST before treating delivery as complete. Do not archive while this delivery gate is red.
- PM retains merge/archive authority; user confirmation is still required for archive. Branch and committed evidence stay local.
