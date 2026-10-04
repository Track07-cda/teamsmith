# P172 · Category-set pulse reminder proposal

agent: verify   status: PARTIAL (proposal complete; baseline full-gate failure)   time: 2026-10-02
branch: `task/P172-propose`   PR/MR: - (local mode; no push)

## Deliverables

| Path | What |
| --- | --- |
| `openspec/changes/pulse-nudge-key/proposal.md` | Planning-only scope, boundaries, flips and copy-pasteable acceptance commands. |
| `openspec/changes/pulse-nudge-key/design.md` | Source-backed key correction, category-key design, empty rearming, compatibility and sibling-delta risk. |
| `openspec/changes/pulse-nudge-key/tasks.md` | Dependency-ordered apply and independent-verification checklist; all implementation boxes remain unchecked. |
| `openspec/changes/pulse-nudge-key/specs/{watchdog,panel}/spec.md` | Full MODIFIED blocks preserving all four baseline scenarios; watchdog 2→9 scenarios, panel 2→3. |
| `docs/team/reports/P172-verify/pkg/` | Reproducible policy probe, container runner, exact baseline comparison and isolated committed-clone gate. |
| `docs/team/reports/P172-verify/logs/` | Raw validation, comparison, red-side, mutation and full-gate output. |

Commits before this report: `94883ec0` (baseline red probe) and `f59bb23f` (complete planning artifacts and expanded evidence package).

## Verification evidence (actually run)

```text
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
✓ change/pulse-nudge-key
Totals: 22 passed, 0 failed (22 items)
exit 0

$ PATH="$HOME/.bun/bin:$PATH" openspec status --change pulse-nudge-key
Progress: 4/4 artifacts complete
[x] proposal
[x] specs
[x] design
[x] tasks
All planning artifacts complete!

$ bash docs/team/reports/P172-verify/pkg/check-baseline.sh
PRESERVED watchdog: The second tick stays quiet (verbatim)
PRESERVED watchdog: Standby suppresses the nudge (verbatim)
COMPARE watchdog: baseline_scenarios=2 delta_scenarios=9
PRESERVED panel: The band mirrors the measured state (verbatim)
PRESERVED panel: Standby is visible where the wake-ups are decided (verbatim)
PRESERVED panel: original normative paragraph (verbatim)
COMPARE panel: baseline_scenarios=2 delta_scenarios=3
PASS: both MODIFIED blocks retain every baseline scenario
exit 0

$ bash -n docs/team/reports/P172-verify/pkg/*.sh
$ git diff --check
both exit 0
```

### Full correctness gate

The gate runs an independent clone of committed revision `f59bb23f` in `localhost/teamsmith-gate:local`, not a
worktree pointer, with an isolated `/tmp`. The host/default tmux socket and live team state are not mounted.

```text
$ bash docs/team/reports/P172-verify/pkg/gate.sh
Totals: 22 passed, 0 failed (22 items)
✗ 36⑧ 产品面检出探针有失败（1 条）
    bad: ⑨ 产品面树里出现裸 tmux 变更调用，§31 仍然绿（跳过把产品问题吞了）
#96 36 · 选段与分段账本自检 · ✓109 ✗1 SKIP0
账本自查：120 段收口 · 增量 ✓4200 ✗1 SKIP3 ｜ 结果行 ✓4200 ✗1 —— 一致
== 结果 == ✓ 4200 ✗ 1
smoke 有失败项（--keep 保留现场）
exit 1; background job harvested after 2046.6s

$ bash docs/team/reports/P172-verify/pkg/baseline-blocker.sh
BASELINE revision=f07d6c1c2da3bdcb5a03be7c7081d56441030df1
bad: ⑨ 产品面树里出现裸 tmux 变更调用，§31 仍然绿（跳过把产品问题吞了）
ok: ⑧ 真实树指纹前后一致（夹具只动 scratch 树）
== 检出形状探针 == ok 71 bad 1 skip 0
exit 1; background job harvested after 265.9s
```

- **Verdict: OpenSpec/proposal evidence PASS; complete smoke FAIL, not waived.** The exact same negative-control
  failure occurs in a separate clone of pre-P172 commit `f07d6c1c`; P172 changes no `skills/**` implementation/test
  files. The owning maintainer must determine whether the defect is in the injector, lint, or selection path.
- Full-gate visible skips: `12b-h` fake-PM knock and watchdog drain require a caller inside tmux; `31b` nested
  podman selftest cannot find a container runtime inside the gate container. These were printed, not counted as
  exercised. Nested fixtures also print their own skip summaries in the raw log.
- The raw full gate includes incidental git auto-identity diagnostics and `branch:: command not found`, with no
  corresponding additional outer assertion failure. They were not edited away or claimed fixed.
- The first standalone baseline attempt exited **125 before tests**, because it omitted `--cgroups=enabled`
  alongside `--pid=host`. Its failed launch log is retained as `baseline-checkout-shape.log`; the corrected,
  reproducible script uses the same explicit cgroup option as the successful full-gate launch. Only the rerun
  supplies baseline attribution. Every background job was harvested.

## Flip evidence

### Real pre-fix failures; no implementation written

```text
$ bash docs/team/reports/P172-verify/pkg/run.sh --expect-current-red
counts=4 0 0 0 0 0 0 0 epoch=100900 sig=31270149 nudges=2 sends=2
FAIL F1-count-only actual=2/100900 expected=1/100000
counts=1 0 0 0 0 0 0 0 epoch=100000 sig=2427741911 nudges=1 sends=1
FAIL F2-empty-return actual=1 expected=2
FAIL F3-standby-empty-return actual=1 expected=2
FAIL F4-all-category-counts actual=8 expected=0
PASS G1-add-category actual=2
PASS G2-remove-category actual=3
PASS G3-before-gap actual=1/100000
PASS G4-at-gap actual=2
PASS G5-empty-silent actual=0/0/0
PASS G6-standby-silent actual=0/0/0
PASS G7-standby-backlog actual=1
PASS G8-standby-off actual=1
PASS G9-panel-current-count actual=4
PASS G10-panel-read-only actual=same
PASS G11-eight-categories actual=8
PASS G12-seven-field-text actual=停了的 agent 2
SUMMARY failures=4 ids=F1-count-only,F2-empty-return,F3-standby-empty-return,F4-all-category-counts
exit 0: the wrapper requires exactly these four known baseline failures, not a repaired implementation.
```

F1 is the count 1→4 bypass inside the 3600-second gap. F2 is the ordinary empty→same-category return suppression;
F3 is the same return after emptiness was observed under standby. F4 independently changes each of the eight
positive category counts 1→4; all eight incorrectly produce a second reminder. This is the red side, not a claim
that the source is fixed. The future post-apply command is `bash docs/team/reports/P172-verify/pkg/run.sh --assert-fixed`
and must report zero failures. It has not been claimed green during propose.

### Negative controls for promises that already hold

```text
$ bash docs/team/reports/P172-verify/pkg/run.sh --mutations
MUTANT constant-key rejected (in-memory override; repository unchanged)
FAIL G1-add-category actual=1 expected=2
FAIL G2-remove-category actual=1 expected=3
FAIL G11-eight-categories actual=1 expected=8
MUTANT frozen-panel rejected (in-memory override; repository unchanged)
FAIL G9-panel-current-count actual=bad expected=4
exit 0: both assertion-mode mutant subprocesses failed, and their specific guard failures were found.
```

The constant-key negative control supplies the red side for “a new category must still wake immediately,” so a
blanket timer/constant-key fix cannot silently satisfy the noise test. The frozen-panel control shows that keeping
actual counts is independently checked. The overrides exist only in disposable child shells; no implementation
file is changed or needs restoration. Complete mutant output, including the known pre-fix failures, is retained.

## Decisions and deviations

- **Corrected the hypothesis:** `skills/teamsmith/scripts/lib/common.sh:3127` hashes the eight-field count vector
  via `team_hash` (`:1202`), not rendered reminder text. `cmd-watch.sh:328–332,360–377` consumes that hash, compares
  `nudge_sig` or elapsed gap, and records the reminder time. The causal count-noise diagnosis still holds.
- **Log write condition:** `common.sh:3144–3158` appends `nudges.log` on every `team_nudge` invocation, before
  delivery; `cmd-watch.sh:368–374` invokes it on a permitted running-PM tick. The line is an attempted reminder,
  not confirmed delivery, and queued/held transport outcomes do not remove it. Standby/no-work return earlier.
- **Additional red evidence within scope:** `cmd-watch.sh:334–358` never clears the reminder key/time on emptiness.
  The brief's empty-return promise therefore needs a real rearm step, not only a change to key generation.
- **Boundary maintained:** only the authorized change and own evidence/report paths were changed. Main
  worktree access was limited to the explicitly named read-only thread/brief/script and the required generated
  blocked-notification inbox write. No main/other worker branch switch, no push, no live patrol manipulation and
  no shared tmux probing. PM incident times/configuration are supplied brief evidence, not independently reread
  live logs. Notification disabled tmux (`TEAM_NOTIFY_TMUX=0`, `TMUX`/`TMUX_PANE` unset).
- **Evidence limitations:** the probe sources real text/key/nudge/tick/state/pending-JSON functions, but stubs
  external scans, capacity, death/outbox steps, PM liveness/start and guarded-send. It checks policy attempts,
  not a live model receipt or rendered TUI. CLI observer modes, actual pending-board readers, migration and
  transport integration are explicitly assigned to apply/verify fixtures and the full gate.
- **Sibling delta:** active `meeting-liveness` also modifies the panel status-band block. Its files were not
  changed. The PM must compose both changes before archiving the second, preserving that change's meeting
  scenario and this change's current-count scenario. This is an archive-order coordination risk, not scope
  authorization to edit another change.

## Suggested next steps

- **BLOCKED:** PM coordinate **agent:dev**, the `skills/teamsmith/tests/**` owner, to investigate/fix the existing
  product-tree negative control at `checkout-shape-probe.sh:379–388` and its §31/lint path, then rerun the full
  correctness gate. No cross-directory fix was attempted under this propose brief.

```text
$ env -u TMUX -u TMUX_PANE TEAM_NOTIFY_TMUX=0 bash <home>/Documents/syncthing/Work/Projects/pm-skills/skills/teamsmith/scripts/team notify verify 'BLOCKED: P172 planning artifacts complete, OpenSpec 22/22; full smoke 4200 pass / 1 fail in #36 product-checkout probe. Same bad case reproduced on pre-P172 f07d6c1c (71 pass / 1 fail). PM please route tests/checkout-shape-probe.sh and tmux-lint interaction to owner dev; proposal/report stay local on task/P172-propose.'
✓ notified pm: BLOCKED: P172 planning artifacts complete, OpenSpec 22/22; full smoke 4200 pass / 1 fail in #36 product-checkout probe. Same bad case reproduced on pre-P172 f07d6c1c (71 pass / 1 fail). PM please route tests/checkout-shape-probe.sh and tmux-lint interaction to owner dev; proposal/report stay local on task/P172-propose.
exit 0; durable blocked-notification output retained in logs/blocked-notify.log
```

- PM review `openspec/changes/pulse-nudge-key/` and record ACCEPTED/NEEDS-CHANGES; this report does not mark the
  task done or authorize apply/merge/archive.
- After acceptance, dispatch one developer-owned apply brief; require F1–F4 to turn green while G1–G12 and both
  mutations retain their intended verdicts, then assign independent verification to a different agent.
