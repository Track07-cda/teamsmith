# Route-page check determinism

## Why

Three page-content controls in `51m` each run a complete route walk even though their verdict depends on files already rendered or on the absence of a help level. Replace those three executions with the original content judgement over files, while retaining real renderer evidence and the full product walk in `51`.

## What Changes

- Delete the complete `walk` executions for control ④ (column-zero command line), ⑪ (undeclared command-page usage) and ⑬ (unread group level). Do not keep them behind another fast/full switch or move them to a later schedule.
- Extract the existing per-page judgement for menu/group/command pages and level judgement, including their parser, comparisons, `ok`/`finding` accounting and failure state, into one test-only implementation. Both the real `51` walk and the replacement controls use it; there is no second parser or product test switch. Review the walk's two failure-propagation call sites explicitly; the short controls do not cheaply prove those call sites.
- Exercise the original damaged renderer for ④ and ⑪ through `help board` and `help dispatch`, respectively, with controls from the unmutated tree; all four calls must exit 0 and produce nonempty files. Require the column-zero attribution finding for ④ and the manifest/page multiset-extra finding for ⑪, not merely a `ghost-probe` literal finding. For ⑬, menu/command pages pass individually, missing group is the only finding, and restoring group passes without findings. Real manifest → enumeration → page-read wiring remains in `51`.
- Run this sample through the same script's explicit `routes.sh pages` section for both acceptance and the unconditional call from non-FAST `mr_flips`; emit at least the three successful named `替代④/⑪/⑬` cases. Do not add an independent runner or duplicate the script's environment setup.
- Permit only these named replacements under the existing assertion-identity/count contract. Use routes' actual `✓/✗` totals and per-case inventory, not smoke's one-line section count. Attribute the old parent assertions by source, retain the historical non-FAST record and manually reproduce only ⑪ before implementation without editing test source. FAST smoke does not produce this evidence; do not synthesize passes to maintain a previous total.
- Keep CLI argument acceptance, unknown-argument rejection, configuration promises, refusal routes and every Pi/tmux/process/window test unchanged. Keep the other route controls, including ⑩'s real `walk control` comparison.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `dispatch`: modify **The printed route is a route that works** to make page-content controls share the real walk's file judgement, retain two damaged-renderer single-page experiments with normal controls, and remove the three redundant complete walks.
- `verification`: modify **A gate that cannot judge says so** to allow exactly those three replacements with a named coverage mapping and truthful counts, without relaxing any other assertion or prerequisite rule.

## Impact

Planned implementation paths are confined to `skills/teamsmith/tests/routes.sh` (including its short-section data and stale header description), a shared `tests/lib/routes-pages.sh`, and that helper's existing `51/51m` path registrations in `tests/section-paths.tsv`. Paths prefixed with `tests/` here are relative to `skills/teamsmith/`. No independent short-entry script, new smoke section, CI job, configuration, dependency, product command or runtime state is introduced. `mr_flips` calls the same `routes.sh pages` command once instead of the old controls. Existing stale count descriptions in smoke and the section map are outside scope.

Guard net change is zero: one shared file judgement and two single-page renderer experiments replace three heavy controls; no permanent guard is added to police deletion of the old tests. Deletion is checked in implementation review and the delivery's execution evidence.

The historical `51m` duration is 512 seconds for the whole section, not the three controls. No time saving is promised before comparable measurements. This proposal changes no source or formal capability spec; independent proposal review and PM acceptance are required before a separate implementer receives Apply authorization.
