# P157 · Independent `delivery-truth` verification

agent: verify  
phase: verify · change: delivery-truth  
status: DELIVERED WITH FINDINGS; not archive authorization  
branch: `task/P157-verify` · local mode, no push/merge/archive  
date: 2026-10-02

## Verdict

The P157 adversaries and the measured **Pi 0.99.2** real fallback/watch routes pass. The real historical sender remains falsifiably red. This is **not** a claim that the current host runtime, Pi **1.0.0**, works: that separate real run failed and is retained below.

**BLOCKED: finding closure belongs to PM/dev**, not this report-only seat. PM must resolve or explicitly hold the repeatability finding and runtime discrepancy before treating the change as ready for archive. No implementation, task brief, baseline spec, ledger or other worktree was edited.

| Dimension | Evidence-backed conclusion |
|---|---|
| Completeness | Planning has 12/13 task checkmarks; 5.4 remains unchecked pending PM acceptance/closure. All six P157 brief items were exercised; broader renderer adversaries are not independently measured here. |
| Correctness | 39 independently written assertions pass; raw command return codes, frames, entries, diagnostics and wake files are in `P157-verify/logs/adversarial/`. Real 0.99.2 fallback and watcher each receive/submit the second message once. |
| Coherence | Shared production geometry/drain paths are exercised, immutable payload/header remains identical after holding, and notify retains the PM knock while referring to the recipient's durable file. Observers do not advance attempts or type. |

Sources tested: merged P147 `484d4836` is in this branch. Initial gate snapshot is `3cafc1aa`; real pinned green first run is `54405d7e`, same-name clean repeat is `d65a2622`. Those revisions differ only in verification artifacts, not product code. Historical red source: `603a4e8e`. Container image at start: `sha256:1d723525ee58a8b177862746bc92cde2307a7d5f8a76045f5641703d8ac1a50b`.

## 1. Independently generated adversaries

Command (non-root, disposable full-dependency container):

```bash
distrobox-host-exec podman run --rm --network=none --userns=keep-id \
  -e HOME=/tmp -e P157_CONTAINER=1 -v "$PWD:/src:ro" \
  -v "$PWD/docs/team/reports/P157-verify:/evidence:rw" -w /src \
  localhost/teamsmith-gate:local python3 /evidence/pkg/adversarial.py
```

Actual result: exit 0, `P157 independent failures=0` (39 `ok` assertions). The script constructs frames and judgments itself; it does **not** source the author's fixture or reuse its output. Its fake tmux logs every operation and refuses typing before any byte can reach an editor. All real tmux contact in the other recipes is container-only.

| Independent case | Observed result | Raw evidence under `logs/adversarial/` |
|---|---|---|
| Cursor in 70-column draft box, a disjoint 120-column pair below it | `geometry=1 3`, `verdict=BUSY`; say exits 0/queued; zero keys | `mixed/{frame,probe.txt,01-say-dev.txt,keys.jsonl}` |
| Equal-width extra pair outside the box | Conservative `geometry=1 7`, `BUSY`, zero keys; the outer pair is content, not a route to EMPTY | `equal/` |
| Recognized Pi footer but incomplete bottom redraw, no closed rectangle | `UNTRUSTED`; say exits 1, `held/geometry-untrusted`, durable payload and `outbox flush` recovery; no draft accusation/automatic-after-clearing promise; zero keys | `untrusted/` |
| Valid independently built empty closed editor, paste blocked before touching input | Flush return codes `0,0,1`; diagnostics `consecutive_empty=1,2,3`; third reports `held/queue-stalled`, entry/target/durable path/recovery | `stalled/{02,03,04}-outbox-flush.txt`, `diagnostic-{1,2,3}.json` |
| Immutable entry and observers | Held entry's original header+payload equals the original byte-for-byte; list/status/digest expose the reason; all outbox file hashes and key trace unchanged | `stalled/05-outbox-list.txt`, `06-status.txt`, `07-digest.txt` |
| Real-content draft-shaped frame | Three flushes exit 0; no stalled inference, no typing, empty count absent/zero | `draft/` |
| Working/spinner-shaped conservative frame | Explicit BUSY premise, three flushes exit 0; zero keys/no stalled inference | `working/` |
| New recipient `recipient157`, PM draft, then live PM watcher route | Queued entry says `target: p157:pm`, `inbox: recipient157`, `inbox-written: 1`; wake field 4 is `recipient157`; the same file exists with exactly one durable line; no `pm.md` fabricated | `notify/queued-entry.msg`, `state/inbox-watch/p157-pm.wake`, `inbox/recipient157.md` |
| Inbox directory chmod 0555, verified genuinely unwritable as non-root | Exit 1/Permission denied naming `inbox/recipient157.md`; no durable file, wake, queue declaration, key or success receipt | `notify-readonly/01-notify-recipient157.txt`, `tmux-calls.jsonl` |

The PM/watch registrations in the independent notify test are fixture registrations with the **test process's own live PID and private project cwd**. Real Pi watcher reception is separately checked in section 2; this registration fixture is not claimed to be a real agent.

## 2. What flips: real red → green

Recipe derived from the explicitly authorized P147 `run-case.sh`/`judge-second.py`, copied into **this task's own** evidence package. Historical source extraction happens inside the disposable container, never by switching/resetting a worktree branch. Cases run with network disabled and a loopback mock model, no credentials. The newly installed exact 0.99.2 package is mounted read-only; dependency acquisition is logged in `logs/pin-pi.txt` and reproducible from `pkg/README.md`.

```bash
P138_SECOND=1 P143_DRAFT=1 bash docs/team/reports/P157-verify/pkg/run-case.sh tmux-p157-before-0992-dirty 603a4e8e 0 0.99.2
python3 docs/team/reports/P157-verify/pkg/judge-second.py tmux-p157-before-0992-dirty
P138_SECOND=1 P143_DRAFT=1 bash docs/team/reports/P157-verify/pkg/run-case.sh tmux-p157-after-0992-dirty HEAD 0 0.99.2
python3 docs/team/reports/P157-verify/pkg/judge-second.py tmux-p157-after-0992-dirty
P138_SECOND=1 bash docs/team/reports/P157-verify/pkg/run-case.sh watch-p157-after-0992-dirty HEAD 0 0.99.2
python3 docs/team/reports/P157-verify/pkg/judge-second.py watch-p157-after-0992-dirty
```

Actual raw tails:

```text
before run_rc=0; judge_rc=1
second_received=0 backend=0 backend_requests=0 settled=2 settle_editors_empty=1
FAIL second say stranded despite idle empty editor

after run_rc=0; judge_rc=0
second_received=1 backend=1 backend_requests=1 settled=3 settle_editors_empty=1
PASS second say delivered

watch run_rc=0; judge_rc=0
second_received=1 backend=1 backend_requests=1 settled=3 settle_editors_empty=1
PASS second say delivered
```

Separate judgments written here, not just the inherited judge:

```bash
python3 docs/team/reports/P157-verify/pkg/check-real.py
```

```text
tmux-p157-before-0992-dirty: first(received,backend)=(1, 1) second=(0, 0) draft_frames_identical=1 draft_turns=0
tmux-p157-before-0992-dirty: real_PM_wake_durable=pm existing_file=0
tmux-p157-after-0992-dirty: first(received,backend)=(1, 1) second=(1, 1) draft_frames_identical=1 draft_turns=0
tmux-p157-after-0992-dirty: real_PM_wake_durable=dev existing_file=1
watch-p157-after-0992-dirty: first(received,backend)=(1, 1) second=(1, 1)
watch-p157-after-0992-dirty: real_PM_wake_durable=dev existing_file=1
PASS independent raw real-artifact checks
```

Raw `pi-version.txt` files are `0.99.2`. Both historical and current first corrections arrive once; only the second was stranded historically. Current fallback `say.txt` reports confirmation and `outbox-after-say.txt` has no false `draft-raced` hold. The real `P143-HUMAN-DRAFT` before/after captures are **byte-identical**, draft guard produces no turn, and say reports queued. Raw `dev-events.jsonl`/`requests.jsonl` independently show reception and model-request counts. PM watcher wake points to an existing `dev.md`, not nonexistent `pm.md` (the baseline real run reproduces the wrong pointer).

### Clean same-name repeat

Every run **clears the exact task-owned case directory first**. `run-case.sh` refuses case names outside `(tmux|watch)-p157-*`. The original author's case directories were not touched.

I repeated `tmux-p157-after-0992-dirty` with the same name and the same command after first green, again with the draft control. The earlier event/request files and judge are preserved in `logs/repeat-first/`; the fresh run is `real-after-0992-repeat-{run,judge}.txt`. Result remains **1 reception / 1 backend / 3 settles**, not 2/2/6. Both run logs print the cleaned case and exact source revision. This closes the repeatability risk in **my** measurements, not in the author's unmodified recipe.

## 3. Gates and preserved scenarios

```bash
PATH=<home>/.bun/bin:$PATH openspec validate --all --strict
bash docs/team/reports/P157-verify/pkg/gates.sh HEAD
python3 docs/team/reports/P147-dev/pkg/check-deltas.py
python3 docs/team/reports/P147-dev/pkg/check-deltas.py --negative-control
```

`gates.sh` feeds an immutable `git archive` into a disposable full-dependency container, initializes a real independent git repository, then serially runs strict validation, `bash skills/teamsmith/tests/smoke.sh --select 0c,0d,57,12b-pi </dev/null`, and `TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null`. No worktree `.git` pointer or host socket is mounted.

| Command | Actual result | Raw output |
|---|---|---|
| Host strict OpenSpec | exit 0, 20 passed / 0 failed | `logs/openspec-host.txt` |
| Independent container strict OpenSpec | exit 0, 20 passed / 0 failed | `logs/openspec.txt` |
| Independent selected smoke | exit 0, **458 ✓ / 0 ✗**; 13 resolved prerequisite/selected sections | `logs/select.txt` |
| Independent FAST | exit 0, **3414 ✓ / 0 ✗**, 37 visibly skipped real-process segments; 119 sections close with matching assertion ledger | `logs/fast.txt`, `logs/gates-run.txt` |
| Scenario preservation | exit 0, all 49 baseline scenarios retained verbatim | `logs/check-deltas.txt` |
| Preservation negative control | exit 1 after test-process scenario removal | `logs/check-deltas-negative.txt` |

Six MODIFIED blocks, before→after scenario counts: delivery draft protection **13→17**, confirmation **7→8**, bottom pairing **11→11**, notify attribution **7→11**, panel queue read-only **5→6**, panel compose **6→7**. Each baseline scenario remains byte-for-byte. These counts/checks are freshly run, not taken from the apply report.

The selected run includes author's promoted `--mutations` guard replays and all six delivery-truth sections, freshly run in this independent repository (`25/10/25/12/15/10` section increments, cumulative 97 assertions); those are **additional coverage**, not substitutes for my generated adversaries. Selected smoke explicitly lists **106 keys not run**. FAST's 37 skipped real-process segments are retained verbatim in its final log line (including live adapters/PM/pulse, true-pane draft/delivery, panel, private-server and meeting controls). Section 57's selected run takes 29s, above its recorded empirical band of 26s but below its 110s budget; this is a printed measurement warning, not a suppressed failure. **No full non-FAST suite was run by this seat**; the P157 brief requests selected+FAST. This is not the final protected-branch/full archive gate.

## 4. Findings and measured limits

### F1 · WARNING: author's real-case recipe accumulates results

`docs/team/reports/P147-dev/pkg/run-case.sh` leaves an existing case directory intact; `scenario.sh` appends to events/requests. PM's prior finding is independently confirmed by reading the recipe's append/create-only behavior. My fresh same-name repeat starts clean and keeps the second count at 1. Owner action: **PM/dev** add a guarded task-specific clear or unique run identity to the source recipe, or explicitly record the recipe restriction. This seat only changed its own copy.

### F2 · WARNING: `host` is not a reproducible Pi version; current 1.0.0 run is red

I actually ran the original host option on both historical and current product code before pinning 0.99.2:

```bash
P138_SECOND=1 bash docs/team/reports/P157-verify/pkg/run-case.sh tmux-p157-before-dirty 603a4e8e 0 host
P138_SECOND=1 P143_DRAFT=1 bash docs/team/reports/P157-verify/pkg/run-case.sh tmux-p157-after-dirty HEAD 0 host
```

Each scenario runner exits 0; each second-message judge exits 1 with `second_received=0 backend=0 ... settled=1`. `pi-version.txt` is **1.0.0**. Current `second-before.frame` contains the line `fatal: no upstream configured for branch 'task/P138'` between the editor rules. The observer recorded an empty editor at settle, but that later captured frame is not visually empty. The current sender exits 0/queued and promises automatic delivery after clearing, although neither correction reaches the backend.

Evidence: `logs/real-{before,after}-{run,judge}.txt`, `logs/tmux-p157-{before,after}-dirty/`. These failed runs are committed and not overwritten. **No root cause or P147 regression attribution is established**: changing the runtime and pinning 0.99.2 demonstrates a reproducibility boundary, not proof that every 1.0.0 discrepancy is harmless. Owner action: **PM/dev** investigate the unexpected fatal row and decide whether 1.0.0 is supported/requires a separate fix; pin or record the runtime for acceptance. Do not cite this report as current-host green.

### Coverage limits (not silently claimed as measured)

- No user's live PM/worker window or default tmux server was inspected, operated or used for a demonstration. No production provider or real customer workflow was exercised.
- No other adapter/TUI was measured. The non-root synthetic notify registration is not a live Pi watcher; live watcher confirmation comes from the separate container cases.
- The independently generated working/spinner control proves the BUSY exclusion, not every real Pi working/render phase.
- Unicode, long rule/spinner/footer-clone drafts at every cursor position, CJK/emoji/combining/tab terminal-cell widths, scrolling and renderer clipping were **not independently recaptured with real Pi**. The author's `drafts` fixture is fake tmux + subprocess/production judgment, not renderer evidence for those cases. 0.99.2 real ASCII draft and one incomplete redraw adversary do not close that wider coverage gap.
- Panel JSON/text/TUI and recovery/concurrency mutations have freshly rerun author-fixture coverage through section 57, not independently constructed panel real-process controls here. Existing whitespace-only/status-clone/folded-paste limitations remain; I do not claim to fix the <peer-c> incident.
- No full non-FAST gate, archive, push, merge, task-checkbox update or protected-branch decision was performed.

## Delivery

Commits: `54405d7e` independent adversaries; `d65a2622` real pinned red/green and separate current-runtime failure; final clean-repeat, gate logs and this report are delivered together. All background jobs were harvested; strict/selected/FAST return codes are `0/0/0`. Branch remains local for PM review. Reproduction commands and dependency pin are in `docs/team/reports/P157-verify/pkg/README.md`.
