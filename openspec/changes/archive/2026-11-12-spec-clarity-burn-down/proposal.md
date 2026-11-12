## Why

OpenSpec 1.16 rejects requirement descriptions longer than 500 characters in strict mode. This pilot rewrites the three smallest affected capabilities so later slices can repeat a reviewed, testable pattern instead of editing all specifications at once.

## What Changes

- Rewrite the 15 long requirement descriptions in `writing-discipline`, `extension-slash` and `help-surface` without changing their titles or behavioral obligations.
- Keep every existing scenario and move removed detail into existing or additional WHEN/THEN scenarios.
- Validate the change itself, then use a disposable trial archive to validate the resulting canonical specifications and measure the warning reduction.
- Do not change product code, tests, canonical specifications in this branch, command behavior or authorization behavior. Do not archive this change in the delivered tree.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `writing-discipline`: shorten four requirement descriptions; preserve support-based writing, consequence-bearing findings, named documentation surfaces and human evaluation.
- `extension-slash`: shorten six requirement descriptions; preserve command registration, token forwarding, whitelist admission, process bounds, output handling, authorization and installation behavior.
- `help-surface`: shorten five requirement descriptions; preserve help hierarchy, language selection, declared/probed claims, compatibility and locale-independent layout.

## Impact

Only `openspec/changes/spec-clarity-burn-down/**` changes. The delta is a prose-only MODIFIED rewrite: it neither adds nor removes a behavioral requirement and does not rename an existing requirement. Archiving remains a later, separately authorized step.
