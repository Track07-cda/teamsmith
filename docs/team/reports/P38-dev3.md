# P38 · dispatch-verify-seat-guard — propose package (a fifth dispatch guard: the verify seat never gets implementation work)

agent: dev3   status: DONE   time: 2026-09-22T08:05:46Z
branch: `task/P38-dispatch-apply-verify-propos`   PR/MR: - (local mode: no push)

## Deliverables

| Path | What |
|---|---|
| `openspec/changes/dispatch-verify-seat-guard/proposal.md` | why / what changes / capabilities / impact / acceptance / flips / boundaries / report evidence (496 words, under the 500 limit) |
| `openspec/changes/dispatch-verify-seat-guard/specs/dispatch/spec.md` | **ADDED** — a verification seat is never dispatched implementation work (refusal before any window, `--print`, `--force` audit, conservative `grant:` classification; 6 scenarios) |
| `openspec/changes/dispatch-verify-seat-guard/specs/verification/spec.md` | **ADDED** — the verification seat's independence includes not implementing (seat identity via `TEAM_VERIFY_SEAT`, the `OWNERSHIP.md` row, allowed ledger/recon work; 3 scenarios) |
| `openspec/changes/dispatch-verify-seat-guard/design.md` | the D36 evidence and the six adjudications (seat identity, trigger predicate, grant classification, ADDED-vs-MODIFIED, guard placement, template/config surface), risks, migration, one deferrable open question |
| `openspec/changes/dispatch-verify-seat-guard/tasks.md` | one apply plan: coverage map, path grants (PM-owned + `agent:dev`), fixture note (P24 family reuse), 15 verifiable items in four groups |

2 requirements / 9 scenarios (brief budget: 1–2 requirements, 5–10 scenarios). Planning only: no implementation
path (`scripts/**`, `references/**`, `templates/**`, `tests/**`, `AGENTS.md`, `docs/team/OWNERSHIP.md`) was touched
by this task.

## Verification evidence (must have actually been run)

```
$ PATH="$HOME/.bun/bin:$PATH" openspec validate dispatch-verify-seat-guard --strict
Change 'dispatch-verify-seat-guard' is valid          # rc=0

$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
✓ spec/agent-adapters … ✓ spec/verification … ✓ spec/watchdog
Totals: 18 passed, 0 failed (18 items)                # rc=0

$ openspec status --change dispatch-verify-seat-guard
Progress: 4/4 artifacts complete
[x] proposal  [x] specs  [x] design  [x] tasks
All planning artifacts complete!

$ rm -rf /tmp/dvsg-trial && mkdir -p /tmp/dvsg-trial && cp -r openspec /tmp/dvsg-trial/openspec
$ (cd /tmp/dvsg-trial && openspec archive -y dispatch-verify-seat-guard)
Applying changes to openspec/specs/dispatch/spec.md:
  + 1 added
Applying changes to openspec/specs/verification/spec.md:
  + 1 added
Totals: + 2, ~ 0, - 0, → 0
Specs updated successfully.
Change 'dispatch-verify-seat-guard' archived as '2026-09-22-dispatch-verify-seat-guard'.

$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
… == 12k · 模板与文档（P24/B7） == … ✓ 7.4 repo AGENTS.md 与模板逐字一致（模板是源）
… == 35 · 门禁只判正确性 … ✓ 35 守卫：门禁无性能判定标记 …
== 结果 ==  ✓ 2302  ✗ 0
FAST 模式：跳过 27 个真进程段落（1c·M11 真沙盒窗口|…|12h·--force 审计落盘|38-b·panel-p21-choices）
smoke 全绿
EXIT=0
```

- Verdict: **pass** — every command above really ran on this branch's tree (commit `d35b339`); the trial archive
  ran in a throwaway `/tmp` copy, the repo's own `openspec/` was never archived. The FAST smoke job is
  `p38-fast-smoke` (exit 0 after 485.6 s), full output
  `.pi/team/state/bg/p38-fast-smoke.log`.
- Notes (be explicit): FAST mode skipped 27 real-process sections by design (the run prints them); this task
  changes no implementation path (`git diff --name-only 042ae49..d35b339` is `openspec/changes/…/**` only), so the
  full gate is not owed by the propose phase — the apply brief's item 4.2 runs it once before delivery.
- `git status --porcelain` → empty at the tip before this report was added; the report is the only file added
  afterwards, committed on the same branch.

## Falsifiability evidence (the red side exists today — measured, not promised)

The guard does not exist on this tree, so the refusal scenarios describe behaviour that is genuinely absent:

```
$ grep -c 'team_dispatch_seat_guard\|TEAM_VERIFY_SEAT' \
    skills/teamsmith/scripts/lib/cmd-agents.sh skills/teamsmith/scripts/lib/common.sh skills/teamsmith/scripts/lib/cmd-config.sh
skills/teamsmith/scripts/lib/cmd-agents.sh:0
skills/teamsmith/scripts/lib/common.sh:0
skills/teamsmith/scripts/lib/cmd-config.sh:0

$ grep -n 'four dispatch guards' skills/teamsmith/references/protocol.md
89:## 5b. The change is the assignment unit (four dispatch guards)

$ grep -c '^grant:' skills/teamsmith/templates/task.md.tmpl
0                       # the field the guard reads is not rendered by the template today
```

The defect happened for real (D36): P36's brief is `agent: verify` + `phase: apply`, and the seat's report is a
`BLOCKED` record quoting `OWNERSHIP.md` line 27 (`verify` 席位例外：**无论任务书怎么写，都不改实现**);

```
$ head -3 docs/team/reports/P36-verify.md
# P36 · PM 会话交接（…）— PARTIAL / BLOCKED
agent: verify   status: BLOCKED   time: 2026-09-22T06:56Z
# BLOCKED：任务书把实现路径授予 `agent: verify`，而 OWNERSHIP 明文禁止 verify 席位改实现
```

and M53 is the same mistake one task earlier (`b0e7645 docs(team): M53's board row names its implementer (dev2),
not the verify seat`).

Why the verification delta is ADDED and not a MODIFIED "one sentence next to the author rule" (the brief's item 3):
the author rule is **not in the base spec yet** — it lives in the unarchived `change-centric-discipline` delta, and
`openspec validate` does not compare MODIFIED headers against the base while the trial archive does:

```
$ grep -n '^### Requirement:' openspec/specs/verification/spec.md | wc -l
12                      # lines 9…312; none of them is the author rule
$ grep -n '^### Requirement: The verifier' \
    openspec/changes/change-centric-discipline/specs/verification/spec.md
3:### Requirement: The verifier of a change is not one of its authors   # a pending delta, not a base spec
```

Fixture grounding for the apply plan (both reused, nothing invented):

```
$ grep -n '^section "12[g-k]' skills/teamsmith/tests/smoke.sh
10943:section "12g · 派单锚点（P24/B3：…）"   … 11180:section "12k · 模板与文档（P24/B7）"
$ grep -c '^section "12l' skills/teamsmith/tests/smoke.sh
0                       # the new section's number is free
```

## Flip evidence (propose-only task: no implementation flip exists here)

This task writes no code, so there is no red→green pair to paste. The flip the **apply** owes is written into
`tasks.md` item 2.4 and named in the proposal's "What flips": drop the `team_dispatch_seat_guard` call (or its
`phase: apply` check) → the new 12l apply fixture goes red and a tmux window is requested where the fixture expects
none; restore → green; the `phase: verify` and ledger-only cases stay green through both revisions so the fixture
separates "refuses implementation" from "refuses everything". The propose-side red side above (guard absent,
`grep = 0`; two real accidents) is what the change closes.

## Decisions and deviations

1. **ADDED, not MODIFIED, for the "role boundary next to the author rule" sentence** (deviation from a literal
   reading of the brief's item 3): a MODIFIED naming `The verifier of a change is not one of its authors` would
   pass `validate` and fail the trial archive, because that requirement is still in the unarchived
   `change-centric-discipline` delta (evidence above). The boundary is its own ADDED requirement; archive order
   between the two changes cannot break either (design §4, R5).
2. **Seat identity is a config key** (`TEAM_VERIFY_SEAT`, default `verify`) rather than a code literal: renaming a
   seat must not silently drop the guard, and the premise stays visible in `team config list`. Unset/empty resolve
   to `verify`, so blanking cannot switch it off. Alternatives and the deferred seat-list option: design §1.
3. **`grant:` classification is conservative** — implementation unless it is `docs/team`/`openspec` (or under
   them) — instead of the brief's sketch of an implementation whitelist (`skills/**`, `scripts/**`,
   `extension/**`): real briefs write skill-relative paths (M53: `extension/team-inbox-watch.ts ·
   scripts/lib/… · tests/smoke.sh`), which the whitelist would silently miss. False positives are visible (the
   entries are printed) and one audited `--force` away. Design §3.
4. **Beyond the brief's two doc files**: the template gains the `grant:` line (the guard reads a field the
   template did not declare), and the AGENTS/PROTOCOL paragraphs are synced with the repo `AGENTS.md` paragraph
   (smoke §12k asserts they stay byte-identical). Both are task items with their own verification; the PM may cut
   them at proposal review if the change must stay smaller.
5. **The config key is registered** (schema row, `references/config.md`, template) rather than read as an
   undocumented environment variable, so `team config set/list` work and no hidden knob is introduced.
6. No `BLOCKED:` items; every dependency the brief named (OWNERSHIP, M53, P36) is resolved in-tree.

## Notes / risks left to the reviewer

- Residual gaps recorded on purpose, not hidden (design Risks): an undeclared phase with no `grant:` line is not
  refused (no signal to judge), and `phase: verify` with an implementation grant proceeds (the declared phase wins
  per the user's adjudication). Both are candidates for a later tightening; neither widens the change.
- The new fixture section runs in fast and slow mode alike (pure logic); the `--force` audit item uses the
  record-only tmux shim the P24 family already provides, so no real window is needed.

## Suggested next steps

- PM proposal review per `references/openspec.md` §4 (ten-point checklist) →
  `docs/team/reviews/dispatch-verify-seat-guard-proposal.md`; then one apply brief (the tasks.md path grants include
  the PM-owned files and note `skills/teamsmith/tests/**` belongs to `agent:dev`).
- The apply's gate item 4.1 re-proves the archive safety on the applied tree (a /tmp copy, never the repo).
- Deferrable open question (no task impact): should `team doctor` report a `TEAM_VERIFY_SEAT` that is not a roster
  member?
