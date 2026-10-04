# P206 · Independent verification of sender-identity-refusal

agent: verify   status: PARTIAL   time: 2026-10-03
branch: `task/P206-verify`   PR/MR: - (local mode)
change: `sender-identity-refusal`   implementation under review: `c220eb00`

**Behavioral verdict: PASS. Archive readiness: NEEDS-CHANGES (F1).**

## Deliverables

| Path | What |
|---|---|
| `docs/team/reports/P206-verify/pkg/probe.py` | Independent project and real-tmux probe; fourteen cases, two mutations, full restore |
| `docs/team/reports/P206-verify/pkg/contract.py` | Baseline scenario preservation and task-ledger observation |
| `docs/team/reports/P206-verify/pkg/run.sh` | Disposable-container probe and sequential acceptance gates |
| `docs/team/reports/P206-verify/pkg/README.md` | Replay instructions, isolation, interpretation and limits |
| `docs/team/reports/P206-verify/pkg/logs/` | Raw gate outputs, OpenSpec JSON and per-case statuses/bytes/argv |

All changes are this report and its evidence package. No implementation, task brief,
change artifact, base spec, other worker directory or main checkout was edited.
The source scripts were mounted read-only during the probe. The implementation
under review is the P205 implementation already present at the initial branch tip;
the later verifier commit only adds evidence.

## Verification scorecard

| Dimension | Result |
|---|---|
| Completeness | One modified requirement; eleven baseline scenario bodies retained verbatim; seven additions; **task ledger 0/16 complete (F1)** |
| Correctness | All seven added scenarios exercised independently; baseline and restore each 14/14; both required mutations detect the intended regression |
| Coherence | Runtime directory determines the sender; roster/window/environment are veto clues only; explicit claim wins; refusal is before durable write |

### Scenario-to-evidence map

Each case directory is `pkg/logs/cases/<variant>/<case>/`, with `result.json`,
`stderr.txt`, `stdout.txt`, `inbox.txt` and `tmux-calls.txt`. `result.json` includes
SHA-256 maps of every inbox/outbox file before and after the call, including
preexisting queued and held entries. Every baseline/restore refusal preserves
these complete maps, exits 1 and issues no send/paste key call.

| Added scenario / brief boundary | Independently built case | Observed baseline |
|---|---|---|
| Main-checkout seat clue refuses | `own-pane-client-pm` | exit 1; `pm` and window `dev` named; both escape routes; zero inbox/outbox change |
| Caller pane, not client's current window | `own-pane-client-pm` | real attached client sees `pm`; targetless query returns `pm`; caller-targeted query returns `dev`; implementation queries `-t <caller pane>` and refuses |
| Inherited roster name refuses | `inherited-roster-refusal` | no tmux; `TEAM_AGENT=dev2`; exit 1; source/name printed; zero writes |
| Names outside roster are not clues | `unknown-window`, `unknown-inherited` | each exit 0; one new `agent:pm` line; inherited unknown name is warned about |
| Other session's same-named window is not a clue | `other-session-dev` | actual `dev` pane in private `p206-other`, not configured `p206-own`; exit 0; `agent:pm` |
| Explicit `--from` still wins with clue | `explicit-wins` | actual own-session `dev` pane; exit 0; `agent:dev3`; stderr names explicit claim and directory `pm` disagreement |
| Seat worktree not refused by roster clue | `seat-roster-clue` | own `dev` pane and `TEAM_AGENT=dev3`, cwd `.worktrees/dev2`; exit 0; `agent:dev2`; ignored inheritance named |

Additional independent controls: PM main checkout without any clue; actual `pm`
window plus `TEAM_AGENT=pm`; seat worktree without tmux; seat subdirectory with
roster clues; both roster clues together (both sources/names printed); outside
worktree refuses without a claim and accepts explicit `--from dev3`.

### Raw refusal / actual-runtime evidence

`pkg/logs/cases/baseline/own-pane-client-pm/result.json`:

```json
"exit": 1,
"failures": [],
"targetless_window": "pm",
"caller_window": "dev"
```

The inbox SHA-256 before and after is
`90638b84903a350fcdc8a49563b72c719eea63788c2a32466bcc201e6baed8d1`.
Both preexisting outbox entries have identical before/after hashes; no extra file
appears. The complete maps are in that JSON, not inferred from file counts.

Actual stderr:

```text
✗ notify：发送者冲突 —— 目录说 'pm'（运行时目录是主检出），线索说 窗口名 'dev'
  账本记的是作者：主检出里按目录署 'pm' 会把席位的活记成 PM，所以这里拒绝而不是猜。
  两条出路：① 从自己的 worktree（/tmp/p206-vpu5f_dv/project/.worktrees/<你的名字>）里调用；② 显式声明发送者：team notify <收件人> --from <你的名字> --from-file <摘要文件>
```

The dual-clue case additionally reports `窗口名 'dev'、TEAM_AGENT 'dev3'`.
The explicit-claim case reports:

```text
! notify：--from dev3 与运行时目录解析出的座位 'pm' 不一致 —— 按显式声明记 dev3（目录：/tmp/p206-vpu5f_dv/project）
! PM 不在运行：消息只落收件箱（pulse 会把 PM 拉起后读到）
```

## Verification evidence (actually run)

```sh
# OpenSpec CLI is installed under ~/.bun/bin, absent from the initial shell PATH.
PATH="$HOME/.bun/bin:$PATH" openspec status --change sender-identity-refusal --json
PATH="$HOME/.bun/bin:$PATH" openspec instructions apply --change sender-identity-refusal --json
python3 docs/team/reports/P206-verify/pkg/contract.py
bash docs/team/reports/P206-verify/pkg/run.sh probe
bash docs/team/reports/P206-verify/pkg/run.sh gates
```

The probe's actual tail:

```text
ok baseline all 14 cases
ok roster shadow reddens both non-roster controls
ok roster shadow preserves genuine conflict refusal
ok directory shadow reddens seat with roster clue
ok directory shadow preserves main no-clue control
ok restore all 14 cases
ok original common.sh unchanged after mutations
P206 independent checks: ok=8 bad=0
```

Contract observation:

```text
contract scenarios: baseline=11 delta=18 preserved=11 additions=7
F1 task ledger: complete=0 remaining=16
```

Gate command expansion and raw output are in `pkg/run.sh` and `pkg/logs/`.
They run sequentially in `localhost/teamsmith-gate:local`, through
`distrobox-host-exec podman`, on a private shallow clone at `/work` (not a
worktree pointer to unmounted main-checkout Git metadata). The clone's reviewed
commit is recorded in `pkg/logs/gate-tip.txt`.

### Acceptance gate tails

Gate clone tip: `c501576b1d24608fa3c6bbe500ea391043448bc7` (P205 implementation
plus the first verification-evidence commit; `skills/**` and `openspec/**` are
byte-identical to reviewed `c220eb00`). The background job was harvested with
exit 0 after 1499.1 seconds. Actual output (ANSI styling removed here; raw bytes
retained in the logs):

```text
$ openspec validate --all --strict
✓ change/sender-identity-refusal
Totals: 14 passed, 0 failed (14 items)
validate exit=0

$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh --select 47 </dev/null
账本自查： 5 段收口 · 增量 ✓102 ✗0 SKIP0 ｜ 结果行 ✓102 ✗0 —— 一致
== 选段结果 ==  ✓ 102  ✗ 0
select47 exit=0

$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
账本自查： 124 段收口 · 增量 ✓3836 ✗0 SKIP36 ｜ 结果行 ✓3836 ✗0 —— 一致
== 结果 ==  ✓ 3836  ✗ 0
smoke 全绿
FAST exit=0
```

Section 47 explicitly omitted these 119 keys (from `select47.log`):

```text
0e 0f 0g 0h 0i 1 1b 1c 2 3 4 4b 4c 5 3b 6 6b 6c 6d 6e 6f 6g 6h 6i 6j 6k 7 7b 8 9 10 10b 10c 11 11b 11b2 11b3 11b4 11c 11d 11e 11e2 11f 11g 11h 11i 11j 14b 15b 15c 12 13 13b 13c 12b 12b-h0 12b-h0b 12b-h0d 12b-h0c 12b-pi 12b-pi2 12b-pi3 14 14c 54 14d 17 18 18b 18c 19 20 21 22 23 24 25 26 27 28 29 30 31 31c 32 33 12e 12f 12g 12h 12i 12j 12k 34 34b 35 36 37 38 39 40 41 42 43 44 45 46 48 49 50 51 52 53 57 58 15 55 56 59
```

The subsequent FAST run visits the entire section set, with 36 visible
process-dependent skips. Their named segments are: `1c`, `6`, `6b`, `6g`, `6h`,
`6i`, `6j`, `6k`, `10c-②`, `11`, `11b`, `11b2`, `11b3`, `11b4`, `11c`, `11d`,
`11g②`, `11g③`, `11j`, `12b-e`, `12b-h`, `26-m`, `31b`, three `31c` live
segments (server lifecycle, fingerprint flip, window injection), `32⑧`, `12g`,
`12h`, `38-b`, `38-f`, `41`, `42`, `44`, `52`, and the meeting-real-tmux segment
(labelled `55` in the skip summary). The exact skip descriptions remain in the
last lines of `fast.log`; they are not counted as passes. No timeout occurred.
Section 36 took 583 seconds; no timing threshold or assertion was relaxed.

## Flip evidence

The probe copies the skill to scratch paths inside the container. It never changes
source files. It removes the membership tests in shadow B and the complete
main-directory precondition in shadow D, runs the same independently constructed
cases, and finally reruns the unmodified source. Mutation diffs are saved as
`pkg/logs/cases/shadow-{roster,directory}.diff`.

```text
$ bash docs/team/reports/P206-verify/pkg/run.sh probe
baseline unknown-window: ok (rc=0)
baseline unknown-inherited: ok (rc=0)
baseline seat-roster-clue: ok (rc=0)

shadow-roster unknown-window: BAD must exit zero; must append exactly one durable line; must record sender pm (rc=1)
shadow-roster unknown-inherited: BAD must exit zero; must append exactly one durable line; must record sender pm; must name ignored inheritance (rc=1)
ok roster shadow reddens both non-roster controls
ok roster shadow preserves genuine conflict refusal

shadow-directory seat-roster-clue: BAD must exit zero; must append exactly one durable line; must record sender dev2; must name ignored inheritance (rc=1)
shadow-directory seat-subdirectory: BAD must exit zero; must append exactly one durable line; must record sender dev2; must name ignored inheritance (rc=1)
ok directory shadow reddens seat with roster clue
ok directory shadow preserves main no-clue control

restore unknown-window: ok (rc=0)
restore unknown-inherited: ok (rc=0)
restore seat-roster-clue: ok (rc=0)
restore seat-subdirectory: ok (rc=0)
ok restore all 14 cases
ok original common.sh unchanged after mutations
P206 independent checks: ok=8 bad=0
```

The mutation-case `BAD` lines are the deliberately demonstrated red side, not
baseline defects. The probe exits 0 only after these specific regressions are
observed and both normal runs are green.

## Findings

### F1 · CRITICAL completeness issue: all sixteen apply tasks remain unchecked

`openspec/changes/sender-identity-refusal/tasks.md` still has `- [ ]` for every
item: 1.1–1.3 (lines 26, 34, 39), 2.1–2.5 (48, 56, 60, 63, 67), 3.1–3.2
(74, 78), 4.1–4.4 (84–87), and 5.1–5.2 (93, 97).

Actual `openspec instructions apply --change sender-identity-refusal --json`:

```json
"progress": {
  "total": 16,
  "complete": 0,
  "remaining": 16
}
```

This is **an incomplete task ledger, not sixteen independently demonstrated
implementation defects**. The landed P205 report contains evidence for these
items, and this verification confirms the brief's behavior. Planning
`isComplete: true` does not establish implementation progress. Archiving now
would leave the change's own completion record claiming none of the apply work
was done.

**BLOCKED:** PM or apply owner `dev` must reconcile each checklist item with its
actual evidence in `docs/team/reports/P205-dev.md`, mark only proven work complete
in the change's `tasks.md`, and rerun OpenSpec validation/progress before archive.
This verifier's grant is reports only; the task ledger was not edited.
No runtime-defect finding was observed in this task's scope.

## Decisions, deviations and limits

- The brief requests five named boundaries (despite calling them “four”); all five
  were exercised, plus both clue sources and additional baseline controls.
- Real tmux 3.7b was used inside the disposable container, including a real
  PTY-attached client. The forwarding wrapper records argv; it does not fake
  window/session answers. No host/shared tmux command was run.
- Original source hash is checked after mutations. Cleanup signals only the
  client process this probe spawned and kills only its explicitly created
  container-private tmux socket.
- No Pi PM/model is launched by the independent probe. The legitimate notify
  controls write the inbox and report PM offline; they do **not** demonstrate a
  successful Pi wake or a queued knock drain. Refusal proves no durable write,
  no new/changed outbox file and no key/paste call.
- The turn-end extension and `[auto]` parity are outside this brief and were not
  independently exercised. Baseline scenario retention is a text-level check,
  not a claim that this independent probe executes all eleven old scenarios.
- Only the brief's specified section 47 and FAST gates were required here; no
  full non-FAST suite, performance/release check or actual/trial archive was run
  by this verifier. Section selection is not a full-suite result, and FAST
  keeps its explicitly reported skips.
- No push/PR was attempted: this is local-mode delivery. Branch retained for PM.

## Suggested next steps

1. Close F1 by reconciling the task checklist with evidence. Do not use the
   behavioral PASS as permission to ignore this finding.
2. PM independently reverify the final protected-branch gate, record the outcome
   and obtain the required archive confirmation. This report does not authorize
   archive or change any board status.
