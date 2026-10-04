# P3 · dev2 · propose report: change `launch-and-adapter-evidence` (C1)

```
task:   P3                       phase:  propose        deps: E2 accepted (D18), E1 §3.1 (the nine rows)
agent:  dev2                     status: DELIVERED (artifacts + report; no code, no archive)
branch: task/P3-propose-launch-and-adapter-e    PR/MR: -  (local mode, no remote push)
```

Planning artifacts only. Nothing was applied, nothing was archived, `openspec/specs/**` was not touched, and no code,
test, reference or ledger file was written. Scope, boundaries and acceptance come from
`docs/team/tasks/P3-propose-launch-and-adapter-evidence.md`; the design is E2's accepted split (D18).

## Deliverables

| Path | What |
|---|---|
| `openspec/changes/launch-and-adapter-evidence/proposal.md` | why/what/capabilities/impact/boundaries + the acceptance commands verbatim (500 words) |
| `openspec/changes/launch-and-adapter-evidence/specs/dispatch/spec.md` | REMOVED (the engine, with Reason/Migration) + 2 MODIFIED (restated verbatim, one scenario added each) + 2 ADDED |
| `openspec/changes/launch-and-adapter-evidence/specs/agent-adapters/spec.md` | new capability: Purpose + the migrated engine (byte-identical) + first-word resolution + the PM side |
| `openspec/changes/launch-and-adapter-evidence/specs/pm-lifecycle/spec.md` | new capability: Purpose + liveness evidence + the `starting` state + reload semantics |
| `openspec/changes/launch-and-adapter-evidence/design.md` | the move shape, the mechanical restatement, the A2 surface decision, the W2 correction, the three verify layers |
| `openspec/changes/launch-and-adapter-evidence/tasks.md` | one apply brief, ordered `dispatch` → `agent-adapters` → `pm-lifecycle`, with the smoke-free rationale |
| `docs/team/reports/P3-dev2/pkg/run.sh` | the reproducible evidence package of this report (15 checks, read-only, no tmux) |

## Delta inventory (rows → requirements → scenarios → the red that exists today)

`F` = falsifier: the smoke assertion that already fails if the behaviour breaks (`skills/teamsmith/tests/smoke.sh`,
line numbers from this branch's tree).

| row | capability · operation | requirement | scenarios | F |
|---|---|---|---|---|
| D1 | `dispatch` · MODIFIED | One task branch per task | 2 base restated + **A worktree parked on another task's branch is refused** | §6 `F16` (`:448-468`: refused, both branches named, the `git switch` line, no dispatch, resume still allowed) |
| D2 | `dispatch` · MODIFIED | A brief is self-contained and names its evidence | 2 base restated + **A brief outside the project is refused, `--print` included** | §6 `F15` (`:472-481`: refused with `--print`, names the main worktree, not called repo-relative) |
| D3 | `dispatch` · ADDED | A dispatch proves the agent started, or fails loudly | 4 | §6h `B1` (`:1142-1151`), `B4a` (`:1165-1168`), `B2`/`B3` (`:1181-1210`); §6j `M8.2` (`:1711-1737`) |
| D4 | `dispatch` · ADDED | A dispatch refuses a session the model's window cannot hold | 6 | §6h `A1`–`A9` (`:1056-1112`), `400k/272k` in roster/ps |
| A1a | `agent-adapters` · ADDED (migrated) | The adapter template contract is enforced, not guessed | 4 (moved verbatim) | §6f (`:656-935`: `F4`/`F5`/`F6`, unknown placeholder, JSON body not a placeholder), §6g real window (`:940-1015`) |
| A1b | `agent-adapters` · ADDED | The template's first word is resolved, not guessed | 2 | §6j `M8.2：裸名字…绝对路径` / `…已经是绝对路径的首词原样保留` / `…TEAM_AGENT_BIN 指向别的名字时不改模板首词` (`:1648-1660`), real window (`:1693`) |
| A2 | `agent-adapters` · ADDED | The PM is an adapter too | 6 | §6i ①–③b (`:1255-1410`), real window 1)/2b)/6) (`:1420-1618`), §11b2 `①b`/`③` (`-c` + `@pm-prompt.md`, `:2387-2400`, `:2417-2435`) |
| W1 | `pm-lifecycle` · ADDED | PM liveness is proven, not inferred | 6 | §11b2 ①–④b + F30 (`:2356-2490`), F28 state fingerprint (`:2720-2726`) |
| W2 | `pm-lifecycle` · ADDED | A PM that is starting is a state, not a missing PM | 2 | §11b3 (`:2491-2650`: second tick does not kill the PM, one restart recorded, marker withdrawn, stale marker expires) |
| W3 | `pm-lifecycle` · ADDED | A reload request is bookkeeping, not a restart | 2 | §11h `F23` (`:3022-3032`) |

Totals: `dispatch` 6 → 7 requirements, two new capabilities with 3 requirements each; 38 scenario blocks across the
three delta files — 8 carried over unchanged (4 restated inside the `MODIFIED` blocks, 4 migrated) and 30 new.

## Deliberately left out, and why

- **The worker-side "unresolvable first word fails before a window opens" scenario.** The code does fail there
  (`cmd-agents.sh:491`), but no assertion for the *dispatch* path exists today — only `team doctor`'s adapter line is
  asserted (`smoke.sh:799-802`), and doctor is a different promise. Per the brief ("a scenario with no runnable
  falsifier does not ship") the scenario is not written; the requirement also does not claim it, so nothing
  unfalsifiable is left behind. Its PM-side counterpart **is** written, because it has falsifiers (§6i). Adding a
  dispatch-time assertion would be test code — a new row for a later change, not this backfill.
- **`busy` as a PM state.** It does not exist; `team_pm_state()` prints `running/starting/idle/unknown/foreign/missing`
  and the pane-busy probe only separates `idle` from `unknown`. A scenario asserting `busy` would be false (E2 §1.3-2,
  D18). The requirement names the six and says the vocabulary is closed.
- **A general `team up` / `team resume` contract, and a `watchdog` delta.** E2 §2.1's fences: C1 pins liveness and
  `starting`, and the watchdog's pointer to "the PM's calls" stays true after this change.
- **Everything owned by other changes**: `B1–B9`, `N1–N3`, `M1–M2` (C3), `V1–V7` (C2), `G1–G2` (C0).
- **Prose that must not become a scenario** (M7.1, M7.3, M9.1, F22, F20's rationale): E1 §3.3; the gate already
  falsifies the enforceable halves.

## Verification evidence (actually run)

The package `docs/team/reports/P3-dev2/pkg/run.sh` runs all of this in a private `mktemp -d`, read-only on the
repository, no tmux. Its full output on this branch:

```
$ bash docs/team/reports/P3-dev2/pkg/run.sh
ok   openspec validate --all --strict: Totals: 9 passed, 0 failed (9 items)
ok   tree spec-lint: spec-lint: OK — 11 spec file(s), 56 requirement(s), 115 scenario(s) under openspec
ok   C0 delta lint (from task/P2.2-apply-rework-2-close-f-v2-1-): spec-lint: OK — 11 spec file(s), 56 requirement(s), 115 scenario(s) under openspec
ok   scratch archive: Totals: + 8, ~ 2, - 1, → 0
ok   scratch archive touched exactly the three promised capabilities
ok   both new specs carry a real Purpose (no TBD - created by archiving)
ok   archived tree validates: Totals: 10 passed, 0 failed (10 items)
ok   the removed requirement is gone from the archived dispatch spec
ok   migration diff is empty: the engine requirement moved byte-for-byte (31 lines)
ok   restatement of "A brief is self-contained and names its evidence": base text intact, only 7 added line(s)
ok   restatement of "One task branch per task": base text intact, only 8 added line(s)
ok   negative control A: a typo'd MODIFIED name is caught (delta-modified-requirement-missing)
ok   negative control A control: the pre-C0 tree lint really misses it (C1 may not rely on the old gate)
ok   negative control B: a MODIFIED block that drops a base scenario is caught (delta-dropped-scenario)
ok   git status: nothing outside openspec/changes/launch-and-adapter-evidence/** and docs/team/reports/P3-dev2/**

== 结果 ==  ✓ 15  ✗ 0  skip 0
```

Acceptance, verbatim from the brief:

```
$ openspec validate --all --strict
Totals: 9 passed, 0 failed (9 items)
$ bash skills/teamsmith/tests/spec-lint.sh
spec-lint: OK — 11 spec file(s), 56 requirement(s), 115 scenario(s) under openspec
$ git status --porcelain
(clean — every artifact is committed; the only paths this branch adds are the change directory,
docs/team/reports/P3-dev2.md and docs/team/reports/P3-dev2/pkg/run.sh)
$ openspec change show launch-and-adapter-evidence
Warning: The "openspec change ..." commands are deprecated. Prefer verb-first commands …
## Why
Nine shipped launch-and-proof behaviours have no spec …            (the full proposal follows; rc=0)
```

### Gate note: why the full `TEAM_GATES` is red in this tree (pre-existing, not this change)

The tree's `smoke.sh` §16 compares the lint summary against a count taken from `openspec/specs/*/spec.md` only
(`:3620-3624`), while the lint also counts active change deltas. With any active change the two assertions therefore
fail — E2 §7.3 documented this and C0's task 2.3 fixes it (on the C0 branch, not in `main`). Reproduced here, fast
mode, with this change active:

```
$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh
  ✗ lint 报的 requirement 数与真树一致（45）… [45 requirement(s)]
  ✗ lint 报的 scenario 数与真树一致（77）… [77 scenario(s)]
== 结果 ==  ✓ 938  ✗ 2                                        rc=1
```

E2's baseline on this tree with no active change is `✓ 940 ✗ 0`; the only delta is the active change directory, and
the two red labels are exactly the coupling, not a document defect. The brief's acceptance is validate + spec-lint
(no smoke) for precisely this reason; the proposal review should either run with `--no-gates`, or run on a tree where
C0 has landed. Nothing inside this task's boundary can fix it (`skills/teamsmith/tests/**` belongs to agent:dev, and
the brief forbids code and test changes).

The archive probe, on a scratch copy only (the repository's `openspec/` was never written):

```
$ rm -rf /tmp/c1-archive && cp -r openspec /tmp/c1-archive && cd /tmp/c1-archive && openspec archive -y launch-and-adapter-evidence
Proposal warnings in proposal.md (non-blocking):
  ⚠ Consider splitting changes with more than 10 deltas
Task status: 0/17 tasks            <- expected at propose; apply checks them off
Warning: 17 incomplete task(s) found. Continuing due to --yes flag.
Specs to update:
  agent-adapters: create
  dispatch: update
  pm-lifecycle: create
Applying changes to openspec/specs/agent-adapters/spec.md:  + 3 added
Applying changes to openspec/specs/dispatch/spec.md:        + 2 added  ~ 2 modified  - 1 removed
Applying changes to openspec/specs/pm-lifecycle/spec.md:    + 3 added
Totals: + 8, ~ 2, - 1, → 0
```

### Migration diff (layer 2 — the only check that can see a dropped scenario)

```
$ git show HEAD:openspec/specs/dispatch/spec.md          > base;  extract the engine requirement
$ /tmp/c1-archive/openspec/specs/agent-adapters/spec.md  > after; extract the same requirement
$ diff base after
(empty) — 31 lines vs 31 lines, byte-identical: same name, same prose, same four scenarios
```

`MODIFIED` restatements against the archived result (only the appended scenario may differ):

```
$ diff base-brief-block archived-brief-block
18a19,25
> #### Scenario: A brief outside the project is refused, `--print` included
...
$ diff base-branch-block archived-branch-block
18a19,26
> #### Scenario: A worktree parked on another task's branch is refused
...
```

No other spec changed: comparing every archived `openspec/specs/*/spec.md` against `HEAD` prints nothing except
`dispatch` (which is the update this change promises).

## Flip evidence (red → green, on scratch copies; this is not a defect-fix task)

The change is a document backfill, so its honest flips are *the gate's rules really fire on these artifacts* — the
exact check that separates a reviewable proposal from a file that merely validates. The negative controls corrupt the
change on a scratch copy only (`/tmp/p3-neg`), never the branch:

```
$ # A) rename the MODIFIED requirement "One task branch per task" -> "…per tasks"
$ bash /tmp/spec-lint-c0.sh /tmp/p3-neg/openspec          # C0 rules
…/specs/dispatch/spec.md:40: delta-modified-requirement-missing: MODIFIED names a requirement the base spec does not have: One task branch per tasks
spec-lint: FAIL — 1 violation(s)          rc=1
$ bash skills/teamsmith/tests/spec-lint.sh /tmp/p3-neg/openspec   # the tree's pre-C0 lint
spec-lint: OK — 11 spec file(s), …        rc=0     <- the hole C0 closes, reproduced on this change
$ openspec validate --all --strict        # (same fixture) Totals: 9 passed, 0 failed  <- green too

$ # B) drop the base scenario "The prompt points at the brief" from the MODIFIED block
$ bash /tmp/spec-lint-c0.sh /tmp/p3-neg/openspec
…/specs/dispatch/spec.md:14: delta-dropped-scenario: MODIFIED drops base scenario "The prompt points at the brief" of: A brief is self-contained and names its evidence
spec-lint: FAIL — 1 violation(s)          rc=1

$ # restore the change dir on the scratch copy (or rerun the package on the real tree):
$ bash docs/team/reports/P3-dev2/pkg/run.sh
== 结果 ==  ✓ 15  ✗ 0  skip 0             rc=0
```

So the two C0 rules that matter for this change's shape have a demonstrated red **and** a demonstrated green on these
very artifacts, and the pre-C0 gate's silence on the same fixture is recorded rather than assumed.

## Decisions and requests for the PM

1. **A2's observable surface (needs your confirmation).** "The empty keys keep the built-in Pi launch path" is written
   at the observable end: `team up` in a fixture project, then the argv of the process recorded in `state/pm.pid`
   (`<TEAM_PI_BIN> --provider … --model … --skill … -c @state/pm-prompt.md`, no `{`). It names no internal function
   and compares against no test-only string. The named red is `smoke.sh` §11b2 `①b`/`③` (which assert `-c` +
   `@pm-prompt.md` in the fake CLI's argv); the fast net stays §6i's render comparison. If you reject this surface,
   say so in the proposal review and the requirement drops to the custom-CLI half with the byte-identical promise
   kept as prose in `references/agent-adapters.md`.
2. **Base and gate.** This branch is cut from `main`, where C0 has not landed, so the tree's `spec-lint.sh` has no
   delta rules. The C0 lint from `task/P2.2-…` is green on this change, and the two negative controls prove it is
   checking *this* change rather than skipping it. If C0's rules change before your proposal review, the package
   re-runs against the newest C0 branch (`P2.2 > P2.1 > P2 > P1`) automatically.
3. **The pre-C0 smoke coupling** (section above): with this change active the tree's `smoke.sh` §16 is red on its two
   count assertions even though the lint is green. That is C0's task 2.3, already fixed on the C0 branch. If the
   proposal review wants the full gate green on this tree, C0 must land first; otherwise review with `--no-gates`.
4. **`tasks.md` items are unchecked on purpose** (propose phase); `openspec archive` therefore warns "17 incomplete
   tasks" and proceeds under `--yes`. Apply checks them off; if you prefer the archive probe to be warning-free, the
   apply brief can state that each item is checked as it is verified.
5. **No code, no test, no `references/` change.** The one row whose missing failure half would need test code (the
   worker-side unresolvable first word) is named above and left to a later change.

## Suggested next steps

- `docs/team/reviews/launch-and-adapter-evidence-proposal.md` — the proposal review. Suggested points: the A2 surface
  (decision 1), the two restated `MODIFIED` blocks (diff tails above), and the migration diff for the move.
- If ACCEPTED: one apply brief, `dispatch` → `agent-adapters` → `pm-lifecycle`, acceptance = the full gate (not
  `TEAM_SMOKE_FAST`; the fast run skips §6h/§6i/§6j/§11b2/§11b3, which hold most of these rows' falsifiers) plus the
  three verify layers of `design.md`/`tasks.md` 4.3–4.5.
