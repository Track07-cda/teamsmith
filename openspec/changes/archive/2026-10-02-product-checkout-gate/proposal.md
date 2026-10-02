## Why

The release export deliberately excludes this repository's ledger and Pi planning install, but its own smoke gate currently requires them. The PM measured public FAST at **✓3141 ✗16** versus internal **✓3156 ✗0**; shipping that workflow would label an intentional packaging boundary a product failure.

## What Changes

- Choose **A: visible prerequisite skips**, not B's additional published Pi scaffolding. Keep the public allowlist and `.pi/**` ban unchanged. The cost is explicit, counted gaps for checks of this development repository's planning install; product assertions retain their coverage.
- Classify prerequisites from the checkout under test, before fixtures create their own ledgers. Absence of an entire internal surface can explain only checks dependent on that surface. Partial internal trees and missing product files remain failures.
- Keep section selection and all product checks running. Distinguish unavailable planning-file existence checks from genuinely missing product literals in `section-select.sh --check`; print `SKIP（条件不满足）` with the affected check and prerequisite.
- Preserve the internal suite's existing assertions and counts; exercise both tree shapes with the same gate and negative controls.

**What flips:** the exported tree's planning prerequisites change from red to visible SKIP while product failures stay red. Reverting that attribution must restore public failures; wrongly skipping an internal assertion must fail the coverage control. These are planned acceptance experiments, not claims of completed implementation.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `verification`: add the checkout-prerequisite contract and amend the selector's unconditional literal-existence rule, retaining every existing selector scenario.

## Impact

One apply slice, then independent verification. Likely implementation paths: `skills/teamsmith/tests/smoke.sh`, `section-select.sh`, a shared test helper under `skills/teamsmith/tests/lib/`, and focused fixtures/mapping entries under `skills/teamsmith/tests/`. No runtime CLI, panel, installer, published specs, release generator, `.pi/` install, or CI trigger/tolerance change. The correctness command in `.github/workflows/gates.yml` stays unchanged; remote CI triggering and publishing require separate authorization.

Acceptance commands (implementation-stage commands and safe container recipes are detailed in design.md):

```bash
openspec validate --all --strict
bash skills/teamsmith/tests/section-select.sh --check
bash docs/team/tools/release-check.sh --with-gates
```

The release command archives committed HEAD; commit the apply changes before running it. Run tmux-dependent commands only inside a disposable gate container, never against the shared host socket. P146 itself runs validation only.

The delivery report must contain revisions, commands/exit statuses/output tails, per-section before/after counts for both shapes, visible skip reasons, both attribution flips, and real product-regression controls. Reconcile the PM's sixteen failures individually before claiming closure: the brief's enumerated rows add to fourteen and place the phase checks under §18, while the source places them under §19.
