# P164 · Selector gate proposal — planning complete

Agent: verify · phase: propose · change: `signal-gate-pgrep`
Branch: `task/P164-propose` · clean reconstruction: `7c055ce0`
Status: **ready for PM proposal review**, not approved or implemented.

## Deliverables

- `openspec/changes/signal-gate-pgrep/{proposal,design,tasks}.md` and `specs/boundary/spec.md`.
- One MODIFIED requirement, no parallel signal contract: five P159 scenarios retained unchanged, ten selector scenarios added.
- `docs/team/reports/P164-verify/pkg/`: container runner, read-only observations, executable counterexamples, temporary archive/preservation witness and real logs.
- Planning commits: `8e1ad6be` (design/tasks and evidence), `afdb99ca` (lint-clean adversarial fixture and baseline controls). No product implementation changed.

Recommendation: **A with a count-only exception**. Design D1 enumerates all four live calls across the three files; D2 compares A/B/C and costs every allowed/unsupported shape. `-g`/`-P` positive-ID diagnostics and full-command counts preserve current valid paths; PID-producing pattern/name/owner selection is refused. Diagnostic query results do not establish signal authority. Design D3 addresses the existing `TEAM_SIGNAL_REAL` pin to pkill without adding configuration. D5 supplies a falsifiable red side for every proposed flip.

The proposal is under 500 words; the eight unchecked tasks are implementation/verification/archive work, not a claim of implementation progress.

## Prior blocker: resolved by PM

The initial P164 commit accidentally included 381 P157 paths and the old worktree showed 15464 P157 deletions. I stopped, notified PM and wrote a PARTIAL report rather than reverting unrelated evidence. PM's 2026-10-02T12:39:11Z inbox message explains that their evidence-recovery `git checkout` had staged those paths; the old branch carried missing report packages. PM reconstructed this branch from main plus P164 artifacts, saved the messy branch separately and explicitly instructed continuation.

On resumption I ran `git status --short; git log --oneline -5; git branch --show-current`: clean worktree, branch `task/P164-propose`, reconstructed proposal and the partial report/delta present. The initial blocker log remains at `pkg/logs/worktree-blocker.log`; the earlier PARTIAL report is retained in Git history. I did not clean P157, rewrite branches or alter the main worktree.

## Commands actually run and output

All runtime probes used `localhost/teamsmith-gate:local` through `pkg/ct.sh`: private PID namespace and container `/tmp`, no `--pid=host`, no host tmux socket. No selector-produced PID was signalled. The observation cleanup uses only the parent/child PIDs recorded by their own spawner; the old P159 signal control uses its own recorded decoy PIDs inside the container.

Host `openspec` was unavailable, so the required CLI command ran in the container. The runner's `--checkout` mode was also exercised: it makes an independent local clone of committed HEAD, not an unresolved linked-worktree pointer.

### 1. Inventory and actual selector behavior

Commands exercised in the container via the runner:

```sh
bash docs/team/reports/P164-verify/pkg/ct.sh bash docs/team/reports/P164-verify/pkg/observe.sh
```

Exit 0. Latest log: `pkg/logs/observe-final.log`; original observation: `pkg/logs/observe.log`.

```text
pgrep from procps-ng 4.0.4
recorded owner=6 child=8 group=6
pgrep -g recorded_group -> 6,8
pgrep -P recorded_owner -> 8
pgrep -fc absent_pattern -> stdout=0 rc=1 (count, not PID list)
pgrep -f -c absent_pattern -> stdout=0 rc=1 (count, not PID list)
pgrep -c -f absent_pattern -> stdout=0 rc=1 (count, not PID list)
pgrep -g 0 -> 1,2 (implicit caller group, not an explicit recorded ID)
pattern shell=28 matches=28
pgrep=/usr/bin/pgrep
pidof=/usr/bin/pidof
OBSERVATIONS PASS: group/parent/count/self-match measured; no pattern-selected PID signalled
```

The log also records all eight native informational-token statuses. This pidof returns 1 for `--help`/`-V`/`--version`, and 0 for `-h`; the proposal preserves native status rather than promising token support across implementations. `pkg/logs/inventory.log` contains the source scan. Actual call sites are `common.sh:1507`, `panel-cpu.sh:285`, `panel-cpu.sh:340`, `smoke.sh:8095`; comments, lint recognition and fixture-data examples are distinguished from callers in design D1.

### 2. Executable planning red sides

The observation mode ran successfully; both assertion modes were then run and their **actual exit 1** checked in the final container batch:

```sh
bash docs/team/reports/P164-verify/pkg/ct.sh bash docs/team/reports/P164-verify/pkg/counterexamples.sh
bash docs/team/reports/P164-verify/pkg/counterexamples.sh --assert=baseline
bash docs/team/reports/P164-verify/pkg/counterexamples.sh --assert=blanket
```

The last two commands execute inside the runner's container (not on the host). Logs: `pkg/logs/counterexamples-final.log`, `pkg/logs/raw-red-final.log`.

```text
RED pgrep -f p164-marker: expected rc=64/no selector; actual rc=0 selector_calls=1 stdout=424242
RED pgrep -u 1000: expected rc=64/no selector; actual rc=0 selector_calls=1 stdout=424242
RED pgrep sleep: expected rc=64/no selector; actual rc=0 selector_calls=1 stdout=424242
RED pidof sleep: expected rc=64/no selector; actual rc=0 selector_calls=1 stdout=424242
RED shell substitution: recording kill received 424242 from the unwrapped selector (no signal)
RED selector audit: no gate call log or forensic refusal record created
baseline_refusal_assertions: RED=6
raw --assert=baseline rc=1
blanket_compatibility_assertions: RED=3
raw --assert=blanket rc=1
```

The blanket shadow demonstrably refuses all three legitimate argv classes. Neither shadow implements the recommended policy: these are counterexamples to the current residual and an overbroad alternative, **not an implemented green side**. Deliberately unsafe shell syntax is fixture data in `pkg/cases/substitution.txt`; the harness installs a recording-only `kill` function before evaluation. There is no lint exemption for executable fixture code.

### 3. Full baseline preservation and trial-archive order

```sh
bash docs/team/reports/P164-verify/pkg/ct.sh bash docs/team/reports/P164-verify/pkg/trial-and-coverage.sh
```

Exit 0. Log: `pkg/logs/trial-and-coverage.log`.

```text
COVERAGE PASS: original=5 retained=5 new=10 total=15; one MODIFIED requirement
COVERAGE RED CONTROL: original scenario missing
boundary MODIFIED failed for header "### Requirement: Signals go to a recorded pid, never to a name or a pattern" - not found
Aborted. No files were changed.
unprepared_archive_rc=1
Change 'safe-signal-discipline' archived as '2026-10-02-safe-signal-discipline'.
Change 'signal-gate-pgrep' archived as '2026-10-02-signal-gate-pgrep'.
ORDERED TRIAL PASS: replacement requirement and every scenario survived archive
REAL ROOT UNCHANGED: baseline hash and both live change directories retained
```

Both archive operations were **only on disposable specification copies**. The live main spec still lacks P159's ADDED signal requirement. This is an explicit PM archive prerequisite, not silently changed to ADDED here. The trial CLI warns that P159 has 0/24 and P164 0/8 checked tasks and proceeds only because this scratch semantics test uses `-y`; those warnings are retained. The test does not authorize either live archive or mark any implementation task complete.

### 4. P159 baseline controls and runner checkout

```sh
bash docs/team/reports/P164-verify/pkg/ct.sh --checkout bash -c 'set -e; printf "committed_checkout=%s\n" "$(git rev-parse --short=12 HEAD)"; bash skills/teamsmith/tests/signal-gate.sh; printf "== old P159 mutation control ==\n"; rc=0; bash skills/teamsmith/tests/signal-gate.sh --break=pass || rc=$?; printf "old_P159_mutation_rc=%s\n" "$rc"; test "$rc" = 1'
```

Exit 0; `pkg/logs/p159-baseline-controls.log`:

```text
committed_checkout=8e1ad6bea926
== signal-gate 结果 == ✓ 62  ✗ 0
signal-gate 全绿
红侧成立：34 条断言变红
old_P159_mutation_rc=1
```

These are unchanged **P159** implementation controls. New selector green/restored-green acceptance and the `✗.*P164` mutation assertion remain the apply/independent-verify agent's work.

### 5. Required strict validation, completeness and package discipline

```sh
bash docs/team/reports/P164-verify/pkg/ct.sh openspec validate --all --strict
```

Exit 0, final log `pkg/logs/validate-final.log`:

```text
✓ change/safe-signal-discipline
✓ change/signal-gate-pgrep
✓ change/spec-rationale-self-contained
✓ spec/verification
✓ spec/watchdog
Totals: 21 passed, 0 failed (21 items)
```

The final container batch also ran `openspec status --change signal-gate-pgrep` and `perl skills/teamsmith/tests/signal-lint.pl`:

```text
Progress: 4/4 artifacts complete
All planning artifacts complete!
signal-lint：红 0 条；另有 2 条落在**历史豁免**的 1 个文件里（按 sha256 冻结；--no-legacy 可让它们全部报红）
```

Logs: `pkg/logs/status-final.log`, `pkg/logs/signal-lint-final.log`. Existing historical exemptions were not changed. `bash -n` on all four package shell scripts and `git diff --check` also passed. Full smoke was not run: the brief requires strict validation for this planning-only phase, and no product code changed. The proposal lists full-container smoke and all new flip checks for implementation acceptance explicitly.

## Handoff and scope

No current planning blocker. PM must record ACCEPTED proposal review before dispatching apply to a different agent. Before real archive, P159 must finish its own independent verification and confirmation and be synchronized into the base; this change must then finish independent verification, protected-branch gates and archive confirmation.

Only the granted P164 change/report/package paths were edited. No `skills/**`, main spec, ownership, briefs or board changes; no branch switch, push, merge or live-window restart. Local mode: branch remains in this worktree. All background jobs were harvested, including the resumption jobs `p164-trial`, `p164-final-planning`, `p164-checkout-control`, `p164-package-check`, `p164-delivery-validate`. Original blocker and intermediate logs remain as historical evidence, superseded by the `*-final.log` files and this completed report.
