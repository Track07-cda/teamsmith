# Design

## Context

See `proposal.md` for the selected scope. Source baseline is `91e48135`; the relevant routes/renderer/manifest code is unchanged from the accepted exploration's `03b7b01e` baseline.

`tests/routes.sh` currently has these boundaries (paths in this design are relative to `skills/teamsmith/`):

- `mr_write_parser` and `mr_page_usage` interpret usage and continuation lines; the same generated awk also interprets manifest claims.
- `mr_walk_a` checks dispatcher/manifest coverage and manifest claims, renders pages through `mr_pages`, judges their contents/levels, and then runs every manifest CLI claim in a fixture. Page failures do not prevent the subsequent claim loop from running.
- `mr_flips` controls ④ and ⑪ damage `scripts/lib/cmd-help.sh`; ⑬ removes all group rows from `scripts/strings/commands.tsv`. Each then calls `mr_flip_run "$s" walk`.
- `smoke.sh`'s `51` executes `walk control promises refusals`; `51m` executes `flips` under the existing meta selection. No selection policy changes are needed.

The normative obligations are the two MODIFIED blocks in `specs/dispatch/spec.md` and `specs/verification/spec.md`. This document describes their implementation and verification, not a second requirement inventory.

## Goals / Non-Goals

**Goals:** use the original judgement for real and file inputs, actually retire three complete executions, and make the changed evidence/counts auditable.

**Non-goals:** a general route-control selector, fake CLI parser, new test framework, clock abstraction, CI/sharding change, copy-tool optimization, or extending the change to `36`, `61b` or any Pi/tmux/process/window test. The remaining route controls and the complete `51` product path keep their current scope.

## Decisions

### 1. Extract the judgement; do not recreate it

Introduce `tests/lib/routes-pages.sh` as test-only shared code. Move the existing awk generator, page-usage continuation handling and the page-content/level portion of `mr_walk_a` into it, rather than leaving the original code alongside a rewritten fast checker. Manifest claim parsing continues to use that same awk. Existing dispatcher-table extraction and true CLI probing stay in `routes.sh`.

The file-facing boundary has two operations, not an optional flag to weaken the complete walk:

| Operation | Inputs | Result and use |
|---|---|---|
| Judge one page | manifest file; existing extracted command/subcommand tables; page kind/label; actual page file; test-owned output/state | Entire original menu/group/command branch, header and multiset comparisons, parser attribution, page/entry/claim/level state, `ok`/`finding` calls and return status. `finding` increments the executing harness's `FIND`; it is not left to a caller interpreting text or a return code. Missing/empty input emits the existing missing-page finding and does not register a page read. |
| Finish level judgement | state of the nonempty pages actually opened by the page judgement | Existing menu/group/command presence judgement, named missing-level `finding`/`FIND` and return status. The real walk always finishes after enumeration; ⑬ uses this same operation over its file inputs. |

A single-page experiment does not pretend to cover three levels: it calls the per-page operation only. The file-level ⑬ case and the full real walk call the level operation after reading their page inputs. Neither may set level presence from planned jobs or manifest rows alone.

Preserve the original `sort` multiset semantics, not `sort -u`; the awk command/subcommand and column-zero rules; continuation/description handling; header detection; error attribution; and actual entry/claim/page accounting. Do not replace the set comparison with a search for the special literal `ghost-probe`. Moving code must not convert a finding into a bare return code that the outer `FIND` accounting ignores.

The shared code may perform local file/text processing but does not invoke `team`, initialize projects, invoke Pi/tmux, sleep or consult the clock. Callers own rendering, scratch setup and cleanup. The operations call the existing harness's `ok`/`finding` directly, with no second verdict/accounting adapter. In the real walk they execute in the current shell, not command substitution or a piped subshell that loses `FIND`. A negative case runs the same operations in an isolated child with its own counters, captures its status and finding records, and interprets that expected failure in the outer sample counter; a normal child must exit 0 with `FIND=0`. Expected negative findings must not contaminate the sample's own failure total. There is no second product manifest or new product switch.

**Alternative rejected:** hand-written expected parser output plus another awk for file cases. It could pass while the real walk still skipped the defect.

### 2. Keep the true walk connected to the same implementation

The real `mr_walk_a` retains this order:

```text
real manifest + dispatcher tables
  → manifest coverage and claims parsed by the shared awk
  → mr_pages: real menu / every real group / every real command
  → shared per-page judgement over each actual file
  → shared level judgement over those nonempty read records
  → original fixture initialization and every real CLI claim
  → original finding-based exit and coverage summary
```

The walk's page loop has one shared page-judgement call site and one shared level-finish call site; both preserve failure propagation to `failed=1`. Their shared operations themselves emit findings and update `FIND`, because the script's final exit is based on `FIND`, not `mr_walk_a`'s return code. Review these two call sites and the same-shell counter state explicitly. A normal real-walk run cannot prove their damaged-input behavior; this sample does not claim a cheap test of that residual wiring.

The page/command/usage/CLI-claim inventory is compared with a pre-extraction run under identical settings. Paths and incidental fixture identifiers can differ; page labels, claim identities, verdicts and counts cannot be replaced by a comparison of aggregate PASS alone. The other `walk control promises refusals` functions are not shortened.

**Alternative rejected:** replacing only the fast cases, leaving the old inline page checker in `mr_walk_a`. That creates two versions of the rule and does not prove the file cases exercise the real judgement.

### 3. Same-script sample section for gate and acceptance

Add only the explicit `pages` section to `tests/routes.sh`; its case function uses that script's existing identity cleanup, owned root, recording shim, counters, trap and scratch/landing helpers. Do not create `tests/routes-pages.sh`, source the top-level script as a library, or copy/move its environment scaffold. Keep the default section set and FAST/meta selection unchanged.

When non-FAST `mr_flips` runs, it unconditionally invokes `env -u TMUX -u TMUX_PANE TEAM_ROUTES_NESTED=1 TEAM_ROUTES_TREE="$tree" bash "$here/routes.sh" pages` once, using the existing nested-run log/root discipline. The nested marker suppresses only recursive `flips`, never explicit `pages`. Missing helper/command or a failed child becomes a finding, never an existence-based skip. Check child rc=0 and at least three distinct successful case-result lines `替代④`, `替代⑪`, `替代⑬`; text in an expected-failure log is not a successful case-result line. The sample itself exits nonzero if any named result is absent or failed. Its raw case inventory and `✓/✗` summary stay available in its disk log. Acceptance runs the identical `routes.sh pages` entry, not parallel case code. The unconditional parent call is source-reviewed; acceptance does not run the full `mr_flips` matrix.

| Old control and deletion | Shared finding required from the replacement | Real operation retained |
|---|---|---|
| ④ `flip-unattributable`: delete its complete `mr_flip_run "$s" walk` | A finding record from parser attribution contains `列 0 的行`, `无法归属` and the injected `board add <ID> [--allow-dup]` line. Print successful `替代④` only if this and the no-finding normal result hold. | Preserve the original insertion/landing proof; render damaged `help board` once and normal `help board` once. Both rc=0 and nonempty; normal comes from the unmutated tree. |
| ⑪ `flip-page-ghost`: delete its complete `mr_flip_run "$s" walk` | One multiset-difference finding record contains `dispatch`, `页与清单不一致`, `页上多出` and complete `dispatch --ghost-probe`. A special-literal finding alone is insufficient. Print successful `替代⑪` only with this and the no-finding normal result. | Preserve the original insertion/landing proof; render damaged `help dispatch` once and normal `help dispatch` once. Both rc=0 and nonempty; normal comes from the unmutated tree. |
| ⑬ `flip-level-unread`: delete its full skill copy, manifest mutation and nested `walk` | Valid menu and command files each pass the shared page judgement without findings. With no group read record, level finish emits exactly one finding, `group 这一级一条都没被判到`; restoring a valid group file/read record gives no findings. Print successful `替代⑬`. | No renderer in this control. Real manifest → enumeration → actual read wiring stays in `51`. |

“Two single-page experiments” includes two damaged calls **and two normal controls**, four successful nonempty help outputs. Small attribution/continuation and extra/missing/duplicate multiset inputs live inline in the same test section, not a golden production manifest. Menu, group and command comparisons all use the same shared operation. A planned group is never registered as read; a separately supplied empty-file input must emit the original `帮助面缺一页` finding and not set level presence. That missing-page check must not substitute for ⑬'s principal witness, whose only finding is missing group. Bad/good pairs differ only in the intended fault. Missing anchors, copy failures, syntax/load errors, renderer nonzero/timeout or empty renderer output are setup failures, not fulfilled content controls.

Run the renderers from the test-owned disk root with inherited project/seat identity removed, no live pane identity, `/dev/null` input, and bounded commands. Reuse the existing owned-temp-root lifecycle and cleanup; no real project `init`, no real Pi or tmux server is needed. Do not redirect an unknown error into success or expand unrelated fixture cleanup.

**Alternatives rejected:** keeping the three old walks as a nightly/release fallback (no retirement), running the new controls in addition to them (more cost), or replacing damaged real renderer output with edited text files only (lost interface evidence).

### 4. Assertion identities and counts: narrow, explicit replacement

The `verification` delta is necessary because its current rule forbids any replacement under an identical-settings inventory/count comparison. The exception covers only the complete nested executions belonging to these three page controls, not all of `51m`, not any real `51` assertion and not future deterministic migrations.

The counted objects are routes' own `✓/✗` totals and named case-result inventory, not smoke's section total: smoke counts the entire successful `51m` child as one pass (or one skip). FAST/default smoke does not execute `51m`'s cases and produces no sample replacement evidence. Explicit non-FAST `routes.sh pages` supplies the candidate evidence; unchanged real-walk evidence comes separately from the identical normal product command before/after extraction.

Separate these accounting scopes; never add their totals together:

1. Old parent controls: at baseline `routes.sh:1779`, `1923`, `1942`, ④/⑪/⑬ each has one parent `ok`; nested walk `✓` lines are log output, not increments to that parent's `PASS`. Cite source for all three; explicitly label ④/⑬ **source-attributed, not rerun**. Retain the existing non-FAST `51m` record (18 passes/1 visible skip; P428 §1's L308), without deriving per-arm timings from it.
2. Old observed content: manually reproduce only ⑪ once by copying the pristine skill trees, applying the original renderer mutation and running the unchanged `routes.sh walk`. Keep rc and the set-difference finding naming the page and complete extra usage. No test-source edit, baseline-only test copy, selector or review of modified baseline bodies is allowed. The future recipe below is not executed in this proposal.
3. Candidate: keep the actual `routes.sh pages` per-case outcomes, including successful `替代④/⑪/⑬`, and its real `✓/✗` total. If a non-FAST `flips` total is otherwise available, report it separately; do not require a full matrix to obtain one. Parent integration assertions and child case counts are distinct, not a sum or a replay of retired nested-walk lines.

After extraction, compare the same normal product path's page/CLI labels, verdicts and counts with baseline. Map each old parent identity and its source/observed provenance to the new named content and normal results. Unchanged controls are checked by source diff and retained inventory, not a fresh full mutation matrix. A missing retained assertion or real CLI probe cannot be excused by a higher candidate sample total. No old three-arm elapsed total is available under this plan.

This mapping is delivery evidence, not a second golden table in the product and not a new permanent inventory guard. Its authority and allowed count changes live only in the MODIFIED verification requirement.

### 5. Integration stays in existing sections

Register the shared helper under existing `51` and `51m` patterns in `tests/section-paths.tsv`; the same-script cases are already covered by the routes path. Keep section keys, meta classification, dependencies, FAST/full behavior and CI invocation unchanged. Existing `51m` calls `routes.sh flips`, which unconditionally reaches `pages` once when flips executes; `pages` is an explicit local section, not an additional smoke section or default selection.

Update only routes.sh's own stale header/usage description for this new section and the mixed renderer/file controls. Do not expand smoke's log filter or fix the existing stale mutation-count descriptions in smoke/section-paths. No `smoke.sh` change is planned. Keep the short command's raw case log because smoke's one-line outcome is not the sample's assertion inventory.

## Verification and migration plan

### Proposal stage (run now, no product execution)

```bash
export PATH="$HOME/.bun/bin:$PATH" OPENSPEC_TELEMETRY=0
openspec validate --all
bash skills/teamsmith/tests/spec-refs.sh --check
bash skills/teamsmith/tests/section-select.sh --check
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check
```

The PATH prefix selects the installed OpenSpec 1.16.0 without installation or configuration changes. Current long-requirement warnings are pre-existing; do not rewrite unrelated requirements or claim strict validation for a non-strict run.

### Apply/independent verification stage (future, not executed by this proposal)

After proposal acceptance, a different implementer can complete this sample in one Apply brief. First retain the old source identities/counts and historical record described in §4. Reproduce only old ⑪ once **before editing any test source**, in the fixed gate image with an owned bind-mounted disk root. The following future recipe copies trees and mutates only the original renderer; it neither edits tests nor introduces a baseline selector:

```bash
set -euo pipefail
base="$(mktemp -d -p /var/tmp route-pages-before.XXXXXX)"
mkdir -p "$base/tree/skills" "$base/logs" "$base/tmp"
cp -a skills/teamsmith skills/teamsmith-init "$base/tree/skills/"
python3 - "$base/tree/skills/teamsmith/scripts/lib/cmd-help.sh" <<'PY'
import pathlib, sys
p = pathlib.Path(sys.argv[1])
s = p.read_text()
old = '  local plain="${_TH_USAGE[$i]// ;; /;;;}"'
new = old + '\n  [ "$name" != "dispatch" ] || team_help_flow 2 4 "dispatch --ghost-probe"'
assert s.count(old) == 1 and new not in s
p.write_text(s.replace(old, new, 1))
PY
cmp skills/teamsmith/tests/routes.sh "$base/tree/skills/teamsmith/tests/routes.sh"
if (cd "$base/tree" && env -u TMUX -u TMUX_PANE -u TEAM_ROUTES_FAST -u TEAM_SMOKE_FAST \
    TMPDIR="$base/tmp" TEAM_ROUTES_TREE="$base/tree" \
    bash skills/teamsmith/tests/routes.sh walk) >"$base/logs/old-11.log" 2>&1; then
  old11_rc=0
else
  old11_rc=$?
fi
test "$old11_rc" -eq 1
grep -F 'dispatch 的页与清单不一致（页上多出：' "$base/logs/old-11.log" > "$base/logs/old-11-difference.log"
grep -F 'dispatch --ghost-probe' "$base/logs/old-11-difference.log"
```

Preserve this renderer mutation's original landing evidence and record the actual rc/command/log; a missing diagnostic or setup failure is not a baseline success. Use `/var/tmp` backed by the evidence bind mount inside the gate image; collect logs before deleting only this owned root. Do not rerun old ④/⑬ or create a modified baseline test file.

The candidate's planned commands are:

```bash
bash -n skills/teamsmith/tests/routes.sh
bash -n skills/teamsmith/tests/lib/routes-pages.sh
# non-FAST environment; explicit pages is the identical entry called by mr_flips
bash skills/teamsmith/tests/routes.sh pages
```

The last command emits the named file/renderer cases and actual counts, and fails on setup error, missing named cases or unmet diagnosis/normal results. Trace this same invocation; do not run the full flips matrix to test its entry. The parent call is reviewed as stated in §3.

In independent scratch copies, (a) silently skip the shared column-zero attribution failure, and (b) remove the command-page multiset-difference finding while retaining the special-literal check. Run the same `pages` command: (a) must fail `替代④`; (b) must fail `替代⑪` specifically for the missing multiset-difference diagnosis, even if `ghost-probe` still produces a different finding. Normal inputs must still pass without findings; restoring shared code returns the sample to green. These are judgement mutations, not syntax/load/renderer failures. Record exact changes and commands; no fictional `--break` option is introduced.

Run the unchanged normal product entry once before and once after extraction with identical tools/settings and disk logs:

```bash
bash skills/teamsmith/tests/routes.sh walk control promises refusals
```

Use the existing recording tmux containment and identity cleanup. This is a real CLI integration check, not a pure-file claim. No full smoke, `meta-suite.sh`, full `51m`/`flips` matrix, `36` or `61b` run is part of this sample's acceptance.

Deletion evidence is a review plus an execution receipt, not a new guard:

- Diff the three old arm bodies and follow the new case runner/helper calls. Confirm all three old complete walks are gone, ⑬'s scratch/manifest patch is gone, and no wrapper, alternate entry, schedule or fast/full branch retains them. Do not globally ban `mr_flip_run ... walk`: other controls legitimately retain it.
- Trace only `routes.sh pages` in its isolated disk-root run. It must show the four specified help commands and shared judgement, with zero nested complete walks, project initializations or whole-manifest CLI loops. Inspect source/call flow too, including the unconditional `mr_flips` call and its checks of all three successful named results; a renamed wrapper is not proof of deletion.
- Compare the real `51` page/CLI identities, results and counts against the baseline, and publish the narrow old→new sample inventory without synthetic passes. `section-select.sh --check` verifies the existing path registrations, not behavioral retirement.

### Measurement

Historical evidence is only `51m = 512 s` for the full section; it does not contain independent timings for ④/⑪/⑬. Current manifest shape gives old help execution counts of `56 + 56 + 48 = 160`; the candidate design has four including normal controls, a structural reduction of 156 **for this baseline manifest only**. Other file-only assertions and shared code preparation still cost work. Three old fixture initializations/CLAIM loops become zero within these controls; the full real `51` path is unchanged. ⑬ no longer needs a full skill copy, while ④/⑪ may retain their existing copies.

Record tree SHA, exact commands, tools/image, host/container, environment, help-call counts, preparation scope and wall time for actual runs. The planned baseline observes old ⑪ alone; ④/⑬ parent counts are source-attributed, not measured runs or durations. Record the candidate's entire `pages` cost, including all file cases, four renders and preparation, but publish no old-three-arm total, total elapsed saving or speed ratio from this partial baseline. Do not compare the historical full-section time with a new subset or turn `160→4` structure into seconds. Timing is reference-only, never a pass condition.

### Rollback and handoff

Reject the candidate if extraction changes a retained real-walk assertion, a bad renderer is not caught by the shared judgement, changing the shared judgement leaves its negative control green, or a retired walk still executes. Fix/revert the candidate on its task branch rather than reinstating the old walks as another mode or adding guards around the failed design. No live-team migration, data write or deployment is involved. A non-author independently reviews the proposal; after Apply another non-author verifies the delivered sample; merging and archiving remain PM actions under the existing authorizations.

## Risks / Trade-offs

- **File cases do not prove renderer wiring.** The two real damaged/normal single-page experiments retain that boundary, and `51` retains the real full manifest/enumeration/read path, including levels.
- **Failure propagation at the real-walk call sites is review-only.** Shared operations include `finding`/`FIND` accounting and status; both real-walk calls must run in the current shell and carry failure into `failed=1`. The short controls prove shared judgement/diagnosis behavior, not these two callers under damaged real pages. Deleting/ignoring that connection is checked by the implementer and independent reviewer in the two-call-site diff; no cheap behavioral coverage is claimed.
- **A copied checker or scaffold would self-confirm.** One extracted judgement and the same-script `pages` section avoid two implementations/environments. The unconditional parent invocation and three named-result checks are source-reviewed without running the whole matrix.
- **Simplified data could change parsing/multiset semantics.** Preserve the original code, cover continuation/description and duplicate/missing usage as file inputs, and compare the original real-page inventory rather than only totals.
- **Counts could conceal removed work.** The limited verification exception requires a named retirement mapping and actual results; it cannot excuse loss elsewhere. The whole-section historical aggregate is explicitly insufficient for per-control counts.
- **Elapsed savings are not yet measured.** The design reports deleted execution structure and an honest measurement boundary; it has no speed threshold and makes no claim to remove all 512 seconds.
