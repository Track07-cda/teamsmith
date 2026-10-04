# M52 · fast-wake degradation proposal

agent: verify   status: DONE (proposal; pending PM proposal review)   time: 2026-09-21T03:43:58Z
branch: `task/M52-inotify-propose`   PR/MR: -（local 模式：不 push；分支留在 `.worktrees/verify`，PM 独立复验后本地合并）
change: `watch-degradation`（phase: propose）

## Deliverables

| Path | What |
|---|---|
| `openspec/changes/watch-degradation/proposal.md` | 437-word proposal: durable degradation record, polling proof, operational visibility, panel distinction, no host quota mutation. |
| `openspec/changes/watch-degradation/design.md` | implementation boundaries, record/read/probe model, fixture isolation and adversarial verification plan. |
| `openspec/changes/watch-degradation/specs/{notify-and-inbox,watchdog,panel}/spec.md` | six ADDED requirements with scenarios, all inside the task header's three authorized delta capabilities. |
| `openspec/changes/watch-degradation/tasks.md` | two-brief apply split, ownership grants, requirement/scenario coverage and F-A…F-E flip plan. |

Commits: `8a4d6c8` (proposal + initial deltas), `8ef4abf` (design + tasks), `f39e8da` (scope/fixture/quota review corrections).

## Review findings resolved before delivery

1. The initial fourth `verification` delta violated M52's explicit three-delta header. R6 now belongs to the
   inbox-watch harness contract in `notify-and-inbox`; `specs/verification/spec.md` was removed. `delivery-guard`
   remains unchanged because `.reg` remains the routing proof and the new `.degraded` file is reporting-only.
2. The planned forced-fixture command could not work because the harness clears inherited `TEAM_*`; furthermore an
   actual preflight would remain healthy while a later forced session failed. The design now snapshots a fixed
   allowlist, clears identity, restores only fixture controls, and explicitly models forced preflight as
   `forced=1`. Thus `S2` can visibly SKIP while forced polling `S22/S23` still prove delivery.
3. A container can enumerate a small but incomplete `/proc` view. Requirements/tasks now emit `watches=unknown/<max>`
   unless a complete same-UID scope can be established; the one-shot registration probe is the verdict.
4. The proposal was reduced from 724 to 437 words, below the required 500.

## Verification evidence (actually run on `f39e8da`)

```text
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
Totals: 17 passed, 0 failed (17 items)

$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
# first run at 03:34Z, while the host's inotify capacity was unavailable:
== 结果 ==  ✓ 2166  ✗ 6
# all six reds were 12b-pi assertions after 31 `fs.watch`-dependent S2…S21 failures.

# rerun at 03:37Z after capacity recovered (no tree change between the two runs):
== 结果 ==  ✓ 2172  ✗ 0
smoke 全绿

$ "$HOME/.bun/bin/bun" skills/teamsmith/tests/team-inbox-watch-harness.mjs \
    skills/teamsmith/extension/team-inbox-watch.ts || true
TEAM-IW-CASE PASS S2 a new spool line wakes the session (fs.watch, polling disabled) :: messages=1
TEAM-IW-CASE PASS S2 wake is a custom team-inbox message with triggerTurn+followUp :: {"customType":"team-inbox","triggerTurn":true,"deliverAs":"followUp"}
TEAM-IW-HARNESS OK

$ cp -R openspec "$trial/openspec" && (cd "$trial" && openspec archive -y watch-degradation)
Specs to update:
  notify-and-inbox: update
  panel: update
  watchdog: update
Totals: + 6, ~ 0, - 0, → 0
Change 'watch-degradation' archived as '2026-09-21-watch-degradation'
```

The first FAST run is retained as the dry-host reproduction, not a claimed green. The second is the required green
acceptance result. The direct harness used the brief's literal `|| true` command but its own final line is `OK`.

## Flip evidence

Not applicable to this **propose** task: no implementation/test guard was changed. The apply plan requires five
reproducible red → restore-green pairs: F-A missing ledger fields, F-B removed poll timer, F-C false healthy reader,
F-D hard-coded probe `ok`, and F-E premise/strict false green. Those are mandatory report evidence for the apply
brief, not claims made here.

## Scope and hand-off

Only `openspec/changes/watch-degradation/**` and this agent-owned report were changed. No implementation, PM-owned
reference/script path, test path, main branch, remote, tmux session, or host inotify setting was touched. The proposal
is ready for the PM's required review; no apply brief may be dispatched until that review is `ACCEPTED`.
