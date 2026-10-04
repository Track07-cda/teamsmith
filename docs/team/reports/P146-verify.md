# P146 · Product-only checkout gate proposal

agent: verify   status: PROPOSED   time: 2026-10-01T16:50:33Z
branch: `task/P146-propose`   PR/MR: - (local mode, no push)
base: `603a4e8eddc7`   planning commits: `74fbf3d3`, `d507eefa`

## Deliverables

| Path | What |
|---|---|
| `openspec/changes/product-checkout-gate/proposal.md` | Chooses A, states publication/test boundaries and the two required flip directions |
| `openspec/changes/product-checkout-gate/design.md` | Source-checkout predicate, exact prerequisite attribution, subprocess skip accounting, per-section transition table and disposable-container acceptance recipes |
| `openspec/changes/product-checkout-gate/specs/verification/spec.md` | ADDED checkout-prerequisite requirement; MODIFIED selector requirement with all five original scenarios retained verbatim |
| `openspec/changes/product-checkout-gate/tasks.md` | One developer apply slice followed by independent verification; baseline, attribution, negative controls, both shapes and full CI-equivalent runs |
| `docs/team/reports/P146-verify/` | Actual export/selector baseline logs, validation/status logs and planning checks |

## Verification evidence (actually run)

### Strict validation and planning completion

```text
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
✓ change/product-checkout-gate
✓ spec/verification
✓ spec/watchdog
Totals: 18 passed, 0 failed (18 items)
exit 0

$ PATH="$HOME/.bun/bin:$PATH" openspec status --change product-checkout-gate
Progress: 4/4 artifacts complete
[x] proposal
[x] specs
[x] design
[x] tasks
All planning artifacts complete!
exit 0

$ git diff --check
exit 0
```

Validation ran through `team_bg_run`, and its job was harvested. The CLI was not initially on PATH; prepending the existing `~/.bun/bin` fixed lookup without installing or modifying anything.

### Pure-file reproduction, no tmux or smoke execution

The actual probe sequence, with temporary export removed by its EXIT trap:

```bash
mkdir -p docs/team/reports/P146-verify
 tmp=$(mktemp -d "${TMPDIR:-/tmp}/teamsmith-p146-probe.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
bash docs/team/tools/publish-public.sh --out "$tmp/public" >docs/team/reports/P146-verify/export.log 2>&1
export_rc=$?
printf 'export exit=%s\n' "$export_rc"
if [ "$export_rc" = 0 ]; then
  bash "$tmp/public/skills/teamsmith/tests/section-select.sh" --check >docs/team/reports/P146-verify/public-selector-before.log 2>&1
  printf 'public selector exit=%s\n' "$?"
fi
bash skills/teamsmith/tests/section-select.sh --check >docs/team/reports/P146-verify/internal-selector-before.log 2>&1
printf 'internal selector exit=%s\n' "$?"
```

Actual outcomes:

```text
export exit=0
public selector exit=1
internal selector exit=0

Export: rev 603a4e8eddc7, 222 files, 6.8M, version 1.42.0
Leak scan: all eight forbidden shapes had zero hits

Public selector:
bad: 行 2 的字面模式在工作树里不存在：AGENTS.md
bad: 行 17 的字面模式在工作树里不存在：SCOPE.md
bad: 行 18 的字面模式在工作树里不存在：SCOPE.md
bad: 行 19 的字面模式在工作树里不存在：.pi/skills
bad: 行 20 的字面模式在工作树里不存在：openspec/changes/archive
bad: 行 12k 的字面模式在工作树里不存在：AGENTS.md
== 选段自检 ==  ok 6  bad 6

Internal selector:
ok: 字面模式全部存在于工作树（481 条）
== 选段自检 ==  ok 7  bad 0
```

Both selectors still checked all 115 section rows, 101 needs edges and real product-token coverage. The six missing literal hits are four distinct deliberately unexported paths, not `docs/team/**` paths; the latter already belong to the selector's exempt class.

### Planning consistency checks

A Python check compared the complete baseline scenario blocks of the MODIFIED requirement with the delta, checked the new ADDED heading did not already exist in the base, counted proposal words, and fed every bash code block in proposal/design to `bash -n` (syntax only). Its real output is in `planning-checks.log`:

```text
MODIFIED baseline scenario preservation: 5/5 exact blocks retained
ADDED anchor already exists in base: False
proposal words: 414 (<500)
proposal.md : 1 bash command blocks parse; NOT executed by this check
design.md : 6 bash command blocks parse; NOT executed by this check
Planning-only invariant checks: PASS
```

- Verdict: planning validation PASS; product fix NOT IMPLEMENTED.
- Not run: smoke FAST/full, release-check with gates, container builds, post-fix flips or remote CI. They are implementation/independent-verification acceptance steps, not this propose task's gate. No tmux server/window was inspected or operated and no remote state changed.

## Flip evidence

**Actual red baseline:** the public selector exited 1 with the six named missing-literal failures above, while the same selector in the internal tree exited 0. This is evidence for the prerequisite mismatch, not red-before → green-after proof of a delivered fix.

**Planned implementation flips:** design.md's What flips section requires restoring the old public attribution to make §18/§19/§36 red again, and forcing an old internal assertion to skip so the inventory/per-section coverage guard turns red. It also requires product-literal/CJK/table-corruption controls to remain red despite coexisting skips, partial-tree deletions to stay red, and restoration runs with saved exits/tails. None of these post-fix claims is made by P146.

## Decisions and deviations

- **A selected:** retain the public allowlist and `.pi` ban. B would require exceptions in both the exporter and release checks while still needing A for other internal prerequisites; it adds published scaffolding but no extra product-behavior coverage.
- **No blanket skips:** recognize only the all-internal-surfaces-absent source shape, attribute individual internal existence checks, and preserve every product assertion/fixture. Mixed/empty/broken internal surfaces stay strict.
- **Brief discrepancy recorded, not guessed away:** the supplied failure rows sum to fourteen, not sixteen. The source puts phase checks in §19, not §18. A fresh apply baseline must reconcile all failure labels; unknown failures cannot be added to the skip allowlist without evidence.
- **Anchor:** the brief's `A gate that cannot judge says so` heading is not yet in the base capability. The delta adds it; the existing selector literal-existence behavior is correctly MODIFIED, not duplicated.
- **Counts:** the PM's ✓3141 ✗16 / ✓3156 ✗0 totals are cited as PM evidence, not as runs performed by this agent. The proposal requires old-assertion inventory preservation and per-section pass counts not decreasing, rather than a brittle absolute total that new tests could conceal.
- **Scope/local mode:** only the explicitly granted change and this agent's report/evidence were written; no implementation, task brief, shared ledger or main-worktree edits. Branch is left local for PM review, without push/merge/archive.

## Suggested next steps

PM reviews `openspec/changes/product-checkout-gate/` and records ACCEPTED before creating an apply brief for a different developer with an explicit test-source grant. Collect the complete two-shape baseline first; after apply, dispatch independent verification of every delta scenario and both mutation directions. This proposal is ready for review, not authorization to publish or archive.
