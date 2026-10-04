# P196 · Fourth independent verification of `safe-signal-discipline`

agent: verify   status: PARTIAL / BLOCKED (global specification gate)   time: 2026-10-03
branch: `task/P196-verify`   PR/MR: - (local mode)
implementation reviewed: `76f68d4072f2a65e5a84ae9a03463bb959b7c7d5` (P195)

**Scope verdict: PASS.** P189 F1 is closed: list and stop reject the three independently constructed records,
print byte-identical reason sentences, and demonstrably share validation. No new safety defect was found in the
requested samples. **Delivery is BLOCKED**, not archive-ready: the frozen tree's global strict validation fails
on another active change (`delivery-truth`). No product implementation or specification was modified.

## Deliverables

| Path | What |
|---|---|
| `docs/team/reports/P196-verify/pkg/verify.py` | Independent public-CLI probes, read-only state snapshots, two independently constructed mutations, reverse healthy job, record/directory boundary samples |
| `docs/team/reports/P196-verify/pkg/regression.py` | Independent signal-shim selection matrix and bidirectional lint flip |
| `docs/team/reports/P196-verify/ct.sh`, `README.md` | Rebuildable frozen standalone tree and container commands; source/image/safety boundaries documented |
| `docs/team/reports/P196-verify/logs/` | Unedited command outputs, including expected shadow failures and a superseded verifier-format error |

The temporary copied implementations live only under ignored `.scratch/`, not in the commit. All host commands
were launched from this worktree. The container mounted only the disposable tree and this owned evidence package;
no host tmux socket was mounted or probed. Signal-gate calls were pinned to an argv-recording stub. Every real
process signalled by the independent probes was spawned and recorded by those probes; cleanup used only their
`Popen` handles. `--pid=host` matches the team's gate environment but grants no pattern-selection authority.

## Verification scorecard

| Dimension | Evidence / result |
|---|---|
| Completeness | OpenSpec `status` / `instructions apply`: spec-driven; proposal, design, delta and tasks available; 24/24 task ticks. These ticks are provenance, not a claim of rerunning all original tasks. |
| Correctness | P196's five requested areas checked: F1 shapes, common-source mutation, healthy reverse, previous-contract samples, specified gates (global validation failed as detailed below). |
| Coherence | D6's P195 design matches `cmd-bg.sh`: validator at line 123; list calls it at 200; stop calls it at 215. The mutation experiment confirms this behaviorally, beyond a source-code inspection. |

### Independent primary and reverse probes

Each run creates fresh synthetic project/state directories. The payload deliberately contains a different `id=`;
the row must name the record filename, which is the id stop accepts. The primary invalid records all reference
the same fixture-owned live process with a correct start fingerprint, isolating each failure from pid liveness.

| Record shape | List verdict | Stop rc | Reason equality / signal result |
|---|---|---:|---|
| `two words.job` (non-flat id) | `unusable` | 2 | Same flat-name reason; target and neighbour alive; no ledger line |
| `zero.job`, `pgid=0` | `unusable` | 4 | Same positive-integer reason; target and neighbour alive; no ledger line |
| `wrong-group.job`, positive but wrong live group | `mismatch` | 5 | Same recorded/live-group reason; target and neighbour alive; no ledger line |
| Negative pgid | `unusable` | 4 | Same numeric-shape reason, no signal |
| Missing start fingerprint | `unusable` | 4 | Same missing-fingerprint reason, no signal |
| Different start fingerprint | `mismatch` | 5 | Same mismatch reason, no signal |
| Healthy `healthy.2-fine.job` amid invalid rows | `holds` | 0 | Recorded group stopped; owned neighbour remains alive; exactly one ledger line |

Reason equality compares UTF-8 bytes after removing only presentation ANSI codes and the caller-specific prefixes
(`bg list: <id>：` / `bg stop: `), not the reason wording or embedded paths. Every list invocation snapshots state
before/after and asserts no state file changed. The invalid-row checks also assert the target lives and no stop
ledger was written. Healthy stop output names the actual recorded process group.

Boundary samples independently exercised record symlinks (stop 4, list visibly skips), traversal (2), FIFO without
a writer (4 before read, not timeout), and a `bg` directory redirected outside state (both commands 4, resolved
target named, no foreign row, no signal or ledger). Restoring the ordinary directory preserves the healthy path.

The independent signal matrix tests six selecting argv forms for each tool, including `--help sleep` (selection,
not a standalone help call), while an inherited `TEAM_ALLOW_PATTERN_KILL=1` grants nothing: all twelve calls
exit 64, the stub is untouched, safe routes are named, and each refusal is retained byte-for-byte. Eight standalone
help/version forms reach the stub unchanged with its exit 17 and do not grow retention. The independent lint
fixture detects all five planted lines (bare/prefixed/absolute selection, xargs kill, predicate-fed kill), then
accepts five recorded-pid forms; the lint's own 29 bidirectional cases also pass.

## Verification evidence (actually run)

All commands below use `PKG=docs/team/reports/P196-verify`. Raw logs contain the full argv, exit codes and output.

```text
$ openspec status --change safe-signal-discipline --json
$ openspec instructions apply --change safe-signal-discipline --json
# Run through bash "$PKG/ct.sh"; context retained in logs/10-context-validate-select58.log.
# 24 tasks, all_done; all four artifact families available.

$ bash "$PKG/ct.sh" openspec validate --all --strict
✓ change/safe-signal-discipline
✗ change/delivery-truth
Totals: 16 passed, 1 failed (17 items)
# rc=1. The initial combined command used set -e and therefore did NOT run select58.

$ bash "$PKG/ct.sh" openspec validate delivery-truth --type change --strict
✗ [ERROR] delivery-guard/spec.md: MODIFIED "An automated send never types into a non-empty input box"
  omits scenario(s) the current spec still has: "A meeting knock never lands on a draft".
# rc=1; full wording in logs/11-select58.log.

$ bash "$PKG/ct.sh" bash skills/teamsmith/tests/smoke.sh --select 58 </dev/null
58 signal-gate 全绿（69 条断言）
58 team-bg-stop 全绿（82 条断言）
== 选段结果 ==  ✓ 429  ✗ 0
select58_rc=0
# 13/123 sections selected through dependencies; 110 unselected keys printed in raw log.

$ bash "$PKG/ct.sh" python3 /evidence/pkg/verify.py --mode normal
RESULT mode=normal checks=68 failures=0
$ bash "$PKG/ct.sh" python3 /evidence/pkg/verify.py --mode common-shadow
COMMON-SOURCE FLIP: zero row unusable->mismatch; stop 4->5; reason changes on BOTH sides
RESULT mode=common-shadow checks=68 failures=0
$ bash "$PKG/ct.sh" python3 /evidence/pkg/verify.py --mode normal
RESULT mode=normal checks=68 failures=0

$ bash "$PKG/ct.sh" python3 /evidence/pkg/regression.py
RESULT regression checks=56 failures=0

$ bash "$PKG/ct.sh" bash -c 'perl skills/teamsmith/tests/signal-lint.pl --root /evidence/pkg --no-legacy;
  perl skills/teamsmith/tests/tmux-lint.pl --root /evidence/pkg --no-legacy'
signal-lint：干净（扫描 2 个脚本；pid 精确形态全部干净）
tmux-lint：干净（扫描 1 个脚本，0 条变更命令全部有隔离证据）
evidence_signal_lint=0 evidence_tmux_lint=0
```

### Container FAST

```text
$ bash "$PKG/ct.sh" bash -c 'TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null'
#120 58 · 信号纪律：闸门 / 作业 pid / lint（P159） · 用时 10s · ✓13 ✗0 SKIP0
账本自查：123 段收口 · 增量 ✓3792 ✗0 SKIP36 ｜ 结果行 ✓3792 ✗0 —— 一致
== 结果 ==  ✓ 3792  ✗ 0
FAST 模式：跳过 36 个真进程段落 […]
smoke 全绿
FAST_rc=0
```

Harvested `p196-fast`: exit 0 after 1482.4 seconds. Section 58 ran, not skipped. The 36 skipped runtime
cases are enumerated in `logs/40-fast.log` (real launch/window/adapter/lifecycle/typing/pane/container cases).
The long run was progressing, not silently hung: section 36 took 584 seconds, and all 123 sections closed with
no timeout. No gate job remains unharvested.

## Flip evidence

### Read-side independence shadow: green → six expected failures → restored green

Only in a disposable copy, replace list's shared-validator invocation with pid-liveness-only rendering. The shared
validator and the complete stop path are explicitly asserted byte-identical to the original. The **same primary
assertions**, not a special shadow-only checker, fail:

```text
$ bash "$PKG/ct.sh" python3 /evidence/pkg/verify.py --mode read-shadow
BAD two words: exact row verdict unusable
BAD two words: byte-equal reason
BAD zero: exact row verdict unusable
BAD zero: byte-equal reason
BAD wrong-group: exact row verdict mismatch
BAD wrong-group: byte-equal reason
RESULT mode=read-shadow checks=29 failures=6
# rc=1; three wrong holds rows, three absent equal reasons; stop still refuses correctly.

$ bash "$PKG/ct.sh" python3 /evidence/pkg/verify.py --mode normal
RESULT mode=normal checks=68 failures=0
# rc=0; restored original source, fresh state.
```

### Common-source shadow: one shared edit changes both surfaces

Only the shared positive-pgid-zero guard is changed (`[ "$pgid" -eq 0 ]` → `[ 1 -eq 0 ]`). Nothing in list or
stop is edited. On the unchanged `zero` record, the later live-group check now rejects it as identity mismatch:
list changes **unusable → mismatch**, stop changes **4 → 5**, and both print the **same new group-mismatch reason**.
The probe checks all three transitions plus no signal / no ledger. This experiment is safe: the unchanged live-group
check still rejects zero. Restoring the source returns both sides to `unusable` / 4 and the positive-integer reason.

Independent runs total 289 assertions: normal 68, read-shadow 29 (6 intentionally red), common-shadow 68,
restored normal 68, regression 56. No unexpected failure remains after correcting the verifier-format error below.

## Findings, decisions and deviations

1. **BLOCKED: global OpenSpec gate.** The `delivery-truth` owner / PM must repair
   `openspec/changes/delivery-truth/specs/delivery-guard/spec.md` so its MODIFIED requirement retains the current
   baseline scenario, then rerun global strict validation on the final protected-branch tree. This is outside
   P196's grant and was not edited or suppressed. P196 cannot claim the all-strict gate passed or authorize archive.
2. Host `openspec` is unavailable (`command not found`, rc127). Context and validation were therefore run using
   the existing container CLI. The image id is `1d723525ee58a8b177862746bc92cde2307a7d5f8a76045f5641703d8ac1a50b`.
3. The first background launch could not redirect into a not-yet-created `logs/` directory (rc1); it was harvested,
   the directory created, and the command relaunched. It did not run any acceptance command.
4. The first independent regression run had **five verifier assertion failures**, not product failures: it expected
   `file:line:` while lint actually reports `file:line SPACE`. All five planted violations were present. The parser
   assertion was corrected, the superseded output kept, and all 56 assertions rerun green. No implementation change.
5. Gates used a frozen standalone snapshot, avoiding a worktree `.git` pointer into the main tree. Neither the
   snapshot's implementation nor the source branch was mutated by shadows. Local mode: no push, merge or PR.

## What was not verified

- No full non-FAST suite was run; P196 explicitly requests container select58 plus FAST. Selected-gate omissions
  and FAST skips are visible in their raw logs; these are not claimed as full-suite coverage.
- No live user/PM/worker window or default tmux server was inspected. No production or other-project process was
  selected or signalled. Synthetic sibling state is entirely owned by this evidence fixture.
- This round does not re-prove all original 24 tasks, historical lexer extraction invariance, real Pi interactive
  launches, performance, or every signal-audit rotation edge. The requested regression samples and section58 were
  run; prior evidence is provenance only.
- No archive, user confirmation, or final protected-branch gate was performed. The all-strict failure remains real
  for the exact reviewed revision; any later repair needs its own successful gate result.

## Suggested next steps

The blocker was notified using `TEAM_NOTIFY_TMUX=0 bash skills/teamsmith/scripts/team notify verify --from verify …`
(durable notification, no tmux knock).

PM: retain **scope PASS / delivery BLOCKED**, resolve the unrelated global validation failure, and perform final
protected-branch gates. The independent F1 and common-source evidence is delivered for reuse. Archive still needs
those gates and the user's confirmation.
