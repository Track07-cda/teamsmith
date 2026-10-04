# P143 · delivery-truth proposal and independently rerun real-Pi evidence

```text
agent: verify
phase: propose
status: DELIVERED (planning only; PM proposal review and apply remain pending)
change: delivery-truth
branch: task/P143-busy-notify-propose
mode: local; no push, merge or archive
tested source: ccfdf854 (product code unchanged from the dispatched tree)
Pi actually measured: 0.99.2; pane: 120×32; image: localhost/teamsmith-gate:local
```

## Summary

Delivered `openspec/changes/delivery-truth/{proposal,design,tasks}.md` and full deltas for `delivery-guard`, `notify-and-inbox`, `panel`. No product implementation or baseline spec was edited. All implementation tasks remain unchecked. Planning/evidence commits: `f4042b9d`, `c4067cb6`; this report and the final committed-tree gate evidence are committed separately.

The design keeps legacy highest-top/lowest-bottom/cursor containment and admits a narrower candidate domain only for a proved closed Pi suffix. It separates untrusted geometry from a human draft, holds repeated no-progress entries visibly with durable reasons, and keeps manual notify's recipient file/declaration/wake pointer equal while retaining the PM knock destination. It preserves existing terminal holds and residual detector limitations.

## What I personally ran versus references

**Personally run in P143:** three fresh disposable-container real Pi cases; fallback second-message red, watcher second-message positive control, real-editor draft negative control; notify path mismatch measured from the PM's actual wake and disk snapshot; production extraction versus planning-only selector on two new real frames; strict all-spec validation; verbatim scenario preservation and its test-only deletion negative control; package syntax and diff/scope checks.

**Referenced, not rerun as P143:** P138's historical version matrix, Pi 0.86.0/0.99.1 runs, 867-file evidence body, <peer-c> original feedback, and the PM's `fe46eae6` reproduction. The dispatched worktree lacked P138's package/report; I read their git objects from `42e364fb` without checking out or changing another branch. The reusable six-file recipe was copied into **this task's own** report directory; modifications are documented in `pkg/README.md`.

No personal claim of a repaired fallback, new panel behavior, Unicode-layout proof or complete smoke green is made. The planning-only frame probe is deliberately separate from the shipped selector and never sends keys.

## Deliverables

| Path | Purpose |
|---|---|
| `openspec/changes/delivery-truth/proposal.md` | Scope, central flips, capabilities, boundaries, acceptance |
| `openspec/changes/delivery-truth/design.md` | Closed-layout admission; companion diagnostics; PM knock versus durable recipient; risks/migration/evidence |
| `openspec/changes/delivery-truth/tasks.md` | Dependency-ordered, unchecked implementation/independent-verification steps with commands |
| `openspec/changes/delivery-truth/specs/*/spec.md` | Six full MODIFIED blocks, one ADDED requirement, observable scenarios |
| `docs/team/reports/P143-verify/pkg/` | P138-derived container recipe and proposal-only judges/checkers |
| `docs/team/reports/P143-verify/logs/` | Raw real frames, actual editor/idle events, backend requests, queue/inbox/wake snapshots and gate tails |

## Actual commands and output tails

All commands ran from the assigned verify worktree. `host` mounts the installed Pi package read-only **inside Podman**; no host tmux socket or credential/session directory is mounted. Historical `skills/` are streamed with `git archive`, extracted in container `/tmp`, and never checked out in a worktree.

### 1. Real fallback red

```bash
P138_SECOND=1 bash docs/team/reports/P143-verify/pkg/run-case.sh tmux-p143-dirty ccfdf854 0 host
python3 docs/team/reports/P143-verify/pkg/judge-second.py tmux-p143-dirty
```

Case runner exit 0; judge **exit 1, expected defect red**:

```text
say_rc=0
second_say_rc=0
notify_rc=0
dev_editor_at_settle= ['', '']
dirty_before= ?? leftover.txt
dirty_after= ?? leftover.txt
tmux-p143-dirty: second_received=0 backend=0 backend_requests=0 settled=2 settle_editors_empty=1
FAIL second say stranded despite idle empty editor
```

`second-say.txt` promises automatic delivery after clearing a draft. `second-outbox.txt` still lists the second entry as queued after two flushes. Before/after frames are byte-identical; actual editor observations are empty/idle. The first correction reached the real model but remains wrongly `draft-raced-left` held. Evidence: `logs/tmux-p143-dirty/`, `red-run.txt`, `red-judge.txt`.

### 2. Real watcher positive control

```bash
P138_SECOND=1 bash docs/team/reports/P143-verify/pkg/run-case.sh watch-p143-dirty ccfdf854 0 host
python3 docs/team/reports/P143-verify/pkg/judge-second.py watch-p143-dirty
```

Both exit 0:

```text
watch-p143-dirty: second_received=1 backend=1 backend_requests=1 settled=3 settle_editors_empty=1
PASS second say delivered
```

This is a working production channel on the same source, **not** a fallback fix. P143 strengthened the inherited judge from backend existence to exactly one matching backend request. Evidence: `logs/watch-p143-dirty/`, `watch-run.txt`, `watch-judge.txt`.

### 3. Real draft negative and real-frame feasibility flip

```bash
P138_SECOND=1 P143_DRAFT=1 bash docs/team/reports/P143-verify/pkg/run-case.sh tmux-p143-draft-dirty ccfdf854 0 host
python3 docs/team/reports/P143-verify/pkg/shape-probe.py
python3 docs/team/reports/P143-verify/pkg/check-evidence.py
```

Exit 0. The fixture deliberately types `P143-HUMAN-DRAFT` once, without Enter; the guarded correction must not alter it. `draft-before.frame == draft-after.frame`, actual editor observer reports that draft, and no `P143-DRAFT-GUARD` reception/backend turn occurs.

```text
tmux-p143-dirty: production geometry=21 30
tmux-p143-dirty: planning closed-shape geometry=[28 30] cursor=29 text=''
PASS real empty frame flips BUSY -> EMPTY in planning probe only
tmux-p143-draft-dirty: planning closed-shape geometry=[28 30] cursor=29 text='P143-HUMAN-DRAFT'
PASS real draft preserved; proposed selector remains BUSY
LIMIT: ASCII-layout proof on two real frames, not implementation-green or Unicode support
F2 RED: recipient=dev declaration=pm wake=pm.md exists=no; PM received one preview wake
F1 RED: same stable real frame; queued after two flushes; automatic-clearing promise; no trust diagnostic
DRAFT CONTROL PASS: real editor draft retained; no guard payload reception; no frame change
```

The probe verifies footer cwd against the actual recorded runtime cwd, Pi version/provenance, cursor containment, exact footer shape, unique rectangle and content/height bounds. It rejects non-ASCII content rather than pretending to implement terminal-cell geometry. Production extraction is read through the shipped Bash function; only the alternate **planning probe** supplies the green frame read. Evidence: `shape-probe.txt`, `evidence-check.txt`, real draft case logs.

### 4. Notify red, personally observed

The recipe ran `team notify dev --from pm "P138-NOTIFY-watch-p143-dirty"` in the isolated fixture. The full summary exists in `inbox-final/dev.md`; `pm.md` does not exist. PM receives one actual `team-inbox` wake saying:

```text
[knock] from pm → pm.md :: [manual] agent:pm · P138-NOTIFY-watch-p143-dirty
Full text: read docs/team/inbox/pm.md
```

The spool's durable field and journal `durable=pm` match the wrong declaration. This is a bad full-text pointer, **not** a claim the preview wake was lost. The proposal fixes the declaration/path and retains the PM destination; it does not invent a second full-text copy.

### 5. Acceptance gates and falsifiable preservation check

```bash
OPENSPEC_TELEMETRY=0 PATH=<home>/.bun/bin:$PATH openspec validate --all --strict
python3 docs/team/reports/P143-verify/pkg/check-deltas.py
python3 docs/team/reports/P143-verify/pkg/check-deltas.py --negative-control
bash -n docs/team/reports/P143-verify/pkg/{run-case,scenario}.sh
```

Strict validation: **16 passed, 0 failed**, including `change/delivery-truth`; exit 0. The final committed-proposal tail is retained in `logs/openspec-validate-committed.txt` (rerun after the last spec edit). Initial missing-PATH invocation exited 127; adding the installed CLI directory resolved it. No new dependency was installed.

Scenario check: exit 0; all **49 original scenarios** in six MODIFIED blocks retained **verbatim**, with 60 scenarios after additions. Test-only deletion of one original scenario per block produces **exit 1 / FAIL baseline scenario loss** without editing any spec. Python AST and Bash syntax passed; `logs/package-syntax.txt`. OpenSpec status reports all four planning artifacts complete; this is not implementation completion.

| MODIFIED block | Before | After | Original scenarios |
|---|---:|---:|---|
| delivery-guard / no automated draft typing | 13 | 17 | verbatim |
| delivery-guard / pane confirmation and queue reporting | 7 | 8 | verbatim |
| delivery-guard / lowest admitted bottom border | 11 | 11 | verbatim |
| notify-and-inbox / sender attribution | 7 | 11 | verbatim |
| panel / read-only delivery queue | 5 | 6 | verbatim |
| panel / compose and honest receipts | 6 | 7 | verbatim |

The proposal's pre-change frame comparison remains scoped to the original enumerated frame corpus. The newly captured real idle-empty frames are explicit, controlled BUSY→EMPTY flips, paired with a real draft; no universal monotonicity assertion was introduced.

## What flips and where the red lives

| Concern | Red evidence / negative test | Required green after apply |
|---|---|---|
| Geometry + real fallback | New real frame `[21 30] BUSY`; second judge exit1 | Same real frame `[28 30] EMPTY`; one received/model submission, first correction properly confirmed |
| Queue truth | Existing real empty editor still queued after two flushes, automatic-clearing promise, no trust diagnostic | Measured trust; unknown geometry nonzero/held; third eligible empty no-progress evaluation nonzero/queue-stalled |
| Notify three-way identity | Real PM wake/declaration `pm`, durable file `dev`, referenced file missing | PM still woken; recipient/declaration/path all dev and existing full text |
| Draft safety | Personally measured draft remains; planning selector BUSY; unsafe nearest-border test mutations specified for apply | Production zero-key control, wrapped-rule/cursor/Unicode adversaries and unchanged legacy frames |
| Panel diagnostics | Current durable queue evidence has no geometry/stall reason; new panel contract is not implemented here | Read-only count/reasons in all modes; reason-mapping removal must make the promoted test fail |
| MODIFIED preservation | Test-only scenario deletion exits1 | All 49 original scenarios verbatim, strict validation exit0 |

New sidecar-transition, panel receipt mutations, write-failure refusal, and adversarial Unicode/scroll controls are **implementation/verification obligations**, not personally obtained P143 product-green results. Each has a falsifiable scenario and an explicit task/command; do not confuse a planned mutation with an executed one.

## Boundaries, deviations and pending work

- No `skills/**` implementation, protected baseline spec, PM ledger/brief, main worktree or other seat was modified. All tracked changes are within the task's explicit change/report grants.
- No default-socket tmux query, probe, send, recovery or kill ran on the host. Container-local cleanup kills only its private server and the recorded mock-server PID. No user credential or Pi session files were read.
- Full smoke was **not run in this propose task**: its brief's acceptance is strict OpenSpec validation, preserved scenarios and real evidence. A full isolated correctness gate is explicitly required before apply delivery/independent verification; no smoke PASS is asserted.
- P143's actual Pi is 0.99.2; the initially copied probe expected P138's 0.99.1 and failed its provenance assertion. I corrected the declared supported version to the measured version and reran it; it was not treated as geometry evidence until that assertion passed.
- The ASCII two-frame probe establishes feasibility, not a universal renderer proof. Scrolled layouts, Unicode cell-width behavior, rule-shaped real drafts, panel rendering, no-progress sidecar transitions, failed durable writes and full regression suite remain for apply/independent verify.
- No hard blocker to **proposal delivery**. PM must accept/reject this proposal before dispatching apply to a different seat; actual product defects remain unresolved until that work and independent verification land. No archive authorization is implied.
