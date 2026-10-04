# P5 · Propose: `deferred-delivery-and-draft-entry` (D20 option B)

agent: dev2   status: delivered (propose phase)   time: 2026-09-15T08:40:00Z
branch: `task/P5-propose-deferred-delivery-an`   PR/MR: - (local mode)

## Deliverables

| Path | What |
|---|---|
| `openspec/changes/deferred-delivery-and-draft-entry/proposal.md` | why + flip + what changes + capabilities + impact + acceptance verbatim + boundaries (486 words) |
| `openspec/changes/deferred-delivery-and-draft-entry/design.md` | DG1–DG12: detector, queue-as-interface, drain, queued-honesty, `--now`, UNKNOWN, TTL/cap, draft file contract, extension enqueue, visibility, no-regression list, flip mechanics; risks; migration |
| `openspec/changes/deferred-delivery-and-draft-entry/tasks.md` | 31 ordered apply items (flip fixture first, then guard/queue/drain/send paths/draft/visibility/docs/tests+isolation/evidence), each naming its capability requirement |
| `openspec/changes/deferred-delivery-and-draft-entry/specs/delivery-guard/spec.md` | new capability: 9 requirements, 27 scenarios |
| `openspec/changes/deferred-delivery-and-draft-entry/specs/notify-and-inbox/spec.md` | 2 MODIFIED requirements (restated in full + 1 new scenario each) |
| `openspec/changes/deferred-delivery-and-draft-entry/specs/watchdog/spec.md` | 1 MODIFIED requirement (restated in full + 1 new scenario) |
| `openspec/changes/deferred-delivery-and-draft-entry/.openspec.yaml` | scaffolded by `openspec new change` |
| `docs/team/reports/P5-dev2/pkg/` | independent evidence package (`lib.sh` + `run.sh` + 5 numbered sections) that re-runs every claim below on scratch copies |

No code, test, reference or `openspec/specs/**` file was touched. The delta's promises are the apply phase's job.

## Verification evidence (must have actually been run)

### Gate 1 — `openspec validate --all --strict`

```
$ openspec validate --all --strict
✓ spec/board-and-status
✓ spec/boundary
✓ change/deferred-delivery-and-draft-entry
✓ spec/dispatch
✓ spec/meeting
✓ spec/memory-and-deps
✓ spec/notify-and-inbox
✓ spec/verification
✓ spec/watchdog
Totals: 9 passed, 0 failed (9 items)
```

### Gate 2 — `bash skills/teamsmith/tests/spec-lint.sh`

```
$ bash skills/teamsmith/tests/spec-lint.sh
spec-lint: OK — 11 spec file(s), 57 requirement(s), 112 scenario(s) under openspec
```

### The change resolves and shows the artefacts

```
$ openspec change show deferred-delivery-and-draft-entry
## Why
D20 (user report, 2026-09-15): automated messages are typed with `send-keys` + `Enter`, …
## Flip
- **Red before** (E3 §1.1(e), real Pi pane): …
## What Changes
- **new capability `delivery-guard`**: …
```

Yes, the command also prints a deprecation warning ("Prefer verb-first commands") on stderr; exit code is 0.

### Scratch archive — the promised operations apply (nested layout is required: openspec resolves the `openspec/` child)

```
$ rm -rf /tmp/p5-archive3 && mkdir -p /tmp/p5-archive3 && cp -r openspec /tmp/p5-archive3
$ (cd /tmp/p5-archive3 && openspec archive -y deferred-delivery-and-draft-entry)
Specs to update:
  delivery-guard: create
  notify-and-inbox: update
  watchdog: update
Applying changes to openspec/specs/delivery-guard/spec.md:
  + 9 added
Applying changes to openspec/specs/notify-and-inbox/spec.md:
  ~ 2 modified
Applying changes to openspec/specs/watchdog/spec.md:
  ~ 1 modified
Totals: + 9, ~ 3, - 0, → 0
Specs updated successfully.
```

Post-archive checks on the scratch tree:

```
$ head -4 /tmp/p5-archive3/openspec/specs/delivery-guard/spec.md
# delivery-guard Specification
## Purpose
The delivery guard: no automated sender may type into a TUI input box that already holds a draft …
$ grep -c 'TBD' /tmp/p5-archive3/openspec/specs/delivery-guard/spec.md
0
$ (cd /tmp/p5-archive3 && openspec validate --all --strict) | tail -1
Totals: 9 passed, 0 failed (9 items)
$ bash skills/teamsmith/tests/spec-lint.sh /tmp/p5-archive3/openspec
spec-lint: OK — 9 spec file(s), 54 requirement(s), 107 scenario(s) under /tmp/p5-archive3/openspec
```

### MODIFIED blocks are mechanical restatements, not retyped text

The three blocks were extracted from `openspec/specs/**` by script and only *extended* (one prose sentence + one
scenario each). The report's own diff (base `git show HEAD:openspec/specs/<cap>/spec.md` vs the scratch archive,
normalized for blank lines) contains **additions only** — no changed or dropped line:

```
$ bash /tmp/p5-restatement-diff.sh
=== notify-and-inbox :: Messages to a stopped agent fall back to the inbox
@@ -2,8 +2,16 @@
 … (base 4 lines unchanged)
+While the agent is running but its input box holds a draft the message MUST NOT be typed: …
+#### Scenario: A draft in the target's input box is not disturbed
=== notify-and-inbox :: A turn-end notification appends one inbox line and knocks once
@@ -2,6 +2,9 @@   → +The knock goes through the delivery guard: …
@@ -9,3 +12,8 @@   → +#### Scenario: A dirty PM input box turns the knock into a queued entry
=== watchdog :: Pending work is defined, and no work means no wake-up
@@ -3,6 +3,9 @@   → +The wake line goes through the delivery guard (`delivery-guard`): …
@@ -11,3 +14,8 @@  → +#### Scenario: A dirty PM input box holds the wake instead of gluing it
```

### C0's delta rules (the P2.4 branch lint) are green on this change — and can fail on it

The in-tree `spec-lint.sh` predates C0, so the six delta-applicability rules were also run from
`task/P2.4-apply-rework-4-close-f-v3-1-` as extra evidence, with two negative controls that fire on *this* delta:

```
$ git show task/P2.4-…:skills/teamsmith/tests/spec-lint.sh > /tmp/spec-lint-c0.sh
$ bash /tmp/spec-lint-c0.sh
spec-lint: OK — 11 spec file(s), 57 requirement(s), 112 scenario(s) under openspec
$ # negative control 1: rename the MODIFIED requirement
$ bash /tmp/spec-lint-c0.sh /tmp/p5-neg/openspec
…/specs/notify-and-inbox/spec.md:3: delta-modified-requirement-missing: MODIFIED names a requirement the base spec does not have: Messages to a stopped agent fall back to the INBOX
spec-lint: FAIL — 1 violation(s) under /tmp/p5-neg/openspec   (rc=1)
$ # negative control 2: drop one of the base requirement's scenarios
$ bash /tmp/spec-lint-c0.sh /tmp/p5-neg2/openspec
…/specs/watchdog/spec.md:3: delta-dropped-scenario: MODIFIED drops base scenario "An unread notification wakes the PM" of: Pending work is defined, and no work means no wake-up
spec-lint: FAIL — 1 violation(s) under /tmp/p5-neg2/openspec   (rc=1)
```

### Independent evidence package — `bash docs/team/reports/P5-dev2/pkg/run.sh`

```
section                                                                    pass   fail   skip findings
-----------------------------------------------------------------------------------------------
① gates: openspec validate --all --strict + spec-lint.sh + proposal <500 words      3      0      0        0
② the change resolves and carries Why/Flip/Capabilities/Acceptance/Boundaries     16      0      0        0
③ scratch archive: +9 / ~3, delivery-guard Purpose (no TBD), openspec/specs untouched     14      0      0        0
④ MODIFIED blocks: additions only, no base scenario dropped                 9      0      0        0
⑤ C0 delta rules green here, red on two broken copies (flip evidence)       4      0      0        2

== 总结果 ==  PASS：所有小节都跑通、没有 ✗（脚本级失败：0）
  被测仓库未被证据包改动（git status 前后一致）
```

The package writes only under `mktemp -d` scratch dirs; section ⑤'s two `FINDING` lines are the *expected*
negative controls (the checker must fire when the delta is broken), not defects. Each section is runnable alone
(`bash docs/team/reports/P5-dev2/pkg/30-archive.sh`), and each acts only on a copy of `openspec/`.

### Acceptance — `git status --porcelain`

Only the change directory (committed) and this report are in play; no other path was written (see the final
`git status --porcelain` at the end of the branch).

## Flip evidence (required for defect-fix tasks)

**This phase ships no implementation, by the brief's design.** The defect-level flip is written into the change and
owned by the apply phase: `proposal.md` §Flip carries E3's measured red (draft glued and pushed out on a real Pi
pane) and the green contract; `tasks.md` item 0.1 requires the apply dev to run that fixture against the
**pre-change tree first** and record the glued pane, then against the branch. A report that only shows green would
fail its own instructions.

The genuine break→red→restore→green cycle available in *this* phase is the artefacts' own falsifier (C0's delta
rules), and it is in the evidence above and reproducible via
`bash docs/team/reports/P5-dev2/pkg/50-delta-lint.sh` (section ⑤, exit 0 with two expected `FINDING` controls): a
typo'd `MODIFIED` name → `delta-modified-requirement-missing`, a dropped base scenario → `delta-dropped-scenario`,
restore → the same lint green. The code-level flip is not claimed here.

## Requirement → scenario → falsifier map

`F` = the apply item in `tasks.md` that must make the scenario red when its behaviour is removed; `*` = the scenario
is real-process (tmux + Pi/fake pane) and has a headless companion per the same item.

| Requirement (capability) | Scenarios | Falsifier |
|---|---|---|
| An automated send never types into a non-empty input box (`delivery-guard`) | empty+hint free; multi-line draft survives; whitespace-only documented miss; unknown shape delivers; draft before Enter holds | 1.1 `tests/guard-matrix.sh` (E3 §1.5 matrix incl. the miss); 1.2 borderless pane; 1.3 scripted fake TUI `*` |
| Queue entries are immutable files under `TEAM_STATE_DIR` (`delivery-guard`) | header+verbatim payload; FIFO drain; `TEAM_STATE_DIR` moves the queue | 2.1 (hostile payload, no `*.tmp`, temp root); 3.1 order `*` |
| One drain delivers each entry once, claims before typing (`delivery-guard`) | flush delivers; two concurrent drains; tick drains without a daemon | 3.1 + 3.2 (flush ∧ `team watch --once` race; `ps`/window diff) |
| Delivery is confirmed by the pane, queued is reported as queued (`delivery-guard`) | queued says `queued`; clean box still confirms; unconfirmed → held, not duplicated | 3.3 (old 6×300 ms loop removed); 3.1 fingerprint-after-Enter `*` |
| Expiry holds, never types (`delivery-guard`) | TTL hold; held delivered later; cap escalates oldest | 2.4 (`TEAM_DEFER_TTL=1`, `TEAM_OUTBOX_MAX=2`) |
| Duplicate notice is not queued/delivered twice (`delivery-guard`) | identical notices → one entry; extension key carried | 2.3; 4.3 extension harness (smoke §13 pattern) |
| Queued/held visible in status and digest (`delivery-guard`) | two held reported; empty prints nothing | 6.1 (`grep -c outbox` 1 vs 0) |
| The human draft entry is a file (`delivery-guard`) | three-line → one user message; editor wrapper enqueues; second draft = second entry; draft window never a target | 5.1 scripted `$EDITOR`; 5.2 three-line paste `*`; 5.3 pane byte-identity |
| Which senders defer, `--now` audited (`delivery-guard`) | `--now` glues + `forced.log`; `TEAM_NOTIFY_TMUX=0` creates nothing | 4.1; 4.4 regression (dispatch argv, meeting knock, shell guard) |
| `team say` falls back per state (`notify-and-inbox`, MODIFIED) | offline → inbox (existing); dirty box → queued, draft untouched (new) | smoke §11g② (existing) + 4.1 (new) |
| Turn-end notification knocks once (`notify-and-inbox`, MODIFIED) | one line; dedup window (existing); dirty box → queued knock (new) | smoke §13 harness (existing) + 4.3 (new) |
| Pending work is defined (`watchdog`, MODIFIED) | nothing pending silent; unread wakes (existing); dirty box → held wake (new) | smoke §11b (existing) + 4.2 (new) |

## What I left out, and why

- **C — the PM-side delivery channel** (`pi.sendUserMessage`, `ctx.ui.getEditorText()`, PM loads the extension):
  D21 defers it; it consumes this change's queue format, so doing it now would couple two pipelines. E3 §6 also
  lists its unmeasured parts (modal states, extension-not-loaded visibility) that its own brief must settle.
- **v3 detector baseline** — spec requires v2's behaviour only; v3 stays an optional upgrade that ships only with its
  own falsifier (tasks 1.1, design DG1), so no scenario depends on an unmeasured baseline.
- **D19 dashboard** — only the one-line `outbox` count (design DG10); the dashboard is D19's own explore.
- **Meeting knock** — cross-project and PM-only; kept byte-for-byte (R9 prose, task 4.4).
- **Multi-line `team say`** — still refused; multi-line is the draft entry's job (R8, existing error unchanged).
- **Aging/retry policy beyond TTL** — capped queue + explicit exits are specified; no exponential backoff, no
  per-entry priority.

## Decisions the PM must take before the apply brief

1. **`team say` defers for worker targets by default** (design DG5; E3 §7 asked). Recommendation: yes — the glue
   damages a worker's draft the same way, and `--now` is the explicit escape. If the PM says no, the spec needs the
   PM-only wording and R9 loses its worker clause.
2. **UNKNOWN pane shape ⇒ deliver as today + one warning** (design DG6). Recommendation: yes — the alternative is
   messages held forever in a pane teamsmith does not control.
3. **Does a queued message write its inbox line at enqueue time?** (design DG4). Recommendation: yes (this is what
   makes the TTL escape lossless and matches today's `team notify`); if rejected, R5's "already durable" clause and
   task 2.2 change.
4. **Where the apply phase may write**: the brief must grant `skills/teamsmith/scripts/**`, `SKILL.md`,
   `references/**`, `extension/**` (PM-owned) and `skills/teamsmith/tests/**` (agent:dev), per OWNERSHIP.
5. **Verify owner**: E3 §5.4's seven surfaces are adversarial; the verifier must not be the apply dev (and not the
   author of this proposal).

## Decisions and deviations

- **No code/specs beyond the change dir** — per the brief; the only deviation-shaped choices are recorded above.
- The scratch-archive command needed `mkdir -p` first (the `cp -r openspec <dir>` must land as a child for openspec
  to resolve the root); the proposal's acceptance fence carries only the two gate commands and the exact archive
  invocation is in this report.
- `openspec change show` is deprecated in 1.8.0 (warning on stderr, exit 0); used as evidence because the brief
  names it.

## Suggested next steps

- PM: review the proposal gate (`docs/team/reviews/deferred-delivery-and-draft-entry-proposal.md`); answer the five
  decisions above; then write the apply brief (P5 → A1) granting the paths in item 4. Re-run the claims with
  `bash docs/team/reports/P5-dev2/pkg/run.sh`.
- Apply dev (≠ dev2): tasks 0.1 first — the red fixture on the pre-change tree is the evidence the review will look
  for; then the guard/queue/drain core before any send-path rewiring.
- Verify (a third agent): E3 §5.4's list, plus the isolation item 7.2 and the negative control "stub the guard to
  always report free → the fixture must glue".
